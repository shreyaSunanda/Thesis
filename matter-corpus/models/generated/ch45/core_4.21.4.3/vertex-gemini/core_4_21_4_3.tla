---- MODULE core_4_21_4_3 ----
EXTENDS Naturals

\* Frame Size for proximity coupling Device (ISO-DEP). Real value is typically 18-256.
CONSTANTS FSD

\* Maximum size of a complete message before fragmentation. 
\* Should be kept small for model checking (e.g., 512).
CONSTANTS MaxMessageSize

VARIABLES 
    commissioneeState,
    remainingDataLen,
    lastResponseAPDU

\* Helper for min function used in Le calculation
Min(a, b) == IF a < b THEN a ELSE b

\* Le SHOULD encode the value equal to min(256,FSD-6)
OptimalLe == Min(256, FSD - 6)

\* Command APDU Definition (Table 51)
GetResponseCmd(le) == [cla |-> "0x00", ins |-> "0xC0", p1 |-> "0x00", p2 |-> "0x00", le |-> le]

\* Response APDU Definitions (Tables 52, 53, 54)
CompleteResp(len) == [sw1 |-> "0x90", sw2 |-> "0x00", dataLen |-> len]
IncompleteResp(len) == [sw1 |-> "0x61", sw2 |-> "...", dataLen |-> len]
ErrorResp == [sw1 |-> "0x69", sw2 |-> "0x85", dataLen |-> 0]
TransportIncompleteResp == [sw1 |-> "0x61", sw2 |-> "...", dataLen |-> 0]

Init ==
    /\ commissioneeState = "Idle"
    /\ remainingDataLen = 0
    /\ lastResponseAPDU = [sw1 |-> "None", sw2 |-> "None", dataLen |-> 0]

\* Helper action to establish the required precondition for a successful GET RESPONSE
\* SOURCE: core_4.21.4.3 (context: "following a TRANSPORT successful Response APDU - Incomplete message")
ReceiveTransportCommandWithIncompleteResponse ==
    \E dataLen \in 1..MaxMessageSize :
        /\ commissioneeState = "Idle"
        /\ commissioneeState' = "PendingIncomplete"
        /\ remainingDataLen' = dataLen
        /\ lastResponseAPDU' = TransportIncompleteResp

\* Main logic for receiving and processing a GET RESPONSE command
\* SOURCE: core_4.21.4.3 GET RESPONSE command
CommissioneeHandlesGetResponse ==
    \E le \in 1..256 :
        \/ /\ commissioneeState = "PendingIncomplete"
           /\ IF remainingDataLen <= le
              THEN /\ commissioneeState' = "Idle"
                   /\ remainingDataLen' = 0
                   /\ lastResponseAPDU' = CompleteResp(remainingDataLen)
              ELSE /\ commissioneeState' = "PendingIncomplete"
                   /\ remainingDataLen' = remainingDataLen - le
                   /\ lastResponseAPDU' = IncompleteResp(le)
        \/ /\ commissioneeState # "PendingIncomplete"
           /\ lastResponseAPDU' = ErrorResp
           /\ UNCHANGED <<commissioneeState, remainingDataLen>>

Next == 
    \/ ReceiveTransportCommandWithIncompleteResponse
    \/ CommissioneeHandlesGetResponse

====