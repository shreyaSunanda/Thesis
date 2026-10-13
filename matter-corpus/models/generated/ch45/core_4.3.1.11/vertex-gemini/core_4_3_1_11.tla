---- MODULE core_4_3_1_11 ----
EXTENDS Naturals, FiniteSets

\* TODO: unspecified - ASCII base-10 variable length encoding of the PH key is abstracted here as a mathematical set of bit indices.
\* TODO: unspecified - Additional custom parameters for PI (like N seconds, color strings, exact button codes) are abstracted to a simple boolean flag indicating PI presence.

CONSTANTS 
    \* Set of bit indices that require no PI. 
    \* Real value per Table 5: {0, 1, 2, 3, 5, 6, 7, 13, 14}
    NoPIBits,
    \* Set of bit indices that mandate PI. 
    \* Real value per Table 5: {4, 8, 10, 12, 15, 17, 19, 20, 21, 22}
    MandatoryPIBits,
    \* Set of bit indices that allow optional PI. 
    \* Real value per Table 5: {9, 11, 16, 18}
    OptionalPIBits

VARIABLES 
    cm,                  \* Commissioning Mode (0 or 1)
    extendedDiscovery,   \* BOOLEAN indicating if Extended Discovery is enabled
    phBits,              \* The active pairing hint bits (subset of AllPHBits)
    publishedTxt         \* Set of published DNS-SD TXT records

AllPHBits == NoPIBits \cup MandatoryPIBits \cup OptionalPIBits

\* SOURCE: core_4.3.1.11
\* "When the PH key is provided, at least one bit in the above bitmap SHALL be set. That is, a PH value of 0 is undefined and illegal."
\* "only one such method can be specified which has a mandatory dependency on the PI key (PI Dependency=M) at a time."
ValidPHBits(bits) ==
    /\ bits /= {}
    /\ Cardinality(bits \cap MandatoryPIBits) <= 1

\* SOURCE: core_4.3.1.11
\* Table 5 and PI Instruction Dependency column requirements.
ValidPIPresence(bits, pi) ==
    \/ /\ (bits \cap MandatoryPIBits) /= {}
       /\ pi = TRUE
    \/ /\ (bits \cap MandatoryPIBits) = {}
       /\ (bits \cap OptionalPIBits) /= {}
       /\ pi \in {TRUE, FALSE}
    \/ /\ (bits \cap MandatoryPIBits) = {}
       /\ (bits \cap OptionalPIBits) = {}
       /\ pi = FALSE

TXTRecord(phP, bits, piP) ==
    [phPresent |-> phP,
     phBits    |-> IF phP = TRUE THEN bits ELSE {},
     piPresent |-> piP]

Init == 
    /\ cm \in {0, 1}
    /\ extendedDiscovery \in {TRUE, FALSE}
    /\ \E initBits \in SUBSET AllPHBits :
        /\ ValidPHBits(initBits)
        /\ phBits = initBits
    /\ publishedTxt = {}

\* SOURCE: core_4.3.1.11
\* "If the Commissionee has enabled Extended Discovery, then it SHALL include the key/value pair for PH in the DNS-SD TXT record when not in Commissioning Mode (CM=0)."
\* "This key/value pair MAY be returned when in Commissioning Mode (CM=1)."
PublishTXTRecord ==
    \E includePH \in {TRUE, FALSE} :
        \E includePI \in {TRUE, FALSE} :
            /\ (extendedDiscovery = TRUE /\ cm = 0) => (includePH = TRUE)
            /\ includePH = TRUE => ValidPHBits(phBits)
            /\ includePH = TRUE => ValidPIPresence(phBits, includePI)
            /\ includePH = FALSE => (includePI = FALSE)
            /\ publishedTxt' = publishedTxt \cup {TXTRecord(includePH, phBits, includePI)}
            /\ UNCHANGED <<cm, extendedDiscovery, phBits>>

\* SOURCE: core_4.3.1.11
\* "This value MAY change during the lifecycle of the device."
\* Models the device updating its pairing hints or commissioning mode over its lifecycle.
UpdateLifecycleState ==
    \E nextCm \in {0, 1} :
        \E nextBits \in SUBSET AllPHBits :
            /\ ValidPHBits(nextBits)
            /\ cm' = nextCm
            /\ phBits' = nextBits
            /\ UNCHANGED <<extendedDiscovery, publishedTxt>>

\* SOURCE: core_4.3.1.11
\* "If the Commissionee has enabled Extended Discovery..."
\* Models the device enabling or disabling Extended Discovery independently.
ToggleExtendedDiscovery ==
    \E nextExt \in {TRUE, FALSE} :
        /\ extendedDiscovery' = nextExt
        /\ UNCHANGED <<cm, phBits, publishedTxt>>

\* SOURCE: core_4.3.1.11
\* "If the Commissioner does not recognize this value... the Commissioner MAY utilize the bits that it does understand..."
\* Formalizes the presence of a Commissioner reading a published record, without changing internal Commissionee state.
CommissionerObserve ==
    \E rec \in publishedTxt :
        UNCHANGED <<cm, extendedDiscovery, phBits, publishedTxt>>

Next == 
    \/ PublishTXTRecord
    \/ UpdateLifecycleState
    \/ ToggleExtendedDiscovery
    \/ CommissionerObserve

====