extends Node

## SaveManager — isolated, atomic save-document and checkpoint persistence
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 6).
## Owns slot/quick/autosave I/O through one injected StorageAdapter and the
## in-memory CheckpointJournal. Never interprets gameplay rules.

signal save_completed(result: Dictionary)
signal load_completed(result: Dictionary)
signal save_failed(result: Dictionary)
signal load_failed(result: Dictionary)
signal slot_metadata_changed()
signal run_restored(checkpoint_id: String, route_id: String)
signal save_capability_changed(capability: Dictionary)
signal live_session_ready()

const MIN_SLOT := 1
const MAX_SLOT := 7

const CHECKPOINT_JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE_DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const SAVE_MIGRATIONS := preload("res://scripts/infrastructure/save/SaveMigrations.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")
## Plan 02 Task 6 (dwm-p2r.32), Phase C2: the external New-Run/restore continuation journal (Task 1,
## dwm-p2r.16) -- distinct from `_journal` (CheckpointJournal) below, which is SaveManager's OWN
## in-memory per-run bundle history. `_continuation_journal` durably records the intent/allocation/
## participant-apply state machine that survives a process crash; `DesktopIdentityAllocationRestore
## Participant` cannot drive its `advance()` calls itself (its frozen `prepare()` input carries no
## `request_fingerprint` -- only whoever calls `prepare_intent()`/`commit_intent()` ever sees one), so
## SaveManager is the one place all journal advancement happens, for both new_run and restore.
const CONTINUATION_JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")

const _GATE_CONTRACT_METHODS: Array[String] = [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]
const _LOCK_OWNERS: Array[StringName] = [&"minesweeper_board", &"scene_transition", &"restore"]
const _CHECKPOINT_INPUT_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint",
	"route_id", "snapshot_input",
]
## IMPORTANT 5 (brief line 209: "input containing any issuer/allocation/remap field rejects before
## durable allocation"). The exact allow-list `commit_prepared_restore()` accepts: the 9 keys
## `_prepare_bundle_with_all_participants()` puts into a genuine `prepare_restore_slot|quick|
## autosave()` result, which is a superset of the 3-key hand-built shape the pure fake-participant
## orchestration tests use (`participant_plans`, `checkpoint_id`, `route_id`). A stray issuer/
## allocation/remap-shaped key (e.g. `identity_allocation_bundle`, `transaction_issuer_receipt`,
## `transaction_remap`) is never legitimate top-level input here -- those are produced INSIDE
## `_begin_restore_continuation()`, never accepted from a caller.
const _PREPARED_RESTORE_ALLOWED_KEYS: Array[String] = [
	"bundle", "journal_seed", "participant_plans", "route_id", "checkpoint_id",
	"source_locator", "existing_run_id", "source_desktop_timeline_generation",
	"remap_source_transaction_ids", "scene_preparation_token",
]

var _storage: RefCounted = null
var _journal: RefCounted = CHECKPOINT_JOURNAL.new()
var _continuation_journal: RefCounted = CONTINUATION_JOURNAL.new()
var _mutation_gate: Object = null
var _identity_issuer: Object = null
var _new_run_profile_owner: Object = null
var _scene_new_run_bridge: Object = null
var _scene_new_run_bundle: Dictionary = {}
var _scene_title_new_run_target := ""
var _scene_title_new_run_context: Dictionary = {}
var _new_run_busy := false
var _new_run_slice_started_us := 0
var _new_run_gate_token := ""
# Process-local tickets survive same-operation retries; never saved in player data.
var _session_activation_tickets: Dictionary = {}
var _scene_restore_preparations: Dictionary = {}
var _scene_restore_preparation_counter := 0
var _scene_restore_activation: Dictionary = {}
var _completed_scene_restore: Dictionary = {}
var _scene_activation_busy := false
var _scene_restore_commit_busy := false
const _SCENE_PARTICIPANT_ORDER: Array[String] = [
	"run", "desktop_consequence", "desktop_board", "profile", "localization", "audio", "route", "narrative",
]
var _new_run_transaction_id := ""
var _prepared_new_run: Dictionary = {}
var _prepared_new_run_counter := 0
var _lock_owner: StringName = &""
var _pending_deferred_save := false
var _restore_participants: Dictionary = {}
var _backup_actions: Dictionary = {}
var _backup_action_sequence := 0
var _backup_capture_provider: Callable
var _backup_capture_available: Callable
var _paused_desktop_admission: Callable
var _backup_capture_configured := false
## Bytes-only parser reuse. Schema/content admission and all storage custody checks
## still run on every call. Keep no more than two documents or 8 MiB of source UTF-8.
const _PARSE_CACHE_MAX_ENTRIES := 2
const _PARSE_CACHE_MAX_TEXT_BYTES := 8 * 1024 * 1024
var _document_parse_cache: Array[Dictionary] = []
var _document_parse_cache_text_bytes := 0

## Bootstrap owns the live desktop source. Fixtures without this provider retain
## their explicit latest-stable contract; production never silently falls back.
func configure_backup_capture_provider(provider: Callable, paused_desktop_admission: Callable = Callable(),
		available: Callable = Callable()) -> Dictionary:
	if not provider.is_valid() or provider.get_argument_count() != 0 or provider.get_object_id() == 0:
		return _fail(&"invalid_backup_capture_provider", "A bound zero-argument provider is required")
	if paused_desktop_admission.is_valid() and paused_desktop_admission.get_argument_count() != 1:
		return _fail(&"invalid_backup_capture_provider", "Paused desktop admission takes exact capture inputs")
	if not available.is_null() and (not available.is_valid() or available.get_argument_count() != 0):
		return _fail(&"invalid_backup_capture_provider", "Availability takes no capture inputs")
	if _backup_capture_configured and (_backup_capture_provider != provider or _paused_desktop_admission != paused_desktop_admission \
			or _backup_capture_available != available):
		return _fail(&"backup_capture_already_configured", "")
	_backup_capture_provider = provider
	_backup_capture_available = available
	_paused_desktop_admission = paused_desktop_admission
	_backup_capture_configured = true
	return {"ok": true}

func initialize(storage: StorageAdapter = null) -> Dictionary:
	if storage == null:
		return _fail(&"invalid_storage", "SaveManager requires an injected StorageAdapter")
	_document_parse_cache.clear()
	_document_parse_cache_text_bytes = 0
	_storage = storage
	var journal_ready: Dictionary = _continuation_journal.configure(storage, self)
	if not journal_ready.get("ok", false):
		return _fail(StringName(str(journal_ready.get("code", "continuation_journal_configure_failed"))),
			str(journal_ready.get("message", "")))
	return {"ok": true, "code": &"ok", "value": {"root": storage.describe_root()}}

