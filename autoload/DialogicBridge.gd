extends Node
# DialogicBridge (prompt_docs/requirements/dialogic_skip.md): owns ALL direct Dialogic interaction.
# Safe checked calls only; no arbitrary gameplay effects from DTL; no GameState calls by
# name; no eval; validates timeline IDs against DialogicTimelineCatalog; returns safe error
# dictionaries for unknown IDs / missing files / missing Dialogic. Never crashes.

signal timeline_started(timeline_id: String, path: String)
signal timeline_finished(timeline_id: String, result: Dictionary)
signal timeline_failed(result: Dictionary)
signal timeline_marker_received(marker_id: String, payload: Dictionary)
signal preference_boundary_step(step_id: StringName)

## Narrative/ending seams (dwm-p2r.8, Plan-05 Task 2).
signal narrative_checkpoint_committed(checkpoint: Dictionary)
signal narrative_validation_failed(result: Dictionary)
signal ending_playback_finished(playback_token: String, ending_id: String, receipt: Dictionary)
signal ending_playback_failed(playback_token: String, ending_id: String, result: Dictionary)

const MISSING_DIALOGIC_MESSAGE := "Dialogic 2 addon file does not exist."
const DIALOGIC_CLEAR_KEEP_VARIABLES := 1

const _ENDINGS_MANIFEST_PATH := "res://data/manifests/endings.json"
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _NARRATIVE_PORT_METHODS := ["commit_current_boundary", "preview_checkpoint_id", "capture", "prepare_candidate", "commit", "rollback"]
## Signal payload kinds a timeline may legally raise.
const _RUNTIME_EVENT_KINDS := ["safe_marker", "effect_transaction", "variable_transaction", "scene_transition", "minesweeper_entry"]
const _PLAYBACK_CONTEXT_KEYS := ["expected_stage", "playback_id", "role", "transaction_id"]

# Whitelisted safe marker ids (DTL may only call DialogicBridge.timeline_marker("<id>")).
const _SAFE_MARKERS := [
	"opening_done", "tutorial_done", "hospital_recovered",
	"contact_history_shown", "invitation_offered", "challenge_ready",
	"dating_pre_done", "dating_post_done", "ending_shown",
]

var _current_timeline_id: String = ""
var _current_timeline_context: Dictionary = {}
var _mutation_gate: Object
var _profile: Node
var _preference_adapter: RefCounted
var _cached_preference_plan: Dictionary = {}
var _preferences_bound := false
var _fatal_preference_failure := {}

# --- Task 2 narrative/ending state ---
var _runtime_adapter: RefCounted = null
var _catalog: Script = null
var _ending_records: Dictionary = {}
var _active_playback: Dictionary = {}
var _playback_counter := 0
var _narrative_checkpoint_port: Object = null
var _initialized := false
## The ONE transient, manifest-validated effect/variable event the checkpoint provider may serve.
var _active_transaction: Dictionary = {}


func _ready() -> void:
	pass


func configure_mutation_gate(gate: Object) -> Dictionary:
	if gate == null or not gate.has_signal("capability_changed"):
		return _command_failure(&"invalid_mutation_gate")
	for method in [&"acquire", &"release", &"guard_external", &"is_active", &"get_active_owner", &"is_internal_owner_active", &"latch_fatal", &"is_fatal_latched"]:
		if not gate.has_method(method):
			return _command_failure(&"invalid_mutation_gate")
	if _mutation_gate != null and _mutation_gate.get_instance_id() != gate.get_instance_id():
		return _command_failure(&"mutation_gate_already_configured")
	var already := _mutation_gate != null
	_mutation_gate = gate
	return {"ok": true, "code": &"ok", "value": {"gate_instance_id": gate.get_instance_id(), "already_configured": already}, "receipt": {}}


