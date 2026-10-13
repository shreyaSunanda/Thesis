---- MODULE core_5_5_1 ----
EXTENDS Naturals

\* Limit on failed attempts before exiting commissioning mode (20 per spec).
CONSTANTS MaxFailedAttempts

\* Available network identifiers to attempt configuration.
CONSTANTS Networks

\* Sentinel value denoting no network configuration is currently pending.
CONSTANTS None

\* Breadcrumb limit to keep the state space finite for checking.
CONSTANTS MaxBreadcrumb

\* Identifiers for the two major commissioning flow types.
CONSTANTS ConcurrentFlow, NonConcurrentFlow

\* Commissioning phase indicators mapping to step sequences from the spec.
CONSTANTS Phase_Init_2_14,
          Phase_Init_15,
          Phase_Init_16_17,
          Phase_Setup_1_4,
          Phase_Commissioned

\* Identifiers for the Fail-Safe timer state.
CONSTANTS State_Armed,
          State_Expired

VARIABLES 
    flowType,
    currentStep,
    failedAttempts,
    commissioningMode,
    acceptingPASE,
    isCommissioningWithoutPower,
    failSafeState,
    breadcrumb,
    networkConfigs,
    pendingNetworkConfig

Init ==
    /\ flowType \in {ConcurrentFlow, NonConcurrentFlow}
    /\ currentStep = Phase_Init_2_14
    /\ failedAttempts = 0
    /\ commissioningMode = TRUE
    /\ acceptingPASE = TRUE
    /\ isCommissioningWithoutPower \in BOOLEAN
    /\ failSafeState = State_Armed
    /\ breadcrumb = 0
    /\ networkConfigs = {}
    /\ pendingNetworkConfig = None

\* SOURCE: core_5.5.1 In both concurrent connection commissioning flow and non-concurrent connection commissioning flow, the Commissionee SHALL exit Commissioning Mode after 20 failed attempts.
NextFailState ==
    IF failedAttempts + 1 >= MaxFailedAttempts THEN
        [fails |-> MaxFailedAttempts, mode |-> FALSE]
    ELSE
        [fails |-> failedAttempts + 1, mode |-> commissioningMode]

\* SOURCE: core_5.5.1 If a Commissionee requires network commissioning, the Commissioner SHOULD attempt to configure the primary network interface ... If the initial attempt fails ... attempt to configure secondary network interfaces
AttemptNetworkConfig ==
    \E netId \in Networks :
        /\ commissioningMode = TRUE
        /\ currentStep = Phase_Init_15
        /\ pendingNetworkConfig = None
        /\ pendingNetworkConfig' = netId
        /\ UNCHANGED <<flowType, currentStep, failedAttempts, commissioningMode, acceptingPASE, isCommissioningWithoutPower, failSafeState, breadcrumb, networkConfigs>>

\* SOURCE: core_5.5.1 Before attempting to configure any such alternative interface, the commissioner SHALL revert network configuration changes made as part of the preceding unsuccessful configuration attempt, specifically the Section 11.9.7.6, “RemoveNetwork” command SHALL be used to remove any Thread or Wi-Fi network configurations added by such an unsuccessful attempt.
RemoveUnsuccessfulNetworkConfig ==
    /\ commissioningMode = TRUE
    /\ pendingNetworkConfig /= None
    /\ pendingNetworkConfig' = None
    /\ UNCHANGED <<flowType, currentStep, failedAttempts, commissioningMode, acceptingPASE, isCommissioningWithoutPower, failSafeState, breadcrumb, networkConfigs>>

\* SOURCE: core_5.5.1 Whenever the Fail-Safe timer is armed, Commissioners and Administrators SHALL NOT consider any cluster operation to have timed-out before waiting at least 30 seconds for a valid response
TimeoutClusterOperation ==
    /\ commissioningMode = TRUE
    /\ failSafeState = State_Armed
    \* TODO: unspecified - explicit real-time elapsed model is omitted, assuming >= 30 seconds elapsed before timeout
    /\ UNCHANGED <<flowType, currentStep, failedAttempts, commissioningMode, acceptingPASE, isCommissioningWithoutPower, failSafeState, breadcrumb, networkConfigs, pendingNetworkConfig>>

\* SOURCE: core_5.5.1 Some request commands used for Commissioning and administration have a 'Breadcrumb' argument. When set, this argument SHALL be used to update the value of the Breadcrumb Attribute as a side-effect of successful execution of those commands.
UpdateBreadcrumbOnSuccess ==
    \E arg \in 1..MaxBreadcrumb :
        /\ commissioningMode = TRUE
        /\ breadcrumb' = arg
        /\ UNCHANGED <<flowType, currentStep, failedAttempts, commissioningMode, acceptingPASE, isCommissioningWithoutPower, failSafeState, networkConfigs, pendingNetworkConfig>>

