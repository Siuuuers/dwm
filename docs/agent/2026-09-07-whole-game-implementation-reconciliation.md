# Whole-game implementation reconciliation — 2026-09-07

## Owner's clarified outcome

Make the whole game's foundation, structure, and promised mechanics playable
through a simpler implementation. Detailed dialogue is not required now.
Small end-to-end increments are a delivery technique, not a reduced product.
Save/Load, Return, Schedule, warning navigation, and promised outcomes remain in
scope. No DTL amendment or gameplay requirement is cancelled by this record.

This is a bounded orchestration decision under the owner's request to simplify
and reconcile the stopped work. It does not assert runtime completion, approve
new plot material, replace design authority, or authorize a push. Beads retains
task status; this record retains the rationale and implementation direction.

## Preserved checkpoints and chosen baseline

- Integration worktree: `temp-artifacts/worktrees/whole-game-integration`,
  branch `codex/whole-game-integration`, based on UI commit
  `13ce0ac3ff2ed7d4d011be079877cdbfe2ae0523`.
- UI source: `temp-artifacts/worktrees/minesweeper-ui-build`. Its 12 WIP files
  remain there. All 12 and the handoff's 582 preserved files matched their
  recorded SHA-256 values before reconciliation.
- Gameplay source: `C:/Users/glori/Documents/dwm-p2r13-resealed`, commit
  `101fe2b9815af4682d1318d0a7cc2d93442b6e2d`. Task 5 Steps 0/1 are complete;
  its 13 WIP paths are stubs/tests, not implemented Step 2-8 behavior. The
  handoff records 155 expected failures; this was not rerun as a new result.
- Verified copies, binary diffs, handoffs, and original Beads records are in
  the root worktree's `temp-artifacts/slice-checkpoints-20260907-171630/`.
  The directory name predates the clarification; its contents are backups.
- Both branches descend from `1790785b`; neither selected head contains the
  other. The UI branch has 42 later commits, the gameplay branch two.

The original root working tree remains the source of the later story/design
edits. Selecting a runtime base does not revert those edits or make older
design text in this checkout current authority. Consult the root authority map
and reconcile relevant later decisions before changing the affected mechanic.

## Reuse instead of repeating Task 5

| Area | Execution direction |
|---|---|
| Schedule UI | Reuse `scripts/ui/ScheduleApp.gd` and `SchedulePresentationPort`; retain applicable external behavior assertions without rebuilding the old scene tree. |
| Minesweeper UI/controller | Reuse `MinesweeperPresentationPort`, `MinesweeperPanelPort`, and the current app. Extend uncovered promised intents, including Debug where required; do not add a second equivalent controller. |
| Desktop | Reuse current per-app injection, cached windows, and host custody. Avoid rebuilding the external generic stub surface. |
| Warning navigation | Carry the missing ownership/receipt behavior into the current host: failed navigation consumes nothing, success consumes once, and cached state survives. |
| Runtime/save owners | Compare the gameplay branch's two committed changes semantically. Matching snapshot version numbers do not establish compatible fields, participants, or restore ordering. |

The external ledger is retained as requirements and provenance. Its exact old
node map, API layout, step numbers, and commit title do not independently
justify duplicate runtime components on the selected baseline. Public/internal
contracts still consumed by live code must be migrated coherently.

## Execution simplification, with behavior retained

Use existing Beads for bounded behavior changes. Record the intended behavior,
affected owners, and relevant checks once. Run focused tests while changing
that behavior and its affected regressions before the checkpoint. Broaden checks
when interfaces change, integration occurs, or an actual failure warrants it.

Do not require predicted RED counts after each microstep, artificial stub-only
checkpoints, a frozen commit subject, or repeated unchanged visual matrices.
Do not silence a failing correctness check or rebind historical evidence to new
bytes. Preserve old evidence as provenance and identify the tested revision.
Retain visual/accessibility coverage when presentation changes and the full
promised acceptance coverage before claiming overall completion.

