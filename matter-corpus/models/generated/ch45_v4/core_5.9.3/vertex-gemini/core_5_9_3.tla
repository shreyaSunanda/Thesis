---- MODULE core_5_9_3 ----
EXTENDS Naturals

CONSTANTS NoInput

VARIABLES pendingInput, state, reconnectAttempts, failSafeState, sessionChannel, hasNewCredentials

Inputs == {
    "OpNetworkLost",
    "Wait120sTimeout",
    "ExtendedAnnouncementTimeout",
    "InitialStepsHintPerformed",
    "EstablishCASE",
    "CASEFailure",
    "FailsafeTimeout",
    "ArmFailSafe",
    "RemoveNetwork",
    "AddOrUpdateWiFiNetwork",
    "AddOrUpdateThreadNetwork",
    "ConnectNetwork",
    "NewNetworkConnected",
    "OperationalDiscoveryComplete",
    "CommissioningComplete",
    "UserConsentDenied"
}

Operational == TRUE

Init ==
    /\ pendingInput = NoInput
    /\ state = "OpNetworkNormal"
    /\ reconnectAttempts = "Active"
    /\ failSafeState = "Disarmed"
    /\ sessionChannel = "None"
    /\ hasNewCredentials = FALSE

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, reconnectAttempts, failSafeState, sessionChannel, hasNewCredentials>>

\* SOURCE: core_5.9.3 3
HandleOpNetworkLost ==
    /\ pendingInput = "OpNetworkLost"
    /\ state = "OpNetworkNormal"
    /\ state' = "LostNetworkWait"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<reconnectAttempts, failSafeState, sessionChannel, hasNewCredentials>>

\* SOURCE: core_5.9.3 3
HandleWait120sTimeout ==
    /\ pendingInput = "Wait120sTimeout"
    /\ state = "LostNetworkWait"
    /\ state' = "Announcing"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<reconnectAttempts, failSafeState, sessionChannel, hasNewCredentials>>

\* SOURCE: core_5.9.3 5
HandleExtendedAnnouncementTimeout ==
    /\ pendingInput = "ExtendedAnnouncementTimeout"
    /\ state = "Announcing"
    /\ state' = "AnnouncingEnded"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<reconnectAttempts, failSafeState, sessionChannel, hasNewCredentials>>

\* SOURCE: core_5.9.3 5
HandleInitialStepsHintPerformed ==
    /\ pendingInput = "InitialStepsHintPerformed"
    /\ state' = "Announcing"
    /\ reconnectAttempts' = "Active"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<failSafeState, sessionChannel, hasNewCredentials>>

\* SOURCE: core_5.9.3 9
\* SOURCE: core_5.9.3 10
HandleEstablishCASE ==
    /\ pendingInput = "EstablishCASE"
    /\ state \in {"Announcing", "AnnouncingEnded"}
    /\ state' = "CASE_Established"
    /\ sessionChannel' = "CommissioningChannel"
    /\ reconnectAttempts' = "Suspended"
    /\ failSafeState' = "ArmedByNode"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<hasNewCredentials>>

\* SOURCE: core_5.9.3 9
HandleCASEFailure ==
    /\ pendingInput = "CASEFailure"
    /\ sessionChannel # "None"
    /\ state' = "AnnouncingEnded"
    /\ reconnectAttempts' = "Active"
    /\ sessionChannel' = "None"
    /\ failSafeState' = "Disarmed"
    /\ hasNewCredentials' = FALSE
    /\ pendingInput' = NoInput

\* SOURCE: core_5.9.3 11
HandleFailsafeTimeout ==
    /\ pendingInput = "FailsafeTimeout"
    /\ failSafeState \in {"ArmedByNode", "ArmedByAdmin"}
    /\ state' = "AnnouncingEnded"
    /\ reconnectAttempts' = "Active"
    /\ sessionChannel' = "None"
    /\ failSafeState' = "Disarmed"
    /\ hasNewCredentials' = FALSE
    /\ pendingInput' = NoInput

\* SOURCE: core_5.9.3 11
HandleArmFailSafe ==
    /\ pendingInput = "ArmFailSafe"
    /\ state = "CASE_Established"
    /\ failSafeState = "ArmedByNode"
    /\ failSafeState' = "ArmedByAdmin"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, reconnectAttempts, sessionChannel, hasNewCredentials>>

\* SOURCE: core_5.9.3 12
HandleRemoveNetwork ==
    /\ pendingInput = "RemoveNetwork"
    /\ state = "CASE_Established"
    /\ hasNewCredentials' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, reconnectAttempts, failSafeState, sessionChannel>>

\* SOURCE: core_5.9.3 12
HandleAddOrUpdateNetwork ==
    /\ pendingInput \in {"AddOrUpdateWiFiNetwork", "AddOrUpdateThreadNetwork"}
    /\ state = "CASE_Established"
    /\ hasNewCredentials' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, reconnectAttempts, failSafeState, sessionChannel>>

\* SOURCE: core_5.9.3 13
HandleConnectNetwork ==
    /\ pendingInput = "ConnectNetwork"
    /\ state = "CASE_Established"
    /\ hasNewCredentials = TRUE
    /\ state' = "ConnectingNewOpNetwork"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<reconnectAttempts, failSafeState, sessionChannel, hasNewCredentials>>

\* SOURCE: core_5.9.3 14
HandleNewNetworkConnected ==
    /\ pendingInput = "NewNetworkConnected"
    /\ state = "ConnectingNewOpNetwork"
    /\ state' = "ConnectedNewOpNetwork"
    /\ sessionChannel' = "OpNetwork"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<reconnectAttempts, failSafeState, hasNewCredentials>>

\* SOURCE: core_5.9.3 15
HandleOperationalDiscoveryComplete ==
    /\ pendingInput = "OperationalDiscoveryComplete"
    /\ state = "ConnectedNewOpNetwork"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, reconnectAttempts, failSafeState, sessionChannel, hasNewCredentials>>

\* SOURCE: core_5.9.3 16
HandleCommissioningComplete ==
    /\ pendingInput = "CommissioningComplete"
    /\ IF sessionChannel = "OpNetwork" THEN
           /\ state' = "OpNetworkNormal"
           /\ failSafeState' = "Disarmed"
           /\ sessionChannel' = "None"
           /\ hasNewCredentials' = FALSE
           /\ reconnectAttempts' = "Active"
       ELSE
           /\ UNCHANGED <<state, failSafeState, sessionChannel, hasNewCredentials, reconnectAttempts>>
    /\ pendingInput' = NoInput

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleOpNetworkLost
    \/ HandleWait120sTimeout
    \/ HandleExtendedAnnouncementTimeout
    \/ HandleInitialStepsHintPerformed
    \/ HandleEstablishCASE
    \/ HandleCASEFailure
    \/ HandleFailsafeTimeout
    \/ HandleArmFailSafe
    \/ HandleRemoveNetwork
    \/ HandleAddOrUpdateNetwork
    \/ HandleConnectNetwork
    \/ HandleNewNetworkConnected
    \/ HandleOperationalDiscoveryComplete
    \/ HandleCommissioningComplete

====