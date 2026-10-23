# Phase 2R Lifecycle and Save/Restore Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans` to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace Day 8 and fragile monolithic saves with an idempotent Day 1–7 lifecycle, stable primitive checkpoints, bounded recovery journals, isolated atomic storage, deterministic migrations, and all-or-nothing restore.

**Architecture:** `RunLifecycle` and `DayResolutionPlan` are pure `RefCounted` domain modules behind the `GameState` facade. Task 3 creates the one process-lifetime `ApplicationMutationGate` and one pure `FatalDiagnosticProjector`; `DayResolutionCoordinator` executes the persisted plan through injected state and checkpoint ports and retains only a narrow fatal-latch reference to that same gate. `RunSnapshotSchema` and `CheckpointJournal` are introduced only after lifecycle issue `dwm-p2r.4` closes. `SaveManager` owns save-document I/O and coordinates six concrete restore participants, but never interprets gameplay rules.

**Tech Stack:** Godot 4.6.3 stable Mono (GDScript only), GUT 9.6.1, strict primitive-only JSON, injected `StorageAdapter`, Beads 1.1.0, and the project-local isolated-Godot PowerShell helper.

## Global Constraints

- This plan owns `dwm-p2r.4` and `dwm-p2r.5`.
- `dwm-p2r.4` starts after `.1`; `.5` starts only after both `.3` and `.4` close.
- Every command uses the master `CommandResult` union. A failure contains no partially usable candidate.
- Only `RunLifecycle.complete_active_stage()` may change day, only for the active `increment_day` stage, and only from Days 1–6.
- Current validation accepts day `1..7`; Day 8 exists only in migration fixtures and negative tests.
- Canonical saves are JSON. `store_var`, `get_var`, object loading, `Resource`, `Callable`, executable objects, and caller-supplied paths are forbidden.
- Generic scene-transition saves defer to the next stable checkpoint. Minesweeper-board save input is silently ignored and never deferred.
- `checkpoint_kind` is the only checkpoint-kind field or parameter name. Its closed allowlist includes `line`; semantic-anchor retention is a separate classification and never rejects a valid line checkpoint.
- New Game is a persistence transaction: a fresh Day-1 run candidate, a reset journal containing only sequence-1 `day_start`, and the Day-start autosave either all commit or all roll back. Profile state is never part of that reset.
- Restore and New Game hold the application mutation/input gate across every awaited apply, finalize, and rollback operation. No external mutation command or user-input callback executes against an intermediate participant state.
- Task 3 creates and exhaustively unit-tests the sole `ApplicationMutationGate` plus the sole `FatalDiagnosticProjector`, implements `GameState.configure_mutation_gate()`, and injects that same gate object into `DayResolutionCoordinator.configure_fatal_latch()`. Every Plan03 fatal call projects raw diagnostics through that helper before latching; no owner passes a raw CommandResult tree to the gate. Task 6 implements the corresponding SaveManager common seam and injects the same gate object into `SaveManagerCheckpointPort.configure_fatal_latch()`. Task 7 only installs the already-created gate class in final bootstrap, adds SceneRouter's common seam, and proves all manager/service references have one object identity; it MUST NOT create a replacement gate class, projector, fatal Boolean, or second latch.
- Every Godot process MUST use `tools/testing/Invoke-IsolatedGodot.ps1`; direct Godot invocations are forbidden after `.1` creates the helper.
- A RED test for a not-yet-created script checks `ResourceLoader.exists()` and loads dynamically; it never `preload`s or type-references the absent script, so the expected failure is an assertion rather than a parse error.
- No test constructs or opens a production `user://` save/profile path.
- Runtime edits require approval of the master plan. Every commit block is a proposed boundary and additionally requires explicit commit authority.
- `implementation_authorized: true` as of 2026-07-18 for the exact task-scoped runtime, test, scene, `project.godot`, and isolated-storage changes below after blockers close. Commit mutations remain separately unauthorized.
- Plan 01 Task 1 creates, behavior-tests, and commits `tools/git/Invoke-ExactPathCommit.ps1` plus both fixtures. Task 1 below proves those three prerequisite paths are unchanged tracked `100644` HEAD blobs and reruns the committed fixtures; it neither recreates nor recommits them. All seven commit boundaries invoke that one helper with exact A/M/D maps, explicit present-only optional UIDs, a mandatory nonempty `ExpectedHead` bound to the current/prerequisite parent identity, and the two accumulated tracked Beads journals left unstaged. The helper enforces `DWM_COMMIT_AUTHORIZED=1`, exact parent identity, regular-blob raw modes, no partial/rename/copy/type/unmerged status, nonempty exact staging, sole direct-child ancestry, and exact committed revalidation.

---

## Task 1: Inventory and freeze the GameState public surface

**Beads:** `dwm-p2r.4`

**Files:**

- Create: `tools/runtime/PublicSurfaceInventory.gd`
- Create: `tools/runtime/generate_public_surface_inventory.gd`
- Consume unchanged from Plan 01 Task 1: `tools/git/Invoke-ExactPathCommit.ps1`
- Consume unchanged from Plan 01 Task 1: `tests/tooling/test_invoke_exact_path_commit.ps1`
- Consume unchanged from Plan 01 Task 1: `tests/unit/tooling/test_exact_path_commit.gd`
- Create: `tests/unit/tooling/test_public_surface_inventory.gd`
- Create: `evidence/phase_2r/runtime/game_state_required_surface.json`
- Generate: `evidence/phase_2r/runtime/game_state_surface.json`
- Modify later in this issue: `autoload/GameState.gd`

**Interfaces:**

- Consumes: `PublicSurfaceInventory.build(script_path: String, search_roots: Array[String], required_symbols: Dictionary) -> Dictionary`; current `autoload/GameState.gd`; repository call sites; master `CommandResult`; and the unchanged Plan 01 Task 1 exact-path helper plus its two committed fixtures.
- Produces: a deterministic inventory record for every public signal, constant, property, and non-underscore method; a complete `retain|replace|deprecate|remove` disposition for symbols owned by this plan; a CLI generator whose output path must be under `evidence/phase_2r/runtime`; the frozen Phase 2R `GameState` facade listed in Step 1.3; and four `planned_future` reservations owned by Plan04 that this plan may neither implement nor classify for removal.

- [ ] **Step 1.1: Claim `.4` and write the inventory RED test**

- [ ] Verify the blocker and claim only the ready issue:

```powershell
bd show dwm-p2r.1 --json
bd show dwm-p2r.4 --json
bd update dwm-p2r.4 --claim
git status --short
```

`dwm-p2r.1` MUST be closed. Stop if `.4` is not ready or another worker owns it.

- [ ] Write `test_public_surface_inventory.gd` so an unclassified symbol, duplicate record, missing call-site scan, malformed signature, or required symbol absent from the target surface fails. The scanner exposes exactly:

```gdscript
class_name PublicSurfaceInventory
extends RefCounted

static func build(
	script_path: String,
	search_roots: Array[String],
	required_symbols: Dictionary
) -> Dictionary

static func validate(inventory: Dictionary) -> Dictionary
static func write_canonical_json(inventory: Dictionary, output_path: String) -> Dictionary
```

`generate_public_surface_inventory.gd` is a `SceneTree` runner. Its script argument is exactly `res://autoload/GameState.gd` or `res://autoload/SaveManager.gd`; search roots are the closed set `res://autoload`, `res://scripts`, `res://scenes`, and `res://tests`; required/output paths are the matching GameState or SaveManager paths named in this task. It rejects absolute paths, `user://`, mismatched target/output pairs, unknown flags, and a missing required-symbol manifest.

Each generated record is exactly:

```json
{
  "symbol": "advance_day_or_end",
  "kind": "function",
  "signature": "func advance_day_or_end() -> bool",
  "call_sites": ["tests/unit/test_game_state.gd:64"],
  "disposition": "remove",
  "replacement": "GameState.request_schedule_done(command_id)",
  "contract_test": "test_day7_schedule_done_never_creates_day8"
}
```

`retain` requires a named contract test. `replace` and `deprecate` require a literal replacement signature and caller-migration test. `remove` requires zero validated non-test consumers after migration.

- [ ] Run the focused RED test:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'game_state_surface_red' -LogName 'phase2r-red-game-state-surface.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_public_surface_inventory.gd','-gexit')
```

Expected RED: `PublicSurfaceInventory must exist`. Any production-path access, parse failure, or unrelated error is not an acceptable RED.

- [ ] **Step 1.2: Classify every existing GameState symbol**

- [ ] Generate the inventory from `autoload/GameState.gd` and direct references under `autoload`, `scripts`, `scenes`, and `tests`. Explicitly classify current direct day advancement, Hospital advancement, Day-7 ending mutation, settings/audio/gallery ownership, raw save serialization, Minesweeper mutation, invitation mutation, schedule execution, and ambiguous `executed` seams.

- [ ] Preserve the exact pre-edit inventory as evidence. Do not infer that a zero-call-site public member is safe to remove until the scanner has checked dynamic `call`, `Callable`, signal connection, and string-name references and recorded any unresolved dynamic reference as a blocking diagnostic.

- [ ] Generate the canonical GameState evidence through the isolated helper:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'game_state_surface_generate' -LogName 'phase2r-game-state-surface-generate.log' -GodotArgs @('-s','res://tools/runtime/generate_public_surface_inventory.gd','--','--script=res://autoload/GameState.gd','--search-root=res://autoload','--search-root=res://scripts','--search-root=res://scenes','--search-root=res://tests','--required=res://evidence/phase_2r/runtime/game_state_required_surface.json','--output=res://evidence/phase_2r/runtime/game_state_surface.json')
```

Expected exit `0`, canonical key ordering, and a validated nonempty `game_state_surface.json`.

- [ ] **Step 1.3: Freeze the retained/replacement facade**

- [ ] The target inventory MUST contain these exact Phase 2R run seams:

```gdscript
var day: int:
	get:
		return _run_lifecycle.get_day()
	set(_attempted_value):
		push_error("GameState.day is read-only; use lifecycle commands")

func capture_run_snapshot_input() -> Dictionary
func configure_mutation_gate(gate: Object) -> Dictionary
func prepare_new_run_snapshot_input(run_id: String) -> Dictionary
func prepare_run_candidate(snapshot: Dictionary) -> Dictionary
func capture_live_run_state() -> Dictionary
func commit_run_candidate(candidate: Dictionary) -> Dictionary
func restore_live_run_state(backup: Dictionary) -> Dictionary
func commit_effect_transaction(transaction_id: String, effect_ids: Array[String], source_id: String) -> Dictionary
func commit_variable_transaction(transaction_id: String, variable_id: String, value: Variant, source_id: String) -> Dictionary
func begin_minesweeper_round(request: Dictionary) -> Dictionary
func complete_minesweeper_round(round_id: String, result: Dictionary, transaction_id: String) -> Dictionary
func commit_fainting_event(transaction_id: String, source_id: String, active_entry_id: String = "") -> Dictionary
func request_schedule_done(command_id: String) -> Dictionary
func resume_day_resolution() -> Dictionary
func begin_day_resolution_stage() -> Dictionary
func complete_day_resolution_stage(transaction_id: String, receipt: Dictionary) -> Dictionary
func complete_ending_playback_stage(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary
```

- [ ] The same target contract reserves these exact final facade seams without implementing or calling them in Plan03:

```gdscript
func open_contact(friend_id: String, command_id: String) -> Dictionary
func reply_invitation(friend_id: String, command_id: String) -> Dictionary
func resolve_invitations_for_day(attendance: Dictionary, command_id: String) -> Dictionary
func request_next_ending_command() -> Dictionary
```

`game_state_required_surface.json` stores each reservation with exact `kind="function"`, its literal signature above, `availability="planned_future"`, and `owner_plan="phase2r-04"`; the first three use `owner_task="Task 3"` and `request_next_ending_command` uses `owner_task="Task 6"`. An absent planned-future symbol is valid in Plan03. If one already exists, its signature must match and its only permitted disposition is `retain`; `replace`, `deprecate`, or `remove` is a blocking inventory error. Plan04 owns the implementation and behavioral tests.

- [ ] Keep the reservation test parse-safe: it strict-parses `game_state_required_surface.json` and compares the four primitive records/signature strings. It MUST NOT reference any reserved method as a callable, preload a future Plan04 class, or invent a success result. The first assertion checks file existence and returns after that assertion when absent, so RED is an assertion failure rather than a parser/runtime call error.

The compatibility property permits reads only. Every external assignment to `GameState.day` receives a `replace` disposition and migrates to a domain command or `prepare_run_candidate()` fixture. The no-op setter is a defensive runtime error path, not an alternate mutation seam.

`prepare_new_run_snapshot_input(run_id)` validates a nonempty new stable run ID and returns the complete detached GameState-owned Day-1 defaults without changing live state or profile data. It contains lifecycle `run_id`, `day=1`, `state="PLAYING"`, null plans, all contracted gameplay/contact/schedule/dating defaults, and empty effect/variable transaction ledgers. Runtime `reset_game()` callers receive a `replace` disposition: menu New Game migrates to `SaveManager.start_new_run()`, while unit fixtures commit the pure candidate through the GameState test port and never imply that a journal/disk transaction occurred.

- [ ] **Step 1.4: Validate and record the proposed boundary**

