---- MODULE core_4_12_5_2 ----
EXTENDS Naturals

\* Upper bound for message counters to keep state space finite
CONSTANTS MaxMsgCounter

\* Set of peers/nodes in the system
CONSTANTS Peers

\* Set of all possible Exchange IDs
CONSTANTS Exchanges

\* A sentinel value representing no peer or an uninitialized source
CONSTANTS NullPeer

VARIABLES 
    retransTable,    \* Set of [exchangeId, msgCounter] representing sent messages awaiting ack. Presence implies timer is running.
    ackTable,        \* Mapping from exchangeId -> [pending, msgCounter, standaloneAckSent, timer, source]
    exchangeState,   \* Mapping from exchangeId -> [ephemeral, closed]
    sentAcks,        \* Set of standalone acknowledgments sent
    delivered,       \* Set of messages delivered to the next processing step (4.7.2)
    dropped          \* Set of messages dropped during reliability processing

\* Represents the universe of possible incoming messages mapped to this component
MessageSpace ==
    [rFlag         : BOOLEAN,
     aFlag         : BOOLEAN,
     cFlag         : BOOLEAN,
     sessionType   : {"Unicast", "Group"},
     ackMsgCounter : 0..MaxMsgCounter,
     isDuplicate   : BOOLEAN,
     msgCounter    : 0..MaxMsgCounter,
     source        : Peers,
     exchangeId    : Exchanges]

Init ==
    /\ retransTable \in SUBSET [exchangeId : Exchanges, msgCounter : 0..MaxMsgCounter]
    /\ ackTable = [e \in Exchanges |-> [
           pending           |-> FALSE,
           msgCounter        |-> 0,
           standaloneAckSent |-> FALSE,
           timer             |-> "Stopped",
           source            |-> NullPeer
       ]]
    /\ exchangeState \in [Exchanges -> [ephemeral : BOOLEAN, closed : BOOLEAN]]
    /\ sentAcks = {}
    /\ delivered = {}
    /\ dropped = {}

\* Helpers for Step 1 Checks
IsIllegalFlags(msg) ==
    \/ (msg.rFlag /\ msg.sessionType = "Group" /\ ~msg.cFlag)
    \/ (msg.aFlag /\ msg.sessionType = "Group" /\ ~msg.cFlag)

\* Helpers for 4.12.5.2.1 Received acknowledgement processing
TargetRetransEntry(msg) == 
    [exchangeId |-> msg.exchangeId, msgCounter |-> msg.ackMsgCounter]

RetransTableUpdate(msg) ==
    IF msg.aFlag
    THEN retransTable \ {TargetRetransEntry(msg)}
    ELSE retransTable

\* Helpers for 4.12.5.2.2 Standalone acknowledgement processing
SentAcksForDuplicate(msg) ==
    sentAcks \cup {[dest          |-> msg.source, 
                    ackMsgCounter |-> msg.msgCounter, 
                    exchangeId    |-> msg.exchangeId]}

ExchangeStateForDuplicate(msg) ==
    [exchangeState EXCEPT ![msg.exchangeId].closed = 
        IF exchangeState[msg.exchangeId].ephemeral THEN TRUE ELSE @]

NeedsImmediateAck(msg) ==
    /\ ackTable[msg.exchangeId].pending
    /\ ~ackTable[msg.exchangeId].standaloneAckSent

SentAcksWithImmediate(msg) ==
    IF NeedsImmediateAck(msg)
    THEN sentAcks \cup {[dest          |-> ackTable[msg.exchangeId].source, 
                         ackMsgCounter |-> ackTable[msg.exchangeId].msgCounter, 
                         exchangeId    |-> msg.exchangeId]}
    ELSE sentAcks

NewAckEntry(msg) ==
    [pending           |-> TRUE,
     msgCounter        |-> msg.msgCounter,
     standaloneAckSent |-> FALSE,
     timer             |-> "Running",
     source            |-> msg.source]

\* SOURCE: core_4.12.5.2 Reliable Message Processing of Incoming Messages
ProcessMessage(msg) ==
    \/ /\ IsIllegalFlags(msg)
       /\ dropped' = dropped \cup {msg}
       /\ UNCHANGED <<retransTable, ackTable, exchangeState, sentAcks, delivered>>
    \/ /\ ~IsIllegalFlags(msg)
       /\ msg.rFlag
       /\ msg.isDuplicate
       /\ sentAcks' = SentAcksForDuplicate(msg)
       /\ exchangeState' = ExchangeStateForDuplicate(msg)
       /\ dropped' = dropped \cup {msg}
       /\ retransTable' = RetransTableUpdate(msg)
       /\ UNCHANGED <<ackTable, delivered>>
    \/ /\ ~IsIllegalFlags(msg)
       /\ msg.rFlag
       /\ ~msg.isDuplicate
       /\ sentAcks' = SentAcksWithImmediate(msg)
       /\ ackTable' = [ackTable EXCEPT ![msg.exchangeId] = NewAckEntry(msg)]
       /\ retransTable' = RetransTableUpdate(msg)
       /\ delivered' = delivered \cup {msg}
       /\ UNCHANGED <<exchangeState, dropped>>
    \/ /\ ~IsIllegalFlags(msg)
       /\ ~msg.rFlag
       /\ retransTable' = RetransTableUpdate(msg)
       /\ delivered' = delivered \cup {msg}
       /\ UNCHANGED <<ackTable, exchangeState, sentAcks, dropped>>

\* Helpers for timer trigger action
SentAcksForTimer(ex) ==
    sentAcks \cup {[dest          |-> ackTable[ex].source,
                    ackMsgCounter |-> ackTable[ex].msgCounter,
                    exchangeId    |-> ex]}

AckTableForTimer(ex) ==
    [ackTable EXCEPT ![ex].timer = "Stopped",
                     ![ex].standaloneAckSent = TRUE]

\* SOURCE: core_4.12.5.2 Standalone acknowledgement processing, 1.b.ii.A
TriggerAckTimer(ex) ==
    /\ ackTable[ex].pending
    /\ ackTable[ex].timer = "Running"
    /\ sentAcks' = SentAcksForTimer(ex)
    /\ ackTable' = AckTableForTimer(ex)
    /\ UNCHANGED <<retransTable, exchangeState, delivered, dropped>>

Next ==
    \/ \E msg \in MessageSpace : ProcessMessage(msg)
    \/ \E ex \in Exchanges : TriggerAckTimer(ex)

====