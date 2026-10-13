---- MODULE core_4_12_6_1 ----
EXTENDS Naturals

\* Maximum number of times a message is sent before delivery failure
CONSTANTS MRP_MAX_TRANSMISSIONS

\* Abstract sets representing valid types for context record fields
CONSTANTS ExchangeContexts, MessageCounters, MessageBuffers

VARIABLES 
    retransmissionTable, 
    appNotifications

\* Helper to construct a new retransmission context record.
\* TODO: unspecified - Retransmission timeout counter initial value and update logic are not explicitly specified here.
NewContextRecord(ec, mc, mb) ==
    [exchangeContext |-> ec,
     messageCounter  |-> mc,
     messageBuffer   |-> mb,
     sendCount       |-> 1,
     timeoutCounter  |-> 0]

\* Helper to update an existing record by incrementing its send count.
UpdatedContextRecord(r) ==
    [r EXCEPT !.sendCount = r.sendCount + 1]

Init ==
    /\ retransmissionTable = {}
    /\ appNotifications = {}

\* SOURCE: core_4.12.6.1 Retransmission Table
\* "Each time a message that requires acknowledgment is sent, a new retransmission context record is inserted into the retransmission table..."
SendNewMessage ==
    \E ec \in ExchangeContexts, mc \in MessageCounters, mb \in MessageBuffers :
        /\ ~\E r \in retransmissionTable : r.exchangeContext = ec /\ r.messageCounter = mc
        /\ retransmissionTable' = retransmissionTable \cup {NewContextRecord(ec, mc, mb)}
        /\ UNCHANGED appNotifications

\* SOURCE: core_4.12.6.1 Retransmission Table
\* "...or an existing record is updated to increment its send count."
RetransmitMessage ==
    \E r \in retransmissionTable :
        /\ r.sendCount < MRP_MAX_TRANSMISSIONS
        /\ retransmissionTable' = (retransmissionTable \ {r}) \cup {UpdatedContextRecord(r)}
        /\ UNCHANGED appNotifications

\* SOURCE: core_4.12.6.1 Retransmission Table
\* "The message is sent a configurable maximum number of times (MRP_MAX_TRANSMISSIONS) and, if still undelivered, the application is notified of the failure."
NotifyDeliveryFailure ==
    \E r \in retransmissionTable :
        /\ r.sendCount = MRP_MAX_TRANSMISSIONS
        /\ appNotifications' = appNotifications \cup {<<r.exchangeContext, r.messageCounter>>}
        \* Removed from the table because it is no longer pending/retrying
        /\ retransmissionTable' = retransmissionTable \ {r}

\* SOURCE: core_4.12.6.1 Retransmission Table
\* "maintains a retransmission table of context records containing information on all reliable messages sent that have acknowledgments still pending"
\* (Implicit behavior: when an acknowledgment is received, the message is no longer pending and is removed).
ReceiveAcknowledgment ==
    \E r \in retransmissionTable :
        /\ retransmissionTable' = retransmissionTable \ {r}
        /\ UNCHANGED appNotifications

Next ==
    \/ SendNewMessage
    \/ RetransmitMessage
    \/ NotifyDeliveryFailure
    \/ ReceiveAcknowledgment

====