## Remaining connected work

1. Reconcile the committed gameplay owner/save differences on this baseline;
   then integrate the preserved live-session WIP with SaveManager as one
   connected change. A fully compensated Load preserves the old session;
   successful replacement and Return reject stale callbacks.
2. Connect production round completion through settlement, outcome dispatch,
   and recovery. `complete_round()` currently has no production call; Bootstrap
   also leaves Hospital/Day-7 destination-outbox dispatch unavailable. Adding
   one call without the downstream owners is not a complete fix.
3. Complete warning navigation and remaining Schedule/Shop/Debug composition
   using the existing presenters and authoritative owners.
4. Verify the promised seven-day, relationship, ending, and persistence paths
   with explicit test data while detailed dialogue remains deferred. Report
   unresolved design-dependent inputs rather than inventing final canon.

Keep one integration writer for shared Bootstrap, GameState, SaveManager, and
snapshot/restore files. Parallel agents can inspect or implement disjoint
surfaces against an agreed interface; one controller runs Godot serially with
isolated user data. No broad branch merge, source deletion, or WIP adoption has
occurred in preparing this record.

## Verification of this reconciliation

The new worktree imported with Godot 4.6.3 through the repository's isolated
user-data runner. Editor import rewrote only `project.godot` among tracked
files; that generated change was restored to the committed baseline. The
existing scene smoke check was then rerun against the restored configuration:
`SMOKE_LOAD_SCENES: PASS (26/26)`, exit 0, with no SCRIPT ERROR/ERROR/WARNING
lines in that final smoke log. This proves scene loading/instantiation only,
not full application startup, save compatibility, rendering, or playability.

Logs are under this worktree's `.godot/phase2r_logs/whole-game-baseline.jsonl`
and `whole-game-baseline-smoke-restored.log`. Generated import/UID files remain
untracked in this isolated worktree. At that baseline-only checkpoint no runtime source change, merge, commit,
push, or player-data operation had been performed. Implementation follows below.


## Implemented save reconciliation

The first implementation increment semantically combines the committed gameplay
save owners from `101fe2b98` with the UI behavior at `13ce0ac3`:

- Snapshot/save document v6 contains captured Dark configuration plus saved
  ScheduleView, condition-Hospital history/plan, and terminal handoff. Both
  conflicting unshipped v5 forms are refused; old Opening/tutorial migration
  and an eight-participant compatibility path are not reintroduced.
- Journal v4 retains the durable initial Autosave/Profile decision and adds
  ScheduleView as the ninth live restore owner. Route dispatch remains the last
  finalization, after all compensable owners succeed.
- Both fresh Load and interrupted-Load reconstruction prepare Schedule from the
  remapped snapshot. The original source identity is explicitly passed to Run;
  it is never inferred from the already-installed destination identity.
- A regression exposed the saved implementation's first-restore rollback leak:
  an unopened Schedule remained open after a later participant failed. The
  existing restore-only installer now accepts the captured null state and
  returns the controller to its unopened state.
- The two independent journal matrices now use fresh fake storage per case.
  Their 36 stage pairs and 72 evidence cases retain their assertions without
  repeatedly validating unrelated earlier cases. No numerical speedup is
  claimed because the earlier full run was interrupted.

This reuses committed gameplay implementations; most added remapper code and
its regression coverage already existed on the gameplay branch. It is not a
new parallel game framework. Independent runtime review found no further
correctness issue in this bounded save change.

The existing `dwm-oyo.3` remains in progress. Neither original WIP set has been
adopted: its 25 file hashes and the UI handoff's 582 preserved file hashes were
rechecked unchanged. Live-session activation, production Schedule presenter
injection, warning navigation, round settlement/outcome dispatch, and whole-game
playability remain outstanding. The retained ScheduleView controller must be
injected into the existing SchedulePresentationPort, never replaced by a second
controller. No DTL feature is cancelled and no Bead is closed by this checkpoint.

