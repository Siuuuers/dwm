extends Node


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
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PROJECTOR := preload("res://scripts/application/transaction/FatalDiagnosticProjector.gd")

const _GATE_CONTRACT_METHODS: Array[String] = [
	"acquire", "release", "guard_external", "is_active", "get_active_owner",
	"is_internal_owner_active", "latch_fatal", "is_fatal_latched",
]
const _LOCK_OWNERS: Array[StringName] = [&"minesweeper_board", &"scene_transition", &"restore"]
const _CHECKPOINT_INPUT_KEYS: Array[String] = [
	"active_app_id", "audio_context", "content_version", "dialogic_checkpoint",
	"route_id", "snapshot_input",
]

var _storage: RefCounted = null
var _journal: RefCounted = CHECKPOINT_JOURNAL.new()
var _mutation_gate: Object = null
var _identity_issuer: Object = null
var _new_run_profile_owner: Object = null
var _scene_new_run_bridge: Object = null
var _scene_new_run_bundle: Dictionary = {}
var _scene_title_new_run_target := ""
var _scene_title_new_run_context: Dictionary = {}
var _new_run_busy := false
var _new_run_gate_token := ""
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
var _prepared_new_run_token := ""
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
const _PARSE_CACHE_MAX_ENTRIES := 2
const _PARSE_CACHE_MAX_TEXT_BYTES := 8 * 1024 * 1024
var _document_parse_cache: Array[Dictionary] = []
var _document_parse_cache_text_bytes := 0

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
	if _storage != null and _storage != storage:
		return _fail(&"journal_already_configured", "cannot replace storage")
	_document_parse_cache.clear()
	_document_parse_cache_text_bytes = 0
	_storage = storage
	return {"ok": true, "code": &"ok", "value": {"root": storage.describe_root()}}

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
	var retained := _validate_scene_restore_preparation(prepared)
	if not retained.ok: return retained
	var token: String = prepared.scene_preparation_token
	var plan: Dictionary = _scene_restore_preparations[token]
	var operation_id := "scene_load:" + token
	_scene_restore_preparations.erase(token)
	_completed_scene_restore.clear()
	return _run_scene_restore_transaction(plan.participant_plans, plan.journal_seed,
		str(plan.route_id), str(plan.checkpoint_id), operation_id, false)


func configure_scene_new_run(bridge: Object) -> Dictionary:
	if not is_instance_valid(bridge) or bridge.get_script() != load("res://autoload/DialogicBridge.gd") or _identity_issuer == null:
		return _fail(&"scene_new_run_not_configured", "actual Bridge and issuer required")
	if _scene_new_run_bridge != null and _scene_new_run_bridge != bridge:
		return _fail(&"scene_new_run_already_configured", "")
	var selected: Dictionary = preload("res://scripts/narrative/DialogicEntryManifest.gd").scene_contract_tables()
	if not selected.get("ok", false): return selected
	if _identity_issuer.get_script() != load("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"):
		return _fail(&"scene_new_run_issuer_unbound", "requires the actual identity owner")
	if not _scene_new_run_bundle.is_empty() and not is_same(_scene_new_run_bundle, selected.bundle) \
			and not CANONICAL_JSON._deep_same(_scene_new_run_bundle, selected.bundle):
		return _fail(&"scene_new_run_validation_already_bound", "cannot replace creation authority")
	_scene_new_run_bridge = bridge
	_scene_new_run_bundle = selected.bundle
	return {"ok": true}

func configure_scene_title_new_run(target_id: String) -> Dictionary:
	if not is_instance_valid(_scene_new_run_bridge) or _scene_new_run_bundle.is_empty():
		return _fail(&"scene_new_run_not_configured", "")
	if _scene_new_run_bundle.get("schema_version") != 3:
		return _fail(&"scene_title_audio_catalogue_required", "")
	if not _scene_title_new_run_target.is_empty():
		return {"ok": true} if _scene_title_new_run_target == target_id else _fail(&"scene_title_new_run_already_configured", "")
	if _new_run_busy or not _prepared_new_run_token.is_empty() or not _new_run_transaction_id.is_empty():
		return _fail(&"new_run_busy", "")
	for row: Dictionary in _scene_new_run_bundle.targets:
		if row.target_id == target_id and row.target.kind == "scene":
			_scene_title_new_run_target = target_id
			_scene_title_new_run_context = {"content_version": row.target.content_version}
			return {"ok": true}
	return _fail(&"scene_initial_target_invalid", target_id)

