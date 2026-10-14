---- MODULE core_4_18_5 ----
EXTENDS Naturals

\* Real value per spec: Maximum random jitter time to wait before sending sync req on multicast
CONSTANTS MSG_COUNTER_SYNC_REQ_JITTER
\* Real value per spec: Timeout to wait for a synchronization response
CONSTANTS MSG_COUNTER_SYNC_TIMEOUT
\* Abstract limits to ensure finite state space for model checking
CONSTANTS MaxNodeId, MaxExchangeId, MaxChallenge, MaxSessionId, MaxCounter, MaxTimerId
\* The Node ID of the entity running this protocol logic
CONSTANTS MyNodeId

\* Mandatory inputs sentinel
CONSTANTS NoInput
\* Sentinels for data input fields
CONSTANTS NullMsg, NullTimerId

VARIABLES
    pendingInput,
    in_msg,
    in_triggerMsg,
    in_timerId,
    activeExchanges,
    jitterTimers,
    syncTimers,
    queuedMsgs,
    peerMessageCounters,
    peerReceptionStateCleared,
    peerCounterSynchronized,
    myGroupDataCounter,
    network,
    nextExchangeId,
    nextTimerId

NodeIds == 1..MaxNodeId
SessionIds == 1..MaxSessionId
ExchangeIds == 1..MaxExchangeId
Challenges == 1..MaxChallenge
Counters == 1..MaxCounter
TimerIds == 1..MaxTimerId

TriggerMessages == [
    sessionId : SessionIds,
    srcNodeId : NodeIds,
    isMulticast : BOOLEAN
]

Messages == [
    type : {"MsgCounterSyncReq", "MsgCounterSyncRsp"},
    SFlag : {0, 1},
    DSIZ : {0, 1},
    PFlag : {0, 1},
    CFlag : {0, 1},
    sessionType : {0, 1},
    sessionId : SessionIds,
    srcNodeId : NodeIds,
    dstNodeId : NodeIds,
    exchangeId : ExchangeIds,
    IFlag : {0, 1},
    AFlag : {0, 1},
    RFlag : {0, 1},
    challenge : Challenges \cup {0},
    response : Challenges \cup {0},
    syncCounter : Counters \cup {0}
]

Inputs == {
    "TriggerSync",
    "JitterDelayExpired",
    "SyncTimeoutExpired",
    "ReceiveMsgCounterSyncReq",
    "ReceiveMsgCounterSyncRsp"
}

ReqMsg(triggerMsg, exId, chal) == [
    type |-> "MsgCounterSyncReq",
    SFlag |-> 1,
    DSIZ |-> 1,
    PFlag |-> 1,
    CFlag |-> 1,
    sessionType |-> 1,
    sessionId |-> triggerMsg.sessionId,
    srcNodeId |-> MyNodeId,
    dstNodeId |-> triggerMsg.srcNodeId,
    exchangeId |-> exId,
    IFlag |-> 1,
    AFlag |-> 0,
    RFlag |-> 1,
    challenge |-> chal,
    response |-> 0,
    syncCounter |-> 0
]

RspMsg(reqMsg, syncCtr) == [
    type |-> "MsgCounterSyncRsp",
    SFlag |-> 1,
    DSIZ |-> 1,
    PFlag |-> 1,
    CFlag |-> 1,
    sessionType |-> 1,
    sessionId |-> reqMsg.sessionId,
    srcNodeId |-> MyNodeId,
    dstNodeId |-> reqMsg.srcNodeId,
    exchangeId |-> reqMsg.exchangeId,
    IFlag |-> 0,
    AFlag |-> 1,
    RFlag |-> 1,
    challenge |-> 0,
    response |-> reqMsg.challenge,
    syncCounter |-> syncCtr
]

NewExchange(exId, chal, dstNode, trigMsg) ==
    [exchangeId |-> exId, challenge |-> chal, dstNodeId |-> dstNode, triggerMsg |-> trigMsg]

