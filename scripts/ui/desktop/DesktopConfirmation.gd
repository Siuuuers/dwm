extends Control
## Shared in-run confirmation host. It owns geometry and input custody only.

const KEY := preload("res://scripts/ui/backup/BackupKey.gd")
# A literal Warning triangle and exclamation; working geometry, not an assertion
# that a previously registered glyph asset was found or accepted.
const WARNING_GLYPH := ["000001100000", "000010010000", "000010010000",
	"000100001000", "000101101000", "001001100100", "001001100100",
	"010000000010", "010001100010", "100000000001", "111111111111"]
signal finished(accepted: bool)
var request: Dictionary = {}
var cancel_button: Button
var confirm_button: Button
var body_scroll: ScrollContainer
var _lower_controls: Array[Dictionary] = []
var _settled := false
var _cancelable := true
var _held: Dictionary = {}
var _navigation_held: Dictionary = {}
var _native_source := ""
var _touch: Dictionary = {}
var _await_neutral := false

func _ready() -> void:
	_cancelable = request.get("cancelable", true)
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP
	_await_neutral = Input.is_action_pressed(&"ui_accept") or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT)
	for sibling in get_parent().get_children():
		if sibling != self:
			_suspend(sibling)
	var sheet := PanelContainer.new()
	sheet.name = "ConfirmationSheet"
	_layout_sheet(sheet)
	resized.connect(_layout_sheet.bind(sheet))
	var paper := StyleBoxFlat.new()
	paper.bg_color = get_theme_color("paper", "Backup")
	paper.border_color = get_theme_color("paper_ink", "Backup")
	paper.set_border_width_all(2)
	for edge in ["left", "right", "top", "bottom"]:
		paper.set("content_margin_" + edge, 16)
	sheet.add_theme_stylebox_override("panel", paper)
	if request.get("warning", true):
		sheet.draw.connect(func(): sheet.draw_rect(Rect2(4, 8, 2, sheet.size.y - 16), get_theme_color("paper_ink", "Backup")))
	add_child(sheet)
	var layout := VBoxContainer.new()
	layout.add_theme_constant_override("separation", 16)
	sheet.add_child(layout)
	if request.get("warning", true):
		var warning := Control.new()
		warning.name = "WarningGlyph"
		warning.custom_minimum_size = Vector2(24, 24)
		warning.mouse_filter = Control.MOUSE_FILTER_IGNORE
		warning.draw.connect(func():
			for y in WARNING_GLYPH.size():
				for x in WARNING_GLYPH[y].length():
					if WARNING_GLYPH[y][x] == "1":
						warning.draw_rect(Rect2(x * 2, y * 2, 2, 2), get_theme_color("paper_ink", "Backup")))
		layout.add_child(warning)
	body_scroll = ScrollContainer.new()
	body_scroll.name = "ConfirmationBody"
	body_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	body_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	layout.add_child(body_scroll)
	var body := Label.new()
	body.text = str(request.get("title", "")) + "\n\n" + str(request.get("body", ""))
	body.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_color_override("font_color", get_theme_color("paper_ink", "Backup"))
	body_scroll.add_child(body)
	var actions := HBoxContainer.new()
	actions.name = "ConfirmationActions"
	actions.add_theme_constant_override("separation", 16)
	layout.add_child(actions)
	cancel_button = KEY.new()
	cancel_button.name = "CancelButton"
	cancel_button.set_caption(str(request.get("cancel", "Cancel")))
	confirm_button = KEY.new()
	confirm_button.name = "ConfirmButton"
	confirm_button.set_caption(str(request.get("confirm", "")))
	confirm_button.risk = str(request.get("risk", "neutral")) if _cancelable else "neutral"
	for button in [cancel_button, confirm_button]:
		button.action_mode = BaseButton.ACTION_MODE_BUTTON_RELEASE
		button.custom_minimum_size = Vector2(248, 64)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	cancel_button.pressed.connect(_finish.bind(false))
	confirm_button.pressed.connect(_finish.bind(true))
	if not _cancelable:
		cancel_button.hide()
		cancel_button.disabled = true
		cancel_button.focus_mode = Control.FOCUS_NONE
		confirm_button.accessibility_description = body.text
	cancel_button.accessibility_description = body.text
	for button: Button in [cancel_button, confirm_button]:
		var other: Button = (confirm_button if button == cancel_button else cancel_button) if _cancelable else button
		button.focus_next = button.get_path_to(other)
		button.focus_previous = button.get_path_to(other)
		button.focus_neighbor_left = button.get_path_to(cancel_button if _cancelable else button)
		button.focus_neighbor_right = button.get_path_to(confirm_button if _cancelable else button)
		button.focus_neighbor_top = button.get_path()
		button.focus_neighbor_bottom = button.get_path()
	body_scroll.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	(cancel_button if _cancelable else confirm_button).grab_focus()
	visibility_changed.connect(_on_visibility_changed)

