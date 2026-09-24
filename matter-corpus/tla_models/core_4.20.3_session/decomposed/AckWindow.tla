---- MODULE AckWindow ----
\* Decomposition of ../PAFTPSessionNaive.tla, piece 2 of 3: the ack/window
\* subsystem (core_4.20.3.7/.8) plus shutdown (core_4.20.3.10), assuming the
\* handshake has already succeeded.
\*
\* WHY THIS SPLIT IS SOUND: in the naive model, {outstanding, ackTimerRunning,
\* pendingAck, sendAckTimerRunning, freeSlots} are never read or written by
\* any SDU-subsystem action (SendSDUAction, SDUCompleteAction,
\* ReceiveBeginSegmentAction, ReceiveMidSegmentAction, ReceiveEndSegmentAction
\* touch only sduInProgress/queueLen/reassemblyInProgress), and vice versa --
\* the two subsystems share no variables and no guard ever references the
\* other's state. That is the textbook precondition for checking them as
\* independent components: the reachable (ackWindowVars, sduVars) pairs are
\* exactly the Cartesian product of each subsystem's own reachable values, so
\* checking each alone finds every reachable local state, and NeverUndefined
\* for the whole system holds iff it holds in EACH piece separately -- unlike
\* the uploaded guide's method, nothing here is sampled or approximated.
\*
\* THE HANDOFF FROM Handshake.tla: every Handshake outcome that reaches
\* "Established" resets these variables to the SAME fixed values (0 / FALSE /
\* FALSE / FALSE / MaxOutstanding) regardless of which nondeterministic
\* branch fired in ReceiveHandshakeResponseAction -- there is only one
\* possible handoff value here, so Init below does not need to range over
\* anything to stay sound.
\*
\* Events includes HandshakeEvents (not just this subsystem's own five) so
\* that a STALE handshake-phase notification arriving after we're already
\* Established -- the naive model's other genuine cross-phase finding --
\* is still checked here. It deliberately does NOT include the SDU
\* subsystem's own event names: those are a different subsystem's concern,
\* and treating them as "undefined here" would be a false positive purely
\* from decomposition, exactly like the ReceiveAck/SlotFreed/WindowLow
\* artifacts caught and fixed in ../../core_4.20.3.8/PacketAcknowledgements.tla.
EXTENDS Naturals

CONSTANTS MaxOutstanding, NullValue

VARIABLES status, outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots, pendingEvent

HandshakeEvents == {"ReceiveHandshakeResponse", "HandshakeTimeout"}
OwnEvents == {"SendPacket", "ReceiveAck", "AckTimeout", "ReceivePacket", "SendAckTimeout", "AppCloseSession"}
Events == HandshakeEvents \cup OwnEvents

vars == <<status, outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots, pendingEvent>>

Init ==
    /\ status = "Established"
    /\ outstanding = 0
    /\ ackTimerRunning = FALSE
    /\ pendingAck = FALSE
    /\ sendAckTimerRunning = FALSE
    /\ freeSlots = MaxOutstanding
    /\ pendingEvent = NullValue

SendPacketAction ==
    /\ pendingEvent = "SendPacket"
    /\ status = "Established"
    /\ outstanding < MaxOutstanding
    /\ outstanding' = outstanding + 1
    /\ ackTimerRunning' = TRUE
    /\ IF pendingAck
           THEN /\ pendingAck' = FALSE
                /\ sendAckTimerRunning' = FALSE
           ELSE UNCHANGED <<pendingAck, sendAckTimerRunning>>
    /\ UNCHANGED <<status, freeSlots>>
    /\ pendingEvent' = NullValue

ReceiveAckAction ==
    /\ pendingEvent = "ReceiveAck"
    /\ status = "Established"
    /\ pendingEvent' = NullValue
    /\ UNCHANGED <<pendingAck, sendAckTimerRunning, freeSlots>>
    /\ \/ /\ outstanding = 0
          /\ status' = "Closed"
          /\ UNCHANGED <<outstanding, ackTimerRunning>>
       \/ /\ outstanding > 0
          /\ status' = "Established"
          /\ \E ackedIsNewest \in BOOLEAN :
                /\ ackedIsNewest \/ outstanding > 1
                /\ IF ackedIsNewest
                       THEN /\ outstanding' = 0
                            /\ ackTimerRunning' = FALSE
                       ELSE /\ outstanding' = outstanding - 1
                            /\ ackTimerRunning' = TRUE

AckTimeoutAction ==
    /\ pendingEvent = "AckTimeout"
    /\ status = "Established"
    /\ ackTimerRunning
    /\ status' = "Closed"
    /\ UNCHANGED <<outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots>>
    /\ pendingEvent' = NullValue

ReceivePacketAction ==
    /\ pendingEvent = "ReceivePacket"
    /\ status = "Established"
    /\ freeSlots > 0
    /\ freeSlots' = freeSlots - 1
    /\ IF freeSlots - 1 <= 2
           THEN /\ pendingAck' = FALSE
                /\ sendAckTimerRunning' = FALSE
           ELSE /\ pendingAck' = TRUE
                /\ sendAckTimerRunning' = TRUE
    /\ UNCHANGED <<status, outstanding, ackTimerRunning>>
    /\ pendingEvent' = NullValue

SendAckTimeoutAction ==
    /\ pendingEvent = "SendAckTimeout"
    /\ status = "Established"
    /\ sendAckTimerRunning
    /\ pendingAck
    /\ pendingAck' = FALSE
    /\ sendAckTimerRunning' = FALSE
    /\ UNCHANGED <<status, outstanding, ackTimerRunning, freeSlots>>
    /\ pendingEvent' = NullValue

SlotFreedAction ==
    /\ status = "Established"
    /\ freeSlots < MaxOutstanding
    /\ freeSlots' = freeSlots + 1
    /\ UNCHANGED <<status, outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, pendingEvent>>

AppCloseSessionAction ==
    /\ pendingEvent = "AppCloseSession"
    /\ status = "Established"
    /\ status' = "Closed"
    /\ UNCHANGED <<outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots>>
    /\ pendingEvent' = NullValue

ClosedStatusIgnoresEvent ==
    /\ pendingEvent # NullValue
    /\ status = "Closed"
    /\ pendingEvent' = NullValue
    /\ UNCHANGED <<status, outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots>>

ReceiveEvent(e) ==
    /\ pendingEvent = NullValue
    /\ pendingEvent' = e
    /\ UNCHANGED <<status, outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots>>

UndefinedTransition ==
    /\ pendingEvent # NullValue
    \* status # "Closed" (not "= Established") so this stays enabled once
    \* status = "Undefined" too -- a self-loop, matching how the naive
    \* model's own UndefinedTransition avoids deadlocking after the first
    \* violation (see ../PAFTPSessionNaive.tla).
    /\ status # "Closed"
    \* Stale handshake-phase notification arriving after we're already
    \* Established -- always undefined here, this subsystem has no action
    \* for either handshake event.
    /\ ~ (pendingEvent = "SendPacket" /\ outstanding < MaxOutstanding)
    /\ pendingEvent # "ReceiveAck"
    /\ ~ (pendingEvent = "AckTimeout" /\ ackTimerRunning)
    /\ ~ (pendingEvent = "ReceivePacket" /\ freeSlots > 0)
    /\ ~ (pendingEvent = "SendAckTimeout" /\ sendAckTimerRunning /\ pendingAck)
    /\ pendingEvent # "AppCloseSession"
    /\ status' = "Undefined"
    /\ UNCHANGED <<outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots, pendingEvent>>

Next ==
    \/ SendPacketAction \/ ReceiveAckAction \/ AckTimeoutAction \/ ReceivePacketAction
    \/ SendAckTimeoutAction \/ SlotFreedAction \/ AppCloseSessionAction \/ ClosedStatusIgnoresEvent
    \/ (\E e \in Events : ReceiveEvent(e))
    \/ UndefinedTransition

Spec == Init /\ [][Next]_vars

NeverUndefined == status # "Undefined"

====
