# Phase 2R Foundation Repair Plan-Set Index

> **For agentic workers:** This document is a non-executed orchestration and frozen-interface index. Execute the six linked child plans, using `superpowers:subagent-driven-development` (recommended) or `superpowers:executing-plans`, only after the approval gate below opens. Child-plan steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Replace the contradictory pre-Phase-3 foundation with a documented, test-first Day 1–7 runtime whose persistence, invitations, endings, Dialogic, profile, localization, audio, and Phase 3 seams have executable evidence.

**Architecture:** `GameState` remains the stable gameplay facade and delegates to pure `RefCounted` domain modules. `ProfileManager` owns global permanent state, `SaveManager` owns slot I/O and restore coordination, Dialogic owns the narrative playhead through `DialogicBridge`, `AudioManager` owns live audio, and scenes own presentation only. Requirement packets, Beads, exact manifests, and generated evidence divide intended behavior, work status, registered IDs, and verification without pretending any one artifact is universal truth.

**Tech Stack:** Godot 4.6.3 stable Mono (GDScript only), GUT 9.6.1, Dialogic 2.0-Alpha-19, JSON/JSON Schema, Markdown with a strict YAML-frontmatter subset, Beads 1.1.0, PowerShell, and `rg`.

**Document role:** `plan_set_index`; `executed_directly: false`. This file supplies ordering, authority, cross-plan signatures, and traceability; each linked child owns its Files → RED → implementation → GREEN → guarded-commit cycle.

## Global Constraints

- Current gameplay day is an integer from 1 through 7; Day 8 is migration/negative-test input only.
- Runtime remains GDScript-only on Godot 4.6.3 stable Mono with GUT 9.6.1 and Dialogic 2.0-Alpha-19.
- Canonical player saves and custom localization catalogs remain strict primitive-only JSON.
- Dialogic is the sole narrative playhead; TranslationServer and object-loading save formats remain forbidden.
- Existing user-owned dirty changes are preserved and never staged, deleted, or committed without exact path-level authority.
- Every Godot process uses a GUID-scoped test root, redirected `APPDATA`/`LOCALAPPDATA`, a project-local log, and a verified descendant `user://`.
- Phase 2R defines/test-drives contracts only for desktop composition and Minesweeper; visible desktop wiring is Phase 3 and the real board is Phase 6.
- No commit, push, remote sync, history rewrite, global CodeGraph uninstall, or narrative prose invention is authorized by this plan.
- Plan 01 Task 1 creates and behavior-tests the one shared `tools/git/Invoke-ExactPathCommit.ps1`; every proposed commit boundary in Plans 01 through 06 invokes that helper. The helper requires `DWM_COMMIT_AUTHORIZED=1`, an empty pre-existing index, one captured expected parent, literal exact A/M/D paths plus present-only declared UID companions, regular-blob modes, no partial staging or rename/copy/type/unmerged records, a successful commit, one sole direct child, and an exact post-commit path/status/mode revalidation. A destructive boundary also names its independent authority variable; no authority variable implies another.

---

## Authorization and stopping rule

The user explicitly approved Phase 2R execution on 2026-07-18 after the seven-plan set passed its final audits. `implementation_authorized: true`; execution mode is Inline unless the user later explicitly requests delegation.

- Plan documents, design metadata, task-scoped Beads bookkeeping, and the dependency-ordered implementation changes named by the approved child plans are authorized.
- Runtime code, `project.godot`, active prompt documents, scenes, tests, localization data, and evidence may change only under the active task's exact Files/Interfaces/RED/GREEN boundary. Repository `.codegraph/` removal and legacy/specification/plan deletion remain separately gated destructive actions.
- Claim only the next ready Beads issue and implement only its referenced plan tasks.
- Do not begin Phase 3 composition or the player-facing Minesweeper simulator in Phase 2R.
- Do not invent narrative prose or claim Chinese narrative coverage.
- Do not commit, push, sync, or rewrite history without separate explicit user authority. Every commit block below is a proposed boundary, not permission to execute it.

The approved source is `docs/superpowers/specs/2026-07-17-phase-2r-foundation-repair-design.md`. If a plan instruction conflicts with that specification, stop, record the drift on the active Beads issue, and resolve the plan before changing runtime behavior.

## Worktree protection

The following pre-existing changes are user-owned and MUST be preserved:

```text
.claude/settings.local.json
.claude/skills/godot-prompter/1.10.0
.claude/skills/superpowers/6.1.1
Prompt.md
prompt_docs/CONTRACTS.md
prompt_docs/DIALOGIC.md
prompt_docs/PHASES.md
prompt_docs/TESTING.md
scripts/data/ArtManifest.gd
scripts/ui/ShopApp.gd
```

Beads export files and the approved specification/plan files are agent-created bookkeeping. Before each issue:

```powershell
git status --short
git diff -- Prompt.md prompt_docs/CONTRACTS.md prompt_docs/DIALOGIC.md prompt_docs/PHASES.md prompt_docs/TESTING.md scripts/data/ArtManifest.gd scripts/ui/ShopApp.gd
bd show dwm-p2r --json
bd ready --json
```

Never use `git add .`. Never stage `.claude/**`, either modified skill directory, `scripts/data/ArtManifest.gd`, or `scripts/ui/ShopApp.gd` unless a later user request explicitly places that exact change in scope.

Plan 06's final `S -> E -> B` evidence chain requires no unrelated worktree or index changes when cleanup subject `S` is created. If any preserved user-owned path above is still dirty at that boundary, stop before `S` and ask the user to resolve or separately authorize that exact path. Never stash, reset, clean, stage, commit, or otherwise absorb it merely to satisfy the clean-tree proof.

## Verified command convention

All Godot commands run from `C:\Users\glori\Documents\dwm`. The explicit `--log-file` keeps Godot logs inside the writable project because an unredirected headless invocation currently crashes while opening `user://logs`. For each requested Godot test/tool process, the worker creates a unique root below `.godot/phase2r_tests`, sets `DWM_TEST_ROOT` to it, and sets both `APPDATA` and `LOCALAPPDATA` to children of that same root. The helper may first launch only the side-effect-free `print_user_dir.gd` proof process under those redirected roots; no requested project test/tool process may start until that probe proves its resolved `user://` is a strict descendant of the GUID root. This protects production persistence even while legacy autoloads still contain hard-coded `user://` paths.

After `dwm-p2r.1` creates `tools/testing/Invoke-IsolatedGodot.ps1`, every later command invokes that helper. It creates a GUID child, redirects all three roots, calls `print_user_dir.gd`, rejects a non-descendant `user://`, runs the requested process, captures argv/exit/diagnostics, and removes only its verified GUID child unless evidence retention was requested. Verified focused GUT list syntax:

```powershell
& .\tools\testing\Invoke-IsolatedGodot.ps1 -SuiteId 'focused' -LogName 'phase2r-focused.log' -GodotArgs @('-s','res://addons/gut/gut_cmdln.gd','-gtest=res://tests/unit/test_localization.gd,res://tests/unit/test_audio_manager.gd','-gexit')
```

This two-file list syntax was executed successfully during planning. Every implementation task supplies its own literal test paths and unique log filename. A behavior task follows RED -> inspect the expected failure -> minimal implementation -> GREEN -> the stated broader suite. An unexpected parse error, crash, production-path access, or unrelated failure is not an acceptable RED result.

