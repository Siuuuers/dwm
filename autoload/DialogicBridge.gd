extends Node
# DialogicBridge (prompt_docs/requirements/dialogic_skip.md): owns ALL direct Dialogic interaction.
# Safe checked calls only; no arbitrary gameplay effects from DTL; no GameState calls by
# name; no eval; validates timeline IDs against DialogicTimelineCatalog; returns safe error
# dictionaries for unknown IDs / missing files / missing Dialogic. Never crashes.

signal timeline_started(timeline_id: String, path: String)
signal timeline_finished(timeline_id: String, result: Dictionary)
signal timeline_failed(result: Dictionary)
signal ordinary_playback_failed(timeline_id: String, result: Dictionary)
## Exact session-abandonment cancellation; consumers release ephemeral ownership only.
signal ordinary_playback_retired(timeline_id: String)
signal entry_playback_failed(playback_token: String, entry_id: String, result: Dictionary)
signal timeline_marker_received(marker_id: String, payload: Dictionary)
signal preference_boundary_step(step_id: StringName)

## Narrative/ending seams (dwm-p2r.8, Plan-05 Task 2).
signal narrative_checkpoint_committed(checkpoint: Dictionary)
signal narrative_validation_failed(result: Dictionary)
signal ending_playback_finished(playback_token: String, ending_id: String, receipt: Dictionary)
signal ending_playback_failed(playback_token: String, ending_id: String, result: Dictionary)
signal ending_playback_retired(playback_token: String, ending_id: String)
signal scene_art_changed
signal reading_session_changed
signal next_traversal_changed
signal _next_runtime_settled

const MISSING_DIALOGIC_MESSAGE := "Dialogic 2 addon file does not exist."
const DIALOGIC_CLEAR_KEEP_VARIABLES := 1
const _SCENE_ART := preload("res://scripts/data/ArtManifest.gd")
const _HOSPITAL_ART := preload("res://scripts/ui/HospitalScene.gd")
const _ART_HOLD_VIEW := preload("res://scripts/ui/witnessed/SceneArtHoldSurface.gd")
var _art_hold: Dictionary = {}
var _art_hold_generation := 0

const _ENDINGS_MANIFEST_PATH := "res://data/manifests/endings.json"
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const _NARRATIVE_PORT_METHODS := ["commit_current_boundary", "preview_checkpoint_id", "capture", "prepare_candidate", "commit", "rollback"]
## Signal payload kinds a timeline may legally raise.
const _RUNTIME_EVENT_KINDS := ["safe_marker", "effect_transaction", "variable_transaction", "scene_transition", "minesweeper_entry"]
const _PLAYBACK_CONTEXT_KEYS := ["expected_stage", "playback_id", "role", "transaction_id"]

## Task 5 semantic-entry surface (Seven-Day Flow Plan 01; dwm-oyo.2 R-AA..R-KK).
const _ENTRY_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _EXECUTION_MODES: Array[StringName] = [&"canonical", &"rehearsal"]
const _RESUME_CHECKPOINT_KEYS := ["content_version", "entry_id", "frozen_context", "stage", "transaction_id"]

# Whitelisted safe marker ids (DTL may only call DialogicBridge.timeline_marker("<id>")).
const _SAFE_MARKERS := [
	"hospital_recovered",
	"contact_history_shown", "invitation_offered", "challenge_ready",
	"dating_pre_done", "dating_post_done", "ending_shown",
]

var _current_timeline_id: String = ""
var _current_timeline_context: Dictionary = {}
## Ephemeral ordinary playback, never inferred from a restored checkpoint cache.
var _ordinary_playback: Dictionary = {}
var _ordinary_speech_counter := 0
var _speech_publication_generation := 0
var _speech_publication: Dictionary = {}
var _speech_append_base: Dictionary = {}
var _speech_append_requested := false
var _start_in_progress := false
var _pause_handle: Dictionary = {}
var _pause_frontier: Dictionary = {}
var _pause_changing := false
var _retired_pause_handle: Dictionary = {}
var _pause_restore: Dictionary = {}
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

# --- Task 5 semantic-entry playback state (Seven-Day Flow Plan 01, dwm-oyo.2 R-AA..R-KK) ---
## The validated entries document, cached statically the way DialogicTimelineCatalog caches its
## registries: nothing is cached until validate_document accepts it, and ONE shared table keeps a
## fresh bridge instance from re-running the published schema over all 139 records (the Task-4
## E05 measurement made that cost a law, not decoration).
static var _entry_document_cache: Dictionary = {}
static var _entry_document_ready := false
var _signal_command_port: Object = null
var _playback_completion_port: Object = null
## The ONE active semantic-entry playback; one process-local token, staleness by exact equality.
var _active_entry: Dictionary = {}
const _READING_SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
var _reading_catalogue_document: Dictionary = {}
var _reading_session: RefCounted
var _reading_restore_pending: Dictionary = {}
var _reading_restore_adoption := false
var _reading_adoption_checkpoint: Dictionary = {}
var _reading_restore_token := ""
var _reading_resume_frontier: Dictionary = {}
const _READING_TRAVERSAL := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
var _next_active := false
var _next_command: Dictionary = {}
var _next_runtime_result: Dictionary = {}
var _next_generation := 0
## Acknowledge ledger keyed by receipt_id, with the SaveManagerNarrativeCheckpointPort
## duplicate/conflict semantics verbatim (R-JJ): an identical replay returns the STORED receipt,
## a conflicting reuse refuses and mutates nothing.
var _signal_receipts: Dictionary = {}


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
	var previous_skip_profile: Object = _skip_profile
	var previous_skip_mode := _skip_mode
	var skip_context := configure_skip_context(profile, prepared["value"]["skip_mode"])
	if not skip_context.get("ok", false):
		return skip_context
	var applied: Dictionary = _preference_adapter.call(&"apply_silent", prepared["value"])
	if not applied.get("ok", false):
		_skip_profile = previous_skip_profile
		_skip_mode = previous_skip_mode
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
		&"preferences.reading.reveal_speed",
		&"preferences.reading.auto_delay",
		&"preferences.reading.auto_enabled",
		&"preferences.reading.skip_mode",
	]:
		return {"ok": true, "code": &"ok", "value": _cached_preference_plan.duplicate(true), "receipt": {}, "unchanged": true}
	var prepared: Dictionary = _preference_adapter.call(&"prepare", _profile.call(&"get_profile_snapshot"))
	if not prepared.get("ok", false):
		return prepared
	var applied: Dictionary = _preference_adapter.call(&"apply_silent", prepared["value"])
	if not applied.get("ok", false):
		return applied
	_cached_preference_plan = (prepared["value"] as Dictionary).duplicate(true)
	set_skip_mode(_cached_preference_plan["skip_mode"])
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
	if not _pause_handle.is_empty():
		return {"ok": false, "reason": "narrative_suspended", "timeline_id": timeline_id}
	if not _active_entry.is_empty():
		# Reviewer I-1: a legacy id start may not physically replace a live semantic entry -
		# the entry branch would later deliver a natural_end intent for prose that was cancelled
		# mid-play. The refusal keeps the legacy failure shape (a reason key, no code).
		var fail0 := {"ok": false, "reason": "semantic_entry_active", "timeline_id": timeline_id,
			"message": "a semantic entry playback is active; abort or complete it first"}
		emit_signal("timeline_failed", fail0)
		return fail0
	if has_active_playback():
		var busy := {"ok": false, "reason": "narrative_playback_active", "timeline_id": timeline_id}
		timeline_failed.emit(busy)
		return busy
	var req := require_dialogic()
	if not req["ok"]:
		var fail := {"ok": false, "reason": "dialogic_missing", "timeline_id": timeline_id, "message": MISSING_DIALOGIC_MESSAGE}
		emit_signal("timeline_failed", fail)
		return fail
	if timeline_id == "hospital.faint" and context.has("presentation"):
		var frozen := preload("res://scripts/narrative/HospitalFrozenContext.gd").validate(context)
		if not frozen.get("ok", false): return frozen
		var semantic_id: String = str(frozen.value.presentation.fields.entry_id)
		var located := _resolve_entry_for_playback(semantic_id, -1)
		if not located.get("ok", false): return located
		return _start_at_path(timeline_id, str(located.value.path), frozen.value, str(located.value.label))
	if not DialogicTimelineCatalog.has_timeline_id(timeline_id):
		var fail2 := {"ok": false, "reason": "unknown_timeline_id", "timeline_id": timeline_id}
		emit_signal("timeline_failed", fail2)
		return fail2
	# Task 5 (R-DD): the deprecated locale-suffixed resolver is retired here. get_path_for_id
	# reads the same single-path registry the old call read while IGNORING its locale argument,
	# so the old locale-then-en double lookup could never produce two different paths and this
	# collapse is behaviour-identical. The on-disk check is unchanged; an id that failed to
	# resolve would land in the same timeline_file_missing refusal via the empty path, though
	# has_timeline_id above already refused every unknown id.
	var located := DialogicTimelineCatalog.get_path_for_id(timeline_id)
	var path := str((located.get("value", {}) as Dictionary).get("path", ""))
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		var fail3 := {"ok": false, "reason": "timeline_file_missing", "timeline_id": timeline_id, "path": path}
		emit_signal("timeline_failed", fail3)
		return fail3
	return _start_at_path(timeline_id, path, context)


## RETIRED for production (Task 5, R-CC): the sole caller moved to start_entry per Ruling Y, and
## a physical path may never again choose what plays. The signature stays byte-exact because the
## frozen schedule gate pins the bridge's declared surface, so retirement is a fail-closed BODY
## in the legacy failure shape (a reason key, no code - DEVIATION-9 item 8), not a deletion.
@warning_ignore("unused_parameter")
func start_timeline_path(path: String, context: Dictionary = {}) -> Dictionary:
	var fail := {"ok": false, "reason": "start_timeline_path_retired", "path": path,
		"message": "production path starts are retired; start_entry is the semantic surface"}
	emit_signal("timeline_failed", fail)
	return fail


## Task 5 (R-BB): the label reaches Dialogic's two-argument start after validation. The legacy
## timeline vocabulary passes the empty label, which is Dialogic's own default and starts at the
## top exactly as the old one-argument call did.
## Presentation-only projection. It never changes the retained command or save checkpoint.
func get_current_scene_art() -> Dictionary:
	var entry_id := ""
	var context: Dictionary = {}
	if not _active_entry.is_empty():
		entry_id = str(_active_entry.get("entry_id", ""))
		context = _active_entry.get("frozen_context", {})
	elif not _active_playback.is_empty():
		entry_id = str(_active_playback.get("presentation_signature", {}).get("entry_id", ""))
	elif not _ordinary_playback.is_empty():
		context = _ordinary_playback.get("context", {})
		entry_id = str(context.get("entry_id", _ordinary_playback.get("timeline_id", "")))
	var show_portraits := not entry_id.is_empty()
	if entry_id == "hospital.faint" and context.get("day") in range(1, 8):
		entry_id += ".day%d" % int(context.day)
	if entry_id == "hospital.faint" or entry_id.begins_with("hospital.faint."):
		show_portraits = false
		if context.has("presentation"):
			show_portraits = _HOSPITAL_ART.art_participants({}, context) == ["sylvia"]
		else:
			var game := get_node_or_null("/root/GameState") if is_inside_tree() else null
			if game != null:
				var contacts: Variant = game.get("contacts")
				if contacts is Dictionary:
					var schedule: Dictionary = game._canonical_committed_schedule() if game.has_method("_canonical_committed_schedule") else {}
					show_portraits = _HOSPITAL_ART.art_participants(contacts, context, schedule) == ["sylvia"]
	return {"entry_id": entry_id, "show_portraits": show_portraits}

## Conservative source proof for an art-only pause before native execution.
static func is_return_only_entry(path: String, label_or_index: Variant) -> bool:
	if not FileAccess.file_exists(path): return false
	if label_or_index is int and label_or_index != 0: return false
	var label := str(label_or_index) if label_or_index is String or label_or_index is StringName else ""
	var selected := label.is_empty()
	for raw_line: String in FileAccess.get_file_as_string(path).split("\n"):
		var line := raw_line.strip_edges()
		if not selected:
			if line == "label " + label: selected = true
			continue
		if line.is_empty() or line.begins_with("#"): continue
		return line == "return"
	return selected

func get_art_hold_view() -> Node:
	var view: Variant = _art_hold.get("view")
	return view if is_instance_valid(view) else null

func _start_with_scene_art(path: String, label_or_index: Variant, allow_art_hold: bool = true) -> Dictionary:
	if allow_art_hold and _try_begin_art_hold(path, label_or_index): return {"ok": true, "code": &"ok"}
	_prepare_scene_art()
	return _runtime_adapter.start_timeline(path, label_or_index)

func _try_begin_art_hold(path: String, label_or_index: Variant) -> bool:
	if not is_inside_tree() or not _art_hold.is_empty() or not is_return_only_entry(path, label_or_index): return false
	var runtime := get_node_or_null("/root/Dialogic")
	if runtime == null or not _runtime_adapter.has_method("is_bound_to_runtime") \
			or not _runtime_adapter.is_bound_to_runtime(runtime): return false
	var source := get_current_scene_art()
	if str(source.entry_id).is_empty(): return false
	_art_hold_generation += 1
	var token := "art-%d-%d" % [get_instance_id(), _art_hold_generation]
	var percent := 100
	var profile := get_node_or_null("/root/ProfileManager")
	if profile != null and profile.has_method("get_preference"):
		percent = int(profile.get_preference(&"preferences.accessibility.text_size", 100))
	var view := _ART_HOLD_VIEW.new()
	if not view.configure(source.entry_id, token, percent, _current_locale(), source.show_portraits):
		view.free()
		return false
	var layer := CanvasLayer.new()
	layer.layer = 20
	layer.name = "SceneArtHold"
	_art_hold = {"token": token, "generation": _art_hold_generation, "path": path,
		"label": label_or_index, "paused": false, "view": view, "layer": layer}
	view.continue_requested.connect(_continue_art_hold)
	layer.add_child(view)
	add_child(layer)
	return true

func _continue_art_hold(token: String) -> void:
	if _art_hold.is_empty() or str(_art_hold.token) != token or _art_hold.paused \
			or not _pause_handle.is_empty() or not _art_hold.view.has_drawn_art(): return
	var retained := _art_hold.duplicate()
	_close_art_hold()
	_start_in_progress = true
	_prepare_scene_art()
	var started: Dictionary = _runtime_adapter.start_timeline(retained.path, retained.label)
	_start_in_progress = false
	if not started.get("ok", false): _on_playback_start_failed(started)

func _close_art_hold() -> void:
	if _art_hold.is_empty(): return
	var retained := _art_hold.duplicate()
	_art_hold.clear()
	if is_instance_valid(retained.view): retained.view.retire()
	if is_instance_valid(retained.layer):
		if retained.layer.get_parent() != null: retained.layer.get_parent().remove_child(retained.layer)
		retained.layer.queue_free()

func _capture_presentation_frontier() -> Dictionary:
	if not _art_hold.is_empty():
		var view := get_art_hold_view()
		if view == null or not view.is_inside_tree() or not view.has_drawn_art():
			return _pause_failure(&"pause_frontier_unavailable")
		return _pause_success({"generation": int(_art_hold.generation), "event_index": -1,
			"request_id": str(_art_hold.token), "paused": bool(_art_hold.paused)})
	return _runtime_adapter.capture_pause_frontier()

func _set_presentation_paused(value: bool) -> Dictionary:
	if not _art_hold.is_empty():
		_art_hold.paused = value
		_art_hold.view.set_presentation_paused(value)
		return _pause_success({"paused": value})
	return _runtime_adapter.set_paused(value)


