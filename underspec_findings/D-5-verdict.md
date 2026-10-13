# D-5 — Verdict, limits, and how D feeds the thesis

---

## 1. The verdict, stated carefully

**Finding D is a genuine underspecification candidate, and it survives scrutiny.**

It is actually *two* defects that happen to share a section number:

| | Bluetooth §4.19.4.10 | Wi-Fi §4.20.3.10 |
|---|---|---|
| Length | 3 sentences | 28 words |
| Defect type | **M-3 — internal contradiction** | **M-4 — external deferral** |
| What is wrong | Server given two incompatible close mechanisms; one is physically impossible in GATT | Both mechanisms are **MAY**; "terminate the publish/subscribe instance" is never defined in Matter and §4.20.3.10 cross-references nothing |
| Confidence | **High** | **High** |

Supported by three composed findings:

- **D (text defect)** — confirmed by Results 1 and 2 in [D-4](D-4-what-we-found.md).
- **D1 (nothing reaps an idle session)** — confirmed *within the transport layer* by
  Results 3 and 4, and **qualified**: something at the application layer does eventually
  reap it, 6× to 5,760× later than the specification's own bound, in a different chapter,
  for a different reason.
- **D2 (teardown is only ever a link-layer act)** — confirmed by Result 5, by exhaustion.

---

## 2. What we are *not* claiming

This matters as much as what we are claiming. Overclaiming is how a thesis finding gets
destroyed in review.

- **We are not claiming a vulnerability.** We describe a reachable divergence between
  the specification and the implementation and state what follows from it. Whether
  that is severe is a human judgement, informed by a threat model we have not built.
- **We are not claiming the Bluetooth implementation is exploitable.** The scenario —
  a peer completing the handshake, sending one ack, and holding the single endpoint slot
  — is **traced in source, never executed**. We did not build the SDK, did not run a
  device, did not transmit a frame. A real attempt could fail for reasons invisible in
  static reading: BLE link supervision timeouts, controller-level connection limits,
  advertising behaviour, or application policy we did not read.
- **We are not claiming the developers were careless.** Result 4 shows the opposite:
  they found this class of bug themselves and fixed it on one transport. The thesis's
  point is that **the specification did not help them do it on both**, and did not record
  the decision for the next implementer.
- **We are not claiming the Linux behaviour in Result 2 is universal.** We read one
  platform.

---

## 3. What would falsify each claim

Per the review discipline on this project, every finding must say what would kill it.

| Claim | What would falsify it |
|---|---|
| "`BTP_CONN_IDLE_TIMEOUT` is unimplemented" | Finding the constant, or an equivalent idle reaper, under a different name in `src/ble/` or in a platform BLE manager. We searched `src/`, `examples/`, `config/` for `BTP_CONN_IDLE` and `IDLE_TIMEOUT`; a differently-named timer with the same effect would overturn this. |
| "No timer runs on an idle BTP session" | Any timer armed at or after `HandleConnectComplete`/`HandleReceiveConnectionComplete` that we missed, or a platform-level BLE inactivity timer that tears the link down. **The BLE link supervision timeout does not count** — it fires only when the radio link genuinely fails, and a connected attacker keeps it alive. |
| "The peripheral never terminates the BLE connection" | Another platform's `NotifyChipConnectionClosed` that does call `CloseConnection` unconditionally. **Checking Darwin, ESP32 and Zephyr is the single highest-value next step** — and note that either outcome strengthens the thesis: uniform no-op = a SHALL universally unimplemented; divergence = the same SHALL realised differently per platform. |
| "A single peer can hold the only endpoint slot" | A build that sets `BLE_LAYER_NUM_BLE_ENDPOINTS > 1`; or a commissioning-window configuration that is always short; or an application-layer admission control we did not read. Running it would settle it — but running it is outside this investigation's rules. |
| "There is no close frame" | A header flag combination handled somewhere we did not read. We enumerated the flag enums and both dispatch functions, so this is near-certain, but it is the kind of claim that a single overlooked `if` would break. |
| "No code comment acknowledges the ambiguity" | Any comment we missed. Note we **did** find one at the application layer (`CommissioningWindowManager.cpp:433-437`) and reported it — it supports the finding rather than refuting it. |

---

## 4. What changed in our understanding during the investigation

Worth recording, because the thesis methodology says downgrading or revising a prior
belief is a wanted outcome, not a failure.

**We went in expecting:** *"nothing reaps an idle BTP session, therefore a silent peer
holds the only slot forever."*

**We came out with:** *"nothing in the transport layer reaps it. The application layer
does, on a timescale 6× to 5,760× longer than the specification's own constant, through
a mechanism in a different chapter written for a different purpose — and a developer
left a comment saying they knew they had nothing lower to rely on."*

The revised version is **weaker as an alarm and stronger as a thesis finding.** It is
more precise, it is harder to refute, and it now includes a developer admission. Had we
obeyed the folder scope rigidly and never looked at `src/app/server/`, we would have
published the stronger-sounding, wrong claim.

**The transferable lesson:** when the finding is "nothing handles X", you must search
*upward* through the layers before you say it, because the thing that handles X is
usually there — and *where* it turned out to live is itself part of the result.

---

## 5. How Finding D connects to the rest of the thesis

### To the corpus pipeline

Finding D is a **negative result about the ranker**, and that is useful.

`matter-corpus/src/ranking/candidate_ranker.py` scores sections by keyword density
(state-machine, timer, and transport-window vocabulary) and drops anything under
`MIN_WORD_COUNT = 50`.

