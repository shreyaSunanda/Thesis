---- MODULE core_4_20_3_8 ----
EXTENDS Naturals

\* Timeout interval for packet acknowledgements
CONSTANTS PAFTP_ACK_TIMEOUT

\* Maximum sequence number, to bound the state space.
CONSTANTS MaxSeqNum

\* Size of the receive window, to bound free slots.
CONSTANTS ReceiveWindowSize

\* Required constants for inputs
CONSTANTS NoInput, Inputs

\* A sentinel value representing no sequence number.
CONSTANTS NullSeqNum

VARIABLES
    pendingInput,
    sessionState,         \* "CLOSED" or "ESTABLISHED"
    ackRxTimer,           \* "STOPPED" or "RUNNING"
    sendAckTimer,         \* "STOPPED" or "RUNNING"
    unackedSent,          \* Set of sequence numbers sent but not yet acknowledged
    lastSentSeq,          \* The sequence number of the most recently sent packet
    unackedReceived,      \* Set of received sequence numbers that have not been acknowledged by us
    receivedSet,          \* The full set of all sequence numbers received so far
    nextSeqToSend,        \* Counter for next outgoing packet sequence number
    freeSlots             \* Number of free slots in the receive window

SeqNums == 0..MaxSeqNum

\* Helper to find the maximum element in a finite non-empty set of naturals
Max(S) == CHOOSE x \in S : \A y \in S : x >= y

\* Helper to determine the sequence number of which all previous contiguous are already received
HighestContiguousRx(recvSet) ==
    IF 0 \notin recvSet THEN NullSeqNum
    ELSE Max({x \in recvSet : \A y \in 0..x : y \in recvSet})

Init ==
    /\ pendingInput = NoInput
    /\ sessionState = "CLOSED"
    /\ ackRxTimer = "STOPPED"
    /\ sendAckTimer = "STOPPED"
    /\ unackedSent = {}
    /\ lastSentSeq = NullSeqNum
    /\ unackedReceived = {}
    /\ receivedSet = {}
    /\ nextSeqToSend = 0
    /\ freeSlots = ReceiveWindowSize

