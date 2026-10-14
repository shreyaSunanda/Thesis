---- MODULE core_4_6_7 ----
EXTENDS Naturals

\* Set of all valid Node IDs
CONSTANTS NodeIds

\* Sentinel value representing the absence of a Node ID
CONSTANTS NullNodeId

\* Max allowed message counter (in reality 2^32 - 1, kept small for model checking)
CONSTANTS MaxMsgCounter

\* Size of the validity window for duplicate detection
CONSTANTS WindowSize

\* Upper limit to prevent infinite state space on counter variables
CONSTANTS MaxOperations

\* Sentinel for no pending input
CONSTANTS NoInput

VARIABLES pendingInput
VARIABLES msgSource
VARIABLES msgCFlag
VARIABLES msgCounter

VARIABLES stateExists
VARIABLES stateMaxCounter
VARIABLES stateReceived

VARIABLES dropped
VARIABLES groupUnsync
VARIABLES follow4_6_5_2
VARIABLES follow4_6_5_3
VARIABLES reliableProcessing
VARIABLES accepted

StateKeys ==
    [type : {"Unicast"}, peer : NodeIds \cup {NullNodeId}]
    \cup [type : {"GroupData", "GroupControl"}, peer : NodeIds \cup {NullNodeId}]
    \cup [type : {"Unsecured"}, peer : NodeIds \cup {NullNodeId}]

Inputs == {
    "ReceiveUnicastMessage",
    "ReceiveGroupMessage",
    "ReceiveUnencryptedMessage"
}

Init ==
    /\ pendingInput = NoInput
    /\ msgSource \in NodeIds \cup {NullNodeId}
    /\ msgCFlag \in {0, 1}
    /\ msgCounter \in 0..MaxMsgCounter
    /\ stateExists = [k \in StateKeys |-> FALSE]
    /\ stateMaxCounter = [k \in StateKeys |-> 0]
    /\ stateReceived = [k \in StateKeys |-> {}]
    /\ dropped = 0
    /\ groupUnsync = 0
    /\ follow4_6_5_2 = 0
    /\ follow4_6_5_3 = 0
    /\ reliableProcessing = 0
    /\ accepted = 0

IsOutsideWindow(counter, maxCounter) ==
    counter + WindowSize < maxCounter

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    \* Randomize message fields on new input to explore state space
    /\ \E src \in NodeIds \cup {NullNodeId},
          cFlag \in {0, 1},
          cnt \in 0..MaxMsgCounter :
          /\ msgSource' = src
          /\ msgCFlag' = cFlag
          /\ msgCounter' = cnt
    /\ UNCHANGED <<stateExists, stateMaxCounter, stateReceived, dropped, groupUnsync, follow4_6_5_2, follow4_6_5_3, reliableProcessing, accepted>>

\* SOURCE: core_4.6.7 1.a, 2, 3.a, 3.c
ProcessUnicastMessage_Duplicate ==
    /\ pendingInput = "ReceiveUnicastMessage"
    \* TODO: unspecified - what if Secure Unicast Session Context has no Message Reception State?
    /\ stateExists[[type |-> "Unicast", peer |-> msgSource]] = TRUE
    /\ ( IsOutsideWindow(msgCounter, stateMaxCounter[[type |-> "Unicast", peer |-> msgSource]])
         \/ (msgCounter \in stateReceived[[type |-> "Unicast", peer |-> msgSource]]) )
    /\ follow4_6_5_2 < MaxOperations
    /\ reliableProcessing < MaxOperations
    /\ follow4_6_5_2' = follow4_6_5_2 + 1
    /\ reliableProcessing' = reliableProcessing + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<stateExists, stateMaxCounter, stateReceived, dropped, groupUnsync, follow4_6_5_3, accepted, msgSource, msgCFlag, msgCounter>>

