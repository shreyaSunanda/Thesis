---- MODULE core_4_19_4_11 ----
EXTENDS Naturals

CONSTANTS NoInput

VARIABLES state, pendingInput

Inputs == {
    "ConfirmedWrite",
    "Indication",
    "KeepAliveMessage",
    "Acknowledgement",
    "Timeout"
}

Init ==
    \* The text references BTP session post-establishment. The exact starting state is omitted
    \* as it relies on missing figures.
    /\ state = "PostEstablishment"
    /\ pendingInput = NoInput

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
\* "clients send data to servers via confirmed writes"
HandleConfirmedWrite ==
    /\ pendingInput = "ConfirmedWrite"
    \* TODO: unspecified - specific state machine transitions for BTP Client are in missing Figure 26/27.
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
\* "servers send data to clients via indications"
HandleIndication ==
    /\ pendingInput = "Indication"
    \* TODO: unspecified - specific state machine transitions for BTP Server are in missing Figure 27.
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
\* "liveliness enforcement through keep alive messages"
HandleKeepAliveMessage ==
    /\ pendingInput = "KeepAliveMessage"
    \* TODO: unspecified - specific state machine transitions for keep alive messages are in missing Figure 28.
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
\* "automatic teardown if acknowledgements are received before the timeout."
HandleAcknowledgement ==
    /\ pendingInput = "Acknowledgement"
    /\ state' = "Teardown"
    /\ pendingInput' = NoInput

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
\* "...automatic teardown if acknowledgements are received before the timeout."
HandleTimeout ==
    /\ pendingInput = "Timeout"
    \* TODO: unspecified - exact behavior upon timeout is missing from the text (the text only specifies teardown if acks are received BEFORE timeout).
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleConfirmedWrite
    \/ HandleIndication
    \/ HandleKeepAliveMessage
    \/ HandleAcknowledgement
    \/ HandleTimeout

====