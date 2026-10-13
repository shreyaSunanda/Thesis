# Review: `core_4.12.5.1` — Reliable Message Processing of Outgoing Messages

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] legitimate terminal state (nothing is supposed to happen next)

Notes:



## Evidence

- steps to deadlock: 5
- ranker score: 52.11
- module: `models/generated/ch45/core_4.12.5.1/vertex-gemini/core_4_12_5_1.tla`

### Under no capability flags

Last action to fire: **`ErrorAssessment`**

Clause that action cites:

```
\* SOURCE: core_4.12.5.1 Message retransmission processing (Step 3)
```

Stuck in this state:

```
State 5: <ErrorAssessment line 88, col 5 to line 109, col 42 of module core_4_12_5_1>
/\ ackTable = {}
/\ transportResult = "None"
/\ outboundMsg = [ destNodeId |-> NullValue,
  exchangeId |-> NullValue,
  sessionId |-> NullValue,
  sessionCreds |-> NullValue,
  unsecured |-> FALSE,
  isStandaloneAck |-> FALSE,
  reliableUDP |-> FALSE,
  aFlag |-> FALSE,
  rFlag |-> FALSE,
  ackMsgCounter |-> NullValue ]
/\ msgState = "Done"
/\ appNotified = FALSE
/\ retransTable = {}
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ ackTable = {}
/\ transportResult = "None"
/\ outboundMsg = [ destNodeId |-> NullValue,
  exchangeId |-> NullValue,
  sessionId |-> NullValue,
  sessionCreds |-> NullValue,
  unsecured |-> FALSE,
  isStandaloneAck |-> FALSE,
  reliableUDP |-> FALSE,
  aFlag |-> FALSE,
  rFlag |-> FALSE,
  ackMsgCounter |-> NullValue ]
/\ msgState = "PiggybackProcessing"
/\ appNotified = FALSE
/\ retransTable = {}

State 2: <PiggybackAckProcessing line 45, col 5 to line 59, col 63 of module core_4_12_5_1>
/\ ackTable = {}
/\ transportResult = "None"
/\ outboundMsg = [ destNodeId |-> NullValue,
  exchangeId |-> NullValue,
  sessionId |-> NullValue,
  sessionCreds |-> NullValue,
  unsecured |-> FALSE,
  isStandaloneAck |-> FALSE,
  reliableUDP |-> FALSE,
  aFlag |-> FALSE,
  rFlag |-> FALSE,
  ackMsgCounter |-> NullValue ]
/\ msgState = "RetransmissionProcessing"
/\ appNotified = FALSE
/\ retransTable = {}

State 3: <MessageRetransmissionProcessing line 63, col 5 to line 76, col 59 of module core_4_12_5_1>
/\ ackTable = {}
/\ transportResult = "None"
/\ outboundMsg = [ destNodeId |-> NullValue,
  exchangeId |-> NullValue,
  sessionId |-> NullValue,
  sessionCreds |-> NullValue,
  unsecured |-> FALSE,
  isStandaloneAck |-> FALSE,
  reliableUDP |-> FALSE,
  aFlag |-> FALSE,
  rFlag |-> FALSE,
  ackMsgCounter |-> NullValue ]
/\ msgState = "Transmitting"
/\ appNotified = FALSE
/\ retransTable = {}

State 4: <MessageTransmission line 80, col 5 to line 84, col 69 of module core_4_12_5_1>
/\ ackTable = {}
/\ transportResult = "Success"
/\ outboundMsg = [ destNodeId |-> NullValue,
  exchangeId |-> NullValue,
  sessionId |-> NullValue,
  sessionCreds |-> NullValue,
  unsecured |-> FALSE,
  isStandaloneAck |-> FALSE,
  reliableUDP |-> FALSE,
  aFlag |-> FALSE,
  rFlag |-> FALSE,
  ackMsgCounter |-> NullValue ]
/\ msgState = "AssessingError"
/\ appNotified = FALSE
/\ retransTable = {}

State 5: <ErrorAssessment line 88, col 5 to line 109, col 42 of module core_4_12_5_1>
/\ ackTable = {}
/\ transportResult = "None"
/\ outboundMsg = [ destNodeId |-> NullValue,
  exchangeId |-> NullValue,
  sessionId |-> NullValue,
  sessionCreds |-> NullValue,
  unsecured |-> FALSE,
  isStandaloneAck |-> FALSE,
  reliableUDP |-> FALSE,
  aFlag |-> FALSE,
  rFlag |-> FALSE,
  ackMsgCounter |-> NullValue ]
/\ msgState = "Done"
/\ appNotified = FALSE
/\ retransTable = {}
```

</details>

## Spec text for this section

4.12.5.1. Reliable Message Processing of Outgoing Messages
To prepare a given Protocol Message for transmission, the message SHALL be processed as follows:
1. Proceed to Section 4.12.5.1.1, “Piggyback acknowledgment processing”.
Piggyback acknowledgment processing
1. Determine if there is a matching pending acknowledgement in the acknowledgement table for
the given message by checking all of the following conditions:
a. If the Destination Node Id and Exchange Id of the given message and pending acknowledgement are the same
b. AND either
i. the Session Id and underlying Session Credentials of the given message and pending
acknowledgement are the same
ii. OR both the given message and pending acknowledgement are of Unsecured Session
Type.
2. If there is a matching pending acknowledgement, the A Flag SHALL be set on the outbound message so it will serve as a piggybacked acknowledgement.
a. For such a piggybacked acknowledgement, the Acknowledgment Message Counter field
SHALL be set to the message counter of the received message for which an acknowledgeMatter Specification R1.6
ment was pending.
b. If the message being prepared is not a standalone acknowledgement, remove the matching
entry from the acknowledgement table.
c. If the message being prepared is a standalone acknowledgement, set the StandaloneAckSent
field of the matching entry in the acknowledgement table to true.
Message retransmission processing
1. If the outbound message is marked to be delivered reliably over a UDP transport, the R Flag
SHALL be set on the given message to request an acknowledgement from the peer upon receipt.
a. Any message flagged for reliable delivery (R Flag set) SHALL be stored in the retransmission
table to track the message until it has been successfully acknowledged by the peer.
2. Perform Section 4.7.1, “Message Transmission” processing step on the message to send the message to the peer:
a. The same Session ID, Destination Node ID, Security Flags, and transport as were used for the
initial message transmission SHALL be used.
3. If the transport interface returns an error on the send attempt, the error is assessed to determine whether the message can be retried.
a. If the error is fatal, the application is notified and the message removed from the retransmission table.
b. If there is no error, or a non-fatal error such as no memory, the message is resent
i. Update the retransmission table to reflect the send count.
ii. Start a retransmission timer to track the maximum time to wait before attempting
another retransmission.
iii. For each retry, the retransmission table is updated to track the number of retries until
the maximum number is attempted, at which point the message is evicted from the
retransmission table.
Send flow state diagram
The MRP send flow described above is depicted in the control flow diagram Figure 12, “MRP send
flow”.
Figure 12. MRP send flow