- [ ] Run the inventory suite again. Expected GREEN and no unclassified records:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'game_state_surface_green' -LogName 'phase2r-game-state-surface.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_public_surface_inventory.gd','-gexit')
```

- [ ] Prove the Plan 01 helper and both fixtures are unchanged tracked regular files whose literal working bytes equal their committed HEAD blobs. This block is read-only:

~~~powershell
$commitPrerequisites = @(
    'tools/git/Invoke-ExactPathCommit.ps1'
    'tests/tooling/test_invoke_exact_path_commit.ps1'
    'tests/unit/tooling/test_exact_path_commit.gd'
)
foreach ($path in $commitPrerequisites) {
    $item = Get-Item -LiteralPath $path -Force -ErrorAction Stop
    if ($item.PSIsContainer -or (($item.Attributes -band [IO.FileAttributes]::ReparsePoint) -ne 0)) {
        throw ('Commit prerequisite is not a regular non-reparse file: ' + $path)
    }

    $treeLine = [string]::Join('', @(& git ls-tree HEAD -- $path)).Trim()
    if ($LASTEXITCODE -ne 0 -or $treeLine -notmatch '^100644 blob ([0-9a-f]+)\t(.+)$' -or $Matches[2] -cne $path) {
        throw ('Commit prerequisite is not an exact tracked 100644 HEAD blob: ' + $path)
    }
    $headBlob = $Matches[1]

    $workingBlob = [string]::Join('', @(& git hash-object --no-filters -- $path)).Trim()
    if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($workingBlob) -or $workingBlob -cne $headBlob) {
        throw ('Commit prerequisite working bytes differ from HEAD: ' + $path)
    }
}
~~~

Expected GREEN: all three paths resolve as exact `100644 blob` entries in `HEAD`, none is a reparse point, and each literal working-byte object ID equals its HEAD blob ID.

- [ ] Rerun the already committed source and behavior fixtures without editing their inputs:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'exact_path_commit_plan03_verify' -LogName 'phase2r-plan03-exact-path-commit.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_exact_path_commit.gd','-gexit')
if ($LASTEXITCODE -ne 0) { throw 'Committed exact-path helper source fixture failed.' }
& .\tests\tooling\test_invoke_exact_path_commit.ps1 -Mode Verify
if ($LASTEXITCODE -ne 0) { throw 'Committed exact-path helper behavior fixture failed.' }
~~~

Expected GREEN: every Plan 01 success/rejection/mode/ancestry fixture, including missing, empty, and wrong `ExpectedHead` rejection, passes only in scratch repositories; no caller path is staged or committed.

- [ ] Run `git diff --check`. Only after separate authority for this exact boundary, bind the current parent and run the helper:

```powershell
$required = [ordered]@{
    'tools/runtime/PublicSurfaceInventory.gd'='A'
    'tools/runtime/generate_public_surface_inventory.gd'='A'
    'tests/unit/tooling/test_public_surface_inventory.gd'='A'
    'evidence/phase_2r/runtime/game_state_required_surface.json'='A'
    'evidence/phase_2r/runtime/game_state_surface.json'='A'
}
$optionalUids = [ordered]@{
    'tools/runtime/PublicSurfaceInventory.gd.uid'='A'
    'tools/runtime/generate_public_surface_inventory.gd.uid'='A'
    'tests/unit/tooling/test_public_surface_inventory.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or [string]::IsNullOrWhiteSpace($expectedHead)) { throw 'Cannot bind the Plan 03 Task 1 parent commit.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'test(runtime): inventory the GameState public surface'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 1 commit boundary failed.' }
```

The helper includes each of the three explicitly listed generated runtime-inventory UIDs if and only if it exists. The committed helper and fixture paths are prerequisites, never members of this Task 1 commit. Never widen a pathspec, hand-edit the expected status map, or use `git add .` to make a failing boundary pass.

## Task 2: Implement DayResolutionPlan and RunLifecycle test-first

**Beads:** `dwm-p2r.4`

**Files:**

- Create: `scripts/domain/run/DayResolutionPlan.gd`
- Create: `scripts/domain/run/RunLifecycle.gd`
- Create: `tests/support/DayResolutionReceiptFixtures.gd`
- Create: `tests/unit/test_day_resolution_plan.gd`
- Create: `tests/unit/test_run_lifecycle.gd`

**Interfaces:**

- Consumes: primitive schedule-entry records with stable `entry_id` and unique integer `slot_index`; validated ending-plan Dictionaries; master `CommandResult`.
- Produces: the exact `DayResolutionPlan` and `RunLifecycle` methods below; persisted lifecycle shape `{"run_id", "day", "state", "active_resolution_plan", "ending_plan"}`; idempotent stage/substage receipts used by Task 3.

- [ ] **Step 2.1: Write the lifecycle RED tests**

- [ ] Start with this complete Day-7 behavior test:

```gdscript
extends "res://addons/gut/test.gd"

const LIFECYCLE_PATH := "res://scripts/domain/run/RunLifecycle.gd"
const RECEIPTS_PATH := "res://tests/support/DayResolutionReceiptFixtures.gd"

func test_day7_enters_ending_without_day8_or_rollover_stage() -> void:
	assert_true(ResourceLoader.exists(LIFECYCLE_PATH, "Script"), "RunLifecycle must exist")
	if not ResourceLoader.exists(LIFECYCLE_PATH, "Script"):
		return
	assert_true(ResourceLoader.exists(RECEIPTS_PATH, "Script"), "receipt fixtures must exist")
	if not ResourceLoader.exists(RECEIPTS_PATH, "Script"):
		return
	var lifecycle_script: Script = load(LIFECYCLE_PATH)
	var receipts_script: Script = load(RECEIPTS_PATH)
	var lifecycle: RefCounted = lifecycle_script.new()
	lifecycle.reset("run-day7")
	var restored := lifecycle.prepare_restore({
		"run_id": "run-day7",
		"day": 7,
		"state": "PLAYING",
		"active_resolution_plan": null,
		"ending_plan": null,
	})
	assert_true(restored["ok"], JSON.stringify(restored))
	assert_true(lifecycle.commit_restore(restored["value"]["candidate"])["ok"])
	assert_true(lifecycle.begin_day_resolution("resolution-day7", [])["ok"])

	var visited: Array[String] = []
	while lifecycle.resume_resolution()["value"]["has_stage"]:
		var begun: Dictionary = lifecycle.begin_next_stage()
		var stage: Dictionary = begun["value"]["stage"]
		visited.append(stage["stage_id"])
		var receipt: Dictionary = receipts_script.call(&"for_stage", stage["stage_id"], 7)
		assert_true(lifecycle.complete_active_stage(
			stage["transaction_id"], receipt
		)["ok"])

	assert_eq(lifecycle.get_day(), 7)
	assert_eq(lifecycle.get_state(), &"ENDING")
	assert_false("increment_day" in visited)
	assert_false("invitation_rollover" in visited)
	assert_false("twofriends_if_deferred" in visited)
```

- [ ] Add this complete idempotence RED test to `tests/unit/test_day_resolution_plan.gd` before implementation:

```gdscript
extends "res://addons/gut/test.gd"

const PLAN_PATH := "res://scripts/domain/run/DayResolutionPlan.gd"
const RECEIPTS_PATH := "res://tests/support/DayResolutionReceiptFixtures.gd"

func test_duplicate_completion_reuses_receipt_and_conflict_changes_nothing() -> void:
	assert_true(ResourceLoader.exists(PLAN_PATH, "Script"), "DayResolutionPlan must exist")
	if not ResourceLoader.exists(PLAN_PATH, "Script"):
		return
	assert_true(ResourceLoader.exists(RECEIPTS_PATH, "Script"), "receipt fixtures must exist")
	if not ResourceLoader.exists(RECEIPTS_PATH, "Script"):
		return
	var plan_result: Dictionary = load(PLAN_PATH).create("resolution-r1-d3", 3, [])
	assert_true(plan_result.get("ok", false), JSON.stringify(plan_result))
	var plan: RefCounted = plan_result["value"]["plan"]
	var stage: Dictionary = plan.get_next_incomplete_stage()["value"]["stage"]
	assert_eq(stage["stage_id"], "lock_day")
	assert_true(plan.begin_stage(stage["stage_id"], stage["transaction_id"])["ok"])
	var receipt: Dictionary = load(RECEIPTS_PATH).call(&"for_stage", &"lock_day", 3)
	var first: Dictionary = plan.complete_stage(
		stage["stage_id"], stage["transaction_id"], receipt
	)
	assert_true(first["ok"])
	var after_first: Dictionary = plan.to_dict()
	var replay: Dictionary = plan.complete_stage(
		stage["stage_id"], stage["transaction_id"], receipt.duplicate(true)
	)
	assert_true(replay["ok"])
	assert_eq(replay["receipt"], first["receipt"])
	var conflicting: Dictionary = receipt.duplicate(true)
	conflicting["value"]["locked"] = false
	var rejected: Dictionary = plan.complete_stage(
		stage["stage_id"], stage["transaction_id"], conflicting
	)
	assert_false(rejected["ok"])
	assert_eq(rejected["code"], &"duplicate_transaction_conflict")
	assert_eq(plan.to_dict(), after_first)
```

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'lifecycle_red' -LogName 'phase2r-red-lifecycle.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_day_resolution_plan.gd,res://tests/unit/test_run_lifecycle.gd','-gexit')
```

Expected RED: `RunLifecycle.gd` and `DayResolutionPlan.gd` do not exist. After parsable skeletons exist, the behavioral RED is `Expected ENDING, got PLAYING`.

- [ ] **Step 2.2: Implement the exact plan and lifecycle interfaces**

- [ ] `DayResolutionPlan` exposes exactly:

```gdscript
class_name DayResolutionPlan
extends RefCounted

static func create(resolution_id: String, source_day: int, schedule_entries: Array[Dictionary]) -> Dictionary
static func from_dict(data: Dictionary) -> Dictionary
func to_dict() -> Dictionary
func get_next_incomplete_stage() -> Dictionary
func begin_stage(stage_id: String, transaction_id: String) -> Dictionary
func begin_substage(stage_id: String, substage_id: String, transaction_id: String) -> Dictionary
func complete_substage(stage_id: String, substage_id: String, transaction_id: String, receipt: Dictionary) -> Dictionary
func complete_stage(stage_id: String, transaction_id: String, receipt: Dictionary) -> Dictionary
func is_complete() -> bool
```

- [ ] `RunLifecycle` exposes exactly:

```gdscript
class_name RunLifecycle
extends RefCounted

const PLAYING := &"PLAYING"
const ENDING := &"ENDING"
const COMPLETED := &"COMPLETED"

func reset(run_id: String) -> void
func get_day() -> int
func get_state() -> StringName
func begin_day_resolution(resolution_id: String, schedule_entries: Array[Dictionary]) -> Dictionary
func resume_resolution() -> Dictionary
func begin_next_stage() -> Dictionary
func complete_active_stage(transaction_id: String, receipt: Dictionary) -> Dictionary
func enter_ending(ending_plan: Dictionary) -> Dictionary
func complete_ending_playback_stage(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary
func complete_ending() -> Dictionary
func to_dict() -> Dictionary
func prepare_restore(data: Dictionary) -> Dictionary
func commit_restore(candidate: Dictionary) -> Dictionary
```

`prepare_restore()` succeeds with `value={"candidate": Dictionary}` and never mutates. `commit_restore()` accepts only a candidate produced by the same validator. `to_dict()` is exactly:

```json
{
  "run_id": "run-uuid",
  "day": 3,
  "state": "PLAYING",
  "active_resolution_plan": null,
  "ending_plan": null
}
```

No second active-plan or ending-plan field may exist outside `lifecycle` in a later run snapshot.

- [ ] Implement lifecycle methods with this ordered state machine; every validation operates on a recursive detached copy and every failure returns before assigning live fields:

```text
DayResolutionPlan.create
  validate nonempty resolution_id, source_day in 1..7, and schedule entry IDs/slots
  sort a detached schedule copy by slot_index
  construct the exact source-day stage allowlist and deterministic transaction IDs
  create execute_schedule_entries substages from the sorted entries
  validate the complete plan through from_dict
  return value={plan:<validated DayResolutionPlan instance>}

RunLifecycle.begin_day_resolution
  require state=PLAYING and no ending_plan
  if an active plan has the same resolution_id: return its detached current value
  if an active plan has another ID: return resolution_conflict without mutation
  call DayResolutionPlan.create(day, detached schedule), assign only after success

RunLifecycle.resume_resolution
  require PLAYING with an active plan
  return has_stage plus the first incomplete stage/substage; if the plan is complete,
  return has_stage=false without clearing persisted receipts

RunLifecycle.begin_next_stage
  obtain the first incomplete stage
  reject if another stage/substage is active
  begin its first pending substage when present, otherwise begin the stage itself
  return the exact begun detached record

RunLifecycle.complete_active_stage
  require the supplied transaction ID equals the sole active stage/substage
  validate the owner receipt before mutation
  delegate completion to DayResolutionPlan
  only an increment_day receipt may assign day=source+1, and only from source 1..6
  enter_ending receipt assigns state=ENDING and the already validated EndingPlan
  duplicate identical completion returns the stored receipt; different bytes reject

RunLifecycle.complete_ending_playback_stage / complete_ending
  require state=ENDING and the expected persisted playback stage
  advance exactly one allowed playback edge with its transaction receipt
  complete_ending requires GALLERY_RECORDED, sets COMPLETED, retains day=7 and plan
```

- [ ] **Step 2.3: Implement exact stage and substage validation**

- [ ] Days 1–6 use exactly this top-level order:

```text
lock_day
validate_schedule
execute_schedule_entries
commit_outcomes
hospital_if_triggered
twofriends_if_deferred
invitation_rollover
increment_day
reset_day_scope
new_day_autosave
unlock_day
```

- [ ] Day 7 shares the first four stages, then permits exactly:

```text
hospital_if_triggered
close_invitations_run_end
resolve_ending_plan
enter_ending
ending_autosave
```

- [ ] A persisted stage is exactly:

```json
{
  "stage_id": "execute_schedule_entries",
  "transaction_id": "resolution-day3:execute_schedule_entries",
  "route_id": null,
  "state": "pending",
  "receipt": null,
  "substages": []
}
```

State is `pending`, `active`, or `completed`. Each schedule entry substage ID is `"schedule:%d:%d:%s" % [source_day, slot_index, entry_id]`. Every registered route segment and committed effect under it has a deterministic child substage and receipt. Duplicate slot indexes, empty IDs, reordered stages, unknown stage IDs, mismatched transaction IDs, multiple active stages, a pending stage with a receipt, or a completed stage after an incomplete earlier stage reject before mutation.

- [ ] Implement the plan cursor and mutation methods with this exact algorithm:

```text
from_dict
  reject unknown/missing top-level, stage, substage, or receipt fields
  reconstruct the expected stage IDs from source_day and compare order byte-for-byte
  validate transaction_id = resolution_id + ":" + stage/substage semantic ID
  scan once in order: completed* then at most one active then pending*; reject gaps
  require completed records have receipts and pending/active records have null receipts
  return a new detached DayResolutionPlan only after all nested validation passes

get_next_incomplete_stage
  return the active substage when present; otherwise first pending substage;
  otherwise the active stage; otherwise first pending stage; otherwise has_stage=false

begin_stage / begin_substage
  require the addressed record is the current first pending record and transaction matches
  duplicate begin of that same active record returns its detached record
  assign only that record state=active; never skip or activate two records

complete_substage / complete_stage
  require addressed record is active and transaction matches
  normalize and validate the receipt envelope before mutation
  completed + identical transaction/receipt returns the stored success receipt
  completed + different bytes returns duplicate_transaction_conflict
  set state=completed and store one detached receipt; a parent stage with substages can
  complete only after every child is completed

is_complete
  pure query returning true only when every stage and substage is completed
```

- [ ] **Step 2.4: Prove idempotent lifecycle transitions**

- [ ] Implement and test all of these assertions:

```text
Days 1–6 have the exact stage order.
Schedule substages sort by ascending slot_index.
Resume selects the first incomplete stage/substage.
Repeated Done with the same resolution_id reuses the active plan.
A different resolution_id while locked rejects without mutation.
Duplicate completion with the same transaction_id returns the stored receipt.
Duplicate completion with different receipt bytes rejects.
Hospital precedes twofriends.
Rollover target_day equals source_day + 1 and precedes increment_day.
increment_day changes day exactly once and only from 1–6.
Day 7 contains no rollover, next-day, twofriends, increment, or new-day stage.
Day 7 Hospital precedes ending selection.
day 0, day 8, day above 8, invalid state, and inconsistent ending plan reject.
COMPLETED permits only a semantic Menu route command.
```

`enter_ending()` accepts only a validated Day-7 `EndingPlan`. `complete_ending()` transitions `ENDING -> COMPLETED`; `COMPLETED` cannot re-enter gameplay.

- [ ] Run the focused suite. Expected GREEN with no scene-tree dependency:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'lifecycle_green' -LogName 'phase2r-lifecycle.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_day_resolution_plan.gd,res://tests/unit/test_run_lifecycle.gd','-gexit')
```

- [ ] **Step 2.5: Record the proposed boundary**

- [ ] Run `git diff --check`. Only after separate authority for this exact Task 2 boundary, run:

```powershell
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
$task1Boundary = [string]::Join('', @(git log -1 --format=%H -- evidence/phase_2r/runtime/game_state_surface.json)).Trim()
if ($task1Boundary -cne $expectedHead) { throw 'Task 2 must be the direct successor of the Task 1 inventory boundary.' }
$required = [ordered]@{
    'scripts/domain/run/DayResolutionPlan.gd'='A'
    'scripts/domain/run/RunLifecycle.gd'='A'
    'tests/support/DayResolutionReceiptFixtures.gd'='A'
    'tests/unit/test_day_resolution_plan.gd'='A'
    'tests/unit/test_run_lifecycle.gd'='A'
}
$optionalUids = [ordered]@{
    'scripts/domain/run/DayResolutionPlan.gd.uid'='A'
    'scripts/domain/run/RunLifecycle.gd.uid'='A'
    'tests/support/DayResolutionReceiptFixtures.gd.uid'='A'
    'tests/unit/test_day_resolution_plan.gd.uid'='A'
    'tests/unit/test_run_lifecycle.gd.uid'='A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'feat(lifecycle): add resumable Day 1 to Day 7 plans'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 2 commit boundary failed.' }
```

The helper includes only present optional UIDs and verifies exact statuses, regular-blob modes, and direct-child ancestry.

## Task 3: Add DayResolutionCoordinator and put lifecycle behind GameState

**Beads:** `dwm-p2r.4`

**Files:**

- Create: `scripts/application/run/DayResolutionCoordinator.gd`
- Create: `scripts/application/run/GameStateDayResolutionPort.gd`
- Create: `scripts/application/transaction/ApplicationMutationGate.gd`
- Create: `scripts/application/transaction/FatalDiagnosticProjector.gd`
- Create: `tests/support/FakeDayResolutionStatePort.gd`
- Create: `tests/support/FakeCheckpointPort.gd`
- Create: `tests/unit/test_day_resolution_coordinator.gd`
- Create: `tests/unit/test_application_mutation_gate.gd`
- Create: `tests/unit/test_fatal_diagnostic_projector.gd`
- Modify: `autoload/GameState.gd`
- Modify: `tests/unit/test_game_state.gd`
- Create: `tests/unit/test_game_state_facade_contract.gd`
- Regenerate: `evidence/phase_2r/runtime/game_state_surface.json`

**Interfaces:**

- Consumes: Task 2 `RunLifecycle`; Task 1 facade inventory; exact structural state/checkpoint ports in Step 3.2. This task MUST NOT consume, create, test, or mention `RunSnapshotSchema` in `.4` acceptance evidence.
- Produces: the sole production `ApplicationMutationGate`; the one general pure `FatalDiagnosticProjector`; the common `GameState.configure_mutation_gate(gate: Object) -> Dictionary` seam; narrow `DayResolutionCoordinator.configure_fatal_latch(gate: Object) -> Dictionary` injection of that identical object; master `DayResolutionCoordinator.configure/request_schedule_done/resume/complete_route_stage`; production `GameState.request_schedule_done()` delegation; the frozen `GameStateDayResolutionPort.begin_or_resume(command_id: String)` signature; exact owner/receipt registry; and a fake checkpoint port with pure `preview_checkpoint_id(run_id: String)`. Task 6 replaces the fake with the real `SaveManagerCheckpointPort` without changing either state/checkpoint port contract.

- [ ] **Step 3.1: Write coordinator and production-facade RED tests**

- [ ] Add this complete RED transaction test to `tests/unit/test_day_resolution_coordinator.gd` before creating the coordinator or fakes:

```gdscript
extends "res://addons/gut/test.gd"

const COORDINATOR_PATH := "res://scripts/application/run/DayResolutionCoordinator.gd"
const STATE_PATH := "res://tests/support/FakeDayResolutionStatePort.gd"
const CHECKPOINT_PATH := "res://tests/support/FakeCheckpointPort.gd"

func test_checkpoint_commit_failure_rolls_back_without_publication() -> void:
	for path in [COORDINATOR_PATH, STATE_PATH, CHECKPOINT_PATH]:
		assert_true(ResourceLoader.exists(path, "Script"), path + " must exist")
		if not ResourceLoader.exists(path, "Script"):
			return
	var calls: Array[String] = []
	var state: RefCounted = load(STATE_PATH).new(calls)
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	state.seed_playing_day("run-1", 3, [])
	checkpoint.seed_empty("run-1")
	checkpoint.set_failure(&"commit_after_mutation")
	var state_before: Dictionary = state.peek_state()
	var checkpoint_before: Dictionary = checkpoint.peek_state()
	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	assert_true(coordinator.configure(state, checkpoint)["ok"])
	var result: Dictionary = coordinator.request_schedule_done("done:run-1:day-3")
	assert_false(result["ok"])
	assert_eq(result["code"], &"checkpoint_commit_failed")
	assert_eq(state.peek_state(), state_before)
	assert_eq(checkpoint.peek_state(), checkpoint_before)
	assert_eq(state.get_publication_count(), 0)
	assert_eq(calls, [
		"state.begin_or_resume", "state.begin_next_stage",
		"state.capture", "checkpoint.capture",
		"state.prepare_completion", "checkpoint.prepare",
		"checkpoint.commit", "checkpoint.rollback",
	])