func start_scene_new_run(target_id: String, initial_context: Dictionary, _rng_nonce: Variant = null) -> Dictionary:
	if _new_run_busy or not _scene_restore_activation.is_empty(): return _fail(&"new_run_busy", "")
	var ready := _new_run_ready()
	if not ready.ok: return ready
	var acquired := _take_new_run_custody()
	if not acquired.ok: return acquired
	_new_run_busy = true
	var result := _start_scene_new_run_in_memory(target_id, initial_context)
	_new_run_busy = false
	if not result.ok and _scene_restore_activation.is_empty():
		_release_new_run_custody()
	return _content_result(result)

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
	var plans := _prepare_scene_new_run_plans(snapshot)
	if not plans.ok: return plans
	var reset := {"candidate_kind": "reset", "run_id": snapshot.run_id, "next_sequence": 2,
		"current": {"checkpoint_kind": "day_start", "snapshot": snapshot}, "earlier": []}
	_new_run_transaction_id = operation_id
	return _run_scene_restore_transaction(plans.value, reset, "scene", snapshot.checkpoint_id, operation_id, true)

func _prepare_scene_new_run_plans(snapshot: Dictionary) -> Dictionary:
	var run: Dictionary = _restore_participants.run.prepare_scene_new_run(snapshot, _identity_issuer, self)
	if not run.get("ok", false): return run
	var profile: Dictionary = _restore_participants.profile.prepare_current()
	if not profile.get("ok", false): return profile
	var narrative: Dictionary = _restore_participants.narrative.prepare_scene_new_run(snapshot, _scene_new_run_bundle, self)
	if not narrative.get("ok", false): return narrative
	var plans := {"run": run.value.run_plan, "profile": profile.value.profile_plan, "narrative": narrative.value.narrative_plan}
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
		"audio": {"preferences": plans.profile.profile.preferences, "audio_context": audio_context.value},
		"route": {"route_id": "scene", "route_context": {"scene": true, "active_app_id": null}}}
	if _scene_new_run_bundle.get("schema_version") == 3:
		inputs.audio["scene_audio_mode"] = "entry"
	var names := {"desktop_consequence": "consequence_plan", "desktop_board": "board_plan",
		"localization": "localization_plan", "audio": "audio_plan", "route": "route_plan"}
	for key: String in inputs:
		var prepared: Dictionary = _restore_participants[key].prepare(inputs[key])
		if not prepared.get("ok", false): return prepared
		plans[key] = prepared.value[names[key]]
	return {"ok": true, "value": plans}

func configure_new_run_profile_owner(owner: Object) -> Dictionary:
	if owner == null or not is_instance_valid(owner):
		return _fail(&"invalid_new_run_profile_owner", "")
	for method: String in ["get_profile_snapshot", "get_preference_group", "flush_reading_history"]:
		if not owner.has_method(method):
			return _fail(&"invalid_new_run_profile_owner", method)
	if _new_run_profile_owner != null and _new_run_profile_owner != owner:
		return _fail(&"new_run_profile_owner_already_configured", "")
	_new_run_profile_owner = owner
	return {"ok": true, "code": &"ok"}

func _new_run_ready() -> Dictionary:
	if _restore_participants.is_empty():
		return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", "")
	if _identity_issuer == null:
		return _fail(&"identity_issuer_not_configured", "")
	if _storage == null or _mutation_gate == null or _new_run_profile_owner == null:
		return _fail(&"new_run_not_configured", "")
	if _scene_new_run_bundle.is_empty():
		return _fail(&"scene_new_run_not_configured", "scene registration required")
	return {"ok": true}

func _take_new_run_custody() -> Dictionary:
	if not _new_run_gate_token.is_empty():
		if _mutation_gate.is_fatal_latched() or not _mutation_gate.is_internal_owner_active(&"new_run") or not _new_run_transaction_id.is_empty():
			return _fail(&"new_run_recovery_conflict", "")
		return {"ok": true}
	var acquired: Dictionary = _mutation_gate.acquire(&"new_run")
	if not acquired.get("ok", false): return acquired
	_new_run_gate_token = str(acquired["value"]["token"])
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

