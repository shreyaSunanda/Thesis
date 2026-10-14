---- MODULE core_4_12_2_2 ----
EXTENDS Naturals, Sequences, FiniteSets

\* The finite set of possible sender nodes sending reliable messages.
CONSTANTS Senders
\* Sentinel value representing no sender.
CONSTANTS NoSender

\* Upper bound for message counters to keep state space finite.
CONSTANTS MaxMsgCounter
\* Sentinel value representing no message counter.
CONSTANTS NoMsgCounter

\* Upper bound on how many unacknowledged messages we can queue for a sender, keeping state finite.
CONSTANTS MaxPendingAcks

\* REQUIRED constant for input signaling.
CONSTANTS NoInput

VARIABLES
    pendingInput,          \* REQUIRED variable holding the event currently waiting, or NoInput
    inputMsgCounter,       \* Event data: the message counter of the incoming message
    inputSender,           \* Event data: the sender of the incoming message
    historyWindow,         \* History of received message counters per sender for duplicate detection
    pendingAcks,           \* Sequence of pending message counters to be acknowledged per sender
    propagatedMessages,    \* Set of message counters successfully propagated to the higher layer per sender
    sentAcks               \* Set of acknowledgement messages sent by this node

\* REQUIRED definition of all events this module processes.
Inputs == {
    "ReceiveReliableMessage", 
    "SendResponse", 
    "TriggerStandaloneAck"
}

\* COMPONENT IS ALWAYS OPERATIONAL IN THIS ABSTRACT MODEL
Operational == TRUE

Init ==
    /\ pendingInput = NoInput
    /\ inputMsgCounter = NoMsgCounter
    /\ inputSender = NoSender
    /\ historyWindow = [s \in Senders |-> {}]
    /\ pendingAcks = [s \in Senders |-> <<>>]
    /\ propagatedMessages = [s \in Senders |-> {}]
    /\ sentAcks = {}

\* Helper to build a record representing an acknowledgement message.
AckRecord(type, dest, counter) ==
    [type |-> type, dest |-> dest, ackedCounter |-> counter]

\* Event delivery mechanism.
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e = "ReceiveReliableMessage"
       THEN \E s \in Senders : \E c \in 0..MaxMsgCounter :
                /\ inputSender' = s
                /\ inputMsgCounter' = c
       ELSE IF e \in {"SendResponse", "TriggerStandaloneAck"}
            THEN \E s \in Senders :
                     /\ inputSender' = s
                     /\ inputMsgCounter' = NoMsgCounter
            ELSE /\ inputSender' = NoSender
                 /\ inputMsgCounter' = NoMsgCounter
    /\ UNCHANGED <<historyWindow, pendingAcks, propagatedMessages, sentAcks>>

\* SOURCE: core_4.12.2.2 Duplicate Message Detection
\* "The receiver SHALL detect and mark duplicate messages... send an acknowledgment message... 
\* including duplicates. The reliability layer SHALL only propagate the first instance... 
\* Any message marked as a duplicate SHALL be dropped..."
HandleReceiveReliableMessage ==
    /\ pendingInput = "ReceiveReliableMessage"
    /\ Len(pendingAcks[inputSender]) < MaxPendingAcks  \* Bound check to keep state space finite
    /\ LET isDup == inputMsgCounter \in historyWindow[inputSender]
       IN /\ pendingAcks' = [pendingAcks EXCEPT ![inputSender] = Append(@, inputMsgCounter)]
          /\ IF isDup
             THEN /\ historyWindow' = historyWindow
                  /\ propagatedMessages' = propagatedMessages
             ELSE /\ historyWindow' = [historyWindow EXCEPT ![inputSender] = @ \cup {inputMsgCounter}]
                  /\ propagatedMessages' = [propagatedMessages EXCEPT ![inputSender] = @ \cup {inputMsgCounter}]
    /\ pendingInput' = NoInput
    /\ inputSender' = NoSender
    /\ inputMsgCounter' = NoMsgCounter
    /\ UNCHANGED <<sentAcks>>

\* SOURCE: core_4.12.2.2 Piggybacking Acknowledgments on Responses
\* "Acknowledgements MAY be conveyed at the same time (i.e. piggybacked) as data in a response message...
\* piggybacking outstanding acknowledgments on messages that it needs to send back"
HandleSendResponse ==
    /\ pendingInput = "SendResponse"
    /\ IF pendingAcks[inputSender] # <<>>
       THEN LET ackedCounter == Head(pendingAcks[inputSender])
            IN /\ sentAcks' = sentAcks \cup {AckRecord("PiggybackedAck", inputSender, ackedCounter)}
               /\ pendingAcks' = [pendingAcks EXCEPT ![inputSender] = Tail(@)]
       ELSE /\ sentAcks' = sentAcks
            /\ pendingAcks' = pendingAcks
    /\ pendingInput' = NoInput
    /\ inputSender' = NoSender
    /\ inputMsgCounter' = NoMsgCounter
    /\ UNCHANGED <<historyWindow, propagatedMessages>>

\* SOURCE: core_4.12.2.2 Acknowledgements
\* "A receiver SHALL acknowledge a reliable message by either using a "piggybacked" acknowledgment... 
\* or a standalone acknowledgment, or both."
\* Abstraction: We model sending one acknowledgement per pending instance to keep state finite. 
\* The spec allows both, but doing so infinitely is not useful to check.
HandleTriggerStandaloneAck ==
    /\ pendingInput = "TriggerStandaloneAck"
    /\ IF pendingAcks[inputSender] # <<>>
       THEN LET ackedCounter == Head(pendingAcks[inputSender])
            IN /\ sentAcks' = sentAcks \cup {AckRecord("StandaloneAck", inputSender, ackedCounter)}
               /\ pendingAcks' = [pendingAcks EXCEPT ![inputSender] = Tail(@)]
       ELSE /\ sentAcks' = sentAcks
            /\ pendingAcks' = pendingAcks
    /\ pendingInput' = NoInput
    /\ inputSender' = NoSender
    /\ inputMsgCounter' = NoMsgCounter
    /\ UNCHANGED <<historyWindow, propagatedMessages>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleReceiveReliableMessage
    \/ HandleSendResponse
    \/ HandleTriggerStandaloneAck

====