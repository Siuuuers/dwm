extends Node
## Mounted policy for the current caption. Dialogic Inputs remains the command owner.

const ACTION_SETTING := "dialogic/text/input_action"
const TAP_LIMIT_MSEC := 500

var _caption: DialogicNode_DialogText
var _viewport_control: Control
var _runtime: Node
var _contacts: Dictionary = {}
var _candidate: Dictionary = {}
var _fresh_key_event := 0
var _accepted_frame := -1
var _await_initial_neutral := false
var _foreground := true

func _enter_tree() -> void:
	add_to_group("dialogic_input_policy")

func bind(caption: DialogicNode_DialogText, viewport_control: Control, runtime: Node) -> void:
	_caption = caption
	_viewport_control = viewport_control
	_runtime = runtime
	_await_initial_neutral = Input.is_action_pressed(_action())
	_caption.visibility_changed.connect(_cancel_candidate)
	if _runtime != null and _runtime.has_signal("dialogic_paused"):
		_runtime.connect("dialogic_paused", _cancel_candidate)

func _cancel_candidate() -> void:
	_candidate.clear()

func _action() -> StringName:
	return StringName(ProjectSettings.get_setting(ACTION_SETTING, "dialogic_default_action"))

func _admissible() -> bool:
	return _foreground and is_instance_valid(_runtime) and not bool(_runtime.get("paused")) \
		and is_instance_valid(_caption) and _caption.is_visible_in_tree() \
		and not _caption.get_parsed_text().is_empty()

func _process(_delta: float) -> void:
	if not _candidate.is_empty() and (not _admissible() \
			or _candidate.generation != _caption.get_reveal_generation()):
		_candidate.clear()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_foreground = false
		_candidate.clear()
		_fresh_key_event = 0
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_foreground = true

func _input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenDrag:
		_candidate.clear()
		return
	if event is InputEventMouseMotion:
		if not _inside_current(event.position):
			_candidate.clear()
		return
	var source := _source(event)
	if source.is_empty():
		return
	_fresh_key_event = 0
	if event.is_pressed():
		if event.is_echo() or _contacts.has(source):
			return
		var neutral := _contacts.is_empty()
		_contacts[source] = true
		_candidate.clear()
		if not neutral or _await_initial_neutral or not _admissible() or _is_double_or_canceled(event):
			return
		_candidate = {"source": source, "generation": _caption.get_reveal_generation(),
			"started": Time.get_ticks_msec(), "armed": false}
		if not _is_pointer(event):
			_fresh_key_event = event.get_instance_id()
	else:
		_contacts.erase(source)
		if _contacts.is_empty() and not Input.is_action_pressed(_action()):
			_await_initial_neutral = false
		if not _candidate.is_empty() and _candidate.source == source:
			if _is_double_or_canceled(event) or (_is_pointer(event) and not _inside_current(_pointer_position(event))):
				_candidate.clear()

func _unhandled_input(event: InputEvent) -> void:
	if _is_pointer(event) or _source(event).is_empty():
		return
	# Consume rejected mapped packets too: a held contact must not reach fallback.
	get_viewport().set_input_as_handled()
	if event.get_instance_id() == _fresh_key_event and event.is_pressed() \
			and not event.is_echo() and is_instance_valid(_caption) and _caption.has_focus():
		_submit(false)

func handle_caption_gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION or not _is_pointer(event):
		return
	var source := _source(event)
	if source.is_empty() or _candidate.is_empty() or _candidate.source != source:
		return
	# GUI positions are local; the raw phase and this phase both check the aperture clip.
	var viewport_point: Vector2 = _caption.get_global_transform_with_canvas() * _pointer_position(event)
	if not _inside_current(viewport_point) or _is_double_or_canceled(event):
		_candidate.clear()
		return
	if event.is_pressed():
		_candidate.armed = true
		_caption.grab_focus()
	elif bool(_candidate.armed):
		if event is InputEventScreenTouch and Time.get_ticks_msec() - int(_candidate.started) > TAP_LIMIT_MSEC:
			_candidate.clear()
			return
		_submit(true)

func _submit(pointer: bool) -> void:
	if _candidate.is_empty():
		return
	var generation: int = _candidate.generation
	_candidate.clear()
	if not _admissible() or generation != _caption.get_reveal_generation() \
			or _accepted_frame == Engine.get_process_frames():
		return
	_accepted_frame = Engine.get_process_frames()
	var inputs: Object = _runtime.call("get_subsystem", "Inputs")
	if inputs != null:
		inputs.set("input_was_mouse_input", pointer)
		inputs.call("handle_input")
		if is_instance_valid(inputs):
			inputs.set("input_was_mouse_input", false)

func _inside_current(viewport_point: Vector2) -> bool:
	if not _admissible() or not is_instance_valid(_viewport_control):
		return false
	var caption_point := _caption.get_global_transform_with_canvas().affine_inverse() * viewport_point
	var clip_point := _viewport_control.get_global_transform_with_canvas().affine_inverse() * viewport_point
	return Rect2(Vector2.ZERO, _caption.size).has_point(caption_point) \
		and Rect2(Vector2.ZERO, _viewport_control.size).has_point(clip_point)

func _is_pointer(event: InputEvent) -> bool:
	return event is InputEventMouseButton or event is InputEventScreenTouch

func _pointer_position(event: InputEvent) -> Vector2:
	if event is InputEventMouseButton:
		return event.position
	if event is InputEventScreenTouch:
		return event.position
	return Vector2.ZERO

func _is_double_or_canceled(event: InputEvent) -> bool:
	if event is InputEventMouseButton:
		return event.double_click or event.canceled
	if event is InputEventScreenTouch:
		return event.double_tap or event.canceled
	return false

func _source(event: InputEvent) -> String:
	if event is InputEventScreenTouch:
		return "touch:%s:%s" % [event.device, event.index]
	if event is InputEventMouseButton:
		return "mouse:%s" % event.device if event.button_index == MOUSE_BUTTON_LEFT else ""
	if not event.is_action(_action()):
		return ""
	if event is InputEventKey:
		return "key:%s:%s" % [event.device, event.physical_keycode if event.physical_keycode else event.keycode]
	if event is InputEventJoypadButton:
		return "joy:%s:%s" % [event.device, event.button_index]
	if event is InputEventAction:
		return "action:%s:%s" % [event.device, event.action]
	return ""
