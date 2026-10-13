---- MODULE core_5_5 ----
EXTENDS Naturals

\* Device configurations determining commissioning flow behavior
CONSTANTS IsCommissioningWithoutPower
CONSTANTS SupportsConcurrentConnection

\* MANDATORY INPUT SHAPE
CONSTANTS NoInput, Inputs
VARIABLES pendingInput

\* Internal state variables
VARIABLES commissioningPhase       \* "None", "Initial", "Deferred", "Setup", "Complete"
VARIABLES paseSessionStatus        \* "None", "Establishing", "Established"
VARIABLES failSafeArmed            \* BOOLEAN
VARIABLES failSafePaused           \* BOOLEAN
VARIABLES commissioningWindowOpen  \* BOOLEAN
VARIABLES concurrentChannelActive  \* BOOLEAN

Init ==
    /\ pendingInput = NoInput
    /\ commissioningPhase = "None"
    /\ paseSessionStatus = "None"
    /\ failSafeArmed = FALSE
    /\ failSafePaused = FALSE
    /\ commissioningWindowOpen = TRUE
    /\ concurrentChannelActive = FALSE

\* SOURCE: core_5.5 Mandatory input receiver
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED << commissioningPhase, paseSessionStatus, failSafeArmed, failSafePaused, commissioningWindowOpen, concurrentChannelActive >>

\* SOURCE: core_5.5 - "A Commissionee that is ready to be commissioned SHALL accept the request to establish a PASE session... SHALL NOT accept any more requests for new PASE sessions until..."
HandlePASE_PBKDFParamRequest ==
    /\ pendingInput = "PASE_PBKDFParamRequest"
    /\ pendingInput' = NoInput
    /\ IF paseSessionStatus = "None" THEN
           /\ paseSessionStatus' = "Establishing"
           /\ concurrentChannelActive' = TRUE
           /\ UNCHANGED << commissioningPhase, failSafeArmed, failSafePaused, commissioningWindowOpen >>
       ELSE
           /\ UNCHANGED << paseSessionStatus, concurrentChannelActive, commissioningPhase, failSafeArmed, failSafePaused, commissioningWindowOpen >>

\* SOURCE: core_5.5 - "Upon completion of PASE session establishment, the Commissionee SHALL autonomously arm the Fail-safe timer for a timeout of 60 seconds."
HandlePASE_PAKE3 ==
    /\ pendingInput = "PASE_PAKE3"
    /\ pendingInput' = NoInput
    /\ IF paseSessionStatus = "Establishing" THEN
           /\ paseSessionStatus' = "Established"
           /\ failSafeArmed' = TRUE
           /\ commissioningPhase' = "Initial"
           /\ UNCHANGED << failSafePaused, commissioningWindowOpen, concurrentChannelActive >>
       ELSE
           /\ UNCHANGED << paseSessionStatus, failSafeArmed, commissioningPhase, failSafePaused, commissioningWindowOpen, concurrentChannelActive >>

\* SOURCE: core_5.5 - "...until one of the following events occurs: session establishment fails..."
HandlePASE_Fail ==
    /\ pendingInput = "PASE_Fail"
    /\ pendingInput' = NoInput
    /\ paseSessionStatus' = "None"
    /\ concurrentChannelActive' = FALSE
    /\ UNCHANGED << failSafeArmed, failSafePaused, commissioningPhase, commissioningWindowOpen >>

\* SOURCE: core_5.5 - "...Commissionee SHALL expect to receive the PAKE3 message within 60 seconds... If the PASE session is not established within the expected time window the Commissionee SHALL terminate the current session establishment"
HandlePASE_60s_Timeout ==
    /\ pendingInput = "PASE_60s_Timeout"
    /\ pendingInput' = NoInput
    /\ IF paseSessionStatus = "Establishing" THEN
           /\ paseSessionStatus' = "None"
           /\ concurrentChannelActive' = FALSE
           /\ UNCHANGED << failSafeArmed, failSafePaused, commissioningPhase, commissioningWindowOpen >>
       ELSE
           /\ UNCHANGED << paseSessionStatus, concurrentChannelActive, failSafeArmed, failSafePaused, commissioningPhase, commissioningWindowOpen >>

\* SOURCE: core_5.5 - "...the successfully established PASE session is terminated... or the PASE session is established through NFC Transport Layer (NTL) and Commissionee receives a valid SELECT command... fail-safe timer SHALL be considered expired"
HandleSessionClose_or_NFC_SELECT ==
    /\ pendingInput \in {"CloseSession", "NFC_SELECT"}
    /\ pendingInput' = NoInput
    /\ failSafeArmed' = FALSE
    /\ failSafePaused' = FALSE
    /\ commissioningPhase' = "None"
    /\ paseSessionStatus' = "None"
    /\ concurrentChannelActive' = FALSE
    /\ UNCHANGED << commissioningWindowOpen >>

\* SOURCE: core_5.5 - "Commissioner SHALL re-arm the Fail-safe timer on the Commissionee to the desired commissioning timeout within 60 seconds of the completion of PASE session establishment"
HandleArmFailSafe ==
    /\ pendingInput = "ArmFailSafe"
    /\ pendingInput' = NoInput
    /\ IF commissioningPhase = "Initial" THEN
           /\ failSafeArmed' = TRUE
           /\ UNCHANGED << paseSessionStatus, failSafePaused, commissioningPhase, commissioningWindowOpen, concurrentChannelActive >>
       ELSE
           /\ UNCHANGED << paseSessionStatus, failSafeArmed, failSafePaused, commissioningPhase, commissioningWindowOpen, concurrentChannelActive >>

