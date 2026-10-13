# Review: `core_4.10.5.3` — Closing an Exchange

Automated triage: **candidate** — neither this section nor any section it references says what happens after the teardown

## DRAFT VERDICT (Claude's first pass - please check)

**legitimate terminal state**

Spec: "If the retransmission list for the Exchange is empty, remove the Exchange." Stuck state: exchangeState="CLOSED", retransmissions={}. Closing an exchange is inherently terminal - there is nothing after removal.

---

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] legitimate terminal state (nothing is supposed to happen next)

Notes:



## Evidence

- steps to deadlock: 2
- ranker score: 21.03
- module: `models/generated/ch45/core_4.10.5.3/vertex-gemini/core_4_10_5_3.tla`

### Under no capability flags

Last action to fire: **`InitiateClose`**

Clause that action cites:

```
\* SOURCE: core_4.10.5.3
```

Stuck in this state:

```
State 2: <InitiateClose line 29, col 5 to line 48, col 36 of module core_4_10_5_3>
/\ exchangeState = "CLOSED"
/\ closePending = FALSE
/\ pendingAcks = {}
/\ sentMessages = {[id |-> AckIds_1, type |-> "StandaloneAck"]}
/\ retransmissions = {}
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ exchangeState = "OPEN"
/\ closePending = FALSE
/\ pendingAcks = {[id |-> AckIds_1, standaloneAckSent |-> FALSE]}
/\ sentMessages = {}
/\ retransmissions = {}

State 2: <InitiateClose line 29, col 5 to line 48, col 36 of module core_4_10_5_3>
/\ exchangeState = "CLOSED"
/\ closePending = FALSE
/\ pendingAcks = {}
/\ sentMessages = {[id |-> AckIds_1, type |-> "StandaloneAck"]}
/\ retransmissions = {}
```

</details>

## Spec text for this section

4.10.5.3. Closing an Exchange
An Exchange MAY be closed by the application layer or a fatal connection error from the lower
message layer. The process of closing an Exchange follows:
1. Any pending acknowledgements associated with the Exchange SHALL be flushed. If there is a
pending acknowledgment in the acknowledgement table for the Exchange and it has StandaloneAckSent set to false:
a. Immediately send a standalone acknowledgement for the pending acknowledgement.
b. Remove the acknowledgement table entry for the pending acknowledgement.
2. Wait for all pending retransmissions associated with the Exchange to complete.
a. If the retransmission list for the Exchange is empty, remove the Exchange.
b. Otherwise, leave the Exchange open and only close it once the retransmission list is empty.
These steps are depicted in Figure 11, “Exchange close flow”.
Figure 11. Exchange close flow
