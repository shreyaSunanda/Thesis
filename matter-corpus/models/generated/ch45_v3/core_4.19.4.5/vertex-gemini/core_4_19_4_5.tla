---- MODULE core_4_19_4_5 ----
EXTENDS Naturals, Sequences

\* Maximum payload size of a GATT PDU (BTP packet size limit).
CONSTANTS MaxBtpPacketSize

\* Size of the BTP packet header when Beginning Segment flag is false.
CONSTANTS HeaderSize

\* Size of the BTP packet header when Beginning Segment flag is true (includes Message Length).
CONSTANTS HeaderSizeWithLength

\* Limit on maximum SDU size (Real value per spec: 65535, use small value for TLC).
CONSTANTS MaxSduSize

\* Maximum depth of the transmit queue (to bound state space).
CONSTANTS MaxQueueSize

\* Sentinel for no pending input waiting to be handled.
CONSTANTS NoInput

VARIABLES pendingInput

\* Data fields carried by incoming events (modeled as separate variables per rules)
VARIABLES inputSduSize         \* For AppSendSdu
VARIABLES inputSegBeginning    \* For ReceiveSegment
VARIABLES inputSegEnding       \* For ReceiveSegment
VARIABLES inputSegMsgLength    \* For ReceiveSegment
VARIABLES inputSegPayloadSize  \* For ReceiveSegment

\* Session variables
VARIABLES sessionState         \* "Open" or "Closed"
VARIABLES errorReported        \* TRUE if an error was reported to the application

\* Transmitter variables
VARIABLES txQueue              \* FIFO queue of pending SDU sizes
VARIABLES txActiveSduSize      \* Size of the currently transmitting SDU (0 if none)
VARIABLES txSentSize           \* Number of bytes of the current SDU already sent

\* Receiver variables
VARIABLES rxState              \* "Idle" or "Receiving"
VARIABLES rxExpectedLength     \* Total length expected based on Beginning Segment
VARIABLES rxAccumulatedLength  \* Total length received so far

\* The complete list of events this section can receive.
Inputs == {"AppSendSdu", "ProceedTx", "ReceiveSegment"}

Init ==
    /\ pendingInput = NoInput
    /\ inputSduSize = 0
    /\ inputSegBeginning = FALSE
    /\ inputSegEnding = FALSE
    /\ inputSegMsgLength = 0
    /\ inputSegPayloadSize = 0
    /\ sessionState = "Open"
    /\ errorReported = FALSE
    /\ txQueue = <<>>
    /\ txActiveSduSize = 0
    /\ txSentSize = 0
    /\ rxState = "Idle"
    /\ rxExpectedLength = 0
    /\ rxAccumulatedLength = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    \* Nondeterministically choose payload values for the input events
    /\ \E sduSize \in 1..MaxSduSize,
          isBeg \in {TRUE, FALSE},
          isEnd \in {TRUE, FALSE},
          msgLen \in 0..MaxSduSize,
          paySize \in 0..(MaxBtpPacketSize + 10):
        /\ inputSduSize' = sduSize
        /\ inputSegBeginning' = isBeg
        /\ inputSegEnding' = isEnd
        /\ inputSegMsgLength' = msgLen
        /\ inputSegPayloadSize' = paySize
    /\ UNCHANGED << txQueue, txActiveSduSize, txSentSize,
                    rxState, rxExpectedLength, rxAccumulatedLength,
                    sessionState, errorReported >>

\* SOURCE: core_4.19.4.5 Message Segmentation and Reassembly
\* TODO: unspecified - Spec does not state how to handle AppSendSdu if the session is not Open.
HandleAppSendSdu ==
    /\ pendingInput = "AppSendSdu"
    /\ sessionState = "Open"
    /\ IF txActiveSduSize = 0
       THEN /\ txActiveSduSize' = inputSduSize
            /\ txSentSize' = 0
            /\ txQueue' = txQueue
       ELSE /\ Len(txQueue) < MaxQueueSize
            /\ txQueue' = Append(txQueue, inputSduSize)
            /\ UNCHANGED <<txActiveSduSize, txSentSize>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED << rxState, rxExpectedLength, rxAccumulatedLength,
                    sessionState, errorReported,
                    inputSduSize, inputSegBeginning, inputSegEnding,
                    inputSegMsgLength, inputSegPayloadSize >>

