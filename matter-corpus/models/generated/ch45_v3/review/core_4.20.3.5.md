# Review: `core_4.20.3.5` — Message Segmentation and Reassembly

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 23.64
- module: `models/generated/ch45_v3/core_4.20.3.5/vertex-gemini/core_4_20_3_5.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 57, col 5 to line 60, col 150 of module core_4_20_3_5>
/\ txOffset = 0
/\ txCurrentSdu = 0
/\ rxExpectedLen = 0
/\ inputSegment = [seq |-> 0, begin |-> FALSE, end |-> FALSE, msgLen |-> 0, payload |-> 0]
/\ rxState = "Idle"
/\ txUnacked = 0
/\ rxAccumulated = 0
/\ txQueue = <<>>
/\ pendingInput = "PeerAckSegment"
/\ rxNextSeq = 0
/\ inputSduSize = 0
/\ txState = "Idle"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ txOffset = 0
/\ txCurrentSdu = 0
/\ rxExpectedLen = 0
/\ inputSegment = [seq |-> 0, begin |-> FALSE, end |-> FALSE, msgLen |-> 0, payload |-> 0]
/\ rxState = "Idle"
/\ txUnacked = 0
/\ rxAccumulated = 0
/\ txQueue = <<>>
/\ pendingInput = NoInput
/\ rxNextSeq = 0
/\ inputSduSize = 0
/\ txState = "Idle"

State 2: <ReceiveInput line 57, col 5 to line 60, col 150 of module core_4_20_3_5>
/\ txOffset = 0
/\ txCurrentSdu = 0
/\ rxExpectedLen = 0
/\ inputSegment = [seq |-> 0, begin |-> FALSE, end |-> FALSE, msgLen |-> 0, payload |-> 0]
/\ rxState = "Idle"
/\ txUnacked = 0
/\ rxAccumulated = 0
/\ txQueue = <<>>
/\ pendingInput = "PeerAckSegment"
/\ rxNextSeq = 0
/\ inputSduSize = 0
/\ txState = "Idle"
```

</details>

## Spec text for this section

4.20.3.5. Message Segmentation and Reassembly
When the session layer (that is, MATTERoPAF) sends a Matter Message as a PAFTP SDU over a
PAFTP session, that PAFTP SDU SHALL be split into ordered, non-overlapping PAFTP segments so
the set of all PAFTP segments may be reassembled into the original PAFTP SDU (see Figure 29,
“MATTERoPAF: Matter Message / PAFTP layering”). Each PAFTP segment SHALL be prepended with
a PAFTP packet header and sent in the Service Specific Info field inside the Service Descriptor
Extension Attribute inside of a single WFA-USD SDF Follow-up message. If a PAFTP SDU is split into
more than one PAFTP segment, the PAFTP segments SHALL be sent in order of their position in the
original PAFTP SDU, starting with the PAFTP segment at the buffer’s head.
At any point in time, only one PAFTP SDU may be transmitted in each direction over a PAFTP session. The transmission of PAFTP segments of any two PAFTP SDUs SHALL NOT overlap. If the appli­
cation attempts to send one PAFTP SDU while transmission of another PAFTP SDU is in progress, the
new PAFTP SDU SHALL be appended to a first-in, first-out queue. The next PAFTP SDU SHALL be
dequeued from this queue and transmitted once transmission of the current PAFTP SDU completes,
that is, once all PAFTP segments of the current PAFTP SDU have been transmitted and received by
the peer.
The first PAFTP segment of a PAFTP SDU sent over a PAFTP session SHALL have its Beginning Segment header flag set to indicate the beginning of a new PAFTP SDU (see Table 37, “PAFTP Packet
PDU format”). The presence of this flag SHALL indicate the further presence of a 16-bit unsigned
integer field, the Message Length, that provides the receiver with the total length of the PAFTP SDU.
The last PAFTP segment for a given PAFTP SDU SHALL have its Ending Segment flag set to indicate
the end of the transmitted PAFTP SDU. A PAFTP packet that bears an unsegmented PAFTP
SDU—that is, a PAFTP SDU small enough to fit into a single PAFTP segment—SHALL have both its
Beginning Segment and Ending Segment flags set.
The size of a single PAFTP SDU sent via PAFTP is limited to 64KB, that is, the maximum size of the
Message Length field in the PAFTP packet header. The number of segments used to send a buffer is
unlimited and delimited by the Beginning Segment and Ending Segment bits in the PAFTP packet
header. The upper layer imposes more stringent requirements over the maximum SDU size, such as
Section 4.4.4, “Message Size Requirements”.
The length of the data payload in each PAFTP segment whose Ending Segment bit is not set SHALL
be equal to the session’s maximum PAFTP packet size minus the size of that PAFTP packet’s header.
If a packet’s Ending Segment bit is set, the length of its PAFTP segment data payload SHALL equal
the size of the original PAFTP SDU minus the total size of all previously transmitted PAFTP segments
of that PAFTP SDU. In this way, the length of a SDU’s last PAFTP segment is implied by its size.
A peer SHALL reassemble PAFTP segments in the ascending order of the segment sequence numbers. Once a peer receives a complete set of PAFTP segments, it SHALL verify that the reassembled
PAFTP SDU’s total length matches that specified by the Beginning Segment’s Message Length value.
If they match, the receiver SHALL pass the reassembled PAFTP SDU up to the next-higher-layer. If
the reassembled buffer’s length does not match that specified by the sender, or if received PAFTP
segment payload size would exceed the maximum PAFTP packet size, or receiver receives an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when
another PAFTP SDU’s transmission is already in progress, the receiver PAFTP SHALL close the
PAFTP session and report an error to the application.
