---- MODULE core_4_14_2_3 ----
EXTENDS Naturals

\* Sentinel values
CONSTANTS NoInput
CONSTANTS NotSet

\* Finite set of abstract identifiers to avoid infinite state space (Rule 12, Rule 14)
CONSTANTS Ids

\* Max value for abstract clock to keep state space finite
CONSTANTS MaxClock

VARIABLES pendingInput
VARIABLES msgIn
VARIABLES state
VARIABLES role
VARIABLES sessionCtx
VARIABLES activeSessions
VARIABLES localNOCs
VARIABLES outbox
VARIABLES clock

\* Rule 4a: Required event inputs
Inputs == {
    "InitiateCASE",
    "InitiateCASEResumption",
    "ReceiveSigma1",
    "ReceiveSigma2",
    "ReceiveSigma3",
    "ReceiveSigma2Resume",
    "ReceiveSigmaFinished",
    "ReceiveStatusReport"
}

Booleans == {TRUE, FALSE}
OptionalIds == Ids \cup {NotSet}

\* Construct the finite message space for incoming events
MessageSpace(e) ==
    IF e = "InitiateCASE" THEN
        {[destinationId |-> d] : d \in Ids}
    ELSE IF e = "InitiateCASEResumption" THEN
        {[destinationId |-> d, resumptionID |-> r] : d \in Ids, r \in Ids}
    ELSE IF e = "ReceiveSigma1" THEN
        [initiatorSessionId : Ids, destinationId : Ids, resumptionID : OptionalIds, initiatorResumeMIC : OptionalIds, validResumeMIC : Booleans]
    ELSE IF e = "ReceiveSigma2" THEN
        [responderSessionId : Ids, resumptionID : Ids, validDecrypt : Booleans, validCert : Booleans, validSignature : Booleans]
    ELSE IF e = "ReceiveSigma3" THEN
        [validDecrypt : Booleans, validCert : Booleans, validSignature : Booleans]
    ELSE IF e = "ReceiveSigma2Resume" THEN
        [responderSessionId : Ids, resumptionID : Ids, validDecrypt : Booleans]
    ELSE IF e = "ReceiveSigmaFinished" THEN
        {NotSet}
    ELSE IF e = "ReceiveStatusReport" THEN
        {[code |-> c] : c \in {"INVALID_PARAMETER", "NO_SHARED_TRUST_ROOTS", "FAILURE"}}
    ELSE
        {NotSet}

Init ==
    /\ pendingInput = NoInput
    /\ msgIn = NotSet
    /\ state = "IDLE"
    /\ role = "NONE"
    /\ sessionCtx = [localSessionId |-> NotSet, peerSessionId |-> NotSet, resumptionId |-> NotSet]
    /\ activeSessions = {}
    /\ localNOCs = Ids
    /\ outbox = {}
    /\ clock = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E m \in MessageSpace(e) : msgIn' = m
    /\ UNCHANGED <<state, role, sessionCtx, activeSessions, localNOCs, outbox, clock>>

\* SOURCE: core_4.14.2.3 Generate and Send Sigma1
HandleInitiateCASE ==
    /\ pendingInput = "InitiateCASE"
    /\ state = "IDLE"
    /\ sessionCtx' = [sessionCtx EXCEPT !.localSessionId = "LocalSess"]
    /\ role' = "INITIATOR"
    /\ state' = "WAIT_SIGMA2_OR_RESUME"
    /\ outbox' = outbox \cup {[type |-> "Sigma1", resumptionID |-> NotSet]}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<msgIn, activeSessions, localNOCs, clock>>

\* SOURCE: core_4.14.2.3 Generate and Send Sigma1 (with resumption)
HandleInitiateCASEResumption ==
    /\ pendingInput = "InitiateCASEResumption"
    /\ state = "IDLE"
    /\ sessionCtx' = [sessionCtx EXCEPT !.localSessionId = "LocalSess"]
    /\ role' = "INITIATOR"
    /\ state' = "WAIT_SIGMA2_OR_RESUME"
    /\ outbox' = outbox \cup {[type |-> "Sigma1", resumptionID |-> msgIn.resumptionID]}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<msgIn, activeSessions, localNOCs, clock>>

