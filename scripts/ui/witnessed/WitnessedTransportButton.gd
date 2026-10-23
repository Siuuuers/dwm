class_name WitnessedTransportButton
extends Button

signal activated

const TAP_LIMIT_MSEC := 500
const POINTER_SLOP := 8.0
const ACTION_SETTING := "dialogic/text/input_action"

var _admission: Callable
var _input_owner: Node
var _contacts: Dictionary = {}
var _blocked_contacts: Dictionary = {}
var _candidate: Dictionary = {}
var _fresh_contact := ""
var _generation := 0
var _retired_frame := -1
var _foreground := true
var _bound := false


func _ready() -> void:
	gui_input.connect(_on_gui_input)
	focus_exited.connect(retire_input)


func bind_admission(admission: Callable, input_owner: Node) -> bool:
	if not admission.is_valid() or admission.get_argument_count() != 0 \
			or not is_instance_valid(input_owner): return false
	for method: String in ["get_physical_contacts", "observe_physical_contact", "get_physical_contact_id", "is_source_input_admitted"]:
		if not input_owner.has_method(method): return false
	for event: String in ["source_input_custody_changed", "input_bindings_changed"]:
		if not input_owner.has_signal(event): return false
	if _bound:
		return _admission == admission and _input_owner == input_owner
	_bound = true
	_admission = admission
	_input_owner = input_owner
	input_owner.connect("source_input_custody_changed", retire_input)
	input_owner.connect("input_bindings_changed", retire_input)
	process_mode = Node.PROCESS_MODE_ALWAYS
	retire_input()
	return true


func retire_input() -> void:
	_candidate.clear()
	_fresh_contact = ""
	_generation += 1
	_retired_frame = Engine.get_process_frames()
	if is_instance_valid(_input_owner):
		_contacts = _input_owner.get_physical_contacts()
		_blocked_contacts = _contacts.duplicate()
	if is_inside_tree(): queue_accessibility_update()


func _notification(what: int) -> void:
	if what == NOTIFICATION_ACCESSIBILITY_UPDATE:
		if not _bound: return
		var element := get_accessibility_element()
		if element.is_valid():
			DisplayServer.accessibility_update_add_action(element, DisplayServer.ACTION_CLICK,
				_on_accessibility_click.bind(_generation))
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_foreground = false
		retire_input()
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN, NOTIFICATION_APPLICATION_FOCUS_IN]:
		_foreground = true
		retire_input()
	elif what in [NOTIFICATION_PAUSED, NOTIFICATION_UNPAUSED, NOTIFICATION_DISABLED, NOTIFICATION_ENABLED]:
		retire_input()


func _process(_delta: float) -> void:
	if not is_instance_valid(_input_owner): return
	_prune_blocked_contacts()
	if not _candidate.is_empty() and not _admitted(): _candidate.clear()


func _input(event: InputEvent) -> void:
	if not is_instance_valid(_input_owner) or event.device == InputEvent.DEVICE_ID_EMULATION: return
	# Logical InputEventAction packets have no physical provenance. They may never mint
	# a transport activation even though InputManager conservatively ledgers them.
	if event is InputEventAction: return
	_input_owner.observe_physical_contact(event)
	_prune_blocked_contacts()
	var id: String = _input_owner.get_physical_contact_id(event)
	var current: Dictionary = _input_owner.get_physical_contacts()
	_fresh_contact = ""
	if not id.is_empty() and event.is_pressed() and current.get(id) != _contacts.get(id):
		_fresh_contact = id
	_contacts = current
	if current.size() > 1:
		retire_input()
		return
	if event is InputEventScreenDrag:
		_cancel_moved_pointer("touch:%s:%s" % [event.device, event.index], event.position)
	elif event is InputEventMouseMotion:
		_cancel_moved_pointer("mouse:%s:%s" % [event.device, MOUSE_BUTTON_LEFT], event.position)
	elif (event is InputEventScreenTouch and event.canceled) \
			or (event is InputEventMouseButton and event.canceled):
		_candidate.clear()
	if (event is InputEventKey or event is InputEventJoypadButton) \
			and _is_accept(event) and has_focus():
		if event.is_pressed():
			get_viewport().set_input_as_handled()
			if not event.is_echo() and id == _fresh_contact and _one_contact(id) and _admitted():
				_candidate = {"id": id, "generation": _generation}
		elif _candidate.get("id") == id:
			get_viewport().set_input_as_handled()
			_activate_candidate()


