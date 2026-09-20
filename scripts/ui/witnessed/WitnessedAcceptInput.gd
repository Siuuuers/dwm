extends Node
## Mounted policy for the current caption. Dialogic Inputs remains the command owner.

signal normal_accept_requested

const ACTION_SETTING := "dialogic/text/input_action"
const TAP_LIMIT_MSEC := 500

var _scene_input: Control
var _review_caption: Control
var _caption: DialogicNode_DialogText
var _viewport_control: ScrollContainer
var _runtime: Node
var _contacts: Dictionary = {}
var _candidate: Dictionary = {}
var _fresh_key_event := 0
var _accepted_frame := -1
var _await_initial_neutral := false
var _foreground := true
var _page_contacts: Dictionary = {}
var _fresh_page_source := ""
var _await_page_neutral := false
var _paged_frame := -1
var _input_custody: Node
var _before_accept: Callable
var _automatic_admission: Callable
var _local_admission: Callable
var _submitting := false

func _enter_tree() -> void:
	add_to_group("dialogic_input_policy")
	# Paused source input remains inert, but releases must not be lost with the tree.
	process_mode = Node.PROCESS_MODE_ALWAYS

func bind(caption: DialogicNode_DialogText, viewport_control: ScrollContainer, runtime: Node) -> void:
	_caption = caption
	_viewport_control = viewport_control
	_runtime = runtime
	var input_owner := get_node_or_null("/root/InputManager")
	if input_owner != null:
		bind_input_custody(input_owner)
	_await_initial_neutral = Input.is_action_pressed(_action())
	_await_page_neutral = _page_is_held()
	_caption.visibility_changed.connect(_cancel_candidate)
	_caption.focus_exited.connect(_cancel_candidate)
	_viewport_control.get_v_scroll_bar().value_changed.connect(cancel_pending_accept)
	if _runtime != null and _runtime.has_signal("dialogic_paused"):
		_runtime.connect("dialogic_paused", _cancel_candidate)

func bind_scene_input(control: Control) -> void:
	_scene_input = control

func set_review_caption(control: Control) -> void:
	_review_caption = control
	if is_instance_valid(control) and not control.focus_exited.is_connected(_cancel_candidate):
		control.focus_exited.connect(_cancel_candidate)
	retire_input()

func _focus_caption() -> Control:
	return _review_caption if is_instance_valid(_review_caption) else _caption

func bind_input_custody(owner: Node) -> bool:
	if owner == null or not owner.has_method("is_source_input_admitted") \
			or not owner.has_signal("source_input_custody_changed"):
		return false
	if _input_custody != null:
		return _input_custody == owner
	_input_custody = owner
	owner.connect("source_input_custody_changed", _on_input_custody_changed)
	_on_input_custody_changed()
	return true


func bind_presentation_admission(before_accept: Callable, automatic_admission: Callable) -> bool:
	if not before_accept.is_valid() or not automatic_admission.is_valid(): return false
	_before_accept = before_accept
	_automatic_admission = automatic_admission
	return true


## Queried by the native text event immediately before automatic advancement.
func is_automatic_advance_admitted(runtime: Node) -> bool:
	if runtime != _runtime: return true
	return _admissible() and (not _automatic_admission.is_valid() or bool(_automatic_admission.call()))

func _on_input_custody_changed() -> void:
	_cancel_candidate()
	_fresh_key_event = 0
	_await_initial_neutral = not _contacts.is_empty() or Input.is_action_pressed(_action())
	_await_page_neutral = not _page_contacts.is_empty() or _page_is_held()

func _source_has_custody() -> bool:
	return (not _local_admission.is_valid() or bool(_local_admission.call())) \
		and (_input_custody == null or (is_instance_valid(_input_custody) \
		and bool(_input_custody.call("is_source_input_admitted"))))

func bind_local_admission(admission: Callable) -> void:
	_local_admission = admission
	retire_input()

func retire_input() -> void:
	_on_input_custody_changed()

func _cancel_candidate() -> void:
	_candidate.clear()
	_fresh_page_source = ""

func cancel_pending_accept(_scroll_value: float = 0.0) -> void:
	# Real scrollbar movement (including its native gutter) also cancels contact.
	_candidate.clear()

