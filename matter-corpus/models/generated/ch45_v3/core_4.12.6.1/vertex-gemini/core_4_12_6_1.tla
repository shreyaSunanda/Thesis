---- MODULE core_4_12_6_1 ----
EXTENDS Naturals

\* The configurable maximum number of times a reliable message is sent.
CONSTANTS MRP_MAX_TRANSMISSIONS

\* Finite sets used to bound the state space for model checking.
CONSTANTS MessageIDs, ExchangeContexts, MessageBuffers
CONSTANTS MaxMessageCounter

\* Sentinel constants for uninitialized input fields.
CONSTANTS NullMessageId, NullExchangeContext, NullMessageBuffer

\* REQUIRED - Sentinel indicating no event is waiting to be processed.
CONSTANTS NoInput

VARIABLES 
    pendingInput,
    retransmissionTable,
    applicationNotifications,
    \* Variables to hold data associated with the incoming event
    inputMessageId,
    inputExchangeContext,
    inputMessageCounter,
    inputMessageBuffer

\* REQUIRED - Every event the spec mentions arriving or that is implied by the domain.
Inputs == {
    "SendMessage", 
    "AckReceived", 
    "RetransmissionTimeout"
}

\* Helper to initialize a new retransmission context record.
\* SOURCE: core_4.12.6.1 Retransmission Table
NewRecord(id, ec, mc, mb) == 
    [id |-> id,
     exchangeContext |-> ec,
     messageCounter |-> mc,
     messageBuffer |-> mb,
     sendCount |-> 1,
     retransmissionTimeoutCounter |-> 0] \* TODO: unspecified - initial value of timeout counter is not explicitly detailed.

Init ==
    /\ pendingInput = NoInput
    /\ retransmissionTable = {}
    /\ applicationNotifications = {}
    /\ inputMessageId = NullMessageId
    /\ inputExchangeContext = NullExchangeContext
    /\ inputMessageCounter = 0
    /\ inputMessageBuffer = NullMessageBuffer

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    \* Populate event data with nondeterministic valid values for the step.
    /\ inputMessageId' \in MessageIDs
    /\ inputExchangeContext' \in ExchangeContexts
    /\ inputMessageCounter' \in 0..MaxMessageCounter
    /\ inputMessageBuffer' \in MessageBuffers
    /\ UNCHANGED <<retransmissionTable, applicationNotifications>>

\* SOURCE: core_4.12.6.1 Retransmission Table
HandleSendMessage ==
    /\ pendingInput = "SendMessage"
    /\ IF \E r \in retransmissionTable : r.id = inputMessageId
       THEN
           \* Update existing record
           \E r \in {rec \in retransmissionTable : rec.id = inputMessageId} :
               IF r.sendCount < MRP_MAX_TRANSMISSIONS
               THEN
                   /\ retransmissionTable' = (retransmissionTable \ {r}) \cup {[r EXCEPT !.sendCount = r.sendCount + 1]}
                   /\ UNCHANGED applicationNotifications
               ELSE
                   /\ applicationNotifications' = applicationNotifications \cup {inputMessageId}
                   /\ UNCHANGED retransmissionTable
                   \* TODO: unspecified - is the record removed after maximum transmissions failure?
       ELSE
           \* Insert new record
           /\ retransmissionTable' = retransmissionTable \cup {NewRecord(inputMessageId, inputExchangeContext, inputMessageCounter, inputMessageBuffer)}
           /\ UNCHANGED applicationNotifications
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inputMessageId, inputExchangeContext, inputMessageCounter, inputMessageBuffer>>

\* SOURCE: core_4.12.6.1 Retransmission Table
HandleAckReceived ==
    /\ pendingInput = "AckReceived"
    \* TODO: unspecified - behavior upon receiving acknowledgment is not explicitly detailed (presumably the record is removed).
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<retransmissionTable, applicationNotifications, inputMessageId, inputExchangeContext, inputMessageCounter, inputMessageBuffer>>

\* SOURCE: core_4.12.6.1 Retransmission Table
HandleRetransmissionTimeout ==
    /\ pendingInput = "RetransmissionTimeout"
    \* TODO: unspecified - how the Retransmission timeout counter is updated or triggers actions is not described in this specific section.
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<retransmissionTable, applicationNotifications, inputMessageId, inputExchangeContext, inputMessageCounter, inputMessageBuffer>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleSendMessage
    \/ HandleAckReceived
    \/ HandleRetransmissionTimeout

====