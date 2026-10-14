---- MODULE core_4_12_1 ----
EXTENDS Naturals

\* Sentinel values for message counters
CONSTANTS NullCounter, ValidCounter

\* pendingInput and the NoInput constant are REQUIRED
CONSTANTS NoInput

VARIABLES 
    pendingInput,
    \* Input variables simulating the sender's intent when constructing a message
    reqRequiresAck,
    reqIsStandaloneAck,
    reqAckMessageCounter,
    \* Resulting fields of the message being constructed
    outMsgRFlag,
    outMsgAFlag,
    outMsgAckCounter,
    \* Input variables simulating the header fields of an incoming message
    inMsgRFlag,
    inMsgAFlag,
    inMsgAckCounter,
    inMsgIsStandaloneAck

\* The events that this section processes:
\* - ConstructMessage: The upper layer requests to send a message.
\* - ReceiveMessage: A message arrives from the network.
Inputs == {"ConstructMessage", "ReceiveMessage"}

Operational == TRUE

Init ==
    /\ pendingInput = NoInput
    \* Explore all possible intent combinations for sending
    /\ reqRequiresAck \in BOOLEAN
    /\ reqIsStandaloneAck \in BOOLEAN
    /\ reqAckMessageCounter \in {NullCounter, ValidCounter}
    \* Initial state for constructed messages
    /\ outMsgRFlag = FALSE
    /\ outMsgAFlag = FALSE
    /\ outMsgAckCounter = NullCounter
    \* Explore all possible header field combinations for receiving
    /\ inMsgRFlag \in BOOLEAN
    /\ inMsgAFlag \in BOOLEAN
    /\ inMsgAckCounter \in {NullCounter, ValidCounter}
    /\ inMsgIsStandaloneAck \in BOOLEAN

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<reqRequiresAck, reqIsStandaloneAck, reqAckMessageCounter, 
                   outMsgRFlag, outMsgAFlag, outMsgAckCounter, 
                   inMsgRFlag, inMsgAFlag, inMsgAckCounter, inMsgIsStandaloneAck>>

\* SOURCE: core_4.12.1 R Flag, A Flag, Acknowledged Message Counter
ConstructMessage ==
    /\ pendingInput = "ConstructMessage"
    /\ IF reqIsStandaloneAck /\ reqAckMessageCounter = NullCounter THEN
           \* TODO: unspecified - requested to send standalone ack but no valid message counter provided
           UNCHANGED <<outMsgRFlag, outMsgAFlag, outMsgAckCounter>>
       ELSE
           \* R Flag rules: SHALL be set if ack required, MAY be clear otherwise
           /\ outMsgRFlag' \in IF reqRequiresAck THEN {TRUE} ELSE {TRUE, FALSE}
           
           \* A Flag rules: MAY be set generally, SHALL be set for Standalone Ack.
           \* But "When set, the Acknowledged Message Counter field SHALL be present and valid."
           /\ \E newAFlag \in
               (IF reqIsStandaloneAck THEN {TRUE}
                ELSE IF reqAckMessageCounter # NullCounter THEN {TRUE, FALSE}
                ELSE {FALSE}):
                /\ outMsgAFlag' = newAFlag
                \* Acknowledged Message Counter: SHALL be set to the counter being acknowledged
                /\ outMsgAckCounter' = IF newAFlag THEN reqAckMessageCounter ELSE NullCounter
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<reqRequiresAck, reqIsStandaloneAck, reqAckMessageCounter, 
                   inMsgRFlag, inMsgAFlag, inMsgAckCounter, inMsgIsStandaloneAck>>

\* SOURCE: core_4.12.1 A Flag, Acknowledged Message Counter
ReceiveMessage ==
    /\ pendingInput = "ReceiveMessage"
    /\ IF inMsgAFlag /\ inMsgAckCounter = NullCounter THEN
           \* TODO: unspecified - message received with A Flag set but Acknowledged Message Counter missing
           TRUE
       ELSE IF inMsgIsStandaloneAck /\ ~inMsgAFlag THEN
           \* TODO: unspecified - Standalone Ack received without A Flag set
           TRUE
       ELSE
           \* Header fields are valid according to 4.12.1 rules
           TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<outMsgRFlag, outMsgAFlag, outMsgAckCounter, 
                   reqRequiresAck, reqIsStandaloneAck, reqAckMessageCounter, 
                   inMsgRFlag, inMsgAFlag, inMsgAckCounter, inMsgIsStandaloneAck>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ConstructMessage
    \/ ReceiveMessage

====