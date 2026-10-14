---- MODULE core_5_9_3 ----
EXTENDS Naturals

\* 120 seconds for initial reconnect attempt, 60 seconds for fail-safe timeout
\* Modeled as abstract timeouts via events, but declared for completeness per spec text.
CONSTANTS InitialAttemptDuration, FailSafeTimeoutDuration

CONSTANTS NoInput
VARIABLES pendingInput, nodeState, userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete

Inputs == {
    "RetrieveRecoveryIdentifier",
    "LoseConnectivity",
    "ReconnectSuccess",
    "EnterRecoveryMode",
    "TimerExtendedAnnouncementExpired",
    "CommissioningModeInitialStepsHint",
    "GrantUserConsent",
    "DenyUserConsent",
    "EstablishCASE",
    "CASETransaction",
    "FailSafeTimeout",
    "AdminArmFailSafe",
    "AdminArmFailSafeFailed",
    "RemoveNetwork",
    "AddOrUpdateNetwork",
    "ConnectNetwork",
    "ConnectNetworkSuccess",
    "ConnectNetworkFailure",
    "OperationalDiscovery",
    "CommissioningCompleteOverOperational",
    "CommissioningCompleteNotOperational"
}

Init ==
    /\ pendingInput = NoInput
    /\ nodeState = "Connected"
    /\ userConsentStatus = "Unknown"
    /\ failSafeStatus = "Disarmed"
    /\ credentialsStatus = "Existing"
    /\ operationalDiscoveryComplete = FALSE

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<nodeState, userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 1
HandleRetrieveRecoveryIdentifier ==
    /\ pendingInput = "RetrieveRecoveryIdentifier"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<nodeState, userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 3
HandleLoseConnectivity ==
    /\ pendingInput = "LoseConnectivity"
    /\ nodeState = "Connected"
    /\ nodeState' = "LostConnectivity"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 3
HandleReconnectSuccess ==
    /\ pendingInput = "ReconnectSuccess"
    /\ nodeState \in {"LostConnectivity", "RecoveryMode"}
    /\ nodeState' = "Connected"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 3
HandleEnterRecoveryMode ==
    /\ pendingInput = "EnterRecoveryMode"
    /\ nodeState = "LostConnectivity"
    \* Node MAY choose to enter Network Recovery mode and commence announcement
    /\ nodeState' = "RecoveryMode"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 5
HandleTimerExtendedAnnouncementExpired ==
    /\ pendingInput = "TimerExtendedAnnouncementExpired"
    /\ nodeState = "RecoveryMode"
    \* Node SHALL continue to attempt to reconnect to the existing operational network
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<nodeState, userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 5
HandleCommissioningModeInitialStepsHint ==
    /\ pendingInput = "CommissioningModeInitialStepsHint"
    \* The Recovery Node SHALL restart the Network Recovery procedure
    /\ nodeState' = "RecoveryMode"
    /\ failSafeStatus' = "Disarmed"
    /\ credentialsStatus' = "Existing"
    /\ operationalDiscoveryComplete' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<userConsentStatus>>

\* SOURCE: core_5.9.3 clause 6
HandleGrantUserConsent ==
    /\ pendingInput = "GrantUserConsent"
    /\ userConsentStatus' = "Granted"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<nodeState, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 7
HandleDenyUserConsent ==
    /\ pendingInput = "DenyUserConsent"
    /\ userConsentStatus' = "Denied"
    \* Administrator terminates its execution of the Network Recovery flow
    /\ \/ /\ nodeState \in {"CASE_Established", "Connected_NewNetwork"}
          /\ nodeState' = "RecoveryMode"
          /\ failSafeStatus' = "Disarmed"
          /\ credentialsStatus' = "Existing"
          /\ operationalDiscoveryComplete' = FALSE
       \/ /\ nodeState \notin {"CASE_Established", "Connected_NewNetwork"}
          /\ UNCHANGED <<nodeState, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>
    /\ pendingInput' = NoInput

\* SOURCE: core_5.9.3 clause 8, 9, 10
HandleEstablishCASE ==
    /\ pendingInput = "EstablishCASE"
    /\ nodeState = "RecoveryMode"
    /\ userConsentStatus = "Granted"
    \* Upon successful establishment of the CASE session, the Recovery Node SHALL autonomously arm the fail-safe timer
    /\ nodeState' = "CASE_Established"
    /\ failSafeStatus' = "ArmedByNode"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<userConsentStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 9
HandleCASETransaction ==
    /\ pendingInput = "CASETransaction"
    /\ nodeState \in {"CASE_Established", "Connected_NewNetwork"}
    \* Recovery Nodes SHALL allow any and all transactions allowed over a CASE session
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<nodeState, userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 10, 11
HandleFailSafeTimeout ==
    /\ pendingInput = "FailSafeTimeout"
    /\ nodeState = "CASE_Established"
    /\ failSafeStatus = "ArmedByNode"
    \* Guard against Administrator not proceeding; autonomous attempts resume
    /\ nodeState' = "RecoveryMode"
    /\ failSafeStatus' = "Disarmed"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<userConsentStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 11
