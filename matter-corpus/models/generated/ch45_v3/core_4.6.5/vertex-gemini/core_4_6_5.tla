---- MODULE core_4_6_5 ----
EXTENDS Naturals

\* The set of peers/nodes that can send messages.
CONSTANTS Senders

\* The upper bound for message counters to ensure a finite state space.
\* Real value per spec: 2^32.
CONSTANTS MaxCounter

\* REQUIRED: sentinel for no pending input
CONSTANTS NoInput

VARIABLES 
    pendingInput,
    msgSender,                \* Sender of the currently pending message
    msgCounter,               \* Counter of the currently pending message
    history,                  \* Message reception state: history window per sender
    applicationLayerMessages  \* Messages that have successfully passed the duplicate check

\* REQUIRED: List of every event this section can receive
Inputs == {"ReceiveMessage"}

Init ==
    /\ pendingInput = NoInput
    /\ msgSender \in Senders
    /\ msgCounter \in 0..MaxCounter
    /\ history = [s \in Senders |-> {}]
    /\ applicationLayerMessages = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<msgSender, msgCounter, history, applicationLayerMessages>>

AcceptedMessage(s, c) == [sender |-> s, counter |-> c]

\* SOURCE: core_4.6.5
\* "Whenever a message is received, its message counter is checked against the history window 
\* of message counters from that sender to determine whether it is a duplicate. The Message Layer 
\* SHALL discard duplicate messages before they reach the application layer."
\* TODO: unspecified - Section 4.6.5.1 states message reception state uses a "lossy compression scheme" 
\* and is "structured as a pair of [text cuts off]". We abstract this as a complete set of received counters.
ProcessReceiveMessage ==
    /\ pendingInput = "ReceiveMessage"
    /\ IF msgCounter \in history[msgSender]
       THEN 
           \* Duplicate detected: discard (do not add to application layer or update history)
           /\ UNCHANGED <<history, applicationLayerMessages>>
       ELSE 
           \* Not a duplicate: maintain in history window and pass to application layer
           /\ history' = [history EXCEPT ![msgSender] = history[msgSender] \cup {msgCounter}]
           /\ applicationLayerMessages' = applicationLayerMessages \cup {AcceptedMessage(msgSender, msgCounter)}
    /\ pendingInput' = NoInput
    \* Non-deterministically pick the next message's data to simulate arbitrary incoming messages
    /\ \E s \in Senders, c \in 0..MaxCounter :
           /\ msgSender' = s
           /\ msgCounter' = c

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ProcessReceiveMessage

====