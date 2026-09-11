# Whole-game implementation reconciliation — 2026-09-07

## Main checkout consolidation - 2026-09-09

The owner authorized committing the main-folder work, reconciling it with the
playable checkpoint, making `master` the everyday branch, and pushing GitHub.
Preservation commit `b5bbf1479` retains the original source/design/story work;
`64f567164` retains the verified playable runtime. `master` was already an
ancestor of the preserved design branch, so no separate content merge is needed.

The reconciliation keeps the playable runtime, scene-based DTLs, exact locators,
and current title/witnessed-caption owners. Superseded title/caption scaffolds
and generated save fixtures remain in Git history rather than being reintroduced.
Newer story/canon decisions remain forward authority; unsettled mechanics remain
provisional. Initial portraits are fixed: one in solo scenes, two in group or
twofriends scenes, with expression variations deferred. Optional art bindings
were subsequently implemented on September 9; use [the drop-in art guide](../../art/README.md)
for the current paths and dimensions. Final artwork remains content work.

`temp-artifacts/.gdignore` prevents nested worktrees and recovery copies from
polluting the main Godot/Dialogic index. Machine-specific tool preferences are
preserved in the original checkpoint and local recovery copy, but their changes
are excluded from the shared consolidation. Existing Markdown hard breaks and
inherited skill-source formatting are preserved.

Fresh isolated verification of the combined candidate:
- Eight focused GUT suites: **86/86 tests, 4,564 assertions**, exit 0;
  `master-consolidation-postfix-batch-20260910.log`.
- Scene smoke: **26/26**, exit 0;
  `master-consolidation-scene-smoke-20260910.log`.
- Real startup -> New Account -> desktop -> Minesweeper -> Schedule -> Day 2:
  exit 0, `master-consolidation-playable-startup-final-20260910.log`.
  This harness requires `-- --phase2r-bootstrap-mode=final` after its script.

The initial startup invocation selected intentional test-manual mode. The first
GUT batch also exposed a v5 save-lock fixture missing v6 fields; only that fixture
was repaired, with production validation and assertions unchanged. Its isolated
rerun passed 5/5 tests and 77 assertions before the complete focused batch above.
Log suffixes retain their original names; the checks ran on September 9 UTC.
After moving the main checkout to merge `68667aae8`, its imports were refreshed
and its own 26-scene smoke and real startup-to-Day-2 journey also passed
(`master-main-scene-smoke-20260909.log` and
`master-main-playable-startup-20260909.log`). Initial first-import font-cache
diagnostics did not recur in those post-import checks.
Known Dialogic orphan/NUL diagnostics and the previously recorded save-latency
and richer-audio follow-ups remain; this integration is not a release-certification
claim. Launch the main checkout using [the playtest guide](playable-build.md).

## Owner's clarified outcome

Make the whole game's foundation, structure, and promised mechanics playable
through a simpler implementation. Detailed dialogue is not required now.
Small end-to-end increments are a delivery technique, not a reduced product.
Save/Load, Return, Schedule, warning navigation, and promised outcomes remain in
scope. The owner subsequently cancelled eight-master DTL consolidation; that restoration is committed as `6789102f5`. No promised gameplay branch is cancelled by this record.

This is a bounded orchestration decision under the owner's request to simplify
and reconcile the stopped work. It does not assert runtime completion, approve
new plot material, replace design authority, or authorize a push. Beads retains
task status; this record retains the rationale and implementation direction.

## Current playable checkpoint status - 2026-09-08

Use [the playtest guide](playable-build.md) to launch the integration checkout.
The historical updates below retain their original pending/failure statements;
this section gives the current status without relabeling old evidence.

- Actual seven-day progression, ordered endings, completed-save Login, both
  Hospital paths, care consumption, ordinary replies/Day-7 echo, native Pause,
  Dating Save/Load, and Gallery ending replay have player-flow evidence below.
- `render-desktop-pause-save-exact-0908.log` passes active desktop board -> Home
  Back -> Pause -> manual Save -> confirmed Load, in 20.9855 seconds. Every
  persisted board/spec/phase field matches through the strict canonical writer;
  StringName/typed-array JSON normalization is not a gameplay difference.
- `render-practice-date-replay-0908.log` passes in 29.4119 seconds: actual reached
  Dating draw, private Practice board, Return twice, exact reached Before card
  through public Gallery Replay, drawn card/Next, and title. Run, Profile,
  live-session and Dialogic canonical facts remain unchanged. Its only seeded
  precondition is the clearly labeled prior-ending milestone in isolated data.
- `render-lavinia-ordinary-reply-current-0908.log` passes in 213.9141 seconds:
  actual ordinary reply and drawn outgoing text, two current-day invitation
  rounds, Lavinia's rendered source and focused withholding, durable Observer
  evidence, canonical challenge result, and next-day desktop. The prior failed
  harness omitted terminal New Board between its two rounds; its log remains.
- `dark-profile-terminal-foresight-0908.log` passes 67 tests/835 assertions,
  covering Profile/migration, atomic Dark discovery and startup repair, desktop
  board presentation, terminal Foresight and adjacent performance behavior.
  `profile-access-fixtures-final-0908.log` separately passed all 9 physical
  Dating and 8 startup retry tests; its two other failures are superseded by
  the corrected 67-test run, not represented as an all-green historical batch.
- The ordinary reply shared writer now compensates both Run/journal and exact
  prior Autosave bytes after a failed final reread. Its focused batch passes
  48 tests/796 assertions (`ordinary-compensation-ui-0908.log`). Canonical Dating
  post-result draw acknowledgment and semantic pair rebind pass with care/mastery
  in `dating-post-rebind-care-0908.log` (47 tests/1,103 assertions).
- Save is available from desktop Backup, desktop Pause and stable Dating Pause.
  Empty story resources do not manufacture a saveable narrative-reading frontier.
  Existing witnessed-reading Load admission and compensation remain preserved.

