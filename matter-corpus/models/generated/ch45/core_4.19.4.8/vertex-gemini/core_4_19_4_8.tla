---- MODULE core_4_19_4_8 ----
EXTENDS Naturals

\* Declare EVERY fixed value the spec text mentions (timeouts, limits, thresholds,
\* fabric indices, etc.) here. Give each one a short comment saying what it is.
CONSTANTS 
    \* Represents the two peers communicating in a BTP session.
    Client, 
    Server,
    \* Maximum sequence number to bound the state space for model checking.
    \* Real value per spec: unsigned 8-bit integer (255).
    MaxSeqNum,
    \* Maximum size of the BTP receive window to bound the state space.
    MaxWindow,
    \* Sentinel value representing no acknowledgement or missing value.
    Null

VARIABLES 
    \* Map of Peer -> "Handshake" | "Active" | "Closed"
    status,
    \* Map of Peer -> Next sequence number to send
    nextSeq,
    \* Map of Peer -> Set of outstanding, unacknowledged sent sequence numbers
    unackedSent,
    \* Map of Peer -> "Stopped" | "Running"
    ackRecvTimer,
    \* Map of Peer -> "Stopped" | "Running"
    sendAckTimer,
    \* Map of Peer -> Sequence number pending acknowledgement (or Null)
    pendingAck,
    \* Map of Peer -> Number of available slots in the receive window
    freeSlots,
    \* Map of Peer -> Set of sequence numbers already received
    received,
    \* Set of all messages transmitted on the network
    network

Peers == {Client, Server}

Init == 
    /\ status = [p \in Peers |-> "Handshake"]
    /\ nextSeq = [p \in Peers |-> 0]
    /\ unackedSent = [p \in Peers |-> {}]
    /\ ackRecvTimer = [p \in Peers |-> "Stopped"]
    /\ sendAckTimer = [p \in Peers |-> "Stopped"]
    /\ pendingAck = [p \in Peers |-> Null]
    /\ freeSlots = [p \in Peers |-> MaxWindow]
    /\ received = [p \in Peers |-> {}]
    /\ network = {}

\* Helper: Encapsulates state updates for sending any BTP packet (with or without data).
SendPacketUpdates(p) ==
    /\ network' = network \cup {[type |-> "Packet", sender |-> p, seq |-> nextSeq[p], ack |-> pendingAck[p]]}
    /\ nextSeq' = [nextSeq EXCEPT ![p] = @ + 1]
    /\ unackedSent' = [unackedSent EXCEPT ![p] = @ \cup {nextSeq[p]}]
    /\ ackRecvTimer' = [ackRecvTimer EXCEPT ![p] = "Running"]
    /\ sendAckTimer' = [sendAckTimer EXCEPT ![p] = "Stopped"]
    /\ pendingAck' = [pendingAck EXCEPT ![p] = Null]
    /\ UNCHANGED <<status, freeSlots, received>>


\* SOURCE: core_4.19.4.8 Packet Acknowledgements
\* "Because the server’s handshake response bears an implicit BTP sequence number of zero, a server SHALL start its acknowledgement-received timer when it sends a handshake response."
ServerSendHandshakeResponse ==
    /\ status[Server] = "Handshake"
    /\ network' = network \cup {[type |-> "HandshakeResponse", sender |-> Server, seq |-> 0, ack |-> Null]}
    /\ ackRecvTimer' = [ackRecvTimer EXCEPT ![Server] = "Running"]
    /\ unackedSent' = [unackedSent EXCEPT ![Server] = {0}]
    /\ nextSeq' = [nextSeq EXCEPT ![Server] = 1]
    /\ status' = [status EXCEPT ![Server] = "Active"]
    /\ UNCHANGED <<sendAckTimer, pendingAck, freeSlots, received>>


\* SOURCE: core_4.19.4.8 Packet Acknowledgements
\* "Because the server’s handshake response bears an implicit BTP sequence number of zero, a client SHALL set its pending acknowledgement value to zero and start its send-acknowledgement timer when it receives the server’s a handshake response."
ClientReceiveHandshakeResponse ==
    /\ status[Client] = "Handshake"
    /\ \E msg \in network : msg.type = "HandshakeResponse"
    /\ status' = [status EXCEPT ![Client] = "Active"]
    /\ pendingAck' = [pendingAck EXCEPT ![Client] = 0]
    /\ sendAckTimer' = [sendAckTimer EXCEPT ![Client] = "Running"]
    /\ received' = [received EXCEPT ![Client] = {0}]
    /\ freeSlots' = [freeSlots EXCEPT ![Client] = @ - 1]
    /\ UNCHANGED <<nextSeq, unackedSent, ackRecvTimer, network>>


\* SOURCE: core_4.19.4.8 Packet Acknowledgements
\* "When a peer sends any BTP packet, it SHALL start this timer if it is not already running."
\* "If the peer sends any packet before this timer expires, it SHALL piggyback any pending acknowledgement on the transmitted packet and stop the send-acknowledgement timer."
PeerSendData(p) ==
    /\ status[p] = "Active"
    /\ nextSeq[p] <= MaxSeqNum
    /\ SendPacketUpdates(p)


