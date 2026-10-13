---- MODULE core_11_10_7_2 ----
EXTENDS Naturals

CONSTANTS
    MaxCumulativeFailsafeSeconds,  \* Maximum cumulative failsafe duration (seconds)
    OK,                            \* Success error code
    BusyWithOtherAdmin,            \* Conflict error code
    InitialBreadcrumbValue,        \* 0
    PASE,                          \* Session type constant
    CaseSession,                          \* Session type constant
    InitialPhase,                  \* "initial"
    SetupPhase,                    \* "setup"
    CompletePhase                  \* "complete"

VARIABLES
    state

\* State record fields:
\* now: current time (seconds)
\* failSafeArmed: BOOLEAN
\* failSafeExpiryTime: Nat (absolute expiry time, valid if armed)
\* cumulativeTimerExpiryTime: Nat (absolute expiry time, valid if context exists)
\* accessingFabricIndex: Nat (fabric index associated with fail-safe context)
\* breadcrumb: Nat (uint64)
\* deviceFullyPowered: BOOLEAN
\* commissioningPhase: {InitialPhase, SetupPhase, CompletePhase}
\* commissioningWindowOpen: BOOLEAN
\* networkConfigBackup: any (backup of Networks attribute)
\* addNOCDone: BOOLEAN
\* updateNOCDone: BOOLEAN
\* csrRequestDone: BOOLEAN
\* operationalCredentialsBackup: any (backup for UpdateNOC fabric)
\* nonFabricScopedBackup: any (optional backup)
\* rcacsAddedDuringFailsafe: Set(any) (RCACs added during failsafe)
\* sessions: Set([type: {PASE, CaseSession}, fabricIndex: Nat])
\* fabrics: Set(Nat) (set of fabric indices)
\* lastResponse: {OK, BusyWithOtherAdmin, "none"}

\* Placeholder type for opaque backup fields: in this abstract model, every
\* backup slot is either empty ("" , the sentinel used in Init/Cleanup) or
\* an abstract non-empty marker string (as used in ArmFailSafeCmd Case 3).
\* NOTE: deliberately pure STRING (not STRING \cup {<<>>}) - TLC cannot
\* consistently order/compare a TupleValue against a StringValue when
\* fingerprinting states, so mixing a tuple sentinel into a string-typed
\* field crashes TLC. The empty string "" is already a member of STRING
\* and serves the same "no backup" purpose without that problem.
\* Not a real TLA+ builtin - "ANY" isn't one - so we define it explicitly.
BackupValue == STRING

TypeOK ==
    /\ state \in [ now : Nat,
                   failSafeArmed : BOOLEAN,
                   failSafeExpiryTime : Nat,
                   cumulativeTimerExpiryTime : Nat,
                   accessingFabricIndex : Nat,
                   breadcrumb : Nat,
                   deviceFullyPowered : BOOLEAN,
                   commissioningPhase : {InitialPhase, SetupPhase, CompletePhase},
                   commissioningWindowOpen : BOOLEAN,
                   networkConfigBackup : BackupValue,
                   addNOCDone : BOOLEAN,
                   updateNOCDone : BOOLEAN,
                   csrRequestDone : BOOLEAN,
                   operationalCredentialsBackup : BackupValue,
                   nonFabricScopedBackup : BackupValue,
                   rcacsAddedDuringFailsafe : SUBSET BackupValue,
                   sessions : SUBSET [type: {PASE, CaseSession}, fabricIndex: Nat],
                   fabrics : SUBSET Nat,
                   lastResponse : {OK, BusyWithOtherAdmin, "none"} ]

Init ==
    state = [ now |-> 0,
              failSafeArmed |-> FALSE,
              failSafeExpiryTime |-> 0,
              cumulativeTimerExpiryTime |-> 0,
              accessingFabricIndex |-> 0,
              breadcrumb |-> InitialBreadcrumbValue,
              deviceFullyPowered |-> FALSE,
              commissioningPhase |-> InitialPhase,
              commissioningWindowOpen |-> TRUE,
              networkConfigBackup |-> "",
              addNOCDone |-> FALSE,
              updateNOCDone |-> FALSE,
              csrRequestDone |-> FALSE,
              operationalCredentialsBackup |-> "",
              nonFabricScopedBackup |-> "",
              rcacsAddedDuringFailsafe |-> {},
              sessions |-> {},
              fabrics |-> {},
              lastResponse |-> "none" ]

