# Review: `core_4.18.5` — Message Counter Synchronization Exchange

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 48.36
- module: `models/generated/ch45_v4/core_4.18.5/vertex-gemini/core_4_18_5.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 99, col 5 to line 108, col 141 of module core_4_18_5>
/\ inDestId = 0
/\ localGlobalGroupCounter = 100
/\ inSourceId = 0
/\ inSyncCounter = 0
/\ outMsg = [type |-> "None"]
/\ timerArmed = FALSE
/\ inExchangeId = 0
/\ inChallengeOrResponse = 0
/\ peerMessageReceptionState = [counter |-> 0, synchronized |-> TRUE, bitmapCleared |-> TRUE]
/\ activeExchange = [active |-> FALSE, exchangeId |-> 0, challenge |-> 0, peerId |-> 0]
/\ syncState = "Idle"
/\ queuedMessagesCount = 0
/\ pendingInput = "JitterTimerExpired"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ inDestId = 0
/\ localGlobalGroupCounter = 100
/\ inSourceId = 0
/\ inSyncCounter = 0
/\ outMsg = [type |-> "None"]
/\ timerArmed = FALSE
/\ inExchangeId = 0
/\ inChallengeOrResponse = 0
/\ peerMessageReceptionState = [counter |-> 0, synchronized |-> TRUE, bitmapCleared |-> TRUE]
/\ activeExchange = [active |-> FALSE, exchangeId |-> 0, challenge |-> 0, peerId |-> 0]
/\ syncState = "Idle"
/\ queuedMessagesCount = 0
/\ pendingInput = NoInput

State 2: <ReceiveInput line 99, col 5 to line 108, col 141 of module core_4_18_5>
/\ inDestId = 0
/\ localGlobalGroupCounter = 100
/\ inSourceId = 0
/\ inSyncCounter = 0
/\ outMsg = [type |-> "None"]
/\ timerArmed = FALSE
/\ inExchangeId = 0
/\ inChallengeOrResponse = 0
/\ peerMessageReceptionState = [counter |-> 0, synchronized |-> TRUE, bitmapCleared |-> TRUE]
/\ activeExchange = [active |-> FALSE, exchangeId |-> 0, challenge |-> 0, peerId |-> 0]
/\ syncState = "Idle"
/\ queuedMessagesCount = 0
/\ pendingInput = "JitterTimerExpired"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 99, col 5 to line 108, col 141 of module core_4_18_5>
/\ inDestId = 0
/\ localGlobalGroupCounter = 100
/\ inSourceId = 0
/\ inSyncCounter = 0
/\ outMsg = [type |-> "None"]
/\ timerArmed = FALSE
/\ inExchangeId = 0
/\ inChallengeOrResponse = 0
/\ peerMessageReceptionState = [counter |-> 0, synchronized |-> TRUE, bitmapCleared |-> TRUE]
/\ activeExchange = [active |-> FALSE, exchangeId |-> 0, challenge |-> 0, peerId |-> 0]
/\ syncState = "Idle"
/\ queuedMessagesCount = 0
/\ pendingInput = "JitterTimerExpired"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ inDestId = 0
/\ localGlobalGroupCounter = 100
/\ inSourceId = 0
/\ inSyncCounter = 0
/\ outMsg = [type |-> "None"]
/\ timerArmed = FALSE
/\ inExchangeId = 0
/\ inChallengeOrResponse = 0
/\ peerMessageReceptionState = [counter |-> 0, synchronized |-> TRUE, bitmapCleared |-> TRUE]
/\ activeExchange = [active |-> FALSE, exchangeId |-> 0, challenge |-> 0, peerId |-> 0]
/\ syncState = "Idle"
/\ queuedMessagesCount = 0
/\ pendingInput = NoInput

State 2: <ReceiveInput line 99, col 5 to line 108, col 141 of module core_4_18_5>
/\ inDestId = 0
/\ localGlobalGroupCounter = 100
/\ inSourceId = 0
/\ inSyncCounter = 0
/\ outMsg = [type |-> "None"]
/\ timerArmed = FALSE
/\ inExchangeId = 0
/\ inChallengeOrResponse = 0
/\ peerMessageReceptionState = [counter |-> 0, synchronized |-> TRUE, bitmapCleared |-> TRUE]
/\ activeExchange = [active |-> FALSE, exchangeId |-> 0, challenge |-> 0, peerId |-> 0]
/\ syncState = "Idle"
/\ queuedMessagesCount = 0
/\ pendingInput = "JitterTimerExpired"
```

</details>

## Spec text for this section