## Plan 02 Task 6 (dwm-p2r.32): the desktop identity issuer `start_new_run()` allocates a real
## branch/generation/causal-day identity through, rather than inventing or accepting one from the
## caller. Mirrors GameState's own `configure_identity_issuer` DI pattern; SaveManager needs its own
## reference because it -- not GameState -- owns the New-Run transaction boundary.
func configure_identity_issuer(identity_issuer: Object) -> Dictionary:
	if identity_issuer == null:
		return _fail(&"invalid_identity_issuer", "identity issuer is required")
	for method_name: String in ["issue", "prepare_continuation_allocation", "commit_continuation_allocation"]:
		if not identity_issuer.has_method(method_name):
			return _fail(&"invalid_identity_issuer", "missing " + method_name)
	if _identity_issuer != null:
		if _identity_issuer == identity_issuer:
			return {"ok": true, "code": &"ok",
				"value": {"issuer_instance_id": _identity_issuer.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return _fail(&"identity_issuer_already_configured", "")
	_identity_issuer = identity_issuer
	return {"ok": true, "code": &"ok",
		"value": {"issuer_instance_id": _identity_issuer.get_instance_id(), "already_configured": false},
		"receipt": {}}

func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"):
		return _fail(&"invalid_mutation_gate", "gate contract incomplete")
	for method in _GATE_CONTRACT_METHODS:
		if not gate.has_method(method):
			return _fail(&"invalid_mutation_gate", "missing method: " + method)
	if _mutation_gate != null:
		if gate == _mutation_gate:
			return {"ok": true, "code": &"ok",
				"value": {"gate_instance_id": _mutation_gate.get_instance_id(), "already_configured": true},
				"receipt": {}}
		return _fail(&"mutation_gate_already_configured", "")
	_mutation_gate = gate
	gate.capability_changed.connect(_on_backup_gate_capability_changed)
	return {"ok": true, "code": &"ok",
		"value": {"gate_instance_id": _mutation_gate.get_instance_id(), "already_configured": false},
		"receipt": {}}

func record_stable_checkpoint(checkpoint_inputs: Dictionary, checkpoint_kind: StringName) -> Dictionary:
	if _storage == null:
		return _fail(&"not_initialized", "")
	var input_error := _validate_checkpoint_inputs(checkpoint_inputs)
	if input_error != "":
		return _fail(&"invalid_checkpoint_inputs", input_error)
	var run_id := str((checkpoint_inputs["snapshot_input"]["lifecycle"] as Dictionary).get("run_id", ""))
	var peeked: Dictionary = _journal.peek_next_sequence(run_id)
	if not peeked.get("ok", false):
		return peeked
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(
		_compose_live_checkpoint_input(checkpoint_inputs["snapshot_input"]), checkpoint_inputs["dialogic_checkpoint"],
		str(checkpoint_inputs["route_id"]), checkpoint_inputs["active_app_id"],
		checkpoint_inputs["audio_context"], int(checkpoint_inputs["content_version"]),
		int(peeked["value"]["checkpoint_sequence"]))
	if not built.get("ok", false):
		return built
	var prepared: Dictionary = _journal.prepare_record(built["value"]["snapshot"], checkpoint_kind)
	if not prepared.get("ok", false):
		return prepared
	var committed: Dictionary = _journal.commit_prepared(prepared["value"]["candidate"])
	if not committed.get("ok", false):
		return committed
	if _pending_deferred_save and _lock_owner == &"":
		_pending_deferred_save = false
		autosave_latest()
	save_capability_changed.emit(get_save_capability())
	return committed

func get_latest_stable_checkpoint() -> Dictionary:
	return _journal.get_current_bundle()

func save_latest_to_slot(slot_id: int) -> Dictionary:
	return _write_latest(_resolve_locator(&"slot", slot_id), "manual")

func quick_save_latest() -> Dictionary:
	return _write_latest(_resolve_locator(&"quick", -1), "quick")

func autosave_latest() -> Dictionary:
	return _write_latest(_resolve_locator(&"autosave", -1), "automatic")

## Only the confirmed session-exit owner may write under abandonment custody.
func save_session_exit_checkpoint(inputs: Dictionary, handle: Dictionary) -> Dictionary:
	if _mutation_gate == null or not _mutation_gate.is_internal_owner_active(&"session_abandonment"):
		return _fail(&"session_abandonment_required", "")
	if not _restore_participants.has("run") \
			or _restore_participants.run.capture_live_session().get("value") != handle \
			or not handle.get("active", false):
		return _fail(&"stale_live_session", "")
	var recorded := record_stable_checkpoint(inputs, &"scene_transition")
	if not recorded.get("ok", false): return recorded
	return _write_latest(_resolve_locator(&"autosave", -1), "logout", true)


func prepare_restore_slot(slot_id: int) -> Dictionary:
	return _prepare_restore(_resolve_locator(&"slot", slot_id))

func prepare_restore_quick() -> Dictionary:
	return _prepare_restore(_resolve_locator(&"quick", -1))

func prepare_restore_autosave() -> Dictionary:
	return _prepare_restore(_resolve_locator(&"autosave", -1))


func commit_prepared_restore(prepared: Dictionary) -> Dictionary:
	if _scene_restore_commit_busy or not _scene_restore_activation.is_empty():
		return _fail(&"scene_restore_busy", "a retained scene restore owns custody")
	_scene_restore_commit_busy = true
	var result := _commit_prepared_scene_restore(prepared)
	_scene_restore_commit_busy = false
	return _content_result(result)


func _commit_prepared_scene_restore(prepared: Dictionary) -> Dictionary:
	if _restore_participants.is_empty():
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "configure_scene_restore_participants first")
	for key: Variant in prepared.keys():
		if str(key) not in _PREPARED_RESTORE_ALLOWED_KEYS:
			return _fail(&"invalid_prepared_restore", "unexpected prepared key: " + str(key))
	if typeof(prepared.get("participant_plans")) != TYPE_DICTIONARY:
		return _fail(&"invalid_prepared_restore", "prepared requires participant_plans")
	var retained := _validate_scene_restore_preparation(prepared)
	if not retained.get("ok", false): return retained
	prepared = _scene_restore_preparations[prepared.scene_preparation_token].prepared
	var plans: Dictionary = prepared.participant_plans.duplicate(true)
	var operation_id := "scene_load:" + str(prepared.scene_preparation_token)
	_scene_restore_preparations.erase(prepared.scene_preparation_token)
	_completed_scene_restore.clear()
	return _run_scene_restore_transaction(plans, prepared.journal_seed,
		str(prepared.route_id), str(prepared.checkpoint_id), true,
		{"kind": "memory_restore", "transaction_id": operation_id}, "", false)


## PREPARE_INTENT is the durable decision. Before it, preparation is detached;
## after it, errors retain custody and retries finish the same frozen pair forward.
## Explicit scene creation dependency. This configures validation, not a production target.
func configure_scene_new_run(bridge: Object) -> Dictionary:
	if not is_instance_valid(bridge) or bridge.get_script() != load("res://autoload/DialogicBridge.gd") or _identity_issuer == null:
		return _fail(&"scene_new_run_not_configured", "actual Bridge and issuer required")
	if _scene_new_run_bridge != null and _scene_new_run_bridge != bridge:
		return _fail(&"scene_new_run_already_configured", "")
	var selected: Dictionary = preload("res://scripts/narrative/DialogicEntryManifest.gd").scene_contract_tables()
	if not selected.get("ok", false): return selected
	var configured: Dictionary = _continuation_journal.configure_scene_new_run_validation(selected.bundle, _identity_issuer)
	if not configured.get("ok", false): return configured
	_scene_new_run_bridge = bridge
	_scene_new_run_bundle = selected.bundle
	return {"ok": true}

## Application configuration selects the installed opening once. The title uses its existing
## prepare/confirm/commit capability; no UI token grants direct scene admission.
func configure_scene_title_new_run(target_id: String) -> Dictionary:
	if not is_instance_valid(_scene_new_run_bridge) or _scene_new_run_bundle.is_empty():
		return _fail(&"scene_new_run_not_configured", "")
	if _scene_new_run_bundle.get("schema_version") != 3:
		return _fail(&"scene_title_audio_catalogue_required", "")
	if not _scene_title_new_run_target.is_empty():
		return {"ok": true} if _scene_title_new_run_target == target_id else _fail(&"scene_title_new_run_already_configured", "")
	if _new_run_busy or not _prepared_new_run.is_empty() or not _new_run_transaction_id.is_empty():
		return _fail(&"new_run_busy", "")
	for row: Dictionary in _scene_new_run_bundle.targets:
		if row.target_id == target_id and row.target.kind == "scene":
			_scene_title_new_run_target = target_id
			_scene_title_new_run_context = {"route_id": "scene", "audio_context": {},
				"content_version": row.target.content_version}
			return {"ok": true}
	return _fail(&"scene_initial_target_invalid", target_id)

## The caller selects only an installed target and presentation context. All identity,
## assignment and reading materials are produced and retained by their existing owners.
func start_scene_new_run(target_id: String, initial_context: Dictionary, _rng_nonce: Variant = null) -> Dictionary:
	if _new_run_busy or not _scene_restore_activation.is_empty(): return _fail(&"new_run_busy", "")
	var ready := _new_run_ready(true)
	if not ready.ok: return ready
	var acquired := _take_new_run_custody()
	if not acquired.ok: return acquired
	_new_run_busy = true
	var result := _start_scene_new_run_in_memory(target_id, initial_context)
	_new_run_busy = false
	if not result.ok and _scene_restore_activation.is_empty():
		_release_new_run_custody()
	return _content_result(result)

## A new run has no durable creation transaction. Keep only the allocated identities
## that later board/day/save operations use, and pass fresh state straight to activation.
func _start_scene_new_run_in_memory(target_id: String, initial_context: Dictionary) -> Dictionary:
	var target := {}
	for row: Dictionary in _scene_new_run_bundle.targets:
		if row.target_id == target_id and row.target.kind == "scene": target = row.target
	if target.is_empty(): return _fail(&"scene_initial_target_invalid", target_id)
	var issued: Dictionary = _identity_issuer.issue(&"transaction_id")
	if not issued.ok: return issued
	var operation_id: String = issued.value.token
	var allocated: Dictionary = _identity_issuer.prepare_continuation_allocation({"kind": "new_run",
		"transaction_id": operation_id, "transaction_issuer_receipt": issued.value.issuer_receipt,
		"existing_run_id": null, "source_desktop_timeline_generation": null, "remap_source_transaction_ids": []})
	if not allocated.ok: return allocated
	var committed: Dictionary = _identity_issuer.commit_continuation_allocation(allocated.value)
	if not committed.ok: return committed
	var allocation: Dictionary = allocated.value
	var input: Dictionary = _restore_participants.run.prepare_scene_new_run_snapshot_input(
		allocation, target.entry_id, operation_id)
	if not input.ok: return input
	var reading: Dictionary = _scene_new_run_bridge._build_current_scene_initial_checkpoint(
		input.value.snapshot_input.scene, _scene_new_run_bundle)
	if not reading.ok: return reading
	var built := RUN_SNAPSHOT_SCHEMA.build_scene(input.value.snapshot_input, reading.value,
		"scene", null, {}, initial_context.content_version, 1)
	if not built.ok: return built
	var snapshot: Dictionary = built.value.snapshot
	var profile := {"candidate": _new_run_profile_owner.get_profile_snapshot()}
	var plans := _prepare_scene_new_run_plans(snapshot, allocation, profile)
	if not plans.ok: return plans
	var reset := {"candidate_kind": "reset", "run_id": snapshot.run_id, "next_sequence": 2,
		"current": {"checkpoint_kind": "day_start", "snapshot": snapshot}, "earlier": []}
	_new_run_transaction_id = operation_id
	return _run_scene_restore_transaction(plans.value, reset, "scene", snapshot.checkpoint_id,
		false, {"kind": "memory_new_run", "transaction_id": operation_id}, _new_run_gate_token, false)

func _prepare_scene_new_run_plans(snapshot: Dictionary, allocation: Dictionary, profile_material: Dictionary) -> Dictionary:
	var run: Dictionary = _restore_participants.run.prepare_scene_new_run(snapshot, allocation,
		profile_material, _scene_new_run_bundle, _identity_issuer, self)
	if not run.get("ok", false): return run
	var profile: Dictionary = _restore_participants.profile.prepare_frozen_profile(profile_material.candidate)
	if not profile.get("ok", false): return profile
	var narrative: Dictionary = _restore_participants.narrative.prepare_scene_new_run(snapshot, allocation,
		profile_material, _scene_new_run_bundle, _identity_issuer, self)
	if not narrative.get("ok", false): return narrative
	var plans := {"run": run.value.run_plan, "profile": profile.value.profile_plan, "narrative": narrative.value.narrative_plan}
	# Creation installs the authored base first; entry cues execute at actual
	# native activation. The snapshot already records their final selection.
	var audio_snapshot := snapshot.duplicate()
	if _scene_new_run_bundle.get("audio_catalogue", {}).get("schema_version") == 3:
		audio_snapshot.scene = snapshot.scene.duplicate()
		audio_snapshot.scene.erase("music_plan_id")
	var audio_context := RUN_SNAPSHOT_SCHEMA.derive_scene_audio_context(audio_snapshot, _scene_new_run_bundle)
	if not audio_context.ok: return audio_context
	var inputs := {"desktop_consequence": {"state": snapshot.desktop.consequence},
		"desktop_board": {"state": snapshot.desktop.board, "schema_version": 9},
		"localization": {"locale_id": profile.value.locale_id, "font_style": profile.value.get("font_style", "pixel"),
			"text_size": profile.value.get("text_size", 100)},
		"audio": {"preferences": profile_material.candidate.preferences, "audio_context": audio_context.value},
		"route": {"route_id": "scene", "route_context": {"run_id": snapshot.run_id,
			"lifecycle_state": snapshot.lifecycle.state, "active_app_id": null,
			"scene": snapshot.scene.duplicate(true), "contacts": snapshot.contacts.duplicate(true)}}}
	if _scene_new_run_bundle.get("schema_version") == 3:
		inputs.audio["scene_audio_mode"] = "entry"
	var names := {"desktop_consequence": "consequence_plan", "desktop_board": "board_plan",
		"localization": "localization_plan", "audio": "audio_plan", "route": "route_plan"}
	for key: String in inputs:
		var prepared: Dictionary = _restore_participants[key].prepare(inputs[key])
		if not prepared.get("ok", false): return prepared
		plans[key] = prepared.value[names[key]]
	return {"ok": true, "value": plans}

func _resume_scene_new_run(operation: Dictionary, gate_token: String) -> Dictionary:
	if not _scene_restore_activation.is_empty():
		if _scene_restore_activation.operation_id != operation.transaction_id: return _fail(&"new_run_recovery_conflict", "")
		return _drive_scene_restore_activation()
	if operation.stage == CONTINUATION_JOURNAL.STAGE_COMPLETED and operation.activation_state == "acknowledged":
		return _release_new_run_custody()
	var settled: Dictionary = call("_settle_new_run_pair", operation, false)
	if not settled.get("ok", false): return _new_run_failure(settled)
	operation = settled.value
	if operation.stage == CONTINUATION_JOURNAL.STAGE_ALLOCATED:
		var advanced := _advance_new_run(operation, CONTINUATION_JOURNAL.STAGE_APPLYING)
		if not advanced.get("ok", false): return _new_run_failure(advanced)
		operation = advanced.value
	var material: Dictionary = operation.new_run_materials
	var parsed: Dictionary = STRICT_JSON.parse_object(material.autosave.outgoing_text)
	if not parsed.get("ok", false): return _new_run_failure(parsed)
	var snapshot: Dictionary = parsed.value.current_snapshot.snapshot
	var plans := _prepare_scene_new_run_plans(snapshot, material.allocation_candidate, material.profile)
	if not plans.get("ok", false): return _new_run_failure(plans)
	var reset: Dictionary = _journal.prepare_scene_new_run_reset(snapshot, material.allocation_candidate,
		material.profile, _scene_new_run_bundle, _identity_issuer)
	if not reset.get("ok", false): return _new_run_failure(reset)
	return _run_scene_restore_transaction(plans.value, reset.value.candidate, "scene", snapshot.checkpoint_id,
		false, {"kind": "scene_new_run", "transaction_id": operation.transaction_id,
		"request_fingerprint": operation.request_fingerprint}, gate_token,
		operation.stage in [CONTINUATION_JOURNAL.STAGE_APPLIED, CONTINUATION_JOURNAL.STAGE_COMPLETED])

func configure_new_run_profile_owner(owner: Object) -> Dictionary:
	if owner == null or not is_instance_valid(owner):
		return _fail(&"invalid_new_run_profile_owner", "")
	for method: String in ["prepare_new_run_consumption", "persist_new_run_consumption", "prove_new_run_consumption", "get_profile_revision"]:
		if not owner.has_method(method):
			return _fail(&"invalid_new_run_profile_owner", method)
	if _new_run_profile_owner != null and _new_run_profile_owner != owner:
		return _fail(&"new_run_profile_owner_already_configured", "")
	_new_run_profile_owner = owner
	return {"ok": true, "code": &"ok"}

func _new_run_ready(live: bool) -> Dictionary:
	if live and _restore_participants.is_empty():
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "")
	if _identity_issuer == null:
		return _fail(&"identity_issuer_not_configured", "")
	if _storage == null or _mutation_gate == null or _new_run_profile_owner == null:
		return _fail(&"new_run_not_configured", "")
	if live and _scene_new_run_bundle.is_empty():
		return _fail(&"scene_new_run_not_configured", "scene registration required")
	if live and not _restore_participants["profile"].has_method("prepare_frozen_profile"):
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "")
	return {"ok": true}

func _take_new_run_custody(transaction_id: String = "") -> Dictionary:
	if not _new_run_gate_token.is_empty():
		if _mutation_gate.is_fatal_latched() or not _mutation_gate.is_internal_owner_active(&"new_run") or _new_run_transaction_id != transaction_id:
			return _fail(&"new_run_recovery_conflict", "")
		return {"ok": true}
	var acquired: Dictionary = _mutation_gate.acquire(&"new_run")
	if not acquired.get("ok", false): return acquired
	_new_run_gate_token = str(acquired["value"]["token"])
	_new_run_transaction_id = transaction_id
	return {"ok": true}

func _release_new_run_custody() -> Dictionary:
	var released: Dictionary = _mutation_gate.release(&"new_run", _new_run_gate_token)
	if not released.get("ok", false): return _new_run_failure(released)
	_new_run_gate_token = ""
	_new_run_transaction_id = ""
	return {"ok": true}

func _new_run_failure(failure: Dictionary) -> Dictionary:
	return {"ok": false, "code": &"NEW_RUN_RECOVERY_PENDING", "recovery_required": true,
		"transaction_id": _new_run_transaction_id, "details": {"cause": failure.duplicate(true)}}

## Journal loading can reconcile durable artifacts, so it needs admission even
## before the actual New Run lease is acquired. All these operations are synchronous.
func _admit_new_run_journal_io() -> Dictionary:
	if _new_run_gate_token.is_empty():
		return _mutation_gate.guard_external(&"new_run_journal")
	if _mutation_gate.is_fatal_latched():
		return _mutation_gate.guard_external(&"new_run_journal")
	if not _mutation_gate.is_internal_owner_active(&"new_run"):
		return _fail(&"new_run_recovery_conflict", "retained custody is no longer active")
	# A prepared UI commit holds the New Run lease before it checks durable
	# incompletes, but has deliberately not issued its transaction identity yet.
	if _new_run_transaction_id.is_empty() and _prepared_new_run.is_empty():
		return _fail(&"new_run_recovery_conflict", "retained custody has no operation")
	return {"ok": true}

## Freezes the exact replaceable sources for the title consent sheet. This is a
## read-only operation: it neither loads the continuation journal nor allocates
## identity, reconciles storage, or changes live run state.
func prepare_new_run_action(initial_context: Dictionary) -> Dictionary:
	if _new_run_busy or not _scene_restore_activation.is_empty(): return _fail(&"new_run_busy", "")
	if not _scene_title_new_run_target.is_empty():
		for key: String in _SCENE_PARTICIPANT_ORDER:
			if not _restore_participants.has(key): return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", key)
	var ready := _new_run_ready(true)
	if not ready.get("ok", false): return ready
	var context_error := _validate_new_run_context(initial_context)
	if not context_error.is_empty(): return _fail(&"invalid_initial_context", context_error)
	if not _new_run_transaction_id.is_empty():
		return _new_run_failure(_fail(&"new_run_recovery_required", ""))
	var admitted: Dictionary = _mutation_gate.guard_external(&"new_run_prepare")
	if not admitted.get("ok", false): return admitted
	if not _scene_title_new_run_target.is_empty():
		var replaces_live: bool = _restore_participants.run.has_new_run_replacement()
		_prepared_new_run_counter += 1
		var token := "prepared-new-run-%d-%d" % [get_instance_id(), _prepared_new_run_counter]
		_prepared_new_run = {"token": token, "scene_target_id": _scene_title_new_run_target,
			"initial_context": _scene_title_new_run_context}
		var occupied: bool = _storage.exists("autosave.json")
		return {"ok": true, "value": {"token": token,
			"requires_confirmation": replaces_live or occupied,
			"replaces_live": replaces_live, "replaces_autosave": occupied}}
	return _fail(&"scene_new_run_not_configured", "scene title target required")

func cancel_prepared_new_run(token: String) -> Dictionary:
	if token.is_empty() or _prepared_new_run.is_empty() or token != str(_prepared_new_run.get("token", "")):
		return _fail(&"invalid_new_run_preparation", "")
	_prepared_new_run.clear()
	return {"ok": true, "code": &"ok", "value": {"cancelled": true}}

func commit_prepared_new_run(token: String) -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	if token.is_empty() or _prepared_new_run.is_empty() or token != str(_prepared_new_run.get("token", "")):
		return _fail(&"invalid_new_run_preparation", "")
	var ready := _new_run_ready(true)
	if not ready.get("ok", false): return ready
	if not _new_run_transaction_id.is_empty():
		_prepared_new_run.clear()
		return _new_run_failure(_fail(&"new_run_recovery_required", ""))
	_new_run_busy = true
	var result: Dictionary = call("_commit_prepared_new_run", false)
	_new_run_busy = false
	return result