func prepare_new_run_action() -> Dictionary:
	if _new_run_busy or not _scene_restore_activation.is_empty(): return _fail(&"new_run_busy", "")
	if not _scene_title_new_run_target.is_empty():
		for key: String in _SCENE_PARTICIPANT_ORDER:
			if not _restore_participants.has(key): return _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", key)
	var ready := _new_run_ready()
	if not ready.get("ok", false): return ready
	if not _new_run_transaction_id.is_empty():
		return _new_run_failure(_fail(&"new_run_recovery_required", ""))
	var admitted: Dictionary = _mutation_gate.guard_external(&"new_run_prepare")
	if not admitted.get("ok", false): return admitted
	if not _scene_title_new_run_target.is_empty():
		var replaces_live: bool = _restore_participants.run.has_new_run_replacement()
		_prepared_new_run_counter += 1
		var token := "prepared-new-run-%d-%d" % [get_instance_id(), _prepared_new_run_counter]
		_prepared_new_run_token = token
		var occupied: bool = _storage.exists("autosave.json")
		return {"ok": true, "value": {"token": token,
			"requires_confirmation": replaces_live or occupied,
			"replaces_live": replaces_live, "replaces_autosave": occupied}}
	return _fail(&"scene_new_run_not_configured", "scene title target required")

func cancel_prepared_new_run(token: String) -> Dictionary:
	if token.is_empty() or token != _prepared_new_run_token:
		return _fail(&"invalid_new_run_preparation", "")
	_prepared_new_run_token = ""
	return {"ok": true, "code": &"ok", "value": {"cancelled": true}}

func commit_prepared_new_run(token: String) -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	if token.is_empty() or token != _prepared_new_run_token:
		return _fail(&"invalid_new_run_preparation", "")
	var ready := _new_run_ready()
	if not ready.get("ok", false): return ready
	if not _new_run_transaction_id.is_empty():
		_prepared_new_run_token = ""
		return _new_run_failure(_fail(&"new_run_recovery_required", ""))
	_new_run_busy = true
	var result := _take_new_run_custody()
	if result.ok:
		_prepared_new_run_token = ""
		result = _start_scene_new_run_in_memory(_scene_title_new_run_target, _scene_title_new_run_context)
		if not result.ok and _scene_restore_activation.is_empty(): _release_new_run_custody()
	_new_run_busy = false
	return result

func retry_new_run(transaction_id: String) -> Dictionary:
	if _new_run_busy: return _fail(&"new_run_busy", "")
	var ready := _new_run_ready()
	if not ready.get("ok", false): return ready
	if transaction_id.is_empty(): return _fail(&"invalid_new_run_transaction", "")
	if _scene_restore_activation.get("owner") != &"new_run" or transaction_id != _new_run_transaction_id:
		return _fail(&"new_run_recovery_conflict", "")
	_new_run_busy = true
	var result := _drive_scene_restore_activation()
	_new_run_busy = false
	return result

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


func _release_transaction(owner: StringName, gate_token: String, holds_save_lock: bool) -> void:
	if _mutation_gate != null and gate_token != "":
		_mutation_gate.release(owner, gate_token)
	if holds_save_lock:
		release_save_lock(&"restore")

func _rollback_transaction(owner: StringName, applied: Array[String], backups: Dictionary, gate_token: String, holds_save_lock: bool, original_failure: Dictionary) -> Dictionary:
	var attempts: Array = []
	var all_recovered := true
	for index: int in range(applied.size() - 1, -1, -1):
		var key: String = applied[index]
		var rolled: Dictionary = _restore_participants[key].rollback_silent(backups[key])
		attempts.append({"owner_id": key, "operation": "rollback_silent", "result": rolled})
		if not rolled.get("ok", false):
			all_recovered = false
	if all_recovered:
		_release_transaction(owner, gate_token, holds_save_lock)
		return original_failure
	attempts.append({"owner_id": String(owner), "operation": "original_failure", "result": original_failure})
	return _fatal_transaction_recovery(String(owner), attempts)

func _fatal_transaction_recovery(source: String, raw_diagnostics: Array) -> Dictionary:
	if _mutation_gate == null:
		return {"ok": false, "code": &"restore_rollback_failed", "message": "rollback failed with no gate"}
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
	var admitted: Dictionary = SAVE_DOCUMENT_SCHEMA.admit_document(parsed["value"],
		{"kind": str(locator["kind"]), "slot_id": locator["slot_id"]})
	if not admitted.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)
	var document: Dictionary = admitted["value"]
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

func inspect_backup(locator_id: String) -> Dictionary:
	return _inspect_backup(locator_id)

