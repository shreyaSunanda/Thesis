---- MODULE core_4_19_4_8 ----
EXTENDS Naturals, Sequences

\* fixed values and parameters from the spec text
CONSTANTS 
    MaxSeqNum,          \* The maximum sequence number value (real value per spec: 255 for 8-bit)
    MaxWindowSize,      \* Maximum slots in the receive/send window
    BTP_ACK_TIMEOUT,    \* Duration for acknowledgement-received timer
    NoSeqNum,           \* Sentinel representing no sequence number / no pending acknowledgement
    NoInput             \* Sentinel for no pending input

VARIABLES 
    state,
    pendingInput,
    ackRecvTimerRunning,
    sendAckTimerRunning,
    pendingAckVal,
    unackedList,
    freeSlots,
    nextSeqNum,
    inPacketSeqNum,
    inPacketAckNum,
    inPacketHasAck,
    inPacketIsStandAlone

Inputs == {
    "ReceivePacket",
    "AckReceivedTimerExpires",
    "SendAckTimerExpires",
    "WindowShrinks",
    "AppSendPacket",
    "SendHandshakeResponse",
    "ReceiveHandshakeResponse"
}

Init == 
    /\ state = "Active"
    /\ pendingInput = NoInput
    /\ ackRecvTimerRunning = FALSE
    /\ sendAckTimerRunning = FALSE
    /\ pendingAckVal = NoSeqNum
    /\ unackedList = <<>>
    /\ freeSlots = MaxWindowSize
    /\ nextSeqNum = 0
    /\ inPacketSeqNum = NoSeqNum
    /\ inPacketAckNum = NoSeqNum
    /\ inPacketHasAck = FALSE
    /\ inPacketIsStandAlone = FALSE

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e = "ReceivePacket"
       THEN \E seq \in 0..MaxSeqNum, ack \in (0..MaxSeqNum) \cup {NoSeqNum}, hasAck \in {TRUE, FALSE}, isStandAlone \in {TRUE, FALSE}:
               /\ inPacketSeqNum' = seq
               /\ inPacketAckNum' = ack
               /\ inPacketHasAck' = hasAck
               /\ inPacketIsStandAlone' = isStandAlone
       ELSE /\ inPacketSeqNum' = inPacketSeqNum
            /\ inPacketAckNum' = inPacketAckNum
            /\ inPacketHasAck' = inPacketHasAck
            /\ inPacketIsStandAlone' = inPacketIsStandAlone
    /\ UNCHANGED <<state, ackRecvTimerRunning, sendAckTimerRunning, pendingAckVal, unackedList, freeSlots, nextSeqNum>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
HandleReceivePacket ==
    /\ pendingInput = "ReceivePacket"
    /\ IF state = "Active"
       THEN IF inPacketHasAck
            THEN IF \E i \in 1..Len(unackedList) : unackedList[i] = inPacketAckNum
                 THEN LET idx == CHOOSE i \in 1..Len(unackedList) : unackedList[i] = inPacketAckNum
                      IN /\ IF idx = Len(unackedList)
                            THEN ackRecvTimerRunning' = FALSE
                            ELSE ackRecvTimerRunning' = TRUE
                         /\ unackedList' = SubSeq(unackedList, idx + 1, Len(unackedList))
                         /\ pendingAckVal' = inPacketSeqNum
                         /\ sendAckTimerRunning' = TRUE
                         /\ state' = state
                 ELSE \* Invalid ack: doesn't correspond to an outstanding, unacknowledged seq number
                      /\ state' = "Closed_Error"
                      /\ ackRecvTimerRunning' = FALSE
                      /\ sendAckTimerRunning' = FALSE
                      /\ pendingAckVal' = pendingAckVal
                      /\ unackedList' = unackedList
            ELSE \* No ack in packet
                 /\ pendingAckVal' = inPacketSeqNum
                 /\ sendAckTimerRunning' = TRUE
                 /\ UNCHANGED <<state, ackRecvTimerRunning, unackedList>>
       ELSE UNCHANGED <<state, ackRecvTimerRunning, sendAckTimerRunning, pendingAckVal, unackedList>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<freeSlots, nextSeqNum, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
HandleAppSendPacket ==
    /\ pendingInput = "AppSendPacket"
    /\ IF state = "Active" /\ Len(unackedList) < MaxWindowSize
       THEN /\ ackRecvTimerRunning' = TRUE
            /\ unackedList' = Append(unackedList, nextSeqNum)
            /\ nextSeqNum' = (nextSeqNum + 1) % (MaxSeqNum + 1)
            /\ IF pendingAckVal # NoSeqNum
               THEN /\ pendingAckVal' = NoSeqNum
                    /\ sendAckTimerRunning' = FALSE
               ELSE UNCHANGED <<pendingAckVal, sendAckTimerRunning>>
            /\ pendingInput' = NoInput
            /\ UNCHANGED <<state, freeSlots, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>
       ELSE /\ pendingInput' = NoInput
            /\ UNCHANGED <<state, ackRecvTimerRunning, unackedList, nextSeqNum, pendingAckVal, sendAckTimerRunning, freeSlots, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
