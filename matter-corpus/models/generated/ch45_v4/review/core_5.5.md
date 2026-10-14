# Review: `core_5.5` — Commissioning Flows

Automated triage: **candidate** — the input was not left unhandled after a teardown

## Verdict to record

- [ ] real specification gap
- [ ] modelling defect (the generated model is wrong)
- [ ] the spec genuinely does describe this case (model missed a handler)

Notes:



## Evidence

- steps to the unhandled input: 6
- ranker score: 111.9
- module: `models/generated/ch45_v4/core_5.5/vertex-gemini/core_5_5.tla`

### Under ConcurrentConnectionCap=True, IsCommissioningWithoutPower=True

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

</details>

### Under ConcurrentConnectionCap=True, IsCommissioningWithoutPower=True

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_Establishment_Request"
/\ failSafeStatus = "Disarmed"

State 3: <AcceptPaseRequest line 72, col 5 to line 77, col 80 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Establishing"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 4: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Establishing"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PAKE3"
/\ failSafeStatus = "Disarmed"

State 5: <ReceivePAKE3 line 90, col 5 to line 96, col 66 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = NoInput
/\ failSafeStatus = "Armed"

State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

</details>

### Under ConcurrentConnectionCap=True, IsCommissioningWithoutPower=False

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

</details>

### Under ConcurrentConnectionCap=True, IsCommissioningWithoutPower=False

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_Establishment_Request"
/\ failSafeStatus = "Disarmed"

State 3: <AcceptPaseRequest line 72, col 5 to line 77, col 80 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Establishing"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 4: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Establishing"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PAKE3"
/\ failSafeStatus = "Disarmed"

State 5: <ReceivePAKE3 line 90, col 5 to line 96, col 66 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = NoInput
/\ failSafeStatus = "Armed"

State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

</details>

### Under ConcurrentConnectionCap=False, IsCommissioningWithoutPower=True

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

</details>

### Under ConcurrentConnectionCap=False, IsCommissioningWithoutPower=True

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_Establishment_Request"
/\ failSafeStatus = "Disarmed"

State 3: <AcceptPaseRequest line 72, col 5 to line 77, col 80 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Establishing"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 4: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Establishing"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PAKE3"
/\ failSafeStatus = "Disarmed"

State 5: <ReceivePAKE3 line 90, col 5 to line 96, col 66 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = NoInput
/\ failSafeStatus = "Armed"

State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

</details>

### Under ConcurrentConnectionCap=False, IsCommissioningWithoutPower=False

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Disarmed"
```

</details>

### Under ConcurrentConnectionCap=False, IsCommissioningWithoutPower=False

Last action to fire: **`ReceiveInput`**

State in which the input went unhandled:

```
State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

<details><summary>Full trace</summary>

```
The behavior up to this point is:
State 1: <Initial predicate>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 2: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Closed"
/\ paseSessionStatus = "None"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PASE_Establishment_Request"
/\ failSafeStatus = "Disarmed"

State 3: <AcceptPaseRequest line 72, col 5 to line 77, col 80 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Establishing"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = NoInput
/\ failSafeStatus = "Disarmed"

State 4: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Establishing"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Idle"
/\ pendingInput = "PAKE3"
/\ failSafeStatus = "Disarmed"

State 5: <ReceivePAKE3 line 90, col 5 to line 96, col 66 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = NoInput
/\ failSafeStatus = "Armed"

State 6: <ReceiveInput line 64, col 5 to line 67, col 121 of module core_5_5>
/\ commissioningChannel = "Open"
/\ paseSessionStatus = "Established"
/\ commissioningWindowOpen = TRUE
/\ commissioningPhase = "Initial"
/\ pendingInput = "PASE_PBKDFParamResponse"
/\ failSafeStatus = "Armed"
```

</details>

## Spec text for this section

