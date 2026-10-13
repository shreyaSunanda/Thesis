---- MODULE core_4_8_3 ----
EXTENDS Naturals

\* Session identifiers and types
CONSTANTS SessionIDs
CONSTANTS SessionTypes

\* Encryption keys and a sentinel for "no key found"
CONSTANTS Keys
CONSTANTS NullKey

\* Message counter upper bound. Real value per spec: 2^32 - 1. 
\* Keep small for model checking.
CONSTANTS MaxMessageCounter

\* Abstract domains for payloads and nonces
CONSTANTS Payloads
CONSTANTS Nonces

\* Deterministic abstraction of Crypto_AEAD_DecryptVerify.
\* Maps <<K, C, A, N>> to a record [success: BOOLEAN, P: Payloads]
CONSTANTS MockDecryptVerify

VARIABLES pendingMessages
VARIABLES sessionKeys
VARIABLES upperLayerMessages
VARIABLES upperLayerErrors

MessageHeaders == 
    [
        sessionId      : SessionIDs,
        sessionType    : SessionTypes,
        messageCounter : 0..MaxMessageCounter
    ]

ValidIncomingMessages == 
    [
        header  : MessageHeaders,
        payload : Payloads,
        nonce   : Nonces
    ]

\* TODO: unspecified - Actual cryptography computation is abstracted deterministically here.
Crypto_AEAD_DecryptVerify(K, C, A, N) == MockDecryptVerify[K, C, A, N]

\* Abstraction: Concatenation of header and payload (A || P).
Concat(A, P) == <<A, P>>

Init ==
    /\ pendingMessages = {}
    \* The session context store is populated non-deterministically with valid keys or NullKey.
    /\ sessionKeys \in [SessionIDs \times SessionTypes -> Keys \cup {NullKey}]
    /\ upperLayerMessages = {}
    /\ upperLayerErrors = {}

\* SOURCE: core_4.8.3
\* "If the transport layer receives a secured message as indicated by the Session ID..."
ReceiveSecuredMessage(msg) ==
    /\ pendingMessages' = pendingMessages \cup {msg}
    /\ UNCHANGED <<sessionKeys, upperLayerMessages, upperLayerErrors>>

\* SOURCE: core_4.8.3
\* "All incoming message processing SHALL occur in a serialized manner... 
\* If the transport layer receives a secured message... it SHALL perform the following steps"
ProcessSecuredMessage(msg) ==
    /\ msg \in pendingMessages
    /\ LET
           \* Step 1
           sid == msg.header.sessionId
           stype == msg.header.sessionType
           ctr == msg.header.messageCounter
           \* Step 2
           K == sessionKeys[sid, stype]
       IN
           IF K = NullKey THEN
               \* Step 2a: Failure finding key
               /\ upperLayerErrors' = upperLayerErrors \cup {"message security failed"}
               /\ pendingMessages' = pendingMessages \ {msg}
               /\ UNCHANGED <<sessionKeys, upperLayerMessages>>
           ELSE
               \* Step 3
               LET
                   C == msg.payload
                   A == msg.header
                   N == msg.nonce
                   result == Crypto_AEAD_DecryptVerify(K, C, A, N)
               IN
                   IF ~result.success THEN
                       \* Step 4a: AEAD failure
                       /\ upperLayerErrors' = upperLayerErrors \cup {"AEAD verification failed"}
                       /\ pendingMessages' = pendingMessages \ {msg}
                       /\ UNCHANGED <<sessionKeys, upperLayerMessages>>
                   ELSE
                       \* Step 4b & 5: Success
                       LET
                           PlaintextMessage == Concat(A, result.P)
                       IN
                           /\ upperLayerMessages' = upperLayerMessages \cup {PlaintextMessage}
                           /\ pendingMessages' = pendingMessages \ {msg}
                           /\ UNCHANGED <<sessionKeys, upperLayerErrors>>

Next ==
    \/ \E msg \in ValidIncomingMessages : ReceiveSecuredMessage(msg)
    \/ \E msg \in pendingMessages : ProcessSecuredMessage(msg)

====