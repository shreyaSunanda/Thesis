# Review: `core_4.23.3.1` — Advertisement from Commissionee

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 22.74
- module: `models/generated/ch45_v3/core_4.23.3.1/vertex-gemini/core_4_23_3_1.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 36, col 5 to line 39, col 43 of module core_4_23_3_1>
/\ state = "Idle"
/\ retransmitCount = 0
/\ pendingInput = "CommissioningMessageReceived"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "Idle"
/\ retransmitCount = 0
/\ pendingInput = NoInput

State 2: <ReceiveInput line 36, col 5 to line 39, col 43 of module core_4_23_3_1>
/\ state = "Idle"
/\ retransmitCount = 0
/\ pendingInput = "CommissioningMessageReceived"
```

</details>

## Spec text for this section

4.23.3.1. Advertisement from Commissionee
Upon selecting a Joiner Router, the Commissionee SHALL use a DNS Announcement to make itself
discoverable. The Commissionee SHALL send an unsolicited DNS Query Response message with
Transaction ID 0. This message SHALL contain information as specified in Section 4.3.1, “Commissionable Node Discovery”. The DNS Announcement SHALL be sent in-line with the restrictions
imposed by the Thread commissioning protocol, i.e., it shall be sent to the link-local address of the
Joiner Router, with the destination UDP port MJ as specified in the Discovery Response message. No
response to this message is expected from the Commissioner.
After sending the DNS Announcement, the Commissionee SHALL await an incoming commissioning
message (see Section 4.14.1, “Passcode-Authenticated Session Establishment (PASE)”) for no less
than 5000 milliseconds. If the commissioning session does not begin to be established within that
time window, the device SHOULD retransmit the DNS Announcement. The device SHOULD retransmit the DNS Announcement up to 3 times with a 1250 millisecond interval between retransmis­
sions.
If after the retransmissions the commissioning session still does not begin to be established, the
device SHOULD attempt to find a different Joiner Router using the procedure described in the subsection above.
NOTE
The timeouts and retransmission counts selected above are subject to fine-tuning.
The 1250 millisecond interval is chosen to align with typical network discovery
retransmission patterns. Per Thread specification, the Commissionee will spend at
least 300ms on each channel.