func bind_profile_preferences(profile: Node, preference_adapter: RefCounted = null) -> Dictionary:
	if _preferences_bound:
		return _command_failure(&"already_initialized")
	if profile == null or not profile.has_method("get_profile_snapshot"):
		return _command_failure(&"invalid_profile_manager")
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic == null:
		return _command_failure(&"dialogic_missing")
	_preference_adapter = preference_adapter
	if _preference_adapter == null:
		_preference_adapter = preload("res://scripts/narrative/DialogicPreferenceAdapter.gd").new()
	var bound: Dictionary = _preference_adapter.call(&"bind", dialogic)
	if not bound.get("ok", false):
		return bound
	var prepared: Dictionary = _preference_adapter.call(&"prepare", profile.call(&"get_profile_snapshot"))
	if not prepared.get("ok", false):
		return prepared
	var applied: Dictionary = _preference_adapter.call(&"apply_silent", prepared["value"])
	if not applied.get("ok", false):
		return applied
	_profile = profile
	_cached_preference_plan = (prepared["value"] as Dictionary).duplicate(true)
	_preferences_bound = true
	if profile.has_signal("preference_changed") and not profile.preference_changed.is_connected(_on_profile_preference_changed):
		profile.preference_changed.connect(_on_profile_preference_changed)
	if dialogic.has_signal("timeline_started") and not dialogic.timeline_started.is_connected(_on_dialogic_timeline_started):
		dialogic.timeline_started.connect(_on_dialogic_timeline_started)
	return {"ok": true, "code": &"ok", "value": _cached_preference_plan.duplicate(true), "receipt": {}}


