# Review: `core_4.19.4.5` — Message Segmentation and Reassembly

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 21.76
- module: `models/generated/ch45_v4/core_4.19.4.5/vertex-gemini/core_4_19_4_5.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 67, col 5 to line 76, col 144 of module core_4_19_4_5>
/\ state = "Running"
/\ rxAccumulatedLength = 0
/\ txCurrentSduLen = NullSdu
/\ inAppSduLength = 4
/\ inSegBeginning = FALSE
/\ txInFlight = FALSE
/\ inSegMsgLength = 0
/\ rxExpectedLength = 0
/\ inSegEnding = FALSE
/\ rxInProgress = FALSE
/\ txSentLen = 0
/\ rxSessionState = "OPEN"
/\ inSegPayloadLength = 0
/\ txQueue = <<>>
/\ pendingInput = "AppSendSDU"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "Running"
/\ rxAccumulatedLength = 0
/\ txCurrentSduLen = NullSdu
/\ inAppSduLength = 0
/\ inSegBeginning = FALSE
/\ txInFlight = FALSE
/\ inSegMsgLength = 0
/\ rxExpectedLength = 0
/\ inSegEnding = FALSE
/\ rxInProgress = FALSE
/\ txSentLen = 0
/\ rxSessionState = "OPEN"
/\ inSegPayloadLength = 0
/\ txQueue = <<>>
/\ pendingInput = NoInput

State 2: <ReceiveInput line 67, col 5 to line 76, col 144 of module core_4_19_4_5>
/\ state = "Running"
/\ rxAccumulatedLength = 0
/\ txCurrentSduLen = NullSdu
/\ inAppSduLength = 4
/\ inSegBeginning = FALSE
/\ txInFlight = FALSE
/\ inSegMsgLength = 0
/\ rxExpectedLength = 0
/\ inSegEnding = FALSE
/\ rxInProgress = FALSE
/\ txSentLen = 0
/\ rxSessionState = "OPEN"
/\ inSegPayloadLength = 0
/\ txQueue = <<>>
/\ pendingInput = "AppSendSDU"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 67, col 5 to line 76, col 144 of module core_4_19_4_5>
/\ state = "Running"
/\ rxAccumulatedLength = 0
/\ txCurrentSduLen = NullSdu
/\ inAppSduLength = 4
/\ inSegBeginning = FALSE
/\ txInFlight = FALSE
/\ inSegMsgLength = 0
/\ rxExpectedLength = 0
/\ inSegEnding = FALSE
/\ rxInProgress = FALSE
/\ txSentLen = 0
/\ rxSessionState = "OPEN"
/\ inSegPayloadLength = 0
/\ txQueue = <<>>
/\ pendingInput = "AppSendSDU"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "Running"
/\ rxAccumulatedLength = 0
/\ txCurrentSduLen = NullSdu
/\ inAppSduLength = 0
/\ inSegBeginning = FALSE
/\ txInFlight = FALSE
/\ inSegMsgLength = 0
/\ rxExpectedLength = 0
/\ inSegEnding = FALSE
/\ rxInProgress = FALSE
/\ txSentLen = 0
/\ rxSessionState = "OPEN"
/\ inSegPayloadLength = 0
/\ txQueue = <<>>
/\ pendingInput = NoInput

State 2: <ReceiveInput line 67, col 5 to line 76, col 144 of module core_4_19_4_5>
/\ state = "Running"
/\ rxAccumulatedLength = 0
/\ txCurrentSduLen = NullSdu
/\ inAppSduLength = 4
/\ inSegBeginning = FALSE
/\ txInFlight = FALSE
/\ inSegMsgLength = 0
/\ rxExpectedLength = 0
/\ inSegEnding = FALSE
/\ rxInProgress = FALSE
/\ txSentLen = 0
/\ rxSessionState = "OPEN"
/\ inSegPayloadLength = 0
/\ txQueue = <<>>
/\ pendingInput = "AppSendSDU"
```

</details>

## Spec text for this section

4.19.4.5. Message Segmentation and Reassembly
When the session layer (that is, MATTERoBLE) sends a Matter Message as a BTP SDU over a BTP session, that BTP SDU SHALL be split into ordered, non-overlapping BTP segments so the set of all BTP
segments may be reassembled into the original BTP SDU (see Figure 22, “MATTERoBLE: Matter MesMatter Specification R1.6
sage / BTP layering”). Each BTP segment SHALL be prepended with a BTP packet header and sent as
the payload of a single GATT PDU. If a BTP SDU is split into more than one BTP segment, the BTP
segments SHALL be sent in order of their position in the original BTP SDU, starting with the BTP
segment at the buffer’s head.
At any point in time, only one BTP SDU may be transmitted in each direction over a BTP session.
The transmission of BTP segments of any two BTP SDUs SHALL NOT overlap. If the application
attempts to send one BTP SDU while transmission of another BTP SDU is in progress, the new BTP
SDU SHALL be appended to a first-in, first-out queue. The next BTP SDU SHALL be dequeued from
this queue and transmitted once transmission of the current BTP SDU completes, that is, once all
BTP segments of the current BDP SDU have been transmitted and received by the peer via GATT.
The first BTP segment of a BTP SDU sent over a BTP session SHALL have its Beginning Segment
header flag set to indicate the beginning of a new BTP SDU (see Table 28, “BTP Packet PDU format”).
The presence of this flag SHALL indicate the further presence of a 16-bit unsigned integer field, the
Message Length, that provides the receiver with the total length of the BTP SDU. The last BTP segment for a given BTP SDU SHALL have its Ending Segment flag set to indicate the end of the trans­
mitted BTP SDU. A BTP packet that bears an unsegmented BTP SDU—that is, a BTP SDU small
enough to fit into a single BTP segment—SHALL have both its Beginning Segment and Ending Segment flags set.
The size of a single BTP SDU sent via BTP is limited to 64KB, that is, the maximum size of the Message Length field in the BTP packet header. The number of segments used to send a buffer is unlim­
ited and delimited by the Beginning Segment and Ending Segment bits in the BTP packet header.
The upper layer imposes more stringent requirements over the maximum SDU size, such as Section
4.4.4, “Message Size Requirements”.
The length of the data payload in each BTP segment whose Ending Segment bit is not set SHALL be
equal to the session’s maximum BTP packet size minus the size of that packet’s header. If a packet’s
Ending Segment bit is set, the length of its BTP segment data payload SHALL equal the size of the
original BTP SDU minus the total size of all previously transmitted BTP segments of that BTP SDU. In
this way, the length of a SDU’s last BTP segment is implied by its size.
Once a peer receives a complete set of BTP segments, it SHALL reassemble them in the order
received, and verify that the reassembled BTP SDU’s total length matches that specified by the
Beginning Segment’s Message Length value. If they match, the receiver SHALL pass the reassembled BTP SDU up to the next-higher-layer. If the reassembled buffer’s length does not match that
specified by the sender, or if received BTP segment payload size would exceed the maximum BTP
packet size, or receiver receives an Ending Segment without the presence of a previous Beginning
Segment, or a Beginning Segment when another BTP SDU’s transmission is already in progress, the
receiver BTP SHALL close the BTP session and report an error to the application.
