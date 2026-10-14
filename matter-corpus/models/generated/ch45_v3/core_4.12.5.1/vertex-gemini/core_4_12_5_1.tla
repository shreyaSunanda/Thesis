---- MODULE core_4_12_5_1 ----
EXTENDS Naturals

\* Maximum number of retransmission attempts before eviction.
CONSTANTS MaxRetries
\* Abstract sets for IDs and configurations.
CONSTANTS MessageIds, NodeIds, ExchangeIds, SessionIds, SessionCredentials, SessionTypes, SecurityFlags, MessageCounters, Transports

\* REQUIRED - pendingInput and NoInput.
CONSTANTS NoInput
VARIABLES pendingInput

\* Tables and state sets required by the specification processing logic.
VARIABLES ackTable
VARIABLES retransTable
VARIABLES pendingTransport
VARIABLES activeTimers
VARIABLES appNotifications

\* All events that can trigger state transitions described or implied by the text.
Inputs == {
    "PrepareMessage", 
    "TransportSendResult", 
    "RetransmissionTimeout", 
    "ReceiveAck", 
    "ReceiveMessageRequiringAck"
}

Init == 
    /\ pendingInput = NoInput
    /\ ackTable = {}
    /\ retransTable = {}
    /\ pendingTransport = {}
    /\ activeTimers = {}
    /\ appNotifications = {}

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<ackTable, retransTable, pendingTransport, activeTimers, appNotifications>>

\* SOURCE: core_4.12.5.1 Piggyback acknowledgment processing & Message retransmission processing
PrepareMessage ==
    /\ pendingInput = "PrepareMessage"
    /\ \E msgId \in MessageIds,
          destNodeId \in NodeIds,
          exchangeId \in ExchangeIds,
          sessionId \in SessionIds,
          sessionCreds \in SessionCredentials,
          sessionType \in SessionTypes,
          securityFlags \in SecurityFlags,
          msgCounter \in MessageCounters,
          isStandaloneAck \in BOOLEAN,
          isReliable \in BOOLEAN,
          transport \in Transports:
       LET msg == [
               msgId |-> msgId,
               destNodeId |-> destNodeId,
               exchangeId |-> exchangeId,
               sessionId |-> sessionId,
               sessionCredentials |-> sessionCreds,
               sessionType |-> sessionType,
               securityFlags |-> securityFlags,
               msgCounter |-> msgCounter,
               isStandaloneAck |-> isStandaloneAck,
               isReliable |-> isReliable,
               transport |-> transport,
               aFlag |-> FALSE,
               ackMsgCounter |-> 0,
               rFlag |-> FALSE
           ]
           
           \* Piggyback processing step 1
           matchingAcks == { ack \in ackTable :
               /\ ack.destNodeId = msg.destNodeId
               /\ ack.exchangeId = msg.exchangeId
               /\ ( (ack.sessionId = msg.sessionId /\ ack.sessionCredentials = msg.sessionCredentials)
                    \/ (ack.sessionType = "Unsecured" /\ msg.sessionType = "Unsecured") )
           }
           hasMatchingAck == matchingAcks # {}
           chosenAck == CHOOSE ack \in matchingAcks : TRUE
           
           \* Piggyback processing step 2
           msgWithA == IF hasMatchingAck THEN
                           [msg EXCEPT !.aFlag = TRUE, !.ackMsgCounter = chosenAck.msgCounter]
                       ELSE
                           msg
                           
           nextAckTable == IF hasMatchingAck THEN
                               IF msg.isStandaloneAck THEN
                                   (ackTable \ {chosenAck}) \cup {[chosenAck EXCEPT !.standaloneAckSent = TRUE]}
                               ELSE
                                   ackTable \ {chosenAck}
                           ELSE
                               ackTable
                               
           \* Message retransmission processing step 1
           isReliableUDP == (msg.isReliable /\ msg.transport = "UDP")
           msgWithR == IF isReliableUDP THEN
                           [msgWithA EXCEPT !.rFlag = TRUE]
                       ELSE
                           msgWithA
                           
           nextRetransTable == IF isReliableUDP THEN
                                   retransTable \cup {[
                                       msgId |-> msgWithR.msgId,
                                       destNodeId |-> msgWithR.destNodeId,
                                       exchangeId |-> msgWithR.exchangeId,
                                       sessionId |-> msgWithR.sessionId,
                                       sessionCredentials |-> msgWithR.sessionCredentials,
                                       securityFlags |-> msgWithR.securityFlags,
                                       transport |-> msgWithR.transport,
                                       sendCount |-> 0,
                                       retries |-> 0
                                   ]}
                               ELSE
                                   retransTable
           
           \* Message retransmission processing step 2 (prepare fields for transport)
           nextPendingTransportRec == [
               msgId |-> msgWithR.msgId,
               rFlag |-> msgWithR.rFlag,
               destNodeId |-> msgWithR.destNodeId,
               exchangeId |-> msgWithR.exchangeId,
               sessionId |-> msgWithR.sessionId,
               securityFlags |-> msgWithR.securityFlags,
               transport |-> msgWithR.transport
           ]
       IN
       /\ ackTable' = nextAckTable
       /\ retransTable' = nextRetransTable
       /\ pendingTransport' = pendingTransport \cup {nextPendingTransportRec}
       /\ pendingInput' = NoInput
       /\ UNCHANGED <<activeTimers, appNotifications>>