Godot-generated `.gd.uid` companions for newly imported scripts belong to the same task and proposed commit boundary as their owning script. A worker records those generated paths after import; it never fabricates UID contents or rewrites unrelated existing UIDs.

## Durable Beads graph

Planning bookkeeping has created this graph. Implementation issues remain open and unclaimed.

| ID | Bounded outcome | Direct blockers |
|---|---|---|
| `dwm-p2r` | Phase 2R epic | none |
| `dwm-p2r.1` | Documentation schema, baseline, and context bootstrap | none |
| `dwm-p2r.2` | Repository CodeGraph removal | `.1` |
| `dwm-p2r.3` | Profile, custom localization, and audio ownership | `.1` |
| `dwm-p2r.4` | GameState decomposition and run lifecycle | `.1` |
| `dwm-p2r.5` | Snapshots, migrations, and isolated storage | `.3`, `.4` |
| `dwm-p2r.6` | Contacts and invitations | `.4`, `.5` |
| `dwm-p2r.7` | Schedule, Hospital, dating, and endings | `.4`, `.5`, `.6` |
| `dwm-p2r.8` | Dialogic, effects, visited history, and skip | `.3`, `.4`, `.5`, `.6`, `.7.1` |

> **Corrected ordering (2026-08-08, dwm-p2r.7.1):** `.8` no longer depends on all of `.7`. The live order is **`.8` → `dwm-7e6` → remaining `.7` tails**, because `.7` now depends on `dwm-7e6`, which depends on `.8`. `.8` depends only on the narrow, committed `.7 → .8` interface frozen in `dwm-p2r.7.1` (`docs/superpowers/specs/2026-08-08-phase-2r-7-to-8-dialogic-handoff-contract.md`): the 11 canonical ending ids (8 primary + 2 postscript + 1 epilogue), physical DTL label dispositions, the four playback stages and four-key context, postscript+audio ownership (`.8`), and ending-ledger (`.7`) vs effect-ledger (`.8`) ownership. `.7` stays open for tails ordered after `.8`/`dwm-7e6`; it is not declared complete.
| `dwm-p2r.9` | Phase 3 desktop and Minesweeper contracts | `.3`, `.4`, `.5`, `.8` |
| `dwm-p2r.10` | Integration and Phase 2R evidence gate | `.1` through `.9` |
| `dwm-eob` | Deferred narrative-localization adapter decision | representative external localized files; blocks translated narrative import only |

At issue start:

```powershell
bd show dwm-p2r.1 --json
bd update dwm-p2r.1 --claim
```

Use the literal ID for the issue being started. Close only after every recorded acceptance criterion has a passing evidence link:

```powershell
bd close dwm-p2r.1 --reason 'All acceptance criteria passed; evidence recorded in evidence/phase_2r.'
```

## Shared interface registry

These signatures and explicitly declared shapes are frozen across all six implementation plans. Changing one requires a plan edit, cross-plan signature audit, and explicit approval before implementation continues. Unless a narrower shape is shown, every command returns exactly one `CommandResult` union:

```gdscript
# success
{"ok": true, "code": &"ok", "value": Variant, "receipt": Dictionary}
# failure
{"ok": false, "code": StringName, "message": String, "details": Dictionary}
```

Success receipts are primitive-only and may be empty. Failure codes are closed allowlists in the owning task; failures never include a partially usable candidate.

### Storage

```gdscript
# scripts/validation/StrictJson.gd
class_name StrictJson
extends RefCounted

static func parse_object(text: String) -> Dictionary

# scripts/validation/CanonicalJsonWriter.gd
class_name CanonicalJsonWriter
extends RefCounted

static func stringify(value: Variant) -> Dictionary

# scripts/infrastructure/storage/StorageAdapter.gd
class_name StorageAdapter
extends RefCounted

func read_text(relative_path: String) -> Dictionary
func write_atomic(relative_path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary
func reconcile(relative_path: String, validator: Callable) -> Dictionary
func exists(relative_path: String) -> bool
func remove(relative_path: String) -> Dictionary
func describe_root() -> String

# scripts/infrastructure/storage/JsonFileStorage.gd
func _init(root_dir: String, file_ops: RefCounted = null) -> void
```

`StrictJson.parse_object()` returns `{ok:true, value:Dictionary}` or `{ok:false, code:StringName, message:String, line:int, column:int}` and rejects duplicate members before materialization, non-object roots, trailing tokens, invalid escapes/surrogates, and non-finite numbers. `CanonicalJsonWriter.stringify()` accepts only primitive JSON trees with String/StringName keys, normalizes keys, rejects collisions/non-finite or unsupported values, sorts object keys by UTF-8 bytes, preserves array order, emits compact locale-independent JSON, and strict-parses its own output before returning `{ok:true, value:String}`. Profile, save, marker, localization, and generated evidence owners use these two boundaries; ad-hoc `JSON.parse*`/`JSON.stringify` is forbidden there.

Every storage result is one of:

```gdscript
{"ok": true, "value": value}
{"ok": false, "code": StringName, "message": String}
```

`JsonFileStorage.write_atomic()` is a crash-recoverable transaction, not a claim that Windows supplies one indivisible rename across every step. The strict `<name>.txn.json` marker discriminates `operation=write|delete`. A write transaction computes the outgoing hash and flushes/re-reads an initial `stage=prepared` marker before creating `.next`, so a first-write crash cannot leave an ambiguous orphan candidate. It then writes, flushes, re-reads, validates, and hashes exact next bytes; preserves the prior final as `<name>.bak`; promotes next; and validates final. After any injected I/O failure, the adapter reconciles from fresh disk state against the outgoing hash: it returns committed success when the outgoing document is the deterministic winner, an uncommitted failure only when the old/absent document wins, and a fatal indeterminate result that blocks the owner when no winner can be proven. It never reports an ordinary failure after durably committing new bytes.

`remove()` is also crash-recoverable. It flushes/re-reads a valid `operation=delete, stage=delete_marked` marker before removing final, `.next`, and `.bak`; the marker is removed last. `reconcile()` completes a valid delete marker before considering backup recovery, so a deleted save cannot be resurrected. A corrupt marker fails closed. Every read/write/remove first reconciles the whole transaction family. An injected `FileOps` fake fails after every write, flush, marker update, rename, re-read, and removal for first-write, replacement, and deletion cases. ProfileManager and SaveManager validate detached documents before serialization and use strict duplicate-rejecting JSON plus the canonical writer. Tests inject a root beneath `.godot/phase2r_tests/`; no test constructs a production `user://` root.

### Profile

