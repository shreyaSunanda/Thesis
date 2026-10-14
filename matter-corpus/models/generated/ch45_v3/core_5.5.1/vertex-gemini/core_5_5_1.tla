---- MODULE core_5_5_1 ----
EXTENDS Naturals

\* Timeout for cluster operations while fail-safe is armed (30 seconds).
CONSTANTS MinTimeoutSeconds

\* Maximum number of failed commissioning attempts before exiting Commissioning Mode (20).
CONSTANTS MaxFailedAttempts

\* Sentinel for no pending event.
CONSTANTS NoInput

VARIABLES
    pendingInput,
    inputBreadcrumb,
    inputWaitTime,
    inputExpiryLength,
    breadcrumb,
    networkNeedsRevert,
    currentStep,
    failedAttempts,
    commissioningMode,
    acceptingPASE,
    failSafeArmed

Inputs == {
    "NetworkConfigAttemptFailed",
    "RemoveNetwork",
    "ConfigAlternativeNetwork",
    "CommandWithBreadcrumbSuccess",
    "CommandWithBreadcrumbFailure",
    "ConcurrentStep2to14Failed",
    "ConcurrentStep15toSetup4Failed",
    "NonConcurrentStep2to17Failed",
    "NonConcurrentSetup1to4Failed_Power",
    "NonConcurrentSetup1to4Failed_NoPower",
    "ArmFailSafe",
    "FailSafeExpired",
    "CommissioningComplete",
    "FactoryReset",
    "EnterCommissioningMode",
    "ClusterOperationTimeout",
    "PASERequest"
}

Init ==
    /\ pendingInput = NoInput
    /\ inputBreadcrumb = 0
    /\ inputWaitTime = 0
    /\ inputExpiryLength = 0
    /\ breadcrumb = 0
    /\ networkNeedsRevert = FALSE
    /\ currentStep = "Step2"
    /\ failedAttempts = 0
    /\ commissioningMode = TRUE
    /\ acceptingPASE = TRUE
    /\ failSafeArmed = FALSE

ReceiveInput(e, bc, wt, el) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ inputBreadcrumb' = bc
    /\ inputWaitTime' = wt
    /\ inputExpiryLength' = el
    /\ UNCHANGED <<breadcrumb, networkNeedsRevert, currentStep, failedAttempts, commissioningMode, acceptingPASE, failSafeArmed>>

\* SOURCE: core_5.5.1 "If the initial attempt fails for networking-related reasons, then the Commissioner SHOULD attempt to configure secondary network interfaces... Before attempting to configure any such alternative interface, the commissioner SHALL revert network configuration changes"
NetworkConfigAttemptFailed ==
    /\ pendingInput = "NetworkConfigAttemptFailed"
    /\ networkNeedsRevert' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, currentStep, failedAttempts, commissioningMode, acceptingPASE, failSafeArmed>>

\* SOURCE: core_5.5.1 "...specifically the Section 11.9.7.6, “RemoveNetwork” command SHALL be used to remove any Thread or Wi-Fi network configurations added by such an unsuccessful attempt."
RemoveNetwork ==
    /\ pendingInput = "RemoveNetwork"
    /\ networkNeedsRevert' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, currentStep, failedAttempts, commissioningMode, acceptingPASE, failSafeArmed>>

\* SOURCE: core_5.5.1 "Before attempting to configure any such alternative interface, the commissioner SHALL revert network configuration changes made as part of the preceding unsuccessful configuration attempt"
ConfigAlternativeNetwork ==
    /\ pendingInput = "ConfigAlternativeNetwork"
    /\ networkNeedsRevert = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, currentStep, failedAttempts, commissioningMode, acceptingPASE, failSafeArmed>>

\* SOURCE: core_5.5.1 "Some request commands used for Commissioning and administration have a 'Breadcrumb' argument. When set, this argument SHALL be used to update the value of the Breadcrumb Attribute as a side-effect of successful execution of those commands."
CommandWithBreadcrumbSuccess ==
    /\ pendingInput = "CommandWithBreadcrumbSuccess"
    /\ breadcrumb' = inputBreadcrumb
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, networkNeedsRevert, currentStep, failedAttempts, commissioningMode, acceptingPASE, failSafeArmed>>

\* SOURCE: core_5.5.1 "On command failures, the Breadcrumb Attribute SHALL remain unchanged."
CommandWithBreadcrumbFailure ==
    /\ pendingInput = "CommandWithBreadcrumbFailure"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, currentStep, failedAttempts, commissioningMode, acceptingPASE, failSafeArmed>>

ProcessFailure(targetStep, paseChange) ==
    /\ failedAttempts < MaxFailedAttempts
    /\ failedAttempts' = failedAttempts + 1
    /\ commissioningMode' = ((failedAttempts + 1) < MaxFailedAttempts)
    /\ currentStep' = IF (failedAttempts + 1) < MaxFailedAttempts THEN targetStep ELSE "None"
    /\ acceptingPASE' = IF paseChange /\ ((failedAttempts + 1) < MaxFailedAttempts) THEN FALSE ELSE acceptingPASE

\* SOURCE: core_5.5.1 "In concurrent connection commissioning flow, the failure of any of the steps from initial phase step 2 through 14 SHALL result in the Commissioner and Commissionee returning to initial phase step 2 (device discovery and commissioning channel establishment) and repeating each step."
ConcurrentStep2to14Failed ==
    /\ pendingInput = "ConcurrentStep2to14Failed"
    /\ ProcessFailure("Step2", TRUE)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, failSafeArmed>>

