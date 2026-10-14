---- MODULE core_5_5 ----
EXTENDS Naturals

\* Boolean indicating whether Commissioner and Commissionee have the ability to maintain two network connections simultaneously
CONSTANTS ConcurrentConnectionCap

\* Boolean indicating if the Commissionee is in a power configuration that prevents connecting to the operational network
CONSTANTS IsCommissioningWithoutPower

CONSTANTS NoInput
VARIABLES pendingInput

\* Represents the Commissionee's PASE session state
VARIABLES paseSessionStatus       \* "None", "Establishing", "Established"

\* Represents the Fail-Safe timer state
VARIABLES failSafeStatus          \* "Disarmed", "Armed", "Expired", "Paused"

\* Represents whether the commissioning window is currently open for accepting connections
VARIABLES commissioningWindowOpen \* BOOLEAN

\* Tracks the high-level phase of the commissioning flow
VARIABLES commissioningPhase      \* "Idle", "Initial", "Setup", "Complete"

\* Represents the state of the commissioning channel
VARIABLES commissioningChannel    \* "Closed", "Open"

Inputs == {
    "PASE_Establishment_Request",
    "PASE_PBKDFParamResponse",
    "PAKE3",
    "PASE_Establishment_Fail",
    "CloseSession",
    "NTL_SELECT",
    "PASE_Timeout",
    "ArmFailSafe",
    "SetRegulatoryConfig",
    "SetTCAcknowledgements",
    "CSRRequest",
    "AddTrustedRootCertificate",
    "AddNOC",
    "UpdateFabricLabel",
    "ScanNetworks",
    "AddOrUpdateWiFiNetwork",
    "AddOrUpdateThreadNetwork",
    "ConnectNetwork",
    "PowerIndication",
    "OperationalDiscovery",
    "CASE_Establishment",
    "CommissioningComplete"
}

Operational == commissioningPhase # "Idle"

Init ==
    /\ pendingInput = NoInput
    /\ paseSessionStatus = "None"
    /\ failSafeStatus = "Disarmed"
    /\ commissioningWindowOpen = TRUE
    /\ commissioningPhase = "Idle"
    /\ commissioningChannel = "Closed"

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<paseSessionStatus, failSafeStatus, commissioningWindowOpen, commissioningPhase, commissioningChannel>>

\* SOURCE: core_5.5 Commissioning Flows
\* "A Commissionee that is ready to be commissioned SHALL accept the request to establish a PASE session with the first Commissioner that initiates the request."
AcceptPaseRequest ==
    /\ pendingInput = "PASE_Establishment_Request"
    /\ paseSessionStatus = "None"
    /\ paseSessionStatus' = "Establishing"
    /\ commissioningChannel' = "Open"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<failSafeStatus, commissioningWindowOpen, commissioningPhase>>

\* SOURCE: core_5.5 Commissioning Flows
\* "When a Commissioner is either in the process of establishing a PASE session... or has successfully established... the Commissionee SHALL NOT accept any more requests for new PASE sessions"
RejectPaseRequest ==
    /\ pendingInput = "PASE_Establishment_Request"
    /\ paseSessionStatus \in {"Establishing", "Established"}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<paseSessionStatus, failSafeStatus, commissioningWindowOpen, commissioningPhase, commissioningChannel>>

\* SOURCE: core_5.5 Commissioning Flows
\* "6. Commissioner and Commissionee SHALL establish encryption keys with PASE... Upon completion of PASE session establishment, the Commissionee SHALL autonomously arm the Fail-safe timer"
ReceivePAKE3 ==
    /\ pendingInput = "PAKE3"
    /\ paseSessionStatus = "Establishing"
    /\ paseSessionStatus' = "Established"
    /\ failSafeStatus' = "Armed"
    /\ commissioningPhase' = "Initial"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningWindowOpen, commissioningChannel>>

\* SOURCE: core_5.5 Commissioning Flows
\* "...until one of the following events occurs: session establishment fails"
FailPaseEstablishment ==
    /\ pendingInput = "PASE_Establishment_Fail"
    /\ paseSessionStatus = "Establishing"
    /\ paseSessionStatus' = "None"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<failSafeStatus, commissioningWindowOpen, commissioningPhase, commissioningChannel>>

\* SOURCE: core_5.5 Commissioning Flows
\* "If the PASE session is not established within the expected time window the Commissionee SHALL terminate the current session establishment using the INVALID_PARAMETER status code"
TimeoutPaseEstablishment ==
    /\ pendingInput = "PASE_Timeout"
    /\ paseSessionStatus = "Establishing"
    /\ paseSessionStatus' = "None"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<failSafeStatus, commissioningWindowOpen, commissioningPhase, commissioningChannel>>