## UI-only cooperative path; the existing mutation lease remains held across frame yields.
func commit_prepared_new_run_responsive(token: String) -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	if token.is_empty() or _prepared_new_run.is_empty() or token != str(_prepared_new_run.get("token", "")):
		return _fail(&"invalid_new_run_preparation", "")
	var ready := _new_run_ready(true)
	if not ready.get("ok", false): return ready
	if not _new_run_transaction_id.is_empty():
		_prepared_new_run.clear()
		return _new_run_failure(_fail(&"new_run_recovery_required", ""))
	_new_run_busy = true
	_new_run_slice_started_us = Time.get_ticks_usec()
	var result: Dictionary = await _commit_prepared_new_run(true)
	_new_run_busy = false
	return result


func _commit_prepared_new_run(_responsive: bool = false) -> Dictionary:
	var acquired := _take_new_run_custody()
	if not acquired.get("ok", false): return acquired
	var retained := _prepared_new_run.duplicate(true)
	_prepared_new_run.clear()
	var result := _start_scene_new_run_in_memory(retained.scene_target_id, retained.initial_context)
	if not result.ok and _scene_restore_activation.is_empty(): _release_new_run_custody()
	return result


func retry_new_run(transaction_id: String) -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	var ready := _new_run_ready(true)
	if not ready.get("ok", false): return ready
	if transaction_id.is_empty(): return _fail(&"invalid_new_run_transaction", "")
	_new_run_busy = true
	var result: Dictionary = call("_retry_new_run", transaction_id, false)
	_new_run_busy = false
	return result

## UI-only cooperative path; the existing mutation lease remains held across frame yields.
func retry_new_run_responsive(transaction_id: String) -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	var ready := _new_run_ready(true)
	if not ready.get("ok", false): return ready
	if transaction_id.is_empty(): return _fail(&"invalid_new_run_transaction", "")
	_new_run_busy = true
	_new_run_slice_started_us = Time.get_ticks_usec()
	var result: Dictionary = await _retry_new_run(transaction_id, true)
	_new_run_busy = false
	return result

func _retry_new_run(transaction_id: String, responsive: bool = false) -> Dictionary:
	if not _scene_restore_activation.is_empty() and _scene_restore_activation.operation_id == transaction_id \
			and _scene_restore_activation.continuation.kind == "memory_new_run":
		return _drive_scene_restore_activation()
	if not _new_run_transaction_id.is_empty() and transaction_id != _new_run_transaction_id:
		return _fail(&"new_run_recovery_conflict", "")
	var admitted := _admit_new_run_journal_io()
	if not admitted.get("ok", false): return admitted
	var listed: Dictionary = _continuation_journal.list_incomplete()
	if not listed.get("ok", false): return listed
	for pending: Dictionary in listed["value"]:
		if pending["kind"] != "scene_new_run" or pending["transaction_id"] != transaction_id:
			return _fail(&"new_run_recovery_conflict", "another unresolved operation exists")
	var found: Dictionary = _continuation_journal.get_operation(transaction_id)
	if not found.get("ok", false): return found
	if found.get("ok", false) and found["value"]["kind"] != "scene_new_run":
		return _fail(&"invalid_new_run_transaction", "")
	var acquired := _take_new_run_custody(transaction_id)
	if not acquired.get("ok", false): return acquired
	return await _resume_new_run(found["value"], _new_run_gate_token, responsive)

## Bootstrap invokes this before Profile.initialize: no live participant is touched.
func reconcile_new_run_storage() -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	var ready := _new_run_ready(false)
	if not ready.get("ok", false): return ready
	_new_run_busy = true
	var result: Dictionary = _continuation_journal.with_creation_storage_recovery(Callable(self, "_reconcile_new_run_storage"))
	_new_run_busy = false
	return result

func _reconcile_new_run_storage() -> Dictionary:
	var admitted := _admit_new_run_journal_io()
	if not admitted.get("ok", false): return admitted
	var retired: Dictionary = _continuation_journal.retire_scene_restore_operations()
	if not retired.get("ok", false): return retired
	var listed: Dictionary = _continuation_journal.list_incomplete()
	if not listed.get("ok", false): return listed
	var pending: Array[Dictionary] = []
	for operation: Dictionary in listed["value"]:
		if operation["kind"] == "scene_new_run": pending.append(operation)
	if not pending.is_empty() and listed["value"].size() != 1:
		return _fail(&"new_run_recovery_conflict", "conflicting incomplete continuations")
	var settled: Array[String] = []
	for operation: Dictionary in listed["value"]:
		if operation["kind"] != "scene_new_run": continue
		var acquired := _take_new_run_custody(str(operation["transaction_id"]))
		if not acquired.get("ok", false): return acquired
		var result: Dictionary = call("_settle_new_run_pair", operation, false)
		if not result.get("ok", false): return _new_run_failure(result)
		settled.append(str(operation["transaction_id"]))
		var released := _release_new_run_custody()
		if not released.get("ok", false): return released
	return {"ok": true, "code": &"ok", "value": {"settled": settled}}


func _advance_new_run(operation: Dictionary, next_stage: String, allocation: Variant = null) -> Dictionary:
	return _continuation_journal.advance({"transaction_id": operation["transaction_id"],
		"request_fingerprint": operation["request_fingerprint"], "expected_stage": operation["stage"],
		"next_stage": next_stage, "expected_next_participant_index": operation["next_participant_index"],
		"allocation_receipt": allocation, "participant_name": null, "participant_receipt": null, "failure": null})

func _record_new_run_target(operation: Dictionary, target: StringName, revision: String) -> Dictionary:
	if operation["stage"] != CONTINUATION_JOURNAL.STAGE_ALLOCATED:
		return {"ok": true, "value": operation}
	return _continuation_journal.record_new_run_target(str(operation["transaction_id"]),
		str(operation["request_fingerprint"]), target, revision)

func _settle_new_run_pair(operation: Dictionary, responsive: bool = false) -> Dictionary:
	if not _identity_issuer.has_method("verify_issued"):
		return _fail(&"invalid_identity_issuer", "verify_issued is required for recovery")
	var verified: Dictionary = _continuation_journal.reconcile_startup(str(operation["transaction_id"]), _identity_issuer)
	if not verified.get("ok", false): return verified
	var refreshed: Dictionary = _continuation_journal.get_operation(str(operation["transaction_id"]))
	if not refreshed.get("ok", false): return refreshed
	operation = refreshed["value"]
	var materials: Dictionary = operation["new_run_materials"]
	var candidate: Dictionary = materials["allocation_candidate"]
	var prepared: Dictionary = _identity_issuer.prepare_continuation_allocation(candidate["request"])
	if not prepared.get("ok", false): return prepared
	if _canonical_sha256(prepared["value"]) != str(operation["allocation_candidate_fingerprint"]):
		return _fail(&"allocation_candidate_fingerprint_mismatch", "")
	var committed: Dictionary = _identity_issuer.commit_continuation_allocation(candidate)
	if not committed.get("ok", false): return committed
	if _canonical_sha256(committed["value"]) != str(operation["allocation_candidate_fingerprint"]):
		return _fail(&"allocation_candidate_fingerprint_mismatch", "")
	if responsive: await _render_new_run_frame()
	if operation["stage"] == CONTINUATION_JOURNAL.STAGE_INTENT:
		var allocated := _advance_new_run(operation, CONTINUATION_JOURNAL.STAGE_ALLOCATED, committed["value"])
		if not allocated.get("ok", false): return allocated
		operation = allocated["value"]
	if responsive: await _render_new_run_frame()
	var identity := _record_new_run_target(operation, &"identity", str(operation["allocation_candidate_fingerprint"]))
	if not identity.get("ok", false): return identity
	operation = identity["value"]
	if responsive: await _render_new_run_frame()
	var autosave := _persist_new_run_autosave(materials["autosave"], operation)
	if not autosave.get("ok", false): return autosave
	if responsive: await _render_new_run_frame()
	var saved := _record_new_run_target(operation, &"autosave", str(materials["autosave"]["outgoing_hash"]))
	if not saved.get("ok", false): return saved
	operation = saved["value"]
	if responsive: await _render_new_run_frame()
	# A fresh process may already have initialized Profile from the consumed target.
	# Proof is independent of the former live revision; persistence still requires it.
	var profile: Dictionary = _new_run_profile_owner.prove_new_run_consumption(materials["profile"])
	if not profile.get("ok", false):
		profile = _new_run_profile_owner.persist_new_run_consumption(materials["profile"])
		if not profile.get("ok", false): return profile
	profile = _new_run_profile_owner.prove_new_run_consumption(materials["profile"])
	if not profile.get("ok", false): return profile
	autosave = _prove_new_run_autosave(materials["autosave"])
	if not autosave.get("ok", false): return autosave
	if responsive: await _render_new_run_frame()
	return _record_new_run_target(operation, &"profile", str(materials["profile"]["outgoing_hash"]))

func _prove_new_run_autosave(material: Dictionary) -> Dictionary:
	var inspected: Dictionary = _storage.inspect_revision("autosave.json")
	if not inspected.get("ok", false): return inspected
	if inspected["value"].get("revision") != material["outgoing_hash"] or inspected["value"].get("text") != material["outgoing_text"]:
		return _fail(&"new_run_autosave_unproven", "")
	return {"ok": true, "value": {"outgoing_hash": material["outgoing_hash"]}}

func _persist_new_run_autosave(material: Dictionary, operation: Dictionary = {}) -> Dictionary:
	var validator: Callable = _document_text_validator
	if operation.get("kind") == "scene_new_run":
		validator = _scene_new_run_text_validator.bind(operation.new_run_materials)
	var inspected: Dictionary = _storage.inspect_revision("autosave.json")
	if not inspected.get("ok", false) and inspected.get("code") == &"reconcile_required":
		# Never reconcile another operation's pending file family.
		var marker_read: Dictionary = _storage.inspect_revision("autosave.json.txn.json")
		if not marker_read.get("ok", false) or not marker_read["value"].get("exists", false):
			return _fail(&"new_run_autosave_foreign_pending", "")
		var parsed: Dictionary = STRICT_JSON.parse_object(str(marker_read["value"]["text"]))
		if not parsed.get("ok", false): return _fail(&"new_run_autosave_foreign_pending", "")
		var marker: Dictionary = parsed["value"]
		var prior: Variant = null if material["source_revision"] == "absent" else material["source_revision"]
		if marker.get("schema_version") != 2 or marker.get("operation") != "write_revision" \
				or marker.get("relative_path") != "autosave.json" or marker.get("previous_hash") != prior \
				or marker.get("outgoing_hash") != material["outgoing_hash"]:
			return _fail(&"new_run_autosave_foreign_pending", "")
		var reconciled: Dictionary = _storage.reconcile("autosave.json", validator)
		if not reconciled.get("ok", false) and reconciled.get("code") != &"write_not_committed": return reconciled
		inspected = _storage.inspect_revision("autosave.json")
	if not inspected.get("ok", false): return inspected
	if inspected["value"].get("revision") == material["outgoing_hash"] and inspected["value"].get("text") == material["outgoing_text"]:
		return _prove_new_run_autosave(material)
	if inspected["value"].get("revision") != material["source_revision"]:
		return _fail(&"new_run_autosave_source_changed", "")
	var written: Dictionary = _storage.write_atomic_if_revision("autosave.json", material["outgoing_text"],
		validator, material["source_revision"])
	if not written.get("ok", false): return written
	return _prove_new_run_autosave(material)


## Opt-in observations only. Scopes are nested/inclusive; their elapsed times must not be summed.
## Disabled calls read no clock, format no metadata and return the original result object unchanged.
func _save_load_profile_begin(scope: String, action: String = "", locator: Variant = "") -> Dictionary:
	if OS.get_environment("DWM_SAVE_LOAD_PROFILE") != "1":
		return {}
	var now := Time.get_ticks_usec()
	return {"scope": scope, "action": action,
		"locator": str(locator.get("relative_path", "")) if locator is Dictionary else str(locator),
		"context": OS.get_environment("DWM_SAVE_LOAD_CONTEXT"),
		"_started_us": now, "_phase_started_us": now}


func _save_load_profile_phase(profile: Dictionary, phase: String) -> void:
	if profile.is_empty(): return
	var now := Time.get_ticks_usec()
	profile[phase] = int(profile.get(phase, 0)) + now - int(profile["_phase_started_us"])
	profile["_phase_started_us"] = now


func _save_load_profile_finish(profile: Dictionary, result: Dictionary) -> Dictionary:
	if profile.is_empty(): return result
	var now := Time.get_ticks_usec()
	profile["elapsed_us"] = now - int(profile["_started_us"])
	profile["unphased_us"] = now - int(profile["_phase_started_us"])
	profile.erase("_started_us")
	profile.erase("_phase_started_us")
	profile["ok"] = bool(result.get("ok", false))
	profile["code"] = str(result.get("code", ""))
	print("DWM_SAVE_LOAD_PROFILE " + JSON.stringify(profile))
	return result


func _validate_new_run_context(initial_context: Dictionary) -> String:
	var keys: Array = initial_context.keys()
	keys.sort()
	if keys != ["active_app_id", "audio_context", "content_version", "dialogic_checkpoint", "route_id"]:
		return "unexpected initial_context keys: " + str(keys)
	if typeof(initial_context["route_id"]) != TYPE_STRING or initial_context["route_id"] != "main":
		return "route_id must be \"main\""
	if typeof(initial_context["dialogic_checkpoint"]) != TYPE_DICTIONARY or not (initial_context["dialogic_checkpoint"] as Dictionary).is_empty():
		return "dialogic_checkpoint must be {}"
	if initial_context["active_app_id"] != null:
		return "active_app_id must be null"
	if typeof(initial_context["audio_context"]) != TYPE_DICTIONARY or not (initial_context["audio_context"] as Dictionary).is_empty():
		return "audio_context must be {}"
	if typeof(initial_context["content_version"]) != TYPE_INT or int(initial_context["content_version"]) < 1:
		return "content_version must be a positive integer"
	return ""

func _release_transaction(owner: StringName, gate_token: String, holds_save_lock: bool) -> void:
	if _mutation_gate != null and gate_token != "":
		_mutation_gate.release(owner, gate_token)
	if holds_save_lock:
		release_save_lock(&"restore")

