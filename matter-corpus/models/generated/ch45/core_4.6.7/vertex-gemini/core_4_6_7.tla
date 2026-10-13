---- MODULE core_4_6_7 ----
EXTENDS Naturals

\* Set of all valid Node IDs in the system.
CONSTANTS Nodes

\* Represents the absence of a Source Node ID.
CONSTANTS NullNode

\* Valid message counter window size (e.g., 32).
CONSTANTS WindowSize

\* Maximum value for message counters. Kept small for model checking enumeration.
\* Real value per spec: 2^32 - 1.
CONSTANTS MaxCounter

VARIABLES 
    incomingMessages,
    unicastStates,
    groupDataStates,
    groupCtrlStates,
    unsecuredStates,
    droppedMessages,
    unsyncMessages,
    reliableMessages,
    acceptedMessages

NullState == "Null"

Init == 
    /\ incomingMessages = {}
    /\ unicastStates = [n \in Nodes \cup {NullNode} |-> NullState]
    /\ groupDataStates = [n \in Nodes \cup {NullNode} |-> NullState]
    /\ groupCtrlStates = [n \in Nodes \cup {NullNode} |-> NullState]
    /\ unsecuredStates = [n \in Nodes \cup {NullNode} |-> NullState]
    /\ droppedMessages = {}
    /\ unsyncMessages = {}
    /\ reliableMessages = {}
    /\ acceptedMessages = {}

IsOutsideWindow(max, counter) ==
    max >= WindowSize /\ counter < (max - WindowSize)

\* SOURCE: core_4.6.5.2
\* SOURCE: core_4.6.5.3
IsDuplicate(state, counter, isEncrypted) ==
    IF isEncrypted THEN
        \/ counter \in state.seenCounters
        \/ IsOutsideWindow(state.maxCounter, counter)
    ELSE
        \/ counter = state.maxCounter
        \/ (counter \in state.seenCounters /\ ~IsOutsideWindow(state.maxCounter, counter))

\* TODO: unspecified - 4.6.5.3 says unencrypted messages behind the window update max_message_counter, 
\* which might imply resetting it, but doing so for out-of-order messages within the window would break 
\* the window mechanism. Abstracting to standard maximum logic.
UpdateState(state, counter) ==
    LET newMax == IF counter > state.maxCounter THEN counter ELSE state.maxCounter IN
    [ maxCounter   |-> newMax,
      seenCounters |-> {c \in state.seenCounters \cup {counter} : ~IsOutsideWindow(newMax, c)} ]

\* SOURCE: core_4.6.7
ProcessIncomingMessage(m) ==
    /\ m \in incomingMessages
    /\ incomingMessages' = incomingMessages \ {m}
    /\ LET stateOpt == IF m.type = "Unicast" THEN unicastStates[m.sourceNodeId]
                       ELSE IF m.type = "Group" /\ m.sourceNodeId # NullNode /\ m.cFlag = 0 THEN groupDataStates[m.sourceNodeId]
                       ELSE IF m.type = "Group" /\ m.sourceNodeId # NullNode /\ m.cFlag = 1 THEN groupCtrlStates[m.sourceNodeId]
                       ELSE IF m.type = "Unencrypted" THEN unsecuredStates[m.sourceNodeId]
                       ELSE NullState
       IN
       IF m.type = "Group" /\ m.sourceNodeId = NullNode THEN
           \* SOURCE: core_4.6.7 1.b.i.A
           /\ droppedMessages' = droppedMessages \cup {m}
           /\ UNCHANGED <<unicastStates, groupDataStates, groupCtrlStates, unsecuredStates, unsyncMessages, reliableMessages, acceptedMessages>>
       ELSE IF m.type = "Group" /\ stateOpt = NullState THEN
           \* SOURCE: core_4.6.7 1.b.iii
           /\ unsyncMessages' = unsyncMessages \cup {m}
           /\ UNCHANGED <<unicastStates, groupDataStates, groupCtrlStates, unsecuredStates, droppedMessages, reliableMessages, acceptedMessages>>
       ELSE IF m.type = "Unencrypted" /\ stateOpt = NullState THEN
           \* SOURCE: core_4.6.7 1.c.ii
           /\ acceptedMessages' = acceptedMessages \cup {m}
           /\ unsecuredStates' = [unsecuredStates EXCEPT ![m.sourceNodeId] = [maxCounter |-> m.counter, seenCounters |-> {m.counter}]]
           /\ UNCHANGED <<unicastStates, groupDataStates, groupCtrlStates, droppedMessages, unsyncMessages, reliableMessages>>
       ELSE IF m.type = "Unicast" /\ stateOpt = NullState THEN
           \* TODO: unspecified - Spec does not state what happens if Unicast message arrives but no session state exists. Dropping it.
           /\ droppedMessages' = droppedMessages \cup {m}
           /\ UNCHANGED <<unicastStates, groupDataStates, groupCtrlStates, unsecuredStates, unsyncMessages, reliableMessages, acceptedMessages>>
       ELSE
           \* Determine if duplicate based on valid window (core_4.6.7 2) and state properties (core_4.6.7 3.a/3.b)
           LET isDup == IsDuplicate(stateOpt, m.counter, m.isEncrypted) IN
           IF isDup THEN
               \* SOURCE: core_4.6.7 3.c
               /\ IF m.isEncrypted THEN
                      reliableMessages' = reliableMessages \cup {m}
                  ELSE
                      UNCHANGED reliableMessages
               /\ droppedMessages' = droppedMessages \cup {m}
               /\ UNCHANGED <<unicastStates, groupDataStates, groupCtrlStates, unsecuredStates, unsyncMessages, acceptedMessages>>
           ELSE
               \* SOURCE: core_4.6.7 3.d
               LET newState == UpdateState(stateOpt, m.counter) IN
               /\ acceptedMessages' = acceptedMessages \cup {m}
               /\ IF m.type = "Unicast" THEN
                      /\ unicastStates' = [unicastStates EXCEPT ![m.sourceNodeId] = newState]
                      /\ UNCHANGED <<groupDataStates, groupCtrlStates, unsecuredStates>>
                  ELSE IF m.type = "Group" /\ m.cFlag = 0 THEN
                      /\ groupDataStates' = [groupDataStates EXCEPT ![m.sourceNodeId] = newState]
                      /\ UNCHANGED <<unicastStates, groupCtrlStates, unsecuredStates>>
                  ELSE IF m.type = "Group" /\ m.cFlag = 1 THEN
                      /\ groupCtrlStates' = [groupCtrlStates EXCEPT ![m.sourceNodeId] = newState]
                      /\ UNCHANGED <<unicastStates, groupDataStates, unsecuredStates>>
                  ELSE 
                      /\ unsecuredStates' = [unsecuredStates EXCEPT ![m.sourceNodeId] = newState]
                      /\ UNCHANGED <<unicastStates, groupDataStates, groupCtrlStates>>
               /\ UNCHANGED <<droppedMessages, unsyncMessages, reliableMessages>>

Next == 
    \E m \in incomingMessages : ProcessIncomingMessage(m)

====