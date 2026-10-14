---- MODULE core_4_8_3 ----
EXTENDS Naturals, Sequences

\* CONSTANTS representing fixed values and sentinels
CONSTANTS NoInput
CONSTANTS NoKey
CONSTANTS NoMessage
CONSTANTS InvalidCiphertext
CONSTANTS MockPlaintext

\* Types for domains
CONSTANTS SessionIDSet
CONSTANTS SessionTypeSet

VARIABLES pendingInput
\* Input event data variables (representing the incoming secured message fields)
VARIABLES inSessionID
VARIABLES inSessionType
VARIABLES inMessageCounter
VARIABLES inMessageHeaderA
VARIABLES inMessagePayloadC
VARIABLES inMessageNonceN

\* State variables
VARIABLES sessionContexts
VARIABLES nextLayerMessage
VARIABLES nextLayerStatus

\* All events this section can receive
Inputs == {"ReceiveSecuredMessage"}

\* Abstraction: Deterministic stub for DecryptVerify.
\* We assume decryption succeeds if C is not InvalidCiphertext.
\* This replaces the cryptographic implementation which cannot be modeled directly.
Crypto_AEAD_DecryptVerify(K, C, A, N) ==
    IF C # InvalidCiphertext
    THEN [success |-> TRUE, payload |-> MockPlaintext]
    ELSE [success |-> FALSE, payload |-> MockPlaintext]

\* Abstraction: Concatenation of A and P (octet strings)
Concat(A, P) == <<A, P>>

Init ==
    /\ pendingInput = NoInput
    /\ inSessionID = "DefaultSessionID"
    /\ inSessionType = "DefaultSessionType"
    /\ inMessageCounter = 0
    /\ inMessageHeaderA = "DefaultHeader"
    /\ inMessagePayloadC = "DefaultPayload"
    /\ inMessageNonceN = "DefaultNonce"
    /\ sessionContexts = [id \in SessionIDSet, type \in SessionTypeSet |-> NoKey]
    /\ nextLayerMessage = NoMessage
    /\ nextLayerStatus = "None"

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<inSessionID, inSessionType, inMessageCounter, inMessageHeaderA, 
                   inMessagePayloadC, inMessageNonceN, sessionContexts, nextLayerMessage, nextLayerStatus>>

\* SOURCE: core_4.8.3 Steps 1-5
ProcessReceiveSecuredMessage ==
    /\ pendingInput = "ReceiveSecuredMessage"
    /\ LET key == IF inSessionID \in SessionIDSet /\ inSessionType \in SessionTypeSet
                  THEN sessionContexts[inSessionID, inSessionType]
                  ELSE NoKey
       IN
           IF key = NoKey THEN
               /\ nextLayerStatus' = "message security failed"
               /\ nextLayerMessage' = NoMessage
           ELSE
               LET decryptResult == Crypto_AEAD_DecryptVerify(key, inMessagePayloadC, inMessageHeaderA, inMessageNonceN)
               IN
                   IF decryptResult.success = FALSE THEN
                       /\ nextLayerStatus' = "message security failed"
                       /\ nextLayerMessage' = NoMessage
                   ELSE
                       /\ nextLayerStatus' = "success"
                       /\ nextLayerMessage' = Concat(inMessageHeaderA, decryptResult.payload)
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSessionID, inSessionType, inMessageCounter, inMessageHeaderA, 
                   inMessagePayloadC, inMessageNonceN, sessionContexts>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ProcessReceiveSecuredMessage

====