```

- [ ] Create `test_application_mutation_gate.gd` and `test_fatal_diagnostic_projector.gd` before either implementation. Their parse-safe REDs first require `scripts/application/transaction/ApplicationMutationGate.gd` and `FatalDiagnosticProjector.gd`, then cover every exact contract case frozen in Step 3.2. Extend `test_game_state_facade_contract.gd` with the common GameState valid/same/null/missing-signal/missing-each-method/replacement matrix and zero-side-effect assertions. Extend the coordinator test with missing/invalid/replacement fatal-latch configuration, same-instance idempotence, one-object identity, and real-gate acceptance of every projected fake rollback diagnostic. Expected RED is the missing gate/projector script or first missing GameState/coordinator seam, never a parser error.

- [ ] Tests invoke `GameState.request_schedule_done("done:run-1:day-3")`, never `advance_day_or_end()`, then assert the returned registered command names the first incomplete stage. Repeat the concrete pattern above with `state.prepare`, `checkpoint.prepare`, `state.commit`, and deterministic publication failures; assert live state, receipts, and the fake journal equal their pre-command snapshots after every recoverable failure. A forced rollback failure completes every required rollback attempt, wraps each result as one exact projector diagnostic, projects/validates `source="day_resolution"`, the original phase, `code="fatal_rollback_failed"`, and primitive context containing only the transaction/stage IDs, substitutes only the invariant fallback when needed, calls the exact Task-3 gate injected through `configure_fatal_latch()` once, then calls `guard_external(&"day_resolution_recovery")` and returns that exact retained `APPLICATION_FATAL`. When a real SaveManagerCheckpointPort recovery has already latched this same gate and returns retained `APPLICATION_FATAL`, the coordinator still finishes other required recoveries but performs no second projection/latch; it calls only its final guard and propagates the first retained failure. It never passes raw diagnostics to the gate, returns outer `fatal_rollback_failed`/latch success/conflict, or owns a coordinator-local fatal flag/fallback gate.

- [ ] Add a compatibility test that reads `GameState.day`, attempts the guarded legacy assignment, verifies the value is unchanged, and verifies the inventory reports every direct assignment caller for migration.

- [ ] Add a pure New Game candidate test: capture live Run A, call `prepare_new_run_snapshot_input("run-b")`, assert the complete Day-1 defaults and empty run-scoped ledgers in the detached value, then assert live Run A and every ProfileManager field are byte-equal. Empty/reused run IDs reject without mutation.

- [ ] Add parse-safe structural tests that dynamically load `GameStateDayResolutionPort.gd` and `FakeCheckpointPort.gd`. Assert `begin_or_resume` requires and forwards the exact nonempty `command_id`; an empty ID fails before lifecycle mutation. Seed the fake checkpoint port, call `preview_checkpoint_id("run-1")`, then call `prepare()` immediately with the same run ID and no intervening commit. Both must return the same `<run_id>:<sequence>` ID, while preview leaves the fake journal, sequence, candidates, and call-visible storage state byte-equal and never invokes snapshot build/write behavior.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'day_resolution_coordinator_red' -LogName 'phase2r-red-day-resolution-coordinator.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_application_mutation_gate.gd,res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_day_resolution_coordinator.gd,res://tests/unit/test_game_state_facade_contract.gd,res://tests/unit/test_game_state.gd','-gexit')
```

Expected RED: `DayResolutionCoordinator must exist`; after creation, `request_schedule_done` still uses the legacy advance path.

- [ ] **Step 3.2: Implement the shared fatal boundary and two exact structural ports**

- [ ] Create the one runtime gate now, before any coordinator rollback path can require its fatal latch:

```gdscript
class_name ApplicationMutationGate
extends RefCounted

signal capability_changed(capability: Dictionary)

func acquire(owner_id: StringName) -> Dictionary
func release(owner_id: StringName, token: String) -> Dictionary
func guard_external(operation_id: StringName) -> Dictionary
func is_active() -> bool
func get_active_owner() -> StringName
func is_internal_owner_active(owner_id: StringName) -> bool
func latch_fatal(failure: Dictionary) -> Dictionary
func is_fatal_latched() -> bool
```

Only `owner_id=&"restore"` and `owner_id=&"new_run"` are valid acquire owners. `acquire()` returns `value={"token": String}`; nested or competing acquisition rejects. Before a fatal latch, `guard_external()` succeeds only while no owner is active and otherwise returns `code=&"TRANSACTION_ACTIVE"` with no candidate. `release()` requires the exact owner/token pair.

`latch_fatal()` is the one callable, irreversible process-fatal mutation fence. Its input has exactly `source`, `phase`, `code`, and `details`; the first three accept String/StringName, normalize to nonempty String, and `details` is a recursively detached primitive JSON Dictionary with String keys and no non-finite number, Object, Resource, Callable, or packed byte value. Unknown/missing keys or an invalid primitive returns `INVALID_FATAL_FAILURE` and changes nothing. The normalized retained shape is exactly:

```gdscript
{
	"source": String,
	"phase": String,
	"code": String,
	"details": Dictionary,
}
```

The first valid call stores that detached value, emits exactly one `capability_changed({"enabled":false,"code":&"APPLICATION_FATAL","active_owner":StringName|null,"fatal_latched":true,"failure":FatalFailure})`, and returns exactly `{"ok":true,"code":&"ok","value":{"fatal_latched":true,"already_latched":false},"receipt":{"failure":FatalFailure}}`. Repeating the byte-equivalent normalized failure emits nothing and returns the same shape with `already_latched=true`. A different valid failure emits nothing, preserves the first failure, and returns `APPLICATION_FATAL_CONFLICT` with exact `details={"latched_failure":FatalFailure,"requested_failure":FatalFailure}`. There is no unlatch/reset method.

Fatal is not a third acquire owner: latching neither creates nor changes the current owner/token. `is_active()` continues to report only whether `restore` or `new_run` owns a token; `get_active_owner()` continues to return that owner or `&""`; `is_fatal_latched()` reports the separate irreversible state. Once latched, `guard_external()`, `acquire()`, and `release()` all return `APPLICATION_FATAL` with exact `details={"failure":FatalFailure}` before any other validation or mutation; `is_internal_owner_active()` returns false for every owner. Thus even the originally correct owner/token cannot release a fatal fence. Successful rollback or finalization releases a nonfatal gate exactly once; every rollback/release recovery failure first projects and validates its ordered raw diagnostics through the one shared projector, latches that primitive failure or invariant fallback, then returns the authoritative post-latch guard result.

`test_application_mutation_gate.gd` exhaustively proves malformed exact-key/type/primitive inputs do not latch; first valid detached retention and the one exact disabled signal; caller-Dictionary mutation isolation; identical normalized repeat idempotence; conflicting-repeat preservation; owner/token identity unchanged by latching; ownerless fatal does not make `is_active()` true; fatal-first acquire/release/guard/internal-owner responses; and absence of any unlatch/reset API. It also source-scans the project after Task 3 and rejects any second `class_name ApplicationMutationGate`, subsystem-local fatal Boolean, or other production latch implementation.

- [ ] Create the one general, pure diagnostic projector beside the gate with the exact shared contract consumed later by desktop and Minesweeper recovery:

```gdscript
class_name FatalDiagnosticProjector
extends RefCounted

static func project_failure(
		source: Variant,
		phase: Variant,
		code: Variant,
		context: Dictionary,
		raw_diagnostics: Array
) -> Dictionary
static func validate_failure(failure: Dictionary) -> Dictionary
static func get_invariant_fallback() -> Dictionary
```

`project_failure()` normalizes nonempty String/StringName `source`, `phase`, and `code` to ordinary String and returns the frozen CommandResult success `value={"failure":FatalFailure}` with empty receipt. `FatalFailure` has exactly those three normalized fields plus `details={"context":Dictionary,"diagnostics":Array[Dictionary]}`. Context and diagnostic data are recursively detached. JSON null, bool, int, finite float, String, Array, and Dictionary are the only admitted values; every StringName value and every String/StringName key becomes String. Arrays preserve order. Dictionary keys must remain unique after normalization. A non-finite number, Object, Resource, Callable, RID, any packed array/bytes value, unsupported value, non-string key, or normalized-key collision is never copied. Instead, the smallest replaceable invalid subtree becomes exactly `{"reason":String,"path":String}`, where reason is one of `nonfinite_number|unsupported_type|non_string_key|normalized_key_collision`; an invalid Dictionary key or collision replaces that whole Dictionary subtree. Paths are deterministic JSONPath-like Strings rooted at `$.context` or `$.diagnostics[index]`. The projector uses closed depth/node budgets and maps budget/cycle exhaustion to the same `unsupported_type` sentinel; it never recurses without a deterministic bound or exposes rejected bytes through a message.

Each raw diagnostic has exactly `owner_id`, `operation`, and `result`. The first two are caller-owned nonempty String/StringName values normalized to String. `result` must be one frozen CommandResult union: its bool `ok` and nonempty String/StringName `code` are retained as bool/String; a success projects `message=""` and `details={}` without copying `value` or `receipt`; a failure requires String/StringName `message` plus Dictionary `details` and recursively projects those details. Every projected diagnostic has exactly `owner_id`, `operation`, `ok`, `code`, `message`, and `details`. A malformed diagnostic/result becomes exactly `{"owner_id":"fatal_diagnostic_projector","operation":"project_diagnostic","ok":false,"code":"invalid_fatal_diagnostic","message":"","details":{"reason":"malformed_diagnostic","path":String}}`; no rejected byte or alias enters it.

`validate_failure()` independently enforces the exact-key/nonempty-normalized-string/recursive-primitive contract frozen for `ApplicationMutationGate.latch_fatal()`. `get_invariant_fallback()` returns a fresh copy of the constant valid primitive failure `{"source":"fatal_diagnostic_projector","phase":"project_failure","code":"FATAL_PROJECTOR_INVARIANT","details":{"reason":"invalid_projector_output","path":"$"}}`. Every caller completes all required recovery attempts first, preserves raw diagnostic order, calls `project_failure()`, validates the returned full failure, and uses `value.failure` only when both CommandResults succeed. A failed projector result, failed validation, thrown projector invariant, or missing candidate substitutes only `get_invariant_fallback()`; it never skips the fatal fence or copies the raw cause.

After `latch_fatal(failure)`, any path whose public result must be authoritative invokes the same gate's `guard_external(<stable operation id>)` and returns that exact retained `APPLICATION_FATAL`, including the first failure details. `APPLICATION_FATAL_CONFLICT` from a concurrent different latch never replaces the retained failure; the final guard remains authoritative. No caller returns the latch's intermediate success/conflict result, an outer raw rollback code, or an empty fatal detail. DayResolutionCoordinator, SaveManagerCheckpointPort, restore, and new_run use stable context containing only their primitive transaction/run/checkpoint identifiers and wrap each attempted recovery result as the exact raw diagnostic envelope before projection.

`test_fatal_diagnostic_projector.gd` covers StringName key/value normalization, recursive detachment, nested invalid-subtree replacement, malformed diagnostic replacement, non-finite floats, Object, Resource, Callable, RID, packed bytes and every other packed array, non-string keys, normalized-key collisions, deterministic path/order, depth/node/cycle bounds, caller mutation after projection, exact validation, and exact invariant fallback. It passes every projected `value.failure` and the invariant fallback to a fresh real gate and requires that neither can produce `INVALID_FATAL_FAILURE`. It source-scans for exactly one `class_name FatalDiagnosticProjector`. Task 6 and Task 7 extend their real failure matrices so every raw rollback/storage/participant CommandResult they can produce is projected, validated, and accepted by a fresh real gate; fake-gate-only acceptance is insufficient.

- [ ] Implement `GameState.configure_mutation_gate(gate: Object) -> Dictionary` now because Task 3 is GameState's first guarded mutation owner. It requires a non-null object with `capability_changed` and all eight methods above; accepts the first compatible instance and the identical instance idempotently; rejects a replacement with `mutation_gate_already_configured`; rejects null/incomplete input with `invalid_mutation_gate`; and returns exactly `{"ok":true,"code":&"ok","value":{"gate_instance_id":int,"already_configured":bool},"receipt":{}}`. Configuration performs no I/O, lifecycle mutation, signal connection/emission, input change, or cross-manager call. Every external GameState mutation calls `guard_external()` before domain validation; internal restore/new-run seams later require `is_internal_owner_active()`.

- [ ] Give `DayResolutionCoordinator` this separate service seam without changing the master two-argument state/checkpoint configuration contract:

```gdscript
func configure_fatal_latch(gate: Object) -> Dictionary
func configure(state_port: Object, checkpoint_port: Object) -> Dictionary
```

`configure_fatal_latch()` requires the same complete gate contract as GameState, retains the first object, accepts only that identical object idempotently, rejects null/incomplete/replacement input with the same codes, and returns the same exact identity result. The coordinator calls only `latch_fatal()`, `is_fatal_latched()`, and the post-latch authoritative `guard_external()` on it; it never acquires/releases the gate, creates a gate, or retains a fatal Boolean. `configure()` fails with `fatal_latch_not_configured` until this seam succeeds. Unit setup constructs one `ApplicationMutationGate`, passes it to both GameState and the coordinator, and asserts both returned IDs equal `gate.get_instance_id()`. Task 7's `configure_day_resolution` bootstrap adapter repeats that same identity proof with the already-injected final gate; the coordinator is an application service and is not a ninth `FINAL_GATE_TARGETS` manager.

- [ ] `DayResolutionCoordinator.configure()` rejects a port missing any method in these contracts:

```gdscript
# state_port, implemented by GameStateDayResolutionPort
func begin_or_resume(command_id: String) -> Dictionary
func inspect_next_stage() -> Dictionary
func begin_next_stage() -> Dictionary
func prepare_completion(transaction_id: String, receipt: Dictionary) -> Dictionary
func capture() -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func publish(publication: Dictionary) -> Dictionary

# checkpoint_port, FakeCheckpointPort in .4 and SaveManagerCheckpointPort in .5
func preview_checkpoint_id(run_id: String) -> Dictionary
func capture() -> Dictionary
func prepare(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
```

`begin_or_resume(command_id: String)` validates that exact nonempty ID and passes it unchanged to the lifecycle start/resume command; no zero-argument overload exists. `prepare_completion()` returns `value={"run_candidate": Dictionary, "snapshot_input": Dictionary, "stage": Dictionary, "publication": Dictionary, "duplicate": bool}` without mutating. On `duplicate=true`, the stage already contains the identical receipt; the coordinator reads the checkpoint ID from the captured checkpoint port's current whole bundle and performs no prepare/commit/publish. `checkpoint_port.preview_checkpoint_id()` returns exactly `value={"checkpoint_id": String}` and derives it from the current next sequence without consuming the sequence, building a snapshot, preparing a journal candidate, or touching storage. The immediately following `checkpoint_port.prepare()` with the same run ID and no intervening commit returns `value={"candidate": Dictionary, "checkpoint_id": String}` with that identical ID. `disk_write` is exactly one of:

```gdscript
{"kind": &"none", "reason": &"stage"}
{"kind": &"autosave", "reason": &"day_start"}
{"kind": &"autosave", "reason": &"ending"}
```

The fake port stores primitive candidates in memory and supports deterministic `fail_prepare`, `fail_commit`, and `fail_rollback` test controls. It never imports `RunSnapshotSchema` or writes disk.

For the executable tests, both fake constructors accept one shared `Array[String]` call log and expose a non-logging detached `peek_state()->Dictionary`. `FakeDayResolutionStatePort` additionally exposes `seed_playing_day(run_id:String,day:int,schedule:Array[Dictionary])`, `set_failure(phase:StringName)`, and `get_publication_count()->int`; `FakeCheckpointPort` exposes `seed_empty(run_id:String)` and `set_failure(phase:StringName)`. `commit_after_mutation` deliberately changes the fake then returns failure so rollback is mandatory and observable.

`state_port.begin_next_stage()` returns one of two exact success values:

```gdscript
{"mode": &"complete_immediately", "stage": Dictionary, "receipt": Dictionary}
{"mode": &"await_registered_command", "stage": Dictionary, "command": Dictionary}
```

`GameStateDayResolutionPort` obtains immediate receipts by invoking the owning pure module through `GameState`; it never fabricates an owner result. Route/timeline work returns `await_registered_command`, and only the matching registered completion can supply its receipt. The coordinator itself produces the deterministic lock/unlock and disk-checkpoint-request receipts. `request_schedule_done()` repeatedly completes immediate stages and stops only at a registered external command, a completed plan, or a typed failure. This is the production Schedule Done path; callers and tests never walk successful stages by hand.

- [ ] **Step 3.3: Freeze the exact stage-owner and receipt registry**

- [ ] `DayResolutionCoordinator` contains one closed `STAGE_CONTRACTS` constant. Every receipt is exactly `{"owner_id": String, "kind": String, "value": Dictionary}`; additional top-level keys reject. The registry is:

| Stage | owner_id | kind | Exact `value` keys |
|---|---|---|---|
| `lock_day` | `day_resolution_coordinator` | `day_lock` | `locked: true` |
| `validate_schedule` | `schedule_rules` | `schedule_validation` | `schedule_digest: String`, `ordered_entry_ids: Array[String]` |
| `execute_schedule_entries` | `schedule_rules` | `schedule_entries_complete` | `entry_receipt_ids: Array[String]` |
| `commit_outcomes` | `game_state` | `outcomes_commit` | `outcome_ids: Array[String]`, `effect_transaction_ids: Array[String]` |
| `hospital_if_triggered` | `dating_ending_rules` | `hospital_resolution` | `required: bool`, `route_receipt_id: String|null`, `prevented_entry_id: String|null` |
| `twofriends_if_deferred` | `contact_invitation_state` | `twofriends_resolution` | `required: bool`, `route_receipt_id: String|null`, `message_transaction_ids: Array[String]` |
| `invitation_rollover` | `contact_invitation_state` | `invitation_rollover` | `target_day: int`, `message_transaction_ids: Array[String]` |
| `increment_day` | `run_lifecycle` | `day_increment` | `source_day: int`, `target_day: int` |
| `reset_day_scope` | `game_state` | `day_scope_reset` | `target_day: int`, `reset_ids: Array[String]` |
| `new_day_autosave` | `save_manager` | `disk_checkpoint_request` | `save_kind: "autosave"`, `save_reason: "day_start"` |
| `unlock_day` | `day_resolution_coordinator` | `day_unlock` | `locked: false` |
| `close_invitations_run_end` | `contact_invitation_state` | `run_end_close` | `resolved_action_ids: Array[String]` |
| `resolve_ending_plan` | `dating_ending_rules` | `ending_resolution` | `ending_plan: Dictionary` |
| `enter_ending` | `run_lifecycle` | `enter_ending` | `state: "ENDING"`, `primary_id: String`, `epilogue_id: String|null` |
| `ending_autosave` | `save_manager` | `disk_checkpoint_request` | `save_kind: "autosave"`, `save_reason: "ending"` |

Route and schedule-entry substage receipts use the same envelope with registered owner/kind pairs `scene_router/route_complete`, `schedule_rules/schedule_entry_complete`, and `effect_resolver/effect_transaction`. Their exact value shapes are `{"route_receipt_id": String}`, `{"entry_receipt_id": String, "outcome_ids": Array[String]}`, and `{"transaction_id": String, "effect_ids": Array[String]}` respectively.

