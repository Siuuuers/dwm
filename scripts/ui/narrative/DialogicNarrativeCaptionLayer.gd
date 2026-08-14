extends DialogicLayoutLayer
class_name DialogicNarrativeCaptionLayer

const CaptionPresenter := preload("res://scripts/ui/narrative/NarrativeCaptionLayer.gd")
const CaptionProjectionSource := preload("res://scripts/narrative/DialogicCaptionProjectionSource.gd")

@onready var _presenter: CaptionPresenter = %NarrativeCaptionLayer

var _runtime: Node = null
var _text_subsystem: Node = null
var _source: CaptionProjectionSource = null
var _last_failure: Dictionary = {}

func bind_runtime(runtime: Node, source: CaptionProjectionSource) -> Dictionary:
	if (
		runtime == null
		or source == null
		or not runtime.has_method("get_subsystem")
		or not runtime.has_signal("timeline_started")
		or not runtime.has_signal("timeline_ended")
	):
		return {"ok": false, "code": &"caption_runtime_binding_invalid"}
	if _runtime == runtime and _source == source:
		return {"ok": true, "code": &"caption_runtime_already_bound"}
	unbind_runtime()
	if is_instance_valid(_presenter):
		_presenter.clear_session()
	var text_subsystem := runtime.call("get_subsystem", "Text") as Node
	if text_subsystem == null or not text_subsystem.has_signal("text_started"):
		return {"ok": false, "code": &"caption_text_subsystem_missing"}
	_runtime = runtime
	_text_subsystem = text_subsystem
	_source = source
	_runtime.connect("timeline_started", _on_timeline_started)
	_runtime.connect("timeline_ended", _on_timeline_ended)
	_text_subsystem.connect("text_started", _on_text_started)
	return {"ok": true, "code": &"caption_runtime_bound"}

func unbind_runtime() -> void:
	if is_instance_valid(_runtime):
		if _runtime.is_connected("timeline_started", _on_timeline_started):
			_runtime.disconnect("timeline_started", _on_timeline_started)
		if _runtime.is_connected("timeline_ended", _on_timeline_ended):
			_runtime.disconnect("timeline_ended", _on_timeline_ended)
	if is_instance_valid(_text_subsystem) and _text_subsystem.is_connected("text_started", _on_text_started):
		_text_subsystem.disconnect("text_started", _on_text_started)
	_runtime = null
	_text_subsystem = null
	_source = null

func get_presenter() -> CaptionPresenter:
	return _presenter

func get_last_failure() -> Dictionary:
	return _last_failure.duplicate(true)

func _on_timeline_started() -> void:
	var session: Dictionary = _source.get_session_projection()
	var result := _presenter.reset_session(session.session_id, session.language_mode)
	_last_failure = {} if result.ok else result.duplicate(true)

func _on_timeline_ended() -> void:
	_presenter.clear_session()

func _on_text_started(info: Dictionary) -> void:
	var projected: Dictionary = _source.project_text(int(_runtime.get("current_event_idx")), info)
	if not projected.ok:
		_last_failure = projected.duplicate(true)
		return
	var result: Dictionary = (
		_presenter.append_current(projected.projection)
		if projected.append
		else _presenter.publish_beat(projected.projection)
	)
	_last_failure = {} if result.ok else result.duplicate(true)

func _exit_tree() -> void:
	if is_instance_valid(_presenter):
		_presenter.clear_session()
	unbind_runtime()
