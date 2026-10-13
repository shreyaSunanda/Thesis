---- MODULE core_4_10_5_3 ----
EXTENDS Naturals

\* The set of possible acknowledgement identifiers
CONSTANTS AckIds

\* The set of possible retransmission identifiers
CONSTANTS RetransmissionIds

VARIABLES 
    exchangeState, 
    closePending, 
    pendingAcks, 
    retransmissions, 
    sentMessages

AckRecords == [id: AckIds, standaloneAckSent: {TRUE, FALSE}]

Init ==
    /\ exchangeState = "OPEN"
    /\ closePending = FALSE
    /\ pendingAcks \in SUBSET AckRecords
    /\ retransmissions \in SUBSET RetransmissionIds
    /\ sentMessages = {}

\* SOURCE: core_4.10.5.3
InitiateClose ==
    \* An Exchange MAY be closed by the application layer or a fatal connection error
    /\ exchangeState = "OPEN"
    /\ ~closePending
    \* 1. Any pending acknowledgements associated with the Exchange SHALL be flushed.
    \* If there is a pending acknowledgment in the acknowledgement table for the Exchange 
    \* and it has StandaloneAckSent set to false:
    \* 1.a. Immediately send a standalone acknowledgement for the pending acknowledgement.
    /\ sentMessages' = sentMessages \cup 
        { [type |-> "StandaloneAck", id |-> ack.id] : 
          ack \in {a \in pendingAcks : ~a.standaloneAckSent} }
    \* 1.b. Remove the acknowledgement table entry for the pending acknowledgement.
    /\ pendingAcks' = {}
    \* 2. Wait for all pending retransmissions associated with the Exchange to complete.
    /\ IF retransmissions = {}
       \* 2.a. If the retransmission list for the Exchange is empty, remove the Exchange.
       THEN /\ exchangeState' = "CLOSED"
            /\ closePending' = FALSE
       \* 2.b. Otherwise, leave the Exchange open and only close it once the retransmission list is empty.
       ELSE /\ exchangeState' = "OPEN"
            /\ closePending' = TRUE
    /\ UNCHANGED <<retransmissions>>

\* SOURCE: core_4.10.5.3
CompleteRetransmission ==
    \* Models the completion of pending retransmissions which the close process waits for
    /\ retransmissions # {}
    /\ \E r \in retransmissions :
        /\ retransmissions' = retransmissions \ {r}
        /\ IF retransmissions' = {} /\ closePending
           \* 2.b. ...only close it once the retransmission list is empty.
           THEN /\ exchangeState' = "CLOSED"
                /\ closePending' = FALSE
           ELSE /\ exchangeState' = exchangeState
                /\ closePending' = closePending
    /\ UNCHANGED <<pendingAcks, sentMessages>>

Next == InitiateClose \/ CompleteRetransmission

====