**Committed baseline:** `537cd458c2eae922a3ddff2450e4e5a576ce69b4` connects the
whole seven-day runtime described above. The subsequent Minesweeper increment
has completed its focused checks, actual player journeys and independent review;
the local checkpoint produced from this record contains its final source.

The current increment implements free difficulty/replacement, saved pre-Reveal
flags, production Debug preparation, canonical capabilities/extras, floor display,
>=100 Perfect, and the actual marked-cell non-Perfect choice. It preserves v2
historical outcomes under their old rule version. The owner question on older
versus later threshold wording remains open; absent steering, the later accepted
August-13 amendment governs new play. Finished-board inspection now survives Save/Load through the existing board
owner; New Board dismissal is durable and does not settle or pay the round again.

- `minesweeper-controls-cold-dating-current-0908.log`: 188 tests executed,
  174 passed, 14 failed, 4,332/4,351 assertions. All 111 UI/scoring/capability/
  Pause tests, all three canonical fallback tests, and physical Dating 9/9
  passed. The failures identify two cold day-receipt fixtures and twelve old
  Dating attempt/Profile fixtures. This remains the original failed batch;
  later focused corrections and results are recorded below.
- `desktop-checkpoint-terminal-corrected-0908.log`: paid replacement 21/21,
  desktop Debug 4/4, board fate 34/34 and Panel 23/23 passed. The sole remaining
  terminal assertion compared parsed JSON with native Dictionary types; it was
  corrected to compare every field through the strict canonical writer.
  `certified-cell-focus-terminal-final-0908.log` then passed 64/64 tests and
  1,868 assertions, including the corrected terminal/focus boundary.
- `render-board-controls-authored-size-0908.log` passes the actual rendered
  difficulty/New Board and replacement Save/Load journey in 29.9023 seconds.
  `render-desktop-debug-certified-view-0908.log` passes in 28.9455 seconds;
  its actual Debug certification took 2,230 ms.
- `render-terminal-inspection-audio-current-0908.log` passes in 45.7434 seconds:
  actual completed-board inspection -> Pause manual Save/Load -> exact restored
  board, Register and resources -> New Board -> Load of durable dismissal.
  The earlier terminal probe exposed a real checkpoint defect: the desktop
  adapter wrote an empty audio context, which AudioManager rejected during
  restore. The adapter now captures the retained AudioManager's current semantic
  context, including the context applied by Load. No neutral audio defaults or
  new playback commands are invented. The new focused audio suite initially
  failed to parse because its helper `_input` conflicted with Node's input method;
  the helper is renamed `_snapshot_input`. The corrected
  `desktop-audio-checkpoint-fixed-0908.log` passes 11/11 tests and 192 assertions
  across the real first-Reveal transaction and semantic-audio boundary.
- `dating-fallback-extension-0908.log`: tool exit 0, 1,296 genuinely certified
  canonical solo/pair fallback records; observed maximum 95 deductions within
  the unchanged reserved 512-operation budget. All 1,608 original desktop rows
  match the committed prefix exactly. Certification took 648,370 ms; whole
  isolated process 651.5242 seconds. This was the bounded canonical extension,
  not a repeat of the historical desktop search build.
- The budget manifest's fallback artifact, builder and benchmark-tool source
  hashes were refreshed after that extension. Historical benchmark rows,
  benchmark corpus/device declaration and all numeric budgets remain unchanged;
  the historical benchmark was not rerun or relabeled as current timing evidence.
  The new fallback artifact SHA-256 is
  `64a0d7491ac66a5699697983cd73d1f101b60068f172c2dd05706212ef8ea642`.

- `dating-preparing-history-fixed-0908.log` passes 40/40 tests and 1,601
  assertions: saved post-ending preparation admits its exact existing recipe,
  reuses an already-written attempt, or makes the validated saved-branch
  continuation. No replacement recipe/nonces are generated during recovery.
- `render-dating-debug-mount-fixed-0908.log` passes in 46.4312 seconds: real
  Lucky/Debug entry -> bounded certification -> full Autosave Load -> the exact
  restored shell/layout -> physical Enter on the forced zero cell. Its failing
  predecessor traced a configured Dating scene being overwritten by the pending
  native scene mount. Bootstrap now leaves the exact continuation pending while
  current_scene is null and wakes its existing queue from scene_changed; the
  fixed trace proves native mount precedes the configured replacement.

- `bootstrap-continuation-mounted-fixture-0908.log` passes 13/13 tests and
  156 assertions, including keeping the exact continuation pending until its
  native target is mounted and then retiring a completed save once.
- The marked-cell GPU probes exposed a runtime performance defect before reaching
  the choice. The latest profiled run reached 36 accepted actions in 306,718 ms,
  with a maximum synchronous dispatch of 14,392 ms; it failed its finite budget.
  No marked-cell player-flow pass is claimed from these runs. A read-only 1.47 MB
  retained-save benchmark measured strict parse 1,680,232 us, schema validation
  116,800 us, canonical stringify (including self-check) 2,354,187 us, and emitted
  strict parse 1,737,502 us. Save reads took milliseconds in the live profile;
  repeated document parsing is the dominant measured target. History is retained.

The scalar processing optimization now retains every existing strict rule while
using native spans for ordinary ASCII strings. The identical 1,469,645-byte source
now parses in 593,749 us and canonicalizes (with its complete self-check) in
899,047 us; previous measurements were 1,680,232 and 2,354,187 us respectively.
Its canonical output is byte-equal to the original except its known trailing LF,
SHA-256 `96704512f195bd80aa42b7ee99db72d18f6a90b8f38db9e0f02e00e22e0b8f2a`.
A one-prepare/commit exact-text cache additionally reuses the physically validated
old save, with frame/lease/failure invalidation; actual profile calls fall from
four to three. No recovery entry, physical read/write/flush, or validation rule is
removed. The six-suite first run passed 67/68 tests (952/956 assertions); its sole
new mutation fixture used schema-valid string money. The corrected fixture uses
an explicitly invalid required object and compares uncached/cached rejection.

