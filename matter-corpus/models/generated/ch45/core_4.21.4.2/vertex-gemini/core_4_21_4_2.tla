---- MODULE core_4_21_4_2 ----
EXTENDS Naturals

CONSTANTS 
    MaxSupportedMsgSize, \* Maximum supported message size for the responder
    NullValue            \* Sentinel value for empty APDUs

VARIABLES 
    networkState,
    cApdu,
    rApdu,
    responderMsgBufferLen,
    responderPendingRespLen,
    initiatorTotalMsgLen,
    initiatorRemainingMsgLen

Init ==
    /\ networkState = "IDLE"
    /\ cApdu = NullValue
    /\ rApdu = NullValue
    /\ responderMsgBufferLen = 0
    /\ responderPendingRespLen = 0
    /\ initiatorTotalMsgLen = 0
    /\ initiatorRemainingMsgLen = 0

\* SOURCE: core_4.21.4.2 TRANSPORT command
InitiatorSendTransportCommand ==
    /\ networkState = "IDLE"
    /\ \E totalLen \in 1..(MaxSupportedMsgSize + 100), fragLen \in 1..255, le \in 1..256:
           IF initiatorRemainingMsgLen = 0 THEN
               \* Begin sending a new message
               /\ fragLen <= totalLen
               /\ cApdu' = [
                      CLA   |-> IF totalLen = fragLen THEN "0x80" ELSE "0x90",
                      INS   |-> "0x20",
                      P1_P2 |-> totalLen,
                      Lc    |-> fragLen,
                      Le    |-> le
                  ]
               /\ initiatorTotalMsgLen' = totalLen
               /\ initiatorRemainingMsgLen' = totalLen - fragLen
           ELSE
               \* Continue an existing chained message
               /\ fragLen <= initiatorRemainingMsgLen
               /\ cApdu' = [
                      CLA   |-> "0x90",
                      INS   |-> "0x20",
                      \* SOURCE: core_4.21.4.2 The same value SHALL be used in all chained commands.
                      P1_P2 |-> initiatorTotalMsgLen,
                      Lc    |-> fragLen,
                      Le    |-> le
                  ]
               /\ initiatorTotalMsgLen' = initiatorTotalMsgLen
               /\ initiatorRemainingMsgLen' = initiatorRemainingMsgLen - fragLen
    /\ networkState' = "WAIT_RESP"
    /\ UNCHANGED <<rApdu, responderMsgBufferLen, responderPendingRespLen>>

\* SOURCE: core_4.21.4.2 TRANSPORT command
ResponderHandleTransportCommand ==
    /\ networkState = "WAIT_RESP"
    /\ IF cApdu.P1_P2 > MaxSupportedMsgSize
       THEN
           \* SOURCE: core_4.21.4.2 In case the chained message exceeds the maximum supported message size, an error response conforming to Table 50 SHALL be issued, indicating 'Not enough memory space'.
           /\ rApdu' = [
                  SW1 |-> "0x6A",
                  SW2 |-> 132, \* 0x84
                  DataLen |-> 0
              ]
           /\ responderMsgBufferLen' = 0
           /\ responderPendingRespLen' = 0
       ELSE
           LET newBufferLen == IF cApdu.CLA = "0x80" THEN cApdu.Lc ELSE responderMsgBufferLen + cApdu.Lc IN
           /\ responderMsgBufferLen' = newBufferLen
           \* Check if the full message has been received
           /\ IF cApdu.CLA = "0x80" \/ newBufferLen = cApdu.P1_P2
              THEN
                  \* Generate response since the complete message is received
                  \E respLen \in 0..MaxSupportedMsgSize:
                      IF respLen <= cApdu.Le
                      THEN
                          \* SOURCE: core_4.21.4.2 In case the full message fits within the number of bytes encoded by Le in C-APDU, a successful response SHALL be indicated by the SW1 and SW2 values in Table 48.
                          /\ rApdu' = [
                                 SW1 |-> "0x90",
                                 SW2 |-> 0, \* 0x00
                                 DataLen |-> respLen
                             ]
                          /\ responderPendingRespLen' = 0
                      ELSE
                          \* SOURCE: core_4.21.4.2 In case the full message does not fit within the number of bytes encoded by Le in C-APDU, a successful but incomplete response SHALL be indicated by the SW1 value in Table 49, and SW2 SHALL encode the number of bytes of message to be sent in the next GET RESPONSE R-APDU.
                          /\ rApdu' = [
                                 SW1 |-> "0x61",
                                 SW2 |-> respLen - cApdu.Le,
                                 DataLen |-> cApdu.Le
                             ]
                          /\ responderPendingRespLen' = respLen - cApdu.Le
              ELSE
                  \* TODO: unspecified - SW1/SW2 values for intermediate successful chained fragments
                  /\ rApdu' = [
                         SW1 |-> "0x90",
                         SW2 |-> 0,
                         DataLen |-> 0
                     ]
                  /\ responderPendingRespLen' = responderPendingRespLen
    /\ networkState' = "IDLE"
    /\ UNCHANGED <<cApdu, initiatorTotalMsgLen, initiatorRemainingMsgLen>>

Next ==
    \/ InitiatorSendTransportCommand
    \/ ResponderHandleTransportCommand

====