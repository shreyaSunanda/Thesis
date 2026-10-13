# D-4 — What we found out

Everything here was established **by reading** code at commit `8b3bd4fcc4`. Nothing was
compiled, nothing was executed, no device was touched. Every claim carries a
`file:line`.

Five results. Each one is explained twice: first the plain-English version, then the
evidence.

---

## Result 1 — The code silently fixes the impossible sentence, and never says so

**Plain English.** Remember sentence 2 of §4.19.4.10: *"The GATT server SHALL take this
action [unsubscribe from C2]."* A server cannot do that. The implementers clearly
realised this, because they implemented the only interpretation that is physically
possible — reading (a) from [D-2](D-2-the-candidate.md): *"the server closes the session
when it is told the client unsubscribed."* And you can see them thinking it, because of
how they **named the error**.

**Evidence.** `src/ble/BleLayer.cpp:573-585`:

```cpp
bool BleLayer::HandleUnsubscribeReceived(BLE_CONNECTION_OBJECT connObj, ...)
{
    ...
    BLEEndPoint * endPoint = sBLEEndPointPool.Find(connObj);
    VerifyOrReturnError(endPoint != nullptr, false, ...);

    endPoint->DoClose(kBleCloseFlag_AbortTransmission, BLE_ERROR_CENTRAL_UNSUBSCRIBED);
    return true;
}
```

Look at the error constant: **`BLE_ERROR_CENTRAL_UNSUBSCRIBED`**. Not
`SERVER_UNSUBSCRIBED`. Not `PEER_UNSUBSCRIBED`. The name states, as a fact baked into
the API, that **the central (= the GATT client) is the one who unsubscribes.**

That is the implementation flatly asserting the opposite of what the spec sentence says.

**Why this matters for the thesis.** This is the *quiet* kind of underspecification —
and the most dangerous kind to leave unrecorded. There is **no comment** at
`BleLayer.cpp:573-585` saying "the spec says the server unsubscribes, which is
impossible, so we assume it meant this." We swept both transport folders for exactly
such an admission (Search 8 in [D-3](D-3-the-search.md)) and found only six unrelated
`TODO`s about buffer sizes. The correction is invisible. A second implementer, reading
the same spec sentence, has nothing to tell them which way the reference
implementation jumped.

**Classification: M-3 (internal contradiction). Confidence: High.**

---

## Result 2 — The server's *only* workable close mechanism is conditional on a flag the spec has never heard of

**Plain English.** Sentence 3 of §4.19.4.10 gives the server a real mechanism: *"it
SHALL terminate its BLE connection to the client."* Kill the radio link. That one is
implementable.

We traced whether the code actually does it. **In the normal build, on the bulb's side,
it does not** — at least not anywhere inside the Matter transport stack. The decision is
handed off, via a flag called `autoClose` that appears nowhere in the specification, to
the application, and from there to platform code that mostly declines to act.

**Evidence — step by step down the call chain.**

**(a)** The role split lives in `BLEEndPoint::FinalizeClose`, `src/ble/BLEEndPoint.cpp:354`.
If the device is the **central** (the phone) it signals the close over the air by
unsubscribing — exactly sentence 1 — at `src/ble/BLEEndPoint.cpp:389`:

```cpp
err = mBle->mPlatformDelegate->UnsubscribeCharacteristic(mConnObj, &CHIP_BLE_SVC_ID,
                                                         &CHIP_BLE_CHAR_2_UUID);
```

If it is the **peripheral** (the bulb), there is no over-the-air signal at all —
`src/ble/BLEEndPoint.cpp:412-415`:

```cpp
else // mRole == kBleRole_Peripheral, OR ...kDidBeginSubscribe == false...
{
    Free();
}
```

So sentence 1 is implemented and sentence 2 is (correctly) ignored. Everything now
depends on what `Free()` does.

**(b)** `Free()` (`src/ble/BLEEndPoint.cpp:461`) immediately calls
`ReleaseBleConnection()` (`src/ble/BLEEndPoint.cpp:441-459`):

```cpp
void BLEEndPoint::ReleaseBleConnection()
{
    if (mConnObj != BLE_CONNECTION_UNINITIALIZED)
    {
        if (mConnStateFlags.Has(ConnectionStateFlag::kAutoClose))
        {
            ChipLogProgress(Ble, "Auto-closing end point's BLE connection.");
            TEMPORARY_RETURN_IGNORED mBle->mPlatformDelegate->CloseConnection(mConnObj);
        }
        else
        {
            ChipLogProgress(Ble, "Releasing end point's BLE connection back to application.");
            mBle->mApplicationDelegate->NotifyChipConnectionClosed(mConnObj);
        }
        ...
```

