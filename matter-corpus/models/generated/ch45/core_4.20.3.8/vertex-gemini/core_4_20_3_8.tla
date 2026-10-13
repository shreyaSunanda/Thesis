---- MODULE core_4_20_3_8 ----
EXTENDS Naturals

\* PAFTP_ACK_TIMEOUT is the duration of the acknowledgement timeout interval.
\* MaxWindowSize limits the number of slots in a peer's PAFTP receive window.
\* MaxSeqNum limits the integer sequence numbers to keep the model state finite.
\* Peers is the set of communicating nodes.
\* NullSeq acts as a sentinel value for uninitialized sequence/acknowledgement fields.
CONSTANTS 
    Peers,
    MaxSeqNum,
    MaxWindowSize,
    NullSeq

VARIABLES 
    sessionState,   \* Peer -> "Handshake", "Active", "Error", "Closed"
    artStatus,      \* Peer -> "Stopped", "Running" (Acknowledgement-Received Timer)
    satStatus,      \* Peer -> "Stopped", "Running" (Send-Acknowledgement Timer)
    unackedSent,    \* Peer -> SET OF 0..MaxSeqNum (Packets sent but not yet acknowledged)
    lastSentSeq,    \* Peer -> NullSeq \cup 0..MaxSeqNum (Most recently sent sequence number)
    recvSet,        \* Peer -> SET OF 0..MaxSeqNum (All sequence numbers received on this session)
    largestRecvSeq, \* Peer -> NullSeq \cup 0..MaxSeqNum (Largest sequence number received)
    pendingAck,     \* Peer -> NullSeq \cup 0..MaxSeqNum (Current pending acknowledgement value)
    freeSlots,      \* Peer -> 0..MaxWindowSize (Free slots in the peer's receive window)
    messages        \* Set of messages currently in flight

Init == 
    /\ sessionState = [p \in Peers |-> "Handshake"]
    /\ artStatus = [p \in Peers |-> "Stopped"]
    /\ satStatus = [p \in Peers |-> "Stopped"]
    /\ unackedSent = [p \in Peers |-> {}]
    /\ lastSentSeq = [p \in Peers |-> NullSeq]
    /\ recvSet = [p \in Peers |-> {}]
    /\ largestRecvSeq = [p \in Peers |-> NullSeq]
    /\ pendingAck = [p \in Peers |-> NullSeq]
    /\ freeSlots = [p \in Peers |-> MaxWindowSize]
    /\ messages = {}

\* Helpers to construct messages
HandshakeMsg(sndr) == [type |-> "Handshake", sender |-> sndr, seq |-> 0, ack |-> NullSeq]
DataMsg(sndr, seqN, ackN) == [type |-> "Data", sender |-> sndr, seq |-> seqN, ack |-> ackN]
AckMsg(sndr, seqN, ackN) == [type |-> "Ack", sender |-> sndr, seq |-> seqN, ack |-> ackN]

\* Helper to calculate the sequence number of which all previous contiguous are already received
ContiguousRecv(p) == { c \in recvSet[p] : \A i \in 0..c : i \in recvSet[p] }
MaxContiguousRecv(p) == 
    IF ContiguousRecv(p) = {} THEN NullSeq 
    ELSE CHOOSE c \in ContiguousRecv(p) : \A d \in ContiguousRecv(p) : c >= d

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
ServerSendHandshake(p) ==
    /\ sessionState[p] = "Handshake"
    /\ sessionState' = [sessionState EXCEPT ![p] = "Active"]
    /\ lastSentSeq' = [lastSentSeq EXCEPT ![p] = 0]
    /\ unackedSent' = [unackedSent EXCEPT ![p] = {0}]
    /\ artStatus' = [artStatus EXCEPT ![p] = "Running"] \* Server starts ART when sending handshake response
    /\ messages' = messages \cup {HandshakeMsg(p)}
    /\ UNCHANGED <<satStatus, recvSet, largestRecvSeq, pendingAck, freeSlots>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
ClientReceiveHandshake(p) ==
    /\ sessionState[p] = "Handshake"
    /\ freeSlots[p] > 0
    /\ \E m \in messages :
           /\ m.type = "Handshake"
           /\ m.sender # p
           /\ sessionState' = [sessionState EXCEPT ![p] = "Active"]
           /\ recvSet' = [recvSet EXCEPT ![p] = recvSet[p] \cup {0}]
           /\ largestRecvSeq' = [largestRecvSeq EXCEPT ![p] = 0]
           /\ pendingAck' = [pendingAck EXCEPT ![p] = 0]
           /\ satStatus' = [satStatus EXCEPT ![p] = "Running"] \* Start send-acknowledgement timer
           /\ freeSlots' = [freeSlots EXCEPT ![p] = freeSlots[p] - 1]
           /\ messages' = messages \ {m}
    /\ UNCHANGED <<artStatus, unackedSent, lastSentSeq>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
SendPacket(p) ==
    /\ sessionState[p] = "Active"
    /\ lastSentSeq[p] = NullSeq \/ lastSentSeq[p] < MaxSeqNum
    /\ LET nextSeq == IF lastSentSeq[p] = NullSeq THEN 0 ELSE lastSentSeq[p] + 1
           \* Piggyback pending acknowledgement on the transmitted packet if timer not expired
           piggyAck == IF satStatus[p] = "Running" /\ pendingAck[p] # NullSeq 
                       THEN MaxContiguousRecv(p) 
                       ELSE NullSeq
           \* Restart SAT for any but the largest received, stop it if it is the largest received
           newSat == IF piggyAck # NullSeq /\ piggyAck = largestRecvSeq[p] THEN "Stopped"
                     ELSE IF piggyAck # NullSeq THEN "Running"
                     ELSE satStatus[p]
       IN
           /\ lastSentSeq' = [lastSentSeq EXCEPT ![p] = nextSeq]
           /\ unackedSent' = [unackedSent EXCEPT ![p] = unackedSent[p] \cup {nextSeq}]
           /\ artStatus' = [artStatus EXCEPT ![p] = "Running"] \* Start ART on sending any packet
           /\ messages' = messages \cup {DataMsg(p, nextSeq, piggyAck)}
           /\ satStatus' = [satStatus EXCEPT ![p] = newSat]
           /\ pendingAck' = IF piggyAck # NullSeq THEN [pendingAck EXCEPT ![p] = NullSeq] ELSE pendingAck
           /\ UNCHANGED <<sessionState, recvSet, largestRecvSeq, freeSlots>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
\* This covers scenarios where a stand-alone ack MAY be sent, SHALL be sent due to SAT expiry,
\* or SHALL be sent due to the receive window shrinking to two or fewer slots.
SendStandaloneAck(p) ==
    /\ sessionState[p] = "Active"
    /\ pendingAck[p] # NullSeq
    /\ lastSentSeq[p] = NullSeq \/ lastSentSeq[p] < MaxSeqNum
    /\ LET nextSeq == IF lastSentSeq[p] = NullSeq THEN 0 ELSE lastSentSeq[p] + 1
           ackVal == MaxContiguousRecv(p)
           newSat == IF ackVal = largestRecvSeq[p] THEN "Stopped" ELSE "Running"
       IN
           /\ lastSentSeq' = [lastSentSeq EXCEPT ![p] = nextSeq]
           /\ unackedSent' = [unackedSent EXCEPT ![p] = unackedSent[p] \cup {nextSeq}]
           /\ artStatus' = [artStatus EXCEPT ![p] = "Running"]
           /\ messages' = messages \cup {AckMsg(p, nextSeq, ackVal)}
           /\ satStatus' = [satStatus EXCEPT ![p] = newSat]
           /\ pendingAck' = [pendingAck EXCEPT ![p] = NullSeq]
           /\ UNCHANGED <<sessionState, recvSet, largestRecvSeq, freeSlots>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
ReceivePacket(p) ==
    /\ sessionState[p] = "Active"
    /\ freeSlots[p] > 0
    /\ \E m \in messages :
           /\ m.sender # p
           /\ LET isAckValid == (m.ack # NullSeq) /\ (m.ack \in unackedSent[p])
                  isAckInvalid == (m.ack # NullSeq) /\ (m.ack \notin unackedSent[p])
                  ackedSubset == IF m.ack = NullSeq THEN {} ELSE { s \in unackedSent[p] : s <= m.ack }
                  newLargest == IF largestRecvSeq[p] = NullSeq \/ m.seq > largestRecvSeq[p] THEN m.seq ELSE largestRecvSeq[p]
              IN
                  /\ freeSlots' = [freeSlots EXCEPT ![p] = freeSlots[p] - 1]
                  /\ pendingAck' = [pendingAck EXCEPT ![p] = m.seq]
                  /\ satStatus' = [satStatus EXCEPT ![p] = "Running"]
                  /\ recvSet' = [recvSet EXCEPT ![p] = recvSet[p] \cup {m.seq}]
                  /\ largestRecvSeq' = [largestRecvSeq EXCEPT ![p] = newLargest]
                  /\ IF isAckInvalid THEN
                         \* Invalid acknowledgement implies closing the session and reporting an error
                         /\ sessionState' = [sessionState EXCEPT ![p] = "Error"]
                         /\ artStatus' = [artStatus EXCEPT ![p] = "Stopped"]
                         /\ unackedSent' = unackedSent
                     ELSE IF isAckValid THEN
                         \* Valid cumulative acknowledgement
                         /\ unackedSent' = [unackedSent EXCEPT ![p] = unackedSent[p] \ ackedSubset]
                         \* Stop ART if acknowledging most recently sent packet, otherwise restart
                         /\ artStatus' = IF m.ack = lastSentSeq[p] THEN [artStatus EXCEPT ![p] = "Stopped"] 
                                         ELSE [artStatus EXCEPT ![p] = "Running"]
                         /\ sessionState' = sessionState
                     ELSE
                         /\ sessionState' = sessionState
                         /\ unackedSent' = unackedSent
                         /\ artStatus' = artStatus
           /\ messages' = messages \ {m}
    /\ UNCHANGED <<lastSentSeq>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
ExpireART(p) ==
    /\ sessionState[p] = "Active"
    /\ artStatus[p] = "Running"
    \* If a peer's ART expires, close the PAFTP session and report an error
    /\ sessionState' = [sessionState EXCEPT ![p] = "Error"]
    /\ artStatus' = [artStatus EXCEPT ![p] = "Stopped"]
    /\ UNCHANGED <<satStatus, unackedSent, lastSentSeq, recvSet, largestRecvSeq, pendingAck, freeSlots, messages>>

\* TODO: unspecified - The specification describes window slots being consumed and checking if they shrink
\* to 2 or fewer, which necessitates application layer reads to free the slots. The specific interface
\* for freeing slots is omitted, so this is modeled as an abstract transition.
ApplicationReadBuffer(p) ==
    /\ sessionState[p] = "Active"
    /\ freeSlots[p] < MaxWindowSize
    /\ freeSlots' = [freeSlots EXCEPT ![p] = freeSlots[p] + 1]
    /\ UNCHANGED <<sessionState, artStatus, satStatus, unackedSent, lastSentSeq, recvSet, largestRecvSeq, pendingAck, messages>>

Next ==
    \/ \E p \in Peers : ServerSendHandshake(p)
    \/ \E p \in Peers : ClientReceiveHandshake(p)
    \/ \E p \in Peers : SendPacket(p)
    \/ \E p \in Peers : SendStandaloneAck(p)
    \/ \E p \in Peers : ReceivePacket(p)
    \/ \E p \in Peers : ExpireART(p)
    \/ \E p \in Peers : ApplicationReadBuffer(p)

====