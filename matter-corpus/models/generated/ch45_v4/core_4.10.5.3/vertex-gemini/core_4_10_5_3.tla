---- MODULE core_4_10_5_3 ----
EXTENDS Naturals

\* Sentinel for no pending event
CONSTANTS NoInput

\* State space limit for the standalone acknowledgements sent counter
CONSTANTS MaxAcks

VARIABLES 
    pendingInput,
    exchangeState,          \* "Open", "ClosePending", "Removed"
    ackTableHasEntry,       \* BOOLEAN: is there a pending acknowledgement?
    standaloneAckSentFlag,  \* BOOLEAN: StandaloneAckSent field in the ack table entry
    retransmissionsPending, \* BOOLEAN: is the retransmission list non-empty?
    standaloneAcksSent      \* INTEGER: count of standalone acks sent during closure

Inputs == {
    "ApplicationClose",
    "FatalConnectionError",
    "RetransmissionsComplete"
}

\* The exchange is operational before it is fully removed from memory
Operational == exchangeState \in {"Open", "ClosePending"}

Init ==
    /\ pendingInput = NoInput
    /\ exchangeState = "Open"
    \* Non-deterministically cover all possible starting conditions for the close sequence
    /\ ackTableHasEntry \in {TRUE, FALSE}
    /\ standaloneAckSentFlag \in {TRUE, FALSE}
    /\ retransmissionsPending \in {TRUE, FALSE}
    /\ standaloneAcksSent = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<exchangeState, ackTableHasEntry, standaloneAckSentFlag, 
                   retransmissionsPending, standaloneAcksSent>>

\* SOURCE: core_4.10.5.3 (1.a, 1.b, 2.a, 2.b)
InitiateClose ==
    /\ pendingInput \in {"ApplicationClose", "FatalConnectionError"}
    /\ exchangeState = "Open"
    /\ pendingInput' = NoInput
    \* Step 1: Any pending acknowledgements SHALL be flushed.
    \* If there is an entry and StandaloneAckSent is false:
    \* a. Immediately send a standalone acknowledgement.
    /\ standaloneAcksSent' = 
        IF ackTableHasEntry /\ ~standaloneAckSentFlag /\ standaloneAcksSent < MaxAcks
        THEN standaloneAcksSent + 1
        ELSE standaloneAcksSent
    \* b. Remove the acknowledgement table entry.
    /\ ackTableHasEntry' = FALSE
    /\ standaloneAckSentFlag' = FALSE
    \* Step 2: Wait for all pending retransmissions.
    \* a. If empty, remove the Exchange. b. Otherwise leave open and close once empty.
    /\ exchangeState' = 
        IF ~retransmissionsPending
        THEN "Removed"
        ELSE "ClosePending"
    /\ UNCHANGED retransmissionsPending

\* SOURCE: core_4.10.5.3 (2.b)
CompleteRetransmissions ==
    /\ pendingInput = "RetransmissionsComplete"
    /\ retransmissionsPending = TRUE
    /\ pendingInput' = NoInput
    /\ retransmissionsPending' = FALSE
    /\ exchangeState' = 
        IF exchangeState = "ClosePending"
        THEN "Removed"
        ELSE exchangeState
    /\ UNCHANGED <<ackTableHasEntry, standaloneAckSentFlag, standaloneAcksSent>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ InitiateClose
    \/ CompleteRetransmissions

====