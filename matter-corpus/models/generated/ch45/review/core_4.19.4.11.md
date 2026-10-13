# Review: `core_4.19.4.11` — Protocol State Diagrams

Automated triage: **candidate** — neither this section nor any section it references says what happens after the teardown

## DRAFT VERDICT (Claude's first pass - please check)

**not reviewable - content is in figures**

Same as core_4.20.3.11: only figure captions (Figures 26-28), normative content is in the images. Carries the same apparently-inverted caption wording.

---

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] legitimate terminal state (nothing is supposed to happen next)

Notes:



## Evidence

- steps to deadlock: 3
- ranker score: 27.69
- module: `models/generated/ch45/core_4.19.4.11/vertex-gemini/core_4_19_4_11.tla`

### Under no capability flags

Last action to fire: **`AutomaticTeardown`**

Clause that action cites:

```
\* SOURCE: core_4.19.4.11 Protocol State Diagrams
```

Stuck in this state:

```
State 3: <AutomaticTeardown line 63, col 5 to line 67, col 55 of module core_4_19_4_11>
/\ timeoutOccurred = FALSE
/\ ackReceived = TRUE
/\ sessionState = StateTornDown
/\ role = RoleClient
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ timeoutOccurred = FALSE
/\ ackReceived = FALSE
/\ sessionState = StateEstablished
/\ role = RoleClient

State 2: <ReceiveAck line 48, col 5 to line 51, col 56 of module core_4_19_4_11>
/\ timeoutOccurred = FALSE
/\ ackReceived = TRUE
/\ sessionState = StateEstablished
/\ role = RoleClient

State 3: <AutomaticTeardown line 63, col 5 to line 67, col 55 of module core_4_19_4_11>
/\ timeoutOccurred = FALSE
/\ ackReceived = TRUE
/\ sessionState = StateTornDown
/\ role = RoleClient
```

</details>

## Spec text for this section

4.19.4.11. Protocol State Diagrams
Figure 26, “BTP session lifecycle for Central acting as GATT Client” shows the state machine for BTP
session management of a BTP Client Device.
Figure 26. BTP session lifecycle for Central acting as GATT Client
Figure 27, “BTP session lifecycle for Peripheral acting as GATT Server” shows the state machine for
BTP session management of a BTP Server Device.
Figure 27. BTP session lifecycle for Peripheral acting as GATT Server
Note that in Figure 27, “BTP session lifecycle for Peripheral acting as GATT Server”, the state
machine is identical for GATT clients and servers with the distinction that clients send data to
servers via confirmed writes, and servers send data to clients via indications.
Figure 28, “State diagram for BTP session post-establishment” shows the state machine for BTP session maintenance at the protocol level, including liveliness enforcement through keep alive mes­
sages and automatic teardown if acknowledgements are received before the timeout.
Figure 28. State diagram for BTP session post-establishment