- `checkpoint-validation-reuse-corrected-0909.log` passes all 8 cache tests and 214 assertions.
  The intervening 7/8 run exposed a fixture read after the deliberate failure had
  invalidated the storage lease; the final assertion checks the fake filesystem's
  actual persisted bytes and retries through the production reconciliation seam.
  No production refusal rule was changed to make that test pass.
- `render-dating-marked-optimized-0909.log` passes in 232.9781 seconds: actual
  saved shell flag -> legal full non-Perfect clear -> clearing-key release gate
  -> actual marked mine activation -> durable Dark receipt -> drawn post scene
  -> full Autosave Load preserving the exact canonical attempt -> next day.
  Its marked choice capture was visually inspected. This completes the finite
  desktop controls/Debug/terminal and Dating Debug/marked player-flow checks.

**Mechanics verification is complete for this increment.** Remaining cumulative
save latency is tracked in `dwm-634`: action 40 still took 5,658 ms synchronous
work, and the next-day save reached 2,942,444 bytes with 68 retained earlier
bundles. The scalar benchmark is a same-byte improvement, not a bounded whole-run
save-size claim. Detailed dialogue, final assets, release certification and the
separate exact-cue audio contract remain follow-up work. This is a mechanically
playable foundation with documented limitations; Beads closure remains scoped to
completed gameplay phases, preserving the separate audio dependency.
Existing 24 Dialogic orphan and Unicode/NUL diagnostics remain visible in tests.
The earlier baseline recovery copy is
`temp-artifacts/runtime-wip-checkpoint-20260908-121719Z` (1,169,458 tracked patch
bytes plus 73 new files); it predates the final Minesweeper increment.

The larger exact-cue/combined-save audio amendment remains a separate follow-up
(`dwm-nqn`), following the orchestration recommendation while the optional scope
question remains unanswered. This does not claim that amendment is implemented:
current audio persists its existing four-field semantic context, not the richer
frozen cue-selection contract. Its Beads dependencies remain visible; gameplay
completion evidence must not silently close that outstanding contract.

## Preserved checkpoints and chosen baseline

The final Minesweeper source recovery copy is `temp-artifacts/runtime-wip-checkpoint-20260908-161640Z` in integration; its manifest and tracked patch are refreshed before the scoped commit.

On 2026-09-08 at 15:35:25 UTC, only `ui00r-authoring` and
`ui00r-authority-candidate` were retired after fresh exact-HEAD/ancestry, full
filesystem, clean tracked/index, exact artifact inventory and archive hash checks.
Their commits remain reachable from integration and both artifacts remain in
`temp-artifacts/worktree-audit-20260908/preserved/` in the root workspace. No merge
or branch deletion occurred. Original stopped worktrees remain preserved.

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

## Phase 04 behavioral gate mapping (2026-09-08)

The authorized simplified integration supersedes the historical Phase 04 file
skeleton, schema numbers and mandatory `CrossStoreTransactionCoordinator`, while
retaining the gate's player-visible and recovery requirements:

| Historical gate | Current implementation boundary |
|---|---|
| Profile v2 / Run and Save v3 migration | Profile v8 and Run/Save v6 validate and migrate through their existing owners; unsupported or corrupt data remains preserved and refused. |
| Irreversible entered boards, effects and stable pair draw | Profile-owned Dating attempts retain immutable entry/materialization and write-once receipts with latest monotonic progress; the finite per-run pair draw survives earlier Run loads. Continue freezes the spec, with first-click-safe layout materialized on the first Reveal under the approved provisional interpretation. |
| Post-milestone replacement and branch mastery | Saved slot heads select exact attempt/progress branches. A fresh pre-entry may create a new attempt; a mid-board load continues the saved layout and progress independently. Mastery follows those heads, including inherited completed heads, without sibling union. |
| Atomic cross-store outcome and crash reconciliation | Existing causal leases serialize Profile preparation/commit and the full Run checkpoint. A failed Run write can leave durable Profile evidence ahead; exact retry or Load reconciliation reapplies that evidence once. Run/restore rollback retains the prior pending retry and uses the storage compensation descriptor where durable bytes changed. A second cross-store journal is not required. |
| Reached signatures, witnesses and Rehearsal isolation | Canonical pre/post draw and ending completion record exact validated signatures; qualifying physical pair completion records witnesses. Practice starts from a reached pre-signature with detached current hidden inputs and private board/receipt state; only validated visited-line history may merge back. |

These are implementation mappings, not a claim that historical gates ran unchanged
or that final verification is complete. Exact source admission, immutable receipts,
failed-write recovery, branch isolation and consequence-free replay remain the
acceptance criteria.

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

## 2026-09-08: scene layout and durable round outcomes

Owner decision: mandatory eight-master DTL consolidation is cancelled. The bounded scene-layout change is locally committed as `6789102f5` (108 files, 1,316 insertions and 4,020 deletions, largely retiring obsolete migration/gate machinery). Retain scene-oriented resources, stable semantic entries, and all promised branches. Detailed dialogue remains deferred. The root design and conflicting plan gates were corrected with exact-file backups in `temp-artifacts/timeline-layout-decision-20260908/`. Runtime locators, aliases, and tooling now use 64 scene resources: the original 61 homes plus three focused group/echo homes. All 137 semantic entry contracts and 19 ending records remain; only physical locators changed. Obsolete master generators and fixed-count gates now stop with an actionable retirement message. Original opening/tutorial DTL resources are restored; their UI flow still needs deliberate integration.

All 19 worktrees were audited against integration checkpoint `ace8ade0b`. No worktree or branch was deleted and no wholesale merge was performed. `ui00r-authoring` and `ui00r-authority-candidate` are retirement candidates: contained history and unique local artifacts copied and hash-verified. Original stopped UI and gameplay worktrees remain preserved. Root evidence: `temp-artifacts/worktree-audit-20260908/README.md`.

Real Minesweeper completion now prepares authored GameState rewards on a detached candidate, commits absolute gameplay/Contacts values under the existing causal lease, and writes the complete result Autosave before clearing the durable pending record. The real paid-start receipt retains difficulty and round identity. A failed full save can be retried through the same player panel; completion replay does not pay or count again. NoFlag uses flag history, including flags later removed. Foresight/3BV and combined qualification reasons still require implementation.