\* SOURCE: core_5.5 - General progression of commands during the Initial and Setup phases.
\* These commands progress the state machine implicitly, but do not dictate specific transition variables at this abstraction level.
HandleRoutineCommands ==
    /\ pendingInput \in {
           "SetRegulatoryConfig", "SetTCAcknowledgements", "CSRRequest",
           "AddTrustedRootCertificate", "AddNOC", "UpdateFabricLabel",
           "ScanNetworks", "AddOrUpdateWiFiNetwork", "AddOrUpdateThreadNetwork",
           "CASE_Connected"
       }
    /\ pendingInput' = NoInput
    /\ UNCHANGED << commissioningPhase, paseSessionStatus, failSafeArmed, failSafePaused, commissioningWindowOpen, concurrentChannelActive >>

\* SOURCE: core_5.5 - "The Commissioner SHALL trigger the Commissionee to connect to the operational network using ConnectNetwork command... In case the device is not fully powered... the fail-safe timer... SHALL be paused, and the connection to the operational network SHALL be deferred to the setup phase"
\* SOURCE: core_5.5 - "In non-concurrent connection commissioning flow the commissioning channel SHALL terminate after successful initial phase step 16"
HandleConnectNetwork ==
    /\ pendingInput = "ConnectNetwork"
    /\ pendingInput' = NoInput
    /\ IF commissioningPhase = "Initial" THEN
           IF IsCommissioningWithoutPower THEN
               /\ commissioningPhase' = "Deferred"
               /\ failSafePaused' = TRUE
               /\ UNCHANGED << concurrentChannelActive, paseSessionStatus, failSafeArmed, commissioningWindowOpen >>
           ELSE
               /\ commissioningPhase' = "Setup"
               /\ failSafePaused' = FALSE
               /\ IF ~SupportsConcurrentConnection THEN
                      /\ concurrentChannelActive' = FALSE
                  ELSE
                      /\ UNCHANGED << concurrentChannelActive >>
               /\ UNCHANGED << paseSessionStatus, failSafeArmed, commissioningWindowOpen >>
       ELSE
           /\ UNCHANGED << commissioningPhase, failSafePaused, concurrentChannelActive, paseSessionStatus, failSafeArmed, commissioningWindowOpen >>

\* SOURCE: core_5.5 - "The setup phase of the Commissioning process consists of the following steps: 1. If the device was not fully powered... it SHALL rearm the failsafe timer... and it SHALL connect to the operational network."
HandlePowerAvailable ==
    /\ pendingInput = "PowerAvailable"
    /\ pendingInput' = NoInput
    /\ IF commissioningPhase = "Deferred" THEN
           /\ commissioningPhase' = "Setup"
           /\ failSafePaused' = FALSE
           /\ IF ~SupportsConcurrentConnection THEN
                  /\ concurrentChannelActive' = FALSE
              ELSE
                  /\ UNCHANGED << concurrentChannelActive >>
           /\ UNCHANGED << paseSessionStatus, failSafeArmed, commissioningWindowOpen >>
       ELSE
           /\ UNCHANGED << commissioningPhase, failSafePaused, concurrentChannelActive, paseSessionStatus, failSafeArmed, commissioningWindowOpen >>

\* SOURCE: core_5.5 - "A success response after invocation of the CommissioningComplete command ends the commissioning process... Successful completion of commissioning SHALL disarm the fail-safe timer."
\* SOURCE: core_5.5 - "In concurrent connection commissioning flow the commissioning channel SHALL terminate after successful setup phase step 4"
\* SOURCE: core_5.5 - "The PASE session SHALL be terminated by both Commissioner and Commissionee once the CommissioningComplete command is received"
HandleCommissioningComplete ==
    /\ pendingInput = "CommissioningComplete"
    /\ pendingInput' = NoInput
    /\ IF commissioningPhase = "Setup" THEN
           /\ commissioningPhase' = "Complete"
           /\ failSafeArmed' = FALSE
           /\ paseSessionStatus' = "None"
           /\ concurrentChannelActive' = FALSE
           /\ UNCHANGED << failSafePaused, commissioningWindowOpen >>
       ELSE
           /\ UNCHANGED << commissioningPhase, failSafeArmed, paseSessionStatus, concurrentChannelActive, failSafePaused, commissioningWindowOpen >>

\* SOURCE: core_5.5 - "If the fail-safe timer expires prior to commissioning completion... cleanup steps... SHALL be executed."
HandleFailSafeExpired ==
    /\ pendingInput = "FailSafe_Expired"
    /\ pendingInput' = NoInput
    /\ failSafeArmed' = FALSE
    /\ failSafePaused' = FALSE
    /\ commissioningPhase' = "None"
    /\ paseSessionStatus' = "None"
    /\ concurrentChannelActive' = FALSE
    /\ UNCHANGED << commissioningWindowOpen >>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandlePASE_PBKDFParamRequest
    \/ HandlePASE_PAKE3
    \/ HandlePASE_Fail
    \/ HandlePASE_60s_Timeout
    \/ HandleSessionClose_or_NFC_SELECT
    \/ HandleArmFailSafe
    \/ HandleRoutineCommands
    \/ HandleConnectNetwork
    \/ HandlePowerAvailable
    \/ HandleCommissioningComplete
    \/ HandleFailSafeExpired

====