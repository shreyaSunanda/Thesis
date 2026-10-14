# Review: `core_4.19.4.3` — Session Establishment

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 4
- ranker score: 33.81
- module: `models/generated/ch45_v4/core_4.19.4.3/vertex-gemini/core_4_19_4_3.tla`

### Under ClientKnowsATT_MTU=True

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = FALSE
/\ pendingInput = "DPLE_Update"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ bleConnectionActive = FALSE
/\ pendingInput = NoInput
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE

State 2: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = FALSE
/\ pendingInput = "DPLE_Update"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE
```

</details>

### Under ClientKnowsATT_MTU=True

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 4: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = TRUE
/\ pendingInput = "BLE_Connect"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "BLE_CONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "BLE_CONNECTED"
/\ clientErrorReported = FALSE
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ bleConnectionActive = FALSE
/\ pendingInput = NoInput
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE

State 2: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = FALSE
/\ pendingInput = "BLE_Connect"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE

State 3: <BLE_Connect_Action line 91, col 5 to line 98, col 187 of module core_4_19_4_3>
/\ bleConnectionActive = TRUE
/\ pendingInput = NoInput
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "BLE_CONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "BLE_CONNECTED"
/\ clientErrorReported = FALSE

State 4: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = TRUE
/\ pendingInput = "BLE_Connect"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "BLE_CONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "BLE_CONNECTED"
/\ clientErrorReported = FALSE
```

</details>

### Under ClientKnowsATT_MTU=False

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = FALSE
/\ pendingInput = "DPLE_Update"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ bleConnectionActive = FALSE
/\ pendingInput = NoInput
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE

State 2: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = FALSE
/\ pendingInput = "DPLE_Update"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE
```

</details>

### Under ClientKnowsATT_MTU=False

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 4: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = TRUE
/\ pendingInput = "BLE_Connect"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "BLE_CONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "BLE_CONNECTED"
/\ clientErrorReported = FALSE
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ bleConnectionActive = FALSE
/\ pendingInput = NoInput
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE

State 2: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = FALSE
/\ pendingInput = "BLE_Connect"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "DISCONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "DISCONNECTED"
/\ clientErrorReported = FALSE

State 3: <BLE_Connect_Action line 91, col 5 to line 98, col 187 of module core_4_19_4_3>
/\ bleConnectionActive = TRUE
/\ pendingInput = NoInput
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "BLE_CONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "BLE_CONNECTED"
/\ clientErrorReported = FALSE

State 4: <ReceiveInput line 84, col 5 to line 87, col 234 of module core_4_19_4_3>
/\ bleConnectionActive = TRUE
/\ pendingInput = "BLE_Connect"
/\ serverErrorReported = FALSE
/\ rspWindow = 0
/\ rspVersion = 0
/\ reqMtu = 0
/\ rspMaxSegmentSize = 0
/\ reqWindow = 0
/\ clientTimerActive = FALSE
/\ serverState = "BLE_CONNECTED"
/\ serverTimerActive = FALSE
/\ reqVersions = <<>>
/\ c2Subscribed = FALSE
/\ clientState = "BLE_CONNECTED"
/\ clientErrorReported = FALSE
```

</details>

## Spec text for this section

4.19.4.3. Session Establishment
Before a BTP session can be initiated, a central SHALL first establish a BLE connection to a peripheral. Once a BLE connection has been formed, centrals SHALL assume the GATT client role for BTP
session establishment and data transfer, and peripherals SHALL assume the GATT server role. If
peripheral supports LE Data Packet Length Extension (DPLE) feature it SHOULD perform data
length update procedure before establishing a GATT connection.
Before establishing a BTP session, the GATT client SHOULD perform a GATT Exchange MTU procedure.
After that the BTP Client SHALL execute the GATT discovery procedure. The GATT discovery procedure starts with primary service discovery using either the GATT Discover All Primary Services sub-
procedure or the GATT Discover Primary Services by Service UUID sub-procedure.
The BTP Client SHALL perform either the GATT Discover All Characteristics of a Service sub-procedure or the GATT Discover Characteristics by UUID sub-procedure in order to discover the C1 and
C2 characteristics.
The BTP Client SHALL perform the GATT Discover All Characteristic Descriptors sub-procedure in
order to discover the Client Characteristic Configuration descriptor (CCCD) of C2 characteristic.
To initiate a BTP session, a BTP Client SHALL send a BTP handshake request packet to the BTP
Server via a ATT_WRITE_REQ PDU on characteristic C1 of the BTP Service. The handshake request
packet SHALL include, a list of BTP protocol versions supported by the client, the client’s GATT
ATT_MTU, and the client’s maximum receive window size. The list of supported protocol versions
SHALL be sorted in descending numerical order. If the client cannot determine the BLE connection’s ATT_MTU, it SHALL specify a value of '23' (the minimum ATT_MTU supported by GATT) for
this field in the handshake request. For a detailed specification of the handshake request binary
data format, see Section 4.19.3.1, “BTP Handshake Request”.
After the BTP Client acknowledges delivery of the handshake request packet, upon receipt of a
GATT Write Response, the BTP Client SHALL enable indications over C2 characteristics by writing
value 0x01 to C2’s Client Characteristic Configuration descriptor as described in Bluetooth® Core
Specification 4.2 (amended) Vol 3, Part C, Section 10.3.1.1 "Handling of GATT Indications and Notifications".
Once the GATT server has received a client’s BTP handshake request and confirmed the client’s subscription to C2, it SHALL send a BTP handshake response to the client via a ATT_HANDLE_VAL­
UE_IND PDU on C2. This response SHALL contain the window size, maximum BTP packet size, and
BTP protocol version selected by the server. For a detailed specification of the handshake response
binary data format, see Section 4.19.3.2, “BTP Handshake Response”.
The server SHALL select a window size equal to the minimum of its and the client’s maximum window sizes. Likewise, the server SHALL select a maximum BTP Segment Size for the BLE connection
by taking the minimum of 244 bytes (the maximum characteristic value length of C1 and C2),
server’s ATT_MTU-3 and ATT_MTU-3 as declared by the client.
The server SHALL select a BTP protocol version that is the newest which it and the client both support, where newer protocol version numbers are strictly larger than those of older versions. The
version number returned in the handshake response SHALL determine the version of the BTP protocol used by client and server for the duration of the session.
If the server determines that it and the client do not share a supported BTP protocol version, the
server SHALL close its BLE connection to the client. When a client sends a handshake request, it
SHALL start a timer with a globally-defined duration of BTP_CONN_RSP_TIMEOUT seconds. If this
timer expires before the client receives a handshake response from the server, the client SHALL
close the BTP session and report an error to the application. Likewise, a server SHALL start a timer
with the same duration when it receives a handshake request from a client. If this timer expires
before the server receives a subscription request on C2, the server SHALL close the BTP session and
report an error to the application. The state machine in Figure 23, “BTP session handshake” illustrates the function of these timers as part of the BTP session establishment procedure.
Figure 23. BTP session handshake
