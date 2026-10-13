---- MODULE core_4_20_3_5 ----
EXTENDS Naturals, Sequences

CONSTANTS 
    \* The maximum size of the Message Length field in the PAFTP packet header (64KB)
    MaxSDUSize,
    \* The session's maximum PAFTP packet size
    MaxPacketSize,
    \* The size of the PAFTP packet's header
    HeaderSize

VARIABLES 
    txQueue,
    txSduActive,
    txCurrentSduLen,
    txBytesSent,
    txNextSeqNum,
    txWaitingPeerReceipt,
    rxState,
    rxSduActive,
    rxExpectedLen,
    rxBytesReceived,
    rxNextExpectedSeqNum,
    network,
    appErrors,
    upperLayerMsgs

Init == 
    /\ txQueue = <<>>
    /\ txSduActive = FALSE
    /\ txCurrentSduLen = 0
    /\ txBytesSent = 0
    /\ txNextSeqNum = 0
    /\ txWaitingPeerReceipt = FALSE
    /\ rxState = "OPEN"
    /\ rxSduActive = FALSE
    /\ rxExpectedLen = 0
    /\ rxBytesReceived = 0
    /\ rxNextExpectedSeqNum = 0
    /\ network = {}
    /\ appErrors = 0
    /\ upperLayerMsgs = <<>>

\* SOURCE: core_4.20.3.5 "If the application attempts to send one PAFTP SDU while transmission of another PAFTP SDU is in progress, the new PAFTP SDU SHALL be appended to a first-in, first-out queue."
AppEnqueueSDU == 
    \E len \in 1..MaxSDUSize :
        /\ txQueue' = Append(txQueue, len)
        /\ UNCHANGED <<txSduActive, txCurrentSduLen, txBytesSent, txNextSeqNum, txWaitingPeerReceipt, rxState, rxSduActive, rxExpectedLen, rxBytesReceived, rxNextExpectedSeqNum, network, appErrors, upperLayerMsgs>>

\* SOURCE: core_4.20.3.5 "The next PAFTP SDU SHALL be dequeued from this queue and transmitted once transmission of the current PAFTP SDU completes, that is, once all PAFTP segments of the current PAFTP SDU have been transmitted and received by the peer."
TxStartNextSDU == 
    /\ ~txSduActive
    /\ ~txWaitingPeerReceipt
    /\ txQueue # <<>>
    /\ txSduActive' = TRUE
    /\ txCurrentSduLen' = Head(txQueue)
    /\ txQueue' = Tail(txQueue)
    /\ txBytesSent' = 0
    /\ UNCHANGED <<txNextSeqNum, txWaitingPeerReceipt, rxState, rxSduActive, rxExpectedLen, rxBytesReceived, rxNextExpectedSeqNum, network, appErrors, upperLayerMsgs>>

\* SOURCE: core_4.20.3.5 "split into ordered, non-overlapping PAFTP segments ... The first PAFTP segment ... SHALL have its Beginning Segment header flag set ... The last PAFTP segment ... SHALL have its Ending Segment flag set"
\* SOURCE: core_4.20.3.5 "The length of the data payload in each PAFTP segment whose Ending Segment bit is not set SHALL be equal to the session’s maximum PAFTP packet size minus the size of that PAFTP packet’s header. If a packet’s Ending Segment bit is set, the length of its PAFTP segment data payload SHALL equal the size of the original PAFTP SDU minus the total size of all previously transmitted PAFTP segments"
TxSendSegment == 
    /\ txSduActive
    /\ LET remaining == txCurrentSduLen - txBytesSent
           maxPayload == MaxPacketSize - HeaderSize
           isFirst == (txBytesSent = 0)
           isLast == (remaining <= maxPayload)
           payloadLen == IF isLast THEN remaining ELSE maxPayload
           seg == [
               begFlag    |-> isFirst,
               endFlag    |-> isLast,
               msgLen     |-> txCurrentSduLen,
               payloadLen |-> payloadLen,
               seqNum     |-> txNextSeqNum
           ]
       IN 
           /\ network' = network \union {seg}
           /\ txBytesSent' = txBytesSent + payloadLen
           /\ txNextSeqNum' = txNextSeqNum + 1
           /\ IF isLast THEN 
                  /\ txSduActive' = FALSE
                  /\ txWaitingPeerReceipt' = TRUE
              ELSE 
                  /\ UNCHANGED <<txSduActive, txWaitingPeerReceipt>>
    /\ UNCHANGED <<txQueue, txCurrentSduLen, rxState, rxSduActive, rxExpectedLen, rxBytesReceived, rxNextExpectedSeqNum, appErrors, upperLayerMsgs>>

\* TODO: unspecified - how the sender determines that the peer has received all segments of the current SDU. Model abstraction considers empty network implies peer receipt.
TxNoticeReceipt ==
    /\ txWaitingPeerReceipt
    /\ network = {}
    /\ txWaitingPeerReceipt' = FALSE
    /\ UNCHANGED <<txQueue, txSduActive, txCurrentSduLen, txBytesSent, txNextSeqNum, rxState, rxSduActive, rxExpectedLen, rxBytesReceived, rxNextExpectedSeqNum, appErrors, upperLayerMsgs, network>>

