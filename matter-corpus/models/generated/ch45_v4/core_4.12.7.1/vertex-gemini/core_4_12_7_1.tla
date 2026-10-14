---- MODULE core_4_12_7_1 ----
EXTENDS Naturals

\* Protocol constants mentioned in the spec
CONSTANTS PROTOCOL_ID_SECURE_CHANNEL
CONSTANTS MRP_STANDALONE_ACKNOWLEDGEMENT

\* Sentinel for no pending input
CONSTANTS NoInput

VARIABLES state, pendingInput
\* Additional variables to capture the generated message and the counter state
VARIABLES msgOut, ackMessageCounter

\* The spec says rules for when to send this are in Section 4.12.5.2.2.
\* We model the trigger to format and send this message as an input event.
Inputs == {"SendMRPStandaloneAcknowledgement"}

Operational == state = "OPERATIONAL"

Init ==
    /\ state = "OPERATIONAL"
    /\ pendingInput = NoInput
    /\ msgOut = [type |-> "None"]
    /\ ackMessageCounter = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, msgOut, ackMessageCounter>>

\* Helper definition to avoid multi-line records inside conjunction lists
StandaloneAckMessage(counter) ==
    [applicationPayload         |-> "",
     aFlag                      |-> 1,
     acknowledgedMessageCounter |-> counter,
     protocolId                 |-> PROTOCOL_ID_SECURE_CHANNEL,
     protocolOpcode             |-> MRP_STANDALONE_ACKNOWLEDGEMENT]

\* SOURCE: core_4.12.7.1
FormatStandaloneAck ==
    /\ pendingInput = "SendMRPStandaloneAcknowledgement"
    /\ msgOut' = StandaloneAckMessage(ackMessageCounter)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, ackMessageCounter>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ FormatStandaloneAck

====