Verification uses the isolated runner with disposable user data. Per-run command,
exit code and log path are in `.godot/phase2r_logs/save-reconciliation-tests.jsonl`.
The GUT runs still report 24 Dialogic nodes outside tests as orphans, and engine
startup/shutdown prints Unexpected NUL decoding diagnostics. Passing results do
not certify the full suite, visual presentation, or a playable seven-day game.


Verified results for this increment (243 distinct GUT cases across 18 files):

| Coverage | Passed | Log in `.godot/phase2r_logs/` |
|---|---:|---|
| Combined snapshot/lifecycle, save admission, New Run pair, Schedule rollback | 66/66 | `save-contract-verified.log` |
| Checkpoint retention, restore orchestration, Dark configuration, remapping | 92/92 | `save-recovery-contracts.log` |
| Full continuation journal and frozen New Run materials | 37/37 | `journal-v4-verified.log` |
| Application, desktop, and Schedule foundation bootstrap | 35/35 | `save-bootstrap-verified.log` |
| Real save-to-load participant adapters | 13/13 | `save-production-restore.log` |
| Scene loading/instantiation | 26/26 | `save-scene-smoke.log` |

The later `save-final-integration.log` also passed all 13 adapter cases with
explicit original-source identity assertions, and all eight durable-pair cases
without numeric-type warnings. Its four stale bootstrap-harness failures were
then fixed and all 35 bootstrap cases rerun in `save-bootstrap-verified.log`.
`git diff --check` passes. This is a local source checkpoint; nothing is pushed.


## Continued integration ? provisional mechanics authorized

The user explicitly approved provisional rules on 2026-09-07 while preserving all promised branches. Numeric relationship windows, Hospital recovery tuning, and ending predicates are labeled noncanonical in one pure rules owner. This is implementation authority for playability, not a story-canon decision or DTL cancellation.

Following checkpoint d111f1d80, the preserved GameState session work is integrated with SaveManager ticket freezing and activation after route finalization. The completion-write retry checks preserve one generation; a post-route activation error latches the shared fatal fence. Public save writes now honor that gate. Current focused evidence: 43 New Run/restore cases; 7 session boundary cases and 6 desktop crash cases passed in session-desktop-regressions.log; the corrected v6 desktop fixture/restore-owner suites passed 32/32 in desktop-v6-verified.log. The 7 owner session tests passed before the later live-identity accessor addition. Board generation passed 3/3; Schedule Done passed 4/4; provisional pure rules passed 6/6. Exact runner commands and isolated roots are recorded in .godot/phase2r_logs/live-session-integration.jsonl.

Still in progress: Bootstrap mount/real first reveal; warning navigation scene checks; mutable provisional-rule integration; Shop purchases; actual dating challenges; condition destination consumption; complete Day-7 playback/Gallery/return flow. These are not completion claims. Original stopped worktrees and root story edits remain preserved. Tests still report the pre-existing 24 Dialogic nodes outside test ownership and Unicode NUL diagnostics.

### Live desktop integration checkpoint

The shared live-session owner now fences New Run, Load, retired handles, and public saves during unresolved custody. GameState snapshot capture reads the retained live board/consequence owners rather than stale restored copies. Bootstrap mounts actual Minesweeper generation/presentation and Schedule Done/warnings; Contacts uses replaceable provisional correspondence. Provisional relationship/Hospital/ending eligibility is implemented as an explicitly labeled policy and wired into GameState; full dating and ending presentation are still in progress.

Verification: desktop v6 regression group 32/32; New Run/restore group 43/43; session activation 8/8 including post-route fatal recovery and restored round ordinals; provisional GameState policy 5/5; bootstrap composition 21/21 including real first Reveal, one charge, Autosave, and live snapshot identity. Schedule host 11/11 and correspondence 3/3 passed; Contacts deferred-scroll teardown diagnostics are tracked in the UI follow-up. Whole-game completion is not claimed. Original worktrees remain untouched; no feature or DTL cancellation and no Bead closure.