\* SOURCE: core_5.5 Commissioning Flows
\* "In the event a CloseSession status message is sent or received, or whenever commissioning through NFC Transport Layer (NTL) is interrupted by SELECT command :
\* 1. If the fail-safe timer is armed, the fail-safe timer SHALL be considered expired... 2. If the commissioning window is still open, the Commissionee SHALL continue listening"
CloseSessionOrNTLSelect ==
    /\ pendingInput \in {"CloseSession", "NTL_SELECT"}
    /\ paseSessionStatus' = "None"
    /\ IF failSafeStatus = "Armed"
       THEN failSafeStatus' = "Expired"
       ELSE failSafeStatus' = failSafeStatus
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningWindowOpen, commissioningPhase, commissioningChannel>>

\* SOURCE: core_5.5 Commissioning Flows
\* "7. Commissioner SHALL re-arm the Fail-safe timer on the Commissionee to the desired commissioning timeout within 60 seconds of the completion of PASE session establishment, using the ArmFailSafe command"
ArmFailSafeCmd ==
    /\ pendingInput = "ArmFailSafe"
    /\ failSafeStatus' = "Armed"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<paseSessionStatus, commissioningWindowOpen, commissioningPhase, commissioningChannel>>

\* SOURCE: core_5.5 Commissioning Flows
\* "16. The Commissioner SHALL trigger the Commissionee to connect to the operational network using ConnectNetwork command... In case the device is not fully powered... fail-safe timer... SHALL be paused... deferred to the setup phase"
\* "In non-concurrent connection commissioning flow the commissioning channel SHALL terminate after successful initial phase step 16... The PASE-derived encryption keys SHALL be deleted when commissioning channel terminates."
ConnectNetworkCmd ==
    /\ pendingInput = "ConnectNetwork"
    /\ commissioningPhase = "Initial"
    /\ IF IsCommissioningWithoutPower
       THEN /\ failSafeStatus' = "Paused"
            /\ commissioningPhase' = "Initial"
       ELSE /\ failSafeStatus' = failSafeStatus
            /\ commissioningPhase' = "Setup"
    /\ IF ~ConcurrentConnectionCap
       THEN /\ commissioningChannel' = "Closed"
            /\ paseSessionStatus' = "None"
       ELSE /\ commissioningChannel' = commissioningChannel
            /\ paseSessionStatus' = paseSessionStatus
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningWindowOpen>>

\* SOURCE: core_5.5 Commissioning Flows
\* "The setup phase of the Commissioning process consists of the following steps: 1. If the device was not fully powered during the initial phase... it SHALL rearm the failsafe timer... and it SHALL connect to the operational network."
PowerIndicationEvt ==
    /\ pendingInput = "PowerIndication"
    /\ commissioningPhase = "Initial"
    /\ failSafeStatus = "Paused"
    /\ failSafeStatus' = "Armed"
    /\ commissioningPhase' = "Setup"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<paseSessionStatus, commissioningWindowOpen, commissioningChannel>>

\* SOURCE: core_5.5 Commissioning Flows
\* "3. The Administrator SHALL open a CASE... session with the Commissionee over the operational network."
CASE_EstablishmentEvt ==
    /\ pendingInput = "CASE_Establishment"
    /\ commissioningPhase = "Setup"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<paseSessionStatus, failSafeStatus, commissioningWindowOpen, commissioningPhase, commissioningChannel>>

\* SOURCE: core_5.5 Commissioning Flows
\* "4. The Administrator having established a CASE session... SHALL invoke the CommissioningComplete command... Successful completion of commissioning SHALL disarm the fail-safe timer."
\* "In concurrent connection commissioning flow the commissioning channel SHALL terminate after successful setup phase step 4 (CommissioningComplete... The PASE session SHALL be terminated by both Commissioner and Commissionee once the CommissioningComplete command is received"
CommissioningCompleteCmd ==
    /\ pendingInput = "CommissioningComplete"
    /\ commissioningPhase = "Setup"
    /\ commissioningPhase' = "Complete"
    /\ failSafeStatus' = "Disarmed"
    /\ paseSessionStatus' = "None"
    /\ IF ConcurrentConnectionCap
       THEN commissioningChannel' = "Closed"
       ELSE commissioningChannel' = commissioningChannel
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissioningWindowOpen>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ AcceptPaseRequest
    \/ RejectPaseRequest
    \/ ReceivePAKE3
    \/ FailPaseEstablishment
    \/ TimeoutPaseEstablishment
    \/ CloseSessionOrNTLSelect
    \/ ArmFailSafeCmd
    \/ ConnectNetworkCmd
    \/ PowerIndicationEvt
    \/ CASE_EstablishmentEvt
    \/ CommissioningCompleteCmd

====