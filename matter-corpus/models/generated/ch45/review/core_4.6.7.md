# Review: `core_4.6.7` — Counter Processing of Incoming Messages

> ⚠️ **Initial-state deadlock.** The model was stuck before it did anything, which points at an under-constrained `Init` rather than a spec gap. Low priority.

Automated triage: **candidate** — not a teardown-shaped deadlock

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] legitimate terminal state (nothing is supposed to happen next)

Notes:



## Evidence

- steps to deadlock: 1
- ranker score: 37.0
- module: `models/generated/ch45/core_4.6.7/vertex-gemini/core_4_6_7.tla`

### Under no capability flags

Stuck in this state:

```
State 1: <Initial predicate>
/\ unicastStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ reliableMessages = {}
/\ groupDataStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ unsecuredStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ droppedMessages = {}
/\ incomingMessages = {}
/\ groupCtrlStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ unsyncMessages = {}
/\ acceptedMessages = {}
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ unicastStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ reliableMessages = {}
/\ groupDataStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ unsecuredStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ droppedMessages = {}
/\ incomingMessages = {}
/\ groupCtrlStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ unsyncMessages = {}
/\ acceptedMessages = {}
```

</details>

## Spec text for this section

4.6.7. Counter Processing of Incoming Messages
1. Determine the Message Reception State for the sending peer and get the current max_message_counter.
a. Given a decrypted message of Unicast Session Type:
i. Get the session-specific Message Reception State from the Secure Unicast Session Context.
b. Given a decrypted message of Group Session Type:
i. Extract the Source Node ID from the Message Header.
A. If there is no Source Node ID for the message, drop the message.
ii. Get the Message Reception State for the Source Node ID of the given message:
A. If the Security Flags C Flag = 0, get the Data Message Reception State for the peer
node.
B. If the Security Flags C Flag = 1, get the Control Message Reception State for the peer
node.
iii. If there is no Message Reception State for the groupcast message, initiate Section 4.18.4,
“Unsynchronized Message Processing”.
c. Given an unencrypted message:
i. Get the Message Reception State associated with the Unsecured Session Context.
ii. If there is no Message Reception State for the unencrypted message, create it with the
information from the given message.
2. If the Message Counter is outside the valid message counter window, the message SHALL be
marked as a duplicate. Note that while messages may be outside of the window for reasons
other than being a duplicate, and we always mark them as such.
3. If the message is a duplicate:
a. If the message is marked as encrypted, follow Section 4.6.5.2, “Use of Message Reception
State for Encrypted Messages”.
b. If the message is marked as unencrypted, follow Section 4.6.5.3, “Use of Message Reception
State for Unencrypted Messages”.
c. If the message is encrypted and marked as a duplicate, i.e. Message Counter is outside the
valid message counter window or marked as previously received in the Message Reception
State:
i. Perform Section 4.12.5.2, “Reliable Message Processing of Incoming Messages” on the
duplicate message.
d. Otherwise, update the Message Reception State as detailed in Section 4.6.5.1, “Message
Reception State”, and accept the message for further processing.