\* SOURCE: core_4.12.5.1 Message retransmission processing (Step 3)
TransportSendResult ==
    /\ pendingInput = "TransportSendResult"
    /\ \E txMsg \in pendingTransport, errorType \in {"Fatal", "NonFatal", "NoError"} :
        /\ pendingTransport' = pendingTransport \ {txMsg}
        /\ IF errorType = "Fatal" THEN
               /\ retransTable' = {rt \in retransTable : rt.msgId # txMsg.msgId}
               /\ appNotifications' = appNotifications \cup {[type |-> "FatalError", msgId |-> txMsg.msgId]}
               /\ UNCHANGED <<activeTimers>>
           ELSE
               IF txMsg.rFlag THEN
                   /\ IF \E rt \in retransTable : rt.msgId = txMsg.msgId THEN
                          /\ \E rt \in retransTable :
                                 /\ rt.msgId = txMsg.msgId
                                 /\ retransTable' = (retransTable \ {rt}) \cup {[rt EXCEPT !.sendCount = rt.sendCount + 1]}
                          /\ activeTimers' = activeTimers \cup {txMsg.msgId}
                      ELSE
                          UNCHANGED <<retransTable, activeTimers>>
                   /\ UNCHANGED <<appNotifications>>
               ELSE
                   UNCHANGED <<retransTable, activeTimers, appNotifications>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<ackTable>>

\* SOURCE: core_4.12.5.1 Message retransmission processing (Step 3.b.ii and 3.b.iii)
RetransmissionTimeout ==
    /\ pendingInput = "RetransmissionTimeout"
    /\ \E rt \in retransTable :
        /\ rt.msgId \in activeTimers
        /\ activeTimers' = activeTimers \ {rt.msgId}
        /\ IF rt.retries < MaxRetries THEN
               LET retryMsg == [
                   msgId |-> rt.msgId,
                   rFlag |-> TRUE,
                   destNodeId |-> rt.destNodeId,
                   exchangeId |-> rt.exchangeId,
                   sessionId |-> rt.sessionId,
                   securityFlags |-> rt.securityFlags,
                   transport |-> rt.transport
               ]
               IN
               /\ retransTable' = (retransTable \ {rt}) \cup {[rt EXCEPT !.retries = rt.retries + 1]}
               /\ pendingTransport' = pendingTransport \cup {retryMsg}
               /\ UNCHANGED <<appNotifications>>
           ELSE
               /\ retransTable' = retransTable \ {rt}
               /\ UNCHANGED <<pendingTransport, appNotifications>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<ackTable>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ PrepareMessage
    \/ TransportSendResult
    \/ RetransmissionTimeout

====