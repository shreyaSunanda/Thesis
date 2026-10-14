---- MODULE core_4_20_3_5 ----
EXTENDS Naturals, Sequences

\* Sentinel for no pending input
CONSTANTS NoInput

\* SDU size limit. (Spec states: 64KB max, limited by 16-bit Message Length)
CONSTANTS MaxSduSize

\* The session's maximum PAFTP packet size
CONSTANTS MaxPaftpPacketSize

\* The size of the PAFTP packet header
CONSTANTS HeaderSize

\* Abstract bound for the transmission queue to ensure finite state space
CONSTANTS MaxTxQueueSize

\* Abstract bound for sequence numbers to avoid infinite state space
CONSTANTS MaxSeqNum

VARIABLES pendingInput
\* Event data variables modelled separately from pendingInput
VARIABLES inputSduSize
VARIABLES inputSegment

\* Tx variables
VARIABLES txQueue        \* FIFO queue of pending PAFTP SDUs (sizes)
VARIABLES txState        \* "Idle" or "Transmitting"
VARIABLES txCurrentSdu   \* Total size of the SDU currently being transmitted
VARIABLES txOffset       \* Bytes of current SDU generated into segments so far
VARIABLES txUnacked      \* Number of segments sent but not yet acknowledged by peer

\* Rx variables
VARIABLES rxState        \* "Idle", "Receiving", "Closed"
VARIABLES rxExpectedLen  \* Expected total SDU length from Beginning Segment's Message Length
VARIABLES rxAccumulated  \* Total payload bytes reassembled so far
VARIABLES rxNextSeq      \* Next expected sequence number

Inputs == {"AppSendSdu", "PeerAckSegment", "ReceiveSegment"}

Init ==
    /\ pendingInput = NoInput
    /\ inputSduSize = 0
    /\ inputSegment = [seq |-> 0, begin |-> FALSE, end |-> FALSE, msgLen |-> 0, payload |-> 0]
    /\ txQueue = <<>>
    /\ txState = "Idle"
    /\ txCurrentSdu = 0
    /\ txOffset = 0
    /\ txUnacked = 0
    /\ rxState = "Idle"
    /\ rxExpectedLen = 0
    /\ rxAccumulated = 0
    /\ rxNextSeq = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<inputSduSize, inputSegment, txQueue, txState, txCurrentSdu, txOffset, txUnacked, rxState, rxExpectedLen, rxAccumulated, rxNextSeq>>

\* SOURCE: core_4.20.3.5
\* "If the application attempts to send one PAFTP SDU while transmission of another PAFTP SDU is in progress,
\* the new PAFTP SDU SHALL be appended to a first-in, first-out queue."
AppSendSdu_Action ==
    /\ pendingInput = "AppSendSdu"
    /\ inputSduSize <= MaxSduSize
    /\ IF txState = "Idle"
       THEN
           /\ txState' = "Transmitting"
           /\ txCurrentSdu' = inputSduSize
           /\ txOffset' = 0
           /\ txUnacked' = 0
           /\ UNCHANGED txQueue
       ELSE
           /\ Len(txQueue) < MaxTxQueueSize
           /\ txQueue' = Append(txQueue, inputSduSize)
           /\ UNCHANGED <<txState, txCurrentSdu, txOffset, txUnacked>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputSduSize, inputSegment, rxState, rxExpectedLen, rxAccumulated, rxNextSeq>>

\* SOURCE: core_4.20.3.5
\* "Each PAFTP segment SHALL be prepended with a PAFTP packet header... The length of the data payload in each PAFTP
\* segment whose Ending Segment bit is not set SHALL be equal to the session’s maximum PAFTP packet size minus the size
\* of that PAFTP packet’s header. If a packet’s Ending Segment bit is set, the length of its PAFTP segment data payload
\* SHALL equal the size of the original PAFTP SDU minus the total size of all previously transmitted PAFTP segments"
\* Note: Internal non-event-driven action modelling the generation/transmission of the next segment of the active SDU.
TransmitNextSegment ==
    /\ pendingInput = NoInput
    /\ txState = "Transmitting"
    /\ txOffset < txCurrentSdu
    /\ LET maxPayload == MaxPaftpPacketSize - HeaderSize
           remaining == txCurrentSdu - txOffset
           isLast == remaining <= maxPayload
           payloadSize == IF isLast THEN remaining ELSE maxPayload
       IN
           /\ txOffset' = txOffset + payloadSize
           /\ txUnacked' = txUnacked + 1
    /\ UNCHANGED <<pendingInput, inputSduSize, inputSegment, txQueue, txState, txCurrentSdu, rxState, rxExpectedLen, rxAccumulated, rxNextSeq>>

