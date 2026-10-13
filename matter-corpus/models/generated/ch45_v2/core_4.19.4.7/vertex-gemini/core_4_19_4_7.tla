---- MODULE core_4_19_4_7 ----
EXTENDS Naturals

\* Largest maximum window size any peer may support is 255, to prevent sequence wrap-around.
CONSTANTS MaxWindowSize

\* Bounding constant for the transmit queue to ensure a finite state space.
CONSTANTS MaxTxQueue

CONSTANTS NoInput, Inputs
VARIABLES state, pendingInput
VARIABLES remoteWindowCounter
VARIABLES localWindowCounter
VARIABLES hasPendingAck
VARIABLES pendingTxCount

Init ==
    /\ state = "Uninitialized"
    /\ pendingInput = NoInput
    /\ remoteWindowCounter = 0
    /\ localWindowCounter = 0
    /\ hasPendingAck = FALSE
    /\ pendingTxCount = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, remoteWindowCounter, localWindowCounter, hasPendingAck, pendingTxCount>>

\* SOURCE: core_4.19.4.7
\* "Because the server’s handshake response bears an implicit BTP sequence number of zero, 
\* a server SHALL initialize its counter for the client’s receive window size at 
\* (negotiated maximum window size - 1)."
InitializeServer ==
    /\ pendingInput = "InitializeServer"
    /\ state = "Uninitialized"
    /\ state' = "Active"
    /\ remoteWindowCounter' = MaxWindowSize - 1
    \* "The server’s initial receive window is empty."
    /\ localWindowCounter' = MaxWindowSize
    /\ hasPendingAck' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<pendingTxCount>>

\* SOURCE: core_4.19.4.7
\* "A client SHALL initialize its counter for the server’s receive window at the 
\* negotiated maximum window size."
InitializeClient ==
    /\ pendingInput = "InitializeClient"
    /\ state = "Uninitialized"
    /\ state' = "Active"
    /\ remoteWindowCounter' = MaxWindowSize
    \* "The handshake request occupies one slot in the client’s initial receive window."
    /\ localWindowCounter' = MaxWindowSize - 1
    \* TODO: unspecified - exact state of hasPendingAck for client immediately after handshake. 
    \* Assumed TRUE since the handshake request occupied a slot, implying it requires an ack.
    /\ hasPendingAck' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<pendingTxCount>>

\* Helper action: application layer enqueues a packet to be sent.
EnqueueData ==
    /\ pendingInput = "EnqueueData"
    /\ state = "Active"
    /\ pendingTxCount < MaxTxQueue
    /\ pendingTxCount' = pendingTxCount + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, remoteWindowCounter, localWindowCounter, hasPendingAck>>

\* SOURCE: core_4.19.4.7
\* "Each peer SHALL decrement this counter when it sends a packet via GATT write or indication..."
\* "If a local peer’s counter for a remote peer’s receive window is zero, the window SHALL 
\* be considered closed, and the local peer SHALL NOT send packets until the window reopens"
\* "When a closed window reopens, a local peer SHALL immediately resume any pending BTP packet transmission."
\* "A local peer SHALL also not send packets if the remote peer’s receive window has one slot open 
\* and the local peer does not have a pending packet acknowledgement."
TransmitPacket ==
    /\ pendingInput = NoInput
    /\ state = "Active"
    /\ pendingTxCount > 0
    /\ remoteWindowCounter > 0
    /\ ~(remoteWindowCounter = 1 /\ ~hasPendingAck)
    /\ remoteWindowCounter' = remoteWindowCounter - 1
    /\ pendingTxCount' = pendingTxCount - 1
    \* Acknowledgment piggybacked on the outgoing packet.
    /\ hasPendingAck' = FALSE
    /\ UNCHANGED <<state, localWindowCounter, pendingInput>>

\* SOURCE: core_4.19.4.7
\* "...and increment this counter when a sent packet is acknowledged."
AckReceived ==
    /\ pendingInput = "AckReceived"
    /\ state = "Active"
    /\ remoteWindowCounter < 255
    /\ remoteWindowCounter' = remoteWindowCounter + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, localWindowCounter, hasPendingAck, pendingTxCount>>

\* SOURCE: core_4.19.4.7
\* "Both peers SHALL also keep a counter of their own receive window size based on the sequence 
\* number difference between the last packet they received and the last packet they acknowledged."
PacketReceived ==
    /\ pendingInput = "PacketReceived"
    /\ state = "Active"
    /\ localWindowCounter > 0
    /\ localWindowCounter' = localWindowCounter - 1
    /\ hasPendingAck' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, remoteWindowCounter, pendingTxCount>>

\* SOURCE: core_4.19.4.7
\* "This counter is used to proactively send early packet acknowledgements when a peer’s own 
\* receive window is about to close."
SendStandaloneAck ==
    /\ pendingInput = "SendStandaloneAck"
    /\ state = "Active"
    /\ hasPendingAck = TRUE
    /\ hasPendingAck' = FALSE
    \* Acknowledging all unacknowledged packets resets the difference to 0, completely freeing the local window.
    /\ localWindowCounter' = MaxWindowSize
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, remoteWindowCounter, pendingTxCount>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ InitializeServer
    \/ InitializeClient
    \/ EnqueueData
    \/ TransmitPacket
    \/ AckReceived
    \/ PacketReceived
    \/ SendStandaloneAck

====