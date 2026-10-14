# Review: `core_4.17.3.5` — Epoch Key Rotation logic

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 24.84
- module: `models/generated/ch45_v4/core_4.17.3.5/vertex-gemini/core_4_17_3_5.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

Clause that action cites:

```
\* Delivers an inbound event along with its associated payload data.
```

State in which the input went unhandled:

```
State 2: <ReceiveInput line 81, col 5 to line 90, col 52 of module core_4_17_3_5>
/\ state = "SteadyState"
/\ inOldKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ groupKeySets = {}
/\ inFabric = Fabrics_1
/\ systemTime = 0
/\ inNewKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ inKeys = {}
/\ pendingInput = "AdminUpdate"
/\ inID = GroupKeySetIDs_1
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "SteadyState"
/\ inOldKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ groupKeySets = {}
/\ inFabric = Fabrics_1
/\ systemTime = 0
/\ inNewKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ inKeys = {}
/\ pendingInput = NoInput
/\ inID = GroupKeySetIDs_1

State 2: <ReceiveInput line 81, col 5 to line 90, col 52 of module core_4_17_3_5>
/\ state = "SteadyState"
/\ inOldKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ groupKeySets = {}
/\ inFabric = Fabrics_1
/\ systemTime = 0
/\ inNewKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ inKeys = {}
/\ pendingInput = "AdminUpdate"
/\ inID = GroupKeySetIDs_1
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

Clause that action cites:

```
\* Delivers an inbound event along with its associated payload data.
```

State in which the input went unhandled:

```
State 2: <ReceiveInput line 81, col 5 to line 90, col 52 of module core_4_17_3_5>
/\ state = "SteadyState"
/\ inOldKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ groupKeySets = {}
/\ inFabric = Fabrics_1
/\ systemTime = 0
/\ inNewKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ inKeys = {}
/\ pendingInput = "AdminUpdate"
/\ inID = GroupKeySetIDs_1
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "SteadyState"
/\ inOldKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ groupKeySets = {}
/\ inFabric = Fabrics_1
/\ systemTime = 0
/\ inNewKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ inKeys = {}
/\ pendingInput = NoInput
/\ inID = GroupKeySetIDs_1

State 2: <ReceiveInput line 81, col 5 to line 90, col 52 of module core_4_17_3_5>
/\ state = "SteadyState"
/\ inOldKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ groupKeySets = {}
/\ inFabric = Fabrics_1
/\ systemTime = 0
/\ inNewKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ inKeys = {}
/\ pendingInput = "AdminUpdate"
/\ inID = GroupKeySetIDs_1
```

</details>

## Spec text for this section

4.17.3.5. Epoch Key Rotation logic
The full life-cycle of Epoch Key rotation is shown in Figure 18, “Epoch Key Rotation”. For each epoch
key slot, the start time of the key is shown as one of the following values:
• New - a key with a start time in the future.
• Current - the active key with the newest start time.
• Previous - the active key with the second newest start time.
• Old - an active key with the third newest start time.
The diagram shows two types of state transitions:
1. Admin - an update of an old key by the Administrator. Changes made during this state transition are indicated in green.
2. Epoch Activate - activation of an epoch key due to system time becoming greater than the start
time. Changes during this state transition are indicated in yellow.
Figure 18. Epoch Key Rotation
The Admin Refresh state begins when an entire group key set is freshly written to a Node during
commissioning or administration, such as when a new group is added. The Epoch Activate state is
entered when time progresses to activate a fresh current epoch key, aging out the other epoch key
slots. The Admin Update state is entered when an Administrator updates an old epoch key with a new
epoch key. When in steady state, the Admin Refresh state MAY be entered in place of an Admin Update
state transition to update additional keys to the required ones or to completely reset the group security.
Note that in the above diagram, only an example key distribution scheme is illustrated. It is also
possible to devise key distribution algorithms that to not rely on time synchronization, or group
configurations that never rotate keys in favor or configuring new groups and removing groups and
group key sets with expired keys.
Group Key Set ID
The Group Key Set ID is a 16-bit field that uniquely identifies the set of epoch keys used for derivation of an operational group key. Each Group Key Set ID is scoped to a particular Fabric and
assigned by an Administrator so as to be unique within a Fabric.
The Group Key Set ID of 0 SHALL be reserved for managing the Identity Protection Key (IPK) on a
given Fabric. It SHALL NOT be possible to remove the IPK Key Set if it exists.
