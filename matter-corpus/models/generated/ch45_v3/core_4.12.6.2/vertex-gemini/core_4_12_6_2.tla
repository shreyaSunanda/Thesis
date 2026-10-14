---- MODULE core_4_12_6_2 ----
EXTENDS Naturals

\* The set of possible exchange references in the system.
CONSTANTS ExchangeIds

\* The set of possible message counter values.
CONSTANTS MessageCounters

\* Sentinel value for when no event is waiting to be processed.
CONSTANTS NoInput

VARIABLES state
VARIABLES pendingInput

\* Input data variables to carry event parameters.
VARIABLES inputExchangeId
VARIABLES inputMessageCounter

\* The acknowledgement table itself.
\* A set of records with fields: exchangeId, msgCounter, standaloneAckSent
VARIABLES ackTable

\* Abstract environment variable capturing messages (standalone and piggybacked acks) sent by the receiver.
\* Records have fields: type, exchangeId, msgCounter
VARIABLES sentMessages

\* REQUIRED - The complete list of events this section can receive.
Inputs == {
    "ReceiveReliableMessage",
    "CloseExchange",
    "SwitchTrackedAck",
    "SendPiggybackMessage",
    "SendStandaloneAck"
}

\* --- Helper Definitions ---

NewAckRecord(ex, cnt) ==
    [exchangeId |-> ex,
     msgCounter |-> cnt,
     standaloneAckSent |-> FALSE]

StandaloneAckMessage(ex, cnt) ==
    [type |-> "StandaloneAck",
     exchangeId |-> ex,
     msgCounter |-> cnt]

PiggybackMessage(ex, cnt) ==
    [type |-> "PiggybackMessage",
     exchangeId |-> ex,
     msgCounter |-> cnt]

MarkAckSent(e) == 
    [e EXCEPT !.standaloneAckSent = TRUE]

\* --- Initialization ---

Init ==
    /\ state = "Running"
    /\ pendingInput = NoInput
    /\ \E ex \in ExchangeIds, cnt \in MessageCounters :
           /\ inputExchangeId = ex
           /\ inputMessageCounter = cnt
    /\ ackTable = {}
    /\ sentMessages = {}

\* --- Input Reception ---

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E ex \in ExchangeIds, cnt \in MessageCounters :
           /\ inputExchangeId' = ex
           /\ inputMessageCounter' = cnt
    /\ UNCHANGED <<state, ackTable, sentMessages>>

\* --- Actions ---

\* SOURCE: core_4.12.6.2 Acknowledgement Table
\* Triggered when a new reliable message arrives requiring an acknowledgement.
AddReliableMessageAckRecord ==
    /\ pendingInput = "ReceiveReliableMessage"
    /\ ackTable' = ackTable \cup {NewAckRecord(inputExchangeId, inputMessageCounter)}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputExchangeId, inputMessageCounter, sentMessages>>

\* SOURCE: core_4.12.6.2 clause 1 & core_4.10.5.3 Closing an Exchange
\* 1. The exchange associated with the entry is closed.
CloseExchangeProcessing ==
    /\ pendingInput = "CloseExchange"
    /\ LET targetEntries == {e \in ackTable : e.exchangeId = inputExchangeId}
           needsStandaloneAck == {e \in targetEntries : e.standaloneAckSent = FALSE}
           newSent == {StandaloneAckMessage(e.exchangeId, e.msgCounter) : e \in needsStandaloneAck}
       IN
           \* "Remove the acknowledgement table entry for the pending acknowledgement."
           /\ ackTable' = ackTable \ targetEntries
           \* "Immediately send a standalone acknowledgement for the pending acknowledgement."
           /\ sentMessages' = sentMessages \cup newSent
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputExchangeId, inputMessageCounter>>

\* SOURCE: core_4.12.6.2 clause 2
\* 2. The exchange associated with the entry has switched to track a pending acknowledgement for a new message counter value.
SwitchPendingAckCounter ==
    /\ pendingInput = "SwitchTrackedAck"
    /\ LET targetEntries == {e \in ackTable : e.exchangeId = inputExchangeId}
           newRecord == NewAckRecord(inputExchangeId, inputMessageCounter)
       IN
           \* Removes the old entry for this exchange as it switches to track a new one
           /\ ackTable' = (ackTable \ targetEntries) \cup {newRecord}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputExchangeId, inputMessageCounter, sentMessages>>

\* SOURCE: core_4.12.6.2 clause 3
\* 3. A message that is not a standalone acknowledgement is sent which serves as an acknowledgement for the entry.
SendPiggybackAck ==
    /\ pendingInput = "SendPiggybackMessage"
    /\ LET targetEntries == {e \in ackTable : e.exchangeId = inputExchangeId}
           newSent == {PiggybackMessage(e.exchangeId, e.msgCounter) : e \in targetEntries}
       IN
           \* Entry is removed because piggyback ack was sent
           /\ ackTable' = ackTable \ targetEntries
           /\ sentMessages' = sentMessages \cup newSent
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputExchangeId, inputMessageCounter>>

\* SOURCE: core_4.12.6.2 Acknowledgement Table
\* Updates the "StandaloneAckSent" boolean flag indicating whether a standalone acknowledgement has been sent.
SendStandaloneAck ==
    /\ pendingInput = "SendStandaloneAck"
    /\ LET targetEntries == {e \in ackTable : e.exchangeId = inputExchangeId}
           updatedEntries == {MarkAckSent(e) : e \in targetEntries}
           newSent == {StandaloneAckMessage(e.exchangeId, e.msgCounter) : e \in targetEntries}
       IN
           /\ ackTable' = (ackTable \ targetEntries) \cup updatedEntries
           /\ sentMessages' = sentMessages \cup newSent
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputExchangeId, inputMessageCounter>>

\* --- State Transition ---

Next ==
    \/ \E e \in Inputs : ReceiveInput(e)
    \/ AddReliableMessageAckRecord
    \/ CloseExchangeProcessing
    \/ SwitchPendingAckCounter
    \/ SendPiggybackAck
    \/ SendStandaloneAck

====