---- MODULE core_4_12_1 ----
EXTENDS Naturals

CONSTANTS 
    MessageCounters, \* Set of valid message counters
    NullCounter      \* Sentinel indicating the counter field is absent

VARIABLES 
    sentMessages,    \* Set of messages generated/sent
    pendingAcks      \* Set of message counters that require an acknowledgment

Init == 
    /\ sentMessages = {}
    /\ pendingAcks = {}

\* Helper action to model the arrival or existence of messages that need to be acknowledged.
ReceiveMessageNeedingAck ==
    \E msgCounter \in MessageCounters :
        /\ pendingAcks' = pendingAcks \cup {msgCounter}
        /\ UNCHANGED sentMessages

\* SOURCE: core_4.12.1 Reliable Messaging Header Fields
SendMessage ==
    \E rFlag \in {TRUE, FALSE} :
    \E aFlag \in {TRUE, FALSE} :
    \E isStandaloneAck \in {TRUE, FALSE} :
    \E msgCounter \in MessageCounters :
    \E ackCounter \in MessageCounters \cup {NullCounter} :
        \* R Flag: Indicates reliable message. MAY be clear for unreliable.
        \* (Modeled by unconstrained choice of rFlag)
        
        \* A Flag: MAY be set on any message. 
        \* SHALL always be set for MRP Standalone Acknowledgement messages.
        /\ isStandaloneAck = TRUE => aFlag = TRUE
        
        \* Acknowledged Message Counter:
        \* When A Flag is set, SHALL be present and valid.
        \* SHALL be set to the Message Counter of the message that is being acknowledged.
        /\ IF aFlag = TRUE 
           THEN ackCounter \in pendingAcks
           ELSE ackCounter = NullCounter
           
        /\ sentMessages' = sentMessages \cup {[
               rFlag           |-> rFlag,
               aFlag           |-> aFlag,
               isStandaloneAck |-> isStandaloneAck,
               ackMsgCounter   |-> ackCounter,
               msgCounter      |-> msgCounter
           ]}
        
        \* Remove the acknowledged message from pending acks
        /\ pendingAcks' = IF aFlag = TRUE 
                          THEN pendingAcks \ {ackCounter} 
                          ELSE pendingAcks

Next == ReceiveMessageNeedingAck \/ SendMessage

====