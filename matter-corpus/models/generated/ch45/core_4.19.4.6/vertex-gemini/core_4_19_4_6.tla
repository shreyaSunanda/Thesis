---- MODULE core_4_19_4_6 ----
EXTENDS Naturals

VARIABLES 
    sessionState,
    clientTxSeq,
    serverTxSeq,
    clientRxExpectedSeq,
    serverRxExpectedSeq,
    networkMsg

\* A helper to model the 8-bit monotonic sequence wrapping past 255 to zero.
NextSeq(s) == IF s = 255 THEN 0 ELSE s + 1

\* A helper representing the absence of an in-transit message.
NoMsg == [sender |-> "None", seq |-> 0]

Init ==
    /\ sessionState = "Handshake"
    /\ clientTxSeq = 0
    /\ serverTxSeq = 0
    /\ clientRxExpectedSeq = 0
    /\ serverRxExpectedSeq = 0
    /\ networkMsg = NoMsg

\* SOURCE: core_4.19.4.6 The sequence number of the first packet sent by the client after completion of the BTP session handshake SHALL be zero. ... For this reason, the sequence number of the first data packet sent by the server after completion of the BTP session handshake SHALL be 1.
FinishHandshake ==
    /\ sessionState = "Handshake"
    /\ sessionState' = "Active"
    /\ clientTxSeq' = 0
    /\ serverTxSeq' = 1
    /\ clientRxExpectedSeq' = 1
    /\ serverRxExpectedSeq' = 0
    /\ UNCHANGED networkMsg

\* SOURCE: core_4.19.4.6 A BTP sequence number SHALL be defined as an unsigned 8-bit integer value that monotonically increments by 1 with each packet sent by a given peer. A sequence number incremented past 255 SHALL wrap to zero.
ClientSend ==
    /\ sessionState = "Active"
    /\ networkMsg = NoMsg
    /\ networkMsg' = [sender |-> "Client", seq |-> clientTxSeq]
    /\ clientTxSeq' = NextSeq(clientTxSeq)
    /\ UNCHANGED <<sessionState, serverTxSeq, clientRxExpectedSeq, serverRxExpectedSeq>>

\* SOURCE: core_4.19.4.6 A BTP sequence number SHALL be defined as an unsigned 8-bit integer value that monotonically increments by 1 with each packet sent by a given peer. A sequence number incremented past 255 SHALL wrap to zero.
ServerSend ==
    /\ sessionState = "Active"
    /\ networkMsg = NoMsg
    /\ networkMsg' = [sender |-> "Server", seq |-> serverTxSeq]
    /\ serverTxSeq' = NextSeq(serverTxSeq)
    /\ UNCHANGED <<sessionState, clientTxSeq, clientRxExpectedSeq, serverRxExpectedSeq>>

\* SOURCE: core_4.19.4.6 Peers SHALL check to ensure that all received BTP packets properly increment the sender’s previous sequence number by 1.
ClientReceiveValid ==
    /\ sessionState = "Active"
    /\ networkMsg.sender = "Server"
    /\ networkMsg.seq = clientRxExpectedSeq
    /\ clientRxExpectedSeq' = NextSeq(clientRxExpectedSeq)
    /\ networkMsg' = NoMsg
    /\ UNCHANGED <<sessionState, clientTxSeq, serverTxSeq, serverRxExpectedSeq>>

\* SOURCE: core_4.19.4.6 If this check fails, the peer SHALL close the BTP session and report an error to the application.
ClientReceiveInvalid ==
    /\ sessionState = "Active"
    /\ networkMsg.sender = "Server"
    /\ networkMsg.seq # clientRxExpectedSeq
    /\ sessionState' = "ClosedError"
    /\ networkMsg' = NoMsg
    /\ UNCHANGED <<clientTxSeq, serverTxSeq, clientRxExpectedSeq, serverRxExpectedSeq>>

\* SOURCE: core_4.19.4.6 Peers SHALL check to ensure that all received BTP packets properly increment the sender’s previous sequence number by 1.
ServerReceiveValid ==
    /\ sessionState = "Active"
    /\ networkMsg.sender = "Client"
    /\ networkMsg.seq = serverRxExpectedSeq
    /\ serverRxExpectedSeq' = NextSeq(serverRxExpectedSeq)
    /\ networkMsg' = NoMsg
    /\ UNCHANGED <<sessionState, clientTxSeq, serverTxSeq, clientRxExpectedSeq>>

\* SOURCE: core_4.19.4.6 If this check fails, the peer SHALL close the BTP session and report an error to the application.
ServerReceiveInvalid ==
    /\ sessionState = "Active"
    /\ networkMsg.sender = "Client"
    /\ networkMsg.seq # serverRxExpectedSeq
    /\ sessionState' = "ClosedError"
    /\ networkMsg' = NoMsg
    /\ UNCHANGED <<clientTxSeq, serverTxSeq, clientRxExpectedSeq, serverRxExpectedSeq>>

Next ==
    \/ FinishHandshake
    \/ ClientSend
    \/ ServerSend
    \/ ClientReceiveValid
    \/ ClientReceiveInvalid
    \/ ServerReceiveValid
    \/ ServerReceiveInvalid

====