func get_backup_save_capability() -> Dictionary:
	var allowed := _backup_guard()
	if not allowed.get("ok", false):
		return {"enabled": false, "reason": str(allowed.get("code", "unavailable"))}
	if not _journal.has_current_bundle():
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

func get_backup_quick_capability(action: String) -> Dictionary:
	if action not in ["save", "load"]:
		return {"ok": false, "code": &"invalid_backup_action", "status_key": "unavailable", "condition": {}}
	var condition := _quick_condition(action)
	var enabled := false
	var status := _quick_guard_status(action)
	if status == "":
		var has_stable: bool = _journal.has_current_bundle()
		var inspected := _inspect_backup("quick")
		if has_stable and inspected.get("ok", false):
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
	_backup_actions[token]["quick_condition"] = condition.duplicate()
	prepared["value"]["condition"] = condition
	return prepared

func is_quick_condition_current(condition: Dictionary) -> bool:
	if condition.size() != 2 or typeof(condition.get("action")) != TYPE_STRING or condition.get("action") not in ["save", "load"] \
			or typeof(condition.get("signature")) != TYPE_STRING or condition["signature"].is_empty():
		return false
	return condition == _quick_condition(condition["action"])

func _quick_condition(action: String) -> Dictionary:
	var stable_hash: String = _journal.current_bundle_hash()
	var captured := _capture_backup_inputs() if _backup_capture_configured else {"ok": false, "code": &"not_configured"}
	var target: Dictionary = {"ok": false, "code": &"not_initialized"}
	if _storage != null:
		target = _storage.inspect_revision(str(_backup_locator("quick")["relative_path"]))
	var evidence := {
		"owner": str(get_instance_id()), "action": action,
		"stable": stable_hash,
		"capture": CANONICAL_JSON.sha256(captured["value"]) if captured.get("ok", false) else str(captured.get("code", "unavailable")),
		"target": target["value"]["revision"] if target.get("ok", false) else str(target.get("code", "unavailable")),
		"lock": str(_lock_owner),
		"gate_owner": str(_mutation_gate.get_active_owner()) if _mutation_gate != null else "",
		"fatal": _mutation_gate.is_fatal_latched() if _mutation_gate != null else false,
	}
	return {"action": action, "signature": CANONICAL_JSON.sha256(evidence)}

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
	var parsed := _parse_document_text(evidence["text"], true)
	_save_load_profile_phase(profile, "parse_us")
	if not parsed.get("ok", false):
		record["reason"] = "unreadable"
		return {"ok": true, "value": record}
	var document: Dictionary = parsed["value"]
	record["reason"] = _player_save_format_reason(document)
	if not record["reason"].is_empty():
		return {"ok": true, "value": record}
	var bundle: Variant = document.get("current_snapshot")
	if typeof(bundle) != TYPE_DICTIONARY or typeof(bundle.get("snapshot")) != TYPE_DICTIONARY:
		record["reason"] = "unreadable"
		return {"ok": true, "value": record}
	record["state"] = "occupied"
	record["family"] = "scene"
	var display_time := SAVE_DOCUMENT_SCHEMA.normalize_optional_saved_time(document.get("saved_time"))
	record["saved_time"] = display_time.get("hhmm")
	record["loadable"] = true
	record["load_family"] = record["family"]
	record["load_day"] = record["day"]
	record["load_saved_time"] = record["saved_time"]
	return {"ok": true, "value": record}

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
		if not _journal.has_current_bundle():
			return _fail(&"no_stable_checkpoint", "")
		var bundle: Dictionary
		var earlier: Array
		var proven_snapshot: Dictionary = {}
		if _backup_capture_configured:
			var fresh := _prepare_backup_capture()
			if not fresh.get("ok", false):
				return fresh
			candidate.merge(fresh["value"])
			bundle = candidate["journal_candidate"]["current"]
			earlier = candidate["journal_candidate"]["earlier"]
			proven_snapshot = bundle.snapshot
		else:
			bundle = _journal.current_bundle_for_save()
			earlier = _journal.get_bundles_for_disk()
		_save_load_profile_phase(profile, "capture_us")
		var built := SAVE_DOCUMENT_SCHEMA.build(StringName(locator["kind"]), locator["slot_id"],
			&"quick" if locator_id == "quick" else &"manual", bundle, earlier, _capture_saved_time(), [], {}, proven_snapshot)
		_save_load_profile_phase(profile, "document_build_us")
		if not built.get("ok", false):
			return built
		candidate["document"] = built["value"]
		if not candidate.has("journal_candidate"):
			candidate["stable_hash"] = CANONICAL_JSON.sha256(bundle)
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
	_backup_actions[token] = candidate
	return {"ok": true, "value": {"token": token, "record": record}}

