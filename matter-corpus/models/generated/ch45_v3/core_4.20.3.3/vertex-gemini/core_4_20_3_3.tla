---- MODULE core_4_20_3_3 ----
EXTENDS Naturals

CONSTANTS NoInput

\* Configured limits and supported features for the Commissioner
CONSTANTS CommissionerSupportedVersions
CONSTANTS CommissionerMaxInfoLength
CONSTANTS CommissionerMaxWindowSize

\* Configured limits and supported features for the Commissionable Device
CONSTANTS DeviceSupportedVersions
CONSTANTS DeviceMaxInfoLength
CONSTANTS DeviceMaxWindowSize

VARIABLES pendingInput
VARIABLES commissionerState
VARIABLES deviceState
VARIABLES commissionerTimerActive
VARIABLES applicationError

\* Negotiated state on the Device
VARIABLES deviceSelectedVersion
VARIABLES deviceSelectedWindowSize
VARIABLES deviceSelectedPacketSize

\* Negotiated state on the Commissioner
VARIABLES commissionerSessionVersion
VARIABLES commissionerSessionWindowSize
VARIABLES commissionerSessionPacketSize

\* In-flight message data for PAFTP Handshake Request
VARIABLES msgRequestVersions
VARIABLES msgRequestMaxInfoLength
VARIABLES msgRequestMaxWindowSize

\* In-flight message data for PAFTP Handshake Response
VARIABLES msgResponseVersion
VARIABLES msgResponseWindowSize
VARIABLES msgResponsePacketSize

Inputs == {
    "EstablishWFAUSDConnection",
    "InitiatePAFTPSession",
    "ReceiveHandshakeRequest",
    "ReceiveHandshakeResponse",
    "PAFTP_CONN_RSP_TIMEOUT"
}

Init ==
    /\ pendingInput = NoInput
    /\ commissionerState = "Idle"
    /\ deviceState = "Idle"
    /\ commissionerTimerActive = FALSE
    /\ applicationError = FALSE
    /\ deviceSelectedVersion = 0
    /\ deviceSelectedWindowSize = 0
    /\ deviceSelectedPacketSize = 0
    /\ commissionerSessionVersion = 0
    /\ commissionerSessionWindowSize = 0
    /\ commissionerSessionPacketSize = 0
    /\ msgRequestVersions = {}
    /\ msgRequestMaxInfoLength = 0
    /\ msgRequestMaxWindowSize = 0
    /\ msgResponseVersion = 0
    /\ msgResponseWindowSize = 0
    /\ msgResponsePacketSize = 0

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<commissionerState, deviceState, commissionerTimerActive, applicationError, 
                   deviceSelectedVersion, deviceSelectedWindowSize, deviceSelectedPacketSize, 
                   commissionerSessionVersion, commissionerSessionWindowSize, commissionerSessionPacketSize,
                   msgRequestVersions, msgRequestMaxInfoLength, msgRequestMaxWindowSize,
                   msgResponseVersion, msgResponseWindowSize, msgResponsePacketSize>>

\* Helper operators for calculating negotiation parameters
Min(a, b) == IF a < b THEN a ELSE b
MaxInSet(S) == CHOOSE x \in S : \A y \in S : x >= y

SharedVersions(req, dev) == req \cap dev
MaxSharedVersion(req, dev) == 
    IF SharedVersions(req, dev) /= {} 
    THEN MaxInSet(SharedVersions(req, dev)) 
    ELSE 0

\* SOURCE: core_4.20.3.3 "Before a PAFTP session can be initiated, a Commissioner SHALL first establish a WFA-USD connection to a Commissionable Device."
EstablishWFAUSDConnection ==
    /\ pendingInput = "EstablishWFAUSDConnection"
    /\ commissionerState = "Idle"
    /\ deviceState = "Idle"
    /\ commissionerState' = "WFA_USD_Connected"
    /\ deviceState' = "WFA_USD_Connected"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissionerTimerActive, applicationError, 
                   deviceSelectedVersion, deviceSelectedWindowSize, deviceSelectedPacketSize, 
                   commissionerSessionVersion, commissionerSessionWindowSize, commissionerSessionPacketSize,
                   msgRequestVersions, msgRequestMaxInfoLength, msgRequestMaxWindowSize,
                   msgResponseVersion, msgResponseWindowSize, msgResponsePacketSize>>

\* SOURCE: core_4.20.3.3 "To initiate a PAFTP session, a Commissioner SHALL send a PAFTP handshake request packet to the Commissionable Device. The handshake request packet SHALL include, a list of PAFTP protocol versions supported by the Commissioner, the Commissioner's Supported Maximum Service Specific Info Length, and the Commissioner's maximum receive window size... When a Commissioner sends a handshake request, it SHALL start a timer with a globally-defined duration of PAFTP_CONN_RSP_TIMEOUT seconds."
InitiatePAFTPSession ==
    /\ pendingInput = "InitiatePAFTPSession"
    /\ commissionerState = "WFA_USD_Connected"
    /\ msgRequestVersions' = CommissionerSupportedVersions
    /\ msgRequestMaxInfoLength' = CommissionerMaxInfoLength
    /\ msgRequestMaxWindowSize' = CommissionerMaxWindowSize
    /\ commissionerState' = "WaitingForResponse"
    /\ commissionerTimerActive' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<deviceState, applicationError, 
                   deviceSelectedVersion, deviceSelectedWindowSize, deviceSelectedPacketSize, 
                   commissionerSessionVersion, commissionerSessionWindowSize, commissionerSessionPacketSize,
                   msgResponseVersion, msgResponseWindowSize, msgResponsePacketSize>>

