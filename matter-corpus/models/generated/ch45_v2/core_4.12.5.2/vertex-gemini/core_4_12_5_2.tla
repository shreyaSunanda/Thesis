---- MODULE core_4_12_5_2 ----
EXTENDS Naturals

\* Set of all valid exchange identifiers.
CONSTANTS ExchangeIds

\* Sentinel value representing an empty slot in the acknowledgement table.
CONSTANTS NullEntry

\* pendingInput and the NoInput/Inputs constants are REQUIRED - see rule 4a.
CONSTANTS NoInput, Inputs

VARIABLES 
    pendingInput,
    retransmissionTable, \* Set of msgCounters for which an Acknowledgment is expected.
    ackTable,            \* Mapping from ExchangeIds to AckEntry \cup {NullEntry}
    exchanges,           \* Mapping from ExchangeIds to [isActive: BOOLEAN, isEphemeral: BOOLEAN]
    messagesSent,        \* Set of messages generated and sent by this layer (e.g., StandaloneAcks)
    messagesDelivered    \* Set of messages that successfully passed processing and are delivered to the next layer

\* Helper definitions for structuring complex updates and state checks
StandaloneAck(exId, dest) ==
    [type |-> "StandaloneAck", exchangeId |-> exId, dest |-> dest]

PendingStandaloneAck(exId, ackMsgCounter) ==
    [type |-> "StandaloneAck", exchangeId |-> exId, ackMsgCounter |-> ackMsgCounter]

NewAckEntry(msgCounter) ==
    [msgCounter |-> msgCounter, StandaloneAckSent |-> FALSE, timerActive |-> TRUE]

InvalidFlags(msg) ==
    msg.isGroupSession /\ ~msg.C_flag /\ (msg.R_flag \/ msg.A_flag)

MatchRetransmission(msg, rTable) ==
    msg.A_flag /\ msg.ackMsgCounter \in rTable

DropRetransmission(msg, rTable) ==
    rTable \ {msg.ackMsgCounter}

CloseEphemeral(exId, exchMap) ==
    IF exchMap[exId].isEphemeral
    THEN [exchMap EXCEPT ![exId].isActive = FALSE]
    ELSE exchMap

ReplaceAckEntry(exId, msgCounter, aTable) ==
    [aTable EXCEPT ![exId] = NewAckEntry(msgCounter)]

TriggeredAckEntry(exId, aTable) ==
    [aTable EXCEPT ![exId].StandaloneAckSent = TRUE,
                   ![exId].timerActive = FALSE]

IsTimerActive(entry) ==
    IF entry = NullEntry THEN FALSE ELSE entry.timerActive

Init == 
    /\ pendingInput = NoInput
    /\ retransmissionTable = {}
    /\ ackTable = [e \in ExchangeIds |-> NullEntry]
    /\ exchanges = [e \in ExchangeIds |-> [isActive |-> TRUE, isEphemeral |-> FALSE]]
    /\ messagesSent = {}
    /\ messagesDelivered = {}

\* SOURCE: core_4.12.5.2 Event Delivery
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<retransmissionTable, ackTable, exchanges, messagesSent, messagesDelivered>>

\* SOURCE: core_4.12.5.2 Reliable Message Processing of Incoming Messages
ProcessReceiveMessage ==
    /\ pendingInput /= NoInput
    /\ pendingInput.type = "ReceiveMessage"
    /\ pendingInput.msg.exchangeId \in ExchangeIds
    /\ LET msg == pendingInput.msg
           exId == msg.exchangeId
           isInvalid == InvalidFlags(msg)
       IN
           IF isInvalid THEN
               \* SOURCE: core_4.12.5.2 Step 1.a & 1.b - drop the message
               /\ pendingInput' = NoInput
               /\ UNCHANGED <<retransmissionTable, ackTable, exchanges, messagesSent, messagesDelivered>>
           ELSE
               \* Proceed to 4.10.5.1 (Exchange matches implicit via msg.exchangeId)
               \* Proceed to 4.12.5.2.1 (Received acknowledgement processing)
               LET matchFound == MatchRetransmission(msg, retransmissionTable)
                   newRetransmissionTable == IF matchFound THEN DropRetransmission(msg, retransmissionTable) ELSE retransmissionTable
               IN
               \* Proceed to 4.12.5.2.2 (Standalone acknowledgement processing)
               IF msg.R_flag THEN
                   IF msg.isDuplicate THEN
                       \* 4.12.5.2.2 Step 1.a
                       /\ messagesSent' = messagesSent \cup {StandaloneAck(exId, "msg_source")}
                       /\ exchanges' = CloseEphemeral(exId, exchanges)
                       /\ retransmissionTable' = newRetransmissionTable
                       /\ pendingInput' = NoInput
                       /\ UNCHANGED <<ackTable, messagesDelivered>>
                   ELSE
                       \* 4.12.5.2.2 Step 1.b
                       LET currentAck == ackTable[exId]
                           pendingExists == currentAck /= NullEntry
                           shouldSendImmediate == IF pendingExists THEN ~currentAck.StandaloneAckSent ELSE FALSE
                           newMsgSent == IF shouldSendImmediate
                                         THEN messagesSent \cup {PendingStandaloneAck(exId, currentAck.msgCounter)}
                                         ELSE messagesSent
                       IN
                       /\ messagesSent' = newMsgSent
                       /\ ackTable' = ReplaceAckEntry(exId, msg.msgCounter, ackTable)
                       /\ retransmissionTable' = newRetransmissionTable
                       /\ messagesDelivered' = messagesDelivered \cup {msg}
                       /\ pendingInput' = NoInput
                       /\ UNCHANGED <<exchanges>>
               ELSE
                   \* 4.12.5.2.2 Step 2: Message delivered to next processing step
                   /\ retransmissionTable' = newRetransmissionTable
                   /\ messagesDelivered' = messagesDelivered \cup {msg}
                   /\ pendingInput' = NoInput
                   /\ UNCHANGED <<ackTable, exchanges, messagesSent>>

\* SOURCE: core_4.12.5.2 Standalone acknowledgement processing step 1.b.ii.A
TriggerAckTimer ==
    /\ pendingInput /= NoInput
    /\ pendingInput.type = "AckTimerTriggered"
    /\ pendingInput.exchangeId \in ExchangeIds
    /\ LET exId == pendingInput.exchangeId
           entry == ackTable[exId]
       IN
           /\ IsTimerActive(entry)
           /\ messagesSent' = messagesSent \cup {PendingStandaloneAck(exId, entry.msgCounter)}
           /\ ackTable' = TriggeredAckEntry(exId, ackTable)
           /\ pendingInput' = NoInput
           /\ UNCHANGED <<retransmissionTable, exchanges, messagesDelivered>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ProcessReceiveMessage
    \/ TriggerAckTimer

====