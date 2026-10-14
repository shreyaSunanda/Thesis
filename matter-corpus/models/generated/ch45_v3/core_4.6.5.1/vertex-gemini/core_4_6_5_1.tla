---- MODULE core_4_6_5_1 ----
EXTENDS Naturals

\* The set of peers this node communicates with.
CONSTANTS Peers

\* Message counter space limit to avoid infinite state space. Real value per spec: 2^32.
CONSTANTS CounterModulus

\* The number of messages prior to max_message_counter kept in the bitmap.
CONSTANTS MSG_COUNTER_WINDOW_SIZE

\* Sentinel value for when no event is waiting to be handled.
CONSTANTS NoInput

VARIABLES pendingInput, incomingSender, incomingCounter, max_message_counter, bitmap

Inputs == {"ReceiveMessage"}

\* Helper to compute (a - b) mod CounterModulus without requiring Integers/negative numbers.
ModDiff(a, b) == (a + CounterModulus - b) % CounterModulus

\* TODO: unspecified - exact definition of "logically greater" is not provided in this section.
\* Assuming standard wrapping counter logic: the distance is less than half the modulus.
IsLogicallyGreater(c, max) ==
    c # max /\ ModDiff(c, max) < (CounterModulus \div 2)

\* Check if a counter falls within the message counter window.
InWindow(c, max) ==
    LET offset == ModDiff(max, c) IN
    offset >= 1 /\ offset <= MSG_COUNTER_WINDOW_SIZE

\* Check if a counter has already been received.
IsDuplicate(c, max, bmp) ==
    \/ c = max
    \/ /\ InWindow(c, max)
       /\ ModDiff(max, c) \in bmp

\* Helper for conceptual bitmap shifting when a logically greater message arrives.
ShiftBitmap(bmp, shift) ==
    { o \in 1..MSG_COUNTER_WINDOW_SIZE : 
        o = shift \/ (o > shift /\ (o - shift) \in bmp) }

Init ==
    /\ pendingInput = NoInput
    /\ incomingSender \in Peers
    /\ incomingCounter \in 0..(CounterModulus-1)
    \* TODO: unspecified - initial value of message reception state is not explicitly described.
    /\ max_message_counter = [p \in Peers |-> 0]
    /\ bitmap = [p \in Peers |-> {}]

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ \E sender \in Peers :
           \E counter \in 0..(CounterModulus-1) :
               /\ incomingSender' = sender
               /\ incomingCounter' = counter
    /\ UNCHANGED <<max_message_counter, bitmap>>

\* SOURCE: core_4.6.5.1 Message Reception State
HandleReceiveMessage ==
    /\ pendingInput = "ReceiveMessage"
    /\ LET peer == incomingSender
           counter == incomingCounter
           max == max_message_counter[peer]
           bmp == bitmap[peer]
           
           duplicate == IsDuplicate(counter, max, bmp)
           logicallyGreater == IsLogicallyGreater(counter, max)
           inWindow == InWindow(counter, max)
       IN
           \/ /\ duplicate
              \* Spec says: "determine if ... duplicate". Implies no state change if it is.
              /\ UNCHANGED <<max_message_counter, bitmap>>
           \/ /\ ~duplicate
              /\ logicallyGreater
              /\ LET shift == ModDiff(counter, max)
                     shiftedBmp == ShiftBitmap(bmp, shift)
                 IN
                     /\ max_message_counter' = [max_message_counter EXCEPT ![peer] = counter]
                     /\ bitmap' = [bitmap EXCEPT ![peer] = shiftedBmp]
           \/ /\ ~duplicate
              /\ ~logicallyGreater
              /\ inWindow
              /\ LET offset == ModDiff(max, counter) IN
                     /\ max_message_counter' = max_message_counter
                     /\ bitmap' = [bitmap EXCEPT ![peer] = bmp \cup {offset}]
           \/ /\ ~duplicate
              /\ ~logicallyGreater
              /\ ~inWindow
              \* TODO: unspecified - The spec text does not state what happens when a message 
              \* arrives that is logically older than the maximum counter and falls outside 
              \* the counter window. Assuming it is treated as an invalid duplicate and ignored.
              /\ UNCHANGED <<max_message_counter, bitmap>>
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<incomingSender, incomingCounter>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleReceiveMessage

====