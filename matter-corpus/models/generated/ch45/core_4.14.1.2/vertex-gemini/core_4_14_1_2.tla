---- MODULE core_4_14_1_2 ----
EXTENDS Naturals

\* TODO: unspecified - I Flag values for PASE messages in the Exchange Flags Table are cut off in the specification text.

CONSTANTS 
    \* Set of valid Session IDs for the Initiator to choose from (non-overlapping)
    InitiatorSessionIds,
    \* Set of valid Session IDs for the Responder to choose from (non-overlapping)
    ResponderSessionIds,
    \* Sentinel value for uninitialized fields
    Null

VARIABLES 
    network,
    iState,
    rState,
    iCtx,
    rCtx

\* --- Helper Definitions for Message Formats ---

EmptyMessage ==
    [type |-> Null,
     sessionId |-> Null,
     sessionType |-> Null,
     sFlag |-> Null,
     dsiz |-> Null,
     protocolId |-> Null,
     initiatorRandom |-> Null,
     responderRandom |-> Null,
     initiatorSessionId |-> Null,
     responderSessionId |-> Null,
     passcodeId |-> Null,
     hasPBKDFParameters |-> Null,
     pbkdf_parameters |-> Null,
     pA |-> Null,
     pB |-> Null,
     cB |-> Null,
     cA |-> Null,
     generalCode |-> Null,
     protocolCode |-> Null]

PBKDFParamReqMsg(sid, passcode, hasParams) ==
    [EmptyMessage EXCEPT
        !.type = "PBKDFParamRequest",
        !.sessionId = 0,
        !.sessionType = 0,
        !.sFlag = 1,
        !.dsiz = 0,
        !.protocolId = "SECURE_CHANNEL",
        !.initiatorRandom = "iRand",
        !.initiatorSessionId = sid,
        !.passcodeId = passcode,
        !.hasPBKDFParameters = hasParams]

PBKDFParamRespMsg(iRand, rSid, hasParams) ==
    [EmptyMessage EXCEPT
        !.type = "PBKDFParamResponse",
        !.sessionId = 0,
        !.sessionType = 0,
        !.sFlag = 0,
        !.dsiz = 1,
        !.protocolId = "SECURE_CHANNEL",
        !.initiatorRandom = iRand,
        !.responderRandom = "rRand",
        !.responderSessionId = rSid,
        !.pbkdf_parameters = IF hasParams = TRUE THEN "Omitted" ELSE "Included"]

StatusReportMsg(isInitiator, gCode, pCode) ==
    [EmptyMessage EXCEPT
        !.type = "StatusReport",
        !.sessionId = 0,
        !.sessionType = 0,
        !.sFlag = IF isInitiator = TRUE THEN 1 ELSE 0,
        !.dsiz = IF isInitiator = TRUE THEN 0 ELSE 1,
        !.protocolId = "SECURE_CHANNEL",
        !.generalCode = gCode,
        !.protocolCode = pCode]

Pake1Msg(pA_val) ==
    [EmptyMessage EXCEPT
        !.type = "Pake1",
        !.sessionId = 0,
        !.sessionType = 0,
        !.sFlag = 1,
        !.dsiz = 0,
        !.protocolId = "SECURE_CHANNEL",
        !.pA = pA_val]

Pake2Msg(pB_val, cB_val) ==
    [EmptyMessage EXCEPT
        !.type = "Pake2",
        !.sessionId = 0,
        !.sessionType = 0,
        !.sFlag = 0,
        !.dsiz = 1,
        !.protocolId = "SECURE_CHANNEL",
        !.pB = pB_val,
        !.cB = cB_val]

Pake3Msg(cA_val) ==
    [EmptyMessage EXCEPT
        !.type = "Pake3",
        !.sessionId = 0,
        !.sessionType = 0,
        !.sFlag = 1,
        !.dsiz = 0,
        !.protocolId = "SECURE_CHANNEL",
        !.cA = cA_val]

