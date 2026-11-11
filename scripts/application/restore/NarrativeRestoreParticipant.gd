class_name NarrativeRestoreParticipant
extends RefCounted

signal scene_activation_confirmed(operation_id: String)
signal scene_activation_failed(operation_id: String, result: Dictionary)


const SCHEMA := preload("res://scripts/narrative/NarrativeCheckpointSchema.gd")
const ENTRY_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const FROZEN_RUN := preload("res://scripts/narrative/FrozenRunContext.gd")

const _CONTENT_CODES := [
	&"unregistered_event", &"illegal_successor", &"event_index_mismatch",
	&"event_kind_mismatch", &"semantic_id_mismatch", &"timeline_mismatch", &"fingerprint_mismatch",
]

const _SEMANTIC_PLAN_KEYS := ["content_version", "entry_id", "frozen_context",
	"manifest_fingerprint", "stage", "transaction_id"]
const _RESUME_CHECKPOINT_KEYS := ["content_version", "entry_id", "frozen_context", "stage",
	"transaction_id"]
const _PHYSICAL_LOCATOR_KEYS := ["label", "path", "timeline_id", "timeline_path"]
const _SEMANTIC_CONTENT_CODES := [
	&"entry_resolution_failed", &"ENTRY_MANIFEST_UNKNOWN_ENTRY", &"ENTRY_MANIFEST_RETIRED_ENTRY",
	&"entry_master_missing", &"entry_record_missing", &"entry_content_version_mismatch",
]
const _READING_CONTENT_CODES := [
	&"reading_catalogue_unavailable", &"reading_catalogue_mismatch", &"reading_line_unavailable",
	&"reading_line_content_mismatch", &"reading_line_ambiguous", &"reading_entry_mismatch",
]

static var _document_fingerprint := ""

var _owner: Object = null
var _catalog: Object = null
var _pending_semantic_plan: Dictionary = {}
var _prepared_scene_checkpoint: Dictionary = {}
var _prepared_terminal := false
var _scene_operation := ""
var _scene_activation_in_call := false
var _scene_activation_proof := false
var _scene_activation_notified := false
var _scene_activation_failure: Dictionary = {}

func _init(owner: Object, catalog: Object = null) -> void:
	_owner = owner
	_catalog = catalog if catalog != null else preload("res://scripts/data/DialogicTimelineCatalog.gd")

func prepare(input: Dictionary) -> Dictionary:
	_prepared_scene_arrival_cues = []
	_prepared_scene_presentation_checkpoint = false
	_prepared_scene_checkpoint = {}
	_prepared_terminal = false
	if typeof(input.get("narrative_checkpoint")) != TYPE_DICTIONARY:
		return _fail(&"invalid_narrative_input", "narrative participant requires a narrative_checkpoint")
	if typeof(input.get("content_version")) != TYPE_INT:
		return _fail(&"invalid_narrative_input", "narrative participant requires a content_version")
	var checkpoint: Dictionary = input["narrative_checkpoint"]
	var snapshot: Variant = input.get("snapshot")
	if snapshot is Dictionary and preload("res://scripts/domain/run/RunSnapshotSchema.gd").is_scene_terminal(snapshot):
		if snapshot.get("narrative_checkpoint") != checkpoint:
			return _fail(&"invalid_narrative_input", "terminal checkpoint must match its complete Run")
		var validated: Dictionary = preload("res://scripts/domain/run/RunSnapshotSchema.gd").validate(snapshot)
		if not validated.get("ok", false): return validated
		if not checkpoint.is_empty():
			var prepared := _prepare_reading(checkpoint, snapshot) if checkpoint.has("reading_session") else _prepare_semantic(checkpoint)
			if not prepared.get("ok", false): return prepared
		_prepared_terminal = true
		_prepared_scene_checkpoint = checkpoint.duplicate(true)
		return {"ok": true, "value": {"narrative_plan": {"scene_terminal_checkpoint": checkpoint.duplicate(true)}}}
	if checkpoint.has("reading_session"):
		return _prepare_reading(checkpoint, input.get("snapshot"))
	if checkpoint.has("entry_id"):
		return _prepare_semantic(checkpoint)
	if not _has_nonempty_playhead(checkpoint):
		return {"ok": true, "code": &"ok", "value": {"narrative_plan": {"narrative_checkpoint": checkpoint.duplicate(true)}}}
	var timeline_id := str(checkpoint.get("timeline_id", ""))
	var resolved: Dictionary = _catalog.get_record(timeline_id)
	if not resolved.get("ok", false):
		return _content_unavailable("unknown timeline: " + timeline_id)
	var record: Dictionary = resolved["value"]
	if str(record.get("content_fingerprint", "")) != str(checkpoint.get("content_fingerprint", "")):
		return _content_unavailable("content fingerprint drifted for " + timeline_id)
	var validated: Dictionary = SCHEMA.validate(checkpoint, record)
	if not validated.get("ok", false):
		if validated.get("code") in _CONTENT_CODES:
			return _content_unavailable(str(validated.get("message", "")))
		return _fail(&"invalid_narrative_checkpoint", str(validated.get("message", "")))
	var post_event: Dictionary = checkpoint["post_event"]
	var plan := {
		"narrative_checkpoint": checkpoint.duplicate(true),
		"position": str(post_event["position"]),
		"resume_event_index": post_event.get("event_index"),
		"timeline_id": timeline_id,
		"timeline_path": _catalog.get_timeline_path(timeline_id, "en"),
	}
	return {"ok": true, "code": &"ok", "value": {"narrative_plan": plan}}