\* SOURCE: core_4.19.4.8 Packet Acknowledgements
\* "If this timer expires and the peer has a pending acknowledgement, the peer SHALL immediately send that acknowledgement."
PeerSendAckTimerExpires(p) ==
    /\ status[p] = "Active"
    /\ sendAckTimer[p] = "Running"
    /\ pendingAck[p] # Null
    /\ nextSeq[p] <= MaxSeqNum
    /\ SendPacketUpdates(p)


\* SOURCE: core_4.19.4.8 Packet Acknowledgements
\* "If a peer detects that its receive window has shrunk to two or fewer free slots, it SHALL immediately send any pending acknowledgement as a stand-alone BTP packet."
PeerWindowLowSendAck(p) ==
    /\ status[p] = "Active"
    /\ freeSlots[p] <= 2
    /\ pendingAck[p] # Null
    /\ nextSeq[p] <= MaxSeqNum
    /\ SendPacketUpdates(p)


\* SOURCE: core_4.19.4.8 Packet Acknowledgements
\* "When it receives any BTP packet, a peer SHALL record the packet’s sequence number as the corresponding BTP session’s pending acknowledgement value and start the send-acknowledgement timer if it is not already running."
\* "An acknowledgement is invalid if the acknowledged sequence number does not correspond to an outstanding, unacknowledged BTP packet sequence number... If a peer receives an invalid acknowledgement, the peer SHALL close the BTP session..."
\* "A peer SHALL restart its acknowledgement-received timer when a valid acknowledgement is received for any but its most recently sent unacknowledged packet. A peer SHALL stop its acknowledgement-received timer if it receives an acknowledgement for its most recently sent unacknowledged packet."
\* TODO: unspecified - sequence number wrapping behavior is abstracted out; model uses bounded increasing sequences.
PeerReceivePacket(p) ==
    /\ status[p] = "Active"
    /\ \E msg \in network :
        /\ msg.type = "Packet"
        /\ msg.sender # p
        /\ msg.seq \notin received[p]
        /\ IF msg.ack # Null /\ msg.ack \notin unackedSent[p] THEN
               /\ status' = [status EXCEPT ![p] = "Closed"]
               /\ UNCHANGED <<nextSeq, unackedSent, ackRecvTimer, sendAckTimer, pendingAck, freeSlots, received, network>>
           ELSE
               /\ received' = [received EXCEPT ![p] = @ \cup {msg.seq}]
               /\ freeSlots' = [freeSlots EXCEPT ![p] = @ - 1]
               /\ pendingAck' = [pendingAck EXCEPT ![p] = msg.seq]
               /\ sendAckTimer' = [sendAckTimer EXCEPT ![p] = "Running"]
               /\ IF msg.ack # Null THEN
                      /\ unackedSent' = [unackedSent EXCEPT ![p] = {s \in @ : s > msg.ack}]
                      /\ ackRecvTimer' = [ackRecvTimer EXCEPT ![p] = IF msg.ack = nextSeq[p] - 1 THEN "Stopped" ELSE "Running"]
                  ELSE
                      /\ UNCHANGED <<unackedSent, ackRecvTimer>>
               /\ UNCHANGED <<status, nextSeq, network>>


\* SOURCE: core_4.19.4.8 Packet Acknowledgements
\* "If a peer’s acknowledgement-received timer expires, or if a peer receives an invalid acknowledgement, the peer SHALL close the BTP session and report an error to the application."
PeerExpireAckRecvTimer(p) ==
    /\ status[p] = "Active"
    /\ ackRecvTimer[p] = "Running"
    /\ status' = [status EXCEPT ![p] = "Closed"]
    /\ ackRecvTimer' = [ackRecvTimer EXCEPT ![p] = "Stopped"]
    /\ UNCHANGED <<nextSeq, unackedSent, sendAckTimer, pendingAck, freeSlots, received, network>>


\* Abstraction: The application consumes data, which frees up BTP receive window slots.
AppConsumeData(p) ==
    /\ status[p] = "Active"
    /\ freeSlots[p] < MaxWindow
    /\ freeSlots' = [freeSlots EXCEPT ![p] = @ + 1]
    /\ UNCHANGED <<status, nextSeq, unackedSent, ackRecvTimer, sendAckTimer, pendingAck, received, network>>


Next == 
    \/ ServerSendHandshakeResponse
    \/ ClientReceiveHandshakeResponse
    \/ \E p \in Peers :
        \/ PeerSendData(p)
        \/ PeerSendAckTimerExpires(p)
        \/ PeerWindowLowSendAck(p)
        \/ PeerReceivePacket(p)
        \/ PeerExpireAckRecvTimer(p)
        \/ AppConsumeData(p)

====