HandleAckReceivedTimerExpires ==
    /\ pendingInput = "AckReceivedTimerExpires"
    /\ IF state = "Active" /\ ackRecvTimerRunning
       THEN /\ state' = "Closed_Error"
            /\ ackRecvTimerRunning' = FALSE
            /\ sendAckTimerRunning' = FALSE
            /\ pendingInput' = NoInput
            /\ UNCHANGED <<pendingAckVal, unackedList, freeSlots, nextSeqNum, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>
       ELSE /\ pendingInput' = NoInput
            /\ UNCHANGED <<state, ackRecvTimerRunning, sendAckTimerRunning, pendingAckVal, unackedList, freeSlots, nextSeqNum, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
HandleSendAckTimerExpires ==
    /\ pendingInput = "SendAckTimerExpires"
    /\ IF state = "Active" /\ sendAckTimerRunning /\ Len(unackedList) < MaxWindowSize
       THEN IF pendingAckVal # NoSeqNum
            THEN /\ pendingAckVal' = NoSeqNum
                 /\ sendAckTimerRunning' = FALSE
                 /\ ackRecvTimerRunning' = TRUE
                 /\ unackedList' = Append(unackedList, nextSeqNum)
                 /\ nextSeqNum' = (nextSeqNum + 1) % (MaxSeqNum + 1)
                 /\ pendingInput' = NoInput
                 /\ UNCHANGED <<state, freeSlots, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>
            ELSE /\ pendingInput' = NoInput
                 /\ UNCHANGED <<state, ackRecvTimerRunning, sendAckTimerRunning, pendingAckVal, unackedList, freeSlots, nextSeqNum, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>
       ELSE /\ pendingInput' = NoInput
            /\ UNCHANGED <<state, ackRecvTimerRunning, sendAckTimerRunning, pendingAckVal, unackedList, freeSlots, nextSeqNum, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
HandleWindowShrinks ==
    /\ pendingInput = "WindowShrinks"
    /\ IF state = "Active" /\ pendingAckVal # NoSeqNum /\ Len(unackedList) < MaxWindowSize
       THEN /\ pendingAckVal' = NoSeqNum
            /\ sendAckTimerRunning' = FALSE
            /\ ackRecvTimerRunning' = TRUE
            /\ unackedList' = Append(unackedList, nextSeqNum)
            /\ nextSeqNum' = (nextSeqNum + 1) % (MaxSeqNum + 1)
            /\ pendingInput' = NoInput
            /\ UNCHANGED <<state, freeSlots, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>
       ELSE /\ pendingInput' = NoInput
            /\ UNCHANGED <<state, ackRecvTimerRunning, sendAckTimerRunning, pendingAckVal, unackedList, freeSlots, nextSeqNum, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
HandleSendHandshakeResponse ==
    /\ pendingInput = "SendHandshakeResponse"
    /\ IF state = "Active" /\ Len(unackedList) < MaxWindowSize
       THEN /\ ackRecvTimerRunning' = TRUE
            /\ unackedList' = Append(unackedList, 0)
            /\ nextSeqNum' = 1
            /\ pendingInput' = NoInput
            /\ UNCHANGED <<state, sendAckTimerRunning, pendingAckVal, freeSlots, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>
       ELSE /\ pendingInput' = NoInput
            /\ UNCHANGED <<state, ackRecvTimerRunning, sendAckTimerRunning, pendingAckVal, unackedList, freeSlots, nextSeqNum, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
HandleReceiveHandshakeResponse ==
    /\ pendingInput = "ReceiveHandshakeResponse"
    /\ IF state = "Active"
       THEN /\ pendingAckVal' = 0
            /\ sendAckTimerRunning' = TRUE
            /\ pendingInput' = NoInput
            /\ UNCHANGED <<state, ackRecvTimerRunning, unackedList, freeSlots, nextSeqNum, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>
       ELSE /\ pendingInput' = NoInput
            /\ UNCHANGED <<state, ackRecvTimerRunning, sendAckTimerRunning, pendingAckVal, unackedList, freeSlots, nextSeqNum, inPacketSeqNum, inPacketAckNum, inPacketHasAck, inPacketIsStandAlone>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleReceivePacket
    \/ HandleAppSendPacket
    \/ HandleAckReceivedTimerExpires
    \/ HandleSendAckTimerExpires
    \/ HandleWindowShrinks
    \/ HandleSendHandshakeResponse
    \/ HandleReceiveHandshakeResponse

====