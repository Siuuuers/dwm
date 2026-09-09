# Seven-Day Flow Phase 06: Integration and Release Evidence Implementation Plan

> **Owner decision, 2026-09-08:** Eight-master consolidation is cancelled. Retain
> the original scene-oriented DTL arrangement and implement all promised scene
> mechanics with dialogue deferred. References below to 61-to-8 migration,
> eight-only path/count gates, and deleting the original DTL/UID files are
> superseded and must not be executed. Semantic IDs, exact entry resolution,
> safe scene completion, save/load, and promised branches remain required.
> Existing consolidated files are temporary implementation state, not layout
> authority. See the updated base design sections 4.1, 12.1, and 16.4.

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Prove the complete approved flow across generated action sequences, crashes, saves, manifests, scenes, accessibility, and five canonical runs; then retire the legacy 61-file DTL layout and record evidence tied to one commit.

**Architecture:** A compact pure reference model checks domain invariants against production owners. Fault-injected integration tests verify receipt and cross-store recovery. Real-headless Dialogic tests start every public label. Scenario harnesses drive the actual scene/application ports. A final evidence runner records commands, versions, worktree identity, counts, and diagnostics.

**Tech Stack:** Godot 4.6.3, GDScript, GUT, Dialogic headless import/playback, deterministic seeds, PowerShell evidence tooling, Beads preflight, exact-path Git commits.

## Global Constraints

- [ ] Required skills: `code-review-and-quality`, `doubt-driven-development`, `godot-master` with `godot-testing`, `input-handling`, `save-load-systems`, and `dialogue-system`, plus `security-and-hardening`, `deprecation-and-migration`, `superpowers:requesting-code-review`, and `superpowers:verification-before-completion`.
- [ ] Plans 00–05 must be green and committed. This plan fixes integration defects but does not invent new mechanics or content.
- [ ] Evidence is valid only when tied to the tested commit/worktree and fresh command output. Stale logs and an unconditional test never count.
- [ ] Use deterministic seeds and manual frame stepping; no sleeps or unseeded random assertions.
- [ ] Test project integration, not Dialogic internals or exact prose pixels.
- [ ] Legacy DTL deletion is a separate destructive boundary. Obtain explicit authorization, validate exact paths against the checked migration manifest, and use recoverable Git history.
- [ ] No push, release, merge, tag, or Beads parent closure without explicit authority and all gates passing.

---

## Task Interface Map

| Task | Consumes | Produces |
|---:|---|---|
| 1 | Production pure owners/commands | Reference-model and idempotency/save-equivalence properties |
| 2 | Fixed enums/calendars/gates | Exhaustive promotion/pair/ending/day7/board matrices |
| 3 | Bridge, restore, journal | Fail-closed/resume/recovery matrix |
| 4 | Production scenes and ports | Five full-flow plus accessibility smokes |
| 5 | Green runtime and immutable migration inventory | Authorized 61-to-8 physical/config cutover |
| 6 | One tested subject commit | Strict sealed evidence gate and Beads closure evidence |

## Task 1: Build the seven-day reference model and P0 property suite

**Specification:** Sections 7–11, 15.1–15.2.

**Files:**

- Create: `tests/support/SevenDayReferenceModel.gd`
- Create: `tests/property/test_seven_day_model.gd`
- Create: `tests/property/test_receipt_idempotency.gd`
- Create: `tests/property/test_save_restore_equivalence.gd`

- [ ] Implement a deliberately small reference model containing only approved observable state: day/lifecycle, contact action states, committed schedule, relationship axes, challenge slot heads, promotion receipts, Hospital closures, P–L counts/deck, echo obligations, Day 7 intent, and ending step identities/cursor.
- [ ] Generate hundreds of seeded legal and illegal action sequences. After each command compare production output with the model and assert:

  - day remains `1..7` and never becomes 8;
  - invitation/contact state transitions are closed and monotonic;
  - schedule limits/order and Dark-mode blocks hold;
  - only approved challenge/Hospital receipts mutate relationship state;
  - tiers never regress or skip;
  - each pair window counts `0..1`, total `0..2`;
  - terminal resolver returns one legal ordered plan;
  - no command duplicates receipts/effects/history/unlocks.

