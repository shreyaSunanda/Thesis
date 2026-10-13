---- MODULE core_4_17_3_5 ----
EXTENDS Naturals

CONSTANTS 
    \* The set of all Fabric indices
    Fabrics,
    \* The set of all valid Group Key Set IDs (e.g., 0..65535)
    GroupKeySetIds

VARIABLES 
    \* The current system time
    now,
    \* A mapping from <<fabric, groupKeySetId>> to a record [exists: BOOLEAN, keys: SET OF Nat]
    \* where 'keys' represents the start times of the epoch keys in the set.
    groupKeySets

\* IPK Key Set ID is reserved as 0 per the specification
IPKKeySetId == 0

Init ==
    /\ now = 0
    /\ groupKeySets = [f \in Fabrics, id \in GroupKeySetIds |-> [exists |-> FALSE, keys |-> {}]]

\* Helper: The set of keys in a key set that are active at time t
ActiveKeys(kSet, t) == { k \in kSet : k <= t }

\* Helper: A key is 'New' if its start time is in the future
IsNew(k, t) == k > t

\* Helper: A key is 'Current' if it is the active key with the newest start time
IsCurrent(k, kSet, t) == 
    /\ k \in ActiveKeys(kSet, t) 
    /\ \A o \in ActiveKeys(kSet, t) : o <= k

\* Helper: A key is 'Previous' if it is the active key with the second newest start time
IsPrevious(k, kSet, t) == 
    /\ k \in ActiveKeys(kSet, t) 
    /\ \E c \in ActiveKeys(kSet, t) : 
        /\ c > k 
        /\ \A o \in ActiveKeys(kSet, t) : o = c \/ o <= k

\* Helper: A key is 'Old' if it is the active key with the third newest start time
IsOld(k, kSet, t) == 
    /\ k \in ActiveKeys(kSet, t) 
    /\ \E c \in ActiveKeys(kSet, t), p \in ActiveKeys(kSet, t) : 
        /\ c > p 
        /\ p > k 
        /\ \A o \in ActiveKeys(kSet, t) : o = c \/ o = p \/ o <= k

\* SOURCE: core_4.17.3.5 Epoch Key Rotation logic
\* "The Admin Refresh state begins when an entire group key set is freshly written to a Node 
\* during commissioning or administration, such as when a new group is added."
AdminRefresh(f, id, newKeys) ==
    /\ groupKeySets' = [groupKeySets EXCEPT ![f, id] = [exists |-> TRUE, keys |-> newKeys]]
    /\ UNCHANGED now

\* SOURCE: core_4.17.3.5 Epoch Key Rotation logic
\* "The Admin Update state is entered when an Administrator updates an old epoch key with a new epoch key."
AdminUpdate(f, id, oldKey, newKey) ==
    /\ groupKeySets[f, id].exists
    /\ IsOld(oldKey, groupKeySets[f, id].keys, now)
    /\ IsNew(newKey, now)
    /\ groupKeySets' = [groupKeySets EXCEPT ![f, id].keys = (@ \ {oldKey}) \cup {newKey}]
    /\ UNCHANGED now

\* SOURCE: core_4.17.3.5 Epoch Key Rotation logic
\* "The Epoch Activate state is entered when time progresses to activate a fresh current epoch key, 
\* aging out the other epoch key slots."
EpochActivate(newTime) ==
    /\ newTime > now
    /\ \E f \in Fabrics, id \in GroupKeySetIds :
        /\ groupKeySets[f, id].exists
        /\ \E k \in groupKeySets[f, id].keys :
            /\ IsNew(k, now)
            /\ k <= newTime
    /\ now' = newTime
    /\ UNCHANGED groupKeySets

\* SOURCE: core_4.17.3.5 Epoch Key Rotation logic
\* "...configuring new groups and removing groups and group key sets with expired keys."
\* "The Group Key Set ID of 0 SHALL be reserved for managing the Identity Protection Key (IPK) 
\* on a given Fabric. It SHALL NOT be possible to remove the IPK Key Set if it exists."
\* TODO: unspecified - exact conditions under which a key is considered 'expired' for removal 
\* are not formally defined in this section, so this action permits removing any existing set (except IPK).
RemoveGroupKeySet(f, id) ==
    /\ groupKeySets[f, id].exists
    /\ id /= IPKKeySetId
    /\ groupKeySets' = [groupKeySets EXCEPT ![f, id] = [exists |-> FALSE, keys |-> {}]]
    /\ UNCHANGED now

Next == 
    \/ \E f \in Fabrics, id \in GroupKeySetIds, newKeys \in SUBSET Nat : AdminRefresh(f, id, newKeys)
    \/ \E f \in Fabrics, id \in GroupKeySetIds, oldKey \in Nat, newKey \in Nat : AdminUpdate(f, id, oldKey, newKey)
    \/ \E newTime \in Nat : EpochActivate(newTime)
    \/ \E f \in Fabrics, id \in GroupKeySetIds : RemoveGroupKeySet(f, id)

====