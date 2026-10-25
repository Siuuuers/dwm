# Current board facts and live retries — 25 October 2026

## Observable outcome

A current Scene player save retains the exact board and frozen BoardSpec, payment
status and settlement status. It does not retain board payment proofs or command
retry history. Load starts a fresh board command session. A later participant failure during
reversible installation restores the old board and its genuine retry acknowledgements.

DesktopBoardState remains the sole current board owner. Every materialized Scene
board uses `{board, spec}` from first Reveal onward. Current validation checks the
actual board, layout, preparation frontier, shell state and frozen recipe using
existing domain validators. It does not rebuild historical payment anchors.
Legacy board contracts retain their existing behavior.

GameState still owns allowance and rewards. First Reveal commits a one-round debit
with the board through the existing checkpoint transaction. Its current reply is
a committed revision acknowledgement; the no-op publication payload is removed
from this path. Rewards and presentation read the frozen recipe, so later selected
difficulty or inventory changes cannot change an existing board's reward tier.

## Player-save and live-backup boundary

The canonical outgoing Scene snapshot builders project the board into player facts.
They omit only board `command_receipts`; all complete live capture and prospective
transaction paths remain unchanged. Explicit player admission refuses an embedded
board retry ledger and installs a fresh empty live ledger. Live rollback uses the
complete capture and reinstalls the genuine prior results.

Narrative checkpoint candidate comparison and Challenge post-commit verification
compare persisted facts to the same owner projection. Before-prepare/before-commit
custody checks still compare full live state. No synthetic payment/admission
records, hidden save slot, or new backup manager is introduced.

## Qualification

Initial qualified local source tree: `7d1fa911e557eaab747450a7005ed4c53bbe2fbc`.
Published runtime candidate: `a9d1c4b9601de003c67f37216b54c7ec845d0d94` (PR91).
Godot 4.6.3 cloud/headless checks pass 459 cases and 31,562 testcase assertions.
The localization fixture has nine additional setup assertions, counted separately.

- Board, replacement, composer, restore, fate and remapper: 200 cases / 1,901 assertions.
- Challenge/checkpoint/reward unit group: 58 / 784.
- Localization group: 178 / 28,178.
- Restore orchestration: 14 / 168.
- Physical round checkpoint: 1 / 91.
- Day/payment integration: 5 / 221.
- Three-process create, Load and settled Load: 3 / 219.

The connected processes use one isolated root and one shell namespace, with
separate process IDs 6, 21 and 36. They check physical Save9 data, no saved retry
ledger, empty restored live ledger, rejection of an authentic pre-Load request,
normal subsequent commands and no repeated rewards. These are headless integration
checks, not physical desktop clicking. The real SaveManager rollback test injects
a later participant failure after real board adoption, then verifies the old
board, genuine acknowledgement, released gate/lock and absence of a success signal.

Independent reviews covered current/legacy callers, frozen-spec consumers,
persisted/live comparisons and rollback ownership. Both public inventories were
regenerated after the final source and test edits. Superseded diagnostics exposed
invalid old frontier fixtures and saved/live comparison assumptions; their failures
are not counted as acceptance. The Challenge/checkpoint grouping retains existing
shutdown resource warnings; its test cases and assertions pass.

Final test/inventory candidate: `107eddbdbc8333461660704b41d78188ed7a9ea2`
(tree `f031387f092eb1ac82d94b4511921dfad884e140`).
Runtime is unchanged from `433dfb0d299cbefb0add1bc551c7925ae11eb230`.
A rendered Supportz fixture compares persisted player facts instead of the full
live retry ledger. Final audit added the required four-field board/lifecycle join
at both current Scene admission boundaries. The connected creator checks rejection
of each mismatch in player and live input; all three connected phases and the
20-case / 480-assertion round/day/rollback group passed again. Earlier connected
reports are retained as diagnostics, not additional test counts.
Windows qualification [40163559243](https://github.com/Siuuuers/dwm/actions/runs/40163559243) passed: 35 jobs succeeded; the incompatible archived timing lane was skipped. Selected reports and connected proofs are in
`linux/` and `windows/`. The final evidence/handoff commit changes no qualified
runtime or test behavior. No performance improvement is claimed.

The prior full run [40162541177](https://github.com/Siuuuers/dwm/actions/runs/40162541177)
passed 33 jobs and skipped the archived timing lane, but failed two stale test
fixtures. Shop custody omitted the board and did not project its fake prepared
save; the backup exit fixture exposed a player snapshot as live capture. Both now
use the actual board owner at the correct boundary. The complete local shop suite
passes 171 cases / 5,542 assertions; backup passes 5 / 69. No runtime checks were
weakened. These reports are additional to the 459-case local group above. The combined
retained local set contains 635 distinct cases and 37,173 testcase assertions,
plus nine localization setup assertions; testcase identities were checked for duplicates.

The retained Windows subset includes desktop (328 cases), shop (171), backup (5),
three fresh-process board phases (3), and the rendered same-day Supportz create/Load
journey (2). The two inspected PNGs show the restored settled board and the shop
after purchase with readable controls. `windows/artifacts.json` identifies each
original archive and its verified SHA-256; `windows/sha256.json` covers retained
files. Original archives were verified before extracting this selected subset.

## Limits and next work

This completes the board's current-fact/payment-proof and player/live-retry split.
The reducer action list remains because BoardPerformance and no-flag metrics use
it; this is not removal of every historical board action. The whole Run save is
not yet compact: reading/admission history, top-level story
receipts and other approved payload omissions remain. Direct caption/held-control,
background and music restoration must preserve choices, outcomes, economy,
inventory and global read/Gallery records without replaying consequences.
Post-durable activation failures still use the existing fatal/input-blocked path;
this change does not claim to redesign all late activation recovery.
Previous development Scene save shapes are refused; no migration is added.
