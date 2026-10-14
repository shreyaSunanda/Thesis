# Review: `core_5.9.3` — Network Recovery Flow

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 2
- ranker score: 27.37
- module: `models/generated/ch45_v4/core_5.9.3/vertex-gemini/core_5_9_3.tla`

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 38, col 5 to line 41, col 95 of module core_5_9_3>
/\ state = "OpNetworkNormal"
/\ failSafeState = "Disarmed"
/\ sessionChannel = "None"
/\ reconnectAttempts = "Active"
/\ hasNewCredentials = FALSE
/\ pendingInput = "Wait120sTimeout"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "OpNetworkNormal"
/\ failSafeState = "Disarmed"
/\ sessionChannel = "None"
/\ reconnectAttempts = "Active"
/\ hasNewCredentials = FALSE
/\ pendingInput = NoInput

State 2: <ReceiveInput line 38, col 5 to line 41, col 95 of module core_5_9_3>
/\ state = "OpNetworkNormal"
/\ failSafeState = "Disarmed"
/\ sessionChannel = "None"
/\ reconnectAttempts = "Active"
/\ hasNewCredentials = FALSE
/\ pendingInput = "Wait120sTimeout"
```

</details>

### Under no capability flags

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 38, col 5 to line 41, col 95 of module core_5_9_3>
/\ state = "OpNetworkNormal"
/\ failSafeState = "Disarmed"
/\ sessionChannel = "None"
/\ reconnectAttempts = "Active"
/\ hasNewCredentials = FALSE
/\ pendingInput = "Wait120sTimeout"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ state = "OpNetworkNormal"
/\ failSafeState = "Disarmed"
/\ sessionChannel = "None"
/\ reconnectAttempts = "Active"
/\ hasNewCredentials = FALSE
/\ pendingInput = NoInput

State 2: <ReceiveInput line 38, col 5 to line 41, col 95 of module core_5_9_3>
/\ state = "OpNetworkNormal"
/\ failSafeState = "Disarmed"
/\ sessionChannel = "None"
/\ reconnectAttempts = "Active"
/\ hasNewCredentials = FALSE
/\ pendingInput = "Wait120sTimeout"
```

</details>

## Spec text for this section

