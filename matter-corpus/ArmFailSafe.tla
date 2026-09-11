---- MODULE ArmFailSafe ----
EXTENDS Naturals

CONSTANTS MaxExpiry, NullValue

VARIABLES state, failSafeExpiry, breadcrumb, pendingMsg

Messages == {"ArmFailSafe", "CommissioningComplete", "FailSafeTimeout"}

Init ==
    /\ state = "Disarmed"
    /\ failSafeExpiry = 0
    /\ breadcrumb = 0
    /\ pendingMsg = NullValue

\* SOURCE: core_11.10.7.2 ArmFailSafe Command
\* Arms (or re-arms, if already Armed) the fail-safe timer.
ArmFailSafeAction(e) ==
    /\ pendingMsg = "ArmFailSafe"
    /\ e \in 1..MaxExpiry
    /\ state \in {"Disarmed", "Armed"}
    /\ state' = "Armed"
    /\ failSafeExpiry' = e
    /\ breadcrumb' = breadcrumb
    /\ pendingMsg' = NullValue

\* SOURCE: core_11.10.7.6 CommissioningComplete Command
CommissioningCompleteAction ==
    /\ pendingMsg = "CommissioningComplete"
    /\ state = "Armed"
    /\ state' = "Disarmed"
    /\ failSafeExpiry' = 0
    /\ pendingMsg' = NullValue
    /\ UNCHANGED breadcrumb

\* SOURCE: core_11.10.7.2 (fail-safe timer expiry teardown)
FailSafeTimeoutAction ==
    /\ pendingMsg = "FailSafeTimeout"
    /\ state = "Armed"
    /\ state' = "Disarmed"
    /\ failSafeExpiry' = 0
    /\ breadcrumb' = 0
    /\ pendingMsg' = NullValue

\* A new message arrives to be processed (bounded nondeterministic injection).
ReceiveMessage(m) ==
    /\ pendingMsg = NullValue
    /\ pendingMsg' = m
    /\ UNCHANGED <<state, failSafeExpiry, breadcrumb>>

\* Catch-all per the thesis methodology (B.4.3): reached when a pending message
\* matches none of the three defined (state, message) transitions above.
\* If TLC finds this reachable, that IS a formal gap — either a real
\* specification ambiguity or a modelling mistake worth reviewing.
UndefinedTransition ==
    /\ pendingMsg # NullValue
    /\ ~ (pendingMsg = "ArmFailSafe" /\ state \in {"Disarmed", "Armed"})
    /\ ~ (pendingMsg = "CommissioningComplete" /\ state = "Armed")
    /\ ~ (pendingMsg = "FailSafeTimeout" /\ state = "Armed")
    /\ state' = "Undefined"
    /\ UNCHANGED <<failSafeExpiry, breadcrumb, pendingMsg>>

Next ==
    \/ \E e \in 1..MaxExpiry : ArmFailSafeAction(e)
    \/ CommissioningCompleteAction
    \/ FailSafeTimeoutAction
    \/ \E m \in Messages : ReceiveMessage(m)
    \/ UndefinedTransition

CommissioningCompleteWithoutFailSafeAction ==
    /\ pendingMsg = "CommissioningComplete"
    /\ state = "Disarmed"
    /\ state' = "Disarmed"
    /\ UNCHANGED <<failSafeExpiry, breadcrumb>>
    /\ pendingMsg' = NullValue


Spec == Init /\ [][Next]_<<state, failSafeExpiry, breadcrumb, pendingMsg>>

\* Invariant checked by TLC (see the .cfg file): should NEVER be violated if
\* this model is complete. If TLC prints a counterexample against this, that
\* trace is your first (toy, hand-made) "gap" artifact.
NeverUndefined == state # "Undefined"

====
