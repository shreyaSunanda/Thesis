---- MODULE core_4_20_3_11 ----
EXTENDS Naturals

CONSTANTS NoInput

VARIABLES state, pendingInput

\* The specification text directly mentions keep alive messages, acknowledgements,
\* and timeouts in relation to the state diagrams.
Inputs == {"KeepAlive", "Acknowledgement", "Timeout"}

\* TRUE when the device is actively in a state evaluated by the Figure 35 lifecycle.
Operational == state \in {"PostEstablishment", "TornDown"}

\* TODO: unspecified - The actual states and transitions for the PAFTP session lifecycle 
\* (Figures 33, 34) and post-establishment maintenance (Figure 35) are embedded entirely 
\* within image figures in the specification. The initialization and core structure are 
\* omitted from the text, so a generic "PostEstablishment" state is assumed as a starting point.
Init ==
    /\ state = "PostEstablishment"
    /\ pendingInput = NoInput

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.20.3.11 Protocol State Diagrams
\* "including liveliness enforcement through keep alive messages"
HandleKeepAlive ==
    /\ pendingInput = "KeepAlive"
    /\ pendingInput' = NoInput
    \* TODO: unspecified - The exact state changes or timers updated by keep alive messages 
    \* are locked in the Figure 35 image and not described in text.
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.20.3.11 Protocol State Diagrams
\* "automatic teardown if acknowledgements are received before the timeout."
HandleAcknowledgement ==
    /\ pendingInput = "Acknowledgement"
    /\ pendingInput' = NoInput
    \* Note: the spec text literally states teardown happens IF acknowledgements are received 
    \* before the timeout. This is modeled exactly as written, despite likely being a typo 
    \* for "not received".
    /\ state' = "TornDown"

\* SOURCE: core_4.20.3.11 Protocol State Diagrams
\* Implicitly mentioned via "before the timeout".
HandleTimeout ==
    /\ pendingInput = "Timeout"
    /\ pendingInput' = NoInput
    \* TODO: unspecified - The behavior occurring upon the timeout itself is not detailed 
    \* in the text, only the teardown triggered by the acknowledgement preceding it.
    /\ UNCHANGED <<state>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleKeepAlive
    \/ HandleAcknowledgement
    \/ HandleTimeout

====