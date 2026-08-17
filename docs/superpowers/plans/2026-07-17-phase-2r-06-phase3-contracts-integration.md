# Phase 2R Phase 3 Contracts and Integration Evidence Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (- [ ]) syntax for tracking.

**Goal:** Deliver contract-tested desktop and Minesweeper seams for Phase 3, then prove the complete Phase 2R foundation through isolated Day 1–7 scenarios, on-tree scenes, exact validators, zero project-owned diagnostics, and requirement-linked evidence.

**Architecture:** Phase 2R supplies closed registries and pure host/round contracts, not player-facing composition. DesktopAppHostState models one visible cached app and deterministic focus outputs. MinesweeperRoundCoordinator applies the real pre-board autosave/save-lock/domain-result/post-result protocol through injected ports and deterministic test fixtures. The final gate resolves every active requirement ID to executed evidence and blocks Phase 3 on any gap.

**Tech Stack:** Godot 4.6.3, GDScript, GUT 9.6.1, on-tree SceneTree harnesses, strict manifests/JSON, Beads, PowerShell, and generated evidence reports.

## Global Constraints

- This plan owns dwm-p2r.9 and dwm-p2r.10.
- .9 starts after .3, .4, .5, and .8 close. .10 starts only after .1 through .9 close.
- Phase 2R does not wire ComputerDesktop's visible app composition and does not wire player-facing Minesweeper fixture-selection buttons.
- Phase 2R does not implement a random/fake board. Phase 6 replaces only the simulator adapter through the same round interface.
- Saved desktop state contains only a registered app ID, never a path.
- The pre-board autosave must succeed before a round is consumed or save lock acquired.
- While a board is active, save input is disabled and silently ignored; no recommendation, unavailable message, toast, dialog, or deferred save appears.
- Final evidence uses isolated roots and treats existing passing counts as verification only when linked to requirement IDs.
- Project-owned leak/orphan/error exceptions are forbidden.
- Proposed commits require separate explicit authority.
- `implementation_authorized: true` as of 2026-07-18 for the exact task-scoped contracts, tests, integration, evidence, and ordinary Beads execution changes below after blockers close. Staging, retirement/deletion, evidence sealing, post-seal Beads closure, and commits remain behind their corresponding explicit authority gates.
- Every Plan-06 commit boundary invokes Plan 01's checked-in `tools/git/Invoke-ExactPathCommit.ps1`. The helper always requires `DWM_COMMIT_AUTHORIZED=1`, distinguishes Git quiet exit 0/1/error, stages only its literal required paths plus explicitly listed optional `.uid` files that are present, rejects a missing required path/status, extra/partial staged path, empty index, malformed/duplicate status, rename/copy/type/unmerged status, or failed diff check, and checks raw modes against the frozen regular-blob contract (`A 000000→100644`, `M 100644→100644`, `D 100644→000000`) before and after verifying the sole direct-child commit. Task 1 through Task 6 and cleanup subject `S` bind a nonempty current/prerequisite commit immediately before the helper's Git mutation and pass it through `-ExpectedHead`; the specialized `E` and `B` flows bind their semantic cleanup/evidence parent before validation or closure mutation and pass that same identity through `-ExpectedHead`. Symlinks, gitlinks, chmod/type drift, and all non-A/M/D modes/statuses fail. Task 1 through Task 6 never stage `.beads/interactions.jsonl` or `.beads/issues.jsonl`; their accumulated tracked worktree changes are explicitly permitted until cleanup subject `S` stages both.

---

## Task 1: Define the closed desktop registry and host state contract

**Beads:** dwm-p2r.9

**Files:**

- Create: scripts/domain/desktop/DesktopAppRegistry.gd
- Create: scripts/domain/desktop/DesktopAppHostState.gd
- Create: scripts/domain/desktop/LogoutPolicy.gd
- Consume without modification from Plan 03 Task 3: scripts/application/transaction/FatalDiagnosticProjector.gd
- Create: tests/unit/test_desktop_app_registry.gd
- Create: tests/unit/test_desktop_app_host_state.gd
- Create: tests/unit/test_logout_policy.gd
- Re-run without modification from Plan 03 Task 3: tests/unit/test_fatal_diagnostic_projector.gd
- Create: tests/integration/test_desktop_day_change_fatal.gd
- Consume without modification: tools/git/Invoke-ExactPathCommit.ps1
- Modify: scripts/domain/run/RunSnapshotSchema.gd
- Modify: scripts/application/run/SaveManagerCheckpointPort.gd
- Modify: scripts/application/restore/RouteRestoreParticipant.gd
- Modify: autoload/ApplicationBootstrap.gd
- Modify: tests/unit/test_run_snapshot_schema.gd
- Modify: tests/integration/test_restore_production_adapters.gd
- Modify: tests/integration/test_narrative_checkpoint_wiring.gd
- Bind existing UID: tests/integration/test_narrative_checkpoint_wiring.gd.uid
- Consume without modification: scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd
- Generate only in Task 3 after Bootstrap is final: evidence/phase_2r/handoff/desktop_contract.json
- Do not modify in Phase 2R: scripts/ui/ComputerDesktop.gd
- Do not modify in Phase 2R: scenes/desktop/ComputerDesktop.tscn

**Interfaces:**

- Consumes: master CommandResult, registered scene IDs/routes, SaveManager logout behavior, current-day notifications, and Plan 05's already-configured one `SaveManagerNarrativeCheckpointPort`, one real Plan-03 checkpoint port, and six stable provider Callables.
- Consumes: Plan-03 Task-3's one checked-in primitive-only `FatalDiagnosticProjector` and exhaustive unit contract without changing either artifact.
- Produces: the frozen DesktopAppRegistry/DesktopAppHostState/LogoutPolicy interfaces; desktop and Minesweeper call sites that use the one shared projector; `SaveManagerCheckpointPort.configure_desktop_context_provider(provider)`; `RouteRestoreParticipant.configure_desktop_host(host)`; one ApplicationBootstrap-owned host instance shared by both consumers and read through Plan 05's existing stable `active_app_id` Callable; identity tests proving no narrative adapter/Callable/real-port replacement; and the exact source contract from which Task 3 generates the handoff artifact. No Phase-3 UI composition is created.

- [ ] **Step 1.1: Claim .9 and write registry RED tests**

- [ ] Run:

~~~powershell
bd show dwm-p2r.3 --json
bd show dwm-p2r.4 --json
bd show dwm-p2r.5 --json
bd show dwm-p2r.8 --json
bd update dwm-p2r.9 --claim
~~~

All four blockers must be closed.

- [ ] Create the RED test with dynamic loading so the missing production class is the assertion failure rather than a parser error:

~~~gdscript
extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const REGISTRY_PATH := "res://scripts/domain/desktop/DesktopAppRegistry.gd"

func test_registry_is_missing_before_task_1_implementation() -> void:
	var loaded: Dictionary = PROBE.load_script(REGISTRY_PATH)
	assert_false(loaded.get("ok", false))
	assert_eq(loaded.get("code"), &"missing_script")
~~~

Run before creating the class:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'desktop_contract_red' -LogName 'phase2r-red-desktop-contract.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_app_registry.gd','-gexit')
~~~

Expected RED: one assertion reaches `missing_script`; a parse error, autoload error, or production-path access is not an acceptable failure.

- [ ] Tests assert this exact registry:

| app_id | approved scene | initial safe focus target |
|---|---|---|
| minesweeper | res://scenes/apps/MinesweeperApp.tscn | %HideButton |
| contacts | res://scenes/apps/ContactListApp.tscn | %HideButton |
| schedule | res://scenes/apps/ScheduleApp.tscn | %HideButton |
| shop | res://scenes/apps/ShopApp.tscn | %HideButton |
| backup | res://scenes/apps/BackupApp.tscn | %HideButton |
| settings | res://scenes/apps/SettingsApp.tscn | %HideButton |
| logout | res://scenes/apps/LogOutApp.tscn | %NoButton |

Every scene must load/instantiate and each focus target must resolve to a visible, enabled Control with FOCUS_ALL after it enters the tree. Phase 3 may improve initial targets only with an updated on-tree focus test.

- [ ] Implement the shared registry signatures. get_record() is the sole app-ID-to-path resolver; unknown IDs return a safe error. validate_all() rejects duplicate IDs/paths, missing scenes, arbitrary saved paths, or nonfocusable targets.

- [ ] **Step 1.2: Model one visible cached app without implementing UI**

- [ ] DesktopAppHostState exposes:

~~~gdscript
class_name DesktopAppHostState
extends RefCounted

func reset(current_day: int) -> void
func open_app(app_id: StringName, current_day: int) -> Dictionary
func close_app() -> Dictionary
func change_day(new_day: int) -> Dictionary
func get_state() -> Dictionary
func capture_persistent_state() -> Dictionary
func prepare_restore(active_app_id: Variant, current_day: int) -> Dictionary
~~~

- [ ] open_app() returns:

~~~gdscript
{
	"ok": true,
	"instantiate": true,
	"hide_app_id": null,
	"show_app_id": &"contacts",
	"focus_target": NodePath("%HideButton"),
}
~~~

instantiate is true only the first time that app opens during the current day. Switching returns the previous active ID in hide_app_id. Exactly one active ID exists. close_app() hides it and returns focus_icon_app_id. `change_day()` rejects a nonpositive or unchanged/backward day and otherwise clears active/cache and returns the master CommandResult with exact `value={"eviction_command":{"command_id":"desktop-day:<new_day>","kind":&"evict_cached_apps","day":new_day,"app_ids":Array[StringName]}}` and empty receipt. `app_ids` contains every prior cached ID exactly once in `DesktopAppRegistry.get_ids()` order, not caller/cache insertion order. The command is recursively detached. Persistent domain state is not stored here.

- [ ] `get_state()` may contain runtime-only `current_day`, `active_app_id`, and `cached_app_ids`. `capture_persistent_state()` returns exactly `{"active_app_id": <registered ID or null>}`. Restore rebuilds an empty cache and returns `instantiate=true` for a non-null saved active ID. No persisted data contains current_day (already in lifecycle), cached IDs, PackedScene, NodePath, arbitrary path, position, z-order, window rectangle, or draggable-window state.

- [ ] Close the persistence seam in this task. Configure the production `SaveManagerCheckpointPort` with this `DesktopAppHostState` as its desktop context provider; immediately before `RunSnapshotSchema.build()`, the port captures the provider and supplies only its `active_app_id`. Assign the same host only to Bootstrap's private slot already read by Plan 05's stable `active_app_id` provider Callable. Before assignment that Callable returns raw JSON null; afterward it returns the same host's raw registered app-ID String or JSON null. It never returns a CommandResult wrapper. Its Callable identity, the configured `SaveManagerNarrativeCheckpointPort` instance ID, its one real checkpoint-port instance ID, and the adapter instance IDs retained by DialogicBridge/GameState remain exactly equal to their pre-assignment values. `RunSnapshotSchema` replaces provisional string validation with `DesktopAppRegistry.has_app()` and still accepts JSON null. `RouteRestoreParticipant` derives its desktop subplan from the validated snapshot and calls `DesktopAppHostState.prepare_restore(active_app_id, lifecycle.day)` during prepare; silent apply rebuilds an empty cache and returns the registered instantiate command, while rollback restores the captured host state. Unknown IDs, cached IDs, paths, or caller-supplied UI state reject before any participant applies. Round-trip null and all seven IDs through slot restore and assert no alias/cache persistence.

- [ ] Consume and re-run Plan 03 Task 3's one shared fatal-diagnostic boundary before using it in this task's desktop handler or Task 2's Minesweeper coordinator. The checked-in interface remains exactly:

~~~gdscript
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
~~~

`project_failure()` normalizes nonempty String/StringName `source`, `phase`, and `code` to ordinary String and returns the frozen success `value={"failure":FatalFailure}` with empty receipt. `FatalFailure` has exactly those three normalized fields plus `details={"context":Dictionary,"diagnostics":Array[Dictionary]}`. Context and diagnostic data are recursively detached. JSON null, bool, int, finite float, String, Array, and Dictionary are the only admitted values; every StringName value and every String/StringName key becomes String. Arrays preserve order. Dictionary keys must remain unique after normalization. A non-finite number, Object, Resource, Callable, any packed array/bytes value, unsupported value, non-string key, or normalized-key collision is never copied. Instead, the smallest replaceable invalid subtree becomes exactly `{"reason":String,"path":String}`, where reason is one of `nonfinite_number|unsupported_type|non_string_key|normalized_key_collision`; an invalid Dictionary key or collision replaces that whole Dictionary subtree. Paths are deterministic JSONPath-like Strings rooted at `$.context` or `$.diagnostics[index]`.

Each raw diagnostic has exactly `owner_id`, `operation`, and `result`. The first two are caller-owned nonempty String/StringName values normalized to String. `result` must be one frozen CommandResult union: its bool `ok` and nonempty String/StringName `code` are retained as bool/String; a success projects `message=""` and `details={}` without copying `value` or `receipt`; a failure requires String/StringName `message` plus Dictionary `details` and recursively projects those details. Every projected diagnostic has exactly `owner_id`, `operation`, `ok`, `code`, `message`, and `details`. A malformed diagnostic/result becomes exactly `{"owner_id":"fatal_diagnostic_projector","operation":"project_diagnostic","ok":false,"code":"invalid_fatal_diagnostic","message":"","details":{"reason":"malformed_diagnostic","path":String}}`; no rejected byte or alias enters it.

`validate_failure()` independently enforces the exact-key/nonempty-normalized-string/recursive-primitive contract frozen for `ApplicationMutationGate.latch_fatal()`. `get_invariant_fallback()` returns a fresh copy of the constant valid primitive failure `{"source":"fatal_diagnostic_projector","phase":"project_failure","code":"FATAL_PROJECTOR_INVARIANT","details":{"reason":"invalid_projector_output","path":"$"}}`. Both callers complete every required recovery attempt first, preserve raw diagnostic order, project, and validate the full failure before the first latch call. A failed projector result or failed validation is an implementation invariant and substitutes only this constant fallback; it never skips the fatal fence. After `latch_fatal()`, the caller invokes the same gate's `guard_external()` and returns that exact retained `APPLICATION_FATAL`, including the first failure details. `APPLICATION_FATAL_CONFLICT` from a concurrent different latch never replaces the retained failure; the final guard remains authoritative.