```gdscript
# autoload/ProfileManager.gd
signal profile_restored(profile: Dictionary)
signal preference_changed(path: StringName, value: Variant)
signal gallery_changed(ending_id: String, unlocked: bool)
signal visited_history_changed(line_id: String, visited: bool)
signal input_mappings_changed(action_id: StringName)
signal profile_reset(section: StringName)
signal profile_write_failed(result: Dictionary)

func initialize(storage: StorageAdapter = null) -> Dictionary
func prepare_profile_document(raw: Dictionary) -> Dictionary
func prepare_preferences(changes: Dictionary) -> Dictionary
func prepare_locale_preference(locale_id: String) -> Dictionary
func commit_prepared_profile(candidate: Dictionary, defer_signals: bool = false) -> Dictionary
func publish_deferred_profile_signals(publication_id: String) -> Dictionary
func get_profile_snapshot() -> Dictionary
func get_preference(path: StringName, default_value: Variant = null) -> Variant
func set_preference(path: StringName, value: Variant) -> Dictionary
func set_preferences(changes: Dictionary) -> Dictionary
func is_line_visited(line_id: String) -> bool
func mark_line_visited(line_id: String) -> Dictionary
func has_gallery_unlock(ending_id: String) -> bool
func prepare_ending_unlock(ending_id: String, transaction_id: String) -> Dictionary
func unlock_ending(ending_id: String, transaction_id: String) -> Dictionary
func get_input_mappings() -> Dictionary
func set_input_mapping(action_id: StringName, events: Array[Dictionary]) -> Dictionary
func prepare_legacy_profile_patch(legacy_run_state: Dictionary, legacy_input_mappings: Dictionary = {}) -> Dictionary
func reset_preferences() -> Dictionary
func reset_visited_history() -> Dictionary
func reset_gallery() -> Dictionary
func reset_entire_profile() -> Dictionary
func capture_restore_state() -> Dictionary
func apply_restore_silent(plan: Dictionary) -> Dictionary
func rollback_restore_silent(backup: Dictionary) -> Dictionary
func finalize_restore() -> Dictionary
```

Initialization is explicit rather than disk I/O in `_ready()`, allowing tests and on-tree harnesses to inject isolated storage before any read. When `defer_signals` is true, a successful commit returns one opaque `publication_id`; no profile signal fires until that ID is published exactly once. `prepare_ending_unlock()` is the pure gallery transaction builder used with this deferred commit path; `unlock_ending()` is its immediate convenience wrapper. If a later run-checkpoint commit fails after the profile write, the durable gallery truth remains ahead, its deferred notification is published before returning the recoverable failure, and retry reuses the receipt without a second unlock. This lets localization, endings, and resets publish only durable state without an inconsistent observation window. `GameState.reset_game()` never initializes, resets, or replaces the profile.

Every preference API and signal uses a fully qualified leaf path beginning `preferences.`; batches are Dictionaries from those exact paths to primitive values. `preferences.language` accepts any nonempty canonical string at schema level so adding a manifest locale never requires a schema edit. Direct `set_preference(s)` calls containing that path fail with `managed_preference`; only LocalizationManager calls `prepare_locale_preference()` after manifest validation. At bootstrap, a removed/unknown stored locale is normalized to the manifest source locale and persisted through the same atomic switch; persistence failure is a startup failure, not an in-memory-only fallback.

All profile inputs, prepared candidates, receipts, snapshots, and getter results are recursively detached primitive copies. ProfileManager never stores a caller-owned nested container or returns an alias to live state; mutation-after-call and mutation-after-return tests enforce the boundary.

Profile schema stores `gallery_transaction_receipts` as a strict map from stable transaction ID to `{ending_id, unlocked}`. Gallery and entire-profile resets clear user-visible unlocks but retain this internal receipt ledger plus migration receipts, preventing an old ending playback transaction from silently re-unlocking reset content; a later run uses a new run-scoped transaction ID and may unlock normally.

### Localization

```gdscript
# autoload/LocalizationManager.gd
signal locale_changed(locale_id: String)

func initialize(profile: Node, manifest_path: String = "res://localization/manifest.json") -> Dictionary
func get_readiness() -> StringName
func get_locale() -> String
func get_selectable_locales() -> Array[Dictionary]
func set_locale(locale_input: String) -> Dictionary
func has_key(key: String) -> bool
func t(key: String, params: Dictionary = {}) -> String
func get_presentation_profile() -> Dictionary
func register_presentation_root(root: Node) -> Dictionary
func unregister_presentation_root(root: Node) -> Dictionary
func prepare_locale(locale_input: String) -> Dictionary
func capture_restore_state() -> Dictionary
func apply_restore_silent(plan: Dictionary) -> Dictionary
func rollback_restore_silent(backup: Dictionary) -> Dictionary
func finalize_restore() -> Dictionary
```

Readiness is exactly `uninitialized|initializing|ready|failed`. Presentation roots may register before initialization and remain weak, pending entries until the validated startup transaction drains them; ready-time registration applies the current presentation before returning. All locale/profile/root publication is atomic and uses the custom strict JSON catalogs—never TranslationServer.

### Run facade and lifecycle

```gdscript
# scripts/domain/run/RunLifecycle.gd
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

# autoload/GameState.gd retained facade seams
func capture_run_snapshot_input() -> Dictionary
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
func open_contact(friend_id: String, command_id: String) -> Dictionary
func configure_narrative_checkpoint_port(port: Object) -> Dictionary
func reply_invitation(friend_id: String, command_id: String) -> Dictionary
func resolve_invitations_for_day(attendance: Dictionary, command_id: String) -> Dictionary
func request_schedule_done(command_id: String) -> Dictionary
func resume_day_resolution() -> Dictionary
func begin_day_resolution_stage() -> Dictionary
func complete_day_resolution_stage(transaction_id: String, receipt: Dictionary) -> Dictionary
func request_next_ending_command() -> Dictionary
func complete_ending_playback_stage(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary

# scripts/application/run/DayResolutionCoordinator.gd
func configure_fatal_latch(gate: Object) -> Dictionary
func configure(state_port: Object, checkpoint_port: Object) -> Dictionary
func request_schedule_done(command_id: String) -> Dictionary
func resume() -> Dictionary
func complete_route_stage(transaction_id: String, receipt: Dictionary) -> Dictionary

# scripts/application/run/GameStateDayResolutionPort.gd
func begin_or_resume(command_id: String) -> Dictionary
func inspect_next_stage() -> Dictionary
func begin_next_stage() -> Dictionary
func prepare_completion(transaction_id: String, receipt: Dictionary) -> Dictionary
func capture() -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func publish(publication: Dictionary) -> Dictionary

# scripts/application/run/SaveManagerCheckpointPort.gd
func configure_fatal_latch(gate: Object) -> Dictionary
func capture() -> Dictionary
func preview_checkpoint_id(run_id: String) -> Dictionary
func prepare(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary
func commit(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
```

`prepare_completion()` returns `value={run_candidate,snapshot_input,stage,publication,duplicate}` without mutation; `prepare()` returns `value={candidate,checkpoint_id}`. Plan 03 Task 3 creates the sole `ApplicationMutationGate` and the one pure `FatalDiagnosticProjector`; before either service accepts its operational ports, `configure_fatal_latch()` injects that identical gate object into `DayResolutionCoordinator` and `SaveManagerCheckpointPort` through a narrow latch-only seam. `DayResolutionCoordinator` is the production executor for every plan stage. It validates owner-specific receipt schemas, prepares a detached run candidate and checkpoint/journal candidate, commits checkpoint then run state, rolls both back in reverse on any pre-publication failure, and only then calls `publish(publication)` or returns a registered route command. A duplicate uses the stored receipt/current whole-bundle checkpoint and performs no prepare, commit, or publication. Tests do not manually manufacture successful stage receipts. `RunLifecycle.complete_active_stage()` is the only method permitted to change day, and only for the active `increment_day` stage. `day` validates in `1..7`; there is no Day 8 sentinel.

