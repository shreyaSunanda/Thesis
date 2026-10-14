---- MODULE core_4_12_2_2 ----
EXTENDS Naturals

\* Declare EVERY fixed value the spec text mentions (timeouts, limits, thresholds,
\* fabric indices, etc.) here. Give each one a short comment saying what it is.

CONSTANTS
    \* Bounded set of possible peers
    Senders,
    \* Bounded set of message counters to prevent infinite state space
    MessageCounters,
    \* Sentinel values for when no message is being processed
    NullSender,
    NoMsgCounter

\* pendingInput and the NoInput constant are REQUIRED - see rule 4a.
CONSTANTS NoInput

VARIABLES
    state,
    pendingInput,
    \* Input variables for receiving a message
    inMsgCounter,
    inMsgSender,
    inMsgIsReliable,
    inMsgIsAuthenticated,
    \* Input variables for sending responses or acks
    outMsgDest,
    \* State tracking
    history,             \* Map of sender -> set of received message counters
    outstandingAcks,     \* Map of sender -> set of counters waiting to be acknowledged
    higherLayerMessages, \* Set of <<sender, counter>> tuples passed to application
    sentAcks             \* Set of <<destination, ackedCounter>> tuples sent out

\* REQUIRED - the complete list of events this section can receive. See rule 4a.
Inputs == {
    "ReceiveMessage",
    "SendResponse",
    "SendStandaloneAck",
    "AckTimerExpiry"     \* Implied by "deferring acknowledgments" referring to 4.12.5.2.2
}

Init ==
    /\ pendingInput = NoInput
    /\ state = "Running"
    /\ inMsgCounter = NoMsgCounter
    /\ inMsgSender = NullSender
    /\ inMsgIsReliable = FALSE
    /\ inMsgIsAuthenticated = FALSE
    /\ outMsgDest = NullSender
    /\ history = [s \in Senders |-> {}]
    /\ outstandingAcks = [s \in Senders |-> {}]
    /\ higherLayerMessages = {}
    /\ sentAcks = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e = "ReceiveMessage" THEN
           /\ \E c \in MessageCounters:
                  \E s \in Senders:
                      \E r \in {TRUE, FALSE}:
                          \E a \in {TRUE, FALSE}:
                              /\ inMsgCounter' = c
                              /\ inMsgSender' = s
                              /\ inMsgIsReliable' = r
                              /\ inMsgIsAuthenticated' = a
           /\ UNCHANGED <<outMsgDest>>
       ELSE
           IF e \in {"SendResponse", "SendStandaloneAck"} THEN
               /\ \E d \in Senders:
                      outMsgDest' = d
               /\ UNCHANGED <<inMsgCounter, inMsgSender, inMsgIsReliable, inMsgIsAuthenticated>>
           ELSE
               UNCHANGED <<inMsgCounter, inMsgSender, inMsgIsReliable, inMsgIsAuthenticated, outMsgDest>>
    /\ UNCHANGED <<state, history, outstandingAcks, higherLayerMessages, sentAcks>>

\* SOURCE: core_4.12.2.2 Duplicate Message Detection
HandleReceiveAuthenticatedReliable ==
    /\ pendingInput = "ReceiveMessage"
    /\ inMsgIsAuthenticated = TRUE
    /\ inMsgIsReliable = TRUE
    /\ LET isDuplicate == inMsgCounter \in history[inMsgSender]
       IN
           \* Detect and mark duplicates using the history window
           /\ history' = [history EXCEPT ![inMsgSender] = @ \cup {inMsgCounter}]
           \* Send an acknowledgment for each instance, including duplicates
           /\ outstandingAcks' = [outstandingAcks EXCEPT ![inMsgSender] = @ \cup {inMsgCounter}]
           \* Only propagate the first instance to the next higher layer; drop duplicates
           /\ IF ~isDuplicate THEN
                  higherLayerMessages' = higherLayerMessages \cup {<<inMsgSender, inMsgCounter>>}
              ELSE
                  UNCHANGED higherLayerMessages
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, sentAcks, inMsgCounter, inMsgSender, inMsgIsReliable, inMsgIsAuthenticated, outMsgDest>>