\* Helper logic for transmitter segmentation calculations
TxIsBeginning == (txSentSize = 0)
TxHdrSize == IF TxIsBeginning THEN HeaderSizeWithLength ELSE HeaderSize
TxMaxPayload == MaxBtpPacketSize - TxHdrSize
TxRemaining == txActiveSduSize - txSentSize
TxPayloadSize == IF TxRemaining <= TxMaxPayload THEN TxRemaining ELSE TxMaxPayload
TxIsEnding == (TxRemaining <= TxMaxPayload)

\* SOURCE: core_4.19.4.5 Message Segmentation and Reassembly
\* Simulates the completion of one segment's transmission and peer acknowledgement via GATT,
\* progressing the active SDU to the next segment or dequeuing the next SDU.
HandleProceedTx ==
    /\ pendingInput = "ProceedTx"
    /\ sessionState = "Open"
    /\ txActiveSduSize > 0
    /\ IF TxIsEnding
       THEN IF txQueue /= <<>>
            THEN /\ txActiveSduSize' = Head(txQueue)
                 /\ txQueue' = Tail(txQueue)
                 /\ txSentSize' = 0
            ELSE /\ txActiveSduSize' = 0
                 /\ txQueue' = txQueue
                 /\ txSentSize' = 0
       ELSE /\ txSentSize' = txSentSize + TxPayloadSize
            /\ UNCHANGED <<txActiveSduSize, txQueue>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED << rxState, rxExpectedLength, rxAccumulatedLength,
                    sessionState, errorReported,
                    inputSduSize, inputSegBeginning, inputSegEnding,
                    inputSegMsgLength, inputSegPayloadSize >>

\* Helper logic for receiver violation and accumulation checks
IsPayloadExceeds == inputSegPayloadSize > MaxBtpPacketSize
IsBegWhileInProgress == inputSegBeginning /\ rxState = "Receiving"
IsEndWithoutBegError == inputSegEnding /\ ~inputSegBeginning /\ rxState = "Idle"
HasReassemblyError == IsPayloadExceeds \/ IsBegWhileInProgress \/ IsEndWithoutBegError

NewRxAccumulated ==
    IF inputSegBeginning
    THEN inputSegPayloadSize
    ELSE rxAccumulatedLength + inputSegPayloadSize

NewRxExpected ==
    IF inputSegBeginning
    THEN inputSegMsgLength
    ELSE rxExpectedLength

\* SOURCE: core_4.19.4.5 Message Segmentation and Reassembly
\* TODO: unspecified - Spec does not state what happens if ReceiveSegment arrives on a Closed session.
HandleReceiveSegment ==
    /\ pendingInput = "ReceiveSegment"
    /\ sessionState = "Open"
    /\ IF HasReassemblyError
       THEN /\ sessionState' = "Closed"
            /\ errorReported' = TRUE
            /\ UNCHANGED <<rxState, rxExpectedLength, rxAccumulatedLength>>
       ELSE IF inputSegEnding
            THEN IF NewRxAccumulated = NewRxExpected
                 THEN /\ rxState' = "Idle"
                      /\ rxExpectedLength' = 0
                      /\ rxAccumulatedLength' = 0
                      /\ UNCHANGED <<sessionState, errorReported>>
                 ELSE /\ sessionState' = "Closed"
                      /\ errorReported' = TRUE
                      /\ UNCHANGED <<rxState, rxExpectedLength, rxAccumulatedLength>>
            ELSE /\ rxState' = "Receiving"
                 /\ rxExpectedLength' = NewRxExpected
                 /\ rxAccumulatedLength' = NewRxAccumulated
                 /\ UNCHANGED <<sessionState, errorReported>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED << txQueue, txActiveSduSize, txSentSize,
                    inputSduSize, inputSegBeginning, inputSegEnding,
                    inputSegMsgLength, inputSegPayloadSize >>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleAppSendSdu
    \/ HandleProceedTx
    \/ HandleReceiveSegment

====