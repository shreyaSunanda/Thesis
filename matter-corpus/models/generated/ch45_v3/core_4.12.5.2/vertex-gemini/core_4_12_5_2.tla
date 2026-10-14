---- MODULE core_4_12_5_2 ----
EXTENDS Naturals

\* Sentinel for when no event is waiting
CONSTANTS NoInput

\* Set of active Exchange IDs. Real value per spec: up to 2^16.
CONSTANTS ExchangeIds

\* Message counter space limit. Real value per spec: 2^32.
CONSTANTS MaxMsgCounter

VARIABLES pendingInput

\* Variables representing data carried by the "ReceiveMessage" event
VARIABLES inMsg_rFlag
VARIABLES inMsg_aFlag
VARIABLES inMsg_cFlag
VARIABLES inMsg_groupSession
VARIABLES inMsg_ackMsgCounter
VARIABLES inMsg_msgCounter
VARIABLES inMsg_isDuplicate
VARIABLES inMsg_exchangeId

\* Variables representing data carried by the "AckTimerTriggered" event
VARIABLES inEvent_exchangeId

\* Protocol state variables
VARIABLES retransmissionTable
VARIABLES ephemeralExchanges
VARIABLES closedExchanges
VARIABLES ackTable
VARIABLES ackTimerRunning
VARIABLES sentMessages
VARIABLES deliveredToNextLayer

Inputs == {"ReceiveMessage", "AckTimerTriggered"}

Init ==
    /\ pendingInput = NoInput
    /\ inMsg_rFlag \in {TRUE, FALSE}
    /\ inMsg_aFlag \in {TRUE, FALSE}
    /\ inMsg_cFlag \in {TRUE, FALSE}
    /\ inMsg_groupSession \in {TRUE, FALSE}
    /\ inMsg_ackMsgCounter \in 0..MaxMsgCounter
    /\ inMsg_msgCounter \in 0..MaxMsgCounter
    /\ inMsg_isDuplicate \in {TRUE, FALSE}
    /\ inMsg_exchangeId \in ExchangeIds
    /\ inEvent_exchangeId \in ExchangeIds
    /\ retransmissionTable \in SUBSET (0..MaxMsgCounter)
    /\ ephemeralExchanges \in SUBSET ExchangeIds
    /\ closedExchanges = {}
    /\ ackTable = [e \in ExchangeIds |-> [hasEntry |-> FALSE, msgCounter |-> 0, standaloneAckSent |-> FALSE]]
    /\ ackTimerRunning = [e \in ExchangeIds |-> FALSE]
    /\ sentMessages = {}
    /\ deliveredToNextLayer = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<inMsg_rFlag, inMsg_aFlag, inMsg_cFlag, inMsg_groupSession, inMsg_ackMsgCounter, inMsg_msgCounter, inMsg_isDuplicate, inMsg_exchangeId, inEvent_exchangeId, retransmissionTable, ephemeralExchanges, closedExchanges, ackTable, ackTimerRunning, sentMessages, deliveredToNextLayer>>

StandaloneAckMessage(exch, counter) ==
    [type |-> "StandaloneAck", exch |-> exch, counter |-> counter]

NewAckTableEntry(counter) ==
    [hasEntry |-> TRUE, msgCounter |-> counter, standaloneAckSent |-> FALSE]

