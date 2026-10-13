---- MODULE core_4_18_5 ----
EXTENDS Naturals

\* The set of all nodes in the system
CONSTANTS Nodes
\* The set of valid exchange identifiers
CONSTANTS ExchangeIds
\* The set of possible challenge values (abstracting Crypto_DRBG)
CONSTANTS Challenges
\* A sentinel value indicating no challenge is currently set
CONSTANTS NullChallenge

\* MANDATORY INPUT SHAPE constants
CONSTANTS NoInput, Inputs

VARIABLES pendingInput
VARIABLES network
VARIABLES exchanges
VARIABLES peerStates
VARIABLES myCounters

\* Helper to represent an inactive synchronization exchange
InactiveExchange ==
    [state      |-> "Inactive",
     peer       |-> "None",
     groupId    |-> "None",
     challenge  |-> NullChallenge,
     triggerMsg |-> "None"]

\* Helper to initialize or update an active exchange
ActiveExchange(stateVal, peerVal, groupIdVal, challengeVal, triggerMsgVal) ==
    [state      |-> stateVal,
     peer       |-> peerVal,
     groupId    |-> groupIdVal,
     challenge  |-> challengeVal,
     triggerMsg |-> triggerMsgVal]

\* Helper to build a MsgCounterSyncReq message
MsgCounterSyncReq(src, dst, groupId, exId, ch) ==
    [type              |-> "MsgCounterSyncReq",
     SFlag             |-> 1,
     DSIZ              |-> 1,
     PFlag             |-> 1,
     CFlag             |-> 1,
     SessionType       |-> 1,
     SessionId         |-> groupId,
     SourceNodeId      |-> src,
     DestinationNodeId |-> dst,
     ExchangeId        |-> exId,
     IFlag             |-> 1,
     AFlag             |-> 0,
     RFlag             |-> 1,
     Challenge         |-> ch]

\* Helper to build a MsgCounterSyncRsp message
MsgCounterSyncRsp(src, dst, groupId, exId, resp, syncCounter) ==
    [type                |-> "MsgCounterSyncRsp",
     SFlag               |-> 1,
     DSIZ                |-> 1,
     PFlag               |-> 1,
     CFlag               |-> 1,
     SessionType         |-> 1,
     SessionId           |-> groupId,
     SourceNodeId        |-> src,
     DestinationNodeId   |-> dst,
     ExchangeId          |-> exId,
     IFlag               |-> 0,
     AFlag               |-> 1,
     RFlag               |-> 1,
     Response            |-> resp,
     SynchronizedCounter |-> syncCounter]

Init ==
    /\ pendingInput = NoInput
    /\ network = {}
    /\ exchanges = [n \in Nodes |-> [x \in ExchangeIds |-> InactiveExchange]]
    /\ peerStates = [n \in Nodes |-> [p \in Nodes |->
                       [counter |-> 0, synchronized |-> TRUE, bitmapCleared |-> FALSE]]]
    /\ myCounters = [n \in Nodes |-> 0]

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<network, exchanges, peerStates, myCounters>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
\* A message synchronization exchange starts by sending the MsgCounterSyncReq message to the
\* peer Node that sent the message with unknown message counter. When a synchronization request
\* is triggered by an incoming multicast message, the Node SHALL first wait for a uniformly random
\* amount of time between 0 and MSG_COUNTER_SYNC_REQ_JITTER.
TriggerSyncRequest ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "TriggerSync"
    /\ \E exId \in ExchangeIds:
        /\ exchanges[pendingInput.node][exId].state = "Inactive"
        /\ IF pendingInput.isMulticast
           THEN
               /\ exchanges' = [exchanges EXCEPT ![pendingInput.node][exId] =
                      ActiveExchange("Jitter", pendingInput.sourceNode, pendingInput.groupId, NullChallenge, pendingInput.msgId)]
               /\ network' = network
           ELSE
               \E ch \in Challenges:
                   /\ exchanges' = [exchanges EXCEPT ![pendingInput.node][exId] =
                          ActiveExchange("SyncWait", pendingInput.sourceNode, pendingInput.groupId, ch, pendingInput.msgId)]
                   /\ network' = network \cup {
                          MsgCounterSyncReq(
                              pendingInput.node,
                              pendingInput.sourceNode,
                              pendingInput.groupId,
                              exId,
                              ch
                          )
                      }
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<peerStates, myCounters>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
\* The sender of the MsgCounterSyncReq message SHALL: 1. Set the Message Header fields ...
\* 2. Create a new synchronization Exchange ... 3. Set the Challenge field to the value returned by Crypto_DRBG ...
\* 4. Arm a timer ... 5. Invoke Section 4.7.1 ... to encrypt and then send the request message over UDP
HandleJitterTimeout ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "JitterTimeout"
    /\ LET node == pendingInput.node
           exId == pendingInput.exchangeId
           ex == exchanges[node][exId]
       IN
           /\ ex.state = "Jitter"
           /\ \E ch \in Challenges:
                  /\ exchanges' = [exchanges EXCEPT ![node][exId] =
                         ActiveExchange("SyncWait", ex.peer, ex.groupId, ch, ex.triggerMsg)]
                  /\ network' = network \cup {
                         MsgCounterSyncReq(node, ex.peer, ex.groupId, exId, ch)
                     }
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<peerStates, myCounters>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
\* 4.a. Upon firing of the timer: i. The synchronization exchange SHALL be closed.
\* ii. Any message waiting on synchronization associated with the exchange SHALL be discarded.
HandleSyncTimeout ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "SyncTimeout"
    /\ exchanges[pendingInput.node][pendingInput.exchangeId].state = "SyncWait"
    /\ exchanges' = [exchanges EXCEPT ![pendingInput.node][pendingInput.exchangeId] = InactiveExchange]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<network, peerStates, myCounters>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
