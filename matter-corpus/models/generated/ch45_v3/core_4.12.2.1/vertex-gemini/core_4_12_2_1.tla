---- MODULE core_4_12_2_1 ----
EXTENDS Naturals

\* The set of possible exchange identifiers and peer node identifiers
CONSTANTS ExchangeIds
CONSTANTS PeerIds

\* Sentinels for empty/unassigned values
CONSTANTS NullExchange
CONSTANTS NullPeer

\* Maximum bound for abstract intervals to ensure finite state space
CONSTANTS MaxInterval

\* Configuration bounds per spec profile (abstracted for finite model)
\* MRP_MAX_TRANSMISSIONS: max total transmissions (initial + retries). Real value usually > 1.
CONSTANTS MRP_MAX_TRANSMISSIONS

\* Spec parameters for backoff calculation
CONSTANTS MRP_BACKOFF_MARGIN
CONSTANTS MRP_BACKOFF_BASE
CONSTANTS MRP_BACKOFF_THRESHOLD

\* Mandatory shape constants and variables
CONSTANTS NoInput
VARIABLES pendingInput

\* State variables
VARIABLES inputData
VARIABLES exchanges
VARIABLES sessionContexts
VARIABLES failedExchanges
VARIABLES activeOpDiscoveries

Inputs == {
    "SendReliableMessage",
    "ReceiveAck",
    "RetransmissionTimeout",
    "OperationalDiscoveryComplete"
}

\* Defines the structure of data that can arrive with an event
ValidInputData ==
    [
        exchangeId : ExchangeIds \cup {NullExchange},
        peerId     : PeerIds \cup {NullPeer},
        isFirstMsg : BOOLEAN,
        activeMode : BOOLEAN,
        activeInt  : 0..MaxInterval,
        idleInt    : 0..MaxInterval,
        isICD      : BOOLEAN,
        fastPoll   : 0..MaxInterval
    ]

DefaultInputData ==
    [
        exchangeId |-> NullExchange,
        peerId     |-> NullPeer,
        isFirstMsg |-> FALSE,
        activeMode |-> FALSE,
        activeInt  |-> 0,
        idleInt    |-> 0,
        isICD      |-> FALSE,
        fastPoll   |-> 0
    ]

Init ==
    /\ pendingInput = NoInput
    /\ inputData = DefaultInputData
    /\ exchanges = [x \in ExchangeIds |-> [
           state          |-> "CLOSED", 
           peerId         |-> NullPeer, 
           n              |-> 0, 
           isFirstMessage |-> FALSE
       ]]
    /\ sessionContexts = [p \in PeerIds |-> [
           PeerActiveMode          |-> FALSE,
           SESSION_ACTIVE_INTERVAL |-> 0,
           SESSION_IDLE_INTERVAL   |-> 0,
           isICD                   |-> FALSE,
           fastPollingInterval     |-> 0
       ]]
    /\ failedExchanges = {}
    /\ activeOpDiscoveries = {}

\* Helper: Computes the base interval 'i' for backoff calculation
\* SOURCE: core_4.12.2.1 Retransmissions
\* TODO: unspecified - spec is slightly ambiguous if 'set according to idle state' means forcing PeerActiveMode=FALSE
\* or directly using SESSION_IDLE_INTERVAL regardless of PeerActiveMode. Assuming the latter for first message.
GetBaseInterval(isFirstMessage, peerSession) ==
    LET rawInterval == IF isFirstMessage
                       THEN peerSession.SESSION_IDLE_INTERVAL
                       ELSE (IF peerSession.PeerActiveMode
                             THEN peerSession.SESSION_ACTIVE_INTERVAL
                             ELSE peerSession.SESSION_IDLE_INTERVAL)
    IN rawInterval * MRP_BACKOFF_MARGIN

