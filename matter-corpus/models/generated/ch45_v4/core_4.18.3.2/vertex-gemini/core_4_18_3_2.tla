---- MODULE core_4_18_3_2 ----
EXTENDS Naturals

\* Sentinel value for no incoming event
CONSTANTS NoInput

VARIABLES
    pendingInput,
    reqChallenge,           \* The 64-bit challenge value from the corresponding MsgCounterSyncReq
    dataMessageCounter,     \* The current data message counter for this node
    controlMessageCounter,  \* The control message counter used for message protection
    outbox                  \* Holds the generated response message

Inputs == {"MsgCounterSyncReq"}

Init ==
    /\ pendingInput = NoInput
    /\ reqChallenge = 0
    /\ dataMessageCounter = 0
    /\ controlMessageCounter = 0
    /\ outbox = [type |-> "None"]

Operational == TRUE

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<reqChallenge, dataMessageCounter, controlMessageCounter, outbox>>

ConstructMsgCounterSyncRsp(ctrlCounter, dataCounter, challenge) ==
    [type |-> "MsgCounterSyncRsp",
     cFlag |-> TRUE,
     messageProtectionCounter |-> ctrlCounter,
     synchronizedCounter |-> dataCounter,
     response |-> challenge]

\* SOURCE: core_4.18.3.2
\* The MsgCounterSyncRsp message is sent in response to a MsgCounterSyncReq.
\* A MsgCounterSyncRsp message SHALL set the C Flag in the message header.
\* The control message counter SHALL be used for message protection.
\* Table 27. Message Counter Sync Response
HandleMsgCounterSyncReq ==
    /\ pendingInput = "MsgCounterSyncReq"
    /\ outbox' = ConstructMsgCounterSyncRsp(controlMessageCounter, dataMessageCounter, reqChallenge)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<reqChallenge, dataMessageCounter, controlMessageCounter>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleMsgCounterSyncReq

====