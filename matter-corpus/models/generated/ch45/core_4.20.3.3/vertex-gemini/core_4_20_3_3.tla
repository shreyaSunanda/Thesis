---- MODULE core_4_20_3_3 ----
EXTENDS Naturals

\* Declare EVERY fixed value the spec text mentions (timeouts, limits, thresholds,
\* fabric indices, etc.) here. Give each one a short comment saying what it is.
CONSTANTS 
    \* A globally-defined duration of PAFTP_CONN_RSP_TIMEOUT seconds
    PAFTP_CONN_RSP_TIMEOUT,
    \* Commissioner's supported versions
    CommissionerSupportedVersions,
    \* Commissioner's maximum service specific info length
    CommissionerMaxInfoLen,
    \* Commissioner's maximum receive window size
    CommissionerMaxWindowSize,
    \* Commissionable Device's locally supported versions
    DeviceSupportedVersions,
    \* Commissionable Device's locally supported maximum service specific info length
    DeviceMaxInfoLen,
    \* Commissionable Device's maximum window size
    DeviceMaxWindowSize

VARIABLES 
    wfa_usd_connection, \* State of the WFA-USD connection (e.g., "CLOSED", "ESTABLISHED")
    paftp_session,      \* State of the PAFTP session (e.g., "CLOSED", "REQ_SENT", "ESTABLISHED")
    timer_state,        \* State of the PAFTP_CONN_RSP_TIMEOUT timer
    network_msg,        \* Simulates the in-flight packet between Commissioner and Device
    app_error,          \* Boolean flag for error reported to the application
    active_version      \* Version of PAFTP negotiated and used for the session

Min(x, y) == IF x < y THEN x ELSE y
MaxOfSet(S) == CHOOSE x \in S : \A y \in S : x >= y

Init ==
    /\ wfa_usd_connection = "CLOSED"
    /\ paftp_session = "CLOSED"
    /\ timer_state = "INACTIVE"
    /\ network_msg = [type |-> "NONE"]
    /\ app_error = FALSE
    /\ active_version = 0

\* SOURCE: core_4.20.3.3
\* "Before a PAFTP session can be initiated, a Commissioner SHALL first establish a WFA-USD connection to a Commissionable Device."
EstablishWFAUSD ==
    /\ wfa_usd_connection = "CLOSED"
    /\ wfa_usd_connection' = "ESTABLISHED"
    /\ UNCHANGED <<paftp_session, timer_state, network_msg, app_error, active_version>>

\* SOURCE: core_4.20.3.3
\* "To initiate a PAFTP session, a Commissioner SHALL send a PAFTP handshake request packet to the Commissionable Device. The handshake request packet SHALL include, a list of PAFTP protocol versions supported by the Commissioner, the Commissioner’s Supported Maximum Service Specific Info Length, and the Commissioner’s maximum receive window size."
\* "When a Commissioner sends a handshake request, it SHALL start a timer with a globally-defined duration of PAFTP_CONN_RSP_TIMEOUT seconds."
CommissionerSendHandshakeReq ==
    /\ wfa_usd_connection = "ESTABLISHED"
    /\ paftp_session = "CLOSED"
    \* Note: Spec states list of versions SHALL be sorted in descending numerical order. Modeled as a Set for abstract logical evaluation.
    /\ network_msg' = [
           type |-> "REQ",
           versions |-> CommissionerSupportedVersions,
           info_len |-> CommissionerMaxInfoLen,
           window_size |-> CommissionerMaxWindowSize
       ]
    /\ paftp_session' = "REQ_SENT"
    /\ timer_state' = "RUNNING"
    /\ UNCHANGED <<wfa_usd_connection, app_error, active_version>>

\* SOURCE: core_4.20.3.3
\* "Once the Commissionable Device has received a PAFTP handshake request, it SHALL send a PAFTP handshake response to the Commissioner."
\* "The Commissionable Device SHALL select a window size equal to the minimum of its and the Commissioner’s maximum window sizes. Likewise, the Commissionable Device SHALL select a maximum PAFTP Segment Size including PAFTP header for the WFA-USD connection by taking the minimum of Supported Maximum Service Specific Info Length received in PAFTP Handshake Request and locally Supported Maximum Service Specific Info Length by the Commissionable Device."
\* "The Commissionable Device SHALL select a PAFTP protocol version that is the newest which it and the Commissioner both support, where newer protocol version numbers are strictly larger than those of older versions."
\* "If the Commissionable Device determines that it and the Commissioner do not share a supported PAFTP protocol version, the Commissionable Device SHALL close its WFA-USD connection to the Commissioner."
DeviceHandleReq ==
    /\ wfa_usd_connection = "ESTABLISHED"
    /\ network_msg.type = "REQ"
    /\ LET shared_versions == network_msg.versions \cap DeviceSupportedVersions
       IN IF shared_versions = {}
          THEN /\ wfa_usd_connection' = "CLOSED"
               /\ network_msg' = [type |-> "NONE"]
          ELSE /\ wfa_usd_connection' = wfa_usd_connection
               /\ network_msg' = [
                      type |-> "RSP",
                      window_size |-> Min(DeviceMaxWindowSize, network_msg.window_size),
                      segment_size |-> Min(DeviceMaxInfoLen, network_msg.info_len),
                      version |-> MaxOfSet(shared_versions)
                  ]
    /\ UNCHANGED <<paftp_session, timer_state, app_error, active_version>>

\* SOURCE: core_4.20.3.3
\* "The version number returned in the handshake response SHALL determine the version of the PAFTP protocol used by Commissionable Device and Commissioner for the duration of the session."
CommissionerReceiveResponse ==
    /\ paftp_session = "REQ_SENT"
    /\ network_msg.type = "RSP"
    /\ timer_state = "RUNNING"
    /\ paftp_session' = "ESTABLISHED"
    /\ active_version' = network_msg.version
    /\ timer_state' = "INACTIVE"
    /\ network_msg' = [type |-> "NONE"]
    /\ UNCHANGED <<wfa_usd_connection, app_error>>

\* SOURCE: core_4.20.3.3
\* "If this timer expires before the Commissioner receives a handshake response from the Commissionable Device..."
TimerExpires ==
    /\ timer_state = "RUNNING"
    /\ timer_state' = "EXPIRED"
    /\ UNCHANGED <<wfa_usd_connection, paftp_session, network_msg, app_error, active_version>>

\* SOURCE: core_4.20.3.3
\* "If this timer expires before the Commissioner receives a handshake response from the Commissionable Device, the Commissioner SHALL close the PAFTP session and report an error to the application."
CommissionerHandleTimeout ==
    /\ timer_state = "EXPIRED"
    /\ paftp_session' = "CLOSED"
    /\ app_error' = TRUE
    /\ timer_state' = "INACTIVE"
    /\ UNCHANGED <<wfa_usd_connection, network_msg, active_version>>

Next ==
    \/ EstablishWFAUSD
    \/ CommissionerSendHandshakeReq
    \/ DeviceHandleReq
    \/ CommissionerReceiveResponse
    \/ TimerExpires
    \/ CommissionerHandleTimeout

====