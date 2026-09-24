---- MODULE SDU ----
\* Decomposition of ../PAFTPSessionNaive.tla, piece 3 of 3: the message
\* segmentation/reassembly subsystem (core_4.20.3.5), assuming the handshake
\* has already succeeded. See AckWindow.tla's header for the full soundness
\* argument (disjoint variables, disjoint guards, deterministic handoff from
\* Handshake.tla) -- it applies symmetrically here.
EXTENDS Naturals

CONSTANTS MaxQueue, NullValue

VARIABLES status, sduInProgress, queueLen, reassemblyInProgress, pendingEvent

HandshakeEvents == {"ReceiveHandshakeResponse", "HandshakeTimeout"}
OwnEvents == {"SendSDU", "SDUComplete", "ReceiveBeginSegment", "ReceiveMidSegment", "ReceiveEndSegment"}
Events == HandshakeEvents \cup OwnEvents

vars == <<status, sduInProgress, queueLen, reassemblyInProgress, pendingEvent>>

Init ==
    /\ status = "Established"
    /\ sduInProgress = FALSE
    /\ queueLen = 0
    /\ reassemblyInProgress = FALSE
    /\ pendingEvent = NullValue

SendSDUAction ==
    /\ pendingEvent = "SendSDU"
    /\ status = "Established"
    /\ \/ /\ ~sduInProgress
          /\ sduInProgress' = TRUE
          /\ UNCHANGED queueLen
       \/ /\ sduInProgress
          /\ queueLen < MaxQueue
          /\ queueLen' = queueLen + 1
          /\ UNCHANGED sduInProgress
    /\ UNCHANGED <<status, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

SDUCompleteAction ==
    /\ pendingEvent = "SDUComplete"
    /\ status = "Established"
    /\ sduInProgress
    /\ IF queueLen > 0
           THEN /\ queueLen' = queueLen - 1
                /\ UNCHANGED sduInProgress
           ELSE /\ sduInProgress' = FALSE
                /\ UNCHANGED queueLen
    /\ UNCHANGED <<status, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

ReceiveBeginSegmentAction ==
    /\ pendingEvent = "ReceiveBeginSegment"
    /\ status = "Established"
    /\ IF reassemblyInProgress
           THEN /\ status' = "Closed"
                /\ UNCHANGED reassemblyInProgress
           ELSE /\ reassemblyInProgress' = TRUE
                /\ UNCHANGED status
    /\ UNCHANGED <<sduInProgress, queueLen>>
    /\ pendingEvent' = NullValue

ReceiveMidSegmentAction ==
    /\ pendingEvent = "ReceiveMidSegment"
    /\ status = "Established"
    /\ reassemblyInProgress
    /\ UNCHANGED <<status, sduInProgress, queueLen, reassemblyInProgress>>
    /\ pendingEvent' = NullValue

ReceiveEndSegmentAction ==
    /\ pendingEvent = "ReceiveEndSegment"
    /\ status = "Established"
    /\ IF reassemblyInProgress
           THEN /\ reassemblyInProgress' = FALSE
                /\ UNCHANGED status
           ELSE /\ status' = "Closed"
                /\ UNCHANGED reassemblyInProgress
    /\ UNCHANGED <<sduInProgress, queueLen>>
    /\ pendingEvent' = NullValue

ClosedStatusIgnoresEvent ==
    /\ pendingEvent # NullValue
    /\ status = "Closed"
    /\ pendingEvent' = NullValue
    /\ UNCHANGED <<status, sduInProgress, queueLen, reassemblyInProgress>>

ReceiveEvent(e) ==
    /\ pendingEvent = NullValue
    /\ pendingEvent' = e
    /\ UNCHANGED <<status, sduInProgress, queueLen, reassemblyInProgress>>

UndefinedTransition ==
    /\ pendingEvent # NullValue
    \* status # "Closed" (not "= Established") so this stays enabled once
    \* status = "Undefined" too -- a self-loop, matching how the naive
    \* model's own UndefinedTransition avoids deadlocking after the first
    \* violation (see ../PAFTPSessionNaive.tla).
    /\ status # "Closed"
    \* Stale handshake-phase notification arriving after we're already
    \* Established -- always undefined here, this subsystem has no action
    \* for either handshake event (same reasoning as AckWindow.tla).
    /\ ~ (pendingEvent = "SendSDU" /\ (~sduInProgress \/ queueLen < MaxQueue))
    /\ ~ (pendingEvent = "SDUComplete" /\ sduInProgress)
    /\ pendingEvent # "ReceiveBeginSegment"
    /\ ~ (pendingEvent = "ReceiveMidSegment" /\ reassemblyInProgress)
    /\ pendingEvent # "ReceiveEndSegment"
    /\ status' = "Undefined"
    /\ UNCHANGED <<sduInProgress, queueLen, reassemblyInProgress, pendingEvent>>

Next ==
    \/ SendSDUAction \/ SDUCompleteAction \/ ReceiveBeginSegmentAction
    \/ ReceiveMidSegmentAction \/ ReceiveEndSegmentAction \/ ClosedStatusIgnoresEvent
    \/ (\E e \in Events : ReceiveEvent(e))
    \/ UndefinedTransition

Spec == Init /\ [][Next]_vars

NeverUndefined == status # "Undefined"

====