### Checkpoints and saves

```gdscript
# scripts/domain/run/RunSnapshotSchema.gd
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

# scripts/infrastructure/save/CheckpointJournal.gd
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

# scripts/infrastructure/save/SaveDocumentSchema.gd
class_name SaveDocumentSchema
extends RefCounted

static func build(kind: StringName, slot_id: Variant, save_reason: StringName, current_bundle: Dictionary, journal: Array[Dictionary]) -> Dictionary
static func validate(document: Dictionary) -> Dictionary
static func prepare_candidate(document: Dictionary) -> Dictionary

# autoload/SaveManager.gd
signal run_restored(checkpoint_id: String, route_id: String)
signal save_capability_changed(capability: Dictionary)

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

`checkpoint_inputs` has exactly `snapshot_input`, `dialogic_checkpoint`, `route_id`, `active_app_id`, `audio_context`, and `content_version`. SaveManager asks CheckpointJournal for the next sequence scoped to `snapshot_input.lifecycle.run_id`; RunSnapshotSchema derives `checkpoint_id` as `<run_id>:<sequence>`. A failed build, validation, or commit does not consume a sequence. The exact snapshot stores the active resolution plan and EndingPlan only inside `lifecycle`, never as duplicate top-level fields.

`checkpoint_kind` is the closed accepted set `line|day_start|timeline_start|timeline_complete|choice|variable_transaction|effect_transaction|safe_marker|scene_transition|pre_board|post_result|day_resolution_stage`. Every value except `line` is a permanent semantic anchor; `line` is recovery-only history subject to the 32-line retention limit. Unknown kinds reject before journal mutation.

The snapshot stores both `applied_effect_transaction_ids` and `applied_variable_transaction_ids` as separate sorted unique string arrays. Restoring either ledger prevents the corresponding Dialogic signal from replaying; migrations default a missing legacy variable ledger to an empty array rather than copying current-session state.

`participants` contains exactly `run`, `profile`, `localization`, `audio`, `route`, and `narrative`, each a concrete adapter implementing `prepare(input)`, `capture()`, `apply_silent(plan)`, `rollback_silent(backup)`, and `finalize()`. `commit_prepared_restore()` may be awaited. Commit order is run → profile → localization derived from the prepared profile language → audio derived from prepared profile preferences plus semantic run context → route and target-scene ready → narrative. Rollback is the exact reverse order and also restores SaveManager's captured CheckpointJournal. SceneRouter suppresses ordinary route signals during the transaction and can reapply its captured semantic route. Participant finalization emits no domain signal; SaveManager emits the sole aggregate `run_restored` signal after all adapters and its own journal commit. Production-adapter failure tests, not only fake adapters, prove the contract.

The route participant input is `route_id` plus `RunSnapshotSchema.derive_route_restore_context(selected_snapshot)`. That detached context is derived only after full snapshot validation from lifecycle/day/ending, active app, contacts, schedule, and dating fields; it is runtime-only and is never persisted as a second route authority.

The prepared journal contains only migrated bundles with the selected bundle's run_id and sequence less than or equal to the selected sequence; incompatible/later recovery candidates are not seeded into live memory. Its latest checkpoint is the selected whole bundle and its next sequence is selected sequence + 1. Loading run A over live run B, then saving, can therefore write only run-A bundles; rollback restores the exact run-B journal.

`start_new_run()` reuses the same six-participant transaction core. It prepares a Day-1 `PLAYING` run and checkpoint `<new_run_id>:1`, derives route context from that validated snapshot, replaces the prior journal through a detached reset candidate, writes a `day_start` autosave, and rolls live state/journal/storage back together on failure. It never calls a profile reset seam. Starting Run B immediately after Run A is a required integration case.

`save_exists()` accepts only `&"slot"`, `&"quick"`, or `&"autosave"`; `slot` additionally requires a configured `slot_id` in `1..7`, while quick/autosave require the default `-1`. Invalid arguments return `false` without reading storage. Metadata and mutation APIs reject the same invalid combinations with a typed `INVALID_SAVE_REFERENCE` result.

Save capability is owner-specific:

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

Manual/quick input under the Minesweeper lock is ignored; it emits no notification and queues no deferred request. A scene-transition request records one deferred save and fulfills it at the next stable commit.

Save documents form a closed union: `kind=slot` requires `slot_id` in `1..7`, `save_reason=manual`, and writes `slot_<id>.json`; `kind=quick` requires `slot_id=null`, `save_reason=quick`, and writes `quicksave.json`; `kind=autosave` requires `slot_id=null`, `save_reason=automatic|day_start|ending|pre_board|logout`, and writes `autosave.json`. Logout never invents a fourth filename/kind. Backup metadata/delete/prepare-restore APIs accept only this union and never return a caller-controlled path.

### Application mutation gate

```gdscript
# scripts/application/transaction/ApplicationMutationGate.gd
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

# scripts/application/transaction/FatalDiagnosticProjector.gd
static func project_failure(source: Variant, phase: Variant, code: Variant, context: Dictionary, raw_diagnostics: Array) -> Dictionary
static func validate_failure(failure: Dictionary) -> Dictionary
static func get_invariant_fallback() -> Dictionary
```

Only `restore` and `new_run` may own the gate. ApplicationBootstrap injects one instance into SaveManager, GameState, ProfileManager, LocalizationManager, AudioManager, SceneRouter, DialogicBridge, and InputManager. Public mutations and user input return `TRANSACTION_ACTIVE` or are consumed while an awaited transaction/rollback is active; participant silent methods require the current internal owner.

Plan 03 Task 3's `FatalDiagnosticProjector` is a pure boundary helper, not another gate or owner. Plans 03, 04, and 06 consume that one checked-in implementation. It normalizes StringName keys/values to String, recursively detaches primitive diagnostics, replaces invalid subtrees with deterministic primitive sentinels, validates the complete `FatalFailure`, and supplies one constant valid fallback if its own output violates the invariant. Recovery callers finish every required recovery attempt, call the shared gate's `latch_fatal()` once, then return the exact retained `APPLICATION_FATAL` from that same gate's `guard_external()`; an intermediate latch success/conflict is never the public recovery result.

`latch_fatal()` accepts exactly a detached primitive `{source,phase,code,details}` failure. Invalid input changes nothing; the first valid failure is retained irreversibly and emits one disabled `APPLICATION_FATAL` capability; the same normalized failure is idempotent; a different failure returns `APPLICATION_FATAL_CONFLICT` while preserving the first. Fatal is separate from acquire ownership: it creates no owner/token and `is_active()` continues to describe only restore/new_run ownership. After a latch, acquire/release/guard calls return `APPLICATION_FATAL`, internal-owner checks are false, every guarded public mutation rejects before domain validation, and InputManager remains blocked for the process. Every rollback/release recovery failure delegates to this one injected gate; no subsystem-local fatal flag or second gate is allowed.

Every guarded owner exposes the identical `configure_mutation_gate(gate: Object) -> Dictionary` seam, rejects a missing/incompatible gate or replacement by another instance, and uses no owner-specific bypass.

ApplicationBootstrap's existing `construct_and_inject_mutation_gate` stage owns factory invocation and precedes ProfileManager initialization. Plan 02 debug modes may install a wrapper-root-proven fake factory and inject only their frozen four/six-manager development target sets. Final mode never accepts that factory: Plan 03 installs the production ApplicationMutationGate factory in the same stage and injects the exact ordered final targets SaveManager, GameState, ProfileManager, LocalizationManager, AudioManager, SceneRouter, DialogicBridge, and InputManager. Every successful target result has exact `value={gate_instance_id,already_configured}` with an empty receipt, and all IDs equal the one gate instance; a missing factory/method, identity mismatch, or failure stops before any initializer.

### Contacts, schedules, and endings

```gdscript
# scripts/domain/contact/ContactInvitationState.gd
static func make_defaults() -> Dictionary
static func validate_state(state: Dictionary) -> Dictionary
static func prepare_append_messages(state: Dictionary, message_batch: Array[Dictionary], transaction_id: String) -> Dictionary
static func prepare_offer_solo(state: Dictionary, friend_id: String, day: int, offer_message_id: String, transaction_id: String) -> Dictionary
static func prepare_open_contact(state: Dictionary, friend_id: String, day: int, transaction_id: String) -> Dictionary
static func prepare_activate_group_after_round(state: Dictionary, day: int, rounds_before: int, rounds_after: int, transaction_id: String) -> Dictionary
static func prepare_reply(state: Dictionary, friend_id: String, day: int, transaction_id: String) -> Dictionary
static func prepare_resolve_day_end(state: Dictionary, day: int, attendance: Dictionary, transaction_id: String) -> Dictionary
static func prepare_close_for_run_end(state: Dictionary, day: int, transaction_id: String) -> Dictionary
static func is_date_addable(state: Dictionary, action_id: String) -> bool
static func is_reply_required(state: Dictionary, friend_id: String) -> bool
static func get_unread_count(state: Dictionary, friend_id: String, day: int) -> int
static func get_contact_view(state: Dictionary, friend_id: String, day: int) -> Dictionary

