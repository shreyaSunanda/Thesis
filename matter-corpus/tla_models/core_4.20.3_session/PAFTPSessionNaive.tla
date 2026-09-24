---- MODULE PAFTPSessionNaive ----
\* SOURCE: core_4.20.3 "PAFTP Control Frames" -- the FULL session, composed
\* from its real cross-referenced subsections instead of modeling one in
\* isolation:
\*   core_4.20.3.1/.2/.3  Handshake Request/Response/Session Establishment
\*   core_4.20.3.4        Data Transmission (scoping only -- no new state)
\*   core_4.20.3.5        Message Segmentation and Reassembly
\*   core_4.20.3.6        Sequence Numbers (informs the ack/window design,
\*                        already reflected in the Established-phase actions
\*                        reused from ../core_4.20.3.8/PacketAcknowledgements.tla)
\*   core_4.20.3.7        Receive Windows (freeSlots bound)
\*   core_4.20.3.8        Packet Acknowledgements (reused verbatim)
\*   core_4.20.3.9        Idle Connection State (no new normative content)
\*   core_4.20.3.10       Connection Shutdown (only 28 words of spec text --
\*                        see AppCloseSessionAction below)
\*   core_4.20.3.11       Protocol State Diagrams (figure references only;
\*                        the actual diagram images aren't captured by the
\*                        text-extraction pipeline, so no rules are derived
\*                        from this subsection -- a real limitation, noted
\*                        rather than silently ignored)
\*
\* THIS FILE IS THE NAIVE, UNDECOMPOSED BASELINE: every variable from every
\* subsystem lives in one flat state, checked as a single product. It exists
\* to get a real "before" state count -- see PAFTPSessionDecomposed's sibling
\* files (AckWindowSubsystem.tla, SDUSubsystem.tla) for the "after".
EXTENDS Naturals

CONSTANTS MaxOutstanding, MaxQueue, NullValue

VARIABLES
    phase,                \* "Handshake" | "Established" | "Closed"
    handshakeTimerRunning,\* Commissioner's PAFTP_CONN_RSP_TIMEOUT timer (4.20.3.3)
    outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots,
                          \* ack/window subsystem, reused from 4.20.3.7/.8
    sduInProgress, queueLen, reassemblyInProgress,
                          \* segmentation/reassembly subsystem, from 4.20.3.5
    pendingEvent

HandshakeEvents == {"ReceiveHandshakeResponse", "HandshakeTimeout"}
AckWindowEvents == {"SendPacket", "ReceiveAck", "AckTimeout", "ReceivePacket", "SendAckTimeout"}
SDUEvents == {"SendSDU", "SDUComplete", "ReceiveBeginSegment", "ReceiveMidSegment", "ReceiveEndSegment"}
ShutdownEvents == {"AppCloseSession"}
Events == HandshakeEvents \cup AckWindowEvents \cup SDUEvents \cup ShutdownEvents

vars == <<phase, handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
           sendAckTimerRunning, freeSlots, sduInProgress, queueLen,
           reassemblyInProgress, pendingEvent>>

ackWindowVars == <<outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning, freeSlots>>
sduVars == <<sduInProgress, queueLen, reassemblyInProgress>>

Init ==
    /\ phase = "Handshake"
    /\ handshakeTimerRunning = TRUE  \* "When a Commissioner sends a handshake request, it
                                      \*  SHALL start a timer" -- request is sent at session start
    /\ outstanding = 0
    /\ ackTimerRunning = FALSE
    /\ pendingAck = FALSE
    /\ sendAckTimerRunning = FALSE
    /\ freeSlots = MaxOutstanding
    /\ sduInProgress = FALSE
    /\ queueLen = 0
    /\ reassemblyInProgress = FALSE
    /\ pendingEvent = NullValue

\* --- Handshake phase (4.20.3.1/.2/.3) -------------------------------------

