---- MODULE core_4_6_5_1 ----
EXTENDS Naturals

\* The size of the message counter window.
CONSTANTS MSG_COUNTER_WINDOW_SIZE

\* The modulus for the message counter. Real value per spec: 2^32.
CONSTANTS CounterModulus

\* Sentinel: nothing is waiting to be handled
CONSTANTS NoInput

VARIABLES state, pendingInput, msgCounter

Inputs == {"ReceiveMessage"}

Operational == TRUE

\* Helper to compute modulo distance safely without negative numbers under Naturals
Dist(a, b) == (a + CounterModulus - b) % CounterModulus

\* TODO: unspecified - spec uses "logically greater" without defining the exact threshold
\* for wrap-around. Assuming standard half-modulus distance logic.
LogicallyGreater(c, maxC) ==
    LET d == Dist(c, maxC) IN
    d > 0 /\ d < (CounterModulus \div 2)

IsNewInWindow(c, maxC, bmap) ==
    LET d == Dist(maxC, c) IN
    IF d > 0 /\ d <= MSG_COUNTER_WINDOW_SIZE THEN
        bmap[d] = FALSE
    ELSE
        FALSE

ShiftBitmap(oldMax, newMax, oldBitmap) ==
    LET shift == Dist(newMax, oldMax) IN
    [i \in 1..MSG_COUNTER_WINDOW_SIZE |->
        IF i < shift THEN FALSE
        ELSE IF i = shift THEN TRUE
        ELSE oldBitmap[i - shift]]

NewStateForGreater(c, maxC, bmap) ==
    [maxMessageCounter |-> c,
     bitmap |-> ShiftBitmap(maxC, c, bmap)]

NewStateForWindow(c, maxC, oldState) ==
    LET d == Dist(maxC, c) IN
    [oldState EXCEPT !.bitmap[d] = TRUE]

Init ==
    /\ pendingInput = NoInput
    /\ msgCounter = 0
    /\ state = [maxMessageCounter |-> 0,
                bitmap |-> [i \in 1..MSG_COUNTER_WINDOW_SIZE |-> FALSE]]

ReceiveInput(e) ==
    /\ pendingInput = NoInput
    /\ e \in Inputs
    /\ pendingInput' = e
    /\ msgCounter' \in 0..(CounterModulus - 1)
    /\ UNCHANGED <<state>>

\* SOURCE: core_4.6.5.1 Message Reception State
HandleReceiveMessage ==
    /\ pendingInput = "ReceiveMessage"
    /\ LET c == msgCounter
           maxC == state.maxMessageCounter
           bmap == state.bitmap
           isGreater == LogicallyGreater(c, maxC)
           isNewWin == IsNewInWindow(c, maxC, bmap)
       IN
           IF isGreater THEN
               state' = NewStateForGreater(c, maxC, bmap)
           ELSE IF isNewWin THEN
               state' = NewStateForWindow(c, maxC, state)
           ELSE
               \* TODO: unspecified - Spec implies duplicates and out-of-window old messages are ignored.
               state' = state
    /\ pendingInput' = NoInput
    /\ UNCHANGED <<msgCounter>>

Next ==
    \/ (\E e \in Inputs : ReceiveInput(e))
    \/ HandleReceiveMessage

====