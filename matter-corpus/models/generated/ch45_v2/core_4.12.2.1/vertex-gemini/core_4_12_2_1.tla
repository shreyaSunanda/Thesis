---- MODULE core_4_12_2_1 ----
EXTENDS Naturals

\* The set of unique exchange identifiers in the system.
CONSTANTS ExchangeIds

\* Maximum number of transmissions (including the initial one).
\* Spec text: sender SHALL retry up to a configured maximum number of times (MRP_MAX_TRANSMISSIONS - 1)
CONSTANTS MRP_MAX_TRANSMISSIONS

\* Base factor for exponential backoff.
CONSTANTS MRP_BACKOFF_BASE

\* Number of linear backoff steps before exponential backoff begins.
CONSTANTS MRP_BACKOFF_THRESHOLD

\* Margin applied to the base interval (represented as an integer multiplier here).
CONSTANTS MRP_BACKOFF_MARGIN

\* Default idle and active polling intervals for session contexts.
CONSTANTS SESSION_IDLE_INTERVAL
CONSTANTS SESSION_ACTIVE_INTERVAL

\* Fast polling interval added for Intermittently Connected Devices.
CONSTANTS FAST_POLLING_INTERVAL

\* Mandatory input shape constants for gap detection.
CONSTANTS NoInput, Inputs
VARIABLES state, pendingInput

\* Helper: Returns the maximum of two values.
Max(a, b) == IF a > b THEN a ELSE b

\* Helper: Calculates the base interval 'i' for an exchange message.
CalculateI(isFirst, peerActive) ==
    LET baseI == IF isFirst THEN SESSION_IDLE_INTERVAL
                 ELSE (IF peerActive THEN SESSION_ACTIVE_INTERVAL ELSE SESSION_IDLE_INTERVAL)
    IN baseI * MRP_BACKOFF_MARGIN

\* TODO: unspecified - random jitter (1.0 + random(0,1) * MRP_BACKOFF_JITTER) is abstracted away as TLA+ does not support floating point or continuous randomness.
\* Helper: Calculates the current mrpBackoffTime for a specific transmission attempt.
CalculateBackoff(i, n, senderIsICD) ==
    LET exp == Max(0, n - MRP_BACKOFF_THRESHOLD)
        baseFactor == MRP_BACKOFF_BASE ^ exp
        mrpBackoffTime == i * baseFactor
    IN IF senderIsICD THEN mrpBackoffTime + FAST_POLLING_INTERVAL
                      ELSE mrpBackoffTime

\* Helper: Constructs a new exchange state record when initiating a transmission.
NewExchangeState(isFirst, peerActive, isICD, backoff) ==
    [status               |-> "WAITING_ACK",
     retries              |-> 0,
     isFirstMessage       |-> isFirst,
     peerActiveMode       |-> peerActive,
     senderIsICD          |-> isICD,
     timerActive          |-> TRUE,
     timerValue           |-> backoff,
     opDiscoveryTriggered |-> FALSE]

\* Helper: Constructs an updated exchange state for a retry.
RetryExchangeState(exState, nextN, backoff, triggerDiscovery) ==
    [exState EXCEPT !.retries = nextN,
                    !.timerActive = TRUE,
                    !.timerValue = backoff,
                    !.opDiscoveryTriggered = triggerDiscovery]

\* Helper: Constructs a failed exchange state.
FailExchangeState(exState) ==
    [exState EXCEPT !.status = "FAILED",
                    !.timerActive = FALSE]

Init == 
    /\ pendingInput = NoInput
    /\ state = [ex \in ExchangeIds |-> 
                   [status               |-> "IDLE",
                    retries              |-> 0,
                    isFirstMessage       |-> FALSE,
                    peerActiveMode       |-> FALSE,
                    senderIsICD          |-> FALSE,
                    timerActive          |-> FALSE,
                    timerValue           |-> 0,
                    opDiscoveryTriggered |-> FALSE]]

\* SOURCE: core_4.12.2.1 Mandatory Event Ingestion
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.12.2.1 "At each sender, a retransmission timer is started each time a reliable message is transmitted... For the first message of a new exchange, the base interval, i, SHALL be set according to the idle state of the peer node... For all subsequent messages of the exchange, the base interval, i, SHOULD be set according to the active state"
HandleTransmitReliableMessage ==
    /\ pendingInput = "TransmitReliableMessage"
    /\ \E ex \in ExchangeIds :
        /\ state[ex].status \in {"IDLE", "CLOSED", "FAILED"}
        /\ \E isFirst \in BOOLEAN, peerActive \in BOOLEAN, isICD \in BOOLEAN :
            LET i == CalculateI(isFirst, peerActive)
                backoff == CalculateBackoff(i, 0, isICD)
            IN state' = [state EXCEPT ![ex] = NewExchangeState(isFirst, peerActive, isICD, backoff)]
    /\ pendingInput' = NoInput

\* SOURCE: core_4.12.2.1 "If a positive acknowledgment is received before the retransmission timer expires, the retransmission timer is stopped."
HandleReceiveAck ==
    /\ pendingInput = "ReceiveAck"
    /\ \E ex \in ExchangeIds :
        /\ state[ex].status = "WAITING_ACK"
        /\ state' = [state EXCEPT ![ex].status = "CLOSED",
                                  ![ex].timerActive = FALSE]
    /\ pendingInput' = NoInput

\* SOURCE: core_4.12.2.1 "Otherwise, if the retransmission timer expires, the message is retransmitted and the timer started again... The sender SHALL retry up to a configured maximum number of times... The sender SHOULD initiate Section 4.3.2, “Operational Discovery” in parallel with the first retry..."
HandleRetransmissionTimerExpire ==
    /\ pendingInput = "RetransmissionTimerExpire"
    /\ \E ex \in ExchangeIds :
        /\ state[ex].status = "WAITING_ACK"
        /\ state[ex].timerActive = TRUE
        /\ LET nextN == state[ex].retries + 1 IN
           IF state[ex].retries < MRP_MAX_TRANSMISSIONS - 1 THEN
               LET i == CalculateI(state[ex].isFirstMessage, state[ex].peerActiveMode)
                   backoff == CalculateBackoff(i, nextN, state[ex].senderIsICD)
                   triggerDiscovery == (nextN = 1) \/ state[ex].opDiscoveryTriggered
               IN state' = [state EXCEPT ![ex] = RetryExchangeState(state[ex], nextN, backoff, triggerDiscovery)]
           ELSE
               state' = [state EXCEPT ![ex] = FailExchangeState(state[ex])]
    /\ pendingInput' = NoInput

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleTransmitReliableMessage
    \/ HandleReceiveAck
    \/ HandleRetransmissionTimerExpire

====