\* "The Commissionable Device SHALL select a PAFTP protocol version that is
\*  the newest which it and the Commissioner both support... If the
\*  Commissionable Device determines that it and the Commissioner do not
\*  share a supported PAFTP protocol version, the Commissionable Device SHALL
\*  close its WFA-USD connection." Version negotiation's outcome is modeled
\* as a nondeterministic choice (the model doesn't need the literal version
\* lists to reflect that either outcome is genuinely possible).
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
    /\ UNCHANGED <<outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning,
                    freeSlots, sduInProgress, queueLen, reassemblyInProgress>>

\* "When a Commissioner sends a handshake request, it SHALL start a timer...
\*  If this timer expires before the Commissioner receives a handshake
\*  response... the Commissioner SHALL close the PAFTP session and report an
\*  error to the application."
HandshakeTimeoutAction ==
    /\ pendingEvent = "HandshakeTimeout"
    /\ phase = "Handshake"
    /\ handshakeTimerRunning
    /\ phase' = "Closed"
    /\ handshakeTimerRunning' = FALSE
    /\ UNCHANGED <<outstanding, ackTimerRunning, pendingAck, sendAckTimerRunning,
                    freeSlots, sduInProgress, queueLen, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

\* --- Established phase: ack/window subsystem (4.20.3.7/.8, reused) --------

SendPacketAction ==
    /\ pendingEvent = "SendPacket"
    /\ phase = "Established"
    /\ outstanding < MaxOutstanding
    /\ outstanding' = outstanding + 1
    /\ ackTimerRunning' = TRUE
    /\ IF pendingAck
           THEN /\ pendingAck' = FALSE
                /\ sendAckTimerRunning' = FALSE
           ELSE UNCHANGED <<pendingAck, sendAckTimerRunning>>
    /\ UNCHANGED <<phase, handshakeTimerRunning, freeSlots, sduInProgress, queueLen, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

ReceiveAckAction ==
    /\ pendingEvent = "ReceiveAck"
    /\ phase = "Established"
    /\ pendingEvent' = NullValue
    /\ UNCHANGED <<handshakeTimerRunning, pendingAck, sendAckTimerRunning, freeSlots,
                    sduInProgress, queueLen, reassemblyInProgress>>
    /\ \/ /\ outstanding = 0
          /\ phase' = "Closed"
          /\ UNCHANGED <<outstanding, ackTimerRunning>>
       \/ /\ outstanding > 0
          /\ phase' = "Established"
          /\ \E ackedIsNewest \in BOOLEAN :
                /\ ackedIsNewest \/ outstanding > 1
                /\ IF ackedIsNewest
                       THEN /\ outstanding' = 0
                            /\ ackTimerRunning' = FALSE
                       ELSE /\ outstanding' = outstanding - 1
                            /\ ackTimerRunning' = TRUE

AckTimeoutAction ==
    /\ pendingEvent = "AckTimeout"
    /\ phase = "Established"
    /\ ackTimerRunning
    /\ phase' = "Closed"
    /\ UNCHANGED <<handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, freeSlots, sduInProgress, queueLen, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

ReceivePacketAction ==
    /\ pendingEvent = "ReceivePacket"
    /\ phase = "Established"
    /\ freeSlots > 0
    /\ freeSlots' = freeSlots - 1
    /\ IF freeSlots - 1 <= 2
           THEN /\ pendingAck' = FALSE
                /\ sendAckTimerRunning' = FALSE
           ELSE /\ pendingAck' = TRUE
                /\ sendAckTimerRunning' = TRUE
    /\ UNCHANGED <<phase, handshakeTimerRunning, outstanding, ackTimerRunning,
                    sduInProgress, queueLen, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

SendAckTimeoutAction ==
    /\ pendingEvent = "SendAckTimeout"
    /\ phase = "Established"
    /\ sendAckTimerRunning
    /\ pendingAck
    /\ pendingAck' = FALSE
    /\ sendAckTimerRunning' = FALSE
    /\ UNCHANGED <<phase, handshakeTimerRunning, outstanding, ackTimerRunning,
                    freeSlots, sduInProgress, queueLen, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

SlotFreedAction ==
    /\ phase = "Established"
    /\ freeSlots < MaxOutstanding
    /\ freeSlots' = freeSlots + 1
    /\ UNCHANGED <<phase, handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, sduInProgress, queueLen, reassemblyInProgress, pendingEvent>>