func cancel_backup_action(token: String) -> void:
	_release_backup_preparation(_backup_actions.get(token, {}))
	_backup_actions.erase(token)

func _release_backup_preparation(candidate: Dictionary) -> void:
	var token: String = candidate.get("prepared_restore", {}).get("scene_preparation_token", "")
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
				if CANONICAL_JSON.sha256(captured["value"]) != candidate["capture_hash"] or _backup_journal_hash() != candidate["journal_hash"]:
					return _fail(&"stale_backup_source", "")
			else:
				if not _journal.has_current_bundle() or _journal.current_bundle_hash() != candidate["stable_hash"]:
					return _fail(&"stale_backup_source", "")
			var flushed := flush_profile_reading_history()
			if not flushed.ok: return flushed
			_save_load_profile_phase(profile, "source_recheck_us")
			var canonical := CANONICAL_JSON.stringify(candidate["document"])
			_save_load_profile_phase(profile, "serialize_us")
			if not canonical.get("ok", false):
				return canonical
			var bytes := str(canonical["value"]) + "\n"
			var validated_texts := {bytes: {"ok": true, "code": &"ok", "value": {}}}
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
				var advanced: Dictionary = _journal._install_prepared(candidate["journal_candidate"])
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
		var snapshot: Dictionary = inputs["snapshot_input"].duplicate()
		snapshot["route_id"] = inputs["route_id"]
		snapshot["narrative_checkpoint"] = narrative
		var reading: Dictionary = preload("res://scripts/narrative/FrozenRunContext.gd").validate_reading_checkpoint(narrative, snapshot)
		if not reading.get("ok", false): return reading
	return {"ok": true, "value": inputs}


func _compose_live_checkpoint_input(snapshot_input: Dictionary) -> Dictionary:
	return preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")._normalize_json_string_types(snapshot_input)


func _backup_journal_hash() -> String:
	return _journal.state_hash()

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
		"capture_hash": CANONICAL_JSON.sha256(inputs), "journal_hash": journal_hash}}

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

func flush_profile_reading_history() -> Dictionary:
	if _new_run_profile_owner == null: return {"ok": true}
	var flushed: Dictionary = _new_run_profile_owner.flush_reading_history()
	if not flushed.ok: save_failed.emit(flushed)
	return flushed


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
	var bundle: Dictionary = _journal.current_bundle_for_save()
	if bundle.is_empty():
		return _fail(&"no_stable_checkpoint", "")
	var built: Dictionary = SAVE_DOCUMENT_SCHEMA.build(
		StringName(str(locator["kind"])), locator["slot_id"], StringName(save_reason),
		bundle, _journal.get_bundles_for_disk(), _capture_saved_time())
	if not built.get("ok", false):
		save_failed.emit(built)
		return built
	var flushed := flush_profile_reading_history()
	if not flushed.ok: return flushed
	var relative_path := str(locator["relative_path"])
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
	if CANONICAL_JSON.sha256(document) != CANONICAL_JSON.sha256(built["value"]):
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
	if not expected_revision.is_empty() and str(read["value"]["revision"]) != expected_revision:
		return _fail(&"stale_backup_target", "")
	var parsed: Dictionary = _parse_document_text(str(read["value"]["text"]), true)
	if not parsed.get("ok", false):
		return _fail(&"corrupt_save_document", relative_path)

	var admitted: Dictionary = SAVE_DOCUMENT_SCHEMA.load_current_document(parsed["value"])
	if not admitted.get("ok", false):
		return admitted
	return _prepare_restore_document(locator, admitted.value)

