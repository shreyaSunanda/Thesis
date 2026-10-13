# D-2 — What the candidate underspecification was, and what is happening there

Candidate D is about **how a BTP or PAFTP session is closed** — how the two devices
hang up.

There are two spec sections involved, one per transport. Both are extremely short. That
shortness is itself the story: hanging up is treated as an afterthought in a document
that spends six pages on how to number packets.

---

## Part 1 — The Bluetooth side: §4.19.4.10, printed spec page 235

Here is the **entire section**, word for word. Four sentences. That is all the Matter
specification says about closing a Bluetooth session:

> **4.19.4.10. Connection Shutdown**
>
> To close a BTP session, a GATT client SHALL unsubscribe from characteristic C2. The
> GATT server SHALL take this action to indicate closure of any BTP session open to the
> client. If a BTP Server needs to close the BTP session, it SHALL terminate its BLE
> connection to the client.

(That is three sentences plus the heading. Printed page 235 = PDF page 239.)

Let us take the sentences one at a time.

### Sentence 1 — fine

> "To close a BTP session, a GATT client SHALL unsubscribe from characteristic C2."

The phone (client) stops asking to be notified about drawer C2. Perfectly sensible, and
perfectly implementable. The server sees the unsubscribe arrive and knows the
conversation is over.

### Sentence 2 — **impossible**

> "The GATT server SHALL take **this action** to indicate closure of any BTP session
> open to the client."

"This action" can only refer back to the action just named: *unsubscribing from
characteristic C2*.

But recall from [D-1 §3](D-1-background-for-newcomers.md): **in GATT, subscribing and
unsubscribing are operations a client performs on a server's characteristic.** A server
has no such operation available to it. C2 is the server's *own* drawer. A server cannot
unsubscribe from its own drawer any more than you can phone yourself.

This is a mandatory requirement (**SHALL**) that **cannot be complied with**. Any
implementer hitting this sentence must guess what was meant.

There are at least three plausible readings, and they produce different systems:

| Reading | What the server would do | Consequence |
|---|---|---|
| **(a)** "The server shall *treat* a received unsubscribe as closure" — a sloppy way of saying the server is the one who observes sentence 1 | Close the session when an unsubscribe arrives | Sensible. Probably the intent. |
| **(b)** The server should force the client to unsubscribe somehow | No such mechanism exists | Dead end |
| **(c)** Typo for "The GATT **client** SHALL take this action..." | Duplicate of sentence 1 | Harmless but redundant |

The specification gives you no way to decide between them. That is underspecification by
definition.

### Sentence 3 — contradicts sentence 2

> "If a BTP Server needs to close the BTP session, it SHALL terminate its BLE connection
> to the client."

Now the server is given a **completely different** mechanism: kill the radio link
entirely.

So within three sentences, the server is told to close sessions **two different ways**:

1. by unsubscribing (sentence 2) — impossible, and would only end the *session*;
2. by terminating the BLE connection (sentence 3) — possible, but a much bigger hammer,
   killing the *radio link* too.

These are not the same act. Recall [D-1 §4](D-1-background-for-newcomers.md): a session
is software, a connection is radio. Sentence 2's mechanism (if it worked) would leave
the radio link up. Sentence 3's mechanism tears it down. A client watching the bulb
cannot tell which behaviour to expect.

**This is an M-3: internal contradiction.** Two sentences in the same paragraph specify
incompatible behaviour for the same role, and one of them is unimplementable.

### What is NOT specified anywhere

Beyond the contradiction, notice everything the section never mentions:

- **No timeout.** Nothing says how long an unused session may sit there.
- **No in-band "goodbye" message.** There is no BTP packet type meaning "I'm closing".
  Compare TCP, which has a `FIN` flag for exactly this.
- **No required cleanup.** It does not say the server must free resources, forget
  sequence numbers, or become available to a new client.
- **No statement of what the peer observes.** If the server terminates the BLE
  connection, how does the client distinguish "deliberate close" from "the bulb lost
  power" or "I walked out of range"? Not stated.

---

## Part 2 — The Wi-Fi side: §4.20.3.10, printed spec page 251

The equivalent section for the Wi-Fi transport is **28 words long**:

> **4.20.3.10. Connection Shutdown**
>
> A Commissioner MAY terminate the subscribe instance, to close a PAFTP session. A
> Commissionable Device MAY terminate the publish instance, to close a PAFTP session.

(Printed page 251 = PDF page 255. "Commissioner" = the phone. "Commissionable Device" =
the bulb.)

Read the modal verbs. Both sentences use **MAY** — optional. See
[D-1 §8](D-1-background-for-newcomers.md).

So for PAFTP there is **no required way to close a session at all.** The spec says the
two parties are *permitted* to do a thing. It never says anyone *must* do anything, and
never says what happens if nobody does.

### The deferral problem

"subscribe instance" and "publish instance" are not Matter concepts. They come from
**Wi-Fi Aware** (also called NAN, Neighbor Awareness Networking), a different standard
owned by the Wi-Fi Alliance. In that world, a device "publishes" a service and others
"subscribe" to it.

The phrases *are* used elsewhere in the Matter spec (§5.4.2.6.3 on printed page 323,
§5.4.3.2 on printed page 327), so they are not undefined words. But:

- No Matter section defines what **terminating** one of those instances means.
- No Matter section says what **the peer observes** when it happens — does it get a
  notification? Silence? An error?
- §4.20.3.10 **cross-references neither** of those sections.

So the rule is handed off to a document outside Matter, without saying which part of
that document to read or what it requires. **This is an M-4: external deferral.**

Note this is a *different* defect from the Bluetooth one. Bluetooth over-specifies
incoherently (M-3). Wi-Fi under-specifies by punting (M-4). Same section number, same
topic, two different failure modes.

---

## Part 3 — Why this is worth investigating at all (the "so what")

A vague sentence only matters if something bad can follow from it. Here is the chain of
reasoning that turned "this paragraph is sloppy" into "this is worth a week's work".

**Step 1.** The only thing that can end a BTP session is: a client unsubscribe, a radio
disconnection, or a timer firing. (There is no goodbye message — see
[D-1 §5](D-1-background-for-newcomers.md).)

**Step 2.** A hostile peer will obviously never unsubscribe, and will never disconnect
its radio. So for a hostile peer, **only a timer can save you.**

**Step 3.** But the ack-received timer **stops** once everything has been acknowledged
(§4.19.4.8, quoted in D-1 §5). A peer that completes the handshake, sends one
acknowledgement, and then goes permanently silent leaves **no timer running**.

**Step 4.** The spec seems to know this — it defines `BTP_CONN_IDLE_TIMEOUT` (30 s) in
§4.19.5 Table 35 for exactly this situation. But §4.19.4.10 "Connection Shutdown"
**never mentions it**. The constant is defined in a glossary and then orphaned. No
normative sentence anywhere tells anyone to start that timer.

**Step 5.** A bulb has a very small endpoint pool. If one silent stranger holds the only
slot, the legitimate owner cannot commission their own device —
[D-1 §7](D-1-background-for-newcomers.md).

So the research questions became:

> **D1** — Does anything in the real implementation actually reap an idle or silent
> session? Or can a connected-but-silent peer hold a slot indefinitely?
>
> **D2** — Is teardown **only ever** a link-layer act? Is it true that neither transport
> has any protocol-level close message? (This is a *finite, checkable* question: the set
> of frame types is small and enumerable.)

Those two questions are what we took into the source code.

---

Next: [D-3-the-search.md](D-3-the-search.md) — exactly what we searched for and where.