**`CloseConnection()` is sentence 3.** It happens only in the `kAutoClose` branch.

**(c)** Is `kAutoClose` set on the bulb? **No.** `src/ble/BleLayer.cpp:447-449`:

```cpp
// Only BLE peripherals can receive GATT writes, so specify this role in our creation of the BLEEndPoint.
// Set autoClose = false. Peripherals only notify the application when an end point releases a BLE connection.
err = NewBleEndPoint(&newEndPoint, connObj, kBleRole_Peripheral, false);
```

Every peripheral endpoint — every bulb being commissioned — is created with
`autoClose = false`. So the bulb always takes the `else` branch: it **notifies the
application** and does not close the link.

**(d)** Does the application close it? On Linux,
`src/platform/Linux/BLEManagerImpl.cpp:838-850`:

```cpp
void BLEManagerImpl::NotifyChipConnectionClosed(BLE_CONNECTION_OBJECT conId)
{
    ChipLogProgress(Ble, "Got notification regarding chip connection closure");
#if CHIP_DEVICE_CONFIG_ENABLE_WPA && !CHIP_DEVICE_CONFIG_SUPPORTS_CONCURRENT_CONNECTION
    if (mState == kState_NotInitialized)
    {
        CloseConnection(conId);
        ...
    }
#endif
}
```

In a build that supports concurrent connections — the ordinary case — the whole body is
compiled out. The function **logs a line and returns.**

**What this means.** Reading §4.19.4.10 sentence 3 and this code side by side:

| Spec says | Code does |
|---|---|
| Server **SHALL terminate its BLE connection** | Server frees its own bookkeeping, tells the app, and leaves the radio link up |

> *This is a trail that leaves the §4.19/§4.20 scope, and we are flagging that
> explicitly.* We read exactly one platform implementation (Linux). Other platforms
> (Darwin, ESP32, Zephyr) may well behave differently — and if they do, **that is an even
> stronger result**, because it means the same SHALL is realised differently per
> platform. We have not checked them. See [D-5](D-5-verdict.md) for what this limitation
> means.

**Classification: M-3, with the SHALL deferred to an unnamed layer. Confidence: High for
Linux; Unverified elsewhere.**

---

## Result 3 — The specification's idle timeout does not exist in the Bluetooth code, and is *repurposed* in the Wi-Fi code

This is the strongest result in Finding D, because the two sibling implementations
diverge — level 1 on the evidence ladder.

### 3a — Bluetooth: the constant simply is not there

The spec's §4.19.5 Table 35 defines **three** constants. The implementation defines
**two**. `src/ble/BleConfig.h`:

```
:215    #define BTP_CONN_RSP_TIMEOUT_MS 15000
:226    #define BTP_ACK_TIMEOUT_MS      15000
```

A search for `BTP_CONN_IDLE` across `src/`, `examples/` and `config/` returns **nothing**.
The symbol does not exist anywhere in the project.

Two observations follow:

- **The idle timeout is unimplemented.** The spec's own mechanism for closing a session
  where "no unique data has been sent" for 30 seconds is absent.
- **A second, smaller divergence falls out for free:** the spec's Table 35 default for
  `BTP_CONN_RSP_TIMEOUT` is **5 seconds**; the code uses **15000 ms = 15 seconds**,
  three times longer. (`BTP_ACK_TIMEOUT` at 15 s does match the spec.) Table 35 labels
  these "Default", so an implementation may arguably tune them — but a handshake window
  three times wider than the specified default is worth recording, because it widens
  every pre-authentication window by the same factor.

### 3b — Wi-Fi: the constant exists, is documented from the spec, and is used for something else

`src/wifipaf/WiFiPAFConfig.h:137-145`:

```c
/**
 * @def PAFTP_CONN_IDLE_TIMEOUT_MS
 *
 * @brief
 *   Maximum amount of time, in milliseconds, no unique data has been sent over PAFTP session
 *   before the Commissioner must close the PAFTP session
 */
#ifndef PAFTP_CONN_IDLE_TIMEOUT_MS
#define PAFTP_CONN_IDLE_TIMEOUT_MS 30000
#endif
```

