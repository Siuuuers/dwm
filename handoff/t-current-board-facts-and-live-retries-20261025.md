# Current board facts and live retries — 25 October 2026

## Status and next task

PR90 fixes current board payment ownership and the next-day ordinal collision.
It merged as `ca54a79c390271ab8ac0ec6511787ade80bc0319` after passing full
[workflow 40160795575](https://github.com/Siuuuers/dwm/actions/runs/40160795575).

PR91 removes current board payment proofs and saved retry history. Its initial
runtime candidate is `a9d1c4b9601de003c67f37216b54c7ec845d0d94`.
Final test/inventory candidate: `107eddbdbc8333461660704b41d78188ed7a9ea2`
(tree `f031387f092eb1ac82d94b4511921dfad884e140`).
Runtime is unchanged from `433dfb0d299cbefb0add1bc551c7925ae11eb230`.
Cloud qualification [40163559243](https://github.com/Siuuuers/dwm/actions/runs/40163559243) passed: 35 jobs succeeded; the incompatible archived timing lane was skipped.

The final evidence/handoff commit changes no qualified runtime or test behavior.
Check live master and PR metadata before changing code. Do not repeat merged work.
The next independent owner migration is direct current reading restoration.
No new product decision was found to block preserving currently authored behavior.

## Board ownership

DesktopBoardState owns current `round_paid` and `settled_inspection`.
GameState owns daily allowance and rewards. First Reveal commits the debit and
board together. Paid preparation/certification/replacement preserve payment;
dismissal, departure, reset and day renewal clear it.

Every current Scene materialized board retains `{board, spec}` from first Reveal.
The frozen spec supplies presentation and reward difficulty. Later inventory,
pressure or selected difficulty must not reconstruct it. The BoardSpec member
shape and nonce/proof fields are unchanged. Current validation uses board, layout,
shell and preparation owners; it no longer derives payment from historical rows.
Legacy board contracts remain separate. The reducer board still retains its
`actions` list: BoardPerformance and the no-flag register consume it. This change
removes payment proofs and command retry history, not every board action record.
Replacing actions with sufficient current counters requires its own caller audit.

Current first Reveal returns a committed revision acknowledgement. The old
publication callback consumed no payload; current retries now replay their genuine
acknowledgement without payment/publication proof reconstruction. Transaction
custody and existing file-write rollback remain.

## Player data and temporary live backup

`DesktopBoardState.capture()` remains complete live data, including genuine
`command_receipts`. Do not replace it with player facts in rollback callers.

`RunSnapshotSchema.build_scene()` and `build_scene_new_run_candidate()` project
only the outgoing player board through `DesktopBoardState.project_player_state()`.
That projection omits board retry records. It does not replay or semantically
revalidate history. Required current state is validated at admission. Non-null board identity must
match the enclosing lifecycle run, branch, timeline generation and causal day in
both live-input and player-save admission. Null identity remains valid when the
board owner permits it.
`prepare_player_restore_scene()` refuses an embedded retry ledger and prepares a
fresh empty live ledger. `prepare_restore_scene()` remains the complete live path.

`DesktopBoardRestoreParticipant.prepare()` uses player admission; its capture and
rollback retain the full live state. Bootstrap/GameState snapshot providers remain
unchanged. Prospective first-Reveal, replacement, completion and day transactions
still have full data for rollback before the canonical outgoing projection.

Two exact persisted/live comparisons now use the board-owner projection:

- `SaveManagerNarrativeCheckpointPort._scene_route_candidate_valid()`.
- `GameState._validate_scene_challenge_checkpoint()` only in `after_commit`.

Their earlier live-input custody comparisons remain full. Remapping preserves the
missing player ledger without creating synthetic records. Successful Load changes
identity/session and old genuine requests fail. A later participant failure
restores the old board and genuine acknowledged result.

Post-durable native activation failures still retain the existing fatal/input-blocked
behavior. This change does not establish that every late activation failure can
roll back. Preserve safe input blocking during reading migration; do not claim late activation
rollback is already implemented.

## Evidence

- [Payment correction](../evidence/phase_2r/current_board_payment_20261025/README.md)
- [Current board facts](../evidence/phase_2r/current_board_facts_20261025/README.md)

Current-facts local checks pass 459 cases / 31,562 testcase assertions, plus nine
localization setup assertions. The actual SaveManager rollback test uses a real
board participant and an injected later participant failure. The three-process
physical Save9 journey shares one storage root and shell namespace, with distinct
process IDs. It tests absent saved retries, empty restored live retries, authentic
stale-command refusal, new commands and no repeated settlement rewards.
Do not describe headless checks as desktop clicks. No performance improvement is
claimed. The archived timing lane is incompatible with changed development-save
shapes; a skip is not a passing performance result.

The current save contract rejects previous Scene shapes. No migration is added.
Both public inventories must be regenerated after final source/test edits because
caller metadata includes line positions.

The prior full run [40162541177](https://github.com/Siuuuers/dwm/actions/runs/40162541177)
passed 33 jobs and skipped the archived timing lane, but failed two stale test
fixtures. Shop custody omitted the board and did not project its fake prepared
save; the backup exit fixture exposed a player snapshot as live capture. Both now
use the actual board owner at the correct boundary. The complete local shop suite
passes 171 cases / 5,542 assertions; backup passes 5 / 69. No runtime checks were
weakened. These reports are additional to the 459-case local group above.

## Next reading migration: actual inspected dependencies

Follow the approved [Save/Load design](../docs/design/2026-10-25-save-load-validator-audit.md)
and the earlier [decisions and limits](s-current-facts-and-board-settlement-20261025.md).
The entire Run save is not compact yet. Top-level story receipts, reading/admission
history and approved optional metadata remain.

A practical compact locator is an entry ID, a compact content/programme compatibility
marker, and either a stable line ID or held-control marker ID. Preserve necessary
active Challenge/Scene occurrence relationships until their callers are replaced.
Do not invent admission history to satisfy an old validator.

Observed current capabilities:

- `DialogicRuntimeAdapter._install_scene_frontier()` already starts directly at a
  compiled caption. A held control displays its preceding caption and parks the
  control without executing the signal again.
- `_scene_control_predecessor()` currently authenticates that caption through a
  saved ledger. The registered marker's `after_line_id` and compiled predecessor
  provide the authored relationship needed by direct restoration.
- The current compiler permits literal captions, labels, local jumps, return and
  registered controls. It rejects other executable events and text interpolation.
- `DialogicBridge.get_current_scene_art()` selects art by entry ID.
- Current music comes from entry bindings in the audio catalogue: one shared plan,
  no cues, and zero Load anchor. Derive that existing behavior by entry. Per-line
  or elapsed-duration scoring is not currently authored runtime behavior; do not
  claim it already exists or silently add it during save cleanup.

Move these owners together:

1. Give `SoloReadingSession` compact position capture/restore against the installed
   programme. Retain genuine live traversal/retry data separately.
2. Adapt `DialogicRuntimeAdapter` and `DialogicBridge` to reconstruct full caption
   or held control directly, retaining input fencing and native readiness checks.
3. Replace history-dependent current admission across `RunSnapshotSchema`,
   `FrozenRunContext`, `NarrativeRestoreParticipant` and `GameState`. GameState
   currently validates every historical event's caption anchor and derives expected
   choices/outcomes from receipts. Removing only the reading ledger cannot work.
4. Make existing saved choices/outcomes authoritative current facts with required
   ID/value/active-state checks. Audit Challenge occurrence and return/Contacts
   state before removing associated admission identities.
5. Derive audio and required gameplay surface from current DTL/mechanics, then omit
   the approved audio/context/app/ending-source and other retired payload fields
   after replacing their actual consumers.

Acceptance must include a normal caption, held thought control, unfinished active
Challenge and subsequent branch after Load. Preserve full text, art/music, exact
board, economy, inventory, counters, reward claims and global read/Gallery records.
Do not replay purchases, charges or rewards. New choice UI/rules and qualification of both authored Day7 fork endpoints remain
separate content work; do not invent content or add an ending selector.

A fresh session is useful after board qualification: the next change crosses the
reading, story-admission and native-presentation owners, rather than extending the
now-separated board boundary. Start from this record and current master.