4.18.5. Message Counter Synchronization Exchange
A message synchronization exchange starts by sending the MsgCounterSyncReq message to the
peer Node that sent the message with unknown message counter. When a synchronization request
is triggered by an incoming multicast message, the Node SHALL first wait for a uniformly random
amount of time between 0 and MSG_COUNTER_SYNC_REQ_JITTER.
The sender of the MsgCounterSyncReq message SHALL:
1. Set the Message Header fields as follows:
a. The S Flag SHALL be set to 1.
b. The DSIZ field SHALL be set to 1.
c. The P Flag SHALL be set to 1.
d. The C Flag SHALL be set to 1.
e. The Session Type field SHALL be set to 1.
f. The Session ID field SHALL be set to the Group Session Id for the operational group key
being synchronized.
g. The Source Node ID field SHALL be set to the Node ID of the sender Node.
h. The Destination Node ID field SHALL be set to the Source Node ID of the message that triggered the synchronization attempt.
2. Create a new synchronization Exchange.
a. The Exchange ID of the message SHALL be set to match the new Exchange.
b. The I Flag SHALL be set to 1.
c. The A Flag SHALL be set to 0.
d. The R Flag SHALL be set to 1.
3. Set the Challenge field to the value returned by Crypto_DRBG(len = 8 * 8) and store that value to
resolve synchronization responses from the destination peer.
4. Arm a timer to enforce that a synchronization response is received before MSG_COUNTER_SYNC_TIMEOUT.
a. Upon firing of the timer:
i. The synchronization exchange SHALL be closed.
ii. Any message waiting on synchronization associated with the exchange SHALL be discarded.
b. The timer SHALL be stopped upon receipt of an authenticated MsgCounterSyncRsp message
that matches:
i. The Source Node ID field matches the Destination Node ID field of the most recent MsgCounterSyncReq message generated for that Node.
ii. The Response field corresponds to the Challenge field of the MsgCounterSyncReq message.
5. Invoke Section 4.7.1, “Message Transmission” using parameters from step 1 to encrypt and then
send the request message over UDP to the IPv6 unicast address of the destination.
a. The request message SHALL use the same operational group key as the message which triggered synchronization.
b. The group key SHALL be known/derivable by both parties (sender and receiver).
The receiver of MsgCounterSyncReq SHALL:
1. Verify the Destination Node ID field SHALL match the Node ID of the receiver, otherwise discard
the message.
2. Respond with MsgCounterSyncRsp.
The sender of the MsgCounterSyncRsp response message SHALL:
1. Set the Message Header fields as follows:
a. The S Flag SHALL be set to 1.
b. The DSIZ field SHALL be set to 1.
c. The P Flag SHALL be set to 1.
d. The C Flag SHALL be set to 1.
e. The Session Type field SHALL be set to 1.
f. The Session ID field SHALL be set to the Group Session Id for the operational group key
being synchronized.
g. The Source Node ID field SHALL be set to the Node ID of the sender Node.
h. The Destination Node ID field SHALL be set to the Source Node ID of the MsgCounterSyncReq.
2. Set the MsgCounterSyncRsp payload fields as follows:
a. The Response field SHALL be set to the value of the Challenge field from the MsgCounterSyncReq.
b. The Synchronized Counter field SHALL be set to the current Global Group Encrypted Data
Message Counter of the sender.
3. Use the same exchange context as the MsgCounterSyncReq being responded to.
a. The Exchange ID of the message SHALL be set to the Exchange ID of the MsgCounterSyncReq.
b. The I Flag SHALL be set to 0.
c. The A Flag SHALL be set to 1.
d. The R Flag SHALL be set to 1.
4. Invoke Section 4.7.1, “Message Transmission” using parameters from step 1 to encrypt and then
send the response message over UDP to the IPv6 unicast address of the destination.
The receiver of the MsgCounterSyncRsp message SHALL:
1. Verify the MsgCounterSyncRsp matches a previously sent MsgCounterSyncReq:
a. An active synchronization exchange SHALL exist with the source node.
b. The Exchange ID field SHALL match the Exchange ID used for the original MsgCounterSyncReq message.
c. The Response field SHALL match the Challenge field used for the original MsgCounterSyncReq message.
d. The Destination Node ID field SHALL match the Source Node ID of the original MsgCounterSyncReq message.
e. The Source Node ID field SHALL match the Destination Node ID of the original MsgCounterSyncReq message.
2. On verification failure:
a. Silently ignore the MsgCounterSyncRsp message.
3. On verification success:
a. Set the peer’s group key data message counter to Synchronized Counter.
b. Clear the Section 4.6.5.1, “Message Reception State” bitmap for the peer.
c. Mark the peer 's group key data message counter as synchronized.
d. Resume processing of any queued message that triggered synchronization according to Section 4.6.7, “Counter Processing of Incoming Messages”.
i. If more than one message is queued from the synchronized peer, using the same operational group key, the messages SHALL be processed in the order received.
e. Close the synchronization exchange created for the original MsgCounterSyncReq message.