Read that comment carefully. It is a near-verbatim transcription of Table 42. Someone sat
with the specification open and copied the requirement across. Thirty seconds, exactly as
specified.

Now follow where it is used. **There is exactly one consumer in the entire project.**
`src/wifipaf/WiFiPAFEndPoint.cpp:74-76`:

```c
#define WIFIPAF_WAIT_RES_TIMEOUT_MS      1000
#define WIFIPAF_MAX_RESOURCE_BLOCK_COUNT (PAFTP_CONN_IDLE_TIMEOUT_MS / WIFIPAF_WAIT_RES_TIMEOUT_MS)
```

30000 / 1000 = **30**. Not 30 seconds. The number **30**, used as a *retry count*. And
here is what it counts — `src/wifipaf/WiFiPAFEndPoint.cpp:1230-1240`:

```cpp
CHIP_ERROR WiFiPAFEndPoint::StartWaitResourceTimer()
{
    mResourceWaitCount++;
    if (mResourceWaitCount >= WIFIPAF_MAX_RESOURCE_BLOCK_COUNT)
    {
        ChipLogError(WiFiPAF, "Network resource has been unavailable for a long time");
        mResourceWaitCount = 0;
        DoClose(kWiFiPAFCloseFlag_AbortTransmission, CHIP_ERROR_NOT_CONNECTED);
        return CHIP_NO_ERROR;
    }
    ...
```

This fires when **our own radio is too busy to transmit** 30 times in a row. It has
nothing to do with the peer being idle. A peer that is perfectly silent will never
increment `mResourceWaitCount`, because `StartWaitResourceTimer` is only reached when
*we* are trying to send and cannot.

**So the specification's idle-session requirement is implemented in neither transport.**
Bluetooth omits the constant entirely; Wi-Fi defines it with the spec's own words and
then spends it on an unrelated retry budget.

That second form is arguably worse for the thesis's purposes, because it looks
implemented. A compliance checklist that greps for `PAFTP_CONN_IDLE_TIMEOUT_MS` would
tick the box. Only following the symbol to its single use reveals the truth.

**Classification: M-2 / unimplemented normative constant. Confidence: High** — this is a
mechanical fact about symbol definitions and uses, not a judgement call.

---

## Result 4 — The twins diverge on idle supervision, and the commit message says why

This is the finding that moves D1 from "we think there's a hole" to **"the maintainers
found this hole, named it, fixed it on one side, and left the other side unfixed."**

### The divergence

Both transports have a function called `HandleConnectComplete()` — "the handshake
finished, we are now in session." They are ports of each other. Put them side by side.

**Bluetooth**, `src/ble/BLEEndPoint.cpp:154-176`:

```cpp
CHIP_ERROR BLEEndPoint::HandleConnectComplete()
{
    mState = kState_Connected;

    // Cancel the connect timer.
    StopConnectTimer();

    // We've successfully completed the BLE transport protocol handshake, ...
```

It **stops** a timer and arms nothing.

**Wi-Fi**, `src/wifipaf/WiFiPAFEndPoint.cpp:146-163`:

```cpp
CHIP_ERROR WiFiPAFEndPoint::HandleConnectComplete()
{
    mState = kState_Connected;
    ...
    // Arm ongoing idle session supervision to ensure upper-layer commissioning
    // (Phase 2 PASE handshake) initiates within a reasonable deadline.
    LogErrorOnFailure(StartAckReceivedTimer());
```

It **starts** one — and the comment names the threat precisely: make sure the peer
actually gets on with authenticating, within a deadline.

That is two ports of the same specification text, by the same project, in the same
repository, resolving the same silence in **opposite** directions. Level-1 evidence.

### Why there is no timer on the Bluetooth side — the trace

The spec's ack-received timer is the only candidate, and we can show exactly when it
dies:

1. The bulb sends its handshake response and starts the ack-received timer —
   `src/ble/BLEEndPoint.cpp:228`, inside `HandleSubscribeReceived()`:
   ```cpp
   // Start ack recvd timer for handshake indication.
   err = StartAckReceivedTimer();
   ```
   This matches §4.19.4.8: *"a server SHALL start its acknowledgement-received timer when
   it sends a handshake response."* Correct.

