---- MODULE core_4_19_4_5 ----
EXTENDS Naturals, Sequences

\* Maximum allowed size for a single BTP SDU (real value per spec: 65535 bytes).
CONSTANTS MaxSduSize

\* Maximum size of a BTP packet, dictated by session MTU.
CONSTANTS MaxBtpPacketSize

\* Size of the BTP header when Beginning Segment flag is set (includes Message Length).
CONSTANTS BtpHeaderSizeWithMsgLength

\* Size of the BTP header when Beginning Segment flag is not set.
CONSTANTS BtpHeaderSizeWithoutMsgLength

\* Maximum bound for the transmitter's SDU queue to ensure finite state space.
CONSTANTS MaxQueueLen

\* Sentinel value indicating no SDU is currently being processed.
CONSTANTS NullSdu

\* Sentinel value indicating no pending input event.
CONSTANTS NoInput

VARIABLES 
    state,
    pendingInput,
    \* Sender state
    txQueue,
    txCurrentSduLen,
    txSentLen,
    txInFlight,
    \* Receiver state
    rxSessionState,
    rxInProgress,
    rxExpectedLength,
    rxAccumulatedLength,
    \* Event payload data variables
    inAppSduLength,
    inSegBeginning,
    inSegEnding,
    inSegMsgLength,
    inSegPayloadLength

Inputs == {"AppSendSDU", "GATTSegmentAck", "GATTReceiveSegment"}

Operational == rxSessionState = "OPEN"