func _rollback_transaction(owner: StringName, applied: Array[String], backups: Dictionary, gate_token: String, holds_save_lock: bool, original_failure: Dictionary, journal_backup: Variant = null) -> Dictionary:
	var attempts: Array = []
	var all_recovered := true
	# The checkpoint commits after participant apply, so compensate it first.
	# Only post-commit failures supply this backup; earlier refusals leave it alone.
	if typeof(journal_backup) == TYPE_DICTIONARY:
		var journal_rolled: Dictionary = _journal.restore_state(journal_backup)
		attempts.append({"owner_id": "checkpoint_journal", "operation": "restore_state", "result": journal_rolled})
		if not journal_rolled.get("ok", false):
			all_recovered = false
	for index: int in range(applied.size() - 1, -1, -1):
		var key: String = applied[index]
		var rolled: Dictionary = _restore_participants[key].rollback_silent(backups[key])
		attempts.append({"owner_id": key, "operation": "rollback_silent", "result": rolled})
		if not rolled.get("ok", false):
			all_recovered = false
	if all_recovered:
		_release_transaction(owner, gate_token, holds_save_lock)
		return original_failure
	# Compensation failure must not erase the refusal that started recovery.
	attempts.append({"owner_id": String(owner), "operation": "original_failure", "result": original_failure})
	return _fatal_transaction_recovery(String(owner), attempts)

func _fatal_transaction_recovery(source: String, raw_diagnostics: Array) -> Dictionary:
	if _mutation_gate == null:
		return {"ok": false, "code": &"restore_rollback_failed", "message": "rollback failed with no gate"}
	# Owner failures may omit optional message/details. Complete only those
	# absent fields at this boundary; malformed supplied values stay visible to
	# the strict projector. Never mutate the owner's retained result.
	var diagnostics: Array = raw_diagnostics.duplicate(true)
	for diagnostic: Dictionary in diagnostics:
		var result: Variant = diagnostic.get("result")
		if result is Dictionary and typeof(result.get("ok")) == TYPE_BOOL and not result.ok:
			if not result.has("message"): result["message"] = ""
			if not result.has("details"): result["details"] = {}
	var already_retained := false
	for diagnostic: Dictionary in diagnostics:
		if str((diagnostic.get("result", {}) as Dictionary).get("code", "")) == "APPLICATION_FATAL":
			already_retained = true
	if not already_retained and not _mutation_gate.is_fatal_latched():
		var projected: Dictionary = PROJECTOR.project_failure(
			source, "rollback", "fatal_rollback_failed", {"phase": source + "_recovery"}, diagnostics)
		var candidate: Dictionary = PROJECTOR.get_invariant_fallback()
		if projected.get("ok", false) and PROJECTOR.validate_failure(projected["value"]["failure"]).get("ok", false):
			candidate = projected["value"]["failure"]
		_mutation_gate.latch_fatal(candidate)
	return _mutation_gate.guard_external(StringName(source + "_recovery"))

func delete_slot(slot_id: int) -> Dictionary:
	return _delete(_resolve_locator(&"slot", slot_id))

func delete_quick_save() -> Dictionary:
	return _delete(_resolve_locator(&"quick", -1))

func delete_autosave() -> Dictionary:
	return _delete(_resolve_locator(&"autosave", -1))

func save_exists(kind: StringName, slot_id: int = -1) -> bool:
	var locator := _resolve_locator(kind, slot_id)
	if locator.is_empty() or _storage == null:
		return false
	return _storage.exists(str(locator["relative_path"]))

func get_save_metadata(kind: StringName, slot_id: int = -1) -> Dictionary:
	var locator := _resolve_locator(kind, slot_id)
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "%s/%d" % [kind, slot_id])
	if _storage == null:
		return _fail(&"not_initialized", "")
	var relative_path := str(locator["relative_path"])
	if not _storage.exists(relative_path):
		return {"ok": true, "code": &"ok", "value": {
			"exists": false, "kind": str(locator["kind"]), "slot_id": locator["slot_id"],
			"save_reason": null, "run_id": null, "day": null, "state": null, "checkpoint_id": null,
		}}
	var read: Dictionary = _storage.read_text(relative_path)
	if not read.get("ok", false):
		return read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(read["value"]))
	if not parsed.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)
	var migrated: Dictionary = SAVE_MIGRATIONS.migrate_document(parsed["value"],
		{"kind": str(locator["kind"]), "slot_id": locator["slot_id"]})
	if not migrated.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)
	var document: Dictionary = migrated["value"]["document"]
	var snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	return {"ok": true, "code": &"ok", "value": {
		"exists": true,
		"kind": str(document["kind"]),
		"slot_id": document["slot_id"],
		"save_reason": str(document["save_reason"]) if document.has("save_reason") else null,
		"run_id": str(snapshot["run_id"]),
		"day": null,
		"state": str(snapshot["lifecycle"]["state"]),
		"checkpoint_id": str(snapshot["checkpoint_id"]),
	}}

func get_all_save_metadata() -> Array[Dictionary]:
	var records: Array[Dictionary] = []
	for slot_id: int in range(MIN_SLOT, MAX_SLOT + 1):
		records.append(get_save_metadata(&"slot", slot_id))
	records.append(get_save_metadata(&"quick", -1))
	records.append(get_save_metadata(&"autosave", -1))
	return records

## Read-only slot information. Listing does not prepare or certify restoration.
func inspect_backup(locator_id: String) -> Dictionary:
	return _inspect_backup(locator_id)

func get_backup_save_capability() -> Dictionary:
	var allowed := _backup_guard()
	if not allowed.get("ok", false):
		return {"enabled": false, "reason": str(allowed.get("code", "unavailable"))}
	if not get_latest_stable_checkpoint().get("ok", false):
		return {"enabled": false, "reason": "no_stable_checkpoint"}
	if _backup_capture_configured:
		if not _backup_capture_provider.is_valid():
			return {"enabled": false, "reason": "backup_capture_unavailable"}
		if not _backup_capture_available.is_null():
			var enabled: bool = _backup_capture_available.is_valid() and _backup_capture_available.call()
			return {"enabled": enabled, "reason": "" if enabled else "backup_capture_unavailable"}
		var captured := _capture_backup_inputs()
		if not captured.get("ok", false):
			return {"enabled": false, "reason": str(captured.get("code", "backup_capture_unavailable"))}
	return {"enabled": true, "reason": ""}

## Quick commands share Backup tokens and the same current-build save contract.
## Conditions are opaque, detached evidence; they are never display copy or save data.
func get_backup_quick_capability(action: String) -> Dictionary:
	if action not in ["save", "load"]:
		return {"ok": false, "code": &"invalid_backup_action", "status_key": "unavailable", "condition": {}}
	var condition := _quick_condition(action)
	var enabled := false
	var status := _quick_guard_status(action)
	if status == "":
		var stable := get_latest_stable_checkpoint()
		var inspected := _inspect_backup("quick")
		if stable.get("ok", false) and inspected.get("ok", false):
			var record: Dictionary = inspected["value"]
			if action == "load":
				enabled = record.get("loadable", false)
				if not enabled:
					status = _quick_load_record_status(record)
			else:
				enabled = get_backup_save_capability().get("enabled", false) and _quick_save_record_allowed(record)
		if not is_quick_condition_current(condition):
			enabled = false
			status = "unavailable"
		elif not enabled and status == "":
			status = "unavailable"
	return {"ok": true, "value": {"enabled": enabled, "status_key": status, "condition": condition}}

func prepare_quick_backup_action(action: String) -> Dictionary:
	var capability := get_backup_quick_capability(action)
	if not capability.get("ok", false):
		return capability
	var value: Dictionary = capability["value"]
	if not value["enabled"]:
		return _quick_failure(action, value["status_key"])
	var condition: Dictionary = value["condition"]
	var prepared := prepare_backup_action(action, "quick")
	if not prepared.get("ok", false):
		return _quick_failure(action)
	var token: String = prepared["value"]["token"]
	if not is_quick_condition_current(condition) or (action == "save" and not _quick_save_record_allowed(prepared["value"]["record"])):
		cancel_backup_action(token)
		return _quick_failure(action)
	_backup_actions[token]["quick_condition"] = condition.duplicate(true)
	prepared["value"]["condition"] = condition.duplicate(true)
	return prepared

func is_quick_condition_current(condition: Dictionary) -> bool:
	if condition.size() != 2 or typeof(condition.get("action")) != TYPE_STRING or condition.get("action") not in ["save", "load"] \
			or typeof(condition.get("signature")) != TYPE_STRING or condition["signature"].is_empty():
		return false
	return condition == _quick_condition(condition["action"])

func _quick_condition(action: String) -> Dictionary:
	var stable := get_latest_stable_checkpoint()
	var captured := _capture_backup_inputs() if _backup_capture_configured else {"ok": false, "code": &"not_configured"}
	var target: Dictionary = {"ok": false, "code": &"not_initialized"}
	if _storage != null:
		target = _storage.inspect_revision(str(_backup_locator("quick")["relative_path"]))
	var evidence := {
		"owner": str(get_instance_id()), "action": action,
		"stable": _canonical_sha256(stable["value"]["bundle"]) if stable.get("ok", false) else "",
		"capture": _canonical_sha256(captured["value"]) if captured.get("ok", false) else str(captured.get("code", "unavailable")),
		"target": target["value"]["revision"] if target.get("ok", false) else str(target.get("code", "unavailable")),
		"lock": str(_lock_owner),
		"gate_owner": str(_mutation_gate.get_active_owner()) if _mutation_gate != null else "",
		"fatal": _mutation_gate.is_fatal_latched() if _mutation_gate != null else false,
	}
	return {"action": action, "signature": _canonical_sha256(evidence)}

func _quick_guard_status(action: String) -> String:
	if _storage == null or (_mutation_gate != null and _mutation_gate.is_fatal_latched()):
		return "unavailable"
	if is_save_locked() or (_mutation_gate != null and _mutation_gate.is_active()):
		return "please_wait" if action == "load" else "unavailable"
	return "" if _backup_guard().get("ok", false) else "unavailable"

func _quick_failure(action: String, status: String = "") -> Dictionary:
	if status == "":
		status = _quick_guard_status(action)
	return {"ok": false, "code": &"backup_action_unavailable",
		"status_key": "unavailable" if status == "" else status, "condition": _quick_condition(action)}

static func _quick_save_record_allowed(record: Dictionary) -> bool:
	return record.get("state") in ["empty", "occupied", "unavailable"]

static func _quick_load_record_status(record: Dictionary) -> String:
	if record.get("state") == "empty":
		return "no_quick_save"
	var reason: String = str(record.get("reason", ""))
	return reason if reason in ["older_version", "newer_version", "unreadable", "no_compatible_checkpoint", "restore_unavailable"] else "unavailable"

func _on_backup_gate_capability_changed(_capability: Dictionary) -> void:
	save_capability_changed.emit(get_backup_save_capability())

func _inspect_backup(locator_id: String) -> Dictionary:
	var profile := _save_load_profile_begin("backup_inspection", "", locator_id)
	return _save_load_profile_finish(profile, _inspect_backup_profiled(locator_id, profile))


## Player admission only. Pending transactions retain their own internal readers.
static func _player_save_format_reason(document: Dictionary) -> String:
	var version: Variant = document.get("schema_version")
	if typeof(version) == TYPE_FLOAT and is_finite(version) and version == floorf(version):
		version = int(version)
	if typeof(version) != TYPE_INT:
		return "unreadable"
	if version < SAVE_DOCUMENT_SCHEMA.SCENE_DOCUMENT_VERSION:
		return "older_version"
	if version > SAVE_DOCUMENT_SCHEMA.SCENE_DOCUMENT_VERSION:
		return "newer_version"
	return ""


func _inspect_backup_profiled(locator_id: String, profile: Dictionary) -> Dictionary:
	var locator := _backup_locator(locator_id)
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	var inspected: Dictionary = _storage.inspect_revision(str(locator["relative_path"]))
	_save_load_profile_phase(profile, "revision_read_us")
	if not inspected.get("ok", false):
		return inspected
	var evidence: Dictionary = inspected["value"]
	var record := {"locator": locator_id, "revision": evidence["revision"],
		"state": "empty" if not evidence["exists"] else "unavailable", "family": null, "day": null,
		"saved_time": null, "fallback": false, "load_family": null, "load_day": null, "load_saved_time": null,
		"reason": "", "loadable": false, "operation_allowed": _backup_guard().get("ok", false)}
	if not evidence["exists"]:
		return {"ok": true, "value": record}
	if typeof(evidence.get("text")) != TYPE_STRING:
		record["reason"] = "unreadable"
		return {"ok": true, "value": record}
	var parsed := _parse_document_text(evidence["text"])
	_save_load_profile_phase(profile, "parse_us")
	if not parsed.get("ok", false):
		record["reason"] = "unreadable"
		return {"ok": true, "value": record}
	# Current-build saves are the supported input. Read only presentation fields;
	# Load owns participant preparation after the player chooses a slot.
	var document: Dictionary = parsed["value"]
	record["reason"] = _player_save_format_reason(document)
	if not record["reason"].is_empty():
		return {"ok": true, "value": record}
	var bundle: Variant = document.get("current_snapshot")
	if typeof(bundle) != TYPE_DICTIONARY or typeof(bundle.get("snapshot")) != TYPE_DICTIONARY:
		record["reason"] = "unreadable"
		return {"ok": true, "value": record}
	var snapshot: Dictionary = bundle["snapshot"]
	record["state"] = "occupied"
	record["family"] = "scene"
	var display_time := SAVE_DOCUMENT_SCHEMA.normalize_optional_saved_time(document.get("saved_time"))
	record["saved_time"] = display_time.get("hhmm")
	record["loadable"] = true
	record["load_family"] = record["family"]
	record["load_day"] = record["day"]
	record["load_saved_time"] = record["saved_time"]
	return {"ok": true, "value": record}

## Detached candidates remain owner-private; tokens convey consent to exactly one candidate.
func prepare_backup_action(action: String, locator_id: String) -> Dictionary:
	var profile := _save_load_profile_begin("backup_prepare", action, locator_id)
	return _save_load_profile_finish(profile, _prepare_backup_action_profiled(action, locator_id, profile))