func apply_profile_preferences(changed_path: StringName = &"") -> Dictionary:
	if not _preferences_bound or _profile == null:
		return _command_failure(&"not_initialized")
	if changed_path != &"" and changed_path not in [
		&"preferences.dialogue.text_speed",
		&"preferences.dialogue.auto_text_speed",
		&"preferences.dialogue.auto_advance_dialogue",
	]:
		return {"ok": true, "code": &"ok", "value": _cached_preference_plan.duplicate(true), "receipt": {}, "unchanged": true}
	var prepared: Dictionary = _preference_adapter.call(&"prepare", _profile.call(&"get_profile_snapshot"))
	if not prepared.get("ok", false):
		return prepared
	var applied: Dictionary = _preference_adapter.call(&"apply_silent", prepared["value"])
	if not applied.get("ok", false):
		return applied
	_cached_preference_plan = (prepared["value"] as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": _cached_preference_plan.duplicate(true), "receipt": {}}


func reapply_cached_preferences_after_clear() -> Dictionary:
	if not _preferences_bound or _cached_preference_plan.is_empty():
		return _command_failure(&"not_initialized")
	return _preference_adapter.call(&"apply_silent", _cached_preference_plan.duplicate(true))


func _on_profile_preference_changed(path: StringName, _value: Variant) -> void:
	var applied := apply_profile_preferences(path)
	if not applied.get("ok", false):
		_latch_preference_fatal(&"committed_preference_apply", applied)


func _on_dialogic_timeline_started(_timeline: Variant = null) -> void:
	var applied := reapply_cached_preferences_after_clear()
	if not applied.get("ok", false):
		_latch_preference_fatal(&"timeline_started_reapply", applied)
		return
	preference_boundary_step.emit(&"profile_preferences_reapplied")


func is_dialogic_available() -> bool:
	# Safe file check + runtime autoload check; never crashes if absent.
	var plugin_present := FileAccess.file_exists("res://addons/dialogic/plugin.cfg")
	var runtime := get_node_or_null("/root/Dialogic")
	return plugin_present and runtime != null


func require_dialogic() -> Dictionary:
	if is_dialogic_available():
		return {"ok": true}
	return {"ok": false, "reason": "dialogic_missing", "message": MISSING_DIALOGIC_MESSAGE}


func start_timeline_id(timeline_id: String, context: Dictionary = {}) -> Dictionary:
	var req := require_dialogic()
	if not req["ok"]:
		var fail := {"ok": false, "reason": "dialogic_missing", "timeline_id": timeline_id, "message": MISSING_DIALOGIC_MESSAGE}
		emit_signal("timeline_failed", fail)
		return fail
	if not DialogicTimelineCatalog.has_timeline_id(timeline_id):
		var fail2 := {"ok": false, "reason": "unknown_timeline_id", "timeline_id": timeline_id}
		emit_signal("timeline_failed", fail2)
		return fail2
	var locale := _current_locale()
	var path := DialogicTimelineCatalog.get_timeline_path(timeline_id, locale)
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		# Permitted English fallback (prompt_docs/requirements/dialogic_skip.md).
		var en_path := DialogicTimelineCatalog.get_timeline_path(timeline_id, "en")
		if ResourceLoader.exists(en_path) or FileAccess.file_exists(en_path):
			path = en_path
		else:
			var fail3 := {"ok": false, "reason": "timeline_file_missing", "timeline_id": timeline_id, "path": path}
			emit_signal("timeline_failed", fail3)
			return fail3
	return _start_at_path(timeline_id, path, context)


func start_timeline_path(path: String, context: Dictionary = {}) -> Dictionary:
	var req := require_dialogic()
	if not req["ok"]:
		var fail := {"ok": false, "reason": "dialogic_missing", "path": path, "message": MISSING_DIALOGIC_MESSAGE}
		emit_signal("timeline_failed", fail)
		return fail
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		var fail2 := {"ok": false, "reason": "timeline_file_missing", "path": path}
		emit_signal("timeline_failed", fail2)
		return fail2
	return _start_at_path("", path, context)


func _start_at_path(timeline_id: String, path: String, context: Dictionary) -> Dictionary:
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic == null or not dialogic.has_method("start"):
		var fail := {"ok": false, "reason": "dialogic_missing", "path": path, "message": MISSING_DIALOGIC_MESSAGE}
		emit_signal("timeline_failed", fail)
		return fail
	_current_timeline_id = timeline_id
	_current_timeline_context = context.duplicate(true)
	if dialogic.has_method("clear"):
		dialogic.call("clear", DIALOGIC_CLEAR_KEEP_VARIABLES)
		preference_boundary_step.emit(&"clear")
	dialogic.call("start", path)
	emit_signal("timeline_started", timeline_id, path)
	return {"ok": true, "timeline_id": timeline_id, "path": path}


func finish_current_timeline(result: Dictionary = {}) -> void:
	var finished_id := _current_timeline_id
	_current_timeline_id = ""
	_current_timeline_context = {}
	emit_signal("timeline_finished", finished_id, result)


func validate_required_timelines() -> Dictionary:
	return DialogicTimelineCatalog.build_missing_timeline_report("en")


func get_required_timeline_paths() -> Array[String]:
	return DialogicTimelineCatalog.get_required_timeline_paths("en")


func get_current_timeline_id() -> String:
	return _current_timeline_id


func get_current_timeline_context() -> Dictionary:
	return _current_timeline_context.duplicate(true)


func timeline_marker(marker_id: String, payload: Dictionary = {}) -> void:
	if not (marker_id in _SAFE_MARKERS):
		push_warning("DialogicBridge: ignoring unknown timeline marker '%s'." % marker_id)
		return
	emit_signal("timeline_marker_received", marker_id, payload)


func _current_locale() -> String:
	var loc := get_node_or_null("/root/LocalizationManager")
	if loc != null and loc.has_method("get_locale"):
		return loc.get_locale()
	return "en"


func _command_failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "details": {}, "receipt": {}}


func _latch_preference_fatal(phase: StringName, result: Dictionary) -> void:
	var failure := {
		"source": "DialogicBridge",
		"phase": String(phase),
		"code": String(result.get("code", &"dialogic_preference_failure")),
		"details": result.duplicate(true),
	}
	_fatal_preference_failure = failure.duplicate(true)
	if _mutation_gate != null:
		_mutation_gate.call(&"latch_fatal", failure.duplicate(true))
	timeline_failed.emit({"ok": false, "code": &"dialogic_preference_failure", "details": failure.duplicate(true), "receipt": {}})