Init ==
    /\ state = "Running"
    /\ pendingInput = NoInput
    /\ txQueue = <<>>
    /\ txCurrentSduLen = NullSdu
    /\ txSentLen = 0
    /\ txInFlight = FALSE
    /\ rxSessionState = "OPEN"
    /\ rxInProgress = FALSE
    /\ rxExpectedLength = 0
    /\ rxAccumulatedLength = 0
    /\ inAppSduLength = 0
    /\ inSegBeginning = FALSE
    /\ inSegEnding = FALSE
    /\ inSegMsgLength = 0
    /\ inSegPayloadLength = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ (\E sduLen \in 1..(MaxSduSize + 1), beg \in BOOLEAN, end \in BOOLEAN, msgLen \in 0..MaxSduSize, payLen \in 0..(MaxBtpPacketSize + 1):
           /\ inAppSduLength' = sduLen
           /\ inSegBeginning' = beg
           /\ inSegEnding' = end
           /\ inSegMsgLength' = msgLen
           /\ inSegPayloadLength' = payLen)
    /\ UNCHANGED <<state, txQueue, txCurrentSduLen, txSentLen, txInFlight, rxSessionState, rxInProgress, rxExpectedLength, rxAccumulatedLength>>

\* SOURCE: core_4.19.4.5 If the application attempts to send one BTP SDU while transmission of another BTP SDU is in progress, the new BTP SDU SHALL be appended to a first-in, first-out queue.
HandleAppSendSDU ==
    /\ pendingInput = "AppSendSDU"
    /\ inAppSduLength <= MaxSduSize
    /\ IF txCurrentSduLen # NullSdu \/ txInFlight
       THEN /\ Len(txQueue) < MaxQueueLen
            /\ txQueue' = Append(txQueue, inAppSduLength)
            /\ UNCHANGED <<txCurrentSduLen, txSentLen>>
       ELSE /\ txQueue' = txQueue
            /\ txCurrentSduLen' = inAppSduLength
            /\ txSentLen' = 0
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, txInFlight, rxSessionState, rxInProgress, rxExpectedLength, rxAccumulatedLength, inAppSduLength, inSegBeginning, inSegEnding, inSegMsgLength, inSegPayloadLength>>

\* SOURCE: core_4.19.4.5 The next BTP SDU SHALL be dequeued from this queue and transmitted once transmission of the current BTP SDU completes...
HandleGATTSegmentAck ==
    /\ pendingInput = "GATTSegmentAck"
    /\ txInFlight = TRUE
    /\ txInFlight' = FALSE
    /\ IF txSentLen = txCurrentSduLen
       THEN IF Len(txQueue) > 0
            THEN /\ txCurrentSduLen' = Head(txQueue)
                 /\ txSentLen' = 0
                 /\ txQueue' = Tail(txQueue)
            ELSE /\ txCurrentSduLen' = NullSdu
                 /\ txSentLen' = 0
                 /\ txQueue' = txQueue
       ELSE UNCHANGED <<txCurrentSduLen, txSentLen, txQueue>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, rxSessionState, rxInProgress, rxExpectedLength, rxAccumulatedLength, inAppSduLength, inSegBeginning, inSegEnding, inSegMsgLength, inSegPayloadLength>>

NextPayloadLength ==
    LET isBeginning == (txSentLen = 0)
        headerSize == IF isBeginning THEN BtpHeaderSizeWithMsgLength ELSE BtpHeaderSizeWithoutMsgLength
        maxPayload == MaxBtpPacketSize - headerSize
        remaining == txCurrentSduLen - txSentLen
        isEnding == remaining <= maxPayload
    IN IF isEnding THEN remaining ELSE maxPayload

\* SOURCE: core_4.19.4.5 Each BTP segment SHALL be prepended with a BTP packet header and sent as the payload of a single GATT PDU.
TransmitSegment ==
    /\ pendingInput = NoInput
    /\ txCurrentSduLen # NullSdu
    /\ ~txInFlight
    /\ txInFlight' = TRUE
    /\ txSentLen' = txSentLen + NextPayloadLength
    /\ UNCHANGED <<state, pendingInput, txQueue, txCurrentSduLen, rxSessionState, rxInProgress, rxExpectedLength, rxAccumulatedLength, inAppSduLength, inSegBeginning, inSegEnding, inSegMsgLength, inSegPayloadLength>>

ErrorDetected ==
    \/ inSegPayloadLength > MaxBtpPacketSize
    \/ (inSegEnding /\ ~inSegBeginning /\ ~rxInProgress)
    \/ (inSegBeginning /\ rxInProgress)
    \/ (inSegEnding /\ (IF inSegBeginning THEN inSegPayloadLength ELSE rxAccumulatedLength + inSegPayloadLength) # (IF inSegBeginning THEN inSegMsgLength ELSE rxExpectedLength))

NextRxExpected ==
    IF inSegBeginning THEN inSegMsgLength ELSE rxExpectedLength

NextRxAccumulated ==
    IF inSegEnding 
    THEN 0 
    ELSE (IF inSegBeginning THEN inSegPayloadLength ELSE rxAccumulatedLength + inSegPayloadLength)

\* SOURCE: core_4.19.4.5 Once a peer receives a complete set of BTP segments, it SHALL reassemble them... If the reassembled buffer’s length does not match...
HandleGATTReceiveSegment ==
    /\ pendingInput = "GATTReceiveSegment"
    /\ IF rxSessionState = "CLOSED"
       THEN \* TODO: unspecified - what happens if a segment is received after the session is closed?
            UNCHANGED <<rxSessionState, rxInProgress, rxExpectedLength, rxAccumulatedLength>>
       ELSE
         IF ErrorDetected
         THEN /\ rxSessionState' = "CLOSED"
              /\ UNCHANGED <<rxInProgress, rxExpectedLength, rxAccumulatedLength>>
         ELSE /\ rxSessionState' = rxSessionState
              /\ rxExpectedLength' = NextRxExpected
              /\ rxAccumulatedLength' = NextRxAccumulated
              /\ rxInProgress' = ~inSegEnding
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, txQueue, txCurrentSduLen, txSentLen, txInFlight, inAppSduLength, inSegBeginning, inSegEnding, inSegMsgLength, inSegPayloadLength>>

Next == 
    \/ (\E e \in Inputs: ReceiveInput(e))
    \/ HandleAppSendSDU
    \/ HandleGATTSegmentAck
    \/ TransmitSegment
    \/ HandleGATTReceiveSegment

====