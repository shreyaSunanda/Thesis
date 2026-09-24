---- MODULE PacketAcknowledgements ----
\* SOURCE: core_4.20.3.8 Packet Acknowledgements (PAFTP)
\*
\* Same modeling style/pattern as ../../ArmFailSafe.tla: a single peer's view
\* of the protocol, external occurrences injected one at a time as
\* `pendingEvent`, and an UndefinedTransition catch-all per the thesis
\* methodology (B.4.3) that fires when a pending event does not match any of
\* the transitions the spec text actually defines for the current state.
\*
\* ABSTRACTIONS (first-draft, for review):
\*  - Real PAFTP sequence numbers are unsigned 8-bit counters; here the
\*    sender's outstanding (sent, unacknowledged) packets are tracked only as
\*    a bounded COUNT (`outstanding`), not literal sequence numbers, since the
\*    spec's induction property ("ack of a given packet implies ack of all
\*    packets received prior") makes exact sequence values irrelevant to the
\*    state machine's control flow -- only "how many are still outstanding"
\*    and "is this ack for the newest one" matter.
\*  - Likewise `pendingAck` is a single boolean (not a set of received seqs)
\*    for the same cumulative/inductive-ack reason on the receive side.
\*  - Real countdown durations (PAFTP_ACK_TIMEOUT, the send-ack timer being
\*    "less than half" of it) are not modeled as clocks; only the
\*    running/not-running enable condition is modeled, same as ArmFailSafe.tla
\*    does not model FailSafeExpiry as a real clock.
\*  - MaxOutstanding bounds both the send window and the receive window
\*    (`freeSlots`) to keep the state space finite, analogous to MaxExpiry in
\*    ArmFailSafe.tla.
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
\*  sends any PAFTP packet, it SHALL start this timer if it is not already
\*  running." Piggybacking the pending ack on the outgoing packet stops the
\*  send-ack timer, since a piggybacked ack is always the current cumulative
\*  (i.e. "largest received sequence number") ack in this abstraction.
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

\* A single incoming ack is classified by state, not chosen as a separate
\* message type by the environment (an earlier draft modeled AckNewest /
\* AckOlder / InvalidAck as independently injectable events, which let TLC
\* "choose" e.g. AckNewest while outstanding = 0 -- a modeling artifact, not a
\* real spec ambiguity, since the spec fully defines the outcome for every
\* (outstanding, which-packet-is-acked) combination):
\*  - "An acknowledgement is invalid if the acknowledged sequence number does
\*    not correspond to an outstanding, unacknowledged PAFTP packet sequence
\*    number... the peer SHALL close the PAFTP session and report an error."
\*  - "A peer SHALL stop its acknowledgement-received timer if it receives an
\*    acknowledgement for its most recently sent unacknowledged packet."
\*    (cumulative ack of the newest outstanding packet clears all of them)
\*  - "A peer SHALL restart its acknowledgement-received timer when a valid
\*    acknowledgement is received for any but its most recently sent
\*    unacknowledged packet." (only possible when more than one packet is
\*    outstanding -- otherwise "newest" and "the only one" coincide)
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
\*  close the PAFTP session and report an error to the application."
AckTimeoutAction ==
    /\ pendingEvent = "AckTimeout"
    /\ state = "Open"
    /\ ackTimerRunning
    /\ state' = "Closed"
    /\ UNCHANGED <<outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots>>
    /\ pendingEvent' = NullValue

\* "When it receives any PAFTP packet, a peer SHALL record the packet's
\*  sequence number as the corresponding PAFTP session's pending
\*  acknowledgement value and start the send-acknowledgement timer if it is
\*  not already running." Folded into the same action (rather than modeled as
\* a separately injectable event) is: "If a peer detects that its receive
\* window has shrunk to two or fewer free slots, it SHALL immediately send
\* any pending acknowledgement as a stand-alone PAFTP packet" -- this is the
\* peer's own automatic reaction to receiving a packet (the only thing that
\* shrinks freeSlots), not a message the network delivers, so making it a
\* freely-injectable pendingEvent (an earlier draft did this) let TLC "fire"
\* it while the window was not actually low -- the same artifact pattern as
\* the earlier ReceiveAck/SlotFreed fixes above.
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

\* Application-layer consumption freeing a receive-window slot (not itself
\* spelled out in 4.20.3.8, but required for freeSlots to ever recover -- a
\* modeling addition, flagged for review rather than asserted as spec text).
\* Deliberately NOT routed through pendingEvent: it is not a protocol event,
\* so it must not be able to land in UndefinedTransition (an earlier draft
\* dispatched it as an event and TLC could "choose" to fire it while the
\* window was already full -- another modeling artifact, not a spec gap).
SlotFreedAction ==
    /\ state = "Open"
    /\ freeSlots < MaxOutstanding
    /\ freeSlots' = freeSlots + 1
    /\ UNCHANGED <<state, outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, pendingEvent>>

\* Once closed, the session no longer reacts to protocol events -- this is a
\* terminal state ArmFailSafe.tla did not need (it has no "Closed" analogue),
\* so unlike that model, UndefinedTransition below is scoped to state = "Open"
\* and this action absorbs events instead of flagging them as gaps.
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
    \* ReceiveAckAction is enabled for every `outstanding` value when
    \* state = "Open" (see its branch on outstanding = 0 above), so it can
    \* never be undefined by construction -- exclude it outright rather than
    \* restate its (trivially always-true) guard here.
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