§4.19.4.10 is **38 words**. §4.20.3.10 is **28 words**. **Both are excluded before
scoring even begins.** Neither can ever appear in `ranked_candidates.json`.

Yet §4.19.4.10 contains an unimplementable **SHALL** — arguably the sharpest single
defect found so far in this thesis.

This is a real, citable limitation of the density-based approach, and it generalises:

> **Underspecification by omission is invisible to a density-based ranker.** The ranker
> finds sections that say a *lot* about state machines. The worst defects are in sections
> that say *too little*. A section cannot score highly on vocabulary it does not contain.

Two concrete follow-ups fall out, and they are cheap:

1. **Add an inverse signal.** Flag sections that are anomalously short *relative to their
   siblings* — §4.19.4.10 is 38 words sitting among siblings of 400–900. A
   "suspiciously brief normative section" detector would have surfaced D automatically.
2. **Add an orphaned-constant check.** `BTP_CONN_IDLE_TIMEOUT` is defined in Table 35 and
   referenced by **no normative sentence anywhere in §4.19**. A cross-reference pass over
   the constant tables, asking "is every constant actually used by a SHALL somewhere?",
   is mechanical and would have found Result 3 from the spec alone — without reading any
   code.

Both are implementable against the existing `sections.json` and `dependency_graph.json`.

### To the TLA+ modelling pipeline

Finding D is close to a **perfect fit** for the formal-modelling half of the thesis, in a
way most candidates are not.

Recall how the gap signal works (`CLAUDE.md`, and `src/validation/`): a generated TLA+
model is checked with TLC, and **a deadlock — a reachable state with no enabled `Next`
action — is the finding.** It means the model reached a state and the specification text
supplied no way out.

Finding D is *literally that*, in English:

> The session reaches `CONNECTED`. The peer stops sending. No timer is armed. No close
> frame exists. **There is no enabled transition.**

A model of §4.19.4.10 composed with §4.19.4.8 should deadlock in exactly that state —
and the deadlock would be a *true* finding, not a modelling artefact. That makes D an
excellent **validation case for the pipeline itself**: a candidate where we already know,
from independent source-code evidence, what TLC ought to report.

This is worth stating plainly in the thesis, because it closes a loop:

- the **corpus ranker** could not find D (too short — see above);
- **manual spec reading** found D;
- **source-code forensics** confirmed D and dated it to a real maintainer-acknowledged
  DoS fix;
- **TLA+ model checking** should independently re-derive D as a deadlock.

Four methods, one finding, and the one that failed tells you something specific about its
own blind spot. That is a stronger methodology chapter than four methods that all agree.

---

## 6. Suggested next steps, in priority order

1. **Check `NotifyChipConnectionClosed` on Darwin, ESP32 and Zephyr** (Result 2). Cheap,
   and either outcome strengthens the finding.
2. **Model §4.19.4.10 + §4.19.4.8 in TLA+** and check whether TLC produces the predicted
   deadlock. This validates the pipeline against a known answer.
3. **Add the two ranker signals** from §5 above (short-section anomaly; orphaned
   constant) and re-run the corpus. See whether they surface D, and what else they
   surface — the orphaned-constant check in particular is likely to find siblings.
4. **Search for the same asymmetry elsewhere.** `src/wifipaf/` has received security
   hardening that `src/ble/` has not (commit `650c569666` here; and the window-size fixes
   recorded in the brief: `c3480ff4d4`, `28e77bdbc9`, `5b4abe1fe1`). Enumerating every
   such one-sided fix is a systematic way to generate further candidates — each one is a
   place where the specification failed to say something clearly enough for both ports to
   get it right.

---

## 7. One-paragraph version, for the thesis body

> Matter §4.19.4.10 specifies BTP session teardown in three sentences, one of which
> requires the GATT server to unsubscribe from its own characteristic — an operation GATT
> does not define for that role — while a third sentence gives the same role a different
> and incompatible mechanism. The reference implementation silently adopts the only
> coherent reading, without recording the ambiguity
> (`src/ble/BleLayer.cpp:573-585`, error `BLE_ERROR_CENTRAL_UNSUBSCRIBED`). The
> specification's own `BTP_CONN_IDLE_TIMEOUT` (§4.19.5, Table 35, 30 s) is referenced by
> no normative sentence and is absent from the implementation entirely; the sibling PAFTP
> port defines it from the spec's own wording
> (`src/wifipaf/WiFiPAFConfig.h:137-145`) and then consumes it as an unrelated retry
> budget (`src/wifipaf/WiFiPAFEndPoint.cpp:76`). Because neither transport defines any
> close, reset, or management frame — the handshake is the only control frame in both,
> and PAFTP reserves a management opcode its code never reads
> (`src/wifipaf/WiFiPAFEndPoint.cpp:859, 893`) — timers are the only defence against a
> peer that simply stops responding. PAFTP arms one after its handshake, with the comment
> *"Arm ongoing idle session supervision"* (`WiFiPAFEndPoint.cpp:161-163`), added in
> commit `650c569666` (16 June 2026) whose message reads *"Resolve endpoint pool
> exhaustion DoS via missing timer"*. BTP arms none, and its endpoint pool default is one
> (`src/ble/BleConfig.h:78`) against PAFTP's two. Two ports of the same specification
> text, in the same repository, resolve the same silence in opposite directions — the
> defining signature of underspecification.
