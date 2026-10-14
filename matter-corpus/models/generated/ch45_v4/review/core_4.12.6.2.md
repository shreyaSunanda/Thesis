# Review: `core_4.12.6.2` — Acknowledgement Table

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 21.46
- module: `models/generated/ch45_v4/core_4.12.6.2/vertex-gemini/core_4_12_6_2.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

Clause that action cites:

```
\* REQUIRED - Exactly one action delivering an event.
```

State in which the input went unhandled:

```
State 2: <ReceiveInput line 53, col 5 to line 60, col 36 of module core_4_12_6_2>
/\ state = (ExchangeIds_1 :> "OPEN" @@ ExchangeIds_2 :> "OPEN")
/\ ackTable = {}
/\ in_retransListEmpty = FALSE
/\ in_msgCounter = MessageCounters_1
/\ pendingInput = "RetransmissionsCompleted"
/\ in_exchangeId = ExchangeIds_1
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = (ExchangeIds_1 :> "OPEN" @@ ExchangeIds_2 :> "OPEN")
/\ ackTable = {}
/\ in_retransListEmpty = FALSE
/\ in_msgCounter = MessageCounters_1
/\ pendingInput = NoInput
/\ in_exchangeId = ExchangeIds_1

State 2: <ReceiveInput line 53, col 5 to line 60, col 36 of module core_4_12_6_2>
/\ state = (ExchangeIds_1 :> "OPEN" @@ ExchangeIds_2 :> "OPEN")
/\ ackTable = {}
/\ in_retransListEmpty = FALSE
/\ in_msgCounter = MessageCounters_1
/\ pendingInput = "RetransmissionsCompleted"
/\ in_exchangeId = ExchangeIds_1
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

Clause that action cites:

```
\* REQUIRED - Exactly one action delivering an event.
```

State in which the input went unhandled:

```
State 2: <ReceiveInput line 53, col 5 to line 60, col 36 of module core_4_12_6_2>
/\ state = (ExchangeIds_1 :> "OPEN" @@ ExchangeIds_2 :> "OPEN")
/\ ackTable = {}
/\ in_retransListEmpty = FALSE
/\ in_msgCounter = MessageCounters_1
/\ pendingInput = "RetransmissionsCompleted"
/\ in_exchangeId = ExchangeIds_1
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = (ExchangeIds_1 :> "OPEN" @@ ExchangeIds_2 :> "OPEN")
/\ ackTable = {}
/\ in_retransListEmpty = FALSE
/\ in_msgCounter = MessageCounters_1
/\ pendingInput = NoInput
/\ in_exchangeId = ExchangeIds_1

State 2: <ReceiveInput line 53, col 5 to line 60, col 36 of module core_4_12_6_2>
/\ state = (ExchangeIds_1 :> "OPEN" @@ ExchangeIds_2 :> "OPEN")
/\ ackTable = {}
/\ in_retransListEmpty = FALSE
/\ in_msgCounter = MessageCounters_1
/\ pendingInput = "RetransmissionsCompleted"
/\ in_exchangeId = ExchangeIds_1
```

</details>

## Spec text for this section

4.12.6.2. Acknowledgement Table
The receiver maintains an acknowledgement table of context records containing information on
each reliable message for which an acknowledgment SHALL be sent. Each such reliable message
context record includes the following fields:
• Reference to Exchange Context
• Message Counter
• A boolean, StandaloneAckSent, indicating whether a standalone acknowledgement has been sent
for this message counter. Initially false.
An entry SHALL remain in the table until one of the following things happens:
1. The exchange associated with the entry is closed. See Section 4.10.5.3, “Closing an Exchange”.
2. The exchange associated with the entry has switched to track a pending acknowledgement for a
new message counter value. See Section 4.12.5.2.2, “Standalone acknowledgement processing”.
3. A message that is not a standalone acknowledgement is sent which serves as an acknowledgement for the entry. See Section 4.12.5.1.1, “Piggyback acknowledgment processing”.
