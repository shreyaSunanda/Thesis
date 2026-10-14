# Review: `core_4.6.7` — Counter Processing of Incoming Messages

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 37.0
- module: `models/generated/ch45_v3/core_4.6.7/vertex-gemini/core_4_6_7.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 68, col 5 to line 78, col 146 of module core_4_6_7>
/\ groupUnsync = 0
/\ msgCFlag = 0
/\ stateMaxCounter = ([type |-> "Unicast", peer |-> NodeIds_1] :> 0 @@ [type |-> "Unicast", peer |-> NodeIds_2] :> 0 @@ [type |-> "Unicast", peer |-> NullNodeId] :> 0 @@ [type |-> "GroupData", peer |-> NodeIds_1] :> 0 @@ [type |-> "GroupData", peer |-> NodeIds_2] :> 0 @@ [type |-> "GroupData", peer |-> NullNodeId] :> 0 @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> 0 @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> 0 @@ [type |-> "GroupControl", peer |-> NullNodeId] :> 0 @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> 0 @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> 0 @@ [type |-> "Unsecured", peer |-> NullNodeId] :> 0)
/\ reliableProcessing = 0
/\ follow4_6_5_2 = 0
/\ dropped = 0
/\ follow4_6_5_3 = 0
/\ accepted = 0
/\ msgSource = NodeIds_1
/\ stateExists = ([type |-> "Unicast", peer |-> NodeIds_1] :> FALSE @@ [type |-> "Unicast", peer |-> NodeIds_2] :> FALSE @@ [type |-> "Unicast", peer |-> NullNodeId] :> FALSE @@ [type |-> "GroupData", peer |-> NodeIds_1] :> FALSE @@ [type |-> "GroupData", peer |-> NodeIds_2] :> FALSE @@ [type |-> "GroupData", peer |-> NullNodeId] :> FALSE @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> FALSE @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> FALSE @@ [type |-> "GroupControl", peer |-> NullNodeId] :> FALSE @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> FALSE @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> FALSE @@ [type |-> "Unsecured", peer |-> NullNodeId] :> FALSE)
/\ msgCounter = 0
/\ pendingInput = "ReceiveUnicastMessage"
/\ stateReceived = ([type |-> "Unicast", peer |-> NodeIds_1] :> {} @@ [type |-> "Unicast", peer |-> NodeIds_2] :> {} @@ [type |-> "Unicast", peer |-> NullNodeId] :> {} @@ [type |-> "GroupData", peer |-> NodeIds_1] :> {} @@ [type |-> "GroupData", peer |-> NodeIds_2] :> {} @@ [type |-> "GroupData", peer |-> NullNodeId] :> {} @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> {} @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> {} @@ [type |-> "GroupControl", peer |-> NullNodeId] :> {} @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> {} @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> {} @@ [type |-> "Unsecured", peer |-> NullNodeId] :> {})
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ groupUnsync = 0
/\ msgCFlag = 0
/\ stateMaxCounter = ([type |-> "Unicast", peer |-> NodeIds_1] :> 0 @@ [type |-> "Unicast", peer |-> NodeIds_2] :> 0 @@ [type |-> "Unicast", peer |-> NullNodeId] :> 0 @@ [type |-> "GroupData", peer |-> NodeIds_1] :> 0 @@ [type |-> "GroupData", peer |-> NodeIds_2] :> 0 @@ [type |-> "GroupData", peer |-> NullNodeId] :> 0 @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> 0 @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> 0 @@ [type |-> "GroupControl", peer |-> NullNodeId] :> 0 @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> 0 @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> 0 @@ [type |-> "Unsecured", peer |-> NullNodeId] :> 0)
/\ reliableProcessing = 0
/\ follow4_6_5_2 = 0
/\ dropped = 0
/\ follow4_6_5_3 = 0
/\ accepted = 0
/\ msgSource = NodeIds_1
/\ stateExists = ([type |-> "Unicast", peer |-> NodeIds_1] :> FALSE @@ [type |-> "Unicast", peer |-> NodeIds_2] :> FALSE @@ [type |-> "Unicast", peer |-> NullNodeId] :> FALSE @@ [type |-> "GroupData", peer |-> NodeIds_1] :> FALSE @@ [type |-> "GroupData", peer |-> NodeIds_2] :> FALSE @@ [type |-> "GroupData", peer |-> NullNodeId] :> FALSE @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> FALSE @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> FALSE @@ [type |-> "GroupControl", peer |-> NullNodeId] :> FALSE @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> FALSE @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> FALSE @@ [type |-> "Unsecured", peer |-> NullNodeId] :> FALSE)
/\ msgCounter = 0
/\ pendingInput = NoInput
/\ stateReceived = ([type |-> "Unicast", peer |-> NodeIds_1] :> {} @@ [type |-> "Unicast", peer |-> NodeIds_2] :> {} @@ [type |-> "Unicast", peer |-> NullNodeId] :> {} @@ [type |-> "GroupData", peer |-> NodeIds_1] :> {} @@ [type |-> "GroupData", peer |-> NodeIds_2] :> {} @@ [type |-> "GroupData", peer |-> NullNodeId] :> {} @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> {} @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> {} @@ [type |-> "GroupControl", peer |-> NullNodeId] :> {} @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> {} @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> {} @@ [type |-> "Unsecured", peer |-> NullNodeId] :> {})

State 2: <ReceiveInput line 68, col 5 to line 78, col 146 of module core_4_6_7>
/\ groupUnsync = 0
/\ msgCFlag = 0
/\ stateMaxCounter = ([type |-> "Unicast", peer |-> NodeIds_1] :> 0 @@ [type |-> "Unicast", peer |-> NodeIds_2] :> 0 @@ [type |-> "Unicast", peer |-> NullNodeId] :> 0 @@ [type |-> "GroupData", peer |-> NodeIds_1] :> 0 @@ [type |-> "GroupData", peer |-> NodeIds_2] :> 0 @@ [type |-> "GroupData", peer |-> NullNodeId] :> 0 @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> 0 @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> 0 @@ [type |-> "GroupControl", peer |-> NullNodeId] :> 0 @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> 0 @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> 0 @@ [type |-> "Unsecured", peer |-> NullNodeId] :> 0)
/\ reliableProcessing = 0
/\ follow4_6_5_2 = 0
/\ dropped = 0
/\ follow4_6_5_3 = 0
/\ accepted = 0
/\ msgSource = NodeIds_1
/\ stateExists = ([type |-> "Unicast", peer |-> NodeIds_1] :> FALSE @@ [type |-> "Unicast", peer |-> NodeIds_2] :> FALSE @@ [type |-> "Unicast", peer |-> NullNodeId] :> FALSE @@ [type |-> "GroupData", peer |-> NodeIds_1] :> FALSE @@ [type |-> "GroupData", peer |-> NodeIds_2] :> FALSE @@ [type |-> "GroupData", peer |-> NullNodeId] :> FALSE @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> FALSE @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> FALSE @@ [type |-> "GroupControl", peer |-> NullNodeId] :> FALSE @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> FALSE @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> FALSE @@ [type |-> "Unsecured", peer |-> NullNodeId] :> FALSE)
/\ msgCounter = 0
/\ pendingInput = "ReceiveUnicastMessage"
/\ stateReceived = ([type |-> "Unicast", peer |-> NodeIds_1] :> {} @@ [type |-> "Unicast", peer |-> NodeIds_2] :> {} @@ [type |-> "Unicast", peer |-> NullNodeId] :> {} @@ [type |-> "GroupData", peer |-> NodeIds_1] :> {} @@ [type |-> "GroupData", peer |-> NodeIds_2] :> {} @@ [type |-> "GroupData", peer |-> NullNodeId] :> {} @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> {} @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> {} @@ [type |-> "GroupControl", peer |-> NullNodeId] :> {} @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> {} @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> {} @@ [type |-> "Unsecured", peer |-> NullNodeId] :> {})
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
