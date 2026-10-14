---- MODULE core_4_20_3_8 ----
EXTENDS Naturals

\* The upper bound for sequence numbers to keep the model finite.
CONSTANTS MaxSeqNum

\* Sentinel value representing the absence of a sequence number.
CONSTANTS NoSeqNum

\* Sentinel value required by rule 4a.
CONSTANTS NoInput

VARIABLES pendingInput, inSeqNum, inAckNum, ackReceivedTimer, sendAckTimer,
          pendingAck, mostRecentUnackedSent, largestUnackedReceived,
          unackedSent, receivedSeqNums, sessionState, outSeqNum

SeqNums == 0..MaxSeqNum

Inputs == {
    "SendPacket",
    "ReceivePacket",
    "AckReceivedTimerExpires",
    "SendAckTimerExpires",
    "ReceiveWindowShrinks",
    "SendHandshakeResponse",
    "ReceiveHandshakeResponse"
}

Operational == sessionState = "OPEN"

Init ==
    /\ pendingInput = NoInput
    /\ inSeqNum = NoSeqNum
    /\ inAckNum = NoSeqNum
    /\ ackReceivedTimer = "STOPPED"
    /\ sendAckTimer = "STOPPED"
    /\ pendingAck = NoSeqNum
    /\ mostRecentUnackedSent = NoSeqNum
    /\ largestUnackedReceived = NoSeqNum
    /\ unackedSent = {}
    /\ receivedSeqNums = {}
    /\ sessionState = "OPEN"
    /\ outSeqNum = 1

