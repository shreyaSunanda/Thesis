---- MODULE core_4_12_2_1 ----
EXTENDS Naturals

\* Constant limits and thresholds defined in the spec
CONSTANTS MRP_MAX_TRANSMISSIONS
CONSTANTS MRP_BACKOFF_BASE
CONSTANTS MRP_BACKOFF_THRESHOLD
CONSTANTS MRP_BACKOFF_MARGIN
CONSTANTS SESSION_ACTIVE_INTERVAL
CONSTANTS SESSION_IDLE_INTERVAL
CONSTANTS FastPollingInterval

\* REQUIRED: pendingInput and the NoInput constant
CONSTANTS NoInput
VARIABLES pendingInput

\* Protocol state
VARIABLES
    state,
    sendAttempts,
    timerRunning,
    isFirstMessage,
    peerActiveMode,
    isICD,
    operationalDiscoveryInitiated

\* REQUIRED: the complete list of events this section can receive
Inputs == {
    "SendReliableMessage",
    "AckReceived",
    "RetransmissionTimerExpired",
    "OperationalDiscoveryComplete"
}

\* REQUIRED: Operational predicate
Operational == state \in {"IDLE", "WAITING_ACK", "DONE", "GIVEN_UP"}

\* Helper computation for the backoff base interval
\* TODO: unspecified - the spec states first messages use idle state and subsequent use active state,
\* but then immediately specifies a fixed mathematical rule based strictly on PeerActiveMode.
\* The model follows the explicit PeerActiveMode rule.
\* SOURCE: core_4.12.2.1
BaseInterval(activeMode) ==
    IF activeMode
    THEN MRP_BACKOFF_MARGIN * SESSION_ACTIVE_INTERVAL
    ELSE MRP_BACKOFF_MARGIN * SESSION_IDLE_INTERVAL

\* Helper computation for the exponential backoff power
\* Abstraction: avoids negative numbers by maxing with 0 directly, preventing the need
\* for the Integers module, since Naturals '-' operator is undefined for negative results.
Power(n) ==
    IF n > MRP_BACKOFF_THRESHOLD
    THEN n - MRP_BACKOFF_THRESHOLD
    ELSE 0

\* Helper computation for MrpBackoffTime
\* Abstraction: Jitter and floating point calculations are omitted to make the model
\* deterministic and checkable within finite state spaces.
\* SOURCE: core_4.12.2.1
MrpBackoffTime(n, activeMode) ==
    BaseInterval(activeMode) * (MRP_BACKOFF_BASE ^ Power(n))

\* Helper computation for the final timer duration, accounting for ICDs
\* SOURCE: core_4.12.2.1
FinalBackoffTime(n, activeMode, icd) ==
    IF icd
    THEN MrpBackoffTime(n, activeMode) + FastPollingInterval
    ELSE MrpBackoffTime(n, activeMode)

Init ==
    /\ pendingInput = NoInput
    /\ state = "IDLE"
    /\ sendAttempts = 0
    /\ timerRunning = FALSE
    /\ isFirstMessage = TRUE
    /\ peerActiveMode = FALSE
    /\ isICD = FALSE
    /\ operationalDiscoveryInitiated = FALSE

\* REQUIRED: receive an input event
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, sendAttempts, timerRunning, isFirstMessage, peerActiveMode, isICD, operationalDiscoveryInitiated>>

\* SOURCE: core_4.12.2.1 Retransmissions
SendReliableMessage ==
    /\ pendingInput = "SendReliableMessage"
    /\ state \in {"IDLE", "DONE", "GIVEN_UP"}
    /\ state' = "WAITING_ACK"
    /\ sendAttempts' = 0
    /\ timerRunning' = TRUE
    /\ operationalDiscoveryInitiated' = FALSE
    \* Establish the session characteristics for this transmission
    /\ \E firstMsg \in BOOLEAN, pActive \in BOOLEAN, icd \in BOOLEAN:
        /\ isFirstMessage' = firstMsg
        /\ peerActiveMode' = pActive
        /\ isICD' = icd
    /\ pendingInput' = NoInput

\* SOURCE: core_4.12.2.1 Retransmissions
RetransmissionTimerExpired ==
    /\ pendingInput = "RetransmissionTimerExpired"
    /\ state = "WAITING_ACK"
    /\ timerRunning = TRUE
    /\ IF sendAttempts < MRP_MAX_TRANSMISSIONS - 1
       THEN
           /\ sendAttempts' = sendAttempts + 1
           /\ timerRunning' = TRUE
           /\ state' = "WAITING_ACK"
           /\ IF sendAttempts = 0
              THEN operationalDiscoveryInitiated' = TRUE
              ELSE operationalDiscoveryInitiated' = operationalDiscoveryInitiated
       ELSE
           /\ sendAttempts' = sendAttempts
           /\ timerRunning' = FALSE
           /\ state' = "GIVEN_UP"
           /\ operationalDiscoveryInitiated' = operationalDiscoveryInitiated
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<isFirstMessage, peerActiveMode, isICD>>

\* SOURCE: core_4.12.2.1 Retransmissions
AckReceived ==
    /\ pendingInput = "AckReceived"
    /\ state = "WAITING_ACK"
    /\ timerRunning' = FALSE
    /\ state' = "DONE"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sendAttempts, isFirstMessage, peerActiveMode, isICD, operationalDiscoveryInitiated>>

\* SOURCE: core_4.12.2.1 Retransmissions
OperationalDiscoveryComplete ==
    /\ pendingInput = "OperationalDiscoveryComplete"
    /\ state = "WAITING_ACK"
    /\ operationalDiscoveryInitiated = TRUE
    \* The sender uses the latest MRP parameters from subsequent operational discovery
    /\ \E pActive \in BOOLEAN:
        peerActiveMode' = pActive
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, sendAttempts, timerRunning, isFirstMessage, isICD, operationalDiscoveryInitiated>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ SendReliableMessage
    \/ RetransmissionTimerExpired
    \/ AckReceived
    \/ OperationalDiscoveryComplete

====