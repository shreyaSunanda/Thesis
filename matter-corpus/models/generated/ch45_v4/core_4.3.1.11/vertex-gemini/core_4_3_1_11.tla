---- MODULE core_4_3_1_11 ----
EXTENDS Naturals

CONSTANTS NoInput

\* Bits defined in Table 5
CONSTANTS 
    Bit_PowerCycle,
    Bit_DeviceManufacturerUrlApp,
    Bit_Administrator,
    Bit_SettingsMenu,
    Bit_CustomInstruction,
    Bit_DeviceManual,
    Bit_PressResetButton,
    Bit_PressResetButtonWithPower,
    Bit_PressResetButtonForNSeconds,
    Bit_PressResetButtonUntilLightBlinks,
    Bit_PressResetButtonForNSecWithPower,
    Bit_PressResetButtonUntilLightBlinksWithPower,
    Bit_PressResetButtonNTimes,
    Bit_PressSetupButton,
    Bit_PressSetupButtonWithPower,
    Bit_PressSetupButtonForNSeconds,
    Bit_PressSetupButtonUntilLightBlinks,
    Bit_PressSetupButtonForNSecWithPower,
    Bit_PressSetupButtonUntilLightBlinksWithPower,
    Bit_PressSetupButtonNTimes,
    Bit_PowerCycleNTimes,
    Bit_PressButtonForNSecWithIndication,
    Bit_PowerCycleUntilIndication

AllDefinedBits == {
    Bit_PowerCycle, Bit_DeviceManufacturerUrlApp, Bit_Administrator,
    Bit_SettingsMenu, Bit_CustomInstruction, Bit_DeviceManual,
    Bit_PressResetButton, Bit_PressResetButtonWithPower,
    Bit_PressResetButtonForNSeconds, Bit_PressResetButtonUntilLightBlinks,
    Bit_PressResetButtonForNSecWithPower, Bit_PressResetButtonUntilLightBlinksWithPower,
    Bit_PressResetButtonNTimes, Bit_PressSetupButton, Bit_PressSetupButtonWithPower,
    Bit_PressSetupButtonForNSeconds, Bit_PressSetupButtonUntilLightBlinks,
    Bit_PressSetupButtonForNSecWithPower, Bit_PressSetupButtonUntilLightBlinksWithPower,
    Bit_PressSetupButtonNTimes, Bit_PowerCycleNTimes,
    Bit_PressButtonForNSecWithIndication, Bit_PowerCycleUntilIndication
}

\* Bits with Instruction Dependency = M
MandatoryPIBits == {
    Bit_CustomInstruction,
    Bit_PressResetButtonForNSeconds,
    Bit_PressResetButtonForNSecWithPower,
    Bit_PressResetButtonNTimes,
    Bit_PressSetupButtonForNSeconds,
    Bit_PressSetupButtonForNSecWithPower,
    Bit_PressSetupButtonNTimes,
    Bit_PowerCycleNTimes,
    Bit_PressButtonForNSecWithIndication,
    Bit_PowerCycleUntilIndication
}

VARIABLES 
    pendingInput,
    inputBits,          \* Input data for setting PH bits
    inputBool,          \* Input data for setting boolean flags (e.g., PI key presence, CM state)
    inCmdMode,          \* TRUE if CM=1, FALSE if CM=0
    extDiscovery,       \* TRUE if Extended Discovery is enabled
    phBits,             \* Currently configured PH bitset
    piKeyPresent,       \* Abstraction: whether the PI key is present and formatted
    advertisedPH,       \* The PH bitset currently being advertised in TXT record
    commissionerUnderstood, \* Subset of advertised bits the Commissioner recognized
    deviceState,        \* Device state, e.g., "FactoryReset", "Commissioned"
    commissioningFlow   \* Inherent device flow, e.g., "Standard", "Custom"

Inputs == {
    "SetCommissioningMode",
    "SetExtendedDiscovery",
    "SetDeviceState",
    "SetCommissioningFlow",
    "SetPairingHint",
    "UpdateAdvertisement",
    "CommissionerReceiveAdvertisement"
}

Operational == TRUE

Init ==
    /\ pendingInput = NoInput
    /\ inputBits = {}
    /\ inputBool = FALSE
    /\ inCmdMode = FALSE
    /\ extDiscovery = FALSE
    /\ phBits = {Bit_PowerCycle}
    /\ piKeyPresent = FALSE
    /\ advertisedPH = {}
    /\ commissionerUnderstood = {}
    /\ deviceState = "FactoryReset"
    /\ commissioningFlow = "Standard"

