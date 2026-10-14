# Review: `core_4.12.6.1` — Retransmission Table

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 26.4
- module: `models/generated/ch45_v4/core_4.12.6.1/vertex-gemini/core_4_12_6_1.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 41, col 5 to line 48, col 65 of module core_4_12_6_1>
/\ state = "OPERATIONAL"
/\ retransmissionTable = {}
/\ appNotifications = {}
/\ inputMsg = [exchange |-> NullContext, counter |-> 0, buffer |-> NullContext]
/\ pendingInput = "RetransmissionTimeout"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "OPERATIONAL"
/\ retransmissionTable = {}
/\ appNotifications = {}
/\ inputMsg = [exchange |-> NullContext, counter |-> 0, buffer |-> NullContext]
/\ pendingInput = NoInput

State 2: <ReceiveInput line 41, col 5 to line 48, col 65 of module core_4_12_6_1>
/\ state = "OPERATIONAL"
/\ retransmissionTable = {}
/\ appNotifications = {}
/\ inputMsg = [exchange |-> NullContext, counter |-> 0, buffer |-> NullContext]
/\ pendingInput = "RetransmissionTimeout"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 41, col 5 to line 48, col 65 of module core_4_12_6_1>
/\ state = "OPERATIONAL"
/\ retransmissionTable = {}
/\ appNotifications = {}
/\ inputMsg = [exchange |-> NullContext, counter |-> 0, buffer |-> NullContext]
/\ pendingInput = "RetransmissionTimeout"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "OPERATIONAL"
/\ retransmissionTable = {}
/\ appNotifications = {}
/\ inputMsg = [exchange |-> NullContext, counter |-> 0, buffer |-> NullContext]
/\ pendingInput = NoInput

State 2: <ReceiveInput line 41, col 5 to line 48, col 65 of module core_4_12_6_1>
/\ state = "OPERATIONAL"
/\ retransmissionTable = {}
/\ appNotifications = {}
/\ inputMsg = [exchange |-> NullContext, counter |-> 0, buffer |-> NullContext]
/\ pendingInput = "RetransmissionTimeout"
```

</details>

## Spec text for this section

4.12.6.1. Retransmission Table
For retransmissions, the sender maintains a retransmission table of context records containing
information on all reliable messages sent that have acknowledgments still pending. Each such reliable message context record includes the following fields:
• Reference to Exchange Context
• Message Counter
• Reference to fully formed, encoded and encrypted message buffer
• Send count
• Retransmission timeout counter
Each time a message that requires acknowledgment is sent, a new retransmission context record is
inserted into the retransmission table or an existing record is updated to increment its send count.
The message is sent a configurable maximum number of times (MRP_MAX_TRANSMISSIONS) and,
if still undelivered, the application is notified of the failure.
