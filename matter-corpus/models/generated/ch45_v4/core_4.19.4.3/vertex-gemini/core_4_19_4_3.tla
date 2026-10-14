---- MODULE core_4_19_4_3 ----
EXTENDS Naturals, Sequences

\* Timeouts and limits
CONSTANTS BTP_CONN_RSP_TIMEOUT
CONSTANTS MinATT_MTU             \* e.g., 23
CONSTANTS MaxCharacteristicLen   \* e.g., 244
CONSTANTS GATT_Header_Size       \* e.g., 3
CONSTANTS C2_CCCD_Enable_Value   \* e.g., 1

\* Supported versions, capabilities, and device knowledge
CONSTANTS ClientSupportedVersions       \* Set of numerical versions
CONSTANTS ServerSupportedVersions       \* Set of numerical versions
CONSTANTS ClientProtocolVersionsSequence \* Sequence of supported versions in descending order
CONSTANTS ClientATT_MTU, ServerATT_MTU
CONSTANTS ClientMaxWindowSize, ServerMaxWindowSize
CONSTANTS ClientKnowsATT_MTU            \* BOOLEAN representing if client can determine ATT_MTU

\* REQUIRED
CONSTANTS NoInput
VARIABLES pendingInput

\* Additional state variables for tracking Client, Server, and exchanged session data
VARIABLES
    clientState,
    serverState,
    clientTimerActive,
    serverTimerActive,
    clientErrorReported,
    serverErrorReported,
    bleConnectionActive,
    reqVersions,
    reqMtu,
    reqWindow,
    c2Subscribed,
    rspVersion,
    rspWindow,
    rspMaxSegmentSize

\* Helper Definitions
Min(a, b) == IF a < b THEN a ELSE b
Min3(a, b, c) == Min(a, Min(b, c))
Max(S) == CHOOSE x \in S : \A y \in S : x >= y

Range(s) == {s[i] : i \in DOMAIN s}
SharedVersionsSet(reqV) == ServerSupportedVersions \cap Range(reqV)
HasSharedVersion(reqV) == SharedVersionsSet(reqV) # {}
NewestSharedVersion(reqV) == IF HasSharedVersion(reqV) THEN Max(SharedVersionsSet(reqV)) ELSE 0

Operational == clientState # "DISCONNECTED" \/ serverState # "DISCONNECTED"

Inputs == {
    "BLE_Connect",
    "DPLE_Update",
    "GATT_Exchange_MTU",
    "GATT_Discover",
    "Initiate_BTP_Session",
    "Receive_Handshake_Request",
    "Receive_GATT_Write_Response",
    "Receive_C2_Subscription",
    "Receive_Handshake_Response",
    "BTP_Conn_Rsp_Timeout_Client",
    "BTP_Conn_Rsp_Timeout_Server"
}

Init ==
    /\ pendingInput = NoInput
    /\ clientState = "DISCONNECTED"
    /\ serverState = "DISCONNECTED"
    /\ clientTimerActive = FALSE
    /\ serverTimerActive = FALSE
    /\ clientErrorReported = FALSE
    /\ serverErrorReported = FALSE
    /\ bleConnectionActive = FALSE
    /\ reqVersions = <<>>
    /\ reqMtu = 0
    /\ reqWindow = 0
    /\ c2Subscribed = FALSE
    /\ rspVersion = 0
    /\ rspWindow = 0
    /\ rspMaxSegmentSize = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<clientState, serverState, clientTimerActive, serverTimerActive, clientErrorReported, serverErrorReported, bleConnectionActive, reqVersions, reqMtu, reqWindow, c2Subscribed, rspVersion, rspWindow, rspMaxSegmentSize>>

\* SOURCE: core_4.19.4.3 Before a BTP session can be initiated, a central SHALL first establish a BLE connection to a peripheral.
BLE_Connect_Action ==
    /\ pendingInput = "BLE_Connect"
    /\ clientState = "DISCONNECTED"
    /\ serverState = "DISCONNECTED"
    /\ bleConnectionActive' = TRUE
    /\ clientState' = "BLE_CONNECTED"
    /\ serverState' = "BLE_CONNECTED"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientTimerActive, serverTimerActive, clientErrorReported, serverErrorReported, reqVersions, reqMtu, reqWindow, c2Subscribed, rspVersion, rspWindow, rspMaxSegmentSize>>

