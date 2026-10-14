---- MODULE core_4_8_2 ----
EXTENDS Naturals

\* Constant limits, thresholds, and fixed sets mentioned or implied by the spec
CONSTANTS 
    NoInput,
    SessionIDs,
    DestNodeIDs,
    NullValue,
    UnsecuredSession,
    SecureUnicastSession,
    GroupSession,
    Const_MaxMessageCounter \* Message counter space limit (e.g. 2^32 in reality)

VARIABLES 
    pendingInput,
    req_sessionId,
    req_destNodeId,
    req_securityFlags_C_Flag,
    req_messagePayload,
    req_messageFlags,
    req_messageExtensions,
    req_aeadFails,

    sessionKeys,
    sessionTypes,
    globalUnencryptedMessageCounter,
    secureSessionMessageCounters,
    globalGroupEncryptedDataMessageCounter,
    globalGroupEncryptedControlMessageCounter,
    myOperationalNodeId,

    out_status,
    out_message

Inputs == {"EncryptMessageRequest"}

\* --- Helper Definitions ---

\* Abstraction: Derives a 16-bit Group ID from a destination Node ID
DerivedGroupId(nodeId) == "DerivedGroupId"

\* Abstraction: Constructs the NONCE based on Table 17 rules
Nonce(msgFlags, sId, secFlags, cnt) == "MockNonce"

\* Abstraction: Crypto AEAD GenerateEncrypt function
Crypto_AEAD_GenerateEncrypt(K, P, A, N, fails) ==
    IF fails THEN NullValue ELSE "AEAD_Ciphertext_And_Tag"

\* Helper to format the Additional Data (A) cleanly without multi-line inline records
A_Record(msgFlags, sId, secFlags, cnt, src, dst, ext) ==
    [MessageFlags |-> msgFlags,
     SessionID |-> sId,
     SecurityFlags |-> secFlags,
     MessageCounter |-> cnt,
     SourceNodeID |-> src,
     DestinationNodeID |-> dst,
     MessageExtensions |-> ext]

\* --- Initialization ---

Init ==
    /\ pendingInput = NoInput
    /\ req_sessionId = NullValue
    /\ req_destNodeId = NullValue
    /\ req_securityFlags_C_Flag = 0
    /\ req_messagePayload = NullValue
    /\ req_messageFlags = [S |-> 0, DSIZ |-> 0]
    /\ req_messageExtensions = NullValue
    /\ req_aeadFails = FALSE
    /\ sessionKeys = [pair \in (SessionIDs \X DestNodeIDs) |-> NullValue]
    /\ sessionTypes = [d \in DestNodeIDs |-> NullValue]
    /\ globalUnencryptedMessageCounter = 0
    /\ secureSessionMessageCounters = [s \in SessionIDs |-> 0]
    /\ globalGroupEncryptedDataMessageCounter = 0
    /\ globalGroupEncryptedControlMessageCounter = 0
    /\ myOperationalNodeId = NullValue
    /\ out_status = "Idle"
    /\ out_message = NullValue

\* --- Input Reception ---

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<req_sessionId, req_destNodeId, req_securityFlags_C_Flag,
                   req_messagePayload, req_messageFlags, req_messageExtensions,
                   req_aeadFails, sessionKeys, sessionTypes,
                   globalUnencryptedMessageCounter, secureSessionMessageCounters,
                   globalGroupEncryptedDataMessageCounter,
                   globalGroupEncryptedControlMessageCounter, myOperationalNodeId,
                   out_status, out_message>>

\* --- Actions ---

