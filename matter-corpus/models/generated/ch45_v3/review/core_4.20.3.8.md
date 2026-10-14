# Review: `core_4.20.3.8` — Packet Acknowledgements

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 127.15
- module: `models/generated/ch45_v3/core_4.20.3.8/vertex-gemini/core_4_20_3_8.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 54, col 5 to line 65, col 54 of module core_4_20_3_8>
/\ mostRecentSentSeqNum = 3
/\ unackedSentMsgs = {}
/\ receivedUnackedSeqs = {}
/\ sessionState = "Open"
/\ ackReceivedTimer = "Stopped"
/\ pendingAckValue = 3
/\ sendAckTimer = "Stopped"
/\ inPacketSeqNum = 3
/\ nextOutSeqNum = 1
/\ largestReceivedUnackedSeqNum = 3
/\ pendingInput = "SendStandaloneAck"
/\ inAckSeqNum = 3
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ mostRecentSentSeqNum = 3
/\ unackedSentMsgs = {}
/\ receivedUnackedSeqs = {}
/\ sessionState = "Open"
/\ ackReceivedTimer = "Stopped"
/\ pendingAckValue = 3
/\ sendAckTimer = "Stopped"
/\ inPacketSeqNum = 3
/\ nextOutSeqNum = 1
/\ largestReceivedUnackedSeqNum = 3
/\ pendingInput = NoInput
/\ inAckSeqNum = 3

State 2: <ReceiveInput line 54, col 5 to line 65, col 54 of module core_4_20_3_8>
/\ mostRecentSentSeqNum = 3
/\ unackedSentMsgs = {}
/\ receivedUnackedSeqs = {}
/\ sessionState = "Open"
/\ ackReceivedTimer = "Stopped"
/\ pendingAckValue = 3
/\ sendAckTimer = "Stopped"
/\ inPacketSeqNum = 3
/\ nextOutSeqNum = 1
/\ largestReceivedUnackedSeqNum = 3
/\ pendingInput = "SendStandaloneAck"
/\ inAckSeqNum = 3
```

</details>

## Spec text for this section

4.20.3.8. Packet Acknowledgements
The purpose of sequence numbers and packet receipt acknowledgements is to support the PAFTP
receive window and its reordering, and provide a keep-alive signal when a session is idle to affirm
the health and continued operation of a remote PAFTP stack.
Per PAFTP Frame Formats, PAFTP packet receipt acknowledgements SHALL be received as
unsigned 8-bit integer values in the header of a PAFTP packet. The value of this field SHALL indicate the sequence number of the acknowledged packet.
Acknowledgement of a sequence number indicates acknowledgement of the previous sequence
number, if it too is unacknowledged. By induction, acknowledgement of a given packet implies
acknowledgement of all packets received on the same PAFTP session prior to the acknowledged
packet.
An acknowledgement is invalid if the acknowledged sequence number does not correspond to an
outstanding, unacknowledged PAFTP packet sequence number. In contrast to TCP, PAFTP acks are
not "free." A stand-alone ack—that is, a PAFTP packet that contains a packet receipt acknowledgement value but no buffer segment payload—consumes a slot in a remote peer’s window just like
any other packet. Stand-alone acknowledgement packets SHALL be acknowledged by a remote
peer. The implications of this are examined in Section 4.20.3.9, “Idle Connection State”.
Each peer SHALL maintain an acknowledgement-received timer. When a peer sends any PAFTP
packet, it SHALL start this timer if it is not already running. The timer’s duration SHALL be globally
defined as PAFTP_ACK_TIMEOUT seconds, referred to as the acknowledgement timeout interval.
A peer SHALL restart its acknowledgement-received timer when a valid acknowledgement is
received for any but its most recently sent unacknowledged packet. A peer SHALL stop its acknowledgement-received timer if it receives an acknowledgement for its most recently sent unacknowl­
edged packet. If a peer’s acknowledgement-received timer expires, or if a peer receives an invalid
acknowledgement, the peer SHALL close the PAFTP session and report an error to the application.
Because the server’s handshake response bears an implicit PAFTP sequence number of zero, a
server SHALL start its acknowledgement-received timer when it sends a handshake response.
Each peer SHALL also maintain a send-acknowledgement timer. When it receives any PAFTP
packet, a peer SHALL record the packet’s sequence number as the corresponding PAFTP session’s
pending acknowledgement value and start the send-acknowledgement timer if it is not already running. The timer’s duration timer SHALL be defined as any value less than one-half the acknowl­
edgement timeout interval. This ensures that on a healthy WFA-USD connection, a peer will always
receive acknowledgements for sent packets before its acknowledgement-received timer expires.
A peer SHALL restart its send-acknowledgement timer when a pending acknowledgement is sent,
either as a stand-alone PAFTP packet or piggybacked onto an outgoing buffer segment, for any but
its received unacknowledged packet with the largest packet sequence number. A peer SHALL stop
its send-acknowledgement timer when a pending acknowledgement is sent, either as a stand-alone
PAFTP packet or piggybacked onto an outgoing buffer segment, for its received unacknowledged
packet with the largest packet sequence number. If this timer expires and the peer has a pending
acknowledgement, the peer SHALL immediately send that acknowledgement, and acknowledgement number SHALL be the PAFTP packet sequence number of which all previous contiguous
PAFTP packet sequence numbers are already received. If the peer sends any packet before this
timer expires, it SHALL piggyback any pending acknowledgement on the transmitted packet, and
acknowledgement number SHALL be the PAFTP packet sequence number of which all previous
contiguous PAFTP packet sequence numbers are already received. If this timer is not expired, the
peer MAY send a pending acknowledgement as a stand-alone PAFTP packet, and acknowledgement
number SHALL be the PAFTP packet sequence number of which all previous contiguous PAFTP
packet sequence numbers are already received.
Because the server’s handshake response bears an implicit PAFTP sequence number of zero, a
client SHALL set its pending acknowledgement value to zero and start its send-acknowledgement
timer when it receives the server’s a handshake response. Operation of the send-acknowledgement
and acknowledgement-received timers is illustrated in Figure 33, “PAFTP session lifecycle for Commissioner” in Section 4.20.3.11, “Protocol State Diagrams”.
If a peer detects that its receive window has shrunk to two or fewer free slots, it SHALL immediately send any pending acknowledgement as a stand-alone PAFTP packet, and acknowledgement
number SHALL be the PAFTP packet sequence number of which all previous contiguous PAFTP
packet sequence numbers are already received. This prevents the session from stalling in the interval between when a peer’s receive window becomes empty and when its send-acknowledgement
timer would normally fire.