var _prepared_scene_arrival_cues: Array = []
var _prepared_scene_presentation_checkpoint := false

func prepare_scene_load(snapshot: Dictionary) -> Dictionary:
	_prepared_scene_arrival_cues = []
	_prepared_scene_presentation_checkpoint = false
	_prepared_terminal = preload("res://scripts/domain/run/RunSnapshotSchema.gd").is_scene_terminal(snapshot)
	_prepared_scene_checkpoint = snapshot.narrative_checkpoint
	var plan: Dictionary = {"scene_terminal_checkpoint": _prepared_scene_checkpoint} \
		if _prepared_terminal else _prepared_scene_checkpoint
	return {"ok": true, "value": {"narrative_plan": plan}}

func prepare_scene_new_run(snapshot: Dictionary, _allocation_candidate: Dictionary, _profile_material: Dictionary,
		_bundle: Dictionary, _issuer: Object, creation_owner: Object) -> Dictionary:
	_prepared_scene_checkpoint = {}
	if not is_instance_valid(creation_owner) or creation_owner.get_script() != load("res://autoload/SaveManager.gd") \
			or not _owner is Node or not _owner.is_inside_tree() \
			or creation_owner != _owner.get_node_or_null("/root/SaveManager"):
		return _fail(&"scene_creation_owner_required", "actual continuation owner required")
	var checkpoint: Dictionary = snapshot.narrative_checkpoint
	var expanded := preload("res://scripts/narrative/SoloReadingSession.gd").expand_player_checkpoint(checkpoint)
	if not expanded.ok: return expanded
	var frames := FROZEN_RUN.derive_current_scene_frames(snapshot.scene, expanded.value.reading_session)
	if not frames.ok: return frames
	if not _owner.has_method("validate_reading_checkpoint") or not _owner.has_method("stage_scene_reading_restore"):
		return _content_unavailable("scene creation owner unavailable")
	var admitted: Dictionary = _owner.validate_reading_checkpoint(expanded.value, frames.value.entry_contexts)
	if not admitted.get("ok", false): return admitted
	_prepared_scene_checkpoint = checkpoint.duplicate(true)
	_prepared_scene_arrival_cues = []
	var game: Node = _owner.get_node("/root/GameState")
	var presentation: Dictionary = game.prepare_scene_presentation_arrival(snapshot.scene, _bundle, "")
	if not presentation.ok: return presentation
	_prepared_scene_presentation_checkpoint = presentation.value.autosave
	if _bundle.get("audio_catalogue", {}).get("schema_version") == 3:
		var arrival: Dictionary = game.prepare_scene_audio_arrival(snapshot.scene, _bundle, "")
		if not arrival.ok: return arrival
		_prepared_scene_arrival_cues = arrival.value.cues
	return {"ok": true, "value": {"narrative_plan": checkpoint.duplicate(true)}}

