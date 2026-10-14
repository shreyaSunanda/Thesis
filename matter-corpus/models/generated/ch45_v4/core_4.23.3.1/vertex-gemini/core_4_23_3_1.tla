---- MODULE core_4_23_3_1 ----
EXTENDS Naturals

\* Maximum number of retransmissions for the DNS Announcement.
\* Real value per spec: 3.
CONSTANTS MaxRetransmissions

\* Sentinel for no pending input.
CONSTANTS NoInput

VARIABLES state, pendingInput, retransmitCount

Inputs == {
    "SelectJoinerRouter",
    "ReceiveCommissioningMessage",
    "ReceiveDNSAnnouncementResponse", \* Explicitly mentioned as not expected, included to test if it arrives
    "Timeout5000ms",
    "Timeout1250ms"
}

Operational == state # "Uninitialized"

Init ==
    /\ state = "Uninitialized"
    /\ retransmitCount = 0
    /\ pendingInput = NoInput

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, retransmitCount>>

\* SOURCE: core_4.23.3.1 Upon selecting a Joiner Router, the Commissionee SHALL use a DNS Announcement to make itself discoverable.
HandleSelectJoinerRouter ==
    /\ pendingInput = "SelectJoinerRouter"
    /\ state \in {"Uninitialized", "FindingNewJoinerRouter"}
    /\ state' = "WaitingInitial"
    /\ retransmitCount' = 0
    /\ pendingInput' = NoInput

\* SOURCE: core_4.23.3.1 After sending the DNS Announcement, the Commissionee SHALL await an incoming commissioning message
HandleReceiveCommissioningMessage ==
    /\ pendingInput = "ReceiveCommissioningMessage"
    /\ state \in {"WaitingInitial", "WaitingRetransmission"}
    /\ state' = "SessionEstablished"
    /\ UNCHANGED retransmitCount
    /\ pendingInput' = NoInput

\* SOURCE: core_4.23.3.1 If the commissioning session does not begin to be established within that time window [5000ms], the device SHOULD retransmit the DNS Announcement.
HandleTimeoutInitial ==
    /\ pendingInput = "Timeout5000ms"
    /\ state = "WaitingInitial"
    /\ state' = "WaitingRetransmission"
    /\ retransmitCount' = 1
    /\ pendingInput' = NoInput

\* SOURCE: core_4.23.3.1 The device SHOULD retransmit the DNS Announcement up to 3 times with a 1250 millisecond interval between retransmissions.
HandleTimeoutRetransmission ==
    /\ pendingInput = "Timeout1250ms"
    /\ state = "WaitingRetransmission"
    /\ retransmitCount < MaxRetransmissions
    /\ retransmitCount' = retransmitCount + 1
    /\ state' = "WaitingRetransmission"
    /\ pendingInput' = NoInput

\* SOURCE: core_4.23.3.1 If after the retransmissions the commissioning session still does not begin to be established, the device SHOULD attempt to find a different Joiner Router
HandleMaxRetransmissionsReached ==
    /\ pendingInput = "Timeout1250ms"
    /\ state = "WaitingRetransmission"
    /\ retransmitCount = MaxRetransmissions
    /\ state' = "FindingNewJoinerRouter"
    /\ retransmitCount' = 0
    /\ pendingInput' = NoInput

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleSelectJoinerRouter
    \/ HandleReceiveCommissioningMessage
    \/ HandleTimeoutInitial
    \/ HandleTimeoutRetransmission
    \/ HandleMaxRetransmissionsReached

====