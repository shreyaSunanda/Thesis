# Review: `core_4.12.5.2` — Reliable Message Processing of Incoming Messages

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 47.63
- module: `models/generated/ch45_v3/core_4.12.5.2/vertex-gemini/core_4_12_5_2.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 59, col 5 to line 62, col 295 of module core_4_12_5_2>
/\ closedExchanges = {}
/\ inMsg_msgCounter = 0
/\ ackTable = (ExchangeIds_1 :> [hasEntry |-> FALSE, msgCounter |-> 0, standaloneAckSent |-> FALSE] @@ ExchangeIds_2 :> [hasEntry |-> FALSE, msgCounter |-> 0, standaloneAckSent |-> FALSE])
/\ retransmissionTable = {}
/\ inMsg_aFlag = FALSE
/\ inMsg_groupSession = FALSE
/\ ephemeralExchanges = {}
/\ inMsg_exchangeId = ExchangeIds_1
/\ inMsg_ackMsgCounter = 0
/\ inMsg_isDuplicate = FALSE
/\ inMsg_rFlag = FALSE
/\ sentMessages = {}
/\ inMsg_cFlag = FALSE
/\ inEvent_exchangeId = ExchangeIds_1
/\ deliveredToNextLayer = {}
/\ pendingInput = "AckTimerTriggered"
/\ ackTimerRunning = (ExchangeIds_1 :> FALSE @@ ExchangeIds_2 :> FALSE)
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ closedExchanges = {}
/\ inMsg_msgCounter = 0
/\ ackTable = (ExchangeIds_1 :> [hasEntry |-> FALSE, msgCounter |-> 0, standaloneAckSent |-> FALSE] @@ ExchangeIds_2 :> [hasEntry |-> FALSE, msgCounter |-> 0, standaloneAckSent |-> FALSE])
/\ retransmissionTable = {}
/\ inMsg_aFlag = FALSE
/\ inMsg_groupSession = FALSE
/\ ephemeralExchanges = {}
/\ inMsg_exchangeId = ExchangeIds_1
/\ inMsg_ackMsgCounter = 0
/\ inMsg_isDuplicate = FALSE
/\ inMsg_rFlag = FALSE
/\ sentMessages = {}
/\ inMsg_cFlag = FALSE
/\ inEvent_exchangeId = ExchangeIds_1
/\ deliveredToNextLayer = {}
/\ pendingInput = NoInput
/\ ackTimerRunning = (ExchangeIds_1 :> FALSE @@ ExchangeIds_2 :> FALSE)

State 2: <ReceiveInput line 59, col 5 to line 62, col 295 of module core_4_12_5_2>
/\ closedExchanges = {}
/\ inMsg_msgCounter = 0
/\ ackTable = (ExchangeIds_1 :> [hasEntry |-> FALSE, msgCounter |-> 0, standaloneAckSent |-> FALSE] @@ ExchangeIds_2 :> [hasEntry |-> FALSE, msgCounter |-> 0, standaloneAckSent |-> FALSE])
/\ retransmissionTable = {}
/\ inMsg_aFlag = FALSE
/\ inMsg_groupSession = FALSE
/\ ephemeralExchanges = {}
/\ inMsg_exchangeId = ExchangeIds_1
/\ inMsg_ackMsgCounter = 0
/\ inMsg_isDuplicate = FALSE
/\ inMsg_rFlag = FALSE
/\ sentMessages = {}
/\ inMsg_cFlag = FALSE
/\ inEvent_exchangeId = ExchangeIds_1
/\ deliveredToNextLayer = {}
/\ pendingInput = "AckTimerTriggered"
/\ ackTimerRunning = (ExchangeIds_1 :> FALSE @@ ExchangeIds_2 :> FALSE)
```

</details>

## Spec text for this section

4.12.5.2. Reliable Message Processing of Incoming Messages
A message received from Section 4.7.2, “Message Reception” for reliability processing SHALL be
processed as follows:
1. Verify the message has a legal combination of reliability flags:
a. If the R Flag is set:
i. If Group Session Type AND C Flag = 0, drop the message.
b. If the A Flag is set:
i. If Group Session Type AND C Flag = 0, drop the message.
2. Proceed to Section 4.10.5.1, “Exchange Message Matching”.
3. Proceed to Section 4.12.5.2.1, “Received acknowledgement processing”.
Received acknowledgement processing
1. If the A Flag is set:
a. Query the retransmission table for the Acknowledgement Message Counter contained in the
received message.
i. If there is a match:
A. Remove the entry from the retransmission table.
B. Stop the retransmission timer for that entry.
ii. If there is no match, it indicates that this is either a duplicate acknowledgment or the
Exchange context does not exist.
2. Proceed to Section 4.12.5.2.2, “Standalone acknowledgement processing”.
Standalone acknowledgement processing
1. If the R Flag is set, the received message is requesting an acknowledgement be sent back:
a. If the message is marked as a duplicate:
i. Immediately send a standalone acknowledgment.
ii. If the Exchange is marked as an ephemeral exchange the Exchange SHALL be closed.
iii. Drop the message.
b. Otherwise, instead of sending an acknowledgement immediately upon the receipt of a reliable message from a peer, the receiver SHOULD wait for a time no longer than MRP_STAND­
ALONE_ACK_TIMEOUT before sending a standalone acknowledgment:
i. Add the message counter of the received message to the acknowledgement table to signal
that an outbound acknowledgement is pending. There can be only one outstanding
acknowledgement at a time on a single Exchange. If a pending acknowledgement
already exists for the Exchange, and it has StandaloneAckSent set to false, a standalone
acknowledgment SHALL be sent immediately for that pending message counter, and the
acknowledgement table entry SHALL be replaced for the new message.
ii. Start the acknowledgement timer for the Exchange.
A. If the timer triggers before being cancelled, a standalone acknowledgment SHALL be
sent to the source of the message. Sending this standalone acknowledgment SHALL
NOT remove the acknowledgement table entry and SHALL set the StandaloneAckSent
field of the entry to true.
2. The received message is then delivered to the next processing step of Section 4.7.2, “Message
Reception”.
Receive flow state diagram
The MRP receive flow described above is depicted in Figure Figure 13, “MRP receive flow”.
Figure 13. MRP receive flow