func _prepare_scene_art() -> void:
	scene_art_changed.emit()
	var source := get_current_scene_art()
	var art: Dictionary = _SCENE_ART.get_scene_art(source.entry_id)
	# Hospital and dating own this caption style even without optional artwork.
	var hospital := str(source.entry_id) == "hospital.faint" or str(source.entry_id).begins_with("hospital.faint.")
	var dating := str(source.entry_id).begins_with("dating.")
	if not hospital and not dating and (str(source.entry_id).is_empty() or (str(art.get("background", "")).is_empty() \
		and art.get("portraits", []).is_empty() and str(art.get("cg", "")).is_empty())): return
	var runtime := get_node_or_null("/root/Dialogic") if is_inside_tree() else null
	# Isolated adapters never borrow the autoload's physical layout.
	if runtime == null or _runtime_adapter == null \
			or not _runtime_adapter.has_method("is_bound_to_runtime") \
			or not _runtime_adapter.is_bound_to_runtime(runtime): return
	var styles: Object = runtime.get_subsystem("Styles")
	if styles != null and styles.has_method("load_style"):
		styles.load_style("res://dialogic/styles/witnessed_caption_style.tres", null, true, false)


func _start_at_path(timeline_id: String, path: String, context: Dictionary, label: String = "") -> Dictionary:
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic == null or not dialogic.has_method("start"):
		var fail := {"ok": false, "reason": "dialogic_missing", "path": path, "message": MISSING_DIALOGIC_MESSAGE}
		emit_signal("timeline_failed", fail)
		return fail
	var caption_styles: Object = null
	# The witnessed Hospital presentation is the physical-presentation owner's only start, and its
	# completion proof is the runtime's own natural end, so it plays the authored timeline itself.
	var witnessed_hospital := timeline_id == "hospital.faint"
	if witnessed_hospital:
		if dialogic.has_method("get_subsystem"):
			caption_styles = dialogic.get_subsystem("Styles")
		if caption_styles == null or not caption_styles.has_method("load_style"):
			var fail := {"ok": false, "reason": "dialogic_style_unavailable", "timeline_id": timeline_id}
			emit_signal("timeline_failed", fail)
			return fail
	var bound := _ensure_runtime_adapter(dialogic)
	if not bound.get("ok", false):
		timeline_failed.emit(bound)
		return bound
	if _runtime_adapter.has_method("is_bound_to_runtime") and not _runtime_adapter.is_bound_to_runtime(dialogic):
		return {"ok": false, "reason": "dialogic_runtime_mismatch", "timeline_id": timeline_id}
	if has_active_playback():
		return {"ok": false, "reason": "narrative_playback_active", "timeline_id": timeline_id}
	if witnessed_hospital and context.has("presentation"):
		var frozen := preload("res://scripts/narrative/HospitalFrozenContext.gd").validate(context)
		if not frozen.get("ok", false): return frozen
		var installed: Dictionary = _runtime_adapter.install_frozen_presentation(frozen.value.presentation)
		if not installed.get("ok", false): return installed
	var before := {"id": _current_timeline_id, "context": _current_timeline_context.duplicate(true)}
	_ordinary_speech_counter += 1
	_start_in_progress = true
	_current_timeline_id = timeline_id
	_current_timeline_context = context.duplicate(true)
	_ordinary_playback = {"timeline_id": timeline_id, "context": context.duplicate(true), "cache_before": before,
		"speech_token": "ordinary-%d" % _ordinary_speech_counter, "content_locale": "en",
		"suppress_first_speech": false}
	scene_art_changed.emit()
	preference_boundary_step.emit(&"clear")
	# An art hold would substitute a canned card for that start and wait on a Continue press, so
	# only a start no owner is waiting on may defer behind one.
	var started: Dictionary = _start_with_scene_art(path, label, not witnessed_hospital)
	_start_in_progress = false
	if not started.get("ok", false):
		if witnessed_hospital and context.has("presentation"): _runtime_adapter.release_frozen_presentation()
		_ordinary_playback = {}
		scene_art_changed.emit()
		_current_timeline_id = before.id
		_current_timeline_context = before.context
		var failed := {"ok": false, "reason": "runtime_start_failed", "timeline_id": timeline_id, "cause": started}
		timeline_failed.emit(failed)
		return failed
	emit_signal("timeline_started", timeline_id, path)
	return {"ok": true, "timeline_id": timeline_id, "path": path}


func _ensure_runtime_adapter(dialogic: Node) -> Dictionary:
	if _runtime_adapter != null:
		return {"ok": true}
	var adapter := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd").new()
	var bound := adapter.bind_runtime(dialogic)
	if not bound.get("ok", false):
		return bound
	_connect_runtime_adapter(adapter)
	return {"ok": true}


func _connect_runtime_adapter(adapter: RefCounted) -> void:
	_runtime_adapter = adapter
	_connect_speech_runtime()
	if adapter.has_signal("reading_frontier_restored") and not adapter.is_connected("reading_frontier_restored", _on_reading_frontier_restored):
		adapter.connect("reading_frontier_restored", _on_reading_frontier_restored)
	if adapter.has_signal("caption_publication_recorded") and not adapter.is_connected("caption_publication_recorded", _on_reading_publication):
		adapter.connect("caption_publication_recorded", _on_reading_publication)
	if adapter.has_signal("timeline_ended_signal") and not adapter.timeline_ended_signal.is_connected(_on_runtime_timeline_ended):
		adapter.timeline_ended_signal.connect(_on_runtime_timeline_ended)
	if adapter.has_signal("runtime_signal_event") and not adapter.runtime_signal_event.is_connected(_on_runtime_signal_event):
		adapter.runtime_signal_event.connect(_on_runtime_signal_event)
	if adapter.has_signal("playback_start_failed") and not adapter.playback_start_failed.is_connected(_on_playback_start_failed):
		adapter.playback_start_failed.connect(_on_playback_start_failed)


func _connect_speech_runtime() -> void:
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic == null or not dialogic.has_method("has_subsystem") \
			or not dialogic.has_method("get_subsystem") or not dialogic.has_subsystem("Text"):
		return
	var text: Object = dialogic.get_subsystem("Text")
	if text == null:
		return
	if text.has_signal("about_to_show_text") and not text.about_to_show_text.is_connected(_on_speech_about_to_show_text):
		text.about_to_show_text.connect(_on_speech_about_to_show_text)
	if text.has_signal("text_started") and not text.text_started.is_connected(_on_speech_text_started):
		text.text_started.connect(_on_speech_text_started)


func _on_speech_about_to_show_text(info: Dictionary) -> void:
	var append_value: Variant = info.get("append", false)
	_speech_append_requested = append_value is bool and bool(append_value)
	_speech_append_base = _speech_publication.duplicate(true) if _speech_append_requested else {}
	_speech_publication_generation += 1
	_speech_publication.clear()


func _on_speech_text_started(_info: Dictionary) -> void:
	var owner := _current_speech_owner()
	var native := _current_native_speech_frontier()
	if owner.is_empty() or native.is_empty():
		_speech_append_base.clear()
		_speech_append_requested = false
		_speech_publication.clear()
		return
	var content_locale := str(owner.get("content_locale", ""))
	var dialogic := get_node_or_null("/root/Dialogic")
	var state: Variant = dialogic.get("current_state_info") if dialogic != null else null
	var display_text := str((state as Dictionary).get("text_parsed", "")) if state is Dictionary else ""
	if content_locale.is_empty() or display_text.strip_edges().is_empty():
		_speech_append_base.clear()
		_speech_append_requested = false
		_speech_publication.clear()
		return
	var identity := {
		"bridge_id": get_instance_id(),
		"owner_kind": owner.kind,
		"owner_token": owner.token,
		"timeline_id": owner.timeline_id,
		"runtime_generation": native.runtime_generation,
		"event_index": native.event_index,
		"segment_index": native.segment_index,
		"publication_generation": _speech_publication_generation,
	}
	if _speech_publication.get("identity", {}) == identity:
		return
	var suppress_replay := bool(owner.get("suppress_first_speech", false))
	if suppress_replay:
		_consume_first_speech_suppression(owner)
	var primary_text := display_text
	if _speech_append_requested:
		var prior_identity: Dictionary = _speech_append_base.get("identity", {})
		var prior_display := str(_speech_append_base.get("display_text", ""))
		var same_source: bool = not prior_identity.is_empty() \
			and prior_identity.get("owner_kind") == identity.owner_kind \
			and str(prior_identity.get("owner_token", "")) == str(identity.owner_token) \
			and str(prior_identity.get("timeline_id", "")) == str(identity.timeline_id) \
			and int(prior_identity.get("runtime_generation", -1)) == int(identity.runtime_generation) \
			and int(prior_identity.get("event_index", -1)) == int(identity.event_index) \
			and int(prior_identity.get("segment_index", -1)) + 1 == int(identity.segment_index) \
			and str(_speech_append_base.get("content_locale", "")) == content_locale
		if not same_source or prior_display.is_empty() or not display_text.begins_with(prior_display) \
				or display_text.length() == prior_display.length():
			# A restored append has no process-local predecessor to prove its suffix against. Retain
			# the exact full display as a suppressed base so only a later proven append may speak.
			if not suppress_replay:
				_speech_append_base.clear()
				_speech_append_requested = false
				_speech_publication.clear()
				return
		else:
			primary_text = display_text.substr(prior_display.length())
	_speech_append_base.clear()
	_speech_append_requested = false
	_speech_publication = {
		"identity": identity,
		"primary_text": primary_text,
		"display_text": display_text,
		"content_locale": content_locale,
		"suppress_replay": suppress_replay,
	}


func _current_native_speech_frontier() -> Dictionary:
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic == null or not dialogic.has_method("get_timeline_generation"):
		return {}
	var state: Variant = dialogic.get("current_state_info")
	if not state is Dictionary:
		return {}
	var event_index: Variant = dialogic.get("current_event_idx")
	if typeof(event_index) != TYPE_INT or int(event_index) < 0:
		return {}
	var segment: Variant = (state as Dictionary).get("text_sub_idx", 0)
	if typeof(segment) != TYPE_INT or int(segment) < 0:
		return {}
	return {"runtime_generation": int(dialogic.call("get_timeline_generation")),
		"event_index": int(event_index), "segment_index": int(segment)}


func _current_speech_owner() -> Dictionary:
	var owner: Dictionary = {}
	if not _active_entry.is_empty():
		owner = {"kind": &"entry", "token": str(_active_entry.get("token", "")),
			"timeline_id": str(_active_entry.get("entry_id", "")),
			"content_locale": str(_active_entry.get("content_locale", "")),
			"suppress_first_speech": bool(_active_entry.get("suppress_first_speech", false))}
	elif not _ordinary_playback.is_empty():
		owner = {"kind": &"ordinary", "token": str(_ordinary_playback.get("speech_token", "")),
			"timeline_id": str(_ordinary_playback.get("timeline_id", "")),
			"content_locale": str(_ordinary_playback.get("content_locale", "")),
			"suppress_first_speech": bool(_ordinary_playback.get("suppress_first_speech", false))}
	elif not _active_playback.is_empty():
		owner = {"kind": &"ending", "token": str(_active_playback.get("token", "")),
			"timeline_id": str(_active_playback.get("timeline_id", "")),
			"content_locale": str(_active_playback.get("content_locale", "")),
			"suppress_first_speech": bool(_active_playback.get("suppress_first_speech", false))}
	if str(owner.get("token", "")).is_empty() or str(owner.get("timeline_id", "")).is_empty() \
			or str(owner.get("content_locale", "")).is_empty():
		return {}
	return owner


func _consume_first_speech_suppression(owner: Dictionary) -> void:
	match owner.kind:
		&"entry":
			if str(_active_entry.get("token", "")) == str(owner.token):
				_active_entry["suppress_first_speech"] = false
		&"ordinary":
			if str(_ordinary_playback.get("speech_token", "")) == str(owner.token):
				_ordinary_playback["suppress_first_speech"] = false
		&"ending":
			if str(_active_playback.get("token", "")) == str(owner.token):
				_active_playback["suppress_first_speech"] = false


## Transient Primary speech projection. It is exact to the current native publication and never
## creates a visited line, speaker identity, receipt, or durable restore field.
func capture_current_speech_presentation() -> Dictionary:
	if _speech_publication.is_empty():
		return _command_failure(&"speech_presentation_unavailable")
	var owner := _current_speech_owner()
	var native := _current_native_speech_frontier()
	var identity: Dictionary = _speech_publication.get("identity", {})
	if owner.is_empty() or native.is_empty() \
			or int(identity.get("bridge_id", 0)) != get_instance_id() \
			or identity.get("owner_kind") != owner.get("kind") \
			or str(identity.get("owner_token", "")) != str(owner.get("token", "")) \
			or str(identity.get("timeline_id", "")) != str(owner.get("timeline_id", "")) \
			or int(identity.get("runtime_generation", -1)) != int(native.runtime_generation) \
			or int(identity.get("event_index", -1)) != int(native.event_index) \
			or int(identity.get("segment_index", -1)) != int(native.segment_index) \
			or int(identity.get("publication_generation", -1)) != _speech_publication_generation \
			or str(_speech_publication.get("content_locale", "")) != str(owner.get("content_locale", "")):
		return _command_failure(&"speech_presentation_changed")
	return {"ok": true, "code": &"ok", "value": _speech_publication.duplicate(true), "receipt": {}}


func _on_playback_start_failed(failure: Dictionary, halt_runtime: bool = false) -> void:
	_close_art_hold()
	if _runtime_adapter != null and _runtime_adapter.has_method("release_frozen_presentation"):
		_runtime_adapter.release_frozen_presentation()
	var ordinary := _ordinary_playback.duplicate(true)
	var ordinary_id := str(_ordinary_playback.get("timeline_id", ""))
	var ending := _active_playback.duplicate(true)
	var entry := _active_entry.duplicate(true)
	var before: Dictionary = ordinary.get("cache_before", ending.get("cache_before", {}))
	_ordinary_playback = {}
	_active_entry = {}
	_active_playback = {}
	scene_art_changed.emit()
	if not before.is_empty():
		_current_timeline_id = str(before.id)
		_current_timeline_context = before.context.duplicate(true)
	if ordinary.has("runtime_before"):
		_restore_playback_started = false
		_pending_resume_token = ""
	if halt_runtime and _runtime_adapter != null:
		_runtime_adapter.halt_with_error(failure.duplicate(true))
	if ordinary.has("runtime_before") and failure.get("code") != &"runtime_playback_replaced":
		# Invalidate a canceled event coroutine before restoring a possibly unpaused state.
		_runtime_adapter.restore_captured_state(ordinary.runtime_before)
	if not _reached_replay.is_empty() and str(entry.get("token", "")) == str(_reached_replay.token):
		var phase: StringName = &"start" if failure.get("code") == &"runtime_start_failed" else &""
		_finish_reached_replay("failed", str(failure.get("code", "replay_failed")), failure.get("code") != &"runtime_playback_replaced", phase)
		return
	if not ordinary_id.is_empty():
		ordinary_playback_failed.emit(ordinary_id, failure.duplicate(true))
	if not entry.is_empty():
		entry_playback_failed.emit(str(entry.token), str(entry.entry_id), failure.duplicate(true))
	if not ending.is_empty():
		ending_playback_failed.emit(str(ending.token), str(ending.ending_id), failure.duplicate(true))
	timeline_failed.emit(failure.duplicate(true))


func validate_required_timelines() -> Dictionary:
	return DialogicTimelineCatalog.build_missing_timeline_report("en")


func get_required_timeline_paths() -> Array[String]:
	return DialogicTimelineCatalog.get_required_timeline_paths("en")


func get_current_timeline_id() -> String:
	return _current_timeline_id


