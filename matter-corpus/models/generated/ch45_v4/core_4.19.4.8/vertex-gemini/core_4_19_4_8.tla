---- MODULE core_4_19_4_8 ----
EXTENDS Naturals

\* Sequence numbers are 8-bit unsigned integers (real value 256).
\* Declared as a constant to allow bounded model checking.
CONSTANTS CounterModulus

\* Maximum size of the receive window, used to bound state space.
CONSTANTS MaxWindowSize

\* Sentinel value representing no sequence number.
CONSTANTS NoSeqNum

\* Sentinel for when no input is waiting.
CONSTANTS NoInput

VARIABLES state
VARIABLES pendingInput
VARIABLES unackedSent
VARIABLES nextOutSeqNum
VARIABLES lastSentSeqNum
VARIABLES ackReceivedTimerRunning
VARIABLES sendAckTimerRunning
VARIABLES pendingAckSeqNum

\* Variables modeling the data carried by an incoming packet event
VARIABLES inSeqNum
VARIABLES inAckNum
VARIABLES inWindowSize

Inputs == {
    "SendBTPPacket",
    "ReceiveBTPPacket",
    "SendServerHandshake",
    "ReceiveServerHandshake",
    "AckReceivedTimerFires",
    "SendAckTimerFires"
}

Operational == state = "OPEN"

Init ==
    /\ pendingInput = NoInput
    /\ state = "CLOSED"
    /\ unackedSent = {}
    /\ nextOutSeqNum = 0
    /\ lastSentSeqNum = NoSeqNum
    /\ ackReceivedTimerRunning = FALSE
    /\ sendAckTimerRunning = FALSE
    /\ pendingAckSeqNum = NoSeqNum
    /\ inSeqNum = NoSeqNum
    /\ inAckNum = NoSeqNum
    /\ inWindowSize = MaxWindowSize

ReceiveInput(e, seq, ack, win) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ inSeqNum' = seq
    /\ inAckNum' = ack
    /\ inWindowSize' = win
    /\ UNCHANGED << state, unackedSent, nextOutSeqNum, lastSentSeqNum,
                    ackReceivedTimerRunning, sendAckTimerRunning,
                    pendingAckSeqNum >>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
SendServerHandshake ==
    /\ pendingInput = "SendServerHandshake"
    \* Server handshake response bears an implicit sequence number of zero.
    /\ state' = "OPEN"
    /\ unackedSent' = {0}
    /\ lastSentSeqNum' = 0
    /\ nextOutSeqNum' = 1
    /\ ackReceivedTimerRunning' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED << sendAckTimerRunning, pendingAckSeqNum, inSeqNum, inAckNum, inWindowSize >>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
ReceiveServerHandshake ==
    /\ pendingInput = "ReceiveServerHandshake"
    \* Client receives server handshake: implicit sequence number zero.
    /\ state' = "OPEN"
    /\ pendingAckSeqNum' = 0
    /\ sendAckTimerRunning' = TRUE
    /\ pendingInput' = NoInput
    /\ UNCHANGED << unackedSent, lastSentSeqNum, nextOutSeqNum, ackReceivedTimerRunning, inSeqNum, inAckNum, inWindowSize >>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
SendBTPPacket ==
    /\ pendingInput = "SendBTPPacket"
    /\ state = "OPEN"
    /\ unackedSent' = unackedSent \cup {nextOutSeqNum}
    /\ lastSentSeqNum' = nextOutSeqNum
    /\ nextOutSeqNum' = (nextOutSeqNum + 1) % CounterModulus
    /\ ackReceivedTimerRunning' = TRUE
    /\ IF pendingAckSeqNum # NoSeqNum
       THEN /\ pendingAckSeqNum' = NoSeqNum
            /\ sendAckTimerRunning' = FALSE
       ELSE /\ pendingAckSeqNum' = pendingAckSeqNum
            /\ sendAckTimerRunning' = sendAckTimerRunning
    /\ pendingInput' = NoInput
    /\ UNCHANGED << state, inSeqNum, inAckNum, inWindowSize >>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
