---- MODULE core_4_8_2 ----
EXTENDS Naturals

\* 
\* CONSTANTS
\* 
CONSTANTS 
    NoInput,           \* sentinel: nothing is waiting to be handled
    MaxCounter,        \* Message counter space upper bound (e.g. 2^32 in spec, use small int for model)
    MyNodeId,          \* The operational node id of the sending node
    NoSession,         \* Sentinel indicating no session exists for a given ID/Node
    SessionIDs,        \* Finite set of possible Session IDs
    NodeIDs            \* Finite set of possible Node IDs

\*
\* VARIABLES
\*
VARIABLES 
    pendingInput,
    inputData,
    sessionStore,
    globalUnencryptedCounter,
    globalGroupDataCounter,
    globalGroupControlCounter,
    sessionCounters,
    outputBuffer,
    processingStatus

\* 
\* DEFINITIONS & HELPERS
\* 
Inputs == {"SendOutgoingMessage"}

Operational == TRUE

SessionTypes == {"Unsecured", "SecureUnicast", "Group"}

PossibleSessions == {NoSession} \cup {[key |-> "Key", sessionType |-> t] : t \in SessionTypes}

\* TODO: unspecified - exact derivation of 16-bit Group ID from Destination Node ID is abstracted.
DeriveGroupId(nid) == nid

NewInputData(sid, did, t, c) ==
    [sessionID     |-> sid,
     destNodeID    |-> did,
     securityFlags |-> [sessionType |-> t],
     cFlag         |-> c,
     payload       |-> "DATA",
     extensions    |-> "EXT"]

ConstructHeader(msgFlags, sid, secFlags, ctr, src, dst, exts) ==
    [msgFlags   |-> msgFlags,
     sessionID  |-> sid,
     secFlags   |-> secFlags,
     msgCounter |-> ctr,
     srcNodeId  |-> src,
     dstNodeId  |-> dst,
     extensions |-> exts]

\*
\* INITIALIZATION
\*
Init ==
    /\ pendingInput = NoInput
    /\ inputData = NewInputData("SID_INIT", "NID_INIT", "Unsecured", 0)
    /\ sessionStore \in [SessionIDs -> [NodeIDs -> PossibleSessions]]
    /\ globalUnencryptedCounter = 0
    /\ globalGroupDataCounter = 0
    /\ globalGroupControlCounter = 0
    /\ sessionCounters = [s \in SessionIDs |-> 0]
    /\ outputBuffer = {}
    /\ processingStatus = "IDLE"

\*
\* ACTIONS
\*

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E sid \in SessionIDs, did \in NodeIDs, t \in SessionTypes, c \in {0, 1} :
           inputData' = NewInputData(sid, did, t, c)
    /\ UNCHANGED <<sessionStore, globalUnencryptedCounter, globalGroupDataCounter, globalGroupControlCounter, sessionCounters, outputBuffer, processingStatus>>

\* SOURCE: core_4.8.2 Security Processing of Outgoing Messages
ProcessOutgoingMessage ==
    /\ pendingInput = "SendOutgoingMessage"
    /\ LET session == sessionStore[inputData.sessionID][inputData.destNodeID] IN
       IF session = NoSession THEN
           /\ processingStatus' = "FAIL_NO_KEY"
           /\ pendingInput' = NoInput
           /\ UNCHANGED <<inputData, sessionStore, globalUnencryptedCounter, globalGroupDataCounter, globalGroupControlCounter, sessionCounters, outputBuffer>>
       ELSE
           LET key == session.key
               type == session.sessionType
               ctr == 
                   IF type = "Unsecured" THEN globalUnencryptedCounter
                   ELSE 
                       IF type = "SecureUnicast" THEN sessionCounters[inputData.sessionID]
                       ELSE 
                           IF type = "Group" THEN
                               (IF inputData.cFlag = 0 THEN globalGroupDataCounter ELSE globalGroupControlCounter)
                           ELSE 0
               msgFlags == [S |-> IF type = "Group" THEN 1 ELSE 0, DSIZ |-> IF type = "Group" THEN 2 ELSE 0]
               secFlags == [inputData.securityFlags EXCEPT !.sessionType = type]
               srcNode == IF type = "Group" THEN MyNodeId ELSE "Omit"
               dstNode == IF type = "Group" THEN DeriveGroupId(inputData.destNodeID) ELSE "Omit"
               header == ConstructHeader(msgFlags, inputData.sessionID, secFlags, ctr, srcNode, dstNode, inputData.extensions)
           IN
           \* TODO: unspecified - Nonce construction per Table 17 is abstracted, AEAD logic combined into basic success/fail mapping.
           /\ \E aeadError \in BOOLEAN :
                  IF aeadError THEN
                      /\ processingStatus' = "FAIL_AEAD"
                      /\ UNCHANGED outputBuffer
                  ELSE
                      /\ processingStatus' = "SUCCESS"
                      /\ outputBuffer' = outputBuffer \cup {[header |-> header, ciphertext |-> inputData.payload, mac |-> "MIC"]}
           /\ pendingInput' = NoInput
           /\ UNCHANGED <<inputData, sessionStore>>
           /\ IF type = "Unsecured" THEN
                  /\ globalUnencryptedCounter' = (globalUnencryptedCounter + 1) % MaxCounter
                  /\ UNCHANGED <<sessionCounters, globalGroupDataCounter, globalGroupControlCounter>>
              ELSE 
                  IF type = "SecureUnicast" THEN
                      /\ sessionCounters' = [sessionCounters EXCEPT ![inputData.sessionID] = (@ + 1) % MaxCounter]
                      \* TODO: unspecified - spec text 4.6.6 cuts off regarding Encryption Key expiration on wrap-around, omitting expiration
                      /\ UNCHANGED <<globalUnencryptedCounter, globalGroupDataCounter, globalGroupControlCounter>>
                  ELSE 
                      IF type = "Group" THEN
                          /\ IF inputData.cFlag = 0 THEN
                                 /\ globalGroupDataCounter' = (globalGroupDataCounter + 1) % MaxCounter
                                 /\ UNCHANGED <<globalGroupControlCounter>>
                             ELSE
                                 /\ globalGroupControlCounter' = (globalGroupControlCounter + 1) % MaxCounter
                                 /\ UNCHANGED <<globalGroupDataCounter>>
                          /\ UNCHANGED <<globalUnencryptedCounter, sessionCounters>>
                      ELSE
                          UNCHANGED <<globalUnencryptedCounter, sessionCounters, globalGroupDataCounter, globalGroupControlCounter>>

Next ==
    \/ \E e \in Inputs : ReceiveInput(e)
    \/ ProcessOutgoingMessage

====