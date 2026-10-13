---- MODULE core_4_12_2_1 ----
EXTENDS Naturals

\* 
\* CONSTANTS
\* 

\* The set of all nodes in the system.
CONSTANTS Nodes

\* The set of unique exchange identifiers.
CONSTANTS ExchangeIDs

\* Sentinel value for a missing or null node.
CONSTANTS NullNode

\* Maximum number of total transmissions before failure (MRP_MAX_TRANSMISSIONS).
\* The limit on retries is MRP_MAX_TRANSMISSIONS - 1.
CONSTANTS MRP_MAX_TRANSMISSIONS

\* Base for the exponential backoff calculation.
CONSTANTS MRP_BACKOFF_BASE

\* Number of linear backoffs before switching to exponential backoff.
CONSTANTS MRP_BACKOFF_THRESHOLD

\* Numerator and Denominator to represent the MRP_BACKOFF_MARGIN (e.g., 11 and 10 for a 1.1x / 10% margin).
CONSTANTS MRP_BACKOFF_MARGIN_NUM, MRP_BACKOFF_MARGIN_DEN

\* The active interval of a session for a peer node.
CONSTANTS SESSION_ACTIVE_INTERVAL

\* The idle interval of a session for a peer node.
CONSTANTS SESSION_IDLE_INTERVAL

\* The fast polling interval used by an Intermittently Connected Device (ICD).
CONSTANTS FAST_POLLING_INTERVAL

\* 
\* VARIABLES
\* 

\* Set of messages currently in the network.
VARIABLES network

\* State mapping for each sender's view of an exchange. Function of [Nodes \times ExchangeIDs -> Record]
VARIABLES exchangeState

\* Set of notifications sent to the application about failed exchanges. Set of [node, exchangeId]
VARIABLES appNotifications

\* 
\* HELPERS & RECORD ABSTRACTIONS
\* 

NullExchange == [
    state                |-> "IDLE",
    peer                 |-> NullNode,
    retries              |-> 0,
    isFirstMsg           |-> FALSE,
    timerExpired         |-> FALSE,
    opDiscoveryTriggered |-> FALSE,
    senderIsICD          |-> FALSE,
    peerActiveMode       |-> FALSE,
    currentBackoff       |-> 0
]

CalculateBaseInterval(peerActiveMode, senderIsICD) ==
    LET base == IF peerActiveMode THEN SESSION_ACTIVE_INTERVAL ELSE SESSION_IDLE_INTERVAL
        marginBase == (base * MRP_BACKOFF_MARGIN_NUM) \div MRP_BACKOFF_MARGIN_DEN
        icdPadding == IF senderIsICD THEN FAST_POLLING_INTERVAL ELSE 0
    IN marginBase + icdPadding

\* TODO: unspecified - float math and random jitter (1.0 + random(0,1) * MRP_BACKOFF_JITTER) 
\* are omitted here as TLA+ does not natively support continuous randomness or floating point 
\* arithmetic. The abstraction is deterministic.
CalculateBackoffTime(n, i) ==
    LET exp == IF n > MRP_BACKOFF_THRESHOLD THEN (n - MRP_BACKOFF_THRESHOLD) ELSE 0
    IN i * (MRP_BACKOFF_BASE ^ exp)

NewExchangeRec(peer, isFirstMsg, isSenderICD, peerActive, backoff) ==
    [state                |-> "WAITING_ACK",
     peer                 |-> peer,
     retries              |-> 0,
     isFirstMsg           |-> isFirstMsg,
     timerExpired         |-> FALSE,
     opDiscoveryTriggered |-> FALSE,
     senderIsICD          |-> isSenderICD,
     peerActiveMode       |-> peerActive,
     currentBackoff       |-> backoff]

RetransmitRec(currentEx, newRetries, newBackoff) ==
    [currentEx EXCEPT
        !.retries = newRetries,
        !.timerExpired = FALSE,
        !.opDiscoveryTriggered = IF currentEx.retries = 0 THEN TRUE ELSE currentEx.opDiscoveryTriggered,
        !.currentBackoff = newBackoff]

FailRec(currentEx) == [currentEx EXCEPT !.state = "FAILED"]

DoneRec(currentEx) == [currentEx EXCEPT !.state = "DONE", !.timerExpired = FALSE]

MsgMsg(s, peer, e) == [type |-> "MSG", sender |-> s, receiver |-> peer, exchangeId |-> e]
AckMsg(peer, s, e) == [type |-> "ACK", sender |-> peer, receiver |-> s, exchangeId |-> e]
FailedAppNotification(s, e) == [node |-> s, exchangeId |-> e]

\* 
\* INIT & TRANSITIONS
\* 

Init ==
    /\ network = {}
    /\ exchangeState = [s \in Nodes, e \in ExchangeIDs |-> NullExchange]
    /\ appNotifications = {}

