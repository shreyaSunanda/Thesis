# Review: `core_4.14.2.3` — Protocol Details

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 81.1
- module: `models/generated/ch45_v3/core_4.14.2.3/vertex-gemini/core_4_14_2_3.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 72, col 5 to line 76, col 86 of module core_4_14_2_3>
/\ state = "IDLE"
/\ msgIn = [resumptionID |-> Ids_1, responderSessionId |-> Ids_1, validDecrypt |-> FALSE, validCert |-> FALSE, validSignature |-> FALSE]
/\ localNOCs = {Ids_1, Ids_2}
/\ outbox = {}
/\ activeSessions = {}
/\ role = "NONE"
/\ sessionCtx = [localSessionId |-> {NotSet_1, NotSet_2}, peerSessionId |-> {NotSet_1, NotSet_2}, resumptionId |-> {NotSet_1, NotSet_2}]
/\ pendingInput = "ReceiveSigma2"
/\ clock = 0
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "IDLE"
/\ msgIn = {NotSet_1, NotSet_2}
/\ localNOCs = {Ids_1, Ids_2}
/\ outbox = {}
/\ activeSessions = {}
/\ role = "NONE"
/\ sessionCtx = [localSessionId |-> {NotSet_1, NotSet_2}, peerSessionId |-> {NotSet_1, NotSet_2}, resumptionId |-> {NotSet_1, NotSet_2}]
/\ pendingInput = NoInput
/\ clock = 0

State 2: <ReceiveInput line 72, col 5 to line 76, col 86 of module core_4_14_2_3>
/\ state = "IDLE"
/\ msgIn = [resumptionID |-> Ids_1, responderSessionId |-> Ids_1, validDecrypt |-> FALSE, validCert |-> FALSE, validSignature |-> FALSE]
/\ localNOCs = {Ids_1, Ids_2}
/\ outbox = {}
/\ activeSessions = {}
/\ role = "NONE"
/\ sessionCtx = [localSessionId |-> {NotSet_1, NotSet_2}, peerSessionId |-> {NotSet_1, NotSet_2}, resumptionId |-> {NotSet_1, NotSet_2}]
/\ pendingInput = "ReceiveSigma2"
/\ clock = 0
```

</details>

## Spec text for this section

