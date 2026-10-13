# Review: `core_4.19.4.8` — Packet Acknowledgements

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] legitimate terminal state (nothing is supposed to happen next)

Notes:



## Evidence

- steps to deadlock: 6
- ranker score: 112.1
- module: `models/generated/ch45/core_4.19.4.8/vertex-gemini/core_4_19_4_8.tla`

### Under no capability flags

Last action to fire: **`PeerExpireAckRecvTimer`**

Clause that action cites:

```
\* SOURCE: core_4.19.4.8 Packet Acknowledgements
\* "If a peer’s acknowledgement-received timer expires, or if a peer receives an invalid acknowledgement, the peer SHALL close the BTP session and report an error to the application."
```

Stuck in this state:

```
State 6: <PeerExpireAckRecvTimer line 146, col 5 to line 150, col 97 of module core_4_19_4_8>
/\ nextSeq = (Client :> 1 @@ Server :> 1)
/\ network = { [type |-> "Packet", sender |-> Client, seq |-> 0, ack |-> 0],
  [type |-> "HandshakeResponse", sender |-> Server, seq |-> 0, ack |-> Null] }
/\ pendingAck = (Client :> Null @@ Server :> Null)
/\ received = (Client :> {0} @@ Server :> {})
/\ ackRecvTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ status = (Client :> "Closed" @@ Server :> "Closed")
/\ unackedSent = (Client :> {0} @@ Server :> {0})
/\ sendAckTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ freeSlots = (Client :> 2 @@ Server :> 3)
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ nextSeq = (Client :> 0 @@ Server :> 0)
/\ network = {}
/\ pendingAck = (Client :> Null @@ Server :> Null)
/\ received = (Client :> {} @@ Server :> {})
/\ ackRecvTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ status = (Client :> "Handshake" @@ Server :> "Handshake")
/\ unackedSent = (Client :> {} @@ Server :> {})
/\ sendAckTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ freeSlots = (Client :> 3 @@ Server :> 3)

State 2: <ServerSendHandshakeResponse line 65, col 5 to line 71, col 66 of module core_4_19_4_8>
/\ nextSeq = (Client :> 0 @@ Server :> 1)
/\ network = {[type |-> "HandshakeResponse", sender |-> Server, seq |-> 0, ack |-> Null]}
/\ pendingAck = (Client :> Null @@ Server :> Null)
/\ received = (Client :> {} @@ Server :> {})
/\ ackRecvTimer = (Client :> "Stopped" @@ Server :> "Running")
/\ status = (Client :> "Handshake" @@ Server :> "Active")
/\ unackedSent = (Client :> {} @@ Server :> {0})
/\ sendAckTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ freeSlots = (Client :> 3 @@ Server :> 3)

State 3: <PeerExpireAckRecvTimer line 146, col 5 to line 150, col 97 of module core_4_19_4_8>
/\ nextSeq = (Client :> 0 @@ Server :> 1)
/\ network = {[type |-> "HandshakeResponse", sender |-> Server, seq |-> 0, ack |-> Null]}
/\ pendingAck = (Client :> Null @@ Server :> Null)
/\ received = (Client :> {} @@ Server :> {})
/\ ackRecvTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ status = (Client :> "Handshake" @@ Server :> "Closed")
/\ unackedSent = (Client :> {} @@ Server :> {0})
/\ sendAckTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ freeSlots = (Client :> 3 @@ Server :> 3)

State 4: <ClientReceiveHandshakeResponse line 77, col 5 to line 84, col 64 of module core_4_19_4_8>
/\ nextSeq = (Client :> 0 @@ Server :> 1)
/\ network = {[type |-> "HandshakeResponse", sender |-> Server, seq |-> 0, ack |-> Null]}
/\ pendingAck = (Client :> 0 @@ Server :> Null)
/\ received = (Client :> {0} @@ Server :> {})
/\ ackRecvTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ status = (Client :> "Active" @@ Server :> "Closed")
/\ unackedSent = (Client :> {} @@ Server :> {0})
/\ sendAckTimer = (Client :> "Running" @@ Server :> "Stopped")
/\ freeSlots = (Client :> 2 @@ Server :> 3)

State 5: <PeerSendData line 91, col 5 to line 93, col 27 of module core_4_19_4_8>
/\ nextSeq = (Client :> 1 @@ Server :> 1)
/\ network = { [type |-> "Packet", sender |-> Client, seq |-> 0, ack |-> 0],
  [type |-> "HandshakeResponse", sender |-> Server, seq |-> 0, ack |-> Null] }
/\ pendingAck = (Client :> Null @@ Server :> Null)
/\ received = (Client :> {0} @@ Server :> {})
/\ ackRecvTimer = (Client :> "Running" @@ Server :> "Stopped")
/\ status = (Client :> "Active" @@ Server :> "Closed")
/\ unackedSent = (Client :> {0} @@ Server :> {0})
/\ sendAckTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ freeSlots = (Client :> 2 @@ Server :> 3)

State 6: <PeerExpireAckRecvTimer line 146, col 5 to line 150, col 97 of module core_4_19_4_8>
/\ nextSeq = (Client :> 1 @@ Server :> 1)
/\ network = { [type |-> "Packet", sender |-> Client, seq |-> 0, ack |-> 0],
  [type |-> "HandshakeResponse", sender |-> Server, seq |-> 0, ack |-> Null] }
/\ pendingAck = (Client :> Null @@ Server :> Null)
/\ received = (Client :> {0} @@ Server :> {})
/\ ackRecvTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ status = (Client :> "Closed" @@ Server :> "Closed")
/\ unackedSent = (Client :> {0} @@ Server :> {0})
/\ sendAckTimer = (Client :> "Stopped" @@ Server :> "Stopped")
/\ freeSlots = (Client :> 2 @@ Server :> 3)
```

