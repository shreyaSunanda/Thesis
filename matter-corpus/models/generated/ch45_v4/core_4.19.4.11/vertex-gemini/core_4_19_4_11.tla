---- MODULE core_4_19_4_11 ----
EXTENDS Naturals

\* The role of the device in the BTP session (e.g., "GATTClient" or "GATTServer").
CONSTANTS Role

\* Sentinel for no pending input.
CONSTANTS NoInput

VARIABLES 
    state,
    pendingInput,
    lastSendMethod

\* Events derived from the text regarding sending data, keep alives, and acks/timeouts.
Inputs == {
    "SendData",
    "ReceiveKeepAlive",
    "ReceiveAck",
    "AckTimeout"
}

Operational == state = "PostEstablishment"

Init ==
    /\ pendingInput = NoInput
    /\ state = "PostEstablishment"
    /\ lastSendMethod = "None"

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, lastSendMethod>>

\* SOURCE: core_4.19.4.11
\* "Note that in Figure 27... the state machine is identical for GATT clients and servers with the distinction that clients send data to servers via confirmed writes, and servers send data to clients via indications."
HandleSendData ==
    /\ pendingInput = "SendData"
    /\ state = "PostEstablishment"
    /\ lastSendMethod' = IF Role = "GATTClient" THEN "ConfirmedWrite" ELSE "Indication"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.19.4.11
\* "Figure 28... shows the state machine for BTP session maintenance at the protocol level, including liveliness enforcement through keep alive messages"
HandleReceiveKeepAlive ==
    /\ pendingInput = "ReceiveKeepAlive"
    /\ state = "PostEstablishment"
    \* TODO: unspecified - exact state updates or replies for liveliness enforcement are in the figure, not the text.
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, lastSendMethod>>

\* SOURCE: core_4.19.4.11
\* "and automatic teardown if acknowledgements are received before the timeout."
\* Note: The text explicitly specifies teardown if acknowledgements are received *before* the timeout.
\* We model this exactly as written. The corresponding timeout event ("AckTimeout") is placed in Inputs 
\* but intentionally left unhandled here because the text omits what happens on timeout.
HandleReceiveAck ==
    /\ pendingInput = "ReceiveAck"
    /\ state = "PostEstablishment"
    /\ state' = "Teardown"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<lastSendMethod>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleSendData
    \/ HandleReceiveKeepAlive
    \/ HandleReceiveAck

====