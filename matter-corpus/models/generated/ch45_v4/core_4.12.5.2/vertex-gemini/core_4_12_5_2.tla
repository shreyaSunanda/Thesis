---- MODULE core_4_12_5_2 ----
EXTENDS Naturals

\* Timeout for standalone acknowledgements
CONSTANTS MRP_STANDALONE_ACK_TIMEOUT

\* Set of available Exchange IDs to bound the state space
CONSTANTS ExchangeIds
CONSTANTS DummyExchangeId

\* Sentinel values for empty/null fields
CONSTANTS NullMsgCounter
CONSTANTS MaxMsgCounter

\* REQUIRED - Sentinel for no pending input
CONSTANTS NoInput

VARIABLES pendingInput
VARIABLES inMessage
VARIABLES inTimerExchangeId
VARIABLES retransmissionTable
VARIABLES acknowledgementTable
VARIABLES exchanges
VARIABLES ackTimers
VARIABLES sentAcks
VARIABLES deliveredMessages
VARIABLES droppedMessages

\* REQUIRED - The events this component can receive
Inputs == {"ReceiveMessage", "AckTimerTriggered"}

Operational == TRUE

Init ==
    /\ pendingInput = NoInput
    /\ inMessage = [
           rFlag |-> FALSE,
           aFlag |-> FALSE,
           cFlag |-> FALSE,
           groupSession |-> FALSE,
           ackMsgCounter |-> NullMsgCounter,
           msgCounter |-> NullMsgCounter,
           isDuplicate |-> FALSE,
           exchangeId |-> DummyExchangeId
       ]
    /\ inTimerExchangeId = DummyExchangeId
    /\ retransmissionTable = {}
    /\ acknowledgementTable = [e \in ExchangeIds |-> [hasPending |-> FALSE, msgCounter |-> NullMsgCounter, standaloneAckSent |-> FALSE]]
    /\ exchanges = [e \in ExchangeIds |-> [isEphemeral |-> FALSE, isOpen |-> TRUE]]
    /\ ackTimers = [e \in ExchangeIds |-> FALSE]
    /\ sentAcks = {}
    /\ deliveredMessages = {}
    /\ droppedMessages = {}

\* REQUIRED - Single action delivering an event
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<inMessage, inTimerExchangeId, retransmissionTable, acknowledgementTable, exchanges, ackTimers, sentAcks, deliveredMessages, droppedMessages>>

\* Environment action: Update the message payload available for ReceiveMessage
UpdateInputData ==
    /\ pendingInput = NoInput
    /\ \E rFlag, aFlag, cFlag, groupSession, isDuplicate \in BOOLEAN:
       \E ackMsgCounter, msgCounter \in 0..MaxMsgCounter:
       \E exchangeId \in ExchangeIds:
           inMessage' = [
               rFlag |-> rFlag,
               aFlag |-> aFlag,
               cFlag |-> cFlag,
               groupSession |-> groupSession,
               ackMsgCounter |-> ackMsgCounter,
               msgCounter |-> msgCounter,
               isDuplicate |-> isDuplicate,
               exchangeId |-> exchangeId
           ]
    /\ \E eid \in ExchangeIds: inTimerExchangeId' = eid
    /\ UNCHANGED <<pendingInput, retransmissionTable, acknowledgementTable, exchanges, ackTimers, sentAcks, deliveredMessages, droppedMessages>>

\* Environment action: Allow testing retransmission table matching
AddRetransmissionEntry ==
    /\ pendingInput = NoInput
    /\ \E c \in 0..MaxMsgCounter :
        retransmissionTable' = retransmissionTable \cup {[msgCounter |-> c, timerActive |-> TRUE]}
    /\ UNCHANGED <<pendingInput, inMessage, inTimerExchangeId, acknowledgementTable, exchanges, ackTimers, sentAcks, deliveredMessages, droppedMessages>>

\* Environment action: Allow testing ephemeral exchange paths
UpdateExchangeState ==
    /\ pendingInput = NoInput
    /\ \E eid \in ExchangeIds, isEph \in BOOLEAN, isOpen \in BOOLEAN :
        exchanges' = [exchanges EXCEPT ![eid] = [isEphemeral |-> isEph, isOpen |-> isOpen]]
    /\ UNCHANGED <<pendingInput, inMessage, inTimerExchangeId, retransmissionTable, acknowledgementTable, ackTimers, sentAcks, deliveredMessages, droppedMessages>>

\* -----------------------------------------------------------------------------
\* Helper definitions for the HandleReceiveMessage action

