---- MODULE core_4_6_5 ----
EXTENDS Naturals

\* Sentinel values for when no input is pending or no message data is present.
CONSTANTS NoInput, NoPeer, NoCounter

\* The set of peers we can receive messages from.
CONSTANTS Peers

\* Message counter space limit. Real value per spec: 2^32.
CONSTANTS MaxMessageCounter

VARIABLES state, pendingInput
VARIABLES inPeer, inCounter, historyWindow, applicationMessages

Inputs == {"ReceiveMessage"}

Operational == state = "Running"

Init == 
    /\ state = "Running"
    /\ pendingInput = NoInput
    /\ inPeer = NoPeer
    /\ inCounter = NoCounter
    /\ historyWindow = [p \in Peers |-> {}]
    /\ applicationMessages = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e = "ReceiveMessage" THEN
           \E p \in Peers : 
               \E c \in 0..MaxMessageCounter :
                   /\ inPeer' = p
                   /\ inCounter' = c
       ELSE
           /\ inPeer' = inPeer
           /\ inCounter' = inCounter
    /\ UNCHANGED <<state, historyWindow, applicationMessages>>

\* SOURCE: core_4.6.5
ProcessReceivedMessage ==
    /\ pendingInput = "ReceiveMessage"
    /\ IF inCounter \in historyWindow[inPeer]
       THEN
           \* Duplicate detected: discard before application layer
           /\ historyWindow' = historyWindow
           /\ applicationMessages' = applicationMessages
       ELSE
           \* Not a duplicate: deliver to application layer and update history window
           /\ historyWindow' = [historyWindow EXCEPT ![inPeer] = historyWindow[inPeer] \cup {inCounter}]
           /\ applicationMessages' = applicationMessages \cup {[peer |-> inPeer, counter |-> inCounter]}
    /\ pendingInput' = NoInput
    /\ inPeer' = NoPeer
    /\ inCounter' = NoCounter
    /\ state' = state

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ProcessReceivedMessage

====