class_name SaveManagerDesktopBoardPort
extends RefCounted


const CHECKPOINT_METHODS: Array[String] = ["preview_checkpoint_id", "capture", "prepare", "commit", "rollback"]
const _DESKTOP_KEYS: Array[String] = ["board", "consequence"]
const _AUDIO_KEYS := ["ambience_context", "ambience_context_id", "music_context", "music_context_id"]
const _JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

var _checkpoint_port: Object = null
var _audio_context_capture := Callable()
var _scene_context_capture := Callable()


func _init(checkpoint_port: Object = null) -> void:
	_checkpoint_port = checkpoint_port


func configure(checkpoint_port: Object) -> Dictionary:
	if checkpoint_port == null:
		return _fail(&"invalid_desktop_board_save_port", "a checkpoint port is required")
	for method in CHECKPOINT_METHODS:
		if not checkpoint_port.has_method(method):
			return _fail(&"invalid_desktop_board_save_port", "checkpoint port is missing " + method)
	if _checkpoint_port != null and _checkpoint_port != checkpoint_port:
		return _fail(&"desktop_board_save_port_already_configured", "another checkpoint port is configured")
	_checkpoint_port = checkpoint_port
	return {"ok": true, "code": &"ok", "value": {"checkpoint_port_instance_id": _checkpoint_port.get_instance_id()}, "receipt": {}}


func configure_audio_context_capture(capture_context: Callable) -> Dictionary:
	if not capture_context.is_valid(): return _fail(&"invalid_audio_context_capture", "")
	if _audio_context_capture.is_valid() and _audio_context_capture != capture_context:
		return _fail(&"audio_context_capture_already_configured", "")
	var already := _audio_context_capture.is_valid()
	_audio_context_capture = capture_context
	return {"ok": true, "value": {"already_configured": already}}


func configure_scene_context_capture(capture_context: Callable) -> Dictionary:
	if not capture_context.is_valid(): return _fail(&"invalid_scene_context_capture", "")
	if _scene_context_capture.is_valid() and _scene_context_capture != capture_context:
		return _fail(&"scene_context_capture_already_configured", "")
	var already := _scene_context_capture.is_valid()
	_scene_context_capture = capture_context
	return {"ok": true, "value": {"already_configured": already}}


func capture() -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	return _checkpoint_port.call(&"capture")


func preview_checkpoint_id(run_id: String) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	return _checkpoint_port.call(&"preview_checkpoint_id", run_id)


func prepare_checkpoint(post_commit_snapshot_input: Dictionary, checkpoint_kind: StringName,
		disk_write: Dictionary) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	var desktop_error := _validate_desktop_shape(post_commit_snapshot_input)
	if not desktop_error.is_empty():
		return _fail(&"invalid_post_commit_snapshot_input", desktop_error)
	if not _audio_context_capture.is_valid(): return _fail(&"audio_context_capture_unavailable", "")
	var captured: Variant = _audio_context_capture.call()
	if not captured is Dictionary: return _fail(&"invalid_audio_snapshot", "")
	var context: Dictionary = captured.duplicate(true)
	var keys: Array = context.keys()
	keys.sort()
	if keys != _AUDIO_KEYS: return _fail(&"invalid_audio_snapshot", "")
	for channel: String in ["music", "ambience"]:
		if not context[channel + "_context_id"] is String or not context[channel + "_context"] is Dictionary:
			return _fail(&"invalid_audio_snapshot", "")
		if context[channel + "_context_id"].is_empty() and not context[channel + "_context"].is_empty():
			return _fail(&"invalid_audio_snapshot", "")
	if not _JSON.stringify(context).get("ok", false): return _fail(&"invalid_audio_snapshot", "")
	var checkpoint_inputs := {
		"active_app_id": null, "audio_context": context, "content_version": 1,
		"dialogic_checkpoint": {}, "route_id": "main",
		"snapshot_input": post_commit_snapshot_input,
	}
	if post_commit_snapshot_input.has("scene"):
		if not _scene_context_capture.is_valid(): return _fail(&"scene_context_capture_unavailable", "")
		var captured_scene: Variant = _scene_context_capture.call(post_commit_snapshot_input.duplicate(true))
		if not captured_scene is Dictionary: return _fail(&"invalid_scene_checkpoint_context", "")
		if not captured_scene.get("ok", false): return captured_scene
		var semantic: Variant = captured_scene.get("value")
		if not semantic is Dictionary: return _fail(&"invalid_scene_checkpoint_context", "")
		var semantic_keys: Array = semantic.keys()
		semantic_keys.sort()
		if semantic_keys != ["active_app_id", "content_version", "dialogic_checkpoint", "route_id"] \
				or semantic.route_id != "scene" \
				or (semantic.active_app_id != null and not semantic.active_app_id is String) \
				or typeof(semantic.content_version) != TYPE_INT or semantic.content_version <= 0 \
				or not semantic.dialogic_checkpoint is Dictionary or semantic.dialogic_checkpoint.is_empty():
			return _fail(&"invalid_scene_checkpoint_context", "")
		for key: String in semantic:
			checkpoint_inputs[key] = semantic[key]
	return _checkpoint_port.call(&"prepare", checkpoint_inputs, checkpoint_kind, disk_write)


func commit_checkpoint(candidate: Dictionary) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	return _checkpoint_port.call(&"commit", candidate)


func rollback(backup: Dictionary) -> Dictionary:
	var ready := _readiness()
	if not ready.is_empty():
		return ready
	var payload: Variant = backup.get("backup", backup)
	return _checkpoint_port.call(&"rollback", payload if typeof(payload) == TYPE_DICTIONARY else backup)


static func _validate_desktop_shape(snapshot_input: Dictionary) -> String:
	if typeof(snapshot_input.get("desktop")) != TYPE_DICTIONARY:
		return "snapshot_input.desktop is required (schema 3 or earlier is not a legal first-Reveal checkpoint source)"
	var desktop: Dictionary = snapshot_input["desktop"]
	var keys: Array = desktop.keys()
	keys.sort()
	var expected := _DESKTOP_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return "snapshot_input.desktop must carry exactly {board,consequence}, saw: " + str(keys)
	if typeof(desktop["board"]) != TYPE_DICTIONARY or typeof(desktop["consequence"]) != TYPE_DICTIONARY:
		return "snapshot_input.desktop.board and .consequence must both be objects"
	return ""


func _readiness() -> Dictionary:
	if _checkpoint_port == null:
		return _fail(&"desktop_board_save_port_not_configured", "")
	return {}


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}, "receipt": {}}