\* Helper for Validate Sigma1 Destination ID logic to keep main action flat
ValidateSigma1DestIdHelper ==
    IF msgIn.destinationId \in localNOCs THEN
        /\ sessionCtx' = [sessionCtx EXCEPT !.peerSessionId = msgIn.initiatorSessionId,
                                            !.localSessionId = "LocalSess",
                                            !.resumptionId = "NewResId"]
        /\ role' = "RESPONDER"
        /\ state' = "WAIT_SIGMA3"
        /\ outbox' = outbox \cup {[type |-> "Sigma2"]}
        /\ UNCHANGED <<activeSessions, clock>>
    ELSE
        /\ outbox' = outbox \cup {[type |-> "StatusReport", code |-> "NO_SHARED_TRUST_ROOTS"]}
        /\ UNCHANGED <<state, role, sessionCtx, activeSessions, clock>>

\* SOURCE: core_4.14.2.3 Validate Sigma1
\* SOURCE: core_4.14.2.3 Validate Sigma1 Destination ID
\* SOURCE: core_4.14.2.3 Validate Sigma1 with Resumption
\* SOURCE: core_4.14.2.3 Generate and Send Sigma2
\* SOURCE: core_4.14.2.3 Generate and Send Sigma2_Resume
HandleReceiveSigma1 ==
    /\ pendingInput = "ReceiveSigma1"
    /\ state = "IDLE"
    /\ \/ /\ (msgIn.resumptionID # NotSet /\ msgIn.initiatorResumeMIC = NotSet) \/ (msgIn.resumptionID = NotSet /\ msgIn.initiatorResumeMIC # NotSet)
          /\ outbox' = outbox \cup {[type |-> "StatusReport", code |-> "INVALID_PARAMETER"]}
          /\ UNCHANGED <<state, role, sessionCtx, activeSessions, clock>>
       \/ /\ msgIn.resumptionID # NotSet
          /\ msgIn.initiatorResumeMIC # NotSet
          /\ IF \E s \in activeSessions : s.resumptionId = msgIn.resumptionID THEN
                 \* TODO: unspecified - what happens if multiple matching sessions exist? The spec assumes single match.
                 IF msgIn.validResumeMIC THEN
                     /\ sessionCtx' = [sessionCtx EXCEPT !.peerSessionId = msgIn.initiatorSessionId,
                                                         !.localSessionId = "LocalSess"]
                     /\ role' = "RESPONDER"
                     /\ state' = "WAIT_SIGMA_FINISHED"
                     /\ outbox' = outbox \cup {[type |-> "Sigma2_Resume"]}
                     /\ UNCHANGED <<activeSessions, clock>>
                 ELSE
                     ValidateSigma1DestIdHelper
             ELSE
                 \* TODO: unspecified - what happens if resumption fields are present but no matching session is found?
                 UNCHANGED <<state, role, sessionCtx, activeSessions, outbox, clock>>
       \/ /\ msgIn.resumptionID = NotSet
          /\ msgIn.initiatorResumeMIC = NotSet
          /\ ValidateSigma1DestIdHelper
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<msgIn, localNOCs>>

\* SOURCE: core_4.14.2.3 Validate Sigma2
\* SOURCE: core_4.14.2.3 Generate and Send Sigma3
HandleReceiveSigma2 ==
    /\ pendingInput = "ReceiveSigma2"
    /\ state = "WAIT_SIGMA2_OR_RESUME"
    /\ role = "INITIATOR"
    /\ IF ~msgIn.validDecrypt \/ ~msgIn.validCert \/ ~msgIn.validSignature THEN
           /\ outbox' = outbox \cup {[type |-> "StatusReport", code |-> "INVALID_PARAMETER"]}
           /\ UNCHANGED <<state, role, sessionCtx, activeSessions, clock>>
       ELSE
           /\ sessionCtx' = [sessionCtx EXCEPT !.resumptionId = msgIn.resumptionID,
                                               !.peerSessionId = msgIn.responderSessionId]
           /\ state' = "WAIT_SIGMA_FINISHED"
           /\ outbox' = outbox \cup {[type |-> "Sigma3"]}
           /\ UNCHANGED <<role, activeSessions, clock>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<msgIn, localNOCs>>

