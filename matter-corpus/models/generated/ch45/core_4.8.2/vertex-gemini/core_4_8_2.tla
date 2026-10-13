---- MODULE core_4_8_2 ----
EXTENDS Naturals, Sequences

CONSTANTS 
    NullKey,
    UnicastSessionType,
    GroupSessionType,
    CryptoError,
    MyOperationalNodeId,
    Omitted

VARIABLES 
    workflow_step,
    in_session_id,
    in_dest_node_id,
    in_security_flags,
    in_payload,
    in_extensions,
    
    \* External state assumed by the spec for lookups
    key_store,
    session_type_store,
    counter_store,

    \* Internal state steps 1-8
    enc_key,
    sess_type,
    msg_counter,
    
    msg_SessionID,
    msg_SecurityFlags,
    msg_MessageFlags_S,
    msg_MessageFlags_DSIZ,
    msg_SourceNodeID,
    msg_DestinationNodeID,
    msg_MessageCounter,
    
    aead_c,
    final_secure_message

\* TODO: unspecified - 16-bit Group ID derived from Destination Node ID
DeriveGroupId(did) == did 

\* TODO: unspecified - CRYPTO_AEAD_NONCE_LENGTH_BYTES-octet string constructed according to Table 17
ConstructNonce(key) == <<>> 

\* Abstract representation of Crypto_AEAD_GenerateEncrypt
Crypto_AEAD_GenerateEncrypt(K, P, A, N) == <<K, P, A, N>> 

ConstructAdditionalData(flags_S, flags_DSIZ, session_id, sec_flags, counter, src_node, dest_node, exts) ==
    LET base == <<flags_S, flags_DSIZ, session_id, sec_flags, counter>>
        src == IF src_node # Omitted THEN <<src_node>> ELSE <<>>
        dest == IF dest_node # Omitted THEN <<dest_node>> ELSE <<>>
    IN base \o src \o dest \o exts

Init ==
    /\ workflow_step = "Step1"
    /\ in_session_id = 0
    /\ in_dest_node_id = 0
    /\ in_security_flags = [SessionType |-> UnicastSessionType]
    /\ in_payload = <<>>
    /\ in_extensions = <<>>
    /\ key_store = [s \in {0}, d \in {0} |-> NullKey]
    /\ session_type_store = [d \in {0} |-> UnicastSessionType]
    /\ counter_store = 0
    /\ enc_key = NullKey
    /\ sess_type = UnicastSessionType
    /\ msg_counter = 0
    /\ msg_SessionID = 0
    /\ msg_SecurityFlags = [SessionType |-> UnicastSessionType]
    /\ msg_MessageFlags_S = 0
    /\ msg_MessageFlags_DSIZ = 0
    /\ msg_SourceNodeID = Omitted
    /\ msg_DestinationNodeID = Omitted
    /\ msg_MessageCounter = 0
    /\ aead_c = <<>>
    /\ final_secure_message = <<>>

\* SOURCE: core_4.8.2 1
Step1_ObtainKey ==
    /\ workflow_step = "Step1"
    /\ enc_key' = key_store[in_session_id, in_dest_node_id]
    /\ sess_type' = session_type_store[in_dest_node_id]
    /\ IF enc_key' = NullKey
       THEN workflow_step' = "Failed"
       ELSE workflow_step' = "Step2"
    /\ UNCHANGED <<in_session_id, in_dest_node_id, in_security_flags, in_payload, in_extensions,
                   key_store, session_type_store, counter_store,
                   msg_counter, msg_SessionID, msg_SecurityFlags, msg_MessageFlags_S, msg_MessageFlags_DSIZ, 
                   msg_SourceNodeID, msg_DestinationNodeID, msg_MessageCounter, aead_c, final_secure_message>>

\* SOURCE: core_4.8.2 2
Step2_ObtainCounter ==
    /\ workflow_step = "Step2"
    /\ msg_counter' = counter_store
    /\ counter_store' = counter_store + 1
    /\ workflow_step' = "Step3"
    /\ UNCHANGED <<in_session_id, in_dest_node_id, in_security_flags, in_payload, in_extensions,
                   key_store, session_type_store, enc_key, sess_type,
                   msg_SessionID, msg_SecurityFlags, msg_MessageFlags_S, msg_MessageFlags_DSIZ, 
                   msg_SourceNodeID, msg_DestinationNodeID, msg_MessageCounter, aead_c, final_secure_message>>

\* SOURCE: core_4.8.2 3
Step3_SetSecurityFields ==
    /\ workflow_step = "Step3"
    /\ msg_SessionID' = in_session_id
    /\ msg_SecurityFlags' = [in_security_flags EXCEPT !.SessionType = sess_type]
    /\ workflow_step' = "Step4"
    /\ UNCHANGED <<in_session_id, in_dest_node_id, in_security_flags, in_payload, in_extensions,
                   key_store, session_type_store, counter_store, enc_key, sess_type, msg_counter,
                   msg_MessageFlags_S, msg_MessageFlags_DSIZ, msg_SourceNodeID, msg_DestinationNodeID, 
                   msg_MessageCounter, aead_c, final_secure_message>>

