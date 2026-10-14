---- MODULE core_4_20_3_11 ----
EXTENDS Naturals

\* Note: The spec text references Figure 33 and Figure 34 for the Commissioner and 
\* Commissionable Device PAFTP session lifecycles, but describes no explicit states, 
\* events, or transitions for them. Per Rule 1, these have not been invented. 
\* The text only provides limited details for the post-establishment state machine.

CONSTANTS NoInput
VARIABLES state, pendingInput

Inputs == {"KeepAlive", "Ack", "Timeout"}

Init ==
    /\ state = "PostEstablishment"
    /\ pendingInput = NoInput

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.20.3.11 Figure 35
HandleKeepAlive ==
    /\ pendingInput = "KeepAlive"
    /\ state = "PostEstablishment"
    \* TODO: unspecified - the text mentions liveliness enforcement through keep alive messages but omits the exact state logic
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.20.3.11 Figure 35
HandleAck ==
    /\ pendingInput = "Ack"
    /\ state = "PostEstablishment"
    \* Text literally states: "automatic teardown if acknowledgements are received before the timeout."
    \* (This is likely a spec typo for "not received", but modeled as written per Rule 1)
    /\ state' = "Teardown"
    /\ pendingInput' = NoInput

\* SOURCE: core_4.20.3.11 Figure 35
HandleTimeout ==
    /\ pendingInput = "Timeout"
    /\ state = "PostEstablishment"
    \* TODO: unspecified - text implies timeout plays a role but does not describe explicit timeout behavior
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleKeepAlive
    \/ HandleAck
    \/ HandleTimeout

====