# scripts/domain/schedule/ScheduleRules.gd
static func validate_candidate(existing: Array[Dictionary], candidate: Dictionary, day: int, motivation: int, eligibility: Dictionary) -> Dictionary
static func validate_existing(schedule: Array[Dictionary], day: int) -> Dictionary
static func build_route_plan(schedule: Array[Dictionary], day: int) -> Dictionary

# scripts/domain/ending/DatingEndingRules.gd
static func resolve_primary_ending(input: Dictionary) -> Dictionary
static func resolve_epilogue(missed_group_counts: Dictionary) -> Dictionary
static func build_ending_plan(input: Dictionary) -> Dictionary
static func validate_ending_plan(plan: Dictionary) -> Dictionary
static func resolve_hospital_outcome(input: Dictionary) -> Dictionary
static func next_playback_command(plan: Dictionary) -> Dictionary
```

Every contact `prepare_*` call is pure and returns the frozen outer `CommandResult`: success `value` has exactly `candidate` and ordered `message_batch`, while the parent transaction receipt is the outer `receipt`; failure exposes no candidate. No contact object owns a second live copy. GameState validates and commits the complete detached run candidate, contact batch, counters, receipt ledger, and prepared checkpoint as one transaction. Message batches use deterministic child IDs beneath one parent transaction ID, so paired group/day-end messages cannot be mistaken for duplicate parent calls. `attendance` has exactly `solo_attended_action_ids`, `scheduled_group_action_id`, `group_route_receipt_id`, and `group_outcome`. `group_outcome` is `not_scheduled|attended|not_attended|prevented_by_fainting`: `not_scheduled` requires both group IDs null; every other value requires the current group action ID and a matching completed/cancelled/prevented route receipt. It is the sole fainting source for group day-end resolution; contradictory combinations reject.

`group_action` has exactly `state`, `action_id`, `day`, `participant_ids`, `inviter_id`, `opened_ids`, `replied_ids`, `history_generated`, and `transaction_id`. Its state is exactly `INACTIVE`, `AVAILABLE_UNOPENED`, `REPLY_REQUIRED`, `ACCEPTED`, `RESOLVED_UNANSWERED`, `RESOLVED_ATTENDED`, `RESOLVED_MISSED`, or `RESOLVED_RUN_END`. Inactive requires null action/day; activation stamps deterministic action ID and day immediately while inviter stays null until the first participating contact opens. Superseded solo messages remain stored with `visibility=superseded_hidden` and do not count toward visible history or unread badges. An AVAILABLE_UNOPENED participant has one derived unread group opportunity until their paired group-offer history is generated/read.

Schedule entries have exactly `entry_id`, `slot_index`, `day`, `type`, `action_id`, `friend_ids`, `route_id`, `effect_ids`, and `unlock_receipt_id`. Days 1–6 require null unlock receipt. Day 7 requires `eligibility={registered_action_ids,day7_candidate,receipt_index}` and proves one synchronized `day7_unlock -> schedule_add -> date_completed` chain whose action, friend, day, and previous-receipt IDs all agree; loose receipt-ID strings are forbidden.

Facade schedule commands return this shape; the ambiguous `executed` boolean is not retained:

```gdscript
{
    "ok": bool,
    "code": StringName,
    "reason": String,
    "committed_effects": Array[Dictionary],
    "date_outcome_ids": Array[String],
    "route_plan": Array[Dictionary],
    "checkpoint_id": String,
}
```

### Narrative

```gdscript
# scripts/data/DialogicTimelineCatalog.gd
static func initialize(manifest_path: String = "res://data/manifests/timelines.json") -> Dictionary
static func has_timeline_id(timeline_id: String) -> bool
static func get_record(timeline_id: String) -> Dictionary
static func get_path_for_id(timeline_id: String) -> Dictionary
static func get_line_record(timeline_id: String, line_id: String) -> Dictionary
static func get_event_record(timeline_id: String, event_id: String) -> Dictionary
static func validate_successor(timeline_id: String, event_id: String, post_event_id: Variant, choice_id: Variant = null) -> Dictionary
static func validate_all() -> Dictionary

# scripts/narrative/NarrativeCheckpointSchema.gd
class_name NarrativeCheckpointSchema
extends RefCounted

static func build(timeline_record: Dictionary, boundary: Dictionary, event: Dictionary, post_event: Dictionary, last_committed_line_id: Variant, timeline_completed: bool) -> Dictionary
static func validate(checkpoint: Dictionary, timeline_record: Dictionary) -> Dictionary

# scripts/narrative/DialogicRuntimeAdapter.gd
func bind_runtime(dialogic: Node) -> Dictionary
func start_timeline(path: String, event_index: int = 0) -> Dictionary
func capture_checkpoint() -> Dictionary
func prepare_runtime_restore(checkpoint: Dictionary, manifest: Dictionary) -> Dictionary
func apply_restore(plan: Dictionary) -> Dictionary
func reveal_current_line() -> Dictionary
func classify_next_event() -> StringName
func advance_one_event() -> Dictionary
func capture_restore_state() -> Dictionary
func restore_captured_state(backup: Dictionary) -> Dictionary
func halt_with_error(result: Dictionary) -> Dictionary