- [ ] For every causative command, call it twice, restore between duplicates, and reuse its transaction ID with identical and conflicting payloads. Identical reuses return the receipt/no-op; conflict fails without mutation.
- [ ] Snapshot at day start, invitation read, draft/Done, pre-board, mid-board, post-clear, terminal outcome, promotion, Hospital, pair draw/board, every ending step, gallery publication, and run completion. Restore and compare continuation with uninterrupted execution.
- [ ] The sole allowed divergence is post-first-ending fresh pre-challenge entry: it creates a new branch/attempt/board; all other state remains consistent.
- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'seven_day_properties' -LogName 'seven-day-properties.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests/property','-ginclude_subdirs','-gexit')
```

- [ ] Commit:

```text
test(flow): add model-based seven-day invariants
```

## Task 2: Exhaust the fixed domain matrices

**Specification:** Sections 15.1–15.2.

**Files:**

- Create: `tests/scenario/test_promotion_matrix.gd`
- Create: `tests/scenario/test_pl_window_matrix.gd`
- Create: `tests/scenario/test_ending_plan_matrix.gd`
- Create: `tests/scenario/test_day7_terminal_matrix.gd`
- Create: `tests/scenario/test_board_result_matrix.gd`

- [ ] Promotion matrix: friend × every canonical window × attendance/miss/Hospital × affection `3,4,7,8` × starting tier. Assert only fixed third/fourth valves, maximum one step, no relocation/repair.
- [ ] P–L matrix: D2/D6 × solo P/L attendance × group generated/opened/replied/scheduled/Hospital state. Assert Prevented versus four meeting forms, exact counter, visibility/board capability, follow-up flavor, and one stable deck draw.
- [ ] Ending matrix: candidate none/P/L/S × tier × dark `0,1,2,4` × attitude × Dark mode × faint/Special × solo mastery/evidence × pair count/deck/mastery/witnesses. Assert exact steps, order, prerequisites, and causal incompatibility.
- [ ] Day 7 matrix: pending echoes × rounds/actions × Sylvia unlock/read timing × danger/sequela × Done state. Assert mandatory drain, read-before-action, no retrospective Special, no post-Done faint, no Day 8 closure, and Dark-mode precedence.
- [ ] Board matrix: all six relationship outcomes, both Perfect reasons, Perfect-then-Dark, three pair outcomes, special-mine pre-clear rejection, post-clear resume, and exactly one payout.
- [ ] Run the scenario gate and commit:

```text
test(flow): exhaust promotion pair and ending matrices
```

## Task 3: Prove fail-closed narrative and recovery behavior

**Specification:** Sections 12–14, 15.1, 15.3.

**Files:**

- Modify: `tests/smoke_dialogic_timelines.gd`
- Create: `tests/integration/test_dialogic_failure_matrix.gd`
- Create: `tests/integration/test_narrative_resume_matrix.gd`
- Modify: `tests/integration/test_cross_store_recovery.gd`
- Modify: `tests/integration/test_restore_transaction.gd`

- [ ] For every public entry, start through the real bridge with the minimal valid frozen context; assert exact label, own return, matching token completion, no neighboring fallthrough, no unsupported signal, and no mutation when presentation-only.
- [ ] Mutate fixtures one defect at a time: missing selected-locale path/label, missing English path/label, duplicate label, wrong resource type, invalid/extra context field, unknown signal, malformed payload, forbidden source/stage, stale token, identical/conflicting receipt, missing completion callback, old/future manifest fingerprint.
- [ ] Assert exact recovery behavior:

  - locale-only problem -> same entry/label English fallback;
  - English/contract problem -> no start/no state advance, pending event retained;
  - pre-commit interruption -> same entry/stage/transaction resumes;
  - post-commit interruption -> consequence remains and causative choice is not offered again;
  - mismatched completion -> no queue/day/cursor advance;
  - future/unmappable save -> original slot untouched with compatibility result.

- [ ] Crash after every cross-store intent/profile/run/completion write and restart bootstrap. Assert deterministic reconciliation and one Gallery/milestone/cursor result.
- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'dialogic_failure_recovery' -LogName 'dialogic-failure-recovery.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/integration/test_dialogic_failure_matrix.gd,res://tests/integration/test_narrative_resume_matrix.gd,res://tests/integration/test_cross_store_recovery.gd,res://tests/integration/test_restore_transaction.gd','-gexit')
```