2. The peer acknowledges. The timer **stops** — `src/ble/BLEEndPoint.cpp:1211-1213`:
   ```cpp
   if (!mBtpEngine.ExpectingAck())
   {
       ChipLogDebugBleEndPoint(Ble, "got ack for last outstanding fragment");
       StopAckReceivedTimer();
   ```
   This also matches §4.19.4.8. Also correct.

3. `HandleConnectComplete()` (above) arms nothing to replace it.

**Result: after a completed handshake and one acknowledgement, a quiet BTP session has
no timer running at all.** Both steps individually comply with the specification. The
gap is in the composition — which is exactly what an M-2 is.

### The commit message — the single best piece of evidence in Finding D

We asked git who wrote the Wi-Fi line and when:

```bash
git log --oneline -L 160,165:src/wifipaf/WiFiPAFEndPoint.cpp
```

Commit **`650c569666a296973d0ff8899cebf2976aa3bad6`**, **16 June 2026**, titled:

> `[WiFi-PAF] Add a connection establishment timer for publisher endpoints (#72424)`

and its body opens with:

> **"WiFi-PAF: Resolve endpoint pool exhaustion DoS via missing timer and robust
> Shutdown cleanup"**
>
> - Add ReceiveConnectionTimer to WiFiPAFEndPoint to supervise incoming NAN subscribe
>   connections in the Publisher role.
> - Arm the ReceiveConnectionTimer upon connection initiation and ensure graceful
>   cancellation on completion or closure.
> - Enhance `WiFiPAFLayer::Shutdown()` to iterate and close active endpoints directly
>   from `sWiFiPAFEndPointPool` ...

Read that first line again: **"endpoint pool exhaustion DoS via missing timer"**.

That is D1's hypothesis, stated in the maintainers' own words, four months before we
formed it. They found it, classified it as a denial-of-service, and fixed it — in
`src/wifipaf/`.

They also added a regression test:
`src/wifipaf/tests/TestWiFiPAFLayer.cpp:499`, `TEST_F(TestWiFiPAFLayer, ReceiveConnectionTimerTimeout)`.

**No equivalent change was made to `src/ble/`.** There is no such timer, and
`src/ble/tests/` contains no pool-exhaustion or idle-session test (the only file that
even mentions idle states is the fuzzer, `src/ble/tests/FuzzBtpEnginePW.cpp`, and it is
about reassembler states, not sessions).

### What the asymmetry costs, numerically

The resource being exhausted is the endpoint pool:

| | Bluetooth | Wi-Fi |
|---|---|---|
| Pool size constant | `BLE_LAYER_NUM_BLE_ENDPOINTS` | `WIFIPAF_LAYER_NUM_PAF_ENDPOINTS` |
| Where | `src/ble/BleConfig.h:78` | `src/wifipaf/WiFiPAFConfig.h:39` |
| **Default value** | **1** | **2** |
| Post-handshake idle timer | **none** | `StartAckReceivedTimer`, `WiFiPAFEndPoint.cpp:161-163` |
| Regression test | none | `TestWiFiPAFLayer.cpp:499` |

So the transport that was **not** hardened is also the one with **half** the slots —
**exactly one.** One occupied slot is a full pool.

What happens when the pool is full? `src/ble/BleLayer.cpp:427-431`:

```cpp
auto endPoint = sBLEEndPointPool.GetFree();
if (endPoint == nullptr)
{
    ChipLogError(Ble, "%s endpoint pool FULL", "Ble");
    return CHIP_ERROR_ENDPOINT_POOL_FULL;
}
```

and the caller, `src/ble/BleLayer.cpp:459-463`, simply hands the connection back to the
application:

```cpp
if (newEndPoint == nullptr)
{
    mApplicationDelegate->NotifyChipConnectionClosed(connObj);
}
```

The second commissioner is turned away.

**Classification: M-2, with sibling-implementation divergence AND a maintainer
acknowledgement. Confidence: High.**

### The honest counterweight — something *does* eventually clean up

We did not stop at the folder boundary, and it is important that we did not, because
**the slot is not held forever.** Searching upward (Search 10 in
[D-3](D-3-the-search.md)) found `CommissioningWindowManager`, which calls
`CloseAllBleConnections()` in three situations:

- commissioning completed — `src/app/server/CommissioningWindowManager.cpp:77`
- a commissioning attempt failed — `:165`
- **the commissioning window closed** — `:429-438`

And that third one carries this comment, at `src/app/server/CommissioningWindowManager.cpp:433-437`:

