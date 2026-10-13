# D-3 — What we searched for, and where we searched

This file is the **method**. If someone asks "how did you reach that conclusion?", this
is the answer. It is also a recipe you can re-run on Finding E, F, G...

Two targets were searched: **the specification PDF** and **the official source code**.

---

## Part 1 — The specification: which pages, and why each one

The thesis corpus pipeline (`matter-corpus/`) had already split the 1335-page PDF into
numbered sections. We pulled the verbatim text of each section below into the working
brief (`connectedhomeip/UNDERSPEC_BRIEF_CD.md`) so that no claim would ever rest on
memory or paraphrase.

> **Page convention:** "printed page" is the number in the PDF's own footer.
> **PDF page = printed page + 4.**

| Spec section | Title | Printed pages | Why we needed it |
|---|---|---|---|
| **§4.19.4.10** | Connection Shutdown (BTP) | **235** | **The candidate itself.** The three contradictory sentences. |
| **§4.20.3.10** | Connection Shutdown (PAFTP) | **251** | **The candidate itself.** The 28-word MAY-only version. |
| §4.19.4.3 | Session Establishment | 228–230 | Establishes that central = GATT client and peripheral = GATT server. This is what makes sentence 2 of §4.19.4.10 impossible. |
| §4.19.4.8 | Packet Acknowledgements | 233–234 | Defines both timers and, crucially, says the ack-received timer **stops** when everything is acked. This creates the "no timer is running" window. |
| §4.19.4.9 | Idle Connection State | 234–235 | The spec's own claim that acks "double as a keep-alive mechanism". We had to check whether that claim survives once the ack timer stops. |
| §4.19.5 | Parameters and Constants (Table 35) | 238–239 | Source of `BTP_CONN_RSP_TIMEOUT` (5 s), `BTP_ACK_TIMEOUT` (15 s), `BTP_CONN_IDLE_TIMEOUT` (30 s). The third one is the whole of D1. |
| §4.20.3.9 | Idle Connection State (PAFTP) | 250 | The Wi-Fi mirror of §4.19.4.9, for the side-by-side comparison. |
| §4.20.4 | Parameters and Constants (Table 42) | 253–254 | The Wi-Fi mirror of Table 35: `PAFTP_CONN_IDLE_TIMEOUT` (30 s). |
| §4.19.4.6 | Sequence Numbers | 231–232 | Context inherited from Finding C; needed to reason about what a stray frame does. |
| §5.4.2.6.3, §5.4.3.2 | (publish/subscribe instances) | 323, 327 | Checked whether "subscribe instance"/"publish instance" are defined elsewhere. They are **used** there but **terminating** one is never defined. |

### The discipline rule we followed

> **Read the entire excerpt before labelling anything underspecified.**

This is a standing rule on this thesis, and it exists for a concrete reason: the Matter
spec routinely *introduces* a field in one subsection and *defines its behaviour* ten
pages later. (The classic example: the `Ack Number` field is declared in §4.19.2.2 but
its semantics only appear in §4.19.4.8.)

So before claiming "the spec never says how to close a session", we had to check:

- the **glossary / constant tables** (§4.19.5, §4.20.4) — this is where we *found*
  `BTP_CONN_IDLE_TIMEOUT`, which a naive reading of §4.19.4.10 alone would have missed;
- the **state diagrams** — Figure 23 (BTP session handshake), Figure 25 (Idle connection
  scenario), Figure 26 (BTP session lifecycle). In this specification, transition labels
  on diagrams sometimes carry requirements the body text omits. We checked for a
  "close" or "timeout" edge. There is none that reaps an idle session.
- the **cross-referenced sections** — §4.19.4.9 explicitly claims acks act as a
  keep-alive, so that claim had to be tested rather than assumed false.

Skipping this step is how you generate false positives, which waste the manual review
budget and damage the thesis's credibility.

---

## Part 2 — The codebase: what `connectedhomeip` is and why we used it

**`connectedhomeip`** (also called the "CHIP SDK", and the thing `chip-tool` is built
from) is the **official open-source reference implementation of Matter**, maintained by
the Connectivity Standards Alliance — the same body that writes the specification.

That is why it is the right oracle. We are not reading some random third-party product.
We are reading the implementation written by, and blessed by, the authors of the
specification. If *this* code cannot implement a sentence, the sentence is broken.

**Checkout state for every claim in these notes:**
- Commit `8b3bd4fcc49ce8b51b4b0b753d032ce52d07f716`
- Fast-forwarded to upstream on 2026-10-08
- Full history available (23,135 commits — `git log`, `git log -S`, `git blame` all
  work). This matters: it let us ask *"did the developers already know?"*

### The scope we deliberately stayed inside