func get_current_timeline_context() -> Dictionary:
	return _current_timeline_context.duplicate(true)


## Zero-argument narrative-checkpoint provider for day-resolution checkpoints (dwm-7e6).
## Returns the cached semantic checkpoint, or {} when no timeline is active -- which
## RunSnapshotSchema accepts as an empty narrative_checkpoint.
func get_current_narrative_checkpoint() -> Dictionary:
	if has_reading_session():
		var captured := capture_reading_checkpoint()
		# A live unsupported frontier must not masquerade as an empty checkpoint.
		return captured.value if captured.ok else {"entry_id": "", "reading_capture_failure": str(captured.get("code", "unavailable"))}
	if _current_timeline_id.is_empty():
		return {}
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
var _restore_playback_started := false


func capture_restore_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"timeline_id": _current_timeline_id,
		"timeline_context": _current_timeline_context.duplicate(true),
		"reading_owner": _reading_session, "reading_pending": _reading_restore_pending.duplicate(),
		"reading_adoption": _reading_restore_adoption,
		"reading_adoption_checkpoint": _reading_adoption_checkpoint.duplicate(true),
		"reading_restore_token": _reading_restore_token,
	}}}


func apply_restore_silent(plan: Dictionary) -> Dictionary:
	if typeof(plan.get("route_ready_token")) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"missing_route_ready_token", "message": "narrative apply requires the route-ready token"}
	if has_active_playback():
		return _playback_failure(&"narrative_playback_active", "restore cannot replace standing playback")
	if has_reading_session(): retire_reading_session()
	_reading_restore_pending = {}
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
			"revealed_event", "before_event":
				var captured: Dictionary = _runtime_adapter.capture_restore_state()
				if not captured.get("ok", false): return captured
				var before := {"id": _current_timeline_id, "context": _current_timeline_context.duplicate(true)}
				_ordinary_speech_counter += 1
				_ordinary_playback = {"timeline_id": str(checkpoint.get("timeline_id", "")),
					"context": checkpoint.duplicate(true), "cache_before": before,
					"runtime_before": captured.get("value", {}).get("backup", {}).duplicate(true),
					"speech_token": "ordinary-%d" % _ordinary_speech_counter, "content_locale": "en",
					"suppress_first_speech": true}
				_current_timeline_id = str(checkpoint.get("timeline_id", ""))
				_current_timeline_context = checkpoint.duplicate(true)
				_restore_playback_started = true
				if position == "before_event": _runtime_adapter.set_paused(true)
				_start_in_progress = true
				_prepare_scene_art()
				var started: Dictionary = _runtime_adapter.start_timeline(path, index)
				_start_in_progress = false
				if not started.get("ok", false):
					_on_playback_start_failed(started)
					return started
				if position == "before_event":
					_resume_counter += 1
					_pending_resume_token = "resume-%d" % _resume_counter
				else:
					# Literal reveal count/tween state is intentionally not restored.
					_runtime_adapter.reveal_current_line()
				return {"ok": true, "code": &"ok"}
			"external_route", "timeline_complete":
				pass
			_:
				return {"ok": false, "code": &"invalid_restore_position", "message": position}
	_current_timeline_id = str(checkpoint.get("timeline_id", ""))
	_current_timeline_context = checkpoint.duplicate(true)
	return {"ok": true, "code": &"ok"}


func rollback_restore_silent(backup: Dictionary) -> Dictionary:
	var reading_backup: Variant = backup.get("backup", backup)
	if reading_backup is Dictionary:
		if not _reading_restore_token.is_empty() and _active_entry.get("token") == _reading_restore_token:
			abort_current_entry(&"reading_restore_rolled_back")
		_reading_session = reading_backup.get("reading_owner")
		_reading_restore_pending = reading_backup.get("reading_pending", {}).duplicate()
		_reading_restore_adoption = bool(reading_backup.get("reading_adoption", false))
		_reading_adoption_checkpoint = reading_backup.get("reading_adoption_checkpoint", {}).duplicate(true)
		_reading_restore_token = str(reading_backup.get("reading_restore_token", ""))
	if is_pause_restore_pending():
		if _pause_restore.get("cancelled", false): return _pause_failure(&"pause_restore_committed")
		# This restore only staged target bytes. The source runtime and its coroutine
		# were never replaced, so rollback must not touch native reveal or pause state.
		_pause_restore["plan"] = {}
		_pause_restore["staged"] = false
		_pause_restore["finalized"] = false
		return _pause_success({"restored": true})
	var source: Variant = backup.get("backup", backup)
	if typeof(source) != TYPE_DICTIONARY or not (source as Dictionary).has("timeline_id"):
		return {"ok": false, "code": &"invalid_narrative_backup", "message": "narrative backup requires a timeline_id"}
	var runtime_before: Dictionary = _ordinary_playback.get("runtime_before", source).duplicate(true)
	if _restore_playback_started:
		_restore_playback_started = false
		_ordinary_playback = {}
		_runtime_adapter.halt_with_error({"ok": false, "code": &"restore_rolled_back"})
	_current_timeline_id = str((source as Dictionary)["timeline_id"])
	var ctx: Variant = (source as Dictionary).get("timeline_context", {})
	_current_timeline_context = (ctx as Dictionary).duplicate(true) if typeof(ctx) == TYPE_DICTIONARY else {}
	_narrative_restore_backup = {}
	# Cancel any staged resume: a rolled-back restore must never resume the successor.
	_pending_resume_token = ""
	if _runtime_adapter != null and _runtime_adapter.has_method("restore_captured_state"):
		_runtime_adapter.restore_captured_state(runtime_before)
	return {"ok": true, "code": &"ok"}


func finalize_restore() -> Dictionary:
	_narrative_restore_backup = {}
	_restore_playback_started = false
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
		_connect_runtime_adapter(runtime_adapter)
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


## Canonical reached recording must name the label that physically played, including
## Alone mode and exceptional full/residue variants; legacy callers keep their old API.
func start_ending_presentation(ending_id: String, context: Dictionary, signature: Dictionary, presentation: Dictionary = {}) -> Dictionary:
	if not _initialized: return _command_failure(&"not_initialized")
	if has_active_playback() or not _pause_handle.is_empty(): return _command_failure(&"narrative_playback_active")
	if not _exact_context_keys(context): return _command_failure(&"invalid_playback_context")
	var checked := _PRESENTATION_SIGNATURE.validate(signature)
	if not checked.ok: return checked
	var entry: Dictionary = _PRESENTATION_SIGNATURE.entry_record(signature.entry_id).value
	var semantic_id := ending_id.trim_suffix(".full").trim_suffix(".residue").replace(".observation", ".observer")
	if entry.ending_id != semantic_id or str(signature.fields.ending_role) != str(context.role):
		return _command_failure(&"ending_presentation_mismatch")
	var resolved := _resolve_entry_for_playback(signature.entry_id, -1)
	if not resolved.ok: return resolved
	if not _ending_records.has(ending_id): return _command_failure(&"unknown_ending_id")
	var timeline_id := str(_ending_records[ending_id].timeline_id)
	var locator: Dictionary = resolved.value
	if not presentation.is_empty():
		var frozen := preload("res://scripts/narrative/FrozenPresentationContext.gd").validate(signature.entry_id, presentation)
		if not frozen.ok: return frozen
		if frozen.value.fields.step_token != context.playback_id or frozen.value.fields.ending_role != str(context.role) \
				or frozen.value.fields.ending_form != signature.fields.ending_form:
			return _command_failure(&"ending_frozen_step_mismatch")
		if _runtime_adapter == null or not _runtime_adapter.has_method("install_frozen_presentation"):
			return _command_failure(&"frozen_context_runtime_unavailable")
		var installed: Dictionary = _runtime_adapter.install_frozen_presentation(frozen.value)
		if not installed.get("ok", false): return installed
	_playback_counter += 1
	var token := "playback-%d" % _playback_counter
	var before := {"id": _current_timeline_id, "context": _current_timeline_context.duplicate(true)}
	_current_timeline_id = timeline_id
	_active_playback = {"token":token, "ending_id":ending_id, "role":str(context.role),
		"stable_playback_id": str(context.playback_id),
		"timeline_id":timeline_id, "label":str(locator.label), "cache_before":before,
		"presentation_signature":signature.duplicate(true),
		"presentation": presentation.duplicate(true),
		"content_locale": str(locator.get("content_locale", "")), "suppress_first_speech": false}
	_start_in_progress = true
	var started := _start_through_runtime(str(locator.path), str(locator.label))
	_start_in_progress = false
	if not started.get("ok", false):
		if str(_active_playback.get("token", "")) == token:
			if not presentation.is_empty(): _runtime_adapter.release_frozen_presentation()
			_active_playback.clear()
			scene_art_changed.emit()
			_current_timeline_id = before.id
			_current_timeline_context = before.context
		return started
	return {"ok":true, "code":&"started", "receipt":{"playback_token":token, "ending_id":ending_id,
		"timeline_id":timeline_id, "label":str(locator.label), "started":true}}


func start_postscript_id(postscript_id: String) -> Dictionary:
	# Bridge-only capability: it never touches an EndingPlan stage or the Gallery.
	return _start_playback(postscript_id, "postscript")


# Gallery has an independent physical completion channel and no canonical command owner.
signal reached_replay_finished(result: Dictionary)
const _PRESENTATION_SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
var _replay_profile: Object
var _reached_replay: Dictionary = {}
const _REPLAY_CARD := preload("res://scripts/ui/Day7PreludeSurface.gd")
const _DATING_PRESENTATION := preload("res://scripts/ui/DatingScene.gd")
var _replay_counter := 0

func configure_reached_replay(profile: Object) -> Dictionary:
	if profile == null or not profile.has_method("get_reached_presentations") \
			or not profile.has_method("get_gallery_discovery_snapshot"):
		return _command_failure(&"invalid_replay_profile")
	if _replay_profile != null and _replay_profile != profile:
		return _command_failure(&"replay_profile_already_configured")
	_replay_profile = profile
	return {"ok": true}

func capture_rehearsal_variables() -> Dictionary:
	if not _initialized: return _command_failure(&"replay_unconfigured")
	if has_active_playback(): return _command_failure(&"narrative_playback_active")
	if _mutation_gate != null:
		var guarded: Dictionary = _mutation_gate.guard_external(&"gallery_replay")
		if not guarded.get("ok", false): return guarded
	var variables: Dictionary = {}
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic != null:
		var current: Variant = dialogic.current_state_info.get("variables", {})
		if not current is Dictionary: return _command_failure(&"invalid_rehearsal_variables")
		variables = current.duplicate(true)
	return {"ok": true, "value": {"variables": variables}}

func replay_reached_signature(signature_id: String) -> Dictionary:
	if not _initialized or _replay_profile == null: return _command_failure(&"replay_unconfigured")
	if has_active_playback() or not _reached_replay.is_empty(): return _command_failure(&"narrative_playback_active")
	if _mutation_gate != null:
		var guarded: Dictionary = _mutation_gate.guard_external(&"gallery_replay")
		if not guarded.get("ok", false): return guarded
	var records: Dictionary = _replay_profile.get_reached_presentations()
	if not records.get("ok", false): return records
	var signature: Dictionary = {}
	for record: Dictionary in records.value.records:
		if str(record.signature_id) == signature_id: signature = record.signature.duplicate(true)
	if signature.is_empty(): return _command_failure(&"presentation_not_reached")
	var checked := _PRESENTATION_SIGNATURE.validate(signature)
	if not checked.ok or checked.value.signature_id != signature_id: return _command_failure(&"invalid_presentation_signature")
	var entry: Dictionary = _PRESENTATION_SIGNATURE.entry_record(signature.entry_id).value
	if entry.ending_id != null:
		var discovered: Dictionary = _replay_profile.get_gallery_discovery_snapshot()
		if not discovered.get("ok", false): return discovered
		var has_discovery := false
		for identity: String in discovered.value.ending_ids:
			if _PRESENTATION_SIGNATURE.semantic_ending_id(identity) == str(entry.ending_id): has_discovery = true
		if not has_discovery: return _command_failure(&"ending_not_discovered")
	elif not _replay_profile.has_method("has_completed_ending") or not _replay_profile.has_completed_ending():
		return _command_failure(&"reached_replay_locked")
	if str(signature.entry_id).ends_with(".residue"):
		return _command_failure(&"gallery_requires_full_presentation")
	var variables: Dictionary = {}
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic != null:
		variables = (dialogic.current_state_info.get("variables", {}) as Dictionary).duplicate(true)
	_replay_counter += 1
	_reached_replay = {"signature_id": signature_id, "signature": signature.duplicate(true),
		"variables": variables, "token": "gallery-%d" % _replay_counter}
	# Date scenes currently present a native phase card around their board. Replay the same
	# frozen presentation without entering the challenge or treating an empty DTL return as it.
	if entry.role in ["solo_pre_challenge", "solo_post_challenge", "pair_pre_challenge_scene", "pair_post_challenge_scene"]:
		var card_started: Dictionary = _begin_reached_date_card(signature)
		if not card_started.get("ok", false): return _reached_start_failure(card_started, signature_id)
		return card_started
	var context := {"expected_stage":"gallery_replay", "playback_id":"gallery-%d" % _replay_counter,
		"role":"gallery", "transaction_id":"gallery-%d" % _replay_counter,
		"presentation_signature":signature.duplicate(true)}
	var started := _begin_entry_playback(signature.entry_id, context, &"rehearsal", "gallery")
	if not started.get("ok", false):
		return _reached_start_failure(started, signature_id)
	return started

func _reached_start_failure(failure: Dictionary, signature_id: String) -> Dictionary:
	# Only allocated replay preparation reaches here. Ordinary admission refusals
	# carry no Retry proof, and live playback replacement is a different failure.
	if str(_reached_replay.get("signature_id", "")) != signature_id:
		return failure # Reentrant replacement already retired this attempt.
	var result := failure.duplicate(true)
	result["failure_phase"] = &"start"
	result["signature_id"] = signature_id
	_finish_reached_replay("failed", str(failure.get("code", "replay_failed")), true, &"start")
	return result

func _begin_reached_date_card(signature: Dictionary) -> Dictionary:
	var locale := "en"
	var localization := get_node_or_null("/root/LocalizationManager")
	if localization != null: locale = str(localization.get_locale())
	if _replay_profile.has_method("get_preference"):
		locale = str(_replay_profile.get_preference("preferences.language.primary_locale_id", locale))
	var projected: Dictionary = _DATING_PRESENTATION.reached_presentation_copy(signature, locale)
	if not projected.get("ok", false): return projected
	if not is_inside_tree(): return _command_failure(&"replay_surface_unavailable")
	var receipt := {"entry_id": signature.entry_id, "signature_id": _reached_replay.signature_id,
		"view_token": _reached_replay.token}
	var card := {"receipt": receipt, "title": projected.value.title, "body": projected.value.body}
	var surface := _REPLAY_CARD.new()
	var configured: Dictionary = surface.configure(card, _acknowledge_reached_date_card, locale)
	if not configured.get("ok", false):
		surface.free()
		return configured
	if _replay_profile.has_method("get_preference") and not surface.bind_typography_preferences(_replay_profile):
		surface.free()
		return _command_failure(&"replay_typography_unavailable")
	_reached_replay["surface"] = surface
	_reached_replay["card"] = card.duplicate(true)
	surface.card_acknowledged.connect(_on_reached_date_card_acknowledged)
	add_child(surface)
	return {"ok": true, "code": &"started", "value": {}, "receipt": {
		"entry_id": signature.entry_id, "playback_token": _reached_replay.token}}

