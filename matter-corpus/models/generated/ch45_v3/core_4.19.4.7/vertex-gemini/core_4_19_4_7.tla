---- MODULE core_4_19_4_7 ----
EXTENDS Naturals

\* The largest maximum window size any peer may support is 255.
CONSTANTS MaxWindowSupported

\* Abstract bounds for finite state checking
CONSTANTS DefaultNegotiatedWindow, MaxQueue

CONSTANTS NoInput
VARIABLES pendingInput

\* State tracking for a single peer's perspective of the BTP session
VARIABLES role
VARIABLES negotiatedMaxWindow
VARIABLES remoteWindowCounter
VARIABLES ownWindowCounter
VARIABLES hasPendingAck
VARIABLES pendingTransmissions

Inputs == {
    "HandshakeCompleted_Client",
    "HandshakeCompleted_Server",
    "ReceiveGATTPacket",
    "ReceiveAck",
    "QueuePacketForSend"
}

Init ==
    /\ pendingInput = NoInput
    /\ role = "None"
    /\ negotiatedMaxWindow = 0
    /\ remoteWindowCounter = 0
    /\ ownWindowCounter = 0
    /\ hasPendingAck = FALSE
    /\ pendingTransmissions = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<role, negotiatedMaxWindow, remoteWindowCounter, ownWindowCounter, hasPendingAck, pendingTransmissions>>

\* SOURCE: core_4.19.4.7
HandleHandshakeClient ==
    /\ pendingInput = "HandshakeCompleted_Client"
    /\ role = "None"
    /\ role' = "Client"
    /\ negotiatedMaxWindow' = DefaultNegotiatedWindow
    \* A client SHALL initialize its counter for the server's receive window at the negotiated maximum window size
    /\ remoteWindowCounter' = DefaultNegotiatedWindow
    /\ ownWindowCounter' = DefaultNegotiatedWindow
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<hasPendingAck, pendingTransmissions>>

\* SOURCE: core_4.19.4.7
HandleHandshakeServer ==
    /\ pendingInput = "HandshakeCompleted_Server"
    /\ role = "None"
    /\ role' = "Server"
    /\ negotiatedMaxWindow' = DefaultNegotiatedWindow
    \* Because the server's handshake response bears an implicit BTP sequence number of zero, a server SHALL 
    \* initialize its counter for the client's receive window size at (negotiated maximum window size - 1)
    /\ remoteWindowCounter' = DefaultNegotiatedWindow - 1
    /\ ownWindowCounter' = DefaultNegotiatedWindow
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<hasPendingAck, pendingTransmissions>>

\* SOURCE: core_4.19.4.7
HandleQueuePacketForSend ==
    /\ pendingInput = "QueuePacketForSend"
    /\ role # "None"
    /\ pendingTransmissions < MaxQueue
    /\ pendingTransmissions' = pendingTransmissions + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<role, negotiatedMaxWindow, remoteWindowCounter, ownWindowCounter, hasPendingAck>>

\* SOURCE: core_4.19.4.7
\* Abstraction: Sequence numbers and their differences are abstracted directly into ownWindowCounter.
HandleReceiveGATTPacket ==
    /\ pendingInput = "ReceiveGATTPacket"
    /\ role # "None"
    \* TODO: unspecified - what happens if a packet arrives when ownWindowCounter is 0?
    /\ ownWindowCounter > 0
    /\ ownWindowCounter' = ownWindowCounter - 1
    /\ hasPendingAck' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<role, negotiatedMaxWindow, remoteWindowCounter, pendingTransmissions>>

\* SOURCE: core_4.19.4.7
HandleReceiveAck ==
    /\ pendingInput = "ReceiveAck"
    /\ role # "None"
    /\ remoteWindowCounter < negotiatedMaxWindow
    \* increment this counter when a sent packet is acknowledged
    /\ remoteWindowCounter' = remoteWindowCounter + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<role, negotiatedMaxWindow, ownWindowCounter, hasPendingAck, pendingTransmissions>>

\* SOURCE: core_4.19.4.7
SendPacket ==
    /\ pendingInput = NoInput
    /\ role # "None"
    /\ pendingTransmissions > 0
    \* If a local peer's counter for a remote peer's receive window is zero, the window SHALL be considered closed, 
    \* and the local peer SHALL NOT send packets
    /\ remoteWindowCounter > 0
    \* A local peer SHALL also not send packets if the remote peer's receive window has one slot open and 
    \* the local peer does not have a pending packet acknowledgement.
    /\ ~(remoteWindowCounter = 1 /\ ~hasPendingAck)
    /\ remoteWindowCounter' = remoteWindowCounter - 1
    /\ pendingTransmissions' = pendingTransmissions - 1
    \* Implicitly piggybacking the ack if we have one pending
    /\ hasPendingAck' = FALSE
    /\ ownWindowCounter' = IF hasPendingAck THEN negotiatedMaxWindow ELSE ownWindowCounter
    /\ UNCHANGED <<role, negotiatedMaxWindow, pendingInput>>

\* SOURCE: core_4.19.4.7
SendProactiveAck ==
    /\ pendingInput = NoInput
    /\ role # "None"
    /\ hasPendingAck = TRUE
    \* TODO: unspecified - what precise threshold determines that the window "is about to close"?
    /\ ownWindowCounter < negotiatedMaxWindow
    /\ hasPendingAck' = FALSE
    /\ ownWindowCounter' = negotiatedMaxWindow
    /\ UNCHANGED <<role, negotiatedMaxWindow, remoteWindowCounter, pendingTransmissions, pendingInput>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleHandshakeClient
    \/ HandleHandshakeServer
    \/ HandleQueuePacketForSend
    \/ HandleReceiveGATTPacket
    \/ HandleReceiveAck
    \/ SendPacket
    \/ SendProactiveAck

====