- [ ] Commit:

```text
test(dialogic): prove fail-closed playback and recovery
```

## Task 4: Add five full-run and accessibility smokes

**Specification:** Sections 15.3–15.4.

**Files:**

- Create: `tests/scenario/test_full_run_sweet_solo.gd`
- Create: `tests/scenario/test_full_run_observer.gd`
- Create: `tests/scenario/test_full_run_hospital.gd`
- Create: `tests/scenario/test_full_run_priscilla_lavinia.gd`
- Create: `tests/scenario/test_full_run_rehearsal.gd`
- Create: `tests/scene/test_accessible_board_to_ending.gd`
- Modify: `tests/smoke_load_scenes.gd`

- [ ] Drive production ports/scenes through five deterministic runs:

  1. ordinary Sweet solo route;
  2. Sweet P/L route with all four Perfect boards and exactly one Perfect-then-Dark board, plus valid Observer behavior evidence;
  3. multiple Hospital misses and at least one Sylvia care witness;
  4. both P–L windows counted, visible counter-ending, and appropriate witness behavior;
  5. first ending -> old save -> fresh branch board -> exact mid-board restore -> Rehearsal -> ordered exceptional steps.

- [ ] Each run asserts visible semantic entry order, durable receipts, final Gallery identities, unchanged hidden/unseen Gallery entries, and no unexpected diagnostics.
- [ ] Observer smokes use the explicitly test-only evidence-capability fixture because production source cards are outside this structure-only scope. The same fixture must be rejected in final mode; evidence reports Observer mechanics as contract-tested but not production-reachable until approved content registers real opportunities.
- [ ] Accessibility smoke completes a Perfect board and an ending using keyboard/controller actions with focus ring, auto-scroll, flag/chord alternatives, pause/remap/assistance, and screen-reader-accessible controls. Assert classification is unchanged.
- [ ] Scene smoke loads every production scene after bootstrap and checks one configured dependency path; no duplicate Dialogic start or orphan node may remain.
- [ ] Run and commit:

```text
test(flow): add full-run and accessibility smokes
```

## Task 5: Retire the 61 legacy DTL/UID pairs

**Specification:** Sections 12.1, 13, 16.4, 17.

**Files:**

- Delete exactly the 61 old `.dtl` and 61 adjacent `.dtl.uid` paths listed in `data/migrations/dialogic_61_to_8.json`
- Modify: `data/migrations/dialogic_61_to_8.json` to set `cutover_status = deleted_pending_evidence`
- Modify: `schemas/manifests/dialogic-migration.schema.json`
- Modify: `tests/unit/test_dialogic_migration_inventory.gd`
- Modify: `project.godot`
- Modify: `tools/config/ProjectConfigGuard.gd`
- Modify: `tests/unit/tooling/test_project_config_guard.gd`

- [ ] Stop and obtain explicit authorization for this exact destructive boundary. Plan approval alone does not waive the deletion confirmation unless the approval names this task.
- [ ] Before deletion, verify:

  - repository root resolves to the intended workspace;
  - every deletion target is a literal strict descendant of `dialogic/timelines/en/`;
  - every target is tracked, has no staged/unstaged/untracked replacement, matches the approved source blob ID and hash recorded from inventory commit `9e15c38f9f2eee7edc5a399bdde07823b90cfeb4`;
  - all 139 entries resolve only to the eight masters;
  - no production/test/save manifest references an old path;
  - eight master DTLs and UIDs exist and import cleanly.

- [ ] Generate a read-only literal-path deletion preview from the validated manifest, inspect it, then delete those exact 122 files with one reviewed `apply_patch` boundary. Do not use globs, recurse, delete the timeline root, or pass enumerated paths between shells.
- [ ] Run import, structure, bridge-start, config, restore, and full-run gates immediately after deletion.
- [ ] Change the permanent migration test from pre-cutover physical-presence checks to post-cutover proof: retain all immutable source path/blob/hash/disposition records, assert all 122 old paths are absent, and assert every replacement semantic locator exists. Do not skip or delete the inventory test.
- [ ] After old resources are absent, update `[dialogic] directories/dtl_directory` to exactly `day_1` through `day_7` plus `endings`; run editor import and assert it remains exactly eight.
- [ ] Confirm exact physical counts: 8 English `.dtl`, 8 adjacent `.dtl.uid`, no old subdirectory DTL.
- [ ] Do not put the deletion commit SHA inside the deletion commit itself. Record only `deleted_pending_evidence`; Task 6 records the resulting subject commit SHA in the evidence gate and may then advance status in the later evidence commit.
- [ ] Commit:

