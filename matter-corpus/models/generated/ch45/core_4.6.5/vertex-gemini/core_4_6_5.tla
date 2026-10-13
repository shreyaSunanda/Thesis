---- MODULE core_4_6_5 ----
EXTENDS Naturals

CONSTANTS 
    \* Set of all possible senders/peers
    Senders,
    \* Set of all possible message counters
    MessageCounters,
    \* Sentinel value representing no message currently being processed
    NullMessage

VARIABLES 
    \* A mapping from sender to a set of received message counters (the conceptual history window)
    historyWindow,
    \* The current message being evaluated by the Message Layer
    pendingMsg,
    \* The set of messages that successfully reached the application layer
    applicationMessages

\* Defines the structure of an incoming message
ValidMessages == [sender: Senders, counter: MessageCounters]

Init == 
    /\ historyWindow = [s \in Senders |-> {}]
    /\ pendingMsg = NullMessage
    /\ applicationMessages = {}

\* SOURCE: core_4.6.5 "Whenever a message is received, its message counter is checked against the history window of message counters from that sender to determine whether it is a duplicate."
ReceiveMessage(m) ==
    /\ pendingMsg = NullMessage
    /\ m \in ValidMessages
    /\ pendingMsg' = m
    /\ UNCHANGED <<historyWindow, applicationMessages>>

\* SOURCE: core_4.6.5 "The Message Layer SHALL discard duplicate messages before they reach the application layer."
DiscardDuplicateMessage ==
    /\ pendingMsg \in ValidMessages
    /\ pendingMsg.counter \in historyWindow[pendingMsg.sender]
    /\ pendingMsg' = NullMessage
    /\ UNCHANGED <<historyWindow, applicationMessages>>

\* SOURCE: core_4.6.5 "To detect duplicate messages, Nodes maintain a history window of the message counters they have received from a particular sender ... The Message Layer SHALL discard duplicate messages before they reach the application layer."
\* (Messages that are not duplicates are added to the history window and reach the application layer)
AcceptNewMessage ==
    /\ pendingMsg \in ValidMessages
    /\ pendingMsg.counter \notin historyWindow[pendingMsg.sender]
    /\ historyWindow' = [historyWindow EXCEPT ![pendingMsg.sender] = historyWindow[pendingMsg.sender] \cup {pendingMsg.counter}]
    /\ applicationMessages' = applicationMessages \cup {pendingMsg}
    /\ pendingMsg' = NullMessage

Next ==
    \/ (\E m \in ValidMessages: ReceiveMessage(m))
    \/ DiscardDuplicateMessage
    \/ AcceptNewMessage

====