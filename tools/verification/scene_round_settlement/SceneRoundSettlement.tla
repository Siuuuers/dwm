------------------------ MODULE SceneRoundSettlement ------------------------
EXTENDS Naturals

Rounds == 1..2
Tokens == {"A", "B", "C"}
None == "-"
EmptyReceipts == [r \in Rounds |-> None]

VARIABLES disk, live, receipts, pending
vars == <<disk, live, receipts, pending>>

InitialBoard == [round |-> 1, settled |-> FALSE, grants |-> 0]

Init == /\ disk = InitialBoard /\ live = disk
        /\ receipts = EmptyReceipts /\ pending = None

\* Revisions 0 and 1 denote the terminal revision and its settled successor.
Answer(board, history, round, token, revision) ==
    IF \E r \in Rounds : history[r] = token
    THEN IF history[round] = token /\ revision = 0
         THEN <<"original receipt", round, token>> ELSE <<"conflict">>
    ELSE IF round # board.round \/ revision # (IF board.settled THEN 1 ELSE 0)
         THEN <<"source changed">>
         ELSE IF board.settled THEN <<"already settled">> ELSE <<"prepare">>

Prepare ==
    /\ pending = None
    /\ \E token \in Tokens :
          /\ Answer(live, receipts, live.round, token, 0) = <<"prepare">>
          /\ pending' = token
    /\ UNCHANGED <<disk, live, receipts>>

Adopt ==
    /\ pending # None
    /\ live' = [live EXCEPT !.settled = TRUE, !.grants = @ + 1]
    /\ receipts' = [receipts EXCEPT ![live.round] = pending]
    /\ pending' = None /\ UNCHANGED disk

Refuse ==
    /\ pending # None /\ pending' = None
    /\ UNCHANGED <<disk, live, receipts>>

Save ==
    /\ pending = None /\ disk' = live
    /\ UNCHANGED <<live, receipts, pending>>

Load ==
    /\ live' = disk /\ receipts' = EmptyReceipts /\ pending' = None
    /\ UNCHANGED disk

NextRound ==
    /\ pending = None /\ live.settled /\ live.round = 1
    /\ live' = [live EXCEPT !.round = 2, !.settled = FALSE]
    /\ UNCHANGED <<disk, receipts, pending>>

Next == Prepare \/ Adopt \/ Refuse \/ Save \/ Load \/ NextRound
Spec == Init /\ [][Next]_vars /\ SF_vars(Prepare) /\ SF_vars(Adopt)

Accounted(b) == b.grants = b.round - 1 + (IF b.settled THEN 1 ELSE 0)
ExactlyOnce == Accounted(disk) /\ Accounted(live)

LiveReplay ==
    \A r \in Rounds :
        receipts[r] # None =>
            /\ (r < live.round \/ (r = live.round /\ live.settled))
            /\ Answer(live, receipts, r, receipts[r], 0) = <<"original receipt", r, receipts[r]>>
            /\ Answer(live, receipts, r, receipts[r], 1) = <<"conflict">>

SavedSettledRetry == disk.settled =>
    \A t \in Tokens :
        /\ Answer(disk, EmptyReceipts, disk.round, t, 1) = <<"already settled">>
        /\ Answer(disk, EmptyReceipts, disk.round, t, 0) = <<"source changed">>

\* With continued requests and opportunities to commit, an eligible round
\* cannot remain the same terminal, unpaid board forever.
EventualSettlement == \A r \in Rounds : ~<>[](live.round = r /\ ~live.settled)

\* Negative control: historical retry while still in the same live session.
BoardOnlyReplay == (live.round = 2 /\ receipts[1] # None) =>
    Answer(live, EmptyReceipts, 1, receipts[1], 0) = <<"original receipt", 1, receipts[1]>>
=============================================================================
