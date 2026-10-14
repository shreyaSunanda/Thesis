# Review: `core_4.21.4.2` — TRANSPORT command

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 24.68
- module: `models/generated/ch45_v3/core_4.21.4.2/vertex-gemini/core_4_21_4_2.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

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

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ outData = "None"
/\ state = "Idle"
/\ cmdP1P2 = 10
/\ cmdCLA = "0x80"
/\ responderMessageSize = 10
/\ outSW1 = "None"
/\ outSW2 = 0
/\ cmdLc = 10
/\ cmdLe = 20
/\ pendingInput = NoInput

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

</details>

## Spec text for this section

4.21.4.2. TRANSPORT command
Once commissioning has been successfully initiated with the SELECT command, Matter messages
SHALL be exchanged using the proprietary TRANSPORT command. This command is defined by
instruction (INS) code 0x20 with parameters P1 and P2 encoding the length of the message to transmit.
Table 47. TRANSPORT Command APDU
CLA
INS
P1
P2
Lc
Data
Le
0x80 (unchained)
0x90 (chained)
0x20
…
…
…
…
…
• The Lc single-octet field SHALL encode the length in octets of the payload’s Data field in compliance with ISO/IEC 7816-4. To optimize underlying ISO-DEP chaining, Lc SHOULD be less or equal
than min(255,FSC-10).
• P1 and P2 SHALL encode the number of octets of the full message to transmit. It is encoded as a
2-bytes integer with P1 being the most significant byte. In case the full message fits in a single
command, the value is equal to Lc. In case the message requires chaining, the value is bigger
than Lc. The same value SHALL be used in all chained commands.
• The Data field SHALL contain a fragment of the message to transmit, possibly the only one.
• The Le single-octet field SHALL encode the maximum length in octets that the reader/writer can
receive in the response APDU in compliance with ISO/IEC 7816-4. To optimize underlying ISO-
DEP chaining, Le SHOULD encode the value equal to min(256,FSD-6).
The response APDU allows the responder to transmit a message to the initiator. In case the full message fits within the number of bytes encoded by Le in C-APDU, a successful response SHALL be indi­
cated by the SW1 and SW2 values in Table 48.
Table 48. TRANSPORT successful Response APDU - Complete
Data
SW1
SW2
Message or last fragment of message to transmit
0x90
0x00
In case the full message does not fit within the number of bytes encoded by Le in C-APDU, a successful but incomplete response SHALL be indicated by the SW1 value in Table 49, and SW2 SHALL
encode the number of bytes of message to be sent in the next GET RESPONSE R-APDU.
Table 49. TRANSPORT successful Response APDU - Incomplete message
Data
SW1
SW2
Fragment of message to transmit
0x61
…
In case the chained message exceeds the maximum supported message size, an error response conforming to Table 50 SHALL be issued, indicating 'Not enough memory space'.
Table 50. TRANSPORT error Response APDU - Not enough memory space
SW1
SW2
0x6A
0x84
