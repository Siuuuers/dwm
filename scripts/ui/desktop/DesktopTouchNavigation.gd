class_name DesktopTouchNavigation
extends HBoxContainer

var previous_button: Button
var next_button: Button
var confirm_button: Button

var _focus_scope_provider := Callable()
var _input_admitted := Callable()
var _held_source := ""
var _held_button: Button
var _held_canceled := false
var _held_scope_id := 0
var _held_focus_id := 0
var _confirm_generation := 0


func configure(focus_scope_provider: Callable, input_admitted: Callable) -> Dictionary:
	if not focus_scope_provider.is_valid() or focus_scope_provider.get_argument_count() != 0:
		return {"ok": false, "code": &"invalid_focus_scope_provider"}
	if not input_admitted.is_valid() or input_admitted.get_argument_count() != 0:
		return {"ok": false, "code": &"invalid_input_admitted_provider"}
	_focus_scope_provider = focus_scope_provider
	_input_admitted = input_admitted
	return {"ok": true, "code": &"ok"}


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	set_process(false)
	add_theme_constant_override("separation", 8)
	mouse_filter = Control.MOUSE_FILTER_STOP
	previous_button = _make_button("Previous")
	next_button = _make_button("Next")
	confirm_button = _make_button("Confirm")
	visibility_changed.connect(_cancel_pointer)


func _make_button(node_name: String) -> Button:
	var button := Button.new()
	button.name = node_name
	button.custom_minimum_size = Vector2(56, 56)
	button.focus_mode = Control.FOCUS_NONE
	button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
	button.mouse_filter = Control.MOUSE_FILTER_STOP
	button.pressed.connect(_activate.bind(button))
	add_child(button)
	return button


func _input(event: InputEvent) -> void:
	if not is_visible_in_tree() or not can_process():
		return
	if event is InputEventMouseButton and event.device == InputEvent.DEVICE_ID_EMULATION:
		return
	if event is InputEventScreenDrag:
		if not _held_source.is_empty() and _held_source == _source(event):
			_held_canceled = true
			get_viewport().set_input_as_handled()
		return
	if not event is InputEventScreenTouch and not (
			event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT):
		return
	var source := _source(event)
	if event.pressed:
		var button := _button_at(event.position)
		if button == null:
			return
		get_viewport().set_input_as_handled()
		if not _held_source.is_empty():
			_held_canceled = true
			return
		_held_source = source
		_held_button = button
		_held_canceled = _pointer_canceled(event) or not _capture_pointer_context()
		button.set_pressed_no_signal(not _held_canceled)
		set_process(true)
		return
	if source != _held_source:
		if _button_at(event.position) != null:
			get_viewport().set_input_as_handled()
		return
	var button := _held_button
	var activate := not _held_canceled and _pointer_context_is_current() \
		and not _pointer_canceled(event) \
		and button == _button_at(event.position)
	_cancel_pointer()
	get_viewport().set_input_as_handled()
	if activate:
		_activate(button)


func _source(event: InputEvent) -> String:
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		return "touch:%d:%d" % [event.device, event.index]
	return "mouse:%d" % event.device


func _pointer_canceled(event: InputEvent) -> bool:
	return (event is InputEventScreenTouch and (event.canceled or event.double_tap)) \
		or (event is InputEventMouseButton and event.double_click)


func _button_at(viewport_point: Vector2) -> Button:
	for button: Button in [previous_button, next_button, confirm_button]:
		if not is_instance_valid(button) or not button.is_visible_in_tree() or button.disabled:
			continue
		var local := button.get_global_transform_with_canvas().affine_inverse() * viewport_point
		if Rect2(Vector2.ZERO, button.size).has_point(local):
			return button
	return null


func _cancel_pointer() -> void:
	_confirm_generation += 1
	if is_instance_valid(_held_button):
		_held_button.set_pressed_no_signal(false)
	_held_source = ""
	_held_button = null
	_held_canceled = false
	_held_scope_id = 0
	_held_focus_id = 0
	set_process(false)


func _capture_pointer_context() -> bool:
	if not _input_admitted.is_valid() or not bool(_input_admitted.call()) \
			or Input.is_action_pressed(&"ui_accept") or not _focus_scope_provider.is_valid():
		return false
	var scope: Variant = _focus_scope_provider.call()
	if not scope is Control or not _scope_available(scope as Control):
		return false
	_held_scope_id = (scope as Control).get_instance_id()
	var focused := get_viewport().gui_get_focus_owner()
	_held_focus_id = focused.get_instance_id() if _eligible(focused) \
		and _contains(scope as Control, focused) else 0
	return true


