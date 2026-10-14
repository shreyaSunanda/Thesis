---- MODULE core_4_19_4_6 ----
EXTENDS Naturals

\* Maximum sequence number value. Real value per spec: 255.
CONSTANTS MaxSeqNum

\* Sentinel: nothing is waiting to be handled
CONSTANTS NoInput

\* Sentinel: no active peer or sequence number provided in the event
CONSTANTS NoActor
CONSTANTS NoSeqNum

VARIABLES 
    pendingInput,
    inEventActor,     \* The peer performing the action / receiving the packet
    inEventSeq,       \* The sequence number on the received packet
    sessionState,
    txSeq,
    expectedRxSeq,
    appError

Inputs == {"CompleteHandshake", "SendPacket", "ReceivePacket"}

Peers == {"Client", "Server"}

Init ==
    /\ pendingInput = NoInput
    /\ inEventActor = NoActor
    /\ inEventSeq = NoSeqNum
    /\ sessionState = "CLOSED"
    /\ txSeq = [p \in Peers |-> NoSeqNum]
    /\ expectedRxSeq = [p \in Peers |-> NoSeqNum]
    /\ appError = FALSE

Operational == sessionState = "OPEN"

\* Helper to monotonically increment sequence number, wrapping to 0 when past MaxSeqNum
NextSeq(seq) == IF seq = MaxSeqNum THEN 0 ELSE seq + 1

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ inEventActor' \in Peers \cup {NoActor}
    /\ inEventSeq' \in 0..MaxSeqNum \cup {NoSeqNum}
    /\ UNCHANGED <<sessionState, txSeq, expectedRxSeq, appError>>

\* SOURCE: core_4.19.4.6
CompleteHandshake ==
    /\ pendingInput = "CompleteHandshake"
    /\ sessionState = "CLOSED"
    /\ sessionState' = "OPEN"
    /\ txSeq' = [p \in Peers |-> IF p = "Client" THEN 0 ELSE 1]
    /\ expectedRxSeq' = [p \in Peers |-> IF p = "Client" THEN 1 ELSE 0]
    /\ appError' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inEventActor, inEventSeq>>

\* SOURCE: core_4.19.4.6
SendPacket ==
    /\ pendingInput = "SendPacket"
    /\ inEventActor \in Peers
    /\ sessionState = "OPEN"
    /\ txSeq' = [txSeq EXCEPT ![inEventActor] = NextSeq(txSeq[inEventActor])]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inEventActor, inEventSeq, sessionState, expectedRxSeq, appError>>

\* SOURCE: core_4.19.4.6
ReceivePacket ==
    /\ pendingInput = "ReceivePacket"
    /\ inEventActor \in Peers
    /\ inEventSeq \in 0..MaxSeqNum
    /\ sessionState = "OPEN"
    /\ IF inEventSeq = expectedRxSeq[inEventActor]
       THEN /\ expectedRxSeq' = [expectedRxSeq EXCEPT ![inEventActor] = NextSeq(expectedRxSeq[inEventActor])]
            /\ UNCHANGED <<sessionState, appError>>
       ELSE /\ sessionState' = "CLOSED"
            /\ appError' = TRUE
            /\ UNCHANGED <<expectedRxSeq>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<txSeq, inEventActor, inEventSeq>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ CompleteHandshake
    \/ SendPacket
    \/ ReceivePacket

====