5.5. Commissioning Flows
There are two commissioning flows depending upon the networking capability of the Commissioner and Commissionee, namely concurrent connection commissioning flow and non-concurrent
connection commissioning flow.
For additional security requirements related to commissioning flows, refer to Section 13.6, “Security Best Practices”.
A Commissioner and Commissionee with concurrent connection have the ability to maintain two
network connections simultaneously. One connection is between the Commissioner (or Commissionee) and the operational network (e.g., home Wi-Fi network or Thread network) that the Com­
missionee is being programmed to join. The second connection is between the Commissioner and
Commissionee for commissioning as is referred to as commissioning channel. A Commissioner and
Commissionee with non-concurrent connection capability cannot be simultaneously connected to
both the operational network that the Commissionee is being configured to join, and the commissioning channel.
The two connections MAY either be on the same or on different networking interfaces. For example, a Commissioner uses its Wi-Fi interface to connect to the operational network, but use its Blue­
tooth Low Energy interface for commissioning.
To determine whether a Commissionee has concurrent or non-concurrent connection capability,
the Commissioner can use the Section 11.10.6.5, “SupportsConcurrentConnection” attribute of the
Section 11.10, “General Commissioning Cluster”.
The Commissionee communication channel used at the beginning of commissioning MAY be on the
same power domain as the operational network interface or MAY be on a different power domain.
For example, a Commissionee could use NFC energy harvesting for commissioning through NFC
Transport Layer (NTL), but require main power to connect to the operational network.
To determine whether a Commissionee is in a power configuration that allows connecting to the
operational network, the Commissioner can use the IsCommissioningWithoutPower attribute of the
General Commissioning Cluster.
Commissioning, including both initial and setup phases, SHALL be a time-bound process that completes before expiration of a fail-safe timer. The fail-safe timer SHALL be set at the beginning of
commissioning. If the device is not in a power configuration that allows connecting to the operational network at the end of the initial phase, then the fail-safe timer countdown is paused, and it is
resumed during the second phase of commissioning. If the fail-safe timer expires prior to commissioning completion, the Commissioner and Commissionee SHALL behave as specified in Section
11.10.7.2.2, “Behavior on expiry of Fail-Safe timer”. Successful completion of commissioning SHALL
disarm the fail-safe timer.
A Commissionee that is ready to be commissioned SHALL accept the request to establish a PASE session with the first Commissioner that initiates the request. When a Commissioner is either in the
process of establishing a PASE session with the Commissionee or has successfully established a session, the Commissionee SHALL NOT accept any more requests for new PASE sessions until one of
the following events occurs:
• session establishment fails,
• the successfully established PASE session is terminated on the commissioning channel (see Section 4.11.1.4, “CloseSession” in Section 4.11.1.3, “Secure Channel Status Report Messages”),
• the PASE session is established through NFC Transport Layer (NTL) and Commissionee receives
a valid SELECT command
In the event a Section 4.11.1.4, “CloseSession” status message is sent or received , or whenever commissioning through NFC Transport Layer (NTL) is interrupted by SELECT command :
1. If the fail-safe timer is armed, the fail-safe timer SHALL be considered expired and the cleanup
steps detailed in Section 11.10.7.2, “ArmFailSafe” SHALL be executed.
2. If the commissioning window is still open, the Commissionee SHALL continue listening for commissioning requests.
In order to avoid locking out the Commissionee from accepting new PASE session requests indefinitely, a Commissionee SHALL expect a PASE session to be established within 60 seconds of receiv­
ing the initial request. This means the Commissionee SHALL expect to receive the PAKE3 message
within 60 seconds after sending a PBKDFParamResponse in response to a PBKDFParamRequest
message from the Commissioner to establish a PASE session. If the PASE session is not established
within the expected time window the Commissionee SHALL terminate the current session establishment using the INVALID_PARAMETER status code as described in Section 4.11.1.3, “Secure Channel
Status Report Messages”.
During commissioning:
• the Commissionee SHALL expose all the supported endpoints and descriptor clusters of the
device
• the Commissionee SHALL support the Access Control cluster, the Basic Information cluster, the
General Commissioning cluster and the Operational Credentials cluster
• if the Commissionee requires network commissioning then it SHALL support the Network Commissioning cluster
• the Commissionee MAY expose other clusters, but it does not have to support subscriptions for
arbitrary clusters
• the Commissionee, when using NFC-based commissioning, MAY reject attribute writes for clusters used during the initial phase of commissioning, therefore the Commissioner SHALL handle
these errors
When using NFC-based commissioning, it can be interrupted without waiting for the expiry of the
fail-safe timer thanks to the physical tap done by the user on the device. Since the transmission of
SELECT command to interrupt the commissioning is under the control of the commissioner, it can
decide whether it should issue it, for example because its internal watchdog fired, or not, filtering
out accidental taps.
The commissioning commands and attributes are defined in Clusters (see Section 11.9, “Network
Commissioning Cluster”, Section 11.10, “General Commissioning Cluster”, Section 11.14, “Thread
Network Diagnostics Cluster”, and Section 11.15, “Wi-Fi Network Diagnostics Cluster”) and are sent,
written, or read using the Interaction Model (see Chapter 8, Interaction Model Specification).
Figure 47, “Commissioning flow diagram” depicts the commissioning flow between the Commissioner and Commissionee, with optional steps applying if the condition within square brackets is
met. The specific steps are described below. Unless indicated otherwise, a commissioner SHALL
complete a step, including waiting for any responses to commands it sends in that step, before moving on to the next step.
The initial phase of the Commissioning process consists of the following steps:
1. The Commissioner initiating the commissioning SHALL have regulatory and fabric information
available, and SHOULD have accurate date, time and timezone.
2. Commissioner and Commissionee SHALL establish a commissioning channel between each
other after discovery or direct physical tap (see Section 5.4, “Device Discovery”).
3. If the Commissioner and device support Section 5.7.4.1, “Terms and Conditions (TC) Acknowledgement”, then the Commissioner SHALL obtain the Terms and Conditions to present to the
user from Section 11.23.6.23, “EnhancedSetupFlowTCUrl”.
4. If the Commissioner and device support Section 5.7.4.1, “Terms and Conditions (TC) AcknowlMatter Specification R1.6
edgement”, the Commissioner SHALL present the Terms and Conditions to the user following
Section 5.7.4.1, “Terms and Conditions (TC) Acknowledgement”, unless the Commissioner
already has user provided responses that can be used.
5. If the Commissioner and device support Section 5.7.4.1, “Terms and Conditions (TC) Acknowledgement”, and Terms and Conditions were presented in step 4, then the Commissioner SHALL
receive the user responses to the provided terms for use in step 9.
6. Commissioner and Commissionee SHALL establish encryption keys with PASE (see Section
4.14.1, “Passcode-Authenticated Session Establishment (PASE)”) on the commissioning channel.
All subsequent messages on the commissioning channel are encrypted using PASE-derived
encryption keys. Upon completion of PASE session establishment, the Commissionee SHALL
autonomously arm the Fail-safe timer for a timeout of 60 seconds. This is to guard against the
Commissioner aborting the Commissioning process without arming the fail-safe, which may
leave the device unable to accept additional connections.
7. Commissioner SHALL re-arm the Fail-safe timer on the Commissionee to the desired commissioning timeout within 60 seconds of the completion of PASE session establishment, using the
ArmFailSafe command (see Section 11.10.7.2, “ArmFailSafe”). A Commissioner MAY obtain
device information including guidance on the fail-safe value from the Commissionee by reading
BasicCommissioningInfo attribute (see Section 11.10.6.2, “BasicCommissioningInfo”) prior to
invoking the Section 11.10.7.2, “ArmFailSafe” command.
8. If the Commissionee has at least one instance of the Network Commissioning cluster on any
endpoint with either the WI (i.e. Wi-Fi) or TH (i.e. Thread) feature flags set in its FeatureMap,
Commissioner SHALL configure regulatory information in the Commissionee using the Section
11.10.7.4, “SetRegulatoryConfig” command.
9. If the Terms & Conditions Enhanced Setup Flow feature is supported by both the device and by
the commissioner, and Section 11.10.6.9, “TCAcknowledgementsRequired” is True, the Commissioner SHALL present them as documented in Terms and Conditions Acknowledgement. The
user’s responses SHALL be propagated back to the node with Section 11.10.7.8, “SetTCAcknowledgements”.
10. Commissioner SHALL establish the authenticity of the Commissionee as a certified Matter
device (see Section 6.2.3, “Device Attestation Procedure”).
◦If the Commissionee fails the Device Attestation Procedure, for any reason, the Commissioner MAY choose to either continue to the Commissioning, or terminate it, depending on
implementation-dependent policies.
◦Upon failure of the procedure, the Commissioner SHOULD warn the user that the Commissionee is not a fully trusted device, and MAY give the user the choice to authorize or deny
the commissioning. Such a warning enables user choice in Commissionee trust on their Fabric, for development workflows, as well as homebrew device development. Such a warning
SHOULD contain as much information as the commissioner can provide about the Commissionee, and SHOULD be adapted to the reason of the failure, for example by being different
between the case of an expired certificate versus a revoked PAI certificate.
◦Reasons for failing the Device Attestation procedure MAY include, but are not limited to, the
following:
▪The Commissionee being of a device type currently in development or not yet certified
(see certification_type in the Certification Declaration). Commissioners SHOULD accept a
Certification Declaration with certification_type=1 (provisional) and MAY inform the customer.
▪The Commissionee’s PAA not being in the Commissioner’s trusted set.
▪The Commissioner having obtained knowledge that a PAA or PAI certificate presented
has been revoked, or that the particular Device Attestation Certificate has been revoked
(see Section 6.2.4, “Device attestation revocation”).
▪The Commissioner cannot obtain a revocation set or cannot obtain updated revocation
information from the CA (see Section 6.2.4.2, “Determining Revocation Status of an
Entity”).
▪The Commissionee failing to prove possession of the Device Attestation private key,
either by programming error, malicious intent or other reasons.
▪One of the elements of the Commissionee’s Device Attestation Certificate chain not meeting the policy validation steps of the Device Attestation Procedure, including errors on
validity period.
◦If a Commissioner denies commissioning for any reason, it SHOULD notify the user of the
reason with sufficient details for the user to understand the reason, so that they could determine if it would be possible to commission the device using a different Commissioner.
11. Following the Device Attestation Procedure yielding a decision to proceed with commissioning,
the Commissioner SHALL request operational CSR from Commissionee using the CSRRequest
command (see Section 11.18.6.5, “CSRRequest Command”). The CSRRequest command will cause
the generation of a new operational key pair at the Commissionee.
12. Commissioner SHALL generate or otherwise obtain an Operational Certificate containing Operational ID after receiving the CSRResponse command from the Commissionee (see Section
11.18.6.5, “CSRRequest Command”), using implementation-specific means.
13. Commissioner SHALL install operational credentials (see Figure 58, “Node Operational Credentials flow”) on the Commissionee using the Section 11.18.6.13, “AddTrustedRootCertificate” and
AddNOC commands, and SHALL use the Section 11.18.6.11, “UpdateFabricLabel” command to
set a string that the user can recognize and relate to this Commissioner/Administrator.
The AdminVendorId field of the AddNOC command SHALL be set to a value for which the Vendor Schema in DCL contains the name and other information of the Commissioner’s manufac­
turer.
14. Commissioner MAY configure the Access Control List (see Section 9.10, “Access Control Cluster”)
on the Commissionee in any way it sees fit, if the singular entry added by the AddNOC command
in the previous step granting Administer privilege over CASE authentication type for the Node
ID provided with the command is not sufficient to express its desired access control policies.
a. The Commissioner MAY read the Commissioning Access Restriction List (see Section 9.10,
“Access Control Cluster”) on the Commissionee in order to identify fabric restrictions. When
restrictions exist, the Administrator MAY invoke the ReviewFabricRestrictions command on
the same cluster in order to initiate the review process (see Section 9.10.4.2, “ManagedDevice”), however, the Administrator SHALL wait until after commissioning completes before
sending this command.
15. If the Commissionee both supports it and requires it, the Commissioner SHALL configure the
operational network at the Commissionee using commands such as AddOrUpdateWiFiNetwork
(see Section 11.9.7.3, “AddOrUpdateWiFiNetwork Command”) and AddOrUpdateThreadNetwork
(see Section 11.9.7.4, “AddOrUpdateThreadNetwork Command”). A Commissionee requires network commissioning if it is not already on the desired operational network. A Commissionee
supports network commissioning if it has any NetworkCommissioning cluster instances. A Commissioner MAY learn about the networks visible to the Commissionee using ScanNetworks com­
mand (see Section 11.9.7.1, “ScanNetworks Command”).
16. The Commissioner SHALL trigger the Commissionee to connect to the operational network
using ConnectNetwork command (see Section 11.9.7.8, “ConnectNetwork Command”) unless the
Commissionee is already on the desired operational network. In case the device is not fully
powered during the initial phase of commissioning, the Commissionee SHALL signal this to the
Commissioner via the IsCommissioningWithoutPower attribute, the fail-safe timer and the
Cumulative Fail Safe Context timer countdown SHALL be paused, and the connection to the
operational network SHALL be deferred to the setup phase of the Commissioning process.
17. If the IsCommissioningWithoutPower attribute is true, the Commissioner SHALL wait for an
indication that the commissionee is in a power configuration that is capable of joining an operational network before proceeding to the next step.
This concludes the initial phase of the Commissioning process. If the device was fully powered during the initial phase of the Commissioning process then the setup phase SHALL happen immedi­
ately after the end of the initial phase, else the setup phase shall start as soon as the device is powered up and running.
The setup phase of the Commissioning process consists of the following steps:
1. If the device was not fully powered during the initial phase of the Commissioning process then
it SHALL rearm the failsafe timer and the Cumulative Fail Safe Context timer countdowns with
the remaining times that they had when they were paused in the first phase of the Commissioning process, and it SHALL connect to the operational network.
2. The Commissionee SHALL use Section 4.3.2, “Operational Discovery” to be discoverable on the
operational network. An Administrator configured in the ACL of the Commissionee by the Commissioner SHALL use Section 4.3.2, “Operational Discovery” to discover the Commissionee. This
Administrator MAY be the Commissioner itself, or another Node to which the Commissioner has
delegated the task. If the device was not fully powered during the initial phase of the Commissioning process, then the Commissionee MAY pause the fail-safe timer and the Cumulative Fail
Safe Context timer countdown until the Administrator discovers the Commissionee, to give the
Administrator sufficient time to discover the Commissionee.
3. The Administrator SHALL open a CASE (see Section 4.14.2, “Certificate Authenticated Session
Establishment (CASE)”) session with the Commissionee over the operational network.
4. The Administrator having established a CASE session with the Commissionee over the operational network in the previous step SHALL invoke the CommissioningComplete command (see
Section 11.10.7.6, “CommissioningComplete”). A success response after invocation of the CommissioningComplete command ends the commissioning process. In case of NFC-based commis­
sioning, the Commissionee SHALL update the operational discovery service according to the
requirement in Section 4.3.2.5, “Subtypes”.
At this point the Commissioner MAY do additional setup like configure UTC time:
1. If the device supports the Time Synchronization Cluster server:
◦The Commissioner SHOULD configure UTC time using the Section 11.17.9.1, “SetUTCTime”
command.
◦The Commissioner SHOULD set the time zone using the Section 11.17.9.3, “SetTimeZone”
command, if the Section 11.17.5.1, “TimeZone” feature is supported.
◦The Commissioner SHOULD set the DST offsets using the Section 11.17.9.5, “SetDSTOffset”
command if the Section 11.17.5.1, “TimeZone” feature is supported, and the Section 11.17.9.4,
“SetTimeZoneResponse” from the Commissionee had the DSTOffsetRequired field set to
True.
◦The Commissioner SHOULD set a Default NTP server using the Section 11.17.9.6, “SetDefaultNTP” command if the Section 11.17.5.2, “NTPClient” feature is supported and the Section
11.17.8.5, “DefaultNTP” attribute is null. If the current value is non-null, Commissioners MAY
opt to overwrite the current value.
◦The Commissioner SHOULD set a trusted time source using the Section 11.17.9.2, “SetTrustedTimeSource” command if the Section 11.17.5.4, “TimeSyncClient” feature is supported, the
Section 11.17.8.4, “TrustedTimeSource” attribute is null and there is an available trusted
time source on the fabric. The Commissioner SHOULD ensure the ACL on the TrustedTimeSource is set to grant the Commissionee View privilege to the Time Synchronization cluster.
If the TrustedTimeSource is non-null, the Commissioner MAY opt to overwrite the current
value with a node from its own fabric by sending the Section 11.17.9.2, “SetTrustedTimeSource” command.
2. After having used NFC Transport Layer (NTL) as a temporary transport protocol for commissioning, the commissioner SHALL rediscover on the operational network the supported end­
points, clusters, attributes and events of the commissionee. This is necessary since the device
capabilities and state exposed in the initial phase of commissioning (when the device has no
operational power) MAY be a subset of the device capabilities in the setup phase of commissioning and afterwards.
While the Administrator of steps in the setup phase of commissioning will, in many situations, be
the Commissioner Node itself, it MAY be a different Node that was configured by the Commissioner
to have Administer privilege against the Commissionee’s Section 11.10, “General Commissioning
Cluster”. This is to support flexibility in finalizing the Commissioning. From a Commissionee’s perspective, all Nodes with Administer privilege in the Commissionee’s ACL are equivalent once the
Node has a Node Operational Certificate and associated Node Operational Identifier on the Fabric
into which it was just commissioned.
A Commissioner MAY configure UTC time, Operational ID, and Operational certificates, etc., information over an arbitrary number of interactions at the Commissionee, over the operational net­
work after the commissioning is complete, or over the commissioning channel after PASE-derived
encryption keys are established during commissioning.
In concurrent connection commissioning flow the commissioning channel SHALL terminate after
successful setup phase step 4 (CommissioningComplete command invocation). In non-concurrent
connection commissioning flow the commissioning channel SHALL terminate after successful initial phase step 16 (trigger joining of operational network at Commissionee). The PASE-derived
encryption keys SHALL be deleted when commissioning channel terminates. The PASE session
SHALL be terminated by both Commissioner and Commissionee once the CommissioningComplete
command is received by the Commissionee.
In both concurrent connection commissioning flow and non-concurrent connection commissioning
flow, the Commissioner MAY choose to continue commissioning and override the failure in initial
phase step 10 (Commissionee attestation).