func _acknowledge_reached_date_card(receipt: Dictionary) -> Dictionary:
	if _reached_replay.is_empty() or not _reached_replay.has("surface") \
			or receipt != _reached_replay.card.receipt:
		return _command_failure(&"replay_identity_mismatch")
	var surface: Node = _reached_replay.surface
	if not is_instance_valid(surface) or not _reached_replay.card in surface.get_presentation_history():
		return _command_failure(&"replay_presentation_not_drawn")
	return {"ok": true}

func _on_reached_date_card_acknowledged(receipt: Dictionary, _result: Dictionary) -> void:
	if _reached_replay.is_empty() or not _reached_replay.has("card") \
			or receipt != _reached_replay.card.receipt: return
	_finish_reached_replay("completed")

func cancel_reached_replay(signature_id: String) -> Dictionary:
	if _reached_replay.is_empty(): return {"ok": true}
	if str(_reached_replay.signature_id) != signature_id: return _command_failure(&"replay_identity_mismatch")
	if _reached_replay.has("surface"):
		_finish_reached_replay("cancelled")
		return {"ok": true}
	if str(_active_entry.get("token", "")) != str(_reached_replay.token):
		return _command_failure(&"replay_identity_mismatch")
	var cancelled := abort_current_entry(&"gallery_closed")
	if not cancelled.get("ok", false): return cancelled
	_finish_reached_replay("cancelled")
	return {"ok": true}

func _finish_reached_replay(outcome: String, code: String = "", restore_variables: bool = true, failure_phase: StringName = &"") -> void:
	if _reached_replay.is_empty(): return
	var replay := _reached_replay.duplicate(true)
	_reached_replay.clear()
	if replay.has("surface") and is_instance_valid(replay.surface):
		replay.surface.hide()
		replay.surface.queue_free()
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic != null and restore_variables: dialogic.current_state_info["variables"] = replay.variables.duplicate(true)
	var result := {"signature_id":replay.signature_id, "playback_token":replay.token,
		"outcome":outcome, "code":code}
	if outcome == "failed" and failure_phase != &"": result["failure_phase"] = failure_phase
	reached_replay_finished.emit(result)


# ---- Global read history and boundary-safe skip (dwm-p2r.8, Plan-05 Task 4) ----

const _SKIP_POLICY := preload("res://scripts/narrative/SkipPolicy.gd")

var _skip_profile: Object = null
var _skip_mode: StringName = _SKIP_POLICY.READ_ONLY
var _skip_step_in_progress := false
static var _skip_line_owners: Dictionary = {}
static var _line_witness_stages: Array = []
var _line_presentation: Dictionary = {}
var _line_ack_in_progress := false
var _line_ack_fatal_failure: Dictionary = {}
var _auto_step_in_progress := false


## Binds the ProfileManager that owns global visited history, plus the active skip mode.
func configure_skip_context(profile: Object, mode: StringName) -> Dictionary:
	if profile == null or not profile.has_method("is_line_visited") or not profile.has_method("mark_line_visited"):
		return _command_failure(&"invalid_visited_history_provider")
	if _skip_line_owners.is_empty():
		var entries := _ensure_entry_document()
		if not entries.get("ok", false): return entries
		var ids := _ENTRY_MANIFEST.load_ids_default()
		if not ids.get("ok", false): return ids
		var checked := _ENTRY_MANIFEST.validate_ids_document(ids.value)
		if not checked.get("ok", false): return checked
		var owners := {}
		for line: Dictionary in ids.value.reply_lines:
			owners[line.line_id] = line.owning_entry_id
		for entry: Dictionary in entries.value.entries:
			for atom: Dictionary in entry.get("observer_atoms", []):
				owners[atom.line_id] = entry.entry_id
		for signal_record: Dictionary in ids.value.signals:
			if signal_record.signal_id == "history.line.witness":
				_line_witness_stages = signal_record.allowed_source_stages.duplicate()
		_skip_line_owners = owners
	if _skip_profile != profile:
		_line_presentation.clear()
		_line_ack_fatal_failure.clear()
	_skip_profile = profile
	_skip_mode = mode
	return {"ok": true, "code": &"ok",
		"value": {"mode": _SKIP_POLICY.evaluate(mode, true, &"text")["mode"]}, "receipt": {}}


func set_skip_mode(mode: StringName) -> Dictionary:
	_skip_mode = mode
	return {"ok": true, "code": &"ok", "value": {"mode": mode}, "receipt": {}}


## Read-only UI admission; never reveals, witnesses, or advances an event.
func can_skip_current_line() -> bool:
	return not _next_active and _line_presentation_context({}, false).get("ok", false)


## Next is opt-in to the complete fixed Solo programme and existing durable
## checkpoint owner. Capability queries do not allocate History or write Profile.
func can_next_current_line() -> bool:
	if _next_active or _line_ack_in_progress or _auto_step_in_progress or _skip_step_in_progress \
			or not _has_exact_caption_source() or _mutation_gate == null \
			or _runtime_adapter == null \
			or _narrative_checkpoint_port == null \
			or not _narrative_checkpoint_port.has_method("commit_reading_next") \
			or not _runtime_adapter.has_method("prepare_reading_seek") \
			or not _runtime_adapter.has_method("apply_reading_seek") \
			or not _runtime_adapter.has_signal("reading_seek_finished"):
		return false
	return _line_presentation_context().get("ok", false)


func is_next_traversal_active() -> bool:
	return _next_active


func request_next(expected_frontier: Dictionary) -> Dictionary:
	if _next_active:
		return {"ok": true, "code": &"coalesced", "value": {"active": true}} \
			if expected_frontier == _next_command else _command_failure(&"reading_next_command_conflict")
	if expected_frontier.is_empty() or not can_next_current_line():
		return _command_failure(&"reading_next_unavailable")
	var current := _line_presentation_context(expected_frontier)
	if not current.ok: return current
	if _skip_profile.get_preference(&"preferences.reading.auto_enabled", false):
		return _command_failure(&"reading_next_auto_enabled")
	_retain_line_presentation(current.value)
	# A newly witnessed partial line cannot become traversable inside this same
	# activation. Reveal is not a semantic seek and retains the ordinary frontier.
	if not _runtime_adapter.is_current_line_complete() and not _line_presentation.was_visited \
			and not _line_presentation.unseen_stop_delivered:
		var completed: Dictionary = _runtime_adapter.reveal_current_line(true)
		if not completed.get("ok", false): return completed
		var partial_ack := acknowledge_current_line_presentation(expected_frontier)
		if not partial_ack.get("ok", false): return partial_ack
		_line_presentation.unseen_stop_delivered = true
		return {"ok": true, "code": &"unseen_stop", "value": {"advance": false}}
	var acknowledged := acknowledge_current_line_presentation(expected_frontier)
	if not acknowledged.get("ok", false): return acknowledged
	var source := capture_reading_checkpoint(false)
	if not source.ok: return source
	var revision: int = _skip_profile.get_profile_revision()
	var planned: Dictionary = _reading_session.prepare_next(current.value.caption_publication,
		Callable(_skip_profile, "is_caption_variant_witnessed"))
	if not planned.ok: return planned
	var plan: Dictionary = planned.value
	var target_reading := _READING_TRAVERSAL.project(plan, "destination")
	var source_reading := _READING_TRAVERSAL.project(plan, "source")
	if not target_reading.ok: return target_reading
	if not source_reading.ok: return source_reading
	var candidate := _READING_SESSION.new()
	var configured: Dictionary = candidate.configure(_reading_catalogue_document)
	if not configured.ok: return configured
	var restored: Dictionary = candidate.restore(target_reading.value, plan.entry_id)
	if not restored.ok: return restored
	var destination_line := "" if plan.destination.kind == "completion" else str(plan.destination.caption.beat.line_id)
	var native: Dictionary = _runtime_adapter.prepare_reading_seek(current.value.caption_publication,
		plan.entry_id, _reading_session.catalogue[plan.entry_id].lines, destination_line)
	if not native.get("ok", false): return native
	var before: Dictionary = _line_presentation_context(expected_frontier)
	if not before.get("ok", false) or _skip_profile.get_profile_revision() != revision:
		return _command_failure(&"presentation_frontier_changed")
	var acquired: Dictionary = _mutation_gate.acquire(&"causal_transaction")
	if not acquired.get("ok", false): return acquired
	var lease: String = acquired.value.token
	_next_active = true
	_next_command = expected_frontier.duplicate(true)
	_next_generation += 1
	_next_runtime_result = {}
	next_traversal_changed.emit()
	var operation_id: String = source_reading.value.next_operation.operation_id
	var source_checkpoint: Dictionary = source.value.duplicate(true)
	source_checkpoint.reading_session = source_reading.value
	var saved_source: Dictionary = _narrative_checkpoint_port.commit_reading_next(source_checkpoint, operation_id, "source")
	if not saved_source.get("ok", false): return _finish_next(lease, saved_source)
	if not _next_source_matches(expected_frontier, revision):
		return _finish_next(lease, _next_fatal(&"reading_next_source_replaced", false))
	# A refused destination retains both the exact live source and its now-durable
	# source operation. A new deliberate retry freezes the same deterministic plan.
	_reading_session.next_operation = source_reading.value.next_operation.duplicate(true)
	var destination_checkpoint: Dictionary = source.value.duplicate(true)
	destination_checkpoint.reading_session = target_reading.value
	var saved_target: Dictionary = _narrative_checkpoint_port.commit_reading_next(destination_checkpoint, operation_id, "destination")
	if not saved_target.get("ok", false): return _finish_next(lease, saved_target)
	if not _next_source_matches(expected_frontier, revision):
		return _finish_next(lease, _next_fatal(&"reading_next_source_replaced"))
	var settled := Callable(self, "_on_next_runtime_finished").bind(_next_generation)
	_runtime_adapter.connect("reading_seek_finished", settled)
	_reading_session = candidate
	var applied: Dictionary = _runtime_adapter.apply_reading_seek(native.value, candidate.ledger, target_reading.value.frontier)
	if applied.get("ok", false) and applied.get("value", {}).get("pending", false) and _next_runtime_result.is_empty():
		await _next_runtime_settled
	if _runtime_adapter.is_connected("reading_seek_finished", settled):
		_runtime_adapter.disconnect("reading_seek_finished", settled)
	var result := applied
	if applied.get("ok", false) and not _next_runtime_result.is_empty(): result = _next_runtime_result
	if not result.get("ok", false):
		return _finish_next(lease, _next_fatal(StringName(result.get("code", "reading_next_projection_failed"))))
	return _finish_next(lease, {"ok": true, "code": &"next_complete", "value": {
		"destination": plan.destination.kind, "operation_id": operation_id}, "receipt": saved_target.get("receipt", {})})


func _next_source_matches(frontier: Dictionary, revision: int) -> bool:
	return _line_presentation_context(frontier, false).get("ok", false) \
		and _skip_profile.get_profile_revision() == revision


func _on_next_runtime_finished(result: Dictionary, generation: int) -> void:
	if not _next_active or generation != _next_generation or not _next_runtime_result.is_empty(): return
	_next_runtime_result = result.duplicate(true)
	_next_runtime_settled.emit()


func _next_fatal(code: StringName, destination_durable: bool = true) -> Dictionary:
	_mutation_gate.latch_fatal({"source": "DialogicBridge", "phase": "reading_next",
		"code": str(code), "details": {"destination_durable": destination_durable}})
	return {"ok": false, "code": code, "fatal": true}


func _finish_next(lease: String, result: Dictionary) -> Dictionary:
	var returned := result.duplicate(true)
	if _mutation_gate.is_fatal_latched():
		returned["fatal"] = true
	else:
		var released: Dictionary = _mutation_gate.release(&"causal_transaction", lease)
		if not released.get("ok", false): returned = _next_fatal(&"reading_next_lease_lost")
	_next_active = false
	_next_command = {}
	next_traversal_changed.emit()
	reading_session_changed.emit()
	return returned


## Physical Dating saves retain a completed Next's semantic History. The next
## admitted entry or final route retirement can then supersede this operation.
func capture_next_physical_checkpoint() -> Dictionary:
	if not has_reading_session() or _reading_session.next_operation.is_empty():
		return {"ok": true, "value": {}}
	if _reading_session.boundary != "between_entries":
		return _command_failure(&"reading_next_physical_boundary_invalid")
	return capture_reading_checkpoint(false)


func is_rehearsal_playback() -> bool:
	return not _reached_replay.is_empty() or _active_entry.get("execution_mode", &"canonical") == &"rehearsal"


## Only registered, single-line canonical sources participate in this acknowledgement.
## Legacy/unregistered prose and rehearsal retain their existing presentation owners.
func requires_line_presentation_acknowledgement() -> bool:
	return not _active_entry.is_empty() and not is_rehearsal_playback() \
		and _line_witness_stage_allowed() \
		and _runtime_adapter != null and (_has_exact_caption_source() \
			or _skip_line_owners.has(str(_runtime_adapter.current_line_id())))


## Pure final admission for automatic input; never retries a Profile write.
func is_current_line_presentation_acknowledged() -> bool:
	var current := _line_presentation_context()
	return current.get("ok", false) and _line_presentation.get("identity") == current.value \
		and _line_presentation.get("acknowledged", false) \
		and _is_presentation_witnessed(current.value)


## Opaque proof of the rendered source, even while a transaction temporarily owns writes.
func capture_current_line_presentation_frontier() -> Dictionary:
	return _line_presentation_context({}, false)


## The host timer may advance only an acknowledged, fully revealed ordinary line.
func can_auto_advance_current_line() -> bool:
	return not _next_active and not _auto_step_in_progress and not _skip_step_in_progress \
		and not _line_ack_in_progress and _auto_line_context().get("ok", false)


func request_auto_step(expected_frontier: Dictionary) -> Dictionary:
	if expected_frontier.is_empty(): return _command_failure(&"presentation_frontier_changed")
	if _next_active or _auto_step_in_progress or _skip_step_in_progress or _line_ack_in_progress:
		return _command_failure(&"reading_command_in_progress")
	_auto_step_in_progress = true
	var admitted := _auto_line_context(expected_frontier)
	if not admitted.get("ok", false):
		_auto_step_in_progress = false
		return admitted
	var result: Dictionary = _runtime_adapter.advance_one_event()
	_auto_step_in_progress = false
	return result


func _auto_line_context(expected_frontier: Dictionary = {}) -> Dictionary:
	var current := _line_presentation_context(expected_frontier)
	if not current.get("ok", false): return current
	if not _skip_profile.has_method("get_preference") \
			or not _skip_profile.get_preference(&"preferences.reading.auto_enabled", false):
		return _command_failure(&"auto_off")
	if _line_presentation.get("identity") != current.value \
			or not _line_presentation.get("acknowledged", false) \
			or not _is_presentation_witnessed(current.value):
		return _command_failure(&"auto_line_unacknowledged")
	if not _runtime_adapter.has_method("is_current_line_complete") \
			or not _runtime_adapter.is_current_line_complete():
		return _command_failure(&"auto_line_revealing")
	if _runtime_adapter.classify_next_event() != &"text":
		return _command_failure(&"auto_boundary")
	return _line_presentation_context(current)


