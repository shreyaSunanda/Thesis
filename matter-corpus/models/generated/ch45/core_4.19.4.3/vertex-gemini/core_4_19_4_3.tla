---- MODULE core_4_19_4_3 ----
EXTENDS Naturals

\* BTP_CONN_RSP_TIMEOUT: globally-defined duration for BTP connection response timer
\* ClientSupportedVersions: set of protocol versions supported by the client
\* ServerSupportedVersions: set of protocol versions supported by the server
\* ClientMaxWindow: client's maximum receive window size
\* ServerMaxWindow: server's maximum receive window size
\* ServerAttMtu: server's GATT ATT_MTU
\* ClientAttMtuKnown: boolean indicating if client can determine the BLE connection's ATT_MTU
\* ActualClientAttMtu: client's GATT ATT_MTU if known
CONSTANTS BTP_CONN_RSP_TIMEOUT,
          ClientSupportedVersions,
          ServerSupportedVersions,
          ClientMaxWindow,
          ServerMaxWindow,
          ServerAttMtu,
          ClientAttMtuKnown,
          ActualClientAttMtu

VARIABLES 
    ble_state,               \* "Disconnected", "Connected", "Closed"
    dple_state,              \* "NotPerformed", "Performed"
    gatt_client_state,       \* "Idle", "MTUExchanged", "PrimaryServicesDiscovered", "CharacteristicsDiscovered", "DescriptorsDiscovered"
    btp_client_state,        \* "Idle", "HandshakeReqSent", "C2Subscribed", "SessionEstablished", "Closed"
    btp_server_state,        \* "Idle", "HandshakeReqReceived", "SessionEstablished", "Closed"
    msg_handshake_req,       \* BOOLEAN
    msg_handshake_ack,       \* BOOLEAN
    msg_handshake_rsp,       \* BOOLEAN
    client_timer,            \* "Inactive", "Active", "Expired"
    server_timer,            \* "Inactive", "Active", "Expired"
    server_c2_subscription,  \* BOOLEAN
    client_reported_error,   \* BOOLEAN
    server_reported_error,   \* BOOLEAN
    session_window_size,
    session_segment_size,
    session_version

Min(a, b) == IF a < b THEN a ELSE b
Min3(a, b, c) == Min(a, Min(b, c))
SharedVersions == ClientSupportedVersions \cap ServerSupportedVersions
HasSharedVersion == SharedVersions # {}
MaxSharedVersion == CHOOSE v \in SharedVersions : \A u \in SharedVersions : v >= u
ClientAttMtuValue == IF ClientAttMtuKnown THEN ActualClientAttMtu ELSE 23

Init ==
    /\ ble_state = "Disconnected"
    /\ dple_state = "NotPerformed"
    /\ gatt_client_state = "Idle"
    /\ btp_client_state = "Idle"
    /\ btp_server_state = "Idle"
    /\ msg_handshake_req = FALSE
    /\ msg_handshake_ack = FALSE
    /\ msg_handshake_rsp = FALSE
    /\ client_timer = "Inactive"
    /\ server_timer = "Inactive"
    /\ server_c2_subscription = FALSE
    /\ client_reported_error = FALSE
    /\ server_reported_error = FALSE
    /\ session_window_size = 0
    /\ session_segment_size = 0
    /\ session_version = 0

\* SOURCE: core_4.19.4.3 Session Establishment
CentralEstablishBLEConnection ==
    /\ ble_state = "Disconnected"
    /\ ble_state' = "Connected"
    /\ UNCHANGED <<dple_state, gatt_client_state, btp_client_state, btp_server_state, 
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp, 
                   client_timer, server_timer, server_c2_subscription, 
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
PeripheralPerformDPLE ==
    /\ ble_state = "Connected"
    /\ dple_state = "NotPerformed"
    /\ gatt_client_state = "Idle"
    /\ dple_state' = "Performed"
    /\ UNCHANGED <<ble_state, gatt_client_state, btp_client_state, btp_server_state,
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp,
                   client_timer, server_timer, server_c2_subscription,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ClientPerformMTUExchange ==
    /\ ble_state = "Connected"
    /\ gatt_client_state = "Idle"
    /\ gatt_client_state' = "MTUExchanged"
    /\ UNCHANGED <<ble_state, dple_state, btp_client_state, btp_server_state,
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp,
                   client_timer, server_timer, server_c2_subscription,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ClientDiscoverPrimaryServices ==
    /\ ble_state = "Connected"
    /\ gatt_client_state \in {"Idle", "MTUExchanged"}
    /\ gatt_client_state' = "PrimaryServicesDiscovered"
    /\ UNCHANGED <<ble_state, dple_state, btp_client_state, btp_server_state,
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp,
                   client_timer, server_timer, server_c2_subscription,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ClientDiscoverCharacteristics ==
    /\ gatt_client_state = "PrimaryServicesDiscovered"
    /\ gatt_client_state' = "CharacteristicsDiscovered"
    /\ UNCHANGED <<ble_state, dple_state, btp_client_state, btp_server_state,
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp,
                   client_timer, server_timer, server_c2_subscription,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ClientDiscoverDescriptors ==
    /\ gatt_client_state = "CharacteristicsDiscovered"
    /\ gatt_client_state' = "DescriptorsDiscovered"
    /\ UNCHANGED <<ble_state, dple_state, btp_client_state, btp_server_state,
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp,
                   client_timer, server_timer, server_c2_subscription,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ClientSendHandshakeRequest ==
    /\ gatt_client_state = "DescriptorsDiscovered"
    /\ btp_client_state = "Idle"
    /\ btp_client_state' = "HandshakeReqSent"
    /\ msg_handshake_req' = TRUE
    /\ client_timer' = "Active"
    /\ UNCHANGED <<ble_state, dple_state, gatt_client_state, btp_server_state,
                   msg_handshake_ack, msg_handshake_rsp,
                   server_timer, server_c2_subscription,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ServerReceiveHandshakeRequest ==
    /\ msg_handshake_req = TRUE
    /\ btp_server_state = "Idle"
    /\ msg_handshake_req' = FALSE
    /\ btp_server_state' = "HandshakeReqReceived"
    /\ msg_handshake_ack' = TRUE
    /\ server_timer' = "Active"
    /\ UNCHANGED <<ble_state, dple_state, gatt_client_state, btp_client_state,
                   msg_handshake_rsp, client_timer, server_c2_subscription,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ClientEnableC2Indications ==
    /\ msg_handshake_ack = TRUE
    /\ btp_client_state = "HandshakeReqSent"
    /\ msg_handshake_ack' = FALSE
    /\ btp_client_state' = "C2Subscribed"
    /\ server_c2_subscription' = TRUE
    /\ UNCHANGED <<ble_state, dple_state, gatt_client_state, btp_server_state,
                   msg_handshake_req, msg_handshake_rsp,
                   client_timer, server_timer,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ServerSendHandshakeResponse ==
    /\ btp_server_state = "HandshakeReqReceived"
    /\ server_c2_subscription = TRUE
    /\ HasSharedVersion
    /\ msg_handshake_rsp' = TRUE
    /\ btp_server_state' = "SessionEstablished"
    /\ server_timer' = "Inactive"
    /\ session_window_size' = Min(ServerMaxWindow, ClientMaxWindow)
    /\ session_segment_size' = Min3(244, ServerAttMtu - 3, ClientAttMtuValue - 3)
    /\ session_version' = MaxSharedVersion
    /\ UNCHANGED <<ble_state, dple_state, gatt_client_state, btp_client_state,
                   msg_handshake_req, msg_handshake_ack, client_timer,
                   server_c2_subscription, client_reported_error, server_reported_error>>

