---- MODULE core_5_5 ----
EXTENDS Naturals

\* True if the device supports concurrent connection commissioning flow, False otherwise.
CONSTANTS SupportsConcurrentConnection

\* sentinel: nothing is waiting to be handled
CONSTANTS NoInput

VARIABLES pendingInput, 
          commissioningPhase, 
          paseState, 
          caseState, 
          failSafeState, 
          isCommissioningWithoutPower, 
          commissioningWindowOpen, 
          nocInstalled, 
          networkConnected

Inputs == {
    "ReceivePBKDFParamRequest",
    "ReceivePAKE3",
    "PASEEstablishmentFailed",
    "PASESessionTimeout",
    "CloseSession",
    "NFCSelect",
    "FailSafeExpired",
    "ArmFailSafe_PASE",
    "ArmFailSafe_CASE",
    "SetRegulatoryConfig",
    "SetTCAcknowledgements",
    "DeviceAttestationRequest",
    "CSRRequest",
    "AddTrustedRootCertificate",
    "AddNOC",
    "UpdateFabricLabel",
    "AddOrUpdateNetwork",
    "ConnectNetwork",
    "PowerRestored",
    "OperationalDiscovery",
    "CASEEstablished",
    "CommissioningComplete",
    "SetPowerConfiguration_FullyPowered",
    "SetPowerConfiguration_WithoutPower"
}

Init ==
    /\ pendingInput = NoInput
    /\ commissioningPhase = "None"
    /\ paseState = "None"
    /\ caseState = "None"
    /\ failSafeState = "Disarmed"
    /\ isCommissioningWithoutPower = FALSE
    /\ commissioningWindowOpen = TRUE
    /\ nocInstalled = FALSE
    /\ networkConnected = FALSE

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<commissioningPhase, paseState, caseState, failSafeState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
ReceivePBKDFParamRequest ==
    /\ pendingInput = "ReceivePBKDFParamRequest"
    /\ IF paseState = "None"
       THEN paseState' = "Establishing"
       ELSE UNCHANGED <<paseState>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningPhase, caseState, failSafeState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
ReceivePAKE3 ==
    /\ pendingInput = "ReceivePAKE3"
    /\ IF paseState = "Establishing"
       THEN /\ paseState' = "Established"
            /\ failSafeState' = "Armed"
            /\ commissioningPhase' = "Initial"
       ELSE UNCHANGED <<paseState, failSafeState, commissioningPhase>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<caseState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
PASEEstablishmentFailed ==
    /\ pendingInput = "PASEEstablishmentFailed"
    /\ IF paseState = "Establishing"
       THEN paseState' = "None"
       ELSE UNCHANGED <<paseState>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningPhase, caseState, failSafeState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
PASESessionTimeout ==
    /\ pendingInput = "PASESessionTimeout"
    /\ IF paseState = "Establishing"
       THEN paseState' = "None"
       ELSE UNCHANGED <<paseState>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningPhase, caseState, failSafeState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

CleanupCommissioning ==
    /\ failSafeState' = "Disarmed"
    /\ paseState' = "None"
    /\ caseState' = "None"
    /\ commissioningPhase' = "None"
    /\ nocInstalled' = FALSE
    /\ networkConnected' = FALSE

\* SOURCE: core_5.5
CloseSessionOrNFCSelect ==
    /\ pendingInput \in {"CloseSession", "NFCSelect"}
    /\ IF failSafeState \in {"Armed", "Paused"}
       THEN CleanupCommissioning
       ELSE /\ paseState' = "None"
            /\ UNCHANGED <<failSafeState, caseState, commissioningPhase, nocInstalled, networkConnected>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<isCommissioningWithoutPower, commissioningWindowOpen>>

\* SOURCE: core_5.5
FailSafeExpired ==
    /\ pendingInput = "FailSafeExpired"
    /\ IF failSafeState \in {"Armed", "Paused"}
       THEN CleanupCommissioning
       ELSE UNCHANGED <<failSafeState, paseState, caseState, commissioningPhase, nocInstalled, networkConnected>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<isCommissioningWithoutPower, commissioningWindowOpen>>

\* SOURCE: core_5.5
ReceiveArmFailSafe_PASE ==
    /\ pendingInput = "ArmFailSafe_PASE"
    /\ failSafeState' = "Armed"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningPhase, paseState, caseState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
ReceiveArmFailSafe_CASE ==
    /\ pendingInput = "ArmFailSafe_CASE"
    /\ IF failSafeState = "Disarmed" /\ commissioningWindowOpen
       THEN UNCHANGED <<failSafeState>>
       ELSE failSafeState' = "Armed"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningPhase, paseState, caseState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
