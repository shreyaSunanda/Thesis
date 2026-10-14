# Review: `core_4.20.3.7` — Receive Windows

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 4
- ranker score: 47.51
- module: `models/generated/ch45_v4/core_4.20.3.7/vertex-gemini/core_4_20_3_7.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 44, col 5 to line 47, col 87 of module core_4_20_3_7>
/\ state = "Uninitialized"
/\ pendingAck = FALSE
/\ remoteWindow = 0
/\ role = "None"
/\ pendingTx = 0
/\ unackedRcvdCount = 0
/\ pendingInput = "EnqueuePayload"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "Uninitialized"
/\ pendingAck = FALSE
/\ remoteWindow = 0
/\ role = "None"
/\ pendingTx = 0
/\ unackedRcvdCount = 0
/\ pendingInput = NoInput

State 2: <ReceiveInput line 44, col 5 to line 47, col 87 of module core_4_20_3_7>
/\ state = "Uninitialized"
/\ pendingAck = FALSE
/\ remoteWindow = 0
/\ role = "None"
/\ pendingTx = 0
/\ unackedRcvdCount = 0
/\ pendingInput = "EnqueuePayload"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 4: <ReceiveInput line 44, col 5 to line 47, col 87 of module core_4_20_3_7>
/\ state = "Open"
/\ pendingAck = FALSE
/\ remoteWindow = 3
/\ role = "Commissioner"
/\ pendingTx = 0
/\ unackedRcvdCount = 0
/\ pendingInput = "EstablishCommissionerSession"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "Uninitialized"
/\ pendingAck = FALSE
/\ remoteWindow = 0
/\ role = "None"
/\ pendingTx = 0
/\ unackedRcvdCount = 0
/\ pendingInput = NoInput

State 2: <ReceiveInput line 44, col 5 to line 47, col 87 of module core_4_20_3_7>
/\ state = "Uninitialized"
/\ pendingAck = FALSE
/\ remoteWindow = 0
/\ role = "None"
/\ pendingTx = 0
/\ unackedRcvdCount = 0
/\ pendingInput = "EstablishCommissionerSession"

State 3: <HandleEstablishCommissionerSession line 51, col 5 to line 57, col 60 of module core_4_20_3_7>
/\ state = "Open"
/\ pendingAck = FALSE
/\ remoteWindow = 3
/\ role = "Commissioner"
/\ pendingTx = 0
/\ unackedRcvdCount = 0
/\ pendingInput = NoInput

State 4: <ReceiveInput line 44, col 5 to line 47, col 87 of module core_4_20_3_7>
/\ state = "Open"
/\ pendingAck = FALSE
/\ remoteWindow = 3
/\ role = "Commissioner"
/\ pendingTx = 0
/\ unackedRcvdCount = 0
/\ pendingInput = "EstablishCommissionerSession"
```

</details>

## Spec text for this section

4.20.3.7. Receive Windows
The purpose of the receive window is to enable flow control at the WFA-USD layer between PAFTP
peers.
Flow control is required at the WFA-USD transport layer for embedded platforms that use "minimal" Wi-Fi chipsets supporting WFA-USD. These platforms may have limited space on the host
processor to receive packets from their Wi-Fi chipsets. When the Wi-Fi chip sends the result of a
received WFA-USD SDF Follow-up message PDU to the host processor, that payload and the corresponding PAFTP packet will be permanently lost if the host does not have enough space to receive
it. For this reason, knowledge of a remote host’s ability to reliably receive WFA-USD SDF Follow
message PDUs is presented at the transport layer in the form of the PAFTP receive window.
Both peers in a PAFTP session SHALL define a receive window, where the window’s size indicates
the number of WFA-USD SDF Follow-up message PDUs (that is, PAFTP segments) a peer can reliably
receive and store without session-layer acknowledgment. A maximum window size SHALL be
established for both peers as part of the PAFTP session handshake. To prevent sequence number
wrap-around, the largest maximum window size any peer may support is 255.
Both peers SHALL maintain a counter to reflect the current size of the remote peer’s receive window. Each peer SHALL decrement this counter when it sends a packet and increment this counter
when a sent packet is acknowledged.
If a local peer’s counter for a remote peer’s receive window is zero, the window SHALL be considered closed, and the local peer SHALL NOT send packets until the window reopens (is incremented
above zero). When a closed window reopens, a local peer SHALL immediately resume any pending
PAFTP packet transmission.
A local peer SHALL also not send packets if the remote peer’s receive window has one slot open and
the local peer does not have a pending packet acknowledgement. This is to avoid the situation
where the receive windows of both peers are full and neither can send an acknowledgement to
reopen its window for the other. Because the Commissionable Device’s handshake response bears
an implicit PAFTP sequence number of zero, a Commissionable Device SHALL initialize its counter
for the Commissioner’s receive window size at (negotiated maximum window size - 1). A Commissioner SHALL initialize its counter for the server’s receive window at the negotiated maximum
window size.
Both peers SHALL also keep a counter of their own receive window size based on the sequence
number difference between the last packet they received and the last packet they acknowledged.
This counter is used to proactively send early packet acknowledgements when a peer’s own receive
window is about to close. See Section 4.20.3.8, “Packet Acknowledgements” for details.
An example scenario involving PAFTP receive windows is depicted in Figure 31, “Example receive
window scenario”, complete with packet acknowledgements as specified in Section 4.20.3.8, “Packet
Acknowledgements”. In this scenario, the Commissioner transmits a three-segment buffer to the
Commissionable Device once it receives the server’s handshake response. The Commissionable
Device’s initial receive window is empty. Both Commissioner and Commissionable Device have a
maximum window size of 4.
Figure 31. Example receive window scenario
