---- MODULE core_4_19_4_6 ----
EXTENDS Naturals

\* 255 in the spec text, representing an 8-bit unsigned integer limit.
\* Declared as a constant to allow smaller bounds during model checking.
CONSTANTS MaxSeqNum

CONSTANTS NoInput

VARIABLES 
    state,
    pendingInput,
    inputPeer,
    inputSeq,
    txSeq,
    rxExpectedSeq,
    errorReported

Peers == {"Client", "Server"}
SeqNumModulus == MaxSeqNum + 1

Inputs == {"SendPacket", "ReceivePacket", "HandshakeComplete"}

Init == 
    /\ pendingInput = NoInput
    /\ inputPeer = "Client"
    /\ inputSeq = 0
    /\ state = [p \in Peers |-> "Handshake"]
    /\ txSeq = [p \in Peers |-> 0]
    /\ rxExpectedSeq = [p \in Peers |-> 0]
    /\ errorReported = [p \in Peers |-> FALSE]

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E p \in Peers : \E s \in 0..MaxSeqNum :
           /\ inputPeer' = p
           /\ inputSeq' = s
    /\ UNCHANGED <<state, txSeq, rxExpectedSeq, errorReported>>

\* SOURCE: core_4.19.4.6
HandleHandshakeComplete ==
    /\ pendingInput = "HandshakeComplete"
    /\ state[inputPeer] = "Handshake"
    /\ state' = [state EXCEPT ![inputPeer] = "Open"]
    /\ txSeq' = [txSeq EXCEPT ![inputPeer] = IF inputPeer = "Client" THEN 0 ELSE 1]
    /\ rxExpectedSeq' = [rxExpectedSeq EXCEPT ![inputPeer] = IF inputPeer = "Client" THEN 1 ELSE 0]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputPeer, inputSeq, errorReported>>

\* SOURCE: core_4.19.4.6
HandleSendPacket ==
    /\ pendingInput = "SendPacket"
    /\ state[inputPeer] = "Open"
    /\ txSeq' = [txSeq EXCEPT ![inputPeer] = (txSeq[inputPeer] + 1) % SeqNumModulus]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputPeer, inputSeq, rxExpectedSeq, errorReported>>

\* SOURCE: core_4.19.4.6
HandleReceivePacketValid ==
    /\ pendingInput = "ReceivePacket"
    /\ state[inputPeer] = "Open"
    /\ inputSeq = rxExpectedSeq[inputPeer]
    /\ rxExpectedSeq' = [rxExpectedSeq EXCEPT ![inputPeer] = (inputSeq + 1) % SeqNumModulus]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputPeer, inputSeq, txSeq, errorReported>>

\* SOURCE: core_4.19.4.6
HandleReceivePacketInvalid ==
    /\ pendingInput = "ReceivePacket"
    /\ state[inputPeer] = "Open"
    /\ inputSeq # rxExpectedSeq[inputPeer]
    /\ state' = [state EXCEPT ![inputPeer] = "Closed"]
    /\ errorReported' = [errorReported EXCEPT ![inputPeer] = TRUE]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputPeer, inputSeq, txSeq, rxExpectedSeq>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleHandshakeComplete
    \/ HandleSendPacket
    \/ HandleReceivePacketValid
    \/ HandleReceivePacketInvalid

====