func _prepare_backup_action_profiled(action: String, locator_id: String, profile: Dictionary) -> Dictionary:
	if action not in ["save", "load", "delete"]:
		return _fail(&"invalid_backup_action", "")
	var guard := _backup_guard()
	if not guard.get("ok", false):
		return guard
	var inspected := _inspect_backup(locator_id)
	_save_load_profile_phase(profile, "inspection_us")
	if not inspected.get("ok", false):
		return inspected
	var record: Dictionary = inspected["value"]
	var locator := _backup_locator(locator_id)
	var candidate := {"action": action, "locator": locator, "revision": record["revision"]}
	if action == "save":
		if locator_id == "autosave":
			return _fail(&"automatic_save_only", "")
		var stable := get_latest_stable_checkpoint()
		if not stable.get("ok", false):
			return _fail(&"no_stable_checkpoint", "")
		var bundle: Dictionary = stable["value"]["bundle"]
		var earlier: Array
		if _backup_capture_configured:
			var fresh := _prepare_backup_capture()
			if not fresh.get("ok", false):
				return fresh
			candidate.merge(fresh["value"])
			bundle = candidate["journal_candidate"]["current"]
			earlier = candidate["journal_candidate"]["earlier"]
		else:
			earlier = _journal.get_bundles_for_disk()
		_save_load_profile_phase(profile, "capture_us")
		var built := SAVE_DOCUMENT_SCHEMA.build(StringName(locator["kind"]), locator["slot_id"],
			&"quick" if locator_id == "quick" else &"manual", bundle, earlier, _capture_saved_time())
		_save_load_profile_phase(profile, "document_build_us")
		if not built.get("ok", false):
			return built
		candidate["document"] = built["value"]
		if not candidate.has("journal_candidate"):
			candidate["stable_hash"] = _canonical_sha256(stable["value"]["bundle"])
		_save_load_profile_phase(profile, "stable_hash_us")
	elif action == "load":
		if not record["loadable"]:
			if record["reason"] in ["older_version", "newer_version"]:
				return _fail(&"unsupported_save_format", "Only current Save9 files can be loaded")
			return _fail(&"backup_load_unavailable", "")
		var prepared := _prepare_restore(locator, str(record["revision"]))
		_save_load_profile_phase(profile, "restore_prepare_us")
		if not prepared.get("ok", false):
			return prepared
		candidate["prepared_restore"] = prepared["value"]["prepared"]
	elif record["state"] == "empty":
		return _fail(&"save_absent", "")
	_backup_action_sequence += 1
	var token := "backup-%d" % _backup_action_sequence
	_backup_actions[token] = candidate.duplicate(true)
	_save_load_profile_phase(profile, "candidate_copy_us")
	return {"ok": true, "value": {"token": token, "record": record}}

func cancel_backup_action(token: String) -> void:
	_release_backup_preparation(_backup_actions.get(token, {}))
	_backup_actions.erase(token)

func _release_backup_preparation(candidate: Dictionary) -> void:
	var token: String = candidate.get("prepared_restore", {}).get("scene_preparation_token", "")
	# Load preparation belongs only to this process and this selection.
	if _scene_restore_preparations.has(token):
		_scene_restore_preparations.erase(token)

func commit_backup_action(token: String) -> Dictionary:
	var candidate: Dictionary = _backup_actions.get(token, {})
	var profile := _save_load_profile_begin("backup_commit", "", "")
	var result := _commit_backup_action_profiled(token, profile)
	_release_backup_preparation(candidate)
	return _save_load_profile_finish(profile, result)


func _commit_backup_action_profiled(token: String, profile: Dictionary) -> Dictionary:
	if not _backup_actions.has(token):
		return _fail(&"stale_backup_action", "")
	var candidate: Dictionary = _backup_actions[token]
	# Every result consumes consent; retries require a fresh prepare and confirmation.
	_backup_actions.erase(token)
	var guard := _backup_guard()
	if not guard.get("ok", false):
		return guard
	if candidate.has("quick_condition") and not is_quick_condition_current(candidate["quick_condition"]):
		return _fail(&"stale_backup_source", "")
	var locator: Dictionary = candidate["locator"]
	var path := str(locator["relative_path"])
	if not profile.is_empty():
		profile["action"] = str(candidate.get("action", ""))
		profile["locator"] = path
	var current: Dictionary = _storage.inspect_revision(path)
	_save_load_profile_phase(profile, "revision_read_us")
	if not current.get("ok", false):
		return current
	if current["value"]["revision"] != candidate["revision"]:
		return _fail(&"stale_backup_target", "")
	match str(candidate["action"]):
		"load":
			var restored := commit_prepared_restore(candidate["prepared_restore"])
			_save_load_profile_phase(profile, "restore_commit_us")
			return restored
		"delete":
			var removed: Dictionary = _storage.remove_if_revision(path, candidate["revision"])
			_save_load_profile_phase(profile, "remove_us")
			if removed.get("ok", false):
				slot_metadata_changed.emit()
				_save_load_profile_phase(profile, "metadata_refresh_us")
			return removed
		"save":
			if candidate.has("journal_candidate"):
				var captured := _capture_backup_inputs()
				if not captured.get("ok", false):
					return captured
				if _canonical_sha256(captured["value"]) != candidate["capture_hash"] or _backup_journal_hash() != candidate["journal_hash"]:
					return _fail(&"stale_backup_source", "")
			else:
				var stable := get_latest_stable_checkpoint()
				if not stable.get("ok", false) or _canonical_sha256(stable["value"]["bundle"]) != candidate["stable_hash"]:
					return _fail(&"stale_backup_source", "")
			_save_load_profile_phase(profile, "source_recheck_us")
			var canonical := CANONICAL_JSON.stringify(candidate["document"])
			_save_load_profile_phase(profile, "serialize_us")
			if not canonical.get("ok", false):
				return canonical
			var bytes := str(canonical["value"]) + "\n"
			var validated_texts := {}
			var validator := _write_document_text_validator.bind(validated_texts)
			var written: Dictionary = _storage.write_atomic_if_revision(path, bytes, validator, candidate["revision"])
			_save_load_profile_phase(profile, "write_atomic_us")
			if not written.get("ok", false):
				save_failed.emit(written)
				return written
			var read: Dictionary = _storage.read_text(path)
			_save_load_profile_phase(profile, "reread_us")
			if not read.get("ok", false) or str(read["value"]) != bytes:
				return _fail(&"reread_mismatch", "")
			if candidate.has("journal_candidate"):
				if _backup_journal_hash() != candidate["journal_hash"]:
					return _fail(&"backup_journal_changed_after_write", "Durable save remains available; journal was not overwritten")
				var advanced: Dictionary = _journal.commit_prepared(candidate["journal_candidate"])
				if not advanced.get("ok", false):
					return _fail(&"backup_journal_commit_failed", "Durable save remains available; checkpoint publication failed")
			_save_load_profile_phase(profile, "journal_commit_us")
			var result := {"ok": true, "value": {"written": true}}
			save_completed.emit(result)
			_save_load_profile_phase(profile, "save_completed_signal_us")
			slot_metadata_changed.emit()
			_save_load_profile_phase(profile, "metadata_refresh_us")
			return result
	return _fail(&"invalid_backup_action", "")

func _capture_backup_inputs() -> Dictionary:
	if not _backup_capture_provider.is_valid():
		return _fail(&"backup_capture_unavailable", "Configured source is no longer available")
	var raw: Variant = _backup_capture_provider.call()
	if not raw is Dictionary:
		return _fail(&"invalid_backup_capture", "Capture provider must return a result")
	if not raw.get("ok", false):
		return raw.duplicate(true)
	if not raw.get("value") is Dictionary:
		return _fail(&"invalid_backup_capture", "Capture inputs are required")
	var inputs: Dictionary = raw["value"].duplicate(true)
	var shape_error := _validate_checkpoint_inputs(inputs)
	if shape_error != "":
		return _fail(&"invalid_backup_capture", shape_error)
	if not inputs["dialogic_checkpoint"] is Dictionary or not inputs["audio_context"] is Dictionary \
			or typeof(inputs["route_id"]) not in [TYPE_STRING, TYPE_STRING_NAME] \
			or typeof(inputs["active_app_id"]) not in [TYPE_NIL, TYPE_STRING, TYPE_STRING_NAME] \
			or not inputs["content_version"] is int:
		return _fail(&"invalid_backup_capture", "Capture context types are invalid")
	inputs["route_id"] = str(inputs["route_id"])
	if inputs["active_app_id"] != null:
		inputs["active_app_id"] = str(inputs["active_app_id"])
	var desktop: bool = inputs["route_id"] == "main" and inputs["active_app_id"] == "backup"
	if inputs["route_id"] == "main" and not desktop and _paused_desktop_admission.is_valid():
		# The retained Pause owner rechecks this exact suspended source. Never relabel its app.
		var paused_admission: Variant = _paused_desktop_admission.call(inputs.duplicate(true))
		desktop = typeof(paused_admission) == TYPE_BOOL and paused_admission
	var gameplay: Variant = inputs["snapshot_input"].get("gameplay")
	var route_context: Variant = gameplay.get("route_context") if gameplay is Dictionary else null
	var dating_record: Variant = route_context.get("active_dating_challenge") if route_context is Dictionary else null
	var dating: bool = inputs["route_id"] == "dating" and dating_record is Dictionary \
		and not dating_record.is_empty() and dating_record.get("phase") in ["pre_challenge", "preparing", "challenge", "cleared_awaiting_terminal_choice", "post_challenge"]
	var narrative: Dictionary = inputs["dialogic_checkpoint"]
	var hospital: bool = inputs["route_id"] == "hospital" and narrative.get("reading_session") is Dictionary \
		and narrative.reading_session.get("schema_version") == 3 and narrative.reading_session.get("family") == "hospital" \
		and narrative.reading_session.get("boundary") == "line"
	var ending: bool = inputs["route_id"] == "ending" and narrative.get("reading_session") is Dictionary \
		and narrative.reading_session.get("schema_version") == 3 and narrative.reading_session.get("family") == "ending" \
		and narrative.reading_session.get("boundary") == "line"
	var scene: bool = inputs["route_id"] == "scene" and inputs["active_app_id"] == null \
		and narrative.get("reading_session") is Dictionary \
		and narrative.reading_session.get("schema_version") == 5 \
		and narrative.reading_session.get("boundary") in ["line", "control"]
	if not (desktop or dating or hospital or ending or scene) or (not narrative.is_empty() and (not (dating or hospital or ending or scene) or not narrative.has("reading_session"))) \
			or inputs["snapshot_input"]["lifecycle"].get("state") != ("ENDING" if ending else "PLAYING"):
		return _fail(&"backup_capture_unavailable", "A qualified desktop or admitted reading capture is required")
	if not narrative.is_empty() and not inputs.snapshot_input.has("scene"):
		# Scene capture already comes from the live reading owner. Preparation
		# builds its complete Run9 candidate once; capability and freshness reads
		# do not need to construct another snapshot or restore temporary ledgers.
		# Keep the historical non-scene reading admission at this boundary.
		var snapshot: Dictionary = inputs["snapshot_input"].duplicate(true)
		snapshot["route_id"] = inputs["route_id"]
		snapshot["narrative_checkpoint"] = narrative
		var reading: Dictionary = preload("res://scripts/narrative/FrozenRunContext.gd").validate_reading_checkpoint(narrative, snapshot)
		if not reading.get("ok", false): return reading
	return {"ok": true, "value": inputs}


func _compose_live_checkpoint_input(snapshot_input: Dictionary) -> Dictionary:
	return preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")._normalize_json_string_types(snapshot_input)


func _backup_journal_hash() -> String:
	return _canonical_sha256(_journal.capture_state()["value"]["backup"])

func _prepare_backup_capture() -> Dictionary:
	var journal_hash := _backup_journal_hash()
	var captured := _capture_backup_inputs()
	if not captured.get("ok", false):
		return captured
	var inputs: Dictionary = captured["value"]
	var run_id := str(inputs["snapshot_input"]["lifecycle"].get("run_id", ""))
	var sequence: Dictionary = _journal.peek_next_sequence(run_id)
	if not sequence.get("ok", false):
		return sequence
	var built: Dictionary = RUN_SNAPSHOT_SCHEMA.build(_compose_live_checkpoint_input(inputs["snapshot_input"]), inputs["dialogic_checkpoint"],
		inputs["route_id"], inputs["active_app_id"], inputs["audio_context"], inputs["content_version"], sequence["value"]["checkpoint_sequence"])
	if not built.get("ok", false):
		return built
	var prepared: Dictionary = _journal.prepare_record(built["value"]["snapshot"], &"manual_save", built["value"]["snapshot"])
	if not prepared.get("ok", false):
		return prepared
	if _backup_journal_hash() != journal_hash:
		return _fail(&"stale_backup_source", "Journal changed during capture")
	return {"ok": true, "value": {"journal_candidate": prepared["value"]["candidate"],
		"capture_hash": _canonical_sha256(inputs), "journal_hash": journal_hash}}

func _backup_guard() -> Dictionary:
	if _storage == null:
		return _fail(&"not_initialized", "")
	if is_save_locked():
		return _fail(&"save_locked", "")
	if _mutation_gate != null:
		return _mutation_gate.guard_external(&"backup")
	return {"ok": true}

func _backup_locator(locator_id: String) -> Dictionary:
	if locator_id not in ["autosave", "quick", "slot:1", "slot:2", "slot:3", "slot:4", "slot:5", "slot:6", "slot:7"]:
		return {}
	return _resolve_locator_from_slot_id(locator_id)

func _capture_saved_time() -> Dictionary:
	var instant := int(Time.get_unix_time_from_system())
	var offset := int(Time.get_time_zone_from_system()["bias"])
	var clock := Time.get_datetime_dict_from_unix_time(instant + offset * 60)
	return {"unix_seconds": instant, "utc_offset_minutes": offset,
		"hhmm": "%02d:%02d" % [clock["hour"], clock["minute"]]}

func acquire_save_lock(owner_id: StringName) -> Dictionary:
	if owner_id not in _LOCK_OWNERS:
		return _fail(&"invalid_lock_owner", String(owner_id))
	if _lock_owner != &"" and _lock_owner != owner_id:
		return _fail(&"save_lock_held", String(_lock_owner))
	var was_locked := _lock_owner == owner_id
	_lock_owner = owner_id
	if not was_locked:
		save_capability_changed.emit(get_save_capability())
	return {"ok": true, "code": &"ok", "value": {"owner_id": owner_id, "already_locked": was_locked}}

func release_save_lock(owner_id: StringName) -> Dictionary:
	if _lock_owner == &"" or owner_id != _lock_owner:
		return _fail(&"save_lock_mismatch", String(owner_id))
	_lock_owner = &""
	save_capability_changed.emit(get_save_capability())
	if _pending_deferred_save:
		_pending_deferred_save = false
		autosave_latest()
	return {"ok": true, "code": &"ok", "value": {"owner_id": owner_id}}

