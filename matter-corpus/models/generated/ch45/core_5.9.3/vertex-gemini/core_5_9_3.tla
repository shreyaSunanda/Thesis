---- MODULE core_5_9_3 ----
EXTENDS Naturals

CONSTANTS
    \* Represents a null or uninitialized time value
    NullTime

VARIABLES
    now,
    nodeState,
    adminState,
    timeNetworkLost,
    announcementActive,
    adminHasConsent,
    connectionType,
    autonomousReconnectSuspended,
    failsafeState,
    failsafeDeadline,
    credentials

Init ==
    /\ now = 0
    /\ nodeState = "Operational"
    /\ adminState = "Init"
    /\ timeNetworkLost = NullTime
    /\ announcementActive = FALSE
    /\ adminHasConsent = "Unknown"
    /\ connectionType = "None"
    /\ autonomousReconnectSuspended = FALSE
    /\ failsafeState = "NotArmed"
    /\ failsafeDeadline = NullTime
    /\ credentials = "Old"

\* Helper to simulate time passing for timeouts
TimePasses ==
    /\ now' = now + 1
    /\ UNCHANGED <<nodeState, adminState, timeNetworkLost, announcementActive, adminHasConsent, connectionType, autonomousReconnectSuspended, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 3
NodeLosesNetwork ==
    /\ nodeState = "Operational"
    /\ nodeState' = "NetworkLost"
    /\ timeNetworkLost' = now
    /\ UNCHANGED <<now, adminState, announcementActive, adminHasConsent, connectionType, autonomousReconnectSuspended, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 3
NodeEnterRecoveryMode ==
    /\ nodeState = "NetworkLost"
    /\ timeNetworkLost /= NullTime
    /\ now >= timeNetworkLost + 120
    /\ nodeState' = "RecoveryMode"
    /\ announcementActive' = TRUE
    /\ UNCHANGED <<now, adminState, timeNetworkLost, adminHasConsent, connectionType, autonomousReconnectSuspended, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 5
NodeExtendedAnnouncementEnds ==
    /\ nodeState = "RecoveryMode"
    /\ announcementActive = TRUE
    /\ announcementActive' = FALSE
    /\ UNCHANGED <<now, nodeState, adminState, timeNetworkLost, adminHasConsent, connectionType, autonomousReconnectSuspended, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 5
NodeRestartRecovery ==
    /\ nodeState /= "Operational"
    /\ nodeState' = "RecoveryMode"
    /\ announcementActive' = TRUE
    /\ connectionType' = "None"
    /\ autonomousReconnectSuspended' = FALSE
    /\ failsafeState' = "NotArmed"
    /\ failsafeDeadline' = NullTime
    /\ UNCHANGED <<now, adminState, timeNetworkLost, adminHasConsent, credentials>>

\* SOURCE: core_5.9.3 6
\* SOURCE: core_5.9.3 7
AdminObtainsUserConsent ==
    /\ adminState = "Init"
    /\ adminHasConsent = "Unknown"
    /\ \E consent \in {"Granted", "Denied"} :
        /\ adminHasConsent' = consent
        /\ adminState' = (IF consent = "Granted" THEN "ReadyToConnect" ELSE "Terminated")
    /\ UNCHANGED <<now, nodeState, timeNetworkLost, announcementActive, connectionType, autonomousReconnectSuspended, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 8
AdminEstablishesConnection ==
    /\ adminState = "ReadyToConnect"
    /\ adminHasConsent = "Granted"
    /\ nodeState = "RecoveryMode"
    /\ announcementActive = TRUE
    /\ connectionType' = "BLE_WiFi"
    /\ adminState' = "Connected"
    /\ nodeState' = "Connected"
    /\ UNCHANGED <<now, timeNetworkLost, announcementActive, adminHasConsent, autonomousReconnectSuspended, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 9
EstablishCASESession ==
    /\ connectionType = "BLE_WiFi"
    /\ nodeState = "Connected"
    /\ adminState = "Connected"
    /\ connectionType' = "CASE_Recovery"
    /\ autonomousReconnectSuspended' = TRUE
    /\ nodeState' = "CASE_Session"
    /\ adminState' = "CASE_Session"
    /\ UNCHANGED <<now, timeNetworkLost, announcementActive, adminHasConsent, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 10
NodeAutonomouslyArmsFailsafe ==
    /\ nodeState = "CASE_Session"
    /\ failsafeState = "NotArmed"
    /\ failsafeState' = "NodeAutonomouslyArmed"
    /\ failsafeDeadline' = now + 60
    /\ UNCHANGED <<now, nodeState, adminState, timeNetworkLost, announcementActive, adminHasConsent, connectionType, autonomousReconnectSuspended, credentials>>