5.9.3. Network Recovery Flow
The Network Recovery process consists of the following steps enumerated below. Recovery Node
refers specifically to the node that has lost its operational network connectivity. This process
assumes that the operational network credentials for one or more Nodes has been changed such
that those Nodes are no longer able to communicate with other Nodes, including Administrators.
Normative requirements below apply to Nodes that choose to implement the Network Recovery
feature.
1. At some time before the operational network credentials change, an Administrator SHOULD
retrieve the value of the RecoveryIdentifier attribute from the GeneralCommissioning cluster
on the Recovery Node. This MAY be done during the commissioning process.
2. The Administrator SHALL have the new credentials required to connect to the operational network, and the new operational network SHALL be present and operational.
3. Should operational network connectivity be lost, the Recovery Node SHALL continue to attempt
to connect to the operational network for a duration of at least 120 seconds using its existing
credentials. Afterwards it MAY choose to enter Network Recovery mode and commence
announcement. Recovery Nodes SHALL attempt to reconnect to the existing operational network while in the recovery state. Given that temporary network outages occur with some fre­
quency, waiting before entering Network Recovery mode and commencing announcement limits wireless spectrum pollution/interference and helps to limit attack opportunities.
4. The Recovery Node SHALL perform recovery announcement using any of its available commissioning channels. A Recovery Node utilizing its BLE interface SHALL advertise the Network
Recovery payload (see BLE Service Data payload format). A Recovery Node utilizing its Wi-Fi
interface with Wi-Fi Unsynchronized Service Discovery SHALL publish its Recovery ID using
Wi-Fi Unsynchronized Service Discovery (see Table 76, “Publish method arguments values for
discovery”). The Administrator uses the Node’s advertised OpCode (see BLE Device Opcode and
Wi-Fi Public Action Frame Device Opcode) to identify Recovery Nodes in the Network Recovery
mode. Recovery Node announcements SHALL follow the announcement duration requirements
described in Announcement Duration and SHALL take advantage of the Extended Announcement duration.
5. If the Extended Announcement duration ends and the Recovery Node is still unable to reach its
operational network, it SHALL continue to attempt to reconnect to the existing operational network at a manufacturer-defined interval. The Recovery Node SHALL restart the Network Recov­
ery procedure when the steps enumerated in CommissioningModeInitialStepsHint are performed.
6. The Administrator SHALL obtain user consent before providing new credentials to a Recovery
Node. This step need not occur in the order it appears in this list of steps (i.e., it could have been
obtained earlier). User consent helps ensure that credentials are not inadvertently provided to
imposter devices, erroneously provided during a temporary network outage, etc.
7. If user consent has not been granted, the Administrator terminates its execution of the Network
Recovery flow and the following steps SHALL NOT be performed.
8. The Administrator establishes a connection with the Recovery Node over BLE or Wi-Fi as it
would to commission an uncommissioned device.
9. Once connected, the Administrator and Recovery Node SHALL establish a secure session using
CASE for purposes of provisioning the Recovery Node with updated network credentials. All
messages exchanged over the recovery connection SHALL be encrypted using CASE-derived
keys. Network recovery procedure SHALL preempt autonomous network reconnect attempts:
once the secure connection is established, any ongoing attempts taken autonomously by the
Recovery Node to re-establish connectivity to the previously configured operational network
SHALL be suspended and SHALL NOT interfere with the session established in this step.
Autonomous attempts to re-establish network connectivity SHALL resume in the event of failure of the network recovery procedure. The remainder of the steps is substantially the same as
the network commissioning during a commissioning flow, except that they are transacted over
a CASE session instead of a PASE session. In addition to the remaining network recovery steps,
Recovery Nodes SHALL allow any and all transactions allowed over a CASE session, such as
reading Basic Information cluster or accessing device configuration data and topology, as
Administrators might require them to fully restore network connectivity.
10. Upon successful establishment of the CASE session, the Recovery Node SHALL autonomously
arm the fail-safe timer for a timeout of 60 seconds. This is to guard against the Administrator
not proceeding with the rest of the flow in a timely fashion, and is analogous to initial phase
step 6 of the standard commissioning flow.
11. Within 60 seconds of establishing the CASE session, the Administrator SHALL arm the fail-safe
timer. If the fail-safe could not be successfully armed, the Administrator SHALL terminate the
session.
12. The Administrator MAY choose to delete a Recovery Node’s existing network credentials by
sending a RemoveNetwork. The Administrator SHALL provide the new credentials of the operational network to the Recovery Node using the AddOrUpdateWiFiNetwork or AddOrUp­
dateThreadNetwork commands.
13. The Administrator SHALL then instruct the Recovery Node to connect to the operational network using the new credentials by issuing a ConnectNetwork command.
14. The Recovery Node SHALL attempt to connect to the operational network using the newly-provisioned credentials. Once connected, all messages associated with the remaining Network
Recovery steps between the Administrator and Recovery Node SHALL be exchanged over the
operational network. These messages SHALL be communicated over a CASE session.
15. The Administrator and the Recovery Node SHALL discover each other on the operational network using operational discovery (see Section 4.3.2, “Operational Discovery”).
16. The Administrator and the Recovery Node SHALL indicate successful completion of the Network
Recovery flow using the CommissioningComplete and CommissioningCompleteResponse commands. These commands SHALL be sent over a CASE session over the operational network. The
Recovery Node SHALL reject the CommissioningComplete that is not received over the operational network.
Figure 53. Network Recovery sequence diagram
Chapter 6. Device Attestation and
Operational Credentials
This chapter describes the procedures and cryptographic credentials involved in establishing trust
between entities.
The Device Attestation section provides mechanisms for Commissioners and Administrators to
determine whether a Node is a genuine certified product before sharing sensitive information such
as keys and other credentials. The Device Attestation feature relies on a Device Attestation Certificate (DAC) chain and on a Certification Declaration (CD).
The Node Operational Credentials section describes the credentials used by all Nodes to mutually
authenticate each other during Certificate-Authenticated Session Establishment, including the Node
Operational Certificate (NOC) chain. These credentials form the basis of how Nodes are identified
and take part in securing operational unicast communication.
