---- MODULE FailSafeContext ----
\* Test fixture, written to look like the LLM-generated modules from the
\* notebook (tla_code_v2 style): snake_case variables, no event mailbox, no
\* Undefined state, `x' = x` frames instead of UNCHANGED, IF/EXCEPT, model
\* values, a TypeInvariant over every variable. It is NOT a faithful Matter
\* model; it exists to exercise decomposition on non-house-style TLA+.
EXTENDS Naturals, FiniteSets

CONSTANTS
  MaxExpiry,
  MaxBreadcrumb,
  MaxFabrics,
  PASE,
  CASE_SESSION

VARIABLES
  fs_armed,
  fs_expiry,
  breadcrumb,
  session_type,
  fabrics,
  cw_open,
  cw_attempts

vars == <<fs_armed, fs_expiry, breadcrumb, session_type, fabrics, cw_open, cw_attempts>>

Sessions == {PASE, CASE_SESSION}

TypeInvariant ==
  /\ fs_armed \in BOOLEAN
  /\ fs_expiry \in 0..MaxExpiry
  /\ breadcrumb \in 0..MaxBreadcrumb
  /\ session_type \in Sessions
  /\ fabrics \in [1..MaxFabrics -> BOOLEAN]
  /\ cw_open \in BOOLEAN
  /\ cw_attempts \in 0..3

Init ==
  /\ fs_armed = FALSE
  /\ fs_expiry = 0
  /\ breadcrumb = 0
  /\ session_type \in Sessions
  /\ fabrics = [i \in 1..MaxFabrics |-> FALSE]
  /\ cw_open = FALSE
  /\ cw_attempts = 0

\* 11.10.7.2: ExpiryLengthSeconds = 0 disarms, otherwise (re)arms.
ArmFailSafe(e) ==
  /\ session_type \in Sessions
  /\ IF e = 0
       THEN /\ fs_armed' = FALSE
            /\ fs_expiry' = 0
       ELSE /\ fs_armed' = TRUE
            /\ fs_expiry' = e
  /\ breadcrumb' = breadcrumb
  /\ session_type' = session_type
  /\ fabrics' = fabrics
  /\ cw_open' = cw_open
  /\ cw_attempts' = cw_attempts

SetBreadcrumb(b) ==
  /\ fs_armed
  /\ breadcrumb' = b
  /\ UNCHANGED <<fs_armed, fs_expiry, session_type, fabrics, cw_open, cw_attempts>>

\* 11.10.7.2.2: on expiry, fail-safe context is cleared.
FailSafeExpire ==
  /\ fs_armed
  /\ fs_armed' = FALSE
  /\ fs_expiry' = 0
  /\ breadcrumb' = 0
  /\ fabrics' = [i \in 1..MaxFabrics |-> FALSE]
  /\ UNCHANGED <<session_type, cw_open, cw_attempts>>

AddFabric(i) ==
  /\ fs_armed
  /\ ~fabrics[i]
  /\ fabrics' = [fabrics EXCEPT ![i] = TRUE]
  /\ UNCHANGED <<fs_armed, fs_expiry, breadcrumb, session_type, cw_open, cw_attempts>>

SessionChange(s) ==
  /\ session_type' = s
  /\ UNCHANGED <<fs_armed, fs_expiry, breadcrumb, fabrics, cw_open, cw_attempts>>

OpenWindow ==
  /\ ~cw_open
  /\ cw_attempts < 3
  /\ cw_open' = TRUE
  /\ cw_attempts' = cw_attempts + 1
  /\ UNCHANGED <<fs_armed, fs_expiry, breadcrumb, session_type, fabrics>>

CloseWindow ==
  /\ cw_open
  /\ cw_open' = FALSE
  /\ cw_attempts' = cw_attempts
  /\ UNCHANGED <<fs_armed, fs_expiry, breadcrumb, session_type, fabrics>>

Next ==
  \/ \E e \in 0..MaxExpiry : ArmFailSafe(e)
  \/ \E b \in 0..MaxBreadcrumb : SetBreadcrumb(b)
  \/ FailSafeExpire
  \/ \E i \in 1..MaxFabrics : AddFabric(i)
  \/ \E s \in Sessions : SessionChange(s)
  \/ OpenWindow
  \/ CloseWindow

Spec == Init /\ [][Next]_vars

\* Deliberately violable properties, so findings exist to compare.
BreadcrumbClearedWhenDisarmed == ~fs_armed => breadcrumb = 0
FabricsOnlyWhileArmed == (\E i \in 1..MaxFabrics : fabrics[i]) => fs_armed
WindowAttemptsBounded == cw_attempts <= 2

====
