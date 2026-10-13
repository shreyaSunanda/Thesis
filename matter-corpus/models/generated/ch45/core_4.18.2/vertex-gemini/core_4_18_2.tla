---- MODULE core_4_18_2 ----
EXTENDS Naturals

\* Declare EVERY fixed value the spec text mentions (timeouts, limits, thresholds,
\* fabric indices, etc.) here. Give each one a short comment saying what it is.
CONSTANTS 
    \* The set of all supported fabrics
    Fabrics,
    \* The set of all peer node IDs
    NodeIds,
    \* Sentinel value representing no entry for a peer in the table
    NullEntry,
    \* Minimum required capacity limit: "SHALL be at least 10 entries per supported fabric 
    \* for Peer Encrypted Group data Message Status"
    MinDataEntriesPerFabric,
    \* Recommended minimum capacity limit: "SHOULD NOT be less than 5 entries per fabric 
    \* per instance of Groups cluster on an endpoint"
    MinDataEntriesPerFabricPerCluster,
    \* Minimum required capacity limit: "SHALL be at least 2 entries per supported fabric 
    \* for Peer Encrypted Group Control Message Status"
    MinControlEntriesPerFabric

VARIABLES 
    \* The Group Peer State Table.
    \* Stores information about every peer with which the node had a group message exchange.
    \* Maps Fabric -> NodeId -> State Record or NullEntry.
    \* 
    \* State Record fields per spec:
    \* - dataSyncCounter : Integer
    \* - dataSyncValid : Boolean
    \* - dataBitmap : Integer (message reception state bitmap)
    \* - controlSyncCounter : Integer
    \* - controlSyncValid : Boolean
    \* - controlBitmap : Integer (message reception state bitmap)
    groupPeerStateTable

Init == 
    \* SOURCE: core_4.18.2
    \* "There are three scenarios where the receiver of an encrypted message does not know the sender’s
    \* last message counter: The encrypted message is the first received from a peer."
    \* (This implies that initially, there are no entries known for any peer).
    groupPeerStateTable = [f \in Fabrics |-> [n \in NodeIds |-> NullEntry]]

\* SOURCE: core_4.18.2 
\* "The device rebooted without persisting the Group Peer State Table content.
\* NOTE: It is not required to persist the Peer State Table."
RebootWithoutPersistence ==
    groupPeerStateTable' = [f \in Fabrics |-> [n \in NodeIds |-> NullEntry]]

\* SOURCE: core_4.18.2 
\* "The entry for the Peer in the Group Peer State Table was expunged due to the table being full."
ExpungeEntryDueToFullTable ==
    \E f \in Fabrics, n \in NodeIds :
        /\ groupPeerStateTable[f][n] # NullEntry
        /\ groupPeerStateTable' = [groupPeerStateTable EXCEPT ![f][n] = NullEntry]
        \* TODO: unspecified - The exact capacity boundary that triggers "table being full" 
        \* (beyond the minimums of 10 and 2 per fabric) and the specific eviction policy 
        \* for choosing which peer entry to expunge.

Next == 
    \/ RebootWithoutPersistence
    \/ ExpungeEntryDueToFullTable

====