# ---- Narrative restore participant seams (dwm-p2r.5 Task 7) ----
# Semantic narrative checkpoint restore. Phase 2R: exact timeline manifests
# arrive in .8, so apply stores the checkpoint semantically after validating the
# route-ready token the route participant produced. Apply/rollback are silent.

var _narrative_restore_backup: Dictionary = {}
var _pending_resume_token := ""
var _resume_counter := 0


func capture_restore_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"timeline_id": _current_timeline_id,
		"timeline_context": _current_timeline_context.duplicate(true),
	}}}


func apply_restore_silent(plan: Dictionary) -> Dictionary:
	if typeof(plan.get("route_ready_token")) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"missing_route_ready_token", "message": "narrative apply requires the route-ready token"}
	var checkpoint: Dictionary = plan.get("narrative_checkpoint", {}) if typeof(plan.get("narrative_checkpoint")) == TYPE_DICTIONARY else {}
	_narrative_restore_backup = {
		"timeline_id": _current_timeline_id,
		"timeline_context": _current_timeline_context.duplicate(true),
	}
	# Exact post-event restore state machine (dwm-p2r.8, Plan-05 Task 2 Step 2.4). The staged
	# successor must NOT execute during apply/finalize; only the deferred resume unpauses it.
	var position := str(plan.get("position", ""))
	if _runtime_adapter != null and position != "":
		var path := str(plan.get("timeline_path", ""))
		var index := int(plan.get("resume_event_index", 0)) if plan.get("resume_event_index") != null else 0
		match position:
			"revealed_event":
				# Start the exact text event, reapply cached preferences (emitted by the adapter),
				# then finish the reveal. Literal reveal count/tween state is not restored.
				_runtime_adapter.start_timeline(path, index)
				_runtime_adapter.reveal_current_line()
			"before_event":
				_runtime_adapter.set_paused(true)
				_runtime_adapter.start_timeline(path, index)
				_resume_counter += 1
				_pending_resume_token = "resume-%d" % _resume_counter
			"external_route", "timeline_complete":
				pass
			_:
				return {"ok": false, "code": &"invalid_restore_position", "message": position}
	_current_timeline_id = str(checkpoint.get("timeline_id", ""))
	_current_timeline_context = checkpoint.duplicate(true)
	return {"ok": true, "code": &"ok"}


func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	var source: Variant = backup.get("backup", backup)
	if typeof(source) != TYPE_DICTIONARY or not (source as Dictionary).has("timeline_id"):
		return {"ok": false, "code": &"invalid_narrative_backup", "message": "narrative backup requires a timeline_id"}
	_current_timeline_id = str((source as Dictionary)["timeline_id"])
	var ctx: Variant = (source as Dictionary).get("timeline_context", {})
	_current_timeline_context = (ctx as Dictionary).duplicate(true) if typeof(ctx) == TYPE_DICTIONARY else {}
	_narrative_restore_backup = {}
	# Cancel any staged resume: a rolled-back restore must never resume the successor.
	_pending_resume_token = ""
	if _runtime_adapter != null and _runtime_adapter.has_method("restore_captured_state"):
		_runtime_adapter.restore_captured_state(source)
	return {"ok": true, "code": &"ok"}


func finalize_restore() -> Dictionary:
	_narrative_restore_backup = {}
	# before_event only: schedule exactly one deferred resume, after SaveManager releases the gate.
	if _pending_resume_token != "":
		call_deferred("_resume_pending_restore", _pending_resume_token)
	return {"ok": true, "code": &"ok"}