InvalidFlags(msg) ==
    \/ (msg.rFlag /\ msg.groupSession /\ ~msg.cFlag)
    \/ (msg.aFlag /\ msg.groupSession /\ ~msg.cFlag)

DropAsDuplicate(msg) == 
    msg.rFlag /\ msg.isDuplicate

EphemeralClose(msg, exchs) == 
    DropAsDuplicate(msg) /\ exchs[msg.exchangeId].isOpen /\ exchs[msg.exchangeId].isEphemeral

ImmediatePendingAck(msg, ackTbl) ==
    /\ msg.rFlag
    /\ ~msg.isDuplicate
    /\ ackTbl[msg.exchangeId].hasPending
    /\ ~ackTbl[msg.exchangeId].standaloneAckSent

NewRetransmissionTable(msg, rTbl) ==
    IF msg.aFlag /\ (\E e \in rTbl : e.msgCounter = msg.ackMsgCounter)
    THEN {e \in rTbl : e.msgCounter # msg.ackMsgCounter}
    ELSE rTbl

NewSentAcks(msg, sAcks, ackTbl) ==
    IF DropAsDuplicate(msg)
    THEN sAcks \cup {msg.msgCounter}
    ELSE IF ImmediatePendingAck(msg, ackTbl)
    THEN sAcks \cup {ackTbl[msg.exchangeId].msgCounter}
    ELSE sAcks

NewExchanges(msg, exchs) ==
    IF EphemeralClose(msg, exchs)
    THEN [exchs EXCEPT ![msg.exchangeId].isOpen = FALSE]
    ELSE exchs

NewAckTable(msg, ackTbl) ==
    IF msg.rFlag /\ ~msg.isDuplicate
    THEN [ackTbl EXCEPT ![msg.exchangeId] = [hasPending |-> TRUE, msgCounter |-> msg.msgCounter, standaloneAckSent |-> FALSE]]
    ELSE ackTbl

NewAckTimers(msg, aTms) ==
    IF msg.rFlag /\ ~msg.isDuplicate
    THEN [aTms EXCEPT ![msg.exchangeId] = TRUE]
    ELSE aTms

\* SOURCE: core_4.12.5.2 Reliable Message Processing of Incoming Messages
HandleReceiveMessage ==
    /\ pendingInput = "ReceiveMessage"
    /\ IF InvalidFlags(inMessage) THEN
           /\ droppedMessages' = droppedMessages \cup {inMessage}
           /\ UNCHANGED <<retransmissionTable, exchanges, sentAcks, acknowledgementTable, ackTimers, deliveredMessages>>
       ELSE
           \* TODO: unspecified - spec notes "If there is no match, it indicates that this is either a duplicate acknowledgment or the Exchange context does not exist" but assigns no action. Modeled as leaving table unchanged.
           /\ retransmissionTable' = NewRetransmissionTable(inMessage, retransmissionTable)
           /\ exchanges' = NewExchanges(inMessage, exchanges)
           /\ sentAcks' = NewSentAcks(inMessage, sentAcks, acknowledgementTable)
           /\ acknowledgementTable' = NewAckTable(inMessage, acknowledgementTable)
           /\ ackTimers' = NewAckTimers(inMessage, ackTimers)
           /\ deliveredMessages' = IF DropAsDuplicate(inMessage) THEN deliveredMessages ELSE deliveredMessages \cup {inMessage}
           /\ droppedMessages' = IF DropAsDuplicate(inMessage) THEN droppedMessages \cup {inMessage} ELSE droppedMessages
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inMessage, inTimerExchangeId>>

\* SOURCE: core_4.12.5.2 Standalone acknowledgement processing 1.b.ii.A
HandleAckTimerTriggered ==
    /\ pendingInput = "AckTimerTriggered"
    /\ IF ackTimers[inTimerExchangeId] THEN
           /\ ackTimers' = [ackTimers EXCEPT ![inTimerExchangeId] = FALSE]
           /\ sentAcks' = sentAcks \cup {acknowledgementTable[inTimerExchangeId].msgCounter}
           /\ acknowledgementTable' = [acknowledgementTable EXCEPT ![inTimerExchangeId].standaloneAckSent = TRUE]
       ELSE
           /\ UNCHANGED <<ackTimers, sentAcks, acknowledgementTable>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<retransmissionTable, exchanges, deliveredMessages, droppedMessages, inMessage, inTimerExchangeId>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ UpdateInputData
    \/ AddRetransmissionEntry
    \/ UpdateExchangeState
    \/ HandleReceiveMessage
    \/ HandleAckTimerTriggered

====