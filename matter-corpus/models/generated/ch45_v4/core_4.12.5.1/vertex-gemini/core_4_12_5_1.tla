---- MODULE core_4_12_5_1 ----
EXTENDS Naturals

\* Maximum number of retransmission attempts before eviction.
CONSTANTS MaxRetries

\* Sentinel value for unsecured session type.
CONSTANTS UnsecuredSessionType

\* Sentinel value for no pending input.
CONSTANTS NoInput

\* Sentinel value for a missing or null message ID.
CONSTANTS NullMsgId

VARIABLES state
VARIABLES pendingInput
VARIABLES inputMsg
VARIABLES timeoutMsgId
VARIABLES activeMsgId
VARIABLES ackTable
VARIABLES retransTable
VARIABLES appNotifications

Inputs == {
    "PrepareOutgoingMessage",
    "TransportSendFatalError",
    "TransportSendRetriableError",
    "TransportSendSuccess",
    "RetransmissionTimeout"
}

Operational == state \in {"IDLE", "WAITING_TRANSPORT"}

DummyMsg == [
    msgId |-> NullMsgId, 
    destNodeId |-> 0, 
    exchangeId |-> 0, 
    sessionId |-> 0, 
    sessionCredentials |-> 0, 
    sessionType |-> UnsecuredSessionType, 
    isStandaloneAck |-> FALSE, 
    reliable |-> FALSE, 
    transport |-> "UDP", 
    securityFlags |-> 0, 
    aFlag |-> FALSE, 
    ackMsgCounter |-> 0, 
    rFlag |-> FALSE
]

Init ==
    /\ state = "IDLE"
    /\ pendingInput = NoInput
    /\ inputMsg = DummyMsg
    /\ timeoutMsgId = NullMsgId
    /\ activeMsgId = NullMsgId
    /\ ackTable = {}
    /\ retransTable = {}
    /\ appNotifications = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, inputMsg, timeoutMsgId, activeMsgId, ackTable, retransTable, appNotifications>>

\* -----------------------------------------------------------------------------
\* Helper definitions for Piggyback Acknowledgment Processing
\* -----------------------------------------------------------------------------

IsAckMatch(msg, ack) ==
    /\ msg.destNodeId = ack.destNodeId
    /\ msg.exchangeId = ack.exchangeId
    /\ \/ (msg.sessionId = ack.sessionId /\ msg.sessionCredentials = ack.sessionCredentials)
       \/ (msg.sessionType = UnsecuredSessionType /\ ack.sessionType = UnsecuredSessionType)

MatchingAcks(msg, acks) ==
    {ack \in acks : IsAckMatch(msg, ack)}

HasMatchingAck(msg, acks) ==
    MatchingAcks(msg, acks) # {}

DummyAck ==
    [destNodeId |-> 0, exchangeId |-> 0, sessionId |-> 0, sessionCredentials |-> 0, sessionType |-> UnsecuredSessionType, msgCounterToAck |-> 0, standaloneAckSent |-> FALSE]

ChosenAck(msg, acks) ==
    IF HasMatchingAck(msg, acks) THEN CHOOSE ack \in MatchingAcks(msg, acks) : TRUE ELSE DummyAck

MsgWithAFlag(msg, acks) ==
    IF HasMatchingAck(msg, acks) THEN
        [msg EXCEPT !.aFlag = TRUE, !.ackMsgCounter = ChosenAck(msg, acks).msgCounterToAck]
    ELSE
        msg

NewAckTable(msg, acks) ==
    IF HasMatchingAck(msg, acks) THEN
        IF ~msg.isStandaloneAck THEN
            acks \ {ChosenAck(msg, acks)}
        ELSE
            (acks \ {ChosenAck(msg, acks)}) \cup {[ChosenAck(msg, acks) EXCEPT !.standaloneAckSent = TRUE]}
    ELSE
        acks

\* -----------------------------------------------------------------------------
\* Helper definitions for Message Retransmission Processing
\* -----------------------------------------------------------------------------

IsReliableUDP(msg) ==
    msg.reliable /\ msg.transport = "UDP"

MsgWithRFlag(msg, acks) ==
    IF IsReliableUDP(msg) THEN
        [MsgWithAFlag(msg, acks) EXCEPT !.rFlag = TRUE]
    ELSE
        MsgWithAFlag(msg, acks)

NewRetransTableEntry(msg, acks) ==
    [
        msgId |-> msg.msgId,
        msg |-> MsgWithRFlag(msg, acks),
        sendCount |-> 0,
        timerActive |-> FALSE,
        destNodeId |-> msg.destNodeId,
        sessionId |-> msg.sessionId,
        securityFlags |-> msg.securityFlags,
        transport |-> msg.transport
    ]