`FakeDayResolutionStatePort` obtains its immediate receipts from `DayResolutionReceiptFixtures.for_stage()` in `.4`; test methods do not inline arbitrary success Dictionaries or walk immediate stages. A test passes a receipt directly only to simulate completion of the exact registered external command returned by the coordinator.

- [ ] **Step 3.4: Implement atomic coordinator completion**

- [ ] The public coordinator interface is exactly:

```gdscript
func configure_fatal_latch(gate: Object) -> Dictionary
func configure(state_port: Object, checkpoint_port: Object) -> Dictionary
func request_schedule_done(command_id: String) -> Dictionary
func resume() -> Dictionary
func complete_route_stage(transaction_id: String, receipt: Dictionary) -> Dictionary
```

`GameState.request_schedule_done()` delegates to `DayResolutionCoordinator.request_schedule_done()`. `resume_day_resolution()` and `begin_day_resolution_stage()` expose coordinator query/command results without reintroducing a second lifecycle owner. `complete_day_resolution_stage()` delegates to `complete_route_stage()`.

For each accepted completion the coordinator performs exactly:

```text
validate stage owner and receipt shape
capture state-port and checkpoint-port backups
prepare detached run candidate
prepare a detached checkpoint candidate (`day_start` for `new_day_autosave`; `day_resolution_stage` for every other stage)
commit checkpoint candidate (including required autosave)
commit run candidate
publish the prepared GameState notification batch
```

The checkpoint-port prepare/commit result supplies the resulting `checkpoint_id`; the coordinator returns it in the successful command value rather than placing a not-yet-created ID inside the stage receipt. For `new_day_autosave` and `ending_autosave`, the disk document contains the stage as completed before the live run candidate becomes observable.

- [ ] Implement the coordinator bodies with this exact control flow:

```text
request_schedule_done(command_id)
  require configured ports and nonempty command_id
  state_port.begin_or_resume(command_id)
  call resume()

resume()
  loop:
    inspect_next_stage; when no stage remains return plan_complete + current checkpoint ID
    begin_next_stage
    if mode=await_registered_command: return that command without any completion
    if mode=complete_immediately: call _commit_completion(stage.tx, receipt)
    on completion success continue; on failure return immediately

complete_route_stage(transaction_id, receipt)
  require the current active stage/substage is await_registered_command
  require transaction ID and registered command owner/kind/value match exactly
  call _commit_completion; on success call resume() to reach the next external command

_commit_completion(transaction_id, receipt)
  validate receipt against STAGE_CONTRACTS before captures
  capture state backup, then checkpoint backup
  state.prepare_completion; on failure return with no rollback
  if duplicate=true: verify captured current bundle contains the same completed transaction;
    return stored receipt/current checkpoint ID with no mutation
  checkpoint.prepare from the returned snapshot_input and stage-specific disk_write
  checkpoint.commit; on failure call checkpoint.rollback(checkpoint backup)
  state.commit; on failure call state.rollback(state backup), then checkpoint.rollback
  state.publish(prepared publication); publish must fail before emitting any signal;
    on failure roll state back, then checkpoint, and emit nothing
  if any required rollback fails: finish every rollback attempt; if the same gate is already
    latched and a recovery returned retained APPLICATION_FATAL, do not latch again and jump
    to the final guard; otherwise wrap raw results in exact {owner_id,operation,result} order;
    project source=day_resolution, original phase, code=fatal_rollback_failed, and primitive
    transaction/stage context through FatalDiagnosticProjector; validate the full failure or
    use only its invariant fallback; latch the shared ApplicationMutationGate once; call
    guard_external(day_resolution_recovery); return that exact retained APPLICATION_FATAL
  on success return receipt + checkpoint_id; publication occurs exactly once
```

Production `publish()` validates the detached notification batch completely before emitting and has no fallible work after its first emission. Tests may inject only a pre-emission failure. A successful duplicate transaction returns the stored receipt and checkpoint ID and does not create another checkpoint, autosave, or notification.

- [ ] **Step 3.5: Remove current Day-8 behavior and close `.4`**

- [ ] Replace current tests expecting `day == 8` with Day-7 `ENDING` assertions. Keep Day-8 fixtures out of `.4`; they are created under Task 7 migration tests.

- [ ] Implement `prepare_new_run_snapshot_input()` as the pure default builder frozen in Task 1. Replace production `reset_game()` callers in the surface inventory with `SaveManager.start_new_run()`; test setup may commit the detached candidate through `GameStateDayResolutionPort` but may not call SaveManager or production storage. `SceneRouter.start_game_from_menu()` no longer resets state directly when Task 7 migrates the menu command.

- [ ] Run the complete `.4` suite:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'lifecycle_issue_gate' -LogName 'phase2r-lifecycle-issue-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_public_surface_inventory.gd,res://tests/unit/test_day_resolution_plan.gd,res://tests/unit/test_run_lifecycle.gd,res://tests/unit/test_application_mutation_gate.gd,res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_day_resolution_coordinator.gd,res://tests/unit/test_game_state_facade_contract.gd,res://tests/unit/test_game_state.gd','-gexit')
```

- [ ] Scan active runtime and separate allowed migration evidence:

```powershell
rg -n '\bday\s*=\s*8\b|day becomes 8|Day-8|Day 8' autoload scripts scenes tests
```

Expected active-runtime matches: none. Any test match at this point must assert rejection; migration fixtures arrive in `.5`.

- [ ] Regenerate `game_state_surface.json`, prove every disposition, append the exact command/log paths to `dwm-p2r.4`, and close `.4` only when its acceptance criteria pass. The `.4` evidence list MUST NOT contain `RunSnapshotSchema`, `SaveDocumentSchema`, `CheckpointJournal`, or SaveManager migration tests.

- [ ] Record the proposed boundary:

```powershell
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
$task2Boundary = [string]::Join('', @(git log -1 --format=%H -- scripts/domain/run/RunLifecycle.gd)).Trim()
if ($task2Boundary -cne $expectedHead) { throw 'Task 3 must be the direct successor of the Task 2 lifecycle boundary.' }
$required = [ordered]@{
    'scripts/application/run/DayResolutionCoordinator.gd'='A'
    'scripts/application/run/GameStateDayResolutionPort.gd'='A'
    'scripts/application/transaction/ApplicationMutationGate.gd'='A'
    'scripts/application/transaction/FatalDiagnosticProjector.gd'='A'
    'tests/support/FakeDayResolutionStatePort.gd'='A'
    'tests/support/FakeCheckpointPort.gd'='A'
    'tests/unit/test_day_resolution_coordinator.gd'='A'
    'tests/unit/test_application_mutation_gate.gd'='A'
    'tests/unit/test_fatal_diagnostic_projector.gd'='A'
    'tests/unit/test_game_state_facade_contract.gd'='A'
    'autoload/GameState.gd'='M'
    'tests/unit/test_game_state.gd'='M'
    'evidence/phase_2r/runtime/game_state_surface.json'='M'
}
$optionalUids = [ordered]@{
    'scripts/application/run/DayResolutionCoordinator.gd.uid'='A'
    'scripts/application/run/GameStateDayResolutionPort.gd.uid'='A'
    'scripts/application/transaction/ApplicationMutationGate.gd.uid'='A'
    'scripts/application/transaction/FatalDiagnosticProjector.gd.uid'='A'
    'tests/support/FakeDayResolutionStatePort.gd.uid'='A'
    'tests/support/FakeCheckpointPort.gd.uid'='A'
    'tests/unit/test_day_resolution_coordinator.gd.uid'='A'
    'tests/unit/test_application_mutation_gate.gd.uid'='A'
    'tests/unit/test_fatal_diagnostic_projector.gd.uid'='A'
    'tests/unit/test_game_state_facade_contract.gd.uid'='A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'refactor(game-state): coordinate idempotent Day 1 to Day 7 resolution'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 3 commit boundary failed.' }
```

Run this block only after separate authority. Existing UID files are never restaged; only the ten explicit newly generated optional UIDs may join the exact required status map.

## Task 4: Inventory SaveManager and define primitive save schemas

**Beads:** `dwm-p2r.5`

**Files:**

- Reuse: `tools/runtime/PublicSurfaceInventory.gd`
- Reuse: `tools/runtime/generate_public_surface_inventory.gd`
- Extend: `tests/unit/tooling/test_public_surface_inventory.gd`
- Create: `evidence/phase_2r/runtime/save_manager_required_surface.json`
- Generate: `evidence/phase_2r/runtime/save_manager_surface.json`
- Create: `scripts/domain/run/RunSnapshotSchema.gd`
- Create: `scripts/infrastructure/save/SaveDocumentSchema.gd`
- Create: `data/manifests/narrative_variables.json`
- Create: `tests/unit/test_run_snapshot_schema.gd`
- Create: `tests/unit/test_save_document_schema.gd`
- Create: `tests/fixtures/snapshots/valid_day3.json`
- Create: `tests/fixtures/snapshots/invalid_day8.json`
- Create: `tests/fixtures/snapshots/invalid_object_shapes.json`

**Interfaces:**

- Consumes: closed `.3` ProfileManager/storage contracts; closed `.4` lifecycle shape; Task 1 generic surface inventory; master `StorageAdapter` and `CommandResult`.
- Produces: frozen SaveManager target surface; `RunSnapshotSchema.build/validate/validate_primitive_tree/prepare_candidate/is_compatible_bundle/derive_route_restore_context`; `SaveDocumentSchema.build/validate/prepare_candidate`; initial empty narrative-variable registry.

- [ ] **Step 4.1: Verify blockers and inventory SaveManager before editing it**

- [ ] Run:

```powershell
bd show dwm-p2r.3 --json
bd show dwm-p2r.4 --json
bd show dwm-p2r.5 --json
bd update dwm-p2r.5 --claim
```

Both blockers MUST be closed. Stop if `.5` is not ready or owned by another worker.

- [ ] Generate `save_manager_surface.json` from current `autoload/SaveManager.gd` plus all repository call sites. Explicitly classify raw path getters, caller-supplied filenames, direct JSON helpers, `save_slot/load_slot`, `quick_save/quick_load`, `autosave/load_autosave`, `has_slot`, metadata APIs, and old completion/failure signals.

- [ ] Use the same CLI runner and isolated helper:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'save_manager_surface_generate' -LogName 'phase2r-save-manager-surface-generate.log' -GodotArgs @('-s','res://tools/runtime/generate_public_surface_inventory.gd','--','--script=res://autoload/SaveManager.gd','--search-root=res://autoload','--search-root=res://scripts','--search-root=res://scenes','--search-root=res://tests','--required=res://evidence/phase_2r/runtime/save_manager_required_surface.json','--output=res://evidence/phase_2r/runtime/save_manager_surface.json')
```

Expected exit `0`, canonical key ordering, and a validated nonempty `save_manager_surface.json`.

- [ ] Freeze this exact target surface:

```gdscript
signal run_restored(checkpoint_id: String, route_id: String)
signal save_capability_changed(capability: Dictionary)

func configure_mutation_gate(gate: Object) -> Dictionary
func initialize(storage: StorageAdapter = null) -> Dictionary
func record_stable_checkpoint(checkpoint_inputs: Dictionary, checkpoint_kind: StringName) -> Dictionary
func get_latest_stable_checkpoint() -> Dictionary
func start_new_run(run_id: String, initial_context: Dictionary) -> Dictionary
func save_latest_to_slot(slot_id: int) -> Dictionary
func quick_save_latest() -> Dictionary
func autosave_latest() -> Dictionary
func save_for_logout() -> Dictionary
func prepare_restore_slot(slot_id: int) -> Dictionary
func prepare_restore_quick() -> Dictionary
func prepare_restore_autosave() -> Dictionary
func commit_prepared_restore(prepared: Dictionary) -> Dictionary
func delete_slot(slot_id: int) -> Dictionary
func delete_quick_save() -> Dictionary
func delete_autosave() -> Dictionary
func save_exists(kind: StringName, slot_id: int = -1) -> bool
func get_save_metadata(kind: StringName, slot_id: int = -1) -> Dictionary
func get_all_save_metadata() -> Array[Dictionary]
func acquire_save_lock(owner_id: StringName) -> Dictionary
func release_save_lock(owner_id: StringName) -> Dictionary
func is_save_locked() -> bool
func get_save_capability() -> Dictionary
func configure_restore_participants(participants: Dictionary) -> Dictionary
```

Old load wrappers may remain for one issue only with `deprecate` dispositions that delegate `prepare + commit`; they MUST NOT retain a second parser/apply path. Raw path getters and caller-supplied path methods receive `remove` dispositions.

- [ ] **Step 4.2: Write primitive-schema RED tests**

- [ ] Tests reject `Node`, `Object`, `Resource`, `Callable`, `StringName`, non-string Dictionary keys, non-finite floats, arbitrary scene/timeline paths, unknown registered IDs, Day 8, unsupported future schema versions, duplicate transaction IDs, and malformed nested fields. JSON integral numbers normalize to integers; non-integral schema/day/sequence/counter fields reject. The document tests also prove that `slot_id=null` survives build -> `JSON.stringify()` -> `JSON.parse_string()` for quick/autosave documents, while a slot document rejects null and non-slot documents reject `-1` or any integer.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'save_schema_red' -LogName 'phase2r-red-save-schema.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/tooling/test_public_surface_inventory.gd','-gexit')
```

Expected RED: `RunSnapshotSchema must exist` and `SaveDocumentSchema must exist`.

- [ ] **Step 4.3: Implement the exact run snapshot shape**

- [ ] `RunSnapshotSchema` exposes exactly:

```gdscript
class_name RunSnapshotSchema
extends RefCounted

const SCHEMA_VERSION := 2
const RECOVERY_LINE_HISTORY_LIMIT := 32

static func build(snapshot_input: Dictionary, dialogic_checkpoint: Dictionary, route_id: String, active_app_id: Variant, audio_context: Dictionary, content_version: int, checkpoint_sequence: int) -> Dictionary
static func validate(snapshot: Dictionary) -> Dictionary
static func validate_primitive_tree(value: Variant, path: String = "$") -> Dictionary
static func prepare_candidate(snapshot: Dictionary) -> Dictionary
static func is_compatible_bundle(bundle: Dictionary, compatibility: Dictionary) -> bool
static func derive_route_restore_context(snapshot: Dictionary) -> Dictionary
```

`build()` returns a detached primitive candidate exactly shaped as:

```json
{
  "schema_version": 2,
  "content_version": 1,
  "run_id": "run-uuid",
  "checkpoint_id": "run-uuid:42",
  "checkpoint_sequence": 42,
  "lifecycle": {
    "run_id": "run-uuid",
    "day": 3,
    "state": "PLAYING",
    "active_resolution_plan": null,
    "ending_plan": null
  },
  "route_id": "main",
  "active_app_id": null,
  "narrative_checkpoint": {},
  "gameplay": {
    "narrative_variables": {}
  },
  "contacts": {},
  "schedule": [],
  "dating": {},
  "applied_effect_transaction_ids": [],
  "applied_variable_transaction_ids": [],
  "audio_context": {}
}
```

`lifecycle` is the only location for `active_resolution_plan` and `ending_plan`. `active_app_id` is the only persisted desktop-host field; no app cache, scene instance, focus node, window geometry, or board state is allowed. Profile data is forbidden. Effect and variable transaction IDs use separate sorted unique arrays.

`gameplay` is the detached, schema-validated gameplay candidate returned by the GameState run facade; the fixture above shows its mandatory `narrative_variables` member, not permission for unregistered arbitrary keys. Task 1's state inventory and `test_game_state_facade_contract.gd` freeze every migrated gameplay field and its default before the old save whitelist is removed. `RunSnapshotSchema` rejects a gameplay key that neither that contract nor the narrative-variable registry owns.

The v2 default table is exact: `lifecycle.active_resolution_plan=null`, `lifecycle.ending_plan=null`, `active_app_id=null`, `gameplay.narrative_variables={}`, `applied_effect_transaction_ids=[]`, and `applied_variable_transaction_ids=[]`. These defaults are fresh detached values. `schema_version`, `content_version`, `run_id`, `checkpoint_id`, `checkpoint_sequence`, lifecycle `run_id/day/state`, `route_id`, `narrative_checkpoint`, the contracted non-narrative gameplay fields, `contacts`, `schedule`, `dating`, and `audio_context` remain required; their absence is not silently filled from a live session.

`derive_route_restore_context()` first calls `validate(snapshot)` and then returns a detached success value with exactly:

```json
{
  "run_id": "run-uuid",
  "day": 3,
  "lifecycle_state": "PLAYING",
  "active_app_id": null,
  "ending_plan": null,
  "contacts": {},
  "schedule": [],
  "dating": {}
}
```

Every value is copied from that one validated snapshot: `day`, `lifecycle_state`, and `ending_plan` come from `lifecycle`; `run_id`, `active_app_id`, `contacts`, `schedule`, and `dating` come from their same-named snapshot fields. The context is runtime-only and is never written beside the snapshot, so restore has no second persisted route-context authority. `route_id` remains the separate validated snapshot discriminator and is not duplicated inside the derived context.

- [ ] Create the initial registry exactly as:

```json
{
  "schema_version": 1,
  "variables": []
}
```

Until Dialogic issue `.8` intentionally adds registered IDs, `gameplay.narrative_variables` accepts only `{}`. Unknown keys reject; it is never an unrestricted variable store.

- [ ] **Step 4.4: Implement the discriminated save-document union**

- [ ] A save document has common keys `schema_version`, `kind`, `slot_id`, `save_reason`, `current_snapshot`, and `recovery_journal`. The only valid discriminator combinations are:

```json
[
  {"kind":"slot","slot_id":1,"save_reason":"manual"},
  {"kind":"quick","slot_id":null,"save_reason":"quick"},
  {"kind":"autosave","slot_id":null,"save_reason":"automatic"},
  {"kind":"autosave","slot_id":null,"save_reason":"day_start"},
  {"kind":"autosave","slot_id":null,"save_reason":"ending"},
  {"kind":"autosave","slot_id":null,"save_reason":"pre_board"},
  {"kind":"autosave","slot_id":null,"save_reason":"logout"}
]
```

The complete slot example is:

```json
{
  "schema_version": 2,
  "kind": "slot",
  "slot_id": 1,
  "save_reason": "manual",
  "current_snapshot": {
    "checkpoint_kind": "day_start",
    "snapshot": {
      "schema_version": 2,
      "content_version": 1,
      "run_id": "run-uuid",
      "checkpoint_id": "run-uuid:42",
      "checkpoint_sequence": 42,
      "lifecycle": {
        "run_id": "run-uuid",
        "day": 3,
        "state": "PLAYING",
        "active_resolution_plan": null,
        "ending_plan": null
      },
      "route_id": "main",
      "active_app_id": null,
      "narrative_checkpoint": {},
      "gameplay": {"narrative_variables": {}},
      "contacts": {},
      "schedule": [],
      "dating": {},
      "applied_effect_transaction_ids": [],
      "applied_variable_transaction_ids": [],
      "audio_context": {}
    }
  },
  "recovery_journal": []
}
```

Slots are integers `1..7`. `quick` and `autosave` require JSON `null` for `slot_id`; omitted discriminator fields reject after migration. Logout always writes the autosave path with `kind="autosave"` and `save_reason="logout"`; there is no fourth `logout` kind.

`SaveDocumentSchema` exposes exactly:

```gdscript
class_name SaveDocumentSchema
extends RefCounted