```cpp
if (mListeningForPASE)
{
    // We never established PASE, so never armed a fail-safe and hence
    // can't rely on it expiring to close our BLE connection.  Do that
    // manually here.
    mServer->GetBleLayerObject()->CloseAllBleConnections();
}
```

This is a developer writing down, in plain English, that **there is no lower-layer
mechanism to rely on** for a session that never reached PASE, so they are plugging it by
hand at the application layer. That is level-2 evidence (an explicit acknowledgement),
and it confirms rather than contradicts the finding: the gap is real, and the patch for
it lives two layers above where the specification puts the requirement.

**But look at the timescale.** The reaper is the *commissioning window*, not a 30-second
idle timer:

| Limit | Value | Source |
|---|---|---|
| Minimum commissioning window | **3 minutes** | `CommissioningWindowManager.h:72-73` (comment cites spec §5.4.2.3) |
| Maximum, normal | **15 minutes** | `CommissioningWindowManager.cpp:328` |
| Maximum, uncommissioned device with extended advertising | **48 hours** | `CommissioningWindowManager.cpp:320-326` (cites spec §2.3.1) |

So the spec asks for a 30-second reaper in §4.19.5. What actually exists is a
180-second-to-48-hour reaper, in a different chapter, at a different layer, for a
different purpose. The shortest real case is **6× the specified bound**; the longest is
**5,760×**.

One more precision, because it matters: `CloseAllBleConnections()`
(`src/ble/BleLayer.cpp:295`) calls `elem->Abort()` on each endpoint, which reaches
`FinalizeClose` → peripheral branch → `Free()`. That reclaims **the endpoint slot**. It
does *not* itself terminate the radio link, for the reasons in Result 2. The two
resources are freed on different schedules, and the specification discusses neither.

---

## Result 5 — Confirmed: neither transport has any close message. Teardown is never a protocol act.

This was D2, and it is a **finite** question — so this is a proof by exhaustion, not an
impression.

### 5a — The complete vocabulary of BTP packets

`src/ble/BtpEngine.h:81-87` is the entire set of things a BTP packet can say:

```cpp
enum class HeaderFlags : uint8_t
{
    kStartMessage    = 0x01,
    kContinueMessage = 0x02,
    kEndMessage      = 0x04,
    kFragmentAck     = 0x08,
};
```

Four bits. "This is the start of a message", "this continues one", "this ends one",
"this carries an acknowledgement." **There is no close bit, no reset bit, no management
opcode.** Compare TCP, which has a dedicated `FIN` flag for precisely this job.

And the dispatcher reads nothing else — `src/ble/BtpEngine.cpp:228-272`,
`HandleCharacteristicReceived()`: read the flag byte, optionally read an ack byte, read
a sequence byte, then treat the remainder as payload. There is no `switch` on an opcode
anywhere, because there is no opcode.

(The handshake is recognised by **endpoint state**, not by any flag — which is precisely
the mechanism Finding C turns on.)

### 5b — Wi-Fi reserves a management opcode and then never reads it

`src/wifipaf/WiFiPAFTP.h:84-92` has two flags Bluetooth lacks:

```cpp
enum class HeaderFlags : uint8_t
{
    kStartMessage     = 0x01,
    kContinueMessage  = 0x02,
    kEndMessage       = 0x04,
    kFragmentAck      = 0x08,
    kManagementOpcode = 0x20,
    kHankshake        = 0x40,
};
```

`kManagementOpcode` is exactly where a "close session" command would live. So we found
every place it is read. **There are two**, and in both the opcode's *value* is ignored —
it is used only to skip a byte while locating the sequence number:

`src/wifipaf/WiFiPAFEndPoint.cpp:859-862` (in `GetPktSn`):

```cpp
if (rx_flags.Has(WiFiPAFTP::HeaderFlags::kManagementOpcode)) // Has Mgmt_Op
{
    SnOffset += kTransferProtocolMgmtOpSize;
}
```

…and the identical three lines at `src/wifipaf/WiFiPAFEndPoint.cpp:893-896`, inside a
debug-logging helper.

That is all. The byte is counted, never interpreted. **The wire format reserves a
management-command field that no code in the project implements.** A field defined in
the frame layout but given no meaning in the behaviour text is itself a clean
underspecification artefact.

