---- MODULE core_4_14_1_2 ----
EXTENDS Naturals

\* valid passcode ID is 0 per spec for current commissioning window
CONSTANTS ValidPasscodeId
\* Abstract constants to limit state space for model checking
CONSTANTS InitMsgCounterValue
CONSTANTS AbstractSessionIdInitiator
CONSTANTS AbstractSessionIdResponder

\* pendingInput and the NoInput constant are REQUIRED - see rule 4a.
CONSTANTS NoInput

VARIABLES pendingInput
VARIABLES inMsgPasscodeId
VARIABLES inMsgHasPBKDFParameters
VARIABLES inMsgSessionId
VARIABLES inMsgCbValid
VARIABLES inMsgCaValid

VARIABLES initiatorState
VARIABLES initiatorSessionId
VARIABLES initiatorPeerSessionId
VARIABLES initiatorKeysEstablished
VARIABLES initiatorLocalMsgCounter
VARIABLES initiatorPeerMaxMsgCounter
VARIABLES initiatorSessionTimestampSet

VARIABLES responderState
VARIABLES responderSessionId
VARIABLES responderPeerSessionId
VARIABLES responderKeysEstablished
VARIABLES responderLocalMsgCounter
VARIABLES responderPeerMaxMsgCounter
VARIABLES responderIncludedPBKDFParams
VARIABLES responderSessionTimestampSet

\* REQUIRED - the complete list of events this section can receive. See rule 4a.
Inputs == {
    "StartPASE",
    "PBKDFParamRequest",
    "PBKDFParamResponse",
    "Pake1",
    "Pake2",
    "Pake3",
    "PakeFinished"
}

Init ==
    /\ pendingInput = NoInput
    /\ inMsgPasscodeId = 0
    /\ inMsgHasPBKDFParameters = FALSE
    /\ inMsgSessionId = 0
    /\ inMsgCbValid = FALSE
    /\ inMsgCaValid = FALSE
    /\ initiatorState = "INITIATOR_IDLE"
    /\ initiatorSessionId = 0
    /\ initiatorPeerSessionId = 0
    /\ initiatorKeysEstablished = FALSE
    /\ initiatorLocalMsgCounter = 0
    /\ initiatorPeerMaxMsgCounter = 0
    /\ initiatorSessionTimestampSet = FALSE
    /\ responderState = "RESPONDER_IDLE"
    /\ responderSessionId = 0
    /\ responderPeerSessionId = 0
    /\ responderKeysEstablished = FALSE
    /\ responderLocalMsgCounter = 0
    /\ responderPeerMaxMsgCounter = 0
    /\ responderIncludedPBKDFParams = FALSE
    /\ responderSessionTimestampSet = FALSE

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    \* Randomize incoming message fields to model arbitrary network data
    /\ inMsgPasscodeId' \in {0, 1}
    /\ inMsgHasPBKDFParameters' \in {TRUE, FALSE}
    /\ inMsgSessionId' \in {1, 2, 3}
    /\ inMsgCbValid' \in {TRUE, FALSE}
    /\ inMsgCaValid' \in {TRUE, FALSE}
    /\ UNCHANGED << initiatorState, initiatorSessionId, initiatorPeerSessionId,
                    initiatorKeysEstablished, initiatorLocalMsgCounter,
                    initiatorPeerMaxMsgCounter, initiatorSessionTimestampSet,
                    responderState, responderSessionId, responderPeerSessionId,
                    responderKeysEstablished, responderLocalMsgCounter,
                    responderPeerMaxMsgCounter, responderIncludedPBKDFParams,
                    responderSessionTimestampSet >>

\* SOURCE: core_4.14.1.2 PBKDFParamRequest
Initiator_StartPASE ==
    /\ pendingInput = "StartPASE"
    /\ initiatorState = "INITIATOR_IDLE"
    /\ initiatorState' = "WAIT_PBKDF_PARAM_RESPONSE"
    /\ initiatorSessionId' = AbstractSessionIdInitiator
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inMsgPasscodeId, inMsgHasPBKDFParameters, inMsgSessionId,
                    inMsgCbValid, inMsgCaValid, initiatorPeerSessionId,
                    initiatorKeysEstablished, initiatorLocalMsgCounter,
                    initiatorPeerMaxMsgCounter, initiatorSessionTimestampSet,
                    responderState, responderSessionId, responderPeerSessionId,
                    responderKeysEstablished, responderLocalMsgCounter,
                    responderPeerMaxMsgCounter, responderIncludedPBKDFParams,
                    responderSessionTimestampSet >>

\* SOURCE: core_4.14.1.2 PBKDFParamResponse
Responder_HandlePBKDFParamRequest ==
    /\ pendingInput = "PBKDFParamRequest"
    /\ responderState = "RESPONDER_IDLE"
    /\ IF inMsgPasscodeId = ValidPasscodeId THEN
           /\ responderState' = "WAIT_PAKE1"
           /\ responderSessionId' = AbstractSessionIdResponder
           /\ responderPeerSessionId' = inMsgSessionId
           /\ IF inMsgHasPBKDFParameters = TRUE THEN
                  responderIncludedPBKDFParams' = FALSE
              ELSE
                  responderIncludedPBKDFParams' = TRUE
       ELSE
           /\ responderState' = "RESPONDER_FAILED"
           /\ UNCHANGED << responderSessionId, responderPeerSessionId,
                           responderIncludedPBKDFParams >>
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inMsgPasscodeId, inMsgHasPBKDFParameters, inMsgSessionId,
                    inMsgCbValid, inMsgCaValid, initiatorState, initiatorSessionId,
                    initiatorPeerSessionId, initiatorKeysEstablished,
                    initiatorLocalMsgCounter, initiatorPeerMaxMsgCounter,
                    initiatorSessionTimestampSet, responderKeysEstablished,
                    responderLocalMsgCounter, responderPeerMaxMsgCounter,
                    responderSessionTimestampSet >>

