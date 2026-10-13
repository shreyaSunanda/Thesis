---- MODULE core_4_20_3_11 ----
EXTENDS Naturals

VARIABLES state, messages, ackReceived, timeoutExpired

Init == 
    /\ state = "PostEstablishment"
    /\ messages = {}
    /\ ackReceived \in BOOLEAN
    /\ timeoutExpired \in BOOLEAN

\* TODO: unspecified - State machines for PAFTP session management of Commissioner (Figure 33) 
\* and Commissionable Device (Figure 34) are only provided in figures, with no transitions 
\* described in the text.

\* SOURCE: core_4.20.3.11 Protocol State Diagrams
\* "including liveliness enforcement through keep alive messages"
\* TODO: unspecified - The full state machine for Figure 35 is missing from the text, 
\* so the exact conditions for sending Keep Alive messages are unspecified.
SendKeepAlive ==
    /\ state = "PostEstablishment"
    /\ messages' = messages \union {"KeepAlive"}
    /\ UNCHANGED <<state, ackReceived, timeoutExpired>>

\* SOURCE: core_4.20.3.11 Protocol State Diagrams
\* "automatic teardown if acknowledgements are received before the timeout"
Teardown ==
    /\ state = "PostEstablishment"
    /\ ackReceived = TRUE
    /\ timeoutExpired = FALSE
    /\ state' = "Teardown"
    /\ UNCHANGED <<messages, ackReceived, timeoutExpired>>

Next == SendKeepAlive \/ Teardown

====