---- MODULE core_5_5 ----
EXTENDS Naturals

\* CONSTANTS mapping to device capabilities and fixed thresholds described in the spec text.
CONSTANTS 
    \* Indicates whether the device supports "concurrent connection flow" (Section 5.5).
    ConcurrentConnectionSupported,
    \* Indicates whether the device supports NFC-based commissioning.
    NFCCommissioningSupported

VARIABLES 
    \* Represents whether the commissioning window is open for accepting PASE requests.
    commissioningWindowOpen,
    \* Tracks the PASE session establishment state: "None", "Establishing", or "Established".
    paseSessionStatus,
    \* Tracks the overall phase of the commissioning process: "None", "Initial", "Setup", "Complete", or "Failed".
    commissioningPhase,
    \* Tracks progress through the 17 steps of the initial commissioning phase.
    initialStep,
    \* Tracks progress through the 4 steps of the setup commissioning phase.
    setupStep,
    \* Tracks the state of the fail-safe timer: "Disarmed", "Armed", "Paused", or "Expired".
    failsafeStatus,
    \* Indicates if the Cumulative Fail Safe Context timer is paused due to power configuration constraints.
    cumulativeContextTimerPaused,
    \* Reflects the IsCommissioningWithoutPower attribute. True if the device currently lacks power to join operational network.
    isCommissioningWithoutPower,
    \* Tracks the commissioning communication channel state: "Closed" or "Open".
    commChannelState

Init == 
    /\ commissioningWindowOpen \in {TRUE, FALSE}
    /\ paseSessionStatus = "None"
    /\ commissioningPhase = "None"
    /\ initialStep = 0
    /\ setupStep = 0
    /\ failsafeStatus = "Disarmed"
    /\ cumulativeContextTimerPaused = FALSE
    /\ isCommissioningWithoutPower \in {TRUE, FALSE}
    /\ commChannelState = "Closed"

\* SOURCE: core_5.5 Commissioning Flows
\* "A Commissionee that is ready to be commissioned SHALL accept the request to establish a PASE session with the first Commissioner that initiates the request."
ReceivePASERequest ==
    /\ paseSessionStatus = "None"
    /\ commissioningWindowOpen = TRUE
    /\ paseSessionStatus' = "Establishing"
    /\ UNCHANGED << commissioningPhase, initialStep, setupStep, failsafeStatus, cumulativeContextTimerPaused, isCommissioningWithoutPower, commChannelState, commissioningWindowOpen >>

\* SOURCE: core_5.5 Commissioning Flows
\* "When a Commissioner is either in the process of establishing a PASE session with the Commissionee or has successfully established a session, the Commissionee SHALL NOT accept any more requests for new PASE sessions"
RejectPASERequest ==
    /\ paseSessionStatus \in {"Establishing", "Established"}
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, commissioningPhase, initialStep, setupStep, failsafeStatus, cumulativeContextTimerPaused, isCommissioningWithoutPower, commChannelState >>

\* SOURCE: core_5.5 Commissioning Flows
\* "Commissionee SHALL expect a PASE session to be established within 60 seconds of receiving the initial request. ... If the PASE session is not established within the expected time window the Commissionee SHALL terminate the current session establishment using the INVALID_PARAMETER status code"
PASEEstablishmentTimeout ==
    /\ paseSessionStatus = "Establishing"
    /\ paseSessionStatus' = "None"
    /\ UNCHANGED << commissioningWindowOpen, commissioningPhase, initialStep, setupStep, failsafeStatus, cumulativeContextTimerPaused, isCommissioningWithoutPower, commChannelState >>

\* SOURCE: core_5.5 Commissioning Flows
\* "until one of the following events occurs: session establishment fails"
PASEEstablishmentFail ==
    /\ paseSessionStatus = "Establishing"
    /\ paseSessionStatus' = "None"
    /\ UNCHANGED << commissioningWindowOpen, commissioningPhase, initialStep, setupStep, failsafeStatus, cumulativeContextTimerPaused, isCommissioningWithoutPower, commChannelState >>

\* SOURCE: core_5.5 Commissioning Flows
\* "6. Commissioner and Commissionee SHALL establish encryption keys with PASE... Upon completion of PASE session establishment, the Commissionee SHALL autonomously arm the Fail-safe timer for a timeout of 60 seconds."
CompletePASEEstablishment ==
    /\ paseSessionStatus = "Establishing"
    /\ paseSessionStatus' = "Established"
    /\ failsafeStatus' = "Armed"
    /\ commissioningPhase' = "Initial"
    /\ initialStep' = 6
    /\ commChannelState' = "Open"
    /\ UNCHANGED << commissioningWindowOpen, setupStep, cumulativeContextTimerPaused, isCommissioningWithoutPower >>