```text
refactor(dialogic): retire legacy timeline fragments
```

Report that Git history can recover the removed skeletons.

## Task 6: Build and run the final evidence gate

**Specification:** Sections 15–18.

**Files:**

- Create: `tools/evidence/run_seven_day_flow_gate.ps1`
- Create: `schemas/evidence/seven-day-flow-gate.schema.json`
- Create: `tools/evidence/validate_seven_day_flow_gate.gd`
- Create: `tests/unit/tooling/test_seven_day_flow_gate_validator.gd`
- Modify: `tools/testing/Invoke-IsolatedGodot.ps1`
- Modify: `tests/tooling/Test-InvokeIsolatedGodot.ps1`
- Create generated: `evidence/seven_day_flow/gate.json`
- Create generated: `evidence/seven_day_flow/validation_receipt.json`
- Create generated logs only under: `evidence/seven_day_flow/logs/`
- Modify: successor Phase 06 Beads issue through `bd` only

- [ ] Write RED validator tests for missing/extra keys, a stale subject commit, changed/missing/extra logs, wrong log hashes, a dirty subject worktree, and malformed command results. Run only `tests/unit/tooling/test_seven_day_flow_gate_validator.gd`; require the intended schema/validator assertions to fail rather than a parse or dependency error.
- [ ] Extend the isolated-Godot wrapper and its PowerShell contract test so `-EvidenceLogPath` may target only the existing `evidence/phase_2r/logs/` root or the new `evidence/seven_day_flow/logs/` root. All containment, non-reparse, filename, exclusive-append, and production-user-data protections remain unchanged. The gate runner supplies an evidence JSONL path on every invocation, copies the wrapper-reported Godot log bytes into its own logs directory, hashes the copy, and removes only the exact newly created ignored scratch file beneath `.godot/phase2r_logs/` whose filename equals that suite's declared `LogName`. GUID test roots continue to self-clean through the wrapper.
- [ ] Implement the runner, strict schema, validator, wrapper change, and their tests. Run `tests/tooling/Test-InvokeIsolatedGodot.ps1` plus the focused GUT validator test GREEN, run `git diff --check`, stage only the six tooling/schema/test paths, and commit before producing evidence:

```text
test(flow): add seven-day evidence gate tooling
```