func is_save_locked() -> bool:
	return _lock_owner != &""

func get_save_capability() -> Dictionary:
	if _mutation_gate != null and not _mutation_gate.guard_external(&"save_write").get("ok", false):
		return {"enabled": false, "silent": true, "deferred": false}
	match _lock_owner:
		&"minesweeper_board":
			return {"enabled": false, "silent": true, "deferred": false}
		&"scene_transition":
			return {"enabled": false, "silent": true, "deferred": true}
		&"restore":
			return {"enabled": false, "silent": true, "deferred": false}
	return {"enabled": true, "silent": false, "deferred": false}


# ---- Deprecated wrappers (one issue only; delegate to the new facade) ----

func save_slot(slot_id: int) -> Dictionary:
	return save_latest_to_slot(slot_id)

func load_slot(slot_id: int) -> Dictionary:
	var prepared := prepare_restore_slot(slot_id)
	if not prepared.get("ok", false):
		return prepared
	return commit_prepared_restore(prepared["value"]["prepared"])

func quick_save() -> Dictionary:
	return quick_save_latest()

func quick_load() -> Dictionary:
	var prepared := prepare_restore_quick()
	if not prepared.get("ok", false):
		return prepared
	return commit_prepared_restore(prepared["value"]["prepared"])

func autosave() -> Dictionary:
	return autosave_latest()

func load_autosave() -> Dictionary:
	var prepared := prepare_restore_autosave()
	if not prepared.get("ok", false):
		return prepared
	return commit_prepared_restore(prepared["value"]["prepared"])

func has_slot(slot_id: int) -> bool:
	return save_exists(&"slot", slot_id)

func get_slot_metadata(slot_id: int) -> Dictionary:
	return get_save_metadata(&"slot", slot_id)

func get_all_slot_metadata() -> Array:
	return get_all_save_metadata()

# ---- Internals ----

func _resolve_locator(kind: StringName, public_slot_id: int) -> Dictionary:
	match kind:
		&"slot":
			if public_slot_id < MIN_SLOT or public_slot_id > MAX_SLOT:
				return {}
			return {"kind": "slot", "slot_id": public_slot_id,
				"relative_path": "slot_%d.json" % public_slot_id}
		&"quick":
			if public_slot_id != -1:
				return {}
			return {"kind": "quick", "slot_id": null, "relative_path": "quicksave.json"}
		&"autosave":
			if public_slot_id != -1:
				return {}
			return {"kind": "autosave", "slot_id": null, "relative_path": "autosave.json"}
	return {}

func _write_latest(locator: Dictionary, save_reason: String, session_exit: bool = false) -> Dictionary:
	if session_exit and (_mutation_gate == null or not _mutation_gate.is_internal_owner_active(&"session_abandonment")):
		return _fail(&"session_abandonment_required", "")
	if _mutation_gate != null and not session_exit:
		var admitted: Dictionary = _mutation_gate.guard_external(&"save_write")
		if not admitted.get("ok", false): return admitted
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	match _lock_owner:
		&"minesweeper_board", &"restore":
			return {"ok": false, "code": &"save_locked", "message": "",
				"details": {"silent": true, "deferred": false}}
		&"scene_transition":
			_pending_deferred_save = true
			return {"ok": false, "code": &"save_locked", "message": "",
				"details": {"silent": true, "deferred": true}}
	var bundle: Dictionary = _journal.get_current_bundle()
	if not bundle.get("ok", false):
		return _fail(&"no_stable_checkpoint", "")
	var built: Dictionary = SAVE_DOCUMENT_SCHEMA.build(
		StringName(str(locator["kind"])), locator["slot_id"], StringName(save_reason),
		bundle["value"]["bundle"], _journal.get_bundles_for_disk(), _capture_saved_time())
	if not built.get("ok", false):
		save_failed.emit(built)
		return built
	var relative_path := str(locator["relative_path"])
	# The previous target is replaceable data, not a restoration prerequisite.
	# Bind this write to its exact bytes so a competing write is still refused.
	var inspected: Dictionary = _storage.inspect_revision(relative_path)
	if not inspected.get("ok", false):
		save_failed.emit(inspected)
		return inspected
	var canonical: Dictionary = CANONICAL_JSON.stringify(built["value"])
	if not canonical.get("ok", false):
		return _fail(&"canonical_serialization_failed", "")
	var written: Dictionary = _storage.write_atomic_if_revision(
		relative_path, str(canonical["value"]) + "\n", _document_text_validator,
		str(inspected["value"]["revision"]))
	if not written.get("ok", false):
		save_failed.emit(written)
		return written
	var re_read: Dictionary = _storage.read_text(relative_path)
	if not re_read.get("ok", false):
		return re_read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(re_read["value"]))
	if not parsed.get("ok", false):
		return _fail(&"reread_mismatch", relative_path)
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return _fail(&"reread_mismatch", relative_path)
	var document: Dictionary = validated["value"]["candidate"]
	if str(document["kind"]) != str(locator["kind"]) or document["slot_id"] != locator["slot_id"]:
		return _fail(&"reread_mismatch", "locator or reason drift")
	if _canonical_sha256(document) != _canonical_sha256(built["value"]):
		return _fail(&"reread_mismatch", "saved candidate drift")
	var result := {"ok": true, "code": &"ok", "value": {
		"kind": str(locator["kind"]),
		"slot_id": locator["slot_id"],
		"save_reason": save_reason,
		"checkpoint_id": str(document["current_snapshot"]["snapshot"]["checkpoint_id"]),
		"written": true,
	}}
	save_completed.emit(result)
	slot_metadata_changed.emit()
	return result

func _content_result(result: Dictionary) -> Dictionary:
	if result.get("code") == &"reading_content_error" and is_inside_tree():
		var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
		if bootstrap != null: bootstrap.show_content_error(result)
	return result

func _prepare_restore(locator: Dictionary, expected_revision: String = "") -> Dictionary:
	return _content_result(_prepare_restore_content(locator, expected_revision))

func _prepare_restore_content(locator: Dictionary, expected_revision: String) -> Dictionary:
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	if _restore_participants.is_empty():
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "configure_scene_restore_participants first")
	var relative_path := str(locator["relative_path"])
	if not _storage.exists(relative_path):
		return _fail(&"save_absent", relative_path)
	var read: Dictionary = _storage.inspect_revision(relative_path)
	if not read.get("ok", false):
		return read
	# The selected bytes must match the metadata on which confirmation is based.
	# This also binds preparation when another writer changes the slot between reads.
	if not expected_revision.is_empty() and str(read["value"]["revision"]) != expected_revision:
		return _fail(&"stale_backup_target", "")
	var parsed: Dictionary = STRICT_JSON.parse_object(str(read["value"]["text"]))
	if not parsed.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)

	# Current game-produced saves need content-position resolution, not admission.
	var migrated: Dictionary = SAVE_MIGRATIONS.load_current_document(parsed["value"])
	if not migrated.get("ok", false):
		return migrated
	var document: Dictionary = migrated["value"]["document"]
	return _prepare_restore_document(locator, document, migrated["value"])

## Prepare the selected Load for the existing restore transaction.
func _prepare_restore_document(locator: Dictionary, document: Dictionary, migration_output: Dictionary) -> Dictionary:
	var profile := _save_load_profile_begin("restore_prepare", "", locator)
	return _save_load_profile_finish(profile, _prepare_restore_document_profiled(document, profile))


func _prepare_restore_document_profiled(document: Dictionary, profile: Dictionary) -> Dictionary:
	if _restore_participants.is_empty():
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "")

	# Load the selected saved state only. An older checkpoint is never substituted.
	var prepared := _prepare_bundle_with_all_participants(document["current_snapshot"])
	_save_load_profile_phase(profile, "participant_prepare_us")
	if not prepared.get("ok", false):
		return prepared
	return {"ok": true, "code": &"ok", "value": {"prepared": prepared["value"]}}

func _prepare_bundle_with_all_participants(bundle: Dictionary) -> Dictionary:
	var snapshot: Dictionary = bundle.snapshot
	var plans := {}
	var run_prep: Dictionary = _restore_participants.run._prepare_admitted_snapshot(snapshot)
	if not run_prep.ok: return run_prep
	plans.run = run_prep.value.run_plan
	var consequence_prep: Dictionary = _restore_participants.desktop_consequence.prepare(
		{"state": snapshot.desktop.consequence})
	if not consequence_prep.ok: return consequence_prep
	plans.desktop_consequence = consequence_prep.value.consequence_plan
	var board_prep: Dictionary = _restore_participants.desktop_board.prepare(
		{"state": snapshot.desktop.board, "schema_version": snapshot.schema_version})
	if not board_prep.ok: return board_prep
	plans.desktop_board = board_prep.value.board_plan
	plans.profile = {"reuse_current": true}
	plans.localization = {"reuse_current": true}
	var preferences: Dictionary = _new_run_profile_owner.get_profile_snapshot().preferences
	var derived := RUN_SNAPSHOT_SCHEMA.derive_scene_audio_context(snapshot)
	if not derived.ok: return derived
	var audio_prep: Dictionary = _restore_participants.audio.prepare(
		{"preferences": preferences, "audio_context": derived.value})
	if not audio_prep.ok: return audio_prep
	plans.audio = audio_prep.value.audio_plan
	var route_context := RUN_SNAPSHOT_SCHEMA.derive_route_restore_context(snapshot)
	if not route_context.ok: return route_context
	var route_prep: Dictionary = _restore_participants.route.prepare(
		{"route_id": snapshot.route_id, "route_context": route_context.value})
	if not route_prep.ok: return route_prep
	plans.route = route_prep.value.route_plan
	var narr_prep: Dictionary = _restore_participants.narrative.prepare_scene_load(snapshot)
	if not narr_prep.ok: return narr_prep
	plans.narrative = narr_prep.value.narrative_plan
	var diagnostics: Array[Dictionary] = []
	var seed: Dictionary = _journal._prepare_seed_from_valid_bundles([bundle], bundle, diagnostics)
	if not seed.ok: return seed
	var prepared := {"bundle": bundle.duplicate(true), "journal_seed": seed.value.candidate,
		"participant_plans": plans, "route_id": snapshot.route_id, "checkpoint_id": snapshot.checkpoint_id}
	_scene_restore_preparation_counter += 1
	var token := "scene_restore_preparation:%d" % _scene_restore_preparation_counter
	prepared.scene_preparation_token = token
	_scene_restore_preparations[token] = {"prepared": prepared}
	return {"ok": true, "code": &"ok", "value": prepared.duplicate(true)}


func load_context(locator: Dictionary) -> Dictionary:
	if _storage == null:
		return _fail(&"not_initialized", "")
	var resolved := _resolve_locator_from_slot_id(str(locator.get("slot_id", "")))
	if resolved.is_empty():
		return _fail(&"invalid_source_locator", "unrecognized slot_id: " + str(locator.get("slot_id", "")))
	var relative_path := str(resolved["relative_path"])
	if not _storage.exists(relative_path):
		return _fail(&"save_absent", relative_path)
	var read: Dictionary = _storage.inspect_revision(relative_path)
	if not read.get("ok", false):
		return read
	var parsed: Dictionary = STRICT_JSON.parse_object(str(read["value"]["text"]))
	if not parsed.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)
	var migrated: Dictionary = SAVE_MIGRATIONS.migrate_document(parsed["value"],
		{"kind": str(resolved["kind"]), "slot_id": resolved["slot_id"]})
	if not migrated.get("ok", false):
		return migrated
	var document: Dictionary = migrated["value"]["document"]
	# Admission already returned the validated, detached document.
	var bundle := _find_bundle_by_checkpoint_id(document, str(locator.get("checkpoint_id", "")))
	if bundle.is_empty():
		return _fail(&"source_bundle_not_found", str(locator.get("checkpoint_id", "")))
	var context: Dictionary = bundle["snapshot"]
	var context_hash := _canonical_sha256(context)
	if context_hash.is_empty():
		return _fail(&"context_not_canonicalizable", "")
	return {"ok": true, "code": &"ok", "value": {
		"context": (context as Dictionary).duplicate(true), "context_sha256": context_hash,
	}}

## The inverse of `_slot_id_string()` below: the source locator's `slot_id` union ("quick" |
## "autosave" | "slot:N") back to `_resolve_locator()`'s own (kind, public_slot_id) shape.
func _resolve_locator_from_slot_id(slot_id_str: String) -> Dictionary:
	if slot_id_str == "quick":
		return _resolve_locator(&"quick", -1)
	if slot_id_str == "autosave":
		return _resolve_locator(&"autosave", -1)
	if slot_id_str.begins_with("slot:"):
		var suffix := slot_id_str.trim_prefix("slot:")
		if suffix.is_valid_int():
			return _resolve_locator(&"slot", int(suffix))
	return {}

func _find_bundle_by_checkpoint_id(document: Dictionary, checkpoint_id: String) -> Dictionary:
	var current: Variant = document.get("current_snapshot")
	if typeof(current) == TYPE_DICTIONARY \
			and str(((current as Dictionary).get("snapshot", {}) as Dictionary).get("checkpoint_id", "")) == checkpoint_id:
		return current
	for entry: Variant in document.get("recovery_journal", []):
		if typeof(entry) == TYPE_DICTIONARY \
				and str(((entry as Dictionary).get("snapshot", {}) as Dictionary).get("checkpoint_id", "")) == checkpoint_id:
			return entry
	return {}


static func _slot_id_string(kind: String, slot_id: Variant) -> String:
	if kind == "slot":
		return "slot:%d" % int(slot_id)
	return kind

static func _is_sha256(value: String) -> bool:
	if value.length() != 64:
		return false
	for character: String in value:
		if character not in "0123456789abcdef":
			return false
	return true

