---- MODULE core_4_14_2_3 ----
EXTENDS Naturals

\* Sentinel for no pending input
CONSTANTS NoInput

\* The set of all possible inputs/events the environment can inject.
\* Expected to contain records for Local_StartCASE, Sigma1, Sigma2, Sigma3, 
\* Sigma2_Resume, and StatusReport messages.
CONSTANTS Inputs

\* Sentinel for optional fields that are not present in a message.
CONSTANTS Null

\* Abstracted sets representing valid identifiers known to the local nodes.
CONSTANTS ValidDestIDs
CONSTANTS ValidResumptionIDs

VARIABLES state
VARIABLES pendingInput

Init ==
    /\ pendingInput = NoInput
    /\ state = [
        initiator |-> [
            phase |-> "IDLE",
            sessionId |-> 0,
            peerSessionId |-> 0,
            resumptionId |-> Null
        ],
        responder |-> [
            phase |-> "IDLE",
            sessionId |-> 0,
            peerSessionId |-> 0,
            resumptionId |-> Null
        ],
        sentMessages |-> {}
    ]

\* SOURCE: mandatory input shape (Rule 4a)
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.14.2.3 Generate and Send Sigma1
Initiator_Start_CASE ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "Local_StartCASE"
    /\ state.initiator.phase = "IDLE"
    /\ LET isResume == pendingInput.resumptionID # Null
           msg == IF isResume THEN
                      [type |-> "Sigma1",
                       initiatorSessionId |-> pendingInput.sessionId,
                       destinationId |-> pendingInput.destinationId,
                       resumptionID |-> pendingInput.resumptionID,
                       initiatorResumeMIC |-> pendingInput.resumeMIC]
                  ELSE
                      [type |-> "Sigma1",
                       initiatorSessionId |-> pendingInput.sessionId,
                       destinationId |-> pendingInput.destinationId,
                       resumptionID |-> Null,
                       initiatorResumeMIC |-> Null]
       IN
       state' = [state EXCEPT
           !.initiator.phase = "WAIT_RESPONSE",
           !.initiator.sessionId = pendingInput.sessionId,
           !.sentMessages = state.sentMessages \cup {msg}
       ]
    /\ pendingInput' = NoInput

\* SOURCE: core_4.14.2.3 Validate Sigma1
\* SOURCE: core_4.14.2.3 Validate Sigma1 Destination ID
\* SOURCE: core_4.14.2.3 Validate Sigma1 with Resumption
\* SOURCE: core_4.14.2.3 Generate and Send Sigma2
\* SOURCE: core_4.14.2.3 Generate and Send Sigma2_Resume
Responder_Validate_Sigma1 ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "Sigma1"
    /\ LET hasResID == pendingInput.resumptionID # Null
           hasMIC == pendingInput.initiatorResumeMIC # Null
           resumeValid == pendingInput.resume1MIC_valid
           destValid == pendingInput.destinationId \in ValidDestIDs
           sessionExists == pendingInput.resumptionID \in ValidResumptionIDs
           failParam == [state EXCEPT 
                            !.sentMessages = state.sentMessages \cup {[type |-> "StatusReport", code |-> "INVALID_PARAMETER"]}, 
                            !.responder.phase = "FAILED"]
           failRoots == [state EXCEPT 
                            !.sentMessages = state.sentMessages \cup {[type |-> "StatusReport", code |-> "NO_SHARED_TRUST_ROOTS"]}, 
                            !.responder.phase = "FAILED"]
           sendSigma2 == [state EXCEPT
                              !.responder.peerSessionId = pendingInput.initiatorSessionId,
                              !.responder.phase = "WAIT_SIGMA3",
                              !.sentMessages = state.sentMessages \cup {[
                                  type |-> "Sigma2",
                                  responderSessionId |-> 22,
                                  resumptionID |-> pendingInput.resumptionID,
                                  encrypted2_valid |-> TRUE,
                                  cert_valid |-> TRUE,
                                  sig_valid |-> TRUE ]}]
           sendSigma2Resume == [state EXCEPT
                                    !.responder.peerSessionId = pendingInput.initiatorSessionId,
                                    !.responder.phase = "WAIT_FINISHED",
                                    !.sentMessages = state.sentMessages \cup {[
                                        type |-> "Sigma2_Resume",
                                        responderSessionID |-> 22,
                                        resumptionID |-> pendingInput.resumptionID,
                                        sigma2ResumeMIC_valid |-> TRUE ]}]
       IN
       \/ /\ (hasResID /\ ~hasMIC) \/ (~hasResID /\ hasMIC)
          /\ state' = failParam
       \/ /\ hasResID /\ hasMIC
          /\ sessionExists
          /\ state' = (IF resumeValid THEN sendSigma2Resume ELSE (IF destValid THEN sendSigma2 ELSE failRoots))
       \* TODO: unspecified - Msg1 has resumption fields but no matching session is found. 
       \* Step 3 condition (single such session exists) fails, so it doesn't do resumption.
       \* Step 4 condition (does not contain fields) fails, so it doesn't say to do Destination ID.
       \* The spec text completely omits what to do in this state, so we leave it unhandled.
       \/ /\ ~hasResID /\ ~hasMIC
          /\ state' = (IF destValid THEN sendSigma2 ELSE failRoots)
    /\ pendingInput' = NoInput