# autoload/DialogicBridge.gd
signal narrative_checkpoint_committed(checkpoint: Dictionary)
signal narrative_validation_failed(result: Dictionary)
signal ending_playback_finished(playback_token: String, ending_id: String, receipt: Dictionary)
signal ending_playback_failed(playback_token: String, ending_id: String, result: Dictionary)

func start_timeline_id(timeline_id: String, context: Dictionary = {}) -> Dictionary
func start_ending_id(ending_id: String, context: Dictionary = {}) -> Dictionary
func capture_semantic_checkpoint() -> Dictionary
func prepare_restore(checkpoint: Dictionary) -> Dictionary
func apply_restore(plan: Dictionary) -> Dictionary
func request_skip_step() -> Dictionary
func get_current_line_id() -> String
func get_current_boundary_kind() -> StringName
func initialize(catalog: Script = DialogicTimelineCatalog, runtime_adapter: RefCounted = null) -> Dictionary
func bind_profile_preferences(profile: Node, preference_adapter: RefCounted = null) -> Dictionary
func apply_profile_preferences(changed_path: StringName = &"") -> Dictionary
func reapply_cached_preferences_after_clear() -> Dictionary
func capture_restore_state() -> Dictionary
func restore_captured_state(backup: Dictionary) -> Dictionary
func configure_narrative_checkpoint_port(port: Object) -> Dictionary
func provide_transaction_narrative_checkpoint(transaction_id: String, source_id: String, checkpoint_kind: StringName) -> Dictionary

# scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd
func configure(checkpoint_port: Object, providers: Dictionary) -> Dictionary
func commit_current_boundary(request: Dictionary) -> Dictionary
func preview_checkpoint_id(run_id: String) -> Dictionary
func capture() -> Dictionary
func prepare_candidate(owner_id: StringName, snapshot_input: Dictionary, transaction_id: String, source_id: String, checkpoint_kind: StringName, expected_checkpoint_id: String) -> Dictionary
func commit(owner_id: StringName, candidate: Dictionary) -> Dictionary
func rollback(owner_id: StringName, backup: Dictionary) -> Dictionary

# scripts/application/ending/DialogicEndingPlaybackPort.gd
signal playback_completed(completion: Dictionary)
signal playback_failed(failure: Dictionary)

func initialize(dialogic_bridge: Object) -> Dictionary
func start_ending_id(ending_id: String, context: Dictionary = {}) -> Dictionary
func is_ready() -> bool

# autoload/SceneRouter.gd
func configure_ending_ports(state_port: Object, playback_port: Object) -> Dictionary
func is_ending_ports_configured() -> bool
```

Narrative checkpoints persist a manifest-validated `boundary`, exact completed/revealed `event`, and exact `post_event` locator. Boundary kind is `timeline_start|line|choice|effect_transaction|variable_transaction|safe_marker|scene_transition|timeline_complete`; post position is `revealed_event|before_event|external_route|timeline_complete`. Choice/effect/variable checkpoints resume before their validated successor, so the completed transaction is neither replayed nor skipped. `variable_transaction` is both an accepted bridge signal and a skip hard stop.

For an ending, GameState returns `value={kind,ending_id,playback_context}` and the context has exactly `playback_id`, `transaction_id`, `expected_stage`, and `role`. EndingScene passes it unchanged. Starting returns immediately and never advances the EndingPlan; only a token-matched physical `timeline_ended` may produce `playback_completed`. A matching asynchronous failure clears the failed port binding while leaving the GameState command pending, so an explicit retry starts a new token.

`DialogicBridge.start_ending_id()` and `DialogicEndingPlaybackPort.start_ending_id()` both return the frozen outer CommandResult with `code=started` and `value={}`. The bridge receipt has exactly `playback_token`, `ending_id`, `role`, `timeline_id`, `label`, and `started`; the port receipt has exactly `playback_id`, `transaction_id`, `expected_stage`, `role`, `ending_id`, `playback_token`, and `started`. A synchronous failure has only `ok/code/message/details` and creates no binding. A matching asynchronous failure removes the token/active/cached-start binding before emitting failure, making the next identical request a real retry with a new token.

For SaveManager participation, concrete adapters wrap DialogicBridge, SceneRouter, ProfileManager, LocalizationManager, AudioManager, and GameState; the low-level DialogicRuntimeAdapter is not registered directly. The narrative adapter's `apply_silent` call occurs only after the restored route reports its target narrative layout ready.

### Audio

```gdscript
# autoload/AudioManager.gd
signal music_context_changed(context_id: String, context: Dictionary)
signal ambience_context_changed(context_id: String, context: Dictionary)
signal sfx_requested(cue_id: String, receipt: Dictionary)
signal audio_settings_applied(settings: Dictionary)
signal audio_warning(result: Dictionary)

func _init(playback_port: RefCounted = null) -> void
func initialize(profile: Node) -> Dictionary
func set_music_context(context_id: String, context: Dictionary = {}) -> Dictionary
func set_ambience_context(context_id: String, context: Dictionary = {}) -> Dictionary
func play_sfx(cue_id: String, context: Dictionary = {}) -> Dictionary
func get_music_context_id() -> String
func get_ambience_context_id() -> String
func get_semantic_audio_context() -> Dictionary
func set_channel_volume(channel_id: StringName, linear: float) -> Dictionary
func set_channel_muted(channel_id: StringName, muted: bool) -> Dictionary
func apply_profile_preferences(changed_path: StringName = &"") -> Dictionary
func prepare_semantic_restore(snapshot: Dictionary, prepared_profile: Dictionary) -> Dictionary
func capture_restore_state() -> Dictionary
func apply_restore_silent(plan: Dictionary) -> Dictionary
func rollback_restore_silent(backup: Dictionary) -> Dictionary
func finalize_restore() -> Dictionary
```

Dialogue presentation preferences (`text_speed`, `auto_text_speed`, and `auto_advance_dialogue`) are applied by DialogicBridge from committed ProfileManager notifications and at initialization. Preference or entire-profile reset uses the same post-commit notification path, so LocalizationManager, AudioManager, InputManager, AccessibilityManager, and DialogicBridge cannot retain stale live values.

`ProfileManager.is_line_visited()` is called before the current line is marked. Restore persists stable IDs and manifest locators, never arbitrary paths or Dialogic's complete addon-owned state.

### Phase 3 contracts

```gdscript
# scripts/domain/desktop/DesktopAppRegistry.gd
static func get_ids() -> Array[StringName]
static func has_app(app_id: StringName) -> bool
static func get_record(app_id: StringName) -> Dictionary
static func validate_all() -> Dictionary

# scripts/domain/minesweeper/MinesweeperRoundContract.gd
static func validate_start_request(request: Dictionary) -> Dictionary
static func validate_result(active_round: Dictionary, result: Dictionary) -> Dictionary
static func build_round_id(run_id: String, day: int, ordinal: int) -> String

# scripts/domain/desktop/DesktopAppHostState.gd
func reset(current_day: int) -> void
func open_app(app_id: StringName, current_day: int) -> Dictionary
func close_app() -> Dictionary
func change_day(new_day: int) -> Dictionary
func get_state() -> Dictionary
func capture_persistent_state() -> Dictionary
func prepare_restore(active_app_id: Variant, current_day: int) -> Dictionary