\* Helper: computes the maximum contiguous received sequence number starting from 0
MaxContiguous(R) ==
    IF R = {} THEN NoSeqNum
    ELSE
        LET ValidS == {s \in R : \A x \in 0..s : x \in R}
        IN IF ValidS = {} THEN NoSeqNum
           ELSE CHOOSE s \in ValidS : \A y \in ValidS : y <= s

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e = "ReceivePacket" THEN
           \E s \in SeqNums, a \in SeqNums \cup {NoSeqNum} :
               /\ inSeqNum' = s
               /\ inAckNum' = a
       ELSE
           /\ inSeqNum' = NoSeqNum
           /\ inAckNum' = NoSeqNum
    /\ UNCHANGED <<ackReceivedTimer, sendAckTimer, pendingAck, mostRecentUnackedSent,
                   largestUnackedReceived, unackedSent, receivedSeqNums, sessionState,
                   outSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleSendPacket ==
    /\ pendingInput = "SendPacket"
    /\ sessionState = "OPEN"
    /\ outSeqNum < MaxSeqNum
    /\ ackReceivedTimer' = "RUNNING"
    /\ unackedSent' = unackedSent \cup {outSeqNum}
    /\ mostRecentUnackedSent' = outSeqNum
    /\ outSeqNum' = outSeqNum + 1
    /\ IF pendingAck # NoSeqNum THEN
           LET ackToSend == MaxContiguous(receivedSeqNums) IN
           /\ pendingAck' = NoSeqNum
           /\ IF ackToSend = largestUnackedReceived THEN
                  sendAckTimer' = "STOPPED"
              ELSE
                  sendAckTimer' = "RUNNING"
       ELSE
           /\ UNCHANGED <<pendingAck, sendAckTimer>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSeqNum, inAckNum, largestUnackedReceived, receivedSeqNums, sessionState>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleReceivePacket ==
    /\ pendingInput = "ReceivePacket"
    /\ sessionState = "OPEN"
    /\ LET isValidAck == (inAckNum # NoSeqNum) => (inAckNum \in unackedSent) IN
       IF ~isValidAck THEN
           /\ sessionState' = "CLOSED"
           /\ UNCHANGED <<ackReceivedTimer, sendAckTimer, pendingAck, mostRecentUnackedSent,
                          largestUnackedReceived, unackedSent, receivedSeqNums, outSeqNum>>
       ELSE
           /\ sessionState' = sessionState
           /\ pendingAck' = inSeqNum
           /\ sendAckTimer' = "RUNNING"
           /\ receivedSeqNums' = receivedSeqNums \cup {inSeqNum}
           /\ IF largestUnackedReceived = NoSeqNum THEN
                  largestUnackedReceived' = inSeqNum
              ELSE IF inSeqNum > largestUnackedReceived THEN
                  largestUnackedReceived' = inSeqNum
              ELSE
                  largestUnackedReceived' = largestUnackedReceived
           /\ IF inAckNum # NoSeqNum THEN
                  /\ unackedSent' = {s \in unackedSent : s > inAckNum}
                  /\ IF inAckNum = mostRecentUnackedSent THEN
                         ackReceivedTimer' = "STOPPED"
                     ELSE
                         ackReceivedTimer' = "RUNNING"
              ELSE
                  /\ unackedSent' = unackedSent
                  /\ ackReceivedTimer' = ackReceivedTimer
           /\ UNCHANGED <<mostRecentUnackedSent, outSeqNum>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSeqNum, inAckNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleAckReceivedTimerExpires ==
    /\ pendingInput = "AckReceivedTimerExpires"
    /\ sessionState = "OPEN"
    /\ ackReceivedTimer = "RUNNING"
    /\ sessionState' = "CLOSED"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSeqNum, inAckNum, ackReceivedTimer, sendAckTimer, pendingAck,
                   mostRecentUnackedSent, largestUnackedReceived, unackedSent, receivedSeqNums,
                   outSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleSendAckTimerExpires ==
    /\ pendingInput = "SendAckTimerExpires"
    /\ sessionState = "OPEN"
    /\ sendAckTimer = "RUNNING"
    /\ IF pendingAck # NoSeqNum THEN
           LET ackToSend == MaxContiguous(receivedSeqNums) IN
           /\ pendingAck' = NoSeqNum
           /\ IF ackToSend = largestUnackedReceived THEN
                  sendAckTimer' = "STOPPED"
              ELSE
                  sendAckTimer' = "RUNNING"
           /\ ackReceivedTimer' = "RUNNING"
           /\ outSeqNum < MaxSeqNum
           /\ unackedSent' = unackedSent \cup {outSeqNum}
           /\ mostRecentUnackedSent' = outSeqNum
           /\ outSeqNum' = outSeqNum + 1
       ELSE
           /\ UNCHANGED <<pendingAck, sendAckTimer, ackReceivedTimer, unackedSent, mostRecentUnackedSent, outSeqNum>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSeqNum, inAckNum, largestUnackedReceived, receivedSeqNums, sessionState>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleReceiveWindowShrinks ==
    /\ pendingInput = "ReceiveWindowShrinks"
    /\ sessionState = "OPEN"
    /\ IF pendingAck # NoSeqNum THEN
           LET ackToSend == MaxContiguous(receivedSeqNums) IN
           /\ pendingAck' = NoSeqNum
           /\ IF ackToSend = largestUnackedReceived THEN
                  sendAckTimer' = "STOPPED"
              ELSE
                  sendAckTimer' = "RUNNING"
           /\ ackReceivedTimer' = "RUNNING"
           /\ outSeqNum < MaxSeqNum
           /\ unackedSent' = unackedSent \cup {outSeqNum}
           /\ mostRecentUnackedSent' = outSeqNum
           /\ outSeqNum' = outSeqNum + 1
       ELSE
           /\ UNCHANGED <<pendingAck, sendAckTimer, ackReceivedTimer, unackedSent, mostRecentUnackedSent, outSeqNum>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSeqNum, inAckNum, largestUnackedReceived, receivedSeqNums, sessionState>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleSendHandshakeResponse ==
    /\ pendingInput = "SendHandshakeResponse"
    /\ sessionState = "OPEN"
    /\ ackReceivedTimer' = "RUNNING"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSeqNum, inAckNum, sendAckTimer, pendingAck, mostRecentUnackedSent,
                   largestUnackedReceived, unackedSent, receivedSeqNums, sessionState, outSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleReceiveHandshakeResponse ==
    /\ pendingInput = "ReceiveHandshakeResponse"
    /\ sessionState = "OPEN"
    /\ pendingAck' = 0
    /\ sendAckTimer' = "RUNNING"
    /\ receivedSeqNums' = receivedSeqNums \cup {0}
    /\ IF largestUnackedReceived = NoSeqNum THEN
           largestUnackedReceived' = 0
       ELSE IF 0 > largestUnackedReceived THEN
           largestUnackedReceived' = 0
       ELSE
           largestUnackedReceived' = largestUnackedReceived
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inSeqNum, inAckNum, ackReceivedTimer, mostRecentUnackedSent,
                   unackedSent, sessionState, outSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
SendOptionalStandAloneAck ==
    /\ pendingInput = NoInput
    /\ sessionState = "OPEN"
    /\ sendAckTimer = "RUNNING"
    /\ pendingAck # NoSeqNum
    /\ LET ackToSend == MaxContiguous(receivedSeqNums) IN
       /\ pendingAck' = NoSeqNum
       /\ IF ackToSend = largestUnackedReceived THEN
              sendAckTimer' = "STOPPED"
          ELSE
              sendAckTimer' = "RUNNING"
       /\ ackReceivedTimer' = "RUNNING"
       /\ outSeqNum < MaxSeqNum
       /\ unackedSent' = unackedSent \cup {outSeqNum}
       /\ mostRecentUnackedSent' = outSeqNum
       /\ outSeqNum' = outSeqNum + 1
    /\ UNCHANGED <<pendingInput, inSeqNum, inAckNum, largestUnackedReceived, receivedSeqNums, sessionState>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleSendPacket
    \/ HandleReceivePacket
    \/ HandleAckReceivedTimerExpires
    \/ HandleSendAckTimerExpires
    \/ HandleReceiveWindowShrinks
    \/ HandleSendHandshakeResponse
    \/ HandleReceiveHandshakeResponse
    \/ SendOptionalStandAloneAck

====