\* The receiver of MsgCounterSyncReq SHALL: 1. Verify the Destination Node ID field SHALL match the Node ID
\* of the receiver, otherwise discard the message. 2. Respond with MsgCounterSyncRsp.
ReceiveMsgCounterSyncReq ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "Delivery"
    /\ pendingInput.msg.type = "MsgCounterSyncReq"
    /\ IF pendingInput.msg.DestinationNodeId # pendingInput.node
       THEN
           \* discard
           /\ network' = network
       ELSE
           \* Respond with MsgCounterSyncRsp
           /\ network' = network \cup {
                  MsgCounterSyncRsp(
                      pendingInput.node,
                      pendingInput.msg.SourceNodeId,
                      pendingInput.msg.SessionId,
                      pendingInput.msg.ExchangeId,
                      pendingInput.msg.Challenge,
                      myCounters[pendingInput.node]
                  )
              }
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<exchanges, peerStates, myCounters>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
\* The receiver of the MsgCounterSyncRsp message SHALL: 1. Verify the MsgCounterSyncRsp matches a previously
\* sent MsgCounterSyncReq: ... 2. On verification failure: silently ignore ... 3. On verification success:
\* a. Set the peer’s group key data message counter ... b. Clear the ... Message Reception State ...
\* c. Mark the peer 's group key data message counter as synchronized ... d. Resume processing ...
\* e. Close the synchronization exchange ...
ReceiveMsgCounterSyncRsp ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "Delivery"
    /\ pendingInput.msg.type = "MsgCounterSyncRsp"
    /\ LET msg == pendingInput.msg
           node == pendingInput.node
           exId == msg.ExchangeId
       IN IF exId \in ExchangeIds THEN
              LET ex == exchanges[node][exId]
                  isValid ==
                      /\ ex.state = "SyncWait"
                      /\ ex.peer = msg.SourceNodeId
                      /\ msg.ExchangeId = exId
                      /\ msg.Response = ex.challenge
                      /\ msg.DestinationNodeId = node
                      /\ msg.SourceNodeId = ex.peer
              IN IF isValid
                 THEN
                     /\ peerStates' = [peerStates EXCEPT ![node][msg.SourceNodeId] =
                            [counter       |-> msg.SynchronizedCounter,
                             synchronized  |-> TRUE,
                             bitmapCleared |-> TRUE]]
                     \* Resume processing is modeled implicitly here; clearing the exchange flushes triggerMsg state.
                     /\ exchanges' = [exchanges EXCEPT ![node][exId] = InactiveExchange]
                 ELSE
                     /\ UNCHANGED <<peerStates, exchanges>>
          ELSE
              /\ UNCHANGED <<peerStates, exchanges>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<network, myCounters>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ TriggerSyncRequest
    \/ HandleJitterTimeout
    \/ HandleSyncTimeout
    \/ ReceiveMsgCounterSyncReq
    \/ ReceiveMsgCounterSyncRsp

====