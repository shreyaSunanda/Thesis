---- MODULE core_4_20_3_5 ----
EXTENDS Naturals, Sequences

\* Maximum size of a PAFTP SDU (real value 64KB, abstracted for checking)
CONSTANTS MaxSduSize
\* Maximum payload size (PAFTP packet size minus header size)
CONSTANTS MaxPayloadSize
\* Bound for the sender's transmission queue
CONSTANTS MaxQueueSize
\* Bound for sequence numbers
CONSTANTS MaxSeqNum

CONSTANTS NoInput
VARIABLES pendingInput

\* Separate variables modeling the data carried by incoming events
VARIABLES inSduSize
VARIABLES inSegBeg
VARIABLES inSegEnd
VARIABLES inSegLen
VARIABLES inSegMsgLen
VARIABLES inSegSeqNum

\* Sender state
VARIABLES txState          \* "IDLE" or "TX"
VARIABLES txQueue          \* FIFO queue of SDU sizes
VARIABLES txCurrentSdu     \* Size of the SDU currently being transmitted
VARIABLES txBytesSent      \* Bytes of the current SDU transmitted so far

\* Receiver state
VARIABLES rxState          \* "IDLE", "RX", or "CLOSED"
VARIABLES rxExpectedLen    \* Expected total length from Beginning Segment
VARIABLES rxAccumulatedLen \* Accumulated bytes for the current SDU
VARIABLES rxExpectedSeqNum \* Expected next sequence number

Inputs == {"AppSendSdu", "ReceiveSegment", "TxComplete"}

Operational == rxState \in {"IDLE", "RX"}

Init ==
    /\ pendingInput = NoInput
    /\ inSduSize = 1
    /\ inSegBeg = FALSE
    /\ inSegEnd = FALSE
    /\ inSegLen = 0
    /\ inSegMsgLen = 0
    /\ inSegSeqNum = 0
    /\ txState = "IDLE"
    /\ txQueue = <<>>
    /\ txCurrentSdu = 0
    /\ txBytesSent = 0
    /\ rxState = "IDLE"
    /\ rxExpectedLen = 0
    /\ rxAccumulatedLen = 0
    /\ rxExpectedSeqNum = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    \* Non-deterministically supply event data for the handling actions to read.
    \* Bounds are small abstract ranges. MaxPayloadSize + 1 allows testing the oversized segment error.
    /\ \E sduSize \in 1..MaxSduSize, beg \in BOOLEAN, end \in BOOLEAN, len \in 0..(MaxPayloadSize + 1), msgLen \in 0..MaxSduSize, seq \in 0..MaxSeqNum:
           /\ inSduSize' = sduSize
           /\ inSegBeg' = beg
           /\ inSegEnd' = end
           /\ inSegLen' = len
           /\ inSegMsgLen' = msgLen
           /\ inSegSeqNum' = seq
    /\ UNCHANGED <<txState, txQueue, txCurrentSdu, txBytesSent, rxState, rxExpectedLen, rxAccumulatedLen, rxExpectedSeqNum>>

\* SOURCE: core_4.20.3.5 Message Segmentation and Reassembly
AppSend_Idle ==
    /\ pendingInput = "AppSendSdu"
    /\ txState = "IDLE"
    /\ txState' = "TX"
    /\ txCurrentSdu' = inSduSize
    /\ txBytesSent' = 0
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSduSize, inSegBeg, inSegEnd, inSegLen, inSegMsgLen, inSegSeqNum, txQueue, rxState, rxExpectedLen, rxAccumulatedLen, rxExpectedSeqNum>>

\* SOURCE: core_4.20.3.5 Message Segmentation and Reassembly
AppSend_TxInProgress ==
    /\ pendingInput = "AppSendSdu"
    /\ txState = "TX"
    /\ Len(txQueue) < MaxQueueSize
    /\ txQueue' = Append(txQueue, inSduSize)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSduSize, inSegBeg, inSegEnd, inSegLen, inSegMsgLen, inSegSeqNum, txState, txCurrentSdu, txBytesSent, rxState, rxExpectedLen, rxAccumulatedLen, rxExpectedSeqNum>>