ReceiveBTPPacket ==
    /\ pendingInput = "ReceiveBTPPacket"
    /\ state = "OPEN"
    /\ LET
           isValidAck == (inAckNum # NoSeqNum) /\ (inAckNum \in unackedSent)
           isInvalidAck == (inAckNum # NoSeqNum) /\ (inAckNum \notin unackedSent)
           \* Acknowledgement of a given packet implies acknowledgement of all packets received prior.
           \* Calculated safely using modulo arithmetic avoiding negative numbers.
           ackedSet == { s \in unackedSent : (inAckNum + CounterModulus - s) % CounterModulus < (CounterModulus \div 2) }
           unackedAfterAck == IF isValidAck THEN unackedSent \ ackedSet ELSE unackedSent
       IN
           IF isInvalidAck THEN
               \* If a peer receives an invalid acknowledgement, it SHALL close the session.
               /\ state' = "CLOSED"
               /\ ackReceivedTimerRunning' = FALSE
               /\ sendAckTimerRunning' = FALSE
               /\ pendingAckSeqNum' = NoSeqNum
               /\ unackedSent' = {}
               /\ lastSentSeqNum' = NoSeqNum
               /\ nextOutSeqNum' = 0
           ELSE
               /\ state' = state
               /\ IF inWindowSize <= 2 THEN
                      \* Receive window shrunk to two or fewer slots: immediately send pending ack.
                      /\ pendingAckSeqNum' = NoSeqNum
                      /\ sendAckTimerRunning' = FALSE
                      /\ unackedSent' = unackedAfterAck \cup {nextOutSeqNum}
                      /\ lastSentSeqNum' = nextOutSeqNum
                      /\ nextOutSeqNum' = (nextOutSeqNum + 1) % CounterModulus
                      /\ ackReceivedTimerRunning' = TRUE
                  ELSE
                      \* Record packet sequence number as pending ack and handle timers.
                      /\ pendingAckSeqNum' = inSeqNum
                      /\ sendAckTimerRunning' = TRUE
                      /\ unackedSent' = unackedAfterAck
                      /\ lastSentSeqNum' = lastSentSeqNum
                      /\ nextOutSeqNum' = nextOutSeqNum
                      /\ ackReceivedTimerRunning' =
                             IF isValidAck THEN
                                 (IF inAckNum = lastSentSeqNum THEN FALSE ELSE TRUE)
                             ELSE
                                 ackReceivedTimerRunning
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inSeqNum, inAckNum, inWindowSize >>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
AckReceivedTimerFires ==
    /\ pendingInput = "AckReceivedTimerFires"
    /\ state = "OPEN"
    /\ ackReceivedTimerRunning = TRUE
    \* Timer expires: close the BTP session and report an error.
    /\ state' = "CLOSED"
    /\ ackReceivedTimerRunning' = FALSE
    /\ sendAckTimerRunning' = FALSE
    /\ pendingAckSeqNum' = NoSeqNum
    /\ unackedSent' = {}
    /\ lastSentSeqNum' = NoSeqNum
    /\ nextOutSeqNum' = 0
    /\ pendingInput' = NoInput
    /\ UNCHANGED << inSeqNum, inAckNum, inWindowSize >>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
SendAckTimerFires ==
    /\ pendingInput = "SendAckTimerFires"
    /\ state = "OPEN"
    /\ sendAckTimerRunning = TRUE
    \* Timer expires with pending ack: immediately send that acknowledgement.
    /\ unackedSent' = unackedSent \cup {nextOutSeqNum}
    /\ lastSentSeqNum' = nextOutSeqNum
    /\ nextOutSeqNum' = (nextOutSeqNum + 1) % CounterModulus
    /\ ackReceivedTimerRunning' = TRUE
    /\ sendAckTimerRunning' = FALSE
    /\ pendingAckSeqNum' = NoSeqNum
    /\ pendingInput' = NoInput
    /\ UNCHANGED << state, inSeqNum, inAckNum, inWindowSize >>

Next ==
    \/ \E e \in Inputs, seq \in 0..(CounterModulus-1), ack \in {NoSeqNum} \cup 0..(CounterModulus-1), win \in 0..MaxWindowSize : ReceiveInput(e, seq, ack, win)
    \/ SendBTPPacket
    \/ ReceiveBTPPacket
    \/ SendServerHandshake
    \/ ReceiveServerHandshake
    \/ AckReceivedTimerFires
    \/ SendAckTimerFires

====