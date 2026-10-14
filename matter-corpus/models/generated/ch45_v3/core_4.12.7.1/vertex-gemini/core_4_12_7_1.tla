---- MODULE core_4_12_7_1 ----
EXTENDS Naturals

\* Declare EVERY fixed value the spec text mentions
CONSTANTS 
    \* Protocol ID for Secure Channel
    PROTOCOL_ID_SECURE_CHANNEL,
    \* Protocol Opcode for MRP Standalone Acknowledgement
    OPCODE_MRP_STANDALONE_ACKNOWLEDGEMENT,
    \* Sentinel value for no pending input
    NoInput

VARIABLES 
    pendingInput

\* No incoming events are mentioned in this section.
Inputs == {}

Init == 
    /\ pendingInput = NoInput

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e

\* SOURCE: core_4.12.7.1 MRP Standalone Acknowledgement
\* The text describes the exact fields required to form this message.
\* The rules for sending it are deferred to another section, so it is modeled here
\* as a helper operator that creates the compliant message record.
StandaloneAckMessage(ackMsgCounter) ==
    [
        applicationPayload         |-> "",
        aFlag                      |-> 1,
        acknowledgedMessageCounter |-> ackMsgCounter,
        protocolId                 |-> PROTOCOL_ID_SECURE_CHANNEL,
        protocolOpcode             |-> OPCODE_MRP_STANDALONE_ACKNOWLEDGEMENT
    ]

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))

====