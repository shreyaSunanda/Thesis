---- MODULE core_4_7_2 ----
EXTENDS Naturals

CONSTANTS 
    SessionIDs,
    SessionType_SecureUnicast,
    SessionType_Group,
    SessionType_Unsecured,
    Transport_UDP,
    Transport_Other

VARIABLES 
    state,
    msg,
    availableKeys,
    keysToProcess,
    sessionTimestamps,
    activeTimestamps,
    clock,
    output

Init ==
    /\ state = "Idle"
    /\ msg = [
        version |-> 0, 
        sessionType |-> SessionType_Unsecured, 
        sessionID |-> CHOOSE x \in SessionIDs : TRUE, 
        dsizGroupPresent |-> FALSE, 
        dsizZero |-> TRUE, 
        sFlagZero |-> TRUE, 
        pFlag |-> FALSE, 
        transport |-> Transport_UDP
       ]
    /\ availableKeys = [id \in SessionIDs |-> {}]
    /\ keysToProcess = {}
    /\ sessionTimestamps = [id \in SessionIDs |-> 0]
    /\ activeTimestamps = [id \in SessionIDs |-> 0]
    /\ clock = 1
    /\ output = "None"

\* Transition to receive a message and start processing
ReceiveMessage(m) ==
    /\ state = "Idle"
    /\ msg' = m
    /\ state' = "ValidityCheck"
    /\ output' = "None"
    /\ UNCHANGED <<availableKeys, keysToProcess, sessionTimestamps, activeTimestamps, clock>>

\* SOURCE: core_4.7.2 1
ValidityCheck ==
    /\ state = "ValidityCheck"
    /\ LET isValid ==
            /\ msg.version = 0
            /\ (msg.sessionType = SessionType_SecureUnicast => ~msg.dsizGroupPresent)
            /\ (msg.sessionType = SessionType_Group => (~msg.dsizZero /\ ~msg.sFlagZero))
       IN
          IF isValid THEN
             IF msg.sessionType # SessionType_Unsecured THEN
                 /\ state' = "ObtainKeys"
                 /\ output' = output
             ELSE
                 /\ state' = "CounterProcessing"
                 /\ output' = output
          ELSE
             /\ state' = "Idle"
             /\ output' = "Error_MessageInvalid"
    /\ UNCHANGED <<msg, availableKeys, keysToProcess, sessionTimestamps, activeTimestamps, clock>>

\* SOURCE: core_4.7.2 2.a
ObtainKeys ==
    /\ state = "ObtainKeys"
    /\ LET keys == availableKeys[msg.sessionID]
       IN
          IF keys = {} THEN
             /\ state' = "Idle"
             /\ output' = "Error_MessageSecurityFailed"
             /\ UNCHANGED keysToProcess
          ELSE
             /\ state' = "SecurityProcessing"
             /\ keysToProcess' = keys
             /\ output' = output
    /\ UNCHANGED <<msg, availableKeys, sessionTimestamps, activeTimestamps, clock>>

\* SOURCE: core_4.7.2 2.b
SecurityProcessing ==
    /\ state = "SecurityProcessing"
    /\ IF keysToProcess # {} THEN
          \E k \in keysToProcess :
             /\ keysToProcess' = keysToProcess \ {k}
             \* TODO: unspecified - detailed behaviors of Sections 4.9.4 and 4.8.3 are abstracted here.
             /\ state' = "SecurityProcessing"
       ELSE
          /\ state' = "CounterProcessing"
          /\ UNCHANGED keysToProcess
    /\ UNCHANGED <<msg, availableKeys, sessionTimestamps, activeTimestamps, clock, output>>

\* SOURCE: core_4.7.2 3
CounterProcessing ==
    /\ state = "CounterProcessing"
    \* TODO: unspecified - detailed behaviors of Section 4.6.7 for replay protection and duplicate detection.
    /\ state' = "ReliabilityProcessing"
    /\ UNCHANGED <<msg, availableKeys, keysToProcess, sessionTimestamps, activeTimestamps, clock, output>>

\* SOURCE: core_4.7.2 4
ReliabilityProcessing ==
    /\ state = "ReliabilityProcessing"
    \* TODO: unspecified - detailed behaviors of Section 4.12.5.2 for UDP message reliability.
    /\ state' = "TimestampUpdate"
    /\ UNCHANGED <<msg, availableKeys, keysToProcess, sessionTimestamps, activeTimestamps, clock, output>>

\* SOURCE: core_4.7.2 5
TimestampUpdate ==
    /\ state = "TimestampUpdate"
    /\ IF msg.sessionType = SessionType_SecureUnicast \/ msg.sessionType = SessionType_Unsecured THEN
          /\ sessionTimestamps' = [sessionTimestamps EXCEPT ![msg.sessionID] = clock]
          /\ activeTimestamps' = [activeTimestamps EXCEPT ![msg.sessionID] = clock]
       ELSE
          /\ UNCHANGED <<sessionTimestamps, activeTimestamps>>
    /\ state' = "Dispatch"
    /\ UNCHANGED <<msg, availableKeys, keysToProcess, clock, output>>

\* SOURCE: core_4.7.2 6
Dispatch ==
    /\ state = "Dispatch"
    /\ output' = "DispatchedToExchange"
    /\ state' = "Idle"
    /\ UNCHANGED <<msg, availableKeys, keysToProcess, sessionTimestamps, activeTimestamps, clock>>

Next ==
    \/ (\E m \in [
            version : Nat, 
            sessionType : {SessionType_SecureUnicast, SessionType_Group, SessionType_Unsecured}, 
            sessionID : SessionIDs, 
            dsizGroupPresent : BOOLEAN, 
            dsizZero : BOOLEAN, 
            sFlagZero : BOOLEAN, 
            pFlag : BOOLEAN, 
            transport : {Transport_UDP, Transport_Other}
        ] : ReceiveMessage(m))
    \/ ValidityCheck
    \/ ObtainKeys
    \/ SecurityProcessing
    \/ CounterProcessing
    \/ ReliabilityProcessing
    \/ TimestampUpdate
    \/ Dispatch

====