## Called after the renderer accepts a registered line, or on a fresh explicit retry.
## The write is the existing atomic Profile mutation, never a per-line run checkpoint.
func acknowledge_current_line_presentation(expected_frontier: Dictionary) -> Dictionary:
	if expected_frontier.is_empty(): return _command_failure(&"presentation_frontier_changed")
	if _next_active: return _command_failure(&"reading_command_in_progress")
	if _line_ack_in_progress: return _command_failure(&"presentation_acknowledgement_in_progress")
	var current := _line_presentation_context(expected_frontier)
	if not current.get("ok", false): return current
	var identity: Dictionary = current.value
	_retain_line_presentation(identity)
	if not _line_presentation.acknowledged:
		_line_ack_in_progress = true
		var marked: Dictionary = _skip_profile.mark_caption_variant_witnessed(
			identity.caption_variant, _reading_session.registry) if identity.has("caption_variant") \
			else _skip_profile.mark_line_visited(str(identity.line_id))
		_line_ack_in_progress = false
		if (marked.get("fatal", false) or marked.get("code") == &"indeterminate_commit") \
				and is_instance_valid(_skip_profile) and _skip_profile.get_instance_id() == identity.profile_id:
			_line_ack_fatal_failure = marked.duplicate(true)
		# Profile publication is synchronous: it may replace or pause this source.
		var after := _line_presentation_context(expected_frontier)
		if not _line_ack_fatal_failure.is_empty(): return _line_ack_fatal_failure.duplicate(true)
		if not after.get("ok", false) or after.value != identity:
			return _command_failure(&"presentation_frontier_changed")
		if not marked.get("ok", false):
			return marked
		if not _is_presentation_witnessed(identity):
			return _command_failure(&"presentation_frontier_changed")
		_line_presentation.acknowledged = true
	return {"ok": true, "code": &"acknowledged", "value": {}, "receipt": {
		"line_id": identity.line_id, "entry_id": identity.entry_id,
		"playback_token": identity.token, "frontier": identity.frontier.duplicate(true),
		"was_visited_before_presentation": _line_presentation.was_visited}}


func _has_exact_caption_source() -> bool:
	return has_reading_session() and _reading_session.catalogue.has(_active_entry.get("entry_id", ""))


func _line_witness_stage_allowed() -> bool:
	var stage := str(_active_entry.get("stage", ""))
	# Solo's admitted phase frames do not use the legacy current_entry signal stage.
	return stage == str(_active_entry.get("entry_id", "")).get_slice(".", 4) \
		if _has_exact_caption_source() else stage in _line_witness_stages


func _is_presentation_witnessed(identity: Dictionary) -> bool:
	return _skip_profile.is_caption_variant_witnessed(identity.caption_variant) \
		if identity.has("caption_variant") else _skip_profile.is_line_visited(str(identity.line_id))


func _retain_line_presentation(identity: Dictionary) -> void:
	var visited := _is_presentation_witnessed(identity)
	if _line_presentation.get("identity") != identity \
			or (_line_presentation.get("acknowledged", false) and not visited):
		_line_presentation = {"identity": identity.duplicate(true),
			"was_visited": visited, "acknowledged": false, "unseen_stop_delivered": false}


func _line_presentation_context(expected_frontier: Dictionary = {}, guard_mutation: bool = true) -> Dictionary:
	if is_rehearsal_playback(): return _command_failure(&"rehearsal_commit_denied")
	if _active_entry.is_empty(): return _command_failure(&"no_active_entry")
	if guard_mutation and not _line_ack_fatal_failure.is_empty(): return _line_ack_fatal_failure.duplicate(true)
	if not _pause_handle.is_empty() or _pause_changing or (is_inside_tree() and get_tree().paused):
		return _command_failure(&"narrative_suspended")
	if guard_mutation and (not _active_transaction.is_empty() or is_pause_restore_pending()):
		return _command_failure(&"presentation_transaction_active")
	if guard_mutation and _mutation_gate != null:
		var guarded: Dictionary = _mutation_gate.guard_external(&"line_presentation")
		if not guarded.get("ok", false): return guarded
	if not is_instance_valid(_skip_profile) or _runtime_adapter == null:
		return _command_failure(&"skip_context_not_configured")
	var token := str(_active_entry.get("token", ""))
	if token.is_empty(): return _command_failure(&"stale_playback_token")
	var stage := str(_active_entry.get("stage", ""))
	if not _line_witness_stage_allowed(): return _command_failure(&"SIGNAL_STAGE_NOT_ALLOWED")
	var line_id: String = str(_runtime_adapter.current_line_id())
	if line_id.is_empty(): return _command_failure(&"no_current_line")
	var caption_variant := {}
	var caption_publication := {}
	if _has_exact_caption_source():
		if not _skip_profile.has_method("is_caption_variant_witnessed") \
				or not _skip_profile.has_method("mark_caption_variant_witnessed"):
			return _command_failure(&"invalid_caption_witness_provider")
		if not _runtime_adapter.has_method("capture_reading_frontier"):
			return _command_failure(&"reading_frontier_unavailable")
		var publication: Dictionary = _runtime_adapter.capture_reading_frontier()
		if not publication.get("ok", false): return publication
		if publication.value.get("line_id") != line_id:
			return _command_failure(&"presentation_frontier_changed")
		var registered: Dictionary = _reading_session.current_caption_variant(_active_entry.entry_id, publication.value)
		if not registered.get("ok", false): return registered
		caption_variant = registered.value
		caption_publication = publication.value.duplicate(true)
	else:
		if not _skip_line_owners.has(line_id): return _command_failure(&"unregistered_line_id")
		if _skip_line_owners[line_id] != _active_entry.get("entry_id"):
			return _command_failure(&"line_not_owned_by_current_entry")
	# Public Pause capture rejects synchronous startup; this renderer frontier is already live.
	var frontier: Dictionary = _runtime_adapter.capture_pause_frontier()
	if not frontier.get("ok", false): return frontier
	if frontier.value.get("paused", false): return _command_failure(&"narrative_suspended")
	var captured := {"ok": true, "value": {"token": token, "stage": stage,
		"entry_id": _active_entry.entry_id, "line_id": line_id, "frontier": frontier,
		"profile_id": _skip_profile.get_instance_id()}}
	if not caption_variant.is_empty():
		captured.value["caption_variant"] = caption_variant
		captured.value["caption_publication"] = caption_publication
		captured.value["caption_session_id"] = _reading_session.command_id
	if not expected_frontier.is_empty() and captured != expected_frontier:
		return _command_failure(&"presentation_frontier_changed")
	return captured


## One held-skip step, in the exact frozen order: read the PRE-reveal visited state, reveal, mark
## visited, classify the next event WITHOUT consuming it, evaluate, advance only when allowed.
func request_skip_step() -> Dictionary:
	if _next_active: return _command_failure(&"reading_command_in_progress")
	if _auto_step_in_progress:
		return _command_failure(&"reading_command_in_progress")
	if _line_ack_in_progress:
		return _command_failure(&"presentation_acknowledgement_in_progress")
	if _skip_step_in_progress:
		return _command_failure(&"skip_step_in_progress")
	_skip_step_in_progress = true
	var result := _perform_skip_step()
	_skip_step_in_progress = false
	return result


func _perform_skip_step() -> Dictionary:
	if is_rehearsal_playback(): return _command_failure(&"rehearsal_commit_denied")
	if not _pause_handle.is_empty():
		return _command_failure(&"narrative_suspended")
	if _skip_profile == null or _runtime_adapter == null:
		return _command_failure(&"skip_context_not_configured")
	var line_id: String = str(_runtime_adapter.current_line_id())
	if line_id.is_empty():
		return _command_failure(&"no_current_line")
	if _active_entry.is_empty(): return _command_failure(&"line_not_owned_by_current_entry")
	var entry_token: String = str(_active_entry.get("token", ""))
	var frontier: Dictionary = _runtime_adapter.capture_pause_frontier()
	if not frontier.get("ok", false): return frontier
	var presentation := _line_presentation_context()
	if not presentation.get("ok", false): return presentation
	# Freeze the baseline before reveal callbacks or our Profile publication can
	# make this occurrence look previously witnessed. Failed writes retain it.
	_retain_line_presentation(presentation.value)
	var revealed: Dictionary = _runtime_adapter.reveal_current_line(true)
	if not revealed.get("ok", false):
		return revealed
	if not _skip_frontier_matches(frontier, entry_token):
		return _command_failure(&"skip_frontier_changed")
	var marked := acknowledge_current_line_presentation(presentation)
	if not marked.get("ok", false):
		if marked.get("code") == &"presentation_frontier_changed":
			return _command_failure(&"skip_frontier_changed")
		return marked
	if not _skip_frontier_matches(frontier, entry_token):
		return _command_failure(&"skip_frontier_changed")
	var next_boundary: StringName = _runtime_adapter.classify_next_event()
	# Normal publication must not let held Read Only run through a newly encountered line.
	# Deliver that stop once; a later deliberate activation may continue the now-read line.
	var was_visited_before_reveal: bool = _line_presentation.was_visited or _line_presentation.unseen_stop_delivered
	var decision: Dictionary = _SKIP_POLICY.evaluate(_skip_mode, was_visited_before_reveal, next_boundary)
	if decision.mode == _SKIP_POLICY.READ_ONLY and not was_visited_before_reveal \
			and next_boundary != &"validation_error":
		_line_presentation.unseen_stop_delivered = true
	if bool(decision["advance"]):
		var advanced: Dictionary = _runtime_adapter.advance_one_event()
		if not advanced.get("ok", false):
			return advanced
	return {"ok": true, "code": &"ok", "value": decision.duplicate(true), "receipt": {
		"line_id": line_id,
		"was_visited_before_reveal": was_visited_before_reveal,
		"next_boundary": next_boundary,
	}}


func _skip_frontier_matches(frontier: Dictionary, entry_token: String) -> bool:
	return _pause_handle.is_empty() and not _active_entry.is_empty() \
		and str(_active_entry.get("token", "")) == entry_token \
		and _runtime_adapter.capture_pause_frontier() == frontier


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


# ---- Task 5: label-aware, token-bound semantic entry playback (Seven-Day Flow Plan 01) ----
# dwm-oyo.2 DEVIATION-9, rulings R-AA through R-KK, and DEVIATION-10. The bridge stays the only
# narrative seam: it resolves the closed 139-entry vocabulary through the injected catalog's
# get_entry, owns the process-local playback/resume tokens and the acknowledge receipt ledger,
# and delegates every state commitment to the two configured ports. Physical completion advances
# nothing directly - see _on_runtime_timeline_ended.


static func _ensure_entry_document() -> Dictionary:
	if _entry_document_ready:
		return {"ok": true, "value": _entry_document_cache}
	var loaded: Dictionary = _ENTRY_MANIFEST.load_default()
	if not loaded.get("ok", false):
		return loaded
	var validated: Dictionary = _ENTRY_MANIFEST.validate_document(loaded["value"])
	if not validated.get("ok", false):
		return validated
	_entry_document_cache = loaded["value"]
	_entry_document_ready = true
	return {"ok": true, "value": _entry_document_cache}


static func _entry_record(entry_id: String) -> Dictionary:
	var document := _ensure_entry_document()
	if not document.get("ok", false):
		return {}
	for record: Variant in ((document["value"] as Dictionary).get("entries", []) as Array):
		if record is Dictionary and str((record as Dictionary).get("entry_id", "")) == entry_id:
			# A copy, never a reference into the shared static document, so no caller can poison
			# every bridge instance for the process lifetime (reviewer M-4).
			return (record as Dictionary).duplicate(true)
	return {}


static func _exact_keys(target: Dictionary, keys: Array) -> bool:
	if target.size() != keys.size():
		return false
	for key in keys:
		if not target.has(key):
			return false
	return true


func configure_signal_command_port(port: Object) -> Dictionary:
	if port == null or not port.has_method("commit_signal"):
		return _command_failure(&"invalid_signal_command_port")
	if _signal_command_port != null and _signal_command_port.get_instance_id() != port.get_instance_id():
		return _command_failure(&"signal_command_port_already_configured")
	var already := _signal_command_port != null
	_signal_command_port = port
	return {"ok": true, "code": &"ok", "value": {"port_instance_id": port.get_instance_id(), "already_configured": already}, "receipt": {}}


func configure_playback_completion_port(port: Object) -> Dictionary:
	if port == null or not port.has_method("complete_entry"):
		return _command_failure(&"invalid_playback_completion_port")
	if _playback_completion_port != null and _playback_completion_port.get_instance_id() != port.get_instance_id():
		return _command_failure(&"playback_completion_port_already_configured")
	var already := _playback_completion_port != null
	_playback_completion_port = port
	return {"ok": true, "code": &"ok", "value": {"port_instance_id": port.get_instance_id(), "already_configured": already}, "receipt": {}}


## Explicit catalogue injection only. The shipped application leaves this absent
## until authored identities and projection copy have been accepted.
func configure_reading_catalogue(document: Dictionary) -> Dictionary:
	if not _reading_catalogue_document.is_empty():
		return {"ok": true} if _reading_catalogue_document == document else _command_failure(&"reading_catalogue_already_configured")
	var checked := _READING_SESSION.new()
	var admitted: Dictionary = checked.configure(document)
	if not admitted.ok: return admitted
	_reading_catalogue_document = document.duplicate(true)
	return {"ok": true}


func begin_reading_session(command: Dictionary) -> Dictionary:
	var entry_id := str(command.get("timeline_id", ""))
	if _reading_catalogue_document.is_empty(): return {"ok": true, "value": {"enabled": false}}
	var candidate := _READING_SESSION.new()
	var configured: Dictionary = candidate.configure(_reading_catalogue_document)
	if not configured.ok: return configured
	if not candidate.catalogue.has(entry_id) or command.get("context", {}).get("kind") != "solo":
		if not _reading_restore_pending.is_empty() or _reading_restore_adoption:
			return _command_failure(&"reading_restore_command_mismatch")
		retire_reading_session()
		return {"ok": true, "value": {"enabled": false}}
	if _reading_restore_adoption:
		if _reading_session == null or _reading_session.pre_entry_id != entry_id \
				or _reading_session.command_id != command.get("completion_transaction_id") \
				or not _reading_command_matches(command, _reading_adoption_checkpoint):
			return _command_failure(&"reading_restore_command_mismatch")
		_reading_restore_adoption = false
		var receipt := {}
		if not _active_entry.is_empty():
			receipt = {"entry_id": _active_entry.entry_id, "playback_token": _active_entry.token,
				"context_fingerprint": _active_entry.context_fingerprint}
		return {"ok": true, "value": {"enabled": true, "restored": true,
			"checkpoint": _reading_adoption_checkpoint.duplicate(true), "receipt": receipt}}
	if not _reading_restore_pending.is_empty():
		if not _reading_command_matches(command, _reading_restore_pending):
			return _command_failure(&"reading_restore_command_mismatch")
		return {"ok": true, "value": {"enabled": true, "restoring": true}}
	var begun: Dictionary = candidate.begin(str(command.get("completion_transaction_id", "")), entry_id)
	if not begun.ok: return begun
	_reading_session = candidate
	reading_session_changed.emit()
	return {"ok": true, "value": {"enabled": true}}


func _reading_command_matches(command: Dictionary, checkpoint: Dictionary) -> bool:
	var saved: Dictionary = checkpoint.get("reading_session", {}).get("ledger", {})
	var context: Dictionary = saved.get("frozen_context", {})
	if context.get("pre_entry_id") != command.get("timeline_id") \
			or context.get("completion_transaction_id") != command.get("completion_transaction_id"):
		return false
	for frame: Dictionary in saved.get("entry_contexts", {}).values():
		if frame.get("playback_id") != str(command.get("physical_token", "")) + ":" + str(frame.get("expected_stage", "")):
			return false
	return true


func retire_reading_session() -> void:
	_reading_session = null
	_reading_restore_adoption = false
	_reading_adoption_checkpoint = {}
	reading_session_changed.emit()


func has_reading_session() -> bool:
	return _reading_session != null and _reading_session.ledger != null


## Cheap UI projection; full catalogue/sequence capture belongs to activation.
func can_capture_reading_checkpoint() -> bool:
	if _next_active or not has_reading_session() or _reading_session.latest_entry.is_empty() \
			or not _reading_restore_pending.is_empty(): return false
	if _reading_session.boundary == "between_entries": return not has_active_playback()
	return not _active_entry.is_empty() and _active_entry.get("entry_id") == _reading_session.latest_entry \
		and _runtime_adapter != null and _runtime_adapter.has_method("can_capture_reading_frontier") \
		and _runtime_adapter.can_capture_reading_frontier()