\* SOURCE: core_4.6.7 1.a, 2, 3.d
ProcessUnicastMessage_Accept ==
    /\ pendingInput = "ReceiveUnicastMessage"
    \* TODO: unspecified - what if Secure Unicast Session Context has no Message Reception State?
    /\ stateExists[[type |-> "Unicast", peer |-> msgSource]] = TRUE
    /\ ~( IsOutsideWindow(msgCounter, stateMaxCounter[[type |-> "Unicast", peer |-> msgSource]])
          \/ (msgCounter \in stateReceived[[type |-> "Unicast", peer |-> msgSource]]) )
    /\ accepted < MaxOperations
    /\ accepted' = accepted + 1
    /\ stateReceived' = [stateReceived EXCEPT ![[type |-> "Unicast", peer |-> msgSource]] = @ \cup {msgCounter}]
    /\ stateMaxCounter' = [stateMaxCounter EXCEPT ![[type |-> "Unicast", peer |-> msgSource]] = IF msgCounter > @ THEN msgCounter ELSE @]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<stateExists, dropped, groupUnsync, follow4_6_5_2, follow4_6_5_3, reliableProcessing, msgSource, msgCFlag, msgCounter>>

\* SOURCE: core_4.6.7 1.b.i.A
ProcessGroupMessage_Drop ==
    /\ pendingInput = "ReceiveGroupMessage"
    /\ msgSource = NullNodeId
    /\ dropped < MaxOperations
    /\ dropped' = dropped + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<stateExists, stateMaxCounter, stateReceived, groupUnsync, follow4_6_5_2, follow4_6_5_3, reliableProcessing, accepted, msgSource, msgCFlag, msgCounter>>

\* SOURCE: core_4.6.7 1.b.ii, 1.b.iii
ProcessGroupMessage_Unsync ==
    /\ pendingInput = "ReceiveGroupMessage"
    /\ msgSource # NullNodeId
    /\ IF msgCFlag = 0 
       THEN ~stateExists[[type |-> "GroupData", peer |-> msgSource]]
       ELSE ~stateExists[[type |-> "GroupControl", peer |-> msgSource]]
    /\ groupUnsync < MaxOperations
    /\ groupUnsync' = groupUnsync + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<stateExists, stateMaxCounter, stateReceived, dropped, follow4_6_5_2, follow4_6_5_3, reliableProcessing, accepted, msgSource, msgCFlag, msgCounter>>

\* SOURCE: core_4.6.7 1.b, 2, 3.a, 3.c
ProcessGroupMessage_Duplicate ==
    /\ pendingInput = "ReceiveGroupMessage"
    /\ msgSource # NullNodeId
    /\ IF msgCFlag = 0 
       THEN stateExists[[type |-> "GroupData", peer |-> msgSource]]
       ELSE stateExists[[type |-> "GroupControl", peer |-> msgSource]]
    /\ IF msgCFlag = 0
       THEN ( IsOutsideWindow(msgCounter, stateMaxCounter[[type |-> "GroupData", peer |-> msgSource]]) 
              \/ (msgCounter \in stateReceived[[type |-> "GroupData", peer |-> msgSource]]) )
       ELSE ( IsOutsideWindow(msgCounter, stateMaxCounter[[type |-> "GroupControl", peer |-> msgSource]]) 
              \/ (msgCounter \in stateReceived[[type |-> "GroupControl", peer |-> msgSource]]) )
    /\ follow4_6_5_2 < MaxOperations
    /\ reliableProcessing < MaxOperations
    /\ follow4_6_5_2' = follow4_6_5_2 + 1
    /\ reliableProcessing' = reliableProcessing + 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<stateExists, stateMaxCounter, stateReceived, dropped, groupUnsync, follow4_6_5_3, accepted, msgSource, msgCFlag, msgCounter>>

\* SOURCE: core_4.6.7 1.b, 2, 3.d
ProcessGroupMessage_Accept ==
    /\ pendingInput = "ReceiveGroupMessage"
    /\ msgSource # NullNodeId
    /\ IF msgCFlag = 0 
       THEN stateExists[[type |-> "GroupData", peer |-> msgSource]]
       ELSE stateExists[[type |-> "GroupControl", peer |-> msgSource]]
    /\ IF msgCFlag = 0
       THEN ~( IsOutsideWindow(msgCounter, stateMaxCounter[[type |-> "GroupData", peer |-> msgSource]]) 
               \/ (msgCounter \in stateReceived[[type |-> "GroupData", peer |-> msgSource]]) )
       ELSE ~( IsOutsideWindow(msgCounter, stateMaxCounter[[type |-> "GroupControl", peer |-> msgSource]]) 
               \/ (msgCounter \in stateReceived[[type |-> "GroupControl", peer |-> msgSource]]) )
    /\ accepted < MaxOperations
    /\ accepted' = accepted + 1
    /\ stateReceived' = IF msgCFlag = 0
                        THEN [stateReceived EXCEPT ![[type |-> "GroupData", peer |-> msgSource]] = @ \cup {msgCounter}]
                        ELSE [stateReceived EXCEPT ![[type |-> "GroupControl", peer |-> msgSource]] = @ \cup {msgCounter}]
    /\ stateMaxCounter' = IF msgCFlag = 0
                          THEN [stateMaxCounter EXCEPT ![[type |-> "GroupData", peer |-> msgSource]] = IF msgCounter > @ THEN msgCounter ELSE @]
                          ELSE [stateMaxCounter EXCEPT ![[type |-> "GroupControl", peer |-> msgSource]] = IF msgCounter > @ THEN msgCounter ELSE @]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<stateExists, dropped, groupUnsync, follow4_6_5_2, follow4_6_5_3, reliableProcessing, msgSource, msgCFlag, msgCounter>>

