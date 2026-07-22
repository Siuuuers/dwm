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

const MISSING_DIALOGIC_MESSAGE := "Dialogic 2 addon file does not exist."
const DIALOGIC_CLEAR_KEEP_VARIABLES := 1

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
	# Semantic-only in Phase 2R: hold the restored checkpoint without driving the
	# live Dialogic playhead (manifest-aware playback arrives in .8).
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
	return {"ok": true, "code": &"ok"}


func finalize_restore() -> Dictionary:
	_narrative_restore_backup = {}
	return {"ok": true, "code": &"ok"}