func apply_silent(plan: Dictionary) -> Dictionary:
	if typeof(plan.get("route_ready_token")) != TYPE_DICTIONARY:
		return _fail(&"missing_route_ready_token", "narrative apply requires the route-ready token")
	if plan.has("scene_terminal_checkpoint") or FROZEN_RUN._is_scene_checkpoint(plan):
		var terminal: bool = plan.has("scene_terminal_checkpoint")
		var checkpoint: Dictionary = plan.scene_terminal_checkpoint if terminal else _projected(plan)
		var method := "stage_scene_terminal_restore" if terminal else "stage_scene_reading_restore"
		if (terminal and not _prepared_terminal) or (not terminal and _prepared_scene_checkpoint.is_empty()) \
				or (not plan.get("read_only_restore", false) and not _same_scene_value(checkpoint, _prepared_scene_checkpoint)) \
				or typeof(plan.get("scene_restore_operation_id")) != TYPE_STRING \
				or plan.scene_restore_operation_id.strip_edges().is_empty() \
				or not _owner.has_method(method):
			return _fail(&"scene_restore_plan_invalid", "private prepared checkpoint and current operation required")
		var staged: Dictionary = _owner.call(method, checkpoint, plan.scene_restore_operation_id, true) \
			if plan.get("read_only_restore", false) else _owner.call(method, checkpoint, plan.scene_restore_operation_id)
		if not staged.get("ok", false): return staged
		if not _prepared_scene_arrival_cues.is_empty():
			_owner._scene_restore["arrival_audio_cues"] = _prepared_scene_arrival_cues
		if _prepared_scene_presentation_checkpoint:
			_owner._scene_restore["arrival_presentation_checkpoint"] = true
		_scene_operation = plan.scene_restore_operation_id
		_scene_activation_proof = false
		_scene_activation_notified = false
		_scene_activation_failure = {}
		_pending_semantic_plan = {}
		return {"ok": true}
	_scene_operation = ""
	_scene_activation_proof = false
	var pause_pending: bool = _owner.has_method("is_pause_restore_pending") and _owner.is_pause_restore_pending()
	if plan.has("reading_session"):
		if not pause_pending and _owner.has_active_playback():
			return _fail(&"narrative_playback_active", "a narrative playback is standing; the reading restore cannot be staged")
		var staged: Dictionary = _owner.stage_reading_restore(_projected(plan))
		if not staged.get("ok", false): return staged
	if pause_pending:
		return _owner.stage_pause_restore(_projected(plan) if plan.has("entry_id") else plan,
			plan.has("entry_id"))
	if plan.has("entry_id"):
		if _owner.has_active_playback():
			return _fail(&"narrative_playback_active",
				"a narrative playback is standing; the semantic restore cannot be staged")
		_pending_semantic_plan = _projected(plan)
		return {"ok": true, "code": &"ok"}
	return _owner.apply_restore_silent(plan)

func capture() -> Dictionary:
	return _owner.capture_restore_state()

func rollback_silent(backup: Dictionary) -> Dictionary:
	_prepared_scene_arrival_cues = []
	_prepared_scene_presentation_checkpoint = false
	_prepared_scene_checkpoint = {}
	_prepared_terminal = false
	_scene_operation = ""
	_scene_activation_proof = false
	_scene_activation_notified = false
	_scene_activation_failure = {}
	_pending_semantic_plan = {}
	return _owner.rollback_restore_silent(backup)

func finalize() -> Dictionary:
	if not _scene_operation.is_empty():
		return {"ok": true, "value": {"pending": true}}
	if _owner.has_method("is_pause_restore_pending") and _owner.is_pause_restore_pending():
		return _owner.finalize_pause_restore()
	if _pending_semantic_plan.is_empty():
		return _owner.finalize_restore()
	var checkpoint: Dictionary = _pending_semantic_plan
	_pending_semantic_plan = {}
	return _owner.resume_entry(checkpoint)

