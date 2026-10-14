---- MODULE core_4_18_5 ----
EXTENDS Naturals

\* Declare EVERY fixed value the spec text mentions (timeouts, limits, thresholds,
\* fabric indices, etc.) here. Give each one a short comment saying what it is.
CONSTANTS NoInput
CONSTANTS LocalNodeId \* The Node ID of the receiver/sender in this local context

VARIABLES pendingInput
\* Input payload variables to carry event data without violating strict string Inputs rule
VARIABLES inSourceId
VARIABLES inDestId
VARIABLES inExchangeId
VARIABLES inChallengeOrResponse
VARIABLES inSyncCounter

\* State variables
VARIABLES outMsg
VARIABLES syncState
VARIABLES activeExchange
VARIABLES timerArmed
VARIABLES peerMessageReceptionState
VARIABLES queuedMessagesCount
VARIABLES localGlobalGroupCounter

\* REQUIRED - the complete list of events this section can receive. See rule 4a.
Inputs == {
    "TriggerSync",
    "JitterTimerExpired",
    "ReceiveMsgCounterSyncReq",
    "ReceiveMsgCounterSyncRsp",
    "SyncTimeout"
}

Operational == syncState \in {"Idle", "WaitingJitter", "Syncing"}

NoMessage == [type |-> "None"]

NewExchange(peer) == [
    active |-> TRUE,
    exchangeId |-> 42,
    challenge |-> 123,
    peerId |-> peer
]

ReqMsg(peer) == [
    type |-> "MsgCounterSyncReq",
    destId |-> peer,
    exchangeId |-> 42,
    challenge |-> 123,
    sFlag |-> 1,
    dsiz |-> 1,
    pFlag |-> 1,
    cFlag |-> 1,
    sessionType |-> 1,
    iFlag |-> 1,
    aFlag |-> 0,
    rFlag |-> 1
]

RspMsg(dest, xid, chal, cnt) == [
    type |-> "MsgCounterSyncRsp",
    destId |-> dest,
    exchangeId |-> xid,
    response |-> chal,
    syncCounter |-> cnt,
    sFlag |-> 1,
    dsiz |-> 1,
    pFlag |-> 1,
    cFlag |-> 1,
    sessionType |-> 1,
    iFlag |-> 0,
    aFlag |-> 1,
    rFlag |-> 1
]

SyncedPeerState(cnt) == [
    counter |-> cnt,
    synchronized |-> TRUE,
    bitmapCleared |-> TRUE
]

Init ==
    /\ pendingInput = NoInput
    /\ inSourceId = 0
    /\ inDestId = 0
    /\ inExchangeId = 0
    /\ inChallengeOrResponse = 0
    /\ inSyncCounter = 0
    /\ outMsg = NoMessage
    /\ syncState = "Idle"
    /\ activeExchange = [active |-> FALSE, exchangeId |-> 0, challenge |-> 0, peerId |-> 0]
    /\ timerArmed = FALSE
    /\ peerMessageReceptionState = [counter |-> 0, synchronized |-> TRUE, bitmapCleared |-> TRUE]
    /\ queuedMessagesCount = 0
    /\ localGlobalGroupCounter = 100

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E src, dst, xid, chal, cnt \in 0..3 :
           /\ inSourceId' = src
           /\ inDestId' = dst
           /\ inExchangeId' = xid
           /\ inChallengeOrResponse' = chal
           /\ inSyncCounter' = cnt
    /\ UNCHANGED << outMsg, syncState, activeExchange, timerArmed, peerMessageReceptionState, queuedMessagesCount, localGlobalGroupCounter >>

\* SOURCE: core_4.18.5 "When a synchronization request is triggered by an incoming multicast message, the Node SHALL first wait for a uniformly random amount of time..."
HandleTriggerSync ==
    /\ pendingInput = "TriggerSync"
    \* TODO: unspecified - what happens if a node is already actively syncing with another peer when a new TriggerSync arrives?
    /\ syncState' = "WaitingJitter"
    /\ activeExchange' = [activeExchange EXCEPT !.peerId = inSourceId]
    /\ queuedMessagesCount' = 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inSourceId, inDestId, inExchangeId, inChallengeOrResponse, inSyncCounter, outMsg, timerArmed, peerMessageReceptionState, localGlobalGroupCounter >>

