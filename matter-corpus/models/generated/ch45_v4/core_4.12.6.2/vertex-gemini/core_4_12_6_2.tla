---- MODULE core_4_12_6_2 ----
EXTENDS Naturals

\* The set of all possible exchange identifiers.
CONSTANTS ExchangeIds

\* The set of all possible message counter values.
CONSTANTS MessageCounters

\* REQUIRED - pendingInput and NoInput constant.
CONSTANTS NoInput
VARIABLES state, pendingInput

\* Variables to model the acknowledgment table and the data attached to incoming events.
VARIABLES ackTable
VARIABLES in_exchangeId
VARIABLES in_msgCounter
VARIABLES in_retransListEmpty

\* REQUIRED - The complete list of events this section can receive.
Inputs == {
    "ReceiveReliableMessage",
    "CloseExchangeApp",
    "CloseExchangeError",
    "SwitchToNewMessageCounter",
    "SendPiggybackAck",
    "SendStandaloneAck",
    "RetransmissionsCompleted"
}

\* Component is operational if there is at least one exchange that isn't fully closed.
Operational == \E ex \in ExchangeIds : state[ex] # "CLOSED"

Init ==
    /\ pendingInput = NoInput
    \* Exchanges start as OPEN so that reliable messages can be processed. 
    \* "CLOSED" models an exchange that has been removed.
    /\ state = [e \in ExchangeIds |-> "OPEN"]
    /\ ackTable = {}
    /\ \E ex \in ExchangeIds, mc \in MessageCounters, rle \in BOOLEAN :
        /\ in_exchangeId = ex
        /\ in_msgCounter = mc
        /\ in_retransListEmpty = rle

\* Helper to build a new context record as described in 4.12.6.2
NewContextRecord(ex, mc) == [exchangeId |-> ex, msgCounter |-> mc, standaloneAckSent |-> FALSE]

\* Helper to update the StandaloneAckSent field for an exchange
AckTableWithStandalone(ex) == { IF r.exchangeId = ex THEN [r EXCEPT !.standaloneAckSent = TRUE] ELSE r : r \in ackTable }

\* REQUIRED - Exactly one action delivering an event.
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E ex \in ExchangeIds, mc \in MessageCounters, rle \in BOOLEAN :
        /\ in_exchangeId' = ex
        /\ in_msgCounter' = mc
        /\ in_retransListEmpty' = rle
    /\ UNCHANGED <<state, ackTable>>

\* SOURCE: core_4.12.6.2 Acknowledgement Table
\* "The receiver maintains an acknowledgement table of context records containing information on
\* each reliable message for which an acknowledgment SHALL be sent."
HandleReceiveReliableMessage ==
    /\ pendingInput = "ReceiveReliableMessage"
    /\ state[in_exchangeId] = "OPEN"
    /\ ackTable' = ackTable \cup {NewContextRecord(in_exchangeId, in_msgCounter)}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, in_exchangeId, in_msgCounter, in_retransListEmpty>>

\* SOURCE: core_4.12.6.2 Acknowledgement Table
\* "A boolean, StandaloneAckSent, indicating whether a standalone acknowledgement has been sent
\* for this message counter."
HandleSendStandaloneAck ==
    /\ pendingInput = "SendStandaloneAck"
    /\ ackTable' = AckTableWithStandalone(in_exchangeId)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, in_exchangeId, in_msgCounter, in_retransListEmpty>>

\* SOURCE: core_4.12.6.2 clause 2
\* "2. The exchange associated with the entry has switched to track a pending acknowledgement for a
\* new message counter value."
HandleSwitchToNewMessageCounter ==
    /\ pendingInput = "SwitchToNewMessageCounter"
    /\ ackTable' = {r \in ackTable : r.exchangeId # in_exchangeId} \cup {NewContextRecord(in_exchangeId, in_msgCounter)}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, in_exchangeId, in_msgCounter, in_retransListEmpty>>

\* SOURCE: core_4.12.6.2 clause 3
\* "3. A message that is not a standalone acknowledgement is sent which serves as an acknowledgement for the entry."
HandleSendPiggybackAck ==
    /\ pendingInput = "SendPiggybackAck"
    /\ ackTable' = {r \in ackTable : r.exchangeId # in_exchangeId}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, in_exchangeId, in_msgCounter, in_retransListEmpty>>

\* SOURCE: core_4.10.5.3 Closing an Exchange
\* "1. Any pending acknowledgements associated with the Exchange SHALL be flushed."
\* "2. Wait for all pending retransmissions associated with the Exchange to complete.
\* a. If the retransmission list for the Exchange is empty, remove the Exchange."
\* b. Otherwise, leave the Exchange open and only close it once the retransmission list is empty."
HandleCloseExchange ==
    /\ pendingInput \in {"CloseExchangeApp", "CloseExchangeError"}
    /\ state[in_exchangeId] = "OPEN"
    \* Flush all entries for this exchange
    /\ ackTable' = {r \in ackTable : r.exchangeId # in_exchangeId}
    /\ state' = [state EXCEPT ![in_exchangeId] = IF in_retransListEmpty THEN "CLOSED" ELSE "CLOSING_WAIT_RETRANS"]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<in_exchangeId, in_msgCounter, in_retransListEmpty>>

\* SOURCE: core_4.10.5.3 Closing an Exchange
\* Handling step 2b once retransmissions finally complete.
HandleRetransmissionsCompleted ==
    /\ pendingInput = "RetransmissionsCompleted"
    /\ state[in_exchangeId] = "CLOSING_WAIT_RETRANS"
    /\ state' = [state EXCEPT ![in_exchangeId] = "CLOSED"]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<ackTable, in_exchangeId, in_msgCounter, in_retransListEmpty>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleReceiveReliableMessage
    \/ HandleSwitchToNewMessageCounter
    \/ HandleSendPiggybackAck
    \/ HandleSendStandaloneAck
    \/ HandleCloseExchange
    \/ HandleRetransmissionsCompleted

====