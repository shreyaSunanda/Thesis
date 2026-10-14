---- MODULE core_4_14_1_2 ----
EXTENDS Naturals

\* Sentinel value indicating no event is waiting to be processed
CONSTANTS NoInput

\* Sentinel value indicating no session ID is assigned
CONSTANTS NoSessionId

\* Set of valid session identifiers available for use
CONSTANTS SessionIds

\* Maximum value for initialized message counter. Real value per spec: 2^28.
CONSTANTS MaxMessageCounter

VARIABLES pendingInput
VARIABLES network
VARIABLES initiator
VARIABLES responder

\* REQUIRED - complete list of events this section can receive
Inputs == {
    "InitiatePASE",
    "PBKDFParamRequest",
    "PBKDFParamResponse",
    "Pake1",
    "Pake2",
    "Pake3",
    "PakeFinished",
    "StatusReport"
}

Operational ==
    \/ initiator.state = "ESTABLISHED"
    \/ responder.state = "ESTABLISHED"

\* Message Constructors
PBKDFParamRequestMsg(sid, pid, hasParams) ==
    [type |-> "PBKDFParamRequest", initiatorSessionId |-> sid, passcodeId |-> pid, hasPBKDFParameters |-> hasParams]

PBKDFParamResponseMsg(sid, hasParams) ==
    [type |-> "PBKDFParamResponse", responderSessionId |-> sid, hasPBKDFParameters |-> hasParams]

StatusReportMsg(codeVal) ==
    [type |-> "StatusReport", code |-> codeVal]

Pake1Msg == [type |-> "Pake1"]

Pake2Msg(isValid) == [type |-> "Pake2", valid |-> isValid]

Pake3Msg(isValid) == [type |-> "Pake3", valid |-> isValid]

PakeFinishedMsg == [type |-> "PakeFinished"]

\* State Updaters
Initiator_SetWaitResp(init, sid, pid, hasParams) ==
    [init EXCEPT !.state = "WAIT_PBKDF_RESP",
                 !.localSessionId = sid,
                 !.passcodeId = pid,
                 !.hasPBKDFParameters = hasParams]

Responder_SetFailed(resp) ==
    [resp EXCEPT !.state = "FAILED"]

Responder_SetWaitPake1(resp, sid, peerSid, hasParams) ==
    [resp EXCEPT !.state = "WAIT_PAKE1",
                 !.localSessionId = sid,
                 !.peerSessionId = peerSid,
                 !.hasPBKDFParameters = hasParams]

Initiator_SetWaitPake2(init, peerSid) ==
    [init EXCEPT !.state = "WAIT_PAKE2",
                 !.peerSessionId = peerSid]

Responder_SetWaitPake3(resp) ==
    [resp EXCEPT !.state = "WAIT_PAKE3"]

Initiator_SetFailed(init) ==
    [init EXCEPT !.state = "FAILED"]

Initiator_SetWaitFinished(init) ==
    [init EXCEPT !.state = "WAIT_FINISHED"]

Responder_SetEstablished(resp, counter) ==
    [resp EXCEPT !.state = "ESTABLISHED",
                 !.keysInstalled = TRUE,
                 !.localMessageCounter = counter,
                 !.peerMaxMessageCounter = 0]

Initiator_SetEstablished(init, counter) ==
    [init EXCEPT !.state = "ESTABLISHED",
                 !.keysInstalled = TRUE,
                 !.localMessageCounter = counter,
                 !.peerMaxMessageCounter = 0]

Init ==
    /\ pendingInput = NoInput
    /\ network = {}
    /\ initiator = [state |-> "UNINITIALIZED",
                    localSessionId |-> NoSessionId,
                    peerSessionId |-> NoSessionId,
                    passcodeId |-> 0,
                    hasPBKDFParameters |-> FALSE,
                    keysInstalled |-> FALSE,
                    localMessageCounter |-> 0,
                    peerMaxMessageCounter |-> 0]
    /\ responder = [state |-> "UNINITIALIZED",
                    localSessionId |-> NoSessionId,
                    peerSessionId |-> NoSessionId,
                    passcodeId |-> 0,
                    hasPBKDFParameters |-> FALSE,
                    keysInstalled |-> FALSE,
                    localMessageCounter |-> 0,
                    peerMaxMessageCounter |-> 0]

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<network, initiator, responder>>

\* SOURCE: core_4.14.1.2 PBKDFParamRequest
Initiator_InitiatePASE ==
    /\ pendingInput = "InitiatePASE"
    /\ initiator.state = "UNINITIALIZED"
    /\ pendingInput' = NoInput
    /\ \E sid \in SessionIds \ {NoSessionId}, pid \in {0, 1}, hasParams \in BOOLEAN:
        /\ initiator' = Initiator_SetWaitResp(initiator, sid, pid, hasParams)
        /\ network' = network \cup {PBKDFParamRequestMsg(sid, pid, hasParams)}
    /\ UNCHANGED <<responder>>

