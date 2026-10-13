---- MODULE core_4_12_5_1 ----
EXTENDS Naturals

\* The maximum number of retries before a message is evicted from the retransmission table.
CONSTANTS MaxRetries

\* REQUIRED: Sentinels for input handling
CONSTANTS NoInput, Inputs

VARIABLES state
VARIABLES pendingInput

\* TODO: unspecified - The specification references the acknowledgement table
\* being populated but does not describe the transition that adds elements to it
\* within this section. We assume it is populated by external message reception processes.
VARIABLES ackTable
VARIABLES retransTable
VARIABLES network
VARIABLES appNotifications

Init ==
    /\ state = "Active"
    /\ pendingInput = NoInput
    /\ ackTable = {}
    /\ retransTable = {}
    /\ network = {}
    /\ appNotifications = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<state, ackTable, retransTable, network, appNotifications>>

\* Helper to determine if an entry in the acknowledgement table matches the outgoing message
IsMatchingAck(msg, ack) ==
    /\ ack.destNodeId = msg.destNodeId
    /\ ack.exchangeId = msg.exchangeId
    /\ \/ /\ msg.sessionId = ack.sessionId
          /\ msg.sessionCredentials = ack.sessionCredentials
       \/ /\ msg.sessionType = "Unsecured"
          /\ ack.sessionType = "Unsecured"

MatchingAcks(msg) == {a \in ackTable : IsMatchingAck(msg, a)}

\* Helpers to construct updated records cleanly, avoiding multi-line literals in conjunctions
MatchedAckUpdate(ack) == [ack EXCEPT !.standaloneAckSent = TRUE]

PiggybackedMsg(msg, matchedAck) == [msg EXCEPT !.aFlag = TRUE,
                                             !.ackMsgCounter = matchedAck.msgCounter]

ReliableMsg(msg) == [msg EXCEPT !.rFlag = TRUE]

NewRetransEntry(msg, count) == [
    msgId |-> msg.msgId,
    msg |-> msg,
    sendCount |-> count,
    timerStarted |-> TRUE
]

\* SOURCE: core_4.12.5.1
PrepareOutgoingMessage ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "PrepareOutgoingMessage"
    /\ LET msg == pendingInput.msg
           matches == MatchingAcks(msg)
           outcome == pendingInput.transportResult
       IN
           \/ /\ matches # {}
              /\ \E matchedAck \in matches :
                  LET piggyMsg == PiggybackedMsg(msg, matchedAck)
                      relMsg == IF piggyMsg.isReliableUDP THEN ReliableMsg(piggyMsg) ELSE piggyMsg
                  IN
                      /\ ackTable' = IF msg.isStandaloneAck THEN
                                         (ackTable \ {matchedAck}) \cup {MatchedAckUpdate(matchedAck)}
                                     ELSE
                                         ackTable \ {matchedAck}
                      /\ IF relMsg.rFlag THEN
                             IF outcome = "Fatal" THEN
                                 /\ retransTable' = retransTable
                                 /\ appNotifications' = appNotifications \cup {relMsg.msgId}
                             ELSE
                                 /\ retransTable' = retransTable \cup {NewRetransEntry(relMsg, 1)}
                                 /\ appNotifications' = appNotifications
                         ELSE
                             /\ retransTable' = retransTable
                             /\ appNotifications' = appNotifications
                      /\ network' = IF outcome = "Success" THEN network \cup {relMsg} ELSE network
           \/ /\ matches = {}
              /\ LET relMsg == IF msg.isReliableUDP THEN ReliableMsg(msg) ELSE msg
                 IN
                     /\ ackTable' = ackTable
                     /\ IF relMsg.rFlag THEN
                            IF outcome = "Fatal" THEN
                                /\ retransTable' = retransTable
                                /\ appNotifications' = appNotifications \cup {relMsg.msgId}
                            ELSE
                                /\ retransTable' = retransTable \cup {NewRetransEntry(relMsg, 1)}
                                /\ appNotifications' = appNotifications
                        ELSE
                            /\ retransTable' = retransTable
                            /\ appNotifications' = appNotifications
                     /\ network' = IF outcome = "Success" THEN network \cup {relMsg} ELSE network
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.12.5.1
HandleRetransmitTimeout ==
    /\ pendingInput # NoInput
    /\ pendingInput.type = "RetransmitTimeout"
    /\ \E entry \in retransTable :
        /\ entry.msgId = pendingInput.msgId
        /\ LET outcome == pendingInput.transportResult IN
           IF outcome = "Fatal" THEN
               /\ retransTable' = retransTable \ {entry}
               /\ appNotifications' = appNotifications \cup {entry.msgId}
               /\ UNCHANGED network
           ELSE
               IF entry.sendCount < MaxRetries THEN
                   /\ retransTable' = (retransTable \ {entry}) \cup {NewRetransEntry(entry.msg, entry.sendCount + 1)}
                   /\ network' = IF outcome = "Success" THEN network \cup {entry.msg} ELSE network
                   /\ UNCHANGED appNotifications
               ELSE
                   \* Maximum retries attempted, message is evicted from the retransmission table
                   /\ retransTable' = retransTable \ {entry}
                   /\ UNCHANGED <<network, appNotifications>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<state, ackTable>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ PrepareOutgoingMessage
    \/ HandleRetransmitTimeout

====