---- MODULE core_4_6_7 ----
EXTENDS Naturals

\* Declare fixed values mentioned in the spec text.
CONSTANTS 
    NoInput,
    NullNodeId,             \* Used when there is no Source Node ID for the message
    MaxMessageCounter,      \* Abstract maximum message counter (e.g., to represent 2^32 - 1)
    WindowSize,             \* The lossy compression window size for the bitmap
    Peers,                  \* Set of known peer node IDs
    NullState               \* Sentinel to represent the absence of a Message Reception State

VARIABLES 
    pendingInput,           \* the event currently waiting, or NoInput
    rxStates,               \* the mapping of contexts to their Message Reception States
    lastProcessedMsg,       \* the full message data being processed in the current transition
    msgOutcome              \* the recorded outcome/routing decision for the message

\* The only explicit event required to drive this module
Inputs == {"ReceiveMessage"}

\* The module models standard protocol operation where processing is always active
Operational == TRUE

\* Valid counter range to ensure a finite state space for the model checker
CounterValues == 0..MaxMessageCounter

\* Contexts map peer and session types to a specific reception state
Contexts == (Peers \times {"Unicast", "GroupData", "GroupControl"}) \cup {"Unsecured"}

\* A record defining the shape of incoming messages
Messages == [
    type : {"Unicast", "Group", "Unencrypted"},
    sourceId : Peers \cup {NullNodeId},
    cFlag : {0, 1},
    counter : CounterValues,
    encrypted : BOOLEAN
]

NoMsg == [
    type |-> "None",
    sourceId |-> NullNodeId,
    cFlag |-> 0,
    counter |-> 0,
    encrypted |-> FALSE
]

Init ==
    /\ pendingInput = NoInput
    /\ rxStates = [c \in Contexts |-> NullState]
    /\ lastProcessedMsg = NoMsg
    /\ msgOutcome = "None"

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<rxStates, lastProcessedMsg, msgOutcome>>

GetContext(msg) ==
    CASE msg.type = "Unicast" -> <<msg.sourceId, "Unicast">>
      [] msg.type = "Group" /\ msg.cFlag = 0 -> <<msg.sourceId, "GroupData">>
      [] msg.type = "Group" /\ msg.cFlag = 1 -> <<msg.sourceId, "GroupControl">>
      [] msg.type = "Unencrypted" -> "Unsecured"

IsBehindWindow(c, st) == c + WindowSize < st.max_counter

IsReceived(c, st) == c \in st.received

IsDuplicate(msg, st) ==
    IF msg.encrypted THEN
        IsBehindWindow(msg.counter, st) \/ IsReceived(msg.counter, st)
    ELSE
        ~IsBehindWindow(msg.counter, st) /\ (msg.counter <= st.max_counter) /\ IsReceived(msg.counter, st)

UpdatedState(msg, baseState) ==
    IF msg.counter > baseState.max_counter THEN
        [max_counter |-> msg.counter,
         received    |-> {x \in baseState.received \cup {msg.counter} : x + WindowSize >= msg.counter}]
    ELSE
        [max_counter |-> baseState.max_counter,
         received    |-> baseState.received \cup {msg.counter}]

\* SOURCE: core_4.6.7
ProcessIncomingMessage ==
    /\ pendingInput = "ReceiveMessage"
    /\ \E msg \in Messages :
        \* Enforce that Unicast/Group are encrypted contexts, and Unencrypted is not.
        /\ IF msg.type \in {"Unicast", "Group"} THEN msg.encrypted = TRUE ELSE msg.encrypted = FALSE
        /\ lastProcessedMsg' = msg
        /\ LET ctx == GetContext(msg) IN
           IF msg.type = "Group" /\ msg.sourceId = NullNodeId THEN
               \* 1.b.i.A: If there is no Source Node ID for the message, drop the message.
               /\ msgOutcome' = "Dropped_NoSourceNodeId"
               /\ UNCHANGED rxStates
           ELSE IF msg.type = "Group" /\ rxStates[ctx] = NullState THEN
               \* 1.b.iii: If there is no Message Reception State for the groupcast message, initiate Section 4.18.4
               /\ msgOutcome' = "InitiatedUnsynchronizedMessageProcessing"
               /\ UNCHANGED rxStates
           ELSE IF msg.type = "Unicast" /\ rxStates[ctx] = NullState THEN
               \* TODO: unspecified - what to do if a decrypted unicast message arrives but there is no session-specific state
               /\ msgOutcome' = "Unspecified_UnicastNoState"
               /\ UNCHANGED rxStates
           ELSE
               LET baseState ==
                   IF msg.type = "Unencrypted" /\ rxStates[ctx] = NullState THEN
                       \* 1.c.ii: create it with the information from the given message
                       [max_counter |-> 0, received |-> {}]
                   ELSE
                       rxStates[ctx]
               IN
               LET isDup == IsDuplicate(msg, baseState) IN
               IF msg.encrypted /\ isDup THEN
                   \* 3.c: If the message is encrypted and marked as a duplicate ... Perform Section 4.12.5.2
                   /\ msgOutcome' = "InitiatedReliableMessageProcessing"
                   /\ UNCHANGED rxStates
               ELSE IF ~msg.encrypted /\ isDup THEN
                   \* TODO: unspecified - section 4.6.7 Step 3 does not explicitly define the action for unencrypted duplicates
                   /\ msgOutcome' = "Unspecified_UnencryptedDuplicate"
                   /\ UNCHANGED rxStates
               ELSE
                   \* 3.d: Otherwise, update the Message Reception State as detailed in 4.6.5.1, and accept the message
                   /\ msgOutcome' = "Accepted"
                   /\ rxStates' = [rxStates EXCEPT ![ctx] = UpdatedState(msg, baseState)]
    /\ pendingInput' = NoInput

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ProcessIncomingMessage

====