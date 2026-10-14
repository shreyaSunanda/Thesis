---- MODULE core_4_23_3_1 ----
EXTENDS Naturals

\* Max number of retransmissions for the DNS Announcement. 
\* Spec says: "up to 3 times"
CONSTANTS MaxRetransmissions

\* Timeouts mentioned in the spec (for context/documentation, though timeouts
\* are modeled as spontaneous events via pendingInput).
\* 5000 milliseconds: wait before first retransmit
CONSTANTS InitialWaitMs
\* 1250 milliseconds: wait between subsequent retransmissions
CONSTANTS RetransmitIntervalMs

\* REQUIRED - standard input sentinel
CONSTANTS NoInput

VARIABLES state
VARIABLES retransmitCount
VARIABLES pendingInput

\* Complete list of events this section can receive
Inputs == {
    "SelectJoinerRouter",
    "CommissioningMessageReceived",
    "InitialTimeoutExpired",
    "RetransmitTimeoutExpired"
}

Init ==
    /\ state = "Idle"
    /\ retransmitCount = 0
    /\ pendingInput = NoInput

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, retransmitCount>>

\* SOURCE: core_4.23.3.1 "Upon selecting a Joiner Router, the Commissionee SHALL use a DNS Announcement to make itself discoverable... The Commissionee SHALL send an unsolicited DNS Query Response message"
HandleSelectJoinerRouter ==
    /\ pendingInput = "SelectJoinerRouter"
    /\ state \in {"Idle", "SearchingRouter"}
    /\ state' = "WaitingInitial"
    /\ retransmitCount' = 0
    /\ pendingInput' = NoInput

\* SOURCE: core_4.23.3.1 "After sending the DNS Announcement, the Commissionee SHALL await an incoming commissioning message (see Section 4.14.1, “Passcode-Authenticated Session Establishment (PASE)”) for no less than 5000 milliseconds."
HandleCommissioningMessage ==
    /\ pendingInput = "CommissioningMessageReceived"
    /\ state \in {"WaitingInitial", "WaitingRetransmit"}
    /\ state' = "SessionEstablishing"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<retransmitCount>>

\* SOURCE: core_4.23.3.1 "If the commissioning session does not begin to be established within that time window, the device SHOULD retransmit the DNS Announcement."
HandleInitialTimeout ==
    /\ pendingInput = "InitialTimeoutExpired"
    /\ state = "WaitingInitial"
    /\ state' = "WaitingRetransmit"
    /\ retransmitCount' = 1
    /\ pendingInput' = NoInput

\* SOURCE: core_4.23.3.1 "The device SHOULD retransmit the DNS Announcement up to 3 times with a 1250 millisecond interval between retransmissions. If after the retransmissions the commissioning session still does not begin to be established, the device SHOULD attempt to find a different Joiner Router"
HandleRetransmitTimeout ==
    /\ pendingInput = "RetransmitTimeoutExpired"
    /\ state = "WaitingRetransmit"
    /\ pendingInput' = NoInput
    /\ \/ /\ retransmitCount < MaxRetransmissions
          /\ state' = "WaitingRetransmit"
          /\ retransmitCount' = retransmitCount + 1
       \/ /\ retransmitCount >= MaxRetransmissions
          /\ state' = "SearchingRouter"
          /\ retransmitCount' = 0

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleSelectJoinerRouter
    \/ HandleCommissioningMessage
    \/ HandleInitialTimeout
    \/ HandleRetransmitTimeout

====