func capture_reading_checkpoint(complete_reveal: bool = false) -> Dictionary:
	if complete_reveal and not _pause_handle.is_empty(): return _command_failure(&"narrative_suspended")
	if not can_capture_reading_checkpoint(): return _command_failure(&"reading_frontier_unavailable")
	var frontier := {}
	if _reading_session.boundary == "line":
		var native_frontier: Dictionary = _runtime_adapter.complete_reading_frontier() if complete_reveal \
			else _runtime_adapter.capture_reading_frontier()
		if not native_frontier.ok: return native_frontier
		frontier = native_frontier.value
	var session_snapshot: Dictionary = _reading_session.capture(frontier)
	if not session_snapshot.ok: return session_snapshot
	var entry_id: String = _reading_session.latest_entry
	var context: Dictionary = session_snapshot.value.ledger.entry_contexts[entry_id]
	var document := _ensure_entry_document()
	if not document.ok: return document
	return {"ok": true, "value": {"content_version": int(_reading_session.catalogue[entry_id].content_version),
		"entry_id": entry_id, "frozen_context": context.duplicate(true),
		"manifest_fingerprint": _ENTRY_MANIFEST.fingerprint(document.value),
		"stage": str(context.expected_stage), "transaction_id": str(context.transaction_id),
		"reading_session": session_snapshot.value}}


## The retained Pause owner alone may finish its hidden admitted caption. The
## semantic checkpoint and native event must remain identical while custody holds.
func complete_paused_reading_reveal(handle: Dictionary, text_node: DialogicNode_DialogText) -> Dictionary:
	if _pause_changing or handle.is_empty() or handle != _pause_handle:
		return _pause_failure(&"invalid_suspension_handle")
	var suspended := get_state()
	if not suspended.get("ok", false): return suspended
	var before := capture_reading_checkpoint(false)
	if not before.get("ok", false): return before
	if _runtime_adapter == null or not _runtime_adapter.has_method("complete_paused_reading_frontier"):
		return _command_failure(&"reading_frontier_unavailable")
	_pause_changing = true
	var completed: Dictionary = _runtime_adapter.complete_paused_reading_frontier(text_node)
	_pause_changing = false
	if not completed.get("ok", false): return completed
	var after := capture_reading_checkpoint(false)
	if not after.get("ok", false) or after.value != before.value or not get_state().get("ok", false):
		return _pause_failure(&"pause_source_changed")
	return completed


func get_reading_history() -> Dictionary:
	if not can_capture_reading_checkpoint(): return _command_failure(&"reading_frontier_unavailable")
	var frontier := {}
	if _reading_session.boundary == "line":
		var captured: Dictionary = _runtime_adapter.capture_reading_frontier()
		if not captured.ok: return captured
		frontier = captured.value
	return _reading_session.project(frontier)


## Prepare is pure and validates every frame and occurrence, never a prefix.
## The restore participant supplies independently admitted saved Run contexts.
func validate_reading_checkpoint(checkpoint: Dictionary, entry_contexts: Dictionary = {}) -> Dictionary:
	if _reading_catalogue_document.is_empty(): return _command_failure(&"reading_catalogue_unavailable")
	var keys := _RESUME_CHECKPOINT_KEYS.duplicate()
	keys.append("manifest_fingerprint")
	keys.append("reading_session")
	if not _exact_keys(checkpoint, keys) or not checkpoint.get("reading_session") is Dictionary \
			or not checkpoint.get("entry_id") is String or not checkpoint.get("frozen_context") is Dictionary \
			or typeof(checkpoint.get("content_version")) != TYPE_INT or checkpoint.content_version <= 0:
		return _command_failure(&"reading_checkpoint_invalid")
	var base := checkpoint.duplicate(true)
	base.erase("manifest_fingerprint")
	base.erase("reading_session")
	var semantic := validate_resume_checkpoint(base)
	if not semantic.ok: return semantic
	var document := _ensure_entry_document()
	if not document.ok: return document
	if checkpoint.manifest_fingerprint != _ENTRY_MANIFEST.fingerprint(document.value):
		return _command_failure(&"reading_catalogue_mismatch")
	var candidate := _READING_SESSION.new()
	var configured: Dictionary = candidate.configure(_reading_catalogue_document)
	if not configured.ok: return configured
	var reconstructed: Dictionary = candidate.restore(checkpoint.reading_session, checkpoint.entry_id)
	if not reconstructed.ok: return reconstructed
	var frames: Dictionary = checkpoint.reading_session.ledger.entry_contexts
	if frames.get(checkpoint.entry_id) != checkpoint.frozen_context \
			or (not entry_contexts.is_empty() and frames != entry_contexts):
		return _command_failure(&"reading_context_invalid")
	if candidate.catalogue[checkpoint.entry_id].content_version != checkpoint.content_version:
		return _command_failure(&"reading_catalogue_mismatch")
	for entry_id: String in frames:
		var context: Dictionary = frames[entry_id]
		if not _exact_context_keys(context): return _command_failure(&"reading_context_invalid")
		var validated := _validate_reading_entry(candidate, entry_id)
		if not validated.ok: return validated
	return {"ok": true, "value": {"entry_contexts": frames.duplicate(true)}}


func _validate_reading_entry(session: RefCounted, entry_id: String) -> Dictionary:
	if _runtime_adapter == null or not _runtime_adapter.has_method("validate_reading_entry"):
		return _command_failure(&"reading_catalogue_unavailable")
	var row: Dictionary = session.catalogue[entry_id]
	var resolved := _resolve_entry_for_playback(entry_id, row.content_version)
	if not resolved.ok: return resolved
	return _runtime_adapter.validate_reading_entry(resolved.value.path, resolved.value.label, row.lines)


func stage_reading_restore(checkpoint: Dictionary) -> Dictionary:
	var checked := validate_reading_checkpoint(checkpoint)
	if not checked.ok: return checked
	_reading_restore_pending = checkpoint.duplicate(true)
	_reading_restore_token = ""
	return {"ok": true}


func is_reading_restore_staged() -> bool:
	return not _reading_restore_pending.is_empty()


func _resume_reading_checkpoint(checkpoint: Dictionary, execution_mode: StringName) -> Dictionary:
	if execution_mode != &"canonical": return _command_failure(&"rehearsal_commit_denied")
	var checked := validate_reading_checkpoint(checkpoint)
	if not checked.ok: return checked
	if has_active_playback(): return _command_failure(&"narrative_playback_active")
	var candidate := _READING_SESSION.new()
	var configured: Dictionary = candidate.configure(_reading_catalogue_document)
	if not configured.ok: return configured
	var restored: Dictionary = candidate.restore(checkpoint.reading_session, checkpoint.entry_id)
	if not restored.ok: return restored
	_reading_session = candidate
	_reading_restore_pending = {}
	_reading_restore_adoption = true
	_reading_adoption_checkpoint = checkpoint.duplicate(true)
	if checkpoint.reading_session.boundary == "between_entries":
		reading_session_changed.emit()
		return {"ok": true, "value": {}, "receipt": {}}
	_reading_resume_frontier = checkpoint.reading_session.frontier.duplicate(true)
	var started := _begin_entry_playback(checkpoint.entry_id, checkpoint.frozen_context,
		execution_mode, "resume", checkpoint.content_version)
	if started.get("ok", false): _reading_restore_token = str(started.get("receipt", {}).get("playback_token", ""))
	_reading_resume_frontier = {}
	return started


func _on_reading_frontier_restored(result: Dictionary) -> void:
	if not result.get("ok", false):
		_on_playback_start_failed(result, true)
	reading_session_changed.emit()


func _on_reading_publication(result: Dictionary) -> void:
	if has_reading_session() and not result.get("ok", false):
		_on_playback_start_failed(result, true)
	elif has_reading_session() and not _next_active and not result.get("value", {}).get("duplicate", false):
		# Ordinary playback after a completed/refused Next starts a new frontier.
		# Keep the prior operation in its already durable retained checkpoint.
		_reading_session.next_operation = {}


func start_entry(entry_id: String, context: Dictionary, execution_mode: StringName = &"canonical") -> Dictionary:
	if not _initialized:
		return _playback_failure(&"not_initialized", "initialize the bridge first")
	if not (execution_mode in _EXECUTION_MODES):
		return _playback_failure(&"invalid_execution_mode",
			"%s is not a declared execution mode (canonical or rehearsal)" % String(execution_mode))
	if not _exact_context_keys(context):
		return _playback_failure(&"invalid_playback_context",
			"start_entry context keys must be exactly " + str(_PLAYBACK_CONTEXT_KEYS))
	var presentation := _validate_frozen_projection(entry_id, context)
	if not presentation.ok: return presentation
	return _begin_entry_playback(entry_id, context, execution_mode, "playback")


func resume_entry(checkpoint: Dictionary, execution_mode: StringName = &"canonical") -> Dictionary:
	if checkpoint.has("reading_session"):
		return _resume_reading_checkpoint(checkpoint, execution_mode)
	var checked := _check_resume_checkpoint(checkpoint, execution_mode)
	if not checked.get("ok", false):
		return checked
	return _begin_entry_playback(str(checkpoint["entry_id"]),
		(checked["value"] as Dictionary)["frozen"], execution_mode,
		"resume", int(checkpoint["content_version"]))


## Task 7 (Seven-Day Flow Plan 01; dwm-oyo.2 Ruling 14-A). A PURE validator: it resolves and
## revalidates a durable resume checkpoint and starts NOTHING, so a restore can prove compatibility
## at prepare time and finalize can no longer refuse for a reason prepare never saw. It is composed
## from the SAME two private steps resume_entry uses, so its acceptance set cannot diverge from
## finalize's - the divergence that would otherwise commit a checkpoint journal and then fail past
## its own rollback point.
##
## Its success value reports SEMANTIC fields ONLY. Physical locators never leave this method:
## specification 12.4 and 14.4 forbid a caller storing or inspecting a path or a label. Contrast
## resume_entry's receipt below, which does carry them to the playback caller that starts Dialogic.
##
## entry_already_active is DELIBERATELY not checked here. Activity is a transient runtime
## precondition, not a compatibility property of the save, so a compatible bundle is never rejected
## because playback happens to be live. The restore participant asks has_active_playback() at APPLY
## time instead - see Ruling 15-B and that method's own comment for why the distinction matters.
func validate_resume_checkpoint(checkpoint: Dictionary,
		execution_mode: StringName = &"canonical") -> Dictionary:
	var checked := _check_resume_checkpoint(checkpoint, execution_mode)
	if not checked.get("ok", false):
		return checked
	var resolved := _resolve_entry_for_playback(str(checkpoint["entry_id"]),
		int(checkpoint["content_version"]))
	if not resolved.get("ok", false):
		return resolved
	var fingerprinted := _context_fingerprint((checked["value"] as Dictionary)["frozen"])
	if not fingerprinted.get("ok", false):
		return fingerprinted
	return {"ok": true, "code": &"validated", "value": {
		"content_version": int((resolved["value"] as Dictionary)["content_version"]),
		"context_fingerprint": str((fingerprinted["value"] as Dictionary)["fingerprint"]),
		"entry_id": str(checkpoint["entry_id"]),
		"stage": str(checkpoint["stage"]),
		"transaction_id": str(checkpoint["transaction_id"]),
	}, "receipt": {}}


## Task 7 (dwm-oyo.2 Ruling 15-B). Whether ANY playback is standing - a semantic entry or an
## ending. A pure read: it starts, stops, clears and mutates nothing.
##
## Why a restore needs this at APPLY time rather than at prepare time. SaveManager runs its
## apply_silent loop, then commits the checkpoint journal, then runs its finalize loop; a refusal
## from apply rolls back BEFORE that commit, a refusal from finalize only after it. Activity is
## still not a compatibility property of the save, so validate_resume_checkpoint stays blind to it
## and prepare never rejects a compatible bundle for a transient runtime state - but the refusal
## that IS owed to activity must surface on the recoverable side of the commit.
##
## _begin_entry_playback asks the same question through this method, so the one-active-playback law
## has ONE copy rather than two that can drift apart.
func has_active_playback() -> bool:
	if _reached_replay.has("surface"): return true
	return _start_in_progress or not (_ordinary_playback.is_empty() and _active_entry.is_empty() and _active_playback.is_empty()) \
		or (_runtime_adapter != null and _runtime_adapter.has_method("has_active_playback") and _runtime_adapter.has_active_playback())


## Narrow playback identity check for the retained Dating phase adapter.
func is_entry_playback_active(playback_token: String, entry_id: String) -> bool:
	return not _active_entry.is_empty() and _active_entry.get("token") == playback_token \
		and _active_entry.get("entry_id") == entry_id

func capture_pause_frontier(timeline_id: String = "") -> Dictionary:
	if (int(not _ordinary_playback.is_empty()) + int(not _active_entry.is_empty()) + int(not _active_playback.is_empty())) != 1 or _start_in_progress or not _active_transaction.is_empty() or _restore_playback_started \
		or not _pending_resume_token.is_empty() or _runtime_adapter == null \
		or not _runtime_adapter.has_method("capture_pause_frontier"):
		return _command_failure(&"pause_frontier_unavailable")
	var owned_id: String = str(_ordinary_playback.get("timeline_id", _active_entry.get("entry_id", _active_playback.get("timeline_id", ""))))
	if not timeline_id.is_empty() and owned_id != timeline_id:
		return _command_failure(&"pause_source_mismatch")
	if _mutation_gate != null:
		var guarded: Dictionary = _mutation_gate.guard_external(&"narrative_pause")
		if not guarded.get("ok", false): return guarded
	var captured: Dictionary = _capture_presentation_frontier()
	if not captured.get("ok", false): return captured
	var frontier: Dictionary = captured.value.duplicate(true)
	frontier.erase("paused")
	return {"ok": true, "code": &"ok", "value": frontier}


func begin_suspend(handle: Dictionary) -> Dictionary:
	if not _valid_pause_handle(handle): return _pause_failure(&"invalid_suspension_handle")
	if _pause_changing: return _pause_failure(&"narrative_suspended")
	if not _pause_handle.is_empty():
		if _pause_handle != handle: return _pause_failure(&"narrative_suspended")
		var state := get_state()
		if not state.get("ok", false): return state
		var live := capture_pause_frontier()
		var expected := _pause_frontier.duplicate(true)
		expected.erase("paused")
		if not live.get("ok", false) or live.value != expected:
			return _pause_failure(&"pause_source_changed")
		return _pause_success({"frontier_id": _pause_frontier_id()})
	var captured := capture_pause_frontier()
	if not captured.get("ok", false): return _pause_failure(captured.get("code", &"pause_frontier_unavailable"))
	var runtime_before: Dictionary = _capture_presentation_frontier()
	if not runtime_before.get("ok", false): return _pause_failure(&"pause_frontier_unavailable")
	_pause_handle = handle.duplicate(true)
	_pause_frontier = runtime_before.value.duplicate(true)
	_pause_changing = true
	var paused: Dictionary = _set_presentation_paused(true)
	var after := capture_pause_frontier()
	_pause_changing = false
	if not paused.get("ok", false) or not after.get("ok", false) or after.value != captured.value:
		# Keep custody until the coordinator compensates or enters recovery.
		return _pause_failure(&"pause_source_changed")
	return _pause_success({"frontier_id": _pause_frontier_id()})


