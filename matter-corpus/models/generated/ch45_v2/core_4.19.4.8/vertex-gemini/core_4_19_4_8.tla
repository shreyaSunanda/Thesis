---- MODULE core_4_19_4_8 ----
EXTENDS Naturals, Sequences

\* Sequence number range limit (real value per spec: 255 for 8-bit unsigned integer)
CONSTANTS MaxSeqNum
\* Maximum size of the BTP receive window
CONSTANTS MaxWindowSize
\* Null value indicating no pending acknowledgement
CONSTANTS Null
\* Duration of the acknowledgement-received timer in seconds
CONSTANTS BTP_ACK_TIMEOUT

\* Sentinel for no waiting input
CONSTANTS NoInput
\* The set of all possible events this section can receive
CONSTANTS Inputs

VARIABLES 
    pendingInput,
    sessionState,       \* "OPEN" or "CLOSED"
    ackReceivedTimer,   \* "STOPPED" or "RUNNING"
    sendAckTimer,       \* "STOPPED" or "RUNNING"
    unackedList,        \* Sequence of sent but unacknowledged sequence numbers
    pendingAck,         \* Sequence number of the pending acknowledgement, or Null
    freeSlots           \* Number of free slots in the receive window

\* Helper to drop the first N elements from a sequence
Drop(lst, n) == [j \in 1..(Len(lst) - n) |-> lst[n + j]]

Init == 
    /\ pendingInput = NoInput
    /\ sessionState = "OPEN"
    /\ ackReceivedTimer = "STOPPED"
    /\ sendAckTimer = "STOPPED"
    /\ unackedList = <<>>
    /\ pendingAck = Null
    /\ freeSlots = MaxWindowSize

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ UNCHANGED <<sessionState, ackReceivedTimer, sendAckTimer, unackedList, pendingAck, freeSlots>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
SendBTPPacket ==
    /\ pendingInput = "SendBTPPacket"
    /\ sessionState = "OPEN"
    /\ \E seqNum \in 0..MaxSeqNum:
        /\ Len(unackedList) < MaxWindowSize
        /\ unackedList' = Append(unackedList, seqNum)
        /\ ackReceivedTimer' = "RUNNING"
        /\ sendAckTimer' = "STOPPED"
        /\ pendingAck' = Null
        /\ pendingInput' = NoInput
        /\ UNCHANGED <<sessionState, freeSlots>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
ReceiveBTPPacket ==
    /\ pendingInput = "ReceiveBTPPacket"
    /\ sessionState = "OPEN"
    /\ \E rcvSeqNum \in 0..MaxSeqNum, hasAck \in {TRUE, FALSE}, ackNum \in 0..MaxSeqNum:
        /\ IF hasAck /\ ~\E i \in 1..Len(unackedList) : unackedList[i] = ackNum
           THEN
               \* Invalid acknowledgement
               /\ sessionState' = "CLOSED"
               /\ ackReceivedTimer' = "STOPPED"
               /\ sendAckTimer' = "STOPPED"
               /\ unackedList' = unackedList
               /\ pendingAck' = pendingAck
               /\ freeSlots' = freeSlots
           ELSE
               \* Valid acknowledgement or no acknowledgement
               /\ pendingAck' = rcvSeqNum
               /\ sendAckTimer' = "RUNNING"
               /\ freeSlots' = IF freeSlots > 0 THEN freeSlots - 1 ELSE 0
               /\ sessionState' = sessionState
               /\ IF hasAck
                  THEN
                      /\ unackedList' = Drop(unackedList, CHOOSE i \in 1..Len(unackedList) : unackedList[i] = ackNum)
                      /\ ackReceivedTimer' = IF (CHOOSE i \in 1..Len(unackedList) : unackedList[i] = ackNum) = Len(unackedList)
                                             THEN "STOPPED"
                                             ELSE "RUNNING"
                  ELSE
                      /\ unackedList' = unackedList
                      /\ ackReceivedTimer' = ackReceivedTimer
        /\ pendingInput' = NoInput

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
AckReceivedTimerExpires ==
    /\ pendingInput = NoInput
    /\ sessionState = "OPEN"
    /\ ackReceivedTimer = "RUNNING"
    /\ sessionState' = "CLOSED"
    /\ ackReceivedTimer' = "STOPPED"
    /\ sendAckTimer' = "STOPPED"
    /\ UNCHANGED <<unackedList, pendingAck, freeSlots, pendingInput>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
SendAckTimerExpires ==
    /\ pendingInput = NoInput
    /\ sessionState = "OPEN"
    /\ sendAckTimer = "RUNNING"
    /\ pendingAck # Null
    /\ \E seqNum \in 0..MaxSeqNum:
        /\ Len(unackedList) < MaxWindowSize
        /\ unackedList' = Append(unackedList, seqNum)
        /\ ackReceivedTimer' = "RUNNING"
        /\ sendAckTimer' = "STOPPED"
        /\ pendingAck' = Null
        /\ UNCHANGED <<sessionState, freeSlots, pendingInput>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
SendAckOnWindowShrink ==
    /\ pendingInput = NoInput
    /\ sessionState = "OPEN"
    /\ freeSlots <= 2
    /\ pendingAck # Null
    /\ \E seqNum \in 0..MaxSeqNum:
        /\ Len(unackedList) < MaxWindowSize
        /\ unackedList' = Append(unackedList, seqNum)
        /\ ackReceivedTimer' = "RUNNING"
        /\ sendAckTimer' = "STOPPED"
        /\ pendingAck' = Null
        /\ UNCHANGED <<sessionState, freeSlots, pendingInput>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
SendHandshakeResponse ==
    /\ pendingInput = "SendHandshakeResponse"
    /\ sessionState = "OPEN"
    /\ Len(unackedList) < MaxWindowSize
    /\ unackedList' = Append(unackedList, 0)
    /\ ackReceivedTimer' = "RUNNING"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, sendAckTimer, pendingAck, freeSlots>>

\* SOURCE: core_4.19.4.8 Packet Acknowledgements
ReceiveHandshakeResponse ==
    /\ pendingInput = "ReceiveHandshakeResponse"
    /\ sessionState = "OPEN"
    /\ pendingAck' = 0
    /\ sendAckTimer' = "RUNNING"
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<sessionState, ackReceivedTimer, unackedList, freeSlots>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ SendBTPPacket
    \/ ReceiveBTPPacket
    \/ SendHandshakeResponse
    \/ ReceiveHandshakeResponse
    \/ AckReceivedTimerExpires
    \/ SendAckTimerExpires
    \/ SendAckOnWindowShrink

====