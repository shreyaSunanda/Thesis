---- MODULE core_4_20_3_3 ----
EXTENDS Naturals

\* Fixed values mentioned in the spec
CONSTANTS PAFTP_CONN_RSP_TIMEOUT    \* Timeout duration for Commissioner to receive response

\* Protocol parameters & capabilities
CONSTANTS CommissionerSupportedVersions
CONSTANTS CommissionerMaxInfoLength
CONSTANTS CommissionerMaxWindowSize

CONSTANTS DeviceSupportedVersions
CONSTANTS DeviceMaxInfoLength
CONSTANTS DeviceMaxWindowSize

\* Sentinels for missing/uninitialized values
CONSTANTS NoVersion
CONSTANTS NoSize

\* REQUIRED - see rule 4a
CONSTANTS NoInput
VARIABLES pendingInput

\* State variables
VARIABLES commState
VARIABLES devState
VARIABLES commTimerActive

\* In-flight request data (abstracting network transmission from Commissioner to Device)
VARIABLES reqVersions
VARIABLES reqInfoLength
VARIABLES reqWindowSize

\* In-flight response data (abstracting network transmission from Device to Commissioner)
VARIABLES respVersion
VARIABLES respWindowSize
VARIABLES respInfoLength

\* Final selected session parameters on Commissioner side
VARIABLES sessionVersion
VARIABLES sessionWindowSize
VARIABLES sessionInfoLength

\* REQUIRED - complete list of events this section can receive
Inputs == {
    "InitiateHandshake",
    "ReceiveHandshakeRequest",
    "ReceiveHandshakeResponse",
    "HandshakeTimeout"
}

\* Helper operators
Min(a, b) == IF a < b THEN a ELSE b

SharedVersions(reqVers) == reqVers \cap DeviceSupportedVersions
HasSharedVersion(reqVers) == SharedVersions(reqVers) # {}

\* Maximum version is the shared version such that no other shared version is strictly larger
MaxSharedVersion(reqVers) == 
    CHOOSE v \in SharedVersions(reqVers) : \A v2 \in SharedVersions(reqVers) : v >= v2

Operational == commState \in {"WaitingForResponse", "SessionEstablished"} \/ devState = "SessionEstablished"

Init == 
    /\ pendingInput = NoInput
    /\ commState = "WFA_USD_Connected"
    /\ devState = "WFA_USD_Connected"
    /\ commTimerActive = FALSE
    /\ reqVersions = {}
    /\ reqInfoLength = NoSize
    /\ reqWindowSize = NoSize
    /\ respVersion = NoVersion
    /\ respWindowSize = NoSize
    /\ respInfoLength = NoSize
    /\ sessionVersion = NoVersion
    /\ sessionWindowSize = NoSize
    /\ sessionInfoLength = NoSize

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<commState, devState, commTimerActive, 
                   reqVersions, reqInfoLength, reqWindowSize, 
                   respVersion, respWindowSize, respInfoLength, 
                   sessionVersion, sessionWindowSize, sessionInfoLength>>

\* SOURCE: core_4.20.3.3 "To initiate a PAFTP session, a Commissioner SHALL send a PAFTP handshake request packet... start a timer"
CommissionerInitiateHandshake ==
    /\ pendingInput = "InitiateHandshake"
    /\ commState = "WFA_USD_Connected"
    /\ commState' = "WaitingForResponse"
    /\ commTimerActive' = TRUE
    /\ reqVersions' = CommissionerSupportedVersions
    /\ reqInfoLength' = CommissionerMaxInfoLength
    /\ reqWindowSize' = CommissionerMaxWindowSize
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<devState, respVersion, respWindowSize, respInfoLength, 
                   sessionVersion, sessionWindowSize, sessionInfoLength>>

\* SOURCE: core_4.20.3.3 "Once the Commissionable Device has received a PAFTP handshake request, it SHALL send a PAFTP handshake response... The Commissionable Device SHALL select..."
DeviceReceiveHandshakeRequest ==
    /\ pendingInput = "ReceiveHandshakeRequest"
    /\ devState = "WFA_USD_Connected"
    /\ reqVersions # {}
    /\ IF HasSharedVersion(reqVersions)
       THEN
           /\ devState' = "SessionEstablished"
           /\ respVersion' = MaxSharedVersion(reqVersions)
           /\ respWindowSize' = Min(reqWindowSize, DeviceMaxWindowSize)
           /\ respInfoLength' = Min(reqInfoLength, DeviceMaxInfoLength)
       ELSE
           \* SOURCE: core_4.20.3.3 "If the Commissionable Device determines that it and the Commissioner do not share a supported PAFTP protocol version, the Commissionable Device SHALL close its WFA-USD connection to the Commissioner."
           /\ devState' = "Closed"
           /\ respVersion' = NoVersion
           /\ respWindowSize' = NoSize
           /\ respInfoLength' = NoSize
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<commState, commTimerActive, reqVersions, reqInfoLength, reqWindowSize, 
                   sessionVersion, sessionWindowSize, sessionInfoLength>>

\* SOURCE: core_4.20.3.3 "The version number returned in the handshake response SHALL determine the version of the PAFTP protocol used by Commissionable Device and Commissioner for the duration of the session."
CommissionerReceiveHandshakeResponse ==
    /\ pendingInput = "ReceiveHandshakeResponse"
    /\ commState = "WaitingForResponse"
    /\ respVersion # NoVersion
    /\ commState' = "SessionEstablished"
    /\ commTimerActive' = FALSE
    /\ sessionVersion' = respVersion
    /\ sessionWindowSize' = respWindowSize
    /\ sessionInfoLength' = respInfoLength
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<devState, reqVersions, reqInfoLength, reqWindowSize, 
                   respVersion, respWindowSize, respInfoLength>>

\* SOURCE: core_4.20.3.3 "If this timer expires before the Commissioner receives a handshake response from the Commissionable Device, the Commissioner SHALL close the PAFTP session and report an error to the application."
CommissionerHandshakeTimeout ==
    /\ pendingInput = "HandshakeTimeout"
    /\ commTimerActive = TRUE
    /\ commState' = "ClosedWithError"
    /\ commTimerActive' = FALSE
    /\ pendingInput' = NoInput
    \* TODO: unspecified - how the application error report is modeled is abstracted here.
    /\ UNCHANGED <<devState, reqVersions, reqInfoLength, reqWindowSize, 
                   respVersion, respWindowSize, respInfoLength, 
                   sessionVersion, sessionWindowSize, sessionInfoLength>>

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ CommissionerInitiateHandshake
    \/ DeviceReceiveHandshakeRequest
    \/ CommissionerReceiveHandshakeResponse
    \/ CommissionerHandshakeTimeout

====