\* SOURCE: core_5.5 Commissioning Flows
\* "Unless indicated otherwise, a commissioner SHALL complete a step, including waiting for any responses to commands it sends in that step, before moving on to the next step."
\* This models the sequential progression of steps 7 through 14 (re-arming failsafe, reg config, TC, attestation, CSR, NOC, ACL).
InitialPhaseSteps ==
    /\ commissioningPhase = "Initial"
    /\ initialStep \in {6, 7, 8, 9, 10, 11, 12, 13, 14}
    /\ initialStep' = initialStep + 1
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, commissioningPhase, setupStep, failsafeStatus, cumulativeContextTimerPaused, isCommissioningWithoutPower, commChannelState >>

\* SOURCE: core_5.5 Commissioning Flows
\* "If the Commissionee fails the Device Attestation Procedure, for any reason, the Commissioner MAY choose to either continue to the Commissioning, or terminate it, depending on implementation-dependent policies."
InitialPhaseAttestationFail ==
    /\ commissioningPhase = "Initial"
    /\ initialStep = 10
    /\ commissioningPhase' = "Failed"
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, initialStep, setupStep, failsafeStatus, cumulativeContextTimerPaused, isCommissioningWithoutPower, commChannelState >>

\* SOURCE: core_5.5 Commissioning Flows
\* "16. The Commissioner SHALL trigger the Commissionee to connect to the operational network... In case the device is not fully powered ... fail-safe timer and the Cumulative Fail Safe Context timer countdown SHALL be paused, and the connection ... deferred to the setup phase"
\* "In non-concurrent connection commissioning flow the commissioning channel SHALL terminate after successful initial phase step 16"
InitialPhaseConnectNetwork ==
    /\ commissioningPhase = "Initial"
    /\ initialStep = 15
    /\ initialStep' = 16
    /\ failsafeStatus' = (IF isCommissioningWithoutPower THEN "Paused" ELSE failsafeStatus)
    /\ cumulativeContextTimerPaused' = (IF isCommissioningWithoutPower THEN TRUE ELSE cumulativeContextTimerPaused)
    /\ commChannelState' = (IF ~ConcurrentConnectionSupported THEN "Closed" ELSE commChannelState)
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, commissioningPhase, setupStep, isCommissioningWithoutPower >>

\* SOURCE: core_5.5 Commissioning Flows
\* "17. If the IsCommissioningWithoutPower attribute is true, the Commissioner SHALL wait for an indication that the commissionee is in a power configuration that is capable of joining"
\* "If the device was fully powered ... then the setup phase SHALL happen immediately after the end of the initial phase, else the setup phase shall start as soon as the device is powered up and running."
InitialPhaseEnd_To_SetupPhase ==
    /\ commissioningPhase = "Initial"
    /\ initialStep = 16
    /\ isCommissioningWithoutPower = FALSE
    /\ commissioningPhase' = "Setup"
    /\ setupStep' = 1
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, initialStep, failsafeStatus, cumulativeContextTimerPaused, commChannelState, isCommissioningWithoutPower >>

\* SOURCE: core_5.5 Commissioning Flows
\* "... else the setup phase shall start as soon as the device is powered up and running."
ApplyPower ==
    /\ isCommissioningWithoutPower = TRUE
    /\ isCommissioningWithoutPower' = FALSE
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, commissioningPhase, initialStep, setupStep, failsafeStatus, cumulativeContextTimerPaused, commChannelState >>

\* SOURCE: core_5.5 Commissioning Flows
\* "1. If the device was not fully powered during the initial phase of the Commissioning process then it SHALL rearm the failsafe timer and the Cumulative Fail Safe Context timer countdowns with the remaining times ... and it SHALL connect to the operational network."
SetupPhaseStep1 ==
    /\ commissioningPhase = "Setup"
    /\ setupStep = 1
    /\ failsafeStatus' = "Armed"
    /\ cumulativeContextTimerPaused' = FALSE
    /\ setupStep' = 2
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, commissioningPhase, initialStep, isCommissioningWithoutPower, commChannelState >>

\* SOURCE: core_5.5 Commissioning Flows
\* "2. The Commissionee SHALL use Section 4.3.2, “Operational Discovery” to be discoverable ... If the device was not fully powered ... the Commissionee MAY pause the fail-safe timer and the Cumulative Fail Safe Context timer countdown until the Administrator discovers the Commissionee"
SetupPhaseStep2_OperationalDiscovery ==
    /\ commissioningPhase = "Setup"
    /\ setupStep = 2
    /\ setupStep' = 3
    /\ \E pauseChoice \in {TRUE, FALSE}:
        /\ failsafeStatus' = (IF pauseChoice THEN "Paused" ELSE failsafeStatus)
        /\ cumulativeContextTimerPaused' = (IF pauseChoice THEN TRUE ELSE cumulativeContextTimerPaused)
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, commissioningPhase, initialStep, isCommissioningWithoutPower, commChannelState >>

