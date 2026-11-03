------------------------- MODULE StoryProgression -------------------------
EXTENDS Naturals, FiniteSets, Sequences

CONSTANT SourceCount
Sources == 1..SourceCount
NextPhases == {"NEXT_ADMITTING", "NEXT_ACTIVE", "NEXT_ACKNOWLEDGING"}
Phases == NextPhases \cup {"IDLE", "AUTO", "SKIP", "ACKNOWLEDGING"}
VARIABLES phase, parent, owner, pc, visible, expected, acknowledged,
          applied, blocked, crossedBlocked, staleAdvance, reached
vars == <<phase, parent, owner, pc, visible, expected, acknowledged,
          applied, blocked, crossedBlocked, staleAdvance, reached>>

Init ==
    /\ phase = "IDLE" /\ parent = "IDLE" /\ owner = {}
    /\ pc = "idle" /\ visible = 1 /\ expected = 0
    /\ acknowledged = FALSE /\ applied = [s \in Sources |-> 0]
    /\ blocked \in BOOLEAN /\ crossedBlocked = FALSE /\ staleAdvance = FALSE
    /\ reached = {}

Begin(command, request) ==
    /\ phase = "IDLE"
    /\ command \in {"next", "auto", "skip"}
    /\ request \in Sources
    /\ phase' = CASE command = "next" -> "NEXT_ADMITTING"
                     [] command = "auto" -> "AUTO"
                     [] OTHER -> "SKIP"
    /\ owner' = owner \cup {command}
    /\ pc' = "prepare" /\ expected' = request
    /\ acknowledged' \in IF command = "next" THEN BOOLEAN ELSE {command = "auto"}
    /\ UNCHANGED <<parent, visible, applied, blocked, crossedBlocked,
                   staleAdvance, reached>>

Prepare ==
    /\ pc = "prepare"
    /\ pc' = IF expected = visible /\ visible \in Sources /\ ~blocked
              THEN "run" ELSE "return"
    /\ reached' = IF expected # visible THEN reached \cup {"stale-refusal"}
                   ELSE reached
    /\ UNCHANGED <<phase, parent, owner, visible, expected, acknowledged,
                   applied, blocked, crossedBlocked, staleAdvance>>

BeginAck ==
    /\ phase \in {"IDLE", "AUTO", "SKIP", "NEXT_ADMITTING"}
    /\ IF phase = "NEXT_ADMITTING" THEN pc = "run" /\ ~acknowledged ELSE TRUE
    /\ parent' = phase
    /\ phase' = IF phase = "NEXT_ADMITTING" THEN "NEXT_ACKNOWLEDGING"
                ELSE "ACKNOWLEDGING"
    /\ owner' = IF phase = "IDLE" THEN {"ack"} ELSE owner
    /\ reached' = reached \cup {"ack-from-" \o phase}
    /\ UNCHANGED <<pc, visible, expected, acknowledged, applied, blocked,
                   crossedBlocked, staleAdvance>>

EndAck(success) ==
    /\ phase \in {"ACKNOWLEDGING", "NEXT_ACKNOWLEDGING"}
    /\ phase' = parent /\ parent' = "IDLE"
    /\ owner' = IF parent = "IDLE" THEN {} ELSE owner
    /\ acknowledged' = success
    /\ pc' = IF ~success /\ parent # "IDLE" THEN "return" ELSE pc
    /\ UNCHANGED <<visible, expected, applied, blocked,
                   crossedBlocked, staleAdvance, reached>>

ActivateNext ==
    /\ phase = "NEXT_ADMITTING" /\ pc = "run" /\ acknowledged
    /\ phase' = "NEXT_ACTIVE"
    /\ UNCHANGED <<parent, owner, pc, visible, expected, acknowledged,
                   applied, blocked, crossedBlocked, staleAdvance, reached>>