| Spec chapter | Code folder | Key files | Size |
|---|---|---|---|
| §4.19 BTP (Bluetooth) | `src/ble/` | `BtpEngine.cpp`, `BLEEndPoint.cpp`, `BleLayer.cpp` | ~4,900 lines |
| §4.20 PAFTP (Wi-Fi) | `src/wifipaf/` | `WiFiPAFTP.cpp`, `WiFiPAFEndPoint.cpp`, `WiFiPAFLayer.cpp` | ~3,900 lines |

~8,800 lines total — small enough to read exhaustively rather than sample.

### The single highest-value technique: diff the twins

`src/wifipaf/` is a **port of** `src/ble/`. Same structure, same function names
(`DoClose`, `FinalizeClose`, `StartAckReceivedTimer`, `HandleConnectComplete`), same
comments in places — because it was copied.

They implement **near-identical specification text** (§4.19 vs §4.20).

Therefore: **wherever the two ports do the same thing, the spec was clear enough.
Wherever they diverge, the spec was not.** A divergence between two ports of the same
sentence, inside the same repository, by the same project, is the strongest possible
evidence that the sentence is ambiguous. It removes the counter-argument "well, that
implementer was just careless".

This is why nearly every search below was run **twice** — once per folder — and compared.

---

## Part 3 — The actual searches, in the order we ran them

### Search 1 — "Is there any close/goodbye frame?" (answers D2)

This is a **finite** question, so we answered it exhaustively rather than by sampling.

A BTP/PAFTP packet starts with one byte of **header flags**. Every packet type the
protocol can express must be a combination of those bits. So: enumerate the bits.

```bash
# The complete vocabulary of BTP packet types
grep -n "HeaderFlags" -A 25 src/ble/BtpEngine.h

# The complete vocabulary of PAFTP packet types
grep -n "HeaderFlags" -A 25 src/wifipaf/WiFiPAFTP.h
```

PAFTP turned out to have two flags BTP does not: `kManagementOpcode` (0x20) and
`kHankshake` (0x40, spelled that way in the source). A "management opcode" sounds
*exactly* like where a close command would live — so we chased it:

```bash
# Every single place the management-opcode bit is read
grep -rn "kManagementOpcode" src/wifipaf/
grep -rn "kHankshake" src/wifipaf/
grep -rn "MgmtOp\|OpCode\|Opcode" src/wifipaf/*.cpp src/wifipaf/*.h
```

Then we read the packet-dispatch function in each transport, to confirm nothing switches
on an opcode:

- `BtpEngine::HandleCharacteristicReceived` — `src/ble/BtpEngine.cpp`
- `WiFiPAFEndPoint::Receive` and `WiFiPAFEndPoint::GetPktSn` — `src/wifipaf/WiFiPAFEndPoint.cpp`

### Search 2 — "What are ALL the ways a session can end?" (answers D2's second half)

Both ports funnel every shutdown through one function named `DoClose`. So enumerating
its callers enumerates every possible death of a session — a closed set, nothing can hide.

```bash
grep -rn "DoClose(" src/ble/
grep -rn "DoClose(" src/wifipaf/
```

Each call site was then opened and classified into exactly one of three buckets:
**(i) link-layer event**, **(ii) timer expiry**, **(iii) peer-sent protocol frame**.
Bucket (iii) is the one D2 predicts will be empty.

### Search 3 — "Does the impossible sentence have a handler?" (answers D)

Sentence 2 of §4.19.4.10 says the *server* unsubscribes. So: does the server ever call
the unsubscribe function, and what does it do when it *receives* one?

```bash
grep -rn "HandleUnsubscribeReceived\|UnsubscribeCharacteristic" src/ble/
```

Then we read the three functions that decide what a close actually *does to the peer*:

- `BleLayer::HandleUnsubscribeReceived` — `src/ble/BleLayer.cpp`
- `BLEEndPoint::FinalizeClose` — `src/ble/BLEEndPoint.cpp` (the role-split lives here)
- `BLEEndPoint::ReleaseBleConnection` + `BLEEndPoint::Free` — `src/ble/BLEEndPoint.cpp`

`ReleaseBleConnection` turned out to branch on a flag called `kAutoClose` that the
specification has never heard of, so that flag became its own search:

```bash
grep -rn "autoClose\|kAutoClose\|AutoClose" src/ble/*.cpp src/ble/*.h
```

…which led to `BleLayer::NewBleEndPoint` and `BleLayer::HandleBleTransportConnectionInitiated`.

### Search 4 — "Is the spec's idle timeout implemented?" (answers D1)

The most direct question in the whole investigation, and the one with the cleanest
answer.

```bash
# Is the spec's third constant implemented ANYWHERE?
grep -rn "BTP_CONN_IDLE\|CONN_IDLE_TIMEOUT\|IDLE_TIMEOUT" src/ examples/ config/

# What timeouts DO exist in each transport?
grep -n "TIMEOUT" src/ble/BleConfig.h
sed -n '100,152p' src/wifipaf/WiFiPAFConfig.h
```