\* --- Established phase: segmentation/reassembly subsystem (4.20.3.5) ------

\* "If the application attempts to send one PAFTP SDU while transmission of
\*  another PAFTP SDU is in progress, the new PAFTP SDU SHALL be appended to
\*  a first-in, first-out queue." No bound on that queue is given in the
\* spec text -- MaxQueue here is a modeling bound to keep the state space
\* finite, and a queue-full attempt is deliberately left unhandled (see
\* UndefinedTransition) since the spec does not say what happens then.
SendSDUAction ==
    /\ pendingEvent = "SendSDU"
    /\ phase = "Established"
    /\ \/ /\ ~sduInProgress
          /\ sduInProgress' = TRUE
          /\ UNCHANGED queueLen
       \/ /\ sduInProgress
          /\ queueLen < MaxQueue
          /\ queueLen' = queueLen + 1
          /\ UNCHANGED sduInProgress
    /\ UNCHANGED <<phase, handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, freeSlots, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

\* "The next PAFTP SDU SHALL be dequeued from this queue and transmitted once
\*  transmission of the current PAFTP SDU completes."
SDUCompleteAction ==
    /\ pendingEvent = "SDUComplete"
    /\ phase = "Established"
    /\ sduInProgress
    /\ IF queueLen > 0
           THEN /\ queueLen' = queueLen - 1
                /\ UNCHANGED sduInProgress
           ELSE /\ sduInProgress' = FALSE
                /\ UNCHANGED queueLen
    /\ UNCHANGED <<phase, handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, freeSlots, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

\* "...or a Beginning Segment when another PAFTP SDU's transmission is
\*  already in progress, the receiver PAFTP SHALL close the PAFTP session and
\*  report an error to the application." (explicitly defined, both branches)
ReceiveBeginSegmentAction ==
    /\ pendingEvent = "ReceiveBeginSegment"
    /\ phase = "Established"
    /\ IF reassemblyInProgress
           THEN /\ phase' = "Closed"
                /\ UNCHANGED reassemblyInProgress
           ELSE /\ reassemblyInProgress' = TRUE
                /\ UNCHANGED phase
    /\ UNCHANGED <<handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, freeSlots, sduInProgress, queueLen>>
    /\ pendingEvent' = NullValue

\* A segment that is neither the first (Beginning) nor last (Ending) of an
\* SDU. The spec's enumerated error conditions only cover "Ending without
\* Beginning" and "Beginning during another SDU" -- it does not say what a
\* receiver should do with an ordinary middle segment when NO Beginning
\* Segment has been seen yet, which is exactly why this is guarded on
\* reassemblyInProgress rather than always enabled: if it arrives while
\* reassemblyInProgress = FALSE, that combination is deliberately left to
\* UndefinedTransition.
ReceiveMidSegmentAction ==
    /\ pendingEvent = "ReceiveMidSegment"
    /\ phase = "Established"
    /\ reassemblyInProgress
    /\ UNCHANGED <<phase, handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, freeSlots, sduInProgress, queueLen, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

\* "...if receiver receives an Ending Segment without the presence of a
\*  previous Beginning Segment... the receiver PAFTP SHALL close the PAFTP
\*  session and report an error." (explicitly defined, both branches)
ReceiveEndSegmentAction ==
    /\ pendingEvent = "ReceiveEndSegment"
    /\ phase = "Established"
    /\ IF reassemblyInProgress
           THEN /\ reassemblyInProgress' = FALSE
                /\ UNCHANGED phase
           ELSE /\ phase' = "Closed"
                /\ UNCHANGED reassemblyInProgress
    /\ UNCHANGED <<handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, freeSlots, sduInProgress, queueLen>>
    /\ pendingEvent' = NullValue