\* SOURCE: core_4.19.4.3 If peripheral supports LE Data Packet Length Extension (DPLE) feature it SHOULD perform data length update procedure before establishing a GATT connection.
DPLE_Update_Action ==
    /\ pendingInput = "DPLE_Update"
    /\ serverState = "BLE_CONNECTED"
    /\ serverState' = "DPLE_UPDATED"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientState, clientTimerActive, serverTimerActive, clientErrorReported, serverErrorReported, bleConnectionActive, reqVersions, reqMtu, reqWindow, c2Subscribed, rspVersion, rspWindow, rspMaxSegmentSize>>

\* SOURCE: core_4.19.4.3 Before establishing a BTP session, the GATT client SHOULD perform a GATT Exchange MTU procedure.
GATT_Exchange_MTU_Action ==
    /\ pendingInput = "GATT_Exchange_MTU"
    /\ clientState = "BLE_CONNECTED"
    /\ clientState' = "MTU_EXCHANGED"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, clientTimerActive, serverTimerActive, clientErrorReported, serverErrorReported, bleConnectionActive, reqVersions, reqMtu, reqWindow, c2Subscribed, rspVersion, rspWindow, rspMaxSegmentSize>>

\* SOURCE: core_4.19.4.3 After that the BTP Client SHALL execute the GATT discovery procedure.
GATT_Discovery_Action ==
    /\ pendingInput = "GATT_Discover"
    /\ clientState \in {"BLE_CONNECTED", "MTU_EXCHANGED"}
    /\ clientState' = "DISCOVERED"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, clientTimerActive, serverTimerActive, clientErrorReported, serverErrorReported, bleConnectionActive, reqVersions, reqMtu, reqWindow, c2Subscribed, rspVersion, rspWindow, rspMaxSegmentSize>>

\* SOURCE: core_4.19.4.3 To initiate a BTP session, a BTP Client SHALL send a BTP handshake request packet to the BTP Server... When a client sends a handshake request, it SHALL start a timer
Initiate_BTP_Session_Action ==
    /\ pendingInput = "Initiate_BTP_Session"
    /\ clientState = "DISCOVERED"
    /\ reqVersions' = ClientProtocolVersionsSequence
    /\ reqMtu' = IF ClientKnowsATT_MTU THEN ClientATT_MTU ELSE MinATT_MTU
    /\ reqWindow' = ClientMaxWindowSize
    /\ clientTimerActive' = TRUE
    /\ clientState' = "HANDSHAKE_REQ_SENT"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, serverTimerActive, clientErrorReported, serverErrorReported, bleConnectionActive, c2Subscribed, rspVersion, rspWindow, rspMaxSegmentSize>>

\* SOURCE: core_4.19.4.3 Likewise, a server SHALL start a timer with the same duration when it receives a handshake request from a client.
Receive_Handshake_Request_Action ==
    /\ pendingInput = "Receive_Handshake_Request"
    /\ serverState \in {"BLE_CONNECTED", "DPLE_UPDATED"}
    /\ serverTimerActive' = TRUE
    /\ serverState' = "WAITING_C2_SUB"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientState, clientTimerActive, clientErrorReported, serverErrorReported, bleConnectionActive, reqVersions, reqMtu, reqWindow, c2Subscribed, rspVersion, rspWindow, rspMaxSegmentSize>>

\* SOURCE: core_4.19.4.3 After the BTP Client acknowledges delivery of the handshake request packet, upon receipt of a GATT Write Response, the BTP Client SHALL enable indications over C2
Receive_GATT_Write_Response_Action ==
    /\ pendingInput = "Receive_GATT_Write_Response"
    /\ clientState = "HANDSHAKE_REQ_SENT"
    /\ c2Subscribed' = TRUE
    /\ clientState' = "WAITING_HANDSHAKE_RSP"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, clientTimerActive, serverTimerActive, clientErrorReported, serverErrorReported, bleConnectionActive, reqVersions, reqMtu, reqWindow, rspVersion, rspWindow, rspMaxSegmentSize>>