func resume(handle: Dictionary) -> Dictionary:
	if _pause_changing or _pause_handle.is_empty() or handle != _pause_handle:
		return _pause_failure(&"invalid_suspension_handle")
	var current := capture_pause_frontier()
	var expected := _pause_frontier.duplicate(true)
	expected.erase("paused")
	if not current.get("ok", false) or current.value != expected:
		return _pause_failure(&"pause_source_changed")
	_pause_changing = true
	var restored: Dictionary = _set_presentation_paused(bool(_pause_frontier.paused))
	_pause_changing = false
	if not restored.get("ok", false): return _pause_failure(&"pause_resume_failed")
	_pause_handle = {}
	_pause_frontier = {}
	return _pause_success({"resumed": true})


func get_state() -> Dictionary:
	if _pause_handle.is_empty(): return _pause_success({"state": &"Active"})
	if _pause_changing: return _pause_failure(&"narrative_runtime_indeterminate")
	var current := capture_pause_frontier()
	var expected := _pause_frontier.duplicate(true)
	expected.erase("paused")
	if not current.get("ok", false) or current.value != expected:
		return _pause_failure(&"narrative_runtime_indeterminate")
	var physical: Dictionary = _capture_presentation_frontier()
	if not physical.get("ok", false) or not physical.value.get("paused", false):
		return _pause_failure(&"narrative_runtime_indeterminate")
	return _pause_success({"state": &"Suspended"})


## Session abandonment cancels this exact suspended runtime. Clearing bridge ownership first
## prevents native end signals from reporting a completed scene or advancing any ending cursor.
func retire_suspended_source(handle: Dictionary) -> Dictionary:
	if _mutation_gate == null or not _mutation_gate.is_internal_owner_active(&"session_abandonment"):
		return _pause_failure(&"session_abandonment_custody_required")
	return _retire_suspended_playback(handle)


func _retire_suspended_playback(handle: Dictionary) -> Dictionary:
	if handle == _retired_pause_handle and _pause_handle.is_empty(): return _pause_success({"retired": true})
	if _pause_handle.is_empty() or handle != _pause_handle or _pause_changing:
		return _pause_failure(&"invalid_suspension_handle")
	if handle != _retired_pause_handle:
		var physical: Dictionary = _capture_presentation_frontier()
		var expected := _pause_frontier.duplicate(true)
		expected["paused"] = true
		if not physical.get("ok", false) or physical.value != expected:
			return _pause_failure(&"pause_source_changed")
		var ordinary := _ordinary_playback.duplicate(true)
		var ending := _active_playback.duplicate(true)
		_ordinary_playback.clear()
		_active_entry.clear()
		_active_playback.clear()
		scene_art_changed.emit()
		_current_timeline_id = ""
		_current_timeline_context.clear()
		_retired_pause_handle = handle.duplicate(true)
		_close_art_hold()
		_runtime_adapter.halt_with_error({"code": &"session_abandoned"})
		# Cancellation is separate from failure: a retired session must not run the
		# scene/coordinator failure handlers or manufacture a physical completion.
		if not ordinary.is_empty():
			ordinary_playback_retired.emit(str(ordinary["timeline_id"]))
		if not ending.is_empty():
			ending_playback_retired.emit(str(ending["token"]), str(ending["ending_id"]))
	# Native clear invalidates the event before its previous pause bit is released.
	# No owned completion remains for the cancellation signal to consume.
	var released: Dictionary = _set_presentation_paused(false)
	if not released.get("ok", false): return released
	_pause_handle.clear()
	_pause_frontier.clear()
	return _pause_success({"retired": true})

## During a witnessed Load, the source stays physically suspended until the new
## session activates. Restore participants stage the target; failure discards only that plan.
func begin_pause_restore(handle: Dictionary) -> Dictionary:
	if _mutation_gate == null or not _mutation_gate.guard_external(&"pause_restore").get("ok", false):
		return _pause_failure(&"pause_restore_unavailable")
	var state := get_state()
	if handle.is_empty() or handle != _pause_handle or not state.get("ok", false) \
			or state.value.state != &"Suspended":
		return _pause_failure(&"pause_source_changed")
	if not _pause_restore.is_empty() and not _pause_restore.get("applied", false):
		return _pause_failure(&"pause_restore_busy")
	_pause_restore = {"handle": handle.duplicate(true), "plan": {}, "semantic": false,
		"staged": false, "finalized": false, "cancelled": false, "applied": false}
	return _pause_success({"staged": true})


func is_pause_restore_pending() -> bool:
	return not _pause_restore.is_empty() and not _pause_restore.get("applied", false)


func stage_pause_restore(plan: Dictionary, semantic: bool) -> Dictionary:
	if not is_pause_restore_pending() or _pause_restore.cancelled \
			or _mutation_gate == null or not _mutation_gate.is_internal_owner_active(&"restore"):
		return _pause_failure(&"pause_restore_unavailable")
	# Restore already owns the gate, so the public get_state()/frontier reader is
	# intentionally unavailable. Verify the identical native source under that custody.
	if _pause_changing or _pause_handle != _pause_restore.handle:
		return _pause_failure(&"pause_source_changed")
	var physical: Dictionary = _capture_presentation_frontier()
	var expected := _pause_frontier.duplicate(true)
	expected["paused"] = true
	if not physical.get("ok", false) or physical.value != expected:
		return _pause_failure(&"pause_source_changed")
	_pause_restore.plan = plan.duplicate(true)
	_pause_restore.semantic = semantic
	_pause_restore.staged = true
	return _pause_success({"staged": true})


func finalize_pause_restore() -> Dictionary:
	if not is_pause_restore_pending() or not _pause_restore.staged or _pause_restore.cancelled:
		return _pause_failure(&"pause_restore_unavailable")
	_pause_restore.finalized = true
	return _pause_success({"deferred": true})


func cancel_pause_restore(handle: Dictionary) -> Dictionary:
	if not is_pause_restore_pending() or _pause_restore.handle != handle or _pause_restore.cancelled \
			or handle != _pause_handle or not get_state().get("ok", false):
		return _pause_failure(&"pause_source_changed")
	_pause_restore.clear()
	return _pause_success({"cancelled": true})


func complete_pause_restore(handle: Dictionary) -> Dictionary:
	if _pause_restore.get("handle") != handle or not _pause_restore.get("finalized", false) \
			or _mutation_gate == null or not _mutation_gate.is_internal_owner_active(&"restore"):
		return _pause_failure(&"pause_restore_unavailable")
	if _pause_restore.applied: return _pause_success({"restored": true})
	if not _pause_restore.cancelled:
		var retired := _retire_suspended_playback(handle)
		# Native cancellation can precede a failed pause-bit release. From this point,
		# retry is forward-only; the old text may never be reinstated or resumed.
		_pause_restore.cancelled = handle == _retired_pause_handle
		if not retired.get("ok", false): return retired
	elif not _pause_handle.is_empty():
		var released := _retire_suspended_playback(handle)
		if not released.get("ok", false): return released
	if _runtime_adapter.has_active_playback():
		await get_tree().process_frame
	if _runtime_adapter.has_active_playback(): return _pause_failure(&"pause_restore_runtime_busy")
	var applied: Dictionary = resume_entry(_pause_restore.plan) if _pause_restore.semantic \
		else apply_restore_silent(_pause_restore.plan)
	if not applied.get("ok", false): return applied
	if not _pause_restore.semantic:
		applied = finalize_restore()
		if not applied.get("ok", false): return applied
	_pause_restore.applied = true
	return _pause_success({"restored": true})


func _pause_frontier_id() -> String:
	return "dialogic:%s:%d:%d" % [_pause_frontier.request_id, _pause_frontier.generation, _pause_frontier.event_index]


static func _valid_pause_handle(handle: Dictionary) -> bool:
	var keys := handle.keys()
	keys.sort()
	return keys == ["generation", "handle_id", "holder", "reason"] \
		and typeof(handle.generation) == TYPE_INT and handle.generation > 0 \
		and typeof(handle.handle_id) == TYPE_STRING and not handle.handle_id.strip_edges().is_empty() \
		and typeof(handle.holder) == TYPE_STRING_NAME and not String(handle.holder).strip_edges().is_empty() \
		and handle.reason == &"universal_pause" and typeof(handle.reason) == TYPE_STRING_NAME


static func _pause_success(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}


static func _pause_failure(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "value": null}


## The six durable-checkpoint checks resume_entry has always made, in this exact order and with
## these exact codes, extracted so the pure validator and the playback path share ONE copy.
func _check_resume_checkpoint(checkpoint: Dictionary, execution_mode: StringName) -> Dictionary:
	if not _initialized:
		return _playback_failure(&"not_initialized", "initialize the bridge first")
	if not (execution_mode in _EXECUTION_MODES):
		return _playback_failure(&"invalid_execution_mode",
			"%s is not a declared execution mode (canonical or rehearsal)" % String(execution_mode))
	if not _exact_keys(checkpoint, _RESUME_CHECKPOINT_KEYS):
		return _playback_failure(&"invalid_resume_checkpoint",
			"resume checkpoint keys must be exactly " + str(_RESUME_CHECKPOINT_KEYS))
	var frozen: Variant = checkpoint["frozen_context"]
	if typeof(frozen) != TYPE_DICTIONARY or not _exact_context_keys(frozen as Dictionary):
		return _playback_failure(&"invalid_playback_context",
			"resume frozen_context keys must be exactly " + str(_PLAYBACK_CONTEXT_KEYS))
	var presentation := _validate_frozen_projection(str(checkpoint["entry_id"]), frozen)
	if not presentation.ok: return presentation
	if str(checkpoint["stage"]) != str((frozen as Dictionary)["expected_stage"]):
		return _playback_failure(&"resume_stage_mismatch",
			"checkpoint stage %s != frozen expected_stage %s"
			% [str(checkpoint["stage"]), str((frozen as Dictionary)["expected_stage"])])
	if str(checkpoint["transaction_id"]) != str((frozen as Dictionary)["transaction_id"]):
		return _playback_failure(&"resume_transaction_mismatch",
			"checkpoint transaction %s != frozen transaction %s"
			% [str(checkpoint["transaction_id"]), str((frozen as Dictionary)["transaction_id"])])
	return {"ok": true, "value": {"frozen": frozen as Dictionary}}


## Catalog resolution, master existence, record presence and the content_version revalidation, in
## this exact order, extracted from _begin_entry_playback so the pure validator cannot hold a
## SECOND copy of the resolution law. expected_version >= 0 revalidates a durable checkpoint
## against the record; -1 is a fresh start.
func _resolve_entry_for_playback(entry_id: String, expected_version: int) -> Dictionary:
	var resolved: Variant = _catalog.get_entry(entry_id, _current_locale())
	if typeof(resolved) != TYPE_DICTIONARY:
		return _playback_failure(&"entry_resolution_failed", entry_id)
	if not (resolved as Dictionary).get("ok", false):
		# The owning validator's code and message reach the caller verbatim (compositional law):
		# ENTRY_MANIFEST_UNKNOWN_ENTRY, ENTRY_MANIFEST_RETIRED_ENTRY, and the locator refusals.
		return resolved
	var locator: Dictionary = (resolved as Dictionary)["value"]
	var path := str(locator.get("path", ""))
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		# Specification 14.1: a missing master starts NOTHING and the event stays pending.
		return _playback_failure(&"entry_master_missing", path)
	var record := _entry_record(entry_id)
	if record.is_empty():
		return _playback_failure(&"entry_record_missing",
			"%s resolves through the catalog but has no record in the shipped entry document" % entry_id)
	var content_version := int(record.get("content_version", 0))
	if expected_version >= 0 and content_version != expected_version:
		return _playback_failure(&"entry_content_version_mismatch",
			"checkpoint content_version %d != record content_version %d"
			% [expected_version, content_version])
	return {"ok": true, "value": {
		"content_version": content_version,
		"content_locale": str(locator.get("locale", "")),
		"label": str(locator.get("label", "")),
		"path": path,
		"used_fallback": bool(locator.get("used_fallback", false)),
	}}


## The frozen context's canonical fingerprint, extracted so the validator reports the SAME digest
## the playback path stores rather than a second derivation of it. The duplicate travels with the
## digest, so both callers freeze exactly the bytes they fingerprinted.
func _context_fingerprint(context: Dictionary) -> Dictionary:
	var frozen := context.duplicate(true)
	var emitted: Dictionary = _CANONICAL_JSON.stringify(frozen)
	if not emitted.get("ok", false):
		return _playback_failure(&"context_not_canonical", str(emitted.get("message", "")))
	return {"ok": true, "value": {
		"fingerprint": str(emitted["value"]).sha256_text(), "frozen": frozen}}


## The shared start/resume pipeline. expected_version >= 0 means a durable checkpoint is being
## revalidated against the record (resume); -1 means a fresh start. token_kind picks the counter:
## playback-%d for starts, resume-%d for restores - both monotonic and process-local, so an
## old-process token can never equal a live one (staleness is exact string equality).
func _begin_entry_playback(entry_id: String, context: Dictionary, execution_mode: StringName,
		token_kind: String, expected_version: int = -1) -> Dictionary:
	var presentation := _validate_frozen_projection(entry_id, context)
	if not presentation.ok: return presentation
	if not _pause_handle.is_empty(): return _playback_failure(&"narrative_suspended", "Pause retains playback custody")
	if has_active_playback():
		var standing := str(_active_entry.get("token", _active_playback.get("token", "")))
		return _playback_failure(&"entry_already_active", "%s is still active" % standing)
	var resolved := _resolve_entry_for_playback(entry_id, expected_version)
	if not resolved.get("ok", false):
		return resolved
	var locator: Dictionary = resolved["value"]
	var path := str(locator["path"])
	var label := str(locator["label"])
	var content_version := int(locator["content_version"])
	var fingerprinted := _context_fingerprint(context)
	if not fingerprinted.get("ok", false):
		return fingerprinted
	var frozen: Dictionary = (fingerprinted["value"] as Dictionary)["frozen"]
	var fingerprint := str((fingerprinted["value"] as Dictionary)["fingerprint"])
	var reading: bool = execution_mode == &"canonical" and has_reading_session() \
		and (token_kind != "resume" or not _reading_resume_frontier.is_empty()) \
		and _reading_session.catalogue.has(entry_id)
	if reading:
		var compatible := _validate_reading_entry(_reading_session, entry_id)
		if not compatible.ok: return compatible
		var frame: Dictionary = _reading_session.admit(entry_id, frozen)
		if not frame.ok: return frame
		var bound: Dictionary = _runtime_adapter.bind_caption_ledger(_reading_session.ledger,
			_reading_session.command_id, entry_id)
		if not bound.ok: return bound
	elif has_reading_session():
		retire_reading_session()
	var has_frozen_variables := false
	if frozen.has("presentation"):
		if _runtime_adapter == null or not _runtime_adapter.has_method("install_frozen_presentation"):
			return _playback_failure(&"frozen_context_runtime_unavailable", entry_id)
		var installed: Dictionary = _runtime_adapter.install_frozen_presentation(frozen.presentation)
		if not installed.get("ok", false): return installed
		has_frozen_variables = true
	elif execution_mode == &"rehearsal" and frozen.has("presentation_signature"):
		if _runtime_adapter == null or not _runtime_adapter.has_method("install_frozen_replay"):
			return _playback_failure(&"frozen_context_runtime_unavailable", entry_id)
		var installed: Dictionary = _runtime_adapter.install_frozen_replay(frozen.presentation_signature, "gallery_replay")
		if not installed.get("ok", false): return installed
		has_frozen_variables = true
	var token := ""
	if token_kind == "gallery":
		token = "gallery-%d" % _replay_counter
	elif token_kind == "resume":
		_resume_counter += 1
		token = "resume-%d" % _resume_counter
	else:
		_playback_counter += 1
		token = "playback-%d" % _playback_counter
	_active_entry = {
		"token": token,
		"entry_id": entry_id,
		"stage": str(frozen["expected_stage"]),
		"transaction_id": str(frozen["transaction_id"]),
		"context_fingerprint": fingerprint,
		"execution_mode": execution_mode,
		"content_version": content_version,
		"path": path,
		"label": label,
		"used_fallback": bool(locator.get("used_fallback", false)),
		"content_locale": str(locator.get("content_locale", "")),
		"suppress_first_speech": token_kind == "resume",
		"frozen_context": frozen,
	}
	_start_in_progress = true
	var started := _start_semantic_playback(path, label)
	_start_in_progress = false
	if not started.get("ok", false):
		if str(_active_entry.get("token", "")) == token:
			if has_frozen_variables: _runtime_adapter.release_frozen_presentation()
			_active_entry = {}
			scene_art_changed.emit()
		return started
	return {"ok": true, "code": &"started", "value": {}, "receipt": {
		"entry_id": entry_id,
		"playback_token": token,
		"content_version": content_version,
		"context_fingerprint": fingerprint,
		"path": path,
		"label": label,
		"used_fallback": bool(locator.get("used_fallback", false)),
	}}