func _action() -> StringName:
	return StringName(ProjectSettings.get_setting(ACTION_SETTING, "dialogic_default_action"))

func _admissible() -> bool:
	return _source_has_custody() and not get_tree().paused and _foreground and is_instance_valid(_runtime) and not bool(_runtime.get("paused")) \
		and is_instance_valid(_caption) and _focus_caption().is_visible_in_tree() \
		and not _caption.get_parsed_text().is_empty()


func is_source_admitted() -> bool:
	return _admissible()

func _process(_delta: float) -> void:
	if not _candidate.is_empty() and (not _admissible() \
			or _candidate.generation != _caption.get_reveal_generation()):
		_candidate.clear()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_foreground = false
		_cancel_candidate()
		_fresh_key_event = 0
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_foreground = true

func _input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventPanGesture or (event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]):
		cancel_pending_accept()
		return
	if _page_direction(event) != 0:
		_track_page_contact(event)
		return
	if event is InputEventScreenDrag:
		_candidate.clear()
		return
	if event is InputEventMouseMotion:
		if not _inside_source(event.position) or (not _candidate.is_empty() and _candidate.has("origin") \
				and event.position.distance_to(_candidate.origin) > 12.0):
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
		if _is_pointer(event): _candidate.origin = _pointer_position(event)
		if not _is_pointer(event):
			_fresh_key_event = event.get_instance_id()
	else:
		_contacts.erase(source)
		if _contacts.is_empty() and not Input.is_action_pressed(_action()):
			_await_initial_neutral = false
		if not _candidate.is_empty() and _candidate.source == source:
			if _is_double_or_canceled(event) or (_is_pointer(event) and not _inside_source(_pointer_position(event))):
				_candidate.clear()

func _unhandled_input(event: InputEvent) -> void:
	if get_tree().paused or not _source_has_custody():
		return
	if handle_page_input(event):
		get_viewport().set_input_as_handled()
		return
	if _is_pointer(event) or _source(event).is_empty():
		return
	# Consume rejected mapped packets too: a held contact must not reach fallback.
	get_viewport().set_input_as_handled()
	if event.get_instance_id() == _fresh_key_event and event.is_pressed() \
			and not event.is_echo() and is_instance_valid(_caption) and _focus_caption().has_focus():
		_submit(false)

func handle_page_input(event: InputEvent) -> bool:
	if get_tree().paused or not _source_has_custody():
		return false
	var direction := _page_direction(event)
	if direction == 0 or not is_instance_valid(_caption) or not _focus_caption().has_focus():
		return false
	# Current-caption GUI gets first refusal; unhandled input is the controller fallback.
	if event.is_pressed() and not event.is_echo() and _fresh_page_source == _physical_source(event):
		_fresh_page_source = ""
		if _admissible():
			cancel_pending_accept()
			var bar := _viewport_control.get_v_scroll_bar()
			if bar.max_value > bar.page and _paged_frame != Engine.get_process_frames():
				_paged_frame = Engine.get_process_frames()
				bar.value += bar.page * direction
	return true

func _track_page_contact(event: InputEvent) -> void:
	var source := _physical_source(event)
	_fresh_page_source = ""
	if event.is_pressed():
		if event.is_echo() or _page_contacts.has(source):
			return
		var neutral := _page_contacts.is_empty()
		_page_contacts[source] = true
		if neutral and not _await_page_neutral and _admissible() and _focus_caption().has_focus():
			_fresh_page_source = source
	else:
		_page_contacts.erase(source)
		if _page_contacts.is_empty() and not _page_is_held():
			_await_page_neutral = false

func _page_direction(event: InputEvent) -> int:
	# Shoulder defaults are local to this viewport; shared Controls mapping is separate.
	if event is InputEventJoypadButton:
		if event.button_index == JOY_BUTTON_LEFT_SHOULDER:
			return -1
		if event.button_index == JOY_BUTTON_RIGHT_SHOULDER:
			return 1
	if event is InputEventKey or event is InputEventAction:
		if event.is_action(&"ui_page_up", true):
			return -1
		if event.is_action(&"ui_page_down", true):
			return 1
	return 0