\* SOURCE: core_4.20.3.5 "A peer SHALL reassemble PAFTP segments in the ascending order of the segment sequence numbers. Once a peer receives a complete set of PAFTP segments, it SHALL verify that the reassembled PAFTP SDU’s total length matches... If they match, the receiver SHALL pass... up to the next-higher-layer. If the reassembled buffer’s length does not match... or if received PAFTP segment payload size would exceed the maximum PAFTP packet size, or receiver receives an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when another PAFTP SDU’s transmission is already in progress, the receiver PAFTP SHALL close the PAFTP session and report an error to the application."
RxReceiveSegment == 
    /\ rxState = "OPEN"
    /\ \E seg \in network :
        /\ seg.seqNum = rxNextExpectedSeqNum
        /\ network' = network \ {seg}
        /\ rxNextExpectedSeqNum' = rxNextExpectedSeqNum + 1
        /\ LET maxPayload == MaxPacketSize - HeaderSize
               newBytesRecv == rxBytesReceived + seg.payloadLen
           IN 
               IF seg.payloadLen > maxPayload THEN 
                   \* SOURCE: core_4.20.3.5 "received PAFTP segment payload size would exceed the maximum PAFTP packet size"
                   /\ rxState' = "CLOSED"
                   /\ appErrors' = appErrors + 1
                   /\ rxSduActive' = FALSE
                   /\ UNCHANGED <<rxExpectedLen, rxBytesReceived, upperLayerMsgs>>
               ELSE IF seg.begFlag /\ rxSduActive THEN 
                   \* SOURCE: core_4.20.3.5 "Beginning Segment when another PAFTP SDU’s transmission is already in progress"
                   /\ rxState' = "CLOSED"
                   /\ appErrors' = appErrors + 1
                   /\ rxSduActive' = FALSE
                   /\ UNCHANGED <<rxExpectedLen, rxBytesReceived, upperLayerMsgs>>
               ELSE IF seg.endFlag /\ ~seg.begFlag /\ ~rxSduActive THEN 
                   \* SOURCE: core_4.20.3.5 "Ending Segment without the presence of a previous Beginning Segment"
                   /\ rxState' = "CLOSED"
                   /\ appErrors' = appErrors + 1
                   /\ rxSduActive' = FALSE
                   /\ UNCHANGED <<rxExpectedLen, rxBytesReceived, upperLayerMsgs>>
               ELSE IF ~seg.begFlag /\ ~seg.endFlag /\ ~rxSduActive THEN 
                   \* TODO: unspecified - behavior when receiving a middle segment without a previous Beginning Segment
                   /\ UNCHANGED <<rxState, appErrors, rxSduActive, rxExpectedLen, rxBytesReceived, upperLayerMsgs>>
               ELSE 
                   \* Valid segments
                   IF seg.endFlag THEN 
                       \* Reassembly completes
                       LET totalLen == IF seg.begFlag THEN seg.payloadLen ELSE newBytesRecv
                           expectedLen == IF seg.begFlag THEN seg.msgLen ELSE rxExpectedLen
                       IN 
                       IF totalLen # expectedLen THEN 
                           \* SOURCE: core_4.20.3.5 "reassembled buffer’s length does not match that specified by the sender"
                           /\ rxState' = "CLOSED"
                           /\ appErrors' = appErrors + 1
                           /\ rxSduActive' = FALSE
                           /\ UNCHANGED <<rxExpectedLen, rxBytesReceived, upperLayerMsgs>>
                       ELSE 
                           \* SOURCE: core_4.20.3.5 "matches ... SHALL pass the reassembled PAFTP SDU up to the next-higher-layer"
                           /\ upperLayerMsgs' = Append(upperLayerMsgs, totalLen)
                           /\ rxSduActive' = FALSE
                           /\ rxExpectedLen' = 0
                           /\ rxBytesReceived' = 0
                           /\ UNCHANGED <<rxState, appErrors>>
                   ELSE 
                       \* Not ending segment
                       /\ rxSduActive' = TRUE
                       /\ rxExpectedLen' = IF seg.begFlag THEN seg.msgLen ELSE rxExpectedLen
                       /\ rxBytesReceived' = IF seg.begFlag THEN seg.payloadLen ELSE newBytesRecv
                       /\ UNCHANGED <<rxState, appErrors, upperLayerMsgs>>
    /\ UNCHANGED <<txQueue, txSduActive, txCurrentSduLen, txBytesSent, txNextSeqNum, txWaitingPeerReceipt>>

Next == 
    \/ AppEnqueueSDU
    \/ TxStartNextSDU
    \/ TxSendSegment
    \/ TxNoticeReceipt
    \/ RxReceiveSegment

====