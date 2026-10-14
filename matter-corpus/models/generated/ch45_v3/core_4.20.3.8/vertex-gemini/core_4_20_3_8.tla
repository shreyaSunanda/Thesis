---- MODULE core_4_20_3_8 ----
EXTENDS Naturals

\* Sentinel for when no sequence number is present or recorded
CONSTANTS NoSeqNum
\* Maximum sequence number, abstracting the real space to bound the model checker
CONSTANTS MaxSeqNum

\* REQUIRED - fixed input shape
CONSTANTS NoInput
VARIABLES pendingInput

\* Data payload for inputs
VARIABLES inPacketSeqNum
VARIABLES inAckSeqNum

\* Protocol state variables
VARIABLES sessionState
VARIABLES ackReceivedTimer
VARIABLES sendAckTimer
VARIABLES pendingAckValue
VARIABLES unackedSentMsgs
VARIABLES mostRecentSentSeqNum
VARIABLES largestReceivedUnackedSeqNum
VARIABLES receivedUnackedSeqs
VARIABLES nextOutSeqNum

Inputs == {
    "SendPacket",
    "ReceivePacket",
    "AckReceivedTimerExpired",
    "SendAckTimerExpired",
    "ServerSendHandshakeResponse",
    "ClientReceiveHandshakeResponse",
    "DetectWindowShrunk",
    "SendStandaloneAck"
}

Init ==
    /\ pendingInput = NoInput
    /\ inPacketSeqNum = NoSeqNum
    /\ inAckSeqNum = NoSeqNum
    /\ sessionState = "Open"
    /\ ackReceivedTimer = "Stopped"
    /\ sendAckTimer = "Stopped"
    /\ pendingAckValue = NoSeqNum
    /\ unackedSentMsgs = {}
    /\ mostRecentSentSeqNum = NoSeqNum
    /\ largestReceivedUnackedSeqNum = NoSeqNum
    /\ receivedUnackedSeqs = {}
    /\ nextOutSeqNum = 1

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ IF e = "ReceivePacket"
       THEN \E pSeq \in 0..MaxSeqNum, aSeq \in {NoSeqNum} \cup 0..MaxSeqNum :
                /\ inPacketSeqNum' = pSeq
                /\ inAckSeqNum' = aSeq
       ELSE /\ inPacketSeqNum' = inPacketSeqNum
            /\ inAckSeqNum' = inAckSeqNum
    /\ UNCHANGED <<sessionState, ackReceivedTimer, sendAckTimer, pendingAckValue,
                  unackedSentMsgs, mostRecentSentSeqNum, largestReceivedUnackedSeqNum,
                  receivedUnackedSeqs, nextOutSeqNum>>