static func build(kind: StringName, slot_id: Variant, save_reason: StringName, current_bundle: Dictionary, journal: Array[Dictionary]) -> Dictionary
static func validate(document: Dictionary) -> Dictionary
static func prepare_candidate(document: Dictionary) -> Dictionary
```

`slot_id` is `Variant` deliberately: JSON null is represented by GDScript `null`, not by the public API sentinel `-1`. `build()` accepts an integer in `1..7` only for `kind=&"slot"`; for `kind=&"quick"` or `kind=&"autosave"` it accepts only `null` and writes that literal null. SaveManager converts its closed public quick/autosave locator to null before calling the schema. It never passes `-1` into a save document.

- [ ] Add this round-trip assertion to `test_save_document_schema.gd` using the validated `valid_day3.json` fixture:

```gdscript
func test_quick_document_build_round_trips_json_null_slot_id() -> void:
	var snapshot: Dictionary = JSON.parse_string(
		FileAccess.get_file_as_string("res://tests/fixtures/snapshots/valid_day3.json")
	)
	var bundle := {"checkpoint_kind": "day_start", "snapshot": snapshot}
	var built: Dictionary = SaveDocumentSchema.build(&"quick", null, &"quick", bundle, [])
	assert_true(built["ok"], JSON.stringify(built))
	var decoded: Variant = JSON.parse_string(JSON.stringify(built["value"]))
	assert_eq(typeof(decoded), TYPE_DICTIONARY)
	assert_true(decoded.has("slot_id"))
	assert_null(decoded["slot_id"])
	assert_true(SaveDocumentSchema.validate(decoded)["ok"])
	assert_false(SaveDocumentSchema.build(&"quick", -1, &"quick", bundle, [])["ok"])
	assert_false(SaveDocumentSchema.build(&"slot", null, &"manual", bundle, [])["ok"])
```

- [ ] **Step 4.5: Run schema tests and record the boundary**

- [ ] Run the focused suite. Expected GREEN for both schema validators and both surface inventories:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'save_schema_green' -LogName 'phase2r-save-schema.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/tooling/test_public_surface_inventory.gd','-gexit')
```

- [ ] Run `git diff --check`. Only after separate authority for this exact Task 4 boundary, run:

```powershell
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
$lifecycleBoundary = [string]::Join('', @(git log -1 --format=%H -- scripts/application/run/DayResolutionCoordinator.gd)).Trim()
if ($lifecycleBoundary -cne $expectedHead) { throw 'Task 4 must start from the exact closed-.4 lifecycle boundary.' }
$required = [ordered]@{
    'tests/unit/tooling/test_public_surface_inventory.gd'='M'
    'evidence/phase_2r/runtime/save_manager_required_surface.json'='A'
    'evidence/phase_2r/runtime/save_manager_surface.json'='A'
    'scripts/domain/run/RunSnapshotSchema.gd'='A'
    'scripts/infrastructure/save/SaveDocumentSchema.gd'='A'
    'data/manifests/narrative_variables.json'='A'
    'tests/unit/test_run_snapshot_schema.gd'='A'
    'tests/unit/test_save_document_schema.gd'='A'
    'tests/fixtures/snapshots/valid_day3.json'='A'
    'tests/fixtures/snapshots/invalid_day8.json'='A'
    'tests/fixtures/snapshots/invalid_object_shapes.json'='A'
}
$optionalUids = [ordered]@{
    'scripts/domain/run/RunSnapshotSchema.gd.uid'='A'
    'scripts/infrastructure/save/SaveDocumentSchema.gd.uid'='A'
    'tests/unit/test_run_snapshot_schema.gd.uid'='A'
    'tests/unit/test_save_document_schema.gd.uid'='A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'feat(save): define primitive run and save document schemas'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 4 commit boundary failed.' }
```

The staged-name output MUST contain only the eleven required literal paths plus the four explicitly listed optional UIDs that are present, for a maximum of fifteen paths. Omit only a UID that the isolated import did not generate; never stage another evidence or fixture path.

## Task 5: Implement monotonic CheckpointJournal state

**Beads:** `dwm-p2r.5`

**Files:**

- Create: `scripts/infrastructure/save/CheckpointJournal.gd`
- Create: `tests/unit/test_checkpoint_journal.gd`
- Create: `tests/fixtures/checkpoints/retention_40_lines.json`

**Interfaces:**

- Consumes: Task 4 `RunSnapshotSchema`; immutable bundle shape `{"checkpoint_kind": String, "snapshot": Dictionary}`.
- Produces: exact journal sequence allocation, candidate commit, disk projection, seed, capture, and rollback APIs below. Task 6 uses this as SaveManager's only in-memory checkpoint owner.

- [ ] **Step 5.1: Write sequence and retention RED tests**

- [ ] Tests cover an empty journal reset, failed preparation, failed commit, duplicate commit, run-ID mismatch, every accepted checkpoint kind including `line`, an unknown kind, 40 line checkpoints with interleaved semantic anchors, seed from disk, and replacement of a live Run-A journal with a prepared Run-B journal.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'checkpoint_journal_red' -LogName 'phase2r-red-checkpoint-journal.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_checkpoint_journal.gd','-gexit')
```

Expected RED: `CheckpointJournal must exist`.

- [ ] **Step 5.2: Implement allocation without sequence consumption on failure**

- [ ] `CheckpointJournal` exposes exactly:

```gdscript
class_name CheckpointJournal
extends RefCounted

func reset(run_id: String) -> Dictionary
func peek_next_sequence(run_id: String) -> Dictionary
func prepare_record(snapshot: Dictionary, checkpoint_kind: StringName) -> Dictionary
func prepare_reset_with_initial(snapshot: Dictionary, checkpoint_kind: StringName) -> Dictionary
func commit_prepared(candidate: Dictionary) -> Dictionary
func get_current_bundle() -> Dictionary
func get_bundles_for_disk() -> Array[Dictionary]
func prepare_seed(document: Dictionary, selected_bundle: Dictionary) -> Dictionary
func capture_state() -> Dictionary
func restore_state(backup: Dictionary) -> Dictionary
```

`peek_next_sequence()` returns `value={"checkpoint_sequence": int}` and does not reserve or mutate. `prepare_record()` requires the snapshot sequence to equal the current cursor plus one and returns a detached complete journal candidate. Only `commit_prepared()` advances the cursor. A build, validation, or commit failure therefore leaves the same next sequence available.

`prepare_reset_with_initial()` is the only API that may prepare replacing a nonempty journal with a new run. It accepts only `checkpoint_kind=&"day_start"` and a validated snapshot whose lifecycle is Day 1 `PLAYING`, whose `checkpoint_sequence` is `1`, and whose `checkpoint_id` is exactly `<run_id>:1`. It returns a detached candidate with that bundle as current, no earlier bundles, and next sequence `2`; it does not mutate the existing Run-A journal. `commit_prepared()` accepts that replacement candidate once, while `restore_state()` can reinstate the captured Run-A journal if a later storage or participant boundary fails.

`prepare_seed()` validates all retained bundles independently, excludes invalid candidates with diagnostics, verifies `selected_bundle` belongs to that document, and returns a detached journal candidate. The prepared journal contains only migrated bundles with the selected bundle's `run_id` and sequences less than or equal to the selected sequence. The selected whole bundle becomes current, every incompatible or later candidate is discarded, and the next sequence is exactly `selected_sequence + 1`.

- [ ] **Step 5.3: Accept line checkpoints and implement exact semantic-anchor retention**

- [ ] Accepted `checkpoint_kind` values are exactly `line` plus these permanent semantic-anchor kinds:

```text
day_start
timeline_start
timeline_complete
choice
variable_transaction
effect_transaction
safe_marker
scene_transition
pre_board
post_result
day_resolution_stage
```

Validation and retention are separate operations: `prepare_record()` accepts `line` and every listed semantic kind, rejects an unknown kind before mutation, and writes the field as `checkpoint_kind`. `line` is non-anchor history. Bundles are immutable, strictly sequence-ordered, and scoped to one `run_id`. `get_current_bundle()` returns the one current bundle. `get_bundles_for_disk()` returns only the ordered immutable earlier `recovery_journal`: every earlier semantic anchor plus the 32 greatest earlier `line` sequences, never the current bundle again. After 40 line checkpoints, lines 9–40 remain when all are earlier than the current semantic bundle. A corrupt neighbor is excluded with a diagnostic and cannot alter a valid bundle.

- [ ] The retention test creates sequences 1–40 with `checkpoint_kind=&"line"`, then sequence 41 with `checkpoint_kind=&"safe_marker"`. It asserts that sequence 41 is current, earlier line sequences are exactly `9..40`, the semantic bundle remains current rather than being counted in the line cap, and preparing `&"unknown"` leaves `capture_state()` byte-equal to the pre-call state.

- [ ] **Step 5.4: Run focused tests and record the boundary**

- [ ] Run. Expected GREEN: exact sequences, retention, seed, capture, and rollback pass:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'checkpoint_journal_green' -LogName 'phase2r-checkpoint-journal.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_checkpoint_journal.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd','-gexit')
```

- [ ] Run `git diff --check`. Only after separate authority for this exact Task 5 boundary, run:

```powershell
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
$task4Boundary = [string]::Join('', @(git log -1 --format=%H -- scripts/infrastructure/save/SaveDocumentSchema.gd)).Trim()
if ($task4Boundary -cne $expectedHead) { throw 'Task 5 must be the direct successor of the Task 4 schema boundary.' }
$required = [ordered]@{
    'scripts/infrastructure/save/CheckpointJournal.gd'='A'
    'tests/unit/test_checkpoint_journal.gd'='A'
    'tests/fixtures/checkpoints/retention_40_lines.json'='A'
}
$optionalUids = [ordered]@{
    'scripts/infrastructure/save/CheckpointJournal.gd.uid'='A'
    'tests/unit/test_checkpoint_journal.gd.uid'='A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'feat(save): add monotonic bounded checkpoint journals'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 5 commit boundary failed.' }
```

Only the two present optional UIDs may join the three required A paths.

## Task 6: Rewrite SaveManager around isolated storage and the real checkpoint port

**Beads:** `dwm-p2r.5`

**Files:**

- Modify: `autoload/SaveManager.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Create: `scripts/application/run/SaveManagerCheckpointPort.gd`
- Reuse unchanged from Task 3: `scripts/application/transaction/ApplicationMutationGate.gd`
- Reuse unchanged from Task 3: `scripts/application/transaction/FatalDiagnosticProjector.gd`
- Reuse and rerun from Task 3: `tests/unit/test_fatal_diagnostic_projector.gd`
- Modify: `scripts/ui/BackupApp.gd`
- Modify: `scripts/ui/SaveSlotRow.gd`
- Modify: `tests/unit/test_save_manager.gd`
- Create: `tests/integration/test_save_manager_journal.gd`
- Create: `tests/integration/test_save_capability.gd`
- Regenerate: `evidence/phase_2r/runtime/save_manager_surface.json`

**Interfaces:**

- Consumes: master `StorageAdapter`, including its crash-recoverable `remove(relative_path)` delete transaction; Tasks 4–5 schemas/journal; Task 3 checkpoint-port contract, the one already-created `ApplicationMutationGate`, and the unchanged shared `FatalDiagnosticProjector`; closed `.3` bootstrap/profile/storage initialization.
- Produces: the complete SaveManager target surface from Step 4.1; common `SaveManager.configure_mutation_gate(gate: Object) -> Dictionary`; real `SaveManagerCheckpointPort`, including pure `preview_checkpoint_id(run_id: String)` and narrow `configure_fatal_latch(gate: Object) -> Dictionary` injection of the same gate; isolated slot/quick/autosave I/O; exact save capability; real coordinator checkpoint wiring; a prepared New Game entry point that stays disabled until Task 7 supplies the production transaction participants.

- [ ] **Step 6.1: Write isolation, locator, and capability RED tests**

- [ ] Add this concrete invalid-locator/no-I/O RED test to `tests/unit/test_save_manager.gd` before rewriting SaveManager:

```gdscript
extends "res://addons/gut/test.gd"

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const TEMP_PATH := "res://tests/support/TemporaryStorage.gd"

