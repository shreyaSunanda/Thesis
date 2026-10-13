# TLC candidate-gap report

Source log: `models/generated/ch45_v2/tlc_results.jsonl`

Candidate gaps are ordered by **how many steps it took to reach the unhandled input**, not by ranker score: the further the model got before hitting one, the more confidence that the model works and the spec is what ran out.

An **unhandled input** is a reachable state in which an event is waiting and no action of `Next` can consume it: something arrived that the spec text defines no handling for. Unlike a plain deadlock this does **not** fire when a protocol simply ends — "SHALL close the session", "perform no further processing" and the like leave nothing pending, so they are vacuously fine. It is still a *candidate* gap: the generated model may have omitted a handler the spec does describe. Each one needs review against the section's own text.

## Summary

| outcome | units |
|---|---|
| candidate gaps (unhandled input) | 6 → **6** after triage (1 of those reached after real progress) |
| invariant violated | 0 |
| checked, nothing found | 1 (of which 0 explored too little to mean anything) |
| **not checkable** (see below) | **4** |
| model-asserted unspecified cases (unverified) | 9 note(s) in 7 unit(s) |
| total | 11 |

7 of 11 modules were actually model-checked. The rest produced no verdict either way.

## Candidate gaps

### `core_4.19.4.8` — Packet Acknowledgements

- steps to the unhandled input: 4
- ranker score: 112.1
- module: `core_4_19_4_8.tla`
- ⚠️ the module does not declare `Inputs`, so its alphabet was recovered from guards; events it handles nowhere cannot be seen
- constants (inferred kind): `MaxSeqNum`=numeric, `MaxWindowSize`=numeric, `Null`=sentinel, `BTP_ACK_TIMEOUT`=numeric, `NoInput`=sentinel, `Inputs`=set

