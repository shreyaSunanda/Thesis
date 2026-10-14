---- MODULE core_4_21_4_3 ----
EXTENDS Naturals

CONSTANTS NoInput

VARIABLES pendingInput, lastSentResponse, outSW1, outSW2

Inputs == {"GET_RESPONSE", "TRANSPORT_INCOMPLETE_SENT", "OTHER_RESPONSE_SENT"}

Init ==
    /\ pendingInput = NoInput
    /\ lastSentResponse = "None"
    /\ outSW1 = "None"
    /\ outSW2 = "None"

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<lastSentResponse, outSW1, outSW2>>

\* SOURCE: core_4.21.4.3 GET RESPONSE command
HandleTransportIncompleteSent ==
    /\ pendingInput = "TRANSPORT_INCOMPLETE_SENT"
    /\ lastSentResponse' = "TRANSPORT_INCOMPLETE"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<outSW1, outSW2>>

\* SOURCE: core_4.21.4.3 GET RESPONSE command
HandleOtherResponseSent ==
    /\ pendingInput = "OTHER_RESPONSE_SENT"
    /\ lastSentResponse' = "OTHER"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<outSW1, outSW2>>

\* SOURCE: core_4.21.4.3 GET RESPONSE command APDU - Table 52
HandleGetResponse_Complete ==
    /\ pendingInput = "GET_RESPONSE"
    /\ lastSentResponse = "TRANSPORT_INCOMPLETE"
    /\ outSW1' = "0x90"
    /\ outSW2' = "0x00"
    /\ lastSentResponse' = "GET_RESPONSE_COMPLETE"
    /\ pendingInput' = NoInput

\* SOURCE: core_4.21.4.3 GET RESPONSE command APDU - Table 53
HandleGetResponse_Incomplete ==
    /\ pendingInput = "GET_RESPONSE"
    /\ lastSentResponse = "TRANSPORT_INCOMPLETE"
    /\ outSW1' = "0x61"
    /\ outSW2' = "Variable" \* Spec uses "…" for SW2
    /\ lastSentResponse' = "GET_RESPONSE_INCOMPLETE"
    /\ pendingInput' = NoInput

\* SOURCE: core_4.21.4.3 GET RESPONSE command APDU - Table 54
HandleGetResponse_Error ==
    /\ pendingInput = "GET_RESPONSE"
    /\ lastSentResponse # "TRANSPORT_INCOMPLETE"
    \* TODO: unspecified - The spec says GET RESPONSE must follow a "TRANSPORT successful Response APDU - Incomplete message".
    \* It does not explicitly state if a GET RESPONSE incomplete response qualifies to allow subsequent GET RESPONSE commands for chaining.
    /\ outSW1' = "0x69"
    /\ outSW2' = "0x85"
    /\ lastSentResponse' = "GET_RESPONSE_ERROR"
    /\ pendingInput' = NoInput

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleTransportIncompleteSent
    \/ HandleOtherResponseSent
    \/ HandleGetResponse_Complete
    \/ HandleGetResponse_Incomplete
    \/ HandleGetResponse_Error

====