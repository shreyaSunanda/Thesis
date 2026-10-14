---- MODULE core_4_18_2 ----
EXTENDS Naturals, FiniteSets

CONSTANTS
    NoInput,
    Fabrics,
    Peers,
    NoEntry,
    \* Limits for the number of entries per fabric.
    \* Spec says at least 10 for data, 2 for control.
    DataCapacity,
    ControlCapacity,
    \* Sentinel values for empty table entries
    NoCounter,
    NoBitmap

VARIABLES
    pendingInput,
    msgFabric,
    msgPeer,
    msgType,
    dataState,
    controlState

Inputs == {"ReceiveEncryptedMessage", "Reboot"}

EmptyState == [
    syncCounter |-> NoCounter,
    isValid     |-> FALSE,
    bitmap      |-> NoBitmap
]

Init ==
    /\ pendingInput = NoInput
    /\ msgFabric \in Fabrics
    /\ msgPeer \in Peers
    /\ msgType \in {"Data", "Control"}
    /\ dataState = [pair \in Fabrics \X Peers |-> NoEntry]
    /\ controlState = [pair \in Fabrics \X Peers |-> NoEntry]

DataEntries(f) == {p \in Peers : dataState[<<f, p>>] # NoEntry}
ControlEntries(f) == {p \in Peers : controlState[<<f, p>>] # NoEntry}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \/ /\ e = "ReceiveEncryptedMessage"
          /\ \E f \in Fabrics, p \in Peers, t \in {"Data", "Control"} :
                 /\ msgFabric' = f
                 /\ msgPeer' = p
                 /\ msgType' = t
          /\ UNCHANGED <<dataState, controlState>>
       \/ /\ e # "ReceiveEncryptedMessage"
          /\ UNCHANGED <<msgFabric, msgPeer, msgType, dataState, controlState>>

\* SOURCE: core_4.18.2 "There are three scenarios where the receiver of an encrypted message does not know the sender’s last message counter... The encrypted message is the first received from a peer."
\* SOURCE: core_4.18.2 "The Group Peer State Table stores information about every peer with which the node had a group message exchange."
ReceiveEncryptedMessage ==
    /\ pendingInput = "ReceiveEncryptedMessage"
    /\ pendingInput' = NoInput
    /\ \/ /\ msgType = "Data"
          /\ \/ /\ dataState[<<msgFabric, msgPeer>>] = NoEntry
                /\ Cardinality(DataEntries(msgFabric)) < DataCapacity
                /\ dataState' = [dataState EXCEPT ![<<msgFabric, msgPeer>>] = EmptyState]
             \/ /\ dataState[<<msgFabric, msgPeer>>] = NoEntry
                /\ Cardinality(DataEntries(msgFabric)) >= DataCapacity
                \* TODO: unspecified - how an entry is added when the table is full (whether it inline expunges or fails)
                /\ dataState' = dataState
             \/ /\ dataState[<<msgFabric, msgPeer>>] # NoEntry
                \* TODO: unspecified - how the window/counter is updated on subsequent messages
                /\ dataState' = dataState
          /\ UNCHANGED controlState
       \/ /\ msgType = "Control"
          /\ \/ /\ controlState[<<msgFabric, msgPeer>>] = NoEntry
                /\ Cardinality(ControlEntries(msgFabric)) < ControlCapacity
                /\ controlState' = [controlState EXCEPT ![<<msgFabric, msgPeer>>] = EmptyState]
             \/ /\ controlState[<<msgFabric, msgPeer>>] = NoEntry
                /\ Cardinality(ControlEntries(msgFabric)) >= ControlCapacity
                \* TODO: unspecified - how an entry is added when the table is full
                /\ controlState' = controlState
             \/ /\ controlState[<<msgFabric, msgPeer>>] # NoEntry
                \* TODO: unspecified - how the window/counter is updated on subsequent messages
                /\ controlState' = controlState
          /\ UNCHANGED dataState
    /\ UNCHANGED <<msgFabric, msgPeer, msgType>>

\* SOURCE: core_4.18.2 "The device rebooted without persisting the Group Peer State Table content."
Reboot ==
    /\ pendingInput = "Reboot"
    /\ pendingInput' = NoInput
    /\ dataState' = [pair \in Fabrics \X Peers |-> NoEntry]
    /\ controlState' = [pair \in Fabrics \X Peers |-> NoEntry]
    /\ UNCHANGED <<msgFabric, msgPeer, msgType>>

\* SOURCE: core_4.18.2 "The entry for the Peer in the Group Peer State Table was expunged due to the table being full."
ExpungeDataEntry ==
    /\ pendingInput = NoInput
    /\ \E f \in Fabrics :
        /\ Cardinality(DataEntries(f)) >= DataCapacity
        /\ \E p \in DataEntries(f) :
            /\ dataState' = [dataState EXCEPT ![<<f, p>>] = NoEntry]
    /\ UNCHANGED <<pendingInput, controlState, msgFabric, msgPeer, msgType>>

\* SOURCE: core_4.18.2 "The entry for the Peer in the Group Peer State Table was expunged due to the table being full."
ExpungeControlEntry ==
    /\ pendingInput = NoInput
    /\ \E f \in Fabrics :
        /\ Cardinality(ControlEntries(f)) >= ControlCapacity
        /\ \E p \in ControlEntries(f) :
            /\ controlState' = [controlState EXCEPT ![<<f, p>>] = NoEntry]
    /\ UNCHANGED <<pendingInput, dataState, msgFabric, msgPeer, msgType>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ReceiveEncryptedMessage
    \/ Reboot
    \/ ExpungeDataEntry
    \/ ExpungeControlEntry

====