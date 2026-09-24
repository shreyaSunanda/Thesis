# Session Log — TLA+ Modeling & State-Space Decomposition (2026-09-18)

This document records everything done in this working session: the starting
state of the project, every decision made and why, every problem encountered
and how it was diagnosed and fixed, and the final results. It is written so
it can be read on its own, without the chat history that produced it.

---

## 1. Starting point

The Matter 1.6 Core Specification (1335 pages) had already been run through
the existing corpus pipeline (`src/build_corpus.py`), producing:

- `data/processed/core/sections.json` — the full parsed, cross-referenced,
  tagged corpus.
- `data/processed/core/dependency_graph.json` — a bidirectional
  cross-reference graph over the corpus.
- `data/processed/core/ranked_candidates.json` — **91 sections** ranked by
  formal-modeling relevance (state-machine/timer/command vocabulary). Top 5:

  | id | title | score |
  |---|---|---|
  | `core_11.10.7.2` | ArmFailSafe Command | 159.31 |
  | `core_4.20.3.8` | Packet Acknowledgements | 127.15 |
  | `core_4.19.4.8` | Packet Acknowledgements | 112.1 |
  | `core_5.5` | Commissioning Flows | 111.9 |
  | `core_4.14.2.3` | Protocol Details | 81.1 |

A single hand-written TLA+ model already existed at the repo root:
`ArmFailSafe.tla` / `ArmFailSafe.cfg`, modeling `core_11.10.7.2`. It uses a
specific pattern (detailed in §7) that everything built today deliberately
follows: a single `pendingMsg` "mailbox" variable, one externally-injected
message at a time, per-message guarded actions, and a catch-all
`UndefinedTransition` action that fires whenever the current
`(state, pendingMsg)` combination matches none of the defined transitions —
if TLC can reach that catch-all, it is a candidate formal specification gap.

---

## 2. The uploaded decomposition guide: what it got right, what it got wrong

Before doing any new modeling, the task was to scale this approach beyond one
section without TLC running out of memory. A guide document was provided,
proposing to adapt a paper's "compositional decomposition" method to avoid
state-space explosion.

### 2.1 What checked out

The citations in the guide are real:

- **WCDCAnalyzer: Scalable Security Analysis of Wi-Fi Certified Device
  Connectivity Protocols** — Zilin Shen (Purdue), Imtiaz Karim (UT Dallas),
  Elisa Bertino (Purdue). Accepted to NDSS Symposium 2026 (23–27 Feb 2026,
  San Diego). DOI `10.14722/ndss.2026.231049`. Verified by fetching the
  actual paper PDF, not just the guide's description of it.
- **Ciobâcă & Cortier, IEEE CSF 2010** — a real protocol-composition theorem,
  cited inside the WCDCAnalyzer paper itself as its theoretical foundation.

### 2.2 What did not check out