\* SOURCE: core_4.6.7 1.c, 2, 3.b
ProcessUnencryptedMessage_Duplicate ==
    /\ pendingInput = "ReceiveUnencryptedMessage"
    /\ IF stateExists[[type |-> "Unsecured", peer |-> msgSource]]
       THEN ( IsOutsideWindow(msgCounter, stateMaxCounter[[type |-> "Unsecured", peer |-> msgSource]]) 
              \/ (msgCounter \in stateReceived[[type |-> "Unsecured", peer |-> msgSource]]) )
       ELSE ( IsOutsideWindow(msgCounter, msgCounter) 
              \/ (msgCounter \in {}) )
    /\ follow4_6_5_3 < MaxOperations
    /\ follow4_6_5_3' = follow4_6_5_3 + 1
    /\ stateExists' = [stateExists EXCEPT ![[type |-> "Unsecured", peer |-> msgSource]] = TRUE]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<stateMaxCounter, stateReceived, dropped, groupUnsync, follow4_6_5_2, reliableProcessing, accepted, msgSource, msgCFlag, msgCounter>>

\* SOURCE: core_4.6.7 1.c, 2, 3.d
ProcessUnencryptedMessage_Accept ==
    /\ pendingInput = "ReceiveUnencryptedMessage"
    /\ ~( IF stateExists[[type |-> "Unsecured", peer |-> msgSource]]
          THEN ( IsOutsideWindow(msgCounter, stateMaxCounter[[type |-> "Unsecured", peer |-> msgSource]]) 
                 \/ (msgCounter \in stateReceived[[type |-> "Unsecured", peer |-> msgSource]]) )
          ELSE ( IsOutsideWindow(msgCounter, msgCounter) 
                 \/ (msgCounter \in {}) ) )
    /\ accepted < MaxOperations
    /\ accepted' = accepted + 1
    /\ stateExists' = [stateExists EXCEPT ![[type |-> "Unsecured", peer |-> msgSource]] = TRUE]
    /\ stateReceived' = IF stateExists[[type |-> "Unsecured", peer |-> msgSource]]
                        THEN [stateReceived EXCEPT ![[type |-> "Unsecured", peer |-> msgSource]] = @ \cup {msgCounter}]
                        ELSE [stateReceived EXCEPT ![[type |-> "Unsecured", peer |-> msgSource]] = {msgCounter}]
    /\ stateMaxCounter' = IF stateExists[[type |-> "Unsecured", peer |-> msgSource]]
                          THEN [stateMaxCounter EXCEPT ![[type |-> "Unsecured", peer |-> msgSource]] = IF msgCounter > @ THEN msgCounter ELSE @]
                          ELSE [stateMaxCounter EXCEPT ![[type |-> "Unsecured", peer |-> msgSource]] = msgCounter]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<dropped, groupUnsync, follow4_6_5_2, follow4_6_5_3, reliableProcessing, msgSource, msgCFlag, msgCounter>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ProcessUnicastMessage_Duplicate
    \/ ProcessUnicastMessage_Accept
    \/ ProcessGroupMessage_Drop
    \/ ProcessGroupMessage_Unsync
    \/ ProcessGroupMessage_Duplicate
    \/ ProcessGroupMessage_Accept
    \/ ProcessUnencryptedMessage_Duplicate
    \/ ProcessUnencryptedMessage_Accept

====