\* SOURCE: core_5.9.3 11
AdminArmsFailsafe ==
    /\ adminState = "CASE_Session"
    /\ nodeState = "CASE_Session"
    /\ failsafeState = "NodeAutonomouslyArmed"
    /\ now <= failsafeDeadline
    /\ failsafeState' = "AdminArmed"
    /\ adminState' = "Provisioning"
    /\ UNCHANGED <<now, nodeState, timeNetworkLost, announcementActive, adminHasConsent, connectionType, autonomousReconnectSuspended, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 11
AdminFailsToArmFailsafe ==
    /\ adminState = "CASE_Session"
    /\ nodeState = "CASE_Session"
    /\ failsafeState = "NodeAutonomouslyArmed"
    /\ now <= failsafeDeadline
    /\ adminState' = "Terminated"
    /\ connectionType' = "None"
    /\ autonomousReconnectSuspended' = FALSE
    /\ nodeState' = "Failed"
    /\ UNCHANGED <<now, timeNetworkLost, announcementActive, adminHasConsent, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 9
\* SOURCE: core_5.9.3 11
FailsafeTimeout ==
    /\ failsafeState \in {"NodeAutonomouslyArmed", "AdminArmed"}
    /\ now > failsafeDeadline
    /\ nodeState' = "Failed"
    /\ adminState' = "Terminated"
    /\ connectionType' = "None"
    /\ autonomousReconnectSuspended' = FALSE
    /\ UNCHANGED <<now, timeNetworkLost, announcementActive, adminHasConsent, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 12
AdminProvisionsCredentials ==
    /\ adminState = "Provisioning"
    /\ failsafeState = "AdminArmed"
    /\ credentials' = "New"
    /\ adminState' = "ReadyToConnectNetwork"
    /\ UNCHANGED <<now, nodeState, timeNetworkLost, announcementActive, adminHasConsent, connectionType, autonomousReconnectSuspended, failsafeState, failsafeDeadline>>

\* SOURCE: core_5.9.3 13
AdminInstructsConnectNetwork ==
    /\ adminState = "ReadyToConnectNetwork"
    /\ nodeState = "CASE_Session"
    /\ nodeState' = "Connecting"
    /\ adminState' = "WaitingForNetwork"
    /\ UNCHANGED <<now, timeNetworkLost, announcementActive, adminHasConsent, connectionType, autonomousReconnectSuspended, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 14
NodeConnectsToOperationalNetwork ==
    /\ nodeState = "Connecting"
    /\ credentials = "New"
    /\ nodeState' = "ConnectedNew"
    /\ connectionType' = "CASE_Operational"
    /\ UNCHANGED <<now, adminState, timeNetworkLost, announcementActive, adminHasConsent, autonomousReconnectSuspended, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 15
OperationalDiscovery ==
    /\ nodeState = "ConnectedNew"
    /\ adminState = "WaitingForNetwork"
    /\ connectionType = "CASE_Operational"
    /\ nodeState' = "Discovered"
    /\ adminState' = "Discovered"
    /\ UNCHANGED <<now, timeNetworkLost, announcementActive, adminHasConsent, connectionType, autonomousReconnectSuspended, failsafeState, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 16
CompleteNetworkRecovery ==
    /\ nodeState = "Discovered"
    /\ adminState = "Discovered"
    /\ connectionType = "CASE_Operational"
    /\ nodeState' = "Completed"
    /\ adminState' = "Completed"
    /\ autonomousReconnectSuspended' = FALSE
    /\ failsafeState' = "NotArmed"
    /\ UNCHANGED <<now, timeNetworkLost, announcementActive, adminHasConsent, connectionType, failsafeDeadline, credentials>>

\* SOURCE: core_5.9.3 16
RejectCommissioningCompleteNotOperational ==
    /\ adminState \in {"WaitingForNetwork", "ReadyToConnectNetwork"}
    /\ connectionType /= "CASE_Operational"
    /\ nodeState' = "Failed"
    /\ autonomousReconnectSuspended' = FALSE
    /\ UNCHANGED <<now, adminState, timeNetworkLost, announcementActive, adminHasConsent, connectionType, failsafeState, failsafeDeadline, credentials>>

Next ==
    \/ TimePasses
    \/ NodeLosesNetwork
    \/ NodeEnterRecoveryMode
    \/ NodeExtendedAnnouncementEnds
    \/ NodeRestartRecovery
    \/ AdminObtainsUserConsent
    \/ AdminEstablishesConnection
    \/ EstablishCASESession
    \/ NodeAutonomouslyArmsFailsafe
    \/ AdminArmsFailsafe
    \/ AdminFailsToArmFailsafe
    \/ FailsafeTimeout
    \/ AdminProvisionsCredentials
    \/ AdminInstructsConnectNetwork
    \/ NodeConnectsToOperationalNetwork
    \/ OperationalDiscovery
    \/ CompleteNetworkRecovery
    \/ RejectCommissioningCompleteNotOperational

====