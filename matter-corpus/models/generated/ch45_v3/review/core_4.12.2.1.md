# Review: `core_4.12.2.1` — Retransmissions

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 54.01
- module: `models/generated/ch45_v3/core_4.12.2.1/vertex-gemini/core_4_12_2_1.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 107, col 5 to line 112, col 85 of module core_4_12_2_1>
/\ sessionContexts = (PeerIds_1 :> [isICD |-> FALSE, PeerActiveMode |-> FALSE, SESSION_ACTIVE_INTERVAL |-> 0, SESSION_IDLE_INTERVAL |-> 0, fastPollingInterval |-> 0] @@ PeerIds_2 :> [isICD |-> FALSE, PeerActiveMode |-> FALSE, SESSION_ACTIVE_INTERVAL |-> 0, SESSION_IDLE_INTERVAL |-> 0, fastPollingInterval |-> 0])
/\ inputData = [exchangeId |-> ExchangeIds_1, peerId |-> NullPeer, isFirstMsg |-> FALSE, activeMode |-> FALSE, activeInt |-> 0, idleInt |-> 0, isICD |-> FALSE, fastPoll |-> 0]
/\ exchanges = (ExchangeIds_1 :> [peerId |-> NullPeer, state |-> "CLOSED", n |-> 0, isFirstMessage |-> FALSE] @@ ExchangeIds_2 :> [peerId |-> NullPeer, state |-> "CLOSED", n |-> 0, isFirstMessage |-> FALSE])
/\ failedExchanges = {}
/\ pendingInput = "SendReliableMessage"
/\ activeOpDiscoveries = {}
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ sessionContexts = (PeerIds_1 :> [isICD |-> FALSE, PeerActiveMode |-> FALSE, SESSION_ACTIVE_INTERVAL |-> 0, SESSION_IDLE_INTERVAL |-> 0, fastPollingInterval |-> 0] @@ PeerIds_2 :> [isICD |-> FALSE, PeerActiveMode |-> FALSE, SESSION_ACTIVE_INTERVAL |-> 0, SESSION_IDLE_INTERVAL |-> 0, fastPollingInterval |-> 0])
/\ inputData = [ exchangeId |-> NullExchange,
  peerId |-> NullPeer,
  isFirstMsg |-> FALSE,
  activeMode |-> FALSE,
  activeInt |-> 0,
  idleInt |-> 0,
  isICD |-> FALSE,
  fastPoll |-> 0 ]
/\ exchanges = (ExchangeIds_1 :> [peerId |-> NullPeer, state |-> "CLOSED", n |-> 0, isFirstMessage |-> FALSE] @@ ExchangeIds_2 :> [peerId |-> NullPeer, state |-> "CLOSED", n |-> 0, isFirstMessage |-> FALSE])
/\ failedExchanges = {}
/\ pendingInput = NoInput
/\ activeOpDiscoveries = {}

State 2: <ReceiveInput line 107, col 5 to line 112, col 85 of module core_4_12_2_1>
/\ sessionContexts = (PeerIds_1 :> [isICD |-> FALSE, PeerActiveMode |-> FALSE, SESSION_ACTIVE_INTERVAL |-> 0, SESSION_IDLE_INTERVAL |-> 0, fastPollingInterval |-> 0] @@ PeerIds_2 :> [isICD |-> FALSE, PeerActiveMode |-> FALSE, SESSION_ACTIVE_INTERVAL |-> 0, SESSION_IDLE_INTERVAL |-> 0, fastPollingInterval |-> 0])
/\ inputData = [exchangeId |-> ExchangeIds_1, peerId |-> NullPeer, isFirstMsg |-> FALSE, activeMode |-> FALSE, activeInt |-> 0, idleInt |-> 0, isICD |-> FALSE, fastPoll |-> 0]
/\ exchanges = (ExchangeIds_1 :> [peerId |-> NullPeer, state |-> "CLOSED", n |-> 0, isFirstMessage |-> FALSE] @@ ExchangeIds_2 :> [peerId |-> NullPeer, state |-> "CLOSED", n |-> 0, isFirstMessage |-> FALSE])
/\ failedExchanges = {}
/\ pendingInput = "SendReliableMessage"
/\ activeOpDiscoveries = {}
```

