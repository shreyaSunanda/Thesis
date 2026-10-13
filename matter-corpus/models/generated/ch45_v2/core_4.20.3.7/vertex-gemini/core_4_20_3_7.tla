---- MODULE core_4_20_3_7 ----
EXTENDS Naturals

\* The roles defined for PAFTP sessions in this context.
CONSTANTS Commissioner, CommissionableDevice

\* The maximum receive window size negotiated during the handshake.
\* SPEC NOTE: "To prevent sequence number wrap-around, the largest maximum window size any peer may support is 255."
CONSTANTS MaxWindowSize

\* Maximum number of packets a peer can queue to send (finite bound for model checking).
CONSTANTS MaxQueueSize

\* Mandatory input constants per rule 4a.
CONSTANTS NoInput, Inputs

VARIABLES 
    pendingInput,
    sessionActive,
    remoteWindow,     \* Each peer's counter reflecting the remote peer's receive window capacity
    localWindow,      \* Each peer's counter reflecting its own receive window capacity
    pendingPackets,   \* Count of packets waiting to be sent by each peer
    pendingAck        \* Boolean indicating if a peer has received a packet and needs to send an ack

Peers == {Commissioner, CommissionableDevice}

Init == 
    /\ pendingInput = NoInput
    /\ sessionActive = FALSE
    /\ remoteWindow = [p \in Peers |-> 0]
    /\ localWindow = [p \in Peers |-> 0]
    /\ pendingPackets = [p \in Peers |-> 0]
    /\ pendingAck = [p \in Peers |-> FALSE]

\* Helper definition to safely format the specific initialization requirements
\* SOURCE: core_4.20.3.7 "A Commissionable Device SHALL initialize its counter for the Commissioner’s receive window size at (negotiated maximum window size - 1). A Commissioner SHALL initialize its counter for the server’s receive window at the negotiated maximum window size."
InitRemoteWindow == 
    [Commissioner |-> MaxWindowSize, CommissionableDevice |-> MaxWindowSize - 1]

\* -------------------------------------------------------------------------
\* ENVIRONMENT INPUT RECEPTION
\* -------------------------------------------------------------------------
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<sessionActive, remoteWindow, localWindow, pendingPackets, pendingAck>>

\* -------------------------------------------------------------------------
\* EVENT HANDLERS
\* -------------------------------------------------------------------------

\* SOURCE: core_4.20.3.7 "A Commissionable Device SHALL initialize its counter... A Commissioner SHALL initialize its counter..."
HandleEstablishSession ==
    /\ pendingInput = [type |-> "EstablishSession"]
    /\ sessionActive = FALSE
    /\ sessionActive' = TRUE
    /\ remoteWindow' = InitRemoteWindow
    \* Initially, zero packets have been received, so difference is 0 and local capacity is full.
    /\ localWindow' = [p \in Peers |-> MaxWindowSize]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<pendingPackets, pendingAck>>

\* Models the upper layer queuing a packet for transmission.
HandleQueuePacket ==
    /\ \E p \in Peers :
        /\ pendingInput = [type |-> "QueuePacket", peer |-> p]
        /\ pendingPackets[p] < MaxQueueSize
        /\ pendingPackets' = [pendingPackets EXCEPT ![p] = @ + 1]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionActive, remoteWindow, localWindow, pendingAck>>

\* SOURCE: core_4.20.3.7 "Both peers SHALL also keep a counter of their own receive window size based on the sequence number difference..."
\* (Receiving a packet decreases available local window capacity).
HandleReceivePacket ==
    /\ \E p \in Peers :
        /\ pendingInput = [type |-> "ReceivePacket", peer |-> p]
        /\ sessionActive = TRUE
        /\ IF localWindow[p] > 0
           THEN /\ localWindow' = [localWindow EXCEPT ![p] = @ - 1]
                /\ pendingAck' = [pendingAck EXCEPT ![p] = TRUE]
           ELSE /\ UNCHANGED <<localWindow, pendingAck>> \* If no space, packet is lost per spec text
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionActive, remoteWindow, pendingPackets>>

\* SOURCE: core_4.20.3.7 "increment this counter when a sent packet is acknowledged"
HandleReceiveAck ==
    /\ \E p \in Peers :
        /\ pendingInput = [type |-> "ReceiveAck", peer |-> p]
        /\ sessionActive = TRUE
        /\ remoteWindow' = [remoteWindow EXCEPT ![p] = IF @ < MaxWindowSize THEN @ + 1 ELSE @]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionActive, localWindow, pendingPackets, pendingAck>>

\* -------------------------------------------------------------------------
\* SPONTANEOUS PROTOCOL ACTIONS
\* -------------------------------------------------------------------------

\* SOURCE: core_4.20.3.7 "Each peer SHALL decrement this counter when it sends a packet"
\* SOURCE: core_4.20.3.7 "If a local peer’s counter for a remote peer’s receive window is zero, the window SHALL be considered closed, and the local peer SHALL NOT send packets until the window reopens (is incremented above zero)."
\* SOURCE: core_4.20.3.7 "When a closed window reopens, a local peer SHALL immediately resume any pending PAFTP packet transmission."
\* SOURCE: core_4.20.3.7 "A local peer SHALL also not send packets if the remote peer’s receive window has one slot open and the local peer does not have a pending packet acknowledgement."
SendPacket(p) ==
    /\ pendingInput = NoInput
    /\ sessionActive = TRUE
    /\ pendingPackets[p] > 0
    /\ remoteWindow[p] > 0
    /\ ~(remoteWindow[p] = 1 /\ pendingAck[p] = FALSE)
    /\ pendingPackets' = [pendingPackets EXCEPT ![p] = @ - 1]
    /\ remoteWindow' = [remoteWindow EXCEPT ![p] = @ - 1]
    /\ UNCHANGED <<pendingInput, sessionActive, localWindow, pendingAck>>

\* SOURCE: core_4.20.3.7 "This counter is used to proactively send early packet acknowledgements when a peer’s own receive window is about to close."
\* (Sending an ack acknowledges all received packets, resetting the received vs acked sequence diff to 0, which restores the full local window size).
SendAck(p) ==
    /\ pendingInput = NoInput
    /\ sessionActive = TRUE
    /\ pendingAck[p] = TRUE
    /\ pendingAck' = [pendingAck EXCEPT ![p] = FALSE]
    /\ localWindow' = [localWindow EXCEPT ![p] = MaxWindowSize]
    /\ UNCHANGED <<pendingInput, sessionActive, remoteWindow, pendingPackets>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleEstablishSession
    \/ HandleQueuePacket
    \/ HandleReceivePacket
    \/ HandleReceiveAck
    \/ (\E p \in Peers : SendPacket(p))
    \/ (\E p \in Peers : SendAck(p))

====