Notification acceptance uses the self-contained no-departure outbox record. It marks the detached result snapshot published, then refreshes persisted Contacts only after the full save and custody release. Published slots can hold a later notification; pending slots cannot be overwritten. The desktop unread indicator reconstructs from Contacts on mount. This never accepts or reads an invitation for the player, and never acknowledges a Hospital destination.

Cold recovery now has an exact complete source Autosave written before round admission. The source checkpoint ID and snapshot hash are bound inside the frozen action candidate. Bootstrap silently restores that exact current Autosave into existing domain owners and journal before replay, without creating a continuation branch or activating a session. Historical slot selection is not part of this preparation. Old pending records without an exact source binding fail safely rather than guessing. Fresh board-fate departure preparation verifies the frozen receipt without rerunning policy. Condition admission reads the prepared action?s resulting stats. Schedule departure uses the retained canonical Schedule controller and its durable departure receipt.

Focused evidence so far: `completion-contracts-verified-0908.log` 89/89; `round-source-checkpoint-green-0908.log` one real loss/save-failure/retry/NoFlag-win/replay test, 104 assertions; `fresh-day-two-owner-recovery-0908.log` fresh production owners recover Day 2 from actual disk, 71 assertions. The scene validator passes 64 resources and 137 entries; all 113 focused scene/manifest/catalog/tooling tests pass. `cold-departure-corrected-0908.log` passes the fresh Day-2 Hospital recovery test with 75 assertions. The subsequent 280-case batch passed all scene suites, condition-source 12/12, consequence state 38/38, and Schedule departure 14/14; the repaired context, policy and board-fate suites pass 20/20, 22/22 and 34/34. The five affected playback/restore files pass 97/97 and the Minesweeper host passes 10/10. `cold-owner-contract-green-0908.log` passes 4/4 with 94 assertions after comparing the complete cold-reloaded value in canonical JSON. The standalone desktop fixture now supplies the required isolated run-configuration owner and restores its scoped global doubles. `desktop-shell-configured-0908.log` reports `DESKTOP_SHELL_PASS`, including geometry, keyboard navigation and unread notice refresh without accepting/reading invitations. The earlier unconfigured run is retained as failed evidence. The earlier legacy outbox key-order compatibility failure is fixed. Existing Dialogic orphan and Unicode NUL diagnostics remain; actual repeated playback in the last batch reports 504 orphans, so these passing cases do not certify leak-free teardown.

The whole-game goal and `dwm-oyo.3` stay active. Remaining connected work includes ordinary Shop condition/persistence, special-Shop source checkpoint binding, Dating physical challenge and witness flow, Hospital destination consumption, ordered endings/Gallery, global pause/exit, opening/tutorial UI integration, and complete seven-day/player-render verification. No whole-game completion is claimed.

The separate runtime WIP is preserved after the DTL commit in `temp-artifacts/runtime-wip-checkpoint-20260908-121938/` (binary tracked patch plus 13 hash-verified new source/test files). This is a recovery copy, not a whole-game completion checkpoint.

Independent scoped review found no additional actionable P1 in exact-source recovery, condition evaluation, canonical Schedule departure receipts, or completed-save/sidecar ordering. This review does not cover the remaining unfinished whole-game features.


### 2026-09-08: canonical Dating physical challenge

Dating now mounts the existing Minesweeper worksheet/grid through the retained presentation port. Solo, group, and deferred two-friends use the canonical 18-by-18 board with 36 ordinary mines. Player reveal/flag/unflag/chord input reaches the existing reducer; no outcome menu is used. Solo mine dispositions reuse the frozen explosion RNG stream. A solo clear stores board truth before the Continue/special-mine choice, applies one exact relationship receipt, and retains `efficiency_gt_100`/`no_flag` qualification reasons. The Dating-only 3BV helper uses the recovered total-click formula. Pair boards apply no relationship effects and record the original run-selected pair-form witness; missed/private encounter visibility does not overwrite that form.

The owner accepts Bootstrap's full-checkpoint callback and rolls back the captured GameState/physical state if a checkpoint fails, including terminal stats and receipts. Completion publishes only after commit. Cached presentation admission re-adopts an exact restored command, retaining board identity/layout/dispositions instead of generating another board. Detailed scene dialogue remains deferred.

Verification: `dating-physical-rerun-0908.log` passed 45/45 cases and 500 assertions, including nine physical-owner cases, mounted real Dating scene mouse input, save-failure rollback, fresh-owner post-clear choice recovery, pair observation, and retained prior-date admission. Existing presentation/scene and exact GameState outcome suites are included in that focused batch. This evidence does not certify all seven-day branch reachability or visual/accessibility behavior at every display setting.

Outstanding persistence law: ordinary snapshots now preserve the active Dating record, but the profile-owned irreversible per-run challenge-slot ledger and its merge over older manual saves are not implemented by this increment. In particular, loading an older same-run slot is not yet proven to preserve the newest entered attempt/terminal choice. The whole-game goal remains active.


### 2026-09-08: durable Shop purchases and actual day transition

All Shop items now use the existing purchase participant and authored EffectResolver, including ordinary consumables, quantities, gift aliases, and the three special items. The participant writes an exact full source Autosave before pending admission; the final full Autosave precedes cleanup and publication. Failed completion saves retain one purchase for retry, and fresh production owners recover both ordinary and special purchases from actual disk without a second charge. No second purchase framework was added.

Evidence: `shop-purchase-regressions-0908.log` 49/49 (719 assertions); `shop-fresh-recovery-green-0908.log` three real purchase/save-failure/fresh-owner cases (193 assertions); `shop-batch-gift-green-0908.log` quantity and public gift-alias case (46 assertions).