static func _canonical_sha256(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	if not emitted.get("ok", false):
		return ""
	return str(emitted["value"]).sha256_text()

## Plan 02 Task 6 (dwm-p2r.32), brief line 293: "Every New-Run/restore startup calls
## DesktopContinuationOperationJournal.list_incomplete() before run input." Exposed here for whoever
## owns application boot to call; NOT wired into any boot sequence by this task -- per the brief,
## Task 9 owns ApplicationBootstrap.gd's own stage sequence, and where exactly this hook belongs in
## it was never resolved by this task (see the handoff report).
##
## FIX (dwm-p2r.35.4 remediation, findings B-C2/B-C3): each nonterminal operation now goes through
## `_resume_operation()` below, which genuinely drives the frozen continuation law's recovery
## sequence -- reacquiring the gate lease, verifying the source/context, and advancing forward
## through allocation/participants/completion (or recording a pre-allocation abort) -- instead of
## merely calling the journal's own `reconcile_startup()` and reporting whatever it said. This
## method's own outer envelope is unchanged (`{"ok": true, "value": {"reconciled": [...]}}`): a
## per-operation resume outcome (completed/aborted/fatal_latched/already_terminal) is never treated
## as a reason to fail the whole reconciliation pass, since one operation's fatal must not stop the
## next incomplete operation from being examined.
func reconcile_incomplete_continuations() -> Dictionary:
	if _mutation_gate != null:
		var admitted := _admit_new_run_journal_io()
		if not admitted.get("ok", false): return admitted
	if _identity_issuer == null:
		return _fail(&"identity_issuer_not_configured", "configure_identity_issuer first")
	var retired: Dictionary = _continuation_journal.retire_scene_restore_operations()
	if not retired.get("ok", false): return retired
	var listed: Dictionary = _continuation_journal.list_incomplete()
	if not listed.get("ok", false):
		return listed
	var results: Array = []
	for operation: Variant in (listed["value"] as Array):
		# Old Load attempts no longer own persistent recovery. Shared creation
		# and identity records remain available to their original owners.
		if operation.get("kind") == "scene_restore": continue
		var transaction_id := str((operation as Dictionary)["transaction_id"])
		var reconciled: Dictionary = _resume_operation((operation as Dictionary).duplicate(true))
		results.append({"transaction_id": transaction_id, "result": reconciled})
		if operation.get("kind") == "scene_new_run" and not reconciled.get("ok", false):
			return reconciled
	return {"ok": true, "code": &"ok", "value": {"reconciled": results}}


func _resume_operation(operation: Dictionary) -> Dictionary:
	if operation.get("kind") == "scene_restore":
		return {"ok": true, "value": {"transaction_id": operation.transaction_id, "outcome": "obsolete_load_ignored"}}
	return retry_new_run(str(operation.transaction_id))


## The retained SaveDocument and Profile candidate drive every live retry. Disk
## targets are reproved first; recorded participant prefixes are not process-local state.
## SaveManager owns this coroutine so retiring the title cannot abandon a durable decision.
## Yield between completed operations, never inside an atomic storage write.
func _render_new_run_frame() -> void:
	if not is_inside_tree() or Time.get_ticks_usec() - _new_run_slice_started_us < 8000: return
	# Menu already painted the initial status. One subsequent process boundary lets
	# the work frame render, including when a slow renderer would make two waits costly.
	# Unlike frame_post_draw, this also progresses while minimized or headless.
	await get_tree().process_frame
	_new_run_slice_started_us = Time.get_ticks_usec()


func _resume_new_run(operation: Dictionary, gate_token: String, _responsive: bool = false) -> Dictionary:
	return _resume_scene_new_run(operation, gate_token)


func _delete(locator: Dictionary) -> Dictionary:
	if locator.is_empty():
		return _fail(&"INVALID_SAVE_REFERENCE", "")
	if _storage == null:
		return _fail(&"not_initialized", "")
	var relative_path := str(locator["relative_path"])
	var removed: Dictionary = _storage.remove(relative_path)
	if not removed.get("ok", false):
		return removed
	if _storage.exists(relative_path):
		return _fail(&"delete_incomplete", relative_path)
	slot_metadata_changed.emit()
	return {"ok": true, "code": &"ok", "value": {"deleted": true, "relative_path": relative_path}}

## One synchronous Backup write may validate the same outgoing text before and after promotion.
## Reuse only a successful validation of that exact String within this call. Storage still reads
## and proves the physical revision/bytes itself; another write receives a fresh empty memo.
## The caller consumes a storage witness, not the admitted document; each success is detached.
func _write_document_text_validator(text: String, validated_texts: Dictionary) -> Dictionary:
	if validated_texts.has(text):
		return {"ok": true, "code": &"ok", "value": {}}
	var result := _document_text_validator(text)
	# Preserve every refusal, including a malformed success that storage rejects.
	if not result.get("ok", false) or typeof(result.get("value")) != TYPE_DICTIONARY:
		return result
	validated_texts[text] = {"ok": true, "code": &"ok", "value": {}}
	return {"ok": true, "code": &"ok", "value": {}}

func _document_text_validator(text: String) -> Dictionary:
	var parsed: Dictionary = _parse_document_text(text)
	if not parsed.get("ok", false):
		return {"ok": false, "code": &"invalid_json", "message": "strict parse failed"}
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": validated["value"]["candidate"]}

## A cache entry proves only strict JSON parsing of this exact String. In particular,
## it never proves current schema, locator, content compatibility, or disk durability.
func _parse_document_text(text: String) -> Dictionary:
	var disabled := OS.get_environment("DWM_SAVE_PARSE_CACHE_DISABLED") == "1"
	var profile := _save_load_profile_begin("document_parse")
	if not profile.is_empty():
		profile["cache_enabled"] = not disabled
		profile["cache_hit"] = false
	if disabled:
		return _save_load_profile_finish(profile, STRICT_JSON.parse_object(text))
	for index: int in _document_parse_cache.size():
		var entry: Dictionary = _document_parse_cache[index]
		if entry["text"] == text:
			_document_parse_cache.remove_at(index)
			_document_parse_cache.append(entry)
			if not profile.is_empty(): profile["cache_hit"] = true
			return _save_load_profile_finish(profile, (entry["parsed"] as Dictionary).duplicate(true))
	var parsed := STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return _save_load_profile_finish(profile, parsed)
	# Count real UTF-8 bytes only for admission, after the unchanged strict parser.
	# Oversized valid inputs keep their normal result without displacing useful entries.
	var text_bytes := text.to_utf8_buffer().size()
	if text_bytes > _PARSE_CACHE_MAX_TEXT_BYTES:
		return _save_load_profile_finish(profile, parsed)
	while not _document_parse_cache.is_empty() and (
		_document_parse_cache.size() >= _PARSE_CACHE_MAX_ENTRIES
		or _document_parse_cache_text_bytes + text_bytes > _PARSE_CACHE_MAX_TEXT_BYTES):
		var oldest: Dictionary = _document_parse_cache.pop_front()
		_document_parse_cache_text_bytes -= int(oldest["text_bytes"])
	# The miss result belongs to this caller. Retain a separate tree even on first use.
	_document_parse_cache.append({"text": text, "text_bytes": text_bytes,
		"parsed": parsed.duplicate(true)})
	_document_parse_cache_text_bytes += text_bytes
	return _save_load_profile_finish(profile, parsed)

func _validate_checkpoint_inputs(checkpoint_inputs: Dictionary) -> String:
	var keys: Array = checkpoint_inputs.keys()
	keys.sort()
	var expected := _CHECKPOINT_INPUT_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return "unexpected checkpoint input keys: " + str(keys)
	if typeof(checkpoint_inputs["snapshot_input"]) != TYPE_DICTIONARY \
			or typeof(checkpoint_inputs["snapshot_input"].get("lifecycle")) != TYPE_DICTIONARY:
		return "snapshot_input.lifecycle is required"
	return ""

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}

## Keep source identity explicit: live run state already contains the remapped destination.
static func _source_identity_from_lifecycle(lifecycle: Dictionary) -> Dictionary:
	var receipt: Variant = lifecycle.get("causal_day_instance_issuer_receipt")
	return {"branch_id": lifecycle.get("branch_id"),
		"desktop_timeline_generation": lifecycle.get("desktop_timeline_generation"),
		"causal_day_instance": lifecycle.get("causal_day_instance"),
		"causal_day_instance_issuer_receipt": receipt.duplicate(true) if typeof(receipt) == TYPE_DICTIONARY else receipt}

func _validate_scene_restore_preparation(prepared: Dictionary) -> Dictionary:
	var token: Variant = prepared.get("scene_preparation_token")
	if not token is String or not _scene_restore_preparations.has(token):
		return _fail(&"invalid_scene_restore_preparation", "selected preparation is unavailable")
	# SaveManager owns the selected plan. Caller copies never replace that source.
	return {"ok": true}

func _scene_activation_pending(operation: Dictionary) -> bool:
	return operation.get("kind") in ["scene_restore", "scene_new_run"] and operation.get("stage") == CONTINUATION_JOURNAL.STAGE_COMPLETED \
		and operation.get("activation_state") == "pending"

func retry_scene_activation(transaction_id: String) -> Dictionary:
	if _completed_scene_restore.get("transaction_id") == transaction_id:
		return _completed_scene_restore.duplicate(true)
	if _scene_activation_busy or _scene_restore_commit_busy: return _fail(&"scene_restore_busy", "")
	if not _scene_restore_activation.is_empty():
		if _scene_restore_activation.operation_id != transaction_id: return _fail(&"scene_restore_busy", "")
		return _drive_scene_restore_activation()
	var found: Dictionary = _continuation_journal.get_operation(transaction_id)
	if not found.get("ok", false): return found
	if found.value.get("kind") == "scene_new_run" and _scene_activation_pending(found.value):
		return retry_new_run(transaction_id)
	if found.value.get("kind") == "scene_new_run" and found.value.get("activation_state") == "acknowledged":
		for key: String in ["route", "narrative"]:
			var checked: Dictionary = _restore_participants[key].validate_scene_activation(transaction_id)
			if not checked.get("ok", false): return checked
		return {"ok": true, "transaction_id": transaction_id, "value": {"transaction_id": transaction_id}}
	return _fail(&"scene_activation_unavailable", "")

func capture_scene_restore_activation(transaction_id: String) -> Dictionary:
	if _completed_scene_restore.get("transaction_id") != transaction_id:
		return _fail(&"scene_restore_not_activated", "Load has not reached live-session readiness")
	return _completed_scene_restore.duplicate(true)

func _advance_scene_restore(continuation: Dictionary, expected: String, next: String,
		index: int, participant: Variant = null, receipt: Variant = null) -> Dictionary:
	return _continuation_journal.advance({"transaction_id": continuation.transaction_id,
		"request_fingerprint": continuation.request_fingerprint, "expected_stage": expected, "next_stage": next,
		"expected_next_participant_index": index, "allocation_receipt": null,
		"participant_name": participant, "participant_receipt": receipt, "failure": null})

func _run_scene_restore_transaction(plans: Dictionary, journal_candidate: Variant,
		route_id: String, checkpoint_id: String, _emit_restored: bool, continuation: Dictionary,
		gate_token: String, already_applied: bool) -> Dictionary:
	if not _scene_restore_activation.is_empty(): return _fail(&"scene_restore_busy", "")
	var operation_id: String = continuation.transaction_id
	var memory_new_run: bool = continuation.kind == "memory_new_run"
	var memory_operation: bool = continuation.kind in ["memory_new_run", "memory_restore"]
	var found: Dictionary = {"ok": true, "value": {"kind": continuation.kind, "next_participant_index": 0}} if memory_operation else _continuation_journal.get_operation(operation_id)
	if not found.get("ok", false): return found
	var committed: bool = _scene_activation_pending(found.value)
	var creating: bool = memory_new_run or found.value.get("kind") == "scene_new_run"
	# Every owner must be reconstructed in a fresh process, but its historical
	# receipt prefix is already durable. In particular, a new live route generation
	# must never replace or be compared as a replay of the old process's receipt.
	var recorded_participants: int = found.value.next_participant_index
	var activation := _prepare_live_session_activation(plans, operation_id)
	if not activation.get("ok", false):
		return _scene_restore_early_failure(activation, committed or creating, gate_token)
	for key: String in ["route", "narrative"]:
		var participant: Object = _restore_participants[key]
		for method: String in ["begin_scene_activation", "validate_scene_activation", "publish_scene_activation"]:
			if not participant.has_method(method):
				return _scene_restore_early_failure(_fail(&"scene_activation_owner_unavailable", key + "." + method), committed or creating, gate_token)
		if not participant.has_signal("scene_activation_confirmed"):
			return _scene_restore_early_failure(_fail(&"scene_activation_owner_unavailable", key), committed or creating, gate_token)
	var held: Dictionary = _restore_participants.route.begin_scene_publication_hold(operation_id)
	if not held.get("ok", false): return _scene_restore_early_failure(held, committed or creating, gate_token)
	var backups := {}
	var applied: Array[String] = []
	var journal_backup: Variant = null
	var captured: Dictionary = _journal.capture_state()
	if not captured.get("ok", false):
		return _scene_restore_prepare_failure(captured, committed or creating, applied, backups, gate_token, operation_id, null)
	journal_backup = captured.value.backup
	for key: String in _SCENE_PARTICIPANT_ORDER:
		if key in ["profile", "localization"] and plans[key].get("reuse_current", false): continue
		var backup: Dictionary = _restore_participants[key].capture()
		if not backup.get("ok", false):
			return _scene_restore_prepare_failure(backup, committed or creating, applied, backups, gate_token, operation_id, null)
		backups[key] = backup.value
	var route_token: Dictionary = {}
	for index: int in _SCENE_PARTICIPANT_ORDER.size():
		var key: String = _SCENE_PARTICIPANT_ORDER[index]
		var plan: Dictionary = plans[key].duplicate(true)
		if key == "narrative":
			plan["route_ready_token"] = route_token.duplicate(true)
			plan["scene_restore_operation_id"] = operation_id
			plan["read_only_restore"] = continuation.kind == "memory_restore"
		var reuse_current: bool = key in ["profile", "localization"] and plan.get("reuse_current", false)
		var result: Dictionary = {"ok": true, "value": {}} if reuse_current else _restore_participants[key].apply_silent(plan)
		if not result.get("ok", false):
			return _scene_restore_prepare_failure(result, committed or creating, applied, backups, gate_token, operation_id, journal_backup)
		if not reuse_current: applied.append(key)
		if key == "route": route_token = result.get("value", {}).get("route_ready_token", {})
		if key == "run" and continuation.has("remap"):
			var remap: Dictionary = continuation.remap
			var remapped: Dictionary = _restore_participants.run.apply_continuation_remap(
				operation_id, remap.identity_allocation_bundle, remap.source_identity)
			if not remapped.get("ok", false):
				return _scene_restore_prepare_failure(remapped, committed or creating, applied, backups, gate_token, operation_id, journal_backup)
		if not memory_operation and not already_applied and index >= recorded_participants:
			var advanced := _advance_scene_restore(continuation, CONTINUATION_JOURNAL.STAGE_APPLYING,
				CONTINUATION_JOURNAL.STAGE_APPLYING, index, key, result.get("value", {}))
			if not advanced.get("ok", false):
				return _scene_restore_prepare_failure(advanced, committed or creating, applied, backups, gate_token, operation_id, journal_backup)
	if not memory_operation and not already_applied:
		var applied_result := _advance_scene_restore(continuation, CONTINUATION_JOURNAL.STAGE_APPLYING,
			CONTINUATION_JOURNAL.STAGE_APPLIED, _SCENE_PARTICIPANT_ORDER.size())
		if not applied_result.get("ok", false):
			return _scene_restore_prepare_failure(applied_result, creating, applied, backups, gate_token, operation_id, journal_backup)
	if journal_candidate is Dictionary:
		var seeded: Dictionary
		if creating and not memory_operation:
			var materials: Dictionary = found.value.new_run_materials
			seeded = _journal.commit_scene_new_run_reset(journal_candidate, materials.allocation_candidate,
				materials.profile, _scene_new_run_bundle, _identity_issuer)
			if not seeded.get("ok", false) and seeded.get("code") == &"duplicate_commit":
				var retained: Dictionary = _journal.capture_state()
				var expected: Dictionary = journal_candidate.duplicate(true)
				expected.erase("candidate_kind")
				if retained.get("ok", false) and CANONICAL_JSON._deep_same(retained.value.backup, expected):
					seeded = {"ok": true}
		elif memory_operation:
			# Creation owns its validated reset; Load owns its retained private seed.
			# Public commit_prepared still validates caller dictionaries.
			seeded = _journal._install_prepared(journal_candidate)
		else:
			seeded = _journal.commit_prepared(journal_candidate)
		if not seeded.get("ok", false):
			return _scene_restore_prepare_failure(seeded, committed or creating, applied, backups, gate_token, operation_id, journal_backup)
	if not memory_operation and not committed:
		var completed := _advance_scene_restore(continuation, CONTINUATION_JOURNAL.STAGE_APPLIED,
			CONTINUATION_JOURNAL.STAGE_COMPLETED, _SCENE_PARTICIPANT_ORDER.size())
		if not completed.get("ok", false):
			var reread: Dictionary = _continuation_journal.reload_operation_from_storage(operation_id)
			if not reread.get("ok", false):
				return _fatal_transaction_recovery("scene_restore", [{"owner_id": "journal", "operation": "completion_uncertain", "result": reread}])
			if _scene_activation_pending(reread.value):
				committed = true
			elif reread.value.get("stage") == CONTINUATION_JOURNAL.STAGE_APPLIED:
				return _scene_restore_prepare_failure(completed, creating, applied, backups, gate_token, operation_id, journal_backup)
			else:
				return _fatal_transaction_recovery("scene_restore", [{"owner_id": "journal", "operation": "completion_state_conflict", "result": reread}])
	if continuation.kind == "memory_restore":
		# All saved owners are installed synchronously. Retire old input handles
		# before mounting the destination; no Load mutation lease is needed.
		_restore_participants.run.activate_loaded_session(activation.value)
	_scene_restore_activation = {"operation_id": operation_id, "continuation": continuation.duplicate(true),
		"ticket": activation.value.duplicate(true), "gate_token": gate_token, "route_id": route_id,
		"owner": "new_run" if creating else "restore",
		"checkpoint_id": checkpoint_id, "phase": "route", "route_confirmed": false,
		"narrative_confirmed": false, "started": false, "failure": {}}
	for key: String in _SCENE_PARTICIPANT_ORDER:
		if key in ["profile", "localization"] and plans[key].get("reuse_current", false): continue
		var finalized: Dictionary = _restore_participants[key].finalize()
		if not finalized.get("ok", false): return _scene_restore_activation_failure(finalized)
	for key: String in ["route", "narrative"]:
		var callback: Callable = _on_scene_route_confirmed if key == "route" else _on_scene_narrative_confirmed
		if not _restore_participants[key].is_connected("scene_activation_confirmed", callback):
			_restore_participants[key].connect("scene_activation_confirmed", callback)
	if not _restore_participants.narrative.is_connected("scene_activation_failed", _on_scene_restore_failed):
		_restore_participants.narrative.connect("scene_activation_failed", _on_scene_restore_failed)
	return _drive_scene_restore_activation()