\* SOURCE: core_4.14.1.2 Pake1
Initiator_HandlePBKDFParamResponse ==
    /\ pendingInput = "PBKDFParamResponse"
    /\ initiatorState = "WAIT_PBKDF_PARAM_RESPONSE"
    /\ initiatorState' = "WAIT_PAKE2"
    /\ initiatorPeerSessionId' = inMsgSessionId
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inMsgPasscodeId, inMsgHasPBKDFParameters, inMsgSessionId,
                    inMsgCbValid, inMsgCaValid, initiatorSessionId,
                    initiatorKeysEstablished, initiatorLocalMsgCounter,
                    initiatorPeerMaxMsgCounter, initiatorSessionTimestampSet,
                    responderState, responderSessionId, responderPeerSessionId,
                    responderKeysEstablished, responderLocalMsgCounter,
                    responderPeerMaxMsgCounter, responderIncludedPBKDFParams,
                    responderSessionTimestampSet >>

\* SOURCE: core_4.14.1.2 Pake2
Responder_HandlePake1 ==
    /\ pendingInput = "Pake1"
    /\ responderState = "WAIT_PAKE1"
    /\ responderState' = "WAIT_PAKE3"
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inMsgPasscodeId, inMsgHasPBKDFParameters, inMsgSessionId,
                    inMsgCbValid, inMsgCaValid, initiatorState, initiatorSessionId,
                    initiatorPeerSessionId, initiatorKeysEstablished,
                    initiatorLocalMsgCounter, initiatorPeerMaxMsgCounter,
                    initiatorSessionTimestampSet, responderSessionId,
                    responderPeerSessionId, responderKeysEstablished,
                    responderLocalMsgCounter, responderPeerMaxMsgCounter,
                    responderIncludedPBKDFParams, responderSessionTimestampSet >>

\* SOURCE: core_4.14.1.2 Pake3
Initiator_HandlePake2 ==
    /\ pendingInput = "Pake2"
    /\ initiatorState = "WAIT_PAKE2"
    /\ IF inMsgCbValid = TRUE THEN
           /\ initiatorState' = "WAIT_PAKE_FINISHED"
       ELSE
           /\ initiatorState' = "INITIATOR_FAILED"
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inMsgPasscodeId, inMsgHasPBKDFParameters, inMsgSessionId,
                    inMsgCbValid, inMsgCaValid, initiatorSessionId,
                    initiatorPeerSessionId, initiatorKeysEstablished,
                    initiatorLocalMsgCounter, initiatorPeerMaxMsgCounter,
                    initiatorSessionTimestampSet, responderState, responderSessionId,
                    responderPeerSessionId, responderKeysEstablished,
                    responderLocalMsgCounter, responderPeerMaxMsgCounter,
                    responderIncludedPBKDFParams, responderSessionTimestampSet >>

\* SOURCE: core_4.14.1.2 Pake3
\* SOURCE: core_4.14.1.2 Session Encryption Keys
Responder_HandlePake3 ==
    /\ pendingInput = "Pake3"
    /\ responderState = "WAIT_PAKE3"
    /\ IF inMsgCaValid = TRUE THEN
           /\ responderState' = "SECURE_SESSION_ESTABLISHED"
           /\ responderKeysEstablished' = TRUE
           /\ responderLocalMsgCounter' = InitMsgCounterValue
           /\ responderPeerMaxMsgCounter' = 0
           /\ responderSessionTimestampSet' = TRUE
       ELSE
           /\ responderState' = "RESPONDER_FAILED"
           /\ UNCHANGED << responderKeysEstablished, responderLocalMsgCounter,
                           responderPeerMaxMsgCounter, responderSessionTimestampSet >>
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inMsgPasscodeId, inMsgHasPBKDFParameters, inMsgSessionId,
                    inMsgCbValid, inMsgCaValid, initiatorState, initiatorSessionId,
                    initiatorPeerSessionId, initiatorKeysEstablished,
                    initiatorLocalMsgCounter, initiatorPeerMaxMsgCounter,
                    initiatorSessionTimestampSet, responderSessionId,
                    responderPeerSessionId, responderIncludedPBKDFParams >>

\* SOURCE: core_4.14.1.2 PakeFinished
\* SOURCE: core_4.14.1.2 Session Encryption Keys
Initiator_HandlePakeFinished ==
    /\ pendingInput = "PakeFinished"
    /\ initiatorState = "WAIT_PAKE_FINISHED"
    /\ initiatorState' = "SECURE_SESSION_ESTABLISHED"
    /\ initiatorKeysEstablished' = TRUE
    /\ initiatorLocalMsgCounter' = InitMsgCounterValue
    /\ initiatorPeerMaxMsgCounter' = 0
    /\ initiatorSessionTimestampSet' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inMsgPasscodeId, inMsgHasPBKDFParameters, inMsgSessionId,
                    inMsgCbValid, inMsgCaValid, initiatorSessionId,
                    initiatorPeerSessionId, responderState, responderSessionId,
                    responderPeerSessionId, responderKeysEstablished,
                    responderLocalMsgCounter, responderPeerMaxMsgCounter,
                    responderIncludedPBKDFParams, responderSessionTimestampSet >>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ Initiator_StartPASE
    \/ Responder_HandlePBKDFParamRequest
    \/ Initiator_HandlePBKDFParamResponse
    \/ Responder_HandlePake1
    \/ Initiator_HandlePake2
    \/ Responder_HandlePake3
    \/ Initiator_HandlePakeFinished

====