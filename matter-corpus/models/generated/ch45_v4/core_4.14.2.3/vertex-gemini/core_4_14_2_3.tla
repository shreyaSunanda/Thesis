---- MODULE core_4_14_2_3 ----
EXTENDS Naturals

\* 
\* CONSTANTS
\* 

\* Required sentinels
CONSTANTS NoInput
CONSTANTS NullValue
CONSTANTS Now

\* Message types
CONSTANTS MSG_SIGMA1, MSG_SIGMA2, MSG_SIGMA3, MSG_SIGMA2_RESUME, MSG_STATUS_REPORT

\* Status codes
CONSTANTS STATUS_SUCCESS, STATUS_FAILURE
CONSTANTS INVALID_PARAMETER, NO_SHARED_TRUST_ROOTS, SESSION_ESTABLISHMENT_SUCCESS

\* Dummy parameters for the model
CONSTANTS LocalSessionIdInit, LocalSessionIdResp
CONSTANTS ResumptionId1, ResumptionId2
CONSTANTS DestId1

\*
\* VARIABLES
\*
VARIABLES pendingInput
VARIABLES inMessage
VARIABLES initiator
VARIABLES responder
VARIABLES network

Inputs == {
    "StartCASE_New", 
    "StartCASE_Resume", 
    "ReceiveSigma1", 
    "ReceiveSigma2", 
    "ReceiveSigma3", 
    "ReceiveSigma2_Resume", 
    "ReceiveSigmaFinished"
}

Operational == TRUE

\*
\* INITIALIZATION
\*
Init ==
    /\ pendingInput = NoInput
    /\ inMessage = NullValue
    /\ network = {}
    /\ initiator = [
           state |-> "IDLE",
           localSessionId |-> NullValue,
           peerSessionId |-> NullValue,
           resumptionId |-> NullValue,
           sessionTimestamp |-> NullValue,
           localMessageCounter |-> NullValue,
           peerMessageCounter |-> NullValue
       ]
    /\ responder = [
           state |-> "IDLE",
           localSessionId |-> NullValue,
           peerSessionId |-> NullValue,
           resumptionId |-> NullValue,
           sessionTimestamp |-> NullValue,
           localMessageCounter |-> NullValue,
           peerMessageCounter |-> NullValue
       ]

\*
\* MESSAGE HELPERS
\*

MsgSigma1New == [
    type |-> MSG_SIGMA1,
    initiatorSessionId |-> LocalSessionIdInit,
    resumptionID |-> NullValue,
    initiatorResumeMIC |-> NullValue,
    destinationId |-> DestId1
]

MsgSigma1Resume == [
    type |-> MSG_SIGMA1,
    initiatorSessionId |-> LocalSessionIdInit,
    resumptionID |-> ResumptionId1,
    initiatorResumeMIC |-> "ValidMIC",
    destinationId |-> DestId1
]

MsgStatusInvalidParam == [
    type |-> MSG_STATUS_REPORT,
    status |-> STATUS_FAILURE,
    code |-> INVALID_PARAMETER
]

MsgStatusNoRoots == [
    type |-> MSG_STATUS_REPORT,
    status |-> STATUS_FAILURE,
    code |-> NO_SHARED_TRUST_ROOTS
]

MsgStatusSuccess == [
    type |-> MSG_STATUS_REPORT,
    status |-> STATUS_SUCCESS,
    code |-> SESSION_ESTABLISHMENT_SUCCESS
]

MsgSigma2Resume(initId) == [
    type |-> MSG_SIGMA2_RESUME,
    resumptionID |-> ResumptionId2,
    responderSessionID |-> LocalSessionIdResp
]

MsgSigma2(initId) == [
    type |-> MSG_SIGMA2,
    responderSessionId |-> LocalSessionIdResp,
    resumptionID |-> ResumptionId2
]

MsgSigma3 == [
    type |-> MSG_SIGMA3
]