- [ ] Require a clean isolated worktree at that tooling commit before sealing. The evidence output directory must be absent or empty; the runner rejects any tracked or nonignored untracked change at start, any subject other than `HEAD`, and any surviving mutation outside its declared evidence output directory. The only temporary exception is the wrapper's exact ignored `.godot/phase2r_logs` file for the active suite, which must not preexist and must be copied, hashed, and removed before the next command.
- [ ] The runner records engine/addon versions, exact subject HEAD, pre-run dirty-path list, plan/spec digests, manifest fingerprints, command lines, exit codes, GUT counts, import result, diagnostics, and bounded third-party exceptions. It writes primary logs first, records every primary log SHA-256, then atomically writes `gate.json`. It next invokes the committed GDScript validator through the isolated wrapper with the dedicated evidence record `logs/validation-command.jsonl`, copies and hashes its Godot log as `logs/seven-day-gate-validate.log`, removes the exact ignored scratch log, and atomically writes `validation_receipt.json` last.
- [ ] The runner itself executes these commands in order; do not run them manually and then fabricate a gate:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'seven_day_import' -LogName 'seven-day-import.log' -GodotArgs @('--editor','--quit-after','1')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'seven_day_all_tests' -LogName 'seven-day-all-tests.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests','-ginclude_subdirs','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'seven_day_dialogic_smoke' -LogName 'seven-day-dialogic-smoke.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/smoke_dialogic_timelines.gd','-gexit')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'seven_day_scene_smoke' -LogName 'seven-day-scene-smoke.log' -GodotArgs @('-s','res://tests/smoke_load_scenes.gd')
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'seven_day_docs' -LogName 'seven-day-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json')
$flowIssues = bd list --spec 'docs/design/2026-08-07-seven-day-dialogic-flow-design.md' --status 'open,in_progress,blocked,deferred,closed' --json --readonly | ConvertFrom-Json
$flowIds = @($flowIssues | ForEach-Object { [string]$_.id })
bd dep cycles --json --readonly
bd lint @flowIds --status all --json --readonly
git diff --check
```

The displayed wrapper calls are the fixed command payloads; the runner adds an `-EvidenceLogPath evidence/seven_day_flow/logs/command-records.jsonl` parameter to each call. The runner filters `$flowIssues` to the exact successor epic title plus the seven exact Phase 00–06 child titles, requires exactly eight unique records, checks their parent/dependency/status contract, then requires `bd dep cycles` to report no cycle and `bd lint` no missing required section for those IDs. The general `bd preflight` command is intentionally excluded because it validates the Beads tool's own Go source tree, not this project's issue graph.

- [ ] From the clean tooling commit, invoke and validate the sealed result against that exact subject commit. Only generated files beneath `evidence/seven_day_flow/` may be dirty after the runner returns:

```powershell
$subjectCommit = (git rev-parse HEAD).Trim()
& .\tools\evidence\run_seven_day_flow_gate.ps1 -SubjectCommit $subjectCommit -OutputDirectory 'evidence/seven_day_flow'
$receipt = Get-Content -Raw -LiteralPath 'evidence/seven_day_flow/validation_receipt.json' | ConvertFrom-Json
if ($receipt.subject_commit -cne $subjectCommit) { throw 'EVIDENCE_SUBJECT_MISMATCH' }
if ((Get-FileHash -Algorithm SHA256 -LiteralPath 'evidence/seven_day_flow/gate.json').Hash.ToLowerInvariant() -cne $receipt.gate_sha256) { throw 'EVIDENCE_GATE_HASH_MISMATCH' }
if ((Get-FileHash -Algorithm SHA256 -LiteralPath 'evidence/seven_day_flow/logs/seven-day-gate-validate.log').Hash.ToLowerInvariant() -cne $receipt.validation_log_sha256) { throw 'EVIDENCE_VALIDATION_LOG_HASH_MISMATCH' }
```

The validator extends `SceneTree`, validates the strict schema, confirms `subject_commit`, recalculates every primary log hash, rejects missing/extra/stale logs, and exits nonzero on any mismatch. The validation receipt has exactly `schema_version`, `subject_commit`, `gate_sha256`, `validation_command_record_sha256`, `validation_log_sha256`, `validator_exit_code`, and `sealed_at_utc`; exit code must be zero. Re-run the runner from an empty evidence directory if any evidence byte changes—never patch a sealed artifact in place. `gate.json` always attests the clean tooling commit; `validation_receipt.json` attests the gate and the otherwise non-self-referential final validator log. The optional evidence commit is the tooling commit's direct child and contains only these sealed generated outputs plus the authorized status update.

- [ ] Run static scans for direct Dialogic starts, direct profile/run bag writes outside owners, retired true IDs, Day 8 live behavior, old DTL paths, arbitrary signal payloads, unsafe load-from-save patterns, test-only result controls in production, and `assert_true(true)` smoke stubs.
- [ ] Inspect logs rather than trusting process exit alone. Any ignored script, parse error, unexpected diagnostic, skipped required test, stale subject, or dirty planned file invalidates the gate.
- [ ] Commit evidence only if evidence sealing is explicitly authorized and the worktree identity matches. Use:

```text
test(flow): record seven-day release evidence
```

- [ ] Update and close only the Phase 06 child after evidence is committed. Close the successor epic only when all seven children are closed and the user accepts the evidence. Do not close `dwm-p2r` or unrelated legacy issues through implication.

## Phase 06 Verification Gate

- [ ] P0 model, exactly-once, save-equivalence, promotion, P–L, ending-order, and faint/echo properties pass.
- [ ] All domain matrices, failure/recovery mutations, five full runs, and accessibility smoke pass.
- [ ] Every one of 139 labels starts/returns through the real bridge.
- [ ] Exactly eight English DTL/UID pairs remain after authorized cutover.
- [ ] Full tests/import/docs/Beads/static scans pass against one identified commit.
- [ ] No final prose was invented and no unrelated dirty path was changed.
- [ ] Evidence—not optimism—supports the final completion report.
