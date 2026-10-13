---- MODULE core_4_20_3_6 ----
EXTENDS Naturals

VARIABLES 
    sessionState,       \* Tracks the state of the PAFTP session: "Active" or "Closed"
    cTxSeq,             \* Commissioner's transmit sequence number
    dTxSeq,             \* Device's transmit sequence number
    cExpectedRxSeq,     \* Commissioner's expected receive sequence number
    dExpectedRxSeq,     \* Device's expected receive sequence number
    packets,            \* Set of in-flight packets, represented as records [sender, seq]
    applicationError    \* Tracks if an error was reported: "None", "CommissionerError", "DeviceError"

\* Helper to wrap sequence numbers at 255 back to 0
NextSeq(seq) == IF seq = 255 THEN 0 ELSE seq + 1

Init ==
    \* Post-handshake completion state
    /\ sessionState = "Active"
    \* SOURCE: core_4.20.3.6 Sequence Numbers 
    \* "The sequence number of the first packet sent by the Commissioner after completion of the PAFTP session handshake SHALL be zero."
    /\ cTxSeq = 0
    \* SOURCE: core_4.20.3.6 Sequence Numbers
    \* "For this reason, the sequence number of the first data packet sent by the Commissionable Device after completion of the PAFTP session handshake SHALL be 1."
    /\ dTxSeq = 1
    \* The Commissioner expects Device sequence 1 (implied 0 was received during handshake)
    /\ cExpectedRxSeq = 1
    \* The Device expects Commissioner sequence 0
    /\ dExpectedRxSeq = 0
    /\ packets = {}
    /\ applicationError = "None"

\* SOURCE: core_4.20.3.6 Sequence Numbers
\* "A PAFTP sequence number SHALL be defined as an unsigned 8-bit integer value that monotonically increments by 1 with each packet sent by a given peer. A sequence number incremented past 255 SHALL wrap to zero."
CommissionerSends ==
    /\ sessionState = "Active"
    /\ packets' = packets \cup {[sender |-> "Commissioner", seq |-> cTxSeq]}
    /\ cTxSeq' = NextSeq(cTxSeq)
    /\ UNCHANGED <<sessionState, dTxSeq, cExpectedRxSeq, dExpectedRxSeq, applicationError>>

\* SOURCE: core_4.20.3.6 Sequence Numbers
\* "A PAFTP sequence number SHALL be defined as an unsigned 8-bit integer value that monotonically increments by 1 with each packet sent by a given peer. A sequence number incremented past 255 SHALL wrap to zero."
DeviceSends ==
    /\ sessionState = "Active"
    /\ packets' = packets \cup {[sender |-> "Device", seq |-> dTxSeq]}
    /\ dTxSeq' = NextSeq(dTxSeq)
    /\ UNCHANGED <<sessionState, cTxSeq, cExpectedRxSeq, dExpectedRxSeq, applicationError>>

\* SOURCE: core_4.20.3.6 Sequence Numbers
\* "Peers SHALL check to ensure that all received PAFTP packets properly increment the sender’s previous sequence number by 1. If this check fails, the peer SHALL close the PAFTP session and report an error to the application."
CommissionerReceives ==
    /\ sessionState = "Active"
    /\ \E p \in packets :
        /\ p.sender = "Device"
        /\ packets' = packets \ {p}
        /\ IF p.seq = cExpectedRxSeq
           THEN
               /\ cExpectedRxSeq' = NextSeq(cExpectedRxSeq)
               /\ UNCHANGED <<sessionState, applicationError>>
           ELSE
               /\ sessionState' = "Closed"
               /\ applicationError' = "CommissionerError"
               /\ UNCHANGED cExpectedRxSeq
        /\ UNCHANGED <<cTxSeq, dTxSeq, dExpectedRxSeq>>

\* SOURCE: core_4.20.3.6 Sequence Numbers
\* "Peers SHALL check to ensure that all received PAFTP packets properly increment the sender’s previous sequence number by 1. If this check fails, the peer SHALL close the PAFTP session and report an error to the application."
DeviceReceives ==
    /\ sessionState = "Active"
    /\ \E p \in packets :
        /\ p.sender = "Commissioner"
        /\ packets' = packets \ {p}
        /\ IF p.seq = dExpectedRxSeq
           THEN
               /\ dExpectedRxSeq' = NextSeq(dExpectedRxSeq)
               /\ UNCHANGED <<sessionState, applicationError>>
           ELSE
               /\ sessionState' = "Closed"
               /\ applicationError' = "DeviceError"
               /\ UNCHANGED dExpectedRxSeq
        /\ UNCHANGED <<cTxSeq, dTxSeq, cExpectedRxSeq>>

Next ==
    \/ CommissionerSends
    \/ DeviceSends
    \/ CommissionerReceives
    \/ DeviceReceives

====