func _resume_pending_restore(token: String) -> void:
	# A rollback or a stale token makes this callback a no-op.
	if token.is_empty() or token != _pending_resume_token:
		return
	_pending_resume_token = ""
	if _runtime_adapter != null and _runtime_adapter.has_method("set_paused"):
		_runtime_adapter.set_paused(false)


# ---- Manifest-backed narrative seam (dwm-p2r.8, Plan-05 Task 2 Step 2.3) ----
# The bridge is the ONLY narrative seam: it resolves endings.json locators, owns the opaque
# playback token, and delegates every runtime call to the injected DialogicRuntimeAdapter.


func initialize(catalog: Script = null, runtime_adapter: RefCounted = null) -> Dictionary:
	_catalog = catalog if catalog != null else preload("res://scripts/data/DialogicTimelineCatalog.gd")
	var loaded := _load_ending_records()
	if not loaded.get("ok", false):
		return loaded
	if runtime_adapter != null:
		if _runtime_adapter != null and _runtime_adapter != runtime_adapter:
			return _command_failure(&"runtime_adapter_already_bound")
		_runtime_adapter = runtime_adapter
		if _runtime_adapter.has_signal("timeline_ended_signal") and not _runtime_adapter.timeline_ended_signal.is_connected(_on_runtime_timeline_ended):
			_runtime_adapter.timeline_ended_signal.connect(_on_runtime_timeline_ended)
		if _runtime_adapter.has_signal("runtime_signal_event") and not _runtime_adapter.runtime_signal_event.is_connected(_on_runtime_signal_event):
			_runtime_adapter.runtime_signal_event.connect(_on_runtime_signal_event)
	_initialized = true
	return {"ok": true, "code": &"ok", "value": {"ending_count": _ending_records.size()}, "receipt": {}}


func configure_narrative_checkpoint_port(port: Object) -> Dictionary:
	if port == null:
		return _command_failure(&"invalid_narrative_checkpoint_port")
	for method in _NARRATIVE_PORT_METHODS:
		if not port.has_method(method):
			return _command_failure(&"invalid_narrative_checkpoint_port")
	if _narrative_checkpoint_port != null and _narrative_checkpoint_port.get_instance_id() != port.get_instance_id():
		return _command_failure(&"narrative_checkpoint_port_already_configured")
	var already := _narrative_checkpoint_port != null
	_narrative_checkpoint_port = port
	return {"ok": true, "code": &"ok", "value": {"port_instance_id": port.get_instance_id(), "already_configured": already}, "receipt": {}}


func start_ending_id(ending_id: String, context: Dictionary = {}) -> Dictionary:
	# The only live EndingPlan resolver: primary/epilogue records only.
	if typeof(context) != TYPE_DICTIONARY or not _exact_context_keys(context):
		return _playback_failure(&"invalid_playback_context", "context keys must be exactly " + str(_PLAYBACK_CONTEXT_KEYS))
	var role := String(context["role"])
	if role != "primary" and role != "epilogue":
		return _playback_failure(&"invalid_playback_role", role)
	return _start_playback(ending_id, role)


func start_postscript_id(postscript_id: String) -> Dictionary:
	# Bridge-only capability: it never touches an EndingPlan stage or the Gallery.
	return _start_playback(postscript_id, "postscript")


func provide_transaction_narrative_checkpoint(transaction_id: String, source_id: String, checkpoint_kind: StringName) -> Dictionary:
	# Exact Callable target for the shared adapter. It serves ONLY the one transient, currently
	# validated effect/variable event, and never executes, commits, advances, or looks anything up.
	if transaction_id.is_empty() or source_id.is_empty():
		return _command_failure(&"invalid_transaction_identity")
	if String(checkpoint_kind) not in ["effect_transaction", "variable_transaction"]:
		return _command_failure(&"invalid_checkpoint_kind")
	if _active_transaction.is_empty():
		return _command_failure(&"no_active_transaction")
	if str(_active_transaction["transaction_id"]) != transaction_id \
			or str(_active_transaction["source_id"]) != source_id \
			or String(_active_transaction["kind"]) != String(checkpoint_kind):
		return _command_failure(&"transaction_identity_mismatch")
	return {"ok": true, "code": &"ok",
		"value": {"narrative_checkpoint": (_active_transaction["narrative_checkpoint"] as Dictionary).duplicate(true)},
		"receipt": {}}


