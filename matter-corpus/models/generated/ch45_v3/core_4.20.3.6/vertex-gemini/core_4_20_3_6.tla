---- MODULE core_4_20_3_6 ----
EXTENDS Naturals

\* Real value per spec is 255 (8-bit unsigned integer max value)
CONSTANTS MaxSeqNum
\* Sentinel value indicating no packet sequence number was provided
CONSTANTS NullSeqNum

CONSTANTS NoInput
VARIABLES pendingInput, inPacketSeqNum, sessionState, localRole, txSeqNum, lastRxSeqNum, errorReported

Inputs == {
    "CompleteHandshakeAsCommissioner",
    "CompleteHandshakeAsDevice",
    "SendPacket",
    "ReceivePacket"
}

Init ==
    /\ pendingInput = NoInput
    /\ inPacketSeqNum = NullSeqNum
    /\ sessionState = "Idle"
    /\ localRole = "None"
    /\ txSeqNum = 0
    /\ lastRxSeqNum = NullSeqNum
    /\ errorReported = FALSE

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e = "ReceivePacket"
       THEN \E seq \in 0..MaxSeqNum : inPacketSeqNum' = seq
       ELSE inPacketSeqNum' = NullSeqNum
    /\ UNCHANGED <<sessionState, localRole, txSeqNum, lastRxSeqNum, errorReported>>

\* SOURCE: core_4.20.3.6
\* "The sequence number of the first packet sent by the Commissioner after completion of the PAFTP session handshake SHALL be zero. ... The Commissioner acknowledges the Commissionable Device’s PAFTP handshake response with an acknowledgement sequence of zero."
HandleHandshakeAsCommissioner ==
    /\ pendingInput = "CompleteHandshakeAsCommissioner"
    /\ sessionState = "Idle"
    /\ sessionState' = "Active"
    /\ localRole' = "Commissioner"
    /\ txSeqNum' = 0
    \* The device's handshake response bears an implied sequence number of 0.
    \* This establishes the remote peer's last sequence number as 0.
    /\ lastRxSeqNum' = 0
    /\ errorReported' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inPacketSeqNum>>

\* SOURCE: core_4.20.3.6
\* "The Commissionable Device PAFTP handshake response bears an implied sequence number of zero ... For this reason, the sequence number of the first data packet sent by the Commissionable Device after completion of the PAFTP session handshake SHALL be 1."
HandleHandshakeAsDevice ==
    /\ pendingInput = "CompleteHandshakeAsDevice"
    /\ sessionState = "Idle"
    /\ sessionState' = "Active"
    /\ localRole' = "Device"
    /\ txSeqNum' = 1
    \* The device expects the commissioner's first packet to have seq 0.
    \* To ensure the validity check ((lastRxSeqNum + 1) % Modulus = 0) succeeds on the
    \* first received packet, we initialize lastRxSeqNum to wrap correctly to 0.
    /\ lastRxSeqNum' = MaxSeqNum
    /\ errorReported' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inPacketSeqNum>>

\* SOURCE: core_4.20.3.6
\* "All PAFTP packets SHALL be sent with sequence numbers ... defined as an unsigned 8-bit integer value that monotonically increments by 1 with each packet sent by a given peer. A sequence number incremented past 255 SHALL wrap to zero."
HandleSendPacket ==
    /\ pendingInput = "SendPacket"
    /\ sessionState = "Active"
    /\ txSeqNum' = (txSeqNum + 1) % (MaxSeqNum + 1)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inPacketSeqNum, sessionState, localRole, lastRxSeqNum, errorReported>>

\* SOURCE: core_4.20.3.6
\* "Peers SHALL check to ensure that all received PAFTP packets properly increment the sender’s previous sequence number by 1. If this check fails, the peer SHALL close the PAFTP session and report an error to the application."
HandleReceivePacket ==
    /\ pendingInput = "ReceivePacket"
    /\ sessionState = "Active"
    /\ inPacketSeqNum \in 0..MaxSeqNum
    /\ IF inPacketSeqNum = (lastRxSeqNum + 1) % (MaxSeqNum + 1)
       THEN /\ sessionState' = sessionState
            /\ lastRxSeqNum' = inPacketSeqNum
            /\ errorReported' = errorReported
       ELSE /\ sessionState' = "Closed"
            /\ errorReported' = TRUE
            /\ lastRxSeqNum' = lastRxSeqNum
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inPacketSeqNum, localRole, txSeqNum>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleHandshakeAsCommissioner
    \/ HandleHandshakeAsDevice
    \/ HandleSendPacket
    \/ HandleReceivePacket

====