\* SOURCE: core_4.14.2.3 Validate Sigma2
\* SOURCE: core_4.14.2.3 Generate and Send Sigma3
Initiator_Validate_Sigma2 ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "Sigma2"
    /\ state.initiator.phase = "WAIT_RESPONSE"
    /\ LET failParam == [state EXCEPT 
                            !.sentMessages = state.sentMessages \cup {[type |-> "StatusReport", code |-> "INVALID_PARAMETER"]}, 
                            !.initiator.phase = "FAILED"]
           sendSigma3 == [state EXCEPT
                              !.initiator.peerSessionId = pendingInput.responderSessionId,
                              !.initiator.resumptionId = pendingInput.resumptionID,
                              !.initiator.phase = "WAIT_FINISHED",
                              !.sentMessages = state.sentMessages \cup {[
                                  type |-> "Sigma3",
                                  encrypted3_valid |-> TRUE,
                                  cert_valid |-> TRUE,
                                  sig_valid |-> TRUE ]}]
           isValid == pendingInput.encrypted2_valid /\ pendingInput.cert_valid /\ pendingInput.sig_valid
       IN
       state' = IF isValid THEN sendSigma3 ELSE failParam
    /\ pendingInput' = NoInput

\* SOURCE: core_4.14.2.3 Validate Sigma2_Resume
\* SOURCE: core_4.14.2.3 SigmaFinished
Initiator_Validate_Sigma2_Resume ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "Sigma2_Resume"
    /\ state.initiator.phase = "WAIT_RESPONSE"
    /\ LET failParam == [state EXCEPT 
                            !.sentMessages = state.sentMessages \cup {[type |-> "StatusReport", code |-> "INVALID_PARAMETER"]}, 
                            !.initiator.phase = "FAILED"]
           sendFinished == [state EXCEPT
                                !.initiator.peerSessionId = pendingInput.responderSessionID,
                                !.initiator.resumptionId = pendingInput.resumptionID,
                                !.initiator.phase = "ESTABLISHED",
                                !.sentMessages = state.sentMessages \cup {[
                                    type |-> "StatusReport",
                                    code |-> "SESSION_ESTABLISHMENT_SUCCESS" ]}]
       IN
       state' = IF pendingInput.sigma2ResumeMIC_valid THEN sendFinished ELSE failParam
    /\ pendingInput' = NoInput

\* SOURCE: core_4.14.2.3 Validate Sigma3
\* SOURCE: core_4.14.2.3 SigmaFinished
Responder_Validate_Sigma3 ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "Sigma3"
    /\ state.responder.phase = "WAIT_SIGMA3"
    /\ LET failParam == [state EXCEPT 
                            !.sentMessages = state.sentMessages \cup {[type |-> "StatusReport", code |-> "INVALID_PARAMETER"]}, 
                            !.responder.phase = "FAILED"]
           sendFinished == [state EXCEPT
                                !.responder.phase = "ESTABLISHED",
                                !.sentMessages = state.sentMessages \cup {[
                                    type |-> "StatusReport",
                                    code |-> "SESSION_ESTABLISHMENT_SUCCESS" ]}]
           isValid == pendingInput.encrypted3_valid /\ pendingInput.cert_valid /\ pendingInput.sig_valid
       IN
       state' = IF isValid THEN sendFinished ELSE failParam
    /\ pendingInput' = NoInput

\* SOURCE: core_4.14.2.3 SigmaFinished
Handle_SigmaFinished ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "StatusReport"
    /\ pendingInput.code = "SESSION_ESTABLISHMENT_SUCCESS"
    /\ LET initMatch == state.initiator.phase = "WAIT_FINISHED"
           respMatch == state.responder.phase = "WAIT_FINISHED"
       IN
       IF initMatch THEN
           state' = [state EXCEPT !.initiator.phase = "ESTABLISHED"]
       ELSE IF respMatch THEN
           state' = [state EXCEPT !.responder.phase = "ESTABLISHED"]
       ELSE
           \* "If this message is received out-of-order or unexpectedly, then it SHALL be ignored."
           state' = state
    /\ pendingInput' = NoInput

\* SOURCE: core_4.14.2.3 Validate Sigma1 (implied session abort on sending StatusReport FAILURE)
Handle_StatusReport_Failure ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "StatusReport"
    /\ pendingInput.code # "SESSION_ESTABLISHMENT_SUCCESS"
    /\ state' = [state EXCEPT
           !.initiator.phase = IF state.initiator.phase \in {"WAIT_RESPONSE", "WAIT_FINISHED"} THEN "FAILED" ELSE state.initiator.phase,
           !.responder.phase = IF state.responder.phase \in {"WAIT_SIGMA3", "WAIT_FINISHED"} THEN "FAILED" ELSE state.responder.phase
       ]
    /\ pendingInput' = NoInput

Next ==
    \/ \E e \in Inputs : ReceiveInput(e)
    \/ Initiator_Start_CASE
    \/ Responder_Validate_Sigma1
    \/ Initiator_Validate_Sigma2
    \/ Initiator_Validate_Sigma2_Resume
    \/ Responder_Validate_Sigma3
    \/ Handle_SigmaFinished
    \/ Handle_StatusReport_Failure

====