Reading the actual WCDCAnalyzer paper (not just the guide's summary of it)
surfaced a mismatch between what the guide told us to do and what the paper
actually does:

- **The guide's recipe:** at a phase boundary, fix the handed-off variable to
  one "representative value" (its own example: `InitialExpiryLength = 300`
  out of a possible `1..900`), then treat a single TLC run against that one
  value as having verified the composed system. Its own §8 even frames this
  explicitly: *"this is where the state space shrinks dramatically — Phase 2
  does not explore all combinations of Phase 1 variables, only a fixed
  assumed starting point."*
- **What the paper actually does:** WCDCAnalyzer's soundness rests on
  Tamarin's *symbolic* treatment of secrets. Quoting the paper's own
  description of its interface mechanism: *"we propose a novel approach
  based on verifying secrecy properties in the previous sub-protocol. If the
  secrecy of a term is maintained, it is treated as freshly generated."*
  "Freshly generated" in Tamarin's symbolic model means the value is
  reasoned about as ranging over **all** possible values — not one sample.
  The composition theorem's actual precondition is **disjoint cryptographic
  primitives** between sub-protocols (Ciobâcă & Cortier's result, restated in
  the paper's §II.C "Protocol Composition") — a statement about symbolic
  encryption/hash operations that has **no analogue** in a plain,
  non-cryptographic TLA+ state machine like ours. None of our models involve
  any cryptography (no keys, nonces-as-crypto, encryption, or hashing).

**Conclusion:** the guide's specific technique (fix one representative
value) is an unsound sampling heuristic, not exhaustive verification — a bug
that only manifests at an untested value would never be found. And even if
it were sound, citing WCDCAnalyzer/Ciobâcă-Cortier as its theoretical
justification would be a misapplication, since our models have no
cryptographic primitives for that theorem's precondition to apply to.

### 2.3 Decision: the corrected, sound alternative

Agreed approach: when a model must be split into phases to keep TLC's state
space manageable, **the downstream phase's `Init` must range over the full
domain (or exact reachable set) of any handed-off variable — never a fixed
sample.** Only the *other*, already-settled machinery of the upstream phase
is dropped from the downstream phase's exploration; the range of values a
handoff variable can take is never narrowed. This is described in this
project as ordinary **assume-guarantee / thin-slicing decomposition**, a
standard TLA+-native technique (component composition, à la Abadi & Lamport)
— not attributed to the WCDCAnalyzer/Ciobâcă-Cortier theorem, since that
theorem's precondition doesn't hold here.

### 2.4 Decision: modeling scope

Three options were considered: model literally every section of the
1335-page spec; hand-pick a multi-section cluster; or model only the 91
sections already surfaced in `ranked_candidates.json`. **Decision: the 91
ranked candidates**, modeled mostly standalone (matching what the existing
pipeline was built to identify), with the phase-decomposition technique
applied *only* to sections whose own model is complex enough to actually
risk state explosion — not reflexively to every section. (This scope was
later refined in §5 to also account for real cross-references between
sections, not just single sections in isolation.)

These two decisions (§2.3, §2.4) were saved as a persistent working
methodology so future sessions on this project stay consistent with them.

---

## 3. Pilot section: `core_4.20.3.8` "Packet Acknowledgements"

Chosen as the pilot because it is a genuine, self-contained state machine
(sequence numbers, two independent timers, a receive window) — unlike
`core_5.5` "Commissioning Flows", which reads as descriptive prose pulling in
several other sections rather than being a standalone state machine.

### 3.1 Model design

Following `ArmFailSafe.tla`'s pattern: variables `state` ("Open"/"Closed"),
`outstanding` (count of sent-unacked packets), `ackTimerRunning`,
`pendingAck`, `sendAckTimerRunning`, `freeSlots`, and `pendingEvent`. Real
8-bit sequence numbers are abstracted to a bounded outstanding-packet
**count**, justified directly from the spec text's own induction property
("acknowledgement of a given packet implies acknowledgement of all packets
received... prior to the acknowledged packet") — exact sequence values don't
affect the control flow, only *how many* packets are still outstanding and
*whether* an ack covers the newest one.

### 3.2 Problems found and fixed (all in the model, not the spec)

TLC found a violation on the very first run. Each one was checked carefully
before being accepted, since the goal is to find *real* spec gaps, not
artifacts of how the model was written:

| # | Problem | Diagnosis | Fix |
|---|---|---|---|
| 1 | `AckNewest`/`AckOlder`/`InvalidAck` modeled as three independently-injectable events; TLC found "Undefined" for `AckNewest` while `outstanding = 0` | These are not three message *types* the network sends — they're one incoming ack, whose classification (newest/older/invalid) is a *consequence* of state, not something the environment freely chooses. Modeling them as separate injectable labels let TLC "choose" a nonsensical classification. | Merged into a single `ReceiveAck` event; classification is now computed from `outstanding` inside one action. |
| 2 | After fix #1, still "Undefined" — for the very same `ReceiveAck` event | `UndefinedTransition`'s exclusion list still didn't recognize the new merged event as always-defined | Added `pendingEvent # "ReceiveAck"` to the catch-all's exclusion list |
| 3 | `SlotFreedAction` (an action I added myself — not spec text, needed only so `freeSlots` can ever recover) was dispatched through the same `pendingEvent` queue as real protocol events, so TLC could "fire" it while the window was already full | Same category as #1: an invented action being treated as an externally injectable message when it isn't one | Pulled `SlotFreedAction` out of the `pendingEvent` dispatch entirely; made it a standalone, always-available background action |
| 4 | `WindowLowAction` (flushing a pending ack when the window drops to ≤2 slots) was also freely injectable | Per the spec text, this is the peer's own **automatic reaction** to receiving a packet (the only thing that shrinks `freeSlots`) — not a message the network sends | Folded the window-low check directly into `ReceivePacketAction` as an immediate consequence of decrementing `freeSlots`; removed the standalone `WindowLowAction`/event entirely |

### 3.3 Final result

Clean run: **9 reachable states**, no explosion. One genuine finding
survived after all four artifacts were removed:

> **Finding A — stale ack-timer notification.** `AckTimeout` arriving while
> `ackTimerRunning = FALSE` is undefined. Real timers are interrupt/callback
> driven: a timer can fire and queue its "I expired" notification a moment
> *before* a `stop timer` instruction (triggered by a just-arrived valid ack)
> takes effect. The spec describes the timer only at the logical level
> (start/stop/restart/"if it expires, close the session") and never says what
> to do with a notification that arrives after the timer was already
> stopped. This is the *same category* of finding already established by the
> pre-existing `ArmFailSafe.tla` (a stale `FailSafeTimeout` arriving after
> the state already moved past `Armed`) — not a new kind of issue invented
> for this section.
>
> **Caveat:** this is a *candidate* for human review, not a proven defect —
> reasonable people could argue this is an implementation-level timer-
> engineering detail rather than a protocol-spec gap. That judgment call is
> exactly what the methodology defers to a human reviewer.

---

## 4. Second section: `core_4.19.4.8` "Packet Acknowledgements" (BTP)

Before modeling from scratch, checked the text: `core_4.19.4.8` (Bluetooth
transport, "BTP") turned out to be the **same design template** as
`core_4.20.3.8` (Wi-Fi transport, "PAFTP") — same paragraphs, same rules,
just `BTP`/`BTP_ACK_TIMEOUT` in place of `PAFTP`/`PAFTP_ACK_TIMEOUT`.

**Decision:** reuse the already-validated model structure instead of
re-deriving it, since the underlying state machine is identical.

**Result:** 9 states, same finding (stale `AckTimeout` notification). Because
the same gap appears identically in two independently-worded transport
bindings, this looks like a **recurring blind spot in Matter's shared
"acknowledgement timer" design pattern**, not a one-off wording accident in a
single section — a stronger finding than either instance alone.

---

## 5. Course-correction: isolated sections vs. inter-section relationships

Three questions were raised that led to a real process change:

### 5.1 "Are you considering inter-section relationships?"

Honest answer at the time: **no.** Both sections above were modeled from
their own isolated `full_text` only, even though the codebase already has a
tool built for exactly this — `DependencyGraph.closure()` in
`src/parsing/dependency_graph.py`, described in its own docstring as *"the
building block for automated context assembly."* It had not been used.

Ran it retroactively:

```
core_4.20.3.8 -> references (1 hop): {core_4.20.3.9, core_4.20.3.11}
core_4.20.3.8 <- referenced_by (1 hop): {core_4.20.3.7, core_4.20.3.9, core_4.20.2.2}
```

Read the referenced neighbor `core_4.20.3.9` "Idle Connection State" in full:
it only explains that the ack timer doubles as a keep-alive signal — it does
not address the stale-notification race. **Finding A stands**, but the
process gap (not checking cross-references before declaring a finding) was
real and is now corrected going forward.

### 5.2 "Why is the AckTimeout race actually an underspecification?"

Answered with the explicit mechanism (real timers are interrupt-driven, so
"stop the timer" and "the timer already fired" can race), an explicit
analogy to the pre-existing `ArmFailSafe.tla` precedent, and an explicit
epistemic caveat: this is a candidate for human judgment, not a certainty —
consistent with how the existing methodology already frames
`UndefinedTransition`-reachable states ("worth reviewing", not "proven
wrong").

### 5.3 "Are you following the existing codebase's conventions?"

For TLA+ *style* — yes, deliberately patterned on `ArmFailSafe.tla` (see §7
for the exact comparison). For the *decomposition step* specifically —
there was nothing to follow, since nothing in this repo had ever been
decomposed before `ArmFailSafe.tla` is a single flat model. The one
concrete gap was the unused `DependencyGraph` tool, corrected in §5.1.

### 5.4 Directive: prove the method works on something that actually needs it

The supervisor-facing ask was explicit: produce real evidence of solving a
state-space problem, and stop treating sections in isolation. Both isolated
sections modeled so far (9–15 states each) never had an actual explosion
risk — there was nothing genuine to "solve" yet. The honest way to get real
evidence, which also directly answers "consider inter-section
relationships", was to **compose several genuinely cross-referenced sections
into one integrated model**, get a real baseline state count, and only then
apply decomposition.

---

## 6. The composed model: `core_4.20.3` "PAFTP Control Frames" (8 subsections)

Checked how large the real, cross-referenced cluster actually is:

| id | title | words |
|---|---|---|
| `core_4.20.3.1` | PAFTP Handshake Request | 255 |
| `core_4.20.3.2` | PAFTP Handshake Response | 245 |
| `core_4.20.3.3` | Session Establishment | 372 |
| `core_4.20.3.4` | Data Transmission | 153 |
| `core_4.20.3.5` | Message Segmentation and Reassembly | 649 |
| `core_4.20.3.6` | Sequence Numbers | 212 |
| `core_4.20.3.7` | Receive Windows | 528 |
| `core_4.20.3.8` | Packet Acknowledgements | 754 |
| `core_4.20.3.9` | Idle Connection State | 95 |
| `core_4.20.3.10` | Connection Shutdown | 28 |
| `core_4.20.3.11` | Protocol State Diagrams | 104 |

This is the *entire* PAFTP session lifecycle: handshake → established
(ack/window + message segmentation) → shutdown — a genuinely large, real,
cross-referenced system, not an artificially inflated one.

Two subsections contributed no independent modelable content:
- `core_4.20.3.9` (Idle Connection State) — already read in §5.1, no new
  normative rules.
- `core_4.20.3.11` (Protocol State Diagrams) — content is almost entirely a
  figure reference ("Figure 33..."); **the actual diagram images are not
  captured by the text-extraction pipeline**, a real limitation of the
  corpus tooling worth flagging on its own, separate from anything TLC
  found.

One subsection is independently notable purely from its *text*:
- `core_4.20.3.10` (Connection Shutdown) is **28 words long in total** — "A
  Commissioner MAY terminate... A Commissionable Device MAY terminate..."
  No procedure, no peer notification, no reference to any shutdown frame
  type is given anywhere, in stark contrast to every other subsection's
  detailed normative text. This is a standalone underspecification
  observation, independent of anything TLC reports.

### 6.1 Naive (undecomposed) model: `PAFTPSessionNaive.tla`

Composed all remaining subsections into one model: `phase`
("Handshake"/"Established"/"Closed"), `handshakeTimerRunning` (§4.20.3.1–.3),
the already-validated ack/window variables (§4.20.3.7–.8), and
`sduInProgress`/`queueLen`/`reassemblyInProgress` (§4.20.3.5, message
segmentation/reassembly and the FIFO send queue). Handshake version
negotiation is modeled as a nondeterministic boolean choice
(`versionsCompatible`) rather than literal version-list arithmetic, since
only the two outcomes ("compatible" vs. "not") matter to the control flow.
The FIFO send queue is bounded by a new modeling constant `MaxQueue`
(analogous to `MaxOutstanding`) since the spec text does not itself bound it
— and, deliberately, an attempt to send while the queue is already full is
left **unhandled** rather than given an invented behavior, since the spec is
silent on that case too (see Finding C, §6.4).

**Problem found and fixed:** while writing this file, TLC itself refused to
run twice with *"Successor state is not completely specified... variable
reassemblyInProgress is not assigned"* — in `ReceiveEndSegmentAction` and
`ReceiveBeginSegmentAction`, one branch of an `IF/THEN/ELSE` set
`reassemblyInProgress'` while the other branch (transitioning to `"Closed"`)
forgot to. This is a plain TLA+ correctness bug (an incomplete next-state
relation), not a spec ambiguity — TLC caught it immediately and refused to
proceed, which is exactly the intended safety net. Fixed by adding the
missing `UNCHANGED reassemblyInProgress` to each incomplete branch.

### 6.2 Naive baseline result

Running with the invariant, TLC stops at the first violation (by design), so
a **separate run without the invariant** was used to get an honest total
reachable-state count (otherwise "solved state explosion" would be citing a
number that was never actually measured):

```
8775 states generated, 4217 distinct states found, 0 states left on queue.
```

**4,217 reachable states** — far larger than any single isolated section
(9–15 states), and genuine confirmation that composing related sections is
where real growth comes from.

With the invariant restored, the first violation found was:

> **Finding B — data arriving before the handshake completes.** A
> `SendPacket` event (an Established-phase data/ack action) arriving while
> `phase = "Handshake"` is undefined. This is a finding that **only exists
> because the model composes multiple sections** — an isolated model of
> `core_4.20.3.8` alone has no concept of a handshake phase and could never
> surface this.

### 6.3 Decomposition

Since the Established phase's variables always reset to the **same fixed
deterministic values** regardless of which nondeterministic branch fired
during the handshake (there is no varying value being handed off — the
handoff is trivial), the growth here isn't from a value range that needs
preserving across a sequential boundary. It's from **width**: many
independent variables multiplied together within the Established phase
itself. The right decomposition for that is by **independent concern**
(disjoint-variable module composition — the standard TLA+ technique for
composing independent components), not sequential phase-handoff.

Checked that the ack/window variables (`outstanding`, `ackTimerRunning`,
`pendingAck`, `sendAckTimerRunning`, `freeSlots`) and the segmentation
variables (`sduInProgress`, `queueLen`, `reassemblyInProgress`) are never
read or written by each other's actions — confirmed disjoint. That is the
exact precondition under which checking two components separately reproduces
the full reachable state space of their product with **zero loss of
soundness** (unlike the guide's method in §2).

Built three submodules in `tla_models/core_4.20.3_session/decomposed/`:

- **`Handshake.tla`** — owns `phase`, `handshakeTimerRunning`. Deliberately
  given the **full original event set** (not just its own two events), so it
  can still catch *any* event type arriving too early — this is what
  reproduces Finding B soundly inside the smaller model.
- **`AckWindow.tla`** — owns the ack/window variables, assumes the handshake
  already succeeded (the one deterministic value it's ever handed). Its
  event set is its own five events **plus** the two handshake events (to
  catch a *stale* handshake notification arriving too late) — but
  deliberately **excludes** the SDU subsystem's event names, because
  treating those as "undefined here" would be a false positive purely from
  decomposition, the same class of self-inflicted mistake fixed in §3.2.
- **`SDU.tla`** — same pattern, for the segmentation/reassembly concern.

**Problem found and fixed:** getting the full state count for `AckWindow.tla`
and `SDU.tla` (running without the invariant) hit a genuine TLA+ **deadlock**
— not a modeling finding. Their `UndefinedTransition` was guarded by
`status = "Established"` specifically, so once `status` reached
`"Undefined"`, no action remained enabled at all (unlike the naive model and
`Handshake.tla`, which both guard on `phase # "Closed"` and so keep
self-looping once `Undefined` is reached). Fixed by widening the guard in
both submodules to `status # "Closed"`, matching the naive model's own
convention.

**Verification step (this matters — it's the check that the decomposition
didn't quietly drop anything):** re-ran all three submodules *with* the
invariant after all fixes:

- `Handshake.tla` → finds `SendPacket` arriving during `"Handshake"`
  (reproduces Finding B).
- `AckWindow.tla` → finds `ReceiveHandshakeResponse` arriving while already
  `"Established"` (a **new**, previously-unreported finding — see §6.4).
- `SDU.tla` → finds the same `ReceiveHandshakeResponse`-too-late case
  independently.

No finding present in the naive model's design was lost by decomposing.

### 6.4 Final results

```
Naive (one combined check):        4,217 states
Decomposed:  Handshake              56 states
             AckWindow             348 states
             SDU                   152 states
             ------------------------------
             sum                   556 states
             largest single piece  348 states
```

**Peak reduction: 4,217 → 348 states (~12x smaller)** — the number that
actually matters for avoiding memory exhaustion, since TLC's memory pressure
is driven by the largest single check it ever has to hold, not the sum
across separate runs. Total-states reduction (sum) is ~7.6x.

**Honesty caveat, stated explicitly:** at this scale, TLC finished in
well under a second either way — nothing here literally exhausted memory.
The value of this exercise is that it **proves the decomposition method is
correct and loses no findings** on a real, non-trivial composed example,
which is what makes it trustworthy to apply to a section or cluster large
enough to actually risk running out of memory. "Solved" here means "built
and validated a lossless method", not "watched something explode and put it
out."

### 6.5 New findings enabled only by composing sections

> **Finding B — data arriving before handshake completes** (§6.2). A
> `SendPacket`/`ReceiveAck`/etc. event arriving while `phase = "Handshake"`
> is undefined.
>
> **Finding C — stale handshake notification arriving after establishment.**
> A `ReceiveHandshakeResponse` (or, symmetrically, `HandshakeTimeout`)
> arriving while the session is already `"Established"` is undefined —
> e.g. a duplicate/delayed handshake response from a retransmission. Found
> independently by both `AckWindow.tla` and `SDU.tla`.
>
> Both are the mirror image of each other (too early / too late) and both
> are gaps that **an isolated single-section model cannot surface**, since
> they only exist at the boundary between sections.

---

## 7. Modeling conventions: comparison to the existing `ArmFailSafe.tla`

Asked directly whether the same "API"/style was used as the pre-existing
model. Checked carefully rather than assuming:

**Matches exactly:**
- The dispatch pattern: one `pendingMsg`/`pendingEvent` mailbox, one event
  injected at a time via a `ReceiveMessage`/`ReceiveEvent` action.
- Per-event guarded actions (`pendingEvent = "X" /\ <state condition>`).
- The `UndefinedTransition` catch-all and `NeverUndefined` invariant.
- The `.cfg` file format (`SPECIFICATION Spec` / `CONSTANTS` /
  `INVARIANT NeverUndefined`), copied verbatim.

**Deliberate deviations, disclosed:**
- Renamed `pendingMsg`/`Messages` → `pendingEvent`/`Events` (cosmetic).
- Introduced a named `vars ==` tuple and `[][Next]_vars`; `ArmFailSafe.tla`
  inlines its variable tuple directly instead (cosmetic).
- `ArmFailSafe.tla` has no terminal state — it cycles between
  `Armed`/`Disarmed` forever, so it never needed an "ignore events once
  finished" action. The Packet Acknowledgement and PAFTP session protocols
  genuinely terminate (a closed connection), so a
  `ClosedSessionIgnoresEvent`/`ClosedStatusIgnoresEvent`-style action was
  **added** — a new pattern this project introduced, not something carried
  over, because `ArmFailSafe.tla` never had to solve this problem.
- The primary state variable is called `state` in `ArmFailSafe.tla` and in
  `PacketAcknowledgements.tla` (kept identical), but renamed to `phase` (and
  `status` in the decomposed pieces) in the composed PAFTP session model,
  since that model has enough going on that a generic "state" name felt
  overloaded.

---

## 8. Where "cryptographic primitives" fit into this work

Asked directly. Answer: **they don't, and that's deliberate, not an
oversight.** WCDCAnalyzer's soundness argument requires "disjoint
cryptographic primitives" between sub-protocols because it's reasoning about
encryption/hashing operations in a symbolic (Dolev-Yao) model. None of our
models — `ArmFailSafe`, `PacketAcknowledgements`, the PAFTP session — involve
any cryptography at all. Forcing that concept onto a plain timer/counter/
boolean state machine would be a category error. Instead, the actual
criterion used to justify the `AckWindow`/`SDU` split (§6.3) is **disjoint
variables and non-interacting guards** — ordinary TLA+ compositional
reasoning for independent components, unrelated to and not requiring the
cited paper's crypto-specific theorem.

---

## 9. Full file manifest (created/modified today)

```
matter-corpus/tla_models/
  core_4.20.3.8/
    PacketAcknowledgements.tla
    PacketAcknowledgements.cfg
  core_4.19.4.8/
    PacketAcknowledgements.tla
    PacketAcknowledgements.cfg
  core_4.20.3_session/
    PAFTPSessionNaive.tla
    PAFTPSessionNaive.cfg
    PAFTPSessionNaive_CountOnly.cfg
    decomposed/
      Handshake.tla
      Handshake.cfg
      Handshake_CountOnly.cfg
      AckWindow.tla
      AckWindow.cfg
      AckWindow_CountOnly.cfg
      SDU.tla
      SDU.cfg
      SDU_CountOnly.cfg
  SESSION_LOG_2026-09-18.md   (this file)
```

`ArmFailSafe.tla` / `ArmFailSafe.cfg` at the repo root were **not modified**.

---

## 10. Findings summary (for quick reference)

| Finding | Where | What it means | Status |
|---|---|---|---|
| A: stale `AckTimeout` notification | `core_4.20.3.8`, `core_4.19.4.8` | Spec doesn't say what to do with a late timer-expiry notification arriving after the timer was already stopped; same class as `ArmFailSafe`'s existing finding; recurs identically across two transport bindings (Wi-Fi and Bluetooth) | Candidate, needs human review |
| B: data arriving before handshake completes | `core_4.20.3` composed model | Spec doesn't say what should happen if the upper layer tries to send/receive data before the transport handshake finishes | Candidate, needs human review; only visible when sections are composed |
| C: stale handshake response/timeout after establishment | `core_4.20.3` composed model | Spec doesn't say what to do with a duplicate/delayed handshake-phase notification arriving after the session is already established | Candidate, needs human review; only visible when sections are composed |
| D: shutdown procedure barely specified | `core_4.20.3.10` (text only, no TLC needed) | Only 28 words of spec text; no procedure, no peer notification, no frame type referenced | Observation, not a TLC-derived finding |
| — | `core_4.20.3.11` | Content is figure references; diagrams aren't captured by the text-extraction pipeline | Tooling limitation, not a spec finding |

---

## 11. Progress against the 91 ranked candidates

- **Modeled individually:** `core_11.10.7.2` (pre-existing), `core_4.20.3.8`,
  `core_4.19.4.8` — 3 of 91.
- **Modeled as a composed cluster:** `core_4.20.3` (8 of its 11
  subsections), demonstrating the decomposition method end-to-end with real
  before/after numbers.
- **Remaining:** 88 ranked candidates not yet modeled.

## 12. Open items for next session

- Continue through the remaining ranked candidates, using
  `DependencyGraph.closure()` as a standard step *before* modeling each one
  (not retroactively, as happened this session — see §5.1).
- Decide pacing for future sessions (one section reviewed at a time vs.
  batches).
- Findings A–D are candidates for human/thesis-author review, not final
  conclusions — they still need that judgment pass before being written up
  as confirmed underspecifications.