NewTimer(tId, trigMsg) ==
    [timerId |-> tId, triggerMsg |-> trigMsg]

NewSyncTimer(tId, exId) ==
    [timerId |-> tId, exchangeId |-> exId]

Init ==
    /\ pendingInput = NoInput
    /\ in_msg = NullMsg
    /\ in_triggerMsg = NullMsg
    /\ in_timerId = NullTimerId
    /\ activeExchanges = {}
    /\ jitterTimers = {}
    /\ syncTimers = {}
    /\ queuedMsgs = {}
    /\ peerMessageCounters = [n \in NodeIds |-> 0]
    /\ peerReceptionStateCleared = [n \in NodeIds |-> FALSE]
    /\ peerCounterSynchronized = [n \in NodeIds |-> FALSE]
    /\ myGroupDataCounter = 1
    /\ network = {}
    /\ nextExchangeId = 1
    /\ nextTimerId = 1

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ in_msg' \in Messages \cup {NullMsg}
    /\ in_triggerMsg' \in TriggerMessages \cup {NullMsg}
    /\ in_timerId' \in TimerIds \cup {NullTimerId}
    /\ UNCHANGED <<activeExchanges, jitterTimers, syncTimers, queuedMsgs,
                   peerMessageCounters, peerReceptionStateCleared,
                   peerCounterSynchronized, myGroupDataCounter,
                   network, nextExchangeId, nextTimerId>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
HandleTriggerSync ==
    /\ pendingInput = "TriggerSync"
    /\ in_triggerMsg # NullMsg
    /\ queuedMsgs' = queuedMsgs \cup {in_triggerMsg}
    /\ IF in_triggerMsg.isMulticast
       THEN
           /\ jitterTimers' = jitterTimers \cup {NewTimer(nextTimerId, in_triggerMsg)}
           /\ nextTimerId' = IF nextTimerId < MaxTimerId THEN nextTimerId + 1 ELSE 1
           /\ UNCHANGED <<activeExchanges, syncTimers, nextExchangeId, network>>
       ELSE
           /\ \E chal \in Challenges:
                LET exId == nextExchangeId
                    msg == ReqMsg(in_triggerMsg, exId, chal)
                IN
                    /\ network' = network \cup {msg}
                    /\ activeExchanges' = activeExchanges \cup {NewExchange(exId, chal, in_triggerMsg.srcNodeId, in_triggerMsg)}
                    /\ syncTimers' = syncTimers \cup {NewSyncTimer(nextTimerId, exId)}
                    /\ nextExchangeId' = IF nextExchangeId < MaxExchangeId THEN nextExchangeId + 1 ELSE 1
                    /\ nextTimerId' = IF nextTimerId < MaxTimerId THEN nextTimerId + 1 ELSE 1
           /\ UNCHANGED jitterTimers
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<peerMessageCounters, peerReceptionStateCleared, peerCounterSynchronized,
                   myGroupDataCounter, in_msg, in_triggerMsg, in_timerId>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
HandleJitterDelayExpired ==
    /\ pendingInput = "JitterDelayExpired"
    /\ in_timerId # NullTimerId
    /\ \E jt \in jitterTimers :
        /\ jt.timerId = in_timerId
        /\ \E chal \in Challenges:
            LET exId == nextExchangeId
                msg == ReqMsg(jt.triggerMsg, exId, chal)
            IN
                /\ network' = network \cup {msg}
                /\ activeExchanges' = activeExchanges \cup {NewExchange(exId, chal, jt.triggerMsg.srcNodeId, jt.triggerMsg)}
                /\ syncTimers' = syncTimers \cup {NewSyncTimer(nextTimerId, exId)}
                /\ nextExchangeId' = IF nextExchangeId < MaxExchangeId THEN nextExchangeId + 1 ELSE 1
                /\ nextTimerId' = IF nextTimerId < MaxTimerId THEN nextTimerId + 1 ELSE 1
        /\ jitterTimers' = jitterTimers \ {jt}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<queuedMsgs, peerMessageCounters, peerReceptionStateCleared,
                   peerCounterSynchronized, myGroupDataCounter, in_msg, in_triggerMsg, in_timerId>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
