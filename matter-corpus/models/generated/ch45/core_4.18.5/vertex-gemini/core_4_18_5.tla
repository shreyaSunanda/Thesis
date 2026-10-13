---- MODULE core_4_18_5 ----
EXTENDS Naturals, Sequences

\* CONSTANTS defined in the spec text.
\* MSG_COUNTER_SYNC_REQ_JITTER: upper bound for random jitter before sending req.
\* MSG_COUNTER_SYNC_TIMEOUT: time to wait for a synchronization response.
CONSTANTS
    Nodes,
    ExchangeIds,
    Challenges,
    GroupSessionIds,
    Messages,
    MSG_COUNTER_SYNC_REQ_JITTER,
    MSG_COUNTER_SYNC_TIMEOUT

VARIABLES 
    network,
    activeExchanges,
    globalGroupCounters,
    peerCounters,
    peerSyncStatus,
    peerBitmapClear

Init == 
    /\ network = {}
    /\ activeExchanges = [n \in Nodes |-> {}]
    /\ globalGroupCounters = [n \in Nodes |-> 0]
    /\ peerCounters = [n \in Nodes |-> [p \in Nodes |-> 0]]
    /\ peerSyncStatus = [n \in Nodes |-> [p \in Nodes |-> FALSE]]
    /\ peerBitmapClear = [n \in Nodes |-> [p \in Nodes |-> FALSE]]

\* Helper: constructs a MsgCounterSyncReq message
ReqMsg(sender, dest, exId, challenge, groupId) ==
    [ type |-> "MsgCounterSyncReq",
      S |-> 1,
      DSIZ |-> 1,
      P |-> 1,
      C |-> 1,
      sessionType |-> 1,
      sessionId |-> groupId,
      sourceNodeId |-> sender,
      destNodeId |-> dest,
      exchangeId |-> exId,
      I |-> 1,
      A |-> 0,
      R |-> 1,
      challenge |-> challenge ]

\* Helper: constructs a new synchronization Exchange record
NewExchange(exId, dest, challenge, groupId, triggerMsg) ==
    [ id |-> exId,
      destNodeId |-> dest,
      challenge |-> challenge,
      groupId |-> groupId,
      queuedMsgs |-> <<triggerMsg>> ]

\* Helper: constructs a MsgCounterSyncRsp message
RspMsg(receiver, req, syncCounter) ==
    [ type |-> "MsgCounterSyncRsp",
      S |-> 1,
      DSIZ |-> 1,
      P |-> 1,
      C |-> 1,
      sessionType |-> 1,
      sessionId |-> req.sessionId,
      sourceNodeId |-> receiver,
      destNodeId |-> req.sourceNodeId,
      exchangeId |-> req.exchangeId,
      I |-> 0,
      A |-> 1,
      R |-> 1,
      response |-> req.challenge,
      synchronizedCounter |-> syncCounter ]

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
\* Steps for the sender of the MsgCounterSyncReq message.
SendMsgCounterSyncReq(sender, triggerMsgSource, triggerMsg, exId, challenge, groupId) ==
    /\ exId \in ExchangeIds
    /\ challenge \in Challenges
    /\ groupId \in GroupSessionIds
    /\ triggerMsg \in Messages
    /\ ~\E ex \in activeExchanges[sender] : ex.id = exId
    /\ activeExchanges' = [activeExchanges EXCEPT ![sender] = @ \cup {NewExchange(exId, triggerMsgSource, challenge, groupId, triggerMsg)}]
    /\ network' = network \cup {ReqMsg(sender, triggerMsgSource, exId, challenge, groupId)}
    /\ UNCHANGED <<globalGroupCounters, peerCounters, peerSyncStatus, peerBitmapClear>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
\* Enforcing the MSG_COUNTER_SYNC_TIMEOUT.
TimeoutMsgCounterSyncReq(sender, exId) ==
    /\ \E ex \in activeExchanges[sender] : ex.id = exId
    \* 4.a.i. The synchronization exchange SHALL be closed.
    \* 4.a.ii. Any message waiting on synchronization associated with the exchange SHALL be discarded.
    \* (Implicitly discarded by removing the exchange which holds queuedMsgs)
    /\ activeExchanges' = [activeExchanges EXCEPT ![sender] = {e \in @ : e.id # exId}]
    /\ UNCHANGED <<network, globalGroupCounters, peerCounters, peerSyncStatus, peerBitmapClear>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
\* Steps for the receiver of MsgCounterSyncReq and sender of MsgCounterSyncRsp.
ReceiveReqAndSendRsp(receiver, req) ==
    /\ req \in network
    /\ req.type = "MsgCounterSyncReq"
    \* 1. Verify the Destination Node ID field SHALL match the Node ID of the receiver, otherwise discard
    /\ req.destNodeId = receiver
    \* 2. Respond with MsgCounterSyncRsp.
    /\ network' = network \cup {RspMsg(receiver, req, globalGroupCounters[receiver])}
    /\ UNCHANGED <<activeExchanges, globalGroupCounters, peerCounters, peerSyncStatus, peerBitmapClear>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
\* Steps for the receiver of the MsgCounterSyncRsp message (verification success).
ReceiveMsgCounterSyncRspSuccess(receiver, rsp) ==
    /\ rsp \in network
    /\ rsp.type = "MsgCounterSyncRsp"
    \* 1. Verify the MsgCounterSyncRsp matches a previously sent MsgCounterSyncReq
    /\ \E ex \in activeExchanges[receiver] :
        /\ ex.destNodeId = rsp.sourceNodeId
        /\ ex.id = rsp.exchangeId
        /\ ex.challenge = rsp.response
        /\ rsp.destNodeId = receiver
        \* 3. On verification success:
        \* a. Set the peer’s group key data message counter to Synchronized Counter.
        /\ peerCounters' = [peerCounters EXCEPT ![receiver][rsp.sourceNodeId] = rsp.synchronizedCounter]
        \* b. Clear the Section 4.6.5.1, “Message Reception State” bitmap for the peer.
        /\ peerBitmapClear' = [peerBitmapClear EXCEPT ![receiver][rsp.sourceNodeId] = TRUE]
        \* c. Mark the peer's group key data message counter as synchronized.
        /\ peerSyncStatus' = [peerSyncStatus EXCEPT ![receiver][rsp.sourceNodeId] = TRUE]
        \* d. Resume processing of any queued message... e. Close the synchronization exchange.
        \* (Stopping the timer is implicit via exchange removal).
        /\ activeExchanges' = [activeExchanges EXCEPT ![receiver] = {e \in @ : e.id # ex.id}]
    /\ UNCHANGED <<network, globalGroupCounters>>

Next == 
    \/ \E sender \in Nodes : \E triggerMsgSource \in Nodes : \E triggerMsg \in Messages : \E exId \in ExchangeIds : \E challenge \in Challenges : \E groupId \in GroupSessionIds :
        SendMsgCounterSyncReq(sender, triggerMsgSource, triggerMsg, exId, challenge, groupId)
    \/ \E sender \in Nodes : \E exId \in ExchangeIds :
        TimeoutMsgCounterSyncReq(sender, exId)
    \/ \E receiver \in Nodes : \E req \in network :
        ReceiveReqAndSendRsp(receiver, req)
    \/ \E receiver \in Nodes : \E rsp \in network :
        ReceiveMsgCounterSyncRspSuccess(receiver, rsp)

====