func _on_gui_input(event: InputEvent) -> void:
	if event.device == InputEvent.DEVICE_ID_EMULATION: return
	if event is InputEventMouseButton:
		if event.button_index != MOUSE_BUTTON_LEFT: return
		accept_event()
		_handle_pointer(event)
		return
	if event is InputEventScreenTouch:
		accept_event()
		_handle_pointer(event)
		return


func _handle_pointer(event: InputEvent) -> void:
	if not is_instance_valid(_input_owner): return
	var id: String = _input_owner.get_physical_contact_id(event)
	if event.is_pressed():
		if id != _fresh_contact or not _one_contact(id) or not _admitted() or _pointer_canceled(event): return
		grab_focus()
		if id != _fresh_contact or not has_focus() or not _admitted(): return
		_candidate = {"id": id, "generation": _generation, "origin": event.position,
			"started": Time.get_ticks_msec(), "touch": event is InputEventScreenTouch}
	elif _candidate.get("id") == id:
		if _pointer_canceled(event) or not Rect2(Vector2.ZERO, size).has_point(event.position):
			_candidate.clear()
			return
		if bool(_candidate.get("touch", false)) \
				and Time.get_ticks_msec() - int(_candidate.started) > TAP_LIMIT_MSEC:
			_candidate.clear()
			return
		_activate_candidate()


func _activate_candidate() -> void:
	var admitted: bool = _candidate.get("generation", -1) == _generation and has_focus() and _admitted() \
		and is_instance_valid(_input_owner) and _input_owner.get_physical_contacts().is_empty()
	_candidate.clear()
	if admitted: _activate()


func _on_accessibility_click(_data: Variant, generation: int) -> void:
	if generation != _generation or not _admitted() or not is_instance_valid(_input_owner) \
			or not _input_owner.get_physical_contacts().is_empty(): return
	_activate()


func _activate() -> void:
	retire_input()
	activated.emit()


func _admitted() -> bool:
	return _bound and is_inside_tree() and not is_queued_for_deletion() and is_visible_in_tree() \
		and not disabled and _foreground and not get_tree().paused \
		and Engine.get_process_frames() != _retired_frame and _blocked_contacts.is_empty() \
		and is_instance_valid(_input_owner) and _input_owner.is_source_input_admitted() \
		and _admission.is_valid() and _admission.call() == true


func _one_contact(id: String) -> bool:
	if id.is_empty() or not is_instance_valid(_input_owner): return false
	var current: Dictionary = _input_owner.get_physical_contacts()
	return current.size() == 1 and current.has(id)


func _prune_blocked_contacts() -> void:
	var current: Dictionary = _input_owner.get_physical_contacts()
	for id: String in _blocked_contacts.keys():
		if current.get(id) != _blocked_contacts[id]: _blocked_contacts.erase(id)


func _cancel_moved_pointer(id: String, viewport_point: Vector2) -> void:
	if _candidate.get("id") != id or not _candidate.has("origin"): return
	var point := get_global_transform_with_canvas().affine_inverse() * viewport_point
	if point.distance_to(_candidate.origin) > POINTER_SLOP or not Rect2(Vector2.ZERO, size).has_point(point):
		_candidate.clear()


func _pointer_canceled(event: InputEvent) -> bool:
	if event is InputEventMouseButton: return event.double_click or event.canceled
	if event is InputEventScreenTouch: return event.double_tap or event.canceled
	return false


func _is_accept(event: InputEvent) -> bool:
	var caption_action := StringName(ProjectSettings.get_setting(ACTION_SETTING, "dialogic_default_action"))
	return event.is_action(&"ui_accept") or event.is_action(caption_action)