\* Helper: Abstract computation of mrpBackoffTime
\* SOURCE: core_4.12.2.1 Retransmissions
\* TODO: unspecified - exact floating point, exponentiation and randomness for jitter cannot be modeled exactly
\* in TLA+ Naturals. Abstracting as a linear combination of base, n, and polling interval.
CalculateMrpBackoffTime(n, i, isICD, fastPollingInterval) ==
    LET baseBackoff == i + (n * MRP_BACKOFF_BASE)
    IN IF isICD THEN baseBackoff + fastPollingInterval ELSE baseBackoff

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E data \in ValidInputData:
           inputData' = data
    /\ UNCHANGED <<exchanges, sessionContexts, failedExchanges, activeOpDiscoveries>>

NewExchangeState(peer, isFirst) ==
    [
        state          |-> "WAIT_ACK",
        peerId         |-> peer,
        n              |-> 0,
        isFirstMessage |-> isFirst
    ]

\* SOURCE: core_4.12.2.1 Retransmissions
HandleSendReliableMessage ==
    /\ pendingInput = "SendReliableMessage"
    /\ inputData.exchangeId \in ExchangeIds
    /\ inputData.peerId \in PeerIds
    /\ exchanges[inputData.exchangeId].state = "CLOSED"
    /\ exchanges' = [exchanges EXCEPT ![inputData.exchangeId] = NewExchangeState(inputData.peerId, inputData.isFirstMsg)]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputData, sessionContexts, failedExchanges, activeOpDiscoveries>>

\* SOURCE: core_4.12.2.1 Retransmissions
HandleReceiveAck ==
    /\ pendingInput = "ReceiveAck"
    /\ inputData.exchangeId \in ExchangeIds
    /\ exchanges[inputData.exchangeId].state = "WAIT_ACK"
    /\ exchanges' = [exchanges EXCEPT ![inputData.exchangeId].state = "CLOSED"]
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputData, sessionContexts, failedExchanges, activeOpDiscoveries>>

\* SOURCE: core_4.12.2.1 Retransmissions
HandleRetransmissionTimeout ==
    /\ pendingInput = "RetransmissionTimeout"
    /\ inputData.exchangeId \in ExchangeIds
    /\ exchanges[inputData.exchangeId].state = "WAIT_ACK"
    /\ LET ex == exchanges[inputData.exchangeId]
           session == sessionContexts[ex.peerId]
       IN IF ex.n < MRP_MAX_TRANSMISSIONS - 1
          THEN
              /\ exchanges' = [exchanges EXCEPT ![inputData.exchangeId].n = ex.n + 1]
              \* Initiate Operational Discovery in parallel with the first retry (n = 0 implies transitioning to retry 1)
              /\ activeOpDiscoveries' = IF ex.n = 0 THEN activeOpDiscoveries \cup {ex.peerId} ELSE activeOpDiscoveries
              /\ UNCHANGED <<failedExchanges>>
          ELSE
              \* Max retries reached, give up and notify application
              /\ exchanges' = [exchanges EXCEPT ![inputData.exchangeId].state = "CLOSED"]
              /\ failedExchanges' = failedExchanges \cup {inputData.exchangeId}
              /\ UNCHANGED <<activeOpDiscoveries>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputData, sessionContexts>>

UpdatedSessionContext(data) ==
    [
        PeerActiveMode          |-> data.activeMode,
        SESSION_ACTIVE_INTERVAL |-> data.activeInt,
        SESSION_IDLE_INTERVAL   |-> data.idleInt,
        isICD                   |-> data.isICD,
        fastPollingInterval     |-> data.fastPoll
    ]

\* SOURCE: core_4.12.2.1 Retransmissions
HandleOperationalDiscoveryComplete ==
    /\ pendingInput = "OperationalDiscoveryComplete"
    /\ inputData.peerId \in PeerIds
    /\ sessionContexts' = [sessionContexts EXCEPT ![inputData.peerId] = UpdatedSessionContext(inputData)]
    /\ activeOpDiscoveries' = activeOpDiscoveries \ {inputData.peerId}
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputData, exchanges, failedExchanges>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleSendReliableMessage
    \/ HandleReceiveAck
    \/ HandleRetransmissionTimeout
    \/ HandleOperationalDiscoveryComplete

====