- [ ] Re-run the unchanged Plan-03 `test_fatal_diagnostic_projector.gd` matrix covering StringName key/value normalization, recursive detachment, nested invalid-subtree replacement, malformed diagnostic replacement, non-finite floats, Object, Resource, Callable, packed bytes and every other packed array, non-string keys, and normalized-key collisions. It passes every projected result and the invariant fallback to the real gate contract and requires that neither can produce `INVALID_FATAL_FAILURE`. Plan 06 adds call-site tests only; it MUST NOT recreate, modify, or recommit the projector or its unit-test owner.

The owner and configuration contract is exact:

~~~gdscript
# SaveManagerCheckpointPort.gd
func configure_desktop_context_provider(provider: Object) -> Dictionary

# RouteRestoreParticipant.gd
func configure_desktop_host(host: Object) -> Dictionary

# ApplicationBootstrap.gd
func register_desktop_eviction_port(port: Object) -> Dictionary

# one Phase-3-owned registered port
func dispatch_desktop_eviction(command: Dictionary) -> Dictionary
~~~

`ApplicationBootstrap` owns exactly one `_desktop_host_state: RefCounted` for the process lifetime. Plan 05's existing `initialize_dialogic_bridge` stage has already created/configured the shared narrative adapter and stable active-app Callable while this field is null. During the existing `configure_restore_participants` stage Plan 06 constructs `DesktopAppHostState.new()`, calls `reset(GameState.day)`, assigns it to that existing field so the same Callable now reads it, configures the `RouteRestoreParticipant`, and retains the instance. During the existing `configure_day_resolution` stage it supplies that same object identity to `SaveManagerCheckpointPort`. Neither consumer may construct or replace the host; no stage may reconfigure the narrative adapter or replace any provider Callable/real checkpoint port; a second direct host configuration with the same object is idempotent and a different object returns `DESKTOP_PROVIDER_ALREADY_CONFIGURED`. Configuration validates these methods before retaining the reference:

~~~text
checkpoint provider: capture_persistent_state
route host: get_state, reset, open_app, close_app, prepare_restore
~~~

`prepare_restore()` returns exactly `value={"candidate_state": {"current_day": int, "active_app_id": StringName|null, "cached_app_ids": Array[StringName]}, "instantiate_command": Dictionary|null}`. Route silent apply calls `reset(day)` and, when non-null, `open_app(active_app_id, day)`. Rollback reconstructs the captured `get_state()` deterministically by resetting, opening every captured cached ID in registry order, reopening the captured active ID last, and calling `close_app()` when the captured active ID was null. Because the host is pure runtime state, these operations emit no signal and perform no I/O.

ApplicationBootstrap alone connects the committed `GameState.day_changed(new_day)` signal, exactly once and only after day/coordinator/host configuration. Its handler calls `_desktop_host_state.change_day(new_day)` exactly once, validates the exact eviction command above, then calls one registered port's `dispatch_desktop_eviction(command)` exactly once with a detached copy. `register_desktop_eviction_port()` accepts one non-null object exposing that method; first configuration succeeds, the same identity is idempotent, and replacement returns `DESKTOP_EVICTION_PORT_ALREADY_CONFIGURED`. A day change before a port is registered creates the constant frozen failure result `DESKTOP_EVICTION_PORT_MISSING`; a dispatch failure retains the port's raw failure result. In either case the handler first finishes the attempted dispatch path, then calls `FatalDiagnosticProjector.project_failure("desktop","day_change_dispatch","DESKTOP_EVICTION_DISPATCH_FAILED", {"day":new_day}, [{"owner_id":"desktop_eviction_port","operation":"dispatch_desktop_eviction","result":raw_result}])`, validates the full projected FatalFailure, substitutes only the shared invariant fallback on a projector invariant, calls the existing gate's `latch_fatal()` exactly once, then calls `guard_external(&"desktop_day_change_dispatch")` and returns/stores that exact retained `APPLICATION_FATAL`. It never returns the latch's intermediate `ok`/conflict result, never copies the raw cause into fatal details, and keeps input blocked permanently. Phase 3 may only register/consume this port; it never connects directly to `day_changed`, accesses the host, or calls `change_day()`.

- [ ] Add `test_desktop_day_change_nonprimitive_failure_projects_then_returns_retained_application_fatal` to `tests/integration/test_desktop_day_change_fatal.gd`. Feed the eviction port failures containing, in turn, a normalized-key collision, non-finite float, Object, Callable, and packed bytes. Assert dispatch once; projection/validation before latch; the exact sentinel path/reason without rejected data; one first-latch capability emission; the exact retained `APPLICATION_FATAL` with primitive failure details; no later bootstrap/domain call; and permanent InputManager blocking despite stale enabled/release events.

- [ ] **Step 1.3: Specify Logout Yes/No without scene wiring**

- [ ] LogoutPolicy exposes:

~~~gdscript
static func plan(
	confirmed: bool,
	has_stable_checkpoint: bool
) -> Dictionary
~~~

Exact results:

~~~text
No -> do not save, do not route, restore desktop focus to logout icon
Yes + checkpoint -> SaveManager.save_for_logout, route menu, run not completed
Yes + no checkpoint -> no write, route menu, run not completed
~~~

Save failure returns an error and does not route. The policy never transitions lifecycle to COMPLETED.

- [ ] **Step 1.4: Verify on-tree registry and pure host state**

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'desktop_contract' -LogName 'phase2r-desktop-contract.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_app_registry.gd,res://tests/unit/test_desktop_app_host_state.gd,res://tests/unit/test_logout_policy.gd,res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_run_snapshot_schema.gd,res://tests/integration/test_desktop_day_change_fatal.gd,res://tests/integration/test_restore_production_adapters.gd,res://tests/integration/test_narrative_checkpoint_wiring.gd','-gexit')
~~~

Expected GREEN: seven registered apps instantiate/focus, one active app, per-day cache, deterministic close/day reset, exact Logout semantics, primitive-only desktop fatal projection with retained `APPLICATION_FATAL`, and the Plan-05 active-app Callable changes only its returned value while the Callable/shared-adapter/real-checkpoint-port/DialogicBridge/GameState identities remain unchanged.

- [ ] **Step 1.5: Freeze the exact Phase 3 handoff inputs**

- [ ] Task 3's generated `desktop_contract.json` records registry version 1, the seven IDs, scene/focus records, DesktopAppHostState signatures/result shapes, the stable Plan-05 narrative active-app provider and unchanged adapter/Callable/real-port/consumer identities, Bootstrap's one day-change owner and one eviction-port signature, the shared fatal projector/sentinel/fallback plus final-guard result, and these Phase 3 responsibilities:

~~~text
compose icon grid and one DesktopAppHost
instantiate/hide/focus from contract outputs
connect app close back to icon focus
register exactly one desktop eviction port and consume its commands
never connect directly to day_changed or call change_day
wire Logout Yes/No to LogoutPolicy and SaveManager
never persist scene paths or UI nodes
~~~

It records Phase 2R exclusion: no player-facing composition was added. Task 1 does not hand-author or generate the artifact; Task 3 does so only after Task 2 freezes final Bootstrap bytes.

- [ ] **Step 1.6: Proposed commit boundary (requires explicit commit authority)**

Do not run without explicit authority for these literal paths and an empty staged index:

~~~powershell
$required = [ordered]@{
  'scripts/domain/desktop/DesktopAppRegistry.gd'='A'
  'scripts/domain/desktop/DesktopAppHostState.gd'='A'
  'scripts/domain/desktop/LogoutPolicy.gd'='A'
  'tests/unit/test_desktop_app_registry.gd'='A'
  'tests/unit/test_desktop_app_host_state.gd'='A'
  'tests/unit/test_logout_policy.gd'='A'
  'tests/integration/test_desktop_day_change_fatal.gd'='A'
  'scripts/domain/run/RunSnapshotSchema.gd'='M'
  'scripts/application/run/SaveManagerCheckpointPort.gd'='M'
  'scripts/application/restore/RouteRestoreParticipant.gd'='M'
  'autoload/ApplicationBootstrap.gd'='M'
  'tests/unit/test_run_snapshot_schema.gd'='M'
  'tests/integration/test_restore_production_adapters.gd'='M'
  'tests/integration/test_narrative_checkpoint_wiring.gd'='M'
}
$optionalUids = [ordered]@{
  'scripts/domain/desktop/DesktopAppRegistry.gd.uid'='A'
  'scripts/domain/desktop/DesktopAppHostState.gd.uid'='A'
  'scripts/domain/desktop/LogoutPolicy.gd.uid'='A'
  'tests/unit/test_desktop_app_registry.gd.uid'='A'
  'tests/unit/test_desktop_app_host_state.gd.uid'='A'
  'tests/unit/test_logout_policy.gd.uid'='A'
  'tests/integration/test_desktop_day_change_fatal.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or -not $expectedHead) { throw 'Cannot bind the Task 1 prerequisite HEAD.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 `
  -RequiredStatus $required `
  -OptionalPresentStatus $optionalUids `
  -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
  -ExpectedHead $expectedHead `
  -Message 'feat(handoff): define desktop registry and one-app host contract'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 1 commit boundary failed.' }
~~~

## Task 2: Define the real Minesweeper round interface and deterministic fixtures

**Beads:** dwm-p2r.9

**Files:**

- Create: scripts/domain/minesweeper/MinesweeperRoundContract.gd
- Create: scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd
- Create: scripts/application/minesweeper/GameStateMinesweeperPort.gd
- Create: scripts/application/minesweeper/SaveManagerMinesweeperPort.gd
- Create: tests/fixtures/minesweeper/results.json
- Create: tests/support/FakeMinesweeperSavePort.gd
- Create: tests/support/FakeMinesweeperStatePort.gd
- Create: tests/support/FakeDesktopEvictionPort.gd
- Create: tests/unit/test_minesweeper_round_contract.gd
- Create: tests/unit/test_application_bootstrap.gd
- Create: tests/integration/test_application_bootstrap.gd
- Create: tests/integration/test_minesweeper_round_coordinator.gd
- Create: tests/integration/test_minesweeper_save_lock.gd
- Consume without modification: scripts/application/transaction/FatalDiagnosticProjector.gd
- Consume without modification: tests/unit/test_fatal_diagnostic_projector.gd
- Modify: autoload/GameState.gd
- Modify: autoload/ApplicationBootstrap.gd
- Bind existing UID: autoload/ApplicationBootstrap.gd.uid
- Generate with Godot import: tests/unit/test_application_bootstrap.gd.uid
- Generate with Godot import: tests/integration/test_application_bootstrap.gd.uid
- Modify: project.godot
- Modify: tests/unit/test_minesweeper_rewards.gd
- Do not modify in Phase 2R: scripts/ui/MinesweeperApp.gd
- Do not modify in Phase 2R: scenes/apps/MinesweeperApp.tscn

**Interfaces:**

- Consumes: plan03 checkpoint transaction and save-lock seams, GameState detached round candidates, ContactInvitationState pure activation, and active DayResolutionPlan dating-entry evidence.
- Produces: the frozen MinesweeperRoundContract/Coordinator methods, exact save/state port adapters including shared-gate `guard_external`, primitive-projected recovery fatal handling, trusted `abort_round`, and the final production ApplicationBootstrap/project-autoload sequence consumed read-only by Tasks 3–4; all results flow through the same real domain seam used by Phase 6.

- [ ] **Step 2.1: Write RED contract tests**

- [ ] Start `test_minesweeper_round_contract.gd` with this parse-safe RED:

~~~gdscript
extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const CONTRACT_PATH := "res://scripts/domain/minesweeper/MinesweeperRoundContract.gd"

func test_contract_is_missing_before_implementation() -> void:
	var loaded: Dictionary = PROBE.load_script(CONTRACT_PATH)
	assert_false(loaded.get("ok", false))
	assert_eq(loaded.get("code"), &"missing_script")
~~~

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'minesweeper_contract_red' -LogName 'phase2r-red-minesweeper-contract.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_minesweeper_round_contract.gd','-gexit')
~~~

Expected RED: `missing_script`; a parser failure is not acceptable.

- [ ] MinesweeperRoundContract uses:

~~~gdscript
class_name MinesweeperRoundContract
extends RefCounted

const DIFFICULTIES: Array[StringName] = [
	&"beginner", &"intermediate", &"expert"
]
const OUTCOMES: Array[StringName] = [
	&"exploded", &"cleared", &"perfect", &"no_flag", &"foresight"
]

static func validate_start_request(request: Dictionary) -> Dictionary
static func validate_result(
	active_round: Dictionary,
	result: Dictionary
) -> Dictionary
static func build_round_id(
	run_id: String,
	day: int,
	ordinal: int
) -> String
~~~

- [ ] Start request is exactly:

~~~json
{
  "context": "app",
  "difficulty": "beginner"
}
~~~

context is app or dating. A completed result is exactly:

~~~json
{
  "outcome": "cleared"
}
~~~

Round ID, context, difficulty, day, and ordinal come from the active round, not untrusted result input.

For `context=app`, state validation requires an available app round and motivation, then consumes exactly one of each; app completion may award money/tasks, increment the daily app-round count, unlock messages, and activate the group offer on 2→3. For `context=dating`, the untrusted request contains no friend/entry identifiers and consumes no app round or motivation. The state port must supply one active route substage with exact `entry_id`, `route_transaction_id`, and `friend_ids`; those trusted values are stamped into the active round. Dating completion applies only its synchronized date outcome/affection/dark-path receipt and can never award app money/tasks, increment app-round count, or activate a group offer.

- [ ] results.json contains exactly fifteen test-only fixtures: each of the five outcomes for each of the three difficulties. It contains no random seed, cell grid, mine placement, fake timer, or board state. Expected reward/task effects are derived through production rules, not duplicated as authoritative fixture values.

- [ ] **Step 2.2: Implement an injected coordinator behind GameState**

- [ ] MinesweeperRoundCoordinator exposes:

~~~gdscript
class_name MinesweeperRoundCoordinator
extends RefCounted

func configure(
	save_port: Object,
	state_port: Object
) -> Dictionary
func begin_round(request: Dictionary) -> Dictionary
func complete_round(
	round_id: String,
	result: Dictionary,
	transaction_id: String
) -> Dictionary
func abort_round(
	round_id: String,
	reason: StringName,
	transaction_id: String
) -> Dictionary
func get_active_round() -> Dictionary
~~~

GameState's shared begin_minesweeper_round() and complete_minesweeper_round() delegate to this coordinator. ApplicationBootstrap supplies production GameState/SaveManager ports after both are initialized; tests inject fakes. `tests/unit/test_application_bootstrap.gd` proves the production bootstrap constructs/configures exactly one coordinator with initialized production adapters, installs it in GameState once, rejects missing/out-of-order dependencies without partial configuration, and is source-bound with both its own UID and `autoload/ApplicationBootstrap.gd.uid`.

