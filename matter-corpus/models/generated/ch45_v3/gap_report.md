# TLC candidate-gap report

Source log: `models/generated/ch45_v3/tlc_results.jsonl`

Candidate gaps are ordered by **how many steps it took to reach the unhandled input**, not by ranker score: the further the model got before hitting one, the more confidence that the model works and the spec is what ran out.

An **unhandled input** is a reachable state in which an event is waiting and no action of `Next` can consume it: something arrived that the spec text defines no handling for. Unlike a plain deadlock this does **not** fire when a protocol simply ends — "SHALL close the session", "perform no further processing" and the like leave nothing pending, so they are vacuously fine. It is still a *candidate* gap: the generated model may have omitted a handler the spec does describe. Each one needs review against the section's own text.

## Summary

| outcome | units |
|---|---|
| candidate gaps (unhandled input) | 27 → **26** after triage (6 of those reached after real progress) |
| &nbsp;&nbsp;of which in an operational state | **0** |
| &nbsp;&nbsp;of which setup-only (lower priority) | 0 |
| &nbsp;&nbsp;of which unranked (no rule 4b) | 26 |
| invariant violated | 0 |
| checked, nothing found | 12 (of which 4 explored too little to mean anything) |
| **not checkable** (see below) | **1** |
| model-asserted unspecified cases (unverified) | 42 note(s) in 21 unit(s) |
| total | 40 |

38 of 40 modules were actually model-checked. The rest produced no verdict either way.

## Candidate gaps

### Ruled out by corpus triage

These deadlocked on a teardown/close/timeout action, and the corpus itself explains why — so they are not candidate gaps. See `triage_gap()` for the rule.

| unit | class | why |
|---|---|---|
| `core_5.5.1` | modelling_defect | the section's own text describes recovery ("restart") but the model has no action for it<br>matched sentence: *"Commissioners that need to restart from initial phase step 2 MAY immediately expire the fail-safe by invoking the ArmFailSafe command with an ExpiryLengthSeconds field set to 0."* |

### Remaining candidates

### `core_4.20.3.11` — Protocol State Diagrams

- steps to the unhandled input: 4
- ranker score: 28.83
- module: `core_4_20_3_11.tla`
- constants (inferred kind): `NoInput`=sentinel

