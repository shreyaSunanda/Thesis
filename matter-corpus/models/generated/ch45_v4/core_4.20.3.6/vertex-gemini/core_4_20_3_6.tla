---- MODULE core_4_20_3_6 ----
EXTENDS Naturals

\* Sentinel for no pending input
CONSTANTS NoInput

\* Sentinel for no sequence number
CONSTANTS NoSeqNum

VARIABLES pendingInput, inPacketSeqNum, sessionState, role, txSeqNum, expectedRxSeqNum, applicationError

Inputs == {"CompleteHandshakeAsCommissioner", "CompleteHandshakeAsDevice", "SendPacket", "ReceivePacket"}

Operational == sessionState \in {"ESTABLISHED", "CLOSED"}

Init ==
    /\ pendingInput = NoInput
    /\ inPacketSeqNum = NoSeqNum
    /\ sessionState = "HANDSHAKE"
    /\ role = "None"
    /\ txSeqNum = NoSeqNum
    /\ expectedRxSeqNum = NoSeqNum
    /\ applicationError = FALSE

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e = "ReceivePacket"
       THEN \E seq \in 0..255 : inPacketSeqNum' = seq
       ELSE inPacketSeqNum' = NoSeqNum
    /\ UNCHANGED <<sessionState, role, txSeqNum, expectedRxSeqNum, applicationError>>

\* SOURCE: core_4.20.3.6
CompleteHandshakeAsCommissioner ==
    /\ pendingInput = "CompleteHandshakeAsCommissioner"
    /\ sessionState = "HANDSHAKE"
    /\ role' = "Commissioner"
    /\ txSeqNum' = 0
    /\ expectedRxSeqNum' = 1
    /\ sessionState' = "ESTABLISHED"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inPacketSeqNum, applicationError>>

\* SOURCE: core_4.20.3.6
CompleteHandshakeAsDevice ==
    /\ pendingInput = "CompleteHandshakeAsDevice"
    /\ sessionState = "HANDSHAKE"
    /\ role' = "Device"
    /\ txSeqNum' = 1
    /\ expectedRxSeqNum' = 0
    /\ sessionState' = "ESTABLISHED"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inPacketSeqNum, applicationError>>

\* SOURCE: core_4.20.3.6
HandleSendPacket ==
    /\ pendingInput = "SendPacket"
    /\ sessionState = "ESTABLISHED"
    /\ txSeqNum' = (txSeqNum + 1) % 256
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inPacketSeqNum, sessionState, role, expectedRxSeqNum, applicationError>>

\* SOURCE: core_4.20.3.6
HandleReceivePacket ==
    /\ pendingInput = "ReceivePacket"
    /\ sessionState = "ESTABLISHED"
    /\ IF inPacketSeqNum = expectedRxSeqNum THEN
           /\ expectedRxSeqNum' = (expectedRxSeqNum + 1) % 256
           /\ UNCHANGED <<sessionState, applicationError>>
       ELSE
           /\ sessionState' = "CLOSED"
           /\ applicationError' = TRUE
           /\ UNCHANGED <<expectedRxSeqNum>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<role, txSeqNum, inPacketSeqNum>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ CompleteHandshakeAsCommissioner
    \/ CompleteHandshakeAsDevice
    \/ HandleSendPacket
    \/ HandleReceivePacket

====