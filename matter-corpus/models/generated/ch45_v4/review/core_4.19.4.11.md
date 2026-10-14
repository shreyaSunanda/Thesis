# Review: `core_4.19.4.11` — Protocol State Diagrams

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 27.69
- module: `models/generated/ch45_v4/core_4.19.4.11/vertex-gemini/core_4_19_4_11.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 31, col 5 to line 34, col 42 of module core_4_19_4_11>
/\ state = "PostEstablishment"
/\ lastSendMethod = "None"
/\ pendingInput = "AckTimeout"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "PostEstablishment"
/\ lastSendMethod = "None"
/\ pendingInput = NoInput

State 2: <ReceiveInput line 31, col 5 to line 34, col 42 of module core_4_19_4_11>
/\ state = "PostEstablishment"
/\ lastSendMethod = "None"
/\ pendingInput = "AckTimeout"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 31, col 5 to line 34, col 42 of module core_4_19_4_11>
/\ state = "PostEstablishment"
/\ lastSendMethod = "None"
/\ pendingInput = "AckTimeout"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "PostEstablishment"
/\ lastSendMethod = "None"
/\ pendingInput = NoInput

State 2: <ReceiveInput line 31, col 5 to line 34, col 42 of module core_4_19_4_11>
/\ state = "PostEstablishment"
/\ lastSendMethod = "None"
/\ pendingInput = "AckTimeout"
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