# scripts/application/run/SaveManagerCheckpointPort.gd
func configure_desktop_context_provider(provider: Object) -> Dictionary

# route restore participant
func configure_desktop_host(host: Object) -> Dictionary

# autoload/ApplicationBootstrap.gd
func register_desktop_eviction_port(port: Object) -> Dictionary

# Phase-3 desktop eviction port
func dispatch_desktop_eviction(command: Dictionary) -> Dictionary

# scripts/domain/desktop/LogoutPolicy.gd
static func plan(confirmed: bool, has_stable_checkpoint: bool) -> Dictionary

# scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd
func configure(save_port: Object, state_port: Object) -> Dictionary
func begin_round(request: Dictionary) -> Dictionary
func complete_round(round_id: String, result: Dictionary, transaction_id: String) -> Dictionary
func abort_round(round_id: String, reason: StringName, transaction_id: String) -> Dictionary
func get_active_round() -> Dictionary

# scripts/application/minesweeper/GameStateMinesweeperPort.gd
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

# scripts/application/minesweeper/SaveManagerMinesweeperPort.gd
func capture() -> Dictionary
func preview_checkpoint_id(run_id: String) -> Dictionary
func prepare_checkpoint(checkpoint_inputs: Dictionary, checkpoint_kind: StringName, disk_write: Dictionary) -> Dictionary
func commit_checkpoint(candidate: Dictionary) -> Dictionary
func rollback(backup: Dictionary) -> Dictionary
func acquire_board_lock() -> Dictionary
func release_board_lock() -> Dictionary
func owns_board_lock() -> bool
```

The only desktop app IDs are `minesweeper`, `contacts`, `schedule`, `shop`, `backup`, `settings`, and `logout`. Phase 2R validates the registry and interfaces; Phase 3 owns visible app-host composition and simulator UI wiring. A player cannot close or route away from an active board. `abort_round()` is restricted to trusted teardown/error handling, restores the captured pre-board run candidate, emits no result/reward, and releases the lock only after rollback succeeds; an abort failure keeps the lock.

`get_state()` is runtime-only and may contain a per-day cache. `capture_persistent_state()` returns exactly `{"active_app_id": <registered ID or null>}`. Restore always rebuilds an empty cache and, when the saved ID is non-null, returns a command to instantiate that registered app; cached IDs are never serialized. ApplicationBootstrap owns one process-lifetime DesktopAppHostState, supplies that same object identity to the route participant and SaveManagerCheckpointPort, and rejects replacement. Save capture asks this provider immediately before RunSnapshotSchema.build(); no second desktop-state authority exists. ApplicationBootstrap is also the sole desktop day-change owner: it consumes `GameState.day_changed` exactly once, calls `DesktopAppHostState.change_day(new_day)` once, and sends the returned exact eviction command through one registered `dispatch_desktop_eviction` port. Phase 3 registers/consumes that port and never connects another desktop day handler or calls `change_day` itself.

Plan 05's `initialize_dialogic_bridge` stage has already configured one `SaveManagerNarrativeCheckpointPort` with the one real Plan-03 checkpoint port and six stable provider Callables, then injected that same adapter into DialogicBridge and GameState. Its Bootstrap-private `active_app_id` provider returns JSON null until the desktop host exists. Plan 06 assigns the one host to the existing private slot read by that Callable and configures the direct checkpoint provider from the same host; it never replaces the Callable, adapter, real checkpoint port, or either consumer's retained adapter identity.

An active round has exactly `round_id`, `run_id`, `context`, `difficulty`, `day`, `ordinal`, and `dating_evidence`; dating evidence is null for app play and exactly `{entry_id,route_transaction_id,friend_ids}` for a trusted dating substage. `prepare_begin` returns candidate/active-round/pre-board checkpoint/start receipt. `prepare_complete` returns a detached prepared candidate/receipt with empty checkpoint ID; the save port previews the next ID without consuming it; `finalize_complete` owner-validates the ID into the candidate/receipt/event batch and builds final post-result checkpoint inputs; checkpoint prepare must return that same ID. The receipt freezes transaction/round/context/difficulty/outcome, counter deltas, task/effect/message transaction IDs, optional group activation/dating outcome, and the committed checkpoint ID. Every public coordinator entry calls the state port's shared-gate `guard_external()` first, before normalization, duplicate lookup, validation, or any other port call.

Round start publishes one exact `round_started` event only after the pre-board checkpoint/autosave, lock, and active candidate commit. A pre-emission start-publication failure rolls back the active candidate and releases the lock while retaining the valid pre-board autosave; rollback/release failure retains the lock, projects its ordered raw diagnostics through `FatalDiagnosticProjector`, calls `GameStateMinesweeperPort.latch_fatal()`, and returns the exact retained failure from `guard_external()`. All three methods delegate to the one injected ApplicationMutationGate; the port owns no alternate Boolean or retained-failure cache.

Completion has one explicit durable boundary. The coordinator normalizes the result to exact `{outcome:String}` and checks stored completed/pending transactions before requiring a live round, making later duplicates reachable and conflicting retries rejectable. Validation, preview/finalization, preparation, checkpoint commit, or state commit failure rolls committed ports back in reverse and leaves the active round/lock/sequence byte-equal when rollback succeeds. After both commits, an in-memory pending record retains the exact CompletionReceipt, ordered domain event batch, checkpoint ID, and normalized result and owns `publish` then `release_lock`: publication failure returns `COMPLETION_COMMITTED_UNPUBLISHED` without rolling back durable truth, and lock-release failure returns `LOCK_RELEASE_PENDING`; only an exact round/transaction/result retry resumes that phase. Player saves are silently disabled throughout an active/pending board, with a pre-board autosave and no quick-save reminder or unavailable message.

The Phase-3 handoff is not free-form prose. Both `desktop-contract.schema.json`/`DesktopContractEvidence`/canonical `desktop_contract.json` and `minesweeper-contract.schema.json`/`MinesweeperContractEvidence`/canonical `minesweeper_contract.json` have strict generators, validators, source-binding mutation tests, and seven exact isolated command records. Fresh regeneration must be byte-equal before `.9` closes. Desktop evidence binds the registry, one-host persistence, stable Plan-05 narrative-provider identity, Bootstrap-only day change, and one eviction port; Minesweeper evidence binds every port signature (including fatal-latch delegation), source hash, fixture, retry phase, and the `reason=stage` post-result call.

### Application bootstrap

Every project-manager autoload `_ready()` is side-effect-free. `ApplicationBootstrap._ready()` performs only one deferred call to `start(...)` after all autoload ready callbacks finish; `start()` is the sole startup orchestrator. ApplicationBootstrap is ordered after the Dialogic addon and every project manager. Its final sequence is: select/prove isolated or production roots; construct and inject the single ApplicationMutationGate; initialize ProfileManager; initialize SaveManager; initialize LocalizationManager from the profile language; initialize InputManager and AccessibilityManager from ProfileManager; initialize AudioManager from profile preferences; initialize DialogicBridge with the already-ready Dialogic autoload, construct/configure the one shared SaveManagerNarrativeCheckpointPort with its six stable Callables and the retained real checkpoint port, inject it into DialogicBridge/GameState, construct the DialogicEndingPlaybackPort, and call `SceneRouter.configure_ending_ports(GameState, playback_port)`; construct the one DesktopAppHostState, assign it behind the existing stable active-app Callable without replacing any narrative/checkpoint identity, configure the RouteRestoreParticipant with it, and configure SaveManager's six restore participants; configure DayResolutionCoordinator and supply that same desktop host as the direct checkpoint context provider; configure MinesweeperRoundCoordinator; connect the one Bootstrap-owned desktop day-change handler; then emit `application_ready`. Plan06 Task 2 finalizes and tests those bytes before Task 3 hashes either handoff. Any step failure records one fatal startup result, leaves menu/run input disabled, and does not silently continue with a partially initialized application.

### Final evidence protocol

The final runner records a closed subject set of four completed read-only Beads commands and six completed isolated Godot commands. Validator processes are not subjects, avoiding self-validation. A build pass writes `final.json` from the ten finished records and six immutable subject logs, then exits; the parent hashes that completed build log, `final.json`, and validator script into `validator-run.json`. A separate closure pass validates those completed bytes and writes a different immutable closure log, so no validator hashes a file that it is still appending. Any authorized retirement/deletion and its exact cleanup commit `S` occur before Full mode. `S` includes the exact tracked `.beads/interactions.jsonl` and `.beads/issues.jsonl` bytes proving `.1` through `.9` closed, `.10` in_progress, and epic open; those same statuses are recorded by Full. A second separately authorized sole-child commit `E` seals exactly the three final JSON artifacts and eight logs. `VerifyExisting` first proves the exact pre-closure chain `S -> E`, its eleven-path diff, HEAD-blob equality, the recorded preclosure statuses, and a clean tree. Only a third, separately authorized Beads-mutation/commit gate may close `.10` and the epic and create sole-child `B` changing exactly the same two tracked journals; the final read-only pass accepts only `S -> E -> B`, proves the eleven evidence blobs unchanged, and derives the closed issue state from `B` without rewriting or asking `final.json` to predict either future commit ID. Without any required archive, deletion, Beads-mutation, commit, or evidence-seal authority, the protocol stops at the last clean proven state and never claims a later one.

## Plan set and execution order

- [ ] Execute [Documentation and Tooling](2026-07-17-phase-2r-01-documentation-tooling.md) — `dwm-p2r.1`, then `dwm-p2r.2`.
- [ ] Execute [Profile, Localization, and Audio](2026-07-17-phase-2r-02-profile-localization-audio.md) — `dwm-p2r.3`.
- [ ] Execute [Lifecycle and Save/Restore](2026-07-17-phase-2r-03-lifecycle-save.md) — `dwm-p2r.4`, then `dwm-p2r.5`.
- [ ] Execute [Invitations, Schedule, and Endings](2026-07-17-phase-2r-04-invitations-schedule-endings.md) — `dwm-p2r.6`, then `dwm-p2r.7`.
- [ ] Execute [Dialogic, Effects, and Skip](2026-07-17-phase-2r-05-dialogic-skip.md) — `dwm-p2r.8`.
- [ ] Execute [Phase 3 Contracts and Integration Evidence](2026-07-17-phase-2r-06-phase3-contracts-integration.md) — `dwm-p2r.9`, then `dwm-p2r.10`.

Within each issue, execute tasks in written order. Independent work may be delegated only after its blockers close and only when agents will not edit overlapping files. `GameState.gd`, `project.godot`, and shared manifest/schema files are serialized integration points.

## Specification traceability

| Approved section | Owning issue and plan task |
|---|---|
| §1 Objective and exclusions | Master authorization; plan 01 Tasks 2/4; plan 06 Task 6 gate |
| §2 Evidence baseline | plan 01 Task 1 |
| §3 Authority model | plan 01 Tasks 2 and 4 |
| §4 Documentation architecture | plan 01 Tasks 2 and 4 |
| §5 Runtime ownership and seams | plan 02 Tasks 1/2/6; plan 03 Tasks 1–3; plan 05 Tasks 1–3 |
| §6 Run lifecycle | plan 03 Tasks 1–3; plan 04 Tasks 5–6; plan 06 Task 5 |
| §7 Hospital, dating, endings | plan 04 Tasks 5–6; plan 06 Task 5 |
| §8 Contacts and invitations | plan 04 Tasks 1–4; plan 06 Task 5 |
| §9 Save, restore, profile | plan 02 Tasks 1–2; plan 03 Tasks 4–6; plan 06 Task 5 |
| §10 Dialogic and effects | plan 05 Tasks 1–5 |
| §11 Phase 3 contracts | plan 06 Tasks 1–3 |
| §12 Audio and preferences | plan 02 Tasks 1–2 and 6 |
| §13 Custom JSON localization | plan 02 Tasks 3–5 |
| §14 Testing and evidence | every RED/GREEN step; plan 06 Tasks 4–7 |
| §15 Beads and tooling | durable graph above; plan 01 Task 2; plan 06 Task 6 preflight and Task 7 close protocol |
| §16 CodeGraph removal | plan 01 Task 5 |
| §17 Execution strategy | this order and every issue close gate |
| §18 Rejected alternatives | master prohibitions and subsystem negative tests |
| §19 Deferred narrative adapter | `.1` decision packet; `.8` exclusion assertion |
| §20 Written-spec gate | this plan approval gate |

No approved section is intentionally uncovered. Requirement-packet migration will replace section-number traceability with stable `req.*` IDs before runtime issue `.3` or `.4` is claimed.

## Final evidence commands

`dwm-p2r.10` runs the checked-in orchestrator below. The orchestrator creates a clean unique root, redirects `DWM_TEST_ROOT`, `APPDATA`, and `LOCALAPPDATA`, verifies Godot's resolved `user://`, executes every command independently with fail-fast handling, records every argv and exit code even on failure, and copies exact logs into `evidence/phase_2r/logs/` before schema validation:

