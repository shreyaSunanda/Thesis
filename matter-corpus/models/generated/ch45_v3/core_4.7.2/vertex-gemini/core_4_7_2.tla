---- MODULE core_4_7_2 ----
EXTENDS Naturals

\* Session IDs used in the system.
CONSTANTS SessionIDs

\* Keys available for security processing.
CONSTANTS Keys

\* Sentinel value for no message delivered.
CONSTANTS NullMessage

\* Maximum value for the abstract clock to prevent infinite state space.
CONSTANTS MaxTime

\* pendingInput and the NoInput constant are REQUIRED - see rule 4a.
CONSTANTS NoInput

VARIABLES 
    state, 
    pendingInput,
    currentMessage,
    sessionKeys,
    nextHigherLayer,
    now,
    sessionTimestamps,
    activeTimestamps,
    deliveredMessage

\* REQUIRED - the complete list of events this section can receive.
Inputs == {"ReceiveMessage"}

Messages == [
    version : {0, 1},
    sessionType : {"SecureUnicast", "Group", "Unsecured"},
    dsizGroupPresent : BOOLEAN,
    dsizZero : BOOLEAN,
    sFlagZero : BOOLEAN,
    sessionId : SessionIDs,
    pFlag : BOOLEAN,
    transport : {"UDP", "TCP"},
    isUnicast : BOOLEAN
]

IsValid(msg) ==
    /\ msg.version = 0
    /\ (msg.sessionType = "SecureUnicast" => ~msg.dsizGroupPresent)
    /\ (msg.sessionType = "Group" => (~msg.dsizZero /\ ~msg.sFlagZero))

Init == 
    /\ state = "Idle"
    /\ pendingInput = NoInput
    /\ \E msg \in Messages : currentMessage = msg
    /\ sessionKeys \in [SessionIDs -> SUBSET Keys]
    /\ nextHigherLayer = "None"
    /\ now = 0
    /\ sessionTimestamps = [s \in SessionIDs |-> 0]
    /\ activeTimestamps = [s \in SessionIDs |-> 0]
    /\ deliveredMessage = NullMessage

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, currentMessage, sessionKeys, nextHigherLayer, now, sessionTimestamps, activeTimestamps, deliveredMessage>>

UpdateCurrentMessage ==
    /\ pendingInput = NoInput
    /\ state = "Idle"
    /\ \E msg \in Messages : currentMessage' = msg
    /\ UNCHANGED <<state, pendingInput, sessionKeys, nextHigherLayer, now, sessionTimestamps, activeTimestamps, deliveredMessage>>

AdvanceClock ==
    /\ state = "Idle"
    /\ pendingInput = NoInput
    /\ now' = (now + 1) % MaxTime
    /\ UNCHANGED <<state, pendingInput, currentMessage, sessionKeys, nextHigherLayer, sessionTimestamps, activeTimestamps, deliveredMessage>>

\* SOURCE: core_4.7.2 1
ValidityChecks ==
    /\ pendingInput = "ReceiveMessage"
    /\ state = "Idle"
    /\ pendingInput' = NoInput
    /\ IF ~IsValid(currentMessage)
       THEN /\ nextHigherLayer' = "message invalid"
            /\ state' = "Idle"
       ELSE /\ state' = "CheckSecurity"
            /\ nextHigherLayer' = "None"
    /\ UNCHANGED <<currentMessage, sessionKeys, now, sessionTimestamps, activeTimestamps, deliveredMessage>>

\* SOURCE: core_4.7.2 2
SecurityProcessing ==
    /\ state = "CheckSecurity"
    /\ IF currentMessage.sessionType # "Unsecured"
       THEN IF sessionKeys[currentMessage.sessionId] = {}
            THEN /\ nextHigherLayer' = "message security failed"
                 /\ state' = "Idle"
            ELSE /\ state' = "CheckCounters"
                 /\ UNCHANGED nextHigherLayer
       ELSE /\ state' = "CheckCounters"
            /\ UNCHANGED nextHigherLayer
    /\ UNCHANGED <<pendingInput, currentMessage, sessionKeys, now, sessionTimestamps, activeTimestamps, deliveredMessage>>

\* SOURCE: core_4.7.2 3
CounterProcessing ==
    /\ state = "CheckCounters"
    /\ state' = "CheckReliability"
    /\ UNCHANGED <<pendingInput, currentMessage, sessionKeys, nextHigherLayer, now, sessionTimestamps, activeTimestamps, deliveredMessage>>

\* SOURCE: core_4.7.2 4
ReliableMessageProcessing ==
    /\ state = "CheckReliability"
    /\ state' = "UpdateTimestamps"
    /\ UNCHANGED <<pendingInput, currentMessage, sessionKeys, nextHigherLayer, now, sessionTimestamps, activeTimestamps, deliveredMessage>>

\* SOURCE: core_4.7.2 5
UpdateTimestamps ==
    /\ state = "UpdateTimestamps"
    /\ IF currentMessage.isUnicast
       THEN /\ sessionTimestamps' = [sessionTimestamps EXCEPT ![currentMessage.sessionId] = now]
            /\ activeTimestamps' = [activeTimestamps EXCEPT ![currentMessage.sessionId] = now]
       ELSE /\ UNCHANGED <<sessionTimestamps, activeTimestamps>>
    /\ state' = "Deliver"
    /\ UNCHANGED <<pendingInput, currentMessage, sessionKeys, nextHigherLayer, now, deliveredMessage>>

\* SOURCE: core_4.7.2 6
DeliverMessage ==
    /\ state = "Deliver"
    /\ deliveredMessage' = currentMessage
    /\ state' = "Idle"
    /\ UNCHANGED <<pendingInput, currentMessage, sessionKeys, nextHigherLayer, now, sessionTimestamps, activeTimestamps>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ UpdateCurrentMessage
    \/ AdvanceClock
    \/ ValidityChecks
    \/ SecurityProcessing
    \/ CounterProcessing
    \/ ReliableMessageProcessing
    \/ UpdateTimestamps
    \/ DeliverMessage

====