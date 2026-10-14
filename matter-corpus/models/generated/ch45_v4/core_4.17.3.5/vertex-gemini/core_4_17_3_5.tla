---- MODULE core_4_17_3_5 ----
EXTENDS Naturals, FiniteSets

\* Small finite sets to model the domains required by the spec.
CONSTANTS
    Fabrics,
    GroupKeySetIDs,
    KeyIDs

\* Maximum time for the system clock to bound the state space.
CONSTANTS
    MaxTime

\* The Group Key Set ID reserved for the Identity Protection Key (IPK).
\* The spec explicitly states ID 0 is reserved for this.
CONSTANTS
    IPKGroupKeySetID

\* Sentinel value indicating no input is pending.
CONSTANTS
    NoInput

VARIABLES
    state,
    pendingInput,
    inFabric,
    inID,
    inKeys,
    inOldKey,
    inNewKey,
    groupKeySets,
    systemTime

\* The set of all possible single epoch keys bounded by MaxTime.
KeyRecordSet == [id : KeyIDs, startTime : 0..MaxTime]

Inputs == {
    "AdminRefresh", 
    "AdminUpdate", 
    "EpochActivate", 
    "RemoveGroupKeySet"
}

Init ==
    /\ state = "SteadyState"
    /\ pendingInput = NoInput
    /\ \E f \in Fabrics, id \in GroupKeySetIDs, ks \in SUBSET KeyRecordSet, ok \in KeyRecordSet, nk \in KeyRecordSet :
        /\ inFabric = f
        /\ inID = id
        /\ inKeys = ks
        /\ inOldKey = ok
        /\ inNewKey = nk
    /\ groupKeySets = {}
    /\ systemTime = 0

Operational == TRUE

\* Helper: Returns the subset of keys that have become active.
ActiveKeys(keys, t) == {k \in keys : k.startTime <= t}

\* Helper: Computes the rank of an active key by counting how many strictly newer active keys exist.
\* A rank of 0 means it is the newest active key.
KeyRank(k, keys, t) ==
    IF k \in ActiveKeys(keys, t)
    THEN Cardinality({other.startTime : other \in {x \in ActiveKeys(keys, t) : x.startTime > k.startTime}})
    ELSE 999

\* Helper: Derives the role of a given key according to the epoch key rotation life-cycle.
RoleOfKey(k, keys, t) ==
    IF k.startTime > t THEN "New"
    ELSE
        IF KeyRank(k, keys, t) = 0 THEN "Current"
        ELSE
            IF KeyRank(k, keys, t) = 1 THEN "Previous"
            ELSE
                IF KeyRank(k, keys, t) = 2 THEN "Old"
                ELSE "Unknown"

\* Delivers an inbound event along with its associated payload data.
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E f \in Fabrics, id \in GroupKeySetIDs, ks \in SUBSET KeyRecordSet, ok \in KeyRecordSet, nk \in KeyRecordSet :
        /\ inFabric' = f
        /\ inID' = id
        /\ inKeys' = ks
        /\ inOldKey' = ok
        /\ inNewKey' = nk
    /\ UNCHANGED <<state, groupKeySets, systemTime>>

\* SOURCE: core_4.17.3.5 Admin Refresh
\* The Admin Refresh state begins when an entire group key set is freshly written.
\* It updates keys to the required ones or completely resets the group security.
HandleAdminRefresh ==
    /\ pendingInput = "AdminRefresh"
    /\ groupKeySets' = {g \in groupKeySets : g.fabric # inFabric \/ g.id # inID} \cup {[fabric |-> inFabric, id |-> inID, keys |-> inKeys]}
    /\ state' = "AdminRefresh"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inFabric, inID, inKeys, inOldKey, inNewKey, systemTime>>

\* SOURCE: core_4.17.3.5 Epoch Activate
\* The Epoch Activate state is entered when time progresses to activate a fresh current epoch key.
\* Advancing system time implicitly ages out other epoch key slots based on their role logic.
HandleEpochActivate ==
    /\ pendingInput = "EpochActivate"
    /\ systemTime < MaxTime
    /\ systemTime' = systemTime + 1
    /\ state' = "EpochActivate"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inFabric, inID, inKeys, inOldKey, inNewKey, groupKeySets>>

\* SOURCE: core_4.17.3.5 Admin Update
\* The Admin Update state is entered when an Administrator updates an old epoch key with a new epoch key.
HandleAdminUpdate ==
    /\ pendingInput = "AdminUpdate"
    /\ \E gks \in groupKeySets :
        /\ gks.fabric = inFabric
        /\ gks.id = inID
        /\ inOldKey \in gks.keys
        /\ RoleOfKey(inOldKey, gks.keys, systemTime) = "Old"
        /\ inNewKey.startTime > systemTime
        /\ groupKeySets' = (groupKeySets \ {gks}) \cup {[fabric |-> gks.fabric, id |-> gks.id, keys |-> (gks.keys \ {inOldKey}) \cup {inNewKey}]}
    /\ state' = "AdminUpdate"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inFabric, inID, inKeys, inOldKey, inNewKey, systemTime>>

\* SOURCE: core_4.17.3.5 Group Key Set ID
\* The IPK Key Set SHALL NOT be removed if it exists. Other sets may be removed.
HandleRemoveGroupKeySet ==
    /\ pendingInput = "RemoveGroupKeySet"
    /\ \E gks \in groupKeySets :
        /\ gks.fabric = inFabric
        /\ gks.id = inID
        /\ gks.id # IPKGroupKeySetID
        /\ groupKeySets' = groupKeySets \ {gks}
    /\ state' = "SteadyState"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inFabric, inID, inKeys, inOldKey, inNewKey, systemTime>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleAdminRefresh
    \/ HandleEpochActivate
    \/ HandleAdminUpdate
    \/ HandleRemoveGroupKeySet

====