func _layout_sheet(sheet: Control) -> void:
	# Keep confirmation actions above the fixed desktop footer at every scale.
	sheet.size = Vector2(560, minf(480, maxf(0, size.y - 96)))
	sheet.position = Vector2(120, minf(112, maxf(16, size.y - 80 - sheet.size.y)))


func _suspend(node: Node) -> void:
	if node is Control:
		_lower_controls.append({"node":weakref(node),"focus":node.focus_behavior_recursive,
			"mouse":node.mouse_behavior_recursive})
		node.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
		node.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		var focused := get_viewport().gui_get_focus_owner()
		if focused != null and (focused == node or node.is_ancestor_of(focused)): focused.release_focus()
		return
	for child: Node in node.get_children(): _suspend(child)

func _restore_custody() -> void:
	for prior: Dictionary in _lower_controls:
		var control: Control = prior.node.get_ref() as Control
		if is_instance_valid(control):
			control.focus_behavior_recursive = prior.focus
			control.mouse_behavior_recursive = prior.mouse
	_lower_controls.clear()

func _exit_tree() -> void:
	_restore_custody()

func _finish(accepted: bool) -> void:
	if _settled or (not accepted and not _cancelable): return
	_settled = true
	# Consume before lower controls or a finished observer regain custody.
	get_viewport().set_input_as_handled()
	_restore_custody()
	hide()
	finished.emit(accepted)
	queue_free()

func invalidate_pending_input() -> void:
	# Keep the contact ledger until release; restoring custody must not revive consent.
	_native_source = ""
	_cancel_touch()
	_await_neutral = (not _held.is_empty() or Input.is_action_pressed(&"ui_accept")
		or Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT))
	for button: Button in [cancel_button,confirm_button]:
		if is_instance_valid(button): button.set_pressed_no_signal(false)

func _on_visibility_changed() -> void:
	if not is_visible_in_tree(): invalidate_pending_input()