NewRetransTable(msg, acks, rTable) ==
    IF IsReliableUDP(msg) THEN
        rTable \cup {NewRetransTableEntry(msg, acks)}
    ELSE
        rTable

HasRetransEntry(rTable, mId) ==
    \E r \in rTable : r.msgId = mId

DummyRetransEntry == 
    [msgId |-> NullMsgId, msg |-> DummyMsg, sendCount |-> 0, timerActive |-> FALSE, destNodeId |-> 0, sessionId |-> 0, securityFlags |-> 0, transport |-> "UDP"]

GetRetransEntry(rTable, mId) ==
    IF HasRetransEntry(rTable, mId) THEN CHOOSE r \in rTable : r.msgId = mId ELSE DummyRetransEntry

UpdateRetransTableNonFatal(rTable, mId) ==
    IF HasRetransEntry(rTable, mId) THEN
        IF GetRetransEntry(rTable, mId).sendCount >= MaxRetries THEN
            \* TODO: unspecified - Does eviction happen immediately after the max-th transport send, or after a timeout waiting for its ack? Modeling as immediate eviction upon reaching MaxRetries.
            {r \in rTable : r.msgId # mId}
        ELSE
            (rTable \ {GetRetransEntry(rTable, mId)}) \cup {[GetRetransEntry(rTable, mId) EXCEPT !.sendCount = @ + 1, !.timerActive = TRUE]}
    ELSE
        rTable

TimeoutRetransEntry(rTable, mId) ==
    CHOOSE r \in rTable : r.msgId = mId /\ r.timerActive = TRUE

UpdateRetransTableTimeout(rTable, mId) ==
    (rTable \ {TimeoutRetransEntry(rTable, mId)}) \cup {[TimeoutRetransEntry(rTable, mId) EXCEPT !.timerActive = FALSE]}

\* -----------------------------------------------------------------------------
\* Actions
\* -----------------------------------------------------------------------------

\* SOURCE: core_4.12.5.1 Piggyback acknowledgment processing and Message retransmission processing step 1, 2
PrepareOutgoingMessageAction ==
    /\ pendingInput = "PrepareOutgoingMessage"
    /\ state = "IDLE"
    /\ ackTable' = NewAckTable(inputMsg, ackTable)
    /\ retransTable' = NewRetransTable(inputMsg, ackTable, retransTable)
    /\ activeMsgId' = inputMsg.msgId
    /\ state' = "WAITING_TRANSPORT"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputMsg, timeoutMsgId, appNotifications>>

\* SOURCE: core_4.12.5.1 Message retransmission processing step 3a
TransportResultFatal ==
    /\ pendingInput = "TransportSendFatalError"
    /\ state = "WAITING_TRANSPORT"
    /\ appNotifications' = appNotifications \cup {activeMsgId}
    /\ retransTable' = {r \in retransTable : r.msgId # activeMsgId}
    /\ state' = "IDLE"
    /\ activeMsgId' = NullMsgId
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputMsg, timeoutMsgId, ackTable>>

\* SOURCE: core_4.12.5.1 Message retransmission processing step 3b
TransportResultNonFatalOrSuccess ==
    /\ pendingInput \in {"TransportSendRetriableError", "TransportSendSuccess"}
    /\ state = "WAITING_TRANSPORT"
    /\ retransTable' = UpdateRetransTableNonFatal(retransTable, activeMsgId)
    /\ state' = "IDLE"
    /\ activeMsgId' = NullMsgId
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputMsg, timeoutMsgId, ackTable, appNotifications>>

\* SOURCE: core_4.12.5.1 Message retransmission processing step 3b.ii and 3b.iii (retry initiation)
RetransmissionTimeoutAction ==
    /\ pendingInput = "RetransmissionTimeout"
    /\ state = "IDLE"
    /\ \E r \in retransTable :
        /\ r.msgId = timeoutMsgId
        /\ r.timerActive = TRUE
    /\ retransTable' = UpdateRetransTableTimeout(retransTable, timeoutMsgId)
    /\ activeMsgId' = timeoutMsgId
    /\ state' = "WAITING_TRANSPORT"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputMsg, timeoutMsgId, ackTable, appNotifications>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ PrepareOutgoingMessageAction
    \/ TransportResultFatal
    \/ TransportResultNonFatalOrSuccess
    \/ RetransmissionTimeoutAction

====