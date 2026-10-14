---- MODULE core_4_19_4_7 ----
EXTENDS Naturals

\* The maximum possible size of the receive window. 
\* Real value per spec: 255. Bounded here to keep state space finite.
CONSTANTS MaxWindowSizeLimit

\* Limit on the pending transmission queue to keep state space finite.
CONSTANTS MaxQueueSize

\* REQUIRED - Sentinel value for no pending input
CONSTANTS NoInput

VARIABLES 
    pendingInput,
    inputData,               \* Carries data for the input events (negotiated window size, ack counts)
    state,                   \* e.g., "Uninitialized", "Established"
    role,                    \* "None", "Client", or "Server"
    maxWindowSize,           \* The established maximum window size for the session
    remoteWindowCount,       \* Counter reflecting current size of remote peer's receive window
    unackedReceivedPackets,  \* Counter of own receive window size (unacknowledged received packets)
    pendingTxQueue           \* Queue of packets from the app waiting to be transmitted

\* REQUIRED - The complete list of events this section can receive.
Inputs == {
    "StartSessionAsClient",
    "StartSessionAsServer",
    "AppEnqueuePacket",
    "ReceivePeerPacket",
    "ReceiveStandaloneAck"
}

Operational == state = "Established"

Init ==
    /\ pendingInput = NoInput
    /\ inputData = [negotiatedMaxWindow |-> 1, ackedCount |-> 0]
    /\ state = "Uninitialized"
    /\ role = "None"
    /\ maxWindowSize = 0
    /\ remoteWindowCount = 0
    /\ unackedReceivedPackets = 0
    /\ pendingTxQueue = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E nWin \in 1..MaxWindowSizeLimit, ackCnt \in 0..MaxWindowSizeLimit : inputData' = [negotiatedMaxWindow |-> nWin, ackedCount |-> ackCnt]
    /\ UNCHANGED <<state, role, maxWindowSize, remoteWindowCount, unackedReceivedPackets, pendingTxQueue>>

\* SOURCE: core_4.19.4.7
HandleStartSessionAsClient ==
    /\ pendingInput = "StartSessionAsClient"
    /\ state = "Uninitialized"
    /\ state' = "Established"
    /\ role' = "Client"
    /\ maxWindowSize' = inputData.negotiatedMaxWindow
    \* A client SHALL initialize its counter for the server's receive window at the negotiated maximum window size.
    /\ remoteWindowCount' = inputData.negotiatedMaxWindow
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputData, unackedReceivedPackets, pendingTxQueue>>

\* SOURCE: core_4.19.4.7
HandleStartSessionAsServer ==
    /\ pendingInput = "StartSessionAsServer"
    /\ state = "Uninitialized"
    /\ state' = "Established"
    /\ role' = "Server"
    /\ maxWindowSize' = inputData.negotiatedMaxWindow
    \* Because the server's handshake response bears an implicit BTP sequence number of zero, a server 
    \* SHALL initialize its counter for the client's receive window size at (negotiated maximum window size - 1).
    /\ remoteWindowCount' = inputData.negotiatedMaxWindow - 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputData, unackedReceivedPackets, pendingTxQueue>>

\* SOURCE: core_4.19.4.7
HandleAppEnqueuePacket ==
    /\ pendingInput = "AppEnqueuePacket"
    /\ state = "Established"
    /\ pendingTxQueue < MaxQueueSize
    /\ pendingTxQueue' = pendingTxQueue + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputData, state, role, maxWindowSize, remoteWindowCount, unackedReceivedPackets>>

\* SOURCE: core_4.19.4.7
HandleReceivePeerPacket ==
    /\ pendingInput = "ReceivePeerPacket"
    /\ state = "Established"
    /\ unackedReceivedPackets < maxWindowSize
    /\ remoteWindowCount + inputData.ackedCount <= maxWindowSize
    /\ unackedReceivedPackets' = unackedReceivedPackets + 1
    /\ remoteWindowCount' = remoteWindowCount + inputData.ackedCount
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputData, state, role, maxWindowSize, pendingTxQueue>>

\* SOURCE: core_4.19.4.7
HandleReceiveStandaloneAck ==
    /\ pendingInput = "ReceiveStandaloneAck"
    /\ state = "Established"
    /\ remoteWindowCount + inputData.ackedCount <= maxWindowSize
    /\ remoteWindowCount' = remoteWindowCount + inputData.ackedCount
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputData, state, role, maxWindowSize, unackedReceivedPackets, pendingTxQueue>>

\* SOURCE: core_4.19.4.7
TransmitPendingPacket ==
    /\ pendingInput = NoInput
    /\ state = "Established"
    /\ pendingTxQueue > 0
    \* If a local peer's counter for a remote peer's receive window is zero, the window SHALL be considered closed,
    \* and the local peer SHALL NOT send packets until the window reopens.
    /\ remoteWindowCount > 0
    \* A local peer SHALL also not send packets if the remote peer's receive window has one slot open
    \* and the local peer does not have a pending packet acknowledgement.
    /\ (remoteWindowCount = 1 => unackedReceivedPackets > 0)
    /\ pendingTxQueue' = pendingTxQueue - 1
    /\ remoteWindowCount' = remoteWindowCount - 1
    \* Acknowledgement of a sequence number implies acknowledgement of all packets received on the same BTP session prior.
    \* Sending a packet implicitly carries an ack, clearing the counter.
    /\ unackedReceivedPackets' = 0
    /\ UNCHANGED <<inputData, pendingInput, state, role, maxWindowSize>>

\* SOURCE: core_4.19.4.7
TransmitStandaloneAck ==
    /\ pendingInput = NoInput
    /\ state = "Established"
    /\ unackedReceivedPackets > 0
    \* Proactively send early packet acknowledgements when a peer's own receive window is about to close.
    /\ unackedReceivedPackets' = 0
    /\ UNCHANGED <<inputData, pendingInput, state, role, maxWindowSize, remoteWindowCount, pendingTxQueue>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleStartSessionAsClient
    \/ HandleStartSessionAsServer
    \/ HandleAppEnqueuePacket
    \/ HandleReceivePeerPacket
    \/ HandleReceiveStandaloneAck
    \/ TransmitPendingPacket
    \/ TransmitStandaloneAck

====