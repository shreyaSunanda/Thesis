---- MODULE core_4_12_1 ----
EXTENDS Naturals

\* Sentinel value representing no input is waiting to be processed.
CONSTANTS NoInput

\* Sentinel value indicating the Acknowledged Message Counter field is absent.
CONSTANTS NoCounter

\* A placeholder valid message counter representing the counter of the message being acknowledged.
CONSTANTS ValidMessageCounter

VARIABLES 
    pendingInput,
    messageOut

\* Complete list of events mentioned or implied by the text.
\* The spec focuses on the sender constructing messages, but passingly mentions 
\* "the receiver to send back an acknowledgment", implying a receive event occurs.
Inputs == {
    "SendReliableMessage",
    "SendUnreliableMessage",
    "SendStandaloneAck",
    "SendMessageWithAck",
    "ReceiveReliableMessage"
}

Init ==
    /\ pendingInput = NoInput
    /\ messageOut = [rFlag |-> FALSE, aFlag |-> FALSE, ackMsgCounter |-> NoCounter, isStandaloneAck |-> FALSE]

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<messageOut>>

\* SOURCE: core_4.12.1 R Flag
\* "This flag SHALL be set by the sender when a message being sent requires 
\* the receiver to send back an acknowledgment."
HandleSendReliableMessage ==
    /\ pendingInput = "SendReliableMessage"
    /\ messageOut' = [rFlag |-> TRUE, aFlag |-> FALSE, ackMsgCounter |-> NoCounter, isStandaloneAck |-> FALSE]
    /\ pendingInput' = NoInput

\* SOURCE: core_4.12.1 R Flag
\* "To support unreliable messages, this flag bit MAY be clear, so that no 
\* acknowledgements are requested from the receiver."
HandleSendUnreliableMessage ==
    /\ pendingInput = "SendUnreliableMessage"
    /\ messageOut' = [rFlag |-> FALSE, aFlag |-> FALSE, ackMsgCounter |-> NoCounter, isStandaloneAck |-> FALSE]
    /\ pendingInput' = NoInput

\* SOURCE: core_4.12.1 A Flag, Acknowledged Message Counter
\* "This flag SHALL always be set for MRP Standalone Acknowledgement messages."
\* "When set, the Acknowledged Message Counter field SHALL be present and valid."
\* "This field SHALL be set to the Message Counter of the message that is being acknowledged."
HandleSendStandaloneAck ==
    /\ pendingInput = "SendStandaloneAck"
    /\ messageOut' = [rFlag |-> FALSE, aFlag |-> TRUE, ackMsgCounter |-> ValidMessageCounter, isStandaloneAck |-> TRUE]
    /\ pendingInput' = NoInput

\* SOURCE: core_4.12.1 A Flag, Acknowledged Message Counter
\* "This flag MAY be set on any message. When set, the Acknowledged Message 
\* Counter field SHALL be present and valid."
HandleSendMessageWithAck ==
    /\ pendingInput = "SendMessageWithAck"
    /\ messageOut' = [rFlag |-> TRUE, aFlag |-> TRUE, ackMsgCounter |-> ValidMessageCounter, isStandaloneAck |-> FALSE]
    /\ pendingInput' = NoInput

\* TODO: unspecified - The spec text says a reliable message "requires the receiver to send back 
\* an acknowledgment", implying the receiver must process an incoming reliable message to trigger
\* the transmission. However, this section only describes the header fields of the messages 
\* being sent, not the receiver's state machine or timing for generating the acknowledgment.
\* "ReceiveReliableMessage" is thus listed in Inputs but unhandled here.

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleSendReliableMessage
    \/ HandleSendUnreliableMessage
    \/ HandleSendStandaloneAck
    \/ HandleSendMessageWithAck

====