Advance ==
    /\ phase \in {"NEXT_ADMITTING", "NEXT_ACTIVE", "AUTO", "SKIP"}
    /\ pc = "run" /\ acknowledged /\ visible \in Sources
    /\ expected = visible /\ ~blocked
    /\ applied' = [applied EXCEPT ![expected] = @ + 1]
    /\ visible' = visible + 1 /\ pc' = "return"
    /\ crossedBlocked' = crossedBlocked \/ blocked
    /\ staleAdvance' = staleAdvance \/ (expected # visible)
    /\ reached' = reached \cup {"advance-" \o phase}
    /\ UNCHANGED <<phase, parent, owner, expected, acknowledged, blocked>>

Refuse ==
    /\ phase \in {"NEXT_ADMITTING", "NEXT_ACTIVE", "AUTO", "SKIP"}
    /\ pc = "run" /\ pc' = "return"
    /\ reached' = reached \cup {"ordinary-refusal"}
    /\ UNCHANGED <<phase, parent, owner, visible, expected, acknowledged,
                   applied, blocked, crossedBlocked, staleAdvance>>

FinishNext ==
    /\ phase = "NEXT_ACTIVE" /\ pc = "return"
    /\ phase' = "NEXT_ADMITTING"
    /\ reached' = reached \cup {"next-completion-signals"}
    /\ UNCHANGED <<parent, owner, pc, visible, expected, acknowledged,
                   applied, blocked, crossedBlocked, staleAdvance>>

Return ==
    /\ phase \in {"NEXT_ADMITTING", "AUTO", "SKIP"} /\ pc = "return"
    /\ phase' = "IDLE" /\ owner' = {} /\ pc' = "idle" /\ expected' = 0
    /\ UNCHANGED <<parent, visible, acknowledged, applied, blocked,
                   crossedBlocked, staleAdvance, reached>>

CompetingNext(request) ==
    /\ phase # "IDLE" /\ request \in Sources
    /\ reached' = reached \cup {
          IF phase \in NextPhases THEN
              IF request = expected THEN "next-coalesced" ELSE "next-conflict"
          ELSE "next-busy"}
    /\ UNCHANGED <<phase, parent, owner, pc, visible, expected, acknowledged,
                   applied, blocked, crossedBlocked, staleAdvance>>

BoundaryChange ==
    /\ blocked' = ~blocked
    /\ UNCHANGED <<phase, parent, owner, pc, visible, expected, acknowledged,
                   applied, crossedBlocked, staleAdvance, reached>>

Next == (\E command \in {"next", "auto", "skip"}, request \in Sources : Begin(command, request))
        \/ Prepare \/ BeginAck \/ (\E success \in BOOLEAN : EndAck(success)) \/ ActivateNext \/ Advance
        \/ Refuse \/ FinishNext \/ Return \/ BoundaryChange
        \/ (\E request \in Sources : CompetingNext(request))
Spec == Init /\ [][Next]_vars

TypeOK == /\ phase \in Phases /\ parent \in Phases
          /\ owner \subseteq {"next", "auto", "skip", "ack"}
          /\ pc \in {"idle", "prepare", "run", "return"}
          /\ visible \in 1..(SourceCount + 1) /\ expected \in 0..SourceCount
          /\ acknowledged \in BOOLEAN /\ blocked \in BOOLEAN
          /\ applied \in [Sources -> Nat]
OneOwner == Cardinality(owner) <= 1
PhaseOwner == /\ (phase = "IDLE" <=> owner = {})
              /\ (phase \in NextPhases => owner = {"next"})
              /\ (phase = "AUTO" => owner = {"auto"})
              /\ (phase = "SKIP" => owner = {"skip"})
AckParent == /\ (phase = "ACKNOWLEDGING" => parent \in {"IDLE", "AUTO", "SKIP"})
             /\ (phase = "NEXT_ACKNOWLEDGING" => parent = "NEXT_ADMITTING")
             /\ (phase = "ACKNOWLEDGING" => owner =
                  CASE parent = "IDLE" -> {"ack"}
                       [] parent = "AUTO" -> {"auto"}
                       [] OTHER -> {"skip"})
OncePerSource == \A source \in Sources : applied[source] <= 1
NoBlockedAdvance == ~crossedBlocked
NoStaleAdvance == ~staleAdvance
IdleReleased == phase = "IDLE" => pc = "idle" /\ expected = 0
=============================================================================
