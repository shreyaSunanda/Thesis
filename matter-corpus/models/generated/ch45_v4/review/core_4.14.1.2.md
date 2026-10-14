# Review: `core_4.14.1.2` — Protocol Details

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 14
- ranker score: 34.62
- module: `models/generated/ch45_v4/core_4.14.1.2/vertex-gemini/core_4_14_1_2.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 117, col 5 to line 120, col 50 of module core_4_14_1_2>
/\ network = {}
/\ initiator = [ state |-> "UNINITIALIZED",
  passcodeId |-> 0,
  hasPBKDFParameters |-> FALSE,
  localSessionId |-> NoSessionId,
  peerSessionId |-> NoSessionId,
  keysInstalled |-> FALSE,
  localMessageCounter |-> 0,
  peerMaxMessageCounter |-> 0 ]
/\ responder = [ state |-> "UNINITIALIZED",
  passcodeId |-> 0,
  hasPBKDFParameters |-> FALSE,
  localSessionId |-> NoSessionId,
  peerSessionId |-> NoSessionId,
  keysInstalled |-> FALSE,
  localMessageCounter |-> 0,
  peerMaxMessageCounter |-> 0 ]
/\ pendingInput = "PBKDFParamRequest"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ network = {}
/\ initiator = [ state |-> "UNINITIALIZED",
  passcodeId |-> 0,
  hasPBKDFParameters |-> FALSE,
  localSessionId |-> NoSessionId,
  peerSessionId |-> NoSessionId,
  keysInstalled |-> FALSE,
  localMessageCounter |-> 0,
  peerMaxMessageCounter |-> 0 ]
/\ responder = [ state |-> "UNINITIALIZED",
  passcodeId |-> 0,
  hasPBKDFParameters |-> FALSE,
  localSessionId |-> NoSessionId,
  peerSessionId |-> NoSessionId,
  keysInstalled |-> FALSE,
  localMessageCounter |-> 0,
  peerMaxMessageCounter |-> 0 ]
/\ pendingInput = NoInput

State 2: <ReceiveInput line 117, col 5 to line 120, col 50 of module core_4_14_1_2>
/\ network = {}
/\ initiator = [ state |-> "UNINITIALIZED",
  passcodeId |-> 0,
  hasPBKDFParameters |-> FALSE,
  localSessionId |-> NoSessionId,
  peerSessionId |-> NoSessionId,
  keysInstalled |-> FALSE,
  localMessageCounter |-> 0,
  peerMaxMessageCounter |-> 0 ]
/\ responder = [ state |-> "UNINITIALIZED",
  passcodeId |-> 0,
  hasPBKDFParameters |-> FALSE,
  localSessionId |-> NoSessionId,
  peerSessionId |-> NoSessionId,
  keysInstalled |-> FALSE,
  localMessageCounter |-> 0,
  peerMaxMessageCounter |-> 0 ]
/\ pendingInput = "PBKDFParamRequest"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 14: <ReceiveInput line 117, col 5 to line 120, col 50 of module core_4_14_1_2>
/\ network = {[type |-> "Pake1"], [type |-> "PakeFinished"], [type |-> "Pake2", valid |-> TRUE], [type |-> "Pake3", valid |-> TRUE], [type |-> "PBKDFParamResponse", hasPBKDFParameters |-> FALSE, responderSessionId |-> SessionIds_1], [type |-> "PBKDFParamRequest", initiatorSessionId |-> SessionIds_1, passcodeId |-> 0, hasPBKDFParameters |-> FALSE]}
/\ initiator = [state |-> "WAIT_FINISHED", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ responder = [state |-> "ESTABLISHED", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> TRUE, localMessageCounter |-> 1, peerMaxMessageCounter |-> 0]
/\ pendingInput = "InitiatePASE"
```

<details><summary>Full trace</summary>