\* SOURCE: core_4.8.2 4
Step4_SetMessageFields ==
    /\ workflow_step = "Step4"
    /\ \/ /\ sess_type = UnicastSessionType
          /\ msg_MessageFlags_S' = 0
          /\ msg_MessageFlags_DSIZ' = 0
          /\ msg_SourceNodeID' = Omitted
          /\ msg_DestinationNodeID' = Omitted
       \/ /\ sess_type = GroupSessionType
          /\ msg_MessageFlags_S' = 1
          /\ msg_MessageFlags_DSIZ' = 2
          /\ msg_SourceNodeID' = MyOperationalNodeId
          /\ msg_DestinationNodeID' = DeriveGroupId(in_dest_node_id)
       \/ /\ sess_type \notin {UnicastSessionType, GroupSessionType}
          \* TODO: unspecified - other session types
          /\ UNCHANGED <<msg_MessageFlags_S, msg_MessageFlags_DSIZ, msg_SourceNodeID, msg_DestinationNodeID>>
    /\ workflow_step' = "Step5"
    /\ UNCHANGED <<in_session_id, in_dest_node_id, in_security_flags, in_payload, in_extensions,
                   key_store, session_type_store, counter_store, enc_key, sess_type, msg_counter,
                   msg_SessionID, msg_SecurityFlags, msg_MessageCounter, aead_c, final_secure_message>>

\* SOURCE: core_4.8.2 5
Step5_SetMessageCounter ==
    /\ workflow_step = "Step5"
    /\ msg_MessageCounter' = msg_counter
    /\ workflow_step' = "Step6"
    /\ UNCHANGED <<in_session_id, in_dest_node_id, in_security_flags, in_payload, in_extensions,
                   key_store, session_type_store, counter_store, enc_key, sess_type, msg_counter,
                   msg_SessionID, msg_SecurityFlags, msg_MessageFlags_S, msg_MessageFlags_DSIZ,
                   msg_SourceNodeID, msg_DestinationNodeID, aead_c, final_secure_message>>

\* SOURCE: core_4.8.2 6
Step6_AEADGenerateEncrypt ==
    /\ workflow_step = "Step6"
    /\ LET 
         A == ConstructAdditionalData(msg_MessageFlags_S, msg_MessageFlags_DSIZ, msg_SessionID, msg_SecurityFlags, msg_MessageCounter, msg_SourceNodeID, msg_DestinationNodeID, in_extensions)
         N == ConstructNonce(enc_key)
       IN
         aead_c' = Crypto_AEAD_GenerateEncrypt(enc_key, in_payload, A, N)
    /\ workflow_step' = "Step7"
    /\ UNCHANGED <<in_session_id, in_dest_node_id, in_security_flags, in_payload, in_extensions,
                   key_store, session_type_store, counter_store, enc_key, sess_type, msg_counter,
                   msg_SessionID, msg_SecurityFlags, msg_MessageFlags_S, msg_MessageFlags_DSIZ,
                   msg_SourceNodeID, msg_DestinationNodeID, msg_MessageCounter, final_secure_message>>

\* SOURCE: core_4.8.2 7
Step7_CheckAEADError ==
    /\ workflow_step = "Step7"
    /\ IF aead_c = CryptoError
       THEN workflow_step' = "Failed"
       ELSE workflow_step' = "Step8"
    /\ UNCHANGED <<in_session_id, in_dest_node_id, in_security_flags, in_payload, in_extensions,
                   key_store, session_type_store, counter_store, enc_key, sess_type, msg_counter,
                   msg_SessionID, msg_SecurityFlags, msg_MessageFlags_S, msg_MessageFlags_DSIZ,
                   msg_SourceNodeID, msg_DestinationNodeID, msg_MessageCounter, aead_c, final_secure_message>>

\* SOURCE: core_4.8.2 8
Step8_FinalizeMessage ==
    /\ workflow_step = "Step8"
    /\ LET 
         A == ConstructAdditionalData(msg_MessageFlags_S, msg_MessageFlags_DSIZ, msg_SessionID, msg_SecurityFlags, msg_MessageCounter, msg_SourceNodeID, msg_DestinationNodeID, in_extensions)
       IN
         final_secure_message' = A \o aead_c
    /\ workflow_step' = "Done"
    /\ UNCHANGED <<in_session_id, in_dest_node_id, in_security_flags, in_payload, in_extensions,
                   key_store, session_type_store, counter_store, enc_key, sess_type, msg_counter,
                   msg_SessionID, msg_SecurityFlags, msg_MessageFlags_S, msg_MessageFlags_DSIZ,
                   msg_SourceNodeID, msg_DestinationNodeID, msg_MessageCounter, aead_c>>

Next == 
    \/ Step1_ObtainKey
    \/ Step2_ObtainCounter
    \/ Step3_SetSecurityFields
    \/ Step4_SetMessageFields
    \/ Step5_SetMessageCounter
    \/ Step6_AEADGenerateEncrypt
    \/ Step7_CheckAEADError
    \/ Step8_FinalizeMessage
====