## Routes a validated effect/variable signal payload into GameState's atomic commit
## (dwm-p2r.8, Plan-05 Task 3). The injected shared gate is consulted as the FIRST operation:
## a gate failure returns before manifest lookup, transient-boundary creation, provider exposure,
## or any GameState invocation.
func _handle_narrative_transaction(kind: String, payload: Dictionary) -> void:
	if _mutation_gate != null:
		var guarded: Variant = _mutation_gate.call(&"guard_external", &"dialogic_narrative_transaction")
		if typeof(guarded) == TYPE_DICTIONARY and not (guarded as Dictionary).get("ok", true):
			narrative_validation_failed.emit((guarded as Dictionary).duplicate(true))
			return
	var transaction_id := str(payload.get("transaction_id", ""))
	var source_id := str(payload.get("source_id", ""))
	if transaction_id.is_empty() or source_id.is_empty():
		narrative_validation_failed.emit({"ok": false, "code": &"invalid_transaction_identity", "details": payload.duplicate(true)})
		return
	var game_state := get_node_or_null("/root/GameState")
	if game_state == null:
		narrative_validation_failed.emit({"ok": false, "code": &"game_state_unavailable", "details": {}})
		return
	# Expose exactly one transient checkpoint for the adapter's provider, then clear it.
	_active_transaction = {
		"kind": kind, "transaction_id": transaction_id, "source_id": source_id,
		"narrative_checkpoint": {"timeline_id": _current_timeline_id, "boundary": {"kind": kind, "transaction_id": transaction_id}},
	}
	var committed: Dictionary = {}
	if kind == "effect_transaction":
		var raw_ids: Variant = payload.get("effect_ids", [])
		if typeof(raw_ids) != TYPE_ARRAY:
			_active_transaction = {}
			narrative_validation_failed.emit({"ok": false, "code": &"invalid_effect_ids", "details": payload.duplicate(true)})
			return
		# The frozen GameState signature takes Array[String]; normalize before invoking it.
		var effect_ids: Array[String] = []
		for raw: Variant in (raw_ids as Array):
			if typeof(raw) != TYPE_STRING:
				_active_transaction = {}
				narrative_validation_failed.emit({"ok": false, "code": &"invalid_effect_ids", "details": payload.duplicate(true)})
				return
			effect_ids.append(str(raw))
		committed = game_state.commit_effect_transaction(transaction_id, effect_ids, source_id)
	else:
		committed = game_state.commit_variable_transaction(transaction_id, str(payload.get("variable_id", "")), payload.get("value"), source_id)
	_active_transaction = {}
	if not committed.get("ok", false):
		narrative_validation_failed.emit(committed.duplicate(true))


func restore_captured_state(backup: Dictionary) -> Dictionary:
	return rollback_restore_silent(backup)


func _start_playback(ending_id: String, expected_role: String) -> Dictionary:
	if not _initialized:
		return _playback_failure(&"not_initialized", "initialize the bridge first")
	if not _ending_records.has(ending_id):
		return _playback_failure(&"unknown_ending_id", ending_id)
	var record: Dictionary = _ending_records[ending_id]
	if str(record["role"]) != expected_role:
		return _playback_failure(&"ending_role_mismatch", "%s is %s, not %s" % [ending_id, str(record["role"]), expected_role])
	var timeline_id := str(record["timeline_id"])
	var path: String = _catalog.get_timeline_path(timeline_id, "en")
	if path.is_empty():
		return _playback_failure(&"unknown_timeline_id", timeline_id)
	var label := str(record["label"])
	var started: Dictionary = _start_through_runtime(path, label)
	if not started.get("ok", false):
		return started
	_playback_counter += 1
	var token := "playback-%d" % _playback_counter
	_current_timeline_id = timeline_id
	_active_playback = {"token": token, "ending_id": ending_id, "role": expected_role, "timeline_id": timeline_id, "label": label}
	return {"ok": true, "code": &"started", "value": {}, "receipt": {
		"playback_token": token, "ending_id": ending_id, "role": StringName(expected_role),
		"timeline_id": timeline_id, "label": label, "started": true,
	}}