\* --- Helper Definitions for Session Key Installation ---

InstallInitiatorKeys(ctx) ==
    [ctx EXCEPT !.sessionTimestamp = 1,
                !.txKey = "I2RKey",
                !.rxKey = "R2IKey",
                !.attestationChallenge = "AttestationChallenge",
                !.localMessageCounter = 67890,
                !.peerMaxMessageCounter = 0]

InstallResponderKeys(ctx) ==
    [ctx EXCEPT !.sessionTimestamp = 1,
                !.txKey = "R2IKey",
                !.rxKey = "I2RKey",
                !.attestationChallenge = "AttestationChallenge",
                !.localMessageCounter = 12345,
                !.peerMaxMessageCounter = 0]

\* --- State Machine Transitions ---

Init ==
    /\ network = {}
    /\ iState = "INIT"
    /\ rState = "IDLE"
    /\ iCtx = [localSessionId |-> 0, peerSessionId |-> 0, sessionTimestamp |-> 0, txKey |-> Null, rxKey |-> Null, attestationChallenge |-> Null, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
    /\ rCtx = [localSessionId |-> 0, peerSessionId |-> 0, sessionTimestamp |-> 0, txKey |-> Null, rxKey |-> Null, attestationChallenge |-> Null, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]

\* SOURCE: core_4.14.1.2 PBKDFParamRequest
Initiator_Send_PBKDFParamRequest ==
    /\ iState = "INIT"
    /\ \E sid \in InitiatorSessionIds :
        \E passcode \in {0, 1} : \* 0 represents a valid passcodeId per spec
            \E hasParams \in {TRUE, FALSE} :
                /\ iCtx' = [iCtx EXCEPT !.localSessionId = sid]
                /\ network' = network \cup {PBKDFParamReqMsg(sid, passcode, hasParams)}
                /\ iState' = "WAIT_RESP"
    /\ rState' = rState
    /\ rCtx' = rCtx

\* SOURCE: core_4.14.1.2 PBKDFParamResponse
Responder_Receive_PBKDFParamRequest ==
    /\ rState = "IDLE"
    /\ \E msg \in network :
        /\ msg.type = "PBKDFParamRequest"
        /\ IF msg.passcodeId /= 0
           THEN
               /\ network' = network \cup {StatusReportMsg(FALSE, "FAILURE", "INVALID_PARAMETER")}
               /\ rState' = "FAILED"
               /\ rCtx' = rCtx
           ELSE
               /\ \E rSid \in ResponderSessionIds :
                   /\ rCtx' = [rCtx EXCEPT !.localSessionId = rSid, !.peerSessionId = msg.initiatorSessionId]
                   /\ network' = network \cup {PBKDFParamRespMsg(msg.initiatorRandom, rSid, msg.hasPBKDFParameters)}
                   /\ rState' = "WAIT_PAKE1"
    /\ iState' = iState
    /\ iCtx' = iCtx

\* SOURCE: core_4.14.1.2 Pake1
Initiator_Receive_PBKDFParamResponse ==
    /\ iState = "WAIT_RESP"
    /\ \E msg \in network :
        /\ msg.type = "PBKDFParamResponse"
        /\ iCtx' = [iCtx EXCEPT !.peerSessionId = msg.responderSessionId]
        /\ network' = network \cup {Pake1Msg("pA_val")}
        /\ iState' = "WAIT_PAKE2"
    /\ rState' = rState
    /\ rCtx' = rCtx

\* SOURCE: core_4.14.1.2 Pake2
Responder_Receive_Pake1 ==
    /\ rState = "WAIT_PAKE1"
    /\ \E msg \in network :
        /\ msg.type = "Pake1"
        /\ network' = network \cup {Pake2Msg("pB_val", "cB_val")}
        /\ rState' = "WAIT_PAKE3"
    /\ iState' = iState
    /\ iCtx' = iCtx
    /\ rCtx' = rCtx

\* SOURCE: core_4.14.1.2 Pake3
Initiator_Receive_Pake2 ==
    /\ iState = "WAIT_PAKE2"
    /\ \E msg \in network :
        /\ msg.type = "Pake2"
        /\ \E cB_valid \in {TRUE, FALSE} :
            IF cB_valid = FALSE
            THEN
                /\ network' = network \cup {StatusReportMsg(TRUE, "FAILURE", "INVALID_PARAMETER")}
                /\ iState' = "FAILED"
                /\ iCtx' = iCtx
            ELSE
                /\ network' = network \cup {Pake3Msg("cA_val")}
                /\ iState' = "WAIT_FIN"
                /\ iCtx' = iCtx
    /\ rState' = rState
    /\ rCtx' = rCtx

\* SOURCE: core_4.14.1.2 PakeFinished
Responder_Receive_Pake3 ==
    /\ rState = "WAIT_PAKE3"
    /\ \E msg \in network :
        /\ msg.type = "Pake3"
        /\ \E cA_valid \in {TRUE, FALSE} :
            IF cA_valid = FALSE
            THEN
                /\ network' = network \cup {StatusReportMsg(FALSE, "FAILURE", "INVALID_PARAMETER")}
                /\ rState' = "FAILED"
                /\ rCtx' = rCtx
            ELSE
                /\ network' = network \cup {StatusReportMsg(FALSE, "SUCCESS", "SESSION_ESTABLISHMENT_SUCCESS")}
                /\ rState' = "ESTABLISHED"
                /\ rCtx' = InstallResponderKeys(rCtx)
    /\ iState' = iState
    /\ iCtx' = iCtx

\* SOURCE: core_4.14.1.2 Session Encryption Keys
Initiator_Receive_PakeFinished ==
    /\ iState = "WAIT_FIN"
    /\ \E msg \in network :
        /\ msg.type = "StatusReport"
        /\ msg.sFlag = 0
        /\ msg.generalCode = "SUCCESS"
        /\ msg.protocolCode = "SESSION_ESTABLISHMENT_SUCCESS"
        /\ iState' = "ESTABLISHED"
        /\ iCtx' = InstallInitiatorKeys(iCtx)
        /\ network' = network
    /\ rState' = rState
    /\ rCtx' = rCtx

\* SOURCE: core_4.14.1.2 Protocol Details
Receive_Failure_StatusReport_Initiator ==
    /\ iState \notin {"INIT", "FAILED", "ESTABLISHED"}
    /\ \E msg \in network :
        /\ msg.type = "StatusReport"
        /\ msg.generalCode = "FAILURE"
        /\ msg.sFlag = 0
    /\ iState' = "FAILED"
    /\ iCtx' = iCtx
    /\ rState' = rState
    /\ rCtx' = rCtx
    /\ network' = network

\* SOURCE: core_4.14.1.2 Protocol Details
Receive_Failure_StatusReport_Responder ==
    /\ rState \notin {"IDLE", "FAILED", "ESTABLISHED"}
    /\ \E msg \in network :
        /\ msg.type = "StatusReport"
        /\ msg.generalCode = "FAILURE"
        /\ msg.sFlag = 1
    /\ rState' = "FAILED"
    /\ rCtx' = rCtx
    /\ iState' = iState
    /\ iCtx' = iCtx
    /\ network' = network

Next == 
    \/ Initiator_Send_PBKDFParamRequest
    \/ Responder_Receive_PBKDFParamRequest
    \/ Initiator_Receive_PBKDFParamResponse
    \/ Responder_Receive_Pake1
    \/ Initiator_Receive_Pake2
    \/ Responder_Receive_Pake3
    \/ Initiator_Receive_PakeFinished
    \/ Receive_Failure_StatusReport_Initiator
    \/ Receive_Failure_StatusReport_Responder

====