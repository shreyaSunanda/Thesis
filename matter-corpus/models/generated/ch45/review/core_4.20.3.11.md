# Review: `core_4.20.3.11` — Protocol State Diagrams

Automated triage: **candidate** — neither this section nor any section it references says what happens after the teardown

## DRAFT VERDICT (Claude's first pass - please check)

**not reviewable - content is in figures**

This section contains ONLY figure captions (Figures 33-35). The actual state machine is in the images, which the PDF text extractor cannot read, so the model was built from almost no normative text. The deadlock says nothing about the spec. SEPARATE OBSERVATION: the caption reads "automatic teardown if acknowledgements are received before the timeout" - that appears to be an editorial error in the spec; teardown should surely follow acknowledgements NOT being received.

---

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] legitimate terminal state (nothing is supposed to happen next)

Notes:



## Evidence

- steps to deadlock: 2
- ranker score: 28.83
- module: `models/generated/ch45/core_4.20.3.11/vertex-gemini/core_4_20_3_11.tla`

### Under no capability flags

Last action to fire: **`Teardown`**

Clause that action cites:

```
\* SOURCE: core_4.20.3.11 Protocol State Diagrams
\* "automatic teardown if acknowledgements are received before the timeout"
```

Stuck in this state:

```
State 2: <Teardown line 28, col 5 to line 32, col 58 of module core_4_20_3_11>
/\ state = "Teardown"
/\ ackReceived = TRUE
/\ messages = {}
/\ timeoutExpired = FALSE
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "PostEstablishment"
/\ ackReceived = TRUE
/\ messages = {}
/\ timeoutExpired = FALSE

State 2: <Teardown line 28, col 5 to line 32, col 58 of module core_4_20_3_11>
/\ state = "Teardown"
/\ ackReceived = TRUE
/\ messages = {}
/\ timeoutExpired = FALSE
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
