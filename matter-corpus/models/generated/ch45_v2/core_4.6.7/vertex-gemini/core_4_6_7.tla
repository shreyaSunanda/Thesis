---- MODULE core_4_6_7 ----
EXTENDS Naturals

\* The valid message counter window size (e.g., 32 per spec, abstracted to a small integer for checking)
CONSTANTS WindowSize
\* The set of all possible sending peers for Unicast messages
CONSTANTS Peers
\* The set of all possible Node IDs for Group messages
CONSTANTS Nodes
\* A sentinel value representing the absence of a value (e.g., no state or no source node ID)
CONSTANTS NullValue

\* Mandatory inputs
CONSTANTS NoInput, Inputs
VARIABLES pendingInput

\* Message reception state contexts
VARIABLES unicastState
VARIABLES groupDataState
VARIABLES groupControlState
VARIABLES unsecuredState

\* Processing outcomes / actions
VARIABLES dropped
VARIABLES unsyncProcessed
VARIABLES reliableProcessed
VARIABLES accepted

Init ==
    /\ pendingInput = NoInput
    /\ unicastState = [p \in Peers |-> NullValue]
    /\ groupDataState = [n \in Nodes |-> NullValue]
    /\ groupControlState = [n \in Nodes |-> NullValue]
    /\ unsecuredState = NullValue
    /\ dropped = {}
    /\ unsyncProcessed = {}
    /\ reliableProcessed = {}
    /\ accepted = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<unicastState, groupDataState, groupControlState, unsecuredState, dropped, unsyncProcessed, reliableProcessed, accepted>>

\* Helpers for Message Reception State logic
IsOutsideWindow(state, c) ==
    state.maxCounter > WindowSize /\ c < state.maxCounter - WindowSize

IsDuplicate(state, c) ==
    \/ c \in state.received
    \/ IsOutsideWindow(state, c)

UpdateState(state, c) ==
    [maxCounter |-> IF c > state.maxCounter THEN c ELSE state.maxCounter,
     received   |-> state.received \cup {c}]

\* SOURCE: core_4.6.7 1-3
ProcessMessage ==
    /\ pendingInput # NoInput
    /\ LET m == pendingInput IN
           \/ /\ m.type = "Group"
              /\ m.sourceNodeId = NullValue
              \* 1.b.i.A: If there is no Source Node ID for the message, drop the message.
              /\ dropped' = dropped \cup {m}
              /\ pendingInput' = NoInput
              /\ UNCHANGED <<unicastState, groupDataState, groupControlState, unsecuredState, unsyncProcessed, reliableProcessed, accepted>>
              
           \/ /\ m.type = "Group"
              /\ m.sourceNodeId # NullValue
              /\ (IF m.cFlag = 0 THEN groupDataState[m.sourceNodeId] ELSE groupControlState[m.sourceNodeId]) = NullValue
              \* 1.b.iii: If there is no Message Reception State for the groupcast message, initiate Unsynchronized Message Processing.
              /\ unsyncProcessed' = unsyncProcessed \cup {m}
              /\ pendingInput' = NoInput
              /\ UNCHANGED <<unicastState, groupDataState, groupControlState, unsecuredState, dropped, reliableProcessed, accepted>>
              
           \/ /\ \/ (m.type = "Unicast" /\ unicastState[m.sender] # NullValue)
                 \* TODO: unspecified - spec 1.a.i says "Get the session-specific Message Reception State". It does not specify what to do if the context doesn't exist for Unicast.
                 \/ (m.type = "Group" /\ m.sourceNodeId # NullValue /\ (IF m.cFlag = 0 THEN groupDataState[m.sourceNodeId] ELSE groupControlState[m.sourceNodeId]) # NullValue)
                 \/ (m.type = "Unencrypted")
              /\ LET
                     currentState ==
                         CASE m.type = "Unicast" -> unicastState[m.sender]
                           [] m.type = "Group" -> (IF m.cFlag = 0 THEN groupDataState[m.sourceNodeId] ELSE groupControlState[m.sourceNodeId])
                           [] m.type = "Unencrypted" -> unsecuredState
                     
                     \* 1.c.ii: If there is no Message Reception State for the unencrypted message, create it with info from given message.
                     workingState ==
                         IF m.type = "Unencrypted" /\ currentState = NullValue
                         THEN [maxCounter |-> m.counter, received |-> {}]
                         ELSE currentState
                         
                     \* 2: Check if message is a duplicate.
                     isDup == IsDuplicate(workingState, m.counter)
                 IN
                     IF isDup THEN
                         IF m.isEncrypted THEN
                             \* 3.c: If encrypted and marked duplicate, perform Reliable Message Processing.
                             /\ reliableProcessed' = reliableProcessed \cup {m}
                             /\ pendingInput' = NoInput
                             /\ UNCHANGED <<unicastState, groupDataState, groupControlState, unsecuredState, dropped, unsyncProcessed, accepted>>
                         ELSE
                             \* TODO: unspecified - spec 3.b says "follow 4.6.5.3" for unencrypted duplicates, but lacks an explicit outcome (like drop or reliable processing).
                             FALSE
                     ELSE
                         \* 3.d: Otherwise, update Message Reception State and accept the message.
                         LET newState == UpdateState(workingState, m.counter) IN
                         /\ unicastState' = IF m.type = "Unicast" THEN [unicastState EXCEPT ![m.sender] = newState] ELSE unicastState
                         /\ groupDataState' = IF m.type = "Group" /\ m.cFlag = 0 THEN [groupDataState EXCEPT ![m.sourceNodeId] = newState] ELSE groupDataState
                         /\ groupControlState' = IF m.type = "Group" /\ m.cFlag = 1 THEN [groupControlState EXCEPT ![m.sourceNodeId] = newState] ELSE groupControlState
                         /\ unsecuredState' = IF m.type = "Unencrypted" THEN newState ELSE unsecuredState
                         /\ accepted' = accepted \cup {m}
                         /\ pendingInput' = NoInput
                         /\ UNCHANGED <<dropped, unsyncProcessed, reliableProcessed>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ProcessMessage

====