\* SOURCE: core_5.5 Commissioning Flows
\* "3. The Administrator SHALL open a CASE ... session with the Commissionee over the operational network."
SetupPhaseStep3_CASE ==
    /\ commissioningPhase = "Setup"
    /\ setupStep = 3
    /\ setupStep' = 4
    /\ failsafeStatus' = "Armed"  \* Un-pause failsafe when CASE session opened
    /\ cumulativeContextTimerPaused' = FALSE
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, commissioningPhase, initialStep, isCommissioningWithoutPower, commChannelState >>

\* SOURCE: core_5.5 Commissioning Flows
\* "4. The Administrator ... SHALL invoke the CommissioningComplete command. A success response ... ends the commissioning process ... Successful completion of commissioning SHALL disarm the fail-safe timer."
\* "In concurrent connection commissioning flow the commissioning channel SHALL terminate after successful setup phase step 4"
\* "The PASE session SHALL be terminated by both Commissioner and Commissionee once the CommissioningComplete command is received by the Commissionee."
SetupPhaseStep4_CommissioningComplete ==
    /\ commissioningPhase = "Setup"
    /\ setupStep = 4
    /\ commissioningPhase' = "Complete"
    /\ failsafeStatus' = "Disarmed"
    /\ paseSessionStatus' = "None"
    /\ commChannelState' = "Closed"
    /\ UNCHANGED << commissioningWindowOpen, initialStep, setupStep, cumulativeContextTimerPaused, isCommissioningWithoutPower >>

\* SOURCE: core_5.5 Commissioning Flows
\* "In the event a CloseSession status message is sent or received, or whenever commissioning through NFC ... is interrupted by SELECT command : 1. If the fail-safe timer is armed, the fail-safe timer SHALL be considered expired ... 2. If the commissioning window is still open, the Commissionee SHALL continue listening"
CloseSessionOrNFCInterrupt ==
    /\ paseSessionStatus = "Established"
    /\ paseSessionStatus' = "None"
    /\ commChannelState' = "Closed"
    /\ failsafeStatus' = (IF failsafeStatus = "Armed" THEN "Expired" ELSE failsafeStatus)
    /\ commissioningPhase' = "Failed"
    /\ UNCHANGED << commissioningWindowOpen, initialStep, setupStep, cumulativeContextTimerPaused, isCommissioningWithoutPower >>

\* SOURCE: core_5.5 Commissioning Flows
\* "If the fail-safe timer expires prior to commissioning completion, the Commissioner and Commissionee SHALL behave as specified in Section 11.10.7.2.2 ... Successful completion ... SHALL disarm"
FailsafeExpire ==
    /\ failsafeStatus = "Armed"
    /\ failsafeStatus' = "Expired"
    /\ commissioningPhase' = "Failed"
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, initialStep, setupStep, cumulativeContextTimerPaused, isCommissioningWithoutPower, commChannelState >>

\* SOURCE: core_5.5 Commissioning Flows
\* "the Commissionee, when using NFC-based commissioning, MAY reject attribute writes for clusters used during the initial phase of commissioning, therefore the Commissioner SHALL handle these errors"
NFCRejectAttributeWrite ==
    /\ NFCCommissioningSupported = TRUE
    /\ commissioningPhase = "Initial"
    /\ UNCHANGED << commissioningWindowOpen, paseSessionStatus, commissioningPhase, initialStep, setupStep, failsafeStatus, cumulativeContextTimerPaused, isCommissioningWithoutPower, commChannelState >>

Next ==
    \/ ReceivePASERequest
    \/ RejectPASERequest
    \/ PASEEstablishmentTimeout
    \/ PASEEstablishmentFail
    \/ CompletePASEEstablishment
    \/ InitialPhaseSteps
    \/ InitialPhaseAttestationFail
    \/ InitialPhaseConnectNetwork
    \/ InitialPhaseEnd_To_SetupPhase
    \/ ApplyPower
    \/ SetupPhaseStep1
    \/ SetupPhaseStep2_OperationalDiscovery
    \/ SetupPhaseStep3_CASE
    \/ SetupPhaseStep4_CommissioningComplete
    \/ CloseSessionOrNFCInterrupt
    \/ FailsafeExpire
    \/ NFCRejectAttributeWrite

====