func begin_scene_activation(operation_id: String) -> Dictionary:
	if operation_id.is_empty() or operation_id != _scene_operation or _scene_activation_in_call:
		return _fail(&"scene_activation_operation_invalid", "no matching staged scene operation")
	if not _scene_activation_failure.is_empty(): return _scene_activation_failure.duplicate(true)
	for method: String in ["begin_scene_activation", "validate_scene_activation"]:
		if not _owner.has_method(method): return _fail(&"scene_activation_owner_unavailable", "")
	if not _owner.has_signal("scene_activation_confirmed") or not _owner.has_signal("scene_activation_failed"):
		return _fail(&"scene_activation_owner_unavailable", "")
	if not _owner.is_connected("scene_activation_confirmed", _on_scene_activation_confirmed):
		_owner.connect("scene_activation_confirmed", _on_scene_activation_confirmed)
	if not _owner.is_connected("scene_activation_failed", _on_scene_activation_failed):
		_owner.connect("scene_activation_failed", _on_scene_activation_failed)
	_scene_activation_in_call = true
	var begun: Dictionary = _owner.begin_scene_activation(operation_id)
	_scene_activation_in_call = false
	if not begun.get("ok", false):
		_on_scene_activation_failed(operation_id, begun)
		return begun
	if not _scene_activation_failure.is_empty(): return _scene_activation_failure.duplicate(true)
	if _scene_activation_proof: _publish_scene_activation_confirmation()
	return begun

func _on_scene_activation_confirmed(operation_id: String) -> void:
	if operation_id != _scene_operation or not _scene_activation_failure.is_empty(): return
	_scene_activation_proof = true
	if not _scene_activation_in_call: _publish_scene_activation_confirmation()

func _publish_scene_activation_confirmation() -> void:
	if _scene_activation_notified or not validate_scene_activation(_scene_operation).get("ok", false): return
	_scene_activation_notified = true
	scene_activation_confirmed.emit(_scene_operation)

func _on_scene_activation_failed(operation_id: String, result: Dictionary) -> void:
	if operation_id != _scene_operation or not _scene_activation_failure.is_empty(): return
	_scene_activation_failure = result.duplicate(true)
	_scene_activation_proof = false
	scene_activation_failed.emit(operation_id, result.duplicate(true))

func validate_scene_activation(operation_id: String) -> Dictionary:
	if operation_id.is_empty() or operation_id != _scene_operation or not _scene_activation_proof \
			or _scene_activation_in_call or not _scene_activation_failure.is_empty() \
			or not _owner.has_method("validate_scene_activation"):
		return _fail(&"scene_activation_unconfirmed", "matching native frontier proof required")
	return _owner.validate_scene_activation(operation_id)

func publish_scene_activation(operation_id: String) -> Dictionary:
	var checked := validate_scene_activation(operation_id)
	if not checked.ok: return checked
	if not _owner.has_method("publish_scene_activation"): return _fail(&"scene_activation_owner_unavailable", "")
	return _owner.publish_scene_activation(operation_id)

static func _same_scene_value(left: Variant, right: Variant) -> bool:
	return preload("res://scripts/narrative/ReadingTraversalOperation.gd")._same(left, right)

func _prepare_semantic(checkpoint: Dictionary) -> Dictionary:
	if FROZEN_RUN._is_scene_checkpoint(checkpoint):
		return _fail(&"invalid_narrative_checkpoint", "scene_owner_validation_unavailable")
	for key: String in _PHYSICAL_LOCATOR_KEYS:
		if checkpoint.has(key):
			return _fail(&"invalid_narrative_checkpoint",
				"a semantic entry checkpoint may not carry the physical locator " + key)
	if not _exact_keys(checkpoint, _SEMANTIC_PLAN_KEYS):
		return _fail(&"invalid_narrative_checkpoint",
			"semantic checkpoint keys must be exactly " + str(_SEMANTIC_PLAN_KEYS))
	for key: String in ["entry_id", "manifest_fingerprint", "stage", "transaction_id"]:
		if typeof(checkpoint[key]) != TYPE_STRING or str(checkpoint[key]).is_empty():
			return _fail(&"invalid_narrative_checkpoint",
				"a semantic entry checkpoint requires a nonempty String " + key)
	if typeof(checkpoint["content_version"]) != TYPE_INT or int(checkpoint["content_version"]) <= 0:
		return _fail(&"invalid_narrative_checkpoint",
			"a semantic entry checkpoint requires a positive int content_version")
	var live := _entry_document_fingerprint()
	if live.is_empty():
		return _content_unavailable("the shipped entry document is unavailable or unfingerprintable")
	if str(checkpoint["manifest_fingerprint"]) != live:
		return _content_unavailable("entry manifest fingerprint drifted")
	var validated: Dictionary = _owner.validate_resume_checkpoint(_projected(checkpoint))
	if not validated.get("ok", false):
		if validated.get("code") in _SEMANTIC_CONTENT_CODES:
			return _content_unavailable("%s is unmappable: %s"
				% [str(checkpoint["entry_id"]), String(validated.get("code", &""))])
		return _fail(&"invalid_narrative_checkpoint", str(validated.get("message", "")))
	var plan := {}
	for key: String in _SEMANTIC_PLAN_KEYS:
		plan[key] = checkpoint[key]
	plan["frozen_context"] = (checkpoint["frozen_context"] as Dictionary).duplicate(true)
	return {"ok": true, "code": &"ok", "value": {"narrative_plan": plan}}