Task 2, not Task 4, freezes the complete final Bootstrap bytes. `tests/integration/test_application_bootstrap.gd` verifies the master stage order, exact eight-target shared gate identity, all restore adapters, profile-backed manager preferences, ending playback port, one process-lifetime DesktopAppHostState shared by route/direct-checkpoint contexts, the same host value appearing through Plan 05's pre-existing stable narrative `active_app_id` Callable without replacement of the Callable/shared adapter/real checkpoint port/DialogicBridge/GameState identities, DayResolution and Minesweeper coordinators, exactly one `GameState.day_changed` connection, and one registered desktop-eviction port dispatch. `project.godot` reaches the final literal autoload order in this task. Task 3 hashes these exact Bootstrap/unit/integration/project bytes into both handoff artifacts; after Task 3 closes `.9`, Task 4 treats them as immutable bindings.

- [ ] Freeze the injected ports; duck-typed alternatives are rejected during `configure()` unless every exact method exists:

~~~gdscript
# GameStateMinesweeperPort and FakeMinesweeperStatePort
func capture() -> Dictionary
func prepare_begin(request: Dictionary, round_id: String) -> Dictionary
func prepare_complete(active_round: Dictionary, result: Dictionary, transaction_id: String) -> Dictionary
func finalize_complete(prepared_completion: Dictionary, checkpoint_id: String) -> Dictionary
func prepare_abort(active_round: Dictionary, reason: StringName, transaction_id: String) -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func publish(receipt: Dictionary, domain_events: Array[Dictionary]) -> Dictionary
func latch_fatal(failure: Dictionary) -> Dictionary
func is_fatal_latched() -> bool
func guard_external(operation_id: StringName) -> Dictionary