</details>

## Spec text for this section

4.19.4.8. Packet Acknowledgements
The purpose of sequence numbers and packet receipt acknowledgements is to support the BTP
receive window and provide a keep-alive signal when a session is idle to affirm the health and continued operation of a remote BTP stack.
Per BTP Frame Formats, BTP packet receipt acknowledgements SHALL be received as unsigned 8-
bit integer values in the header of a BTP packet. The value of this field SHALL indicate the sequence
number of the acknowledged packet.
Acknowledgement of a sequence number indicates acknowledgement of the previous sequence
number, if it too is unacknowledged. By induction, acknowledgement of a given packet implies
acknowledgement of all packets received on the same BTP session prior to the acknowledged
packet.
An acknowledgement is invalid if the acknowledged sequence number does not correspond to an
outstanding, unacknowledged BTP packet sequence number. In contrast to TCP, BTP acks are not
"free." A stand-alone ack—that is, a BTP packet that contains a packet receipt acknowledgement
value but no buffer segment payload—consumes a slot in a remote peer’s window just like any
other packet. Stand-alone acknowledgement packets SHALL be acknowledged by a remote peer.
The implications of this are examined in Section 4.19.4.9, “Idle Connection State”.
Each peer SHALL maintain an acknowledgement-received timer. When a peer sends any BTP
packet, it SHALL start this timer if it is not already running. The timer’s duration SHALL be globally
defined as BTP_ACK_TIMEOUT seconds, referred to as the acknowledgement timeout interval.
A peer SHALL restart its acknowledgement-received timer when a valid acknowledgement is
received for any but its most recently sent unacknowledged packet. A peer SHALL stop its acknowledgement-received timer if it receives an acknowledgement for its most recently sent unacknowl­
edged packet. If a peer’s acknowledgement-received timer expires, or if a peer receives an invalid
acknowledgement, the peer SHALL close the BTP session and report an error to the application.
Because the server’s handshake response bears an implicit BTP sequence number of zero, a server
SHALL start its acknowledgement-received timer when it sends a handshake response.
Each peer SHALL also maintain a send-acknowledgement timer. When it receives any BTP packet, a
peer SHALL record the packet’s sequence number as the corresponding BTP session’s pending
acknowledgement value and start the send-acknowledgement timer if it is not already running. The
timer’s duration timer SHALL be defined as any value less than one-half the acknowledgement
timeout interval. This ensures that on a healthy BLE connection, a peer will always receive
acknowledgements for sent packets before its acknowledgement-received timer expires.
A peer SHALL stop its send-acknowledgement timer when any pending acknowledgement is sent,
either as a stand-alone BTP packet or piggybacked onto an outgoing buffer segment. If this timer
expires and the peer has a pending acknowledgement, the peer SHALL immediately send that
acknowledgement. If the peer sends any packet before this timer expires, it SHALL piggyback any
pending acknowledgement on the transmitted packet and stop the send-acknowledgement timer.
Because the server’s handshake response bears an implicit BTP sequence number of zero, a client
SHALL set its pending acknowledgement value to zero and start its send-acknowledgement timer
when it receives the server’s a handshake response. Operation of the send-acknowledgement and
acknowledgement-received timers is illustrated in Figure 26, “BTP session lifecycle for Central acting as GATT Client” in Section 4.19.4.11, “Protocol State Diagrams”.
If a peer detects that its receive window has shrunk to two or fewer free slots, it SHALL immediately send any pending acknowledgement as a stand-alone BTP packet. This prevents the session
from stalling in the interval between when a peer’s receive window becomes empty and when its
send-acknowledgement timer would normally fire.