func _prepare_reading(checkpoint: Dictionary, snapshot: Variant) -> Dictionary:
	var keys := _SEMANTIC_PLAN_KEYS.duplicate()
	keys.append("reading_session")
	if not _exact_keys(checkpoint, keys):
		return _fail(&"invalid_narrative_checkpoint", "reading checkpoint requires its versioned semantic envelope")
	if not snapshot is Dictionary or snapshot.get("narrative_checkpoint") != checkpoint:
		return _fail(&"invalid_narrative_input", "reading restoration requires the complete matching saved Run")
	var frozen := FROZEN_RUN.validate(snapshot, true) if FROZEN_RUN._is_scene_checkpoint(checkpoint) \
		else FROZEN_RUN.validate_reading_checkpoint(checkpoint, snapshot)
	if not frozen.get("ok", false):
		return _fail(&"invalid_narrative_checkpoint", str(frozen.get("code", "")))
	if FROZEN_RUN._is_scene_checkpoint(checkpoint):
		if not _owner.has_method("validate_reading_checkpoint") or not _owner.has_method("stage_scene_reading_restore"):
			return _content_unavailable("scene restore owner unavailable")
		var admitted: Dictionary = _owner.validate_reading_checkpoint(checkpoint, frozen.value.entry_contexts)
		if not admitted.get("ok", false): return admitted
		_prepared_scene_checkpoint = checkpoint.duplicate(true)
		return {"ok": true, "value": {"narrative_plan": checkpoint.duplicate(true)}}
	var semantic := checkpoint.duplicate(true)
	semantic.erase("reading_session")
	var base := _prepare_semantic(semantic)
	if not base.get("ok", false): return base
	if not _owner.has_method("validate_reading_checkpoint") or not _owner.has_method("stage_reading_restore"):
		return _content_unavailable("the reading catalogue is unavailable")
	var checked: Dictionary = _owner.validate_reading_checkpoint(checkpoint, frozen.value.entry_contexts)
	if not checked.get("ok", false):
		if checked.get("code") in _READING_CONTENT_CODES or checked.get("code") in _SEMANTIC_CONTENT_CODES:
			return _content_unavailable("the saved reading catalogue is unavailable or incompatible")
		return _fail(&"invalid_narrative_checkpoint", str(checked.get("code", "")))
	return {"ok": true, "code": &"ok", "value": {"narrative_plan": checkpoint.duplicate(true)}}

static func _projected(source: Dictionary) -> Dictionary:
	if source.has("reading_session"):
		var reading := {}
		for key: String in _SEMANTIC_PLAN_KEYS:
			reading[key] = source.get(key)
		reading["reading_session"] = source.get("reading_session")
		return reading.duplicate(true)
	var projected := {}
	for key: String in _RESUME_CHECKPOINT_KEYS:
		projected[key] = source.get(key)
	return projected

static func _entry_document_fingerprint() -> String:
	if not _document_fingerprint.is_empty():
		return _document_fingerprint
	var loaded: Dictionary = ENTRY_MANIFEST.load_default()
	if not loaded.get("ok", false):
		return ""
	_document_fingerprint = str(ENTRY_MANIFEST.fingerprint(loaded["value"]))
	return _document_fingerprint

static func _exact_keys(target: Dictionary, keys: Array) -> bool:
	if target.size() != keys.size():
		return false
	for key in keys:
		if not target.has(key):
			return false
	return true

static func _has_nonempty_playhead(checkpoint: Dictionary) -> bool:
	if checkpoint.is_empty():
		return false
	for key: String in ["timeline_id", "line_id", "marker_id"]:
		if str(checkpoint.get(key, "")) != "":
			return true
	return false

static func _content_unavailable(message: String) -> Dictionary:
	return {"ok": false, "code": &"NARRATIVE_CONTENT_UNAVAILABLE", "message": message,
		"details": {"cause": {"reason": "content_unavailable"}}}

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}


