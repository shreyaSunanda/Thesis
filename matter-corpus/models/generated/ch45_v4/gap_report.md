# TLC candidate-gap report

Source log: `models/generated/ch45_v4/tlc_results.jsonl`

Candidate gaps are ordered by **how many steps it took to reach the unhandled input**, not by ranker score: the further the model got before hitting one, the more confidence that the model works and the spec is what ran out.

An **unhandled input** is a reachable state in which an event is waiting and no action of `Next` can consume it: something arrived that the spec text defines no handling for. Unlike a plain deadlock this does **not** fire when a protocol simply ends — "SHALL close the session", "perform no further processing" and the like leave nothing pending, so they are vacuously fine. It is still a *candidate* gap: the generated model may have omitted a handler the spec does describe. Each one needs review against the section's own text.

## Summary

| outcome | units |
|---|---|
| candidate gaps (unhandled input) | 26 → **26** after triage (15 of those reached after real progress) |
| &nbsp;&nbsp;of which in an operational state | **26** |
| &nbsp;&nbsp;of which setup-only (lower priority) | 0 |
| &nbsp;&nbsp;of which unranked (no rule 4b) | 0 |
| invariant violated | 0 |
| checked, nothing found | 9 (of which 4 explored too little to mean anything) |
| **not checkable** (see below) | **5** |
| model-asserted unspecified cases (unverified) | 33 note(s) in 21 unit(s) |
| total | 40 |

35 of 40 modules were actually model-checked. The rest produced no verdict either way.

## Candidate gaps

### `core_4.14.1.2` — Protocol Details

- steps to the unhandled input: 14
- ranker score: 34.62
- module: `core_4_14_1_2.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_6.2.3`: *"The Commissionee SHALL make the Certificate Chain available whenever requested using CertificateChainRequest."*
    - `core_4.14.2.3`: *"Msg1 = { initiatorRandom (1) = InitiatorRandom, initiatorSessionId (2) = InitiatorSessionId, destinationId (3) = DestinationId, initiatorEphPubKey (4) = InitiatorEphKeyPair.publicKey initiatorSessionParams (5) = session-parameter-struct (optional), resumptionID (6) = ResumptionID (optional, only pre"*
    - `core_4.14.2.2`: *"Session Resumption In the case where a Responder is not able to resume a session as requested by a Sigma1 with Resumption, the information included in the Sigma1 with Resumption message SHALL be processed as a Sig­ ma1 message without any resumption fields to construct a Sigma2 message and continue "*
- 🔴 **declared but handled nowhere**: `StatusReport` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `NoInput`=sentinel, `NoSessionId`=opaque, `SessionIds`=set, `MaxMessageCounter`=numeric

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 117 of the module)

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

**Unhandled input under no capability flags** after 14 state(s) (1726 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 117 of the module)

State in which the input went unhandled:

```
State 14: <ReceiveInput line 117, col 5 to line 120, col 50 of module core_4_14_1_2>
/\ network = {[type |-> "Pake1"], [type |-> "PakeFinished"], [type |-> "Pake2", valid |-> TRUE], [type |-> "Pake3", valid |-> TRUE], [type |-> "PBKDFParamResponse", hasPBKDFParameters |-> FALSE, responderSessionId |-> SessionIds_1], [type |-> "PBKDFParamRequest", initiatorSessionId |-> SessionIds_1, passcodeId |-> 0, hasPBKDFParameters |-> FALSE]}
/\ initiator = [state |-> "WAIT_FINISHED", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> FALSE, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0]
/\ responder = [state |-> "ESTABLISHED", passcodeId |-> 0, hasPBKDFParameters |-> FALSE, localSessionId |-> SessionIds_1, peerSessionId |-> SessionIds_1, keysInstalled |-> TRUE, localMessageCounter |-> 1, peerMaxMessageCounter |-> 0]
/\ pendingInput = "InitiatePASE"
```

### `core_4.12.2.2` — Acknowledgements

- steps to the unhandled input: 8
- ranker score: 36.68
- module: `core_4_12_2_2.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.12.1`: *"To support unreliable messages, this flag bit MAY be clear, so that no acknowledgements are requested from the receiver."*
    - `core_4.12.4`: *"Transport Considerations When the upper layer requests a reliable message over a UDP transport, the R Flag SHALL be set on that message indicating that MRP SHALL be used."*
    - `core_4.12.5.1`: *"Reliable Message Processing of Outgoing Messages To prepare a given Protocol Message for transmission, the message SHALL be processed as follows: 1."*
- constants (inferred kind): `Senders`=set, `NoSender`=opaque, `MaxMsgCounter`=numeric, `NoMsgCounter`=numeric, `MaxPendingAcks`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 8 state(s) (1334 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 54 of the module)

Spec clause that action cites:

```
\* Event delivery mechanism.
```
State in which the input went unhandled:

```
State 8: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<0, 0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"
```

**Unhandled input under no capability flags** after 8 state(s) (1334 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 54 of the module)

Spec clause that action cites:

```
\* Event delivery mechanism.
```
State in which the input went unhandled:

```
State 8: <ReceiveInput line 54, col 5 to line 67, col 77 of module core_4_12_2_2>
/\ inputSender = Senders_1
/\ sentAcks = {}
/\ inputMsgCounter = 0
/\ pendingAcks = (Senders_1 :> <<0, 0, 0>> @@ Senders_2 :> <<>>)
/\ historyWindow = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ propagatedMessages = (Senders_1 :> {0} @@ Senders_2 :> {})
/\ pendingInput = "ReceiveReliableMessage"
```

### `core_5.5` — Commissioning Flows

- steps to the unhandled input: 6
- ranker score: 111.9
- module: `core_5_5.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_11.10.7.4`: *"If the LocationCapability attribute is not Indoor/Outdoor and the NewRegulatoryConfig value received does not match either the Indoor or Outdoor fixed value in LocationCapability, then the SetRegulatoryConfigResponse replied SHALL have the ErrorCode field set to ValueOutsideRange error and the Regul"*
    - `core_11.10.7.8`: *"TCUserResponse field This field SHALL contain the user responses to the Enhanced Setup Flow Terms & Conditions as a map where each bit set in the bitmap corresponds to an accepted term in the file located at Section 11.23.6.23, “EnhancedSetupFlowTCUrl”."*
    - `core_11.18.6.5`: *"If the IsForUpdateNOC field is present and set to true, but the command was received over a PASE session, the command SHALL fail with an INVALID_COMMAND status code, as it would never be possible to use a resulting subsequent certificate issued from the CSR with the UpdateNOC command, which is forbi"*
- 🔴 **declared but handled nowhere**: `PASE_PBKDFParamResponse`, `SetRegulatoryConfig`, `SetTCAcknowledgements`, `CSRRequest`, `AddTrustedRootCertificate`, `AddNOC`, `UpdateFabricLabel`, `ScanNetworks`, `AddOrUpdateWiFiNetwork`, `AddOrUpdateThreadNetwork`, `OperationalDiscovery` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `ConcurrentConnectionCap`=boolean, `IsCommissioningWithoutPower`=boolean, `NoInput`=sentinel

**Unhandled input under ConcurrentConnectionCap=True, IsCommissioningWithoutPower=True** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 64 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

**Unhandled input under ConcurrentConnectionCap=True, IsCommissioningWithoutPower=True** after 6 state(s) (75 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 64 of the module)

State in which the input went unhandled:

```
State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

**Unhandled input under ConcurrentConnectionCap=True, IsCommissioningWithoutPower=False** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 64 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

**Unhandled input under ConcurrentConnectionCap=True, IsCommissioningWithoutPower=False** after 6 state(s) (75 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 64 of the module)

State in which the input went unhandled:

```
State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

