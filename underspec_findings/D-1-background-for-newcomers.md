# D-1 — Background: every word you need, explained from zero

You said you do not know the terms. So this file assumes **nothing**. If you already
know a section, skip it.

---

## 1. What is Matter, and what is "commissioning"?

**Matter** is a standard that lets a smart bulb from one company talk to a hub from
another company. It is written down as a very long PDF called the **Matter Core
Specification** (1335 pages, version 1.6).

**Commissioning** is the technical word for *"adding a new device to your home"*. You
unbox a bulb, open an app, scan a QR code, and 20 seconds later the bulb is on your
Wi-Fi and under your control. Everything that happens in those 20 seconds is
commissioning.

The crucial fact for security: **a brand-new bulb is not yet on your Wi-Fi.** So the
phone and the bulb need a *temporary* way to talk, just long enough to pass the Wi-Fi
password across. Matter offers two such temporary channels:

| Channel | Radio used | Spec chapter | Source code folder |
|---|---|---|---|
| **BTP** — Bluetooth Transport Protocol | Bluetooth Low Energy | §4.19 | `src/ble/` |
| **PAFTP** — Publish-And-Find Transport Protocol | Wi-Fi Aware / NAN | §4.20 | `src/wifipaf/` |

These two are near-copies of each other. `src/wifipaf/` was written later by copying
`src/ble/` and adapting it. **That is the single most useful fact in this whole
investigation**, and I will come back to it. When two copies of the same idea resolve
the same vague sentence *differently*, the vagueness is proven, not merely suspected.

---

## 2. Why "before PASE" is the phrase that makes this a security topic

**PASE** = *Password-Authenticated Session Establishment*. It is the moment the phone
proves it knows the setup code from the QR sticker, and from then on the two devices
share a secret and everything is encrypted and authenticated.

**BTP and PAFTP both run BEFORE PASE.**

Think about what that means. Before PASE:

- The bulb has **no idea who it is talking to.**
- **Anyone** within radio range can open a BTP session with it — a neighbour, someone
  in a parked car, a laptop in the next flat.
- Every byte the bulb processes at this stage came from an **unauthenticated** stranger.

So any rule that is vague in §4.19 or §4.20 is a rule that a stranger gets to exploit the
ambiguity of. That is why these two chapters are the thesis's hunting ground.

---

## 3. Bluetooth Low Energy (BLE): the four words that confuse everyone

BLE has **two separate pairs of roles**, and people mix them up constantly. The
specification sentence we are investigating mixes them up too — that is literally the
bug.

### Pair 1: who started the radio connection?

- **Central** — the device that *dialled*. Your phone.
- **Peripheral** — the device that *was dialled*. The bulb.

Think of it as: central = caller, peripheral = receiver. This is about the **radio
link**.

### Pair 2: who owns the data?

BLE organises data using a system called **GATT** (Generic Attribute Profile). Picture a
filing cabinet:

- **GATT server** — the device that *owns the filing cabinet*. It holds the drawers.
- **GATT client** — the device that *reaches into someone else's cabinet* to read or
  write a drawer.

Each drawer is called a **characteristic**. Matter defines two that matter here:

- **C1** — the drawer the phone *writes into* to send data to the bulb.
- **C2** — the drawer the bulb uses to *push data back* to the phone.

In Matter, the specification fixes the pairing (§4.19.4.3):

> centrals SHALL assume the GATT client role [...] and peripherals SHALL assume the GATT
> server role

So for us, always:

```
  phone  =  central  =  GATT client   (dialled; reaches into the cabinet)
  bulb   =  peripheral = GATT server  (was dialled; owns the cabinet)
```

### Subscribe / unsubscribe — and why direction matters

The bulb cannot just shout at the phone whenever it likes. The phone must first say
"please notify me when drawer C2 changes". That act is called **subscribing**.

**Subscribing is something a GATT client does to a GATT server's characteristic.**
It is a one-way street, by the design of Bluetooth itself. The client subscribes. The
server gets subscribed-to. A server **cannot subscribe to its own drawer** — the
sentence does not even typecheck. Remember this; it is the heart of Finding D.

In the code these are two different functions, and you can see the direction baked in:

- `SubscribeCharacteristic()` / `UnsubscribeCharacteristic()` — the **client** calls
  these.
- `HandleSubscribeReceived()` / `HandleUnsubscribeReceived()` — the **server** is
  *told* that this happened to it.

---

## 4. "Session" vs "connection" — two different things that can outlive each other

This distinction is the second half of Finding D, so be slow here.

- A **BLE connection** is a *radio* fact. Two chips have agreed on a timing pattern and
  are exchanging packets. Think: the phone line is physically off the hook.
- A **BTP session** is a *software* fact layered on top. Think: the two people on the
  line have agreed what language they are speaking and have started counting their
  sentences.

They can come apart. You can **end the conversation but leave the line open**. The
radio connection survives. And a radio connection that nobody is using still costs the
bulb real resources — a tiny Bluetooth chip can usually hold only **one**.