\*
\* ACTIONS
\*

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e = "ReceiveSigma1" THEN \E msg \in network : msg.type = MSG_SIGMA1 /\ inMessage' = msg
       ELSE IF e = "ReceiveSigma2" THEN \E msg \in network : msg.type = MSG_SIGMA2 /\ inMessage' = msg
       ELSE IF e = "ReceiveSigma3" THEN \E msg \in network : msg.type = MSG_SIGMA3 /\ inMessage' = msg
       ELSE IF e = "ReceiveSigma2_Resume" THEN \E msg \in network : msg.type = MSG_SIGMA2_RESUME /\ inMessage' = msg
       ELSE IF e = "ReceiveSigmaFinished" THEN \E msg \in network : msg.type = MSG_STATUS_REPORT /\ inMessage' = msg
       ELSE inMessage' = NullValue
    /\ UNCHANGED <<initiator, responder, network>>

\* SOURCE: core_4.14.2.3 Generate and Send Sigma1
StartCASENew ==
    /\ pendingInput = "StartCASE_New"
    /\ initiator.state = "IDLE"
    /\ initiator' = [initiator EXCEPT !.state = "WAIT_SIGMA2",
                                      !.localSessionId = LocalSessionIdInit]
    /\ network' = network \cup {MsgSigma1New}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<responder, inMessage>>

\* SOURCE: core_4.14.2.3 Generate and Send Sigma1
StartCASEResume ==
    /\ pendingInput = "StartCASE_Resume"
    /\ initiator.state = "IDLE"
    /\ initiator' = [initiator EXCEPT !.state = "WAIT_SIGMA2",
                                      !.localSessionId = LocalSessionIdInit,
                                      !.resumptionId = ResumptionId1]
    /\ network' = network \cup {MsgSigma1Resume}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<responder, inMessage>>

\* SOURCE: core_4.14.2.3 Validate Sigma1
\* SOURCE: core_4.14.2.3 Validate Sigma1 Destination ID
\* SOURCE: core_4.14.2.3 Generate and Send Sigma2
\* SOURCE: core_4.14.2.3 Validate Sigma1 with Resumption
\* SOURCE: core_4.14.2.3 Generate and Send Sigma2_Resume
ReceiveSigma1 ==
    /\ pendingInput = "ReceiveSigma1"
    /\ inMessage # NullValue
    /\ inMessage.type = MSG_SIGMA1
    /\ responder.state = "IDLE"
    /\ IF (inMessage.resumptionID # NullValue /\ inMessage.initiatorResumeMIC = NullValue)
          \/ (inMessage.resumptionID = NullValue /\ inMessage.initiatorResumeMIC # NullValue)
       THEN
           \* step 1: INVALID_PARAMETER
           /\ network' = network \cup {MsgStatusInvalidParam}
           /\ responder' = [responder EXCEPT !.state = "FAILED"]
       ELSE IF inMessage.resumptionID # NullValue /\ inMessage.initiatorResumeMIC # NullValue
       THEN
           \* step 3: Validate Sigma1 with Resumption
           /\ network' = network \cup {MsgSigma2Resume(inMessage.initiatorSessionId)}
           /\ responder' = [responder EXCEPT !.state = "WAIT_SIGMAFINISHED",
                                             !.peerSessionId = inMessage.initiatorSessionId,
                                             !.localSessionId = LocalSessionIdResp]
       ELSE IF inMessage.destinationId # DestId1
       THEN
           \* Validate Sigma1 Destination ID step 2: NO_SHARED_TRUST_ROOTS
           /\ network' = network \cup {MsgStatusNoRoots}
           /\ responder' = [responder EXCEPT !.state = "FAILED"]
       ELSE
           \* Validate Sigma1 Destination ID and Generate Sigma2
           /\ network' = network \cup {MsgSigma2(inMessage.initiatorSessionId)}
           /\ responder' = [responder EXCEPT !.state = "WAIT_SIGMA3",
                                             !.peerSessionId = inMessage.initiatorSessionId,
                                             !.localSessionId = LocalSessionIdResp,
                                             !.resumptionId = ResumptionId2]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<initiator, inMessage>>

