---- MODULE core_4_20_3_7 ----
EXTENDS Naturals

\* The negotiated maximum window size established as part of the PAFTP session handshake.
\* Largest allowed by the spec is 255.
CONSTANTS MaxWindowSize

VARIABLES 
    remoteWindowCounter,
    ownWindowCounter,
    pendingPackets,
    inFlightPackets,
    inFlightAcks

Peers == {"Commissioner", "CommissionableDevice"}

OtherPeer(p) == IF p = "Commissioner" THEN "CommissionableDevice" ELSE "Commissioner"

\* SOURCE: core_4.20.3.7 Receive Windows
Init ==
    \* "A Commissionable Device SHALL initialize its counter for the Commissioner's receive window size at (negotiated maximum window size - 1)."
    \* "A Commissioner SHALL initialize its counter for the server's receive window at the negotiated maximum window size."
    /\ remoteWindowCounter = [p \in Peers |-> IF p = "Commissioner" THEN MaxWindowSize ELSE MaxWindowSize - 1]
    /\ ownWindowCounter = [p \in Peers |-> 0]
    /\ pendingPackets = [p \in Peers |-> 0]
    /\ inFlightPackets = [p \in Peers |-> 0]
    /\ inFlightAcks = [p \in Peers |-> 0]

\* SOURCE: core_4.20.3.7 Receive Windows
QueuePacket(p) ==
    \* TODO: unspecified - Spec implies an upper layer queues packets to be sent.
    /\ pendingPackets' = [pendingPackets EXCEPT ![p] = @ + 1]
    /\ UNCHANGED <<remoteWindowCounter, ownWindowCounter, inFlightPackets, inFlightAcks>>

\* SOURCE: core_4.20.3.7 Receive Windows
SendPacket(p) ==
    /\ pendingPackets[p] > 0
    \* "If a local peer's counter for a remote peer's receive window is zero, the window SHALL be considered closed, and the local peer SHALL NOT send packets"
    /\ remoteWindowCounter[p] > 0
    \* "A local peer SHALL also not send packets if the remote peer's receive window has one slot open and the local peer does not have a pending packet acknowledgement."
    /\ (remoteWindowCounter[p] = 1) => (ownWindowCounter[p] > 0)
    \* "Each peer SHALL decrement this counter when it sends a packet"
    /\ remoteWindowCounter' = [remoteWindowCounter EXCEPT ![p] = @ - 1]
    /\ pendingPackets' = [pendingPackets EXCEPT ![p] = @ - 1]
    /\ inFlightPackets' = [inFlightPackets EXCEPT ![p] = @ + 1]
    /\ UNCHANGED <<ownWindowCounter, inFlightAcks>>

\* SOURCE: core_4.20.3.7 Receive Windows
ReceivePacket(p) ==
    /\ inFlightPackets[OtherPeer(p)] > 0
    /\ inFlightPackets' = [inFlightPackets EXCEPT ![OtherPeer(p)] = @ - 1]
    \* "Both peers SHALL also keep a counter of their own receive window size based on the sequence number difference between the last packet they received and the last packet they acknowledged."
    /\ ownWindowCounter' = [ownWindowCounter EXCEPT ![p] = @ + 1]
    /\ UNCHANGED <<remoteWindowCounter, pendingPackets, inFlightAcks>>

\* SOURCE: core_4.20.3.7 Receive Windows
SendAck(p) ==
    \* "Both peers SHALL also keep a counter of their own receive window size ... to proactively send early packet acknowledgements"
    /\ ownWindowCounter[p] > 0
    /\ inFlightAcks' = [inFlightAcks EXCEPT ![p] = @ + ownWindowCounter[p]]
    /\ ownWindowCounter' = [ownWindowCounter EXCEPT ![p] = 0]
    /\ UNCHANGED <<remoteWindowCounter, pendingPackets, inFlightPackets>>

\* SOURCE: core_4.20.3.7 Receive Windows
ReceiveAck(p) ==
    /\ inFlightAcks[OtherPeer(p)] > 0
    /\ inFlightAcks' = [inFlightAcks EXCEPT ![OtherPeer(p)] = @ - 1]
    \* "... and increment this counter when a sent packet is acknowledged."
    /\ remoteWindowCounter' = [remoteWindowCounter EXCEPT ![p] = @ + 1]
    /\ UNCHANGED <<ownWindowCounter, pendingPackets, inFlightPackets>>

Next == 
    \/ \E p \in Peers : QueuePacket(p)
    \/ \E p \in Peers : SendPacket(p)
    \/ \E p \in Peers : ReceivePacket(p)
    \/ \E p \in Peers : SendAck(p)
    \/ \E p \in Peers : ReceiveAck(p)

====