---- MODULE PacketAcknowledgements ----
\* SOURCE: core_4.19.4.8 Packet Acknowledgements (BTP)
\*
\* This section's spec text is the BTP (Bluetooth Transport Protocol) analogue
\* of core_4.20.3.8 (the PAFTP/Wi-Fi transport binding): the paragraphs are
\* the same design template with "BTP"/"BTP_ACK_TIMEOUT" substituted for
\* "PAFTP"/"PAFTP_ACK_TIMEOUT". The state machine is therefore identical to
\* ../core_4.20.3.8/PacketAcknowledgements.tla; see that file's header for the
\* full rationale of every modeling choice and the artifact fixes that led to
\* this shape (ReceiveAck merged into one event, WindowLow folded into
\* ReceivePacket, SlotFreed pulled out of pendingEvent dispatch). This is
\* deliberately NOT re-derived from scratch: since the underlying design
\* pattern recurs verbatim across transport bindings, the same underspecified
\* transition (a stale AckTimeout notification arriving after the
\* acknowledgement-received timer was already stopped) is a candidate
\* cross-cutting gap in Matter's shared "acknowledgement timer" pattern, not a
\* one-off in a single transport's wording -- worth noting for the thesis.
EXTENDS Naturals

CONSTANTS MaxOutstanding, NullValue

VARIABLES
    state,               \* "Open" | "Closed" | "Undefined"
    outstanding,         \* count of sent, not-yet-acknowledged packets (sender side)
    ackTimerRunning,     \* acknowledgement-received timer (sender side)
    pendingAck,          \* TRUE if we owe the remote peer a cumulative ack (receiver side)
    sendAckTimerRunning, \* send-acknowledgement timer (receiver side)
    freeSlots,           \* free slots in our receive window
    pendingEvent

Events == {"SendPacket", "ReceiveAck", "AckTimeout",
           "ReceivePacket", "SendAckTimeout"}

vars == <<state, outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning,
           freeSlots, pendingEvent>>

Init ==
    /\ state = "Open"
    /\ outstanding = 0
    /\ ackTimerRunning = FALSE
    /\ pendingAck = FALSE
    /\ sendAckTimerRunning = FALSE
    /\ freeSlots = MaxOutstanding
    /\ pendingEvent = NullValue

\* "Each peer SHALL maintain an acknowledgement-received timer. When a peer
\*  sends any BTP packet, it SHALL start this timer if it is not already
\*  running."
SendPacketAction ==
    /\ pendingEvent = "SendPacket"
    /\ state = "Open"
    /\ outstanding < MaxOutstanding
    /\ outstanding' = outstanding + 1
    /\ ackTimerRunning' = TRUE
    /\ IF pendingAck
           THEN /\ pendingAck' = FALSE
                /\ sendAckTimerRunning' = FALSE
           ELSE UNCHANGED <<pendingAck, sendAckTimerRunning>>
    /\ UNCHANGED <<state, freeSlots>>
    /\ pendingEvent' = NullValue

\* Single incoming-ack event, classified by state (see core_4.20.3.8's
\* header comment on ReceiveAckAction for why this must not be split into
\* separately-injectable AckNewest/AckOlder/InvalidAck events):
\*  - "An acknowledgement is invalid if the acknowledged sequence number does
\*    not correspond to an outstanding, unacknowledged BTP packet sequence
\*    number... the peer SHALL close the BTP session and report an error."
\*  - "A peer SHALL stop its acknowledgement-received timer if it receives an
\*    acknowledgement for its most recently sent unacknowledged packet."
\*  - "A peer SHALL restart its acknowledgement-received timer when a valid
\*    acknowledgement is received for any but its most recently sent
\*    unacknowledged packet."
ReceiveAckAction ==
    /\ pendingEvent = "ReceiveAck"
    /\ state = "Open"
    /\ pendingEvent' = NullValue
    /\ UNCHANGED <<pendingAck, sendAckTimerRunning, freeSlots>>
    /\ \/ /\ outstanding = 0
          /\ state' = "Closed"
          /\ UNCHANGED <<outstanding, ackTimerRunning>>
       \/ /\ outstanding > 0
          /\ state' = "Open"
          /\ \E ackedIsNewest \in BOOLEAN :
                /\ ackedIsNewest \/ outstanding > 1
                /\ IF ackedIsNewest
                       THEN /\ outstanding' = 0
                            /\ ackTimerRunning' = FALSE
                       ELSE /\ outstanding' = outstanding - 1
                            /\ ackTimerRunning' = TRUE