\* Helper: Cleanup steps on fail-safe expiry
Cleanup(s) ==
    LET newSessions == { sess \in s.sessions : sess.type # PASE } \* Step 2: terminate PASE sessions
        newSessions2 == IF s.addNOCDone \/ s.updateNOCDone
                        THEN { sess \in newSessions : ~(sess.type = CaseSession /\ sess.fabricIndex = s.accessingFabricIndex) }
                        ELSE newSessions
        newFabrics == IF s.addNOCDone
                      THEN s.fabrics \ { s.accessingFabricIndex } \* Step 7: RemoveFabric equivalent
                      ELSE s.fabrics
        newRcacs == { rcac \in s.rcacsAddedDuringFailsafe :
                      \E f \in newFabrics : rcac.referencesFabric = f } \* Step 9: keep only referenced
    IN [ s EXCEPT
         !.failSafeArmed = FALSE,
         !.failSafeExpiryTime = 0,
         !.cumulativeTimerExpiryTime = 0,
         !.accessingFabricIndex = 0,
         !.breadcrumb = InitialBreadcrumbValue,  \* Step 10
         !.networkConfigBackup = "",         \* Step 5: reset (backup cleared)
         !.addNOCDone = FALSE,
         !.updateNOCDone = FALSE,
         !.csrRequestDone = FALSE,
         !.operationalCredentialsBackup = "", \* Step 6: revert (backup cleared)
         !.nonFabricScopedBackup = "",       \* Step 11: optional rollback
         !.rcacsAddedDuringFailsafe = newRcacs,
         !.sessions = newSessions2,
         !.fabrics = newFabrics ]

\* SOURCE: core_11.10.7.2 ArmFailSafe Command - Main command handling
ArmFailSafeCmd(expiryLen, breadcrumbVal, currentFabricIndex, sessionType) ==
    LET s == state
        armed == s.failSafeArmed
        windowOpen == s.commissioningWindowOpen
        isCase == (sessionType = CaseSession)
        fabricMatch == (currentFabricIndex = s.accessingFabricIndex)
    IN
    \* Condition: not armed, window open, CaseSession session -> BusyWithOtherAdmin
    IF ~armed /\ windowOpen /\ isCase
    THEN /\ state' = [ s EXCEPT !.lastResponse = BusyWithOtherAdmin ]
    ELSE
    \* Otherwise, process arm/re-arm/disarm
    CASE
    \* Case 1: ExpiryLengthSeconds = 0, already armed, fabric matches -> immediate expiry (cleanup)
    expiryLen = 0 /\ armed /\ fabricMatch ->
        /\ state' = [ Cleanup(s) EXCEPT !.lastResponse = OK ]
    \* Case 2: ExpiryLengthSeconds = 0, not armed -> success, no side-effects
    [] expiryLen = 0 /\ ~armed ->
        /\ state' = [ s EXCEPT !.lastResponse = OK, !.breadcrumb = breadcrumbVal ]
    \* Case 3: ExpiryLengthSeconds > 0, not armed -> arm for duration, create context
    [] expiryLen > 0 /\ ~armed ->
        /\ state' = [ s EXCEPT
                      !.failSafeArmed = TRUE,
                      !.failSafeExpiryTime = s.now + expiryLen,
                      !.cumulativeTimerExpiryTime = s.now + MaxCumulativeFailsafeSeconds,
                      !.accessingFabricIndex = currentFabricIndex,
                      !.breadcrumb = breadcrumbVal,
                      !.networkConfigBackup = "current_network_config",  \* abstract backup
                      !.addNOCDone = FALSE,
                      !.updateNOCDone = FALSE,
                      !.csrRequestDone = FALSE,
                      !.operationalCredentialsBackup = "",
                      !.nonFabricScopedBackup = "",
                      !.rcacsAddedDuringFailsafe = {},
                      !.lastResponse = OK ]
    \* Case 4: ExpiryLengthSeconds > 0, armed, fabric matches -> re-arm (update fail-safe timer only)
    [] expiryLen > 0 /\ armed /\ fabricMatch ->
        /\ state' = [ s EXCEPT
                      !.failSafeExpiryTime = s.now + expiryLen,
                      !.breadcrumb = breadcrumbVal,
                      !.lastResponse = OK ]
    \* Case 5: Otherwise (armed but fabric mismatch, or other conflict) -> BusyWithOtherAdmin
    [] OTHER ->
        /\ state' = [ s EXCEPT !.lastResponse = BusyWithOtherAdmin ]