IsValidPH(bits, piPresent) ==
    /\ bits /= {}
    \* SOURCE: core_4.3.1.11 "only one such method can be specified which has a mandatory dependency on the PI key (PI Dependency=M) at a time."
    /\ \A b1, b2 \in (bits \cap MandatoryPIBits) : b1 = b2
    /\ (bits \cap MandatoryPIBits /= {} => piPresent)
    \* SOURCE: core_4.3.1.11 "When used with the target state of Commissioning Mode for a device that is in a factory reset state, this bit SHALL be set to 1 for devices using Standard Commissioning Flow, and set to 0 otherwise."
    /\ (deviceState = "FactoryReset" =>
           (commissioningFlow = "Standard" <=> Bit_PowerCycle \in bits))
    \* SOURCE: core_4.3.1.11 "When used with the target state of Commissioning Mode for a device that is in a factory reset state, this bit SHALL be set to 1 for devices requiring Custom Commissioning Flow before they can be available for Commissioning by any Commissioner."
    /\ (deviceState = "FactoryReset" /\ commissioningFlow = "Custom" =>
           Bit_DeviceManufacturerUrlApp \in bits)

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e \in {"SetPairingHint", "SetCommissioningMode", "SetExtendedDiscovery", "SetDeviceState", "SetCommissioningFlow"} THEN
           \E b \in SUBSET AllDefinedBits :
               \E flag \in BOOLEAN :
                   /\ inputBits' = b
                   /\ inputBool' = flag
       ELSE
           UNCHANGED <<inputBits, inputBool>>
    /\ UNCHANGED <<inCmdMode, extDiscovery, phBits, piKeyPresent, advertisedPH, commissionerUnderstood, deviceState, commissioningFlow>>

Action_SetCommissioningMode ==
    /\ pendingInput = "SetCommissioningMode"
    /\ inCmdMode' = inputBool
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBits, inputBool, extDiscovery, phBits, piKeyPresent, advertisedPH, commissionerUnderstood, deviceState, commissioningFlow>>

Action_SetExtendedDiscovery ==
    /\ pendingInput = "SetExtendedDiscovery"
    /\ extDiscovery' = inputBool
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBits, inputBool, inCmdMode, phBits, piKeyPresent, advertisedPH, commissionerUnderstood, deviceState, commissioningFlow>>

\* SOURCE: core_4.3.1.11 "This value MAY change during the lifecycle of the device. For example, a device may have a value... when in a factory reset state, and then have a value... after it has been Commissioned."
Action_SetDeviceState ==
    /\ pendingInput = "SetDeviceState"
    /\ deviceState' = IF inputBool THEN "Commissioned" ELSE "FactoryReset"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBits, inputBool, inCmdMode, extDiscovery, phBits, piKeyPresent, advertisedPH, commissionerUnderstood, commissioningFlow>>

Action_SetCommissioningFlow ==
    /\ pendingInput = "SetCommissioningFlow"
    /\ commissioningFlow' = IF inputBool THEN "Standard" ELSE "Custom"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBits, inputBool, inCmdMode, extDiscovery, phBits, piKeyPresent, advertisedPH, commissionerUnderstood, deviceState>>

\* SOURCE: core_4.3.1.11 "When the PH key is provided, at least one bit in the above bitmap SHALL be set. That is, a PH value of 0 is undefined and illegal."
Action_SetPairingHint ==
    /\ pendingInput = "SetPairingHint"
    /\ IF IsValidPH(inputBits, inputBool) THEN
           /\ phBits' = inputBits
           /\ piKeyPresent' = inputBool
       ELSE
           \* TODO: unspecified - how to handle an attempt to set an invalid PH configuration
           UNCHANGED <<phBits, piKeyPresent>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBits, inputBool, inCmdMode, extDiscovery, advertisedPH, commissionerUnderstood, deviceState, commissioningFlow>>

\* SOURCE: core_4.3.1.11 "If the Commissionee has enabled Extended Discovery, then it SHALL include the key/value pair for PH in the DNS-SD TXT record when not in Commissioning Mode (CM=0)."
\* SOURCE: core_4.3.1.11 "This key/value pair MAY be returned when in Commissioning Mode (CM=1)."
Action_UpdateAdvertisement ==
    /\ pendingInput = "UpdateAdvertisement"
    /\ IF ~inCmdMode /\ extDiscovery THEN
           advertisedPH' = phBits
       ELSE IF inCmdMode THEN
           \E choice \in {phBits, {}} : advertisedPH' = choice
       ELSE
           \* TODO: unspecified - whether PH is included when CM=0 and Extended Discovery is disabled.
           advertisedPH' = {}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBits, inputBool, inCmdMode, extDiscovery, phBits, piKeyPresent, commissionerUnderstood, deviceState, commissioningFlow>>

\* SOURCE: core_4.3.1.11 "If the Commissioner does not recognize this value... the Commissioner MAY utilize the bits that it does understand and MAY utilize additional data sets available for assisting the user."
Action_CommissionerReceiveAdvertisement ==
    /\ pendingInput = "CommissionerReceiveAdvertisement"
    /\ IF advertisedPH = {} THEN
           commissionerUnderstood' = {}
       ELSE
           \E recognized \in SUBSET advertisedPH :
               commissionerUnderstood' = recognized
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputBits, inputBool, inCmdMode, extDiscovery, phBits, piKeyPresent, advertisedPH, deviceState, commissioningFlow>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ Action_SetCommissioningMode
    \/ Action_SetExtendedDiscovery
    \/ Action_SetDeviceState
    \/ Action_SetCommissioningFlow
    \/ Action_SetPairingHint
    \/ Action_UpdateAdvertisement
    \/ Action_CommissionerReceiveAdvertisement

====