---- MODULE core_4_19_4_3 ----
EXTENDS Naturals

\* Timeout value for session establishment (globally-defined).
CONSTANTS BTP_CONN_RSP_TIMEOUT

\* Set of protocol versions supported by the client.
CONSTANTS ClientSupportedVersions

\* Set of protocol versions supported by the server.
CONSTANTS ServerSupportedVersions

\* Sentinel value for when no shared version exists or session is not yet established.
CONSTANTS NullVersion

\* Maximum receive window size supported by the client.
CONSTANTS ClientWindowSize

\* Maximum receive window size supported by the server.
CONSTANTS ServerWindowSize

\* Client's GATT ATT_MTU.
CONSTANTS ClientATT_MTU

\* Flag indicating if the client can determine the BLE connection's ATT_MTU.
CONSTANTS ClientATT_MTU_Known

\* Server's GATT ATT_MTU.
CONSTANTS ServerATT_MTU

\* Sentinel: nothing is waiting to be handled
CONSTANTS NoInput

VARIABLES pendingInput
VARIABLES clientState
VARIABLES serverState
VARIABLES clientTimerRunning
VARIABLES serverTimerRunning
VARIABLES clientReqVersions
VARIABLES clientReqMTU
VARIABLES clientReqWindow
VARIABLES serverRspVersion
VARIABLES serverRspMTU
VARIABLES serverRspWindow
VARIABLES sessionVersion
VARIABLES sessionMTU
VARIABLES sessionWindow

Inputs == {
    "BLE_Connect",
    "DPLE_Update",
    "GATT_Exchange_MTU",
    "GATT_Discover_Primary_Service",
    "GATT_Discover_Characteristics",
    "GATT_Discover_Descriptors",
    "Send_Handshake_Request",
    "Receive_Handshake_Request",
    "Receive_GATT_Write_Response",
    "Send_Subscribe_C2",
    "Receive_Subscribe_C2",
    "Send_Handshake_Response",
    "Receive_Handshake_Response",
    "Client_Timer_Expiry",
    "Server_Timer_Expiry"
}

Min(a, b) == IF a < b THEN a ELSE b
Min3(a, b, c) == Min(a, Min(b, c))

SharedVersions == clientReqVersions \cap ServerSupportedVersions
HasSharedVersion == SharedVersions # {}
MaxSharedVersion ==
    IF HasSharedVersion THEN
        CHOOSE v \in SharedVersions : \A w \in SharedVersions : v >= w
    ELSE
        NullVersion

Init ==
    /\ pendingInput = NoInput
    /\ clientState = "Init"
    /\ serverState = "Init"
    /\ clientTimerRunning = FALSE
    /\ serverTimerRunning = FALSE
    /\ clientReqVersions = {}
    /\ clientReqMTU = 0
    /\ clientReqWindow = 0
    /\ serverRspVersion = NullVersion
    /\ serverRspMTU = 0
    /\ serverRspWindow = 0
    /\ sessionVersion = NullVersion
    /\ sessionMTU = 0
    /\ sessionWindow = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<clientState, serverState, clientTimerRunning, serverTimerRunning, 
                   clientReqVersions, clientReqMTU, clientReqWindow, 
                   serverRspVersion, serverRspMTU, serverRspWindow, 
                   sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
BLE_Connect ==
    /\ pendingInput = "BLE_Connect"
    /\ clientState = "Init"
    /\ serverState = "Init"
    /\ clientState' = "BLE_Connected"
    /\ serverState' = "BLE_Connected"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientTimerRunning, serverTimerRunning, clientReqVersions, clientReqMTU, 
                   clientReqWindow, serverRspVersion, serverRspMTU, serverRspWindow, 
                   sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
DPLE_Update ==
    /\ pendingInput = "DPLE_Update"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientState, serverState, clientTimerRunning, serverTimerRunning, 
                   clientReqVersions, clientReqMTU, clientReqWindow, 
                   serverRspVersion, serverRspMTU, serverRspWindow, 
                   sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
GATT_Exchange_MTU ==
    /\ pendingInput = "GATT_Exchange_MTU"
    /\ clientState = "BLE_Connected"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientState, serverState, clientTimerRunning, serverTimerRunning, 
                   clientReqVersions, clientReqMTU, clientReqWindow, 
                   serverRspVersion, serverRspMTU, serverRspWindow, 
                   sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
GATT_Discover_Primary_Service ==
    /\ pendingInput = "GATT_Discover_Primary_Service"
    /\ clientState = "BLE_Connected"
    /\ clientState' = "Service_Discovered"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, clientTimerRunning, serverTimerRunning, clientReqVersions, 
                   clientReqMTU, clientReqWindow, serverRspVersion, serverRspMTU, 
                   serverRspWindow, sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
GATT_Discover_Characteristics ==
    /\ pendingInput = "GATT_Discover_Characteristics"
    /\ clientState = "Service_Discovered"
    /\ clientState' = "Chars_Discovered"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, clientTimerRunning, serverTimerRunning, clientReqVersions, 
                   clientReqMTU, clientReqWindow, serverRspVersion, serverRspMTU, 
                   serverRspWindow, sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
