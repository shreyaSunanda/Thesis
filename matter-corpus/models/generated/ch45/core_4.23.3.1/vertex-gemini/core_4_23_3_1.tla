---- MODULE core_4_23_3_1 ----
EXTENDS Naturals

\* 5000 milliseconds initial wait for a commissioning message
CONSTANTS INITIAL_WAIT_MS

\* 1250 milliseconds interval between retransmissions
CONSTANTS RETRANSMIT_WAIT_MS

\* Up to 3 retransmissions
CONSTANTS MAX_RETRANSMITS

\* Destination UDP port MJ as specified in the Discovery Response message
CONSTANTS JoinerRouterPortMJ

\* Sentinel value for no network message sent
CONSTANTS NoneMessage

VARIABLES 
    state,
    retransmitCount,
    timePassedMs,
    networkMessage

Init ==
    /\ state = "IDLE"
    /\ retransmitCount = 0
    /\ timePassedMs = 0
    /\ networkMessage = NoneMessage

\* SOURCE: core_4.23.3.1 Upon selecting a Joiner Router, the Commissionee SHALL use a DNS Announcement to make itself discoverable. The Commissionee SHALL send an unsolicited DNS Query Response message with Transaction ID 0. This message SHALL contain information as specified in Section 4.3.1 ... sent to the link-local address of the Joiner Router, with the destination UDP port MJ ... No response to this message is expected from the Commissioner.
SelectJoinerRouter ==
    /\ state = "IDLE"
    /\ networkMessage' = [
           type |-> "DNS_Announcement",
           transactionId |-> 0,
           containsCommissionableNodeDiscoveryInfo |-> TRUE,
           destinationAddress |-> "LinkLocal",
           destinationPort |-> JoinerRouterPortMJ
       ]
    /\ state' = "AWAITING_COMMISSIONING"
    /\ retransmitCount' = 0
    /\ timePassedMs' = 0

\* Helper action to model the passage of time necessary for timeouts
AdvanceTime ==
    /\ state \in {"AWAITING_COMMISSIONING", "RETRANSMITTING"}
    /\ \E step \in 1..1000 : timePassedMs' = timePassedMs + step
    /\ UNCHANGED << state, retransmitCount, networkMessage >>

\* SOURCE: core_4.23.3.1 After sending the DNS Announcement, the Commissionee SHALL await an incoming commissioning message (see Section 4.14.1...) for no less than 5000 milliseconds. If the commissioning session does not begin to be established within that time window, the device SHOULD retransmit the DNS Announcement.
InitialTimeoutRetransmit ==
    /\ state = "AWAITING_COMMISSIONING"
    /\ timePassedMs >= INITIAL_WAIT_MS
    /\ retransmitCount < MAX_RETRANSMITS
    /\ networkMessage' = [
           type |-> "DNS_Announcement",
           transactionId |-> 0,
           containsCommissionableNodeDiscoveryInfo |-> TRUE,
           destinationAddress |-> "LinkLocal",
           destinationPort |-> JoinerRouterPortMJ
       ]
    /\ state' = "RETRANSMITTING"
    /\ retransmitCount' = retransmitCount + 1
    /\ timePassedMs' = 0

\* SOURCE: core_4.23.3.1 The device SHOULD retransmit the DNS Announcement up to 3 times with a 1250 millisecond interval between retransmissions.
SubsequentRetransmit ==
    /\ state = "RETRANSMITTING"
    /\ timePassedMs >= RETRANSMIT_WAIT_MS
    /\ retransmitCount < MAX_RETRANSMITS
    /\ networkMessage' = [
           type |-> "DNS_Announcement",
           transactionId |-> 0,
           containsCommissionableNodeDiscoveryInfo |-> TRUE,
           destinationAddress |-> "LinkLocal",
           destinationPort |-> JoinerRouterPortMJ
       ]
    /\ retransmitCount' = retransmitCount + 1
    /\ timePassedMs' = 0
    /\ UNCHANGED << state >>

\* SOURCE: core_4.23.3.1 If after the retransmissions the commissioning session still does not begin to be established, the device SHOULD attempt to find a different Joiner Router using the procedure described in the subsection above.
FindDifferentJoinerRouter ==
    /\ state = "RETRANSMITTING"
    /\ timePassedMs >= RETRANSMIT_WAIT_MS
    /\ retransmitCount = MAX_RETRANSMITS
    /\ state' = "FINDING_NEW_ROUTER"
    /\ UNCHANGED << retransmitCount, timePassedMs, networkMessage >>

\* SOURCE: core_4.23.3.1 incoming commissioning message (see Section 4.14.1, “Passcode-Authenticated Session Establishment (PASE)”)
EstablishCommissioningSession ==
    /\ state \in {"AWAITING_COMMISSIONING", "RETRANSMITTING"}
    /\ state' = "COMMISSIONING_ESTABLISHED"
    /\ UNCHANGED << retransmitCount, timePassedMs, networkMessage >>

Next ==
    \/ SelectJoinerRouter
    \/ AdvanceTime
    \/ InitialTimeoutRetransmit
    \/ SubsequentRetransmit
    \/ FindDifferentJoinerRouter
    \/ EstablishCommissioningSession

====