```
State 9: <Responder_HandlePake1 line 160, col 5 to line 168, col 30 of module core_4_14_1_2>
/\ network = {[type |-> "Pake1"], [type |-> "Pake2", valid |-> TRUE], [type |-> "PBKDFParamResponse", hasPBKDFParameters |-> FALSE, responderSessionId |-> SessionIds_1], [type |-> "PBKDFParamRequest", initiatorSessionId |-> SessionIds_1, passcodeId |-> 0, hasPBKDFParameters |-> FALSE]}
/\ initiator = [state |-> "WAIT_PAKE2", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ responder = [state |-> "WAIT_PAKE3", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ pendingInput = NoInput

State 10: <ReceiveInput line 117, col 5 to line 120, col 50 of module core_4_14_1_2>
/\ network = {[type |-> "Pake1"], [type |-> "Pake2", valid |-> TRUE], [type |-> "PBKDFParamResponse", hasPBKDFParameters |-> FALSE, responderSessionId |-> SessionIds_1], [type |-> "PBKDFParamRequest", initiatorSessionId |-> SessionIds_1, passcodeId |-> 0, hasPBKDFParameters |-> FALSE]}
/\ initiator = [state |-> "WAIT_PAKE2", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ responder = [state |-> "WAIT_PAKE3", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ pendingInput = "Pake2"

State 11: <Initiator_HandlePake2 line 172, col 5 to line 184, col 30 of module core_4_14_1_2>
/\ network = {[type |-> "Pake1"], [type |-> "Pake2", valid |-> TRUE], [type |-> "Pake3", valid |-> TRUE], [type |-> "PBKDFParamResponse", hasPBKDFParameters |-> FALSE, responderSessionId |-> SessionIds_1], [type |-> "PBKDFParamRequest", initiatorSessionId |-> SessionIds_1, passcodeId |-> 0, hasPBKDFParameters |-> FALSE]}
/\ initiator = [state |-> "WAIT_FINISHED", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ responder = [state |-> "WAIT_PAKE3", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ pendingInput = NoInput

State 12: <ReceiveInput line 117, col 5 to line 120, col 50 of module core_4_14_1_2>
/\ network = {[type |-> "Pake1"], [type |-> "Pake2", valid |-> TRUE], [type |-> "Pake3", valid |-> TRUE], [type |-> "PBKDFParamResponse", hasPBKDFParameters |-> FALSE, responderSessionId |-> SessionIds_1], [type |-> "PBKDFParamRequest", initiatorSessionId |-> SessionIds_1, passcodeId |-> 0, hasPBKDFParameters |-> FALSE]}
/\ initiator = [state |-> "WAIT_FINISHED", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ responder = [state |-> "WAIT_PAKE3", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ pendingInput = "Pake3"

State 13: <Responder_HandlePake3 line 188, col 5 to line 200, col 30 of module core_4_14_1_2>
/\ network = {[type |-> "Pake1"], [type |-> "PakeFinished"], [type |-> "Pake2", valid |-> TRUE], [type |-> "Pake3", valid |-> TRUE], [type |-> "PBKDFParamResponse", hasPBKDFParameters |-> FALSE, responderSessionId |-> SessionIds_1], [type |-> "PBKDFParamRequest", initiatorSessionId |-> SessionIds_1, passcodeId |-> 0, hasPBKDFParameters |-> FALSE]}
/\ initiator = [state |-> "WAIT_FINISHED", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ responder = [state |-> "ESTABLISHED", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> TRUE, localMessageCounter |-> 1, peerMaxMessageCounter |-> 0]
/\ pendingInput = NoInput

State 14: <ReceiveInput line 117, col 5 to line 120, col 50 of module core_4_14_1_2>
/\ network = {[type |-> "Pake1"], [type |-> "PakeFinished"], [type |-> "Pake2", valid |-> TRUE], [type |-> "Pake3", valid |-> TRUE], [type |-> "PBKDFParamResponse", hasPBKDFParameters |-> FALSE, responderSessionId |-> SessionIds_1], [type |-> "PBKDFParamRequest", initiatorSessionId |-> SessionIds_1, passcodeId |-> 0, hasPBKDFParameters |-> FALSE]}
/\ initiator = [state |-> "WAIT_FINISHED", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ responder = [state |-> "ESTABLISHED", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> TRUE, localMessageCounter |-> 1, peerMaxMessageCounter |-> 0]
/\ pendingInput = "InitiatePASE"
```

