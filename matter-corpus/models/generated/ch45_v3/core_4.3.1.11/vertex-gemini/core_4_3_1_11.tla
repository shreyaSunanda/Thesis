---- MODULE core_4_3_1_11 ----
EXTENDS Naturals, FiniteSets

\* Standard flow vs Custom flow for Factory Reset hint requirements
CONSTANTS 
    NoInput,
    \* @type: Bool;
    StandardCommissioningFlow,
    \* @type: Bool;
    CustomCommissioningFlow

VARIABLES 
    pendingInput,
    cm,                       \* Commissioning Mode status (0 or 1)
    extendedDiscoveryEnabled, \* Whether Extended Discovery is enabled (BOOLEAN)
    currentPHBits,            \* Set of Nat representing currently set pairing hint bits
    currentPIPresent,         \* Whether the PI key/value pair is present (BOOLEAN)
    deviceState,              \* e.g., "FactoryReset", "Commissioned"
    advertisedTXT             \* Record modeling the TXT record presence of PH

Inputs == {
    "SetExtendedDiscovery", 
    "ClearExtendedDiscovery", 
    "EnterCommissioningMode", 
    "ExitCommissioningMode",
    "TransitionToFactoryReset",
    "TransitionToCommissioned",
    "AdvertiseTXT",
    "CommissionerEvaluateHint"
}

\* Abstraction: We abstract the 23 possible bits in Table 5 to a smaller representative 
\* set to keep the state space finite and easily model-checkable.
\* 0: Power Cycle (PI: no)
\* 1: Device Manufacturer URL/App (PI: no)
\* 2: Administrator (PI: no)
\* 3: Settings menu on the Node (PI: no)
\* 4: Custom Instruction (PI: M - Mandatory)
\* 9: Press Reset Button until light blinks (PI: O - Optional)
MandatoryPIBits == {4}
OptionalPIBits == {9}
NoPIBits == {0, 1, 2, 3}
AllDefinedBits == MandatoryPIBits \cup OptionalPIBits \cup NoPIBits

\* SOURCE: core_4.3.1.11 "When the PH key is provided, at least one bit in the above bitmap SHALL be set. That is, a PH value of 0 is undefined and illegal."
\* SOURCE: core_4.3.1.11 "only one such method can be specified which has a mandatory dependency on the PI key (PI Dependency=M) at a time."
IsValidPH(bits) ==
    /\ bits /= {}
    /\ Cardinality(bits \cap MandatoryPIBits) <= 1

\* SOURCE: core_4.3.1.11 Table 5, Bit 0 and Bit 1 descriptions (Factory Reset target states)
SatisfiesFactoryResetFlowRules(bits) ==
    /\ (StandardCommissioningFlow => 0 \in bits)
    /\ (~StandardCommissioningFlow => 0 \notin bits)
    /\ (CustomCommissioningFlow => 1 \in bits)

Init == 
    /\ pendingInput = NoInput
    /\ cm = 0
    /\ extendedDiscoveryEnabled = FALSE
    /\ deviceState = "FactoryReset"
    \* Initialize with a valid bit configuration based on the flow constants
    /\ currentPHBits = {b \in AllDefinedBits : (b = 0 /\ StandardCommissioningFlow) \/ (b = 1 /\ CustomCommissioningFlow) \/ (b = 3 /\ ~StandardCommissioningFlow /\ ~CustomCommissioningFlow)}
    /\ currentPIPresent = FALSE
    /\ advertisedTXT = [PHPresent |-> FALSE]

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<cm, extendedDiscoveryEnabled, currentPHBits, currentPIPresent, deviceState, advertisedTXT>>