func _pointer_context_is_current() -> bool:
	if not _input_admitted.is_valid() or not bool(_input_admitted.call()) \
			or Input.is_action_pressed(&"ui_accept") or not _focus_scope_provider.is_valid():
		return false
	var scope: Variant = _focus_scope_provider.call()
	if not scope is Control or not _scope_available(scope as Control) \
			or (scope as Control).get_instance_id() != _held_scope_id:
		return false
	var focused := get_viewport().gui_get_focus_owner()
	var focus_id := focused.get_instance_id() if _eligible(focused) \
		and _contains(scope as Control, focused) else 0
	return focus_id == _held_focus_id


func _process(_delta: float) -> void:
	if not _held_source.is_empty() and not _pointer_context_is_current():
		_held_canceled = true
		if is_instance_valid(_held_button):
			_held_button.set_pressed_no_signal(false)


func _notification(what: int) -> void:
	if what in [NOTIFICATION_APPLICATION_FOCUS_OUT, NOTIFICATION_PAUSED]:
		_cancel_pointer()


func _activate(button: Button) -> void:
	if not _input_admitted.is_valid() or not bool(_input_admitted.call()):
		return
	var scope: Variant = _focus_scope_provider.call() if _focus_scope_provider.is_valid() else null
	if not scope is Control:
		return
	var scope_control := scope as Control
	if not _scope_available(scope_control):
		return
	var focused := get_viewport().gui_get_focus_owner()
	if not _eligible(focused) or not _contains(scope_control, focused):
		var first := _first_eligible(scope_control)
		if first != null:
			first.grab_focus(false)
		return
	if button == confirm_button:
		_confirm_generation += 1
		_dispatch_accept.call_deferred(_confirm_generation, scope_control.get_instance_id(),
			focused.get_instance_id())
		return
	var forward := button == next_button
	var target: Control = focused.find_next_valid_focus() if forward \
		else focused.find_prev_valid_focus()
	if not _eligible(target) or not _contains(scope_control, target) or target == focused:
		target = _ordered_neighbor(scope_control, focused, 1 if forward else -1)
	if target != null and target != focused:
		target.grab_focus(false)


func _scope_available(scope: Control) -> bool:
	return is_instance_valid(scope) and scope.is_inside_tree() and scope.is_visible_in_tree() \
		and scope.get_viewport() == get_viewport() and scope.can_process() \
		and _focus_behavior_enabled(scope)


func _contains(scope: Control, target: Control) -> bool:
	return target == scope or scope.is_ancestor_of(target)


func _eligible(control: Control) -> bool:
	if not is_instance_valid(control) or not control.is_inside_tree() \
			or not control.is_visible_in_tree() or not control.can_process() \
			or control.get_viewport() != get_viewport() \
			or control.get_focus_mode_with_override() != Control.FOCUS_ALL \
			or not _focus_behavior_enabled(control):
		return false
	return not (control is BaseButton and (control as BaseButton).disabled)


func _focus_behavior_enabled(control: Control) -> bool:
	var current: Control = control
	while current != null:
		if current.focus_behavior_recursive != Control.FOCUS_BEHAVIOR_INHERITED:
			return current.focus_behavior_recursive == Control.FOCUS_BEHAVIOR_ENABLED
		current = current.get_parent_control()
	return true


func _first_eligible(scope: Control) -> Control:
	var controls: Array[Control] = []
	_collect_eligible(scope, controls)
	return controls[0] if not controls.is_empty() else null


func _ordered_neighbor(scope: Control, focused: Control, direction: int) -> Control:
	var controls: Array[Control] = []
	_collect_eligible(scope, controls)
	var index := controls.find(focused)
	if index < 0 or controls.size() < 2:
		return null
	return controls[posmod(index + direction, controls.size())]


func _collect_eligible(node: Node, out: Array[Control]) -> void:
	if node is Control and _eligible(node as Control):
		out.append(node as Control)
	for child: Node in node.get_children():
		_collect_eligible(child, out)


func _dispatch_accept(generation: int, scope_id: int, focus_id: int) -> void:
	if generation != _confirm_generation or not is_visible_in_tree() or not can_process() \
			or not _input_admitted.is_valid() \
			or not bool(_input_admitted.call()) or not _focus_scope_provider.is_valid():
		return
	var scope: Variant = _focus_scope_provider.call()
	if not scope is Control or not is_instance_valid(scope) \
			or (scope as Control).get_instance_id() != scope_id \
			or not _scope_available(scope as Control):
		return
	var focused := get_viewport().gui_get_focus_owner()
	if not _eligible(focused) or focused.get_instance_id() != focus_id \
			or not _contains(scope as Control, focused):
		return
	var viewport := get_viewport()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.device = 0
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		viewport.push_input(event, true)