**Unhandled input under no capability flags** after 4 state(s) (6 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 19 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 19, col 5 to line 22, col 26 of module core_4_20_3_11>
/\ state = "Teardown"
/\ pendingInput = "KeepAlive"
```

### `core_4.7.2` — Message Reception

- steps to the unhandled input: 4
- ranker score: 20.92
- module: `core_4_7_2.tla`
- constants (inferred kind): `SessionIDs`=set, `Keys`=set, `NullMessage`=sentinel, `MaxTime`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 4 state(s) (14383 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 62 of the module)

State in which the input went unhandled:

```
State 4: <ReceiveInput line 62, col 5 to line 65, col 132 of module core_4_7_2>
/\ state = "CheckSecurity"
/\ now = 0
/\ sessionTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ sessionKeys = (SessionIDs_1 :> {} @@ SessionIDs_2 :> {})
/\ deliveredMessage = NullMessage
/\ nextHigherLayer = "None"
/\ currentMessage = [version |-> 0, sessionType |-> "SecureUnicast", dsizGroupPresent |-> FALSE, dsizZero |-> FALSE, sFlagZero |-> FALSE, sessionId |-> SessionIDs_1, pFlag |-> FALSE, transport |-> "UDP", isUnicast |-> FALSE]
/\ activeTimestamps = (SessionIDs_1 :> 0 @@ SessionIDs_2 :> 0)
/\ pendingInput = "ReceiveMessage"
```

### `core_4.20.3.8` — Packet Acknowledgements

- steps to the unhandled input: 2
- ranker score: 127.15
- module: `core_4_20_3_8.tla`
- constants (inferred kind): `NoSeqNum`=numeric, `MaxSeqNum`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (24 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 54 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 54, col 5 to line 65, col 54 of module core_4_20_3_8>
/\ mostRecentSentSeqNum = 3
/\ unackedSentMsgs = {}
/\ receivedUnackedSeqs = {}
/\ sessionState = "Open"
/\ ackReceivedTimer = "Stopped"
/\ pendingAckValue = 3
/\ sendAckTimer = "Stopped"
/\ inPacketSeqNum = 3
/\ nextOutSeqNum = 1
/\ largestReceivedUnackedSeqNum = 3
/\ pendingInput = "SendStandaloneAck"
/\ inAckSeqNum = 3
```

### `core_4.14.2.3` — Protocol Details

- steps to the unhandled input: 2
- ranker score: 81.1
- module: `core_4_14_2_3.tla`
- constants (inferred kind): `NoInput`=sentinel, `NotSet`=set, `Ids`=set, `MaxClock`=numeric

**Unhandled input under no capability flags** after 2 state(s) (80 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 72 of the module)

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

### `core_4.12.2.1` — Retransmissions

- steps to the unhandled input: 2
- ranker score: 54.01
- module: `core_4_12_2_1.tla`
- constants (inferred kind): `ExchangeIds`=set, `PeerIds`=set, `NullExchange`=sentinel, `NullPeer`=sentinel, `MaxInterval`=numeric, `MRP_MAX_TRANSMISSIONS`=numeric, `MRP_BACKOFF_MARGIN`=numeric, `MRP_BACKOFF_BASE`=numeric, `MRP_BACKOFF_THRESHOLD`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (1026 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 107 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 107, col 5 to line 112, col 85 of module core_4_12_2_1>
/\ sessionContexts = (PeerIds_1 :> [isICD |-> FALSE, PeerActiveMode |-> FALSE, SESSION_ACTIVE_INTERVAL |-> 0, SESSION_IDLE_INTERVAL |-> 0, fastPollingInterval |-> 0] @@ PeerIds_2 :> [isICD |-> FALSE, PeerActiveMode |-> FALSE, SESSION_ACTIVE_INTERVAL |-> 0, SESSION_IDLE_INTERVAL |-> 0, fastPollingInterval |-> 0])
/\ inputData = [exchangeId |-> ExchangeIds_1, peerId |-> NullPeer, isFirstMsg |-> FALSE, activeMode |-> FALSE, activeInt |-> 0, idleInt |-> 0, isICD |-> FALSE, fastPoll |-> 0]
/\ exchanges = (ExchangeIds_1 :> [peerId |-> NullPeer, state |-> "CLOSED", n |-> 0, isFirstMessage |-> FALSE] @@ ExchangeIds_2 :> [peerId |-> NullPeer, state |-> "CLOSED", n |-> 0, isFirstMessage |-> FALSE])
/\ failedExchanges = {}
/\ pendingInput = "SendReliableMessage"
/\ activeOpDiscoveries = {}
```

### `core_4.12.5.1` — Reliable Message Processing of Outgoing Messages

- steps to the unhandled input: 2
- ranker score: 52.11
- module: `core_4_12_5_1.tla`
- 🔴 **declared but handled nowhere**: `ReceiveAck`, `ReceiveMessageRequiringAck` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `MaxRetries`=numeric, `MessageIds`=set, `NodeIds`=set, `ExchangeIds`=set, `SessionIds`=set, `SessionCredentials`=set, `SessionTypes`=set, `SecurityFlags`=set, `MessageCounters`=set, `Transports`=set, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 38 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 38, col 5 to line 41, col 93 of module core_4_12_5_1>
/\ pendingTransport = {}
/\ ackTable = {}
/\ activeTimers = {}
/\ appNotifications = {}
/\ pendingInput = "TransportSendResult"
/\ retransTable = {}
```

### `core_4.12.5.2` — Reliable Message Processing of Incoming Messages

- steps to the unhandled input: 2
- ranker score: 47.63
- module: `core_4_12_5_2.tla`
- constants (inferred kind): `NoInput`=sentinel, `ExchangeIds`=set, `MaxMsgCounter`=numeric

**Unhandled input under no capability flags** after 2 state(s) (131074 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 59 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 59, col 5 to line 62, col 295 of module core_4_12_5_2>
/\ closedExchanges = {}
/\ inMsg_msgCounter = 0
/\ ackTable = (ExchangeIds_1 :> [hasEntry |-> FALSE, msgCounter |-> 0, standaloneAckSent |-> FALSE] @@ ExchangeIds_2 :> [hasEntry |-> FALSE, msgCounter |-> 0, standaloneAckSent |-> FALSE])
/\ retransmissionTable = {}
/\ inMsg_aFlag = FALSE
/\ inMsg_groupSession = FALSE
/\ ephemeralExchanges = {}
/\ inMsg_exchangeId = ExchangeIds_1
/\ inMsg_ackMsgCounter = 0
/\ inMsg_isDuplicate = FALSE
/\ inMsg_rFlag = FALSE
/\ sentMessages = {}
/\ inMsg_cFlag = FALSE
/\ inEvent_exchangeId = ExchangeIds_1
/\ deliveredToNextLayer = {}
/\ pendingInput = "AckTimerTriggered"
/\ ackTimerRunning = (ExchangeIds_1 :> FALSE @@ ExchangeIds_2 :> FALSE)
```

### `core_4.20.3.7` — Receive Windows

- steps to the unhandled input: 2
- ranker score: 47.51
- module: `core_4_20_3_7.tla`
- 🔴 **declared but handled nowhere**: `AppQueueTxCommissioner`, `AppQueueTxDevice`, `ReceivePacketCommissioner`, `ReceivePacketDevice`, `ReceiveAckCommissioner`, `ReceiveAckDevice` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `NegotiatedMaxWindow`=numeric, `MaxPendingTx`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 42 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 42, col 5 to line 45, col 78 of module core_4_20_3_7>
/\ remoteWin = [Commissioner |-> 0, Device |-> 0]
/\ pendingAck = [Commissioner |-> FALSE, Device |-> FALSE]
/\ unackedRx = [Commissioner |-> 0, Device |-> 0]
/\ sessionState = "UNINITIALIZED"
/\ pendingTx = [Commissioner |-> 0, Device |-> 0]
/\ pendingInput = "AppQueueTxCommissioner"
```

### `core_4.19.4.7` — Receive Windows

- steps to the unhandled input: 2
- ranker score: 45.97
- module: `core_4_19_4_7.tla`
- constants (inferred kind): `MaxWindowSupported`=numeric, `DefaultNegotiatedWindow`=numeric, `MaxQueue`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (4 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 39 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 39, col 5 to line 42, col 122 of module core_4_19_4_7>
/\ negotiatedMaxWindow = 0
/\ role = "None"
/\ remoteWindowCounter = 0
/\ ownWindowCounter = 0
/\ hasPendingAck = FALSE
/\ pendingTransmissions = 0
/\ pendingInput = "ReceiveGATTPacket"
```

### `core_4.3.1.11` — TXT key for pairing hint (PH)

- steps to the unhandled input: 2
- ranker score: 44.85
- module: `core_4_3_1_11.tla`
- constants (inferred kind): `NoInput`=sentinel, `StandardCommissioningFlow`=boolean, `CustomCommissioningFlow`=boolean

**Unhandled input under StandardCommissioningFlow=True, CustomCommissioningFlow=True** after 2 state(s) (9 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 68 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 68, col 5 to line 71, col 110 of module core_4_3_1_11>
/\ extendedDiscoveryEnabled = FALSE
/\ currentPIPresent = FALSE
/\ cm = 0
/\ deviceState = "FactoryReset"
/\ currentPHBits = {0, 1}
/\ pendingInput = "CommissionerEvaluateHint"
/\ advertisedTXT = [PHPresent |-> FALSE]
```

**Unhandled input under StandardCommissioningFlow=True, CustomCommissioningFlow=False** after 2 state(s) (9 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 68 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 68, col 5 to line 71, col 110 of module core_4_3_1_11>
/\ extendedDiscoveryEnabled = FALSE
/\ currentPIPresent = FALSE
/\ cm = 0
/\ deviceState = "FactoryReset"
/\ currentPHBits = {0}
/\ pendingInput = "CommissionerEvaluateHint"
/\ advertisedTXT = [PHPresent |-> FALSE]
```

**Unhandled input under StandardCommissioningFlow=False, CustomCommissioningFlow=True** after 2 state(s) (9 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 68 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 68, col 5 to line 71, col 110 of module core_4_3_1_11>
/\ extendedDiscoveryEnabled = FALSE
/\ currentPIPresent = FALSE
/\ cm = 0
/\ deviceState = "FactoryReset"
/\ currentPHBits = {1}
/\ pendingInput = "CommissionerEvaluateHint"
/\ advertisedTXT = [PHPresent |-> FALSE]
```

**Unhandled input under StandardCommissioningFlow=False, CustomCommissioningFlow=False** after 2 state(s) (9 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 68 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 68, col 5 to line 71, col 110 of module core_4_3_1_11>
/\ extendedDiscoveryEnabled = FALSE
/\ currentPIPresent = FALSE
/\ cm = 0
/\ deviceState = "FactoryReset"
/\ currentPHBits = {3}
/\ pendingInput = "CommissionerEvaluateHint"
/\ advertisedTXT = [PHPresent |-> FALSE]
```

### `core_4.6.7` — Counter Processing of Incoming Messages

- steps to the unhandled input: 2
- ranker score: 37.0
- module: `core_4_6_7.tla`
- constants (inferred kind): `NodeIds`=set, `NullNodeId`=sentinel, `MaxMsgCounter`=numeric, `WindowSize`=numeric, `MaxOperations`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (25 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 68 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 68, col 5 to line 78, col 146 of module core_4_6_7>
/\ groupUnsync = 0
/\ msgCFlag = 0
/\ stateMaxCounter = ([type |-> "Unicast", peer |-> NodeIds_1] :> 0 @@ [type |-> "Unicast", peer |-> NodeIds_2] :> 0 @@ [type |-> "Unicast", peer |-> NullNodeId] :> 0 @@ [type |-> "GroupData", peer |-> NodeIds_1] :> 0 @@ [type |-> "GroupData", peer |-> NodeIds_2] :> 0 @@ [type |-> "GroupData", peer |-> NullNodeId] :> 0 @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> 0 @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> 0 @@ [type |-> "GroupControl", peer |-> NullNodeId] :> 0 @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> 0 @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> 0 @@ [type |-> "Unsecured", peer |-> NullNodeId] :> 0)
/\ reliableProcessing = 0
/\ follow4_6_5_2 = 0
/\ dropped = 0
/\ follow4_6_5_3 = 0
/\ accepted = 0
/\ msgSource = NodeIds_1
/\ stateExists = ([type |-> "Unicast", peer |-> NodeIds_1] :> FALSE @@ [type |-> "Unicast", peer |-> NodeIds_2] :> FALSE @@ [type |-> "Unicast", peer |-> NullNodeId] :> FALSE @@ [type |-> "GroupData", peer |-> NodeIds_1] :> FALSE @@ [type |-> "GroupData", peer |-> NodeIds_2] :> FALSE @@ [type |-> "GroupData", peer |-> NullNodeId] :> FALSE @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> FALSE @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> FALSE @@ [type |-> "GroupControl", peer |-> NullNodeId] :> FALSE @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> FALSE @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> FALSE @@ [type |-> "Unsecured", peer |-> NullNodeId] :> FALSE)
/\ msgCounter = 0
/\ pendingInput = "ReceiveUnicastMessage"
/\ stateReceived = ([type |-> "Unicast", peer |-> NodeIds_1] :> {} @@ [type |-> "Unicast", peer |-> NodeIds_2] :> {} @@ [type |-> "Unicast", peer |-> NullNodeId] :> {} @@ [type |-> "GroupData", peer |-> NodeIds_1] :> {} @@ [type |-> "GroupData", peer |-> NodeIds_2] :> {} @@ [type |-> "GroupData", peer |-> NullNodeId] :> {} @@ [type |-> "GroupControl", peer |-> NodeIds_1] :> {} @@ [type |-> "GroupControl", peer |-> NodeIds_2] :> {} @@ [type |-> "GroupControl", peer |-> NullNodeId] :> {} @@ [type |-> "Unsecured", peer |-> NodeIds_1] :> {} @@ [type |-> "Unsecured", peer |-> NodeIds_2] :> {} @@ [type |-> "Unsecured", peer |-> NullNodeId] :> {})
```

### `core_4.12.2.2` — Acknowledgements

- steps to the unhandled input: 2
- ranker score: 36.68
- module: `core_4_12_2_2.tla`
- 🔴 **declared but handled nowhere**: `AckTimerExpiry` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `Senders`=set, `MessageCounters`=set, `NullSender`=sentinel, `NoMsgCounter`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (22 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 57 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 57, col 5 to line 77, col 83 of module core_4_12_2_2>
/\ state = "Running"
/\ higherLayerMessages = {}
/\ outMsgDest = NullSender
/\ inMsgCounter = 3
/\ inMsgSender = NullSender
/\ sentAcks = {}
/\ history = (Senders_1 :> {} @@ Senders_2 :> {})
/\ inMsgIsAuthenticated = FALSE
/\ outstandingAcks = (Senders_1 :> {} @@ Senders_2 :> {})
/\ inMsgIsReliable = FALSE
/\ pendingInput = "AckTimerExpiry"
```

### `core_4.14.1.2` — Protocol Details

- steps to the unhandled input: 2
- ranker score: 34.62
- module: `core_4_14_1_2.tla`
- constants (inferred kind): `ValidPasscodeId`=opaque, `InitMsgCounterValue`=numeric, `AbstractSessionIdInitiator`=opaque, `AbstractSessionIdResponder`=opaque, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (98 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 73 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 73, col 5 to line 88, col 51 of module core_4_14_1_2>
/\ responderState = "RESPONDER_IDLE"
/\ initiatorState = "INITIATOR_IDLE"
/\ inMsgSessionId = 1
/\ initiatorSessionTimestampSet = FALSE
/\ inMsgCbValid = FALSE
/\ initiatorPeerMaxMsgCounter = 0
/\ initiatorPeerSessionId = 0
/\ responderPeerMaxMsgCounter = 0
/\ initiatorSessionId = 0
/\ initiatorLocalMsgCounter = 0
/\ responderPeerSessionId = 0
/\ inMsgCaValid = FALSE
/\ initiatorKeysEstablished = FALSE
/\ inMsgPasscodeId = 0
/\ responderIncludedPBKDFParams = FALSE
/\ responderSessionTimestampSet = FALSE
/\ responderSessionId = 0
/\ responderLocalMsgCounter = 0
/\ pendingInput = "PBKDFParamResponse"
/\ inMsgHasPBKDFParameters = FALSE
/\ responderKeysEstablished = FALSE
```

### `core_4.19.4.3` — Session Establishment

- steps to the unhandled input: 2
- ranker score: 33.81
- module: `core_4_19_4_3.tla`
- constants (inferred kind): `BTP_CONN_RSP_TIMEOUT`=numeric, `ClientSupportedVersions`=set, `ServerSupportedVersions`=set, `NullVersion`=sentinel, `ClientWindowSize`=numeric, `ServerWindowSize`=numeric, `ClientATT_MTU`=opaque, `ClientATT_MTU_Known`=boolean, `ServerATT_MTU`=numeric, `NoInput`=sentinel

**Unhandled input under ClientATT_MTU_Known=True** after 2 state(s) (4 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 95 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 95, col 5 to line 101, col 62 of module core_4_19_4_3>
/\ serverRspVersion = NullVersion
/\ clientTimerRunning = FALSE
/\ serverRspWindow = 0
/\ serverRspMTU = 0
/\ clientReqVersions = {}
/\ sessionVersion = NullVersion
/\ sessionWindow = 0
/\ serverTimerRunning = FALSE
/\ sessionMTU = 0
/\ clientReqWindow = 0
/\ pendingInput = "GATT_Exchange_MTU"
/\ serverState = "Init"
/\ clientState = "Init"
/\ clientReqMTU = 0
```

**Unhandled input under ClientATT_MTU_Known=False** after 2 state(s) (4 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 95 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 95, col 5 to line 101, col 62 of module core_4_19_4_3>
/\ serverRspVersion = NullVersion
/\ clientTimerRunning = FALSE
/\ serverRspWindow = 0
/\ serverRspMTU = 0
/\ clientReqVersions = {}
/\ sessionVersion = NullVersion
/\ sessionWindow = 0
/\ serverTimerRunning = FALSE
/\ sessionMTU = 0
/\ clientReqWindow = 0
/\ pendingInput = "GATT_Exchange_MTU"
/\ serverState = "Init"
/\ clientState = "Init"
/\ clientReqMTU = 0
```

### `core_5.9.3` — Network Recovery Flow

- steps to the unhandled input: 2
- ranker score: 27.37
- module: `core_5_9_3.tla`
- constants (inferred kind): `InitialAttemptDuration`=opaque, `FailSafeTimeoutDuration`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (4 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 44 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 44, col 5 to line 47, col 114 of module core_5_9_3>
/\ userConsentStatus = "Unknown"
/\ credentialsStatus = "Existing"
/\ operationalDiscoveryComplete = FALSE
/\ nodeState = "Connected"
/\ pendingInput = "ReconnectSuccess"
/\ failSafeStatus = "Disarmed"
```

### `core_4.19.4.6` — Sequence Numbers

- steps to the unhandled input: 2
- ranker score: 26.95
- module: `core_4_19_4_6.tla`
- constants (inferred kind): `MaxSeqNum`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (2 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 34 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 34, col 5 to line 40, col 63 of module core_4_19_4_6>
/\ state = [Client |-> "Handshake", Server |-> "Handshake"]
/\ inputPeer = "Client"
/\ txSeq = [Client |-> 0, Server |-> 0]
/\ rxExpectedSeq = [Client |-> 0, Server |-> 0]
/\ errorReported = [Client |-> FALSE, Server |-> FALSE]
/\ inputSeq = 0
/\ pendingInput = "SendPacket"
```

### `core_4.20.3.6` — Sequence Numbers

- steps to the unhandled input: 2
- ranker score: 26.8
- module: `core_4_20_3_6.tla`
- constants (inferred kind): `MaxSeqNum`=numeric, `NullSeqNum`=sentinel, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (4 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 29 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 29, col 5 to line 35, col 83 of module core_4_20_3_6>
/\ txSeqNum = 0
/\ sessionState = "Idle"
/\ errorReported = FALSE
/\ inPacketSeqNum = NullSeqNum
/\ localRole = "None"
/\ pendingInput = "SendPacket"
/\ lastRxSeqNum = NullSeqNum
```

### `core_4.17.3.5` — Epoch Key Rotation logic

- steps to the unhandled input: 2
- ranker score: 24.84
- module: `core_4_17_3_5.tla`
- constants (inferred kind): `IPKKeySetId`=opaque, `KeySetIds`=set, `Fabrics`=set, `MaxTime`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (513 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 58 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 58, col 5 to line 66, col 52 of module core_4_17_3_5>
/\ state = "Idle"
/\ groupKeySets = (Fabrics_1 :> (KeySetIds_1 :> {} @@ KeySetIds_2 :> {}) @@ Fabrics_2 :> (KeySetIds_1 :> {} @@ KeySetIds_2 :> {}))
/\ inputKeys = {}
/\ inputKey = 0
/\ systemTime = 0
/\ inputFabric = Fabrics_1
/\ pendingInput = "AdminUpdate"
/\ inputKeySetId = KeySetIds_1
```

### `core_4.21.4.2` — TRANSPORT command

- steps to the unhandled input: 2
- ranker score: 24.68
- module: `core_4_21_4_2.tla`
- 🔴 **declared but handled nowhere**: `GetResponseCommand` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `MaxSupportedMessageSize`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (10 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 39 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 39, col 5 to line 42, col 104 of module core_4_21_4_2>
/\ outData = "None"
/\ state = "Idle"
/\ cmdP1P2 = 10
/\ cmdCLA = "0x80"
/\ responderMessageSize = 10
/\ outSW1 = "None"
/\ outSW2 = 0
/\ cmdLc = 10
/\ cmdLe = 20
/\ pendingInput = "GetResponseCommand"
```

### `core_4.20.3.5` — Message Segmentation and Reassembly

- steps to the unhandled input: 2
- ranker score: 23.64
- module: `core_4_20_3_5.tla`
- constants (inferred kind): `NoInput`=sentinel, `MaxSduSize`=numeric, `MaxPaftpPacketSize`=numeric, `HeaderSize`=numeric, `MaxTxQueueSize`=numeric, `MaxSeqNum`=numeric

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 57 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 57, col 5 to line 60, col 150 of module core_4_20_3_5>
/\ txOffset = 0
/\ txCurrentSdu = 0
/\ rxExpectedLen = 0
/\ inputSegment = [seq |-> 0, begin |-> FALSE, end |-> FALSE, msgLen |-> 0, payload |-> 0]
/\ rxState = "Idle"
/\ txUnacked = 0
/\ rxAccumulated = 0
/\ txQueue = <<>>
/\ pendingInput = "PeerAckSegment"
/\ rxNextSeq = 0
/\ inputSduSize = 0
/\ txState = "Idle"
```

### `core_4.23.3.1` — Advertisement from Commissionee

- steps to the unhandled input: 2
- ranker score: 22.74
- module: `core_4_23_3_1.tla`
- constants (inferred kind): `MaxRetransmissions`=numeric, `InitialWaitMs`=numeric, `RetransmitIntervalMs`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 36 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 36, col 5 to line 39, col 43 of module core_4_23_3_1>
/\ state = "Idle"
/\ retransmitCount = 0
/\ pendingInput = "CommissioningMessageReceived"
```

### `core_4.12.1` — Reliable Messaging Header Fields

- steps to the unhandled input: 2
- ranker score: 22.59
- module: `core_4_12_1.tla`
- 🔴 **declared but handled nowhere**: `ReceiveReliableMessage` — the module lists these as events this section can receive, and no action in it handles them in any state
- constants (inferred kind): `NoInput`=sentinel, `NoCounter`=numeric, `ValidMessageCounter`=numeric

**Unhandled input under no capability flags** after 2 state(s) (6 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 33 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 33, col 5 to line 36, col 31 of module core_4_12_1>
/\ messageOut = [ rFlag |-> FALSE,
  aFlag |-> FALSE,
  ackMsgCounter |-> 3,
  isStandaloneAck |-> FALSE ]
/\ pendingInput = "ReceiveReliableMessage"
```

### `core_4.20.3.3` — Session Establishment

- steps to the unhandled input: 2
- ranker score: 22.17
- module: `core_4_20_3_3.tla`
- constants (inferred kind): `NoInput`=sentinel, `CommissionerSupportedVersions`=set, `CommissionerMaxInfoLength`=numeric, `CommissionerMaxWindowSize`=numeric, `DeviceSupportedVersions`=set, `DeviceMaxInfoLength`=numeric, `DeviceMaxWindowSize`=numeric

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 70 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 70, col 5 to line 77, col 85 of module core_4_20_3_3>
/\ commissionerTimerActive = FALSE
/\ applicationError = FALSE
/\ msgResponseVersion = 0
/\ commissionerSessionVersion = 0
/\ deviceSelectedPacketSize = 0
/\ deviceSelectedVersion = 0
/\ msgResponsePacketSize = 0
/\ deviceSelectedWindowSize = 0
/\ commissionerState = "Idle"
/\ msgResponseWindowSize = 0
/\ commissionerSessionPacketSize = 0
/\ msgRequestVersions = {}
/\ deviceState = "Idle"
/\ commissionerSessionWindowSize = 0
/\ pendingInput = "InitiatePAFTPSession"
/\ msgRequestMaxWindowSize = 0
/\ msgRequestMaxInfoLength = 0
```

### `core_4.19.4.5` — Message Segmentation and Reassembly

- steps to the unhandled input: 2
- ranker score: 21.76
- module: `core_4_19_4_5.tla`
- constants (inferred kind): `MaxBtpPacketSize`=numeric, `HeaderSize`=numeric, `HeaderSizeWithLength`=numeric, `MaxSduSize`=numeric, `MaxQueueSize`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (674 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 65 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 65, col 5 to line 81, col 50 of module core_4_19_4_5>
/\ rxAccumulatedLength = 0
/\ inputSegEnding = FALSE
/\ inputSegPayloadSize = 0
/\ txActiveSduSize = 0
/\ rxExpectedLength = 0
/\ inputSegBeginning = FALSE
/\ sessionState = "Open"
/\ inputSegMsgLength = 0
/\ errorReported = FALSE
/\ rxState = "Idle"
/\ txQueue = <<>>
/\ pendingInput = "ProceedTx"
/\ txSentSize = 0
/\ inputSduSize = 1
```

### `core_4.10.5.3` — Closing an Exchange

- steps to the unhandled input: 2
- ranker score: 21.03
- module: `core_4_10_5_3.tla`
- constants (inferred kind): `ExchangeIds`=set, `MaxRetransmissions`=numeric, `NoInput`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (2597 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 34 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 34, col 5 to line 38, col 88 of module core_4_10_5_3>
/\ retransmissionCounts = (ExchangeIds_1 :> 0 @@ ExchangeIds_2 :> 0)
/\ acknowledgementTable = (ExchangeIds_1 :> "None" @@ ExchangeIds_2 :> "None")
/\ sentMessages = {}
/\ exchanges = (ExchangeIds_1 :> "OPEN" @@ ExchangeIds_2 :> "OPEN")
/\ inputExchangeId = ExchangeIds_1
/\ pendingInput = "RetransmissionComplete"
```

### `core_4.18.5` — Message Counter Synchronization Exchange  ⚠️ reached immediately

> The deadlock is the **initial state itself** — no action was ever enabled. This almost always means `Init` leaves a variable free over a value no action accepts, i.e. a modelling defect, not a spec gap. Treat as low priority.

- steps to the unhandled input: 1
- ranker score: 48.36
- module: `core_4_18_5.tla`
- constants (inferred kind): `MSG_COUNTER_SYNC_REQ_JITTER`=numeric, `MSG_COUNTER_SYNC_TIMEOUT`=numeric, `MaxNodeId`=numeric, `MaxExchangeId`=numeric, `MaxChallenge`=numeric, `MaxSessionId`=numeric, `MaxCounter`=numeric, `MaxTimerId`=numeric, `MyNodeId`=opaque, `NoInput`=sentinel, `NullMsg`=sentinel, `NullTimerId`=sentinel

**Unhandled input under no capability flags** after 1 state(s) (2 distinct states explored):

State in which the input went unhandled:

```
State 1: <Initial predicate>
/\ peerCounterSynchronized = <<FALSE, FALSE, FALSE>>
/\ queuedMsgs = {}
/\ peerReceptionStateCleared = <<FALSE, FALSE, FALSE>>
/\ network = {}
/\ nextExchangeId = 1
/\ nextTimerId = 1
/\ in_msg = NullMsg
/\ activeExchanges = {}
/\ in_timerId = NullTimerId
/\ jitterTimers = {}
/\ syncTimers = {}
/\ pendingInput = NoInput
/\ peerMessageCounters = <<0, 0, 0>>
/\ myGroupDataCounter = 1
/\ in_triggerMsg = NullMsg
```

## Model-asserted unspecified cases

These are **not** TLC findings. While writing each model the generator was told (prompt rule 2) to leave a `\* TODO: unspecified` note rather than invent behaviour wherever the spec text did not say what happens. These are those notes, verbatim.

They are a **separate, unverified signal**. TLC never checked them. Some are genuine omissions, some are modelling limitations (TLA+ has no floating point), and some may simply be the generator misreading the text. Treat each as a lead to check against the section, not as a result.

They are listed for **every generated module**, including those TLC could not reach a verdict on — a module that never compiled can still have flagged a real omission on its way past.

### `core_4.20.3.8` — Packet Acknowledgements

- TLC outcome: **unhandled_input**
- ranker score: 127.15

> abstracting the exact computation of highest contiguous received sequence number
>
> — line 73 (near `DoSendStandaloneAck`)

> abstracting sequence number wrap-around ordering as strictly linear
>
> — line 76 (near `DoSendStandaloneAck`)

> abstracting sequence number wrap-around ordering as strictly linear
>
> — line 94 (near `HandleReceivePacket`)

### `core_4.14.2.3` — Protocol Details

- TLC outcome: **unhandled_input**
- ranker score: 81.1

> what happens if multiple matching sessions exist? The spec assumes single match.
>
> — line 128 (near `HandleReceiveSigma1`)

> what happens if resumption fields are present but no matching session is found?
>
> — line 139 (near `HandleReceiveSigma1`)

### `core_4.12.2.1` — Retransmissions

- TLC outcome: **unhandled_input**
- ranker score: 54.01

> spec is slightly ambiguous if 'set according to idle state' means forcing PeerActiveMode=FALSE
>
> — line 88 (near `GetBaseInterval`)

> exact floating point, exponentiation and randomness for jitter cannot be modeled exactly
>
> — line 100 (near `CalculateMrpBackoffTime`)

### `core_4.18.5` — Message Counter Synchronization Exchange

- TLC outcome: **unhandled_input**
- ranker score: 48.36

> abstracted ordered message processing on resumption as plain removal from queuedMsgs
>
> — line 244 (near `HandleReceiveMsgCounterSyncRsp`)

### `core_4.20.3.7` — Receive Windows

- TLC outcome: **unhandled_input**
- ranker score: 47.51

> spec notes packets are "permanently lost" if the host lacks space,
>
> — line 92 (near `HandleReceivePacket`)

### `core_4.19.4.7` — Receive Windows

- TLC outcome: **unhandled_input**
- ranker score: 45.97

> what happens if a packet arrives when ownWindowCounter is 0?
>
> — line 83 (near `HandleReceiveGATTPacket`)

> what precise threshold determines that the window "is about to close"?
>
> — line 123 (near `SendProactiveAck`)

### `core_4.3.1.11` — TXT key for pairing hint (PH)

- TLC outcome: **unhandled_input**
- ranker score: 44.85

> spec does not explicitly state if PH is forbidden when ED is disabled and CM=0. Assuming FALSE here to represent general absence.
>
> — line 132 (near `AdvertiseTXT`)

### `core_4.6.7` — Counter Processing of Incoming Messages

- TLC outcome: **unhandled_input**
- ranker score: 37.0

> what if Secure Unicast Session Context has no Message Reception State?
>
> — line 83 (near `ProcessUnicastMessage_Duplicate`)

> what if Secure Unicast Session Context has no Message Reception State?
>
> — line 97 (near `ProcessUnicastMessage_Accept`)

### `core_4.12.2.2` — Acknowledgements

- TLC outcome: **unhandled_input**
- ranker score: 36.68

> the section focuses strictly on authenticated messages. Behavior for unauthenticated duplicate checking/acking is left ambiguous here.
>
> — line 120 (near `HandleReceiveUnauthenticated`)

### `core_4.20.3.11` — Protocol State Diagrams

- TLC outcome: **unhandled_input**
- ranker score: 28.83

> the text mentions liveliness enforcement through keep alive messages but omits the exact state logic
>
> — line 28 (near `HandleKeepAlive`)

> text implies timeout plays a role but does not describe explicit timeout behavior
>
> — line 45 (near `HandleTimeout`)

### `core_4.19.4.11` — Protocol State Diagrams

- TLC outcome: **no_error**
- ranker score: 27.69

> specific state machine transitions for BTP Client are in missing Figure 26/27.
>
> — line 32 (near `HandleConfirmedWrite`)

> specific state machine transitions for BTP Server are in missing Figure 27.
>
> — line 40 (near `HandleIndication`)

> specific state machine transitions for keep alive messages are in missing Figure 28.
>
> — line 48 (near `HandleKeepAliveMessage`)

> exact behavior upon timeout is missing from the text (the text only specifies teardown if acks are received BEFORE timeout).
>
> — line 63 (near `HandleTimeout`)

### `core_4.6.5.1` — Message Reception State

- TLC outcome: **no_error**
- ranker score: 27.22

> exact definition of "logically greater" is not provided in this section.
>
> — line 23 (near `IsLogicallyGreater`)

> initial value of message reception state is not explicitly described.
>
> — line 48 (near `Init`)

> The spec text does not state what happens when a message
>
> — line 93 (near `HandleReceiveMessage`)

### `core_4.12.6.1` — Retransmission Table

- TLC outcome: **no_error**
- ranker score: 26.4

> is the record removed after maximum transmissions failure?
>
> — line 78 (near `HandleSendMessage`)

> behavior upon receiving acknowledgment is not explicitly detailed (presumably the record is removed).
>
> — line 89 (near `HandleAckReceived`)

> how the Retransmission timeout counter is updated or triggers actions is not described in this specific section.
>
> — line 96 (near `HandleRetransmissionTimeout`)

### `core_4.17.3.5` — Epoch Key Rotation logic

- TLC outcome: **unhandled_input**
- ranker score: 24.84

> what happens if there is no Old key to update.
>
> — line 80 (near `AdminUpdate`)

### `core_4.21.4.2` — TRANSPORT command

- TLC outcome: **unhandled_input**
- ranker score: 24.68

> Spec does not state how the responder should handle a malformed command where P1|P2 != Lc for an unchained command, or P1|P2 <= Lc for a chained command.
>
> — line 44 (near `HandleTransportCommand`)

> Spec does not state if a successful R-APDU is generated immediately for intermediate chained C-APDUs (CLA=0x90), or only after the entire chained message is reassembled.
>
> — line 45 (near `HandleTransportCommand`)

> SW2 is a single byte. Spec does not state how to encode if the remaining bytes (responderMessageSize - cmdLe) > 255.
>
> — line 60 (near `HandleTransportCommand`)

### `core_4.20.3.5` — Message Segmentation and Reassembly

- TLC outcome: **unhandled_input**
- ranker score: 23.64

> what happens if a middle segment (begin=FALSE, end=FALSE) is received when rxState is "Idle"?
>
> — line 140 (near `ReceiveSegment_Action`)

> what happens if a middle segment payload size is strictly less than (MaxPaftpPacketSize - HeaderSize)?
>
> — line 141 (near `ReceiveSegment_Action`)

### `core_4.18.2` — Group Peer State

- TLC outcome: **no_error**
- ranker score: 22.77

> how an entry is added when the table is full (whether it inline expunges or fails)
>
> — line 68 (near `ReceiveEncryptedMessage`)

> how the window/counter is updated on subsequent messages
>
> — line 71 (near `ReceiveEncryptedMessage`)

> how an entry is added when the table is full
>
> — line 80 (near `ReceiveEncryptedMessage`)

> how the window/counter is updated on subsequent messages
>
> — line 83 (near `ReceiveEncryptedMessage`)

### `core_4.12.1` — Reliable Messaging Header Fields

- TLC outcome: **unhandled_input**
- ranker score: 22.59

> The spec text says a reliable message "requires the receiver to send back
>
> — line 71 (near `HandleSendMessageWithAck`)

### `core_4.19.4.5` — Message Segmentation and Reassembly

- TLC outcome: **unhandled_input**
- ranker score: 21.76

> Spec does not state how to handle AppSendSdu if the session is not Open.
>
> — line 84 (near `HandleAppSendSdu`)

> Spec does not state what happens if ReceiveSegment arrives on a Closed session.
>
> — line 149 (near `HandleReceiveSegment`)

### `core_4.6.5` — Replay Prevention and Duplicate Message Detection

- TLC outcome: **no_error**
- ranker score: 21.04

> Section 4.6.5.1 states message reception state uses a "lossy compression scheme"
>
> — line 43 (near `ProcessReceiveMessage`)

### `core_4.21.4.3` — GET RESPONSE command

- TLC outcome: **no_error**
- ranker score: 20.07

> The spec says GET RESPONSE must follow a "TRANSPORT successful Response APDU - Incomplete message".
>
> — line 58 (near `HandleGetResponse_Error`)


## Not checkable

These modules parsed (SANY passed) but TLC could not reach a verdict. They are **not** evidence of a clean spec.

| unit | outcome | why |
|---|---|---|
| `core_4.12.7.1` | input_alphabet_unknown |  |

## Checked, nothing found

TLC explored these models completely and found no deadlock. How much that is worth depends on how much the model actually does — a model with a handful of states cannot deadlock no matter how incomplete the spec is, so the small ones are **not** evidence of a complete spec.

| unit | states | depth | meaningful? | title |
|---|---|---|---|---|
| `core_4.12.6.2` | 115516 | 34 | yes | Acknowledgement Table |
| `core_4.19.4.8` | 69025 | 22 | yes | Packet Acknowledgements |
| `core_4.12.6.1` | 68065 | 18 | yes | Retransmission Table |
| `core_5.5` | 11200 | 26 | yes | Commissioning Flows |
| `core_4.18.2` | 4112 | 18 | yes | Group Peer State |
| `core_4.6.5` | 4096 | 18 | yes | Replay Prevention and Duplicate Message Detection |
| `core_4.6.5.1` | 164 | 11 | yes | Message Reception State |
| `core_4.21.4.3` | 48 | 8 | yes | GET RESPONSE command |
| `core_4.19.4.11` | 12 | 4 | ⚠️ too small to conclude | Protocol State Diagrams |
| `core_4.18.3.2` | 4 | 4 | ⚠️ too small to conclude | MsgCounterSyncRsp - Message Counter Synchronization Response |
| `core_4.8.2` | 4 | 4 | ⚠️ too small to conclude | Security Processing of Outgoing Messages |
| `core_4.8.3` | 4 | 4 | ⚠️ too small to conclude | Security Processing of Incoming Messages |