func _start_through_runtime(path: String, label: String) -> Dictionary:
	if _runtime_adapter != null:
		var result: Variant = _runtime_adapter.start_timeline(path, 0)
		if typeof(result) != TYPE_DICTIONARY or not (result as Dictionary).get("ok", false):
			return _playback_failure(&"runtime_start_failed", label)
		return {"ok": true}
	var required := require_dialogic()
	if not required.get("ok", false):
		return _playback_failure(&"dialogic_missing", MISSING_DIALOGIC_MESSAGE)
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic == null or not dialogic.has_method("start"):
		return _playback_failure(&"dialogic_missing", MISSING_DIALOGIC_MESSAGE)
	if dialogic.has_method("clear"):
		dialogic.call("clear", DIALOGIC_CLEAR_KEEP_VARIABLES)
		preference_boundary_step.emit(&"clear")
	dialogic.call("start", path, label)
	return {"ok": true}


func _on_runtime_timeline_ended() -> void:
	if _active_playback.is_empty():
		return
	var playback := _active_playback.duplicate(true)
	_active_playback = {}
	ending_playback_finished.emit(str(playback["token"]), str(playback["ending_id"]),
		{"receipt_id": "%s:complete" % str(playback["token"]), "ending_id": str(playback["ending_id"]), "timeline_id": str(playback["timeline_id"])})


func _on_runtime_signal_event(argument: Variant) -> void:
	if typeof(argument) == TYPE_DICTIONARY and str((argument as Dictionary).get("kind", "")) in _RUNTIME_EVENT_KINDS:
		var kind := str((argument as Dictionary)["kind"])
		if kind == "effect_transaction" or kind == "variable_transaction":
			_handle_narrative_transaction(kind, argument as Dictionary)
		return
	var failure := {"ok": false, "code": &"invalid_runtime_event", "message": "unregistered signal payload", "details": {"argument": argument}}
	if _runtime_adapter != null:
		_runtime_adapter.halt_with_error(failure.duplicate(true))
	narrative_validation_failed.emit(failure.duplicate(true))
	if not _active_playback.is_empty():
		var playback := _active_playback.duplicate(true)
		_active_playback = {}
		ending_playback_failed.emit(str(playback["token"]), str(playback["ending_id"]), failure.duplicate(true))


func _load_ending_records() -> Dictionary:
	var text := FileAccess.get_file_as_string(_ENDINGS_MANIFEST_PATH)
	if text.is_empty():
		return _command_failure(&"ending_manifest_missing")
	var parsed: Dictionary = _STRICT_JSON.parse_object(text)
	if not parsed.get("ok", false):
		return parsed
	var records: Variant = (parsed["value"] as Dictionary).get("records")
	if typeof(records) != TYPE_ARRAY:
		return _command_failure(&"ending_manifest_invalid")
	var by_id := {}
	for record in records:
		if typeof(record) != TYPE_DICTIONARY:
			return _command_failure(&"ending_manifest_invalid")
		by_id[str((record as Dictionary)["ending_id"])] = (record as Dictionary).duplicate(true)
	_ending_records = by_id
	return {"ok": true}


func _exact_context_keys(context: Dictionary) -> bool:
	if context.size() != _PLAYBACK_CONTEXT_KEYS.size():
		return false
	for key in _PLAYBACK_CONTEXT_KEYS:
		if not context.has(key):
			return false
	return true


func _playback_failure(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
