---- MODULE core_4_19_4_5 ----
EXTENDS Naturals, Sequences

\* Declare EVERY fixed value the spec text mentions (timeouts, limits, thresholds,
\* fabric indices, etc.) here. Give each one a short comment saying what it is.
CONSTANTS 
    \* Maximum size of a BTP SDU (64KB as per spec)
    MaxSduSize,
    \* Maximum size of a BTP packet for the session
    MaxBtpPacketSize,
    \* Size of the BTP packet header
    BtpHeaderSize

VARIABLES 
    appQueue,
    senderState,
    senderCurrentSdu,
    senderRemainingBytes,
    inFlight,
    receiverState,
    receiverExpectedLen,
    receiverReceivedLen,
    receiverHasBeg

Init ==
    /\ appQueue = <<>>
    /\ senderState = "IDLE"
    /\ senderCurrentSdu = 0
    /\ senderRemainingBytes = 0
    /\ inFlight = <<>>
    /\ receiverState = "IDLE"
    /\ receiverExpectedLen = 0
    /\ receiverReceivedLen = 0
    /\ receiverHasBeg = FALSE

\* SOURCE: core_4.19.4.5 "If the application attempts to send one BTP SDU while transmission of another BTP SDU is in progress, the new BTP SDU SHALL be appended to a first-in, first-out queue."
AppSendsSdu ==
    \E sduLen \in 1..MaxSduSize:
        /\ appQueue' = Append(appQueue, sduLen)
        /\ UNCHANGED <<senderState, senderCurrentSdu, senderRemainingBytes, inFlight, receiverState, receiverExpectedLen, receiverReceivedLen, receiverHasBeg>>

\* SOURCE: core_4.19.4.5 "The next BTP SDU SHALL be dequeued from this queue and transmitted once transmission of the current BTP SDU completes"
SenderDequeueSdu ==
    /\ senderState = "IDLE"
    /\ Len(appQueue) > 0
    /\ senderState' = "TX"
    /\ senderCurrentSdu' = Head(appQueue)
    /\ senderRemainingBytes' = Head(appQueue)
    /\ appQueue' = Tail(appQueue)
    /\ UNCHANGED <<inFlight, receiverState, receiverExpectedLen, receiverReceivedLen, receiverHasBeg>>

\* SOURCE: core_4.19.4.5 "That BTP SDU SHALL be split into ordered, non-overlapping BTP segments... length of the data payload in each BTP segment whose Ending Segment bit is not set SHALL be equal to the session's maximum BTP packet size minus the size of that packet's header."
SenderTxSegment ==
    /\ senderState = "TX"
    /\ senderRemainingBytes > 0
    /\ LET maxPayload == MaxBtpPacketSize - BtpHeaderSize
           isEnd == (senderRemainingBytes <= maxPayload)
           payloadSize == IF isEnd THEN senderRemainingBytes ELSE maxPayload
           isBeg == (senderRemainingBytes = senderCurrentSdu)
           msgLen == IF isBeg THEN senderCurrentSdu ELSE 0
           seg == [
               isBeg |-> isBeg,
               isEnd |-> isEnd,
               msgLen |-> msgLen,
               payloadSize |-> payloadSize
           ]
       IN
           /\ inFlight' = Append(inFlight, seg)
           /\ senderRemainingBytes' = senderRemainingBytes - payloadSize
    /\ UNCHANGED <<appQueue, senderState, senderCurrentSdu, receiverState, receiverExpectedLen, receiverReceivedLen, receiverHasBeg>>

\* SOURCE: core_4.19.4.5 "once transmission of the current BTP SDU completes, that is, once all BTP segments of the current BDP SDU have been transmitted and received by the peer via GATT"
SenderCompleteSdu ==
    /\ senderState = "TX"
    /\ senderRemainingBytes = 0
    /\ Len(inFlight) = 0
    /\ senderState' = "IDLE"
    /\ senderCurrentSdu' = 0
    /\ UNCHANGED <<appQueue, senderRemainingBytes, inFlight, receiverState, receiverExpectedLen, receiverReceivedLen, receiverHasBeg>>

\* SOURCE: core_4.19.4.5 "Once a peer receives a complete set of BTP segments, it SHALL reassemble them... verify that the reassembled BTP SDU's total length matches... If the reassembled buffer's length does not match... or if received BTP segment payload size would exceed the maximum BTP packet size, or receiver receives an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when another BTP SDU's transmission is already in progress, the receiver BTP SHALL close the BTP session"
\* TODO: unspecified - Behavior when a middle BTP segment (neither Beginning nor Ending) is received while the receiver is IDLE is not explicitly stated. The model accumulates it until an Ending segment triggers the 'Ending without Beginning' error.
ReceiverRxSegment ==
    /\ receiverState # "CLOSED"
    /\ Len(inFlight) > 0
    /\ LET seg == Head(inFlight)
           payloadExceedsMax == seg.payloadSize + BtpHeaderSize > MaxBtpPacketSize
           endingWithoutBeg == seg.isEnd /\ ~receiverHasBeg /\ ~(seg.isBeg)
           begWhileInProgress == seg.isBeg /\ receiverState = "RX"
       IN
           IF payloadExceedsMax \/ endingWithoutBeg \/ begWhileInProgress THEN
               /\ receiverState' = "CLOSED"
               /\ receiverExpectedLen' = 0
               /\ receiverReceivedLen' = 0
               /\ receiverHasBeg' = FALSE
               /\ inFlight' = Tail(inFlight)
           ELSE
               LET newReceivedLen == IF seg.isBeg THEN seg.payloadSize ELSE receiverReceivedLen + seg.payloadSize
                   newExpectedLen == IF seg.isBeg THEN seg.msgLen ELSE receiverExpectedLen
               IN
                   IF seg.isEnd THEN
                       IF newReceivedLen = newExpectedLen THEN
                           /\ receiverState' = "IDLE"
                           /\ receiverExpectedLen' = 0
                           /\ receiverReceivedLen' = 0
                           /\ receiverHasBeg' = FALSE
                       ELSE
                           /\ receiverState' = "CLOSED"
                           /\ receiverExpectedLen' = 0
                           /\ receiverReceivedLen' = 0
                           /\ receiverHasBeg' = FALSE
                   ELSE
                       /\ receiverState' = "RX"
                       /\ receiverExpectedLen' = newExpectedLen
                       /\ receiverReceivedLen' = newReceivedLen
                       /\ receiverHasBeg' = receiverHasBeg \/ seg.isBeg
               /\ inFlight' = Tail(inFlight)
    /\ UNCHANGED <<appQueue, senderState, senderCurrentSdu, senderRemainingBytes>>

Next == 
    \/ AppSendsSdu 
    \/ SenderDequeueSdu 
    \/ SenderTxSegment 
    \/ SenderCompleteSdu 
    \/ ReceiverRxSegment

====