\* Helper definition encapsulating the logic for sending a stand-alone acknowledgment packet
DoSendStandaloneAck ==
    /\ ackReceivedTimer' = "Running"
    /\ unackedSentMsgs' = unackedSentMsgs \cup {nextOutSeqNum}
    /\ mostRecentSentSeqNum' = nextOutSeqNum
    /\ \E ackNum \in receivedUnackedSeqs :
           \* TODO: unspecified - abstracting the exact computation of highest contiguous received sequence number
           /\ sendAckTimer' = IF ackNum = largestReceivedUnackedSeqNum THEN "Stopped" ELSE "Running"
           /\ pendingAckValue' = NoSeqNum
           \* TODO: unspecified - abstracting sequence number wrap-around ordering as strictly linear
           /\ receivedUnackedSeqs' = {s \in receivedUnackedSeqs : s > ackNum}
    /\ nextOutSeqNum' = IF nextOutSeqNum < MaxSeqNum THEN nextOutSeqNum + 1 ELSE 0

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleReceivePacket ==
    /\ pendingInput = "ReceivePacket"
    /\ LET isAckPresent == inAckSeqNum # NoSeqNum
           isAckValid == inAckSeqNum \in unackedSentMsgs
       IN
           IF isAckPresent /\ ~isAckValid THEN
               /\ sessionState' = "Closed"
               /\ UNCHANGED <<ackReceivedTimer, sendAckTimer, pendingAckValue,
                              unackedSentMsgs, mostRecentSentSeqNum,
                              largestReceivedUnackedSeqNum, receivedUnackedSeqs,
                              nextOutSeqNum>>
           ELSE
               /\ IF isAckPresent THEN
                      \* TODO: unspecified - abstracting sequence number wrap-around ordering as strictly linear
                      /\ unackedSentMsgs' = {s \in unackedSentMsgs : s > inAckSeqNum}
                      /\ ackReceivedTimer' = IF inAckSeqNum = mostRecentSentSeqNum
                                             THEN "Stopped"
                                             ELSE "Running"
                  ELSE
                      /\ UNCHANGED <<unackedSentMsgs, ackReceivedTimer>>
               /\ pendingAckValue' = inPacketSeqNum
               /\ sendAckTimer' = "Running"
               /\ receivedUnackedSeqs' = receivedUnackedSeqs \cup {inPacketSeqNum}
               /\ largestReceivedUnackedSeqNum' = IF largestReceivedUnackedSeqNum = NoSeqNum \/ inPacketSeqNum > largestReceivedUnackedSeqNum
                                                  THEN inPacketSeqNum
                                                  ELSE largestReceivedUnackedSeqNum
               /\ UNCHANGED <<sessionState, mostRecentSentSeqNum, nextOutSeqNum>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<inPacketSeqNum, inAckSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleSendPacket ==
    /\ pendingInput = "SendPacket"
    /\ ackReceivedTimer' = "Running"
    /\ unackedSentMsgs' = unackedSentMsgs \cup {nextOutSeqNum}
    /\ mostRecentSentSeqNum' = nextOutSeqNum
    /\ nextOutSeqNum' = IF nextOutSeqNum < MaxSeqNum THEN nextOutSeqNum + 1 ELSE 0
    /\ IF pendingAckValue # NoSeqNum THEN
           \E ackNum \in receivedUnackedSeqs :
               /\ sendAckTimer' = IF ackNum = largestReceivedUnackedSeqNum THEN "Stopped" ELSE "Running"
               /\ pendingAckValue' = NoSeqNum
               /\ receivedUnackedSeqs' = {s \in receivedUnackedSeqs : s > ackNum}
       ELSE
           UNCHANGED <<sendAckTimer, pendingAckValue, receivedUnackedSeqs>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, largestReceivedUnackedSeqNum, inPacketSeqNum, inAckSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleAckReceivedTimerExpired ==
    /\ pendingInput = "AckReceivedTimerExpired"
    /\ sessionState' = "Closed"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<ackReceivedTimer, sendAckTimer, pendingAckValue, unackedSentMsgs,
                  mostRecentSentSeqNum, largestReceivedUnackedSeqNum, receivedUnackedSeqs,
                  nextOutSeqNum, inPacketSeqNum, inAckSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleSendAckTimerExpired ==
    /\ pendingInput = "SendAckTimerExpired"
    /\ IF pendingAckValue # NoSeqNum THEN
           DoSendStandaloneAck
       ELSE
           UNCHANGED <<ackReceivedTimer, unackedSentMsgs, mostRecentSentSeqNum,
                       sendAckTimer, pendingAckValue, receivedUnackedSeqs, nextOutSeqNum>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, largestReceivedUnackedSeqNum, inPacketSeqNum, inAckSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleDetectWindowShrunk ==
    /\ pendingInput = "DetectWindowShrunk"
    /\ IF pendingAckValue # NoSeqNum THEN
           DoSendStandaloneAck
       ELSE
           UNCHANGED <<ackReceivedTimer, unackedSentMsgs, mostRecentSentSeqNum,
                       sendAckTimer, pendingAckValue, receivedUnackedSeqs, nextOutSeqNum>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, largestReceivedUnackedSeqNum, inPacketSeqNum, inAckSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleSendStandaloneAck ==
    /\ pendingInput = "SendStandaloneAck"
    /\ sendAckTimer = "Running"
    /\ IF pendingAckValue # NoSeqNum THEN
           DoSendStandaloneAck
       ELSE
           UNCHANGED <<ackReceivedTimer, unackedSentMsgs, mostRecentSentSeqNum,
                       sendAckTimer, pendingAckValue, receivedUnackedSeqs, nextOutSeqNum>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, largestReceivedUnackedSeqNum, inPacketSeqNum, inAckSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleServerSendHandshakeResponse ==
    /\ pendingInput = "ServerSendHandshakeResponse"
    /\ ackReceivedTimer' = "Running"
    /\ unackedSentMsgs' = unackedSentMsgs \cup {0}
    /\ mostRecentSentSeqNum' = 0
    /\ nextOutSeqNum' = 1
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, sendAckTimer, pendingAckValue, largestReceivedUnackedSeqNum,
                  receivedUnackedSeqs, inPacketSeqNum, inAckSeqNum>>

\* SOURCE: core_4.20.3.8 Packet Acknowledgements
HandleClientReceiveHandshakeResponse ==
    /\ pendingInput = "ClientReceiveHandshakeResponse"
    /\ pendingAckValue' = 0
    /\ sendAckTimer' = "Running"
    /\ receivedUnackedSeqs' = receivedUnackedSeqs \cup {0}
    /\ largestReceivedUnackedSeqNum' = IF largestReceivedUnackedSeqNum = NoSeqNum \/ 0 > largestReceivedUnackedSeqNum
                                       THEN 0
                                       ELSE largestReceivedUnackedSeqNum
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, ackReceivedTimer, unackedSentMsgs, mostRecentSentSeqNum,
                  nextOutSeqNum, inPacketSeqNum, inAckSeqNum>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleReceivePacket
    \/ HandleSendPacket
    \/ HandleAckReceivedTimerExpired
    \/ HandleSendAckTimerExpired
    \/ HandleDetectWindowShrunk
    \/ HandleSendStandaloneAck
    \/ HandleServerSendHandshakeResponse
    \/ HandleClientReceiveHandshakeResponse

====