The standalone `verify_playable_startup.gd` exercises actual autoload startup, New Account, a visible desktop, Minesweeper worksheet input, real loss settlement, Home, Schedule Done and its public warning dismissal. `playable-contacts-rollover-0908.log` passes that complete Day-1 to Day-2 journey with two rounds restored, finished-round count cleared, and motivation restored. It inspects the hidden board only as a test fixture to select a real mine; production Reveal determines the result.

GameState now supplies one pure daily reset projection shared with legacy advancement; the durable day-resolution candidate saves and silently commits that same projection. Day notifications emit only on an actual transition. Invitation rollover now uses ContactInvitationState's real day-end candidate, queued messages and receipt, rather than empty acknowledgments. The Hospital witness candidate is also included in the saved snapshot, not just live state. A completed Schedule-Done Hospital now prepares provisional recovery in that same candidate. The latter path still needs its physical journey verification.

`day-reset-fixtures-0908.log` passes 82/82 tests and 1,107 assertions across snapshot production, coordinator, committed Schedule, disk durability and Contacts rollover. Current-schema fixture repairs retain real Schedule view ownership and nine restore participants. The focused Contacts case verifies detached preparation, saved/live equality, one next-day follow-up, replay and rollback. Existing Dialogic orphan/Unicode diagnostics remain.

Condition-Hospital adapter, durable stage saves and Bootstrap pump are under integration. Its first focused executed subset passed 7/7 (72 assertions); the next 12-case subset exposed two real identity-parent errors, which remain failed evidence until corrected and rerun. The first full Hospital probe did not trigger because its setup omitted the required carried sequela; the fixture now explicitly includes both condition boundaries. These are not Hospital completion claims.

Remaining whole-game work includes full Hospital and Dating player journeys, unscheduled visible pair routing, irreversible Dating slot history, receipt-based pair ending eligibility, complete Day-7 playback/Gallery/return, global pause/exit, opening/tutorial UI integration, and final visual checks. The original stopped worktrees are still preserved; no Bead or whole-game goal has been closed.


### 2026-09-08: Hospital journey, pair windows and ending continuation

The actual Shop wine purchase now reaches the physical Hospital scene, applies provisional recovery once, advances exactly one day through the shared allocator, retires its saved plan and returns to the desktop. The corrected issuer ancestry uses the existing root plus sorted source identities; the day allocator binds the exact receipt/provenance projection. `hospital-real-root-hash-0908.log` passes four tests/50 assertions including fresh root-store reload and exact retry. `hospital-pair-ancestry-0908.log` passes 21 Hospital/pair tests and 395 assertions. `playable-hospital-hash-fixed-0908.log` and the instrumented `hospital-profile-baseline-0908.log` both pass the actual purchase-to-Day-3 journey.

Visible unscheduled pair windows now derive from the real detached Contacts day-end candidate. Actual issuer-backed accepted sources remain required. The receipt-derived pair-window counter counts distinct eligible Day 2/6 windows, including offscreen windows, without a duplicate mutable counter. Seven visible-pair cases and eight transaction-release gate cases passed in `pair-window-and-release-0908.log`; the remaining provisional-policy fixture assertion was repaired and its case passed in `pair-window-fixture-fixed-0908.log`. The new independent transaction-release signal wakes the condition consumer after the action lease ends without changing fatal-capability signal semantics.

`playable-seven-days-first-0908.log` passes actual public Schedule Done through all daily transitions to Day 7. It does not cover the final ending. The actual Contacts/Schedule/Dating probe reaches Day 2 and its desktop; its last assertion used `RESOLVED` instead of the authoritative `RESOLVED_ATTENDED` literal and is corrected pending rerun. Detailed dialogue remains deferred.

Ordered endings now preserve all semantic steps through physical playback, Profile completion evidence, full-checkpoint retry/rollback and session retirement. `ending-completion-green-0908.log` passes 39 cases/393 assertions across six focused files. Subsequent narrow full-Profile-reset/pair-form-replay corrections still require their rerun. Bootstrap now listens to completed resolution and post-activation `live_session_ready`, fences deferred work with the exact live-session handle, and replays the stored Done command for an unfinished restored plan. Day 6 arriving at Day 7 is explicitly distinguished from completing a Day-7 source plan. Actual final-Day-7 and Login journeys remain to be verified.

The Hospital performance baseline is 222.64 seconds for the whole isolated journey. Its 14 Hospital checkpoint persists total 148.623 seconds: composition 0.013, preparation 17.297, commit 131.313. Repeated text validation plus the separate final reread validation account for 82.49% of that persistence time. The next bounded ablation reuses successful validation for identical text within one commit while preserving physical reads, writes and durability boundaries; no speedup is claimed before a measured rerun.

The latest recovery copy is `temp-artifacts/runtime-wip-checkpoint-20260908-062805Z/`: 460,194-byte binary tracked patch plus 23 hash-verified new source/test files. It predates the final reset filter and upcoming cache change. No runtime commit or push is claimed. Remaining whole-game requirements include the condition-triggered Day-7 destination, irreversible Dating slots/old-save reconciliation, post-milestone replacement/Rehearsal, global pause and opening/tutorial integration, and complete player/render verification. Original stopped worktrees remain preserved; no Bead or whole-game goal is closed.


### 2026-09-08: measured save simplification and physical ending checks

The identical-text validation cache is scoped to one checkpoint commit, records only successful results, and returns detached results. Physical writes, flushes, final rereads, history retention and retry boundaries remain intact. `checkpoint-reuse-fixed-0908.log` passes the five cache/failure-injection regressions. A matched Hospital rerun (`hospital-profile-reuse-0908.log`) took 152.2695 seconds against 222.6405 seconds before the cache: 31.6% less time for this isolated journey. The 14 Hospital persists fell from 148.623 to 85.431 seconds (42.5%); full validations fell from 98 to 56. This is measured on the same fixture, not a general gameplay performance guarantee. A separate compact recovery-history policy remains a pending user preference; the accepted keep-every-stage rule is unchanged.