ReceiveGenericCommand ==
    /\ pendingInput \in {"SetRegulatoryConfig", "SetTCAcknowledgements", "DeviceAttestationRequest", "CSRRequest", "AddTrustedRootCertificate", "UpdateFabricLabel", "AddOrUpdateNetwork"}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningPhase, paseState, caseState, failSafeState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
ReceiveAddNOC ==
    /\ pendingInput = "AddNOC"
    /\ nocInstalled' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningPhase, paseState, caseState, failSafeState, isCommissioningWithoutPower, commissioningWindowOpen, networkConnected>>

\* SOURCE: core_5.5
ReceiveConnectNetwork ==
    /\ pendingInput = "ConnectNetwork"
    /\ IF isCommissioningWithoutPower
       THEN /\ failSafeState' = "Paused"
            /\ commissioningPhase' = "WaitingForPower"
            /\ UNCHANGED <<networkConnected>>
       ELSE /\ networkConnected' = TRUE
            /\ commissioningPhase' = "Setup"
            /\ UNCHANGED <<failSafeState>>
    /\ IF ~SupportsConcurrentConnection
       THEN paseState' = "None"
       ELSE UNCHANGED <<paseState>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<caseState, nocInstalled, isCommissioningWithoutPower, commissioningWindowOpen>>

\* SOURCE: core_5.5
ReceivePowerRestored ==
    /\ pendingInput = "PowerRestored"
    /\ IF isCommissioningWithoutPower /\ commissioningPhase = "WaitingForPower"
       THEN /\ failSafeState' = "Armed"
            /\ networkConnected' = TRUE
            /\ commissioningPhase' = "Setup"
       ELSE UNCHANGED <<failSafeState, networkConnected, commissioningPhase>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<paseState, caseState, isCommissioningWithoutPower, nocInstalled, commissioningWindowOpen>>

\* SOURCE: core_5.5
SetPowerConfiguration ==
    /\ pendingInput \in {"SetPowerConfiguration_FullyPowered", "SetPowerConfiguration_WithoutPower"}
    /\ isCommissioningWithoutPower' = (pendingInput = "SetPowerConfiguration_WithoutPower")
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningPhase, paseState, caseState, failSafeState, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
PauseFailSafeForDiscovery ==
    /\ pendingInput = NoInput
    /\ commissioningPhase = "Setup"
    /\ isCommissioningWithoutPower
    /\ failSafeState = "Armed"
    /\ failSafeState' = "Paused"
    /\ UNCHANGED <<pendingInput, commissioningPhase, paseState, caseState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
ReceiveOperationalDiscovery ==
    /\ pendingInput = "OperationalDiscovery"
    /\ IF commissioningPhase = "Setup" /\ failSafeState = "Paused"
       THEN failSafeState' = "Armed"
       ELSE UNCHANGED <<failSafeState>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningPhase, paseState, caseState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
CASEEstablished ==
    /\ pendingInput = "CASEEstablished"
    /\ caseState' = "Established"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningPhase, paseState, failSafeState, isCommissioningWithoutPower, commissioningWindowOpen, nocInstalled, networkConnected>>

\* SOURCE: core_5.5
ReceiveCommissioningComplete ==
    /\ pendingInput = "CommissioningComplete"
    /\ IF caseState = "Established"
       THEN /\ commissioningPhase' = "Complete"
            /\ failSafeState' = "Disarmed"
            /\ paseState' = "None"
            /\ commissioningWindowOpen' = FALSE
       ELSE UNCHANGED <<commissioningPhase, failSafeState, paseState, commissioningWindowOpen>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<caseState, isCommissioningWithoutPower, nocInstalled, networkConnected>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ReceivePBKDFParamRequest
    \/ ReceivePAKE3
    \/ PASEEstablishmentFailed
    \/ PASESessionTimeout
    \/ CloseSessionOrNFCSelect
    \/ FailSafeExpired
    \/ ReceiveArmFailSafe_PASE
    \/ ReceiveArmFailSafe_CASE
    \/ ReceiveGenericCommand
    \/ ReceiveAddNOC
    \/ ReceiveConnectNetwork
    \/ ReceivePowerRestored
    \/ SetPowerConfiguration
    \/ PauseFailSafeForDiscovery
    \/ ReceiveOperationalDiscovery
    \/ CASEEstablished
    \/ ReceiveCommissioningComplete

====