\* SOURCE: core_4.20.3.5
\* "The next PAFTP SDU SHALL be dequeued from this queue and transmitted once transmission of the current PAFTP SDU completes,
\* that is, once all PAFTP segments of the current PAFTP SDU have been transmitted and received by the peer."
PeerAckSegment_Action ==
    /\ pendingInput = "PeerAckSegment"
    /\ txState = "Transmitting"
    /\ txUnacked > 0
    /\ txUnacked' = txUnacked - 1
    /\ IF txOffset = txCurrentSdu /\ txUnacked' = 0
       THEN
           IF txQueue /= <<>>
           THEN
               /\ txState' = "Transmitting"
               /\ txCurrentSdu' = Head(txQueue)
               /\ txOffset' = 0
               /\ txQueue' = Tail(txQueue)
           ELSE
               /\ txState' = "Idle"
               /\ txCurrentSdu' = 0
               /\ txOffset' = 0
               /\ UNCHANGED txQueue
       ELSE
           UNCHANGED <<txState, txCurrentSdu, txOffset, txQueue>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputSduSize, inputSegment, rxState, rxExpectedLen, rxAccumulated, rxNextSeq>>

\* Helper to abstract error conditions during reception into a clean definition
IsErrorCondition(seg, currentRxState) ==
    \/ seg.payload > (MaxPaftpPacketSize - HeaderSize)
    \/ (seg.end /\ ~seg.begin /\ currentRxState = "Idle")
    \/ (seg.begin /\ currentRxState = "Receiving")

\* SOURCE: core_4.20.3.5
\* "A peer SHALL reassemble PAFTP segments in the ascending order of the segment sequence numbers. Once a peer receives
\* a complete set of PAFTP segments, it SHALL verify that the reassembled PAFTP SDU’s total length matches that specified
\* by the Beginning Segment’s Message Length value... If the reassembled buffer’s length does not match that specified
\* by the sender, or if received PAFTP segment payload size would exceed the maximum PAFTP packet size, or receiver receives
\* an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when another PAFTP SDU’s
\* transmission is already in progress, the receiver PAFTP SHALL close the PAFTP session and report an error"
\* TODO: unspecified - what happens if a middle segment (begin=FALSE, end=FALSE) is received when rxState is "Idle"?
\* TODO: unspecified - what happens if a middle segment payload size is strictly less than (MaxPaftpPacketSize - HeaderSize)?
ReceiveSegment_Action ==
    /\ pendingInput = "ReceiveSegment"
    /\ rxState \in {"Idle", "Receiving"}
    /\ LET seg == inputSegment
           isError == IsErrorCondition(seg, rxState)
       IN
           IF isError
           THEN
               /\ rxState' = "Closed"
               /\ UNCHANGED <<rxExpectedLen, rxAccumulated, rxNextSeq>>
           ELSE
               LET newAccumulated == IF seg.begin THEN seg.payload ELSE rxAccumulated + seg.payload
                   expectedLen == IF seg.begin THEN seg.msgLen ELSE rxExpectedLen
               IN
                   IF seg.end
                   THEN
                       IF newAccumulated = expectedLen
                       THEN
                           \* Matching length, pass up to next-higher-layer
                           /\ rxState' = "Idle"
                           /\ rxAccumulated' = 0
                           /\ rxExpectedLen' = 0
                           /\ rxNextSeq' = 0
                       ELSE
                           \* Length mismatch
                           /\ rxState' = "Closed"
                           /\ rxAccumulated' = newAccumulated
                           /\ rxExpectedLen' = expectedLen
                           /\ UNCHANGED rxNextSeq
                   ELSE
                       \* Accumulate middle segment
                       /\ rxState' = "Receiving"
                       /\ rxAccumulated' = newAccumulated
                       /\ rxExpectedLen' = expectedLen
                       /\ rxNextSeq' = (seg.seq + 1) % MaxSeqNum
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputSduSize, inputSegment, txQueue, txState, txCurrentSdu, txOffset, txUnacked>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ AppSendSdu_Action
    \/ TransmitNextSegment
    \/ PeerAckSegment_Action
    \/ ReceiveSegment_Action

====