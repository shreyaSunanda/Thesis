---- MODULE core_4_21_4_3 ----
EXTENDS Naturals

\* Sentinel for when no input is pending
CONSTANTS NoInput

VARIABLES state, pendingInput
VARIABLES lastResponseIncomplete
VARIABLES lastResponseStatus

Inputs == {"GetResponseCommand"}

Operational == TRUE

Init ==
    /\ state = "IDLE"
    /\ pendingInput = NoInput
    \* Initialize nondeterministically to test both when GET RESPONSE follows
    \* an incomplete message and when it does not.
    /\ lastResponseIncomplete \in BOOLEAN
    /\ lastResponseStatus = [SW1 |-> "None", SW2 |-> "None"]

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, lastResponseIncomplete, lastResponseStatus>>

\* SOURCE: core_4.21.4.3 GET RESPONSE command
HandleGetResponseCommand ==
    /\ pendingInput = "GetResponseCommand"
    /\ pendingInput' = NoInput
    /\ IF lastResponseIncomplete
       THEN \/ /\ lastResponseStatus' = [SW1 |-> "0x90", SW2 |-> "0x00"]
               /\ lastResponseIncomplete' = FALSE
            \/ /\ lastResponseStatus' = [SW1 |-> "0x61", SW2 |-> "Any"]
               /\ lastResponseIncomplete' = TRUE
       ELSE /\ lastResponseStatus' = [SW1 |-> "0x69", SW2 |-> "0x85"]
            /\ UNCHANGED lastResponseIncomplete
    /\ UNCHANGED state

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleGetResponseCommand

====