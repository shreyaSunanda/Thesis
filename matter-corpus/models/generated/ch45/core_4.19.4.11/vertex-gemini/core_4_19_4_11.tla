---- MODULE core_4_19_4_11 ----
EXTENDS Naturals

CONSTANTS 
    RoleClient,
    RoleServer,
    StateEstablished,
    StateTornDown

VARIABLES 
    role,
    sessionState,
    ackReceived,
    timeoutOccurred

Init ==
    /\ role \in {RoleClient, RoleServer}
    /\ sessionState = StateEstablished
    /\ ackReceived = FALSE
    /\ timeoutOccurred = FALSE

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
ClientSendData ==
    \* "clients send data to servers via confirmed writes"
    /\ role = RoleClient
    /\ sessionState = StateEstablished
    \* TODO: unspecified - exact state machine details of sending confirmed writes from Figure 27
    /\ UNCHANGED <<role, sessionState, ackReceived, timeoutOccurred>>

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
ServerSendData ==
    \* "servers send data to clients via indications."
    /\ role = RoleServer
    /\ sessionState = StateEstablished
    \* TODO: unspecified - exact state machine details of sending indications from Figure 27
    /\ UNCHANGED <<role, sessionState, ackReceived, timeoutOccurred>>

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
SendKeepAlive ==
    \* "liveliness enforcement through keep alive messages"
    /\ sessionState = StateEstablished
    \* TODO: unspecified - exact state machine details of sending keep alive messages from Figure 28
    /\ UNCHANGED <<role, sessionState, ackReceived, timeoutOccurred>>

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
ReceiveAck ==
    \* Helper action to model receiving an acknowledgement before timeout
    /\ sessionState = StateEstablished
    /\ ~timeoutOccurred
    /\ ackReceived' = TRUE
    /\ UNCHANGED <<role, sessionState, timeoutOccurred>>

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
Timeout ==
    \* Helper action to model the timeout occurring
    /\ sessionState = StateEstablished
    /\ timeoutOccurred' = TRUE
    /\ UNCHANGED <<role, sessionState, ackReceived>>

\* SOURCE: core_4.19.4.11 Protocol State Diagrams
AutomaticTeardown ==
    \* "automatic teardown if acknowledgements are received before the timeout."
    /\ sessionState = StateEstablished
    /\ ackReceived = TRUE
    /\ timeoutOccurred = FALSE
    /\ sessionState' = StateTornDown
    /\ UNCHANGED <<role, ackReceived, timeoutOccurred>>

Next == 
    \/ ClientSendData
    \/ ServerSendData
    \/ SendKeepAlive
    \/ ReceiveAck
    \/ Timeout
    \/ AutomaticTeardown

====