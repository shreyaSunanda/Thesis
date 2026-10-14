# Review: `core_4.20.3.3` — Session Establishment

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 22.17
- module: `models/generated/ch45_v3/core_4.20.3.3/vertex-gemini/core_4_20_3_3.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

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

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
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
/\ pendingInput = NoInput
/\ msgRequestMaxWindowSize = 0
/\ msgRequestMaxInfoLength = 0

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

</details>

## Spec text for this section

4.20.3.3. Session Establishment
Before a PAFTP session can be initiated, a Commissioner SHALL first establish a WFA-USD connection to a Commissionable Device.
To initiate a PAFTP session, a Commissioner SHALL send a PAFTP handshake request packet to the
Commissionable Device. The handshake request packet SHALL include, a list of PAFTP protocol versions supported by the Commissioner, the Commissioner’s Supported Maximum Service Specific
Info Length, and the Commissioner’s maximum receive window size. The list of supported protocol
versions SHALL be sorted in descending numerical order. For a detailed specification of the handshake request binary data format, see Section 4.20.3.1, “PAFTP Handshake Request”.
Once the Commissionable Device has received a PAFTP handshake request, it SHALL send a PAFTP
handshake response to the Commissioner. This response SHALL contain the window size, maximum selected PAFTP packet size, and PAFTP protocol version selected by the Commissionable
Device. For a detailed specification of the handshake response binary data format, see Section
4.20.3.2, “PAFTP Handshake Response”.
The Commissionable Device SHALL select a window size equal to the minimum of its and the Commissioner’s maximum window sizes. Likewise, the Commissionable Device SHALL select a maxi­
mum PAFTP Segment Size including PAFTP header for the WFA-USD connection by taking the miniMatter Specification R1.6
mum of Supported Maximum Service Specific Info Length received in PAFTP Handshake Request
and locally Supported Maximum Service Specific Info Length by the Commissionable Device.
The Commissionable Device SHALL select a PAFTP protocol version that is the newest which it and
the Commissioner both support, where newer protocol version numbers are strictly larger than
those of older versions. The version number returned in the handshake response SHALL determine
the version of the PAFTP protocol used by Commissionable Device and Commissioner for the duration of the session.
If the Commissionable Device determines that it and the Commissioner do not share a supported
PAFTP protocol version, the Commissionable Device SHALL close its WFA-USD connection to the
Commissioner. When a Commissioner sends a handshake request, it SHALL start a timer with a
globally-defined duration of PAFTP_CONN_RSP_TIMEOUT seconds. If this timer expires before the
Commissioner receives a handshake response from the Commissionable Device, the Commissioner
SHALL close the PAFTP session and report an error to the application.
Figure 30. PAFTP session handshake