HandleSyncTimeoutExpired ==
    /\ pendingInput = "SyncTimeoutExpired"
    /\ in_timerId # NullTimerId
    /\ \E st \in syncTimers :
        /\ st.timerId = in_timerId
        /\ \E ex \in activeExchanges :
            /\ ex.exchangeId = st.exchangeId
            /\ activeExchanges' = activeExchanges \ {ex}
            /\ queuedMsgs' = {m \in queuedMsgs : m # ex.triggerMsg}
        /\ syncTimers' = syncTimers \ {st}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<jitterTimers, nextExchangeId, nextTimerId, network, peerMessageCounters,
                   peerReceptionStateCleared, peerCounterSynchronized, myGroupDataCounter,
                   in_msg, in_triggerMsg, in_timerId>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
HandleReceiveMsgCounterSyncReq ==
    /\ pendingInput = "ReceiveMsgCounterSyncReq"
    /\ in_msg # NullMsg
    /\ in_msg.type = "MsgCounterSyncReq"
    /\ IF in_msg.dstNodeId = MyNodeId
       THEN
           /\ network' = network \cup {RspMsg(in_msg, myGroupDataCounter)}
       ELSE
           /\ UNCHANGED network
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<activeExchanges, jitterTimers, syncTimers, queuedMsgs, peerMessageCounters,
                   peerReceptionStateCleared, peerCounterSynchronized, myGroupDataCounter,
                   nextExchangeId, nextTimerId, in_msg, in_triggerMsg, in_timerId>>

\* SOURCE: core_4.18.5 Message Counter Synchronization Exchange
HandleReceiveMsgCounterSyncRsp ==
    /\ pendingInput = "ReceiveMsgCounterSyncRsp"
    /\ in_msg # NullMsg
    /\ in_msg.type = "MsgCounterSyncRsp"
    /\ LET matchingExchanges == { ex \in activeExchanges :
                                    /\ ex.exchangeId = in_msg.exchangeId
                                    /\ ex.challenge = in_msg.response
                                    /\ in_msg.dstNodeId = MyNodeId
                                    /\ in_msg.srcNodeId = ex.dstNodeId }
       IN
           IF matchingExchanges # {}
           THEN
               \E ex \in matchingExchanges :
                   /\ peerMessageCounters' = [peerMessageCounters EXCEPT ![in_msg.srcNodeId] = in_msg.syncCounter]
                   /\ peerReceptionStateCleared' = [peerReceptionStateCleared EXCEPT ![in_msg.srcNodeId] = TRUE]
                   /\ peerCounterSynchronized' = [peerCounterSynchronized EXCEPT ![in_msg.srcNodeId] = TRUE]
                   \* TODO: unspecified - abstracted ordered message processing on resumption as plain removal from queuedMsgs
                   /\ queuedMsgs' = {m \in queuedMsgs : m.srcNodeId # in_msg.srcNodeId \/ m.sessionId # in_msg.sessionId}
                   /\ activeExchanges' = activeExchanges \ {ex}
                   /\ syncTimers' = {t \in syncTimers : t.exchangeId # ex.exchangeId}
           ELSE
               /\ UNCHANGED <<peerMessageCounters, peerReceptionStateCleared, peerCounterSynchronized,
                              queuedMsgs, activeExchanges, syncTimers>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<jitterTimers, myGroupDataCounter, network, nextExchangeId, nextTimerId,
                   in_msg, in_triggerMsg, in_timerId>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleTriggerSync
    \/ HandleJitterDelayExpired
    \/ HandleSyncTimeoutExpired
    \/ HandleReceiveMsgCounterSyncReq
    \/ HandleReceiveMsgCounterSyncRsp

====