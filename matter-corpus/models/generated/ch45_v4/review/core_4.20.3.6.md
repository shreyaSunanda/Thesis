# Review: `core_4.20.3.6` — Sequence Numbers

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 4
- ranker score: 26.8
- module: `models/generated/ch45_v4/core_4.20.3.6/vertex-gemini/core_4_20_3_6.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 26, col 5 to line 32, col 85 of module core_4_20_3_6>
/\ applicationError = FALSE
/\ expectedRxSeqNum = 3
/\ txSeqNum = 3
/\ sessionState = "HANDSHAKE"
/\ role = "None"
/\ inPacketSeqNum = 3
/\ pendingInput = "SendPacket"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ applicationError = FALSE
/\ expectedRxSeqNum = 3
/\ txSeqNum = 3
/\ sessionState = "HANDSHAKE"
/\ role = "None"
/\ inPacketSeqNum = 3
/\ pendingInput = NoInput

State 2: <ReceiveInput line 26, col 5 to line 32, col 85 of module core_4_20_3_6>
/\ applicationError = FALSE
/\ expectedRxSeqNum = 3
/\ txSeqNum = 3
/\ sessionState = "HANDSHAKE"
/\ role = "None"
/\ inPacketSeqNum = 3
/\ pendingInput = "SendPacket"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 4: <ReceiveInput line 26, col 5 to line 32, col 85 of module core_4_20_3_6>
/\ applicationError = FALSE
/\ expectedRxSeqNum = 1
/\ txSeqNum = 0
/\ sessionState = "ESTABLISHED"
/\ role = "Commissioner"
/\ inPacketSeqNum = 3
/\ pendingInput = "CompleteHandshakeAsCommissioner"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ applicationError = FALSE
/\ expectedRxSeqNum = 3
/\ txSeqNum = 3
/\ sessionState = "HANDSHAKE"
/\ role = "None"
/\ inPacketSeqNum = 3
/\ pendingInput = NoInput

State 2: <ReceiveInput line 26, col 5 to line 32, col 85 of module core_4_20_3_6>
/\ applicationError = FALSE
/\ expectedRxSeqNum = 3
/\ txSeqNum = 3
/\ sessionState = "HANDSHAKE"
/\ role = "None"
/\ inPacketSeqNum = 3
/\ pendingInput = "CompleteHandshakeAsCommissioner"

State 3: <CompleteHandshakeAsCommissioner line 36, col 5 to line 43, col 53 of module core_4_20_3_6>
/\ applicationError = FALSE
/\ expectedRxSeqNum = 1
/\ txSeqNum = 0
/\ sessionState = "ESTABLISHED"
/\ role = "Commissioner"
/\ inPacketSeqNum = 3
/\ pendingInput = NoInput

State 4: <ReceiveInput line 26, col 5 to line 32, col 85 of module core_4_20_3_6>
/\ applicationError = FALSE
/\ expectedRxSeqNum = 1
/\ txSeqNum = 0
/\ sessionState = "ESTABLISHED"
/\ role = "Commissioner"
/\ inPacketSeqNum = 3
/\ pendingInput = "CompleteHandshakeAsCommissioner"
```

</details>

## Spec text for this section

4.20.3.6. Sequence Numbers
All PAFTP packets SHALL be sent with sequence numbers, regardless of whether they contain SDU
segments (for example, a packet acknowledgement with no attached segment payload). The purpose of sequence numbers is to facilitate the PAFTP receive window. A PAFTP sequence number
SHALL be defined as an unsigned 8-bit integer value that monotonically increments by 1 with each
packet sent by a given peer. A sequence number incremented past 255 SHALL wrap to zero.
Sequence numbers SHALL be separately defined for either direction of a PAFTP session. The
sequence number of the first packet sent by the Commissioner after completion of the PAFTP session handshake SHALL be zero. The Commissionable Device PAFTP handshake response bears an
implied sequence number of zero because it occupies a slot in the Commissioner’s receive window.
The Commissioner acknowledges the Commissionable Device’s PAFTP handshake response with an
acknowledgement sequence of zero. For this reason, the sequence number of the first data packet
sent by the Commissionable Device after completion of the PAFTP session handshake SHALL be 1.
Peers SHALL check to ensure that all received PAFTP packets properly increment the sender’s previous sequence number by 1. If this check fails, the peer SHALL close the PAFTP session and report
an error to the application.
