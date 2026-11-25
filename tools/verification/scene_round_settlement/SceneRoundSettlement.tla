------------------------ MODULE SceneRoundSettlement ------------------------
EXTENDS Naturals

Rounds == 1..2
TerminalRevision == 2
CurrentRevision(board) == IF board.settled THEN TerminalRevision + 1 ELSE TerminalRevision

VARIABLES disk, live, pending
vars == <<disk, live, pending>>

Init == /\ live = [round |-> 1, settled |-> FALSE, grants |-> 0]
        /\ disk = live /\ pending = FALSE

AcceptRevision(board, revision) ==
    revision = CurrentRevision(board)
    \/ (board.settled /\ revision + 1 = CurrentRevision(board))

ExactRevisionOnly(board, revision) == revision = CurrentRevision(board)

Answer(board, round, revision) ==
    IF round # board.round \/ ~AcceptRevision(board, revision)
    THEN "source changed"
    ELSE IF board.settled THEN "already settled" ELSE "prepare"

Prepare ==
    /\ ~pending /\ Answer(live, live.round, TerminalRevision) = "prepare"
    /\ pending' = TRUE /\ UNCHANGED <<disk, live>>

Adopt ==
    /\ pending /\ pending' = FALSE
    /\ live' = [live EXCEPT !.settled = TRUE, !.grants = @ + 1]
    /\ UNCHANGED disk

Refuse ==
    /\ pending /\ pending' = FALSE /\ UNCHANGED <<disk, live>>

Save ==
    /\ ~pending /\ disk' = live /\ UNCHANGED <<live, pending>>

Load ==
    /\ live' = disk /\ pending' = FALSE /\ UNCHANGED disk

NextRound ==
    /\ ~pending /\ live.settled /\ live.round = 1
    /\ live' = [live EXCEPT !.round = 2, !.settled = FALSE]
    /\ UNCHANGED <<disk, pending>>

Next == Prepare \/ Adopt \/ Refuse \/ Save \/ Load \/ NextRound
Spec == Init /\ [][Next]_vars /\ SF_vars(Prepare) /\ SF_vars(Adopt)

Accounted(board) == board.grants = board.round - 1 + (IF board.settled THEN 1 ELSE 0)
ExactlyOnce == Accounted(disk) /\ Accounted(live)

RetryAcknowledged ==
    \A board \in {live, disk} :
        board.settled =>
            /\ Answer(board, board.round, TerminalRevision) = "already settled"
            /\ Answer(board, board.round, TerminalRevision + 1) = "already settled"

StaleRefused ==
    \A board \in {live, disk}, round \in Rounds, rev \in 0..(TerminalRevision + 2) :
        (round # board.round \/ rev < TerminalRevision \/ rev > CurrentRevision(board))
            => Answer(board, round, rev) = "source changed"

\* Continued retries and opportunities to adopt cannot leave the same round unpaid forever.
EventualSettlement == \A r \in Rounds : ~<>[](live.round = r /\ ~live.settled)
=============================================================================
