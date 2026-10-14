---- MODULE core_4_12_6_1 ----
EXTENDS Naturals

\* Configurable maximum number of times a message is sent
CONSTANTS MRP_MAX_TRANSMISSIONS

\* Sentinel: nothing is waiting to be handled
CONSTANTS NoInput

\* Sentinel for a null reference (e.g., no exchange context or buffer)
CONSTANTS NullContext

\* Maximum value for message counter to keep state space finite
CONSTANTS MaxMessageCounter

VARIABLES state
VARIABLES pendingInput

\* Holds the payload for the current input event (simulating data on the wire/API)
VARIABLES inputMsg

\* Set of context records currently in the retransmission table
VARIABLES retransmissionTable

\* Set of message counters that have been notified to the application as failed
VARIABLES appNotifications

\* The complete list of events this section can receive.
Inputs == {"SendReliableMessage", "ReceiveAck", "RetransmissionTimeout"}

Operational == state = "OPERATIONAL"

Init ==
    /\ state = "OPERATIONAL"
    /\ pendingInput = NoInput
    /\ inputMsg = [exchange |-> NullContext, counter |-> 0, buffer |-> NullContext]
    /\ retransmissionTable = {}
    /\ appNotifications = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E exchange \in {NullContext, "Exch1"} :
         \E counter \in 0..MaxMessageCounter :
           \E buffer \in {NullContext, "Buf1"} :
             inputMsg' = [exchange |-> exchange, counter |-> counter, buffer |-> buffer]
    /\ UNCHANGED <<state, retransmissionTable, appNotifications>>

ExistingRecord(counter) ==
    {r \in retransmissionTable : r.messageCounter = counter}

NewRecord(exchange, counter, buffer) ==
    [exchangeContext |-> exchange,
     messageCounter  |-> counter,
     messageBuffer   |-> buffer,
     sendCount       |-> 1,
     timeoutCounter  |-> 0]

UpdatedRecord(rec) ==
    [exchangeContext |-> rec.exchangeContext,
     messageCounter  |-> rec.messageCounter,
     messageBuffer   |-> rec.messageBuffer,
     sendCount       |-> rec.sendCount + 1,
     timeoutCounter  |-> rec.timeoutCounter]

\* SOURCE: core_4.12.6.1 Retransmission Table
SendReliableMessage ==
    /\ pendingInput = "SendReliableMessage"
    /\ LET existingSet == ExistingRecord(inputMsg.counter) IN
       IF existingSet # {} THEN
           \E rec \in existingSet :
               IF rec.sendCount < MRP_MAX_TRANSMISSIONS THEN
                   /\ retransmissionTable' = (retransmissionTable \ {rec}) \cup {UpdatedRecord(rec)}
                   /\ appNotifications' = appNotifications
               ELSE
                   \* Max transmissions reached, notify the application
                   /\ appNotifications' = appNotifications \cup {rec.messageCounter}
                   \* TODO: unspecified - spec does not explicitly state if the record is removed upon failure notification, assuming removed here.
                   /\ retransmissionTable' = retransmissionTable \ {rec}
       ELSE
           /\ retransmissionTable' = retransmissionTable \cup {NewRecord(inputMsg.exchange, inputMsg.counter, inputMsg.buffer)}
           /\ appNotifications' = appNotifications
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputMsg>>

\* SOURCE: core_4.12.6.1 Retransmission Table
ReceiveAck ==
    /\ pendingInput = "ReceiveAck"
    \* Removes the acknowledged message from the table (acknowledgments no longer pending)
    /\ retransmissionTable' = {r \in retransmissionTable : r.messageCounter # inputMsg.counter}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputMsg, appNotifications>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ SendReliableMessage
    \/ ReceiveAck

====