func _prepare_restore_document(locator: Dictionary, document: Dictionary) -> Dictionary:
	var profile := _save_load_profile_begin("restore_prepare", "", locator)
	if _restore_participants.is_empty():
		return _save_load_profile_finish(profile, _fail(&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED", ""))
	var result := _prepare_bundle_with_all_participants(document.current_snapshot)
	_save_load_profile_phase(profile, "participant_prepare_us")
	if result.ok:
		result = {"ok": true, "code": &"ok", "value": {"prepared": result.value}}
	return _save_load_profile_finish(profile, result)

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
	var audio_preferences: Dictionary = _new_run_profile_owner.get_preference_group(&"audio")
	var derived := RUN_SNAPSHOT_SCHEMA.derive_scene_audio_context(snapshot)
	if not derived.ok: return derived
	var audio_prep: Dictionary = _restore_participants.audio.prepare(
		{"preferences": {"audio": audio_preferences}, "audio_context": derived.value})
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
	var prepared := {"journal_seed": seed.value.candidate,
		"participant_plans": plans, "route_id": snapshot.route_id, "checkpoint_id": snapshot.checkpoint_id}
	_scene_restore_preparation_counter += 1
	var token := "scene_restore_preparation:%d" % _scene_restore_preparation_counter
	_scene_restore_preparations[token] = prepared
	return {"ok": true, "code": &"ok", "value": {"scene_preparation_token": token}}


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
	var admitted: Dictionary = SAVE_DOCUMENT_SCHEMA.admit_document(parsed["value"],
		{"kind": str(resolved["kind"]), "slot_id": resolved["slot_id"]})
	if not admitted.get("ok", false):
		return admitted
	var document: Dictionary = admitted["value"]
	var bundle := _find_bundle_by_checkpoint_id(document, str(locator.get("checkpoint_id", "")))
	if bundle.is_empty():
		return _fail(&"source_bundle_not_found", str(locator.get("checkpoint_id", "")))
	var context: Dictionary = bundle["snapshot"]
	var context_hash := CANONICAL_JSON.sha256(context)
	if context_hash.is_empty():
		return _fail(&"context_not_canonicalizable", "")
	return {"ok": true, "code": &"ok", "value": {
		"context": context, "context_sha256": context_hash,
	}}

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

func _write_document_text_validator(text: String, validated_texts: Dictionary) -> Dictionary:
	if validated_texts.has(text):
		return {"ok": true, "code": &"ok", "value": {}}
	var result := _document_text_validator(text)
	if not result.get("ok", false) or typeof(result.get("value")) != TYPE_DICTIONARY:
		return result
	validated_texts[text] = {"ok": true, "code": &"ok", "value": {}}
	return {"ok": true, "code": &"ok", "value": {}}

func _document_text_validator(text: String) -> Dictionary:
	var parsed: Dictionary = _parse_document_text(text, true)
	if not parsed.get("ok", false):
		return {"ok": false, "code": &"invalid_json", "message": "strict parse failed"}
	var validated: Dictionary = SAVE_DOCUMENT_SCHEMA.validate(parsed["value"])
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": validated["value"]["candidate"]}

func _parse_document_text(text: String, borrow_cached: bool = false) -> Dictionary:
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
			var cached: Dictionary = entry["parsed"]
			return _save_load_profile_finish(profile, cached if borrow_cached else cached.duplicate(true))
	var parsed := STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return _save_load_profile_finish(profile, parsed)
	var text_bytes := text.to_utf8_buffer().size()
	if text_bytes > _PARSE_CACHE_MAX_TEXT_BYTES:
		return _save_load_profile_finish(profile, parsed)
	while not _document_parse_cache.is_empty() and (
		_document_parse_cache.size() >= _PARSE_CACHE_MAX_ENTRIES
		or _document_parse_cache_text_bytes + text_bytes > _PARSE_CACHE_MAX_TEXT_BYTES):
		var oldest: Dictionary = _document_parse_cache.pop_front()
		_document_parse_cache_text_bytes -= int(oldest["text_bytes"])
	_document_parse_cache.append({"text": text, "text_bytes": text_bytes,
		"parsed": parsed})
	_document_parse_cache_text_bytes += text_bytes
	return _save_load_profile_finish(profile, parsed if borrow_cached else parsed.duplicate(true))

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

func _validate_scene_restore_preparation(prepared: Dictionary) -> Dictionary:
	if prepared.size() != 1: return _fail(&"invalid_prepared_restore", "expected a scene preparation token")
	var token: Variant = prepared.get("scene_preparation_token")
	if not token is String or not _scene_restore_preparations.has(token):
		return _fail(&"invalid_scene_restore_preparation", "selected preparation is unavailable")
	return {"ok": true}

func retry_scene_activation(transaction_id: String) -> Dictionary:
	if _completed_scene_restore.get("transaction_id") == transaction_id:
		return capture_scene_restore_activation(transaction_id)
	if _scene_activation_busy or _scene_restore_commit_busy: return _fail(&"scene_restore_busy", "")
	if not _scene_restore_activation.is_empty():
		if _scene_restore_activation.operation_id != transaction_id: return _fail(&"scene_restore_busy", "")
		return _drive_scene_restore_activation()
	return _fail(&"scene_activation_unavailable", "")

func capture_scene_restore_activation(transaction_id: String) -> Dictionary:
	if _completed_scene_restore.get("transaction_id") != transaction_id:
		return _fail(&"scene_restore_not_activated", "Load has not reached live-session readiness")
	return {"ok": true, "transaction_id": transaction_id, "value": _completed_scene_restore.duplicate()}

func _run_scene_restore_transaction(plans: Dictionary, journal_candidate: Dictionary,
		route_id: String, checkpoint_id: String, operation_id: String, creating: bool) -> Dictionary:
	if not _scene_restore_activation.is_empty(): return _fail(&"scene_restore_busy", "")
	var activation := _prepare_live_session_activation(plans, operation_id)
	if not activation.get("ok", false):
		return _scene_restore_early_failure(activation, creating)
	for key: String in ["route", "narrative"]:
		var participant: Object = _restore_participants[key]
		for method: String in ["begin_scene_activation", "validate_scene_activation", "publish_scene_activation"]:
			if not participant.has_method(method):
				return _scene_restore_early_failure(_fail(&"scene_activation_owner_unavailable", key + "." + method), creating)
		if not participant.has_signal("scene_activation_confirmed"):
			return _scene_restore_early_failure(_fail(&"scene_activation_owner_unavailable", key), creating)
	var held: Dictionary = _restore_participants.route.begin_scene_publication_hold(operation_id)
	if not held.get("ok", false): return _scene_restore_early_failure(held, creating)
	var backups := {}
	var applied: Array[String] = []
	for key: String in _SCENE_PARTICIPANT_ORDER:
		if key in ["profile", "localization"] and plans[key].get("reuse_current", false): continue
		var backup: Dictionary = _restore_participants[key].capture()
		if not backup.get("ok", false):
			return _scene_restore_prepare_failure(backup, creating, applied, backups, operation_id)
		backups[key] = backup.value
	var route_token: Dictionary = {}
	for key: String in backups:
		var plan: Dictionary = plans[key]
		if key == "narrative":
			plan = plan.duplicate()
			plan["route_ready_token"] = route_token
			plan["scene_restore_operation_id"] = operation_id
			plan["read_only_restore"] = not creating
		var result: Dictionary = _restore_participants[key].apply_silent(plan)
		if not result.get("ok", false):
			return _scene_restore_prepare_failure(result, creating, applied, backups, operation_id)
		applied.append(key)
		if key == "route": route_token = result.get("value", {}).get("route_ready_token", {})
	var seeded: Dictionary = _journal._install_prepared(journal_candidate.duplicate(true) if creating else journal_candidate)
	if not seeded.get("ok", false):
		return _scene_restore_prepare_failure(seeded, creating, applied, backups, operation_id)
	if not creating:
		_restore_participants.run.activate_loaded_session(activation.value)
	_scene_restore_activation = {"operation_id": operation_id, "ticket": activation.value, "route_id": route_id,
		"owner": &"new_run" if creating else &"restore",
		"checkpoint_id": checkpoint_id, "phase": "route", "route_confirmed": false,
		"narrative_confirmed": false, "started": false, "failure": {}}
	for key: String in applied:
		var finalized: Dictionary = _restore_participants[key].finalize()
		if not finalized.get("ok", false): return _scene_restore_activation_failure(finalized)
	for key: String in ["route", "narrative"]:
		var callback: Callable = _on_scene_route_confirmed if key == "route" else _on_scene_narrative_confirmed
		if not _restore_participants[key].is_connected("scene_activation_confirmed", callback):
			_restore_participants[key].connect("scene_activation_confirmed", callback)
	if not _restore_participants.narrative.is_connected("scene_activation_failed", _on_scene_restore_failed):
		_restore_participants.narrative.connect("scene_activation_failed", _on_scene_restore_failed)
	return _drive_scene_restore_activation()

func _scene_restore_prepare_failure(failure: Dictionary, creating: bool, applied: Array[String],
		backups: Dictionary, operation_id: String) -> Dictionary:
	if creating:
		return _fatal_transaction_recovery("scene_restore", [{"owner_id": "restore", "operation": "reconstruct", "result": failure}])
	var cancelled: Dictionary = _restore_participants.route.cancel_scene_publication_hold(operation_id)
	if not cancelled.get("ok", false):
		return _fatal_transaction_recovery("scene_restore", [{"owner_id": "route", "operation": "cancel_hold", "result": cancelled}])
	return _rollback_transaction(&"restore", applied, backups, "", _lock_owner == &"restore", failure)

func _scene_restore_early_failure(failure: Dictionary, creating: bool) -> Dictionary:
	if creating:
		return _fatal_transaction_recovery("scene_restore", [{"owner_id": "restore", "operation": "reconstruct", "result": failure}])
	_release_transaction(&"restore", "", _lock_owner == &"restore")
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
	var activation_owner: StringName = _scene_restore_activation.owner
	if activation_owner == &"new_run":
		if _mutation_gate == null or not _mutation_gate.is_lease_active(activation_owner, _new_run_gate_token):
			return _scene_restore_activation_failure(_fail(&"scene_restore_lease_lost", ""))
		var ticket: Dictionary = _scene_restore_activation.ticket
		var activated: Dictionary = _restore_participants.run.activate_live_session(ticket)
		if not activated.get("ok", false): return _scene_restore_activation_failure(activated)
	for key: String in ["narrative", "route"]:
		var published: Dictionary = _restore_participants[key].publish_scene_activation(operation_id)
		if not published.get("ok", false): return _scene_restore_activation_failure(published)
	var completed := _scene_restore_activation
	_scene_restore_activation = {}
	var destination := {"transaction_id": operation_id, "checkpoint_id": completed.checkpoint_id,
		"route_id": completed.route_id}
	if activation_owner == &"restore":
		_completed_scene_restore = destination.duplicate()
	else:
		var released := _release_new_run_custody()
		if not released.get("ok", false): return released
	live_session_ready.emit()
	if activation_owner == &"restore": run_restored.emit(completed.checkpoint_id, completed.route_id)
	return {"ok": true, "value": destination}


func _prepare_live_session_activation(plans: Dictionary, operation_id: String) -> Dictionary:
	var plan: Dictionary = plans.get("run", {})
	if not plan.has("snapshot"):
		return {"ok": true, "value": {}}
	var run: Object = _restore_participants["run"]
	if not run.has_method("capture_live_session"):
		return _fail(&"session_owner_unconfigured", "run participant requires live-session ownership")
	var captured: Dictionary = run.capture_live_session()
	if not captured.get("ok", false): return captured
	var session: Dictionary = captured["value"]
	var ticket := {"operation_id": operation_id, "expected_generation": session["generation"],
		"owner_id": session["owner_id"], "run_id": plan["snapshot"]["run_id"]}
	return {"ok": true, "value": ticket}


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

func capture_committed_scene_creation(transaction_id: String) -> Dictionary:
	if _identity_issuer == null or _new_run_profile_owner == null:
		return _fail(&"scene_creation_owner_unavailable", "")
	var history: Script = load("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
	var found: Dictionary = history.get_creation_operation(_storage, _scene_new_run_bundle, _identity_issuer, transaction_id)
	if not found.get("ok", false): return found
	var operation: Dictionary = found.value
	var materials: Dictionary = operation.new_run_materials
	var captured: Dictionary = _identity_issuer.capture_root()
	if not captured.get("ok", false): return captured
	var root: Dictionary = captured.value
	if not CANONICAL_JSON._deep_same(root.get("allocation_receipts", {}).get(transaction_id), materials.allocation_candidate):
		return _fail(&"scene_creation_allocation_unproven", "")
	var profile: Dictionary = _new_run_profile_owner.prove_scene_assignment(materials.allocation_candidate.run_id,
		materials.profile.scene_assignment.receipt)
	if not profile.get("ok", false): return profile
	var initial: Dictionary = _parse_document_text(materials.autosave.outgoing_text, true)
	if not initial.get("ok", false): return initial
	var initial_scene: Variant = initial.value.current_snapshot.snapshot.get("scene")
	if not initial_scene is Dictionary or initial_scene.get("active_occurrence_id") != transaction_id:
		return _fail(&"scene_creation_proof_invalid", "retained initial scene missing")
	return {"ok": true, "value": {
		"allocation_candidate": materials.allocation_candidate, "profile_material": materials.profile,
		"initial_scene": initial_scene.duplicate(true)}}