\* SOURCE: core_4.12.2.1
\* "At each sender, a retransmission timer is started each time a reliable message is transmitted."
\* "For the first message of a new exchange, the base interval, i, SHALL be set according to the idle state..."
SendReliableMessage(sender, exId, peer, isFirstMsg, isSenderICD, peerActive) ==
    LET baseInterval == CalculateBaseInterval(peerActive, isSenderICD)
        backoff == CalculateBackoffTime(0, baseInterval)
    IN
        /\ exchangeState[sender, exId].state = "IDLE"
        /\ exchangeState' = [exchangeState EXCEPT ![sender, exId] = NewExchangeRec(peer, isFirstMsg, isSenderICD, peerActive, backoff)]
        /\ network' = network \cup {MsgMsg(sender, peer, exId)}
        /\ UNCHANGED appNotifications

\* SOURCE: core_4.12.2.1
\* Models the progression of time causing the wait timer (mrpBackoffTime) to expire.
Timeout(sender, exId) ==
    /\ exchangeState[sender, exId].state = "WAITING_ACK"
    /\ exchangeState[sender, exId].timerExpired = FALSE
    /\ exchangeState' = [exchangeState EXCEPT ![sender, exId].timerExpired = TRUE]
    /\ UNCHANGED <<network, appNotifications>>

\* SOURCE: core_4.12.2.1
\* "If the retransmission timer expires, the message is retransmitted and the timer started again."
\* "initiate Operational Discovery in parallel with the first retry ... if the initial transmission fails"
Retransmit(sender, exId) ==
    LET currentEx == exchangeState[sender, exId]
        newRetries == currentEx.retries + 1
        baseInterval == CalculateBaseInterval(currentEx.peerActiveMode, currentEx.senderIsICD)
        newBackoff == CalculateBackoffTime(newRetries, baseInterval)
    IN
        /\ currentEx.state = "WAITING_ACK"
        /\ currentEx.timerExpired = TRUE
        /\ currentEx.retries < MRP_MAX_TRANSMISSIONS - 1
        /\ exchangeState' = [exchangeState EXCEPT ![sender, exId] = RetransmitRec(currentEx, newRetries, newBackoff)]
        /\ network' = network \cup {MsgMsg(sender, currentEx.peer, exId)}
        /\ UNCHANGED appNotifications

\* SOURCE: core_4.12.2.1
\* "The sender SHALL retry up to a configured maximum number of times (MRP_MAX_TRANSMISSIONS - 1) before giving up and notifying the application."
MaxRetriesFailure(sender, exId) ==
    LET currentEx == exchangeState[sender, exId] IN
        /\ currentEx.state = "WAITING_ACK"
        /\ currentEx.timerExpired = TRUE
        /\ currentEx.retries >= MRP_MAX_TRANSMISSIONS - 1
        /\ exchangeState' = [exchangeState EXCEPT ![sender, exId] = FailRec(currentEx)]
        /\ appNotifications' = appNotifications \cup {FailedAppNotification(sender, exId)}
        /\ UNCHANGED network

\* SOURCE: core_4.12.2.1
\* "If a positive acknowledgment is received before the retransmission timer expires, the retransmission timer is stopped."
ReceiveAck(sender, exId) ==
    LET currentEx == exchangeState[sender, exId] IN
        /\ currentEx.state = "WAITING_ACK"
        /\ \E m \in network :
            /\ m.type = "ACK"
            /\ m.receiver = sender
            /\ m.exchangeId = exId
        /\ exchangeState' = [exchangeState EXCEPT ![sender, exId] = DoneRec(currentEx)]
        /\ UNCHANGED <<network, appNotifications>>

\* SOURCE: core_4.12.2.1 (Contextual necessity)
\* Environment action: models a receiver receiving a message and dispatching an acknowledgment.
PeerSendsAck(peer, sender, exId) ==
    /\ \E m \in network :
        /\ m.type = "MSG"
        /\ m.receiver = peer
        /\ m.sender = sender
        /\ m.exchangeId = exId
    /\ network' = network \cup {AckMsg(peer, sender, exId)}
    /\ UNCHANGED <<exchangeState, appNotifications>>

Next ==
    \/ \E s \in Nodes : \E peer \in Nodes : \E e \in ExchangeIDs : \E isFirst \in {TRUE, FALSE} : \E isICD \in {TRUE, FALSE} : \E pActive \in {TRUE, FALSE} :
        SendReliableMessage(s, e, peer, isFirst, isICD, pActive)
    \/ \E s \in Nodes : \E e \in ExchangeIDs :
        Timeout(s, e)
    \/ \E s \in Nodes : \E e \in ExchangeIDs :
        Retransmit(s, e)
    \/ \E s \in Nodes : \E e \in ExchangeIDs :
        MaxRetriesFailure(s, e)
    \/ \E s \in Nodes : \E e \in ExchangeIDs :
        ReceiveAck(s, e)
    \/ \E peer \in Nodes : \E s \in Nodes : \E e \in ExchangeIDs :
        PeerSendsAck(peer, s, e)

====