**Unhandled input under ConcurrentConnectionCap=False, IsCommissioningWithoutPower=True** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 64 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

**Unhandled input under ConcurrentConnectionCap=False, IsCommissioningWithoutPower=True** after 6 state(s) (75 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 64 of the module)

State in which the input went unhandled:

```
State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

**Unhandled input under ConcurrentConnectionCap=False, IsCommissioningWithoutPower=False** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 64 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

**Unhandled input under ConcurrentConnectionCap=False, IsCommissioningWithoutPower=False** after 6 state(s) (75 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 64 of the module)

State in which the input went unhandled:

```
State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

### `core_4.19.4.8` — Packet Acknowledgements

- steps to the unhandled input: 4
- ranker score: 112.1
- module: `core_4_19_4_8.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.19.4.5`: *"If the reassembled buffer’s length does not match that specified by the sender, or if received BTP segment payload size would exceed the maximum BTP packet size, or receiver receives an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when another BTP SDU’s"*
    - `core_4.19.2.1`: *"When set, this bit indicates a BTP handshake packet for session establishment and has a different packet format described below."*
    - `core_4.19.4.2`: *"BTP GATT service Attribute Description BTP Service UUID = MATTER_BLE_SERVICE_UUID C1 Characteristic (Client TX Buffer) UUID = 18EE2EF5-263D-4559-959F-4F9C429F9D11 Characteristic Properties = Write max length = 244 bytes C2 Characteristic (Client RX Buffer) UUID = 18EE2EF5-263D-4559-959F-4F9C429F9D12"*
