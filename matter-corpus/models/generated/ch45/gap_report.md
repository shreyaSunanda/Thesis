# TLC candidate-gap report

Source log: `models/generated/ch45/tlc_results.jsonl`

Candidate gaps are ordered by **how many steps it took to reach the deadlock**, not by ranker score. A deadlock at state 1 means the model's *initial* state had nothing enabled — almost always an under-constrained `Init` rather than a specification gap — whereas a deadlock reached after several transitions means the model made real progress and then ran out of defined behavior. Those are the ones worth reading.

A **deadlock** is a reachable state in which no action of `Next` is enabled: the model reached a situation and the spec text supplied no transition out of it. That is a *candidate* specification gap, not a proven one — it can equally mean the generated model is wrong, or that the state is a legitimate terminal state. Each one below needs manual review against the section's own text.

## Summary

| outcome | units |
|---|---|
| candidate gaps (deadlock) | 14 → **11** after triage (8 of those reached after real progress) |
| invariant violated | 0 |
| checked, nothing found | 11 (of which 5 explored too little to mean anything) |
| **not checkable** (see below) | **15** |
| total | 40 |

22 of 40 modules were actually model-checked. The rest produced no verdict either way.

## Candidate gaps

### Ruled out by corpus triage

These deadlocked on a teardown/close/timeout action, and the corpus itself explains why — so they are not candidate gaps. See `triage_gap()` for the rule.

| unit | class | why |
|---|---|---|
| `core_4.12.5.1` | modelling_defect | the section's own text describes recovery ("retry") but the model has no action for it |
| `core_4.14.2.3` | modelling_defect | the section's own text describes recovery ("Resume") but the model has no action for it |
| `core_4.19.4.8` | modelling_defect | the section's own text describes recovery ("restart") but the model has no action for it |

### Remaining candidates

### `core_4.19.4.3` — Session Establishment

- steps to deadlock: 12
- ranker score: 33.81
- module: `core_4_19_4_3.tla`
- constants (inferred kind): `BTP_CONN_RSP_TIMEOUT`=numeric, `ClientSupportedVersions`=set, `ServerSupportedVersions`=set, `ClientMaxWindow`=numeric, `ServerMaxWindow`=numeric, `ServerAttMtu`=numeric, `ClientAttMtuKnown`=boolean, `ActualClientAttMtu`=opaque

**Deadlock under ClientAttMtuKnown=True** after 12 state(s) (65 distinct states explored):