\* SOURCE: core_11.10.7.2 Behavior on expiry of Fail-Safe timer
FailSafeTimerExpiry ==
    LET s == state
    IN
    IF s.failSafeArmed /\ s.now >= s.failSafeExpiryTime
    THEN
        \* Determine if cleanup should run based on phase and power state
        IF s.deviceFullyPowered /\ s.commissioningPhase \in {InitialPhase, SetupPhase}
        THEN
            /\ state' = [ Cleanup(s) EXCEPT !.lastResponse = "none" ]
        ELSE IF ~s.deviceFullyPowered /\ s.commissioningPhase = InitialPhase
        THEN
            /\ state' = [ Cleanup(s) EXCEPT !.lastResponse = "none" ]
        ELSE IF ~s.deviceFullyPowered /\ s.commissioningPhase = SetupPhase
        THEN
            \* Spec: cleanup steps SHALL NOT be executed
            /\ state' = [ s EXCEPT
                          !.failSafeArmed = FALSE,
                          !.failSafeExpiryTime = 0,
                          !.cumulativeTimerExpiryTime = 0,
                          !.accessingFabricIndex = 0,
                          !.lastResponse = "none" ]
        ELSE
            \* Phase CompletePhase or other: no cleanup specified, just disarm
            /\ state' = [ s EXCEPT
                          !.failSafeArmed = FALSE,
                          !.failSafeExpiryTime = 0,
                          !.cumulativeTimerExpiryTime = 0,
                          !.accessingFabricIndex = 0,
                          !.lastResponse = "none" ]
    ELSE
        /\ UNCHANGED state

\* SOURCE: core_11.10.7.2 Fail Safe Context - Cumulative timer expiry
CumulativeTimerExpiry ==
    LET s == state
    IN
    IF s.failSafeArmed /\ s.now >= s.cumulativeTimerExpiryTime
    THEN
        /\ state' = [ Cleanup(s) EXCEPT !.lastResponse = "none" ]
    ELSE
        /\ UNCHANGED state

\* SOURCE: core_11.10.7.2 Receiver restart behavior
Restart ==
    /\ state' = [ Cleanup(state) EXCEPT
                  !.now = 0,
                  !.commissioningPhase = InitialPhase,
                  !.commissioningWindowOpen = TRUE,
                  !.deviceFullyPowered = FALSE,
                  !.sessions = {},
                  !.fabrics = {},
                  !.lastResponse = "none" ]

\* Time advancement (for timer expiration reachability)
Tick ==
    /\ state' = [ state EXCEPT !.now = @ + 1 ]

\* NOTE: bounded to small ranges for TLC tractability. The real protocol
\* uses expiryLen in 0..65535 and breadcrumbVal as a full uint64; those
\* full ranges belong in TypeOK (above), not in the enumerated Next
\* transition relation, which only needs a handful of representative
\* values per variable to explore the reachable state space.
Next ==
    \/ \E expiryLen \in 0..2, breadcrumbVal \in {0, 1, 42},
           currentFabricIndex \in 1..2, sessionType \in {PASE, CaseSession}:
           ArmFailSafeCmd(expiryLen, breadcrumbVal, currentFabricIndex, sessionType)
    \/ FailSafeTimerExpiry
    \/ CumulativeTimerExpiry
    \/ Restart
    \/ Tick

Spec == Init /\ [][Next]_state

====