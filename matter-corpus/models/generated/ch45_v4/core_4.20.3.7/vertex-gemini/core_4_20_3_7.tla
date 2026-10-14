---- MODULE core_4_20_3_7 ----
EXTENDS Naturals

\* The maximum receive window size established for both peers during the PAFTP session handshake.
\* To prevent sequence number wrap-around, the largest maximum window size any peer may support is 255.
CONSTANTS MaxWindowSize

\* Bounding constant for the local application's transmit queue to prevent infinite state space.
CONSTANTS MaxPendingTx

\* REQUIRED - Sentinel for no pending input.
CONSTANTS NoInput

VARIABLES pendingInput
VARIABLES state
VARIABLES role
VARIABLES remoteWindow
VARIABLES pendingTx
VARIABLES pendingAck
VARIABLES unackedRcvdCount

\* REQUIRED - The complete list of events this section can receive.
Inputs == {
    "EstablishCommissionerSession",
    "EstablishDeviceSession",
    "EnqueuePayload",
    "ReceivePAFTPPacket",
    "ReceivePAFTPAck"
}

\* The component is operational when a PAFTP session is established.
Operational == state = "Open"

Init ==
    /\ pendingInput = NoInput
    /\ state = "Uninitialized"
    /\ role = "None"
    /\ remoteWindow = 0
    /\ pendingTx = 0
    /\ pendingAck = FALSE
    /\ unackedRcvdCount = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, role, remoteWindow, pendingTx, pendingAck, unackedRcvdCount>>

\* SOURCE: core_4.20.3.7 Initialization of Commissioner receive window size counter
HandleEstablishCommissionerSession ==
    /\ pendingInput = "EstablishCommissionerSession"
    /\ state = "Uninitialized"
    /\ state' = "Open"
    /\ role' = "Commissioner"
    /\ remoteWindow' = MaxWindowSize
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<pendingTx, pendingAck, unackedRcvdCount>>

\* SOURCE: core_4.20.3.7 Initialization of Commissionable Device receive window size counter
HandleEstablishDeviceSession ==
    /\ pendingInput = "EstablishDeviceSession"
    /\ state = "Uninitialized"
    /\ state' = "Open"
    /\ role' = "CommissionableDevice"
    \* The Commissionable Device's handshake response bears an implicit sequence number of zero,
    \* so its counter starts at MaxWindowSize - 1.
    /\ remoteWindow' = MaxWindowSize - 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<pendingTx, pendingAck, unackedRcvdCount>>

\* SOURCE: core_4.20.3.7 (Implicit) Local host enqueueing payload to be sent
HandleEnqueuePayload ==
    /\ pendingInput = "EnqueuePayload"
    /\ state = "Open"
    /\ pendingTx < MaxPendingTx
    /\ pendingTx' = pendingTx + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, role, remoteWindow, pendingAck, unackedRcvdCount>>

\* SOURCE: core_4.20.3.7 Local peer counter for own receive window size
HandleReceivePAFTPPacket ==
    /\ pendingInput = "ReceivePAFTPPacket"
    /\ state = "Open"
    \* TODO: unspecified - spec mentions "payload ... will be permanently lost" if host does not have space,
    \* but does not state the exact protocol state transitions (e.g., error responses) for overflow.
    /\ unackedRcvdCount < MaxWindowSize
    /\ unackedRcvdCount' = unackedRcvdCount + 1
    /\ pendingAck' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, role, remoteWindow, pendingTx>>

\* SOURCE: core_4.20.3.7 Incrementing counter when sent packet is acknowledged
HandleReceivePAFTPAck ==
    /\ pendingInput = "ReceivePAFTPAck"
    /\ state = "Open"
    \* TODO: unspecified - spec says to increment the counter, but does not specify behavior if
    \* duplicate or invalid acknowledgements would push the remote window above MaxWindowSize.
    /\ remoteWindow < MaxWindowSize
    /\ remoteWindow' = remoteWindow + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, role, pendingTx, pendingAck, unackedRcvdCount>>

\* SOURCE: core_4.20.3.7 Decrementing counter on send, closed window handling, and deadlock avoidance
SendPAFTPPacket ==
    /\ pendingInput = NoInput
    /\ state = "Open"
    /\ pendingTx > 0
    \* "If a local peer's counter for a remote peer's receive window is zero... local peer SHALL NOT send packets"
    /\ remoteWindow > 0
    \* "A local peer SHALL also not send packets if the remote peer's receive window has one slot open
    \* and the local peer does not have a pending packet acknowledgement."
    /\ ~(remoteWindow = 1 /\ pendingAck = FALSE)
    /\ pendingTx' = pendingTx - 1
    /\ remoteWindow' = remoteWindow - 1
    /\ UNCHANGED <<pendingInput, state, role, pendingAck, unackedRcvdCount>>

\* SOURCE: core_4.20.3.7 Proactively send early packet acknowledgements
SendPAFTPAck ==
    /\ pendingInput = NoInput
    /\ state = "Open"
    /\ pendingAck = TRUE
    /\ pendingAck' = FALSE
    \* Abstracting the sequence number modulo math by tracking the raw count of unacknowledged packets directly.
    /\ unackedRcvdCount' = 0
    /\ UNCHANGED <<pendingInput, state, role, remoteWindow, pendingTx>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleEstablishCommissionerSession
    \/ HandleEstablishDeviceSession
    \/ HandleEnqueuePayload
    \/ HandleReceivePAFTPPacket
    \/ HandleReceivePAFTPAck
    \/ SendPAFTPPacket
    \/ SendPAFTPAck

====