```powershell
& .\tools\evidence\run_phase2r_gate.ps1
```

Expected final evidence:

```text
Godot import exit=0
GUT failed=0
Phase 2R on-tree scenes failed=0
Documentation validation errors=0
Manifest/schema validation errors=0
Project-owned orphan_nodes=0
Project-owned unfreed_nodes=0
Project-owned retained_resources=0
Unexpected errors=0
Dependency cycles=0
Day 8 current-state occurrences=0
Unconditional-pass stubs=0
Production persistence paths reached by tests=0
```

Third-party diagnostics may be excluded only by a machine-readable exception containing owner, exact diagnostic fingerprint, reason, created date, and expiry date. No project-owned diagnostic may be excepted.

## Conservative commit protocol

Every subsystem plan names proposed commit boundaries. If the user later grants the boundary's exact commit authority, the worker captures the required parent and invokes Plan 01's checked-in exact-path helper with only the task's literal status map and declared present-only UID companions. A nonempty or uninspectable starting index, unexpected/partial path, wrong status or mode, ancestry drift, or post-commit mismatch is a hard stop. Never unstage, overwrite, or otherwise alter a pre-existing index entry to make a boundary pass.

## Completion condition

Phase 2R is complete only when all ten child issues are evidence-closed, the final generated gate report passes, the epic closes, and no implementation work remains. Closing the planning issue or approving this plan does not itself complete Phase 2R or unblock Phase 3.