\* SOURCE: core_4.19.4.3 Once the GATT server has received a client’s BTP handshake request and confirmed the client’s subscription to C2, it SHALL send a BTP handshake response
Receive_C2_Subscription_Action ==
    /\ pendingInput = "Receive_C2_Subscription"
    /\ serverState = "WAITING_C2_SUB"
    /\ serverTimerActive' = FALSE
    /\ IF HasSharedVersion(reqVersions)
       THEN /\ rspVersion' = NewestSharedVersion(reqVersions)
            /\ rspWindow' = Min(ServerMaxWindowSize, reqWindow)
            /\ rspMaxSegmentSize' = Min3(MaxCharacteristicLen,
                                         IF ServerATT_MTU > GATT_Header_Size THEN ServerATT_MTU - GATT_Header_Size ELSE 0,
                                         IF reqMtu > GATT_Header_Size THEN reqMtu - GATT_Header_Size ELSE 0)
            /\ serverState' = "SESSION_ESTABLISHED"
            /\ bleConnectionActive' = bleConnectionActive
       ELSE /\ bleConnectionActive' = FALSE
            /\ serverState' = "CLOSED"
            /\ rspVersion' = rspVersion
            /\ rspWindow' = rspWindow
            /\ rspMaxSegmentSize' = rspMaxSegmentSize
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientState, clientTimerActive, clientErrorReported, serverErrorReported, reqVersions, reqMtu, reqWindow, c2Subscribed>>

\* SOURCE: core_4.19.4.3 The version number returned in the handshake response SHALL determine the version of the BTP protocol used by client and server for the duration of the session.
Receive_Handshake_Response_Action ==
    /\ pendingInput = "Receive_Handshake_Response"
    /\ clientState = "WAITING_HANDSHAKE_RSP"
    /\ clientTimerActive' = FALSE
    /\ clientState' = "SESSION_ESTABLISHED"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, serverTimerActive, clientErrorReported, serverErrorReported, bleConnectionActive, reqVersions, reqMtu, reqWindow, c2Subscribed, rspVersion, rspWindow, rspMaxSegmentSize>>

\* SOURCE: core_4.19.4.3 If this timer expires before the client receives a handshake response from the server, the client SHALL close the BTP session and report an error to the application.
BTP_Conn_Rsp_Timeout_Client_Action ==
    /\ pendingInput = "BTP_Conn_Rsp_Timeout_Client"
    /\ clientTimerActive = TRUE
    /\ clientTimerActive' = FALSE
    /\ clientState' = "CLOSED"
    /\ clientErrorReported' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<serverState, serverTimerActive, serverErrorReported, bleConnectionActive, reqVersions, reqMtu, reqWindow, c2Subscribed, rspVersion, rspWindow, rspMaxSegmentSize>>

\* SOURCE: core_4.19.4.3 If this timer expires before the server receives a subscription request on C2, the server SHALL close the BTP session and report an error to the application.
BTP_Conn_Rsp_Timeout_Server_Action ==
    /\ pendingInput = "BTP_Conn_Rsp_Timeout_Server"
    /\ serverTimerActive = TRUE
    /\ serverTimerActive' = FALSE
    /\ serverState' = "CLOSED"
    /\ serverErrorReported' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<clientState, clientTimerActive, clientErrorReported, bleConnectionActive, reqVersions, reqMtu, reqWindow, c2Subscribed, rspVersion, rspWindow, rspMaxSegmentSize>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ BLE_Connect_Action
    \/ DPLE_Update_Action
    \/ GATT_Exchange_MTU_Action
    \/ GATT_Discovery_Action
    \/ Initiate_BTP_Session_Action
    \/ Receive_Handshake_Request_Action
    \/ Receive_GATT_Write_Response_Action
    \/ Receive_C2_Subscription_Action
    \/ Receive_Handshake_Response_Action
    \/ BTP_Conn_Rsp_Timeout_Client_Action
    \/ BTP_Conn_Rsp_Timeout_Server_Action

====