\* SOURCE: core_4.19.4.3 Session Establishment
ServerCloseBLEOnVersionMismatch ==
    /\ btp_server_state = "HandshakeReqReceived"
    /\ ~HasSharedVersion
    /\ ble_state' = "Closed"
    /\ server_timer' = "Inactive"
    /\ btp_server_state' = "Closed"
    /\ UNCHANGED <<dple_state, gatt_client_state, btp_client_state,
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp,
                   client_timer, server_c2_subscription,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ClientReceiveHandshakeResponse ==
    /\ msg_handshake_rsp = TRUE
    /\ btp_client_state = "C2Subscribed"
    /\ msg_handshake_rsp' = FALSE
    /\ btp_client_state' = "SessionEstablished"
    /\ client_timer' = "Inactive"
    /\ UNCHANGED <<ble_state, dple_state, gatt_client_state, btp_server_state,
                   msg_handshake_req, msg_handshake_ack, server_timer,
                   server_c2_subscription, client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ClientTimerExpires ==
    /\ client_timer = "Active"
    /\ client_timer' = "Expired"
    /\ UNCHANGED <<ble_state, dple_state, gatt_client_state, btp_client_state, btp_server_state,
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp,
                   server_timer, server_c2_subscription,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ServerTimerExpires ==
    /\ server_timer = "Active"
    /\ server_timer' = "Expired"
    /\ UNCHANGED <<ble_state, dple_state, gatt_client_state, btp_client_state, btp_server_state,
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp,
                   client_timer, server_c2_subscription,
                   client_reported_error, server_reported_error,
                   session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ClientHandleTimerExpiry ==
    /\ client_timer = "Expired"
    /\ btp_client_state # "Closed"
    /\ btp_client_state' = "Closed"
    /\ client_reported_error' = TRUE
    /\ UNCHANGED <<ble_state, dple_state, gatt_client_state, btp_server_state,
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp,
                   client_timer, server_timer, server_c2_subscription,
                   server_reported_error, session_window_size, session_segment_size, session_version>>

\* SOURCE: core_4.19.4.3 Session Establishment
ServerHandleTimerExpiry ==
    /\ server_timer = "Expired"
    /\ ~server_c2_subscription
    /\ btp_server_state # "Closed"
    /\ btp_server_state' = "Closed"
    /\ server_reported_error' = TRUE
    /\ UNCHANGED <<ble_state, dple_state, gatt_client_state, btp_client_state,
                   msg_handshake_req, msg_handshake_ack, msg_handshake_rsp,
                   client_timer, server_timer, server_c2_subscription,
                   client_reported_error, session_window_size, session_segment_size, session_version>>

Next == 
    \/ CentralEstablishBLEConnection
    \/ PeripheralPerformDPLE
    \/ ClientPerformMTUExchange
    \/ ClientDiscoverPrimaryServices
    \/ ClientDiscoverCharacteristics
    \/ ClientDiscoverDescriptors
    \/ ClientSendHandshakeRequest
    \/ ServerReceiveHandshakeRequest
    \/ ClientEnableC2Indications
    \/ ServerSendHandshakeResponse
    \/ ServerCloseBLEOnVersionMismatch
    \/ ClientReceiveHandshakeResponse
    \/ ClientTimerExpires
    \/ ClientHandleTimerExpiry
    \/ ServerTimerExpires
    \/ ServerHandleTimerExpiry

====