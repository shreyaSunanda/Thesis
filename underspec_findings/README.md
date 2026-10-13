# Finding D — Session Teardown in Matter's BTP and PAFTP transports

**Written for: Sunanda, as a newcomer to security / protocol work.** Every term is
explained the first time it appears. Nothing assumes you already know BLE, GATT, or C++.

This folder is the full teaching write-up of **underspecification candidate D**, the
sibling of candidate C (which you already understand).

Read the files in order. Each one answers one of your questions.

| File | Answers the question |
|---|---|
| [D-1-background-for-newcomers.md](D-1-background-for-newcomers.md) | What are all these words? BLE, GATT, central, peripheral, session, commissioning, DoS... |
| [D-2-the-candidate.md](D-2-the-candidate.md) | **What was the candidate underspecification, and what is happening there?** |
| [D-3-the-search.md](D-3-the-search.md) | **What did we search for, and where?** (spec pages + code files + git commands) |
| [D-4-what-we-found.md](D-4-what-we-found.md) | **What did we find out?** Every claim with a `file:line` citation. |
| [D-5-verdict.md](D-5-verdict.md) | How confident are we, what would prove us wrong, and how this feeds the thesis. |

---

## The 30-second version

The Matter specification has a section, §4.19.4.10 "Connection Shutdown", that tells two
devices how to **hang up** on each other. It is **four sentences long**. One of those
sentences tells a device to do something that is physically impossible for it to do.

We went into the official Matter source code (`connectedhomeip`, the "CHIP tool"
codebase) to see what real programmers did when faced with that sentence. We found:

1. The code **silently corrects** the impossible sentence — and never writes down that
   it did so.
2. One of the specification's three official timing constants for this transport,
   `BTP_CONN_IDLE_TIMEOUT`, **does not exist anywhere in the implementation.**
3. The sister transport (PAFTP, over Wi-Fi) **does** define that constant — and then
   uses it for something completely different.
4. In June 2026 the developers fixed a **denial-of-service** bug in the Wi-Fi transport
   caused by exactly this missing-timer problem. They did **not** apply the same fix to
   the Bluetooth transport, which has a smaller resource pool (1 slot vs 2).
5. Neither transport has any "goodbye" message. Hanging up is never a protocol action —
   it is always a radio-layer or application-layer action. The specification never says
   this out loud.

All five points are evidence of **underspecification**: the written rules do not
determine the behaviour, so each implementer invents their own, and the inventions
differ.

---

## Ground rules this investigation followed

These come from `CLAUDE.local.md` in the `connectedhomeip` checkout, and they are worth
knowing because they are what makes the result trustworthy:

- **Read-only.** Nothing in the Matter source code was modified, and nothing was
  compiled or executed. Every statement below comes from *reading* code.
- **No citation, no claim.** Every factual sentence names a file and a line number, or a
  git commit hash.
- **"The code got it right and the spec is still vague" is a wanted result**, not a
  failure. We are documenting the specification's silence, not hunting for bugs.
- **Never upgrade a divergence into a claimed vulnerability.** We describe what differs
  and what follows from it. Judging severity is a human's job.

Code state: commit `8b3bd4fcc49ce8b51b4b0b753d032ce52d07f716`, fast-forwarded 2026-10-08.
Spec: Matter Core Specification R1.6, CSA Doc 23-27349, 16 June 2026.
