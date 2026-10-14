---- MODULE core_4_18_3_2 ----
EXTENDS Naturals

\* Sentinel value for no pending input event.
CONSTANTS NoInput

VARIABLES pendingInput
VARIABLES reqChallenge
VARIABLES dataMessageCounter
VARIABLES outMessage

\* The only event described in this section is receiving a MsgCounterSyncReq.
Inputs == {"MsgCounterSyncReq"}

Init ==
    /\ pendingInput = NoInput
    /\ reqChallenge = 0
    /\ dataMessageCounter = 0
    /\ outMessage = NoInput

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<reqChallenge, dataMessageCounter, outMessage>>

\* Helper to construct the response message outside of conjunction list
SyncRsp(counter, challenge) == [
    type                |-> "MsgCounterSyncRsp",
    cFlag               |-> TRUE,
    messageProtection   |-> "ControlMessageCounter",
    synchronizedCounter |-> counter,
    response            |-> challenge
]

\* SOURCE: core_4.18.3.2 MsgCounterSyncRsp - Message Counter Synchronization Response
HandleMsgCounterSyncReq ==
    /\ pendingInput = "MsgCounterSyncReq"
    /\ outMessage' = SyncRsp(dataMessageCounter, reqChallenge)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<reqChallenge, dataMessageCounter>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleMsgCounterSyncReq

====