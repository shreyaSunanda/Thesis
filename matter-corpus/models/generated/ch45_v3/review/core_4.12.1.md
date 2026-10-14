# Review: `core_4.12.1` — Reliable Messaging Header Fields

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 22.59
- module: `models/generated/ch45_v3/core_4.12.1/vertex-gemini/core_4_12_1.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 33, col 5 to line 36, col 31 of module core_4_12_1>
/\ messageOut = [ rFlag |-> FALSE,
  aFlag |-> FALSE,
  ackMsgCounter |-> 3,
  isStandaloneAck |-> FALSE ]
/\ pendingInput = "ReceiveReliableMessage"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ messageOut = [ rFlag |-> FALSE,
  aFlag |-> FALSE,
  ackMsgCounter |-> 3,
  isStandaloneAck |-> FALSE ]
/\ pendingInput = NoInput

State 2: <ReceiveInput line 33, col 5 to line 36, col 31 of module core_4_12_1>
/\ messageOut = [ rFlag |-> FALSE,
  aFlag |-> FALSE,
  ackMsgCounter |-> 3,
  isStandaloneAck |-> FALSE ]
/\ pendingInput = "ReceiveReliableMessage"
```

</details>

## Spec text for this section

4.12.1. Reliable Messaging Header Fields
The following fields are defined in the Exchange Flags for use exclusively by MRP:
• R Flag
Indicates a reliable message. This flag SHALL be set by the sender when a message being sent
requires the receiver to send back an acknowledgment. To support unreliable messages, this
flag bit MAY be clear, so that no acknowledgements are requested from the receiver.
• A Flag
Indicates the message is acting as an acknowledgement. This flag MAY be set on any message.
When set, the Acknowledged Message Counter field SHALL be present and valid. This flag SHALL
always be set for MRP Standalone Acknowledgement messages.
• Acknowledged Message Counter
This field SHALL be set to the Message Counter of the message that is being acknowledged.