HandleAdminArmFailSafe ==
    /\ pendingInput = "AdminArmFailSafe"
    /\ nodeState = "CASE_Established"
    /\ failSafeStatus' = "ArmedByAdmin"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<nodeState, userConsentStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 11
HandleAdminArmFailSafeFailed ==
    /\ pendingInput = "AdminArmFailSafeFailed"
    /\ nodeState = "CASE_Established"
    \* If the fail-safe could not be successfully armed, the Administrator SHALL terminate the session
    /\ nodeState' = "RecoveryMode"
    /\ failSafeStatus' = "Disarmed"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<userConsentStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 12
HandleRemoveNetwork ==
    /\ pendingInput = "RemoveNetwork"
    /\ nodeState = "CASE_Established"
    /\ failSafeStatus = "ArmedByAdmin"
    /\ credentialsStatus' = "Removed"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<nodeState, userConsentStatus, failSafeStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 12
HandleAddOrUpdateNetwork ==
    /\ pendingInput = "AddOrUpdateNetwork"
    /\ nodeState = "CASE_Established"
    /\ failSafeStatus = "ArmedByAdmin"
    /\ credentialsStatus' = "NewProvided"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<nodeState, userConsentStatus, failSafeStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 13
HandleConnectNetwork ==
    /\ pendingInput = "ConnectNetwork"
    /\ nodeState = "CASE_Established"
    /\ credentialsStatus = "NewProvided"
    \* Attempting connection; node state remains in CASE_Established while trying
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<nodeState, userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 14
HandleConnectNetworkSuccess ==
    /\ pendingInput = "ConnectNetworkSuccess"
    /\ nodeState = "CASE_Established"
    /\ credentialsStatus = "NewProvided"
    \* Once connected, remaining messages SHALL be exchanged over the operational network
    /\ nodeState' = "Connected_NewNetwork"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 14
HandleConnectNetworkFailure ==
    /\ pendingInput = "ConnectNetworkFailure"
    /\ nodeState = "CASE_Established"
    /\ credentialsStatus = "NewProvided"
    \* Autonomous attempts to re-establish network connectivity SHALL resume in the event of failure
    /\ nodeState' = "RecoveryMode"
    /\ failSafeStatus' = "Disarmed"
    /\ credentialsStatus' = "Existing"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<userConsentStatus, operationalDiscoveryComplete>>

\* SOURCE: core_5.9.3 clause 15
HandleOperationalDiscovery ==
    /\ pendingInput = "OperationalDiscovery"
    /\ nodeState = "Connected_NewNetwork"
    /\ operationalDiscoveryComplete' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<nodeState, userConsentStatus, failSafeStatus, credentialsStatus>>

\* SOURCE: core_5.9.3 clause 16
HandleCommissioningCompleteOverOperational ==
    /\ pendingInput = "CommissioningCompleteOverOperational"
    /\ nodeState = "Connected_NewNetwork"
    /\ operationalDiscoveryComplete = TRUE
    \* Indicate successful completion of the Network Recovery flow
    /\ nodeState' = "Connected"
    /\ failSafeStatus' = "Disarmed"
    /\ credentialsStatus' = "Existing"
    /\ operationalDiscoveryComplete' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<userConsentStatus>>

\* SOURCE: core_5.9.3 clause 16
HandleCommissioningCompleteNotOperational ==
    /\ pendingInput = "CommissioningCompleteNotOperational"
    /\ nodeState \in {"CASE_Established", "Connected_NewNetwork"}
    \* The Recovery Node SHALL reject the CommissioningComplete that is not received over the operational network
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<nodeState, userConsentStatus, failSafeStatus, credentialsStatus, operationalDiscoveryComplete>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleRetrieveRecoveryIdentifier
    \/ HandleLoseConnectivity
    \/ HandleReconnectSuccess
    \/ HandleEnterRecoveryMode
    \/ HandleTimerExtendedAnnouncementExpired
    \/ HandleCommissioningModeInitialStepsHint
    \/ HandleGrantUserConsent
    \/ HandleDenyUserConsent
    \/ HandleEstablishCASE
    \/ HandleCASETransaction
    \/ HandleFailSafeTimeout
    \/ HandleAdminArmFailSafe
    \/ HandleAdminArmFailSafeFailed
    \/ HandleRemoveNetwork
    \/ HandleAddOrUpdateNetwork
    \/ HandleConnectNetwork
    \/ HandleConnectNetworkSuccess
    \/ HandleConnectNetworkFailure
    \/ HandleOperationalDiscovery
    \/ HandleCommissioningCompleteOverOperational
    \/ HandleCommissioningCompleteNotOperational

====