\* SOURCE: core_4.14.2.3 Validate Sigma3
\* SOURCE: core_4.14.2.3 SigmaFinished
HandleReceiveSigma3 ==
    /\ pendingInput = "ReceiveSigma3"
    /\ state = "WAIT_SIGMA3"
    /\ role = "RESPONDER"
    /\ IF ~msgIn.validDecrypt \/ ~msgIn.validCert \/ ~msgIn.validSignature THEN
           /\ outbox' = outbox \cup {[type |-> "StatusReport", code |-> "INVALID_PARAMETER"]}
           /\ UNCHANGED <<state, sessionCtx, activeSessions, clock>>
       ELSE
           /\ state' = "ESTABLISHED"
           /\ clock' = IF clock < MaxClock THEN clock + 1 ELSE clock
           /\ activeSessions' = activeSessions \cup {sessionCtx}
           /\ outbox' = outbox \cup {[type |-> "SigmaFinished"]}
           /\ UNCHANGED <<sessionCtx>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<msgIn, role, localNOCs>>

\* SOURCE: core_4.14.2.3 Validate Sigma2_Resume
\* SOURCE: core_4.14.2.3 SigmaFinished
HandleReceiveSigma2Resume ==
    /\ pendingInput = "ReceiveSigma2Resume"
    /\ state = "WAIT_SIGMA2_OR_RESUME"
    /\ role = "INITIATOR"
    /\ IF ~msgIn.validDecrypt THEN
           /\ outbox' = outbox \cup {[type |-> "StatusReport", code |-> "INVALID_PARAMETER"]}
           /\ UNCHANGED <<state, sessionCtx, activeSessions, clock, role>>
       ELSE
           /\ sessionCtx' = [sessionCtx EXCEPT !.resumptionId = msgIn.resumptionID,
                                               !.peerSessionId = msgIn.responderSessionId]
           /\ state' = "ESTABLISHED"
           /\ clock' = IF clock < MaxClock THEN clock + 1 ELSE clock
           /\ activeSessions' = activeSessions \cup {sessionCtx'}
           /\ outbox' = outbox \cup {[type |-> "SigmaFinished"]}
           /\ UNCHANGED <<role>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<msgIn, localNOCs>>

\* SOURCE: core_4.14.2.3 SigmaFinished
HandleReceiveSigmaFinished ==
    /\ pendingInput = "ReceiveSigmaFinished"
    /\ state = "WAIT_SIGMA_FINISHED"
    /\ state' = "ESTABLISHED"
    /\ clock' = IF clock < MaxClock THEN clock + 1 ELSE clock
    /\ activeSessions' = activeSessions \cup {sessionCtx}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<msgIn, role, sessionCtx, localNOCs, outbox>>

\* SOURCE: core_4.14.2.3 SigmaFinished (unexpected reception logic)
HandleUnexpectedSigmaFinished ==
    /\ pendingInput = "ReceiveSigmaFinished"
    /\ state # "WAIT_SIGMA_FINISHED"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<msgIn, state, role, sessionCtx, activeSessions, localNOCs, outbox, clock>>

\* SOURCE: core_4.14.2.3 Validate Sigma1 (implicit abort processing logic on status report)
HandleReceiveStatusReport ==
    /\ pendingInput = "ReceiveStatusReport"
    /\ state # "IDLE"
    /\ state' = "IDLE"
    /\ role' = "NONE"
    /\ sessionCtx' = [localSessionId |-> NotSet, peerSessionId |-> NotSet, resumptionId |-> NotSet]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<msgIn, activeSessions, localNOCs, outbox, clock>>

Next ==
    \/ \E e \in Inputs : ReceiveInput(e)
    \/ HandleInitiateCASE
    \/ HandleInitiateCASEResumption
    \/ HandleReceiveSigma1
    \/ HandleReceiveSigma2
    \/ HandleReceiveSigma3
    \/ HandleReceiveSigma2Resume
    \/ HandleReceiveSigmaFinished
    \/ HandleUnexpectedSigmaFinished
    \/ HandleReceiveStatusReport

====