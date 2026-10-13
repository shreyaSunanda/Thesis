---- MODULE core_4_3_1_11 ----
EXTENDS Naturals

\* Maximum bit index for Pairing Hint. Real value per spec: 22.
CONSTANTS MaxPHBit

\* Defines the type of commissioning flow required by the device.
CONSTANTS CommissioningFlowType, StandardCommissioningFlow, CustomCommissioningFlow

\* Mandatory input shape declarations
CONSTANTS NoInput, Inputs
VARIABLES state, pendingInput, extendedDiscoveryEnabled, cm, phBits, piIncluded, txtRecords

\* Bit sets matching Table 5 Instruction Dependency mappings
M_Bits == {4, 8, 10, 12, 15, 17, 19, 20, 21, 22}
O_Bits == {9, 11, 16, 18}
No_Bits == {0, 1, 2, 3, 5, 6, 7, 13, 14}

\* Helper for generating the subset of fields in a DNS-SD TXT record 
GeneratedRecord(includePH, currentCM, currentPH, currentPI) ==
    [
        cm |-> currentCM,
        phIncluded |-> includePH,
        phBits |-> IF includePH THEN currentPH ELSE {},
        piIncluded |-> IF includePH THEN currentPI ELSE FALSE
    ]

Init ==
    /\ state = "FactoryReset"
    /\ pendingInput = NoInput
    /\ extendedDiscoveryEnabled = FALSE
    /\ cm = 0
    /\ txtRecords = {}
    /\ \E initialPH \in SUBSET (0..MaxPHBit) :
           /\ initialPH /= {}
           /\ ~(\E b1, b2 \in initialPH : b1 /= b2 /\ b1 \in M_Bits /\ b2 \in M_Bits)
           /\ (CommissioningFlowType = StandardCommissioningFlow <=> 0 \in initialPH)
           /\ (CommissioningFlowType = CustomCommissioningFlow => 1 \in initialPH)
           /\ phBits = initialPH
           /\ \E initialPIIncluded \in BOOLEAN :
                  /\ (\E b \in initialPH : b \in M_Bits) => (initialPIIncluded = TRUE)
                  \* TODO: unspecified - whether PI can be present if all bits are 'no'. The spec says "does not apply" but lacks explicit SHALL NOT.
                  /\ piIncluded = initialPIIncluded

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, extendedDiscoveryEnabled, cm, phBits, piIncluded, txtRecords>>

\* SOURCE: core_4.3.1.11 "If the Commissionee has enabled Extended Discovery..."
EnableExtendedDiscovery ==
    /\ pendingInput = "EnableExtendedDiscovery"
    /\ extendedDiscoveryEnabled' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, cm, phBits, piIncluded, txtRecords>>

\* SOURCE: core_4.3.1.11 "If the Commissionee has enabled Extended Discovery..."
DisableExtendedDiscovery ==
    /\ pendingInput = "DisableExtendedDiscovery"
    /\ extendedDiscoveryEnabled' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, cm, phBits, piIncluded, txtRecords>>

\* SOURCE: core_4.3.1.11 "when not in Commissioning Mode (CM=0)... when in Commissioning Mode (CM=1)."
EnterCommissioningMode ==
    /\ pendingInput = "EnterCommissioningMode"
    /\ cm' = 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, extendedDiscoveryEnabled, phBits, piIncluded, txtRecords>>

\* SOURCE: core_4.3.1.11 "when not in Commissioning Mode (CM=0)... when in Commissioning Mode (CM=1)."
ExitCommissioningMode ==
    /\ pendingInput = "ExitCommissioningMode"
    /\ cm' = 0
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, extendedDiscoveryEnabled, phBits, piIncluded, txtRecords>>