\* SOURCE: core_4.3.1.11 "The value MAY change during the lifecycle of the device. For example, a device may have a value with bit 0 (Power Cycle) set and bit 2 (Administrator app) unset when in a factory reset state..."
TransitionToFactoryReset ==
    /\ pendingInput = "TransitionToFactoryReset"
    /\ deviceState' = "FactoryReset"
    /\ \E newBits \in SUBSET AllDefinedBits :
        /\ IsValidPH(newBits)
        /\ SatisfiesFactoryResetFlowRules(newBits)
        /\ 2 \notin newBits  \* Example from spec: bit 2 unset in factory reset
        /\ currentPHBits' = newBits
        /\ \E pi \in BOOLEAN :
            /\ (newBits \cap MandatoryPIBits /= {} => pi = TRUE)
            /\ currentPIPresent' = pi
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<cm, extendedDiscoveryEnabled, advertisedTXT>>

\* SOURCE: core_4.3.1.11 "...and then have a value with bit 0 unset and bit 2 set after it has been Commissioned."
TransitionToCommissioned ==
    /\ pendingInput = "TransitionToCommissioned"
    /\ deviceState' = "Commissioned"
    /\ \E newBits \in SUBSET AllDefinedBits :
        /\ IsValidPH(newBits)
        /\ 0 \notin newBits  \* Example from spec: bit 0 unset
        /\ 2 \in newBits     \* Example from spec: bit 2 set
        /\ currentPHBits' = newBits
        /\ \E pi \in BOOLEAN :
            /\ (newBits \cap MandatoryPIBits /= {} => pi = TRUE)
            /\ currentPIPresent' = pi
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<cm, extendedDiscoveryEnabled, advertisedTXT>>

SetExtendedDiscovery ==
    /\ pendingInput = "SetExtendedDiscovery"
    /\ extendedDiscoveryEnabled' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<cm, currentPHBits, currentPIPresent, deviceState, advertisedTXT>>

ClearExtendedDiscovery ==
    /\ pendingInput = "ClearExtendedDiscovery"
    /\ extendedDiscoveryEnabled' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<cm, currentPHBits, currentPIPresent, deviceState, advertisedTXT>>

EnterCommissioningMode ==
    /\ pendingInput = "EnterCommissioningMode"
    /\ cm' = 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<extendedDiscoveryEnabled, currentPHBits, currentPIPresent, deviceState, advertisedTXT>>

ExitCommissioningMode ==
    /\ pendingInput = "ExitCommissioningMode"
    /\ cm' = 0
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<extendedDiscoveryEnabled, currentPHBits, currentPIPresent, deviceState, advertisedTXT>>

\* SOURCE: core_4.3.1.11 "If the Commissionee has enabled Extended Discovery, then it SHALL include the key/value pair for PH in the DNS-SD TXT record when not in Commissioning Mode (CM=0). This key/value pair MAY be returned when in Commissioning Mode (CM=1)."
AdvertiseTXT ==
    /\ pendingInput = "AdvertiseTXT"
    /\ \E includePH \in BOOLEAN :
        /\ (extendedDiscoveryEnabled /\ cm = 0) => (includePH = TRUE)
        \* TODO: unspecified - spec does not explicitly state if PH is forbidden when ED is disabled and CM=0. Assuming FALSE here to represent general absence.
        /\ (~extendedDiscoveryEnabled /\ cm = 0) => (includePH = FALSE)
        \* For cm = 1, includePH can be TRUE or FALSE (MAY be returned)
        /\ advertisedTXT' = [PHPresent |-> includePH]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<cm, extendedDiscoveryEnabled, currentPHBits, currentPIPresent, deviceState>>

\* SOURCE: core_4.3.1.11 "If the Commissioner does not recognize this value... the Commissioner MAY utilize the bits that it does understand..."
CommissionerEvaluateHint ==
    /\ pendingInput = "CommissionerEvaluateHint"
    /\ advertisedTXT.PHPresent = TRUE
    \* Note: The Commissioner evaluates the hint internally. The Commissionee's state does not change in response to this evaluation.
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<cm, extendedDiscoveryEnabled, currentPHBits, currentPIPresent, deviceState, advertisedTXT>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ TransitionToFactoryReset
    \/ TransitionToCommissioned
    \/ SetExtendedDiscovery
    \/ ClearExtendedDiscovery
    \/ EnterCommissioningMode
    \/ ExitCommissioningMode
    \/ AdvertiseTXT
    \/ CommissionerEvaluateHint

====