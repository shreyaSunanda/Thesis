---- MODULE core_4_14_2_3 ----
EXTENDS Naturals

\* CONSTANTS
\* Nodes: The set of nodes participating in the protocol.
\* SessionIds: The finite set of allowed local session identifiers.
\* ResumptionIds: The finite set of allowed resumption identifiers.
\* Null: A sentinel value representing the absence of a value.
CONSTANTS Nodes, SessionIds, ResumptionIds, Null

VARIABLES 
    network,            \* Set of all messages sent over the network
    activeSessions,     \* activeSessions[node] = Subset of SessionIds currently active for the node
    sessionContexts,    \* sessionContexts[node][sessionId] = Record containing session metadata
    caseState,          \* caseState[node][peer] = Handshake state tracking ("IDLE", "WAIT_SIGMA2", etc.)
    resumptionContext   \* resumptionContext[node][peer] = Stored resumptionId from a previous successful session

\* Helper definitions for creating complex records safely at the top level
InitialSessionContext(role, peerSid, rid) ==
    [sessionType         |-> "CASE",
     sessionRole         |-> role,
     peerSessionId       |-> peerSid,
     resumptionId        |-> rid,
     localMessageCounter |-> 0]

NullSessionContext ==
    [sessionType         |-> Null,
     sessionRole         |-> Null,
     peerSessionId       |-> Null,
     resumptionId        |-> Null,
     localMessageCounter |-> 0]

\* Message constructors
Sigma1Msg(sender, receiver, isid, rid) ==
    [msgType            |-> "Sigma1",
     sender             |-> sender,
     receiver           |-> receiver,
     exchangeId         |-> isid,
     initiatorSessionId |-> isid,
     resumptionID       |-> rid]

Sigma2Msg(sender, receiver, isid, rsid, rid) ==
    [msgType            |-> "Sigma2",
     sender             |-> sender,
     receiver           |-> receiver,
     exchangeId         |-> isid,
     responderSessionId |-> rsid,
     resumptionID       |-> rid]

Sigma2ResumeMsg(sender, receiver, isid, rsid, rid) ==
    [msgType            |-> "Sigma2_Resume",
     sender             |-> sender,
     receiver           |-> receiver,
     exchangeId         |-> isid,
     responderSessionId |-> rsid,
     resumptionID       |-> rid]

Sigma3Msg(sender, receiver, isid) ==
    [msgType            |-> "Sigma3",
     sender             |-> sender,
     receiver           |-> receiver,
     exchangeId         |-> isid]

SigmaFinishedMsg(sender, receiver, isid) ==
    [msgType            |-> "SigmaFinished",
     sender             |-> sender,
     receiver           |-> receiver,
     exchangeId         |-> isid]

StatusReportMsg(sender, receiver, isid, status) ==
    [msgType            |-> "StatusReport",
     sender             |-> sender,
     receiver           |-> receiver,
     exchangeId         |-> isid,
     status             |-> status]

Init ==
    /\ network = {}
    /\ activeSessions = [n \in Nodes |-> {}]
    /\ sessionContexts = [n \in Nodes |-> [sid \in SessionIds |-> NullSessionContext]]
    /\ caseState = [n \in Nodes |-> [p \in Nodes |-> "IDLE"]]
    /\ resumptionContext = [n \in Nodes |-> [p \in Nodes |-> Null]]