\* SOURCE: core_4.3.1.11 Table 5 Power Cycle & Device Manufacturer URL/App
PerformFactoryReset ==
    /\ pendingInput = "FactoryReset"
    /\ state' = "FactoryReset"
    /\ \E newPH \in SUBSET (0..MaxPHBit) :
           /\ newPH /= {}
           /\ ~(\E b1, b2 \in newPH : b1 /= b2 /\ b1 \in M_Bits /\ b2 \in M_Bits)
           /\ (CommissioningFlowType = StandardCommissioningFlow <=> 0 \in newPH)
           /\ (CommissioningFlowType = CustomCommissioningFlow => 1 \in newPH)
           /\ phBits' = newPH
    /\ \E newPIIncluded \in BOOLEAN :
           /\ (\E b \in phBits' : b \in M_Bits) => (newPIIncluded = TRUE)
           /\ piIncluded' = newPIIncluded
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<extendedDiscoveryEnabled, cm, txtRecords>>

\* SOURCE: core_4.3.1.11 "For example, a device may have a value with bit 0 (Power Cycle) set and bit 2 (Administrator app) unset when in a factory reset state, and then have a value with bit 0 unset and bit 2 set after it has been Commissioned."
PerformCommissioning ==
    /\ pendingInput = "CommissionDevice"
    /\ state' = "Commissioned"
    /\ \E newPH \in SUBSET (0..MaxPHBit) :
           /\ newPH /= {}
           /\ ~(\E b1, b2 \in newPH : b1 /= b2 /\ b1 \in M_Bits /\ b2 \in M_Bits)
           /\ phBits' = newPH
    /\ \E newPIIncluded \in BOOLEAN :
           /\ (\E b \in phBits' : b \in M_Bits) => (newPIIncluded = TRUE)
           /\ piIncluded' = newPIIncluded
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<extendedDiscoveryEnabled, cm, txtRecords>>

\* SOURCE: core_4.3.1.11 "This value MAY change during the lifecycle of the device."
UpdatePairingHint ==
    /\ \E newPH \in SUBSET (0..MaxPHBit) :
           /\ newPH /= {}
           /\ ~(\E b1, b2 \in newPH : b1 /= b2 /\ b1 \in M_Bits /\ b2 \in M_Bits)
           /\ (state = "FactoryReset") => (CommissioningFlowType = StandardCommissioningFlow <=> 0 \in newPH)
           /\ (state = "FactoryReset") => (CommissioningFlowType = CustomCommissioningFlow => 1 \in newPH)
           /\ phBits' = newPH
    /\ \E newPIIncluded \in BOOLEAN :
           /\ (\E b \in phBits' : b \in M_Bits) => (newPIIncluded = TRUE)
           /\ piIncluded' = newPIIncluded
    /\ UNCHANGED <<state, pendingInput, extendedDiscoveryEnabled, cm, txtRecords>>

\* SOURCE: core_4.3.1.11 "If the Commissionee has enabled Extended Discovery, then it SHALL include the key/value pair for PH in the DNS-SD TXT record when not in Commissioning Mode (CM=0). This key/value pair MAY be returned when in Commissioning Mode (CM=1)."
GenerateTXTRecord ==
    /\ pendingInput = "GenerateTXTRecord"
    /\ \E includePH \in BOOLEAN :
           /\ (extendedDiscoveryEnabled = TRUE /\ cm = 0) => (includePH = TRUE)
           \* TODO: unspecified - whether PH is included when CM=0 and Extended Discovery is disabled
           /\ txtRecords' = txtRecords \cup {GeneratedRecord(includePH, cm, phBits, piIncluded)}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, extendedDiscoveryEnabled, cm, phBits, piIncluded>>

\* SOURCE: core_4.3.1.11 "If the Commissioner does not recognize this value... the Commissioner MAY utilize the bits that it does understand and MAY utilize additional data sets available for assisting the user."
CommissionerReadTXTRecord ==
    /\ pendingInput = "CommissionerReadTXT"
    /\ \E record \in txtRecords :
           /\ record.phIncluded = TRUE
           \* Abstraction: The commissioner internally utilizes recognized bits and available datasets.
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, extendedDiscoveryEnabled, cm, phBits, piIncluded, txtRecords>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ EnableExtendedDiscovery
    \/ DisableExtendedDiscovery
    \/ EnterCommissioningMode
    \/ ExitCommissioningMode
    \/ PerformFactoryReset
    \/ PerformCommissioning
    \/ UpdatePairingHint
    \/ GenerateTXTRecord
    \/ CommissionerReadTXTRecord

====