func _page_is_held() -> bool:
	if Input.is_action_pressed(&"ui_page_up") or Input.is_action_pressed(&"ui_page_down"):
		return true
	for device: int in Input.get_connected_joypads():
		if Input.is_joy_button_pressed(device, JOY_BUTTON_LEFT_SHOULDER) \
				or Input.is_joy_button_pressed(device, JOY_BUTTON_RIGHT_SHOULDER):
			return true
	return false

func handle_caption_gui_input(event: InputEvent) -> void:
	handle_background_gui_input(event, _caption)

func handle_background_gui_input(event: InputEvent, source_control: Control) -> void:
	if get_tree().paused or not _source_has_custody():
		return
	if event.device == InputEvent.DEVICE_ID_EMULATION or not _is_pointer(event):
		return
	var source := _source(event)
	if source.is_empty() or _candidate.is_empty() or _candidate.source != source:
		return
	# GUI positions are local; the raw phase and this phase both check the aperture clip.
	var viewport_point: Vector2 = source_control.get_global_transform_with_canvas() * _pointer_position(event)
	if not _inside_source(viewport_point) or _is_double_or_canceled(event):
		_candidate.clear()
		return
	if not event.is_pressed() and _release_hits_control(viewport_point):
		_candidate.clear()
		return
	if event.is_pressed():
		_candidate.armed = true
		_focus_caption().grab_focus()
	elif bool(_candidate.armed):
		if event is InputEventScreenTouch and Time.get_ticks_msec() - int(_candidate.started) > TAP_LIMIT_MSEC:
			_candidate.clear()
			return
		_submit(true)

func _submit(pointer: bool) -> void:
	if _candidate.is_empty() or _submitting:
		return
	var generation: int = _candidate.generation
	_candidate.clear()
	if not _admissible() or generation != _caption.get_reveal_generation() \
			or _accepted_frame == Engine.get_process_frames():
		return
	_submitting = true
	normal_accept_requested.emit()
	if not _admissible() or generation != _caption.get_reveal_generation() \
			or (_before_accept.is_valid() and not bool(_before_accept.call())):
		_submitting = false
		return
	if not _admissible() or generation != _caption.get_reveal_generation():
		_submitting = false
		return
	_accepted_frame = Engine.get_process_frames()
	var inputs: Object = _runtime.call("get_subsystem", "Inputs")
	if inputs != null:
		inputs.set("input_was_mouse_input", pointer)
		inputs.call("handle_input")
		if is_instance_valid(inputs):
			inputs.set("input_was_mouse_input", false)
	_submitting = false

func _release_hits_control(viewport_point: Vector2) -> bool:
	# A captured release still belongs to the pressed background Control. Check
	# the real buttons/scrollbar under it so crossing an edge cannot accept prose.
	var controls: Array[Node] = get_tree().get_nodes_in_group("dialogic_choice_button")
	if is_instance_valid(_scene_input):
		controls.append_array(_scene_input.get_parent().find_children("*", "BaseButton", true, false))
	if is_instance_valid(_viewport_control): controls.append(_viewport_control.get_v_scroll_bar())
	for node: Node in controls:
		if not node is Control or not node.is_visible_in_tree(): continue
		var control := node as Control
		if Rect2(Vector2.ZERO, control.size).has_point(
				control.get_global_transform_with_canvas().affine_inverse() * viewport_point): return true
	return false

func _inside_source(viewport_point: Vector2) -> bool:
	if is_instance_valid(_scene_input):
		return _admissible() and _scene_input.is_visible_in_tree() and Rect2(Vector2.ZERO, _scene_input.size).has_point(
			_scene_input.get_global_transform_with_canvas().affine_inverse() * viewport_point)
	return _inside_current(viewport_point)

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
	return _physical_source(event)

func _physical_source(event: InputEvent) -> String:
	if event is InputEventKey:
		return "key:%s:%s" % [event.device, event.physical_keycode if event.physical_keycode else event.keycode]
	if event is InputEventJoypadButton:
		return "joy:%s:%s" % [event.device, event.button_index]
	if event is InputEventAction:
		return "action:%s:%s" % [event.device, event.action]
	return ""
