---- MODULE core_4_8_3 ----
EXTENDS Naturals

\* Session identifier domain
CONSTANTS SessionIds
\* Session type domain
CONSTANTS SessionTypes
\* Message counter domain
CONSTANTS MessageCounters
\* Set of possible symmetric keys
CONSTANTS Keys
\* Sentinel value for when a session context has no associated key
CONSTANTS NoKey
\* Set of possible message headers
CONSTANTS Headers
\* Set of possible ciphertexts (encrypted payloads)
CONSTANTS Ciphertexts
\* Set of possible decrypted plaintexts
CONSTANTS Plaintexts

\* Sentinel for no input event
CONSTANTS NoInput
\* Sentinel for empty or uninitialized message
CONSTANTS NoMsg
\* Sentinel for no output message produced
CONSTANTS NoOutput

VARIABLES pendingInput
VARIABLES inMsg
VARIABLES sessionKeys
VARIABLES outputMsg
VARIABLES status

Inputs == {"ReceiveSecuredMessage"}

Operational == TRUE

Init ==
    /\ pendingInput = NoInput
    /\ inMsg = NoMsg
    \* The environment dictates which sessions have which keys.
    \* This initializes with an arbitrary mapping and stays constant in this module.
    /\ sessionKeys \in [SessionIds \times SessionTypes -> Keys \cup {NoKey}]
    /\ outputMsg = NoOutput
    /\ status = "Idle"

SecuredMessage(sid, stype, ctr, hdr, cipher, vk, plain) == 
    [sessionId   |-> sid, 
     sessionType |-> stype, 
     counter     |-> ctr,
     header      |-> hdr, 
     ciphertext  |-> cipher, 
     validKey    |-> vk, 
     plaintext   |-> plain]

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e = "ReceiveSecuredMessage" THEN
           \* The incoming message carries intrinsic validity properties to abstract cryptography.
           \E sid \in SessionIds, stype \in SessionTypes, ctr \in MessageCounters, 
              hdr \in Headers, cipher \in Ciphertexts, vk \in Keys \cup {NoKey}, plain \in Plaintexts:
               inMsg' = SecuredMessage(sid, stype, ctr, hdr, cipher, vk, plain)
       ELSE
           inMsg' = inMsg
    /\ UNCHANGED <<sessionKeys, outputMsg, status>>

\* Abstraction: Nonce construction (Table 17).
\* We represent the nonce abstractly as a tuple of its constituent parameters.
\* TODO: unspecified - detailed byte-level construction is abstracted.
ConstructNonce(sid, stype, ctr) == <<sid, stype, ctr>>

\* Abstraction: AEAD decryption is abstracted. A real implementation would verify the MIC.
\* Here we simulate success if the key matches a designated validKey in the message.
\* TODO: unspecified - exact cryptographic operations are abstracted away.
Crypto_AEAD_DecryptVerify(K, C, A, N, msg) ==
    [success |-> (K /= NoKey /\ K = msg.validKey), P |-> msg.plaintext]

\* SOURCE: core_4.8.3 1-5
ProcessSecuredMessage ==
    /\ pendingInput = "ReceiveSecuredMessage"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inMsg, sessionKeys>>
    /\ LET sid == inMsg.sessionId
           stype == inMsg.sessionType
           ctr == inMsg.counter
           hdr == inMsg.header
           payload == inMsg.ciphertext
           key == sessionKeys[<<sid, stype>>]
       IN 
           IF key = NoKey THEN
               \* Step 2a: If no key is found, security processing SHALL indicate a failure
               /\ status' = "MessageSecurityFailed"
               /\ outputMsg' = NoOutput
           ELSE
               LET 
                   \* Step 3b: Construct nonce N
                   nonce == ConstructNonce(sid, stype, ctr)
                   \* Step 3e: Execute AEAD decrypt and verify
                   aeadResult == Crypto_AEAD_DecryptVerify(key, payload, hdr, nonce, inMsg)
               IN
                   IF ~aeadResult.success THEN
                       \* Step 4a: If success is FALSE, security processing SHALL fail
                       /\ status' = "AEADFailed"
                       /\ outputMsg' = NoOutput
                   ELSE
                       \* Step 4b & 5: Otherwise, PlaintextMessage = A || P
                       /\ status' = "Success"
                       \* PlaintextMessage is represented here as a tuple abstracting concatenation
                       /\ outputMsg' = <<hdr, aeadResult.P>> 

Next == 
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ ProcessSecuredMessage

====