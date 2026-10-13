---- MODULE core_4_12_5_1 ----
EXTENDS Naturals

\* CONSTANTS declared for unspecified fixed values in the spec text
CONSTANTS 
    MaxRetries,    \* The maximum number of retries before a message is evicted
    NullValue      \* Placeholder for uninitialized fields

VARIABLES 
    ackTable,        \* Set of pending acknowledgements
    retransTable,    \* Set of messages stored for retransmission
    outboundMsg,     \* The message currently being prepared
    msgState,        \* Current step in the outbound processing flow
    transportResult, \* Status of the transport send attempt
    appNotified      \* Boolean flag for fatal error application notification

\* Helper to determine if an acknowledgement matches the given message
Match(ack, msg) ==
    /\ ack.destNodeId = msg.destNodeId
    /\ ack.exchangeId = msg.exchangeId
    /\ \/ (ack.sessionId = msg.sessionId /\ ack.sessionCreds = msg.sessionCreds)
       \/ (ack.unsecured = TRUE /\ msg.unsecured = TRUE)

Init ==
    /\ ackTable = {}
    /\ retransTable = {}
    /\ msgState = "PiggybackProcessing"
    /\ transportResult = "None"
    /\ appNotified = FALSE
    /\ outboundMsg = [
           destNodeId |-> NullValue,
           exchangeId |-> NullValue,
           sessionId |-> NullValue,
           sessionCreds |-> NullValue,
           unsecured |-> FALSE,
           isStandaloneAck |-> FALSE,
           reliableUDP |-> FALSE,
           aFlag |-> FALSE,
           rFlag |-> FALSE,
           ackMsgCounter |-> NullValue
       ]

\* SOURCE: core_4.12.5.1 Piggyback acknowledgment processing
PiggybackAckProcessing ==
    /\ msgState = "PiggybackProcessing"
    /\ IF \E ack \in ackTable : Match(ack, outboundMsg)
       THEN
         LET ack == CHOOSE a \in ackTable : Match(a, outboundMsg) IN
         /\ outboundMsg' = [outboundMsg EXCEPT 
                !.aFlag = TRUE, 
                !.ackMsgCounter = ack.msgCounter]
         /\ IF ~outboundMsg.isStandaloneAck
            THEN ackTable' = ackTable \ {ack}
            ELSE ackTable' = (ackTable \ {ack}) \cup {[ack EXCEPT !.standaloneAckSent = TRUE]}
       ELSE
         /\ outboundMsg' = outboundMsg
         /\ ackTable' = ackTable
    /\ msgState' = "RetransmissionProcessing"
    /\ UNCHANGED <<retransTable, transportResult, appNotified>>

\* SOURCE: core_4.12.5.1 Message retransmission processing (Step 1)
MessageRetransmissionProcessing ==
    /\ msgState = "RetransmissionProcessing"
    /\ IF outboundMsg.reliableUDP
       THEN 
         /\ outboundMsg' = [outboundMsg EXCEPT !.rFlag = TRUE]
         /\ retransTable' = retransTable \cup {[
                msg |-> [outboundMsg EXCEPT !.rFlag = TRUE], 
                sendCount |-> 0, 
                timerStarted |-> FALSE
            ]}
       ELSE 
         /\ outboundMsg' = outboundMsg
         /\ retransTable' = retransTable
    /\ msgState' = "Transmitting"
    /\ UNCHANGED <<ackTable, transportResult, appNotified>>

\* SOURCE: core_4.12.5.1 Message retransmission processing (Step 2)
MessageTransmission ==
    /\ msgState = "Transmitting"
    /\ \E res \in {"Success", "FatalError", "NonFatalError"} :
        transportResult' = res
    /\ msgState' = "AssessingError"
    /\ UNCHANGED <<ackTable, retransTable, outboundMsg, appNotified>>

\* SOURCE: core_4.12.5.1 Message retransmission processing (Step 3)
ErrorAssessment ==
    /\ msgState = "AssessingError"
    /\ IF transportResult = "FatalError"
       THEN 
         /\ appNotified' = TRUE
         /\ retransTable' = { r \in retransTable : r.msg # outboundMsg }
       ELSE 
         /\ appNotified' = appNotified
         /\ IF outboundMsg.reliableUDP
            THEN 
              LET rSet == { x \in retransTable : x.msg = outboundMsg } IN
              IF rSet # {} THEN
                  LET r == CHOOSE x \in rSet : TRUE IN
                  LET newCount == r.sendCount + 1 IN
                  IF newCount >= MaxRetries
                  THEN retransTable' = retransTable \ {r}
                  ELSE retransTable' = (retransTable \ {r}) \cup {[r EXCEPT !.sendCount = newCount, !.timerStarted = TRUE]}
              ELSE retransTable' = retransTable
            ELSE 
              retransTable' = retransTable
    /\ msgState' = "Done"
    /\ transportResult' = "None"
    /\ UNCHANGED <<ackTable, outboundMsg>>

\* SOURCE: core_4.12.5.1 Message retransmission processing (Step 3.b.ii and 3.b.iii)
RetryTimeout ==
    /\ msgState = "Done"
    /\ \E r \in retransTable : 
        /\ r.timerStarted = TRUE
        /\ outboundMsg' = r.msg
        /\ retransTable' = (retransTable \ {r}) \cup {[r EXCEPT !.timerStarted = FALSE]}
        /\ msgState' = "Transmitting"
    /\ UNCHANGED <<ackTable, transportResult, appNotified>>

Next == 
    \/ PiggybackAckProcessing
    \/ MessageRetransmissionProcessing
    \/ MessageTransmission
    \/ ErrorAssessment
    \/ RetryTimeout

====