func test_invalid_save_references_do_not_touch_storage() -> void:
	for path in [SAVE_MANAGER_PATH, STORAGE_PATH, TEMP_PATH]:
		assert_true(ResourceLoader.exists(path, "Script"), path + " must exist")
		if not ResourceLoader.exists(path, "Script"):
			return
	var root_result: Dictionary = load(TEMP_PATH).create("save_manager_invalid_locator")
	assert_true(root_result.get("ok", false), JSON.stringify(root_result))
	var root: String = root_result["value"]["path"].path_join("saves")
	var storage: RefCounted = load(STORAGE_PATH).new(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	assert_true(manager.initialize(storage)["ok"])
	assert_false(manager.save_exists(&"slot", 0))
	assert_false(manager.save_exists(&"quick", 1))
	assert_false(manager.save_exists(&"unknown", -1))
	assert_eq(manager.get_save_metadata(&"slot", 8)["code"],
		&"INVALID_SAVE_REFERENCE")
	assert_eq(manager.delete_slot(0)["code"], &"INVALID_SAVE_REFERENCE")
	assert_eq(DirAccess.get_files_at(root), PackedStringArray())
```

- [ ] Install a storage probe that fails a test if production `user://saves`, quicksave, autosave, or slot paths are constructed or opened. Every test injects a `StorageAdapter` rooted at the helper-provided `DWM_TEST_ROOT.path_join("save_manager").path_join("saves")`.

- [ ] Test every API family separately:

```text
save: slot 1..7, quick, automatic autosave, logout autosave
restore preparation: slot, quick, autosave
delete: slot, quick, autosave
existence: present, absent, invalid kind, invalid slot
metadata: present, absent, corrupt, stable sorted all-record list
```

For each valid delete locator, the RED/GREEN matrix starts from a document with a valid older `.bak`, fails the injected `FileOps` process after every delete marker/write/flush/removal boundary, reconstructs `JsonFileStorage`, calls `reconcile(relative_path, validator)`, and asserts `exists(relative_path)==false`. No restart may restore the final, `.next`, or `.bak` after a valid delete marker has been flushed. A malformed or hash-invalid delete marker fails closed and preserves artifacts for diagnosis.

- [ ] Add a real-port preview contract test before implementing `SaveManagerCheckpointPort`: dynamically load the future port, seed an isolated journal for `run-1`, capture journal/storage/probe counts, call `preview_checkpoint_id("run-1")`, and assert exact `value={"checkpoint_id":"run-1:<next-sequence>"}` with every captured value unchanged. Call `prepare()` immediately with valid inputs for the same run and assert its `checkpoint_id` is byte-equal to the preview. The preview path must record zero `RunSnapshotSchema.build`, `CheckpointJournal.prepare_record`, serialization, or storage calls. Empty/mismatched run IDs fail without mutation.

- [ ] Extend `test_save_manager.gd` and `test_save_manager_journal.gd` before implementation. A fresh real SaveManager must run the Task-3 common-gate valid/same/null/missing-signal/missing-each-method/replacement matrix with no initialization/storage/signal side effect. A fresh real checkpoint port must run the corresponding `configure_fatal_latch()` matrix. Configure both with one Task-3 `ApplicationMutationGate`, assert both returned IDs equal that object ID, and force each rollback/recovery failure with raw CommandResults containing StringName keys/values, a normalized-key collision, non-finite float, Object, Resource, Callable, packed bytes, and another packed array. Require every attempted recovery to finish in order; exact projector/validation or invariant fallback; one latch; one `guard_external(&"save_checkpoint_recovery")`; and the gate's exact retained `APPLICATION_FATAL`, never `INVALID_FATAL_FAILURE`, outer `fatal_rollback_failed`, latch success/conflict, or rejected data. A source scan rejects `ApplicationMutationGate.new()`, another `FatalDiagnosticProjector`, a local fatal Boolean, or any fallback latch/projector inside SaveManager and the checkpoint port. Expected RED is the first missing seam, not a fabricated gate double.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'save_manager_red' -LogName 'phase2r-red-save-manager.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_save_manager.gd,res://tests/integration/test_save_manager_journal.gd,res://tests/integration/test_save_capability.gd','-gexit')
```

Expected RED: legacy SaveManager exposes caller-supplied paths and lacks injected initialization/checkpoint APIs.

- [ ] **Step 6.2: Implement closed locators and metadata**

- [ ] Production relative names are exactly:

```text
autosave.json
quicksave.json
slot_1.json
slot_2.json
slot_3.json
slot_4.json
slot_5.json
slot_6.json
slot_7.json
```

No caller supplies a filename or path to a SaveManager public API. `ApplicationBootstrap` constructs `JsonFileStorage.new(selected_root.path_join("saves"))` and passes that `StorageAdapter` to `SaveManager.initialize(storage)`; isolated mode therefore stays under `DWM_TEST_ROOT`, while production uses the bootstrap-selected production root.

- [ ] Implement one private locator function used by every public API:

```text
_resolve_locator(kind, public_slot_id)
  slot: require integer 1..7; return {kind=slot, slot_id=int, relative_path="slot_N.json"}
  quick: require public_slot_id=-1; return {kind=quick, slot_id=null, relative_path="quicksave.json"}
  autosave: require public_slot_id=-1; return {kind=autosave, slot_id=null, relative_path="autosave.json"}
  otherwise return INVALID_SAVE_REFERENCE before calling any storage method

save_exists
  resolve locator; invalid returns false
  call storage.exists only with resolved relative_path

metadata/prepare/delete
  resolve locator; invalid returns frozen failure
  never accept, concatenate, or return a caller-controlled path
```

- [ ] `save_exists(kind, slot_id)` accepts only `&"slot"`, `&"quick"`, or `&"autosave"`; slot requires the configured range `1..7`, while quick/autosave require the default `-1`. Invalid arguments return `false` without reading storage. Metadata, save, restore, and delete APIs reject the same invalid combinations with `code=&"INVALID_SAVE_REFERENCE"` and perform no storage operation. Successful metadata has exactly this value:

```json
{
  "exists": true,
  "kind": "slot",
  "slot_id": 1,
  "save_reason": "manual",
  "run_id": "run-uuid",
  "day": 3,
  "state": "PLAYING",
  "checkpoint_id": "run-uuid:42"
}
```

An absent record uses `exists=false` and JSON `null` for the last five values. A corrupt record returns a recoverable failure from `get_save_metadata`; it is never reported as a valid existing save. `get_all_save_metadata()` returns nine `CommandResult` Dictionaries in fixed order—slots 1–7, quick, autosave—so one corrupt locator is a failure element and cannot erase valid sibling metadata.

- [ ] `delete_slot()`, `delete_quick_save()`, and `delete_autosave()` resolve only the closed relative names above and call the injected `StorageAdapter.remove(relative_path)` exactly once. SaveManager never directly removes the final, `.next`, `.bak`, or `.txn.json` artifacts. The storage contract writes, flushes, and re-reads a strict `<name>.txn.json` marker with `operation="delete"` and `stage="delete_marked"` before removing final/`.next`/`.bak`, removes the marker last, and makes `reconcile()` complete that deletion before considering backup recovery. A successful delete re-runs `reconcile()` and reports success only when the owned locator remains absent; a recoverable/fatal storage failure is returned unchanged and never converted to an absent-save success.

- [ ] **Step 6.3: Implement save capability and atomic document writes**

- [ ] Capability values are exactly:

```gdscript
# no lock
{"enabled": true, "silent": false, "deferred": false}
# minesweeper_board
{"enabled": false, "silent": true, "deferred": false}
# scene_transition
{"enabled": false, "silent": true, "deferred": true}
# restore
{"enabled": false, "silent": true, "deferred": false}
```

Repeated acquisition by the same owner is idempotent; another owner cannot release it. Scene-transition input records one pending save and fulfills it at the next stable checkpoint. Minesweeper-board input returns `{"ok":false,"code":&"save_locked","message":"","details":{"silent":true,"deferred":false}}`, emits no notification, and queues nothing.

`start_new_run()` is present at this boundary but returns `code=&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED"` without mutation until Task 7 installs the production participants and application mutation gate. It never falls back to direct `GameState.reset_game()`.

- [ ] Manual, quick, automatic, Day-start, ending, pre-board, and logout writes validate the complete document before serialization, call `StorageAdapter.write_atomic()`, re-read and strict-parse final bytes, validate them again, then prune only in-memory non-anchor line history excluded by the successful disk document. Failure preserves the prior final/backup and unpruned journal.

```text
_write_latest(locator, save_reason)
  reject while the owner-specific capability forbids this request
  get one detached current whole bundle and bounded disk journal
  SaveDocumentSchema.build(kind, Variant slot_id, reason, current, journal)
  validate candidate, canonical-serialize once, and retain exact bytes/hash
  storage.write_atomic(relative_path, bytes, SaveDocumentSchema validator)
  storage.read_text(relative_path), strict-parse, and validate exact locator/reason/current ID
  only after the verified re-read, commit the prepared in-memory prune candidate
  emit capability/save notifications only after both durable and memory commits
  on any failure return the storage/schema phase and leave journal/prior file unchanged

_delete(locator)
  storage.remove(relative_path) exactly once
  storage.reconcile(relative_path, validator)
  require storage.exists(relative_path)==false
  never inspect/remove .next/.bak/.txn.json directly
```

`save_for_logout()` returns a success with `value={"written":false,"save_reason":"logout"}` when no stable checkpoint exists. Otherwise it writes `autosave.json` with `kind="autosave"` and `save_reason="logout"`.

- [ ] **Step 6.4: Implement and wire the real checkpoint port**

- [ ] Implement SaveManager's Task-3 common `configure_mutation_gate()` contract before any guarded save command. Implement `SaveManagerCheckpointPort.configure_fatal_latch(gate: Object) -> Dictionary` with the exact validation, first/same/replacement behavior, error codes, identity result, and zero-side-effect rules of `DayResolutionCoordinator.configure_fatal_latch()`. The port retains only that injected object and calls only `latch_fatal()`/`is_fatal_latched()` plus the post-latch authoritative `guard_external()`; it cannot construct or discover a gate. Its operational configuration fails with `fatal_latch_not_configured` until this succeeds. Unit and integration setup pass one Task-3 gate instance to SaveManager, the checkpoint port, GameState, and the coordinator and require all four returned IDs to match.

- [ ] `SaveManagerCheckpointPort` implements the five checkpoint methods from Task 3, including `preview_checkpoint_id(run_id: String) -> Dictionary`. `checkpoint_inputs` has exactly `snapshot_input`, `dialogic_checkpoint`, `route_id`, `active_app_id`, `audio_context`, and `content_version`. `preview_checkpoint_id()` validates the nonempty run ID, calls only `CheckpointJournal.peek_next_sequence(run_id)`, and returns exactly the master CommandResult success with `value={"checkpoint_id":"<run_id>:<sequence>"}` and an empty receipt. It consumes no sequence, builds/prepares nothing, and performs no storage operation. Its immediately following `prepare()` for the same run with no intervening commit must return the same ID. `prepare()` calls `CheckpointJournal.peek_next_sequence()`, `RunSnapshotSchema.build()`, and `CheckpointJournal.prepare_record()` without mutation. Its candidate contains the prepared journal, resulting checkpoint ID, and optional prepared autosave document/storage backup descriptor.

The storage backup descriptor is exactly `{"relative_path": String, "existed": bool, "validated_text": String|null, "sha256": String|null}` and is captured through the injected `StorageAdapter` before an autosave commit. `commit()` writes the prepared disk document first, commits the journal candidate second, and returns the checkpoint ID. `rollback()` restores the captured journal, atomically rewrites the validated prior bytes when `existed=true`, or removes only the just-created closed relative path when `existed=false`. Failure injection covers prior-file present/absent and every rollback I/O boundary. Any failed recovery completes every required attempt, preserves exact raw order, projects/validates `source="save_checkpoint"`, the original phase, `code="fatal_rollback_failed"`, primitive run/checkpoint context, and exact diagnostic envelopes through the unchanged Task-3 projector, substitutes only its invariant fallback, calls the retained Task-3 gate once, calls `guard_external(&"save_checkpoint_recovery")`, and returns that exact retained `APPLICATION_FATAL` while the checkpoint remains fatally locked.

```text
SaveManagerCheckpointPort.preview_checkpoint_id(run_id)
  validate nonempty run_id against the configured journal
  journal.peek_next_sequence(run_id) without mutation
  return only value={checkpoint_id="<run_id>:<sequence>"}; build/write nothing

SaveManagerCheckpointPort.prepare(inputs, kind, disk_write)
  validate exact input/disk_write keys and capture no live aliases
  journal.peek_next_sequence(run_id)
  derive the same ID a prior preview returned when journal state has not changed
  RunSnapshotSchema.build(..., returned sequence)
  journal.prepare_record(snapshot, checkpoint_kind)
  when disk_write=none, return journal candidate + checkpoint ID
  when autosave, build/validate the projected autosave from that prepared journal and
    capture the validated old/absent autosave descriptor without writing

commit(candidate)
  reject a candidate not issued by this configured port or stale against live journal
  if autosave candidate: write_atomic, re-read exact bytes, and validate first
  journal.commit_prepared second
  return checkpoint ID only after both succeed

rollback(backup)
  restore journal backup first when journal commit was attempted
  restore validated prior autosave bytes through write_atomic when it existed;
  otherwise remove the created autosave through the delete-marker protocol
  reconcile and validate the recovered disk winner
  any rollback failure finishes every recovery attempt and projects/validates its exact
    ordered diagnostic envelopes with source=save_checkpoint, original phase,
    code=fatal_rollback_failed, and primitive run/checkpoint context; use only the shared
    invariant fallback on projector failure; latch once; guard_external(save_checkpoint_recovery);
    return the exact retained APPLICATION_FATAL
```

- [ ] Task 6 implements the `configure_day_resolution` adapter without running final startup: it receives the already-retained bootstrap gate, configures `SaveManagerCheckpointPort.configure_fatal_latch()` and `DayResolutionCoordinator.configure_fatal_latch()` with that exact object, requires both identity results to equal the bootstrap gate ID, then configures the production coordinator with `GameStateDayResolutionPort` and `SaveManagerCheckpointPort`. It rejects any missing seam or identity mismatch and never references `FakeCheckpointPort`. Task 7 invokes this adapter in final mode only after SaveManager initialization and participant setup; Task 6 tests it with test-owned earlier-stage adapters and no production storage.

- [ ] `BackupApp` and `SaveSlotRow` disable only save controls from `save_capability_changed`. They display no unavailable message for Minesweeper. The global quick-save input is ignored under that lock.

- [ ] **Step 6.5: Run focused tests and regenerate the inventory**

- [ ] Run. Expected GREEN: all locators, document kinds/reasons, journal transactions, pure preview/following-prepare checkpoint-ID equality, transition deferral, silent board lock, logout behavior, and production-path probes pass:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'save_manager_green' -LogName 'phase2r-save-manager.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_application_mutation_gate.gd,res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_save_manager.gd,res://tests/unit/test_checkpoint_journal.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/integration/test_save_manager_journal.gd,res://tests/integration/test_save_capability.gd,res://tests/unit/test_day_resolution_coordinator.gd','-gexit')
```

- [ ] Regenerate `save_manager_surface.json`; every old method/signal must have a proved disposition and no production consumer may call a raw path method.

- [ ] Run `git diff --check`. Only after separate authority for this exact Task 6 boundary, run:

```powershell
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
$task5Boundary = [string]::Join('', @(git log -1 --format=%H -- scripts/infrastructure/save/CheckpointJournal.gd)).Trim()
if ($task5Boundary -cne $expectedHead) { throw 'Task 6 must be the direct successor of the Task 5 journal boundary.' }
$required = [ordered]@{
    'autoload/SaveManager.gd'='M'
    'autoload/ApplicationBootstrap.gd'='M'
    'scripts/application/run/SaveManagerCheckpointPort.gd'='A'
    'scripts/ui/BackupApp.gd'='M'
    'scripts/ui/SaveSlotRow.gd'='M'
    'tests/unit/test_save_manager.gd'='M'
    'tests/integration/test_save_manager_journal.gd'='A'
    'tests/integration/test_save_capability.gd'='A'
    'evidence/phase_2r/runtime/save_manager_surface.json'='M'
}
$optionalUids = [ordered]@{
    'scripts/application/run/SaveManagerCheckpointPort.gd.uid'='A'
    'tests/integration/test_save_manager_journal.gd.uid'='A'
    'tests/integration/test_save_capability.gd.uid'='A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'refactor(save): isolate atomic save documents and checkpoint persistence'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 6 commit boundary failed.' }
```

The exact gate stages no existing UID and no user-owned UI path outside `BackupApp.gd`/`SaveSlotRow.gd`; only three present new UIDs may join the required set.

## Task 7: Implement explicit migrations and six-participant restore

**Beads:** `dwm-p2r.5`

**Files:**

- Create: `scripts/infrastructure/save/SaveMigrations.gd`
- Create: `scripts/domain/ending/DatingEndingRules.gd`
- Create: `scripts/application/restore/RunRestoreParticipant.gd`
- Create: `scripts/application/restore/ProfileRestoreParticipant.gd`
- Create: `scripts/application/restore/LocalizationRestoreParticipant.gd`
- Create: `scripts/application/restore/AudioRestoreParticipant.gd`
- Create: `scripts/application/restore/RouteRestoreParticipant.gd`
- Create: `scripts/application/restore/NarrativeRestoreParticipant.gd`
- Reuse unchanged from Task 3: `scripts/application/transaction/ApplicationMutationGate.gd`
- Reuse unchanged from Task 3: `scripts/application/transaction/FatalDiagnosticProjector.gd`
- Reuse and rerun from Task 3: `tests/unit/test_application_mutation_gate.gd`
- Reuse and rerun from Task 3: `tests/unit/test_fatal_diagnostic_projector.gd`
- Create: `tests/support/FakeRestoreParticipant.gd`
- Create: `tests/support/RestoreCallLog.gd`
- Create: `tests/unit/test_save_migrations.gd`
- Create: `tests/unit/test_dating_ending_rules_migration.gd`
- Create: `tests/unit/test_restore_participants.gd`
- Extend: `tests/unit/test_game_state_facade_contract.gd`
- Extend: `tests/unit/test_application_bootstrap_profile_stage.gd`
- Create: `tests/integration/test_restore_transaction.gd`
- Create: `tests/integration/test_restore_production_adapters.gd`
- Create: `tests/integration/test_restore_mutation_gate.gd`
- Create: `tests/integration/test_new_run_transaction.gd`
- Create: `tests/fixtures/saves/v1_minimal_slot.json`
- Create: `tests/fixtures/saves/v2_future_schema.json`
- Create: `tests/fixtures/saves/day8_group_synchronized.json`
- Create: `tests/fixtures/saves/day8_ending_non_group.json`
- Create: `tests/fixtures/saves/day8_playing_with_day7_journal.json`
- Create: `tests/fixtures/saves/day8_group_invalid_with_day7_journal.json`
- Create: `tests/fixtures/saves/day8_no_fallback.json`
- Create: `tests/fixtures/saves/reversed_pair_tokens.json`
- Create: `tests/fixtures/saves/unknown_ending_id.json`
- Modify: `autoload/GameState.gd`
- Modify: `autoload/SceneRouter.gd`
- Modify: `autoload/DialogicBridge.gd` only for the minimal participant seam; exact narrative manifests arrive in `.8`
- Modify: `autoload/ProfileManager.gd`
- Modify: `autoload/LocalizationManager.gd`
- Modify: `autoload/AudioManager.gd`
- Modify: `autoload/InputManager.gd`
- Modify: `autoload/ApplicationBootstrap.gd`
- Modify: `autoload/SaveManager.gd`
- Modify: `scripts/ui/MenuScene.gd`

**Interfaces:**

- Consumes: Tasks 4–6 schemas, journal, storage, SaveManager, and the unchanged Task-3 `ApplicationMutationGate`/`FatalDiagnosticProjector`; the Task-3 GameState/coordinator and Task-6 SaveManager/checkpoint-port gate seams; closed `.3` ProfileManager/LocalizationManager/AudioManager; closed `.4` GameState lifecycle; the approved ending migration table.
- Produces: explicit schema-v1-to-v2 and legacy migrations; six concrete restore participants; Plan 02's existing `construct_and_inject_mutation_gate` stage completed with a private factory for the already-created Task-3 gate class and exact ordered `FINAL_GATE_TARGETS`; one verified gate identity across all eight final targets plus the coordinator/checkpoint services; the remaining production `SceneRouter.configure_mutation_gate(gate: Object)` seam and external-mutation fence; `SaveManager.configure_restore_participants({run,profile,localization,audio,route,narrative})`; private `_prepare_bundle_with_all_participants()` over those same six registered participants; greatest-earlier compatible whole-bundle restore; atomic journal replacement/rollback; atomic Run-A-to-new-Run-B creation.

- [ ] **Step 7.1: Write explicit schema and legacy migration RED fixtures**

- [ ] `SaveMigrations` exposes exactly:

```gdscript
class_name SaveMigrations
extends RefCounted

static func migrate_document(raw: Dictionary, expected_locator: Dictionary) -> Dictionary
static func migrate_snapshot_v1_to_v2(snapshot: Dictionary) -> Dictionary
static func migrate_legacy_day8(snapshot: Dictionary, compatible_day7_bundles: Array[Dictionary]) -> Dictionary
static func migrate_ending_id(ending_id: String) -> Dictionary
static func migrate_pair_token(token: String) -> Dictionary
```

`expected_locator` is exactly `{"kind": "slot", "slot_id": 1}`, `{"kind": "quick", "slot_id": null}`, or `{"kind": "autosave", "slot_id": null}` and comes from the requested SaveManager API, never live gameplay state.

- [ ] Schema dispatch is explicit:

```text
schema_version absent or 1 -> run v1_to_v2 exactly once
schema_version 2           -> validate without migration
schema_version > 2         -> unsupported_future_schema
schema_version < 1         -> unsupported_legacy_schema
non-integral/non-number    -> invalid_schema_version
```

The v1-to-v2 step moves legacy top-level `active_day_resolution_plan` and `ending_plan` into `lifecycle`, renames `applied_transaction_ids` to `applied_effect_transaction_ids`, adds `applied_variable_transaction_ids=[]`, adds `active_app_id=null`, and adds `gameplay.narrative_variables={}`. It fills only these declared schema defaults; it never reads the current run, profile, route, locale, audio, or journal. Missing required IDs and malformed present values still reject.

`migrate_document()` succeeds with exactly `value={"document": Dictionary, "legacy_profile_patch_input": Dictionary, "migration_receipts": Array[Dictionary]}`. Legacy `settings`, `audio_state`, `seen_endings`, visited-line history, and input mappings are removed from the run candidate and copied into `legacy_profile_patch_input={"legacy_run_state": Dictionary, "legacy_input_mappings": Dictionary}`. `ProfileRestoreParticipant.prepare()` passes only that detached input to `ProfileManager.prepare_legacy_profile_patch()`; migration never writes `profile.json`, and a normal v2 save uses two empty Dictionaries here.

- [ ] Ending migration accepts only these mappings; all twelve canonical values also pass through unchanged:

```json
{
  "alone": "ending.alone",
  "priscilla.sweet": "ending.priscilla.sweet",
  "priscilla.dark": "ending.priscilla.dark",
  "priscilla.true": "ending.priscilla.true",
  "lavinia.sweet": "ending.lavinia.sweet",
  "lavinia.dark": "ending.lavinia.dark",
  "lavinia.true": "ending.lavinia.true",
  "sylvia.sweet": "ending.sylvia.sweet",
  "sylvia.dark": "ending.sylvia.dark",
  "sylvia.true": "ending.sylvia.true",
  "sylvia.special": "ending.sylvia.special",
  "priscilla_lavinia": "ending.priscilla_lavinia",
  "lavinia_priscilla": "ending.priscilla_lavinia"
}
```

Unknown IDs reject recoverably. Pair-token migration changes `lavinia_priscilla` to `priscilla_lavinia` in missed-group counts, inter-friend state, invitation state, route context, and gallery data without summing counts or duplicating history when both keys exist.

- [ ] Day-8 fixtures cover every approved row:

```text
group primary + sufficient synchronized Day-7 inputs
  -> recompute non-group primary, group epilogue, day 7