</details>

## Spec text for this section

4.12.2.1. Retransmissions
Senders provide an automatic retransmission mechanism for reliable messages. In order for the
receiver to receive a message reliably, the sender SHALL trigger the automatic retry mechanism
after a period of mrpBackoffTime milliseconds without receiving an acknowledgement, where mrpBackoffTime is calculated according to the formula below. The sender SHALL retry up to a config­
ured maximum number of times (MRP_MAX_TRANSMISSIONS - 1) before giving up and notifying
the application.
Messages sent to a Node can be lost for various reasons such as lossy network or insufficient buffer
space at the receiver. In the case of Intermittently Connected Devices, which are active infrequently
to receive messages destined for them, a sender must be aware of the characteristics of the recipient to ensure it does not attempt to send at a rate beyond the recipient’s capability. Therefore, the
sender SHALL choose retransmission timeouts based on the session characteristics of the destination Node exposed via Section 4.3.2, “Operational Discovery”.
At each sender, a retransmission timer is started each time a reliable message is transmitted. The
duration of the retransmission timer SHALL be calculated as follows:
"mrpBackoffTime" = i * "MRP_BACKOFF_BASE"^(max(0,n-"MRP_BACKOFF_THRESHOLD")) * (1.0 +
"random"(0,1) * "MRP_BACKOFF_JITTER")
Where:
{:("mrpBackoffTime", =, "the resultant retransmission timeout for this
transmission"),(n, =, "the number of send attempts before the current one for this
message (0 if this is the initial transmission)"),(i, =, "the base retry interval for
the Exchange (either IDLE or ACTIVE)"):}
For each unique Exchange, the sender SHALL wait for the acknowledgement message until the
retransmission timer, mrpBackoffTime, expires.
When waiting for an acknowledgement, an Intermittently Connected Device will always be in
Active Mode since it will have at least one active exchange. An Intermittently Connected Device
sender SHOULD increase the mrpBackoffTime by its fast polling interval to take into account the
delay that might happen in receiving the acknowledgment while in Active Mode.
For the first message of a new exchange, the base interval, i, SHALL be set according to the idle
state of the peer node as stored in the Session Context of the session (either the Secure Session Context or the Unsecured Session Context depending on the Session Type). For all subsequent messages
of the exchange, the base interval, i, SHOULD be set according to the active state of the peer node as
stored in the Session Context of the session (either the Secure Session Context or the Unsecured Session Context depending on the Session Type), unless the sender has other means to determine
whether the device is active or idle. The backoff base interval SHALL be set to a value at least 10%
greater than the idle interval of the destination:
• If PeerActiveMode in the Session Context is true:
◦i = SESSION_ACTIVE_INTERVAL of the peer
• Else the peer is in idle mode:
◦i = SESSION_IDLE_INTERVAL of the peer
• i = MRP_BACKOFF_MARGIN * i
The MRP_BACKOFF_THRESHOLD parameter creates a two-phase scheme which begins with linear
backoff to improve initial latency when congestion is not the cause of packet drops, and then transitions to exponential backoff to provide convergence when the network is congested. If a positive
acknowledgment is received before the retransmission timer expires, the retransmission timer is
stopped. Otherwise, if the retransmission timer expires, the message is retransmitted and the timer
started again.
The following table illustrates minimum, maximum, and cumulative retransmission times using
default parameters.
Table 21. Example MRP Retransmission Times
Metric
Transmission Time [ms]
Min Jitter
Max Jitter
Min Total
Max Total
Transmission #
The sender SHOULD initiate Section 4.3.2, “Operational Discovery” in parallel with the first retry to
re-resolve the address of the destination Node if the initial transmission fails after one expected
round trip. The sender SHOULD use the latest MRP parameters for the destination that result from
subsequent Operational Discovery.
When a client is communicating with an ICD (i.e. the ICD Management cluster is present), the
sender SHALL initiate Section 4.3.2, “Operational Discovery” in parallel with the first retry to re-
resolve the address of the destination Node if the initial transmission fails after one expected round
trip. The sender SHALL use the latest MRP parameters for the destination that result from subsequent Operational Discovery.