\* SOURCE: core_5.5.1 On command failures, the Breadcrumb Attribute SHALL remain unchanged.
KeepBreadcrumbOnFailure ==
    /\ commissioningMode = TRUE
    /\ breadcrumb' = breadcrumb
    /\ UNCHANGED <<flowType, currentStep, failedAttempts, commissioningMode, acceptingPASE, isCommissioningWithoutPower, failSafeState, networkConfigs, pendingNetworkConfig>>

\* SOURCE: core_5.5.1 In concurrent connection commissioning flow, the failure of any of the steps from initial phase step 2 through 14 SHALL result in the Commissioner and Commissionee returning to initial phase step 2
FailConcurrentStep2to14 ==
    /\ commissioningMode = TRUE
    /\ flowType = ConcurrentFlow
    /\ currentStep = Phase_Init_2_14
    /\ currentStep' = Phase_Init_2_14
    /\ failedAttempts' = NextFailState.fails
    /\ commissioningMode' = NextFailState.mode
    /\ UNCHANGED <<flowType, acceptingPASE, isCommissioningWithoutPower, failSafeState, breadcrumb, networkConfigs, pendingNetworkConfig>>

\* SOURCE: core_5.5.1 The failure of any of the steps from initial phase step 15 through setup phase step 4 in concurrent connection commissioning flow SHALL result in the Commissioner and Commissionee returning to initial phase step 15 (configuration of operational network information), and MAY result in an attempt to configure secondary network interfaces.
FailConcurrentStep15toSetup4 ==
    /\ commissioningMode = TRUE
    /\ flowType = ConcurrentFlow
    /\ currentStep \in {Phase_Init_15, Phase_Init_16_17, Phase_Setup_1_4}
    /\ currentStep' = Phase_Init_15
    /\ failedAttempts' = NextFailState.fails
    /\ commissioningMode' = NextFailState.mode
    /\ UNCHANGED <<flowType, acceptingPASE, isCommissioningWithoutPower, failSafeState, breadcrumb, networkConfigs, pendingNetworkConfig>>

\* SOURCE: core_5.5.1 In non-concurrent connection commissioning flow, the failure of any of the steps from initial phase step 2 through 17 SHALL result in the Commissioner and Commissionee returning to initial phase step 2
FailNonConcurrentStep2to17 ==
    /\ commissioningMode = TRUE
    /\ flowType = NonConcurrentFlow
    /\ currentStep \in {Phase_Init_2_14, Phase_Init_15, Phase_Init_16_17}
    /\ currentStep' = Phase_Init_2_14
    /\ failedAttempts' = NextFailState.fails
    /\ commissioningMode' = NextFailState.mode
    /\ UNCHANGED <<flowType, acceptingPASE, isCommissioningWithoutPower, failSafeState, breadcrumb, networkConfigs, pendingNetworkConfig>>

\* SOURCE: core_5.5.1 In case IsCommissioningWithoutPower attribute was false in initial phase step 17 the failure of any of steps from setup phase step 1 through 4 SHALL result in the Commissioner and Commissionee returning to initial phase step 2
FailNonConcurrentSetup1to4_PowerFalse ==
    /\ commissioningMode = TRUE
    /\ flowType = NonConcurrentFlow
    /\ currentStep = Phase_Setup_1_4
    /\ ~isCommissioningWithoutPower
    /\ currentStep' = Phase_Init_2_14
    /\ failedAttempts' = NextFailState.fails
    /\ commissioningMode' = NextFailState.mode
    /\ UNCHANGED <<flowType, acceptingPASE, isCommissioningWithoutPower, failSafeState, breadcrumb, networkConfigs, pendingNetworkConfig>>

\* SOURCE: core_5.5.1 In case IsCommissioningWithoutPower attribute was true in initial phase step 17, the failure of any of the steps from setup phase step 1 through 4 SHALL result in the Commissioner and Commissionee returning to setup phase step 1
FailNonConcurrentSetup1to4_PowerTrue ==
    /\ commissioningMode = TRUE
    /\ flowType = NonConcurrentFlow
    /\ currentStep = Phase_Setup_1_4
    /\ isCommissioningWithoutPower
    /\ currentStep' = Phase_Setup_1_4
    /\ failedAttempts' = NextFailState.fails
    /\ commissioningMode' = NextFailState.mode
    /\ UNCHANGED <<flowType, acceptingPASE, isCommissioningWithoutPower, failSafeState, breadcrumb, networkConfigs, pendingNetworkConfig>>

