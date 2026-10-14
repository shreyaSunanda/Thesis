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
- module: `models/generated/ch45_v4/core_4.7.2/vertex-gemini/core_4_7_2.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 4: <ReceiveInput line 67, col 5 to line 70, col 125 of module core_4_7_2>
/\ state = "VALIDITY_CHECKS"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> FALSE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> FALSE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "UDP" ]
/\ pendingInput = "ReceiveMessage"
/\ errorState = "none"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "IDLE"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> TRUE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> TRUE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "TCP" ]
/\ pendingInput = NoInput
/\ errorState = "none"

State 2: <ReceiveInput line 67, col 5 to line 70, col 125 of module core_4_7_2>
/\ state = "IDLE"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> TRUE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> TRUE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "TCP" ]
/\ pendingInput = "ReceiveMessage"
/\ errorState = "none"

State 3: <HandleReceiveMessage line 74, col 5 to line 82, col 54 of module core_4_7_2>
/\ state = "VALIDITY_CHECKS"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> FALSE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> FALSE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "UDP" ]
/\ pendingInput = NoInput
/\ errorState = "none"

State 4: <ReceiveInput line 67, col 5 to line 70, col 125 of module core_4_7_2>
/\ state = "VALIDITY_CHECKS"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> FALSE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> FALSE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "UDP" ]
/\ pendingInput = "ReceiveMessage"
/\ errorState = "none"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 4: <ReceiveInput line 67, col 5 to line 70, col 125 of module core_4_7_2>
/\ state = "VALIDITY_CHECKS"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> FALSE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> FALSE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "UDP" ]
/\ pendingInput = "ReceiveMessage"
/\ errorState = "none"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "IDLE"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> TRUE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> TRUE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "TCP" ]
/\ pendingInput = NoInput
/\ errorState = "none"

State 2: <ReceiveInput line 67, col 5 to line 70, col 125 of module core_4_7_2>
/\ state = "IDLE"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> TRUE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> TRUE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "TCP" ]
/\ pendingInput = "ReceiveMessage"
/\ errorState = "none"

State 3: <HandleReceiveMessage line 74, col 5 to line 82, col 54 of module core_4_7_2>
/\ state = "VALIDITY_CHECKS"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> FALSE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> FALSE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "UDP" ]
/\ pendingInput = NoInput
/\ errorState = "none"

State 4: <ReceiveInput line 67, col 5 to line 70, col 125 of module core_4_7_2>
/\ state = "VALIDITY_CHECKS"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> FALSE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> FALSE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "UDP" ]
/\ pendingInput = "ReceiveMessage"
/\ errorState = "none"
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