4.14.2.3. Protocol Details
Message format
All CASE messages SHALL be structured as specified in Section 4.4, “Message Frame Format”.
All CASE messages are sent using an Unsecured Session:
• The Session ID field SHALL be set to 0.
• The Session Type bits of the Security Flags SHALL be set to 0.
• In the CASE messages from the initiator, S Flag SHALL be set to 1 and DSIZ SHALL be set to 0.
• In the CASE messages from the responder, S Flag SHALL be set to 0 and DSIZ SHALL be set to 1.
For each CASE message, the application payload is the TLV encoding of the message structure as
defined below:
Table 25. CASE Messages
Message Name
Payload TLV Encoding
Sigma1
sigma-1-struct
Sigma2
sigma-2-struct,
Sigma3
sigma-3-struct,
Sigma2_Resume
sigma-2-resume-struct,
SigmaFinished
N/A (encoded via StatusReport)
The other fields of the Message format are not specific to the CASE messages.
Message Exchange
The Sigma1, Sigma2, Sigma3, and SigmaFinished of a distinct session establishment are part of the same
message exchange. The Sigma1 with resumption, Sigma2_Resume and SigmaFinished of a distinct session resumption are part of the same message exchange. The Sigma1 with resumption, Sigma2, Sigma3
and SigmaFinished of a distinct session resumption that failed to perform the resumption are part of
the same message exchange.
Each message SHALL use PROTOCOL_ID_SECURE_CHANNEL as Protocol ID and the corresponding Protocol
Opcode as defined in Table 18, “Secure Channel Protocol Opcodes”.
The Exchange Flags of the Protocol Header are defined as follows per CASE message:
Message
I Flag
CASE Sigma1
CASE Sigma2
CASE Sigma3
CASE Sigma2_Resume
For the SigmaFinished message the value of the I Flag is set depending on whether the status message is sent by the Initiator or the Responder.
All CASE messages SHALL be sent reliably. This may be implicit (e.g. TCP) or explicit (e.g. MRP reliable messaging) in the underlying transport.
The other fields of the Exchange format are not specific to the CASE messages.
Generate and Send Sigma1
The initiator encodes and sends a Sigma1 message, with a payload that follows this TLV schema:
sigma-1-struct => STRUCTURE [ tag-order ]
{
initiatorRandom        [1] : OCTET STRING [ length 32 ],
initiatorSessionId     [2] : UNSIGNED INTEGER [ range 16-bits ],
destinationId          [3] : destination-identifier,
initiatorEphPubKey     [4] : ec-pub-key,
initiatorSessionParams [5, optional] : session-parameter-struct,
resumptionID           [6, optional] : OCTET STRING [ length 16 ],
initiatorResumeMIC     [7, optional] : OCTET STRING [ length
CRYPTO_AEAD_MIC_LENGTH_BYTES ]
}
1. The initiator SHALL generate a random number InitiatorRandom = Crypto_DRBG(len = 32 * 8).
2. The initiator SHALL generate a session identifier (InitiatorSessionId) for subsequent identification of this session. The InitiatorSessionId field SHALL NOT overlap with any other existing
PASE or CASE session identifier in use by the initiator. See Section 4.13.2.4, “Choosing Secure
Unicast Session Identifiers” for more details.
3. The initiator SHALL generate a destination identifier (DestinationId) according to Destination
Identifier to enable the responder to properly select a mutual Fabric and trusted root for the
secure session.
4. The initiator SHALL generate an ephemeral key pair InitiatorEphKeyPair = Crypto_GenerateKeypair().
5. The initiator MAY encode any relevant MRP parameters.
6. Any context-specific tags not listed in the above TLV schemas SHALL be reserved for future use,
and SHALL be silently ignored if seen by a responder which cannot understand them.
7. If the initiator is resuming a session from a previous execution of the CASE with the same peer,
the initiator SHALL:
a. Note the ResumptionID of the previous session.
b. Generate the S1RK key.
c. Generate the initiatorResumeMIC using the SharedSecret from the previous session:
byte Resume1MIC_P[] = {}
byte Resume1MIC_A[] = {}
byte Resume1MIC_Nonce[13] = /* "NCASE_SigmaS1" */
{0x4e, 0x43, 0x41, 0x53, 0x45, 0x5f, 0x53, 0x69,
0x67, 0x6d, 0x61, 0x53, 0x31}
InitiatorResume1MIC = Crypto_AEAD_GenerateEncrypt(
K = S1RK,
P = Resume1MIC_P,
A = Resume1MIC_A,
N = Resume1MIC_Nonce
)
8. The initiator SHALL send a message with Secure Channel Protocol ID and Sigma1 Protocol Opcode
from Table 18, “Secure Channel Protocol Opcodes” whose payload is the TLV-encoded Sigma1
Msg1 with an anonymous tag for the outermost struct.
Msg1 =
{
initiatorRandom        (1) = InitiatorRandom,
initiatorSessionId     (2) = InitiatorSessionId,
destinationId          (3) = DestinationId,
initiatorEphPubKey     (4) = InitiatorEphKeyPair.publicKey
initiatorSessionParams (5) = session-parameter-struct (optional),
resumptionID           (6) = ResumptionID (optional, only present if performing
resumption),
initiatorResumeMIC     (7) = InitiatorResume1MIC (optional, only present if
performing resumption)
}
Validate Sigma1
On receipt of Msg1, the responder SHALL perform the following:
1. If Msg1 contains either a resumptionID or an initiatorResumeMIC field but not both, the responder
SHALL send a status report: StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL,
ProtocolCode: INVALID_PARAMETER) and perform no further processing.
2. Set the Peer Session Identifier in the Session Context to the value Msg1.initiatorSessionId.
3. If Msg1 contains both the resumptionID and initiatorResumeMIC fields, the responder SHALL
search for an existing session that has a Resumption ID equal to the incoming resumptionID. If a
single such session exists, the responder SHALL follow the steps in Section 4.14.2.3.10, “Validate
Sigma1 with Resumption” rather than continue the steps outlined in Section 4.14.2.3.5, “Validate
Sigma1 Destination ID”.
4. If Msg1 does not contain a resumptionID and initiatorResumeMIC field, the responder SHALL continue the steps in Section 4.14.2.3.5, “Validate Sigma1 Destination ID”.
Validate Sigma1 Destination ID
1. The responder SHALL validate the incoming destinationId:
a. The responder SHALL traverse all its installed Node Operational Certificates (NOC), gathering the associated trusted roots' public keys from the associated chains and SHALL generate
a candidateDestinationId based on the procedure in Section 4.14.2.4.1, “Destination Identifier” for that tuple of <Root Public Key, Fabric ID, Node ID>.
b. The responder SHALL verify that the incoming destinationId matches one of the candidateDestinationId generated above. Upon such a match, the associated trusted root, Fabric ID,
Node ID and IPK SHALL be recorded for subsequent use.
c. Note that at the initiator, only the current Epoch Key for the IPK will have been used. At the
receiver, several IPK Epoch Keys may be installed, requiring several candidateDestinationId
to be computed, one per available IPK Operational Key, per NOC.
2. If there is no candidateDestinationId matching the incoming destinationId, the responder
SHALL send a status report: StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL,
ProtocolCode: NO_SHARED_TRUST_ROOTS) and perform no further processing.
3. Otherwise, if a match was found for the destinationId, the matched NOC, ICAC (if present), and
associated trusted root SHALL be used for selection of the responderNOC and responderICAC in the
steps for Sigma2.
Generate and Send Sigma2
If validation is successful, the responder encodes and sends a Sigma2 message.
sigma-2-tbsdata => STRUCTURE [ tag-order ]
{
responderNOC       [1] : OCTET STRING,
responderICAC      [2, optional] : OCTET STRING,
responderEphPubKey [3] : ec-pub-key,
initiatorEphPubKey [4] : ec-pub-key,
}
sigma-2-tbedata => STRUCTURE [ tag-order ]
{
responderNOC  [1] : OCTET STRING,
responderICAC [2, optional] : OCTET STRING,
signature     [3] : ec-signature,
resumptionID  [4] : OCTET STRING [ length 16 ],
}
sigma-2-struct => STRUCTURE [ tag-order ]
{
responderRandom        [1] : OCTET STRING [ length 32 ],
responderSessionId     [2] : UNSIGNED INTEGER [ range 16-bits ],
responderEphPubKey     [3] : ec-pub-key,
encrypted2             [4] : OCTET STRING,
responderSessionParams [5, optional] : session-parameter-struct
}
NOTE
sigma-2-tbsdata is NOT transmitted but is instead signed; the signature will be
encrypted and transmitted.
1. The responder SHALL generate a random resumption ID ResumptionID = Crypto_DRBG(len = 16 *
8).
a. The responder SHALL set the Resumption ID in the Session Context to the value ResumptionID.
2. The responder SHALL use the Node Operational Key Pair ResponderNOKeyPair, responderNOC, and
responderICAC (if present) corresponding to the NOC obtained in Section 4.14.2.3.4, “Validate Sigma1”.
3. The responder SHALL generate an ephemeral key pair ResponderEphKeyPair = Crypto_GenerateKeypair().
4. The responder SHALL generate a shared secret:
SharedSecret = Crypto_ECDH(
privateKey = ResponderEphKeyPair.privateKey,
publicKey = Msg1.initiatorEphPubKey,
)
5. The responder SHALL encode the following items as a sigma-2-tbsdata with an anonymous tag:
a. responderNOC as a matter-certificate
b. responderICAC (if present) as a matter-certificate
c. ResponderEphKeyPair.publicKey
d. Msg1.initiatorEphPubKey
6. The responder SHALL generate a signature:
TBSData2Signature = Crypto_Sign(
message = sigma-2-tbsdata,
privateKey = ResponderNOKeyPair.privateKey
)
7. The responder SHALL encode the following items as a sigma-2-tbedata, where the encoding of
responderNOC and responderICAC items SHALL be byte-for-byte identical to the encoding in sigma-
2-tbsdata:
a. responderNOC as a matter-certificate. This encoding SHALL be byte-for-byte identical to the
encoding in sigma-2-tbsdata.
b. responderICAC (if present) as a matter-certificate. This encoding SHALL be byte-for-byte identical to the encoding in sigma-2-tbsdata.
c. TBSData2Signature
d. ResumptionID
8. The responder SHALL generate a random number Random = Crypto_DRBG(len = 32 * 8).
9. The responder SHALL generate the S2K key using Random as Responder Random and ResponderEphKeyPair.publicKey as Responder Ephemeral Public Key.
10. The responder SHALL generate the encrypted and integrity protected data:
byte TBEData2_A[] = {}
byte TBEData2_Nonce[13] = /* "NCASE_Sigma2N" */
{0x4e, 0x43, 0x41, 0x53, 0x45, 0x5f, 0x53, 0x69,
0x67, 0x6d, 0x61, 0x32, 0x4e}
TBEData2Encrypted = Crypto_AEAD_GenerateEncrypt(
K = S2K,
P = TBEData2,
A = TBEData2_A,
N = TBEData2_Nonce
)
11. The responder SHALL generate a session identifier (ResponderSessionId) for subsequent identification of this secured session. The ResponderSessionId field SHALL NOT overlap with any other
existing PASE or CASE session identifier in use by the responder. See Section 4.13.2.4, “Choosing
Secure Unicast Session Identifiers” for more details. The responder SHALL set the Local Session
Identifier in the Session Context to the value ResponderSessionId.
12. The responder SHALL use the Fabric IPK configured as described in Section 4.14.2.6.1, “Identity
Protection Key (IPK)”.
13. Any context-specific tags not listed in the above TLV schemas SHALL be reserved for future use,
and SHALL be silently ignored if seen by an initiator which cannot understand them.
14. The responder SHALL send a message with Secure Channel Protocol ID and Sigma2 Protocol
Opcode from Table 18, “Secure Channel Protocol Opcodes” whose payload is the TLV-encoded
Sigma2 Msg2 with an anonymous tag for the outermost struct.
Msg2 =
{
responderRandom        (1) = Random,
responderSessionId     (2) = ResponderSessionId,
responderEphPubKey     (3) = ResponderEphKeyPair.publicKey,
encrypted2             (4) = TBEData2Encrypted,
responderSessionParams (5) = session-parameter-struct (optional)
}
Validate Sigma2
On receipt of Msg2, the initiator SHALL perform the following:
1. The initiator SHALL generate a shared secret:
SharedSecret = Crypto_ECDH(
privateKey = InitiatorEphKeyPair.privateKey,
publicKey = Msg2.responderEphPubKey,
)
2. The initiator SHALL generate the S2K key using Msg2.responderRandom as Responder Random and
Msg2.responderEphPubKey as Responder Ephemeral Public Key.
3. The initiator SHALL generate the decrypted data:
byte TBEData2_A[] = {}
byte TBEData2_Nonce[13] = /* "NCASE_Sigma2N" */
{0x4e, 0x43, 0x41, 0x53, 0x45, 0x5f, 0x53, 0x69,
0x67, 0x6d, 0x61, 0x32, 0x4e}
Success, TBEData2 = Crypto_AEAD_DecryptVerify(
K = S2K,
C = Msg2.encrypted2,
A = TBEData2_A,
N = TBEData2_Nonce
)
4. If the value of Success is FALSE, the initiator SHALL send a status report: StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAMETER) and perform no
further processing.
5. The initiator SHALL verify that the NOC in TBEData2.responderNOC and ICAC in TBEData2.responderICAC (if present) fulfills the following constraints:
a. The Fabric ID and Node ID SHALL match the intended identity of the receiver Node, as
included in the computation of the Destination Identifier when generating Sigma1.
b. If an ICAC is present, and it contains a Fabric ID in its subject, then it SHALL match the FabricID in the NOC leaf certificate.
c. The certificate chain SHALL chain back to the Trusted Root CA Certificate TrustedRCAC whose
public key was used in the computation of the Destination Identifier when generating Sigma1.
d. All the elements in the certificate chain SHALL respect the Matter Certificate DN Encoding
Rules, including range checks for identifiers such as Fabric ID and Node ID.
6. If any of the validations from the previous step fail, the initiator SHALL send a status report:
StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAMETER) and perform no further processing.
7. The initiator SHALL verify TBEData2.responderNOC using:
a. Success = Crypto_VerifyChain(certificates = [TBEData2.responderNOC, TBEData2.responderICAC, TrustedRCAC]), when TBEData2.responderICAC is present, or
b. Success = Crypto_VerifyChain(certificates = [TBEData2.responderNOC, TrustedRCAC]), when
TBEData2.responderICAC is not present.
8. If the value of Success is FALSE, the initiator SHALL send a status report: StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAMETER) and perform no
further processing.
9. The initiator SHALL encode the following items as a sigma-2-tbsdata with an anonymous tag:
a. responderNOC as copied from TBEData2
b. responderICAC (if present) as copied from TBEData2
c. Msg2.responderEphPubKey
d. InitiatorEphKeyPair.publicKey
10. The initiator SHALL verify TBEData2.signature (see RFC 5280):
Success = Crypto_Verify(
publicKey = Public key obtained from responderNOC,
message = sigma-2-tbsdata,
signature = TBEData2.signature
)
11. If the value of Success is FALSE, the initiator SHALL send a status report: StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAMETER) and perform no
further processing.
12. Set the Resumption ID in the Session Context to the value TBEData2.resumptionID.
13. Set the Peer Session Identifier in the Session Context to the value Msg2.responderSessionId.
Generate and Send Sigma3
If validation is successful, the initiator encodes and sends a Sigma3 message.
sigma-3-tbsdata => STRUCTURE [ tag-order ]
{
initiatorNOC       [1] : OCTET STRING,
initiatorICAC      [2, optional] : OCTET STRING,
initiatorEphPubKey [3] : ec-pub-key,
responderEphPubKey [4] : ec-pub-key,
}
sigma-3-tbedata => STRUCTURE [ tag-order ]
{
initiatorNOC  [1] : OCTET STRING,
initiatorICAC [2, optional] : OCTET STRING,
signature     [3] : ec-signature,
}
sigma-3-struct => STRUCTURE [ tag-order ]
{
encrypted3 [1] : OCTET STRING,
}
NOTE
sigma-3-tbsdata is NOT transmitted but is instead signed; the signature will be
encrypted and transmitted.
1. The initiator SHALL select its Node Operational Key Pair InitiatorNOKeyPair, Node Operational
Certificates initiatorNOC and initiatorICAC (if present), and Trusted Root CA Certificate TrustedRCAC corresponding to the chosen Fabric as determined by the Destination Identifier from Sig­
ma1.
2. The initiator SHALL encode the following items as a sigma-3-tbsdata with an anonymous tag:
a. initiatorNOC as a matter-certificate
b. initiatorICAC (if present) as a matter-certificate
c. InitiatorEphKeyPair.publicKey
d. Msg2.responderEphPubKey
3. The initiator SHALL generate a signature:
TBSData3Signature = Crypto_Sign(
message = sigma-3-tbsdata,
privateKey = InitiatorNOKeyPair.privateKey
)
4. The initiator SHALL encode the following items as a sigma-3-tbedata:
a. initiatorNOC as a matter-certificate. This encoding SHALL be byte-for-byte identical to the
encoding in sigma-3-tbsdata.
b. initiatorICAC (if present) as a matter-certificate. This encoding SHALL be byte-for-byte identical to the encoding in sigma-3-tbsdata.
c. TBSData3Signature
5. The initiator SHALL generate the S3K key.
6. The initiator SHALL generate the encrypted and integrity protected data:
byte TBEData3_A[] = {}
byte TBEData3_Nonce[13] = /* "NCASE_Sigma3N" */
{0x4e, 0x43, 0x41, 0x53, 0x45, 0x5f, 0x53, 0x69,
0x67, 0x6d, 0x61, 0x33, 0x4e}
TBEData3Encrypted = Crypto_AEAD_GenerateEncrypt(
K = S3K,
P = TBEData3,
A = TBEData3_A,
N = TBEData3_Nonce
)
7. Any context-specific tags not listed in the above TLV schemas SHALL be reserved for future use,
and SHALL be silently ignored if seen by a responder which cannot understand them.
8. The initiator SHALL send a message with Secure Channel Protocol ID and Sigma3 Protocol Opcode
from Table 18, “Secure Channel Protocol Opcodes” whose payload is the TLV-encoded Sigma3
Msg3 = { encrypted3 (1) = TBEData3Encrypted } with an anonymous tag for the outermost
struct.
9. The initiator SHALL generate the session encryption keys using the method described in Section
4.14.2.6.6, “Session Encryption Keys”.
Validate Sigma3
On receipt of Msg3, the responder SHALL perform the following:
1. The responder SHALL generate the S3K key.
2. The responder SHALL generate the decrypted data:
byte TBEData3_A[] = {}
byte TBEData3_Nonce[13] = /* "NCASE_Sigma3N" */
{0x4e, 0x43, 0x41, 0x53, 0x45, 0x5f, 0x53, 0x69,
0x67, 0x6d, 0x61, 0x33, 0x4e}
Success, TBEData3 = Crypto_AEAD_DecryptVerify(
K = S3K,
C = Msg3.encrypted3,
A = TBEData3_A,
N = TBEData3_Nonce
)
3. If the value of Success is FALSE, the responder SHALL send a status report: StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAMETER) and perform
no further processing.
4. The responder SHALL verify that the NOC in TBEData3.initiatorNOC and the ICAC in TBEData3.initiatorICAC fulfill the following constraints:
a. The Fabric ID SHALL match the Fabric ID matched during processing of the Destination
Identifier after receiving Sigma1.
b. If an ICAC is present, and it contains a Fabric ID in its subject, then it SHALL match the FabricID in the NOC leaf certificate.
c. The certificate chain SHALL chain back to the Trusted Root CA Certificate TrustedRCAC whose
public key was matched during processing of the Destination Identifier after receiving Sigma1.
d. All the elements in the certificate chain SHALL respect the Matter Certificate DN Encoding
Rules, including range checks for identifiers such as Fabric ID and Node ID.
5. If any of the validations from the previous step fail, the responder SHALL send a status report:
StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAMETER) and perform no further processing.
6. The responder SHALL verify TBEData3.initiatorNOC using:
a. Success = Crypto_VerifyChain(certificates = [TBEData3.initiatorNOC, TBEData3.initiatorICAC, TrustedRCAC]), when TBEData3.initiatorICAC is present, or
b. Success = Crypto_VerifyChain(certificates = [TBEData3.initiatorNOC, TrustedRCAC]), when
TBEData3.initiatorICAC is not present.
7. If the value of Success is FALSE, the responder SHALL send a status report: StatusReport(GeneralMatter Specification R1.6
Code: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAMETER_) and perform
no further processing.
8. The responder SHALL encode the following items as a sigma-3-tbsdata with an anonymous tag:
a. initiatorNOC as copied from TBEData3
b. initiatorICAC (if present) as copied from TBEData3
c. Msg1.initiatorEphPubKey
d. ResponderEphKeyPair.publicKey
9. The responder SHALL verify TBEData3.signature (see RFC 5280):
Success = Crypto_Verify(
publicKey= public key obtained from initiatorNOC,
message = sigma-3-tbsdata,
signature = TBEData3.signature
)
10. If the value of Success is FALSE, the responder SHALL send a status report: StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAMETER) and perform no
further processing.
11. The responder SHALL generate the session keys as described in Section 4.14.2.6.6, “Session
Encryption Keys”.
12. The responder SHALL initialize its Local Message Counter in the Session Context per Section
4.6.1.1, “Message Counter Initialization”.
13. The responder SHALL initialize the Message Reception State in the Session Context` and set the
synchronized max_message_counter of the peer to 0.
14. The responder SHALL set SessionTimestamp to a timestamp from a clock which would allow for
the eventual determination of the last session use relative to other sessions.
15. The responder SHALL encode and send SigmaFinished.
Validate Sigma1 with Resumption
The responder SHALL continue validating the Sigma1 message Msg1 as follows:
1. Obtain the SharedSecret from the Section 4.13.3.1, “Secure Session Context” of the resumed session.
2. Generate the S1RK key.
3. Verify the Resume1MIC by decrypting the following values:
byte Resume1MIC_A[] = {}
byte Resume1MIC_Nonce[13] = /* "NCASE_SigmaR1" */
{0x4e, 0x43, 0x41, 0x53, 0x45, 0x5f, 0x53, 0x69,
0x67, 0x6d, 0x61, 0x53, 0x31}
Success, Resume1MICPayload = Crypto_AEAD_DecryptVerify(
K = S1RK,
C = Msg1.sigma1ResumeMIC,
A = Resume1MIC_A,
N = Resume1MIC_Nonce
)
4. If the value of Success is FALSE, the responder SHALL continue processing Sigma1 as if it didn’t
include any resumption information by continuing the steps in Section 4.14.2.3.5, “Validate Sigma1 Destination ID”.
5. If the value of Success is TRUE, the responder SHALL:
a. Set the Peer Session Identifier in the in the Session Context to the value Msg1.initiatorSessionId.
b. Send a Sigma2_Resume message.
Generate and Send Sigma2_Resume
The responder SHALL encode and send a Sigma2_Resume message in response to a valid Sigma1 with
response.
sigma-2-resume-struct => STRUCTURE [ tag-order ]
{
resumptionID           [1] : OCTET STRING [ length 16 ],
sigma2ResumeMIC        [2] : OCTET STRING [ length 16 ],
responderSessionID     [3] : UNSIGNED INTEGER [ range 16-bits ],
responderSessionParams [4, optional] : session-parameter-struct
}
1. The responder SHALL generate a new resumption ID ResumptionID = Crypto_DRBG(len = 128).
2. The responder SHALL generate a session identifier (ResponderSessionId) for subsequent identification of this session. The ResponderSessionId field SHALL NOT overlap with any other existing
PASE or CASE session identifier in use by the responder. See Section 4.13.2.4, “Choosing Secure
Unicast Session Identifiers” for more details. The responder SHALL set the Local Session Identifier in the Session Context to the value ResponderSessionId.
3. The responder SHALL generate the S2RK key.
4. The responder SHALL generate a resumption MIC:
byte Resume2MIC_P[] = {}
byte Resume2MIC_A[] = {}
byte Resume2MIC_Nonce[13] = /* "NCASE_SigmaS2" */
{0x4e, 0x43, 0x41, 0x53, 0x45, 0x5f, 0x53, 0x69,
0x67, 0x6d, 0x61, 0x53, 0x32}
Resume2MIC = Crypto_AEAD_GenerateEncrypt(
K = S2RK,
P = Resume2MIC_P,
A = Resume2MIC_A,
N = Resume2MIC_Nonce
)
5. Any context-specific tags not listed in the above TLV schemas SHALL be reserved for future use,
and SHALL be silently ignored if seen by an initiator which cannot understand them.
6. The responder SHALL send a message with the Secure Channel Protocol ID and Sigma2Resume Protocol Opcode from Table 18, “Secure Channel Protocol Opcodes” whose payload is the TLV-
encoded Sigma2_Resume ResumeMsg2 with an anonymous tag for the outermost struct.
ResumeMsg2 =
{
resumptionID           (1) = ResumptionID,
sigma2ResumeMIC        (2) = ResumeMIC2,
responderSessionID     (3) = ResponderSessionId,
responderSessionParams (4) = session-parameter-struct (optional)
}
7. The responder SHALL generate the session keys as described in Section 4.14.2.6.7, “Resumption
Session Encryption Keys”.
Validate Sigma2_Resume
On receipt of ResumeMsg2, the initiator SHALL perform the following:
1. The initiator SHALL generate the S2RK key.
2. The initiator SHALL verify the Resume2MIC by decrypting the following values:
byte Resume2MIC_A[] = {}
byte Resume2MIC_Nonce[13] = /* "NCASE_SigmaR2" */
{0x4e, 0x43, 0x41, 0x53, 0x45, 0x5f, 0x53, 0x69,
0x67, 0x6d, 0x61, 0x53, 0x32}
Success, Resume2MICPayload = Crypto_AEAD_DecryptVerify(
K = S2RK,
C = ResumeMsg2.sigma2ResumeMIC,
A = Resume2MIC_A,
N = Resume2MIC_Nonce
)
3. If Success is FALSE, the initiator SHALL send a status report: StatusReport(GeneralCode: FAILURE,
ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAMETER_) and perform no further processing.
4. The initiator SHALL set the Resumption ID in the Session Context to the value Resume2Msg.resumptionID.
5. The initiator SHALL generate the session keys as described in Section 4.14.2.6.7, “Resumption
Session Encryption Keys”.
6. The initiator SHALL reset its Local Message Counter in the Session Context per Section 4.6.1.1,
“Message Counter Initialization”.
7. The initiator SHALL reset the Message Reception State of the Session Context` and set the synchronized max_message_counter of the peer to 0.
8. The initiator SHALL set SessionTimestamp to a timestamp from a clock which would allow for the
eventual determination of the last session use relative to other sessions.
9. The initiator SHALL set the Peer Session Identifier in the in the Session Context to the value
ResumeMsg2.responderSessionId.
10. The initiator SHALL send Section 4.14.2.3.13, “SigmaFinished”.
SigmaFinished
To indicate the successful completion of the protocol, the Node receiving Sigma3 (if a new session is
being established) or Sigma2_Resume (if a session is being resumed) SHALL send a status report:
StatusReport(GeneralCode: SUCCESS, ProtocolId: SECURE_CHANNEL, ProtocolCode: SESSION_ESTABLISHMENT_SUCCESS).
On successful receipt of SigmaFinished:
1. The receiving node SHALL initialize the Local Message Counter according to Section 4.6.1.1,
“Message Counter Initialization” for the newly established secure session whose success is
acknowledged by this message.
2. The receiving node SHALL set SessionTimestamp to a timestamp from a clock which would allow
for the eventual determination of the last session usage relative to other sessions.
If this message is received out-of-order or unexpectedly, then it SHALL be ignored.
