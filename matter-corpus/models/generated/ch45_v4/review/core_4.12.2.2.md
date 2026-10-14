# Review: `core_4.12.2.2` — Acknowledgements

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 8
- ranker score: 36.68
- module: `models/generated/ch45_v4/core_4.12.2.2/vertex-gemini/core_4_12_2_2.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

Clause that action cites:

```
\* Event delivery mechanism.
```

State in which the input went unhandled:

```
State 8: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<0, 0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ inputSender = NoSender
/\ sentAcks = {}
/\ inputMsgCounter = 3
/\ pendingAcks = (Senders_1 :> <<>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {} @@ Senders_2 :> {})
/\ pendingInput = NoInput

State 2: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"

State 3: <HandleReceiveReliableMessage line 74, col 5 to line 86, col 29 of module core_4_12_2_2>
/\ inputSender = NoSender
/\ sentAcks = {}
/\ inputMsgCounter = 3
/\ pendingAcks = (Senders_1 :> <<0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = NoInput

State 4: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"

State 5: <HandleReceiveReliableMessage line 74, col 5 to line 86, col 29 of module core_4_12_2_2>
/\ inputSender = NoSender
/\ sentAcks = {}
/\ inputMsgCounter = 3
/\ pendingAcks = (Senders_1 :> <<0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = NoInput

State 6: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"

State 7: <HandleReceiveReliableMessage line 74, col 5 to line 86, col 29 of module core_4_12_2_2>
/\ inputSender = NoSender
/\ sentAcks = {}
/\ inputMsgCounter = 3
/\ pendingAcks = (Senders_1 :> <<0, 0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = NoInput

State 8: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<0, 0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

Clause that action cites:

```
\* Event delivery mechanism.
```

State in which the input went unhandled:

```
State 8: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<0, 0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ inputSender = NoSender
/\ sentAcks = {}
/\ inputMsgCounter = 3
/\ pendingAcks = (Senders_1 :> <<>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {} @@ Senders_2 :> {})
/\ pendingInput = NoInput

State 2: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"

State 3: <HandleReceiveReliableMessage line 74, col 5 to line 86, col 29 of module core_4_12_2_2>
/\ inputSender = NoSender
/\ sentAcks = {}
/\ inputMsgCounter = 3
/\ pendingAcks = (Senders_1 :> <<0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = NoInput

State 4: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"

State 5: <HandleReceiveReliableMessage line 74, col 5 to line 86, col 29 of module core_4_12_2_2>
/\ inputSender = NoSender
/\ sentAcks = {}
/\ inputMsgCounter = 3
/\ pendingAcks = (Senders_1 :> <<0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = NoInput

State 6: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"

State 7: <HandleReceiveReliableMessage line 74, col 5 to line 86, col 29 of module core_4_12_2_2>
/\ inputSender = NoSender
/\ sentAcks = {}
/\ inputMsgCounter = 3
/\ pendingAcks = (Senders_1 :> <<0, 0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = NoInput

State 8: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<0, 0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"
```

</details>

## Spec text for this section

4.12.2.2. Acknowledgements
A receiver SHALL acknowledge a reliable message by either using a "piggybacked" acknowledgment in the next message destined to the peer, or a standalone acknowledgment, or both.
The acknowledgement message SHALL set the Acknowledged Message Counter field to the value of
the Message Counter of the reliable message to be acknowledged.
Piggybacking Acknowledgments on Responses
Acknowledgements MAY be conveyed at the same time (i.e. piggybacked) as data in a response message. The receiver tries to optimize message transmission by deferring acknowledgments when a
reliable message is received (see Section 4.12.5.2.2, “Standalone acknowledgement processing”) and
piggybacking outstanding acknowledgments on messages that it needs to send back (see Section
4.12.5.1.1, “Piggyback acknowledgment processing” for more details).
Duplicate Message Detection
Since the reliable messaging protocol has a provision for the sender to retransmit messages, there
is a significant chance that a duplicate message may arrive at the receiver. The receiver SHALL
detect and mark duplicate messages that it receives using the standard authentication and replay
protection mechanisms of the secure message layer (see Section 4.6.5, “Replay Prevention and
Duplicate Message Detection”). The receiver SHALL send an acknowledgment message to the
sender for each instance of an authenticated, reliable message, including duplicates. The reliability
layer SHALL only propagate the first instance of a message to the next higher layer. Any message
marked as a duplicate SHALL be dropped by the reliability layer.
