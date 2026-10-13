---- MODULE core_4_18_3_2 ----
EXTENDS Naturals

CONSTANTS 
    \* Set of all participating nodes in the network
    Nodes

VARIABLES 
    \* Set of all messages sent in the network
    network,
    \* Map from Node to its current data message counter (4 bytes)
    dataMessageCounter

Init == 
    /\ network = {}
    /\ dataMessageCounter = [n \in Nodes |-> 0]

MsgCounterSyncRsp(node, destNode, counter, challenge) ==
    [type                |-> "MsgCounterSyncRsp",
     sender              |-> node,
     dest                |-> destNode,
     cFlag               |-> TRUE,
     protection          |-> "controlMessageCounter",
     synchronizedCounter |-> counter,
     response            |-> challenge]

\* SOURCE: core_4.18.3.2 
\* "The Message Counter Synchronization Response (MsgCounterSyncRsp) message is sent in response
\* to a MsgCounterSyncReq."
\* "A MsgCounterSyncRsp message SHALL set the C Flag in the message header."
\* "The control message counter SHALL be used for message protection."
\* "Synchronized Counter: The current data message counter for the node sending the MsgCounterSyncRsp message."
\* "Response: The Response SHALL be the same as the 64-bit value sent in the Challenge field of the corresponding MsgCounterSyncReq."
SendMsgCounterSyncRsp(node, reqMsg) ==
    /\ reqMsg \in network
    /\ reqMsg.type = "MsgCounterSyncReq"
    /\ reqMsg.dest = node
    /\ network' = network \cup {MsgCounterSyncRsp(node, reqMsg.sender, dataMessageCounter[node], reqMsg.challenge)}
    /\ UNCHANGED dataMessageCounter

Next == 
    \E n \in Nodes : \E msg \in network : SendMsgCounterSyncRsp(n, msg)

====