GATT_Discover_Descriptors ==
    /\ pendingInput = "GATT_Discover_Descriptors"
    /\ clientState = "Chars_Discovered"
    /\ clientState' = "Descriptors_Discovered"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, clientTimerRunning, serverTimerRunning, clientReqVersions, 
                   clientReqMTU, clientReqWindow, serverRspVersion, serverRspMTU, 
                   serverRspWindow, sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
Send_Handshake_Request ==
    /\ pendingInput = "Send_Handshake_Request"
    /\ clientState = "Descriptors_Discovered"
    /\ clientState' = "Handshake_Sent"
    /\ clientReqVersions' = ClientSupportedVersions
    /\ clientReqMTU' = IF ClientATT_MTU_Known THEN ClientATT_MTU ELSE 23
    /\ clientReqWindow' = ClientWindowSize
    /\ clientTimerRunning' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, serverTimerRunning, serverRspVersion, serverRspMTU, 
                   serverRspWindow, sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
Receive_Handshake_Request ==
    /\ pendingInput = "Receive_Handshake_Request"
    /\ IF HasSharedVersion
       THEN /\ serverState' = "Handshake_Req_Received"
            /\ serverTimerRunning' = TRUE
       ELSE /\ serverState' = "Closed"
            /\ serverTimerRunning' = serverTimerRunning
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientState, clientTimerRunning, clientReqVersions, clientReqMTU, 
                   clientReqWindow, serverRspVersion, serverRspMTU, serverRspWindow, 
                   sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
Receive_GATT_Write_Response ==
    /\ pendingInput = "Receive_GATT_Write_Response"
    /\ clientState = "Handshake_Sent"
    /\ clientState' = "Handshake_Acked"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, clientTimerRunning, serverTimerRunning, clientReqVersions, 
                   clientReqMTU, clientReqWindow, serverRspVersion, serverRspMTU, 
                   serverRspWindow, sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
Send_Subscribe_C2 ==
    /\ pendingInput = "Send_Subscribe_C2"
    /\ clientState = "Handshake_Acked"
    /\ clientState' = "Subscribing_C2"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, clientTimerRunning, serverTimerRunning, clientReqVersions, 
                   clientReqMTU, clientReqWindow, serverRspVersion, serverRspMTU, 
                   serverRspWindow, sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
Receive_Subscribe_C2 ==
    /\ pendingInput = "Receive_Subscribe_C2"
    /\ serverState = "Handshake_Req_Received"
    /\ serverTimerRunning' = FALSE
    /\ serverState' = "C2_Subscribed"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientState, clientTimerRunning, clientReqVersions, clientReqMTU, 
                   clientReqWindow, serverRspVersion, serverRspMTU, serverRspWindow, 
                   sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
Send_Handshake_Response ==
    /\ pendingInput = "Send_Handshake_Response"
    /\ serverState = "C2_Subscribed"
    /\ serverRspWindow' = Min(ServerWindowSize, clientReqWindow)
    /\ serverRspMTU' = Min3(244, ServerATT_MTU - 3, clientReqMTU - 3)
    /\ serverRspVersion' = MaxSharedVersion
    /\ serverState' = "Session_Established"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientState, clientTimerRunning, serverTimerRunning, clientReqVersions, 
                   clientReqMTU, clientReqWindow, sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
Receive_Handshake_Response ==
    /\ pendingInput = "Receive_Handshake_Response"
    /\ clientState = "Subscribing_C2"
    /\ clientTimerRunning' = FALSE
    /\ sessionVersion' = serverRspVersion
    /\ sessionMTU' = serverRspMTU
    /\ sessionWindow' = serverRspWindow
    /\ clientState' = "Session_Established"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, serverTimerRunning, clientReqVersions, clientReqMTU, 
                   clientReqWindow, serverRspVersion, serverRspMTU, serverRspWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
Client_Timer_Expiry ==
    /\ pendingInput = "Client_Timer_Expiry"
    /\ clientTimerRunning = TRUE
    /\ clientTimerRunning' = FALSE
    /\ clientState' = "Error"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, serverTimerRunning, clientReqVersions, clientReqMTU, 
                   clientReqWindow, serverRspVersion, serverRspMTU, serverRspWindow, 
                   sessionVersion, sessionMTU, sessionWindow>>

\* SOURCE: core_4.19.4.3 Session Establishment
Server_Timer_Expiry ==
    /\ pendingInput = "Server_Timer_Expiry"
    /\ serverTimerRunning = TRUE
    /\ serverTimerRunning' = FALSE
    /\ serverState' = "Error"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientState, clientTimerRunning, clientReqVersions, clientReqMTU, 
                   clientReqWindow, serverRspVersion, serverRspMTU, serverRspWindow, 
                   sessionVersion, sessionMTU, sessionWindow>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ BLE_Connect
    \/ DPLE_Update
    \/ GATT_Exchange_MTU
    \/ GATT_Discover_Primary_Service
    \/ GATT_Discover_Characteristics
    \/ GATT_Discover_Descriptors
    \/ Send_Handshake_Request
    \/ Receive_Handshake_Request
    \/ Receive_GATT_Write_Response
    \/ Send_Subscribe_C2
    \/ Receive_Subscribe_C2
    \/ Send_Handshake_Response
    \/ Receive_Handshake_Response
    \/ Client_Timer_Expiry
    \/ Server_Timer_Expiry

====