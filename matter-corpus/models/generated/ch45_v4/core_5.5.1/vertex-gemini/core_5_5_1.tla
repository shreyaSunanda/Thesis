---- MODULE core_5_5_1 ----
EXTENDS Naturals

\* Sentinel for no pending event
CONSTANTS NoInput

\* Abstract bounds to keep state space finite
CONSTANTS MaxFailedAttempts \* Spec says 20
CONSTANTS MaxFailSafeTimeout
CONSTANTS MaxBreadcrumb

VARIABLES
    pendingInput,
    inputBreadcrumb,
    inputExpiry,
    inputIsAlternative,
    state,              \* "Idle", "CommissioningMode", "Commissioned"
    flowType,           \* "Concurrent", "NonConcurrent"
    currentPhase,       \* "Initial", "Setup"
    currentStep,        \* Integer representing the logical step (e.g., 1..17)
    failedAttempts,
    isCommissioningWithoutPower,
    failSafeArmed,      \* BOOLEAN
    breadcrumbAttr,
    uncommittedNetworkConfig,
    commandStatus

\* REQUIRED - Explicit list of incoming events
Inputs == {
    "EnterCommissioningMode",
    "PASERequest",
    "AttemptNetworkConfig",
    "RemoveNetworkCommand",
    "CommissioningCompleteCommand",
    "CommandWithBreadcrumbSuccess",
    "CommandWithBreadcrumbFailure",
    "StepFailure",
    "ArmFailSafeCommand",
    "FailSafeTimeout",
    "FactoryReset"
}

Operational == state \in {"CommissioningMode", "Commissioned"}

Init ==
    /\ pendingInput = NoInput
    /\ inputBreadcrumb = 0
    /\ inputExpiry = 0
    /\ inputIsAlternative = FALSE
    /\ state = "Idle"
    \* We allow the module to non-deterministically start in either flow type
    /\ flowType \in {"Concurrent", "NonConcurrent"}
    /\ currentPhase = "Initial"
    /\ currentStep = 2
    /\ failedAttempts = 0
    /\ isCommissioningWithoutPower \in BOOLEAN
    /\ failSafeArmed = FALSE
    /\ breadcrumbAttr = 0
    /\ uncommittedNetworkConfig = FALSE
    /\ commandStatus = "NONE"

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    \* Randomize abstract input data
    /\ inputBreadcrumb' \in 0..MaxBreadcrumb
    /\ inputExpiry' \in 0..MaxFailSafeTimeout
    /\ inputIsAlternative' \in BOOLEAN
    /\ UNCHANGED <<state, flowType, currentPhase, currentStep, failedAttempts, isCommissioningWithoutPower, failSafeArmed, breadcrumbAttr, uncommittedNetworkConfig, commandStatus>>

\* SOURCE: core_5.5.1
HandleEnterCommissioningMode ==
    /\ pendingInput = "EnterCommissioningMode"
    /\ state' = "CommissioningMode"
    /\ failedAttempts' = 0
    /\ commandStatus' = "SUCCESS"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputExpiry, inputIsAlternative, flowType, currentPhase, currentStep, isCommissioningWithoutPower, failSafeArmed, breadcrumbAttr, uncommittedNetworkConfig>>

\* SOURCE: core_5.5.1
HandlePASERequest ==
    /\ pendingInput = "PASERequest"
    /\ IF state = "Commissioned" \/ failSafeArmed = TRUE THEN
           /\ commandStatus' = "IGNORED"
       ELSE
           /\ commandStatus' = "SUCCESS"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputExpiry, inputIsAlternative, state, flowType, currentPhase, currentStep, failedAttempts, isCommissioningWithoutPower, failSafeArmed, breadcrumbAttr, uncommittedNetworkConfig>>

\* SOURCE: core_5.5.1
HandleAttemptNetworkConfig ==
    /\ pendingInput = "AttemptNetworkConfig"
    \* TODO: unspecified - Spec says "the commissioner SHALL revert network configuration changes made as part of the preceding unsuccessful configuration attempt". It does not define Commissionee behavior if the Commissioner violates this requirement. We simply record that a configuration is now uncommitted.
    /\ uncommittedNetworkConfig' = TRUE
    /\ commandStatus' = "SUCCESS"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputExpiry, inputIsAlternative, state, flowType, currentPhase, currentStep, failedAttempts, isCommissioningWithoutPower, failSafeArmed, breadcrumbAttr>>

\* SOURCE: core_5.5.1, core_11.9.7.6
HandleRemoveNetworkCommand ==
    /\ pendingInput = "RemoveNetworkCommand"
    /\ IF failSafeArmed = FALSE THEN
           /\ commandStatus' = "FAILSAFE_REQUIRED"
           /\ uncommittedNetworkConfig' = uncommittedNetworkConfig
       ELSE
           /\ commandStatus' = "SUCCESS"
           /\ uncommittedNetworkConfig' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputExpiry, inputIsAlternative, state, flowType, currentPhase, currentStep, failedAttempts, isCommissioningWithoutPower, failSafeArmed, breadcrumbAttr>>