valid ENDING/COMPLETED + non-group primary
  -> day 7 and preserve lifecycle/plan
PLAYING Day 8 + compatible Day-7 bundle
  -> greatest compatible Day-7 whole bundle
invalid/group primary + compatible Day-7 bundle
  -> greatest compatible Day-7 whole bundle
no valid plan and no compatible Day-7 bundle
  -> reject with live state unchanged
```

Reconstruction never grants an unseen gallery unlock. Create the pure ending-selection core here so migration can recompute a synchronized primary; issue `.7` extends this same `DatingEndingRules.gd` with Hospital/playback behavior and never creates a second resolver.

- [ ] Run:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'save_migrations_red' -LogName 'phase2r-red-save-migrations.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_save_migrations.gd,res://tests/unit/test_dating_ending_rules_migration.gd','-gexit')
```

Expected RED: `SaveMigrations must exist`; after creation, unsupported future schema and Day-8 table rows fail until explicitly implemented.

- [ ] **Step 7.2: Implement the exact participant contract**

- [ ] Before wiring the already-created Task-3 production gate into final bootstrap, extend `tests/unit/test_application_bootstrap_profile_stage.gd` with these exact final-mode expectations. Reuse its Plan-02-owned test target map and stage call log; add SaveManager, GameState, and SceneRouter doubles to that map without adding a production public injection API:

```gdscript
const EXPECTED_FINAL_GATE_TARGETS: Array[StringName] = [
	&"SaveManager", &"GameState", &"ProfileManager", &"LocalizationManager",
	&"AudioManager", &"SceneRouter", &"DialogicBridge", &"InputManager",
]

const EXPECTED_FINAL_STAGE_ORDER: Array[StringName] = [
	&"select_and_prove_roots",
	&"construct_and_inject_mutation_gate",
	&"initialize_profile",
	&"initialize_saves",
	&"initialize_localization",
	&"initialize_input",
	&"initialize_accessibility",
	&"initialize_audio",
	&"initialize_dialogic_bridge",
	&"configure_restore_participants",
	&"configure_day_resolution",
	&"configure_minesweeper_rounds",
	&"publish_application_ready",
]
```

Add named cases `test_final_uses_existing_gate_stage_before_profile`, `test_final_gate_targets_are_exact_and_share_one_identity`, `test_final_gate_rejects_each_incomplete_gate_before_any_target`, `test_final_gate_rejects_missing_configure_method_at_each_target`, `test_final_gate_failure_at_each_target_stops_before_profile`, `test_final_gate_rejects_wrong_retained_identity_at_each_target`, and `test_new_final_targets_expose_the_common_gate_contract`. A success case supplies test-owned successful adapters for later Plan-05/06 stages, then requires the exact `EXPECTED_FINAL_STAGE_ORDER`, one production factory call, the exact ordered target list, eight target calls, and eight `value.gate_instance_id` values equal to the one positive constructed-object ID. It must observe no `missing_production_gate_factory`, no development readiness, and exactly one final readiness. Those later-stage doubles prove the stage runner only; they do not claim the later production adapters exist.

For each of the eight target ordinals, run three isolated cases: the selected target lacks `configure_mutation_gate`; it returns a frozen failure; or it returns success with a different `value.gate_instance_id`. Earlier targets receive exactly one call, the selected target receives at most one call, later targets receive zero calls, and every initializer/storage adapter receives zero calls. Separately return a gate missing `capability_changed` and each of the eight required methods in turn; no target may be called. Re-run Task 3's real GameState and Task 6's real SaveManager matrices unchanged; a fresh real SceneRouter runs the same valid/same/null/missing-signal/missing-each-method/replacement matrix. All three prove configuration causes no storage, run mutation, routing, signal, input, or initialization side effect.

- [ ] Run the production-bootstrap RED test before adding the final factory adapter or SceneRouter seam; the Task-3 gate script must already be present and GREEN:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'production_gate_bootstrap_red' -LogName 'phase2r-red-production-gate-bootstrap.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_application_mutation_gate.gd,res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_application_bootstrap_profile_stage.gd,res://tests/unit/test_game_state_facade_contract.gd','-gexit')
```

Expected RED: the final gate stage returns `missing_production_gate_factory`, or SceneRouter lacks the remaining common configuration seam. A missing/changed Task-3 gate file, parse error, production-path access, profile initialization, or failure in a later stage is not acceptable RED.

- [ ] Reuse `scripts/application/transaction/ApplicationMutationGate.gd` and `FatalDiagnosticProjector.gd` plus both Task-3 unit tests byte-for-byte before final wiring. The one `git diff --quiet HEAD -- scripts/application/transaction/ApplicationMutationGate.gd scripts/application/transaction/FatalDiagnosticProjector.gd tests/unit/test_application_mutation_gate.gd tests/unit/test_fatal_diagnostic_projector.gd` check must return `0`; exit `1` is forbidden staged/unstaged drift and any other exit is a Git error. Rerun both tests. Task 7 adds no gate/projector method, owner, reset path, alternate factory class, second projector, or second fatal state.

Do not create or reorder a bootstrap stage. Modify only Plan 02's existing `construct_and_inject_mutation_gate` adapter. Its final branch replaces the temporary `missing_production_gate_factory` result with this private production factory; the debug-development factory branch and `test_manual` behavior remain byte-for-byte unchanged:

```gdscript
# private additions in autoload/ApplicationBootstrap.gd
const APPLICATION_MUTATION_GATE_SCRIPT := preload(
	"res://scripts/application/transaction/ApplicationMutationGate.gd"
)

func _create_production_mutation_gate() -> Object:
	return APPLICATION_MUTATION_GATE_SCRIPT.new()
```

In `MODE_FINAL`, the existing gate stage invokes `_create_production_mutation_gate()` exactly once, validates `capability_changed` plus all eight frozen gate methods, and consumes the already-declared `FINAL_GATE_TARGETS` without copying, sorting, extending, or redefining it. The order remains exactly SaveManager → GameState → ProfileManager → LocalizationManager → AudioManager → SceneRouter → DialogicBridge → InputManager. The stage calls each target's exact `configure_mutation_gate(gate: Object) -> Dictionary` once and accepts only the frozen success `{"ok":true,"code":&"ok","value":{"gate_instance_id":int,"already_configured":bool},"receipt":{}}`. Each `value.gate_instance_id` must equal `gate.get_instance_id()` and all prior returned IDs; the outer receipt remains empty. Missing/incomplete gate objects, a missing target method, any target failure, a mismatched identity, or an unexpected target is one fatal startup result. It stops inside the existing gate stage, invokes no initializer or later stage, emits no readiness, and leaves input disabled. Partial injection is never undone by replacement.

On success, `get_startup_state().gate_injection` contains `factory_invocation_count=1`, the one positive gate ID, the exact eight-name target array, and eight parallel copies of that ID. This is the only final-mode resolution of Plan 02's `missing_production_gate_factory`; `MODE_FINAL` still rejects and never reads `configure_debug_mutation_gate_factory()`. No second production factory, fallback fake, gate stage, target list, or public factory setter is permitted.

GameState's Task-3 and SaveManager's Task-6 common seams remain unchanged. SceneRouter implements that same common contract now: require a non-null object with `capability_changed` and all of `acquire`, `release`, `guard_external`, `is_active`, `get_active_owner`, `is_internal_owner_active`, `latch_fatal`, and `is_fatal_latched`; accept the first compatible instance; accept that identical instance idempotently; reject a different instance with `mutation_gate_already_configured`; reject null/incomplete input with `invalid_mutation_gate`; and return the exact success with `already_configured=false` then `true`. The retained object is private. Configuration performs no I/O, initialization, route/run/profile mutation, signal connection/emission, input change, or cross-manager call.

Every external mutation command on all eight managers calls `guard_external()` before validation or mutation, so a fatal latch is always reported as `APPLICATION_FATAL` rather than `TRANSACTION_ACTIVE` or a domain error. The six participant adapters use only their owners' silent transaction seams and assert `is_internal_owner_active(&"restore")` or `is_internal_owner_active(&"new_run")`; they never create a bypass gate. SaveManager's prepare methods remain pure and unlocked, but commit revalidates the prepared transaction immediately after acquiring the gate. At `configure_day_resolution`, Bootstrap passes that same gate to the Task-3 coordinator and Task-6 checkpoint-port narrow seams and rejects either ID unless it equals the one final gate ID. Restore, new-run, DayResolution/checkpoint recovery, and later Minesweeper adapters all receive the same injected gate object; none may construct a second gate or retain a separate fatal Boolean.

`test_application_mutation_gate.gd` and `test_fatal_diagnostic_projector.gd` remain the exhaustive pure matrices. `test_game_state_facade_contract.gd` reruns the GameState common configuration/guard behavior without changing the Task-3 contract. `test_restore_mutation_gate.gd` is now the production identity/integration matrix: all eight configured real owners plus DayResolutionCoordinator and SaveManagerCheckpointPort retain the one factory-created gate ID; every DayResolution/checkpoint/restore/new_run raw recovery result is projected and independently validated; a representative public mutation on every owner and each fatal path's stable final guard returns the same retained `APPLICATION_FATAL`; and InputManager stays blocked after every synthesized release/enabled event. It rejects `INVALID_FATAL_FAILURE`, raw-result leakage, a latch intermediate result, another projector identity, and any Plan04 `planned_future` call.

InputManager maps `capability_changed` to one global user-input block: while disabled it disables GUI input on the root viewport and consumes incoming `_input` events before scene callbacks; when the exact nonfatal gate token releases it restores the captured prior input setting. An `APPLICATION_FATAL` capability permanently suppresses restoration for that process even if a stale enabled event is injected. This is an input fence, not a scene-tree pause, so awaited route readiness/finalization continues to process. On-tree tests must prove buttons, `_unhandled_input`, quick-save shortcuts, route commands, and manager mutation commands do nothing during both an awaited apply and an awaited rollback, then prove a fatal latch keeps all of them blocked and makes every guarded public command return `APPLICATION_FATAL`.

- [ ] `configure_restore_participants()` accepts a Dictionary with exactly these keys, no omissions or extras:

```gdscript
{
	"run": RunRestoreParticipant,
	"profile": ProfileRestoreParticipant,
	"localization": LocalizationRestoreParticipant,
	"audio": AudioRestoreParticipant,
	"route": RouteRestoreParticipant,
	"narrative": NarrativeRestoreParticipant,
}
```

Every participant implements this exact common interface:

```gdscript
func prepare(input: Dictionary) -> Dictionary
func capture() -> Dictionary
func apply_silent(plan: Dictionary) -> Dictionary
func rollback_silent(backup: Dictionary) -> Dictionary
func finalize() -> Dictionary
```

The run participant additionally exposes the one New Game preparation seam:

```gdscript
func prepare_new_run(run_id: String) -> Dictionary
```

It delegates to `GameState.prepare_new_run_snapshot_input(run_id)` and returns exactly `value={"snapshot_input": Dictionary, "run_plan": Dictionary}`. It is pure; `run_plan` is accepted by the same `apply_silent()` used for restore. No other participant gains a New Game-specific API.

SaveManager supplies these exact participant inputs from the one selected bundle and migration result:

```gdscript
{"snapshot": Dictionary} # run
{"legacy_profile_patch_input": Dictionary} # profile
{"locale_id": String} # localization, from the prepared profile candidate
{"preferences": Dictionary, "audio_context": Dictionary} # audio
{"route_id": String, "route_context": Dictionary} # route; context derived from the selected snapshot
{"narrative_checkpoint": Dictionary, "content_version": int} # narrative
```

SaveManager has one private, pure compatibility seam and no configurable compatibility provider:

```gdscript
func _prepare_bundle_with_all_participants(
	bundle: Dictionary,
	migrated_document: Dictionary
) -> Dictionary
```

The helper validates that `bundle` is one recursively detached whole bundle from `migrated_document`; derives all six inputs above from only that bundle plus that document's detached migration output; and calls the already-registered participants' pure `prepare(input)` methods in exact `run → profile → localization → audio → route → narrative` order. Localization uses only the prepared profile candidate's language; audio uses only that same candidate's preferences plus the bundle audio context; route context comes only from `RunSnapshotSchema.derive_route_restore_context(bundle.snapshot)`; narrative uses only that bundle's checkpoint/content version. It performs no capture/apply/finalize, I/O, signal, live getter, registry replacement, or global lookup.

Success is exactly `value={"bundle":Dictionary,"journal_seed":Dictionary,"participant_plans":{"run":Dictionary,"profile":Dictionary,"localization":Dictionary,"audio":Dictionary,"route":Dictionary,"narrative":Dictionary}}`, with every value detached. A typed content incompatibility from any participant returns recoverable `BUNDLE_CONTENT_INCOMPATIBLE` with exact `details={"participant_id":String,"cause":Dictionary,"checkpoint_sequence":int}` and no candidate. Malformed bundle/document structure, unsupported/future schema, primitive violation, or migration failure uses the already-frozen structural failure and is never relabeled as content incompatibility.

Route success contains `value={"route_ready_token": {"route_id": String, "layout_id": String, "generation": int}}`. SaveManager adds that exact token to the narrative apply plan; the narrative adapter validates all three fields against the live ready layout before touching Dialogic.

`prepare()` and `capture()` return detached values and emit nothing. `apply_silent`, `rollback_silent`, and `finalize` emit no domain signals. The adapters wrap the production owners rather than copying their state:

```text
run          -> GameState
profile      -> ProfileManager legacy profile patch only
localization -> LocalizationManager, derived from prepared profile language
audio        -> AudioManager, derived from prepared profile preferences plus snapshot audio_context
route        -> SceneRouter semantic route and target-layout readiness
narrative    -> DialogicBridge semantic checkpoint
```

`SceneRouter` gains semantic capture/prepare/apply/rollback methods that suppress ordinary route signals during restore and can restore its prior semantic route. `RouteRestoreParticipant.apply_silent()` does not return success until the registered target scene reports its narrative layout ready. `NarrativeRestoreParticipant.apply_silent()` rejects a missing route-ready token and therefore cannot run early.

SaveManager obtains `route_context` only by calling `RunSnapshotSchema.derive_route_restore_context(selected_snapshot)` after migration and validation. It passes the returned detached context and that snapshot's `route_id` to the route participant. No migration, adapter, or live-state getter supplies or patches route context, and no save document contains a second `route_context` field.

At `.5`, the registered `NarrativeRestoreParticipant.prepare()` returns recoverable `NARRATIVE_CONTENT_UNAVAILABLE` for every nonempty playhead because exact timeline manifests do not yet exist; the private helper maps that cause to `BUNDLE_CONTENT_INCOMPATIBLE` and tries an earlier whole bundle. Empty/no-playhead checkpoints and the participant transaction are fully testable. Plan 05 modifies this same class/registered `narrative` participant to use the manifest-aware implementation, activating nonempty selection without a second provider, configuration seam, or global lookup. Record that scoped limitation/handoff on both Beads issues.

- [ ] **Step 7.3: Prepare one whole compatible bundle without mutation**

- [ ] Each public `prepare_restore_*()` performs exactly:

```text
read the closed relative locator
strict-parse JSON
migrate the document and every retained bundle independently
validate outer document/current structure; exclude independently invalid retained journal entries with diagnostics
order structurally valid candidates as current first, then earlier journal bundles by descending checkpoint_sequence
for each candidate call _prepare_bundle_with_all_participants(candidate, migrated_document)
on BUNDLE_CONTENT_INCOMPATIBLE try the next candidate without mutation
on success select that candidate and return its journal seed plus all six prepared plans
if all candidates are content-incompatible return NO_COMPATIBLE_BUNDLE with ordered causes
on structural corruption/future schema return the frozen structural failure without compatibility fallback
```

Compatibility requires gameplay state, route ID, timeline ID, marker or line ID, schema version, and content version from the same bundle. The selected recovery sequence must be less than the current snapshot sequence. No field may be combined across bundles.

`prepare_restore_*()` validates defaults using only the migrated snapshot. Missing optional fields use the declared v2 defaults; they never inherit stale live state. Malformed nested types, unsupported future versions, arbitrary paths, or no compatible bundle return a recoverable failure and leave all live participants and SaveManager journal untouched. Unknown registered content IDs are typed content incompatibilities only after structural/schema validation, so they may select the greatest earlier compatible whole bundle.

- [ ] Extend `test_restore_transaction.gd` and `test_restore_production_adapters.gd` only through public `prepare_restore_*()` calls; no test invokes the private helper. Use participant call logs to prove current-then-descending order, all six plans come from one bundle, a late narrative incompatibility mutates nothing and tries the next bundle, highest compatible sequence wins, structural/future-schema failure never falls back, all-incompatible returns ordered causes, and `.5` nonempty narrative is unavailable while an earlier empty checkpoint can win. Plan 05 reruns the same public tests after manifest-aware narrative preparation and flips the nonempty case to the current compatible bundle.

- [ ] **Step 7.4: Commit or roll back participants and journal as one transaction**

- [ ] `commit_prepared_restore()` may be awaited and executes exactly:

```text
acquire SaveManager owner=restore lock
acquire ApplicationMutationGate owner=restore and disable user input
revalidate the prepared transaction against the selected document and configured participants
capture SaveManager CheckpointJournal
capture run, profile, localization, audio, route, narrative
apply_silent run
apply_silent profile
apply_silent localization
apply_silent audio
await apply_silent route until target narrative layout is ready
apply_silent narrative with the route-ready token
commit the prepared CheckpointJournal seed
finalize run, profile, localization, audio, route, narrative without domain signals
release ApplicationMutationGate with the exact token and restore prior input capability
release SaveManager restore lock
emit exactly one run_restored(checkpoint_id, route_id)
```

On any application, route-readiness, narrative, journal-commit, or finalize failure, restore the journal backup first if its commit was attempted, then call `rollback_silent()` on applied participants in exact reverse order: narrative, route, audio, localization, profile, run. Both locks and the input block remain held across every awaited rollback. Release the mutation/input gate first and the restore lock second only after rollback succeeds; emit no historical mutation signal and no `run_restored` signal. If any rollback or release recovery fails, finish every required recovery attempt and record one exact raw diagnostic `{owner_id,operation,result}` per attempt in execution order. Project/validate `source="restore"`, the original phase, `code="fatal_rollback_failed"`, primitive selected run/checkpoint context, and that array through the unchanged Task-3 `FatalDiagnosticProjector`; substitute only its invariant fallback; call `latch_fatal()` once on the already-injected gate; then call `guard_external(&"restore_recovery")` and return that exact retained `APPLICATION_FATAL`. The fatal path retains both locks/input block, never passes a raw result to the gate, and never returns outer `fatal_rollback_failed`, latch success/conflict, or empty failure details.

If mutation-gate acquisition or post-acquisition revalidation fails before any participant applies, release whichever gate/lock was acquired in reverse order and return without rollback. Tests cover this pre-apply branch separately from rollback failures.

The restored line is fully revealed. Semantic audio restarts. Tween progress, audio sample position, and partial-character count are not restored.

- [ ] **Step 7.5: Prove fake and production-adapter failure behavior**

- [ ] Implement `start_new_run(run_id, initial_context)` by reusing the participant transaction core, not by calling the legacy reset seam. `initial_context` is a closed Dictionary with exactly:

```gdscript
{
	"route_id": "opening",
	"dialogic_checkpoint": {},
	"active_app_id": null,
	"audio_context": {},
	"content_version": 1,
}
```

`content_version` must equal the configured runtime manifest version; the other four values are exact for Phase 2R and reject substitutions or extra keys. The algorithm is:

```text
ask RunRestoreParticipant/GameState for a detached Day-1 snapshot input for the new run_id
build and validate snapshot <new_run_id>:1 from only that input and initial_context
derive route_context from that validated snapshot
prepare all six participant plans; profile patch is empty and preserves the complete global profile
prepare CheckpointJournal.prepare_reset_with_initial(snapshot, day_start)
prepare a validated autosave/day_start document with that bundle current and recovery_journal=[]
acquire ApplicationMutationGate owner=new_run and revalidate every prepared input
capture six participants, Run-A journal, and the prior autosave storage descriptor
apply participants in restore order, awaiting route readiness before empty narrative apply
write/re-read/validate autosave, then commit the Run-B journal candidate
finalize participants, release the gate, and return run_id/checkpoint_id/route_id
```

On any apply, readiness, write, re-read, journal, or finalize failure, restore the journal/storage backup if attempted, roll participants back in reverse order, and release the gate only after all rollback work succeeds. Any rollback/storage/delete/release recovery failure completes every required recovery attempt and records the exact ordered raw diagnostic envelopes; projects/validates `source="new_run"`, the original phase, `code="fatal_rollback_failed"`, primitive old/new run and checkpoint context, and those diagnostics through the shared Task-3 projector; substitutes only its invariant fallback; calls `latch_fatal()` once on that same gate; then calls `guard_external(&"new_run_recovery")` and returns the exact retained `APPLICATION_FATAL`. The prior autosave is restored with `write_atomic()` when it existed; when it did not exist, the just-created autosave is removed through the crash-recoverable `StorageAdapter.remove()` delete transaction. No raw recovery result enters the gate, no projector/latch intermediate result becomes public, and no profile reset method is called. `MenuScene._on_new_acc_pressed()` awaits this API and does not route or call `SceneRouter.start_game_from_menu()` separately; the prepared route participant is the only opening transition.

- [ ] `FakeRestoreParticipant` can fail each prepare/apply/finalize position, pause an awaited apply, pause an awaited rollback, and records every call in `RestoreCallLog`. While either pause is active, issue one command through every guarded owner plus an on-tree input event and assert `TRANSACTION_ACTIVE`/no callback with byte-equal state. For every injected failure, assert participant snapshots and SaveManager journal equal their pre-load state, both locks and input release after successful rollback, and signal count is zero. For restore and new_run, inject each real rollback/storage/delete/release failure result with StringName keys/values, normalized-key collision, non-finite float, Object, Resource, Callable, packed bytes, and another packed array. Require every recovery attempt, exact raw diagnostic order, exact projector sentinel paths/reasons or invariant fallback, successful full-failure validation, no rejected data, no `INVALID_FATAL_FAILURE`, exactly one latch, then exactly one stable final guard and its retained `APPLICATION_FATAL`. Also assert both locks/input retained, identical-latch idempotence, conflicting-latch preservation through the final guard, `is_active()`/`get_active_owner()` unchanged, `is_fatal_latched()==true`, all eight public owners returning the same failure, and zero input restoration after a stale release/enabled event.

- [ ] `test_restore_production_adapters.gd` uses all six real adapter classes around failure-injectable manager ports. It proves profile-derived localization/audio inputs, route-ready-before-narrative order, reverse rollback, no participant domain signals, and one aggregate success signal. Fake-adapter success is not sufficient acceptance evidence.

- [ ] Add the exact cross-run regression:

```text
live state and journal contain Run B through sequence 12
slot document contains Run A current sequence 40 and earlier compatible sequence 35
compatibility recovery selects Run A sequence 35
successful load removes every Run-B and later Run-A bundle and allocates Run A sequence 36 next
failure at each participant or journal commit restores the complete Run-B journal and live Run-B state
```

- [ ] Add the exact New Game regression:

```text
live state, journal, and autosave contain Run A through sequence 12; profile contains visited/gallery/preferences
start_new_run prepares Run B without mutation and then commits
success leaves live Day-1 Run B, current checkpoint Run-B:1 kind day_start, empty recovery, next sequence 2, and matching autosave
success leaves the complete profile byte-equal and no Run-A bundle in the live Run-B journal/autosave
failure at every participant, awaited route, storage write/re-read, journal commit, or finalize boundary restores exact Run-A live state/journal/autosave/profile
an external GameState command, profile mutation, route command, quick-save shortcut, and on-tree button event during awaited apply and awaited rollback each return/do nothing and change no state
the mutation/input gate releases once after success or successful rollback; rollback failure irreversibly latches the one shared gate, makes every guarded mutation return APPLICATION_FATAL, and keeps input disabled
```

- [ ] Run. Expected GREEN: explicit schema migrations, every Day-8 row, whole-bundle fallback, Run-A-over-Run-B replacement/rollback, real/fake failure matrices, route readiness, one production gate factory invocation in the existing pre-profile stage, one identity across the exact eight final targets plus the Task-3 coordinator and Task-6 checkpoint port, no later initializer after every gate failure, no `missing_production_gate_factory`, and exactly one transaction success signal:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'restore_transaction_green' -LogName 'phase2r-restore-transaction.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_application_mutation_gate.gd,res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_save_migrations.gd,res://tests/unit/test_dating_ending_rules_migration.gd,res://tests/unit/test_restore_participants.gd,res://tests/unit/test_game_state_facade_contract.gd,res://tests/unit/test_application_bootstrap_profile_stage.gd,res://tests/integration/test_restore_transaction.gd,res://tests/integration/test_restore_production_adapters.gd,res://tests/integration/test_restore_mutation_gate.gd,res://tests/integration/test_new_run_transaction.gd','-gexit')
```