\* SOURCE: core_4.14.2.3 Validate Sigma2
\* SOURCE: core_4.14.2.3 Generate and Send Sigma3
ReceiveSigma2 ==
    /\ pendingInput = "ReceiveSigma2"
    /\ inMessage # NullValue
    /\ inMessage.type = MSG_SIGMA2
    /\ initiator.state = "WAIT_SIGMA2"
    /\ initiator' = [initiator EXCEPT !.state = "WAIT_SIGMAFINISHED",
                                      !.peerSessionId = inMessage.responderSessionId,
                                      !.resumptionId = inMessage.resumptionID]
    /\ network' = network \cup {MsgSigma3}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<responder, inMessage>>

\* SOURCE: core_4.14.2.3 Validate Sigma3
\* SOURCE: core_4.14.2.3 SigmaFinished
ReceiveSigma3 ==
    /\ pendingInput = "ReceiveSigma3"
    /\ inMessage # NullValue
    /\ inMessage.type = MSG_SIGMA3
    /\ responder.state = "WAIT_SIGMA3"
    /\ responder' = [responder EXCEPT !.state = "ESTABLISHED",
                                      !.sessionTimestamp = Now,
                                      !.localMessageCounter = 0,
                                      !.peerMessageCounter = 0]
    /\ network' = network \cup {MsgStatusSuccess}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<initiator, inMessage>>

\* SOURCE: core_4.14.2.3 Validate Sigma2_Resume
\* SOURCE: core_4.14.2.3 SigmaFinished
ReceiveSigma2_Resume ==
    /\ pendingInput = "ReceiveSigma2_Resume"
    /\ inMessage # NullValue
    /\ inMessage.type = MSG_SIGMA2_RESUME
    /\ initiator.state = "WAIT_SIGMA2"
    /\ initiator' = [initiator EXCEPT !.state = "ESTABLISHED",
                                      !.peerSessionId = inMessage.responderSessionID,
                                      !.resumptionId = inMessage.resumptionID,
                                      !.sessionTimestamp = Now,
                                      !.localMessageCounter = 0,
                                      !.peerMessageCounter = 0]
    /\ network' = network \cup {MsgStatusSuccess}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<responder, inMessage>>

\* SOURCE: core_4.14.2.3 SigmaFinished
ReceiveSigmaFinished ==
    /\ pendingInput = "ReceiveSigmaFinished"
    /\ inMessage # NullValue
    /\ inMessage.type = MSG_STATUS_REPORT
    /\ inMessage.status = STATUS_SUCCESS
    /\ inMessage.code = SESSION_ESTABLISHMENT_SUCCESS
    /\ IF initiator.state = "WAIT_SIGMAFINISHED"
       THEN /\ initiator' = [initiator EXCEPT !.state = "ESTABLISHED",
                                              !.sessionTimestamp = Now,
                                              !.localMessageCounter = 0]
            /\ UNCHANGED responder
       ELSE IF responder.state = "WAIT_SIGMAFINISHED"
       THEN /\ responder' = [responder EXCEPT !.state = "ESTABLISHED",
                                              !.sessionTimestamp = Now,
                                              !.localMessageCounter = 0]
            /\ UNCHANGED initiator
       ELSE \* "If this message is received out-of-order or unexpectedly, then it SHALL be ignored."
            UNCHANGED <<initiator, responder>>
    /\ network' = network
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inMessage>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ StartCASENew
    \/ StartCASEResume
    \/ ReceiveSigma1
    \/ ReceiveSigma2
    \/ ReceiveSigma3
    \/ ReceiveSigma2_Resume
    \/ ReceiveSigmaFinished

====