# SaveManagerMinesweeperPort and FakeMinesweeperSavePort
func capture() -> Dictionary
func preview_checkpoint_id(run_id: String) -> Dictionary
func prepare_checkpoint(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary
func commit_checkpoint(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func acquire_board_lock() -> Dictionary
func release_board_lock() -> Dictionary
func owns_board_lock() -> bool
~~~

Both fake ports additionally expose test-only `reset_call_counts() -> void`, `get_call_counts() -> Dictionary`, and `set_failure(method: StringName, remaining_failures: int = 1) -> void`. `get_call_counts()` has one integer key for every exact port method above; it returns a detached copy and inspection never increments a count. Coordinator tests use these counters to prove phase-only retry rather than inferring it from final state.

`GameStateMinesweeperPort.latch_fatal(failure)`, `is_fatal_latched()`, and `guard_external(operation_id)` delegate to GameState's already-configured ApplicationMutationGate; the adapter owns no local fatal field or retained-failure cache. `latch_fatal()` returns the gate's exact intermediate first/idempotent/conflict result, while `guard_external()` returns the gate's exact authoritative result. The fake state port delegates all three methods to one injected `FakeApplicationMutationGate` with identical behavior. Coordinator configuration rejects any method missing, and fake call counts include all three independently.

Every public `begin_round()`, `complete_round()`, and `abort_round()` operation calls `state_port.guard_external(<exact operation ID>)` as its first operation, before argument normalization, pending/completed lookup, contract validation, capture, or any other port call. It propagates a failed guard unchanged, including exact retained `APPLICATION_FATAL details={"failure":FatalFailure}`; it never substitutes empty details. Recovery first attempts every required state rollback/lock release in frozen order and records one raw diagnostic per attempt. It then projects `source="minesweeper"`, the exact original recovery phase, inner `code="ROLLBACK_FAILED"`, a context containing only stable round/transaction IDs, and the ordered raw diagnostics through `FatalDiagnosticProjector`, validates the full failure, and substitutes only the constant invariant fallback if projection/validation fails. It calls `state_port.latch_fatal(failure)` exactly once, then `state_port.guard_external(&"minesweeper_recovery")` exactly once and returns that final guard result unchanged. Thus outer `ROLLBACK_FAILED`, a latch-success result, `APPLICATION_FATAL_CONFLICT`, and empty-detail `APPLICATION_FATAL` are forbidden after the irreversible fence; `ROLLBACK_FAILED` survives only as the retained inner `FatalFailure.code` and projected diagnostic identity. A concurrent different latch preserves and returns the first retained failure.

`prepare_begin()` returns a detached active-round/run candidate plus `pre_board_checkpoint_inputs` captured from the still-unconsumed run. `prepare_complete()` returns a detached prepared completion whose receipt checkpoint ID is still empty. `preview_checkpoint_id()` delegates plan03's pure checkpoint-port preview and consumes no sequence. `finalize_complete()` validates that preview, inserts it into the detached receipt and candidate, rebuilds `post_result_checkpoint_inputs` from that final candidate, and returns the exact completed candidate/receipt/events without live mutation. The following checkpoint prepare must return the identical ID or the coordinator rejects before commit. `prepare_abort()` returns the captured pre-board run candidate with no reward/event. The production save adapter delegates checkpoint preview/capture/prepare/commit/rollback to plan03's `SaveManagerCheckpointPort` and delegates only owner `&"minesweeper_board"` to SaveManager's lock API; it does not reimplement schemas, journals, filenames, or save capability.

Freeze these schemas before writing the coordinator. Unknown or missing keys reject, all nested containers are detached, and every success is wrapped in the master `CommandResult`:

~~~json
{
  "round_id": "run-1:day-2:round-3",
  "run_id": "run-1",
  "context": "app",
  "difficulty": "beginner",
  "day": 2,
  "ordinal": 3,
  "dating_evidence": null
}
~~~

For `context=dating`, `dating_evidence` is exactly `{"entry_id":String,"route_transaction_id":String,"friend_ids":Array[String]}` with one or two unique registered friend IDs. App rounds require null. The prepared state-port values are exactly:

~~~text
prepare_begin.value = {
  candidate: Dictionary,
  active_round: ActiveRound,
  pre_board_checkpoint_inputs: Dictionary,
  start_receipt: {round_id, context, difficulty, day, ordinal}
}
prepare_complete.value = {
  prepared_candidate: Dictionary,
  prepared_domain_receipt: CompletionReceiptWithEmptyCheckpointId,
  domain_events: Array[Dictionary],
  checkpoint_input_template: Dictionary
}
finalize_complete.value = {
  candidate: Dictionary,
  domain_receipt: CompletionReceipt,
  domain_events: Array[Dictionary],
  post_result_checkpoint_inputs: Dictionary
}
prepare_abort.value = {
  candidate: Dictionary,
  abort_receipt: {round_id, reason, transaction_id}
}
~~~

The coordinator-built start event is exactly `{"event_id":"round_started","round_id":String,"context":String,"difficulty":String,"day":int,"ordinal":int}` and all six values must equal the prepared `active_round`/`start_receipt`. `state_port.publish()` rejects any extra/missing key or disagreement before emitting.

`CompletionReceipt` has exactly these keys:

~~~json
{
  "transaction_id": "round-result:run-1:2:3",
  "round_id": "run-1:day-2:round-3",
  "context": "app",
  "difficulty": "beginner",
  "outcome": "cleared",
  "counter_deltas": {"money": 0, "motivation": 0, "app_rounds": 1, "health": 0, "pressure": 0},
  "task_ids": [],
  "effect_transaction_ids": [],
  "message_transaction_ids": [],
  "group_activation_transaction_id": null,
  "dating_outcome_id": null,
  "checkpoint_id": "run-1:18"
}
~~~

App completion requires `dating_outcome_id=null`; dating completion requires zero app-round/motivation/money deltas, null group activation, and a nonempty synchronized dating outcome. `prepare_complete()` uses the same shape with `checkpoint_id=""`. The coordinator then calls the save port's non-consuming preview, passes that ID to `finalize_complete()`, and checkpoint preparation must prove the same ID before either commit. Thus the committed state candidate, CompletionReceipt, and snapshot all contain one nonempty ID; no caller mutates an owner-validated candidate.

The coordinator stores at most one pending post-durable record:

~~~gdscript
{
  "round_id": String,
  "transaction_id": String,
  "phase": StringName,
  "receipt": CompletionReceipt,
  "domain_events": Array[Dictionary],
  "checkpoint_id": String,
  "normalized_result": {"outcome": String},
}
~~~

`phase` is exactly `&"publish"` or `&"release_lock"`; `receipt` is the detached exact CompletionReceipt shown above, `domain_events` is the detached exact ordered event batch returned by `finalize_complete()`, `checkpoint_id` MUST equal `receipt.checkpoint_id`, and `normalized_result` is the detached exact result after `MinesweeperRoundContract.validate_result()` has reduced it to the one-key String-valued shape shown above. All four values are retained byte-equivalent through publish/release retries. The completed-transaction lookup stores exactly `{"receipt":CompletionReceipt,"normalized_result":{"outcome":String}}` under `transaction_id`; it never stores a bare receipt.

Before consulting pending/completed lookup, `_normalize_result_for_identity(result)` requires a Dictionary with exactly one key `outcome`, converts StringName to String, requires the value in `MinesweeperRoundContract.OUTCOMES`, and returns a fresh `{"outcome":String}`. Equality is exact Dictionary equality after this normalization; no `JSON.stringify()`, caller-owned alias, omitted-key default, or subset comparison is allowed. A matching transaction with a different `round_id` or normalized result returns `TRANSACTION_ID_CONFLICT` before any port call.

`phase` is `publish` or `release_lock`. Closed nonfatal coordinator failure codes are `NOT_CONFIGURED`, `INVALID_REQUEST`, `ROUND_ALREADY_ACTIVE`, `NO_APP_ROUND_AVAILABLE`, `INSUFFICIENT_MOTIVATION`, `DATING_ROUTE_NOT_ACTIVE`, `ROUND_ID_MISMATCH`, `INVALID_RESULT`, `INVALID_TRANSACTION_ID`, `TRANSACTION_ID_CONFLICT`, `PRE_BOARD_CHECKPOINT_FAILED`, `PRE_BOARD_AUTOSAVE_FAILED`, `SAVE_LOCK_FAILED`, `STATE_PREPARE_FAILED`, `CHECKPOINT_PREPARE_FAILED`, `STATE_COMMIT_FAILED`, `CHECKPOINT_COMMIT_FAILED`, `ROUND_START_PUBLICATION_FAILED`, `COMPLETION_COMMITTED_UNPUBLISHED`, `LOCK_RELEASE_PENDING`, and `ABORT_FAILED`. Recoverable port failures are nested under `details.cause`; they never become new public codes. A recovery failure irreversibly latches and returns only the gate's outer `APPLICATION_FATAL`; `ROLLBACK_FAILED` is reserved for the retained inner FatalFailure.code and is not an ordinary coordinator failure code.

`state_port.publish(receipt, domain_events)` is a pre-emission failpoint: failure guarantees zero signal/callback emission; success emits the supplied entire stable event batch exactly once. Partial publication violates the port contract and is fatal. This makes a retry well-defined rather than pretending emitted signals can be rolled back.

- [ ] **Step 2.3: Implement the exact start transaction**

- [ ] begin_round() performs in this order after its first-operation `state_port.guard_external(&"minesweeper_begin_round")` succeeds:

1. Validate difficulty/context and domain availability without mutation; resolve trusted dating evidence from the state port.
2. Capture the state-port backup, build the stable round ID from run ID, day, and next ordinal, and prepare the active-round candidate without publishing it.
3. Prepare a pre_board checkpoint from the still-unconsumed live run and capture journal/slot backups.
4. Commit the checkpoint journal and `autosave.json` as one recoverable save transaction. Failure restores journal/sequence/file and returns with no round consumed or lock.
5. Acquire save lock owner minesweeper_board.
6. Commit the prepared active-round candidate and the context-specific cost. Failure rolls the state port back to the captured backup and releases the lock; the successful durable pre-board checkpoint/autosave remains valid. A rollback or release failure completes both required recovery attempts, projects/validates their ordered diagnostics through the shared projector, latches once, performs the final guard, returns that exact retained `APPLICATION_FATAL`, retains the lock, and relies on the shared fatal mutation fence.
7. Construct exactly one detached `round_started` domain event from the owner-validated `active_round` and `start_receipt`, then call `state_port.publish(start_receipt, [round_started_event])`. The port validates the whole batch before its first emission.
8. If start publication fails before emission, roll the committed active candidate back first and release the lock second. Leave the already-durable pre-board checkpoint/autosave intact and return `ROUND_START_PUBLICATION_FAILED` with the publish cause. If either recovery action fails, still attempt both in order, use the same projection → validation/fallback → latch → final-guard sequence, return the retained `APPLICATION_FATAL`, retain the lock, and do not retry publication automatically.
9. Only publication success returns the immutable active-round record. There is no post-active pending record for a failed start because successful recovery has restored the pre-active run; the caller may begin a new round through a new normal request.

The player receives no quick-save recommendation.

- [ ] **Step 2.4: Implement the exact completion transaction**

- [ ] `complete_round()` uses this exact two-boundary transaction after its first-operation `state_port.guard_external(&"minesweeper_complete_round")` succeeds:

1. Validate nonempty `transaction_id` and call `_normalize_result_for_identity(result)` without consulting or mutating a live round.
2. Look up `transaction_id` in completed records **before** active-round validation. When found, require both `round_id == stored.receipt.round_id` and exact equality with `stored.normalized_result`; mismatch returns `TRANSACTION_ID_CONFLICT`, while equality returns a detached stored receipt with zero state/save/publish/lock calls.
3. If a pending record exists, require exact equality of `round_id`, `transaction_id`, and normalized result before any port call. A mismatch returns `TRANSACTION_ID_CONFLICT`; a match jumps directly to its recorded `publish` or `release_lock` phase.
4. Only when neither lookup exists, validate the matching active round ID and validate the normalized result against that active round through `MinesweeperRoundContract.validate_result()`.
5. Capture the pre-result state/save backups and call `prepare_complete()` for a detached prepared completion with an empty receipt checkpoint ID.
6. Apply context-allowed reward, task, counter, health/pressure, fainting, message, invitation, or dating-outcome effects to that candidate.
7. Pass exact completed-round counts before/after to ContactInvitationState; only 2 -> 3 on Day 2/6 can activate the group offer.
8. Call `save_port.preview_checkpoint_id(run_id)`, then `state_port.finalize_complete(prepared_completion, checkpoint_id)`; this owner method inserts the ID, validates the final candidate/receipt/events, and builds checkpoint inputs from that final candidate.
9. Call `save_port.prepare_checkpoint(finalized.post_result_checkpoint_inputs, &"post_result", {"kind":&"none","reason":&"stage"})` and reject unless its returned checkpoint ID exactly equals the preview. Neither call consumes a sequence; `post_result` is the checkpoint kind, while the frozen no-disk `disk_write` reason remains `stage`.
10. Commit the checkpoint candidate, then commit the finalized state candidate without signals. A commit failure rolls committed ports back in reverse order and attempts every required recovery even after an earlier recovery failure. Successful rollback leaves state, journal, receipt ledgers, checkpoint sequence, signals, active round, and lock byte-equal to the pre-call values. Any failed recovery uses the same ordered projection → validation/fallback → latch → final-guard sequence and returns only the retained `APPLICATION_FATAL`.
11. After both commits, write the non-failing in-memory pending record with the exact finalized receipt/event batch/checkpoint ID, detached normalized result, and `phase=publish`; this is the post-durable boundary. It never rolls either committed truth back after this point.
12. Call the pre-emission `state_port.publish(receipt, domain_events)`. Failure keeps both commits and the lock, returns `COMPLETION_COMMITTED_UNPUBLISHED`, and retains the pending record byte-equivalent.
13. An identical retry resumes only the pending phase; it never captures, previews, finalizes, prepares, commits, or rebuilds events. A conflicting round/result/transaction returns `TRANSACTION_ID_CONFLICT` without changing the pending record.
14. After successful publication, change pending phase to `release_lock`. Lock-release failure returns `LOCK_RELEASE_PENDING`; retry calls only `release_board_lock()` and does not republish.
15. On release success, store the exact completed record `{receipt,normalized_result}` for duplicate lookup, clear active/pending state, and return a detached receipt. The Step 2 lookup makes every later exact duplicate reachable even though no active round remains.

Thus validation, preparation, and either commit failure are pre-durable and roll back unchanged; publication/release failures are explicitly committed-but-unpublished or committed-and-published cleanup states. Unknown/mismatched results mutate nothing. Player close/route actions remain disabled while active or pending. Trusted fatal teardown may call `abort_round()` only before the post-durable boundary and only after its first-operation `state_port.guard_external(&"minesweeper_abort_round")` succeeds; it restores the captured pre-board run candidate, emits no result/reward, and releases the lock only after rollback succeeds. Its recovery failure uses the same projector/fallback/latch/final-guard path. Pending completion must be recovered through `complete_round()`, never aborted.

- [ ] Existing reward tests remain the authority for current money/pressure/task behavior. no_flag and foresight retain their approved perfect-equivalent reward semantics while recording their distinct outcome/task IDs.

- [ ] **Step 2.5: Prove silent lock and activation boundaries**

- [ ] During an active round:

~~~text
SaveManager.get_save_capability = disabled, silent, not deferred
manual save returns silent save_locked result
game_quick_save input is consumed/ignored
BackupApp save buttons are disabled if present
no notification/toast/dialog/recommendation signal fires
~~~

- [ ] Complete the third round on an eligible Day 2 and assert group AVAILABLE_UNOPENED, null inviter, zero group-offer history. Complete transitions 1 -> 2, 3 -> 4, wrong days, or ineligible/read solo offers and assert no activation.
- [ ] Inject failure at pre-board checkpoint prepare, journal commit, autosave promotion, lock acquisition, active-candidate commit, round-start publication, result candidate preparation, checkpoint-ID preview, completion finalization, preview/prepare ID mismatch, post-result checkpoint preparation, either commit, combined completion publication, lock release, and trusted abort rollback. Assert the exact state/sequence/file/lock invariant above at every point. Run both app and dating contexts; prove dating cannot consume/award/activate app state.
- [ ] Add named `test_minesweeper_recovery_nonprimitive_failure_projects_then_returns_retained_application_fatal`. For round-start publication failure, assert zero start emissions, restored pre-active state when recoveries succeed, released lock, and the exact pre-board checkpoint/autosave still committed. Inject state-rollback and lock-release recovery failures separately and together; always attempt both in order. Supply diagnostic details containing, in turn, a normalized-key collision, non-finite float, Object, Resource, Callable, packed bytes, and another packed array. Require exact sentinel reason/path with no rejected bytes, projection and full-failure validation before one latch, then one final guard and the gate's exact retained `APPLICATION_FATAL`—never outer `ROLLBACK_FAILED`, latch `ok`/conflict, or empty fatal details. Assert `is_fatal_latched()` true without an acquire owner, first-operation guard precedence for invalid/duplicate/pending direct coordinator calls with zero later port calls, one first-latch capability emission, InputManager permanently blocked despite stale enabled/release events, and no second publication. Repeat the identical failure for idempotence and race a different valid latch; the first failure and its exact details remain authoritative.
- [ ] Before every completion call, reset and capture per-method call counts for both fake ports. On `COMPLETION_COMMITTED_UNPUBLISHED`, assert exactly one preview/finalize/prepare/checkpoint-commit/state-commit and zero lock release; the exact retry increments only `publish` and then `release_board_lock`. On `LOCK_RELEASE_PENDING`, assert publication count remains one and each retry increments only `release_board_lock`. Checkpoint sequence, snapshot bytes, receipt, normalized result, and event batch remain byte-equivalent across retries.
- [ ] Retry each pending phase with (a) changed outcome, (b) changed round ID, and (c) changed transaction ID. Each returns `TRANSACTION_ID_CONFLICT`, performs zero port calls, and leaves pending bytes unchanged. After release success, call the exact duplicate with no active round and assert the detached stored receipt is returned with zero port calls; then vary outcome/round under the stored transaction and assert conflict.
- [ ] Finalize `ApplicationBootstrap.gd` and `project.godot` here. The literal autoload order is `ProfileManager`, `GameState`, `SaveManager`, `LocalizationManager`, `AudioManager`, `EffectResolver`, `SceneRouter`, `InputManager`, `AccessibilityManager`, `Dialogic`, `DialogicBridge`, `ApplicationBootstrap`. The exact final stage order is roots → one mutation gate/eight identities → profile → saves → localization → input → accessibility → audio → DialogicBridge/shared narrative checkpoint adapter/ending port → restore participants/one desktop host assigned behind the existing stable active-app Callable → day resolution/same real checkpoint port/direct desktop provider → Minesweeper coordinator → one desktop day-change connection → application_ready. `tests/integration/test_application_bootstrap.gd` injects one failure at every stage and proves one primitive-validated fatal result returned through the exact final guard, no later call/readiness, and disabled input; success proves every shared identity, proves the host assignment replaced no Plan-05 Callable/adapter/real-port/consumer identity, and proves exactly one day-change dispatch. The desktop-fatal and Minesweeper-fatal named tests prove both callers use the same projector source identity and sentinel/fallback bytes. No later Plan-06 task may change these eleven bound paths: `autoload/ApplicationBootstrap.gd`, `autoload/ApplicationBootstrap.gd.uid`, `tests/unit/test_application_bootstrap.gd`, `tests/unit/test_application_bootstrap.gd.uid`, `tests/integration/test_application_bootstrap.gd`, `tests/integration/test_application_bootstrap.gd.uid`, `project.godot`, `scripts/application/transaction/FatalDiagnosticProjector.gd`, `tests/unit/test_fatal_diagnostic_projector.gd`, `tests/integration/test_desktop_day_change_fatal.gd`, and `tests/integration/test_desktop_day_change_fatal.gd.uid`.

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'minesweeper_contract' -LogName 'phase2r-minesweeper-contract.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_minesweeper_round_contract.gd,res://tests/unit/test_minesweeper_rewards.gd,res://tests/unit/test_application_bootstrap.gd,res://tests/integration/test_application_bootstrap.gd,res://tests/integration/test_desktop_day_change_fatal.gd,res://tests/integration/test_narrative_checkpoint_wiring.gd,res://tests/integration/test_minesweeper_round_coordinator.gd,res://tests/integration/test_minesweeper_save_lock.gd','-gexit')
~~~

Expected GREEN: all fifteen fixtures traverse the real interface; first-operation fatal guards preserve the retained failure details; start ordering and start-publication recovery are exact; every pre-durable completion failure rolls back or returns the primitive-projected retained `APPLICATION_FATAL`; post-durable publication/release failures retain committed truth and resume only their recorded phase; exact duplicates work after active state clears; conflicting retries mutate nothing; the lock is silent; and group activation occurs only on the approved transition.

- [ ] **Step 2.6: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
$required = [ordered]@{
  'scripts/domain/minesweeper/MinesweeperRoundContract.gd'='A'
  'scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd'='A'
  'scripts/application/minesweeper/GameStateMinesweeperPort.gd'='A'
  'scripts/application/minesweeper/SaveManagerMinesweeperPort.gd'='A'
  'tests/fixtures/minesweeper/results.json'='A'
  'tests/support/FakeMinesweeperSavePort.gd'='A'
  'tests/support/FakeMinesweeperStatePort.gd'='A'
  'tests/support/FakeDesktopEvictionPort.gd'='A'
  'tests/unit/test_minesweeper_round_contract.gd'='A'
  'tests/unit/test_application_bootstrap.gd'='A'
  'tests/integration/test_application_bootstrap.gd'='A'
  'tests/integration/test_minesweeper_round_coordinator.gd'='A'
  'tests/integration/test_minesweeper_save_lock.gd'='A'
  'autoload/GameState.gd'='M'
  'autoload/ApplicationBootstrap.gd'='M'
  'project.godot'='M'
  'tests/unit/test_minesweeper_rewards.gd'='M'
}
$optionalUids = [ordered]@{
  'scripts/domain/minesweeper/MinesweeperRoundContract.gd.uid'='A'
  'scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd.uid'='A'
  'scripts/application/minesweeper/GameStateMinesweeperPort.gd.uid'='A'
  'scripts/application/minesweeper/SaveManagerMinesweeperPort.gd.uid'='A'
  'tests/support/FakeMinesweeperSavePort.gd.uid'='A'
  'tests/support/FakeMinesweeperStatePort.gd.uid'='A'
  'tests/support/FakeDesktopEvictionPort.gd.uid'='A'
  'tests/unit/test_minesweeper_round_contract.gd.uid'='A'
  'tests/unit/test_application_bootstrap.gd.uid'='A'
  'tests/integration/test_application_bootstrap.gd.uid'='A'
  'tests/integration/test_minesweeper_round_coordinator.gd.uid'='A'
  'tests/integration/test_minesweeper_save_lock.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or -not $expectedHead) { throw 'Cannot bind the Task 2 prerequisite HEAD.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 `
  -RequiredStatus $required `
  -OptionalPresentStatus $optionalUids `
  -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
  -ExpectedHead $expectedHead `
  -Message 'feat(handoff): define deterministic Minesweeper round contract'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 2 commit boundary failed.' }
~~~

## Task 3: Produce the Phase 3 handoff artifact and close .9

**Files:**

- Create: schemas/evidence/desktop-contract.schema.json
- Create: schemas/evidence/minesweeper-contract.schema.json
- Create: tools/evidence/DesktopContractEvidence.gd
- Create: tools/evidence/MinesweeperContractEvidence.gd
- Create: tools/evidence/generate_desktop_contract.gd
- Create: tools/evidence/validate_desktop_contract.gd
- Create: tools/evidence/generate_minesweeper_contract.gd
- Create: tools/evidence/validate_minesweeper_contract.gd
- Create: tests/unit/tooling/test_desktop_contract_evidence.gd
- Create: tests/unit/tooling/test_minesweeper_contract_evidence.gd
- Generate: evidence/phase_2r/handoff/desktop_contract.json
- Generate: evidence/phase_2r/handoff/minesweeper_contract.json
- Generate: evidence/phase_2r/handoff/phase3_contracts.commands.jsonl
- Bind source bytes without Task-3 mutation: autoload/ApplicationBootstrap.gd
- Bind source bytes without Task-3 mutation: autoload/ApplicationBootstrap.gd.uid
- Bind source bytes without Task-3 mutation: tests/unit/test_application_bootstrap.gd
- Bind source bytes without Task-3 mutation: tests/unit/test_application_bootstrap.gd.uid
- Bind source bytes without Task-3 mutation: tests/integration/test_application_bootstrap.gd
- Bind source bytes without Task-3 mutation: tests/integration/test_application_bootstrap.gd.uid
- Bind source bytes without Task-3 mutation: scripts/application/transaction/FatalDiagnosticProjector.gd
- Bind source bytes without Task-3 mutation: tests/unit/test_fatal_diagnostic_projector.gd
- Bind source bytes without Task-3 mutation: tests/integration/test_desktop_day_change_fatal.gd
- Bind source bytes without Task-3 mutation: tests/integration/test_desktop_day_change_fatal.gd.uid
- Bind source bytes without Task-3 mutation: project.godot
- Update generated: prompt_docs/INDEX.md
- Update evidence links only: prompt_docs/requirements/desktop_minesweeper_handoff.md

**Interfaces:**

- Consumes: Tasks 1–2 contract results, the final Task-2 Bootstrap/project bytes, canonical JSON tooling, source SHA-256, and isolated command records.
- Produces: `DesktopContractEvidence.build()/validate()` and `MinesweeperContractEvidence.build()/validate()`, two generator/validator CLI pairs, two strict versioned schemas, two canonical source-bound Phase-3 handoff artifacts, one seven-record immutable command ledger, and closed `.9`; no runtime code.

- [ ] **Step 3.1: Generate and validate both handoff artifacts**

Write both tooling tests before either evidence class/CLI. Each first test dynamically loads its evidence class and expects `missing_script`; after implementation both MUST:

1. Strict-parse the schema and artifact with duplicate-member rejection.
2. Require its matching schema validation and evidence-class `validate()` success.
3. Recompute every source SHA-256 and require exact ordered binding equality.
4. Rebuild the artifact from production constants and require canonical byte equality with the checked-in artifact.
5. Mutate each top-level field, nested contract record, and source binding in isolated copies; each mutation must fail. Desktop mutations cover all registry records, every host/persistence/bootstrap/eviction-port signature, the shared fatal-projector schema/fallback, exact final-guard return, the stable narrative active-app Callable and unchanged adapter/real-port/consumer identity record, result schema, day-change owner/once rule, Phase-3 prohibition, source path/hash, and Logout row. Minesweeper mutations cover every port signature including `latch_fatal`/`is_fatal_latched`/`guard_external`, projector/fallback/final-guard order, retained fatal details, `normalized_result`, the `reason=stage` post-result call, both retry phases, every source hash, and one fixture ID. For each artifact, delete, reorder, path-rename, or hash-corrupt every mandatory binding one at a time; every case fails closed.

Expected RED command before implementation:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase3_handoff_evidence_red' -LogName 'phase2r-red-phase3-handoff-evidence.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/tooling/test_desktop_contract_evidence.gd,res://tests/unit/tooling/test_minesweeper_contract_evidence.gd','-gexit') -EvidenceLogPath 'evidence/phase_2r/logs/isolated-godot.jsonl'
~~~

`desktop-contract.schema.json` rejects duplicate/unknown members and defines exactly this closed top-level field set; `CanonicalJsonWriter` alone determines serialized object-key order:

~~~text
schema_version = 1
artifact_id = "phase_2r.desktop_contract"
interface_version = 1
source_bindings[] {path, sha256}
registry_version
registry_records[]
host_signatures
host_result_schemas
persistence_signatures
bootstrap_signatures
day_change_owner
logout_contract
phase_split
~~~

Its `source_bindings`, sorted by UTF-8 path bytes, are exactly:

~~~text
autoload/ApplicationBootstrap.gd
autoload/ApplicationBootstrap.gd.uid
autoload/DialogicBridge.gd
autoload/GameState.gd
project.godot
scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd
scripts/application/restore/RouteRestoreParticipant.gd
scripts/application/run/SaveManagerCheckpointPort.gd
scripts/application/transaction/ApplicationMutationGate.gd
scripts/application/transaction/FatalDiagnosticProjector.gd
scripts/domain/desktop/DesktopAppHostState.gd
scripts/domain/desktop/DesktopAppRegistry.gd
scripts/domain/desktop/LogoutPolicy.gd
scripts/domain/run/RunSnapshotSchema.gd
tests/integration/test_application_bootstrap.gd
tests/integration/test_application_bootstrap.gd.uid
tests/integration/test_desktop_day_change_fatal.gd
tests/integration/test_desktop_day_change_fatal.gd.uid
tests/integration/test_narrative_checkpoint_wiring.gd
tests/integration/test_narrative_checkpoint_wiring.gd.uid
tests/integration/test_restore_production_adapters.gd
tests/support/FakeDesktopEvictionPort.gd
tests/unit/test_application_bootstrap.gd
tests/unit/test_application_bootstrap.gd.uid
tests/unit/test_desktop_app_host_state.gd
tests/unit/test_desktop_app_registry.gd
tests/unit/test_fatal_diagnostic_projector.gd
tests/unit/test_logout_policy.gd
tests/unit/test_run_snapshot_schema.gd
~~~

`persistence_signatures` states exactly that Plan 05's stable Bootstrap `active_app_id` Callable returns raw JSON null before host injection and the one host's raw registered app-ID String or JSON null afterward; it never returns a CommandResult wrapper. Its Callable identity, the one configured `SaveManagerNarrativeCheckpointPort`, the retained real `SaveManagerCheckpointPort`, and DialogicBridge/GameState adapter identities never change; the direct checkpoint provider reads that same host. `day_change_owner` states exactly: Bootstrap owns one signal connection; it calls `change_day(new_day)` once; that returns one `{command_id,kind,day,app_ids}` eviction command; Bootstrap dispatches it once through the sole registered `dispatch_desktop_eviction(command)` port; Phase 3 only registers/consumes that port and is forbidden to connect `day_changed`, access the host, or call `change_day`. A missing/failing dispatch records one closed raw diagnostic, uses the source-bound shared projector and constant invariant fallback, latches once, and returns the final guard's exact retained primitive `APPLICATION_FATAL`. `phase_split` records that visible composition remains Phase 3. Every registry ID/scene/focus record and every exact signature/result shape comes from Task 1 production constants or frozen source contracts, not duplicated free-form values.

`minesweeper-contract.schema.json` rejects duplicate/unknown members and defines exactly this closed top-level field set; `CanonicalJsonWriter` alone determines serialized object-key order:

~~~text
schema_version = 1
artifact_id = "phase_2r.minesweeper_contract"
interface_version = 1
source_bindings[] {path, sha256}
difficulties[]
outcomes[]
start_request_schema
active_round_schema
port_signatures
prepared_value_schemas
completion_receipt_schema
pending_record_schema
fatal_latch_contract
failure_codes[]
start_order[]
completion_order[]
fixture_ids[]
save_lock_contract
phase_split
~~~

`source_bindings` is sorted by UTF-8 path bytes and contains exactly these paths—no inferred, omitted, extra, or glob-expanded binding is permitted:

~~~text
autoload/ApplicationBootstrap.gd
autoload/ApplicationBootstrap.gd.uid
autoload/GameState.gd
project.godot
scripts/application/minesweeper/GameStateMinesweeperPort.gd
scripts/application/minesweeper/SaveManagerMinesweeperPort.gd
scripts/application/transaction/ApplicationMutationGate.gd
scripts/application/transaction/FatalDiagnosticProjector.gd
scripts/domain/minesweeper/MinesweeperRoundContract.gd
scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd
tests/fixtures/minesweeper/results.json
tests/integration/test_application_bootstrap.gd
tests/integration/test_application_bootstrap.gd.uid
tests/integration/test_minesweeper_round_coordinator.gd
tests/integration/test_minesweeper_save_lock.gd
tests/integration/test_restore_mutation_gate.gd
tests/support/FakeApplicationMutationGate.gd
tests/support/FakeMinesweeperSavePort.gd
tests/support/FakeMinesweeperStatePort.gd
tests/unit/test_application_bootstrap.gd
tests/unit/test_application_bootstrap.gd.uid
tests/unit/test_fatal_diagnostic_projector.gd
tests/unit/test_minesweeper_rewards.gd
tests/unit/test_minesweeper_round_contract.gd
~~~

Hashes are lowercase SHA-256 over exact file bytes. `port_signatures`, prepared values, receipt, pending record—including exact `normalized_result`—failure codes, ordering arrays, save-lock values, and fatal-latch delegation are mechanical transcriptions of Task 2. The fatal record requires the state port's three exact gate methods, one shared ApplicationMutationGate identity, first-operation guard precedence, the source-bound projector's closed primitive/sentinel/fallback rules, completed recovery attempts before projection, projection → full validation/fallback → one latch → final guard ordering, first-failure/idempotence/conflict behavior, no fatal acquire owner or coordinator-local cache, exact retained-failure `APPLICATION_FATAL` results, and permanent input block. `ROLLBACK_FAILED` is inner fatal identity only. The completion order records the literal post-result call with `checkpoint_kind="post_result"`, `disk_write.kind="none"`, and `disk_write.reason="stage"`. `phase_split` states that Phase 3 labels its selector as a deterministic result simulator and calls only GameState begin/complete methods; it never mutates rewards, counters, invitations, or the fatal gate. Phase 6 replaces only the simulator adapter and retains every contract/domain test.

Each evidence class imports production constants, constructs only its closed tree, computes bindings from exact bytes, validates its own result, and returns a detached primitive tree. Each generator canonical-serializes to a same-directory temporary file, strict-parses/revalidates, and atomically promotes. Each validator strict-parses artifact and schema, applies schema plus semantic validation, rebuilds expected canonical bytes, and prints only `DESKTOP_HANDOFF: PASS interface_version=1` or `MINESWEEPER_HANDOFF: PASS interface_version=1`. Any artifact byte drift, including final Bootstrap/project/source-binding drift, fails freshness.

- [ ] **Step 3.2: Run the exact handoff gate**

~~~powershell
& .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-all.json'
if (Test-Path -LiteralPath 'evidence/phase_2r/handoff/phase3_contracts.commands.jsonl') { throw 'Handoff command record already exists; use a versioned artifact instead of appending across executions.' }
$ledger = 'evidence/phase_2r/handoff/phase3_contracts.commands.jsonl'
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase3_desktop_generate' -LogName 'phase2r-phase3-desktop-generate.log' -GodotArgs @('-s','res://tools/evidence/generate_desktop_contract.gd') -EvidenceLogPath $ledger
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase3_desktop_validate' -LogName 'phase2r-phase3-desktop-validate.log' -GodotArgs @('-s','res://tools/evidence/validate_desktop_contract.gd') -EvidenceLogPath $ledger
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase3_minesweeper_generate' -LogName 'phase2r-phase3-minesweeper-generate.log' -GodotArgs @('-s','res://tools/evidence/generate_minesweeper_contract.gd') -EvidenceLogPath $ledger
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase3_minesweeper_validate' -LogName 'phase2r-phase3-minesweeper-validate.log' -GodotArgs @('-s','res://tools/evidence/validate_minesweeper_contract.gd') -EvidenceLogPath $ledger
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase3_handoff_contracts' -LogName 'phase2r-phase3-handoff-contracts.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_desktop_app_registry.gd,res://tests/unit/test_desktop_app_host_state.gd,res://tests/unit/test_logout_policy.gd,res://tests/unit/test_fatal_diagnostic_projector.gd,res://tests/unit/test_minesweeper_round_contract.gd,res://tests/unit/test_minesweeper_rewards.gd,res://tests/unit/test_application_bootstrap.gd,res://tests/unit/tooling/test_desktop_contract_evidence.gd,res://tests/unit/tooling/test_minesweeper_contract_evidence.gd,res://tests/integration/test_application_bootstrap.gd,res://tests/integration/test_desktop_day_change_fatal.gd,res://tests/integration/test_narrative_checkpoint_wiring.gd,res://tests/integration/test_minesweeper_round_coordinator.gd,res://tests/integration/test_minesweeper_save_lock.gd','-gexit') -EvidenceLogPath $ledger
~~~

Strict-parse those first five JSONL lines, require their suite IDs/order/exits, and compute each `command_record_id` as lowercase SHA-256 over the exact compact UTF-8 line bytes excluding its newline. Update `desktop_minesweeper_handoff.md` through `apply_patch` with separate evidence links whose `path` and `sha256` bind the immutable desktop/minesweeper artifact bytes and whose `command_record_id` binds each artifact's generate, validate, and shared contract-test line. Do not bind the still-growing whole JSONL hash inside the document. Then regenerate and validate the index as the final two recorded commands:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase3_handoff_index' -LogName 'phase2r-phase3-handoff-index.log' -GodotArgs @('-s','res://tools/docs/generate_index.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json') -EvidenceLogPath $ledger
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase3_handoff_docs' -LogName 'phase2r-phase3-handoff-docs.log' -GodotArgs @('-s','res://tools/docs/validate_docs.gd','--','--beads-snapshot=res://.godot/beads/phase2r-all.json') -EvidenceLogPath $ledger
~~~

Expected GREEN: the JSONL strict-parses as exactly seven isolated command records in the written order, every exit is zero, documentation errors are `0`, both artifacts have canonical byte equality with fresh builds, every binding hash matches the final Task-2 bytes, and every handoff schema/contract/reward/retry/day-owner/fatal-latch test passes. For each `.9` requirement, append only structured evidence links containing `requirement_id`, artifact path, current lowercase artifact SHA-256, and the SHA-256 command-record ID of the supporting compact JSONL line. After the seventh record, bind the final JSONL path/SHA-256 in Beads issue evidence without changing the validated requirement document. The docs/index records prove the already-linked final document bytes and do not trigger another document edit. Close `.9` only after both authoritative artifacts and all links validate; bare paths or unbound log names are insufficient.

- [ ] **Step 3.3: Proposed path-specific commit boundary**

~~~powershell
$required = [ordered]@{
  'schemas/evidence/desktop-contract.schema.json'='A'
  'schemas/evidence/minesweeper-contract.schema.json'='A'
  'tools/evidence/DesktopContractEvidence.gd'='A'
  'tools/evidence/MinesweeperContractEvidence.gd'='A'
  'tools/evidence/generate_desktop_contract.gd'='A'
  'tools/evidence/validate_desktop_contract.gd'='A'
  'tools/evidence/generate_minesweeper_contract.gd'='A'
  'tools/evidence/validate_minesweeper_contract.gd'='A'
  'tests/unit/tooling/test_desktop_contract_evidence.gd'='A'
  'tests/unit/tooling/test_minesweeper_contract_evidence.gd'='A'
  'evidence/phase_2r/handoff/desktop_contract.json'='A'
  'evidence/phase_2r/handoff/minesweeper_contract.json'='A'
  'evidence/phase_2r/handoff/phase3_contracts.commands.jsonl'='A'
  'prompt_docs/INDEX.md'='M'
  'prompt_docs/requirements/desktop_minesweeper_handoff.md'='M'
}
$optionalUids = [ordered]@{
  'tools/evidence/DesktopContractEvidence.gd.uid'='A'
  'tools/evidence/MinesweeperContractEvidence.gd.uid'='A'
  'tools/evidence/generate_desktop_contract.gd.uid'='A'
  'tools/evidence/validate_desktop_contract.gd.uid'='A'
  'tools/evidence/generate_minesweeper_contract.gd.uid'='A'
  'tools/evidence/validate_minesweeper_contract.gd.uid'='A'
  'tests/unit/tooling/test_desktop_contract_evidence.gd.uid'='A'
  'tests/unit/tooling/test_minesweeper_contract_evidence.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or -not $expectedHead) { throw 'Cannot bind the Task 3 prerequisite HEAD.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 `
  -RequiredStatus $required `
  -OptionalPresentStatus $optionalUids `
  -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
  -ExpectedHead $expectedHead `
  -Message 'docs(handoff): freeze Phase 3 desktop and Minesweeper contracts'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 3 commit boundary failed.' }
~~~

## Task 4: Replace off-tree scene smoke with an on-tree lifecycle harness

**Beads:** dwm-p2r.10

**Files:**

- Create: tests/support/OnTreeSceneHarness.gd
- Create: tests/smoke_phase2r_on_tree.gd
- Create: tests/scene/test_phase2r_scene_lifecycle.gd
- Create: tools/testing/DiagnosticAttributor.gd
- Bind/read-only: autoload/ApplicationBootstrap.gd
- Bind/read-only: autoload/ApplicationBootstrap.gd.uid
- Bind/read-only: tests/unit/test_application_bootstrap.gd
- Bind/read-only: tests/unit/test_application_bootstrap.gd.uid
- Bind/read-only: tests/integration/test_application_bootstrap.gd
- Bind/read-only: tests/integration/test_application_bootstrap.gd.uid
- Bind/read-only: tests/integration/test_narrative_checkpoint_wiring.gd
- Bind/read-only: tests/integration/test_narrative_checkpoint_wiring.gd.uid
- Bind/read-only: scripts/application/transaction/FatalDiagnosticProjector.gd
- Bind/read-only: tests/unit/test_fatal_diagnostic_projector.gd
- Bind/read-only: tests/integration/test_desktop_day_change_fatal.gd
- Bind/read-only: tests/integration/test_desktop_day_change_fatal.gd.uid
- Bind/read-only: project.godot
- Bind/read-only: evidence/phase_2r/handoff/desktop_contract.json
- Bind/read-only: evidence/phase_2r/handoff/minesweeper_contract.json
- Replace: tests/smoke_load_scenes.gd
- Generate: evidence/phase_2r/scenes/on_tree_results.json

**Interfaces:**

- Consumes read-only: Task 2's final Bootstrap/project/test bytes, Task 3's fresh handoff artifacts, all final manager initializers, and the exact 28-scene baseline below.
- Produces: awaited on-tree lifecycle/diagnostic evidence against the already-frozen startup orchestrator; all manager `_ready()` methods remain side-effect-free and no `.9` binding changes.

- [ ] **Step 4.1: Claim .10 only after every implementation issue closes**

- [ ] Run:

~~~powershell
bd show dwm-p2r.1 --json
bd show dwm-p2r.2 --json
bd show dwm-p2r.3 --json
bd show dwm-p2r.4 --json
bd show dwm-p2r.5 --json
bd show dwm-p2r.6 --json
bd show dwm-p2r.7 --json
bd show dwm-p2r.8 --json
bd show dwm-p2r.9 --json
bd update dwm-p2r.10 --claim
~~~

All nine statuses must be closed.

- [ ] **Step 4.2: Write the on-tree harness RED test**

- [ ] OnTreeSceneHarness exposes:

~~~gdscript
func instantiate_on_tree(
	scene_path: String,
	parent: Node,
	frames: int = 2
) -> Dictionary
func free_on_tree(instance: Node, frames: int = 2) -> Dictionary
~~~

- [ ] For every required Phase 2R scene, it loads/instantiates, adds under the active SceneTree, awaits ready plus two process frames, verifies expected unique nodes/signals/focus/navigation contracts, queue_frees, awaits two frames, and asserts the WeakRef is dead.

- [ ] The exact production scene list is:

~~~text
res://scenes/menu/MenuScene.tscn
res://scenes/menu/GalleryScene.tscn
res://scenes/menu/Setting.tscn
res://scenes/opening/OpeningScene.tscn
res://scenes/main/MainGameScene.tscn
res://scenes/desktop/ComputerDesktop.tscn
res://scenes/apps/MinesweeperApp.tscn
res://scenes/apps/ContactListApp.tscn
res://scenes/apps/ShopApp.tscn
res://scenes/apps/ScheduleApp.tscn
res://scenes/apps/SettingsApp.tscn
res://scenes/apps/LogOutApp.tscn
res://scenes/apps/BackupApp.tscn
res://scenes/overlay/TutorialOverlay.tscn
res://scenes/ending/EndingScene.tscn
res://scenes/hospital/HospitalScene.tscn
res://scenes/dating/DatingScene.tscn
res://scenes/dating/MinesweeperChallengeOverlay.tscn
res://scenes/shared/BoxMeter.tscn
res://scenes/shared/StatHud.tscn
res://scenes/shared/AppWindowBase.tscn
res://scenes/shared/IconButton.tscn
res://scenes/shared/ContactBox.tscn
res://scenes/shared/ChatBubble.tscn
res://scenes/shared/ShopItemBox.tscn
res://scenes/shared/ScheduleEntryBox.tscn
res://scenes/shared/SaveSlotRow.tscn
res://scenes/shared/DialogueBox.tscn
~~~

Test-only fixture scenes are listed in a separate exact `fixture_scene_paths` array generated from their manifest; they never change the production count of 28. The generated result lists every path individually; a missing/unexecuted path fails.

- [ ] Before the harness runs, validate both handoff artifacts and recompute every bound source hash, including `autoload/ApplicationBootstrap.gd/.uid`, both Bootstrap tests/UIDs, `tests/integration/test_narrative_checkpoint_wiring.gd/.uid`, `scripts/application/transaction/FatalDiagnosticProjector.gd`, its projector/desktop-fatal tests, and `project.godot`. `project.godot` must still have Task 2's literal autoload order; the stable narrative active-app Callable/shared adapter/real checkpoint port/consumer identities and fatal projector/final-guard contract must still match Task 2; and ApplicationMutationGate remains a runtime RefCounted, not an autoload. Task 4 tests the frozen orchestrator on-tree; it does not edit or restate its implementation.
- [ ] If any on-tree finding requires a change to ApplicationBootstrap, either Bootstrap test/UID, the narrative-checkpoint identity test/UID, the fatal projector or either fatal-path test/UID, project.godot, or either handoff-bound contract, stop `.10`, reopen `dwm-p2r.9`, make the correction under Task 1 or Task 2 ownership as named above, regenerate/revalidate both Task-3 artifacts and their seven-record ledger, recommit/close `.9`, then restart Task 4. Editing a bound path under `.10` or accepting a stale artifact is forbidden.

- [ ] **Step 4.3: Replace immediate off-tree free behavior**

- [ ] tests/smoke_load_scenes.gd becomes a compatibility wrapper that invokes smoke_phase2r_on_tree.gd. It is retained and modified in Phase 2R, matching this task's exact `M` commit status, and must no longer instantiate/free off-tree in one frame.
- [ ] Capture project-owned error, orphan, unfreed-child, and retained-resource diagnostics by scene. Third-party diagnostics receive separate fingerprints and are not silently counted as project success.

- [ ] Run:

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'on_tree_scenes' -LogName 'phase2r-on-tree-scenes.log' -GodotArgs @('-s','res://tests/smoke_phase2r_on_tree.gd')
~~~

Expected GREEN: every path passes ready/focus/free checks; project-owned diagnostics are zero.

- [ ] **Step 4.4: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
$required = [ordered]@{
  'tests/support/OnTreeSceneHarness.gd'='A'
  'tests/smoke_phase2r_on_tree.gd'='A'
  'tests/scene/test_phase2r_scene_lifecycle.gd'='A'
  'tools/testing/DiagnosticAttributor.gd'='A'
  'tests/smoke_load_scenes.gd'='M'
  'evidence/phase_2r/scenes/on_tree_results.json'='A'
}
$optionalUids = [ordered]@{
  'tests/support/OnTreeSceneHarness.gd.uid'='A'
  'tests/smoke_phase2r_on_tree.gd.uid'='A'
  'tests/scene/test_phase2r_scene_lifecycle.gd.uid'='A'
  'tools/testing/DiagnosticAttributor.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or -not $expectedHead) { throw 'Cannot bind the Task 4 prerequisite HEAD.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 `
  -RequiredStatus $required `
  -OptionalPresentStatus $optionalUids `
  -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
  -ExpectedHead $expectedHead `
  -Message 'test(scenes): exercise Phase 2R scenes on-tree'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 4 commit boundary failed.' }
~~~

## Task 5: Run consequential Day 1–7 scenarios

**Beads:** dwm-p2r.10

**Files:**

- Create: tests/scenario/test_days_1_to_7.gd
- Create: tests/scenario/test_restore_mid_resolution.gd
- Create: tests/scenario/test_logout_resume.gd
- Generate: evidence/phase_2r/scenarios/results.json

**Interfaces:**

- Consumes: the same production facade/coordinator/restore/round/playback seams used by UI; no manual receipt walking.
- Produces: deterministic Day-1–7 equivalence evidence for uninterrupted and restored runs.

- [ ] **Step 5.1: Prove the ordinary full run**

- [ ] A deterministic run starts PLAYING Day 1, completes one valid schedule each day, advances exactly once through Days 2–7, resolves ending.alone on Day 7, writes ending autosave before playback, records gallery once, transitions ENDING -> COMPLETED, and routes Menu.

Assertions:

~~~text
observed days = [1,2,3,4,5,6,7]
observed current Day 8 count = 0
day_changed signal count = 6
Day 7 next-day message count = 0
primary playback count = 1
epilogue playback count = 0
gallery transaction count = 1
final route = menu
~~~

- [ ] **Step 5.2: Prove cross-domain difficult paths**

- [ ] Table-driven scenarios include:

~~~text
Hospital before deferred twofriends and one advancement
every solo invitation resolution row
every group invitation resolution row
one-reply attended judgment variation
Day 7 Hospital before ending and no twofriends
primary plus optional group epilogue and two gallery transactions
restore after each DayResolutionPlan stage
restore after each ending playback stage
greatest earlier compatible whole-bundle recovery
both skip modes and all six stop boundaries
pre-board autosave, silent active-board lock, post-result unlock
logout with and without a stable checkpoint
~~~

Every scenario runs from fresh defaults under a unique storage root and uses deterministic fixtures, not wall clock or random outcomes.

- [ ] **Step 5.3: Verify restored idempotence**

- [ ] test_restore_mid_resolution.gd snapshots immediately after each stage/substage completion, restores, and completes the run. Compare it with an uninterrupted reference run: gameplay, history, receipts, checkpoints, routes, ending plan, gallery, and profile must be equal.

~~~powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'scenario_gate' -LogName 'phase2r-scenarios.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gdir=res://tests/scenario','-ginclude_subdirs','-gexit')
~~~

Expected GREEN: all consequential scenarios and uninterrupted/restored equivalence pass.

- [ ] **Step 5.4: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
$required = [ordered]@{
  'tests/scenario/test_days_1_to_7.gd'='A'
  'tests/scenario/test_restore_mid_resolution.gd'='A'
  'tests/scenario/test_logout_resume.gd'='A'
  'evidence/phase_2r/scenarios/results.json'='A'
}
$optionalUids = [ordered]@{
  'tests/scenario/test_days_1_to_7.gd.uid'='A'
  'tests/scenario/test_restore_mid_resolution.gd.uid'='A'
  'tests/scenario/test_logout_resume.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or -not $expectedHead) { throw 'Cannot bind the Task 5 prerequisite HEAD.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 `
  -RequiredStatus $required `
  -OptionalPresentStatus $optionalUids `
  -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
  -ExpectedHead $expectedHead `
  -Message 'test(flow): prove deterministic Day 1 to Day 7 scenarios'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 5 commit boundary failed.' }
~~~

## Task 6: Build and preflight the blocking Phase 2R evidence gate

**Beads:** dwm-p2r.10

**Files:**

- Create: tools/evidence/Phase2RGate.gd
- Create: tools/evidence/validate_phase_2r.gd
- Create: tools/evidence/run_phase2r_gate.ps1
- Create: schemas/evidence/phase2r-final.schema.json
- Create: schemas/evidence/diagnostic-exception.schema.json
- Create: schemas/evidence/phase2r-validator-run.schema.json
- Create: tests/unit/tooling/test_phase2r_gate.gd

**Interfaces:**

- Consumes: `Invoke-IsolatedGodot.ps1`, all validators/smokes, `bd` read-only checks, storage-access probe, and diagnostic attribution.
- Produces: a preflighted runner whose finite subject-command set and two-pass validator are non-circular. Task 7 runs it in `Full` mode only after final documentation cleanup.

- [ ] **Step 6.1: Make missing evidence fail first**

- [ ] test_phase2r_gate.gd loads every active approved, Phase-2R-blocking requirement from generated docs and fails if implementation_evidence or verification_evidence is empty, missing, stale, schema-invalid, or reports a nonzero result.
- [ ] It also fails on any unconditional pass, production-path test access, project-owned diagnostic, config-version defect, manifest drift, docs-index drift, active CodeGraph consumer, current Day 8 state, or unresolved non-deferred decision.
- [ ] Its injected Git/Beads verifier fixtures accept exactly the pre-closure chain `S -> E` and post-closure chain `S -> E -> B`. `S` contains both tracked Beads journals whose strict state is `.1` through `.9=closed`, `.10=in_progress`, and epic `dwm-p2r=open`; `E` changes neither journal; `B` changes exactly those same two paths and proves `.1` through `.10` plus the epic closed. Isolated mutations add a merge parent, skip/reverse a parent, add/remove/rename one path in either diff, alter one evidence blob between `E` and `B`, put any pre/post issue in the wrong status, change either Beads journal in `E`, omit either journal from `S`/`B`, add a third `B` path, or dirty the index/worktree; every mutation must fail. The valid post-closure fixture retains the pre-closure/in-progress-`.10` `final.json` bytes unchanged and proves current closure separately.

- [ ] **Step 6.2: Execute the checked-in fail-safe orchestrator**

- [ ] `run_phase2r_gate.ps1` exposes exactly `param([ValidateSet('Preflight','Full','VerifyExisting')][string]$Mode='Full')`. `Full` creates one GUID evidence root and records this finite subject set before validation: four Beads children (`bd dep cycles`, `bd lint`, `bd orphans`, `bd list --status all --json --readonly`) and six isolated Godot children (`import`, `GUT`, `on_tree_scenes`, `dialogic_fixture`, `docs`, `manifests`). `commands.json` contains exactly those ten completed records; validator processes are deliberately not subjects and the schema rejects any eleventh record.

The non-circular outer protocol is exact:

~~~text
1. Run all ten subjects independently; always write commands.json, including nonzero exits.
2. Run validate_phase_2r.gd --mode=build once all subject records and six immutable subject logs exist. Redirect this child to a new `final-validator-build.log`; it validates only the finite subject set, hashes only commands.json and the six already-completed subject logs, and writes final.json. It never reads or hashes its own log.
3. Wait for the build child and its log handle to close. Re-read immutable final.json/build-log bytes, then the PowerShell parent writes validator-run.json with completed argv, exit, start/end, build-log SHA-256, validator-script SHA-256, and final.json SHA-256. Any later byte change fails.
4. Run validate_phase_2r.gd --mode=verify-closure against final.json and validator-run.json with stdout/stderr redirected to a distinct new `final-validator-closure.log`. It validates the completed build record and bytes, writes no JSON, never reads/hashes its own log, and exits before any seal check.
5. Wait for the closure child/log handle to close; require its exact terminal PASS record and immutable bytes. `verify-seal-input` later validates the two completed log roles/contents and all recorded hashes without writing either log.
6. Return nonzero when any subject, build pass, closure pass, schema, copy, or cleanup fails. Never use PowerShell's continue-after-error behavior.
~~~

The validator also exposes read-only `--mode=verify-seal-input --expected-subject-commit=<full-object-id>`. It strict-validates the completed Full artifacts, requires `final.json.worktree.subject_commit` to equal that exact object ID, and writes nothing. This mode is used only as the pre-staging seal assertion in Task 7.

The eight final logs are the six subject logs plus immutable `final-validator-build.log` and `final-validator-closure.log`. The build log is hashed only after its producer exits and is then bound by validator-run.json; the closure log is created only after validator-run.json is immutable and is bound by the evidence commit. No process opens either completed log for append. `Preflight` runs the GUT contract with synthetic completed subject/validator fixtures and writes no `evidence/phase_2r/final.json`. `VerifyExisting` reruns the closure checks with all output directed to stdout only; it MUST NOT append, touch timestamps, rewrite, or create any repository evidence path.

`VerifyExisting` derives one of exactly two accepted ancestry shapes without an input flag. Let `S = final.json.worktree.subject_commit`, let `E` be the evidence-seal commit, let `B` be the optional Beads-closure commit, let `P_e` be the exact eleven closed evidence paths (three JSON plus eight logs), and let `P_b = {".beads/interactions.jsonl", ".beads/issues.jsonl"}`:

~~~text
pre-closure:  HEAD == E; E has sole parent S; diff S..E == P_e
post-closure: HEAD == B; B has sole parent E; E has sole parent S; diff S..E == P_e; diff E..B == P_b
~~~

Any merge, skipped parent, extra/missing path, reversed ancestry, or third shape rejects. In both shapes every current evidence path must equal its blob in `E`, the subject tree/requirements/commands/completed-log hashes must still validate, and the index/worktree must be empty outside ignored `.godot` scratch output. The pre-closure shape additionally requires both committed `S` journal blobs and Full's read-only record to agree exactly: `.1` through `.9` closed, `.10` in_progress, and epic open. The post-closure shape requires every Phase-2R child `.1` through `.10` and epic `dwm-p2r` to be closed in `B`'s committed Beads state, requires all eleven evidence blobs at `B` to be byte-identical to `E`, and permits `dwm-eob` only as the separately scoped nonblocking deferred issue. Thus closure is proven from `B` without rewriting or asking `final.json` to predict `E`, `B`, or its own future state.

- [ ] Preflight from repository root before any final document deletion:

~~~powershell
& .\tools\evidence\run_phase2r_gate.ps1 -Mode Preflight
~~~

- [ ] **Step 6.3: Require exact final outcomes**

- [ ] In Task 7 Full mode, final.json records the ten subject argv/exit records, engine/addon/tool versions, test/assertion counts, per-scene results, diagnostic fingerprints, requirement IDs, evidence paths, and the post-cleanup worktree identity. It never claims to contain its currently running validator.

`final.json.worktree.subject_commit` and `subject_tree` identify the clean Task-7 cleanup commit/tree tested by all ten subjects. Its committed Beads journals and read-only Beads result both represent the pre-closure state exactly: `.1` through `.9` are closed, `.10` is in_progress, epic `dwm-p2r` is open, and their later closure is not claimed by `Full`. The closed seal set is `commands.json`, `validator-run.json`, `final.json`, six subject logs, `final-validator-build.log`, and `final-validator-closure.log`. These eleven output paths are excluded only from the subject-status comparison because they do not exist until `Full`; every other status entry fails. `final.json` hashes commands and only the six already-completed subject logs; after the build process/log closes, `validator-run.json` hashes `final.json`, the build-validator script, and the immutable build log; the closure log is written separately after those bytes freeze; the later Git evidence-seal commit binds all eleven output blobs. No artifact stores the future evidence-commit ID, Beads-closure commit ID, post-closure issue state, closure log's own hash, or its own hash, avoiding self-reference; the final read-only `VerifyExisting` pass proves closure separately from committed ancestry and current committed Beads bytes.

It fails unless:

~~~text
import exit = 0
GUT failed = 0
on-tree scene failures = 0
Dialogic fixture failures = 0
documentation errors = 0
manifest/schema errors = 0
project-owned orphan nodes = 0
project-owned unfreed children = 0
project-owned retained resources = 0
unexpected errors = 0
unconditional-pass stubs = 0
production persistence paths reached by tests = 0
current-state Day 8 occurrences = 0
dependency cycles = 0
blocking approved requirements without passing evidence = 0
~~~

- [ ] A third-party exception is allowed only if its JSON record contains exact fingerprint, owner=third_party, package/version, reason, created_on, expires_on, and a reproduction command. An expired/mismatched record fails. Project-owned diagnostics cannot be excepted.
- [ ] In test mode, the sole FileOps/JsonFileStorage persistence path records every resolved root + relative path. The gate fails if any write/read root is outside that command's GUID root. A source audit rejects raw profile/save/input persistence access outside the approved storage layer. DiagnosticAttributor classifies records as project only when the stack/source path is outside `addons/**`; unattributed diagnostics fail instead of being silently called third-party.

- [ ] **Step 6.4: Proposed commit boundary (requires explicit commit authority)**

~~~powershell
$required = [ordered]@{
  'tools/evidence/Phase2RGate.gd'='A'
  'tools/evidence/validate_phase_2r.gd'='A'
  'tools/evidence/run_phase2r_gate.ps1'='A'
  'schemas/evidence/phase2r-final.schema.json'='A'
  'schemas/evidence/diagnostic-exception.schema.json'='A'
  'schemas/evidence/phase2r-validator-run.schema.json'='A'
  'tests/unit/tooling/test_phase2r_gate.gd'='A'
}
$optionalUids = [ordered]@{
  'tools/evidence/Phase2RGate.gd.uid'='A'
  'tools/evidence/validate_phase_2r.gd.uid'='A'
  'tests/unit/tooling/test_phase2r_gate.gd.uid'='A'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or -not $expectedHead) { throw 'Cannot bind the Task 6 prerequisite HEAD.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 `
  -RequiredStatus $required `
  -OptionalPresentStatus $optionalUids `
  -AllowedDirtyPaths @('.beads/interactions.jsonl','.beads/issues.jsonl') `
  -ExpectedHead $expectedHead `
  -Message 'test(phase2r): add blocking requirement-linked evidence gate'
if ($LASTEXITCODE -ne 0) { throw 'Exact Task 6 commit boundary failed.' }
~~~

## Task 7: Final documentation disposition and Beads closure

**Beads:** dwm-p2r.10 and epic dwm-p2r

**Files:**

- Create: evidence/phase_2r/documentation/final_cleanup_manifest.json
- Modify: Prompt.md
- Modify generated: prompt_docs/INDEX.md
- Modify evidence links: prompt_docs/requirements/authority_context.md
- Modify evidence links: prompt_docs/requirements/documentation_tooling.md
- Modify evidence links: prompt_docs/requirements/runtime_ownership.md
- Modify evidence links: prompt_docs/requirements/run_lifecycle.md
- Modify evidence links: prompt_docs/requirements/dating_endings.md
- Modify evidence links: prompt_docs/requirements/contacts_invitations.md
- Modify evidence links: prompt_docs/requirements/persistence.md
- Modify evidence links: prompt_docs/requirements/dialogic_skip.md
- Modify evidence links: prompt_docs/requirements/desktop_minesweeper_handoff.md
- Modify evidence links: prompt_docs/requirements/audio_preferences.md
- Modify evidence links: prompt_docs/requirements/localization.md
- Modify evidence links: prompt_docs/requirements/verification.md
- Delete only after exact archive and path authority: docs/superpowers/specs/2026-07-17-phase-2r-foundation-repair-design.md
- Delete only after exact archive and path authority: docs/superpowers/plans/2026-07-17-phase-2r-foundation-repair.md
- Delete only after exact archive and path authority: docs/superpowers/plans/2026-07-17-phase-2r-01-documentation-tooling.md
- Delete only after exact archive and path authority: docs/superpowers/plans/2026-07-17-phase-2r-02-profile-localization-audio.md
- Delete only after exact archive and path authority: docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md
- Delete only after exact archive and path authority: docs/superpowers/plans/2026-07-17-phase-2r-04-invitations-schedule-endings.md
- Delete only after exact archive and path authority: docs/superpowers/plans/2026-07-17-phase-2r-05-dialogic-skip.md
- Delete only after exact archive and path authority: docs/superpowers/plans/2026-07-17-phase-2r-06-phase3-contracts-integration.md
- Generate after cleanup: evidence/phase_2r/commands.json
- Generate after cleanup: evidence/phase_2r/validator-run.json
- Generate after cleanup: evidence/phase_2r/final.json
- Generate after cleanup: evidence/phase_2r/logs/final-import.log
- Generate after cleanup: evidence/phase_2r/logs/final-gut.log
- Generate after cleanup: evidence/phase_2r/logs/final-scenes.log
- Generate after cleanup: evidence/phase_2r/logs/final-dialogic.log
- Generate after cleanup: evidence/phase_2r/logs/final-docs.log
- Generate after cleanup: evidence/phase_2r/logs/final-manifests.log
- Generate after cleanup: evidence/phase_2r/logs/final-validator-build.log
- Generate after cleanup: evidence/phase_2r/logs/final-validator-closure.log
- Modify in cleanup subject S and again only in separately authorized post-seal closure B: .beads/issues.jsonl
- Modify in cleanup subject S and again only in separately authorized post-seal closure B: .beads/interactions.jsonl

**Interfaces:**

- Consumes: immutable legacy inventory/dispositions, exact Git blob/archive evidence, the preflighted Task-6 runner, and all child metadata/evidence.
- Produces: an exact post-cleanup subject whose two tracked Beads journals prove `.1`–`.9=closed`, `.10=in_progress`, epic=open; post-cleanup final evidence; a direct-child eleven-path evidence seal; a separately authorized direct-child Beads-closure commit changing only those same two journals; closed `.10`/epic; and the Phase-3 unblock decision.

- [ ] **Step 7.1: Prove every superseded artifact is safely archived before deletion**

- [ ] Run the legacy disposition validator and reference audit. `final_cleanup_manifest.json` records each of the eight literal deletion paths above with its current SHA-256, reachable archive commit/blob, disposition evidence path, and `authorized=false|true`. The validator rejects an extra/missing path, a hash mismatch, an unreachable blob, or `authorized=false`.
- [ ] Delete a superseded specification/plan only when both are true:

~~~text
all of its normative content has a validated migrated/retired/rejected disposition
the exact reviewed file bytes or reconstruction evidence hash to a Git blob reachable from repository history
~~~

If commit authority was not granted and exact reviewed content is not in history, do not delete it and do not claim the Git-history archive rule is satisfied. Record the external authority blocker and ask the user for the narrow commit/archive permission needed. Retaining an unarchived file outside active context is a temporary safety state, not Phase 2R completion.

- [ ] After safe archival, leave every manifest record `authorized=false` and keep all eight files intact. Step 7.1 is proof-only: it may report that the exact bytes are ready for retirement, but it MUST NOT delete a file, regenerate post-deletion INDEX bytes, or claim cleanup completion. Evidence reports remain outside normal context.

- [ ] **Step 7.2: Commit the exact cleanup before final validation**

This boundary requires separate archive/deletion authority and commit authority because it commits deletions. It deliberately precedes the final gate so worktree identity, documentation drift, links, and preclosure Beads bytes describe the tree declared complete. Before staging, use the checked-in duplicate-aware reader/validator—not `ConvertFrom-Json`—to prove both tracked journal files encode exactly `.1` through `.9=closed`, `.10=in_progress`, and epic `dwm-p2r=open`; require `.10` to have one claim/in-progress transition and no close transition. The cleanup commit `S` MUST include those exact two journal deltas together with the cleanup paths.

Before any Step-7.2 deletion, manifest authorization flip, INDEX regeneration, Beads mutation, or staging, require both `DWM_ARCHIVE_DELETION_AUTHORIZED=1` and `DWM_COMMIT_AUTHORIZED=1`, bind the expected parent, prove the exact archive/manifest/reference prerequisites, and compare `git status --porcelain=v1` with the master plan's preserved user-owned dirty-path inventory. If either authority is absent or any unrelated/pre-existing user-owned path remains dirty, stop while all eight files and every `authorized=false` record are still intact. Ask the user either to resolve the unrelated path independently or grant separate exact-path resolution authority. The worker MUST NOT stash, reset, restore, discard, stage, commit, or silently absorb those bytes, and cleanup/deletion authority does not imply authority over them. If the user places an exact path in scope, revise and reapprove the literal `S` status map/evidence contract before touching it; never improvise an extra `S` path. `S -> E -> B` may begin only from a worktree whose remaining changes are exactly the declared `S` map, because `-RequireRemainingDirtyExact` intentionally rejects every preserved unrelated path.

Only after that entire preflight passes in one uninterrupted operation: change all eight manifest records to `authorized=true`; delete exactly the eight literal files above with one reviewed `apply_patch`; regenerate INDEX; prove active Prompt/context references only bounded packets; then immediately execute the exact `S` block below. No glob/directory deletion or intervening task is permitted. A failed preflight performs none of these mutations.

~~~powershell
if ($env:DWM_ARCHIVE_DELETION_AUTHORIZED -ne '1') { throw 'Explicit archive/deletion authority is required.' }
& .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-preclosure.json'
if ($LASTEXITCODE -ne 0) { throw 'Failed to export strict preclosure Beads snapshot.' }
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase2r_subject_beads' -LogName 'phase2r-subject-beads.log' -GodotArgs @('-s','res://tools/evidence/validate_phase_2r.gd','--','--mode=verify-subject-beads','--snapshot=res://.godot/beads/phase2r-preclosure.json')
if ($LASTEXITCODE -ne 0) { throw 'Preclosure Beads state is not exact.' }
$required = [ordered]@{
  'evidence/phase_2r/documentation/final_cleanup_manifest.json'='A'
  'Prompt.md'='M'
  'prompt_docs/INDEX.md'='M'
  'prompt_docs/requirements/authority_context.md'='M'
  'prompt_docs/requirements/documentation_tooling.md'='M'
  'prompt_docs/requirements/runtime_ownership.md'='M'
  'prompt_docs/requirements/run_lifecycle.md'='M'
  'prompt_docs/requirements/dating_endings.md'='M'
  'prompt_docs/requirements/contacts_invitations.md'='M'
  'prompt_docs/requirements/persistence.md'='M'
  'prompt_docs/requirements/dialogic_skip.md'='M'
  'prompt_docs/requirements/desktop_minesweeper_handoff.md'='M'
  'prompt_docs/requirements/audio_preferences.md'='M'
  'prompt_docs/requirements/localization.md'='M'
  'prompt_docs/requirements/verification.md'='M'
  'docs/superpowers/specs/2026-07-17-phase-2r-foundation-repair-design.md'='D'
  'docs/superpowers/plans/2026-07-17-phase-2r-foundation-repair.md'='D'
  'docs/superpowers/plans/2026-07-17-phase-2r-01-documentation-tooling.md'='D'
  'docs/superpowers/plans/2026-07-17-phase-2r-02-profile-localization-audio.md'='D'
  'docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md'='D'
  'docs/superpowers/plans/2026-07-17-phase-2r-04-invitations-schedule-endings.md'='D'
  'docs/superpowers/plans/2026-07-17-phase-2r-05-dialogic-skip.md'='D'
  'docs/superpowers/plans/2026-07-17-phase-2r-06-phase3-contracts-integration.md'='D'
  '.beads/interactions.jsonl'='M'
  '.beads/issues.jsonl'='M'
}
$expectedHead = [string]::Join('', @(git rev-parse --verify 'HEAD^{commit}')).Trim()
if ($LASTEXITCODE -ne 0 -or -not $expectedHead) { throw 'Cannot bind the cleanup-subject prerequisite HEAD.' }
& .\tools\git\Invoke-ExactPathCommit.ps1 `
  -RequiredStatus $required `
  -OptionalPresentStatus ([ordered]@{}) `
  -RequiredAuthorityVariables @('DWM_ARCHIVE_DELETION_AUTHORIZED') `
  -ExpectedHead $expectedHead `
  -RequireRemainingDirtyExact `
  -Message 'docs: retire archived Phase 2R planning artifacts'
if ($LASTEXITCODE -ne 0) { throw 'Exact cleanup-subject commit failed.' }
~~~

If archive/deletion/commit authority is absent, or any preserved unrelated dirty path has not been separately resolved/authorized and incorporated through an approved plan revision, stop before the Step-7.2 mutation sequence with all eight files intact and every manifest record still `authorized=false`; keep `.10` in_progress and the epic open, and report that exact external-authority blocker. Do not stash/reset the user's work and do not run or claim the final gate against the pre-cleanup tree.

- [ ] **Step 7.3: Run the full gate on the post-cleanup commit**

~~~powershell
& .\tools\evidence\run_phase2r_gate.ps1 -Mode Full
~~~

Expected GREEN: the ten finite subject commands, build validator, and closure validator pass; all eight completed logs exist; `final.json.worktree.subject_commit` equals the cleanup commit; the committed/live Beads state is `.1`–`.9 closed, `.10` in_progress, epic open; all eight deletion paths are absent; generated docs/index bytes match; every exact outcome in Task 6 is zero. This is the first command permitted to create final.json.

- [ ] **Step 7.4: Seal the exact final evidence in a direct-child commit**

This is a second, separately authorized evidence-seal/commit gate. Let `$cleanupCommit` be the exact commit tested in `final.json.worktree.subject_commit`. Before staging, require `HEAD` to equal that commit and require the only worktree changes to be the eleven exact Full-mode evidence paths below. Strict-validate all three JSON artifacts, both completed validator logs, and every recorded hash first.

~~~powershell
$cleanupCommit = [string]::Join('', @(git rev-parse --verify HEAD^{commit})).Trim()
if ($env:DWM_EVIDENCE_SEAL_AUTHORIZED -ne '1') { throw 'Explicit evidence-seal authority is required.' }
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase2r-preseal-validate' -LogName 'phase2r-preseal-validate.log' -GodotArgs @('-s','res://tools/evidence/validate_phase_2r.gd','--','--mode=verify-seal-input',('--expected-subject-commit=' + $cleanupCommit))
if ($LASTEXITCODE -ne 0) { throw 'Full evidence does not strictly validate against current cleanup commit.' }
$required = [ordered]@{
  'evidence/phase_2r/commands.json'='A'
  'evidence/phase_2r/validator-run.json'='A'
  'evidence/phase_2r/final.json'='A'
  'evidence/phase_2r/logs/final-import.log'='A'
  'evidence/phase_2r/logs/final-gut.log'='A'
  'evidence/phase_2r/logs/final-scenes.log'='A'
  'evidence/phase_2r/logs/final-dialogic.log'='A'
  'evidence/phase_2r/logs/final-docs.log'='A'
  'evidence/phase_2r/logs/final-manifests.log'='A'
  'evidence/phase_2r/logs/final-validator-build.log'='A'
  'evidence/phase_2r/logs/final-validator-closure.log'='A'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
  -RequiredStatus $required `
  -OptionalPresentStatus ([ordered]@{}) `
  -RequiredAuthorityVariables @('DWM_EVIDENCE_SEAL_AUTHORIZED') `
  -ExpectedHead $cleanupCommit `
  -RequireRemainingDirtyExact `
  -Message 'test(phase2r): seal final evidence'
if ($LASTEXITCODE -ne 0) { throw 'Exact evidence-seal commit failed.' }
$evidenceCommit = [string]::Join('', @(git rev-parse --verify HEAD^{commit})).Trim()
$evidenceParent = [string]::Join('', @(git rev-parse --verify ($evidenceCommit + '^1^{commit}'))).Trim()
if ($evidenceParent -cne $cleanupCommit) { throw 'Evidence commit is not the direct child of the tested cleanup commit.' }
~~~

Do not substitute `ConvertFrom-Json` for the checked-in duplicate-aware validation command. Do not amend the cleanup commit, add a timestamp after Full, or regenerate evidence after sealing.

Immediately run `VerifyExisting`. This invocation must select the pre-closure ancestry shape: current `HEAD` is `E`, its sole parent is `final.json.worktree.subject_commit`, `git diff --name-status S..E` is exactly eleven `A` paths, every current evidence byte equals its `E` blob, the subject tree/requirements/command/completed-log hashes still validate, both Beads journals are byte-identical to `S`, `.1` through `.9` are closed while `.10` is in_progress and epic `dwm-p2r` is open, and the working tree/index are empty. It writes nothing and prints the subject/evidence commit IDs plus `state=pre-closure` on success.

~~~powershell
& .\tools\evidence\run_phase2r_gate.ps1 -Mode VerifyExisting
git status --porcelain=v1
~~~

Expected GREEN: `PHASE2R_VERIFY_EXISTING: PASS state=pre-closure`, followed by no status output. If evidence-commit authority is absent, leave `.10` in_progress and the epic open; uncommitted final evidence is not a closure artifact.

- [ ] **Step 7.5: Close evidence-complete work in an exact Beads-only commit**

- [ ] Append final.json, all command logs, the exact `$cleanupCommit`, and the exact direct-child `$evidenceCommit` to dwm-p2r.10; every path includes its current HEAD-blob SHA-256.
- [ ] Close dwm-p2r.10 only when every acceptance criterion is linked and GREEN.
- [ ] Verify all ten children are closed, then close epic.

This is the third, separately authorized commit gate and also a separate Beads-mutation gate. Do not append evidence, close either issue, stage, or commit unless the user has granted both authorities after the pre-closure `VerifyExisting` pass. Let `$evidenceCommit` be the current pre-closure `HEAD`. The evidence-link append, `.10` close, epic close, and Beads inspection commands may modify exactly the two tracked journal paths `.beads/interactions.jsonl` and `.beads/issues.jsonl`; no evidence, documentation, database/config, or other path may change.

~~~powershell
if ($env:DWM_BEADS_MUTATION_AUTHORIZED -ne '1') { throw 'Explicit Beads-mutation authority is required.' }
if ($env:DWM_COMMIT_AUTHORIZED -ne '1') { throw 'Explicit commit authority is required before any closure mutation.' }
$evidenceCommit = [string]::Join('', @(git rev-parse --verify HEAD^{commit})).Trim()
& .\tools\evidence\run_phase2r_gate.ps1 -Mode VerifyExisting
if ($LASTEXITCODE -ne 0) { throw 'Pre-closure evidence-seal verification failed.' }
if (@(git status --porcelain=v1).Count -ne 0) { throw 'Beads closure must start from the clean evidence seal.' }

$cleanupCommit = [string]::Join('', @(git rev-parse --verify ($evidenceCommit + '^1^{commit}'))).Trim()
$evidencePaths = @(
  'evidence/phase_2r/commands.json',
  'evidence/phase_2r/validator-run.json',
  'evidence/phase_2r/final.json',
  'evidence/phase_2r/logs/final-import.log',
  'evidence/phase_2r/logs/final-gut.log',
  'evidence/phase_2r/logs/final-scenes.log',
  'evidence/phase_2r/logs/final-dialogic.log',
  'evidence/phase_2r/logs/final-docs.log',
  'evidence/phase_2r/logs/final-manifests.log',
  'evidence/phase_2r/logs/final-validator-build.log',
  'evidence/phase_2r/logs/final-validator-closure.log'
)
$evidenceLinks = @()
foreach ($path in $evidencePaths) {
  $blobOid = [string]::Join('', @(git rev-parse --verify ($evidenceCommit + ':' + $path))).Trim()
  if (-not $blobOid) { throw ('Missing evidence blob at seal: ' + $path) }
  $sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
  $evidenceLinks += [ordered]@{path=$path;sha256=$sha256;git_blob_oid=$blobOid}
}
$closureEvidenceNote = ([ordered]@{
  schema_version=1
  kind='phase2r_closure_evidence'
  subject_commit=$cleanupCommit
  evidence_commit=$evidenceCommit
  artifacts=$evidenceLinks
} | ConvertTo-Json -Compress -Depth 8)
bd update dwm-p2r.10 --append-notes $closureEvidenceNote
if ($LASTEXITCODE -ne 0) { throw 'Failed to append exact closure evidence to dwm-p2r.10.' }
bd show dwm-p2r --json
if ($LASTEXITCODE -ne 0) { throw 'Failed to inspect Phase 2R epic.' }
bd dep cycles
if ($LASTEXITCODE -ne 0) { throw 'Beads dependency-cycle check failed.' }
bd close dwm-p2r.10 --reason 'All Phase 2R acceptance criteria have requirement-linked evidence sealed in the direct-child evidence commit.'
if ($LASTEXITCODE -ne 0) { throw 'Failed to close dwm-p2r.10.' }
bd show dwm-p2r --json
if ($LASTEXITCODE -ne 0) { throw 'Failed to verify all ten Phase 2R children.' }
bd close dwm-p2r --reason 'All ten Phase 2R children closed with passing requirement-linked evidence; final gate evidence/phase_2r/final.json passed.'
if ($LASTEXITCODE -ne 0) { throw 'Failed to close Phase 2R epic.' }
bd ready --json
if ($LASTEXITCODE -ne 0) { throw 'Failed to inspect ready work after Phase 2R closure.' }
$allIssuesJson = [string]::Join("`n", @(bd list --status all --json --readonly))
if ($LASTEXITCODE -ne 0) { throw 'Failed to read final Beads status.' }
& .\tools\beads\Export-BeadsSnapshot.ps1 -OutputPath '.godot/beads/phase2r-postclosure.json'
if ($LASTEXITCODE -ne 0) { throw 'Failed to export postclosure Beads snapshot.' }
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'phase2r_closure_beads' -LogName 'phase2r-closure-beads.log' -GodotArgs @('-s','res://tools/evidence/validate_phase_2r.gd','--','--mode=verify-closure-beads','--snapshot=res://.godot/beads/phase2r-postclosure.json')
if ($LASTEXITCODE -ne 0) { throw 'Postclosure Beads state is not exact.' }
~~~

Strict-parse `$allIssuesJson` with the checked-in duplicate-aware JSON reader before staging; `ConvertFrom-Json` is forbidden. Require the exact Phase-2R issue set `dwm-p2r.1` through `dwm-p2r.10` plus `dwm-p2r` to exist once each and have closed status; require no additional open issue in that epic; permit `dwm-eob` only as the separately scoped nonblocking deferred issue. Then require and commit the exact journal delta:

~~~powershell
$required = [ordered]@{
  '.beads/interactions.jsonl'='M'
  '.beads/issues.jsonl'='M'
}
& .\tools\git\Invoke-ExactPathCommit.ps1 `
  -RequiredStatus $required `
  -OptionalPresentStatus ([ordered]@{}) `
  -RequiredAuthorityVariables @('DWM_BEADS_MUTATION_AUTHORIZED') `
  -ExpectedHead $evidenceCommit `
  -RequireRemainingDirtyExact `
  -Message 'chore(beads): close Phase 2R evidence work'
if ($LASTEXITCODE -ne 0) { throw 'Exact Beads-closure commit failed.' }
$beadsClosureCommit = [string]::Join('', @(git rev-parse --verify HEAD^{commit})).Trim()
$beadsParent = [string]::Join('', @(git rev-parse --verify ($beadsClosureCommit + '^1^{commit}'))).Trim()
if ($beadsParent -cne $evidenceCommit) { throw 'Beads closure commit is not the direct child of the evidence seal.' }
$paths = @('.beads/interactions.jsonl','.beads/issues.jsonl')
$closureDiff = @(git diff --name-status $evidenceCommit $beadsClosureCommit | Sort-Object)
$expectedClosureDiff = @($paths | ForEach-Object { "M`t$_" } | Sort-Object)
if ([string]::Join("`n", $closureDiff) -cne [string]::Join("`n", $expectedClosureDiff)) { throw 'Committed Beads closure diff/status is not exact.' }
~~~

No issue or artifact may store `$beadsClosureCommit` before it exists; the commit proves closure through its two journal blobs and ancestry, avoiding self-reference. If either Beads-mutation or third-commit authority is absent, stop with `.10` in_progress and the epic open and the evidence-seal tree clean.

Then run the read-only post-closure pass without rewriting final evidence:

~~~powershell
& .\tools\evidence\run_phase2r_gate.ps1 -Mode VerifyExisting
git status --porcelain=v1
~~~

Expected GREEN: `PHASE2R_VERIFY_EXISTING: PASS state=post-closure`, followed by no status output. It proves `HEAD == B`, `B` is the sole direct child of `E`, `E` is the sole direct child of the tested subject `S`, `diff E..B` is exactly the two Beads journals, every evidence blob at `B` is byte-identical to its blob at `E`, all ten children and epic `dwm-p2r` are closed, `dwm-eob` remains the sole permitted nonblocking deferred issue, and the index/worktree are clean. `final.json` continues to represent the tested pre-closure subject state with `dwm-p2r.10=in_progress` and epic `dwm-p2r=open`; this verification derives closure from committed ancestry and Beads bytes without changing that artifact.

- [ ] Phase 3 is unblocked only after the epic is closed. An open archive-authority blocker, failed exception expiry, uncovered requirement, or diagnostic keeps Phase 3 blocked.

- [ ] **Step 7.6: Final handoff**

- [ ] Report exact passing counts/versions, remaining deferred narrative-localization decision, whether any third-party exception exists, and the Phase 3 interface versions.
- [ ] State explicitly that Phase 3 still owns visible desktop composition and deterministic simulator wiring, while Phase 6 owns the real board adapter.