\* SOURCE: core_4.20.3.3 "Once the Commissionable Device has received a PAFTP handshake request, it SHALL send a PAFTP handshake response to the Commissioner. This response SHALL contain the window size, maximum selected PAFTP packet size, and PAFTP protocol version selected by the Commissionable Device... The Commissionable Device SHALL select a window size equal to the minimum of its and the Commissioner’s maximum window sizes... SHALL select a maximum PAFTP Segment Size... by taking the minimum of Supported Maximum Service Specific Info Length received... and locally Supported Maximum Service Specific Info Length... SHALL select a PAFTP protocol version that is the newest which it and the Commissioner both support... If the Commissionable Device determines that it and the Commissioner do not share a supported PAFTP protocol version, the Commissionable Device SHALL close its WFA-USD connection to the Commissioner."
ReceiveHandshakeRequest ==
    /\ pendingInput = "ReceiveHandshakeRequest"
    /\ deviceState = "WFA_USD_Connected"
    /\ IF MaxSharedVersion(msgRequestVersions, DeviceSupportedVersions) = 0 THEN
           /\ deviceState' = "Closed"
           /\ UNCHANGED <<deviceSelectedVersion, deviceSelectedWindowSize, deviceSelectedPacketSize,
                          msgResponseVersion, msgResponseWindowSize, msgResponsePacketSize>>
       ELSE
           /\ deviceSelectedVersion' = MaxSharedVersion(msgRequestVersions, DeviceSupportedVersions)
           /\ deviceSelectedWindowSize' = Min(msgRequestMaxWindowSize, DeviceMaxWindowSize)
           /\ deviceSelectedPacketSize' = Min(msgRequestMaxInfoLength, DeviceMaxInfoLength)
           /\ deviceState' = "SessionEstablished"
           /\ msgResponseVersion' = MaxSharedVersion(msgRequestVersions, DeviceSupportedVersions)
           /\ msgResponseWindowSize' = Min(msgRequestMaxWindowSize, DeviceMaxWindowSize)
           /\ msgResponsePacketSize' = Min(msgRequestMaxInfoLength, DeviceMaxInfoLength)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commissionerState, commissionerTimerActive, applicationError, 
                   commissionerSessionVersion, commissionerSessionWindowSize, commissionerSessionPacketSize,
                   msgRequestVersions, msgRequestMaxInfoLength, msgRequestMaxWindowSize>>

\* SOURCE: core_4.20.3.3 "The version number returned in the handshake response SHALL determine the version of the PAFTP protocol used by Commissionable Device and Commissioner for the duration of the session."
ReceiveHandshakeResponse ==
    /\ pendingInput = "ReceiveHandshakeResponse"
    /\ commissionerState = "WaitingForResponse"
    /\ commissionerSessionVersion' = msgResponseVersion
    /\ commissionerSessionWindowSize' = msgResponseWindowSize
    /\ commissionerSessionPacketSize' = msgResponsePacketSize
    /\ commissionerState' = "SessionEstablished"
    /\ commissionerTimerActive' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<deviceState, applicationError, 
                   deviceSelectedVersion, deviceSelectedWindowSize, deviceSelectedPacketSize, 
                   msgRequestVersions, msgRequestMaxInfoLength, msgRequestMaxWindowSize,
                   msgResponseVersion, msgResponseWindowSize, msgResponsePacketSize>>

\* SOURCE: core_4.20.3.3 "If this timer expires before the Commissioner receives a handshake response from the Commissionable Device, the Commissioner SHALL close the PAFTP session and report an error to the application."
HandshakeResponseTimeout ==
    /\ pendingInput = "PAFTP_CONN_RSP_TIMEOUT"
    /\ commissionerTimerActive = TRUE
    /\ commissionerState = "WaitingForResponse"
    /\ commissionerState' = "Closed"
    /\ applicationError' = TRUE
    /\ commissionerTimerActive' = FALSE
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<deviceState, deviceSelectedVersion, deviceSelectedWindowSize, deviceSelectedPacketSize, 
                   commissionerSessionVersion, commissionerSessionWindowSize, commissionerSessionPacketSize,
                   msgRequestVersions, msgRequestMaxInfoLength, msgRequestMaxWindowSize,
                   msgResponseVersion, msgResponseWindowSize, msgResponsePacketSize>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ EstablishWFAUSDConnection
    \/ InitiatePAFTPSession
    \/ ReceiveHandshakeRequest
    \/ ReceiveHandshakeResponse
    \/ HandshakeResponseTimeout

====