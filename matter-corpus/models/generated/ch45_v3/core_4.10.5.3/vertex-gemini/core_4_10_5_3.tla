---- MODULE core_4_10_5_3 ----
EXTENDS Naturals

\* The set of all possible exchange identifiers.
CONSTANTS ExchangeIds

\* Maximum number of pending retransmissions for an exchange.
CONSTANTS MaxRetransmissions

\* Sentinel value indicating no pending event is waiting to be handled.
CONSTANTS NoInput

VARIABLES
    pendingInput,
    inputExchangeId,
    exchanges,
    acknowledgementTable,
    retransmissionCounts,
    sentMessages

Inputs == {"AppCloseExchange", "FatalConnectionError", "RetransmissionComplete"}

StandaloneAckMsg(exId) == [type |-> "StandaloneAck", exchangeId |-> exId]

Init ==
    /\ pendingInput = NoInput
    /\ inputExchangeId \in ExchangeIds
    /\ exchanges \in [ExchangeIds -> {"OPEN", "CLOSING", "CLOSED"}]
    /\ acknowledgementTable \in [ExchangeIds -> {"None", "PendingNoAckSent", "PendingAckSent"}]
    /\ retransmissionCounts \in [ExchangeIds -> 0..MaxRetransmissions]
    /\ sentMessages = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E ex \in ExchangeIds : inputExchangeId' = ex
    /\ UNCHANGED <<exchanges, acknowledgementTable, retransmissionCounts, sentMessages>>

\* SOURCE: core_4.10.5.3 Closing an Exchange
HandleAppCloseExchange ==
    /\ pendingInput = "AppCloseExchange"
    /\ exchanges[inputExchangeId] = "OPEN"
    /\ IF acknowledgementTable[inputExchangeId] = "PendingNoAckSent" THEN
           sentMessages' = sentMessages \cup {StandaloneAckMsg(inputExchangeId)}
       ELSE
           sentMessages' = sentMessages
    /\ acknowledgementTable' = [acknowledgementTable EXCEPT ![inputExchangeId] = "None"]
    /\ IF retransmissionCounts[inputExchangeId] = 0 THEN
           exchanges' = [exchanges EXCEPT ![inputExchangeId] = "CLOSED"]
       ELSE
           exchanges' = [exchanges EXCEPT ![inputExchangeId] = "CLOSING"]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputExchangeId, retransmissionCounts>>

\* SOURCE: core_4.10.5.3 Closing an Exchange
HandleFatalConnectionError ==
    /\ pendingInput = "FatalConnectionError"
    /\ exchanges[inputExchangeId] = "OPEN"
    /\ IF acknowledgementTable[inputExchangeId] = "PendingNoAckSent" THEN
           sentMessages' = sentMessages \cup {StandaloneAckMsg(inputExchangeId)}
       ELSE
           sentMessages' = sentMessages
    /\ acknowledgementTable' = [acknowledgementTable EXCEPT ![inputExchangeId] = "None"]
    /\ IF retransmissionCounts[inputExchangeId] = 0 THEN
           exchanges' = [exchanges EXCEPT ![inputExchangeId] = "CLOSED"]
       ELSE
           exchanges' = [exchanges EXCEPT ![inputExchangeId] = "CLOSING"]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputExchangeId, retransmissionCounts>>

\* SOURCE: core_4.10.5.3 Closing an Exchange
HandleRetransmissionComplete ==
    /\ pendingInput = "RetransmissionComplete"
    /\ retransmissionCounts[inputExchangeId] > 0
    /\ retransmissionCounts' = [retransmissionCounts EXCEPT ![inputExchangeId] = retransmissionCounts[inputExchangeId] - 1]
    /\ IF exchanges[inputExchangeId] = "CLOSING" /\ (retransmissionCounts[inputExchangeId] - 1) = 0 THEN
           exchanges' = [exchanges EXCEPT ![inputExchangeId] = "CLOSED"]
       ELSE
           exchanges' = exchanges
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputExchangeId, acknowledgementTable, sentMessages>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleAppCloseExchange
    \/ HandleFatalConnectionError
    \/ HandleRetransmissionComplete

====