\* SOURCE: core_5.5.1 "The failure of any of the steps from initial phase step 15 through setup phase step 4 in concurrent connection commissioning flow SHALL result in the Commissioner and Commissionee returning to initial phase step 15... SHALL reuse the existing PASE-derived encryption keys"
ConcurrentStep15toSetup4Failed ==
    /\ pendingInput = "ConcurrentStep15toSetup4Failed"
    /\ ProcessFailure("Step15", FALSE)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, failSafeArmed>>

\* SOURCE: core_5.5.1 "In non-concurrent connection commissioning flow, the failure of any of the steps from initial phase step 2 through 17 SHALL result in the Commissioner and Commissionee returning to initial phase step 2..."
NonConcurrentStep2to17Failed ==
    /\ pendingInput = "NonConcurrentStep2to17Failed"
    /\ ProcessFailure("Step2", TRUE)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, failSafeArmed>>

\* SOURCE: core_5.5.1 "In case IsCommissioningWithoutPower attribute was false in initial phase step 17 the failure of any of steps from setup phase step 1 through 4 SHALL result in the Commissioner and Commissionee returning to initial phase step 2..."
NonConcurrentSetup1to4Failed_Power ==
    /\ pendingInput = "NonConcurrentSetup1to4Failed_Power"
    /\ ProcessFailure("Step2", TRUE)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, failSafeArmed>>

\* SOURCE: core_5.5.1 "In case IsCommissioningWithoutPower attribute was true in initial phase step 17, the failure of any of the steps from setup phase step 1 through 4 SHALL result in the Commissioner and Commissionee returning to setup phase step 1..."
NonConcurrentSetup1to4Failed_NoPower ==
    /\ pendingInput = "NonConcurrentSetup1to4Failed_NoPower"
    /\ ProcessFailure("Setup1", FALSE)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, failSafeArmed>>

\* SOURCE: core_5.5.1 "Commissioners that need to restart from initial phase step 2 MAY immediately expire the fail-safe by invoking the ArmFailSafe command with an ExpiryLengthSeconds field set to 0."
ArmFailSafe ==
    /\ pendingInput = "ArmFailSafe"
    /\ IF inputExpiryLength = 0 THEN
           /\ failSafeArmed' = FALSE
           /\ acceptingPASE' = IF commissioningMode THEN TRUE ELSE FALSE
       ELSE
           /\ failSafeArmed' = TRUE
           /\ acceptingPASE' = acceptingPASE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, currentStep, failedAttempts, commissioningMode>>

\* SOURCE: core_5.5.1 "Otherwise, Commissioners will need to wait until the current fail-safe timer has expired for the Commissionee to begin accepting PASE again."
FailSafeExpired ==
    /\ pendingInput = "FailSafeExpired"
    /\ failSafeArmed' = FALSE
    /\ acceptingPASE' = IF commissioningMode THEN TRUE ELSE FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, currentStep, failedAttempts, commissioningMode>>

\* SOURCE: core_5.5.1 "Once a Commissionee has been successfully commissioned by a Commissioner into its fabric, the commissioned Node SHALL NOT accept any more PASE requests until any one of the following conditions is met..."
CommissioningComplete ==
    /\ pendingInput = "CommissioningComplete"
    /\ commissioningMode' = FALSE
    /\ acceptingPASE' = FALSE
    /\ currentStep' = "Commissioned"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, failedAttempts, failSafeArmed>>

\* SOURCE: core_5.5.1 "Device is factory-reset."
FactoryReset ==
    /\ pendingInput = "FactoryReset"
    /\ acceptingPASE' = TRUE
    /\ commissioningMode' = TRUE
    /\ failedAttempts' = 0
    /\ currentStep' = "Step2"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, failSafeArmed>>

\* SOURCE: core_5.5.1 "Device enters commissioning mode."
EnterCommissioningMode ==
    /\ pendingInput = "EnterCommissioningMode"
    /\ acceptingPASE' = TRUE
    /\ commissioningMode' = TRUE
    /\ failedAttempts' = 0
    /\ currentStep' = "Step2"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, failSafeArmed>>

\* SOURCE: core_5.5.1 "Whenever the Fail-Safe timer is armed, Commissioners and Administrators SHALL NOT consider any cluster operation to have timed-out before waiting at least 30 seconds"
ClusterOperationTimeout ==
    /\ pendingInput = "ClusterOperationTimeout"
    /\ failSafeArmed => (inputWaitTime >= MinTimeoutSeconds)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, currentStep, failedAttempts, commissioningMode, acceptingPASE, failSafeArmed>>

\* SOURCE: core_5.5.1 "Once a Commissionee has been successfully commissioned by a Commissioner into its fabric, the commissioned Node SHALL NOT accept any more PASE requests until any one of the following conditions is met"
HandlePASERequest ==
    /\ pendingInput = "PASERequest"
    /\ acceptingPASE = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputWaitTime, inputExpiryLength, breadcrumb, networkNeedsRevert, currentStep, failedAttempts, commissioningMode, acceptingPASE, failSafeArmed>>

Next ==
    \/ (\E e \in Inputs : \E bc \in {0, 1} : \E wt \in {0, 30} : \E el \in {0, 60} : ReceiveInput(e, bc, wt, el))
    \/ NetworkConfigAttemptFailed
    \/ RemoveNetwork
    \/ ConfigAlternativeNetwork
    \/ CommandWithBreadcrumbSuccess
    \/ CommandWithBreadcrumbFailure
    \/ ConcurrentStep2to14Failed
    \/ ConcurrentStep15toSetup4Failed
    \/ NonConcurrentStep2to17Failed
    \/ NonConcurrentSetup1to4Failed_Power
    \/ NonConcurrentSetup1to4Failed_NoPower
    \/ ArmFailSafe
    \/ FailSafeExpired
    \/ CommissioningComplete
    \/ FactoryReset
    \/ EnterCommissioningMode
    \/ ClusterOperationTimeout
    \/ HandlePASERequest

====