func _input(event: InputEvent) -> void:
	if _settled: return
	if not is_visible_in_tree(): return
	if event.is_echo():
		get_viewport().set_input_as_handled()
		return
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		get_viewport().set_input_as_handled()
		return
	if event.is_action(&"ui_cancel"):
		get_viewport().set_input_as_handled()
		if event.is_pressed():
			if not _cancelable: invalidate_pending_input()
			_finish(false)
		return
	if event is InputEventScreenDrag:
		invalidate_pending_input()
		get_viewport().set_input_as_handled()
		return
	if (event is InputEventPanGesture or (event is InputEventMouseButton
		and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,
		MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT] and event.pressed)):
		invalidate_pending_input()
	var source := _accept_source(event)
	if not source.is_empty():
		if event.is_pressed():
			var fresh := _held.is_empty() and not _await_neutral
			if _held.has(source):
				get_viewport().set_input_as_handled()
				return
			_held[source] = true
			if not fresh or _double_or_canceled(event):
				invalidate_pending_input()
				get_viewport().set_input_as_handled()
				return
			if event is InputEventScreenTouch:
				var button := _button_at(event.position)
				if button != null:
					_touch = {"source":source,"button":button,"started":Time.get_ticks_msec()}
					button.grab_focus()
					button.set_pressed_no_signal(true)
				get_viewport().set_input_as_handled()
			else:
				_native_source = source
		else:
			_held.erase(source)
			if _held.is_empty() and not Input.is_action_pressed(&"ui_accept") and not Input.is_mouse_button_pressed(MOUSE_BUTTON_LEFT):
				_await_neutral = false
			if event is InputEventScreenTouch:
				var button: Button = _touch.get("button")
				var activate: bool = (not _touch.is_empty() and _touch.source == source
					and not _double_or_canceled(event)
					and Time.get_ticks_msec()-int(_touch.started) <= 500
					and button == _button_at(event.position))
				_cancel_touch()
				get_viewport().set_input_as_handled()
				if activate: _finish(button == confirm_button)
			elif source == _native_source and not _double_or_canceled(event):
				_native_source = ""
				# Native Button GUI receives only its own admitted release.
			else:
				get_viewport().set_input_as_handled()
		return
	if _navigation_event(event):
		if event.is_pressed(): invalidate_pending_input()
		var key := _physical_source(event)
		if event.is_pressed():
			if _navigation_held.has(key):
				get_viewport().set_input_as_handled()
				return
			_navigation_held[key] = true
			if event.is_action(&"ui_up") or event.is_action(&"ui_down") or event.is_action(&"ui_page_up") or event.is_action(&"ui_page_down"):
				var backwards := event.is_action(&"ui_up") or event.is_action(&"ui_page_up")
				var distance := 240 if event.is_action(&"ui_page_up") or event.is_action(&"ui_page_down") else 48
				body_scroll.scroll_vertical += -distance if backwards else distance
				get_viewport().set_input_as_handled()
		else: _navigation_held.erase(key)

func _unhandled_input(event: InputEvent) -> void:
	if is_visible_in_tree() and (event is InputEventKey or event is InputEventAction or event is InputEventJoypadButton):
		get_viewport().set_input_as_handled()

func _accept_source(event: InputEvent) -> String:
	if event is InputEventScreenTouch: return "touch:%d:%d" % [event.device,event.index]
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		return "mouse:%d" % event.device
	if event.is_action(&"ui_accept"): return _physical_source(event)
	return ""

func _physical_source(event: InputEvent) -> String:
	if event is InputEventKey: return "key:%d:%d" % [event.device,event.physical_keycode if event.physical_keycode else event.keycode]
	if event is InputEventJoypadButton: return "pad:%d:%d" % [event.device,event.button_index]
	if event is InputEventAction: return "action:%s" % event.action
	return str(event.get_instance_id())

func _navigation_event(event: InputEvent) -> bool:
	for action: StringName in [&"ui_focus_next",&"ui_focus_prev",&"ui_left",&"ui_right",&"ui_up",&"ui_down",&"ui_page_up",&"ui_page_down"]:
		if event.is_action(action): return true
	return false

func _double_or_canceled(event: InputEvent) -> bool:
	return ((event is InputEventMouseButton and event.double_click)
		or (event is InputEventScreenTouch and (event.double_tap or event.canceled)))

func _button_at(point: Vector2) -> Button:
	for button: Button in [cancel_button,confirm_button]:
		var local := button.get_global_transform_with_canvas().affine_inverse()*point
		if button.is_visible_in_tree() and not button.disabled and Rect2(Vector2.ZERO,button.size).has_point(local): return button
	return null

func _cancel_touch() -> void:
	var button: Button = _touch.get("button")
	if is_instance_valid(button): button.set_pressed_no_signal(false)
	_touch.clear()