\* SOURCE: core_4.20.3.5 Message Segmentation and Reassembly
DequeueAndTransmit ==
    /\ pendingInput = "TxComplete"
    /\ txState = "TX"
    /\ txQueue # <<>>
    /\ txCurrentSdu' = Head(txQueue)
    /\ txQueue' = Tail(txQueue)
    /\ txBytesSent' = 0
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSduSize, inSegBeg, inSegEnd, inSegLen, inSegMsgLen, inSegSeqNum, txState, rxState, rxExpectedLen, rxAccumulatedLen, rxExpectedSeqNum>>

\* SOURCE: core_4.20.3.5 Message Segmentation and Reassembly
TxComplete_Idle ==
    /\ pendingInput = "TxComplete"
    /\ txState = "TX"
    /\ txQueue = <<>>
    /\ txState' = "IDLE"
    /\ txCurrentSdu' = 0
    /\ txBytesSent' = 0
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSduSize, inSegBeg, inSegEnd, inSegLen, inSegMsgLen, inSegSeqNum, txQueue, rxState, rxExpectedLen, rxAccumulatedLen, rxExpectedSeqNum>>

\* Helper logic for segment payload sizing according to Ending Segment bit rules
\* SOURCE: core_4.20.3.5 Message Segmentation and Reassembly
TransmitSegment ==
    /\ pendingInput = NoInput
    /\ txState = "TX"
    /\ txBytesSent < txCurrentSdu
    /\ LET remaining == txCurrentSdu - txBytesSent
           isLast == remaining <= MaxPayloadSize
           payloadLen == IF isLast THEN remaining ELSE MaxPayloadSize
       IN
           /\ txBytesSent' = txBytesSent + payloadLen
           /\ UNCHANGED <<pendingInput, inSduSize, inSegBeg, inSegEnd, inSegLen, inSegMsgLen, inSegSeqNum, txState, txQueue, txCurrentSdu, rxState, rxExpectedLen, rxAccumulatedLen, rxExpectedSeqNum>>

\* Helper definitions for receiver validation rules
IsMaxPayloadExceeded == inSegLen > MaxPayloadSize
IsEndingWithoutBeg == (inSegEnd = TRUE) /\ (inSegBeg = FALSE) /\ (rxState = "IDLE")
IsBegWhileInProgress == (inSegBeg = TRUE) /\ (rxState = "RX")

TotalLen == IF inSegBeg = TRUE THEN inSegLen ELSE rxAccumulatedLen + inSegLen
ExpectedLen == IF inSegBeg = TRUE THEN inSegMsgLen ELSE rxExpectedLen

IsLengthMismatch == (inSegEnd = TRUE) /\ (TotalLen # ExpectedLen)

IsReceiverError ==
    \/ IsMaxPayloadExceeded
    \/ IsEndingWithoutBeg
    \/ IsBegWhileInProgress
    \/ IsLengthMismatch

\* TODO: unspecified - The spec lists an error for receiving an Ending Segment without a previous Beginning Segment, but does not specify the behavior (or error) for receiving a middle segment (Beginning = FALSE, Ending = FALSE) while in the IDLE state.
\* TODO: unspecified - Spec says to reassemble in ascending order but does not specify the explicit failure behavior (e.g., buffer, drop, or close session) when segments arrive out of order or are missing.

\* SOURCE: core_4.20.3.5 Message Segmentation and Reassembly
HandleReceiveSegment ==
    /\ pendingInput = "ReceiveSegment"
    /\ rxState # "CLOSED"
    /\ IF IsReceiverError THEN
           /\ rxState' = "CLOSED"
           /\ UNCHANGED <<rxExpectedLen, rxAccumulatedLen, rxExpectedSeqNum>>
       ELSE
           /\ rxExpectedLen' = ExpectedLen
           /\ rxAccumulatedLen' = TotalLen
           /\ rxExpectedSeqNum' = inSegSeqNum + 1
           /\ rxState' = IF inSegEnd = TRUE THEN "IDLE" ELSE "RX"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSduSize, inSegBeg, inSegEnd, inSegLen, inSegMsgLen, inSegSeqNum, txState, txQueue, txCurrentSdu, txBytesSent>>

Next ==
    \/ \E e \in Inputs : ReceiveInput(e)
    \/ AppSend_Idle
    \/ AppSend_TxInProgress
    \/ DequeueAndTransmit
    \/ TxComplete_Idle
    \/ TransmitSegment
    \/ HandleReceiveSegment

====