\* SOURCE: core_4.14.1.2 PBKDFParamResponse
Responder_HandlePBKDFParamRequest ==
    /\ pendingInput = "PBKDFParamRequest"
    /\ \E msg \in network :
        /\ msg.type = "PBKDFParamRequest"
        /\ pendingInput' = NoInput
        /\ IF msg.passcodeId # 0 THEN
               /\ network' = network \cup {StatusReportMsg("FAILURE")}
               /\ responder' = Responder_SetFailed(responder)
           ELSE
               /\ \E sid \in SessionIds \ {NoSessionId}:
                   /\ responder' = Responder_SetWaitPake1(responder, sid, msg.initiatorSessionId, msg.hasPBKDFParameters)
                   /\ network' = network \cup {PBKDFParamResponseMsg(sid, msg.hasPBKDFParameters)}
    /\ UNCHANGED <<initiator>>

\* SOURCE: core_4.14.1.2 Pake1
Initiator_HandlePBKDFParamResponse ==
    /\ pendingInput = "PBKDFParamResponse"
    /\ initiator.state = "WAIT_PBKDF_RESP"
    /\ \E msg \in network :
        /\ msg.type = "PBKDFParamResponse"
        /\ pendingInput' = NoInput
        /\ initiator' = Initiator_SetWaitPake2(initiator, msg.responderSessionId)
        /\ network' = network \cup {Pake1Msg}
    /\ UNCHANGED <<responder>>

\* SOURCE: core_4.14.1.2 Pake2
Responder_HandlePake1 ==
    /\ pendingInput = "Pake1"
    /\ responder.state = "WAIT_PAKE1"
    /\ \E msg \in network :
        /\ msg.type = "Pake1"
        /\ pendingInput' = NoInput
        /\ responder' = Responder_SetWaitPake3(responder)
        /\ \E isValid \in BOOLEAN:
            network' = network \cup {Pake2Msg(isValid)}
    /\ UNCHANGED <<initiator>>

\* SOURCE: core_4.14.1.2 Pake3
Initiator_HandlePake2 ==
    /\ pendingInput = "Pake2"
    /\ initiator.state = "WAIT_PAKE2"
    /\ \E msg \in network :
        /\ msg.type = "Pake2"
        /\ pendingInput' = NoInput
        /\ IF ~msg.valid THEN
               /\ network' = network \cup {StatusReportMsg("FAILURE")}
               /\ initiator' = Initiator_SetFailed(initiator)
           ELSE
               /\ initiator' = Initiator_SetWaitFinished(initiator)
               /\ \E isValid \in BOOLEAN:
                   network' = network \cup {Pake3Msg(isValid)}
    /\ UNCHANGED <<responder>>

\* SOURCE: core_4.14.1.2 PakeFinished
Responder_HandlePake3 ==
    /\ pendingInput = "Pake3"
    /\ responder.state = "WAIT_PAKE3"
    /\ \E msg \in network :
        /\ msg.type = "Pake3"
        /\ pendingInput' = NoInput
        /\ IF ~msg.valid THEN
               /\ network' = network \cup {StatusReportMsg("FAILURE")}
               /\ responder' = Responder_SetFailed(responder)
           ELSE
               /\ \E counter \in 1..MaxMessageCounter:
                   /\ responder' = Responder_SetEstablished(responder, counter)
                   /\ network' = network \cup {PakeFinishedMsg}
    /\ UNCHANGED <<initiator>>

\* SOURCE: core_4.14.1.2 Session Encryption Keys
Initiator_HandlePakeFinished ==
    /\ pendingInput = "PakeFinished"
    /\ initiator.state = "WAIT_FINISHED"
    /\ \E msg \in network :
        /\ msg.type = "PakeFinished"
        /\ pendingInput' = NoInput
        /\ \E counter \in 1..MaxMessageCounter:
            initiator' = Initiator_SetEstablished(initiator, counter)
    /\ UNCHANGED <<network, responder>>

\* TODO: unspecified - Section 4.14.1.2 does not specify state transitions upon receipt of a FAILURE StatusReport, so it is left unhandled here.

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ Initiator_InitiatePASE
    \/ Responder_HandlePBKDFParamRequest
    \/ Initiator_HandlePBKDFParamResponse
    \/ Responder_HandlePake1
    \/ Initiator_HandlePake2
    \/ Responder_HandlePake3
    \/ Initiator_HandlePakeFinished

====