`playable-seven-day-ending-0908.log` passes actual Schedule controls through the whole week, ordered physical endings, Profile Gallery discovery, session retirement and title. `playable-dating-login-picker-0908.log` passes actual Contacts invitation, Schedule date, physical Dating challenge, Day 2, confirmed Logout, title Login's actual Autosave picker and a fresh live session. With Profile-backed Dating attempt writes newly connected, the same journey passes again in `dating-profile-live-0908.log` (61.7662 seconds). Profile schema 6 now retains irreversible attempts; nine detached ledger/persistence tests passed earlier. The new action/old-save/failure reconciliation integration still needs its targeted failure-injection tests before being treated as complete.

Day 7 condition admission consumes the exact saved action/condition/destination evidence and Sylvia read fact, freezes the ending order, closes Contacts and publishes consumption in the full checkpoint. The normal-mode Hospital Alone physical journey passes in `playable-day7-condition-0908.log`: public daily progression, actual wine purchase under a labeled health/pressure fixture, Alone plus the retained pair coda, Profile completion, no Day 8, session retirement and title. `condition-context-regressions-0908.log` passes 42 tests/408 assertions. All eight condition-ending/continuation cases pass in `day7-terminal-remap-0908.log`; its existing remapper parity failure exposed two missing already-supported Hospital child kinds and has been corrected, pending its focused rerun.

The stronger Day 2 board probe deliberately remains failed evidence (`playable-day2-board-0908.log`): calendar advancement and a playable board passed, but ordinary Schedule advancement reused Day 1's causal-day identity. The shared allocator was configured but never invoked on that path. A focused correction is underway; prior whole-week journey passes did not establish this identity invariant.

Scope correction: current `docs/design/current-ui/new-acc-lifecycle.md` explicitly retires opening/tutorial routes and requires direct-main, explore-first New Account. The actual title probe exercises that route; restoring scene-oriented DTL asset organization does not revive the retired UI. Global Pause is a real production-wiring gap; its existing components are being connected. Completed-run reload also now has a no-replay return path, with its focused regression pending. Post-milestone Dating replacement/Rehearsal and remaining physical pause/restore journeys are still open. No whole-game completion, Bead closure, runtime commit, push or worktree deletion is claimed.


### 2026-09-08: exact Dating Load and ordinary next-day identity

The ordinary Schedule allocator is now invoked at `increment_day`, with the exact durable source and target issuer pair saved alongside the next-day empty board/consequence/Schedule view. `playable-day2-identity-0908.log` passes the previously failing actual board probe: current identity differs from Day 1, ordinal is 1, the board remains playable, and exactly one round is charged. Retry and repeated-Load fixture checks are the next focused validation; older fake fixtures are being brought onto the existing real issuer/start API.

All eleven real-GameState/Profile Dating runtime cases pass in `dating-pause-fixtures-fixed-0908.log`: entry/layout commitments, Profile write failure rollback, Profile-ahead Autosave failure with exact retry, write-once terminal effects, earlier entry guards, silent current-day restoration, command rebinding, shared pair-slot presentation and atomic witness completion. Profile remains ahead on an Autosave failure; only the exact frozen checkpoint may be retried. The first increment covers pre-ending permanence. Post-ending branch-specific replacement progress is a separate active increment, not a completion claim.

`dating-midboard-route-order-0908.log` passes the complete actual journey in 77.8985 seconds: New Account, real invitation/Schedule, first Dating Reveal, mid-board Autosave Load, exact spec/board restoration, resumed real input, terminal outcome, Day 2, confirmed Logout, actual Login picker and fresh Day 2 session. Three concrete integration faults were corrected: SceneRouter now merges its routing metadata with the run-restored gameplay context instead of erasing the challenge; the retained presentation mount cache is scoped to route generation; Bootstrap lets the deferred base scene mount complete before publishing its physical continuation. A restored active Schedule plan retains its historical command ancestry while the shared allocator derives an independently verified continuation source under its persisted restore identity.

`ending-load-hospital-custody-0908.log` passes all 78 tests/776 assertions for completed-ending no-replay return, Hospital wait-custody release, and the corrected remapper parity. Production Pause is composed at final startup. Five of its first six controller cases pass; the remaining failure is an obsolete fake bridge function signature, now corrected. Idle Pause Backup Load/Delete and actual public Pause controls are newly connected and awaiting their focused/player-flow checks. Witnessed narrative Load and cross-route Save remain unsupported, rather than silently advertised as complete. Existing orphan/Unicode diagnostics are still present.

Recovery copy: `temp-artifacts/runtime-wip-checkpoint-20260908-074939Z/` holds a 565,790-byte tracked binary patch and 32 hash-verified new files; tracked bytes were stable during capture. It predates later route ordering/continuation/Pause edits and is explicitly a WIP recovery copy. Original stopped worktrees and the two documented retirement candidates remain untouched. No runtime commit, push, Bead closure or whole-game completion is claimed.


### 2026-09-08: Hospital outcome, completed Login, and branch history

Actual desktop and materialized-Dating Back -> Pause -> Continue -> same scene -> confirmed Return -> title pass with isolated saves (`playable-pause-desktop-0908.log`, `playable-pause-dating-0908.log`). Return now notifies retained narrative/ending adapters of cancellation without reporting completion or failure; this lets a later run reuse them. Both old Backup nine-case suites and the cancellation cases pass within the 69 executed tests/751 assertions in `branch-history-condition-pause-0908.log`. That batch correctly exited 126 because a separate new Profile branch test had a parse error; it was not treated as fully green. The corrected branch suite and actual allocator recovery suite subsequently pass all 12 tests/338 assertions in `profile-branches-day-identity-0908.log`.

A stronger physical Hospital probe found that production Schedule Done never evaluated its end-of-day condition: `commit_outcomes` only emitted an empty completion envelope. The existing outcome stage now prepares detached condition gameplay and Autosaves it before Hospital/date selection. It uses the accepted `carried sequela AND (pressure >= 10 OR health <= 0)` predicate; first-time danger alone does not fabricate Hospital and Day 7 Done bypasses evaluation. Candidate equality, retry, rollback and Day-7 bypass regressions pass. `playable-schedule-hospital-condition-0908.log` passes actual two desktop rounds -> Sylvia invitation -> committed Schedule -> physical Hospital -> one unapplied Sylvia witness -> recovered Day 2 desktop in 60.7488 seconds. The earlier fixture and missing-evaluation failures remain as evidence. Caring-message consumption is the next separate mechanic; Hospital itself does not apply its future relationship effect.

