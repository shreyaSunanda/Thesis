# Review: `core_4.19.4.7` — Receive Windows

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 45.97
- module: `models/generated/ch45_v3/core_4.19.4.7/vertex-gemini/core_4_19_4_7.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 39, col 5 to line 42, col 122 of module core_4_19_4_7>
/\ negotiatedMaxWindow = 0
/\ role = "None"
/\ remoteWindowCounter = 0
/\ ownWindowCounter = 0
/\ hasPendingAck = FALSE
/\ pendingTransmissions = 0
/\ pendingInput = "ReceiveGATTPacket"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ negotiatedMaxWindow = 0
/\ role = "None"
/\ remoteWindowCounter = 0
/\ ownWindowCounter = 0
/\ hasPendingAck = FALSE
/\ pendingTransmissions = 0
/\ pendingInput = NoInput

State 2: <ReceiveInput line 39, col 5 to line 42, col 122 of module core_4_19_4_7>
/\ negotiatedMaxWindow = 0
/\ role = "None"
/\ remoteWindowCounter = 0
/\ ownWindowCounter = 0
/\ hasPendingAck = FALSE
/\ pendingTransmissions = 0
/\ pendingInput = "ReceiveGATTPacket"
```

</details>

## Spec text for this section

4.19.4.7. Receive Windows
The purpose of the receive window is to enable flow control at the GATT session layer between BTP
peers.
Flow control is required at the GATT transport layer for embedded platforms that use "minimal"
BLE chipsets. These platforms may have limited space on the host processor to receive packets from
their BLE chipsets. In the case of some dual-chip architectures, writes and indications are received
and confirmed by the BLE chip with no input from the host processor. When the BLE chip sends the
result of a received GATT PDU to the host processor, that payload and the corresponding BTP packet
will be permanently lost if the host does not have enough space to receive it. For this reason, knowledge of a remote host’s ability to reliably receive GATT PDUs is presented at the transport layer in
the form of the BTP receive window.
Both peers in a BTP session SHALL define a receive window, where the window’s size indicates the
number of GATT PDUs (that is, BTP segments) a peer can reliably receive and store without session-
layer acknowledgment. A maximum window size SHALL be established for both peers as part of
the BTP session handshake. To prevent sequence number wrap-around, the largest maximum window size any peer may support is 255.
Both peers SHALL maintain a counter to reflect the current size of the remote peer’s receive window. Each peer SHALL decrement this counter when it sends a packet via GATT write or indication
and increment this counter when a sent packet is acknowledged.
If a local peer’s counter for a remote peer’s receive window is zero, the window SHALL be considered closed, and the local peer SHALL NOT send packets until the window reopens (is incremented
above zero). When a closed window reopens, a local peer SHALL immediately resume any pending
BTP packet transmission.
A local peer SHALL also not send packets if the remote peer’s receive window has one slot open and
the local peer does not have a pending packet acknowledgement. This is to avoid the situation
where the receive windows of both peers are full and neither can send an acknowledgement to
reopen its window for the other. Because the server’s handshake response bears an implicit BTP
sequence number of zero, a server SHALL initialize its counter for the client’s receive window size
at (negotiated maximum window size - 1). A client SHALL initialize its counter for the server’s
receive window at the negotiated maximum window size.
Both peers SHALL also keep a counter of their own receive window size based on the sequence
number difference between the last packet they received and the last packet they acknowledged.
This counter is used to proactively send early packet acknowledgements when a peer’s own receive
window is about to close. See Section 4.19.4.8, “Packet Acknowledgements” for details.
An example scenario involving BTP receive windows is depicted in Figure 24, “Example receive
window scenario”, complete with packet acknowledgements as specified in Section 4.19.4.8, “Packet
Acknowledgements”. In this scenario, the client transmits a three-segment buffer to the server once
it receives the server’s handshake request. The handshake request occupies one slot in the client’s
initial receive window. The server’s initial receive window is empty. Both client and server have a
maximum window size of 4.
Figure 24. Example receive window scenario
