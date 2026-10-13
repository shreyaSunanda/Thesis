# Review: `core_4.8.2` — Security Processing of Outgoing Messages

Automated triage: **candidate** — not a teardown-shaped deadlock

## DRAFT VERDICT (Claude's first pass - please check)

**legitimate terminal state**

Spec step 1a: "If no key is found for the given Session ID, security processing SHALL fail and no further security processing SHALL be done on this message." Stuck state: workflow_step="Failed", enc_key=NullKey. The spec explicitly says to stop.

---

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] legitimate terminal state (nothing is supposed to happen next)

Notes:



## Evidence

- steps to deadlock: 2
- ranker score: 21.61
- module: `models/generated/ch45/core_4.8.2/vertex-gemini/core_4_8_2.tla`

### Under no capability flags

Last action to fire: **`Step1_ObtainKey`**

Clause that action cites:

```
\* SOURCE: core_4.8.2 1
```

Stuck in this state:

```
State 2: <Step1_ObtainKey line 81, col 5 to line 90, col 110 of module core_4_8_2>
/\ msg_SecurityFlags = [SessionType |-> UnicastSessionType]
/\ in_payload = <<>>
/\ workflow_step = "Failed"
/\ msg_DestinationNodeID = Omitted
/\ counter_store = 0
/\ final_secure_message = <<>>
/\ in_dest_node_id = 0
/\ enc_key = NullKey
/\ aead_c = <<>>
/\ session_type_store = (0 :> UnicastSessionType)
/\ msg_SessionID = 0
/\ msg_MessageCounter = 0
/\ in_extensions = <<>>
/\ in_session_id = 0
/\ msg_MessageFlags_DSIZ = 0
/\ key_store = (<<0, 0>> :> NullKey)
/\ msg_SourceNodeID = Omitted
/\ msg_counter = 0
/\ in_security_flags = [SessionType |-> UnicastSessionType]
/\ msg_MessageFlags_S = 0
/\ sess_type = UnicastSessionType
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ msg_SecurityFlags = [SessionType |-> UnicastSessionType]
/\ in_payload = <<>>
/\ workflow_step = "Step1"
/\ msg_DestinationNodeID = Omitted
/\ counter_store = 0
/\ final_secure_message = <<>>
/\ in_dest_node_id = 0
/\ enc_key = NullKey
/\ aead_c = <<>>
/\ session_type_store = (0 :> UnicastSessionType)
/\ msg_SessionID = 0
/\ msg_MessageCounter = 0
/\ in_extensions = <<>>
/\ in_session_id = 0
/\ msg_MessageFlags_DSIZ = 0
/\ key_store = (<<0, 0>> :> NullKey)
/\ msg_SourceNodeID = Omitted
/\ msg_counter = 0
/\ in_security_flags = [SessionType |-> UnicastSessionType]
/\ msg_MessageFlags_S = 0
/\ sess_type = UnicastSessionType

State 2: <Step1_ObtainKey line 81, col 5 to line 90, col 110 of module core_4_8_2>
/\ msg_SecurityFlags = [SessionType |-> UnicastSessionType]
/\ in_payload = <<>>
/\ workflow_step = "Failed"
/\ msg_DestinationNodeID = Omitted
/\ counter_store = 0
/\ final_secure_message = <<>>
/\ in_dest_node_id = 0
/\ enc_key = NullKey
/\ aead_c = <<>>
/\ session_type_store = (0 :> UnicastSessionType)
/\ msg_SessionID = 0
/\ msg_MessageCounter = 0
/\ in_extensions = <<>>
/\ in_session_id = 0
/\ msg_MessageFlags_DSIZ = 0
/\ key_store = (<<0, 0>> :> NullKey)
/\ msg_SourceNodeID = Omitted
/\ msg_counter = 0
/\ in_security_flags = [SessionType |-> UnicastSessionType]
/\ msg_MessageFlags_S = 0
/\ sess_type = UnicastSessionType
```

</details>

## Spec text for this section

4.8.2. Security Processing of Outgoing Messages
The process for encrypting Matter messages is depicted graphically in Figure 8, “Matter Message
Encryption” with color code conventions described in Figure 9, “Matter Message Encryption Legend”.
Figure 8. Matter Message Encryption
Figure 9. Matter Message Encryption Legend
To prepare a secure message for transmission with a given Session ID, Destination Node ID (which
may be a group node id or an operational node id) and Security Flags, the Node SHALL perform the
following steps:
1. Obtain the Encryption Key associated with the Session ID and Destination Node ID and the Session Type associated with the Destination Node ID:
a. If no key is found for the given Session ID, security processing SHALL fail and no further
security processing SHALL be done on this message.
2. Obtain the outgoing message counter of the sending Node as per Section 4.6.6, “Counter ProcessMatter Specification R1.6
ing of Outgoing Messages”.
3. Set the Security fields as follows:
a. The Session ID field SHALL be set to the value provided to step 1.
b. The Security Flags field SHALL be set to the value provided to step 1 with the following subfields updated:
i. The Session Type field SHALL be set to the value obtained from step 1.
4. Set the Message Flags, Destination Node ID, and Source Node ID fields as follows:
a. If the Session Type is a unicast session:
i. Set S Flag to 0.
ii. Set DSIZ to 0.
iii. Omit both Destination Node ID, and Source Node ID.
b. Else if the Session Type is a group session:
i. Set S Flag to 1.
ii. Set DSIZ to 2.
iii. Set Source Node ID field to the operational node id of the sending node.
iv. Set Destination Node ID field to the 16-bit Group ID derived from the Destination Node
ID.
5. Set the Message Counter field to the outgoing message counter from step 2.
6. Execute the AEAD generate and encrypt operation, as specified in Section 3.6.1, “Generate and
encrypt”, with the following instantiations:
a. The bit string key K SHALL be the Encryption Key obtained from step 1;
b. The nonce N SHALL be the CRYPTO_AEAD_NONCE_LENGTH_BYTES-octet string constructed according to Table 17, “Nonce”;
c. The parameter P SHALL be the Message Payload;
d. The additional data octet string A SHALL be the Message Header contents, using little-endian
byte order for all scalars, exactly as they appear in the message segments from which they
originate:
Message Flags || Session ID || Security Flags || Message Counter
with the optional fields appended according to the Message Flags:
[Source Node ID] || [Destination Node ID] || [Message Extensions]
e. C = Crypto_AEAD_GenerateEncrypt(K, P, A, N)
7. If the AEAD operation invoked in step 6 results in an error, then security processing SHALL fail
and no further security processing SHALL be done on this message.
8. Let C be the output from step 6. C contains the tag of CRYPTO_AEAD_MIC_LENGTH_BITS bits (Message
Integrity Check (MIC)) as specified by Section 3.6.1, “Generate and encrypt”. The secured outgoing message SHALL be:
A || C
