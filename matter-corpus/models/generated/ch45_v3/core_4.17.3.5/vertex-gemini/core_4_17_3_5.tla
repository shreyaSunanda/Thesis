---- MODULE core_4_17_3_5 ----
EXTENDS Naturals

\* The Group Key Set ID of 0 SHALL be reserved for managing the Identity Protection Key (IPK).
CONSTANTS IPKKeySetId
\* The available IDs for key sets, e.g., {0, 1, 2}.
CONSTANTS KeySetIds
\* The available fabric indices.
CONSTANTS Fabrics
\* Maximum time bound to keep the state space finite.
CONSTANTS MaxTime

CONSTANTS NoInput
VARIABLES state, pendingInput
VARIABLES systemTime, groupKeySets
VARIABLES inputFabric, inputKeySetId, inputKeys, inputKey

Inputs == {
    "AdminRefresh",
    "AdminUpdate",
    "RemoveKeySet"
}

\* Helper: A key is active if its start time is in the past or present.
IsActive(k, t) == k <= t

ActiveKeys(keys, t) == {k \in keys : IsActive(k, t)}

\* Helper: Returns the active key with the newest start time (as a singleton set, or empty).
CurrentKey(keys, t) ==
    { k \in ActiveKeys(keys, t) : \A other \in ActiveKeys(keys, t) : k >= other }

\* Helper: Returns the active key with the second newest start time.
PreviousKey(keys, t) ==
    LET rem == ActiveKeys(keys, t) \ CurrentKey(keys, t) IN
    { k \in rem : \A other \in rem : k >= other }

\* Helper: Returns the active key with the third newest start time.
OldKey(keys, t) ==
    LET rem == ActiveKeys(keys, t) \ (CurrentKey(keys, t) \cup PreviousKey(keys, t)) IN
    { k \in rem : \A other \in rem : k >= other }

\* Helper: Keys that are active but older than the third newest key.
AgedOutKeys(keys, t) ==
    ActiveKeys(keys, t) \ (CurrentKey(keys, t) \cup PreviousKey(keys, t) \cup OldKey(keys, t))

Init ==
    /\ state = "Idle"
    /\ pendingInput = NoInput
    /\ systemTime = 0
    /\ groupKeySets = [f \in Fabrics |-> [id \in KeySetIds |-> {}]]
    /\ inputFabric \in Fabrics
    /\ inputKeySetId \in KeySetIds
    /\ inputKeys \in SUBSET (0..MaxTime)
    /\ inputKey \in 0..MaxTime

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E f \in Fabrics, id \in KeySetIds, ks \in SUBSET (0..MaxTime), k \in 0..MaxTime :
           /\ inputFabric' = f
           /\ inputKeySetId' = id
           /\ inputKeys' = ks
           /\ inputKey' = k
    /\ UNCHANGED <<state, systemTime, groupKeySets>>

\* SOURCE: core_4.17.3.5 Epoch Key Rotation logic
AdminRefresh ==
    /\ pendingInput = "AdminRefresh"
    /\ state' = "AdminRefresh"
    /\ groupKeySets' = [groupKeySets EXCEPT ![inputFabric][inputKeySetId] = inputKeys]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<systemTime, inputFabric, inputKeySetId, inputKeys, inputKey>>

\* SOURCE: core_4.17.3.5 Epoch Key Rotation logic
AdminUpdate ==
    /\ pendingInput = "AdminUpdate"
    /\ state' = "AdminUpdate"
    \* TODO: unspecified - what happens if there is no Old key to update.
    /\ \E old \in OldKey(groupKeySets[inputFabric][inputKeySetId], systemTime) :
           groupKeySets' = [groupKeySets EXCEPT ![inputFabric][inputKeySetId] = (groupKeySets[inputFabric][inputKeySetId] \ {old}) \cup {inputKey}]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<systemTime, inputFabric, inputKeySetId, inputKeys, inputKey>>

\* SOURCE: core_4.17.3.5 Epoch Key Rotation logic
RemoveKeySet ==
    /\ pendingInput = "RemoveKeySet"
    /\ groupKeySets' = IF inputKeySetId = IPKKeySetId THEN groupKeySets ELSE [groupKeySets EXCEPT ![inputFabric][inputKeySetId] = {}]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, systemTime, inputFabric, inputKeySetId, inputKeys, inputKey>>

\* SOURCE: core_4.17.3.5 Epoch Key Rotation logic
EpochActivate ==
    /\ pendingInput = NoInput
    /\ systemTime < MaxTime
    /\ systemTime' = systemTime + 1
    /\ state' = "EpochActivate"
    /\ groupKeySets' = [f \in Fabrics |-> [id \in KeySetIds |-> groupKeySets[f][id] \ AgedOutKeys(groupKeySets[f][id], systemTime')]]
    /\ UNCHANGED <<pendingInput, inputFabric, inputKeySetId, inputKeys, inputKey>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ AdminRefresh
    \/ AdminUpdate
    \/ RemoveKeySet
    \/ EpochActivate

====