(`kHankshake` — the project's spelling — is handled at three places:
`WiFiPAFEndPoint.cpp:852` "Handkshake message => No ack/sn", `:886` in the same debug
helper, and `:1046` `"Unexpected handshake packet => drop"`. That last one is Finding C's
territory, not D's.)

### 5c — Every way a session can die, classified

Both ports funnel all shutdowns through `DoClose()`. Enumerating its callers enumerates
every possible death. For Bluetooth:

| Trigger class | Call sites | Example |
|---|---|---|
| **Link-layer / peer GATT act** | `BleLayer.cpp:583`, `BleLayer.cpp:615` | client unsubscribed; BLE connection error |
| **Timer expiry** | `BLEEndPoint.cpp:1437`, `:1450`, `:1464` | connect timeout; receive-connection timeout; ack-received timeout |
| **Local error / upper-layer call** | `BLEEndPoint.cpp:148, 251, 264, 291, 301, 638, 783, 834, 1296, 1484` | `Abort()`, `Close()`, send failures, malformed frame |
| **Peer-sent close frame** | **(none)** | — *no such frame exists* |

Wi-Fi is the same shape: timers at `WiFiPAFEndPoint.cpp:1296, 1309, 1323`, the
resource-budget close at `:1238`, layer-driven closes at `WiFiPAFLayer.cpp:254, 295, 561`
— and, again, **nothing triggered by a peer-sent close frame.**

Where Wi-Fi *does* differ is what it does on the way out.
`WiFiPAFEndPoint::FinalizeClose` (`src/wifipaf/WiFiPAFEndPoint.cpp:240-248`) calls:

```cpp
TEMPORARY_RETURN_IGNORED mWiFiPafLayer->mWiFiPAFTransport->WiFiPAFCloseSession(mSessionInfo);
```

which lands at `src/transport/raw/WiFiPAF.cpp:110-117`:

```cpp
CHIP_ERROR WiFiPAFBase::WiFiPAFCloseSession(WiFiPAFSession & SessionInfo)
{
    ...
    TEMPORARY_RETURN_IGNORED DeviceLayer::ConnectivityMgr().WiFiPAFShutdown(SessionInfo.id, SessionInfo.role);
```

That is §4.20.3.10's "terminate the publish/subscribe instance" — and it is a **radio
management call**, not a protocol frame. Which is exactly D2's claim.

**D2 is confirmed, as a structural property of the specification, not as an exploit:**

> In both Matter pre-authentication transports, the handshake is the only control frame.
> There is no close, reset, or management message. Every teardown is a link-layer event,
> a timer expiry, or an upper-layer call. Consequently, **no peer can ever end a session
> by sending something** — it can only stop sending, disconnect its radio, or (as the
> GATT client) unsubscribe.

**Why this is a real finding and not trivia.** It explains *why* Results 3 and 4 matter
so much. Because no "goodbye" exists, the **timer is the only defence** against a peer
that simply stops talking. Take the timer away and there is no mechanism left at all.
The specification never states this structural fact anywhere, so a reader of
§4.19.4.10 has no way to know that the four sentences they just read are the *complete*
set of teardown mechanisms.

---

## Summary table

| # | Result | Evidence class | Confidence |
|---|---|---|---|
| 1 | Code silently reinterprets the impossible "server SHALL unsubscribe" sentence; no comment records it | (a) spec silent + code chose, undocumented | High |
| 2 | Server-side "SHALL terminate its BLE connection" is gated on a non-spec `autoClose` flag, false for all peripherals; Linux platform then no-ops | (a) + out-of-scope deferral | High (Linux); unverified elsewhere |
| 3 | `BTP_CONN_IDLE_TIMEOUT` absent from Bluetooth entirely; `PAFTP_CONN_IDLE_TIMEOUT_MS` defined from spec text in Wi-Fi then spent on an unrelated retry budget | (b) **the two ports differ** | High |
| 4 | Wi-Fi arms post-handshake idle supervision; Bluetooth does not — and the Wi-Fi commit says "endpoint pool exhaustion DoS via missing timer". Bluetooth pool = 1, Wi-Fi = 2 | (b) **ports differ** + (c) **maintainer acknowledgement** | High |
| 5 | No close/reset/management frame in either transport; PAFTP reserves a management opcode and never reads it; teardown is always link-layer, timer, or upper-layer | structural, proof by exhaustion | High |

---

Next: [D-5-verdict.md](D-5-verdict.md) — how confident we are, what would prove us
wrong, and what this feeds into.