`playable-completed-login-0908.log` passes public Schedule progression through all seven days after the identity/condition fixes, physical ending, title Login's actual completed Autosave picker, no ending replay, unchanged Profile, and a retired title session (232.4752 seconds). Bootstrap also handles a compatible COMPLETED save whose saved route is main/menu through the existing validated retirement seam; its focused real-state test passes.

Profile schema 7 retains original attempts plus independent branch progress, with v6 migration preserving records and receipts. Production Dating now uses the already allocated Load branch, restores selected mid-board progress exactly after the milestone, appends a fresh attempt only at a fresh pre-challenge entry, commits a copied continuation only on its first canonical action, and saves explicit active/canonical pointers in route_context. All 19 real runtime cases pass in `dating-branches-pause-save-mastery-0908.log`, including pre-ending first-lock behavior, sibling divergence, unmaterialized saves, Profile/Autosave failures, inherited heads, and restore rollback. The new six-case canonical mastery helper and affected ending/cap suites pass there too. Mastery uses exact loaded slot heads and preserves Perfect-then-Dark; it cannot supply missing independent Observer behavior evidence. Affection now clamps to the accepted -4..10 and solo dark to 0..4. The combined batch is 57/58, not fully green: one new Pause Save test read the wrong Quick filename; its fixture was corrected to quicksave.json and awaits rerun.

Paused Dating Save is wired through the existing complete checkpoint provider and source-binding checks; its actual Save/Load player probe and corrected regression are pending. Witnessed narrative Pause Load is a separate staged-publication increment. Remaining whole-game work includes Sylvia care consumption, independent Observer evidence acquisition, reached-signature/Gallery replay/Rehearsal, and remaining physical/render verification. No whole-game completion, Bead closure, runtime commit, push or worktree removal is claimed.


### 2026-09-08: paused Save/Load and bounded care recovery

`playable-dating-pause-save-load-mode-0908.log` passes the actual Dating Back -> Backup manual Save -> confirmed Load -> exact playable board journey in 51.3119 seconds, with a fresh session and unchanged Profile. The earlier harness failure selected Load while still in the Save tab; its failed log remains preserved.

The corrected six-suite recovery/care batch (`dating-retry-pause-care-typed-0908.log`) executes 71 tests: 69 pass, with two new witnessed-narrative Load regressions failing. All 20 Dating runtime cases, all 11 Pause controller cases, and all seven Sylvia care cases pass. Dating transaction rollback now restores its local pending checkpoint retry along with GameState, including Profile-ahead failures, without adding another persistent journal. The witnessed Load failure was traced to an internal Restore operation calling an externally gated Pause snapshot; that narrow fix awaits rerun. The 288 reported Dialogic test orphans remain a limitation.

Sylvia care is provisionally readable through the existing Contacts action on the next day. It validates the exact Hospital witness, composes any same-day invitation with the fixed affection/dark/tier/attitude effect, and saves the whole candidate under one lease. Missing copy and failed checkpoint leave the previous state intact; reread and restored replay do not reapply effects. Bootstrap binds the existing main-route checkpoint writer. The real Hospital-to-care journey reached the care message, then its harness incorrectly assumed the pre-entry Sylvia Dating state was non-sparse; the fixture is corrected and its full Load/reread check is pending.

Recovery copy `temp-artifacts/runtime-wip-checkpoint-20260908-090200Z/` preserves a 656,529-byte tracked binary patch plus 40 hash-verified new files. Tracked bytes remained stable during capture. It is a WIP backup, not a runnable-completion claim, and predates the narrow pair-witness fix and pending Observer/replay work. The audit found further accepted-design gaps: independent Observer acquisition, run-stable pair draws at the first counted window, and reached-signature/Gallery replay/Rehearsal. These remain active work; no whole-game or Bead completion, runtime commit, push, or worktree deletion is claimed.


### 2026-09-08: Observer, exact Gallery replay, pair draws and GPU evidence

The actual Sylvia Hospital -> next-day care -> full Autosave Load -> harmless reread passes in `playable-sylvia-care-sparse-load-0908.log` (73.1830 seconds). The corrected native Pause/Load, pair completion witness, and canonical Day-7 tier gates pass 41 tests/1,021 assertions in `native-pause-pair-care-gates-0908.log`. Exploded pair boards retain their attempt completion but no longer grant combination witness credit. Day-7 eligibility uses durable relationship stage, including care's low-affection advancement.

Profile v8 adds three finite stores for Observer evidence, per-run pair draws, and exact reached presentations. Original Dating branches and existing Profile regressions passed after the explicit schema-key correction. Profile v8's six cases, first-count pair draw's eleven cases, and five ending signature/admission cases pass in the integrated log; its seven other failures were retained and corrected. `observer-retry-gallery-alias-0908.log` then passes all 45 tests/969 assertions for actual native ordered endings/Gallery replay, Observer runtime, and mastery. A real misplaced Observer checkpoint guard was moved from read projection to input dispatch; Continue cannot leave the pending evidence checkpoint. The pair Observer command separately requires the actual preceding Sweet completion and durable all-four witnesses, including the promised supplying-fourth-ending case.

The shared pair port obtains a Profile run draw before the first counted window, reuses it across branches/retries, and imports only established legacy form evidence from that exact run. It uses an independent nonce and rejection sampling for unseen-first selection. Ordinary and condition-Hospital paths share the same port; the latter proves its exact coordinator gate token. New Account no longer draws early. Full-week player verification after this change is the next check.