## All physical starts use the retained runtime adapter, including deferred layout admission.
## Entry labels and ending labels retain the native String-or-index vocabulary.
func _start_semantic_playback(path: String, label: String) -> Dictionary:
	if _runtime_adapter != null:
		# The adapter performs the physical clear inside start_timeline, so the boundary step is
		# announced first; the reapply itself arrives via the runtime's own timeline_started.
		preference_boundary_step.emit(&"clear")
		if not _reading_resume_frontier.is_empty():
			_prepare_scene_art()
			return _runtime_adapter.start_reading_frontier(path, _reading_resume_frontier, label)
		# Empty dating DTL returns naturally. It must never introduce an art-hold Continue.
		var allow_art_hold := not str(_active_entry.get("entry_id", "")).begins_with("dating.")
		var result: Variant = _start_with_scene_art(path, label, allow_art_hold)
		if typeof(result) != TYPE_DICTIONARY or not (result as Dictionary).get("ok", false):
			return _playback_failure(&"runtime_start_failed", label)
		return {"ok": true}
	var required := require_dialogic()
	if not required.get("ok", false):
		return _playback_failure(&"dialogic_missing", MISSING_DIALOGIC_MESSAGE)
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic == null or not dialogic.has_method("start"):
		return _playback_failure(&"dialogic_missing", MISSING_DIALOGIC_MESSAGE)
	var bound := _ensure_runtime_adapter(dialogic)
	if not bound.get("ok", false): return bound
	return _start_semantic_playback(path, label)


func acknowledge_signal(signal_id: String, payload: Dictionary) -> Dictionary:
	if not _reached_replay.is_empty():
		return _playback_failure(&"rehearsal_commit_denied", "direct replay cannot commit commands")
	if _active_entry.is_empty():
		return _playback_failure(&"no_active_entry", "no semantic entry is active")
	var token := str(payload.get("playback_token", ""))
	if token != str(_active_entry["token"]):
		# Staleness is exact string equality: an old-process or superseded token never matches.
		return _playback_failure(&"stale_playback_token", "%s is not the active playback token" % token)
	var document := _ensure_entry_document()
	if not document.get("ok", false):
		return document
	var entry_id := str(_active_entry["entry_id"])
	var stage := StringName(str(_active_entry["stage"]))
	var validated: Dictionary = _ENTRY_MANIFEST.validate_signal(document["value"], entry_id, stage, signal_id, payload)
	if not validated.get("ok", false):
		# The owning validator's SIGNAL_* code and message reach the caller verbatim.
		return validated
	if _active_entry["execution_mode"] == &"rehearsal":
		# R-HH: rehearsal may start and observe, never commit. Checked AFTER validate_signal so
		# the refusal is provably about the mode, not about a grant the entry lacks.
		return _playback_failure(&"rehearsal_commit_denied",
			"a rehearsal playback may not commit %s" % signal_id)
	# validate_signal enforced the registered payload field set, and every shipped signal
	# carries receipt_id; the soft read keeps the file's never-crashes law even against a
	# parseable-but-corrupt registry (reviewer M-1).
	var receipt_id := str(payload.get("receipt_id", ""))
	var emitted: Dictionary = _CANONICAL_JSON.stringify({"payload": payload, "signal_id": signal_id})
	if not emitted.get("ok", false):
		# Defence in depth behind validate_signal: only canonical bytes may enter the ledger.
		return _playback_failure(&"payload_not_canonical", str(emitted.get("message", "")))
	var fingerprint := str(emitted["value"]).sha256_text()
	if _signal_receipts.has(receipt_id):
		var stored: Dictionary = _signal_receipts[receipt_id]
		if str(stored["fingerprint"]) == fingerprint:
			return {"ok": true, "code": &"acknowledged", "value": {"duplicate": true},
				"receipt": (stored["receipt"] as Dictionary).duplicate(true)}
		return _playback_failure(&"duplicate_transaction_conflict", receipt_id)
	if _signal_command_port == null:
		return _playback_failure(&"signal_command_port_not_configured",
			"configure_signal_command_port must install the state owner first")
	var committed: Variant = _signal_command_port.call(&"commit_signal",
		entry_id, stage, signal_id, payload.duplicate(true), _active_entry["execution_mode"])
	if typeof(committed) != TYPE_DICTIONARY or not (committed as Dictionary).get("ok", false):
		# A rejected boundary pauses playback at the registered continuation stage so no
		# consequence-dependent prose can show; NOTHING enters the ledger, so a retry is fresh.
		if _runtime_adapter != null and _runtime_adapter.has_method("set_paused"):
			_runtime_adapter.set_paused(true)
		if typeof(committed) == TYPE_DICTIONARY:
			return committed
		return _playback_failure(&"signal_command_failed", signal_id)
	var receipt := {
		"receipt_id": receipt_id,
		"entry_id": entry_id,
		"signal_id": signal_id,
		"stage": str(stage),
		"playback_token": token,
	}
	_signal_receipts[receipt_id] = {"fingerprint": fingerprint, "receipt": receipt.duplicate(true)}
	return {"ok": true, "code": &"acknowledged", "value": {"duplicate": false}, "receipt": receipt}


func abort_current_entry(code: StringName) -> Dictionary:
	if _active_entry.is_empty():
		return _playback_failure(&"no_active_entry", "no semantic entry is active")
	var entry := _active_entry.duplicate(true)
	# Clear BEFORE halting: the physical end signal the halt provokes must find no active entry,
	# so an aborted playback can never reach the completion port (the stale-completion law).
	_active_entry = {}
	_close_art_hold()
	scene_art_changed.emit()
	if _runtime_adapter != null and _runtime_adapter.has_method("halt_with_error"):
		_runtime_adapter.halt_with_error({"ok": false, "code": &"entry_aborted",
			"message": String(code), "details": {}})
	return {"ok": true, "code": &"aborted", "value": {}, "receipt": {
		"entry_id": str(entry["entry_id"]),
		"playback_token": str(entry["token"]),
		"completion_kind": &"aborted",
		"reason_code": code,
	}}


func _start_playback(ending_id: String, expected_role: String) -> Dictionary:
	if not _pause_handle.is_empty(): return _playback_failure(&"narrative_suspended", "Pause retains playback custody")
	if not _initialized:
		return _playback_failure(&"not_initialized", "initialize the bridge first")
	if not _active_entry.is_empty():
		# Reviewer I-1: the one-active law is bidirectional. An ending may not cancel a live
		# semantic entry and later masquerade its completion through the entry branch.
		return _playback_failure(&"entry_already_active",
			"%s is still active" % str(_active_entry["token"]))
	if has_active_playback():
		return _playback_failure(&"narrative_playback_active", "complete or cancel standing playback first")
	if not _ending_records.has(ending_id):
		return _playback_failure(&"unknown_ending_id", ending_id)
	var record: Dictionary = _ending_records[ending_id]
	if str(record["role"]) != expected_role:
		return _playback_failure(&"ending_role_mismatch", "%s is %s, not %s" % [ending_id, str(record["role"]), expected_role])
	var timeline_id := str(record["timeline_id"])
	# Task 5 (R-DD): the ending locator resolves through the exact single-path API. This site
	# keeps its established failure code and message; an unknown id now arrives as the locator's
	# ok:false envelope instead of an empty string.
	var located: Variant = _catalog.get_path_for_id(timeline_id)
	if typeof(located) != TYPE_DICTIONARY or not (located as Dictionary).get("ok", false):
		return _playback_failure(&"unknown_timeline_id", timeline_id)
	var path := str(((located as Dictionary)["value"] as Dictionary).get("path", ""))
	var label := str(record["label"])
	_playback_counter += 1
	var token := "playback-%d" % _playback_counter
	var before := {"id": _current_timeline_id, "context": _current_timeline_context.duplicate(true)}
	_current_timeline_id = timeline_id
	_active_playback = {"token": token, "ending_id": ending_id, "role": expected_role,
		"timeline_id": timeline_id, "label": label, "cache_before": before,
		"content_locale": "en", "suppress_first_speech": false}
	_start_in_progress = true
	var started: Dictionary = _start_through_runtime(path, label)
	_start_in_progress = false
	if not started.get("ok", false):
		if str(_active_playback.get("token", "")) == token:
			_active_playback = {}
			_current_timeline_id = before.id
			_current_timeline_context = before.context
		return started
	return {"ok": true, "code": &"started", "value": {}, "receipt": {
		"playback_token": token, "ending_id": ending_id, "role": StringName(expected_role),
		"timeline_id": timeline_id, "label": label, "started": true,
	}}


func _start_through_runtime(path: String, label: String) -> Dictionary:
	if _runtime_adapter != null:
		var result: Variant = _start_with_scene_art(path, label)
		if typeof(result) != TYPE_DICTIONARY or not (result as Dictionary).get("ok", false):
			return _playback_failure(&"runtime_start_failed", label)
		return {"ok": true}
	var required := require_dialogic()
	if not required.get("ok", false):
		return _playback_failure(&"dialogic_missing", MISSING_DIALOGIC_MESSAGE)
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic == null or not dialogic.has_method("start"):
		return _playback_failure(&"dialogic_missing", MISSING_DIALOGIC_MESSAGE)
	var bound := _ensure_runtime_adapter(dialogic)
	if not bound.get("ok", false): return bound
	return _start_through_runtime(path, label)


## The runtime's own end-of-timeline signal, and since Task 8 (dwm-p2r.14) the ONLY way a timeline
## can be declared finished. The public `finish_current_timeline()` used to let any caller announce
## a completion that never physically happened; it is gone, and `DialogicPresentationOwnerAdapter`
## converts only what arrives here into a trusted physical completion.
func _on_runtime_timeline_ended() -> void:
	# The Ending playback branch is unchanged: it owns its own token and completion record.
	if not _active_playback.is_empty():
		var playback := _active_playback.duplicate(true)
		_active_playback = {}
		scene_art_changed.emit()
		# Reviewer I-2: _start_playback retained this timeline id; consuming the completion must
		# clear it, or a later semantic abort's halt replays it as a phantom generic completion.
		# Conditional on the exact id so a retained id this branch does NOT own is untouched.
		if _current_timeline_id == str(playback["timeline_id"]):
			_current_timeline_id = ""
			_current_timeline_context = {}
		ending_playback_finished.emit(str(playback["token"]), str(playback["ending_id"]),
			{"receipt_id": "%s:complete" % str(playback.get("stable_playback_id", playback["token"])), "ending_id": str(playback["ending_id"]), "timeline_id": str(playback["timeline_id"])})
		return
	# Task 5 semantic-entry branch (R-FF): physical completion advances NOTHING directly; it
	# builds ONE intent from the validated frozen context (R-GG: stage and transaction_id come
	# from _PLAYBACK_CONTEXT_KEYS) and hands it to the ONE configured completion port. Clearing
	# before the call makes a duplicate runtime signal a no-op, exactly like the branches around
	# it. A completion with no configured port is reported, never swallowed.
	if not _active_entry.is_empty():
		var entry := _active_entry.duplicate(true)
		_active_entry = {}
		if has_reading_session() and _reading_session.latest_entry == entry.entry_id:
			_reading_session.completed(entry.entry_id)
			reading_session_changed.emit()
		scene_art_changed.emit()
		if not _reached_replay.is_empty() and entry.token == _reached_replay.token:
			_finish_reached_replay("completed")
			return
		var intent := {
			"entry_id": str(entry["entry_id"]),
			"transaction_id": str(entry["transaction_id"]),
			"stage": str(entry["stage"]),
			"playback_token": str(entry["token"]),
			"context_fingerprint": str(entry["context_fingerprint"]),
			"execution_mode": StringName(entry["execution_mode"]),
			"completion_kind": &"natural_end",
		}
		if _playback_completion_port != null:
			_playback_completion_port.call(&"complete_entry", intent)
		else:
			narrative_validation_failed.emit({"ok": false,
				"code": &"playback_completion_port_not_configured",
				"message": "a semantic entry completed with no configured completion port",
				"details": {"entry_id": str(entry["entry_id"])}})
		return
	# The generic branch: finalize the retained timeline/context and emit exactly ONE completion.
	# Clearing before the emit is what makes a duplicate runtime signal a no-op rather than a second
	# completion for the same presentation.
	if _ordinary_playback.is_empty():
		return
	var finished_id := str(_ordinary_playback.timeline_id)
	var context: Dictionary = _ordinary_playback.context.duplicate(true)
	_ordinary_playback = {}
	scene_art_changed.emit()
	_current_timeline_id = ""
	_current_timeline_context = {}
	timeline_finished.emit(finished_id, {"timeline_id": finished_id, "context": context})


func _on_runtime_signal_event(argument: Variant) -> void:
	if not _reached_replay.is_empty():
		# Direct Gallery playback can observe; it owns no Run or Profile command capability.
		return
	if typeof(argument) == TYPE_DICTIONARY and str((argument as Dictionary).get("kind", "")) in _RUNTIME_EVENT_KINDS:
		var kind := str((argument as Dictionary)["kind"])
		if kind == "effect_transaction" or kind == "variable_transaction":
			_handle_narrative_transaction(kind, argument as Dictionary)
		return
	var failure := {"ok": false, "code": &"invalid_runtime_event", "message": "unregistered signal payload", "details": {"argument": argument}}
	# Retire ownership before halt: its physical end is cancellation, never natural completion.
	_on_playback_start_failed(failure, true)
	narrative_validation_failed.emit(failure.duplicate(true))


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
	# The four-key envelope remains readable during staged producer migration.
	# New production Dating always supplies the separately versioned presentation.
	if context.size() != _PLAYBACK_CONTEXT_KEYS.size() + (1 if context.has("presentation") else 0):
		return false
	for key in _PLAYBACK_CONTEXT_KEYS:
		if not context.has(key):
			return false
	return true

func _validate_frozen_projection(entry_id: String, context: Dictionary) -> Dictionary:
	if not context.has("presentation"): return {"ok": true}
	for key: String in _PLAYBACK_CONTEXT_KEYS:
		if not context.get(key) is String or str(context[key]).strip_edges().is_empty():
			return _playback_failure(&"invalid_playback_context", key)
	var checked := preload("res://scripts/narrative/FrozenPresentationContext.gd").validate(entry_id, context.presentation)
	if not checked.ok: return checked
	var fields: Dictionary = checked.value.fields
	if str(fields.entry_role) in ["solo_pre_challenge", "solo_post_challenge", "pair_pre_challenge_scene", "pair_post_challenge_scene"] \
			and (context.role != "dating_phase" or context.expected_stage != fields.phase):
		return _playback_failure(&"frozen_context_stage_mismatch", entry_id)
	return checked


func _playback_failure(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