\* "If a peer's acknowledgement-received timer expires... the peer SHALL
\*  close the BTP session and report an error to the application."
AckTimeoutAction ==
    /\ pendingEvent = "AckTimeout"
    /\ state = "Open"
    /\ ackTimerRunning
    /\ state' = "Closed"
    /\ UNCHANGED <<outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots>>
    /\ pendingEvent' = NullValue

\* "When it receives any BTP packet, a peer SHALL record the packet's
\*  sequence number as the corresponding BTP session's pending
\*  acknowledgement value and start the send-acknowledgement timer if it is
\*  not already running." Window-low flush folded in as in core_4.20.3.8 (see
\* that file's header comment on ReceivePacketAction for why).
ReceivePacketAction ==
    /\ pendingEvent = "ReceivePacket"
    /\ state = "Open"
    /\ freeSlots > 0
    /\ freeSlots' = freeSlots - 1
    /\ IF freeSlots - 1 <= 2
           THEN /\ pendingAck' = FALSE        \* immediately flushed as a stand-alone ack
                /\ sendAckTimerRunning' = FALSE
           ELSE /\ pendingAck' = TRUE
                /\ sendAckTimerRunning' = TRUE
    /\ UNCHANGED <<state, outstanding, ackTimerRunning>>
    /\ pendingEvent' = NullValue

\* "If this timer expires and the peer has a pending acknowledgement, the
\*  peer SHALL immediately send that acknowledgement."
SendAckTimeoutAction ==
    /\ pendingEvent = "SendAckTimeout"
    /\ state = "Open"
    /\ sendAckTimerRunning
    /\ pendingAck
    /\ pendingAck' = FALSE
    /\ sendAckTimerRunning' = FALSE
    /\ UNCHANGED <<state, outstanding, ackTimerRunning, freeSlots>>
    /\ pendingEvent' = NullValue

\* Application-layer consumption freeing a receive-window slot (a modeling
\* addition, not spec text -- see core_4.20.3.8's header comment on this
\* action for why it is deliberately NOT routed through pendingEvent).
SlotFreedAction ==
    /\ state = "Open"
    /\ freeSlots < MaxOutstanding
    /\ freeSlots' = freeSlots + 1
    /\ UNCHANGED <<state, outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, pendingEvent>>

\* Once closed, the session no longer reacts to protocol events.
ClosedSessionIgnoresEvent ==
    /\ pendingEvent # NullValue
    /\ state = "Closed"
    /\ pendingEvent' = NullValue
    /\ UNCHANGED <<state, outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots>>

ReceiveEvent(e) ==
    /\ pendingEvent = NullValue
    /\ pendingEvent' = e
    /\ UNCHANGED <<state, outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots>>

\* Catch-all per the thesis methodology (B.4.3): reached when a pending event
\* matches none of the (state, event) transitions the spec text above defines.
\* If TLC finds this reachable, that IS a formal gap worth reviewing.
UndefinedTransition ==
    /\ pendingEvent # NullValue
    /\ state = "Open"
    /\ ~ (pendingEvent = "SendPacket" /\ outstanding < MaxOutstanding)
    /\ pendingEvent # "ReceiveAck"
    /\ ~ (pendingEvent = "AckTimeout" /\ ackTimerRunning)
    /\ ~ (pendingEvent = "ReceivePacket" /\ freeSlots > 0)
    /\ ~ (pendingEvent = "SendAckTimeout" /\ sendAckTimerRunning /\ pendingAck)
    /\ state' = "Undefined"
    /\ UNCHANGED <<outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots, pendingEvent>>

Next ==
    \/ SendPacketAction \/ ReceiveAckAction
    \/ AckTimeoutAction \/ ReceivePacketAction \/ SendAckTimeoutAction
    \/ SlotFreedAction \/ ClosedSessionIgnoresEvent
    \/ (\E e \in Events : ReceiveEvent(e))
    \/ UndefinedTransition

Spec == Init /\ [][Next]_vars

\* Invariant checked by TLC (see the .cfg file): should NEVER be violated if
\* this model is complete.
NeverUndefined == state # "Undefined"

====
