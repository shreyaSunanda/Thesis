---- MODULE Handshake ----
\* Decomposition of ../PAFTPSessionNaive.tla, piece 1 of 3: the Handshake
\* phase only (core_4.20.3.1/.2/.3).
\*
\* WHY THIS SPLIT IS SOUND: PAFTPSessionNaive's Handshake actions
\* (ReceiveHandshakeResponseAction, HandshakeTimeoutAction) are gated purely
\* on `phase = "Handshake"`, and every OTHER action in the naive model is
\* gated on `phase = "Established"` -- none of them reference
\* handshakeTimerRunning, and none of the Established-side variables
\* (outstanding, freeSlots, sduInProgress, ...) affect whether a Handshake
\* action -- or the catch-all -- is enabled. So this submodule reproduces
\* every naive-model transition and UndefinedTransition case that involves
\* phase = "Handshake" WITHOUT needing any of those other variables at all --
\* nothing is approximated or sampled, this is an exact projection.
\*
\* Events is deliberately the FULL union from the naive model (not just this
\* phase's own two events): the whole point of this submodule is to catch
\* ANY event type arriving too early, before the handshake completes (e.g.
\* the naive model's own finding: a "SendPacket" event arriving while
\* phase = "Handshake"). Restricting Events to just the handshake's own two
\* event names would silently make that finding unreachable here -- an
\* under-approximation, exactly the kind of mistake this whole exercise is
\* about avoiding.
EXTENDS Naturals

CONSTANTS NullValue

VARIABLES phase, handshakeTimerRunning, pendingEvent

Events == {"ReceiveHandshakeResponse", "HandshakeTimeout",
           "SendPacket", "ReceiveAck", "AckTimeout", "ReceivePacket", "SendAckTimeout",
           "SendSDU", "SDUComplete", "ReceiveBeginSegment", "ReceiveMidSegment", "ReceiveEndSegment",
           "AppCloseSession"}

vars == <<phase, handshakeTimerRunning, pendingEvent>>

Init ==
    /\ phase = "Handshake"
    /\ handshakeTimerRunning = TRUE
    /\ pendingEvent = NullValue

ReceiveHandshakeResponseAction ==
    /\ pendingEvent = "ReceiveHandshakeResponse"
    /\ phase = "Handshake"
    /\ pendingEvent' = NullValue
    /\ \E versionsCompatible \in BOOLEAN :
          IF versionsCompatible
              THEN /\ phase' = "Established"
                   /\ handshakeTimerRunning' = FALSE
              ELSE /\ phase' = "Closed"
                   /\ handshakeTimerRunning' = FALSE

HandshakeTimeoutAction ==
    /\ pendingEvent = "HandshakeTimeout"
    /\ phase = "Handshake"
    /\ handshakeTimerRunning
    /\ phase' = "Closed"
    /\ handshakeTimerRunning' = FALSE
    /\ pendingEvent' = NullValue

\* Once the handshake has resolved (Established or Closed), this submodule's
\* job is done -- checking events from here on is AckWindow/SDU's job (they
\* independently re-check late Handshake-labeled events; see their headers).
PostHandshakeQuiesce ==
    /\ pendingEvent # NullValue
    /\ phase # "Handshake"
    /\ pendingEvent' = NullValue
    /\ UNCHANGED <<phase, handshakeTimerRunning>>

ReceiveEvent(e) ==
    /\ pendingEvent = NullValue
    /\ pendingEvent' = e
    /\ UNCHANGED <<phase, handshakeTimerRunning>>

UndefinedTransition ==
    /\ pendingEvent # NullValue
    /\ phase = "Handshake"
    /\ pendingEvent # "ReceiveHandshakeResponse"
    /\ ~ (pendingEvent = "HandshakeTimeout" /\ handshakeTimerRunning)
    /\ phase' = "Undefined"
    /\ UNCHANGED <<handshakeTimerRunning, pendingEvent>>

Next ==
    \/ ReceiveHandshakeResponseAction \/ HandshakeTimeoutAction \/ PostHandshakeQuiesce
    \/ (\E e \in Events : ReceiveEvent(e))
    \/ UndefinedTransition

Spec == Init /\ [][Next]_vars

NeverUndefined == phase # "Undefined"

====
