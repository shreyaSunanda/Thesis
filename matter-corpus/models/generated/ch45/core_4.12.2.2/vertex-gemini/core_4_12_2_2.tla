---- MODULE core_4_12_2_2 ----
EXTENDS Naturals, Sequences

\* The set of possible message counters
CONSTANTS MessageCounters

VARIABLES 
    historyWindow,
    pendingAcks,
    higherLayer,
    sentAcks

Init ==
    /\ historyWindow = {}
    /\ pendingAcks = <<>>
    /\ higherLayer = <<>>
    /\ sentAcks = {}

\* SOURCE: core_4.12.2.2 Acknowledgements
\* "Since the reliable messaging protocol has a provision for the sender to retransmit messages, there is a significant chance that a duplicate message may arrive at the receiver. The receiver SHALL detect and mark duplicate messages that it receives using the standard authentication and replay protection mechanisms of the secure message layer... The receiver SHALL send an acknowledgment message to the sender for each instance of an authenticated, reliable message, including duplicates. The reliability layer SHALL only propagate the first instance of a message to the next higher layer. Any message marked as a duplicate SHALL be dropped by the reliability layer."
ReceiveAuthenticatedReliableMessage(c) ==
    /\ c \in MessageCounters
    /\ LET isDuplicate == c \in historyWindow IN
       /\ historyWindow' = historyWindow \cup {c}
       /\ pendingAcks' = Append(pendingAcks, c)
       /\ higherLayer' = IF isDuplicate THEN higherLayer ELSE Append(higherLayer, c)
    /\ UNCHANGED sentAcks

\* SOURCE: core_4.12.2.2 Acknowledgements
\* "A receiver SHALL acknowledge a reliable message by either using a "piggybacked" acknowledgment in the next message destined to the peer, or a standalone acknowledgment, or both."
\* "The acknowledgement message SHALL set the Acknowledged Message Counter field to the value of the Message Counter of the reliable message to be acknowledged."
SendStandaloneAck ==
    /\ pendingAcks # <<>>
    /\ LET c == Head(pendingAcks) IN
       /\ sentAcks' = sentAcks \cup {[type |-> "standalone", ackMessageCounter |-> c]}
       /\ pendingAcks' = Tail(pendingAcks)
    /\ UNCHANGED <<historyWindow, higherLayer>>

\* SOURCE: core_4.12.2.2 Acknowledgements
\* "A receiver SHALL acknowledge a reliable message by either using a "piggybacked" acknowledgment in the next message destined to the peer, or a standalone acknowledgment, or both."
\* "The acknowledgement message SHALL set the Acknowledged Message Counter field to the value of the Message Counter of the reliable message to be acknowledged."
\* "Acknowledgements MAY be conveyed at the same time (i.e. piggybacked) as data in a response message."
SendPiggybackedAck ==
    /\ pendingAcks # <<>>
    /\ LET c == Head(pendingAcks) IN
       /\ sentAcks' = sentAcks \cup {[type |-> "piggybacked", ackMessageCounter |-> c]}
       /\ pendingAcks' = Tail(pendingAcks)
    /\ UNCHANGED <<historyWindow, higherLayer>>

\* SOURCE: core_4.12.2.2 Acknowledgements
\* "A receiver SHALL acknowledge a reliable message by either using a "piggybacked" acknowledgment in the next message destined to the peer, or a standalone acknowledgment, or both."
\* "The acknowledgement message SHALL set the Acknowledged Message Counter field to the value of the Message Counter of the reliable message to be acknowledged."
SendBothAcks ==
    /\ pendingAcks # <<>>
    /\ LET c == Head(pendingAcks) IN
       /\ sentAcks' = sentAcks \cup {
             [type |-> "standalone", ackMessageCounter |-> c],
             [type |-> "piggybacked", ackMessageCounter |-> c]
          }
       /\ pendingAcks' = Tail(pendingAcks)
    /\ UNCHANGED <<historyWindow, higherLayer>>

Next == 
    \/ (\E c \in MessageCounters : ReceiveAuthenticatedReliableMessage(c))
    \/ SendStandaloneAck
    \/ SendPiggybackedAck
    \/ SendBothAcks

====