\* SOURCE: core_5.5.1 Commissioners that need to restart from initial phase step 2 MAY immediately expire the fail-safe by invoking the ArmFailSafe command with an ExpiryLengthSeconds field set to 0.
RestartStep2_ArmFailSafeZero ==
    /\ currentStep = Phase_Init_2_14
    /\ failSafeState = State_Armed
    /\ failSafeState' = State_Expired
    /\ acceptingPASE' = TRUE
    /\ UNCHANGED <<flowType, currentStep, failedAttempts, commissioningMode, isCommissioningWithoutPower, breadcrumb, networkConfigs, pendingNetworkConfig>>

\* SOURCE: core_5.5.1 Otherwise, Commissioners will need to wait until the current fail-safe timer has expired for the Commissionee to begin accepting PASE again.
WaitFailSafeExpiry ==
    /\ failSafeState = State_Armed
    /\ failSafeState' = State_Expired
    /\ acceptingPASE' = TRUE
    /\ UNCHANGED <<flowType, currentStep, failedAttempts, commissioningMode, isCommissioningWithoutPower, breadcrumb, networkConfigs, pendingNetworkConfig>>

\* SOURCE: core_5.5.1 This ensures that when commissioning ultimately succeeds, only the configuration changes relating to the network interface that was successfully configured will be committed by the Section 11.10.7.6, “CommissioningComplete” command.
CommissioningCompleteCommand ==
    /\ commissioningMode = TRUE
    /\ currentStep = Phase_Setup_1_4
    /\ currentStep' = Phase_Commissioned
    /\ networkConfigs' = (IF pendingNetworkConfig /= None THEN networkConfigs \cup {pendingNetworkConfig} ELSE networkConfigs)
    /\ pendingNetworkConfig' = None
    \* SOURCE: core_5.5.1 Once a Commissionee has been successfully commissioned by a Commissioner into its fabric, the commissioned Node SHALL NOT accept any more PASE requests
    /\ acceptingPASE' = FALSE
    /\ UNCHANGED <<flowType, failedAttempts, commissioningMode, isCommissioningWithoutPower, failSafeState, breadcrumb>>

\* SOURCE: core_5.5.1 until any one of the following conditions is met: Device is factory-reset.
FactoryReset ==
    /\ currentStep' = Phase_Init_2_14
    /\ failedAttempts' = 0
    /\ acceptingPASE' = TRUE
    /\ commissioningMode' = TRUE
    /\ networkConfigs' = {}
    /\ pendingNetworkConfig' = None
    /\ UNCHANGED <<flowType, isCommissioningWithoutPower, failSafeState, breadcrumb>>

\* SOURCE: core_5.5.1 until any one of the following conditions is met: ... Device enters commissioning mode.
EnterCommissioningMode ==
    /\ currentStep' = Phase_Init_2_14
    /\ acceptingPASE' = TRUE
    /\ commissioningMode' = TRUE
    /\ UNCHANGED <<flowType, failedAttempts, isCommissioningWithoutPower, failSafeState, breadcrumb, networkConfigs, pendingNetworkConfig>>

\* Implicit progression allowing successful advancement to expose intermediate phases for the error scenarios described in the spec.
AdvanceCommissioningPhase ==
    /\ commissioningMode = TRUE
    /\ ( (currentStep = Phase_Init_2_14 /\ currentStep' = Phase_Init_15) \/
         (currentStep = Phase_Init_15 /\ currentStep' = Phase_Init_16_17) \/
         (currentStep = Phase_Init_16_17 /\ currentStep' = Phase_Setup_1_4) )
    /\ UNCHANGED <<flowType, failedAttempts, commissioningMode, acceptingPASE, isCommissioningWithoutPower, failSafeState, breadcrumb, networkConfigs, pendingNetworkConfig>>

Next ==
    \/ AttemptNetworkConfig
    \/ RemoveUnsuccessfulNetworkConfig
    \/ TimeoutClusterOperation
    \/ UpdateBreadcrumbOnSuccess
    \/ KeepBreadcrumbOnFailure
    \/ FailConcurrentStep2to14
    \/ FailConcurrentStep15toSetup4
    \/ FailNonConcurrentStep2to17
    \/ FailNonConcurrentSetup1to4_PowerFalse
    \/ FailNonConcurrentSetup1to4_PowerTrue
    \/ RestartStep2_ArmFailSafeZero
    \/ WaitFailSafeExpiry
    \/ CommissioningCompleteCommand
    \/ FactoryReset
    \/ EnterCommissioningMode
    \/ AdvanceCommissioningPhase

====