\* SOURCE: core_4.20.3.8 Mandatory Input Shape
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<sessionState, ackRxTimer, sendAckTimer, unackedSent, lastSentSeq, unackedReceived, receivedSet, nextSeqToSend, freeSlots>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
\* "When a peer sends any PAFTP packet, it SHALL start this timer if it is not already running."
\* "If the peer sends any packet before this timer expires, it SHALL piggyback any pending acknowledgement..."
SendPacket ==
    /\ pendingInput = [type |-> "SendPacket"]
    /\ sessionState = "ESTABLISHED"
    /\ nextSeqToSend <= MaxSeqNum
    /\ LET seq == nextSeqToSend
           hasPending == (unackedReceived # {})
           ackNum == HighestContiguousRx(receivedSet)
           largestUnacked == Max(unackedReceived)
       IN
       /\ nextSeqToSend' = seq + 1
       /\ lastSentSeq' = seq
       /\ unackedSent' = unackedSent \cup {seq}
       /\ ackRxTimer' = "RUNNING"
       /\ IF hasPending THEN
              \* TODO: unspecified - what acknowledgement number to use if sequence 0 is missing but a packet is received, causing the timer to start and fire.
              IF ackNum = NullSeqNum THEN
                  /\ unackedReceived' = unackedReceived
                  /\ sendAckTimer' = "RUNNING"
              ELSE
                  /\ unackedReceived' = {x \in unackedReceived : x > ackNum}
                  /\ IF ackNum = largestUnacked THEN
                         sendAckTimer' = "STOPPED"
                     ELSE
                         sendAckTimer' = "RUNNING"
          ELSE
              /\ UNCHANGED <<unackedReceived, sendAckTimer>>
       /\ pendingInput' = NoInput
       /\ UNCHANGED <<sessionState, receivedSet, freeSlots>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
\* "When it receives any PAFTP packet, a peer SHALL record the packet’s sequence number... and start the send-acknowledgement timer"
\* "A peer SHALL restart its acknowledgement-received timer when a valid acknowledgement is received for any but its most recently sent"
\* "A peer SHALL stop its acknowledgement-received timer if it receives an acknowledgement for its most recently sent unacknowledged packet"
\* "If a peer receives an invalid acknowledgement, the peer SHALL close the PAFTP session and report an error"
ReceivePacket ==
    /\ \E seq \in SeqNums, hasAck \in BOOLEAN, ackSeq \in SeqNums :
           /\ pendingInput = [type |-> "ReceivePacket", seq |-> seq, hasAck |-> hasAck, ack |-> ackSeq]
           /\ sessionState = "ESTABLISHED"
           /\ receivedSet' = receivedSet \cup {seq}
           /\ unackedReceived' = unackedReceived \cup {seq}
           /\ freeSlots' = IF freeSlots > 0 THEN freeSlots - 1 ELSE 0
           /\ IF hasAck /\ ackSeq \notin unackedSent THEN
                  /\ sessionState' = "CLOSED"
                  /\ ackRxTimer' = "STOPPED"
                  /\ sendAckTimer' = "STOPPED"
                  /\ unackedSent' = {}
              ELSE
                  /\ sendAckTimer' = "RUNNING"
                  /\ IF hasAck THEN
                         /\ unackedSent' = {x \in unackedSent : x > ackSeq}
                         /\ IF ackSeq = lastSentSeq THEN
                                ackRxTimer' = "STOPPED"
                            ELSE
                                ackRxTimer' = "RUNNING"
                         /\ UNCHANGED <<sessionState>>
                     ELSE
                         UNCHANGED <<sessionState, unackedSent, ackRxTimer>>
           /\ pendingInput' = NoInput
           /\ UNCHANGED <<nextSeqToSend, lastSentSeq>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
\* "Because the server’s handshake response bears an implicit PAFTP sequence number of zero, a server SHALL start its acknowledgement-received timer when it sends a handshake response."
SendHandshakeResponse ==
    /\ pendingInput = [type |-> "SendHandshakeResponse"]
    /\ sessionState = "CLOSED"
    /\ sessionState' = "ESTABLISHED"
    /\ lastSentSeq' = 0
    /\ unackedSent' = {0}
    /\ nextSeqToSend' = 1
    /\ ackRxTimer' = "RUNNING"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sendAckTimer, unackedReceived, receivedSet, freeSlots>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
\* "Because the server’s handshake response bears an implicit PAFTP sequence number of zero, a client SHALL set its pending acknowledgement value to zero and start its send-acknowledgement timer when it receives the server’s a handshake response."
ReceiveHandshakeResponse ==
    /\ pendingInput = [type |-> "ReceiveHandshakeResponse"]
    /\ sessionState = "CLOSED"
    /\ sessionState' = "ESTABLISHED"
    /\ receivedSet' = {0}
    /\ unackedReceived' = {0}
    /\ sendAckTimer' = "RUNNING"
    /\ freeSlots' = IF freeSlots > 0 THEN freeSlots - 1 ELSE 0
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<ackRxTimer, unackedSent, lastSentSeq, nextSeqToSend>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
\* Helper defining the behavior of sending a standalone pending acknowledgement.
\* "acknowledgement number SHALL be the PAFTP packet sequence number of which all previous contiguous PAFTP packet sequence numbers are already received."
SendPendingAckAction ==
    /\ nextSeqToSend <= MaxSeqNum
    /\ LET seq == nextSeqToSend
           ackNum == HighestContiguousRx(receivedSet)
           largestUnacked == Max(unackedReceived)
       IN
       /\ nextSeqToSend' = seq + 1
       /\ lastSentSeq' = seq
       /\ unackedSent' = unackedSent \cup {seq}
       /\ ackRxTimer' = "RUNNING"
       /\ IF ackNum = NullSeqNum THEN
              /\ unackedReceived' = unackedReceived
              /\ sendAckTimer' = "RUNNING"
          ELSE
              /\ unackedReceived' = {x \in unackedReceived : x > ackNum}
              /\ IF ackNum = largestUnacked THEN
                     sendAckTimer' = "STOPPED"
                 ELSE
                     sendAckTimer' = "RUNNING"

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
\* "If a peer’s acknowledgement-received timer expires... the peer SHALL close the PAFTP session and report an error to the application."
AckReceivedTimerExpires ==
    /\ sessionState = "ESTABLISHED"
    /\ ackRxTimer = "RUNNING"
    /\ sessionState' = "CLOSED"
    /\ ackRxTimer' = "STOPPED"
    /\ sendAckTimer' = "STOPPED"
    /\ UNCHANGED <<pendingInput, unackedSent, lastSentSeq, unackedReceived, nextSeqToSend, freeSlots, receivedSet>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
\* "If this timer expires and the peer has a pending acknowledgement, the peer SHALL immediately send that acknowledgement"
SendAckTimerExpires ==
    /\ sessionState = "ESTABLISHED"
    /\ sendAckTimer = "RUNNING"
    /\ unackedReceived # {}
    /\ SendPendingAckAction
    /\ UNCHANGED <<pendingInput, sessionState, receivedSet, freeSlots>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
\* "If this timer is not expired, the peer MAY send a pending acknowledgement as a stand-alone PAFTP packet"
SendStandAloneAck ==
    /\ sessionState = "ESTABLISHED"
    /\ sendAckTimer = "RUNNING"
    /\ unackedReceived # {}
    /\ SendPendingAckAction
    /\ UNCHANGED <<pendingInput, sessionState, receivedSet, freeSlots>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
\* "If a peer detects that its receive window has shrunk to two or fewer free slots, it SHALL immediately send any pending acknowledgement as a stand-alone PAFTP packet"
HandleWindowShrinks ==
    /\ sessionState = "ESTABLISHED"
    /\ freeSlots <= 2
    /\ unackedReceived # {}
    /\ SendPendingAckAction
    /\ UNCHANGED <<pendingInput, sessionState, receivedSet, freeSlots>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ SendPacket
    \/ ReceivePacket
    \/ SendHandshakeResponse
    \/ ReceiveHandshakeResponse
    \/ AckReceivedTimerExpires
    \/ SendAckTimerExpires
    \/ SendStandAloneAck
    \/ HandleWindowShrinks

====