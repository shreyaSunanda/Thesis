---- MODULE core_4_12_6_2 ----
EXTENDS Naturals

\* The set of all possible Exchange Context identifiers
CONSTANTS Exchanges
\* The set of all possible Message Counter values
CONSTANTS MessageCounters

\* A set of context records containing information on each reliable message
\* for which an acknowledgment SHALL be sent.
\* Each record contains: exchange, msgCounter, standaloneAckSent.
VARIABLES ackTable

Init == 
    ackTable = {}

\* SOURCE: core_4.12.6.2 Acknowledgement Table
\* The receiver maintains an acknowledgement table of context records containing information on
\* each reliable message for which an acknowledgment SHALL be sent.
\* A boolean, StandaloneAckSent ... Initially false.
AddReliableMessage(e, c) ==
    /\ e \in Exchanges
    /\ c \in MessageCounters
    \* TODO: unspecified - behavior if an entry for this exchange and message counter already exists
    /\ ackTable' = ackTable \cup {[exchange |-> e, msgCounter |-> c, standaloneAckSent |-> FALSE]}

\* SOURCE: core_4.12.6.2 Acknowledgement Table
\* A boolean, StandaloneAckSent, indicating whether a standalone acknowledgement has been sent
\* for this message counter.
SendStandaloneAck(e, c) ==
    /\ \E r \in ackTable : r.exchange = e /\ r.msgCounter = c /\ r.standaloneAckSent = FALSE
    /\ ackTable' = {r \in ackTable : ~(r.exchange = e /\ r.msgCounter = c)}
                   \cup {[exchange |-> e, msgCounter |-> c, standaloneAckSent |-> TRUE]}

\* SOURCE: core_4.12.6.2 1
\* An entry SHALL remain in the table until one of the following things happens:
\* 1. The exchange associated with the entry is closed.
RemoveOnExchangeClosed(e) ==
    /\ \E r \in ackTable : r.exchange = e
    /\ ackTable' = {r \in ackTable : r.exchange # e}

\* SOURCE: core_4.12.6.2 2
\* An entry SHALL remain in the table until one of the following things happens:
\* 2. The exchange associated with the entry has switched to track a pending acknowledgement
\* for a new message counter value.
SwitchToNewMessageCounter(e, oldC, newC) ==
    /\ e \in Exchanges
    /\ oldC \in MessageCounters
    /\ newC \in MessageCounters
    /\ oldC # newC
    /\ \E r \in ackTable : r.exchange = e /\ r.msgCounter = oldC
    /\ ackTable' = {r \in ackTable : ~(r.exchange = e /\ r.msgCounter = oldC)}
                   \cup {[exchange |-> e, msgCounter |-> newC, standaloneAckSent |-> FALSE]}

\* SOURCE: core_4.12.6.2 3
\* An entry SHALL remain in the table until one of the following things happens:
\* 3. A message that is not a standalone acknowledgement is sent which serves as an
\* acknowledgement for the entry.
RemoveOnPiggybackAck(e, c) ==
    /\ \E r \in ackTable : r.exchange = e /\ r.msgCounter = c
    /\ ackTable' = {r \in ackTable : ~(r.exchange = e /\ r.msgCounter = c)}

Next == 
    \/ \E e \in Exchanges, c \in MessageCounters : AddReliableMessage(e, c)
    \/ \E e \in Exchanges, c \in MessageCounters : SendStandaloneAck(e, c)
    \/ \E e \in Exchanges : RemoveOnExchangeClosed(e)
    \/ \E e \in Exchanges, oldC \in MessageCounters, newC \in MessageCounters : SwitchToNewMessageCounter(e, oldC, newC)
    \/ \E e \in Exchanges, c \in MessageCounters : RemoveOnPiggybackAck(e, c)

====