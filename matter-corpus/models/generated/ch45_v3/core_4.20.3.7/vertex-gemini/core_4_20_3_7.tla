---- MODULE core_4_20_3_7 ----
EXTENDS Naturals

\* Max allowable window size. Per spec, largest max is 255. 
\* Checkers should use a small value (e.g., 4) to keep the state space finite.
CONSTANTS NegotiatedMaxWindow

\* Maximum queue size for pending transmission requests to keep state space finite.
CONSTANTS MaxPendingTx

\* Sentinel indicating no event is waiting
CONSTANTS NoInput

VARIABLES pendingInput
VARIABLES sessionState
VARIABLES remoteWin
VARIABLES unackedRx
VARIABLES pendingTx
VARIABLES pendingAck

Peers == {"Commissioner", "Device"}

Inputs == {
    "SessionHandshakeComplete",
    "AppQueueTxCommissioner",
    "AppQueueTxDevice",
    "ReceivePacketCommissioner",
    "ReceivePacketDevice",
    "ReceiveAckCommissioner",
    "ReceiveAckDevice"
}

Init ==
    /\ pendingInput = NoInput
    /\ sessionState = "UNINITIALIZED"
    /\ remoteWin = [p \in Peers |-> 0]
    /\ unackedRx = [p \in Peers |-> 0]
    /\ pendingTx = [p \in Peers |-> 0]
    /\ pendingAck = [p \in Peers |-> FALSE]

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<sessionState, remoteWin, unackedRx, pendingTx, pendingAck>>

\* SOURCE: core_4.20.3.7 Receive Windows
\* "A maximum window size SHALL be established for both peers as part of the PAFTP session handshake."
\* "a Commissionable Device SHALL initialize its counter for the Commissioner’s receive window size at (negotiated maximum window size - 1)."
\* "A Commissioner SHALL initialize its counter for the server’s receive window at the negotiated maximum window size."
HandleHandshakeComplete ==
    /\ pendingInput = "SessionHandshakeComplete"
    /\ sessionState = "UNINITIALIZED"
    /\ sessionState' = "ACTIVE"
    /\ remoteWin' = [p \in Peers |-> IF p = "Commissioner" THEN NegotiatedMaxWindow ELSE NegotiatedMaxWindow - 1]
    /\ unackedRx' = [p \in Peers |-> 0]
    /\ pendingTx' = [p \in Peers |-> 0]
    /\ pendingAck' = [p \in Peers |-> FALSE]
    /\ pendingInput' = NoInput

\* Helper: Simulates the application layer queuing a packet for transmission so there is a "pending PAFTP packet transmission".
HandleAppQueueTx(p) ==
    /\ pendingInput = IF p = "Commissioner" THEN "AppQueueTxCommissioner" ELSE "AppQueueTxDevice"
    /\ sessionState = "ACTIVE"
    /\ pendingTx[p] < MaxPendingTx
    /\ pendingTx' = [pendingTx EXCEPT ![p] = pendingTx[p] + 1]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, remoteWin, unackedRx, pendingAck>>

\* SOURCE: core_4.20.3.7 Receive Windows
\* "Each peer SHALL decrement this counter [remote window] when it sends a packet"
\* "If a local peer’s counter for a remote peer’s receive window is zero... SHALL NOT send packets"
\* "When a closed window reopens, a local peer SHALL immediately resume any pending PAFTP packet transmission."
\* "A local peer SHALL also not send packets if the remote peer’s receive window has one slot open and the local peer does not have a pending packet acknowledgement."
SendPacket(p) ==
    /\ pendingInput = NoInput  \* Spontaneous internal action
    /\ sessionState = "ACTIVE"
    /\ pendingTx[p] > 0
    /\ remoteWin[p] > 0
    /\ ~(remoteWin[p] = 1 /\ ~pendingAck[p])
    /\ pendingTx' = [pendingTx EXCEPT ![p] = pendingTx[p] - 1]
    /\ remoteWin' = [remoteWin EXCEPT ![p] = remoteWin[p] - 1]
    /\ pendingAck' = IF pendingAck[p] THEN [pendingAck EXCEPT ![p] = FALSE] ELSE pendingAck
    /\ unackedRx' = IF pendingAck[p] THEN [unackedRx EXCEPT ![p] = 0] ELSE unackedRx
    /\ UNCHANGED <<pendingInput, sessionState>>

\* SOURCE: core_4.20.3.7 Receive Windows
\* "Both peers SHALL also keep a counter of their own receive window size based on the sequence number difference between the last packet they received and the last packet they acknowledged."
HandleReceivePacket(p) ==
    /\ pendingInput = IF p = "Commissioner" THEN "ReceivePacketCommissioner" ELSE "ReceivePacketDevice"
    /\ sessionState = "ACTIVE"
    \* TODO: unspecified - spec notes packets are "permanently lost" if the host lacks space, 
    \* but does not explicitly dictate local transport state behavior if a packet arrives when the window is full.
    /\ unackedRx[p] < NegotiatedMaxWindow
    /\ unackedRx' = [unackedRx EXCEPT ![p] = unackedRx[p] + 1]
    /\ pendingAck' = [pendingAck EXCEPT ![p] = TRUE]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, remoteWin, pendingTx>>

\* SOURCE: core_4.20.3.7 Receive Windows
\* "Each peer SHALL... increment this counter [remote window] when a sent packet is acknowledged."
HandleReceiveAck(p) ==
    /\ pendingInput = IF p = "Commissioner" THEN "ReceiveAckCommissioner" ELSE "ReceiveAckDevice"
    /\ sessionState = "ACTIVE"
    \* Abstraction: assumes each generic ReceiveAck event acknowledges one newly transmitted packet.
    /\ remoteWin[p] < NegotiatedMaxWindow
    /\ remoteWin' = [remoteWin EXCEPT ![p] = remoteWin[p] + 1]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, unackedRx, pendingTx, pendingAck>>

\* SOURCE: core_4.20.3.7 Receive Windows
\* "This counter [own receive window] is used to proactively send early packet acknowledgements when a peer’s own receive window is about to close."
SendStandaloneAck(p) ==
    /\ pendingInput = NoInput
    /\ sessionState = "ACTIVE"
    /\ pendingAck[p] = TRUE
    /\ pendingAck' = [pendingAck EXCEPT ![p] = FALSE]
    /\ unackedRx' = [unackedRx EXCEPT ![p] = 0]
    /\ UNCHANGED <<pendingInput, sessionState, remoteWin, pendingTx>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleHandshakeComplete
    \/ (\E p \in Peers : HandleAppQueueTx(p))
    \/ (\E p \in Peers : SendPacket(p))
    \/ (\E p \in Peers : HandleReceivePacket(p))
    \/ (\E p \in Peers : HandleReceiveAck(p))
    \/ (\E p \in Peers : SendStandaloneAck(p))

====