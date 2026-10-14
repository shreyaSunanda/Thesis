---- MODULE core_4_7_2 ----
EXTENDS Naturals

\* Sentinel for no pending input
CONSTANTS NoInput

\* Abstract timestamps
CONSTANTS NoTimestamp, UpdatedTimestamp

\* Abstract keys for group message processing
CONSTANTS Key1, Key2

VARIABLES 
    state,
    pendingInput,
    currentMessage,
    errorState,
    sessionTimestamp,
    activeTimestamp,
    deliveredToExchange,
    keysRemaining

Inputs == {"ReceiveMessage"}

KeySet == {Key1, Key2}

\* Abstract representation of the incoming message fields evaluated by 4.7.2
MessageShape == [
    version: {0, 1},
    sessionType: {"Unsecured", "SecureUnicast", "Group"},
    isUnicastSession: BOOLEAN,
    dsizIndicatesGroup: BOOLEAN,
    dsizZero: BOOLEAN,
    sFlagZero: BOOLEAN,
    keysFound: BOOLEAN,
    keysToProcess: SUBSET KeySet,
    pFlagSet: BOOLEAN,
    transport: {"UDP", "TCP"}
]

DefaultMessage == [
    version |-> 0,
    sessionType |-> "Unsecured",
    isUnicastSession |-> TRUE,
    dsizIndicatesGroup |-> FALSE,
    dsizZero |-> FALSE,
    sFlagZero |-> FALSE,
    keysFound |-> TRUE,
    keysToProcess |-> {},
    pFlagSet |-> FALSE,
    transport |-> "TCP"
]

Operational == state # "IDLE"

Init ==
    /\ state = "IDLE"
    /\ pendingInput = NoInput
    /\ currentMessage = DefaultMessage
    /\ errorState = "none"
    /\ sessionTimestamp = NoTimestamp
    /\ activeTimestamp = NoTimestamp
    /\ deliveredToExchange = FALSE
    /\ keysRemaining = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, currentMessage, errorState, sessionTimestamp, activeTimestamp, deliveredToExchange, keysRemaining>>

\* SOURCE: core_4.7.2 (Message Reception trigger)
HandleReceiveMessage ==
    /\ pendingInput = "ReceiveMessage"
    /\ state \in {"IDLE", "ERROR", "DONE"}
    /\ pendingInput' = NoInput
    /\ state' = "VALIDITY_CHECKS"
    /\ \E msg \in MessageShape : currentMessage' = msg
    /\ deliveredToExchange' = FALSE
    /\ errorState' = "none"
    /\ keysRemaining' = {}
    /\ UNCHANGED <<sessionTimestamp, activeTimestamp>>

\* SOURCE: core_4.7.2 Step 1
ValidityChecks ==
    /\ state = "VALIDITY_CHECKS"
    /\ IF \/ currentMessage.version # 0
          \/ (currentMessage.sessionType = "SecureUnicast" /\ currentMessage.dsizIndicatesGroup)
          \/ (currentMessage.sessionType = "Group" /\ (currentMessage.dsizZero \/ currentMessage.sFlagZero))
       THEN /\ errorState' = "message invalid"
            /\ state' = "ERROR"
       ELSE /\ errorState' = "none"
            /\ state' = "SECURITY_PROCESSING"
    /\ UNCHANGED <<pendingInput, currentMessage, sessionTimestamp, activeTimestamp, deliveredToExchange, keysRemaining>>

\* SOURCE: core_4.7.2 Step 2a
SecurityProcessing_Start ==
    /\ state = "SECURITY_PROCESSING"
    /\ IF currentMessage.sessionType # "Unsecured"
       THEN IF ~currentMessage.keysFound
            THEN /\ errorState' = "message security failed"
                 /\ state' = "ERROR"
                 /\ UNCHANGED keysRemaining
            ELSE /\ keysRemaining' = currentMessage.keysToProcess
                 /\ state' = "SECURITY_PROCESSING_LOOP"
                 /\ UNCHANGED errorState
       ELSE /\ state' = "COUNTER_PROCESSING"
            /\ UNCHANGED <<errorState, keysRemaining>>
    /\ UNCHANGED <<pendingInput, currentMessage, sessionTimestamp, activeTimestamp, deliveredToExchange>>

\* SOURCE: core_4.7.2 Step 2b
SecurityProcessing_Loop ==
    /\ state = "SECURITY_PROCESSING_LOOP"
    /\ IF keysRemaining # {}
       THEN \E k \in keysRemaining :
                \* TODO: unspecified - 4.7.2 does not explicitly state what happens if decrypt/auth fails for ONE key in a group message, or if ALL fail.
                /\ keysRemaining' = keysRemaining \ {k}
                /\ UNCHANGED state
       ELSE /\ state' = "COUNTER_PROCESSING"
            /\ UNCHANGED keysRemaining
    /\ UNCHANGED <<pendingInput, currentMessage, errorState, sessionTimestamp, activeTimestamp, deliveredToExchange>>

\* SOURCE: core_4.7.2 Step 3
CounterProcessing ==
    /\ state = "COUNTER_PROCESSING"
    \* Defers to Section 4.6.7 for replay protection and duplicate detection
    /\ state' = "RELIABLE_PROCESSING"
    /\ UNCHANGED <<pendingInput, currentMessage, errorState, sessionTimestamp, activeTimestamp, deliveredToExchange, keysRemaining>>

\* SOURCE: core_4.7.2 Step 4
ReliableProcessing ==
    /\ state = "RELIABLE_PROCESSING"
    \* Defers to Section 4.12.5.2 if UDP, otherwise proceeds
    /\ state' = "TIMESTAMP_UPDATE"
    /\ UNCHANGED <<pendingInput, currentMessage, errorState, sessionTimestamp, activeTimestamp, deliveredToExchange, keysRemaining>>

\* SOURCE: core_4.7.2 Step 5
TimestampUpdate ==
    /\ state = "TIMESTAMP_UPDATE"
    /\ IF currentMessage.isUnicastSession
       THEN /\ sessionTimestamp' = UpdatedTimestamp
            /\ activeTimestamp' = UpdatedTimestamp
       ELSE /\ UNCHANGED <<sessionTimestamp, activeTimestamp>>
    /\ state' = "EXCHANGE_DELIVERY"
    /\ UNCHANGED <<pendingInput, currentMessage, errorState, deliveredToExchange, keysRemaining>>

\* SOURCE: core_4.7.2 Step 6
ExchangeDelivery ==
    /\ state = "EXCHANGE_DELIVERY"
    /\ deliveredToExchange' = TRUE
    /\ state' = "DONE"
    /\ UNCHANGED <<pendingInput, currentMessage, errorState, sessionTimestamp, activeTimestamp, keysRemaining>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleReceiveMessage
    \/ ValidityChecks
    \/ SecurityProcessing_Start
    \/ SecurityProcessing_Loop
    \/ CounterProcessing
    \/ ReliableProcessing
    \/ TimestampUpdate
    \/ ExchangeDelivery

====