Canonical ending playback now starts the exact registered presentation label, freezes its role-specific signature, and records it only after matching physical completion. Gallery's actual controls select only discovered, reached versions and replay without canonical callbacks. Two historical solo `.observation` IDs are normalized only at read boundaries; storage is preserved. Chinese provisional public titles were repaired and checked after a shell encoding failure. These are provisional audience titles, not final dialogue or artwork. Rehearsal is the remaining active increment: exact reached pre-presentation, current detached hidden inputs, hypothetical legal outcomes, and visited-line-only persistence. It does not claim to reconstruct unrecorded historical promotion state and adds no historical seed store.

GPU evidence now exists: `render-pause-surface-current-0908.log` passes 145 measurements and saves 31 images. English default and Chinese 150% confirmation screenshots were inspected. `render-playable-dating-pause-save-0908.log` passes the actual title/desktop/Dating/Pause/manual Save/Load journey in 52.1163 seconds, captures eight native 1280x720 screens, and preserves the exact restored board. Minesweeper, Dating board and Backup screenshots were inspected. The isolated wrapper was reused with the installed Windows/OpenGL driver; no second rendering wrapper was added. The initial render command's automatic approval service timed out before process creation; its permitted single retry succeeded. Existing Unicode/orphan diagnostics remain; there is no leak-free claim.

Latest WIP recovery copy: `temp-artifacts/runtime-wip-checkpoint-20260908-094244Z/`, 947,630 tracked patch bytes plus 51 hash-verified new files; tracked bytes were stable during capture. It predates subsequent Rehearsal work. No runtime commit, push, worktree removal, Bead closure, or whole-game completion is claimed.


## 2026-09-08: whole-week Gallery, Practice and ordinary correspondence

- GPU player journey `render-wholeweek-gallery-0908.log` passed with terminal 0 in 251.2015 seconds: actual New Account, first board, all seven public Schedule transitions, physical Alone and pair ending steps, title Gallery, exact reached-version replay and unchanged canonical Run/Profile. Four screenshots retained in isolated root `13dbca22-b5c9-49f4-a20d-6d1cc2716f1d`; Gallery inspected. The low-contrast Practice control found there now uses the existing paper ink role.
- Rehearsal owner now uses the production board issuer envelope inside its private namespace. Its five owner tests pass. Gallery hosts actual Practice through explicit GameState/InputManager injection; UI, Gallery, fixed third/fourth promotion valves and Hospital reaction batch passed 26 tests / 1,142 assertions (`practice-valves-hospital-0908.log`). No historical latent-stat ledger was added: hypothetical practice uses detached current hidden inputs plus the reached displayed fields.
- GPU `render-observer-priscilla-round-0908.log` passed in 149.4953 seconds: actual Day 2 board unlock, Priscilla invitation/date, visibly drawn registered source, keyboard-revealed Capture, durable capture evidence, board outcome and next-day return. The initial probe omitted current-day invitation-unlocking rounds and failed its fixture assertion; corrected probe uses the real round flow. Capture alone does not manufacture cross-run verification. Screenshot `10-observer-capture.png` inspected in root `59f6f134-2d26-4c64-a13e-1a91dea4cc76`.
- Compact ordinary correspondence is implemented through existing Contacts history/receipts: six virtual unanswered messages, 18 registered stat-neutral replies, actual selected Label draw, full checkpoint/rollback, and oldest-first echo receipts. Ignored messages create no history or echo. Failed uncommitted replies retain an exact local Retry; leaving the thread cancels only the unsaved command.
- Day 7 uses the original registered fallback identity and an actual staging-card surface. Due Day 6 followups precede echoes; existing read watermarks acknowledge followups. Pure admission guards protect board mutations, Shop preparation, Schedule preparation/cached commit and direct Done admission; presentation-only board resume/suspend and exact prior-day recovery remain available. Restore and New Account are not trapped by narrative admission. The transient prelude owner resumes from saved pending work, not another durable index.
- UI review found destroyed-instance scroll/focus callbacks and a next-card preparation retry gap; both were repaired. `ordinary-retry-runtime-0908.log` passed 34/35 tests, 567/573 assertions: pure 7, command port 4, application guards 7, Contacts UI 3 and surface 6 passed; one full-checkpoint echo retry case remains under diagnosis. The diagnostic reports `reconcile_required`; the fixture was then aligned with production and confirmed a real preparation-stage storage lease defect. The correction and its passing rerun are recorded below.
- Last hash-verified backup before correspondence work: `temp-artifacts/runtime-wip-checkpoint-20260908-101459Z`, 1,060,230 tracked patch bytes and 57 meaningful new files; tracked diff was byte-stable during copying. Later correspondence work is not in that backup.
- Remaining required verification: repair and rerun echo checkpoint retry, real reply?followup?interrupted/resumed Day 7 echo?ending/Gallery, rendered Practice, rendered Lavinia withholding, relevant regression/review and a reviewed runtime checkpoint. The explicit whole-game goal and Beads remain active; no runtime push, worktree deletion, or whole-game closure.


## Current verification update: 2026-09-08

Checkpoint preparation now revalidates durable evidence after an invalidated read lease, while still refusing the failed attempt. Explicit retry succeeds; corrupted artifacts remain preserved and refused. `checkpoint-ordinary-recovery-0908.log` passes 18 tests / 450 assertions, including the actual GameState reply and echo retry cases.

`render-ordinary-echo-week-0908.log` passes the actual seven-day reply -> Day 6 invitation -> ordered Day 7 followup/echo -> interrupted Autosave Load -> once-only acknowledgment -> ending -> Gallery replay journey (terminal 0, 350.1928 seconds). Its screenshots exposed an outgoing-text decoration overlap and focused Next contrast issue; these require the pending UI correction and rendered recheck. Review additionally found that the shared presentation checkpoint caller omitted the durable rollback descriptor after final-reread failure. That narrow compensation fix and canonical Dating post-challenge reached-signature recording are under verification. No whole-game completion is claimed by this journey alone.

Hash-verified recovery copy before those latest corrections: `temp-artifacts/runtime-wip-checkpoint-20260908-105914Z/`, 1,116,683 tracked binary patch bytes plus 69 new source/test/doc files. No original stopped worktree has been removed or merged.