Last action to fire: **`ClientHandleTimerExpiry`** (line 229 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.19.4.3 Session Establishment
```
State it got stuck in:

```
State 12: <ClientHandleTimerExpiry line 229, col 5 to line 236, col 102 of module core_4_19_4_3>
/\ btp_server_state = "Closed"
/\ server_c2_subscription = TRUE
/\ btp_client_state = "Closed"
/\ client_reported_error = TRUE
/\ msg_handshake_req = FALSE
/\ msg_handshake_ack = FALSE
/\ session_window_size = 0
/\ msg_handshake_rsp = FALSE
/\ dple_state = "Performed"
/\ session_segment_size = 0
/\ gatt_client_state = "DescriptorsDiscovered"
/\ session_version = 0
/\ server_reported_error = FALSE
/\ client_timer = "Expired"
/\ ble_state = "Closed"
/\ server_timer = "Inactive"
```

**Deadlock under ClientAttMtuKnown=False** after 11 state(s) (65 distinct states explored):

Last action to fire: **`ServerCloseBLEOnVersionMismatch`** (line 184 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.19.4.3 Session Establishment
```
State it got stuck in:

```
State 11: <ServerCloseBLEOnVersionMismatch line 184, col 5 to line 193, col 79 of module core_4_19_4_3>
/\ btp_server_state = "Closed"
/\ server_c2_subscription = FALSE
/\ btp_client_state = "Closed"
/\ client_reported_error = TRUE
/\ msg_handshake_req = FALSE
/\ msg_handshake_ack = TRUE
/\ session_window_size = 0
/\ msg_handshake_rsp = FALSE
/\ dple_state = "Performed"
/\ session_segment_size = 0
/\ gatt_client_state = "DescriptorsDiscovered"
/\ session_version = 0
/\ server_reported_error = FALSE
/\ client_timer = "Expired"
/\ ble_state = "Closed"
/\ server_timer = "Inactive"
```

### `core_4.14.1.2` — Protocol Details

- steps to deadlock: 4
- ranker score: 34.62
- module: `core_4_14_1_2.tla`
- constants (inferred kind): `InitiatorSessionIds`=set, `ResponderSessionIds`=set, `Null`=sentinel

**Deadlock under no capability flags** after 4 state(s) (74 distinct states explored):

Last action to fire: **`Receive_Failure_StatusReport_Initiator`** (line 243 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.14.1.2 Protocol Details
```
State it got stuck in:

```
State 4: <Receive_Failure_StatusReport_Initiator line 243, col 5 to line 252, col 25 of module core_4_14_1_2>
/\ network = {[type |-> "PBKDFParamRequest", sessionId |-> 0, sessionType |-> 0, sFlag |-> 1, dsiz |-> 0, protocolId |-> "SECURE_CHANNEL", initiatorRandom |-> "iRand", responderRandom |-> Null, initiatorSessionId |-> InitiatorSessionIds_1, responderSessionId |-> Null, passcodeId |-> 1, hasPBKDFParameters |-> FALSE, pbkdf_parameters |-> Null, pA |-> Null, pB |-> Null, cB |-> Null, cA |-> Null, generalCode |-> Null, protocolCode |-> Null], [type |-> "StatusReport", sessionId |-> 0, sessionType |-> 0, sFlag |-> 0, dsiz |-> 1, protocolId |-> "SECURE_CHANNEL", initiatorRandom |-> Null, responderRandom |-> Null, initiatorSessionId |-> Null, responderSessionId |-> Null, passcodeId |-> Null, hasPBKDFParameters |-> Null, pbkdf_parameters |-> Null, pA |-> Null, pB |-> Null, cB |-> Null, cA |-> Null, generalCode |-> "FAILURE", protocolCode |-> "INVALID_PARAMETER"]}
/\ rState = "FAILED"
/\ rCtx = [ sessionTimestamp |-> 0,
  txKey |-> Null,
  rxKey |-> Null,
  attestationChallenge |-> Null,
  localMessageCounter |-> 0,
  peerMaxMessageCounter |-> 0,
  localSessionId |-> 0,
  peerSessionId |-> 0 ]
/\ iState = "FAILED"
/\ iCtx = [sessionTimestamp |-> 0, txKey |-> Null, rxKey |-> Null, attestationChallenge |-> Null, localMessageCounter |-> 0, peerMaxMessageCounter |-> 0, localSessionId |-> InitiatorSessionIds_1, peerSessionId |-> 0]
```

### `core_4.20.3.6` — Sequence Numbers

- steps to deadlock: 4
- ranker score: 26.8
- module: `core_4_20_3_6.tla`

**Deadlock under no capability flags** after 4 state(s) (87 distinct states explored):

Last action to fire: **`CommissionerReceives`** (line 51 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.20.3.6 Sequence Numbers
\* "Peers SHALL check to ensure that all received PAFTP packets properly increment the sender’s previous sequence number by 1. If this check fails, the peer SHALL close the PAFTP session and report an error to the application."
```
State it got stuck in:

```
State 4: <CommissionerReceives line 51, col 5 to line 63, col 55 of module core_4_20_3_6>
/\ applicationError = "CommissionerError"
/\ packets = {[seq |-> 1, sender |-> "Device"]}
/\ cExpectedRxSeq = 1
/\ sessionState = "Closed"
/\ dExpectedRxSeq = 0
/\ dTxSeq = 3
/\ cTxSeq = 0
```

### `core_4.23.3.1` — Advertisement from Commissionee

- steps to deadlock: 4
- ranker score: 22.74
- module: `core_4_23_3_1.tla`
- constants (inferred kind): `INITIAL_WAIT_MS`=numeric, `RETRANSMIT_WAIT_MS`=numeric, `MAX_RETRANSMITS`=numeric, `JoinerRouterPortMJ`=opaque, `NoneMessage`=sentinel

**Deadlock under no capability flags** after 4 state(s) (4019 distinct states explored):

Last action to fire: **`EstablishCommissioningSession`** (line 93 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.23.3.1 incoming commissioning message (see Section 4.14.1, “Passcode-Authenticated Session Establishment (PASE)”)
```
State it got stuck in:

```
State 4: <EstablishCommissioningSession line 93, col 5 to line 95, col 68 of module core_4_23_3_1>
/\ state = "COMMISSIONING_ESTABLISHED"
/\ timePassedMs = 4
/\ retransmitCount = 0
/\ networkMessage = [ type |-> "DNS_Announcement",
  transactionId |-> 0,
  containsCommissionableNodeDiscoveryInfo |-> TRUE,
  destinationAddress |-> "LinkLocal",
  destinationPort |-> JoinerRouterPortMJ ]
```

### `core_4.19.4.11` — Protocol State Diagrams

- steps to deadlock: 3
- ranker score: 27.69
- module: `core_4_19_4_11.tla`
- constants (inferred kind): `RoleClient`=opaque, `RoleServer`=opaque, `StateEstablished`=opaque, `StateTornDown`=opaque

**Deadlock under no capability flags** after 3 state(s) (10 distinct states explored):

Last action to fire: **`AutomaticTeardown`** (line 63 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.19.4.11 Protocol State Diagrams
```
State it got stuck in:

```
State 3: <AutomaticTeardown line 63, col 5 to line 67, col 55 of module core_4_19_4_11>
/\ timeoutOccurred = FALSE
/\ ackReceived = TRUE
/\ sessionState = StateTornDown
/\ role = RoleClient
```

### `core_4.20.3.11` — Protocol State Diagrams

- steps to deadlock: 2
- ranker score: 28.83
- module: `core_4_20_3_11.tla`

**Deadlock under no capability flags** after 2 state(s) (10 distinct states explored):

Last action to fire: **`Teardown`** (line 28 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.20.3.11 Protocol State Diagrams
\* "automatic teardown if acknowledgements are received before the timeout"
```
State it got stuck in:

```
State 2: <Teardown line 28, col 5 to line 32, col 58 of module core_4_20_3_11>
/\ state = "Teardown"
/\ ackReceived = TRUE
/\ messages = {}
/\ timeoutExpired = FALSE
```

### `core_4.8.2` — Security Processing of Outgoing Messages

- steps to deadlock: 2
- ranker score: 21.61
- module: `core_4_8_2.tla`
- constants (inferred kind): `NullKey`=sentinel, `UnicastSessionType`=opaque, `GroupSessionType`=opaque, `CryptoError`=opaque, `MyOperationalNodeId`=opaque, `Omitted`=opaque

**Deadlock under no capability flags** after 2 state(s) (2 distinct states explored):

Last action to fire: **`Step1_ObtainKey`** (line 81 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.8.2 1
```
State it got stuck in:

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

### `core_4.10.5.3` — Closing an Exchange

- steps to deadlock: 2
- ranker score: 21.03
- module: `core_4_10_5_3.tla`
- constants (inferred kind): `AckIds`=set, `RetransmissionIds`=set

**Deadlock under no capability flags** after 2 state(s) (80 distinct states explored):

Last action to fire: **`InitiateClose`** (line 29 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.10.5.3
```
State it got stuck in:

```
State 2: <InitiateClose line 29, col 5 to line 48, col 36 of module core_4_10_5_3>
/\ exchangeState = "CLOSED"
/\ closePending = FALSE
/\ pendingAcks = {}
/\ sentMessages = {[id |-> AckIds_1, type |-> "StandaloneAck"]}
/\ retransmissions = {}
```

### `core_5.5` — Commissioning Flows  ⚠️ initial-state deadlock

> The deadlock is the **initial state itself** — no action was ever enabled. This almost always means `Init` leaves a variable free over a value no action accepts, i.e. a modelling defect, not a spec gap. Treat as low priority.

- steps to deadlock: 1
- ranker score: 111.9
- module: `core_5_5.tla`
- constants (inferred kind): `ConcurrentConnectionSupported`=boolean, `NFCCommissioningSupported`=boolean

**Deadlock under ConcurrentConnectionSupported=True, NFCCommissioningSupported=True** after 1 state(s) (63 distinct states explored):

State it got stuck in:

```
State 1: <Initial predicate>
/\ paseSessionStatus = "None"
/\ isCommissioningWithoutPower = FALSE
/\ cumulativeContextTimerPaused = FALSE
/\ initialStep = 0
/\ commissioningWindowOpen = FALSE
/\ commissioningPhase = "None"
/\ commChannelState = "Closed"
/\ setupStep = 0
/\ failsafeStatus = "Disarmed"
```

**Deadlock under ConcurrentConnectionSupported=True, NFCCommissioningSupported=False** after 1 state(s) (75 distinct states explored):

State it got stuck in:

```
State 1: <Initial predicate>
/\ paseSessionStatus = "None"
/\ isCommissioningWithoutPower = FALSE
/\ cumulativeContextTimerPaused = FALSE
/\ initialStep = 0
/\ commissioningWindowOpen = FALSE
/\ commissioningPhase = "None"
/\ commChannelState = "Closed"
/\ setupStep = 0
/\ failsafeStatus = "Disarmed"
```

**Deadlock under ConcurrentConnectionSupported=False, NFCCommissioningSupported=True** after 1 state(s) (54 distinct states explored):

State it got stuck in:

```
State 1: <Initial predicate>
/\ paseSessionStatus = "None"
/\ isCommissioningWithoutPower = FALSE
/\ cumulativeContextTimerPaused = FALSE
/\ initialStep = 0
/\ commissioningWindowOpen = FALSE
/\ commissioningPhase = "None"
/\ commChannelState = "Closed"
/\ setupStep = 0
/\ failsafeStatus = "Disarmed"
```

**Deadlock under ConcurrentConnectionSupported=False, NFCCommissioningSupported=False** after 1 state(s) (55 distinct states explored):

State it got stuck in:

```
State 1: <Initial predicate>
/\ paseSessionStatus = "None"
/\ isCommissioningWithoutPower = FALSE
/\ cumulativeContextTimerPaused = FALSE
/\ initialStep = 0
/\ commissioningWindowOpen = FALSE
/\ commissioningPhase = "None"
/\ commChannelState = "Closed"
/\ setupStep = 0
/\ failsafeStatus = "Disarmed"
```

### `core_4.6.7` — Counter Processing of Incoming Messages  ⚠️ initial-state deadlock

> The deadlock is the **initial state itself** — no action was ever enabled. This almost always means `Init` leaves a variable free over a value no action accepts, i.e. a modelling defect, not a spec gap. Treat as low priority.

- steps to deadlock: 1
- ranker score: 37.0
- module: `core_4_6_7.tla`
- constants (inferred kind): `Nodes`=set, `NullNode`=sentinel, `WindowSize`=numeric, `MaxCounter`=numeric

**Deadlock under no capability flags** after 1 state(s) (1 distinct states explored):

State it got stuck in:

```
State 1: <Initial predicate>
/\ unicastStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ reliableMessages = {}
/\ groupDataStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ unsecuredStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ droppedMessages = {}
/\ incomingMessages = {}
/\ groupCtrlStates = (Nodes_1 :> "Null" @@ Nodes_2 :> "Null" @@ NullNode :> "Null")
/\ unsyncMessages = {}
/\ acceptedMessages = {}
```

### `core_4.18.3.2` — MsgCounterSyncRsp - Message Counter Synchronization Response  ⚠️ initial-state deadlock

> The deadlock is the **initial state itself** — no action was ever enabled. This almost always means `Init` leaves a variable free over a value no action accepts, i.e. a modelling defect, not a spec gap. Treat as low priority.

- steps to deadlock: 1
- ranker score: 22.22
- module: `core_4_18_3_2.tla`
- constants (inferred kind): `Nodes`=set

**Deadlock under no capability flags** after 1 state(s) (1 distinct states explored):

State it got stuck in:

```
State 1: <Initial predicate>
/\ network = {}
/\ dataMessageCounter = (Nodes_1 :> 0 @@ Nodes_2 :> 0)
```

## Not checkable

These modules parsed (SANY passed) but TLC could not reach a verdict. They are **not** evidence of a clean spec.

| unit | outcome | why |
|---|---|---|
| `core_4.20.3.8` | runtime_error | TLC evaluation error inside the model |
| `core_4.12.2.1` | timeout | state space too large to finish within the time budget |
| `core_4.18.5` | timeout | state space too large to finish within the time budget |
| `core_4.12.5.2` | timeout | state space too large to finish within the time budget |
| `core_4.20.3.7` | timeout | state space too large to finish within the time budget |
| `core_4.19.4.7` | config_error | module applies CONSTANT(s) MaxWindowSize[...] as a function, but declares them as plain constants - the harness cannot infer the domain; the model should declare them as a function-valued constant or index a VARIABLE instead |
| `core_4.3.1.11` | timeout | state space too large to finish within the time budget |
| `core_4.12.2.2` | timeout | state space too large to finish within the time budget |
| `core_5.9.3` | timeout | state space too large to finish within the time budget |
| `core_4.17.3.5` | unbounded_quantifier | model quantifies over an infinite set - needs explicit bounds |
| `core_4.21.4.2` | timeout | state space too large to finish within the time budget |
| `core_4.20.3.5` | timeout | state space too large to finish within the time budget |
| `core_4.19.4.5` | runtime_error | TLC evaluation error inside the model |
| `core_4.7.2` | unbounded_quantifier | model quantifies over an infinite set - needs explicit bounds |
| `core_4.8.3` | config_error | module applies CONSTANT(s) MockDecryptVerify[...] as a function, but declares them as plain constants - the harness cannot infer the domain; the model should declare them as a function-valued constant or index a VARIABLE instead |

## Checked, nothing found

TLC explored these models completely and found no deadlock. How much that is worth depends on how much the model actually does — a model with a handful of states cannot deadlock no matter how incomplete the spec is, so the small ones are **not** evidence of a complete spec.

| unit | states | depth | meaningful? | title |
|---|---|---|---|---|
| `core_4.12.1` | 203593 | 39 | yes | Reliable Messaging Header Fields |
| `core_4.19.4.6` | 196609 | 1023 | yes | Sequence Numbers |
| `core_4.12.6.1` | 38416 | 29 | yes | Retransmission Table |
| `core_5.5.1` | 7584 | 23 | yes | Commissioning Flows Error Handling |
| `core_4.12.6.2` | 256 | 13 | yes | Acknowledgement Table |
| `core_4.6.5` | 80 | 10 | yes | Replay Prevention and Duplicate Message Detection |
| `core_4.20.3.3` | 17 | 9 | ⚠️ too small to conclude | Session Establishment |
| `core_4.6.5.1` | 16 | 5 | ⚠️ too small to conclude | Message Reception State |
| `core_4.21.4.3` | 11 | 3 | ⚠️ too small to conclude | GET RESPONSE command |
| `core_4.12.7.1` | 4 | 3 | ⚠️ too small to conclude | MRP Standalone Acknowledgement |
| `core_4.18.2` | 1 | 1 | ⚠️ too small to conclude | Group Peer State |
