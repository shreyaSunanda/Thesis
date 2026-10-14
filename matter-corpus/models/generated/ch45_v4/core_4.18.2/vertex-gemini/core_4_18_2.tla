---- MODULE core_4_18_2 ----
EXTENDS Naturals

\* The set of all supported fabrics on the node.
CONSTANTS Fabrics

\* The set of all peer node IDs.
CONSTANTS NodeIds

\* Minimum entries per fabric for Data Message Status (Spec: SHALL be at least 10)
CONSTANTS MinDataEntriesPerFabric

\* Minimum entries per fabric for Control Message Status (Spec: SHALL be at least 2)
CONSTANTS MinControlEntriesPerFabric

\* Maximum counter value for the finite state space
CONSTANTS MaxCounter

\* Sentinel values
CONSTANTS NoInput
CONSTANTS NoEntry
CONSTANTS NoCounter
CONSTANTS NoFabric
CONSTANTS NoNodeId
CONSTANTS NoType

VARIABLES state
VARIABLES pendingInput

\* Input event data
VARIABLES inputFabric
VARIABLES inputNodeId
VARIABLES inputType
VARIABLES inputCounter

\* The Group Peer State Table
VARIABLES groupPeerTable

Inputs == {
    "Reboot",
    "ExpungeEntry",
    "ReceiveEncryptedMessage"
}

\* Helper defining the structure of a counter status as described in the spec
EmptyCounterStatus == [
    syncCounter |-> NoCounter,
    isValid     |-> FALSE,
    bitmap      |-> {}
]

\* Helper defining the structure of a full peer entry as described in the spec
EmptyPeerEntry == [
    dataStatus    |-> EmptyCounterStatus,
    controlStatus |-> EmptyCounterStatus
]

Init ==
    /\ state = "Running"
    /\ pendingInput = NoInput
    /\ inputFabric = NoFabric
    /\ inputNodeId = NoNodeId
    /\ inputType = NoType
    /\ inputCounter = NoCounter
    /\ groupPeerTable = [f \in Fabrics, n \in NodeIds |-> NoEntry]

Operational == TRUE

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ inputFabric' \in Fabrics
    /\ inputNodeId' \in NodeIds
    /\ inputType' \in {"Data", "Control"}
    /\ inputCounter' \in 0..MaxCounter
    /\ UNCHANGED <<state, groupPeerTable>>

\* SOURCE: core_4.18.2
\* There are three scenarios where the receiver of an encrypted message does not know the sender’s last message counter:
\* ... The device rebooted without persisting the Group Peer State Table content.
Reboot ==
    /\ pendingInput = "Reboot"
    /\ groupPeerTable' = [f \in Fabrics, n \in NodeIds |-> NoEntry]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputFabric, inputNodeId, inputType, inputCounter>>

\* SOURCE: core_4.18.2
\* There are three scenarios where the receiver of an encrypted message does not know the sender’s last message counter:
\* ... The entry for the Peer in the Group Peer State Table was expunged due to the table being full.
ExpungeEntry ==
    /\ pendingInput = "ExpungeEntry"
    /\ groupPeerTable' = [groupPeerTable EXCEPT ![inputFabric, inputNodeId] = NoEntry]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputFabric, inputNodeId, inputType, inputCounter>>

\* SOURCE: core_4.18.2
\* There are three scenarios where the receiver of an encrypted message does not know the sender’s last message counter:
\* ... The encrypted message is the first received from a peer.
\* The next sections describe the functional protocol used to request message counter synchronization and form responses to such message counter synchronization requests.
ReceiveEncryptedMessage ==
    /\ pendingInput = "ReceiveEncryptedMessage"
    \* TODO: unspecified - The spec identifies scenarios where the counter is unknown but leaves the handling to the subsequent synchronization protocol sections.
    /\ groupPeerTable' = groupPeerTable
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, inputFabric, inputNodeId, inputType, inputCounter>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ Reboot
    \/ ExpungeEntry
    \/ ReceiveEncryptedMessage

====