\* SOURCE: core_4.14.2.3 Generate and Send Sigma1
GenerateAndSendSigma1(initiator, responder, useResumption, isid) ==
    /\ initiator # responder
    /\ caseState[initiator][responder] = "IDLE"
    /\ isid \in SessionIds \ activeSessions[initiator]
    /\ LET rid == IF useResumption THEN resumptionContext[initiator][responder] ELSE Null IN
       /\ (useResumption => rid # Null)
       /\ network' = network \cup {Sigma1Msg(initiator, responder, isid, rid)}
       /\ caseState' = [caseState EXCEPT ![initiator][responder] = "WAIT_SIGMA2"]
       /\ activeSessions' = [activeSessions EXCEPT ![initiator] = @ \cup {isid}]
       /\ sessionContexts' = [sessionContexts EXCEPT ![initiator][isid] = InitialSessionContext("INITIATOR", Null, rid)]
    /\ UNCHANGED resumptionContext

\* SOURCE: core_4.14.2.3 Validate Sigma1, Validate Sigma1 Destination ID, Validate Sigma1 with Resumption, Generate and Send Sigma2, Generate and Send Sigma2_Resume
\* acceptDestination and acceptResumption abstract the underlying cryptographic checks.
ValidateSigma1(responder, msg, acceptDestination, acceptResumption, rsid, newRid) ==
    /\ msg \in network
    /\ msg.msgType = "Sigma1"
    /\ msg.receiver = responder
    /\ caseState[responder][msg.sender] = "IDLE"
    /\ rsid \in SessionIds \ activeSessions[responder]
    /\ newRid \in ResumptionIds
    /\ LET isResumptionAttempt == msg.resumptionID # Null
           isValidResumption == (msg.resumptionID = resumptionContext[responder][msg.sender]) /\ acceptResumption
       IN
       \/ /\ isResumptionAttempt
          /\ isValidResumption
          \* Validate Sigma1 with Resumption -> Send Sigma2_Resume
          /\ network' = network \cup {Sigma2ResumeMsg(responder, msg.sender, msg.exchangeId, rsid, newRid)}
          /\ caseState' = [caseState EXCEPT ![responder][msg.sender] = "WAIT_SIGMA_FINISHED"]
          /\ activeSessions' = [activeSessions EXCEPT ![responder] = @ \cup {rsid}]
          /\ sessionContexts' = [sessionContexts EXCEPT ![responder][rsid] = InitialSessionContext("RESPONDER", msg.exchangeId, msg.resumptionID)]
       \/ /\ (~isResumptionAttempt \/ ~isValidResumption)
          /\ acceptDestination
          \* Fallback / No resumption -> Send Sigma2
          /\ network' = network \cup {Sigma2Msg(responder, msg.sender, msg.exchangeId, rsid, newRid)}
          /\ caseState' = [caseState EXCEPT ![responder][msg.sender] = "WAIT_SIGMA3"]
          /\ activeSessions' = [activeSessions EXCEPT ![responder] = @ \cup {rsid}]
          /\ sessionContexts' = [sessionContexts EXCEPT ![responder][rsid] = InitialSessionContext("RESPONDER", msg.exchangeId, newRid)]
       \/ /\ (~isResumptionAttempt \/ ~isValidResumption)
          /\ ~acceptDestination
          \* NO_SHARED_TRUST_ROOTS -> FAILURE
          /\ network' = network \cup {StatusReportMsg(responder, msg.sender, msg.exchangeId, "FAILURE")}
          /\ UNCHANGED <<caseState, activeSessions, sessionContexts>>
    /\ UNCHANGED resumptionContext

\* SOURCE: core_4.14.2.3 Validate Sigma2, Generate and Send Sigma3
ValidateSigma2(initiator, msg, acceptCrypto) ==
    /\ msg \in network
    /\ msg.msgType = "Sigma2"
    /\ msg.receiver = initiator
    /\ caseState[initiator][msg.sender] = "WAIT_SIGMA2"
    /\ \E isid \in activeSessions[initiator] :
        /\ sessionContexts[initiator][isid].sessionRole = "INITIATOR"
        /\ msg.exchangeId = isid
        /\ IF acceptCrypto THEN
               /\ network' = network \cup {Sigma3Msg(initiator, msg.sender, isid)}
               /\ sessionContexts' = [sessionContexts EXCEPT ![initiator][isid].peerSessionId = msg.responderSessionId, ![initiator][isid].resumptionId = msg.resumptionID]
               /\ caseState' = [caseState EXCEPT ![initiator][msg.sender] = "WAIT_SIGMA_FINISHED"]
           ELSE
               /\ network' = network \cup {StatusReportMsg(initiator, msg.sender, isid, "FAILURE")}
               /\ caseState' = [caseState EXCEPT ![initiator][msg.sender] = "IDLE"]
               /\ UNCHANGED sessionContexts
    /\ UNCHANGED <<activeSessions, resumptionContext>>

\* SOURCE: core_4.14.2.3 Validate Sigma2_Resume, SigmaFinished
ValidateSigma2Resume(initiator, msg, acceptCrypto) ==
    /\ msg \in network
    /\ msg.msgType = "Sigma2_Resume"
    /\ msg.receiver = initiator
    /\ caseState[initiator][msg.sender] = "WAIT_SIGMA2"
    /\ \E isid \in activeSessions[initiator] :
        /\ sessionContexts[initiator][isid].sessionRole = "INITIATOR"
        /\ msg.exchangeId = isid
        /\ IF acceptCrypto THEN
               /\ network' = network \cup {SigmaFinishedMsg(initiator, msg.sender, isid)}
               /\ sessionContexts' = [sessionContexts EXCEPT ![initiator][isid].peerSessionId = msg.responderSessionId, ![initiator][isid].resumptionId = msg.resumptionID, ![initiator][isid].localMessageCounter = 1]
               /\ caseState' = [caseState EXCEPT ![initiator][msg.sender] = "ESTABLISHED"]
               /\ resumptionContext' = [resumptionContext EXCEPT ![initiator][msg.sender] = msg.resumptionID]
           ELSE
               /\ network' = network \cup {StatusReportMsg(initiator, msg.sender, isid, "FAILURE")}
               /\ caseState' = [caseState EXCEPT ![initiator][msg.sender] = "IDLE"]
               /\ UNCHANGED <<sessionContexts, resumptionContext>>
    /\ UNCHANGED activeSessions

\* SOURCE: core_4.14.2.3 Validate Sigma3
ValidateSigma3(responder, msg, acceptCrypto) ==
    /\ msg \in network
    /\ msg.msgType = "Sigma3"
    /\ msg.receiver = responder
    /\ caseState[responder][msg.sender] = "WAIT_SIGMA3"
    /\ \E rsid \in activeSessions[responder] :
        /\ sessionContexts[responder][rsid].sessionRole = "RESPONDER"
        /\ sessionContexts[responder][rsid].peerSessionId = msg.exchangeId
        /\ IF acceptCrypto THEN
               /\ network' = network \cup {SigmaFinishedMsg(responder, msg.sender, msg.exchangeId)}
               /\ sessionContexts' = [sessionContexts EXCEPT ![responder][rsid].localMessageCounter = 1]
               /\ caseState' = [caseState EXCEPT ![responder][msg.sender] = "ESTABLISHED"]
               /\ resumptionContext' = [resumptionContext EXCEPT ![responder][msg.sender] = sessionContexts[responder][rsid].resumptionId]
           ELSE
               /\ network' = network \cup {StatusReportMsg(responder, msg.sender, msg.exchangeId, "FAILURE")}
               /\ caseState' = [caseState EXCEPT ![responder][msg.sender] = "IDLE"]
               /\ UNCHANGED <<sessionContexts, resumptionContext>>
    /\ UNCHANGED activeSessions

\* SOURCE: core_4.14.2.3 SigmaFinished
ReceiveSigmaFinished(node, msg) ==
    /\ msg \in network
    /\ msg.msgType = "SigmaFinished"
    /\ msg.receiver = node
    /\ caseState[node][msg.sender] = "WAIT_SIGMA_FINISHED"
    /\ \E sid \in activeSessions[node] :
        /\ IF sessionContexts[node][sid].sessionRole = "INITIATOR"
           THEN sid = msg.exchangeId
           ELSE sessionContexts[node][sid].peerSessionId = msg.exchangeId
        /\ sessionContexts' = [sessionContexts EXCEPT ![node][sid].localMessageCounter = 1]
        /\ caseState' = [caseState EXCEPT ![node][msg.sender] = "ESTABLISHED"]
        /\ resumptionContext' = [resumptionContext EXCEPT ![node][msg.sender] = sessionContexts[node][sid].resumptionId]
    /\ UNCHANGED <<network, activeSessions>>

\* SOURCE: core_4.14.2.3 Protocol Details - Validate Sigma1 / Validate Sigma2 / Validate Sigma3
ReceiveStatusReport(node, msg) ==
    /\ msg \in network
    /\ msg.msgType = "StatusReport"
    /\ msg.receiver = node
    /\ msg.status = "FAILURE"
    /\ caseState' = [caseState EXCEPT ![node][msg.sender] = "IDLE"]
    /\ UNCHANGED <<network, activeSessions, sessionContexts, resumptionContext>>

\* SOURCE: core_4.13.2.4 Choosing Secure Unicast Session Identifiers
TerminateSession(node, sid) ==
    /\ sid \in activeSessions[node]
    /\ activeSessions' = [activeSessions EXCEPT ![node] = @ \ {sid}]
    /\ sessionContexts' = [sessionContexts EXCEPT ![node][sid] = NullSessionContext]
    /\ UNCHANGED <<network, caseState, resumptionContext>>

Next ==
    \/ \E initiator, responder \in Nodes, useResumption \in {TRUE, FALSE}, isid \in SessionIds :
           GenerateAndSendSigma1(initiator, responder, useResumption, isid)
    \/ \E responder \in Nodes, msg \in network, acceptDestination \in {TRUE, FALSE}, acceptResumption \in {TRUE, FALSE}, rsid \in SessionIds, newRid \in ResumptionIds :
           ValidateSigma1(responder, msg, acceptDestination, acceptResumption, rsid, newRid)
    \/ \E initiator \in Nodes, msg \in network, acceptCrypto \in {TRUE, FALSE} :
           ValidateSigma2(initiator, msg, acceptCrypto)
    \/ \E initiator \in Nodes, msg \in network, acceptCrypto \in {TRUE, FALSE} :
           ValidateSigma2Resume(initiator, msg, acceptCrypto)
    \/ \E responder \in Nodes, msg \in network, acceptCrypto \in {TRUE, FALSE} :
           ValidateSigma3(responder, msg, acceptCrypto)
    \/ \E node \in Nodes, msg \in network :
           ReceiveSigmaFinished(node, msg)
    \/ \E node \in Nodes, msg \in network :
           ReceiveStatusReport(node, msg)
    \/ \E node \in Nodes, sid \in SessionIds :
           TerminateSession(node, sid)

====