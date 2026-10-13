---- MODULE core_4_12_7_1 ----
EXTENDS Naturals

\* The protocol ID for the secure channel
CONSTANTS PROTOCOL_ID_SECURE_CHANNEL

\* The opcode for MRP Standalone Acknowledgement
CONSTANTS OPCODE_MRP_STANDALONE_ACK

\* Representation of an empty application payload
CONSTANTS EmptyPayload

\* The set of valid message counters (used to bound the state space)
CONSTANTS MessageCounters

\* The set of messages sent to the network
VARIABLES sentMessages

Init ==
    sentMessages = {}

\* Formats the MRP Standalone Acknowledgement message
\* SOURCE: core_4.12.7.1 MRP Standalone Acknowledgement
StandaloneAckMessage(ackCounter) ==
    [payload       |-> EmptyPayload,
     aFlag         |-> 1,
     ackMsgCounter |-> ackCounter,
     protocolId    |-> PROTOCOL_ID_SECURE_CHANNEL,
     opcode        |-> OPCODE_MRP_STANDALONE_ACK]

\* SOURCE: core_4.12.7.1 MRP Standalone Acknowledgement
\* TODO: unspecified - The rules for when to send this message are detailed in
\* Section 4.12.5.2.2, which is outside the scope of this module. Therefore, 
\* this action is modeled to fire non-deterministically for any valid message 
\* counter in this isolated module.
SendStandaloneAck(ackCounter) ==
    sentMessages' = sentMessages \cup {StandaloneAckMessage(ackCounter)}

Next ==
    \E ackCounter \in MessageCounters :
        SendStandaloneAck(ackCounter)

====