When a `PAFTP_CONN_IDLE_TIMEOUT_MS` *did* turn up in the Wi-Fi config, we did not stop
at "so it is implemented". **Defining a constant is not the same as using it for its
stated purpose.** So we traced every consumer:

```bash
grep -rn "PAFTP_CONN_IDLE_TIMEOUT_MS" src/wifipaf/
grep -rn "WIFIPAF_MAX_RESOURCE_BLOCK_COUNT\|WIFIPAF_WAIT_RES_TIMEOUT_MS" src/wifipaf/
```

That single extra step is what turned a boring result into the most interesting one in
D1. (See D-4 §3.)

### Search 5 — "What timers are running on an idle session?" (the core of D1)

We listed every timer start/stop in each endpoint and then walked the handshake path to
see which ones are still armed once a session goes quiet.

```bash
grep -n "StartAckReceivedTimer\|RestartAckReceivedTimer\|StopAckReceivedTimer\|\
StartSendAckTimer\|StopSendAckTimer\|StartReceiveConnectionTimer\|StartConnectTimer" \
     src/ble/BLEEndPoint.cpp
```

Then we read the two "we are now connected" functions side by side — this is the twin
comparison, and it is where the divergence appeared:

- `BLEEndPoint::HandleConnectComplete` — `src/ble/BLEEndPoint.cpp`
- `WiFiPAFEndPoint::HandleConnectComplete` — `src/wifipaf/WiFiPAFEndPoint.cpp`

A plain-text grep for the word "idle" across both folders was the thing that surfaced
the decisive comment:

```bash
grep -rni "idle" src/ble/ src/wifipaf/ --include=*.cpp --include=*.h
```

### Search 6 — "How many slots, and what happens when they run out?" (D1's consequence)

```bash
grep -rn "BLE_LAYER_NUM_BLE_ENDPOINTS" src/ble/
grep -rn "WIFIPAF_LAYER_NUM_PAF_ENDPOINTS" src/wifipaf/
```

…then read `BleLayer::NewBleEndPoint`'s failure path and what its caller does on
failure.

### Search 7 — "Did the developers already know?" (git archaeology)

This is the step that upgrades a finding from *"we think there's a gap"* to
*"the maintainers hit this gap and said so in writing."*

`git log -L` follows the history of **specific lines** through renames and refactors —
far better than searching commit messages, which usually do not mention the thing you
care about.

```bash
# Who wrote the "idle session supervision" line, and when?
git log --oneline -L 160,165:src/wifipaf/WiFiPAFEndPoint.cpp

# Read that commit's full message
git log -1 --format="%H%n%ad%n%s%n%n%b" 650c569666
```

That commit message is the single most important piece of evidence in Finding D.

### Search 8 — "Did anyone write down that they were guessing?"

A code comment admitting ambiguity is level-2 evidence on the ladder in
[D-1 §9](D-1-background-for-newcomers.md). So we swept for the usual tells:

```bash
grep -rni "TODO\|FIXME\|XXX\|not specified\|unspecified\|undefined behav\|\
we assume\|spec does not\|spec is silent" \
     src/ble/*.cpp src/ble/*.h src/wifipaf/*.cpp src/wifipaf/*.h
```

### Search 9 — "Is there a test for this?"

Whether a behaviour has a regression test tells you whether the project considers it a
*requirement* or an *accident*.

```bash
grep -rn "ReceiveConnectionTimer\|EstablishmentTimeout" src/wifipaf/tests/TestWiFiPAFLayer.cpp
grep -rln "PoolFull\|pool FULL\|Idle\|Timeout" src/ble/tests/
```

### Search 10 — following the trail out of scope, deliberately and visibly

The scope rules said: stay in `src/ble/` and `src/wifipaf/` **unless a specific trail
leads elsewhere — and say so when it does.**

Two trails led out, and both were followed because refusing to follow them would have
produced an *overstated* finding:

1. `ReleaseBleConnection` ends in `mApplicationDelegate->NotifyChipConnectionClosed()`.
   Whether the radio link actually dies depends on what that does, which lives in
   `src/platform/`. We read one concrete implementation (`src/platform/Linux/`).

2. If `src/ble/` has no idle reaper, **something higher up might still reap it.** We had
   to check before claiming a slot can be held forever:

```bash
grep -rn "CloseAllBleConnections\|CloseConnection" src/app/ src/platform/internal/
grep -n "Close\|Abort" src/transport/raw/BLE.cpp
```

This found `CommissioningWindowManager`, which **does** eventually clean up — and
carries a comment that turns out to be the best single sentence of evidence in the whole
finding. Had we stopped at the folder boundary, D1 would have been wrong.

---

Next: [D-4-what-we-found.md](D-4-what-we-found.md) — the results.
