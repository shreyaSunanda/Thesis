---- MODULE core_4_21_4_2 ----
EXTENDS Naturals

\* Max supported size for incoming chained messages.
CONSTANTS MaxSupportedMessageSize

\* REQUIRED: Sentinel for no pending input
CONSTANTS NoInput

VARIABLES state, pendingInput

\* Incoming Transport C-APDU fields modeled as separate variables.
\* cmdP1P2 encodes the number of octets of the full message to transmit.
VARIABLES cmdCLA, cmdP1P2, cmdLc, cmdLe

\* Internal responder state: the size of the message the responder intends to transmit back.
VARIABLES responderMessageSize

\* Output R-APDU fields modeled as variables to capture the response.
VARIABLES outSW1, outSW2, outData

\* REQUIRED: The complete list of events this section can receive.
\* The spec mentions the TRANSPORT command, and explicitly refers to the "next GET RESPONSE R-APDU".
Inputs == {"TransportCommand", "GetResponseCommand"}

Init ==
    /\ state = "Idle"
    /\ pendingInput = NoInput
    /\ cmdCLA \in {"0x80", "0x90"}
    /\ cmdP1P2 \in {10, MaxSupportedMessageSize + 10}
    /\ cmdLc \in {10}
    /\ cmdLe \in {20}
    /\ responderMessageSize \in {10, 30}
    /\ outSW1 = "None"
    /\ outSW2 = 0
    /\ outData = "None"

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, cmdCLA, cmdP1P2, cmdLc, cmdLe, responderMessageSize, outSW1, outSW2, outData>>

\* TODO: unspecified - Spec does not state how the responder should handle a malformed command where P1|P2 != Lc for an unchained command, or P1|P2 <= Lc for a chained command.
\* TODO: unspecified - Spec does not state if a successful R-APDU is generated immediately for intermediate chained C-APDUs (CLA=0x90), or only after the entire chained message is reassembled.
\* SOURCE: core_4.21.4.2 TRANSPORT command
HandleTransportCommand ==
    /\ pendingInput = "TransportCommand"
    /\ IF cmdP1P2 > MaxSupportedMessageSize
       THEN /\ outSW1' = "0x6A"
            /\ outSW2' = 132 \* 0x84 in decimal
            /\ outData' = "None"
       ELSE
            IF responderMessageSize <= cmdLe
            THEN /\ outSW1' = "0x90"
                 /\ outSW2' = 0 \* 0x00
                 /\ outData' = "MessageOrLastFragment"
            ELSE /\ outSW1' = "0x61"
                 /\ outSW2' = responderMessageSize - cmdLe
                 \* TODO: unspecified - SW2 is a single byte. Spec does not state how to encode if the remaining bytes (responderMessageSize - cmdLe) > 255.
                 /\ outData' = "Fragment"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, cmdCLA, cmdP1P2, cmdLc, cmdLe, responderMessageSize>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleTransportCommand

====