\* SOURCE: core_4.12.5.2 Reliable Message Processing of Incoming Messages
ReceiveMessageAction ==
    /\ pendingInput = "ReceiveMessage"
    /\ LET dropFromFlags ==
               \/ (inMsg_rFlag /\ inMsg_groupSession /\ ~inMsg_cFlag)
               \/ (inMsg_aFlag /\ inMsg_groupSession /\ ~inMsg_cFlag)
       IN
       IF dropFromFlags THEN
           /\ pendingInput' = NoInput
           /\ UNCHANGED <<retransmissionTable, ephemeralExchanges, closedExchanges, ackTable, ackTimerRunning, sentMessages, deliveredToNextLayer, inMsg_rFlag, inMsg_aFlag, inMsg_cFlag, inMsg_groupSession, inMsg_ackMsgCounter, inMsg_msgCounter, inMsg_isDuplicate, inMsg_exchangeId, inEvent_exchangeId>>
       ELSE
           LET
               \* Received acknowledgement processing (Section 4.12.5.2.1)
               matchRetransmission == inMsg_aFlag /\ (inMsg_ackMsgCounter \in retransmissionTable)
               newRetransmissionTable == IF matchRetransmission THEN retransmissionTable \ {inMsg_ackMsgCounter} ELSE retransmissionTable
               
               \* Standalone acknowledgement processing (Section 4.12.5.2.2)
               exch == inMsg_exchangeId
               isR == inMsg_rFlag
               isDup == inMsg_isDuplicate
               dropFromDuplicate == isR /\ isDup
               shouldDeliver == ~dropFromDuplicate
               
               oldAckEntry == ackTable[exch]
               hasOldPending == oldAckEntry.hasEntry
               oldNotSent == hasOldPending /\ ~oldAckEntry.standaloneAckSent
               
               sendImmediateForDuplicate == dropFromDuplicate
               sendImmediateForOld == isR /\ ~isDup /\ oldNotSent
               
               sentMsgs1 == IF sendImmediateForDuplicate THEN sentMessages \cup {StandaloneAckMessage(exch, inMsg_msgCounter)} ELSE sentMessages
               sentMsgs2 == IF sendImmediateForOld THEN sentMsgs1 \cup {StandaloneAckMessage(exch, oldAckEntry.msgCounter)} ELSE sentMsgs1
               
               newClosedExchanges == IF dropFromDuplicate /\ (exch \in ephemeralExchanges) THEN closedExchanges \cup {exch} ELSE closedExchanges
               
               newAckTable == IF isR /\ ~isDup THEN [ackTable EXCEPT ![exch] = NewAckTableEntry(inMsg_msgCounter)] ELSE ackTable
               newAckTimerRunning == IF isR /\ ~isDup THEN [ackTimerRunning EXCEPT ![exch] = TRUE] ELSE ackTimerRunning
               
               \* Message Reception continuation (Section 4.7.2)
               newDelivered == IF shouldDeliver THEN deliveredToNextLayer \cup {inMsg_msgCounter} ELSE deliveredToNextLayer
           IN
               /\ retransmissionTable' = newRetransmissionTable
               /\ closedExchanges' = newClosedExchanges
               /\ ackTable' = newAckTable
               /\ ackTimerRunning' = newAckTimerRunning
               /\ sentMessages' = sentMsgs2
               /\ deliveredToNextLayer' = newDelivered
               /\ pendingInput' = NoInput
               /\ UNCHANGED <<ephemeralExchanges, inMsg_rFlag, inMsg_aFlag, inMsg_cFlag, inMsg_groupSession, inMsg_ackMsgCounter, inMsg_msgCounter, inMsg_isDuplicate, inMsg_exchangeId, inEvent_exchangeId>>

\* SOURCE: core_4.12.5.2 Standalone acknowledgement processing
AckTimerTriggeredAction ==
    /\ pendingInput = "AckTimerTriggered"
    /\ ackTimerRunning[inEvent_exchangeId] = TRUE
    /\ ackTable[inEvent_exchangeId].hasEntry = TRUE
    /\ sentMessages' = sentMessages \cup {StandaloneAckMessage(inEvent_exchangeId, ackTable[inEvent_exchangeId].msgCounter)}
    /\ ackTable' = [ackTable EXCEPT ![inEvent_exchangeId].standaloneAckSent = TRUE]
    /\ ackTimerRunning' = [ackTimerRunning EXCEPT ![inEvent_exchangeId] = FALSE]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<retransmissionTable, ephemeralExchanges, closedExchanges, deliveredToNextLayer, inMsg_rFlag, inMsg_aFlag, inMsg_cFlag, inMsg_groupSession, inMsg_ackMsgCounter, inMsg_msgCounter, inMsg_isDuplicate, inMsg_exchangeId, inEvent_exchangeId>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ReceiveMessageAction
    \/ AckTimerTriggeredAction

====