---

## 5. Sequence numbers, acknowledgements, and timers

BTP numbers every packet: 0, 1, 2, ... up to 255, then back to 0. The receiver sends
back an **acknowledgement** ("ack") saying "I got up to number N".

Two timers govern this (§4.19.4.8):

- **acknowledgement-received timer** — "I sent something; if nobody acks it within
  `BTP_ACK_TIMEOUT` (15 s), the other side is dead, so hang up."
- **send-acknowledgement timer** — "I received something; I must ack it within half the
  ack timeout, or the other side will think I am dead."

Here is the subtle part that Finding D turns on. **The ack-received timer only runs
while you are waiting for an ack.** The spec says so explicitly:

> A peer SHALL **stop** its acknowledgement-received timer if it receives an
> acknowledgement for its most recently sent unacknowledged packet.

So once everything you sent has been acknowledged, **that timer stops**. If both sides
then go quiet, *no timer is running at all*. Nothing is watching the session.

The spec appears to have anticipated this: §4.19.5 Table 35 defines a **third**
constant,

> **BTP_CONN_IDLE_TIMEOUT** — "The maximum amount of time no unique data has been sent
> over a BTP session before the Central Device must close the BTP session." Default:
> **30 seconds.**

That constant exists to plug exactly this hole. Hold that thought — in D-4 you will see
that it does not exist in the code.

---

## 6. "Endpoint", and what an "endpoint pool" is

In the Matter source code, an **endpoint** is the C++ object that represents *one
ongoing conversation*. It holds the sequence numbers, the timers, the half-received
message, and so on. (Confusingly, Matter also uses "endpoint" to mean a logical device
inside a bulb. Different meaning. Here it means a transport conversation object.)

Small devices cannot allocate memory freely, so these objects are pre-allocated in a
fixed-size array called a **pool**. For Bluetooth that array is sized by a constant
called `BLE_LAYER_NUM_BLE_ENDPOINTS`.

If the pool is full and a new stranger tries to connect, there is no object to give
them, and they are refused.

---

## 7. "Denial of service" (DoS), in one paragraph

A **denial-of-service** attack is not about stealing data. It is about **taking up the
only chair in the room so the legitimate person cannot sit down.** If the bulb can only
hold one commissioning conversation at a time, and an attacker occupies that one slot
and then says nothing, the real owner cannot commission their own bulb. No secrets are
leaked. The device is simply unusable.

The reason this connects to timers: the defence against someone occupying a slot and
going silent is **a timer that reclaims the slot**. No timer, no defence.

---

## 8. "SHALL", "SHOULD", "MAY" — the grammar of specifications

Specifications use these three words with strict meanings (from a standard called
RFC 2119):

- **SHALL** / **MUST** = mandatory. An implementation that does not do this is
  non-compliant.
- **SHOULD** = recommended. You may skip it if you have a good reason.
- **MAY** = entirely optional.

This matters for Finding D because:

- The Bluetooth shutdown section is written with **SHALL** (mandatory) — but one of the
  mandatory sentences is impossible.
- The Wi-Fi shutdown section is written with **MAY** (optional) — which means the spec
  declines to require *any* way of closing a session at all.

Both are defects, of opposite kinds.

---

## 9. What "underspecification" actually means in this thesis

Not "the spec has a bug". Specifically: **the written rules do not determine the
behaviour.** Two engineers can read the same sentence, both follow it in good faith, and
build systems that behave differently.

The thesis classification scheme (which you've seen on Finding C as "M-2", "M-4") labels
*how* the text fails:

| Code | Meaning | Plain English |
|---|---|---|
| **M-1** | Undefined term | A word is used but never defined. |
| **M-2** | Composed / cross-section | No single sentence is wrong, but combining sections leaves a case uncovered. |
| **M-3** | Internal contradiction | Two sentences in the same place conflict. |
| **M-4** | External deferral | The spec hands the rule off to another standard without saying what that standard requires. |

Finding C was **M-2**. Finding D, as you'll see, is **M-3** on the Bluetooth side and
**M-4** on the Wi-Fi side.

### The evidence ladder — strongest to weakest

This is the quality ranking we use when judging a finding:

1. **Strongest** — spec is silent, and **the two sibling implementations chose
   *differently*.** This is proof, not opinion: two competent teams read the same text
   and diverged.
2. **Strong** — spec is silent, and a **code comment or commit message admits** the
   developer was guessing or found a problem.
3. **Moderate** — spec is silent, and the code quietly chose one behaviour with no
   acknowledgement.
4. **Weak** — spec looks silent, but the rule is actually defined somewhere else in the
   document. *This is a false positive and must be discarded.*

Finding D produces evidence at levels 1, 2, **and** 3 simultaneously. That is what makes
it a good finding.

---

Next: [D-2-the-candidate.md](D-2-the-candidate.md) — the actual spec text, and what is
wrong with it.
