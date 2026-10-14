# Review: `core_4.7.2` — Message Reception

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 4
- ranker score: 20.92
- module: `models/generated/ch45_v3/core_4.7.2/vertex-gemini/core_4_7_2.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 4: <ReceiveInput line 62, col 5 to line 65, col 132 of module core_4_7_2>
/\ state = "CheckSecurity"
/\ now = 0
/\ sessionTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ sessionKeys = (SessionIDs_1 :> {} @@ SessionIDs_2 :> {})
/\ deliveredMessage = NullMessage
/\ nextHigherLayer = "None"
/\ currentMessage = [version |-> 0, sessionType |-> "SecureUnicast", dsizGroupPresent |-> FALSE, dsizZero |-> FALSE, sFlagZero |-> FALSE, sessionId |-> SessionIDs_1, pFlag |-> FALSE, transport |-> "UDP", isUnicast |-> FALSE]
/\ activeTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ pendingInput = "ReceiveMessage"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "Idle"
/\ now = 0
/\ sessionTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ sessionKeys = (SessionIDs_1 :> {} @@ SessionIDs_2 :> {})
/\ deliveredMessage = NullMessage
/\ nextHigherLayer = "None"
/\ currentMessage = [version |-> 0, sessionType |-> "SecureUnicast", dsizGroupPresent |-> FALSE, dsizZero |-> FALSE, sFlagZero |-> FALSE, sessionId |-> SessionIDs_1, pFlag |-> FALSE, transport |-> "UDP", isUnicast |-> FALSE]
/\ activeTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ pendingInput = NoInput

State 2: <ReceiveInput line 62, col 5 to line 65, col 132 of module core_4_7_2>
/\ state = "Idle"
/\ now = 0
/\ sessionTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ sessionKeys = (SessionIDs_1 :> {} @@ SessionIDs_2 :> {})
/\ deliveredMessage = NullMessage
/\ nextHigherLayer = "None"
/\ currentMessage = [version |-> 0, sessionType |-> "SecureUnicast", dsizGroupPresent |-> FALSE, dsizZero |-> FALSE, sFlagZero |-> FALSE, sessionId |-> SessionIDs_1, pFlag |-> FALSE, transport |-> "UDP", isUnicast |-> FALSE]
/\ activeTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ pendingInput = "ReceiveMessage"

State 3: <ValidityChecks line 81, col 5 to line 89, col 108 of module core_4_7_2>
/\ state = "CheckSecurity"
/\ now = 0
/\ sessionTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ sessionKeys = (SessionIDs_1 :> {} @@ SessionIDs_2 :> {})
/\ deliveredMessage = NullMessage
/\ nextHigherLayer = "None"
/\ currentMessage = [version |-> 0, sessionType |-> "SecureUnicast", dsizGroupPresent |-> FALSE, dsizZero |-> FALSE, sFlagZero |-> FALSE, sessionId |-> SessionIDs_1, pFlag |-> FALSE, transport |-> "UDP", isUnicast |-> FALSE]
/\ activeTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ pendingInput = NoInput

State 4: <ReceiveInput line 62, col 5 to line 65, col 132 of module core_4_7_2>
/\ state = "CheckSecurity"
/\ now = 0
/\ sessionTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ sessionKeys = (SessionIDs_1 :> {} @@ SessionIDs_2 :> {})
/\ deliveredMessage = NullMessage
/\ nextHigherLayer = "None"
/\ currentMessage = [version |-> 0, sessionType |-> "SecureUnicast", dsizGroupPresent |-> FALSE, dsizZero |-> FALSE, sFlagZero |-> FALSE, sessionId |-> SessionIDs_1, pFlag |-> FALSE, transport |-> "UDP", isUnicast |-> FALSE]
/\ activeTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ pendingInput = "ReceiveMessage"
```

</details>

## Spec text for this section

4.7.2. Message Reception
To process a received message, the following steps SHALL be performed in order:
1. Perform validity checks on the message; if any fail, processing of the message SHALL stop, and a
'message invalid' error SHOULD be indicated to the next higher layer:
a. The Version field SHALL be 0.
b. If the message is of Secure Unicast Session Type:
i. The DSIZ field SHALL NOT indicate a Group ID is present.
c. If the message is of Group Session Type:
i. The DSIZ field SHALL NOT be 0.
ii. The S Flag field SHALL NOT be 0.
2. If the message is NOT of Unsecured Session Type:
a. Obtain the Privacy and Encryption Keys associated with the given Session ID:
i. If no keys are found, security processing SHALL indicate a failure to the next higher
layer with a status of 'message security failed' and no further security processing SHALL
be done on this message.
b. For each Privacy and Encryption Key, of which there may be more than one in the case of
group messages:
i. If the P Flag is set, follow Section 4.9.4, “Privacy Processing of Incoming Messages” to
deobfuscate the message.
ii. Follow Section 4.8.3, “Security Processing of Incoming Messages” to decrypt and authenticate the message.
3. Follow Section 4.6.7, “Counter Processing of Incoming Messages” to enforce replay protection
and duplicate detection.
4. If the message transport is UDP, follow Section 4.12.5.2, “Reliable Message Processing of Incoming Messages” to process message reliability.
5. If the message’s Session Type is a Unicast Session:
a. Set SessionTimestamp and ActiveTimestamp to a timestamp from a clock which would allow for
the eventual determination of the last session use relative to other sessions.
6. The received message is then delivered to Section 4.10.5, “Exchange Message Processing”.