\* SOURCE: core_5.5.1
HandleCommissioningCompleteCommand ==
    /\ pendingInput = "CommissioningCompleteCommand"
    /\ state' = "Commissioned"
    /\ commandStatus' = "SUCCESS"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputExpiry, inputIsAlternative, flowType, currentPhase, currentStep, failedAttempts, isCommissioningWithoutPower, failSafeArmed, breadcrumbAttr, uncommittedNetworkConfig>>

\* SOURCE: core_5.5.1
HandleCommandWithBreadcrumbSuccess ==
    /\ pendingInput = "CommandWithBreadcrumbSuccess"
    /\ breadcrumbAttr' = inputBreadcrumb
    /\ commandStatus' = "SUCCESS"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputExpiry, inputIsAlternative, state, flowType, currentPhase, currentStep, failedAttempts, isCommissioningWithoutPower, failSafeArmed, uncommittedNetworkConfig>>

\* SOURCE: core_5.5.1
HandleCommandWithBreadcrumbFailure ==
    /\ pendingInput = "CommandWithBreadcrumbFailure"
    /\ commandStatus' = "SUCCESS"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputExpiry, inputIsAlternative, state, flowType, currentPhase, currentStep, failedAttempts, isCommissioningWithoutPower, failSafeArmed, breadcrumbAttr, uncommittedNetworkConfig>>

\* SOURCE: core_5.5.1
HandleStepFailure ==
    /\ pendingInput = "StepFailure"
    /\ LET newFailCount == failedAttempts + 1 IN
       IF newFailCount >= MaxFailedAttempts THEN
           /\ state' = "Idle"
           /\ failedAttempts' = newFailCount
           /\ currentPhase' = "Initial"
           /\ currentStep' = 2
       ELSE
           /\ state' = state
           /\ failedAttempts' = newFailCount
           /\ IF flowType = "Concurrent" THEN
                  IF currentPhase = "Initial" /\ currentStep <= 14 THEN
                      /\ currentPhase' = "Initial"
                      /\ currentStep' = 2
                  ELSE
                      /\ currentPhase' = "Initial"
                      /\ currentStep' = 15
              ELSE
                  IF currentPhase = "Initial" \/ (currentPhase = "Setup" /\ ~isCommissioningWithoutPower) THEN
                      /\ currentPhase' = "Initial"
                      /\ currentStep' = 2
                  ELSE
                      /\ currentPhase' = "Setup"
                      /\ currentStep' = 1
    /\ commandStatus' = "SUCCESS"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputExpiry, inputIsAlternative, flowType, isCommissioningWithoutPower, failSafeArmed, breadcrumbAttr, uncommittedNetworkConfig>>

\* SOURCE: core_5.5.1
HandleArmFailSafeCommand ==
    /\ pendingInput = "ArmFailSafeCommand"
    /\ IF inputExpiry = 0 THEN
           failSafeArmed' = FALSE
       ELSE
           failSafeArmed' = TRUE
    /\ commandStatus' = "SUCCESS"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputExpiry, inputIsAlternative, state, flowType, currentPhase, currentStep, failedAttempts, isCommissioningWithoutPower, breadcrumbAttr, uncommittedNetworkConfig>>

\* SOURCE: core_5.5.1
HandleFailSafeTimeout ==
    /\ pendingInput = "FailSafeTimeout"
    /\ failSafeArmed' = FALSE
    /\ commandStatus' = "SUCCESS"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputExpiry, inputIsAlternative, state, flowType, currentPhase, currentStep, failedAttempts, isCommissioningWithoutPower, breadcrumbAttr, uncommittedNetworkConfig>>

\* SOURCE: core_5.5.1
HandleFactoryReset ==
    /\ pendingInput = "FactoryReset"
    /\ state' = "Idle"
    /\ failSafeArmed' = FALSE
    /\ commandStatus' = "SUCCESS"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBreadcrumb, inputExpiry, inputIsAlternative, flowType, currentPhase, currentStep, failedAttempts, isCommissioningWithoutPower, breadcrumbAttr, uncommittedNetworkConfig>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleEnterCommissioningMode
    \/ HandlePASERequest
    \/ HandleAttemptNetworkConfig
    \/ HandleRemoveNetworkCommand
    \/ HandleCommissioningCompleteCommand
    \/ HandleCommandWithBreadcrumbSuccess
    \/ HandleCommandWithBreadcrumbFailure
    \/ HandleStepFailure
    \/ HandleArmFailSafeCommand
    \/ HandleFailSafeTimeout
    \/ HandleFactoryReset

====