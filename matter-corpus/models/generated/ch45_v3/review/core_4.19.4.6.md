# Review: `core_4.19.4.6` — Sequence Numbers

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 26.95
- module: `models/generated/ch45_v3/core_4.19.4.6/vertex-gemini/core_4_19_4_6.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 34, col 5 to line 40, col 63 of module core_4_19_4_6>
/\ state = [Client |-> "Handshake", Server |-> "Handshake"]
/\ inputPeer = "Client"
/\ txSeq = [Client |-> 0, Server |-> 0]
/\ rxExpectedSeq = [Client |-> 0, Server |-> 0]
/\ errorReported = [Client |-> FALSE, Server |-> FALSE]
/\ inputSeq = 0
/\ pendingInput = "SendPacket"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = [Client |-> "Handshake", Server |-> "Handshake"]
/\ inputPeer = "Client"
/\ txSeq = [Client |-> 0, Server |-> 0]
/\ rxExpectedSeq = [Client |-> 0, Server |-> 0]
/\ errorReported = [Client |-> FALSE, Server |-> FALSE]
/\ inputSeq = 0
/\ pendingInput = NoInput

State 2: <ReceiveInput line 34, col 5 to line 40, col 63 of module core_4_19_4_6>
/\ state = [Client |-> "Handshake", Server |-> "Handshake"]
/\ inputPeer = "Client"
/\ txSeq = [Client |-> 0, Server |-> 0]
/\ rxExpectedSeq = [Client |-> 0, Server |-> 0]
/\ errorReported = [Client |-> FALSE, Server |-> FALSE]
/\ inputSeq = 0
/\ pendingInput = "SendPacket"
```

</details>

## Spec text for this section

4.19.4.6. Sequence Numbers
All BTP packets SHALL be sent with sequence numbers, regardless of whether they contain SDU
segments (for example, a packet acknowledgement with no attached segment payload). The purpose of sequence numbers is to facilitate the BTP receive window. A BTP sequence number SHALL
be defined as an unsigned 8-bit integer value that monotonically increments by 1 with each packet
sent by a given peer. A sequence number incremented past 255 SHALL wrap to zero.
Sequence numbers SHALL be separately defined for either direction of a BTP session. The sequence
number of the first packet sent by the client after completion of the BTP session handshake SHALL
be zero. The server’s BTP handshake response bears an implied sequence number of zero because
it occupies a slot in the client’s receive window. The client acknowledges the server’s BTP handshake response with an acknowledgement sequence of zero. For this reason, the sequence number
of the first data packet sent by the server after completion of the BTP session handshake SHALL be
1.
Peers SHALL check to ensure that all received BTP packets properly increment the sender’s previous sequence number by 1. If this check fails, the peer SHALL close the BTP session and report an
error to the application.