\* --- Shutdown (4.20.3.10 -- only 28 words of spec text: "A Commissioner MAY
\* terminate the subscribe instance, to close a PAFTP session. A
\* Commissionable Device MAY terminate the publish instance, to close a
\* PAFTP session." No procedure, no peer-notification, no reference to any
\* shutdown PAFTP frame type is given -- this subsection is itself a
\* candidate underspecification finding independent of anything TLC reports,
\* simply from how little it says compared to every other subsection here.
AppCloseSessionAction ==
    /\ pendingEvent = "AppCloseSession"
    /\ phase = "Established"
    /\ phase' = "Closed"
    /\ UNCHANGED <<handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, freeSlots, sduInProgress, queueLen, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

ClosedPhaseIgnoresEvent ==
    /\ pendingEvent # NullValue
    /\ phase = "Closed"
    /\ pendingEvent' = NullValue
    /\ UNCHANGED <<phase, handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, freeSlots, sduInProgress, queueLen, reassemblyInProgress>>

ReceiveEvent(e) ==
    /\ pendingEvent = NullValue
    /\ pendingEvent' = e
    /\ UNCHANGED <<phase, handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, freeSlots, sduInProgress, queueLen, reassemblyInProgress>>

\* Catch-all per the thesis methodology (B.4.3). Deliberately includes
\* cross-phase combinations (e.g. a handshake response arriving after the
\* session is already Established, or a data packet arriving before the
\* handshake finishes) that only exist BECAUSE this model composes the whole
\* session instead of one subsection in isolation -- these are exactly the
\* "inter-section relationship" findings isolated per-section models cannot
\* surface.
UndefinedTransition ==
    /\ pendingEvent # NullValue
    /\ phase # "Closed"
    /\ ~ (pendingEvent = "ReceiveHandshakeResponse" /\ phase = "Handshake")
    /\ ~ (pendingEvent = "HandshakeTimeout" /\ phase = "Handshake" /\ handshakeTimerRunning)
    /\ ~ (pendingEvent = "SendPacket" /\ phase = "Established" /\ outstanding < MaxOutstanding)
    /\ ~ (pendingEvent = "ReceiveAck" /\ phase = "Established")
    /\ ~ (pendingEvent = "AckTimeout" /\ phase = "Established" /\ ackTimerRunning)
    /\ ~ (pendingEvent = "ReceivePacket" /\ phase = "Established" /\ freeSlots > 0)
    /\ ~ (pendingEvent = "SendAckTimeout" /\ phase = "Established" /\ sendAckTimerRunning /\ pendingAck)
    /\ ~ (pendingEvent = "SendSDU" /\ phase = "Established" /\ (~sduInProgress \/ queueLen < MaxQueue))
    /\ ~ (pendingEvent = "SDUComplete" /\ phase = "Established" /\ sduInProgress)
    /\ ~ (pendingEvent = "ReceiveBeginSegment" /\ phase = "Established")
    /\ ~ (pendingEvent = "ReceiveMidSegment" /\ phase = "Established" /\ reassemblyInProgress)
    /\ ~ (pendingEvent = "ReceiveEndSegment" /\ phase = "Established")
    /\ ~ (pendingEvent = "AppCloseSession" /\ phase = "Established")
    /\ phase' = "Undefined"
    /\ UNCHANGED <<handshakeTimerRunning, outstanding, ackTimerRunning, pendingAck,
                    sendAckTimerRunning, freeSlots, sduInProgress, queueLen,
                    reassemblyInProgress, pendingEvent>>

Next ==
    \/ ReceiveHandshakeResponseAction \/ HandshakeTimeoutAction
    \/ SendPacketAction \/ ReceiveAckAction \/ AckTimeoutAction \/ ReceivePacketAction
    \/ SendAckTimeoutAction \/ SlotFreedAction
    \/ SendSDUAction \/ SDUCompleteAction \/ ReceiveBeginSegmentAction
    \/ ReceiveMidSegmentAction \/ ReceiveEndSegmentAction
    \/ AppCloseSessionAction \/ ClosedPhaseIgnoresEvent
    \/ (\E e \in Events : ReceiveEvent(e))
    \/ UndefinedTransition

Spec == Init /\ [][Next]_vars

NeverUndefined == phase # "Undefined"

====
