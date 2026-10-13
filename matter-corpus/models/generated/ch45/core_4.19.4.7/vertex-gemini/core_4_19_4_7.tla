---- MODULE core_4_19_4_7 ----
EXTENDS Naturals, Sequences

\* A mapping from Peers to their negotiated maximum receive window size (1..255).
\* The maximum window size SHALL be established for both peers as part of the BTP session handshake.
CONSTANTS MaxWindowSize

VARIABLES
    remoteWindowCounter, \* Counter to reflect the current size of the remote peer's receive window
    ownWindowDiff,       \* Counter of own receive window size based on seq num diff of received vs acked
    pendingAckTx,        \* Boolean tracking if the peer needs to send a packet acknowledgement
    pendingTx,           \* Packets waiting to be sent
    channel              \* In-flight BTP packets between peers

Peers == {"Client", "Server"}

Other(p) == IF p = "Client" THEN "Server" ELSE "Client"

Init ==
    \* SOURCE: core_4.19.4.7
    \* "Because the server's handshake response bears an implicit BTP sequence number of zero, a server SHALL initialize its counter for the client's receive window size at (negotiated maximum window size - 1). A client SHALL initialize its counter for the server's receive window at the negotiated maximum window size."
    /\ remoteWindowCounter = [p \in Peers |-> IF p = "Client" THEN MaxWindowSize["Server"] ELSE MaxWindowSize["Client"] - 1]
    \* TODO: unspecified - explicit initialization of own receive window counter and pending acks considering the implicit handshake sequence number
    /\ ownWindowDiff = [p \in Peers |-> 0]
    /\ pendingAckTx = [p \in Peers |-> FALSE]
    /\ pendingTx = [p \in Peers |-> 0]
    /\ channel = [p \in Peers |-> <<>>]

\* TODO: unspecified - how upper layers provide BTP packets to be sent
EnqueueData(p) ==
    /\ pendingTx' = [pendingTx EXCEPT ![p] = @ + 1]
    /\ UNCHANGED <<remoteWindowCounter, ownWindowDiff, pendingAckTx, channel>>

\* SOURCE: core_4.19.4.7
\* "Each peer SHALL decrement this counter when it sends a packet..."
\* "If a local peer's counter for a remote peer's receive window is zero, the window SHALL be considered closed, and the local peer SHALL NOT send packets until the window reopens..."
\* "When a closed window reopens, a local peer SHALL immediately resume any pending BTP packet transmission."
\* "A local peer SHALL also not send packets if the remote peer's receive window has one slot open and the local peer does not have a pending packet acknowledgement."
SendPacket(p) ==
    /\ pendingTx[p] > 0
    /\ remoteWindowCounter[p] > 0
    /\ remoteWindowCounter[p] = 1 => pendingAckTx[p]
    /\ LET piggybackAck == pendingAckTx[p]
           sentAckCount == IF piggybackAck THEN ownWindowDiff[p] ELSE 0
           msg == [type |-> "DATA", ackCount |-> sentAckCount]
       IN /\ remoteWindowCounter' = [remoteWindowCounter EXCEPT ![p] = @ - 1]
          /\ pendingTx' = [pendingTx EXCEPT ![p] = @ - 1]
          /\ channel' = [channel EXCEPT ![Other(p)] = Append(@, msg)]
          /\ IF piggybackAck
             THEN /\ ownWindowDiff' = [ownWindowDiff EXCEPT ![p] = 0]
                  /\ pendingAckTx' = [pendingAckTx EXCEPT ![p] = FALSE]
             ELSE /\ ownWindowDiff' = ownWindowDiff
                  /\ pendingAckTx' = pendingAckTx

\* SOURCE: core_4.19.4.7
\* "Both peers SHALL also keep a counter of their own receive window size... This counter is used to proactively send early packet acknowledgements when a peer's own receive window is about to close."
SendStandaloneAck(p) ==
    /\ pendingAckTx[p]
    /\ LET sentAckCount == ownWindowDiff[p]
           msg == [type |-> "ACK", ackCount |-> sentAckCount]
       IN /\ channel' = [channel EXCEPT ![Other(p)] = Append(@, msg)]
          /\ ownWindowDiff' = [ownWindowDiff EXCEPT ![p] = 0]
          /\ pendingAckTx' = [pendingAckTx EXCEPT ![p] = FALSE]
    /\ UNCHANGED <<remoteWindowCounter, pendingTx>>

\* SOURCE: core_4.19.4.7
\* "Both peers SHALL maintain a counter to reflect the current size of the remote peer's receive window... and increment this counter when a sent packet is acknowledged."
\* "Both peers SHALL also keep a counter of their own receive window size based on the sequence number difference between the last packet they received and the last packet they acknowledged."
ReceiveMessage(p) ==
    /\ Len(channel[p]) > 0
    /\ LET msg == Head(channel[p])
       IN /\ channel' = [channel EXCEPT ![p] = Tail(@)]
          /\ remoteWindowCounter' = [remoteWindowCounter EXCEPT ![p] = @ + msg.ackCount]
          /\ IF msg.type = "DATA"
             THEN /\ ownWindowDiff' = [ownWindowDiff EXCEPT ![p] = @ + 1]
                  /\ pendingAckTx' = [pendingAckTx EXCEPT ![p] = TRUE]
             ELSE /\ ownWindowDiff' = ownWindowDiff
                  /\ pendingAckTx' = pendingAckTx
    /\ UNCHANGED pendingTx

Next ==
    \/ \E p \in Peers : EnqueueData(p)
    \/ \E p \in Peers : SendPacket(p)
    \/ \E p \in Peers : SendStandaloneAck(p)
    \/ \E p \in Peers : ReceiveMessage(p)

====