</details>

## Spec text for this section

4.14.1.2. Protocol Details
Message format
All PASE messages SHALL be structured as specified in Section 4.4, “Message Frame Format”.
All PASE messages are sent using an Unsecured Session:
• The Session ID field SHALL be set to 0.
• The Session Type bits of the Security Flags SHALL be set to 0.
• In the PASE messages from the initiator, S Flag SHALL be set to 1 and DSIZ SHALL be set to 0.
• In the PASE messages from the responder, S Flag SHALL be set to 0 and DSIZ SHALL be set to 1.
For each PASE message, the application payload is the TLV encoding of the message structure as
defined below:
Table 24. PASE Messages
Message Name
Payload TLV Encoding
PBKDFParamRequest
pbkdfparamreq-struct
PBKDFParamResponse
pbkdfparamresp-struct
Pake1
pake-1-struct
Pake2
pake-2-struct
Pake3
pake-3-struct
PakeFinished
N/A (encoded via StatusReport)
The other fields of the Message format are not specific to the PASE messages.
For all TLV-encoded PASE messages, any context-specific tags not listed in the associated TLV
schemas SHALL be reserved for future use, and SHALL be silently ignored if seen by a recipient
which cannot understand them.
Message Exchange
The PBKDFParamRequest, PBKDFParamResponse, Pake1, Pake2, Pake3, and PakeFinished of a distinct session
establishment are part of the same message exchange. The initiator and responder SHALL NOT
send encrypted application data in the newly established session until PakeFinished is received by
the initiator within the unencrypted session used for establishment.
Each message SHALL use PROTOCOL_ID_SECURE_CHANNEL as Protocol ID and the corresponding Protocol
Opcode as defined in Table 18, “Secure Channel Protocol Opcodes”.
The flags of the Exchange Flags of the Protocol Header are defined as follows per PASE message:
Message
I Flag
PBKDFParamRequest
PBKDFParamResponse
Pake1
Pake2
Pake3
All PASE messages SHALL be sent reliably. This may be implicit (e.g. TCP) or explicit (e.g. MRP reliable messaging) in the underlying transport.
The other fields of the Protocol Header are not specific to the PASE messages.
PBKDFParamRequest
This message serves to request the PBKDF parameters, with a payload that follows this TLV schema:
pbkdfparamreq-struct => STRUCTURE [ tag-order ]
{
initiatorRandom        [1] : OCTET STRING [ length 32 ],
initiatorSessionId     [2] : UNSIGNED INTEGER [ range 16-bits ],
passcodeId             [3] : UNSIGNED INTEGER [ length 16-bits ],
hasPBKDFParameters     [4] : BOOLEAN,
initiatorSessionParams [5, optional] : session-parameter-struct
}
1. The initiator SHALL generate a random number InitiatorRandom = Crypto_DRBG(len = 32 * 8).
2. The initiator SHALL generate a session identifier (InitiatorSessionId) for subsequent identification of this session. The InitiatorSessionId field SHALL NOT overlap with any other existing
PASE or CASE session identifier in use by the initiator. See Section 4.13.2.4, “Choosing Secure
Unicast Session Identifiers” for more details. The initiator SHALL set the Local Session Identifier in the Session Context to the value InitiatorSessionId.
3. The initiator SHALL choose a passcode identifier (PasscodeId) corresponding to a particular
PAKE passcode verifier installed on the responder. A value of 0 for the passcodeID SHALL correspond to the PAKE passcode verifier for the currently-open commissioning window, if any. Non-
zero values are reserved for future use. For example, for initial commissioning, the verifier
would be the built-in verifier matching the Onboarding Payload's passcode or, equivalently, the
multi-fabric Basic Commissioning Method passcode if that method is supported. For the multi-
fabric Enhanced Commissioning Method, the verifier would match the verifier provided
through the OpenCommissioningWindow command.
4. The initiator SHALL indicate whether the PBKDF parameters (salt and iterations) are known for
the particular passcodeId (for example from the QR code) by setting HasPBKDFParameters. If HasPBKDFParameters is set to True, the responder SHALL NOT return the PBKDF parameters. If HasP­
BKDFParameters is set to False, the responder SHALL return the PBKDF parameters.
5. The initiator SHALL send a message with the appropriate Protocol Id and Protocol Opcode from
Table 18, “Secure Channel Protocol Opcodes” whose payload is the TLV-encoded pbkdfparamreq-struct PBKDFParamRequest with an anonymous tag for the outermost struct.
PBKDFParamRequest =
{
initiatorRandom (1) = InitiatorRandom,
initiatorSessionId (2) = InitiatorSessionId,
passcodeID (3) = PasscodeId,
hasPBKDFParameters (4) = HasPBKDFParameters,
}
PBKDFParamResponse
pbkdfparamresp-struct => STRUCTURE [ tag-order ]
{
initiatorRandom         [1] : OCTET STRING [ length 32 ],
responderRandom         [2] : OCTET STRING [ length 32 ],
responderSessionId      [3] : UNSIGNED INTEGER [ range 16-bits ],
pbkdf_parameters        [4] : Crypto_PBKDFParameterSet,
responderSessionParams  [5, optional] : session-parameter-struct
}
On receipt of PBKDFParamRequest, the responder SHALL:
1. Verify passcodeID is set to 0. If verification fails, the responder SHALL send a status report: StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAME­
TER) and perform no further processing.
2. Generate a random number ResponderRandom = Crypto_DRBG(len = 32 * 8).
3. Generate a session identifier (ResponderSessionId) for subsequent identification of this session.
The ResponderSessionId field SHALL NOT overlap with any other existing PASE or CASE session
identifier in use by the responder. See Section 4.13.2.4, “Choosing Secure Unicast Session Identifiers” for more details. The responder SHALL set the Local Session Identifier in the Session
Context to the value ResponderSessionId.
4. Set the Peer Session Identifier in the Session Context to the value PBKDFParamRequest.initiatorSessionId.
5. Construct the appropriate Crypto_PBKDFParameterSet (PBKDFParameters). If PBKDFParamRequest.hasPBKDFParameters is True the responder SHALL NOT include the PBKDF parameters (i.e.
salt and iteration count) in the Crypto_PBKDFParameterSet. If Msg1.hasPBKDFParameters is False the
responder SHALL include the PBKDF parameters (i.e. salt and iteration count) in the Crypto_PBKDFParameterSet.
6. Send a message with the appropriate Protocol Id and Protocol Opcode from Table 18, “Secure
Channel Protocol Opcodes” whose payload is the TLV-encoded pbkdfparamresp-struct PBKDFParamResponse with an anonymous tag for the outermost struct.
PBKDFParamResponse =
{
initiatorRandom (1) = PBKDFParamRequest.initiatorRandom,
responderRandom (2) = ResponderRandom,
responderSessionId (3) = ResponderSessionId,
pbkdf_parameters (4) = PBKDFParameters
}
Pake1
pake-1-struct => STRUCTURE [ tag-order ]
{
pA [1] : OCTET STRING [ length CRYPTO_PUBLIC_KEY_SIZE_BYTES ],
}
On receipt of PBKDFParamResponse, the initiator SHALL:
1. Set the Peer Session Identifier in the Session Context to the value PBKDFParamResponse.responderSessionId.
2. Generate the Crypto_PAKEValues_Initiator according to the PBKDFParamResponse.pbkdf_parameters
3. Using Crypto_PAKEValues_Initiator, generate pA := Crypto_pA(Crypto_PAKEValues_Initiator)
4. Send a message with the appropriate Protocol Id and Protocol Opcode from Table 18, “Secure
Channel Protocol Opcodes” whose payload is the TLV-encoded pake-1-struct Pake1 with an
anonymous tag for the outermost struct.
Pake1 =
{
pA (1) = pA,
}
Pake2
pake-2-struct => STRUCTURE [ tag-order ]
{
pB [1] : OCTET STRING [ length CRYPTO_PUBLIC_KEY_SIZE_BYTES ],
cB [2] : OCTET STRING [ length CRYPTO_HASH_LEN_BYTES],
}
On receipt of Pake1, the responder SHALL:
1. Compute pB := Crypto_pB(Crypto_PAKEValues_Responder) using the passcode verifier indicated in
PBKDFParamRequest
2. Compute TT := Crypto_Transcript(PBKDFParamRequest, PBKDFParamResponse, Pake1.pA, pB)
3. Compute (cA, cB, Ke) := Crypto_P2(TT, Pake1.pA, pB)
4. Send a message with the appropriate Protocol Id and Protocol Opcode from Table 18, “Secure
Channel Protocol Opcodes” whose payload is the TLV-encoded pake-2-struct Pake2 with an
anonymous tag for the outermost struct.
Pake2 =
{
pB (1) = pB,
cB (2) = cB,
}
Pake3
pake-3-struct => STRUCTURE [ tag-order ]
{
cA [1] : OCTET STRING [length CRYPTO_HASH_LEN_BYTES],
}
On receipt of Pake2, the initiator SHALL:
1. Compute TT := Crypto_Transcript(PBKDFParamRequest, PBKDFParamResponse, Pake1.pA, Pake2.pB)
2. Compute (cA, cB, Ke) := Crypto_P2(TT, Pake1.pA, Pake2.pB)
3. Verify Pake2.cB against cB. If verification fails, the initiator SHALL send a status report: StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAMETER)
and perform no further processing.
4. Send a message with the appropriate Protocol Id and Protocol Opcode from Table 18, “Secure
Channel Protocol Opcodes” whose payload is the TLV-encoded pake-3-struct Pake3 with an
anonymous tag for the outermost struct.
Pake3 =
{
cA (1) = cA,
}
5. The initiator SHALL NOT send any encrypted application data until it receives PakeFinished
from the responder.
On reception of Pake3, the responder SHALL:
1. Verify Pake3.cA against cA. If verification fails, the responder SHALL send a status report: StatusReport(GeneralCode: FAILURE, ProtocolId: SECURE_CHANNEL, ProtocolCode: INVALID_PARAME­
TER) and perform no further processing.
2. The responder SHALL set SessionTimestamp to a timestamp from a clock which would allow for
the eventual determination of the last session use relative to other sessions.
3. The responder SHALL encode and send PakeFinished.
PakeFinished
To indicate the successful completion of the protocol, the responder SHALL send a status report:
StatusReport(GeneralCode: SUCCESS, ProtocolId: SECURE_CHANNEL, ProtocolCode: SESSION_ESTABLISHMENT_SUCCESS).
The initiator SHALL set SessionTimestamp to a timestamp from a clock which would allow for the
eventual determination of the last session use relative to other sessions.
Session Encryption Keys
After verification of Pake3, each party can compute their sending and receiving session keys as
described below:
byte SEKeys_Info[] = /* "SessionKeys" */
{0x53, 0x65, 0x73, 0x73, 0x69, 0x6f, 0x6e, 0x4b,
0x65, 0x79, 0x73}
I2RKey || R2IKey || AttestationChallenge =
Crypto_KDF
(
inputKey = Ke,
salt = [],
info = SEKeys_Info,
len = 3 * CRYPTO_SYMMETRIC_KEY_LENGTH_BITS
)
1. Each key is exactly CRYPTO_SYMMETRIC_KEY_LENGTH_BITS bits.
2. The initiator SHALL use I2RKey to encrypt and integrity protect messages and the `R2IKey' to
decrypt and verify messages.
3. The responder SHALL use R2IKey to encrypt and integrity protect messages and the `I2RKey' to
decrypt and verify messages.
4. The AttestationChallenge SHALL only be used as a challenge during device attestation. See Section 6.2.3, “Device Attestation Procedure” for more details.
Upon initial installation of the new PASE Session Keys:
1. The Node SHALL initialize its Local Message Counter in the Session Context per Section 4.6.1.1,
“Message Counter Initialization”.
2. The Node SHALL initialize the Message Reception State in the Session Context` and set the synchronized max_message_counter of the peer to 0.
where || indicates message concatenation and [] a zero-length array.