\* SOURCE: core_4.8.2 1-8
EncryptMessage ==
    /\ pendingInput = "EncryptMessageRequest"
    /\ pendingInput' = NoInput
    /\ LET
        key == IF <<req_sessionId, req_destNodeId>> \in (SessionIDs \X DestNodeIDs) THEN sessionKeys[<<req_sessionId, req_destNodeId>>] ELSE NullValue
        sessionType == IF req_destNodeId \in DestNodeIDs THEN sessionTypes[req_destNodeId] ELSE NullValue
       IN
        IF key = NullValue THEN
            \* SOURCE: core_4.8.2 1.a (If no key is found, processing SHALL fail)
            /\ out_status' = "Failed"
            /\ out_message' = NullValue
            /\ UNCHANGED <<req_sessionId, req_destNodeId, req_securityFlags_C_Flag, req_messagePayload, req_messageFlags, req_messageExtensions, req_aeadFails, sessionKeys, sessionTypes, globalUnencryptedMessageCounter, secureSessionMessageCounters, globalGroupEncryptedDataMessageCounter, globalGroupEncryptedControlMessageCounter, myOperationalNodeId>>
        ELSE
            \* SOURCE: core_4.8.2 2 (Obtain outgoing message counter per 4.6.6)
            LET
                counter == IF sessionType = UnsecuredSession THEN globalUnencryptedMessageCounter ELSE IF sessionType = SecureUnicastSession THEN (IF req_sessionId \in SessionIDs THEN secureSessionMessageCounters[req_sessionId] ELSE NullValue) ELSE IF sessionType = GroupSession THEN (IF req_securityFlags_C_Flag = 0 THEN globalGroupEncryptedDataMessageCounter ELSE globalGroupEncryptedControlMessageCounter) ELSE NullValue
                nextCounter == IF counter = NullValue THEN NullValue ELSE (counter + 1) % Const_MaxMessageCounter
                counterWrapped == IF counter = NullValue THEN FALSE ELSE (counter = Const_MaxMessageCounter - 1)
            IN
            \* SOURCE: core_4.6.6 2, 3 (Increment and store counter)
            /\ globalUnencryptedMessageCounter' = IF sessionType = UnsecuredSession THEN nextCounter ELSE globalUnencryptedMessageCounter
            /\ secureSessionMessageCounters' = IF sessionType = SecureUnicastSession /\ req_sessionId \in SessionIDs THEN [secureSessionMessageCounters EXCEPT ![req_sessionId] = nextCounter] ELSE secureSessionMessageCounters
            /\ globalGroupEncryptedDataMessageCounter' = IF sessionType = GroupSession /\ req_securityFlags_C_Flag = 0 THEN nextCounter ELSE globalGroupEncryptedDataMessageCounter
            /\ globalGroupEncryptedControlMessageCounter' = IF sessionType = GroupSession /\ req_securityFlags_C_Flag = 1 THEN nextCounter ELSE globalGroupEncryptedControlMessageCounter
            
            \* SOURCE: core_4.6.6 3.a (Counter wrap-around expiry logic for Secure Unicast)
            /\ sessionKeys' = IF counterWrapped /\ sessionType = SecureUnicastSession /\ <<req_sessionId, req_destNodeId>> \in (SessionIDs \X DestNodeIDs) THEN [sessionKeys EXCEPT ![<<req_sessionId, req_destNodeId>>] = "Expired"] ELSE sessionKeys
            
            \* SOURCE: core_4.8.2 3, 4, 5, 6
            /\ LET
                isUnicast == (sessionType = SecureUnicastSession \/ sessionType = UnsecuredSession)
                sFlag == IF isUnicast THEN 0 ELSE IF sessionType = GroupSession THEN 1 ELSE 0
                dsiz == IF isUnicast THEN 0 ELSE IF sessionType = GroupSession THEN 2 ELSE 0
                msgDestNodeId == IF isUnicast THEN "Omitted" ELSE IF sessionType = GroupSession THEN DerivedGroupId(req_destNodeId) ELSE "Omitted"
                msgSourceNodeId == IF isUnicast THEN "Omitted" ELSE IF sessionType = GroupSession THEN myOperationalNodeId ELSE "Omitted"
                msgFlags == [req_messageFlags EXCEPT !.S = sFlag, !.DSIZ = dsiz]
                
                \* Mock updated Security Flags as per 3.b.i
                msgSecurityFlags == [SessionType |-> sessionType, C_Flag |-> req_securityFlags_C_Flag]
                
                A == A_Record(msgFlags, req_sessionId, msgSecurityFlags, counter, msgSourceNodeId, msgDestNodeId, req_messageExtensions)
                N == Nonce(msgFlags, req_sessionId, msgSecurityFlags, counter)
                C == Crypto_AEAD_GenerateEncrypt(key, req_messagePayload, A, N, req_aeadFails)
               IN
                IF C = NullValue THEN
                    \* SOURCE: core_4.8.2 7 (If AEAD fails, security processing SHALL fail)
                    /\ out_status' = "Failed"
                    /\ out_message' = NullValue
                ELSE
                    \* SOURCE: core_4.8.2 8 (Secured outgoing message assembly)
                    /\ out_status' = "Success"
                    /\ out_message' = [Header |-> A, CiphertextAndTag |-> C]
            /\ UNCHANGED <<req_sessionId, req_destNodeId, req_securityFlags_C_Flag, req_messagePayload, req_messageFlags, req_messageExtensions, req_aeadFails, sessionTypes, myOperationalNodeId>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ EncryptMessage

====