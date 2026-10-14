# Review: `core_4.20.3.11` — Protocol State Diagrams

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 4
- ranker score: 28.83
- module: `models/generated/ch45_v3/core_4.20.3.11/vertex-gemini/core_4_20_3_11.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 4: <ReceiveInput line 19, col 5 to line 22, col 26 of module core_4_20_3_11>
/\ state = "Teardown"
/\ pendingInput = "KeepAlive"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "PostEstablishment"
/\ pendingInput = NoInput

State 2: <ReceiveInput line 19, col 5 to line 22, col 26 of module core_4_20_3_11>
/\ state = "PostEstablishment"
/\ pendingInput = "Ack"

State 3: <HandleAck line 34, col 5 to line 39, col 30 of module core_4_20_3_11>
/\ state = "Teardown"
/\ pendingInput = NoInput

State 4: <ReceiveInput line 19, col 5 to line 22, col 26 of module core_4_20_3_11>
/\ state = "Teardown"
/\ pendingInput = "KeepAlive"
```

</details>

## Spec text for this section

4.20.3.11. Protocol State Diagrams
Figure 33, “PAFTP session lifecycle for Commissioner” shows the state machine for PAFTP session
management of a PAFTP Commissioner Device.
Figure 33. PAFTP session lifecycle for Commissioner
Figure 34, “PAFTP session lifecycle for Commissionable Device” shows the state machine for PAFTP
session management of a Commissionable Device.
Figure 34. PAFTP session lifecycle for Commissionable Device
Figure 35, “State diagram for PAFTP session post-establishment” shows the state machine for PAFTP
session maintenance at the protocol level, including liveliness enforcement through keep alive messages and automatic teardown if acknowledgements are received before the timeout.
Figure 35. State diagram for PAFTP session post-establishment