\* SOURCE: core_4.18.5 "The sender of the MsgCounterSyncReq message SHALL: ... Set Header ... Create new synchronization Exchange ... Arm a timer ... send the request message"
HandleJitterTimerExpired ==
    /\ pendingInput = "JitterTimerExpired"
    /\ syncState = "WaitingJitter"
    /\ syncState' = "Syncing"
    /\ activeExchange' = NewExchange(activeExchange.peerId)
    /\ timerArmed' = TRUE
    /\ outMsg' = ReqMsg(activeExchange.peerId)
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inSourceId, inDestId, inExchangeId, inChallengeOrResponse, inSyncCounter, peerMessageReceptionState, queuedMessagesCount, localGlobalGroupCounter >>

\* SOURCE: core_4.18.5 "Upon firing of the timer: i. The synchronization exchange SHALL be closed. ii. Any message waiting on synchronization associated with the exchange SHALL be discarded."
HandleSyncTimeout ==
    /\ pendingInput = "SyncTimeout"
    /\ timerArmed = TRUE
    /\ syncState' = "Idle"
    /\ timerArmed' = FALSE
    /\ activeExchange' = [activeExchange EXCEPT !.active = FALSE]
    /\ queuedMessagesCount' = 0
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inSourceId, inDestId, inExchangeId, inChallengeOrResponse, inSyncCounter, outMsg, peerMessageReceptionState, localGlobalGroupCounter >>

\* SOURCE: core_4.18.5 "The receiver of MsgCounterSyncReq SHALL: 1. Verify the Destination Node ID ... otherwise discard. 2. Respond with MsgCounterSyncRsp."
HandleReceiveMsgCounterSyncReq ==
    /\ pendingInput = "ReceiveMsgCounterSyncReq"
    /\ IF inDestId = LocalNodeId THEN
           /\ outMsg' = RspMsg(inSourceId, inExchangeId, inChallengeOrResponse, localGlobalGroupCounter)
       ELSE
           /\ outMsg' = outMsg
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inSourceId, inDestId, inExchangeId, inChallengeOrResponse, inSyncCounter, syncState, activeExchange, timerArmed, peerMessageReceptionState, queuedMessagesCount, localGlobalGroupCounter >>

\* SOURCE: core_4.18.5 "The receiver of the MsgCounterSyncRsp message SHALL: 1. Verify ... matches a previously sent ... 2. On verification failure: silently ignore ... 3. On verification success: ..."
HandleReceiveMsgCounterSyncRsp ==
    /\ pendingInput = "ReceiveMsgCounterSyncRsp"
    /\ LET isValid ==
           /\ activeExchange.active = TRUE
           /\ activeExchange.peerId = inSourceId
           /\ activeExchange.exchangeId = inExchangeId
           /\ activeExchange.challenge = inChallengeOrResponse
           /\ inDestId = LocalNodeId
       IN
           IF isValid THEN
               /\ peerMessageReceptionState' = SyncedPeerState(inSyncCounter)
               /\ activeExchange' = [activeExchange EXCEPT !.active = FALSE]
               /\ timerArmed' = FALSE
               /\ syncState' = "Idle"
               /\ queuedMessagesCount' = 0
           ELSE
               /\ UNCHANGED << peerMessageReceptionState, activeExchange, timerArmed, syncState, queuedMessagesCount >>
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inSourceId, inDestId, inExchangeId, inChallengeOrResponse, inSyncCounter, outMsg, localGlobalGroupCounter >>

Next ==
    \/ \E e \in Inputs : ReceiveInput(e)
    \/ HandleTriggerSync
    \/ HandleJitterTimerExpired
    \/ HandleSyncTimeout
    \/ HandleReceiveMsgCounterSyncReq
    \/ HandleReceiveMsgCounterSyncRsp

====