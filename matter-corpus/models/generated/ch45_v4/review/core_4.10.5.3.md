# Review: `core_4.10.5.3` — Closing an Exchange

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 21.03
- module: `models/generated/ch45_v4/core_4.10.5.3/vertex-gemini/core_4_10_5_3.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 37, col 5 to line 41, col 63 of module core_4_10_5_3>
/\ ackTableHasEntry = FALSE
/\ exchangeState = "Open"
/\ standaloneAckSentFlag = FALSE
/\ standaloneAcksSent = 0
/\ retransmissionsPending = FALSE
/\ pendingInput = "RetransmissionsComplete"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ ackTableHasEntry = FALSE
/\ exchangeState = "Open"
/\ standaloneAckSentFlag = FALSE
/\ standaloneAcksSent = 0
/\ retransmissionsPending = FALSE
/\ pendingInput = NoInput

State 2: <ReceiveInput line 37, col 5 to line 41, col 63 of module core_4_10_5_3>
/\ ackTableHasEntry = FALSE
/\ exchangeState = "Open"
/\ standaloneAckSentFlag = FALSE
/\ standaloneAcksSent = 0
/\ retransmissionsPending = FALSE
/\ pendingInput = "RetransmissionsComplete"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 37, col 5 to line 41, col 63 of module core_4_10_5_3>
/\ ackTableHasEntry = FALSE
/\ exchangeState = "Open"
/\ standaloneAckSentFlag = FALSE
/\ standaloneAcksSent = 0
/\ retransmissionsPending = FALSE
/\ pendingInput = "RetransmissionsComplete"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ ackTableHasEntry = FALSE
/\ exchangeState = "Open"
/\ standaloneAckSentFlag = FALSE
/\ standaloneAcksSent = 0
/\ retransmissionsPending = FALSE
/\ pendingInput = NoInput

State 2: <ReceiveInput line 37, col 5 to line 41, col 63 of module core_4_10_5_3>
/\ ackTableHasEntry = FALSE
/\ exchangeState = "Open"
/\ standaloneAckSentFlag = FALSE
/\ standaloneAcksSent = 0
/\ retransmissionsPending = FALSE
/\ pendingInput = "RetransmissionsComplete"
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