func _scene_restore_prepare_failure(failure: Dictionary, committed: bool, applied: Array[String],
		backups: Dictionary, gate_token: String, operation_id: String, journal_backup: Variant) -> Dictionary:
	if committed:
		return _fatal_transaction_recovery("scene_restore", [{"owner_id": "restore", "operation": "reconstruct", "result": failure}])
	var cancelled: Dictionary = _restore_participants.route.cancel_scene_publication_hold(operation_id)
	if not cancelled.get("ok", false):
		return _fatal_transaction_recovery("scene_restore", [{"owner_id": "route", "operation": "cancel_hold", "result": cancelled}])
	return _rollback_transaction(&"restore", applied, backups, gate_token, _lock_owner == &"restore", failure, journal_backup)

func _scene_restore_early_failure(failure: Dictionary, committed: bool, gate_token: String) -> Dictionary:
	if committed:
		return _fatal_transaction_recovery("scene_restore", [{"owner_id": "restore", "operation": "reconstruct", "result": failure}])
	_release_transaction(&"restore", gate_token, _lock_owner == &"restore")
	return failure

func _on_scene_route_confirmed(operation_id: String) -> void:
	if _scene_restore_activation.get("operation_id") != operation_id: return
	_scene_restore_activation.route_confirmed = true
	if not _scene_activation_busy: _drive_scene_restore_activation()

func _on_scene_narrative_confirmed(operation_id: String) -> void:
	if _scene_restore_activation.get("operation_id") != operation_id: return
	_scene_restore_activation.narrative_confirmed = true
	if not _scene_activation_busy: _drive_scene_restore_activation()

func _on_scene_restore_failed(operation_id: String, result: Dictionary) -> void:
	if _scene_restore_activation.get("operation_id") == operation_id:
		_scene_restore_activation_failure(result)

func _scene_restore_activation_failure(failure: Dictionary) -> Dictionary:
	if not _scene_restore_activation.is_empty(): _scene_restore_activation.failure = failure.duplicate(true)
	var fatal := _fatal_transaction_recovery("scene_restore", [{"owner_id": "restore", "operation": "activate", "result": failure}])
	if failure.get("code") == &"reading_content_error": return _content_result(failure)
	return fatal

func _drive_scene_restore_activation() -> Dictionary:
	if _scene_activation_busy: return _fail(&"scene_restore_busy", "")
	_scene_activation_busy = true
	var result := _drive_scene_restore_activation_owned()
	_scene_activation_busy = false
	return result

func _drive_scene_restore_activation_owned() -> Dictionary:
	if _scene_restore_activation.is_empty(): return _fail(&"scene_activation_unavailable", "")
	if not _scene_restore_activation.failure.is_empty(): return _scene_restore_activation.failure
	var operation_id: String = _scene_restore_activation.operation_id
	for phase: String in ["route", "narrative"]:
		if _scene_restore_activation.phase != phase: continue
		var participant: Object = _restore_participants[phase]
		if not _scene_restore_activation.started:
			_scene_restore_activation.started = true
			var begun: Dictionary = participant.begin_scene_activation(operation_id)
			if not begun.get("ok", false): return _scene_restore_activation_failure(begun)
		if not _scene_restore_activation.failure.is_empty(): return _scene_restore_activation.failure
		if not _scene_restore_activation[phase + "_confirmed"]:
			return {"ok": false, "code": &"scene_activation_pending", "recovery_required": true,
				"transaction_id": operation_id,
				"value": {"transaction_id": operation_id}}
		var checked: Dictionary = participant.validate_scene_activation(operation_id)
		if not checked.get("ok", false): return _scene_restore_activation_failure(checked)
		_scene_restore_activation.phase = "narrative" if phase == "route" else "ack"
		_scene_restore_activation.started = false
	for key: String in ["route", "narrative"]:
		var checked: Dictionary = _restore_participants[key].validate_scene_activation(operation_id)
		if not checked.get("ok", false): return _scene_restore_activation_failure(checked)
	var activation_owner := StringName(_scene_restore_activation.get("owner", "restore"))
	if _scene_restore_activation.continuation.kind != "memory_restore":
		if _mutation_gate == null or not _mutation_gate.is_lease_active(activation_owner, _scene_restore_activation.gate_token):
			return _scene_restore_activation_failure(_fail(&"scene_restore_lease_lost", ""))
		var ticket: Dictionary = _scene_restore_activation.ticket
		var activated: Dictionary = _restore_participants.run.activate_live_session(ticket)
		if not activated.get("ok", false): return _scene_restore_activation_failure(activated)
	if _scene_restore_activation.continuation.kind not in ["memory_new_run", "memory_restore"]:
		var acknowledged: Dictionary = _continuation_journal.acknowledge_scene_activation(operation_id,
			_scene_restore_activation.continuation.request_fingerprint)
		if not acknowledged.get("ok", false):
			var reread: Dictionary = _continuation_journal.reload_operation_from_storage(operation_id)
			if not reread.get("ok", false): return _scene_restore_activation_failure(reread)
			if reread.value.get("activation_state") != "acknowledged":
				return _scene_restore_activation_failure(acknowledged)
	for key: String in ["narrative", "route"]:
		var published: Dictionary = _restore_participants[key].publish_scene_activation(operation_id)
		if not published.get("ok", false): return _scene_restore_activation_failure(published)
	var completed := _scene_restore_activation.duplicate(true)
	_scene_restore_activation.clear()
	_session_activation_tickets.erase(operation_id)
	if completed.continuation.kind == "memory_restore":
		_completed_scene_restore = {"ok": true, "transaction_id": operation_id,
			"value": {"transaction_id": operation_id, "checkpoint_id": completed.checkpoint_id,
				"route_id": completed.route_id}}
	if activation_owner == &"new_run":
		var released := _release_new_run_custody()
		if not released.get("ok", false): return released
	elif completed.continuation.kind != "memory_restore":
		_release_transaction(&"restore", completed.gate_token, true)
	live_session_ready.emit()
	if activation_owner == &"restore": run_restored.emit(completed.checkpoint_id, completed.route_id)
	return {"ok": true, "value": {"transaction_id": operation_id, "checkpoint_id": completed.checkpoint_id,
		"route_id": completed.route_id}}


## Freeze the current lifetime before any candidate apply. Pure participant
## orchestration without a run snapshot has no live session to replace.
func _prepare_live_session_activation(plans: Dictionary, operation_id: String) -> Dictionary:
	var plan: Dictionary = plans.get("run", {})
	if not plan.has("snapshot"):
		return {"ok": true, "value": {}}
	if _session_activation_tickets.has(operation_id):
		return {"ok": true, "value": _session_activation_tickets[operation_id].duplicate(true)}
	var run: Object = _restore_participants["run"]
	if not run.has_method("capture_live_session"):
		return _fail(&"session_owner_unconfigured", "run participant requires live-session ownership")
	var captured: Dictionary = run.capture_live_session()
	if not captured.get("ok", false): return captured
	var session: Dictionary = captured["value"]
	var ticket := {"operation_id": operation_id, "expected_generation": session["generation"],
		"owner_id": session["owner_id"], "run_id": plan["snapshot"]["run_id"]}
	_session_activation_tickets[operation_id] = ticket.duplicate(true)
	return {"ok": true, "value": ticket}


func _scene_new_run_text_validator(text: String, materials: Dictionary) -> Dictionary:
	var parsed: Dictionary = STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false): return parsed
	return SAVE_DOCUMENT_SCHEMA.validate_scene_new_run_candidate(parsed.value, materials.allocation_candidate,
		materials.profile, _scene_new_run_bundle, _identity_issuer)

func configure_scene_restore_participants(participants: Dictionary) -> Dictionary:
	var keys: Array = participants.keys()
	keys.sort()
	var expected: Array = _SCENE_PARTICIPANT_ORDER.duplicate()
	expected.sort()
	if keys != expected: return _fail(&"invalid_restore_participants", "exactly eight scene participants required")
	for key: String in keys:
		if not is_instance_valid(participants[key]): return _fail(&"invalid_restore_participants", key)
		for method: String in ["prepare", "capture", "apply_silent", "rollback_silent", "finalize"]:
			if not participants[key].has_method(method): return _fail(&"invalid_restore_participants", key + "." + method)
	_restore_participants = participants.duplicate()
	return {"ok": true}

## Ordinary Load obtains authority only from an acknowledged creation, the exact
## committed allocation and its still-physical Profile assignment. Autosave may
## legitimately have advanced since creation; the retained initial state fixes its origin.
func capture_committed_scene_creation(transaction_id: String) -> Dictionary:
	if _identity_issuer == null or _new_run_profile_owner == null:
		return _fail(&"scene_creation_owner_unavailable", "")
	var found: Dictionary = _continuation_journal.get_creation_operation(transaction_id)
	if not found.get("ok", false): return found
	var operation: Dictionary = found.value
	if operation.get("kind") != "scene_new_run" or operation.get("stage") != CONTINUATION_JOURNAL.STAGE_COMPLETED \
			or operation.get("activation_state") != "acknowledged":
		return _fail(&"scene_creation_not_activated", "durable completed creation and activation required")
	var materials: Dictionary = operation.new_run_materials
	var captured: Dictionary = _identity_issuer.capture_root()
	if not captured.get("ok", false): return captured
	var root: Dictionary = captured.value
	if not CANONICAL_JSON._deep_same(root.get("allocation_receipts", {}).get(transaction_id), materials.allocation_candidate):
		return _fail(&"scene_creation_allocation_unproven", "")
	var profile: Dictionary = _new_run_profile_owner.prove_scene_assignment(materials.allocation_candidate.run_id,
		materials.profile.scene_assignment.receipt)
	if not profile.get("ok", false): return profile
	# The retained canonical initial document fixes the actual first scene. Never
	# read today's mutable Autosave or require later snapshots to equal this one.
	var initial: Dictionary = _parse_document_text(materials.autosave.outgoing_text)
	if not initial.get("ok", false): return initial
	var initial_scene: Variant = initial.value.current_snapshot.snapshot.get("scene")
	if not initial_scene is Dictionary or initial_scene.get("active_occurrence_id") != transaction_id:
		return _fail(&"scene_creation_proof_invalid", "retained initial scene missing")
	return {"ok": true, "value": {"operation": operation.duplicate(true),
		"allocation_candidate": materials.allocation_candidate.duplicate(true), "profile_material": materials.profile.duplicate(true),
		"initial_scene": initial_scene.duplicate(true)}}