\* SOURCE: core_4.12.2.2 Duplicate Message Detection
HandleReceiveAuthenticatedUnreliable ==
    /\ pendingInput = "ReceiveMessage"
    /\ inMsgIsAuthenticated = TRUE
    /\ inMsgIsReliable = FALSE
    /\ LET isDuplicate == inMsgCounter \in history[inMsgSender]
       IN
           \* History is still maintained for duplicate detection of all authenticated messages
           /\ history' = [history EXCEPT ![inMsgSender] = @ \cup {inMsgCounter}]
           \* Only propagate the first instance; drop duplicates
           /\ IF ~isDuplicate THEN
                  higherLayerMessages' = higherLayerMessages \cup {<<inMsgSender, inMsgCounter>>}
              ELSE
                  UNCHANGED higherLayerMessages
    /\ pendingInput' = NoInput
    \* Unreliable messages are not acknowledged
    /\ UNCHANGED <<state, outstandingAcks, sentAcks, inMsgCounter, inMsgSender, inMsgIsReliable, inMsgIsAuthenticated, outMsgDest>>

\* SOURCE: core_4.12.2.2 Duplicate Message Detection
HandleReceiveUnauthenticated ==
    /\ pendingInput = "ReceiveMessage"
    /\ inMsgIsAuthenticated = FALSE
    \* TODO: unspecified - the section focuses strictly on authenticated messages. Behavior for unauthenticated duplicate checking/acking is left ambiguous here.
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, history, outstandingAcks, higherLayerMessages, sentAcks, inMsgCounter, inMsgSender, inMsgIsReliable, inMsgIsAuthenticated, outMsgDest>>

\* SOURCE: core_4.12.2.2 Piggybacking Acknowledgments on Responses
HandleSendResponse ==
    /\ pendingInput = "SendResponse"
    /\ IF outstandingAcks[outMsgDest] # {} THEN
           \E ackedCounter \in outstandingAcks[outMsgDest]:
               \* Piggybacking outstanding acknowledgments on messages sent back
               \* The message sets the Acknowledged Message Counter field to the Message Counter of the received message
               /\ sentAcks' = sentAcks \cup {<<outMsgDest, ackedCounter>>}
               /\ outstandingAcks' = [outstandingAcks EXCEPT ![outMsgDest] = @ \ {ackedCounter}]
       ELSE
           /\ sentAcks' = sentAcks
           /\ outstandingAcks' = outstandingAcks
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, history, higherLayerMessages, inMsgCounter, inMsgSender, inMsgIsReliable, inMsgIsAuthenticated, outMsgDest>>

\* SOURCE: core_4.12.2.2 Acknowledgements
HandleSendStandaloneAck ==
    /\ pendingInput = "SendStandaloneAck"
    /\ IF outstandingAcks[outMsgDest] # {} THEN
           \E ackedCounter \in outstandingAcks[outMsgDest]:
               \* A standalone acknowledgment is used to acknowledge a reliable message
               /\ sentAcks' = sentAcks \cup {<<outMsgDest, ackedCounter>>}
               /\ outstandingAcks' = [outstandingAcks EXCEPT ![outMsgDest] = @ \ {ackedCounter}]
       ELSE
           /\ sentAcks' = sentAcks
           /\ outstandingAcks' = outstandingAcks
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, history, higherLayerMessages, inMsgCounter, inMsgSender, inMsgIsReliable, inMsgIsAuthenticated, outMsgDest>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleReceiveAuthenticatedReliable
    \/ HandleReceiveAuthenticatedUnreliable
    \/ HandleReceiveUnauthenticated
    \/ HandleSendResponse
    \/ HandleSendStandaloneAck

====