**Unhandled input under no capability flags** after 4 state(s) (56 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 41 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.19.4.8 Packet Acknowledgements
```
State in which the input went unhandled:

```
State 4: <ReceiveInput line 41, col 5 to line 44, col 101 of module core_4_19_4_8>
/\ pendingAck = Null
/\ sessionState = "CLOSED"
/\ ackReceivedTimer = "STOPPED"
/\ sendAckTimer = "STOPPED"
/\ unackedList = <<>>
/\ pendingInput = "SendBTPPacket"
/\ freeSlots = 3
```

### `core_4.20.3.8` — Packet Acknowledgements

- steps to the unhandled input: 2
- ranker score: 127.15
- module: `core_4_20_3_8.tla`
- ⚠️ the module does not declare `Inputs`, so its alphabet was recovered from guards; events it handles nowhere cannot be seen
- constants (inferred kind): `PAFTP_ACK_TIMEOUT`=numeric, `MaxSeqNum`=numeric, `ReceiveWindowSize`=numeric, `NoInput`=sentinel, `Inputs`=set, `NullSeqNum`=sentinel

**Unhandled input under no capability flags** after 2 state(s) (2 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 55 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.20.3.8 Mandatory Input Shape
```
State in which the input went unhandled:

```
State 2: <ReceiveInput line 55, col 5 to line 58, col 141 of module core_4_20_3_8>
/\ lastSentSeq = NullSeqNum
/\ receivedSet = {}
/\ sessionState = "CLOSED"
/\ unackedReceived = {}
/\ unackedSent = {}
/\ sendAckTimer = "STOPPED"
/\ ackRxTimer = "STOPPED"
/\ nextSeqToSend = 0
/\ pendingInput = [type |-> "SendPacket"]
/\ freeSlots = 3
```

### `core_4.12.2.1` — Retransmissions

- steps to the unhandled input: 2
- ranker score: 54.01
- module: `core_4_12_2_1.tla`
- ⚠️ the module does not declare `Inputs`, so its alphabet was recovered from guards; events it handles nowhere cannot be seen
- constants (inferred kind): `ExchangeIds`=set, `MRP_MAX_TRANSMISSIONS`=numeric, `MRP_BACKOFF_BASE`=numeric, `MRP_BACKOFF_THRESHOLD`=numeric, `MRP_BACKOFF_MARGIN`=numeric, `SESSION_IDLE_INTERVAL`=numeric, `SESSION_ACTIVE_INTERVAL`=numeric, `FAST_POLLING_INTERVAL`=numeric, `NoInput`=sentinel, `Inputs`=set

**Unhandled input under no capability flags** after 2 state(s) (3 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 86 of the module)

Spec clause that action cites:

```
\* SOURCE: core_4.12.2.1 Mandatory Event Ingestion
```
State in which the input went unhandled:

```
State 2: <ReceiveInput line 86, col 5 to line 89, col 26 of module core_4_12_2_1>
/\ state = (ExchangeIds_1 :> [senderIsICD |-> FALSE, status |-> "IDLE", retries |-> 0, isFirstMessage |-> FALSE, peerActiveMode |-> FALSE, timerActive |-> FALSE, timerValue |-> 0, opDiscoveryTriggered |-> FALSE] @@ ExchangeIds_2 :> [senderIsICD |-> FALSE, status |-> "IDLE", retries |-> 0, isFirstMessage |-> FALSE, peerActiveMode |-> FALSE, timerActive |-> FALSE, timerValue |-> 0, opDiscoveryTriggered |-> FALSE])
/\ pendingInput = "ReceiveAck"
```

### `core_4.20.3.7` — Receive Windows

- steps to the unhandled input: 2
- ranker score: 47.51
- module: `core_4_20_3_7.tla`
- ⚠️ the module does not declare `Inputs`, so its alphabet was recovered from guards; events it handles nowhere cannot be seen
- constants (inferred kind): `Commissioner`=opaque, `CommissionableDevice`=opaque, `MaxWindowSize`=numeric, `MaxQueueSize`=numeric, `NoInput`=sentinel, `Inputs`=set

**Unhandled input under no capability flags** after 2 state(s) (5 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 44 of the module)

Spec clause that action cites:

```
\* -------------------------------------------------------------------------
\* ENVIRONMENT INPUT RECEPTION
\* -------------------------------------------------------------------------
```
State in which the input went unhandled:

```
State 2: <ReceiveInput line 44, col 5 to line 47, col 89 of module core_4_20_3_7>
/\ sessionActive = FALSE
/\ pendingAck = (Commissioner :> FALSE @@ CommissionableDevice :> FALSE)
/\ remoteWindow = (Commissioner :> 0 @@ CommissionableDevice :> 0)
/\ localWindow = (Commissioner :> 0 @@ CommissionableDevice :> 0)
/\ pendingPackets = (Commissioner :> 0 @@ CommissionableDevice :> 0)
/\ pendingInput = [type |-> "ReceivePacket", peer |-> Commissioner]
```

### `core_4.19.4.7` — Receive Windows

- steps to the unhandled input: 2
- ranker score: 45.97
- module: `core_4_19_4_7.tla`
- ⚠️ the module does not declare `Inputs`, so its alphabet was recovered from guards; events it handles nowhere cannot be seen
- constants (inferred kind): `MaxWindowSize`=numeric, `MaxTxQueue`=numeric, `NoInput`=sentinel, `Inputs`=set

**Unhandled input under no capability flags** after 2 state(s) (4 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 26 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 26, col 5 to line 29, col 98 of module core_4_19_4_7>
/\ state = "Uninitialized"
/\ pendingTxCount = 0
/\ localWindowCounter = 0
/\ remoteWindowCounter = 0
/\ hasPendingAck = FALSE
/\ pendingInput = "EnqueueData"
```

### `core_4.3.1.11` — TXT key for pairing hint (PH)

- steps to the unhandled input: 2
- ranker score: 44.85
- module: `core_4_3_1_11.tla`
- ⚠️ the module does not declare `Inputs`, so its alphabet was recovered from guards; events it handles nowhere cannot be seen
- constants (inferred kind): `MaxPHBit`=numeric, `CommissioningFlowType`=opaque, `StandardCommissioningFlow`=numeric, `CustomCommissioningFlow`=opaque, `NoInput`=sentinel, `Inputs`=set

**Unhandled input under no capability flags** after 2 state(s) (22 distinct states explored):

Last action to fire: **`ReceiveInput`** (line 46 of the module)

State in which the input went unhandled:

```
State 2: <ReceiveInput line 46, col 5 to line 49, col 88 of module core_4_3_1_11>
/\ piIncluded = FALSE
/\ state = "FactoryReset"
/\ phBits = {1}
/\ extendedDiscoveryEnabled = FALSE
/\ txtRecords = {}
/\ cm = 0
/\ pendingInput = "CommissionerReadTXT"
```

## Model-asserted unspecified cases

These are **not** TLC findings. While writing each model the generator was told (prompt rule 2) to leave a `\* TODO: unspecified` note rather than invent behaviour wherever the spec text did not say what happens. These are those notes, verbatim.

They are a **separate, unverified signal**. TLC never checked them. Some are genuine omissions, some are modelling limitations (TLA+ has no floating point), and some may simply be the generator misreading the text. Treat each as a lead to check against the section, not as a result.

They are listed for **every generated module**, including those TLC could not reach a verdict on — a module that never compiled can still have flagged a real omission on its way past.

### `core_4.20.3.8` — Packet Acknowledgements

- TLC outcome: **unhandled_input**
- ranker score: 127.15

> what acknowledgement number to use if sequence 0 is missing but a packet is received, causing the timer to start and fire.
>
> — line 77 (near `SendPacket`)

### `core_4.14.2.3` — Protocol Details

- TLC outcome: **did not compile**
- ranker score: 81.1

> Msg1 has resumption fields but no matching session is found.
>
> — line 116 (near `Responder_Validate_Sigma1`)

### `core_4.12.2.1` — Retransmissions

- TLC outcome: **unhandled_input**
- ranker score: 54.01

> random jitter (1.0 + random(0,1) * MRP_BACKOFF_JITTER) is abstracted away as TLA+ does not support floating point or continuous randomness.
>
> — line 40 (near `CalculateBackoff`)

### `core_4.12.5.1` — Reliable Message Processing of Outgoing Messages

- TLC outcome: **input_alphabet_unknown**
- ranker score: 52.11

> The specification references the acknowledgement table
>
> — line 13

### `core_4.19.4.7` — Receive Windows

- TLC outcome: **unhandled_input**
- ranker score: 45.97

> exact state of hasPendingAck for client immediately after handshake.
>
> — line 56 (near `InitializeClient`)

### `core_4.3.1.11` — TXT key for pairing hint (PH)

- TLC outcome: **unhandled_input**
- ranker score: 44.85

> whether PI can be present if all bits are 'no'. The spec says "does not apply" but lacks explicit SHALL NOT.
>
> — line 42 (near `Init`)

> whether PH is included when CM=0 and Extended Discovery is disabled
>
> — line 127 (near `GenerateTXTRecord`)

### `core_4.6.7` — Counter Processing of Incoming Messages

- TLC outcome: **input_alphabet_unknown**
- ranker score: 37.0

> spec 1.a.i says "Get the session-specific Message Reception State". It does not specify what to do if the context doesn't exist for Unicast.
>
> — line 78 (near `ProcessMessage`)

> spec 3.b says "follow 4.6.5.3" for unencrypted duplicates, but lacks an explicit outcome (like drop or reliable processing).
>
> — line 103 (near `ProcessMessage`)


## Not checkable

These modules parsed (SANY passed) but TLC could not reach a verdict. They are **not** evidence of a clean spec.

| unit | outcome | why |
|---|---|---|
| `core_4.12.5.1` | input_alphabet_unknown |  |
| `core_4.18.5` | input_alphabet_unknown |  |
| `core_4.12.5.2` | input_alphabet_unknown |  |
| `core_4.6.7` | input_alphabet_unknown |  |

## Checked, nothing found

TLC explored these models completely and found no deadlock. How much that is worth depends on how much the model actually does — a model with a handful of states cannot deadlock no matter how incomplete the spec is, so the small ones are **not** evidence of a complete spec.

| unit | states | depth | meaningful? | title |
|---|---|---|---|---|
| `core_5.5` | 418 | 18 | yes | Commissioning Flows |