- [ ] **Step 7.6: Wire production participants and record the boundary**

- [ ] `ApplicationBootstrap` retains Plan 02's exact `STAGE_ORDER`. In its existing `construct_and_inject_mutation_gate` slot, before `initialize_profile`, it invokes the private factory for the unchanged Task-3 gate class once and completes the exact eight-target identity-checked injection described in Step 7.2. It then initializes owners in the already-frozen order; constructs the six production restore adapters only after their owners initialize; passes the exact Dictionary to `SaveManager.configure_restore_participants()` at `configure_restore_participants`; and invokes Task 6's `configure_day_resolution` adapter only at that stage. That adapter passes the retained same gate to `SaveManagerCheckpointPort.configure_fatal_latch()` and `DayResolutionCoordinator.configure_fatal_latch()`, requires both IDs equal the gate-stage ID, then configures the coordinator's unchanged state/checkpoint ports. These two application services are not added to `FINAL_GATE_TARGETS` and do not receive another factory object. Bootstrap neither moves gate construction beside participant construction nor creates a second gate. A gate construction/compatibility/target/identity failure records one fatal result at the gate stage, calls no initializer, and leaves load/menu/run input disabled. A later participant/service configuration failure preserves the already-recorded stage order and also remains fatal.

- [ ] Turn the production-bootstrap RED cases GREEN. Assert `get_startup_state()` records the exact full Plan-02 stage order when test-owned later-stage adapters succeed, and records only `[select_and_prove_roots, construct_and_inject_mutation_gate]` through a successful gate stage before a forced profile failure. For every gate/target failure it records no completed initializer stage. Assert the final branch never invokes the debug factory, never emits `development_subset_ready`, never reports `missing_production_gate_factory`, and cannot reach `initialize_profile` until all eight ordered targets return the one production gate identity. At `configure_day_resolution`, assert the coordinator and checkpoint-port identity results are parallel copies of that same ID; missing/replacement/mismatch at either service prevents the stage from completing and prevents every later stage. The development-mode expectations from Plan 02 remain unchanged.

- [ ] Run `git diff --check`. Only after separate authority for this exact Task 7 boundary, run:

```powershell
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
$task6Boundary = [string]::Join('', @(git log -1 --format=%H -- scripts/application/run/SaveManagerCheckpointPort.gd)).Trim()
if ($task6Boundary -cne $expectedHead) { throw 'Task 7 must be the direct successor of the Task 6 SaveManager boundary.' }
$required = [ordered]@{
  'scripts/infrastructure/save/SaveMigrations.gd'='A'
  'scripts/domain/ending/DatingEndingRules.gd'='A'
  'scripts/application/restore/RunRestoreParticipant.gd'='A'
  'scripts/application/restore/ProfileRestoreParticipant.gd'='A'
  'scripts/application/restore/LocalizationRestoreParticipant.gd'='A'
  'scripts/application/restore/AudioRestoreParticipant.gd'='A'
  'scripts/application/restore/RouteRestoreParticipant.gd'='A'
  'scripts/application/restore/NarrativeRestoreParticipant.gd'='A'
  'tests/support/FakeRestoreParticipant.gd'='A'
  'tests/support/RestoreCallLog.gd'='A'
  'tests/unit/test_save_migrations.gd'='A'
  'tests/unit/test_dating_ending_rules_migration.gd'='A'
  'tests/unit/test_restore_participants.gd'='A'
  'tests/integration/test_restore_transaction.gd'='A'
  'tests/integration/test_restore_production_adapters.gd'='A'
  'tests/integration/test_restore_mutation_gate.gd'='A'
  'tests/integration/test_new_run_transaction.gd'='A'
  'tests/fixtures/saves/v1_minimal_slot.json'='A'
  'tests/fixtures/saves/v2_future_schema.json'='A'
  'tests/fixtures/saves/day8_group_synchronized.json'='A'
  'tests/fixtures/saves/day8_ending_non_group.json'='A'
  'tests/fixtures/saves/day8_playing_with_day7_journal.json'='A'
  'tests/fixtures/saves/day8_group_invalid_with_day7_journal.json'='A'
  'tests/fixtures/saves/day8_no_fallback.json'='A'
  'tests/fixtures/saves/reversed_pair_tokens.json'='A'
  'tests/fixtures/saves/unknown_ending_id.json'='A'
  'tests/unit/test_game_state_facade_contract.gd'='M'
  'tests/unit/test_application_bootstrap_profile_stage.gd'='M'
  'autoload/GameState.gd'='M'
  'autoload/SceneRouter.gd'='M'
  'autoload/DialogicBridge.gd'='M'
  'autoload/ProfileManager.gd'='M'
  'autoload/LocalizationManager.gd'='M'
  'autoload/AudioManager.gd'='M'
  'autoload/InputManager.gd'='M'
  'autoload/ApplicationBootstrap.gd'='M'
  'autoload/SaveManager.gd'='M'
  'scripts/ui/MenuScene.gd'='M'
}
$optionalUids = [ordered]@{
  'scripts/infrastructure/save/SaveMigrations.gd.uid'='A'
  'scripts/domain/ending/DatingEndingRules.gd.uid'='A'
  'scripts/application/restore/RunRestoreParticipant.gd.uid'='A'
  'scripts/application/restore/ProfileRestoreParticipant.gd.uid'='A'
  'scripts/application/restore/LocalizationRestoreParticipant.gd.uid'='A'
  'scripts/application/restore/AudioRestoreParticipant.gd.uid'='A'
  'scripts/application/restore/RouteRestoreParticipant.gd.uid'='A'
  'scripts/application/restore/NarrativeRestoreParticipant.gd.uid'='A'
  'tests/support/FakeRestoreParticipant.gd.uid'='A'
  'tests/support/RestoreCallLog.gd.uid'='A'
  'tests/unit/test_save_migrations.gd.uid'='A'
  'tests/unit/test_dating_ending_rules_migration.gd.uid'='A'
  'tests/unit/test_restore_participants.gd.uid'='A'
  'tests/integration/test_restore_transaction.gd.uid'='A'
  'tests/integration/test_restore_production_adapters.gd.uid'='A'
  'tests/integration/test_restore_mutation_gate.gd.uid'='A'
  'tests/integration/test_new_run_transaction.gd.uid'='A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 -RequiredStatus $required -OptionalPresentStatus $optionalUids -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') -ExpectedHead $expectedHead -Message 'feat(save): migrate legacy saves and restore atomically'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 7 commit boundary failed.' }
```

Existing UID files are immutable bindings and never staged. The helper may add only the eighteen present new UIDs above; it rejects `project.godot`, Beads journals, unrelated autoload changes, mode/type drift, and every user-owned dirty path from the commit.

## Task 8: Run the lifecycle/persistence subsystem gate

**Beads:** `dwm-p2r.5`

**Files:**

- Verify: all files created/modified by Tasks 1–7
- Append evidence: `evidence/phase_2r/runtime/`
- Update bookkeeping: `dwm-p2r.5`

**Interfaces:**

- Consumes: the production `GameState -> DayResolutionCoordinator -> state/checkpoint ports` path; SaveManager surface; all schema, migration, journal, storage, and participant tests.
- Produces: reproducible `.4`/`.5` evidence with no Day 8 current state, no production-path access, no unclassified public surfaces, and `.5` closure only after every command succeeds.

- [ ] **Step 8.1: Run the isolated combined gate**

- [ ] Run exactly:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'lifecycle_save_gate' -LogName 'phase2r-lifecycle-save-gate.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_public_surface_inventory.gd,res://tests/unit/test_day_resolution_plan.gd,res://tests/unit/test_run_lifecycle.gd,res://tests/unit/test_application_mutation_gate.gd,res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_day_resolution_coordinator.gd,res://tests/unit/test_game_state_facade_contract.gd,res://tests/unit/test_application_bootstrap_profile_stage.gd,res://tests/unit/test_game_state.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/unit/test_save_document_schema.gd,res://tests/unit/test_checkpoint_journal.gd,res://tests/unit/test_save_manager.gd,res://tests/unit/test_dating_ending_rules_migration.gd,res://tests/unit/test_save_migrations.gd,res://tests/unit/test_restore_participants.gd,res://tests/integration/test_save_manager_journal.gd,res://tests/integration/test_save_capability.gd,res://tests/integration/test_restore_transaction.gd,res://tests/integration/test_restore_production_adapters.gd,res://tests/integration/test_restore_mutation_gate.gd,res://tests/integration/test_new_run_transaction.gd','-gexit')
```

Expected GREEN: all listed files pass; the production gate occupies the unchanged pre-profile stage and shares one verified identity across the exact eight final targets; zero project-owned error/orphan/leak delta, zero production-path access, crash-interrupted deletion never resurrects a save, and restore/New Game never expose an input or mutation window. Any third-party Dialogic diagnostic is fingerprinted against the immutable `.1` baseline and attached separately; it is neither attributed to `.5` nor waived as final success. The final `.10` gate still requires every project-owned diagnostic count to be zero.

- [ ] **Step 8.2: Run static and durable-state checks**

- [ ] Run:

```powershell
rg -n '\bday\s*=\s*8\b|day becomes 8|Day-8|Day 8' autoload scripts scenes tests
rg -n 'user://saves|store_var|get_var|allow_objects|ResourceLoader\.load|load\(' autoload/SaveManager.gd scripts/infrastructure/save scripts/domain/run scripts/application/restore
bd dep cycles
bd lint
git diff --check
```

Expected results:

```text
No active-runtime Day-8 match.
Day-8 matches exist only in named migration/negative fixtures and assertions.
No canonical-save object loading or caller-supplied production save path.
No Beads dependency cycle or lint error attributable to this issue.
No whitespace error.
```

The generic `load(` scan may find fixed compile-time script loading outside SaveManager serialization; classify each match in evidence. Any dynamic path derived from a save document is a failure.

- [ ] **Step 8.3: Close `.5` only from fresh evidence**

- [ ] Regenerate both surface inventories and prove every disposition. Attach the exact commands, exit codes, log paths, production-path probe result, Day-8 classification, migration fixture list, and Run-A-over-Run-B evidence to `dwm-p2r.5`.

- [ ] Close only after every acceptance criterion passes:

```powershell
bd close dwm-p2r.5 --reason 'Lifecycle/save acceptance passed: primitive schemas, isolated atomic storage, deterministic migrations, whole-bundle recovery, six-participant rollback, and fresh gate evidence recorded.'
bd show dwm-p2r.6 --json
bd show dwm-p2r.7 --json
```

Confirm `.6` becomes ready and `.7` remains blocked on `.6`. If any command fails, keep `.5` open, record the failure, and do not claim downstream work.