- constants (inferred kind): `CounterModulus`=numeric, `MaxWindowSize`=numeric, `NoSeqNum`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (4 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 56 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 56, col 5 to line 64, col 39 of module core_4_19_4_8>
/\ state = "CLOSED"
/\ inAckNum = 0
/\ inWindowSize = 0
/\ sendAckTimerRunning = FALSE
/\ ackReceivedTimerRunning = FALSE
/\ unackedSent = {}
/\ pendingAckSeqNum = 3
/\ inSeqNum = 0
/\ nextOutSeqNum = 0
/\ pendingInput = "SendBTPPacket"
/\ lastSentSeqNum = 3
```

**Unhandled input under no capability flags** after 4 state(s) (391 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 56 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 56, col 5 to line 64, col 39 of module core_4_19_4_8>
/\ state = "OPEN"
/\ inAckNum = 0
/\ inWindowSize = 0
/\ sendAckTimerRunning = FALSE
/\ ackReceivedTimerRunning = TRUE
/\ unackedSent = {0}
/\ pendingAckSeqNum = 3
/\ inSeqNum = 0
/\ nextOutSeqNum = 1
/\ pendingInput = "SendAckTimerFires"
/\ lastSentSeqNum = 0
```

### `core_4.14.2.3` — Protocol Details

- steps to the unhandled input: 4
- ranker score: 81.1
- module: `core_4_14_2_3.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.13.3.1`: *"The CAT fields are 32-bit values that MAY have been present in RDN case-authenticated-tag of the remote peer’s operational certificate, during CASE."*
    - `core_4.14.2.6`: *"For the generation of the Destination Identifier, the originator SHALL use the operational group key with the second newest EpochStartTime, if one exists, otherwise it SHALL use the single operational group key available."*
    - `core_4.14.2.8`: *"Minimal Number of CASE Sessions A node SHALL support at least 3 CASE session contexts per fabric."*
- constants (inferred kind): `NoInput`=sentinel, `NullValue`=sentinel, `Now`=opaque, `MSG_SIGMA1`=opaque, `MSG_SIGMA2`=opaque, `MSG_SIGMA3`=opaque, `MSG_SIGMA2_RESUME`=opaque, `MSG_STATUS_REPORT`=opaque, `STATUS_SUCCESS`=opaque, `STATUS_FAILURE`=opaque, `INVALID_PARAMETER`=opaque, `NO_SHARED_TRUST_ROOTS`=opaque, `SESSION_ESTABLISHMENT_SUCCESS`=opaque, `LocalSessionIdInit`=opaque, `LocalSessionIdResp`=opaque, `ResumptionId1`=opaque, `ResumptionId2`=opaque, `DestId1`=opaque

**Unhandled input under no capability flags** after 4 state(s) (7 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 131 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 131, col 5 to line 140, col 50 of module core_4_14_2_3>
/\ network = {[type |-> MSG_SIGMA1, initiatorSessionId |-> LocalSessionIdInit, resumptionID |-> NullValue, initiatorResumeMIC |-> NullValue, destinationId |-> DestId1]}
/\ inMessage = NullValue
/\ initiator = [ state |-> "WAIT_SIGMA2",
  localSessionId |-> LocalSessionIdInit,
  peerSessionId |-> NullValue,
  resumptionId |-> NullValue,
  sessionTimestamp |-> NullValue,
  localMessageCounter |-> NullValue,
  peerMessageCounter |-> NullValue ]
/\ responder = [ state |-> "IDLE",
  localSessionId |-> NullValue,
  peerSessionId |-> NullValue,
  resumptionId |-> NullValue,
  sessionTimestamp |-> NullValue,
  localMessageCounter |-> NullValue,
  peerMessageCounter |-> NullValue ]
/\ pendingInput = "StartCASE_New"
```

**Unhandled input under no capability flags** after 4 state(s) (7 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 131 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 131, col 5 to line 140, col 50 of module core_4_14_2_3>
/\ network = {[type |-> MSG_SIGMA1, initiatorSessionId |-> LocalSessionIdInit, resumptionID |-> NullValue, initiatorResumeMIC |-> NullValue, destinationId |-> DestId1]}
/\ inMessage = NullValue
/\ initiator = [ state |-> "WAIT_SIGMA2",
  localSessionId |-> LocalSessionIdInit,
  peerSessionId |-> NullValue,
  resumptionId |-> NullValue,
  sessionTimestamp |-> NullValue,
  localMessageCounter |-> NullValue,
  peerMessageCounter |-> NullValue ]
/\ responder = [ state |-> "IDLE",
  localSessionId |-> NullValue,
  peerSessionId |-> NullValue,
  resumptionId |-> NullValue,
  sessionTimestamp |-> NullValue,
  localMessageCounter |-> NullValue,
  peerMessageCounter |-> NullValue ]
/\ pendingInput = "StartCASE_New"
```

### `core_4.20.3.7` — Receive Windows

- steps to the unhandled input: 4
- ranker score: 47.51
- module: `core_4_20_3_7.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.20.3.5`: *"If the reassembled buffer’s length does not match that specified by the sender, or if received PAFTP segment payload size would exceed the maximum PAFTP packet size, or receiver receives an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when another PAFTP"*
    - `core_4.20.3.6`: *"Sequence Numbers All PAFTP packets SHALL be sent with sequence numbers, regardless of whether they contain SDU segments (for example, a packet acknowledgement with no attached segment payload)."*
- constants (inferred kind): `MaxWindowSize`=numeric, `MaxPendingTx`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (4 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 44 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 44, col 5 to line 47, col 87 of module core_4_20_3_7>
/\ state = "Uninitialized"
/\ pendingAck = FALSE
/\ remoteWindow = 0
/\ role = "None"
/\ pendingTx = 0
/\ unackedRcvdCount = 0
/\ pendingInput = "EnqueuePayload"
```

**Unhandled input under no capability flags** after 4 state(s) (9 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 44 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 44, col 5 to line 47, col 87 of module core_4_20_3_7>
/\ state = "Open"
/\ pendingAck = FALSE
/\ remoteWindow = 3
/\ role = "Commissioner"
/\ pendingTx = 0
/\ unackedRcvdCount = 0
/\ pendingInput = "EstablishCommissionerSession"
```

### `core_4.19.4.7` — Receive Windows

- steps to the unhandled input: 4
- ranker score: 45.97
- module: `core_4_19_4_7.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.19.4.5`: *"If the reassembled buffer’s length does not match that specified by the sender, or if received BTP segment payload size would exceed the maximum BTP packet size, or receiver receives an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when another BTP SDU’s"*
    - `core_4.19.4.8`: *"Per BTP Frame Formats, BTP packet receipt acknowledgements SHALL be received as unsigned 8- bit integer values in the header of a BTP packet."*
    - `core_4.19.2.1`: *"When set, this bit indicates a BTP handshake packet for session establishment and has a different packet format described below."*
- constants (inferred kind): `MaxWindowSizeLimit`=numeric, `MaxQueueSize`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (26 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 46 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 46, col 5 to line 50, col 106 of module core_4_19_4_7>
/\ state = "Uninitialized"
/\ unackedReceivedPackets = 0
/\ maxWindowSize = 0
/\ pendingTxQueue = 0
/\ remoteWindowCount = 0
/\ role = "None"
/\ inputData = [negotiatedMaxWindow |-> 1, ackedCount |-> 0]
/\ pendingInput = "AppEnqueuePacket"
```

**Unhandled input under no capability flags** after 4 state(s) (86 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 46 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 46, col 5 to line 50, col 106 of module core_4_19_4_7>
/\ state = "Established"
/\ unackedReceivedPackets = 0
/\ maxWindowSize = 1
/\ pendingTxQueue = 0
/\ remoteWindowCount = 1
/\ role = "Client"
/\ inputData = [negotiatedMaxWindow |-> 1, ackedCount |-> 0]
/\ pendingInput = "StartSessionAsClient"
```

### `core_4.19.4.3` — Session Establishment

- steps to the unhandled input: 4
- ranker score: 33.81
- module: `core_4_19_4_3.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- constants (inferred kind): `BTP_CONN_RSP_TIMEOUT`=numeric, `MinATT_MTU`=numeric, `MaxCharacteristicLen`=numeric, `GATT_Header_Size`=numeric, `C2_CCCD_Enable_Value`=opaque, `ClientSupportedVersions`=set, `ServerSupportedVersions`=set, `ClientProtocolVersionsSequence`=opaque, `ClientATT_MTU`=opaque, `ServerATT_MTU`=numeric, `ClientMaxWindowSize`=numeric, `ServerMaxWindowSize`=numeric, `ClientKnowsATT_MTU`=boolean, `NoInput`=sentinel

**Unhandled input under ClientKnowsATT_MTU=True** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 84 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = FALSE
/\ pendingInput = "DPLE_Update"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE
```

**Unhandled input under ClientKnowsATT_MTU=True** after 4 state(s) (14 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 84 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = TRUE
/\ pendingInput = "BLE_Connect"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "BLE_CONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "BLE_CONNECTED"
/\ clientErrorReported = FALSE
```

**Unhandled input under ClientKnowsATT_MTU=False** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 84 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = FALSE
/\ pendingInput = "DPLE_Update"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE
```

**Unhandled input under ClientKnowsATT_MTU=False** after 4 state(s) (14 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 84 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = TRUE
/\ pendingInput = "BLE_Connect"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "BLE_CONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "BLE_CONNECTED"
/\ clientErrorReported = FALSE
```

### `core_4.19.4.6` — Sequence Numbers

- steps to the unhandled input: 4
- ranker score: 26.95
- module: `core_4_19_4_6.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.19.4.5`: *"If the reassembled buffer’s length does not match that specified by the sender, or if received BTP segment payload size would exceed the maximum BTP packet size, or receiver receives an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when another BTP SDU’s"*
    - `core_4.19.2.1`: *"When set, this bit indicates a BTP handshake packet for session establishment and has a different packet format described below."*
    - `core_4.19.4.4`: *"All BTP packets sent on an open BLE connection SHALL adhere to the BTP Packet PDU binary data format specified in BTP Frame Formats."*
- constants (inferred kind): `MaxSeqNum`=numeric, `NoInput`=sentinel, `NoActor`=opaque, `NoSeqNum`=numeric

**Unhandled input under no capability flags** after 2 state(s) (14 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 42 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 42, col 5 to line 47, col 65 of module core_4_19_4_6>
/\ inEventSeq = 0
/\ txSeq = [Client |-> 3, Server |-> 3]
/\ appError = FALSE
/\ sessionState = "CLOSED"
/\ expectedRxSeq = [Client |-> 3, Server |-> 3]
/\ pendingInput = "SendPacket"
/\ inEventActor = NoActor
```

**Unhandled input under no capability flags** after 4 state(s) (50 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 42 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 42, col 5 to line 47, col 65 of module core_4_19_4_6>
/\ inEventSeq = 0
/\ txSeq = [Client |-> 0, Server |-> 1]
/\ appError = FALSE
/\ sessionState = "OPEN"
/\ expectedRxSeq = [Client |-> 1, Server |-> 0]
/\ pendingInput = "CompleteHandshake"
/\ inEventActor = NoActor
```

### `core_4.20.3.6` — Sequence Numbers

- steps to the unhandled input: 4
- ranker score: 26.8
- module: `core_4_20_3_6.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.20.3.5`: *"If the reassembled buffer’s length does not match that specified by the sender, or if received PAFTP segment payload size would exceed the maximum PAFTP packet size, or receiver receives an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when another PAFTP"*
    - `core_4.20.3.8`: *"A peer SHALL restart its send-acknowledgement timer when a pending acknowledgement is sent, either as a stand-alone PAFTP packet or piggybacked onto an outgoing buffer segment, for any but its received unacknowledged packet with the largest packet sequence number."*
    - `core_4.20.2.1`: *"When set, this bit indicates a PAFTP handshake packet for session establishment and has a different packet format described below."*
- constants (inferred kind): `NoInput`=sentinel, `NoSeqNum`=numeric

**Unhandled input under no capability flags** after 2 state(s) (4 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 26 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 26, col 5 to line 32, col 85 of module core_4_20_3_6>
/\ applicationError = FALSE
/\ expectedRxSeqNum = 3
/\ txSeqNum = 3
/\ sessionState = "HANDSHAKE"
/\ role = "None"
/\ inPacketSeqNum = 3
/\ pendingInput = "SendPacket"
```

**Unhandled input under no capability flags** after 4 state(s) (263 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 26 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 26, col 5 to line 32, col 85 of module core_4_20_3_6>
/\ applicationError = FALSE
/\ expectedRxSeqNum = 1
/\ txSeqNum = 0
/\ sessionState = "ESTABLISHED"
/\ role = "Commissioner"
/\ inPacketSeqNum = 3
/\ pendingInput = "CompleteHandshakeAsCommissioner"
```

### `core_4.21.4.2` — TRANSPORT command

- steps to the unhandled input: 4
- ranker score: 24.68
- module: `core_4_21_4_2.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.21.4`: *"In case the size of the Matter message to transmit in the TRANSPORT command APDU is bigger than the maximum size that can be transmitted by this APDU, the APDU chaining procedure specified in ISO/IEC 7816-4 SHALL be used, even though the TRANSPORT command belongs to proprietary class."*
    - `core_4.21.4.1`: *"SELECT command Matter commissioning SHALL be initiated by the NFC Reader/Writer by issuing the 7816-4 SELECT command with the Application Identifier (AID) 'A0 00 00 09 09 8A 77 E4 01' as shown in Table 44."*
    - `core_4.21.4.3`: *"GET RESPONSE command This command SHALL be issued following the reception of an incomplete successful R-APDU, in compliance with ISO/IEC 7816-4."*
- 🔴 **declared but handled nowhere**: `Receive_GET_RESPONSE_Command` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `MaxMessageSize`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 45 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 45, col 5 to line 48, col 148 of module core_4_21_4_2>
/\ rx_accumulated_len = 0
/\ in_cmd_P1P2 = 0
/\ rx_expected_len = 0
/\ tx_pending_len = 0
/\ in_cmd_CLA = "None"
/\ commissioned = FALSE
/\ last_response = [SW1 |-> "None", SW2 |-> 0]
/\ in_cmd_Lc = 0
/\ in_cmd_Le = 0
/\ pendingInput = "Receive_TRANSPORT_Command"
```

**Unhandled input under no capability flags** after 4 state(s) (8 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 45 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 45, col 5 to line 48, col 148 of module core_4_21_4_2>
/\ rx_accumulated_len = 0
/\ in_cmd_P1P2 = 0
/\ rx_expected_len = 0
/\ tx_pending_len = 0
/\ in_cmd_CLA = "None"
/\ commissioned = TRUE
/\ last_response = [SW1 |-> "None", SW2 |-> 0]
/\ in_cmd_Lc = 0
/\ in_cmd_Le = 0
/\ pendingInput = "Receive_GET_RESPONSE_Command"
```

### `core_4.23.3.1` — Advertisement from Commissionee

- steps to the unhandled input: 4
- ranker score: 22.74
- module: `core_4_23_3_1.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.23.3.2`: *"If the contents of the DNS Announcement do not match the intents of the Commissioner, the Commissioner SHALL ignore the DNS Announcement and SHALL NOT initiate commissioning with that Commissionee."*
    - `core_4.3.1`: *"If a Node is connected to multiple IP-bearing networks, and it receives either the OpenCommissioningWindow or the OpenBasicCommissioningWindow command, it MAY make itself discoverable only on the network on which the command was received."*
    - `core_4.23.2.2`: *"For non-concurrent connection commissioning, the MAC extended address MAY change after the commissioning connection is closed."*
- 🔴 **declared but handled nowhere**: `ReceiveDNSAnnouncementResponse` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `MaxRetransmissions`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 29 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 29, col 5 to line 32, col 43 of module core_4_23_3_1>
/\ state = "Uninitialized"
/\ retransmitCount = 0
/\ pendingInput = "ReceiveCommissioningMessage"
```

**Unhandled input under no capability flags** after 4 state(s) (8 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 29 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 29, col 5 to line 32, col 43 of module core_4_23_3_1>
/\ state = "WaitingInitial"
/\ retransmitCount = 0
/\ pendingInput = "SelectJoinerRouter"
```

### `core_4.20.3.3` — Session Establishment

- steps to the unhandled input: 4
- ranker score: 22.17
- module: `core_4_20_3_3.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.20.3.8`: *"Because the server’s handshake response bears an implicit PAFTP sequence number of zero, a server SHALL start its acknowledgement-received timer when it sends a handshake response."*
    - `core_4.20.2.1`: *"When set, this bit indicates a PAFTP handshake packet for session establishment and has a different packet format described below."*
    - `core_4.20.3.6`: *"The sequence number of the first packet sent by the Commissioner after completion of the PAFTP session handshake SHALL be zero."*
- constants (inferred kind): `PAFTP_CONN_RSP_TIMEOUT`=numeric, `CommissionerSupportedVersions`=set, `CommissionerMaxInfoLength`=numeric, `CommissionerMaxWindowSize`=numeric, `DeviceSupportedVersions`=set, `DeviceMaxInfoLength`=numeric, `DeviceMaxWindowSize`=numeric, `NoVersion`=opaque, `NoSize`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 80 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 80, col 5 to line 86, col 73 of module core_4_20_3_3>
/\ reqInfoLength = 3
/\ commState = "WFA_USD_Connected"
/\ respVersion = NoVersion
/\ respWindowSize = 3
/\ reqVersions = {}
/\ respInfoLength = 3
/\ sessionVersion = NoVersion
/\ commTimerActive = FALSE
/\ sessionWindowSize = 3
/\ pendingInput = "ReceiveHandshakeRequest"
/\ sessionInfoLength = 3
/\ reqWindowSize = 3
/\ devState = "WFA_USD_Connected"
```

**Unhandled input under no capability flags** after 4 state(s) (7 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 80 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 80, col 5 to line 86, col 73 of module core_4_20_3_3>
/\ reqInfoLength = 3
/\ commState = "WaitingForResponse"
/\ respVersion = NoVersion
/\ respWindowSize = 3
/\ reqVersions = {CommissionerSupportedVersions_1, CommissionerSupportedVersions_2}
/\ respInfoLength = 3
/\ sessionVersion = NoVersion
/\ commTimerActive = TRUE
/\ sessionWindowSize = 3
/\ pendingInput = "InitiateHandshake"
/\ sessionInfoLength = 3
/\ reqWindowSize = 3
/\ devState = "WFA_USD_Connected"
```

### `core_4.7.2` — Message Reception

- steps to the unhandled input: 4
- ranker score: 20.92
- module: `core_4_7_2.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- constants (inferred kind): `NoInput`=sentinel, `NoTimestamp`=opaque, `UpdatedTimestamp`=opaque, `Key1`=opaque, `Key2`=opaque

**Unhandled input under no capability flags** after 4 state(s) (3075 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 67 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 67, col 5 to line 70, col 125 of module core_4_7_2>
/\ state = "VALIDITY_CHECKS"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> FALSE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> FALSE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "UDP" ]
/\ pendingInput = "ReceiveMessage"
/\ errorState = "none"
```

**Unhandled input under no capability flags** after 4 state(s) (3075 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 67 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 67, col 5 to line 70, col 125 of module core_4_7_2>
/\ state = "VALIDITY_CHECKS"
/\ activeTimestamp = NoTimestamp
/\ keysRemaining = {}
/\ sessionTimestamp = NoTimestamp
/\ deliveredToExchange = FALSE
/\ currentMessage = [ version |-> 0,
  sessionType |-> "Unsecured",
  isUnicastSession |-> FALSE,
  dsizIndicatesGroup |-> FALSE,
  dsizZero |-> FALSE,
  sFlagZero |-> FALSE,
  keysFound |-> FALSE,
  keysToProcess |-> {},
  pFlagSet |-> FALSE,
  transport |-> "UDP" ]
/\ pendingInput = "ReceiveMessage"
/\ errorState = "none"
```

### `core_4.20.3.8` — Packet Acknowledgements

- steps to the unhandled input: 2
- ranker score: 127.15
- module: `core_4_20_3_8.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.20.3.5`: *"If the reassembled buffer’s length does not match that specified by the sender, or if received PAFTP segment payload size would exceed the maximum PAFTP packet size, or receiver receives an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when another PAFTP"*
    - `core_4.20.3.6`: *"Sequence Numbers All PAFTP packets SHALL be sent with sequence numbers, regardless of whether they contain SDU segments (for example, a packet acknowledgement with no attached segment payload)."*
    - `core_4.20.3.7`: *"Each peer SHALL decrement this counter when it sends a packet and increment this counter when a sent packet is acknowledged."*
- constants (inferred kind): `MaxSeqNum`=numeric, `NoSeqNum`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (19 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 54 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 54, col 5 to line 66, col 30 of module core_4_20_3_8>
/\ outSeqNum = 1
/\ pendingAck = 3
/\ inAckNum = 3
/\ sessionState = "OPEN"
/\ largestUnackedReceived = 3
/\ ackReceivedTimer = "STOPPED"
/\ unackedSent = {}
/\ inSeqNum = 3
/\ sendAckTimer = "STOPPED"
/\ pendingInput = "AckReceivedTimerExpires"
/\ receivedSeqNums = {}
/\ mostRecentUnackedSent = 3
```

**Unhandled input under no capability flags** after 2 state(s) (19 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 54 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 54, col 5 to line 66, col 30 of module core_4_20_3_8>
/\ outSeqNum = 1
/\ pendingAck = 3
/\ inAckNum = 3
/\ sessionState = "OPEN"
/\ largestUnackedReceived = 3
/\ ackReceivedTimer = "STOPPED"
/\ unackedSent = {}
/\ inSeqNum = 3
/\ sendAckTimer = "STOPPED"
/\ pendingInput = "AckReceivedTimerExpires"
/\ receivedSeqNums = {}
/\ mostRecentUnackedSent = 3
```

### `core_4.12.2.1` — Retransmissions

- steps to the unhandled input: 2
- ranker score: 54.01
- module: `core_4_12_2_1.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.12.3`: *"MRP SHALL support one pending acknowledgement and one pending retransmission per Exchange."*
    - `core_4.12.5.1`: *"Any message flagged for reliable delivery (R Flag set) SHALL be stored in the retransmission table to track the message until it has been successfully acknowledged by the peer."*
    - `core_4.12.5.2`: *"If the timer triggers before being cancelled, a standalone acknowledgment SHALL be sent to the source of the message."*
- constants (inferred kind): `MRP_MAX_TRANSMISSIONS`=numeric, `MRP_BACKOFF_BASE`=numeric, `MRP_BACKOFF_THRESHOLD`=numeric, `MRP_BACKOFF_MARGIN`=numeric, `SESSION_ACTIVE_INTERVAL`=numeric, `SESSION_IDLE_INTERVAL`=numeric, `FastPollingInterval`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 82 of the module)

Spec clause that action cites:

```
\* REQUIRED: receive an input event
```
State in which the input went unhandled:

```
State 2: <ReceiveInput line 82, col 5 to line 85, col 124 of module core_4_12_2_1>
/\ state = "IDLE"
/\ isICD = FALSE
/\ isFirstMessage = TRUE
/\ timerRunning = FALSE
/\ peerActiveMode = FALSE
/\ operationalDiscoveryInitiated = FALSE
/\ pendingInput = "RetransmissionTimerExpired"
/\ sendAttempts = 0
```

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 82 of the module)

Spec clause that action cites:

```
\* REQUIRED: receive an input event
```
State in which the input went unhandled:

```
State 2: <ReceiveInput line 82, col 5 to line 85, col 124 of module core_4_12_2_1>
/\ state = "IDLE"
/\ isICD = FALSE
/\ isFirstMessage = TRUE
/\ timerRunning = FALSE
/\ peerActiveMode = FALSE
/\ operationalDiscoveryInitiated = FALSE
/\ pendingInput = "RetransmissionTimerExpired"
/\ sendAttempts = 0
```

### `core_4.12.5.1` — Reliable Message Processing of Outgoing Messages

- steps to the unhandled input: 2
- ranker score: 52.11
- module: `core_4_12_5_1.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.12.4`: *"Transport Considerations When the upper layer requests a reliable message over a UDP transport, the R Flag SHALL be set on that message indicating that MRP SHALL be used."*
- constants (inferred kind): `MaxRetries`=numeric, `UnsecuredSessionType`=opaque, `NoInput`=sentinel, `NullMsgId`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 62 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 62, col 5 to line 65, col 105 of module core_4_12_5_1>
/\ state = "IDLE"
/\ ackTable = {}
/\ activeMsgId = NullMsgId
/\ appNotifications = {}
/\ inputMsg = [ msgId |-> NullMsgId,
  destNodeId |-> 0,
  exchangeId |-> 0,
  sessionId |-> 0,
  sessionCredentials |-> 0,
  sessionType |-> UnsecuredSessionType,
  isStandaloneAck |-> FALSE,
  reliable |-> FALSE,
  transport |-> "UDP",
  securityFlags |-> 0,
  aFlag |-> FALSE,
  ackMsgCounter |-> 0,
  rFlag |-> FALSE ]
/\ pendingInput = "TransportSendFatalError"
/\ retransTable = {}
/\ timeoutMsgId = NullMsgId
```

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 62 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 62, col 5 to line 65, col 105 of module core_4_12_5_1>
/\ state = "IDLE"
/\ ackTable = {}
/\ activeMsgId = NullMsgId
/\ appNotifications = {}
/\ inputMsg = [ msgId |-> NullMsgId,
  destNodeId |-> 0,
  exchangeId |-> 0,
  sessionId |-> 0,
  sessionCredentials |-> 0,
  sessionType |-> UnsecuredSessionType,
  isStandaloneAck |-> FALSE,
  reliable |-> FALSE,
  transport |-> "UDP",
  securityFlags |-> 0,
  aFlag |-> FALSE,
  ackMsgCounter |-> 0,
  rFlag |-> FALSE ]
/\ pendingInput = "TransportSendFatalError"
/\ retransTable = {}
/\ timeoutMsgId = NullMsgId
```

### `core_4.18.5` — Message Counter Synchronization Exchange

- steps to the unhandled input: 2
- ranker score: 48.36
- module: `core_4_18_5.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- constants (inferred kind): `NoInput`=sentinel, `LocalNodeId`=opaque

**Unhandled input under no capability flags** after 2 state(s) (1026 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 99 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 99, col 5 to line 108, col 141 of module core_4_18_5>
/\ inDestId = 0
/\ localGlobalGroupCounter = 100
/\ inSourceId = 0
/\ inSyncCounter = 0
/\ outMsg = [type |-> "None"]
/\ timerArmed = FALSE
/\ inExchangeId = 0
/\ inChallengeOrResponse = 0
/\ peerMessageReceptionState = [counter |-> 0, synchronized |-> TRUE, bitmapCleared |-> TRUE]
/\ activeExchange = [active |-> FALSE, exchangeId |-> 0, challenge |-> 0, peerId |-> 0]
/\ syncState = "Idle"
/\ queuedMessagesCount = 0
/\ pendingInput = "JitterTimerExpired"
```

**Unhandled input under no capability flags** after 2 state(s) (1026 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 99 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 99, col 5 to line 108, col 141 of module core_4_18_5>
/\ inDestId = 0
/\ localGlobalGroupCounter = 100
/\ inSourceId = 0
/\ inSyncCounter = 0
/\ outMsg = [type |-> "None"]
/\ timerArmed = FALSE
/\ inExchangeId = 0
/\ inChallengeOrResponse = 0
/\ peerMessageReceptionState = [counter |-> 0, synchronized |-> TRUE, bitmapCleared |-> TRUE]
/\ activeExchange = [active |-> FALSE, exchangeId |-> 0, challenge |-> 0, peerId |-> 0]
/\ syncState = "Idle"
/\ queuedMessagesCount = 0
/\ pendingInput = "JitterTimerExpired"
```

### `core_4.19.4.11` — Protocol State Diagrams

- steps to the unhandled input: 2
- ranker score: 27.69
- module: `core_4_19_4_11.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.19.4.5`: *"If the reassembled buffer’s length does not match that specified by the sender, or if received BTP segment payload size would exceed the maximum BTP packet size, or receiver receives an Ending Segment without the presence of a previous Beginning Segment, or a Beginning Segment when another BTP SDU’s"*
    - `core_4.19.4.6`: *"Sequence Numbers All BTP packets SHALL be sent with sequence numbers, regardless of whether they contain SDU segments (for example, a packet acknowledgement with no attached segment payload)."*
    - `core_4.19.4.7`: *"Each peer SHALL decrement this counter when it sends a packet via GATT write or indication and increment this counter when a sent packet is acknowledged."*
- 🔴 **declared but handled nowhere**: `AckTimeout` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `Role`=string, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (5 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 31 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 31, col 5 to line 34, col 42 of module core_4_19_4_11>
/\ state = "PostEstablishment"
/\ lastSendMethod = "None"
/\ pendingInput = "AckTimeout"
```

**Unhandled input under no capability flags** after 2 state(s) (5 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 31 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 31, col 5 to line 34, col 42 of module core_4_19_4_11>
/\ state = "PostEstablishment"
/\ lastSendMethod = "None"
/\ pendingInput = "AckTimeout"
```

### `core_5.9.3` — Network Recovery Flow

- steps to the unhandled input: 2
- ranker score: 27.37
- module: `core_5_9_3.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 🔴 **declared but handled nowhere**: `UserConsentDenied` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 38 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 38, col 5 to line 41, col 95 of module core_5_9_3>
/\ state = "OpNetworkNormal"
/\ failSafeState = "Disarmed"
/\ sessionChannel = "None"
/\ reconnectAttempts = "Active"
/\ hasNewCredentials = FALSE
/\ pendingInput = "Wait120sTimeout"
```

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 38 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 38, col 5 to line 41, col 95 of module core_5_9_3>
/\ state = "OpNetworkNormal"
/\ failSafeState = "Disarmed"
/\ sessionChannel = "None"
/\ reconnectAttempts = "Active"
/\ hasNewCredentials = FALSE
/\ pendingInput = "Wait120sTimeout"
```

### `core_4.12.6.1` — Retransmission Table

- steps to the unhandled input: 2
- ranker score: 26.4
- module: `core_4_12_6_1.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.12.2.1`: *"The duration of the retransmission timer SHALL be calculated as follows: "mrpBackoffTime" = i * "MRP_BACKOFF_BASE"^(max(0,n-"MRP_BACKOFF_THRESHOLD")) * (1.0 + "random"(0,1) * "MRP_BACKOFF_JITTER") Where: {:("mrpBackoffTime", =, "the resultant retransmission timeout for this transmission"),(n, =, "th"*
    - `core_4.12.3`: *"MRP SHALL support one pending acknowledgement and one pending retransmission per Exchange."*
    - `core_4.12.5.1`: *"Any message flagged for reliable delivery (R Flag set) SHALL be stored in the retransmission table to track the message until it has been successfully acknowledged by the peer."*
- 🔴 **declared but handled nowhere**: `RetransmissionTimeout` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `MRP_MAX_TRANSMISSIONS`=numeric, `NoInput`=sentinel, `NullContext`=sentinel, `MaxMessageCounter`=numeric

**Unhandled input under no capability flags** after 2 state(s) (34 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 41 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 41, col 5 to line 48, col 65 of module core_4_12_6_1>
/\ state = "OPERATIONAL"
/\ retransmissionTable = {}
/\ appNotifications = {}
/\ inputMsg = [exchange |-> NullContext, counter |-> 0, buffer |-> NullContext]
/\ pendingInput = "RetransmissionTimeout"
```

**Unhandled input under no capability flags** after 2 state(s) (34 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 41 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 41, col 5 to line 48, col 65 of module core_4_12_6_1>
/\ state = "OPERATIONAL"
/\ retransmissionTable = {}
/\ appNotifications = {}
/\ inputMsg = [exchange |-> NullContext, counter |-> 0, buffer |-> NullContext]
/\ pendingInput = "RetransmissionTimeout"
```

### `core_4.17.3.5` — Epoch Key Rotation logic

- steps to the unhandled input: 2
- ranker score: 24.84
- module: `core_4_17_3_5.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.17.3.2`: *"Any update of the key set, including a partial update, SHALL remove all previous keys in the set, however many were defined."*
    - `core_4.17.3.4`: *"The Administrator SHOULD provide a sufficient set of epoch keys to Nodes that do not maintain synchronized time so that they can maintain communication with other group members while a key update is in progress."*
    - `core_4.17.1.1`: *"Administrators SHALL assign Group Ids such that no two operational groups within a Fabric have the same Group ID."*
- constants (inferred kind): `Fabrics`=set, `GroupKeySetIDs`=set, `KeyIDs`=set, `MaxTime`=numeric, `IPKGroupKeySetID`=opaque, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (131073 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 81 of the module)

Spec clause that action cites:

```
\* Delivers an inbound event along with its associated payload data.
```
State in which the input went unhandled:

```
State 2: <ReceiveInput line 81, col 5 to line 90, col 52 of module core_4_17_3_5>
/\ state = "SteadyState"
/\ inOldKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ groupKeySets = {}
/\ inFabric = Fabrics_1
/\ systemTime = 0
/\ inNewKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ inKeys = {}
/\ pendingInput = "AdminUpdate"
/\ inID = GroupKeySetIDs_1
```

**Unhandled input under no capability flags** after 2 state(s) (131073 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 81 of the module)

Spec clause that action cites:

```
\* Delivers an inbound event along with its associated payload data.
```
State in which the input went unhandled:

```
State 2: <ReceiveInput line 81, col 5 to line 90, col 52 of module core_4_17_3_5>
/\ state = "SteadyState"
/\ inOldKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ groupKeySets = {}
/\ inFabric = Fabrics_1
/\ systemTime = 0
/\ inNewKey = [id |-> KeyIDs_1, startTime |-> 0]
/\ inKeys = {}
/\ pendingInput = "AdminUpdate"
/\ inID = GroupKeySetIDs_1
```

### `core_4.20.3.5` — Message Segmentation and Reassembly

- steps to the unhandled input: 2
- ranker score: 23.64
- module: `core_4_20_3_5.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- constants (inferred kind): `MaxSduSize`=numeric, `MaxPayloadSize`=numeric, `MaxQueueSize`=numeric, `MaxSeqNum`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (1922 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 58 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 58, col 5 to line 70, col 124 of module core_4_20_3_5>
/\ txCurrentSdu = 0
/\ inSduSize = 1
/\ rxExpectedLen = 0
/\ inSegLen = 0
/\ txBytesSent = 0
/\ rxAccumulatedLen = 0
/\ inSegEnd = FALSE
/\ rxState = "IDLE"
/\ rxExpectedSeqNum = 0
/\ inSegSeqNum = 0
/\ txQueue = <<>>
/\ pendingInput = "TxComplete"
/\ inSegBeg = FALSE
/\ inSegMsgLen = 0
/\ txState = "IDLE"
```

**Unhandled input under no capability flags** after 2 state(s) (1922 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 58 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 58, col 5 to line 70, col 124 of module core_4_20_3_5>
/\ txCurrentSdu = 0
/\ inSduSize = 1
/\ rxExpectedLen = 0
/\ inSegLen = 0
/\ txBytesSent = 0
/\ rxAccumulatedLen = 0
/\ inSegEnd = FALSE
/\ rxState = "IDLE"
/\ rxExpectedSeqNum = 0
/\ inSegSeqNum = 0
/\ txQueue = <<>>
/\ pendingInput = "TxComplete"
/\ inSegBeg = FALSE
/\ inSegMsgLen = 0
/\ txState = "IDLE"
```

### `core_4.19.4.5` — Message Segmentation and Reassembly

- steps to the unhandled input: 2
- ranker score: 21.76
- module: `core_4_19_4_5.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- 📎 **possibly handled nearby** — read these before calling it a gap:
    - `core_4.4.4`: *"This message size limit SHALL apply to the UDP transport ."*
    - `core_4.19.2.1`: *"A segment MAY have both the Beginning and Ending bits set indicating that a full BTP SDU is included in the message."*
    - `core_4.19.4.3`: *"If this timer expires before the client receives a handshake response from the server, the client SHALL close the BTP session and report an error to the application."*
- constants (inferred kind): `MaxSduSize`=numeric, `MaxBtpPacketSize`=numeric, `BtpHeaderSizeWithMsgLength`=numeric, `BtpHeaderSizeWithoutMsgLength`=numeric, `MaxQueueLen`=numeric, `NullSdu`=sentinel, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (5 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 67 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 67, col 5 to line 76, col 144 of module core_4_19_4_5>
/\ state = "Running"
/\ rxAccumulatedLength = 0
/\ txCurrentSduLen = NullSdu
/\ inAppSduLength = 4
/\ inSegBeginning = FALSE
/\ txInFlight = FALSE
/\ inSegMsgLength = 0
/\ rxExpectedLength = 0
/\ inSegEnding = FALSE
/\ rxInProgress = FALSE
/\ txSentLen = 0
/\ rxSessionState = "OPEN"
/\ inSegPayloadLength = 0
/\ txQueue = <<>>
/\ pendingInput = "AppSendSDU"
```

**Unhandled input under no capability flags** after 2 state(s) (5 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 67 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 67, col 5 to line 76, col 144 of module core_4_19_4_5>
/\ state = "Running"
/\ rxAccumulatedLength = 0
/\ txCurrentSduLen = NullSdu
/\ inAppSduLength = 4
/\ inSegBeginning = FALSE
/\ txInFlight = FALSE
/\ inSegMsgLength = 0
/\ rxExpectedLength = 0
/\ inSegEnding = FALSE
/\ rxInProgress = FALSE
/\ txSentLen = 0
/\ rxSessionState = "OPEN"
/\ inSegPayloadLength = 0
/\ txQueue = <<>>
/\ pendingInput = "AppSendSDU"
```

### `core_4.12.6.2` — Acknowledgement Table

- steps to the unhandled input: 2
- ranker score: 21.46
- module: `core_4_12_6_2.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- constants (inferred kind): `ExchangeIds`=set, `MessageCounters`=set, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (57 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 53 of the module)

Spec clause that action cites:

```
\* REQUIRED - Exactly one action delivering an event.
```
State in which the input went unhandled:

```
State 2: <ReceiveInput line 53, col 5 to line 60, col 36 of module core_4_12_6_2>
/\ state = (ExchangeIds_1 :> "OPEN" @@ ExchangeIds_2 :> "OPEN")
/\ ackTable = {}
/\ in_retransListEmpty = FALSE
/\ in_msgCounter = MessageCounters_1
/\ pendingInput = "RetransmissionsCompleted"
/\ in_exchangeId = ExchangeIds_1
```

**Unhandled input under no capability flags** after 2 state(s) (57 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 53 of the module)

Spec clause that action cites:

```
\* REQUIRED - Exactly one action delivering an event.
```
State in which the input went unhandled:

```
State 2: <ReceiveInput line 53, col 5 to line 60, col 36 of module core_4_12_6_2>
/\ state = (ExchangeIds_1 :> "OPEN" @@ ExchangeIds_2 :> "OPEN")
/\ ackTable = {}
/\ in_retransListEmpty = FALSE
/\ in_msgCounter = MessageCounters_1
/\ pendingInput = "RetransmissionsCompleted"
/\ in_exchangeId = ExchangeIds_1
```

### `core_4.10.5.3` — Closing an Exchange

- steps to the unhandled input: 2
- ranker score: 21.03
- module: `core_4_10_5_3.tla`
- 🔴 **operational state** — the module says the device genuinely sits in this state; the event did not arrive during setup
- constants (inferred kind): `NoInput`=sentinel, `MaxAcks`=numeric

**Unhandled input under no capability flags** after 2 state(s) (11 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 37 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 37, col 5 to line 41, col 63 of module core_4_10_5_3>
/\ ackTableHasEntry = FALSE
/\ exchangeState = "Open"
/\ standaloneAckSentFlag = FALSE
/\ standaloneAcksSent = 0
/\ retransmissionsPending = FALSE
/\ pendingInput = "RetransmissionsComplete"
```

**Unhandled input under no capability flags** after 2 state(s) (11 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 37 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 37, col 5 to line 41, col 63 of module core_4_10_5_3>
/\ ackTableHasEntry = FALSE
/\ exchangeState = "Open"
/\ standaloneAckSentFlag = FALSE
/\ standaloneAcksSent = 0
/\ retransmissionsPending = FALSE
/\ pendingInput = "RetransmissionsComplete"
```

## Model-asserted unspecified cases

These are **not** TLC findings. While writing each model the generator was told (prompt rule 2) to leave a `\* TODO: unspecified` note rather than invent behaviour wherever the spec text did not say what happens. These are those notes, verbatim.

They are a **separate, unverified signal**. TLC never checked them. Some are genuine omissions, some are modelling limitations (TLA+ has no floating point), and some may simply be the generator misreading the text. Treat each as a lead to check against the section, not as a result.

They are listed for **every generated module**, including those TLC could not reach a verdict on — a module that never compiled can still have flagged a real omission on its way past.

### `core_4.12.2.1` — Retransmissions

- TLC outcome: **unhandled_input**
- ranker score: 54.01

> the spec states first messages use idle state and subsequent use active state,
>
> — line 39 (near `BaseInterval`)

### `core_4.12.5.1` — Reliable Message Processing of Outgoing Messages

- TLC outcome: **unhandled_input**
- ranker score: 52.11

> Does eviction happen immediately after the max-th transport send, or after a timeout waiting for its ack? Modeling as immediate eviction upon reaching MaxRetries.
>
> — line 147 (near `UpdateRetransTableNonFatal`)

### `core_4.18.5` — Message Counter Synchronization Exchange

- TLC outcome: **unhandled_input**
- ranker score: 48.36

> what happens if a node is already actively syncing with another peer when a new TriggerSync arrives?
>
> — line 113 (near `HandleTriggerSync`)

### `core_4.12.5.2` — Reliable Message Processing of Incoming Messages

- TLC outcome: **runtime_error**
- ranker score: 47.63

> spec notes "If there is no match, it indicates that this is either a duplicate acknowledgment or the Exchange context does not exist" but assigns no action. Modeled as leaving table unchanged.
>
> — line 148 (near `HandleReceiveMessage`)

### `core_4.20.3.7` — Receive Windows

- TLC outcome: **unhandled_input**
- ranker score: 47.51

> spec mentions "payload ... will be permanently lost" if host does not have space,
>
> — line 84 (near `HandleReceivePAFTPPacket`)

> spec says to increment the counter, but does not specify behavior if
>
> — line 96 (near `HandleReceivePAFTPAck`)

### `core_4.3.1.11` — TXT key for pairing hint (PH)

- TLC outcome: **timeout**
- ranker score: 44.85

> how to handle an attempt to set an invalid PH configuration
>
> — line 154 (near `Action_SetPairingHint`)

> whether PH is included when CM=0 and Extended Discovery is disabled.
>
> — line 168 (near `Action_UpdateAdvertisement`)

### `core_4.6.7` — Counter Processing of Incoming Messages

- TLC outcome: **runtime_error**
- ranker score: 37.0

> what to do if a decrypted unicast message arrives but there is no session-specific state
>
> — line 101 (near `ProcessIncomingMessage`)

> section 4.6.7 Step 3 does not explicitly define the action for unencrypted duplicates
>
> — line 118 (near `ProcessIncomingMessage`)

### `core_4.14.1.2` — Protocol Details

- TLC outcome: **unhandled_input**
- ranker score: 34.62

> Section 4.14.1.2 does not specify state transitions upon receipt of a FAILURE StatusReport, so it is left unhandled here.
>
> — line 213 (near `Next`)

### `core_5.5.1` — Commissioning Flows Error Handling

- TLC outcome: **incomplete_next_state**
- ranker score: 29.77

> Spec says "the commissioner SHALL revert network configuration changes made as part of the preceding unsuccessful configuration attempt". It does not define Commissionee behavior if the Commissioner violates this requirement. We simply record that a configuration is now uncommitted.
>
> — line 94 (near `HandleAttemptNetworkConfig`)

### `core_4.20.3.11` — Protocol State Diagrams

- TLC outcome: **no_error**
- ranker score: 28.83

> The actual states and transitions for the PAFTP session lifecycle
>
> — line 15 (near `Init`)

> The exact state changes or timers updated by keep alive messages
>
> — line 34 (near `HandleKeepAlive`)

> The behavior occurring upon the timeout itself is not detailed
>
> — line 53 (near `HandleTimeout`)

### `core_4.19.4.11` — Protocol State Diagrams

- TLC outcome: **unhandled_input**
- ranker score: 27.69

> exact state updates or replies for liveliness enforcement are in the figure, not the text.
>
> — line 50 (near `HandleReceiveKeepAlive`)

### `core_4.6.5.1` — Message Reception State

- TLC outcome: **no_error**
- ranker score: 27.22

> spec uses "logically greater" without defining the exact threshold
>
> — line 22 (near `LogicallyGreater`)

> Spec implies duplicates and out-of-window old messages are ignored.
>
> — line 77 (near `HandleReceiveMessage`)

### `core_4.12.6.1` — Retransmission Table

- TLC outcome: **unhandled_input**
- ranker score: 26.4

> spec does not explicitly state if the record is removed upon failure notification, assuming removed here.
>
> — line 79 (near `SendReliableMessage`)

### `core_4.21.4.2` — TRANSPORT command

- TLC outcome: **unhandled_input**
- ranker score: 24.68

> the spec text does not state what SW1/SW2 to return for intermediate C-APDU fragments
>
> — line 83 (near `Handle_TRANSPORT_Command_APDU`)

### `core_4.20.3.5` — Message Segmentation and Reassembly

- TLC outcome: **unhandled_input**
- ranker score: 23.64

> The spec lists an error for receiving an Ending Segment without a previous Beginning Segment, but does not specify the behavior (or error) for receiving a middle segment (Beginning = FALSE, Ending = FALSE) while in the IDLE state.
>
> — line 142 (near `HandleReceiveSegment`)

> Spec says to reassemble in ascending order but does not specify the explicit failure behavior (e.g., buffer, drop, or close session) when segments arrive out of order or are missing.
>
> — line 143 (near `HandleReceiveSegment`)

### `core_4.18.2` — Group Peer State

- TLC outcome: **no_error**
- ranker score: 22.77

> The spec identifies scenarios where the counter is unknown but leaves the handling to the subsequent synchronization protocol sections.
>
> — line 103 (near `ReceiveEncryptedMessage`)

### `core_4.12.1` — Reliable Messaging Header Fields

- TLC outcome: **no_error**
- ranker score: 22.59

> requested to send standalone ack but no valid message counter provided
>
> — line 61 (near `ConstructMessage`)

> message received with A Flag set but Acknowledged Message Counter missing
>
> — line 84 (near `ReceiveMessage`)

> Standalone Ack received without A Flag set
>
> — line 87 (near `ReceiveMessage`)

### `core_4.20.3.3` — Session Establishment

- TLC outcome: **unhandled_input**
- ranker score: 22.17

> how the application error report is modeled is abstracted here.
>
> — line 143 (near `CommissionerHandshakeTimeout`)

### `core_4.8.2` — Security Processing of Outgoing Messages

- TLC outcome: **timeout**
- ranker score: 21.61

> exact derivation of 16-bit Group ID from Destination Node ID is abstracted.
>
> — line 40 (near `DeriveGroupId`)

> Nonce construction per Table 17 is abstracted, AEAD logic combined into basic success/fail mapping.
>
> — line 111 (near `ProcessOutgoingMessage`)

> spec text 4.6.6 cuts off regarding Encryption Key expiration on wrap-around, omitting expiration
>
> — line 127 (near `ProcessOutgoingMessage`)

### `core_4.7.2` — Message Reception

- TLC outcome: **unhandled_input**
- ranker score: 20.92

> 4.7.2 does not explicitly state what happens if decrypt/auth fails for ONE key in a group message, or if ALL fail.
>
> — line 116 (near `SecurityProcessing_Loop`)

### `core_4.8.3` — Security Processing of Incoming Messages

- TLC outcome: **no_error**
- ranker score: 20.63

> detailed byte-level construction is abstracted.
>
> — line 71 (near `ConstructNonce`)

> exact cryptographic operations are abstracted away.
>
> — line 76 (near `Crypto_AEAD_DecryptVerify`)


## Not checkable

These modules parsed (SANY passed) but TLC could not reach a verdict. They are **not** evidence of a clean spec.

| unit | outcome | why |
|---|---|---|
| `core_4.12.5.2` | runtime_error | TLC evaluation error inside the model |
| `core_4.3.1.11` | timeout | state space too large to finish within the time budget |
| `core_4.6.7` | runtime_error | TLC evaluation error inside the model |
| `core_5.5.1` | incomplete_next_state | an action leaves a variable neither assigned nor UNCHANGED (`inputBreadcrumb`) |
| `core_4.8.2` | timeout | state space too large to finish within the time budget |

## Checked, nothing found

TLC explored these models completely and found no deadlock. How much that is worth depends on how much the model actually does — a model with a handful of states cannot deadlock no matter how incomplete the spec is, so the small ones are **not** evidence of a complete spec.

| unit | states | depth | meaningful? | title |
|---|---|---|---|---|
| `core_4.8.3` | 50193 | 4 | yes | Security Processing of Incoming Messages |
| `core_4.6.5` | 2304 | 18 | yes | Replay Prevention and Duplicate Message Detection |
| `core_4.12.1` | 864 | 4 | yes | Reliable Messaging Header Fields |
| `core_4.18.2` | 129 | 3 | yes | Group Peer State |
| `core_4.6.5.1` | 20 | 7 | yes | Message Reception State |
| `core_4.21.4.3` | 10 | 4 | ⚠️ too small to conclude | GET RESPONSE command |
| `core_4.20.3.11` | 8 | 4 | ⚠️ too small to conclude | Protocol State Diagrams |
| `core_4.12.7.1` | 4 | 4 | ⚠️ too small to conclude | MRP Standalone Acknowledgement |
| `core_4.18.3.2` | 4 | 4 | ⚠️ too small to conclude | MsgCounterSyncRsp - Message Counter Synchronization Response |
