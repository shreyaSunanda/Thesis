---- MODULE core_4_6_5_1 ----
EXTENDS Naturals

\* Size of the bitmap window
CONSTANTS MSG_COUNTER_WINDOW_SIZE

\* Modulus for message counters. Real value per spec: 2^32.
CONSTANTS CounterModulus

\* Set of valid peer or session identifiers for which state is maintained
CONSTANTS Peers

VARIABLES reception_state

\* TODO: unspecified - exact definition of "logically greater". 
\* Assuming standard circular sequence logic where forward distance < modulus / 2.
IsLogicallyGreater(c, max) ==
    LET dist == (c + CounterModulus - max) % CounterModulus
    IN dist > 0 /\ dist < (CounterModulus \div 2)

InWindow(c, max) ==
    LET dist == (max + CounterModulus - c) % CounterModulus
    IN dist >= 1 /\ dist <= MSG_COUNTER_WINDOW_SIZE

ShiftBitmap(bm, shift) ==
    [i \in 1..MSG_COUNTER_WINDOW_SIZE |->
        IF i < shift THEN FALSE
        ELSE IF i = shift THEN TRUE
        ELSE bm[i - shift]
    ]

InitBitmap == [i \in 1..MSG_COUNTER_WINDOW_SIZE |-> FALSE]

Init ==
    reception_state = [p \in Peers |-> [
        max_message_counter |-> 0,
        bitmap |-> InitBitmap
    ]]

UpdateGreater(p, c, st) ==
    LET shift == (c + CounterModulus - st.max_message_counter) % CounterModulus
        new_bm == ShiftBitmap(st.bitmap, shift)
    IN [reception_state EXCEPT ![p] = [
            max_message_counter |-> c,
            bitmap |-> new_bm
       ]]

UpdateInWindow(p, dist) ==
    [reception_state EXCEPT ![p].bitmap[dist] = TRUE]

\* SOURCE: core_4.6.5.1 Message Reception State
ReceiveMessage(p, c) ==
    LET st == reception_state[p]
        max == st.max_message_counter
        bm == st.bitmap
    IN
        IF IsLogicallyGreater(c, max) THEN
            reception_state' = UpdateGreater(p, c, st)
        ELSE
            IF InWindow(c, max) THEN
                LET dist == (max + CounterModulus - c) % CounterModulus IN
                IF ~bm[dist] THEN
                    reception_state' = UpdateInWindow(p, dist)
                ELSE
                    reception_state' = reception_state
            ELSE
                \* Implicitly older than window, treated as duplicate/ignored
                reception_state' = reception_state

Next ==
    \E p \in Peers, c \in 0..(CounterModulus - 1) :
        ReceiveMessage(p, c)

====