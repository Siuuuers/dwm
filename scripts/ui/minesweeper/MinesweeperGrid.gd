extends Control
## Composite roving-focus grid over owner-published public cell facts.

signal cell_action_requested(action: StringName, index: int, revision: int)
signal new_board_requested()
signal pan_requested(delta: Vector2)
signal panning_changed(active: bool)
signal focused_cell_changed(index: int)
signal mode_changed(mode: StringName)

const CELL := preload("res://scripts/ui/minesweeper/MinesweeperCell.gd")
const TOP_KEYS := ["width","height","revision","mine_estimate","terminal","custody","cells"]
const MODES := [&"reveal",&"flag",&"drag"]
const TOGGLE_ACTION := &"game_toggle_board_mode"

var cell_nodes: Array[Control] = []
var focused_index := -1
var mode: StringName = &"reveal"
var projection: Dictionary = {}
## The exact projection instance can_present() last accepted; present() skips re-validating it.
var _last_validated_projection: Dictionary = {}
var _locale := "en"
var _percent := 100
var _large := false
var _palette: StringName = &"after_hours"
var _high_contrast := false
var _colour_preset := "standard"
var _held_index := -1
var _held_revision := -1
var _held_action: StringName = &""
var _held_button := 0
var _hovered_index := -1
var _joy_direction: StringName = &""
var _confirm_held := false
var _mouse_dragging := false
var _mouse_drag_displacement := Vector2.ZERO
var _touch_id := -1
var _touch_index := -1
var _touch_revision := -1
var _touch_elapsed := 0.0
var _touch_displacement := Vector2.ZERO
var _touch_long_pressed := false
var _panning := false
var _right_stick_direction: StringName = &""
var _longpress_callback_active := false
var _interaction_blocked := false
var _input_owner: Object
var _toggle_contacts: Dictionary = {}
var _foreground_input := true

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	_update_focus_mode()
	focus_entered.connect(_on_focus_entered)
	focus_exited.connect(_on_focus_exited)
	mouse_exited.connect(_cancel_contacts)
	visibility_changed.connect(_retain_toggle_contacts)

static func accepts_input_owner(input_owner: Object) -> bool:
	if not is_instance_valid(input_owner): return false
	for method: String in ["get_physical_contacts","get_physical_contact_id","is_source_input_admitted"]:
		if not input_owner.has_method(method): return false
	for event: String in ["input_bindings_changed","source_input_custody_changed"]:
		if not input_owner.has_signal(event): return false
	return true

func configure_input(input_owner: Object) -> bool:
	if not accepts_input_owner(input_owner): return false
	if _input_owner != null: return _input_owner == input_owner
	_input_owner = input_owner
	_input_owner.connect("input_bindings_changed",_retain_toggle_contacts)
	_input_owner.connect("source_input_custody_changed",_retain_toggle_contacts)
	_retain_toggle_contacts()
	return true

func _retain_toggle_contacts() -> void:
	if is_instance_valid(_input_owner):
		_toggle_contacts = _input_owner.get_physical_contacts()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: _foreground_input = false
	elif what == NOTIFICATION_APPLICATION_FOCUS_IN: _foreground_input = true
	if what in [NOTIFICATION_DISABLED,NOTIFICATION_ENABLED,NOTIFICATION_PAUSED,NOTIFICATION_UNPAUSED,
			NOTIFICATION_APPLICATION_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_IN]:
		_retain_toggle_contacts()

func configure(locale: String = "en", percent: int = 100, large: bool = false, palette: StringName = &"after_hours",
		high_contrast: bool = false, colour_preset: String = "standard") -> bool:
	var probe: Control = CELL.new()
	if not probe.configure(locale,percent,large,palette,high_contrast,colour_preset):
		probe.free()
		return false
	var content_changed: bool = _locale != locale.replace("_","-") or _percent != percent or _large != large
	_locale = locale.replace("_","-")
	_percent = percent
	_large = large
	_palette = palette
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	theme = probe.theme
	probe.free()
	if content_changed: cancel_pointer_gesture()
	for cell: Control in cell_nodes: cell.configure(_locale,_percent,_large,_palette,_high_contrast,_colour_preset)
	_reflow()
	_refresh_accessibility()
	return true

func can_present(value: Dictionary) -> bool:
	if value.size() != TOP_KEYS.size(): return false
	for key: String in TOP_KEYS:
		if not value.has(key): return false
	if typeof(value.width) != TYPE_INT or value.width <= 0 or typeof(value.height) != TYPE_INT or value.height <= 0: return false
	if typeof(value.revision) != TYPE_INT or value.revision < 0 or (value.mine_estimate != null and typeof(value.mine_estimate) != TYPE_INT): return false
	if typeof(value.terminal) != TYPE_BOOL or typeof(value.custody) != TYPE_BOOL: return false
	var terminal_choices := 0
	if typeof(value.cells) != TYPE_ARRAY or value.cells.size() != value.width*value.height: return false
	var probe: Control = CELL.new()
	_last_validated_projection = {}
	for index in value.cells.size():
		if typeof(value.cells[index]) != TYPE_DICTIONARY or value.cells[index].get("index") != index or not probe.present(value.cells[index]):
			probe.free()
			return false
		var public_cell: Dictionary = value.cells[index]
		if value.custody and (public_cell.inspectable or not public_cell.actions.is_empty()):
			probe.free()
			return false
		if value.terminal:
			var marked_choice: bool = not value.custody and public_cell.mark in ["marked_mine", "marked_flag"] \
				and public_cell.inspectable and public_cell.pressable and public_cell.actions == ["activate"] and not public_cell.bracketed
			if marked_choice: terminal_choices += 1
			elif public_cell.bracketed or public_cell.inspectable or public_cell.pressable or not public_cell.actions.is_empty():
				probe.free()
				return false
		if not value.terminal and public_cell.mark in ["mine","exploded","correct_flag","incorrect_flag"]:
			probe.free()
			return false
	probe.free()
	var valid: bool = terminal_choices == 1 if value.terminal and not value.custody else terminal_choices == 0
	if valid: _last_validated_projection = value
	return valid

func present(value: Dictionary) -> bool:
	# dwm-634.1: the panel validates this same instance before presenting it; validating the
	# 484 cells of an expert board a second time cost a full probe pass per click.
	if not is_same(value, _last_validated_projection) and not can_present(value): return false
	_last_validated_projection = {}
	_cancel_for_projection()
	projection = value.duplicate(true)
	_rebuild()
	if projection.custody:
		_retain_toggle_contacts()
		_confirm_held = false
		cancel_pointer_gesture()
	return true

func set_mode(next_mode: StringName) -> bool:
	if next_mode not in MODES: return false
	if next_mode == mode: return true
	_cancel_gestures()
	mode = next_mode
	mode_changed.emit(mode)
	return true

func cancel_pointer_gesture() -> void:
	_cancel_gestures()

func cancel_input() -> void:
	_retain_toggle_contacts()
	_cancel_gestures()
	_confirm_held = false
	_joy_direction = &""
	_right_stick_direction = &""

func focus_cell(index: int) -> bool:
	if _interaction_blocked or projection.is_empty() or projection.custody or index < 0 or index >= cell_nodes.size(): return false
	if not projection.cells[index].inspectable: return false
	_set_focused(index)
	if is_inside_tree(): grab_focus()
	return true

func set_interaction_blocked(blocked: bool) -> void:
	if _interaction_blocked == blocked: return
	_interaction_blocked = blocked
	_retain_toggle_contacts()
	_cancel_gestures()
	_confirm_held = false
	_joy_direction = &""
	_right_stick_direction = &""
	_update_focus_mode()
	if blocked: release_focus()
	_refresh_contacts()

func _update_focus_mode() -> void:
	focus_mode = Control.FOCUS_ALL if not _interaction_blocked and not projection.is_empty() and not projection.custody and focused_index >= 0 else Control.FOCUS_NONE

func has_held_touch() -> bool:
	return _touch_id >= 0

func _process(delta: float) -> void:
	if _interaction_blocked or _touch_id < 0 or _panning or _touch_long_pressed or _touch_displacement.length() > 8.0: return
	_touch_elapsed += delta
	if _touch_elapsed < 0.5 or _touch_revision != projection.get("revision",-1): return
	var action: StringName = _pointer_action(_touch_index,MOUSE_BUTTON_RIGHT)
	_touch_long_pressed = true
	_refresh_contacts()
	if action != &"":
		_longpress_callback_active = true
		cell_action_requested.emit(action,_touch_index,_touch_revision)
		_longpress_callback_active = false

func _rebuild() -> void:
	while cell_nodes.size() > projection.cells.size():
		var removed: Control = cell_nodes.pop_back()
		remove_child(removed)
		removed.free()
	while cell_nodes.size() < projection.cells.size():
		var cell: Control = CELL.new()
		add_child(cell)
		cell.configure(_locale,_percent,_large,_palette,_high_contrast,_colour_preset)
		cell_nodes.append(cell)
	for index in projection.cells.size(): cell_nodes[index].present(projection.cells[index])
	_reflow()
	focused_index = _repair_focus(focused_index)
	_update_focus_mode()
	_refresh_contacts()
	if focused_index >= 0: focused_cell_changed.emit(focused_index)

func _reflow() -> void:
	if projection.is_empty(): return
	var target: int = 64 if _large else 48
	custom_minimum_size = Vector2(projection.width*target+4,projection.height*target+4)
	size = custom_minimum_size
	for index in cell_nodes.size(): cell_nodes[index].position = Vector2(2+(index%projection.width)*target,2+(index/projection.width)*target)
	queue_redraw()

func _repair_focus(prior: int) -> int:
	if projection.custody: return -1
	for cell: Dictionary in projection.cells:
		if cell.bracketed and cell.inspectable: return cell.index
	if prior >= 0 and prior < projection.cells.size() and projection.cells[prior].inspectable: return prior
	for cell: Dictionary in projection.cells:
		if cell.inspectable: return cell.index
	return -1

func _gui_input(event: InputEvent) -> void:
	if _interaction_blocked or projection.is_empty() or projection.custody: return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		_handle_touch(event)
	elif event is InputEventMouseMotion:
		if event.device == -1: return
		if _mouse_dragging:
			_mouse_drag_displacement += event.relative
			if _panning or _mouse_drag_displacement.length() > 8.0:
				_set_panning(true)
				pan_requested.emit(event.relative)
			return
		_hovered_index = _index_at(event.position)
		if _held_index >= 0 and _hovered_index != _held_index: _clear_hold()
		_refresh_contacts()
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_LEFT,MOUSE_BUTTON_RIGHT]:
		if event.device == -1: return
		var index: int = _index_at(event.position)
		if event.pressed:
			if _touch_id >= 0: return
			_clear_hold()
			if event.double_click or _confirm_held: return
			if mode == &"drag" and event.button_index == MOUSE_BUTTON_LEFT:
				_mouse_dragging = true
				_mouse_drag_displacement = Vector2.ZERO
				return
			if index >= 0 and projection.cells[index].inspectable:
				_set_focused(index)
				grab_focus()
				_refresh_accessibility()
			var action: StringName = _pointer_action(index,event.button_index)
			if action == &"": return
			_held_index = index
			_held_revision = projection.revision
			_held_action = action
			_held_button = event.button_index
			_refresh_contacts()
			# dwm-634.1 (owner ruling 2026-09-12): mouse actions fire on press. The publication that
			# follows cancels this contact; the release below then has nothing left to submit.
			cell_action_requested.emit(action,index,projection.revision)
		else:
			if _mouse_dragging and event.button_index == MOUSE_BUTTON_LEFT:
				_mouse_dragging = false
				_mouse_drag_displacement = Vector2.ZERO
				_set_panning(false)
				return
			_clear_hold()
	elif event is InputEventMouseButton and event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN,MOUSE_BUTTON_WHEEL_LEFT,MOUSE_BUTTON_WHEEL_RIGHT]:
		if event.device == -1: return
		if has_held_touch():
			accept_event()
			return
		cancel_pointer_gesture()
		var target: float = 64.0 if _large else 48.0
		match event.button_index:
			MOUSE_BUTTON_WHEEL_UP: pan_requested.emit(Vector2(0,target))
			MOUSE_BUTTON_WHEEL_DOWN: pan_requested.emit(Vector2(0,-target))
			MOUSE_BUTTON_WHEEL_LEFT: pan_requested.emit(Vector2(target,0))
			MOUSE_BUTTON_WHEEL_RIGHT: pan_requested.emit(Vector2(-target,0))
		accept_event()
	elif event is InputEventKey or event is InputEventJoypadButton or event is InputEventJoypadMotion:
		_handle_navigation(event)

func _handle_navigation(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and event.echo: return
	if _handle_toggle(event): return
	if event is InputEventKey and event.pressed and event.keycode == KEY_SPACE:
		if _held_index >= 0 or _mouse_dragging or _touch_id >= 0 or _confirm_held: return
		new_board_requested.emit()
		accept_event()
		return
	var confirm_event: bool = (event is InputEventJoypadButton and event.is_action("ui_accept")) or (event is InputEventKey and event.keycode in [KEY_ENTER,KEY_KP_ENTER])
	if not event.is_pressed():
		if confirm_event: _confirm_held = false
		_joy_direction = &""
		_right_stick_direction = &""
		return
	if event is InputEventJoypadMotion and event.axis in [JOY_AXIS_RIGHT_X,JOY_AXIS_RIGHT_Y]:
		if _held_index >= 0 or _mouse_dragging or _touch_id >= 0 or _confirm_held: return
		var stick_direction: StringName = &"right" if event.axis == JOY_AXIS_RIGHT_X and event.axis_value > 0.5 else (&"left" if event.axis == JOY_AXIS_RIGHT_X and event.axis_value < -0.5 else (&"down" if event.axis_value > 0.5 else (&"up" if event.axis_value < -0.5 else &"")))
		if stick_direction == &"" or stick_direction == _right_stick_direction: return
		_right_stick_direction = stick_direction
		var target: float = 64.0 if _large else 48.0
		match stick_direction:
			&"right": pan_requested.emit(Vector2(target,0))
			&"left": pan_requested.emit(Vector2(-target,0))
			&"down": pan_requested.emit(Vector2(0,target))
			&"up": pan_requested.emit(Vector2(0,-target))
		return
	if _held_index >= 0 or _mouse_dragging or _touch_id >= 0: return
	var direction: StringName = &""
	for candidate: StringName in [&"ui_left",&"ui_right",&"ui_up",&"ui_down"]:
		if event.is_action_pressed(candidate): direction = candidate
	if event is InputEventJoypadMotion:
		if direction == &"" or direction == _joy_direction: return
		_joy_direction = direction
	var delta: Vector2i = Vector2i.ZERO
	match direction:
		&"ui_left": delta = Vector2i.LEFT
		&"ui_right": delta = Vector2i.RIGHT
		&"ui_up": delta = Vector2i.UP
		&"ui_down": delta = Vector2i.DOWN
	if delta != Vector2i.ZERO:
		_move_focus(delta)
		accept_event()
		return
	var confirm: bool = event is InputEventJoypadButton and event.is_action_pressed("ui_accept")
	if event is InputEventKey:
		confirm = event.keycode in [KEY_ENTER,KEY_KP_ENTER]
	if confirm:
		if _confirm_held: return
		_confirm_held = true
		var action: StringName = _mode_action(focused_index)
		if action != &"": cell_action_requested.emit(action,focused_index,projection.revision)
		accept_event()

func _handle_toggle(event: InputEvent) -> bool:
	if not (event is InputEventKey or event is InputEventJoypadButton) \
			or not InputMap.has_action(TOGGLE_ACTION) or not event.is_action_pressed(TOGGLE_ACTION,false,true): return false
	# This action belongs to the focused board. Observe physical generations from
	# the ALWAYS input owner so releases during a disabled sheet or Pause count.
	if not is_instance_valid(_input_owner): return true
	var contacts: Dictionary = _input_owner.get_physical_contacts()
	for held: String in _toggle_contacts.keys():
		if contacts.get(held) != _toggle_contacts[held]: _toggle_contacts.erase(held)
	var contact: String = _input_owner.get_physical_contact_id(event)
	if contact.is_empty() or not contacts.has(contact): return true
	var held_before := not _toggle_contacts.is_empty()
	_toggle_contacts[contact] = contacts[contact]
	accept_event()
	if held_before or not _foreground_input or not has_focus() or not is_visible_in_tree() or not can_process() \
			or not _input_owner.is_source_input_admitted(): return true
	if _held_index >= 0 or _mouse_dragging or _touch_id >= 0 or _confirm_held: return true
	set_mode(&"flag" if mode in [&"drag",&"reveal"] else &"reveal")
	return true

func _move_focus(delta: Vector2i) -> void:
	if focused_index < 0: return
	var at: Vector2i = Vector2i(focused_index%projection.width,focused_index/projection.width)
	var target: Vector2i = at+delta
	if target.x < 0 or target.x >= projection.width or target.y < 0 or target.y >= projection.height: return
	var index: int = target.y*projection.width+target.x
	if not projection.cells[index].inspectable: return
	_set_focused(index)
	_refresh_contacts()
	_refresh_accessibility()

func _handle_touch(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			if event.double_tap or _touch_id >= 0 or _held_index >= 0 or _mouse_dragging or _confirm_held: return
			_touch_id = event.index
			_touch_index = _index_at(event.position)
			_touch_revision = projection.revision
			_touch_elapsed = 0.0
			_touch_displacement = Vector2.ZERO
			_touch_long_pressed = false
			if _touch_index >= 0 and projection.cells[_touch_index].inspectable:
				_set_focused(_touch_index)
				grab_focus()
			_refresh_contacts()
		elif event.index == _touch_id and event.canceled:
			_cancel_touch()
			return
		elif event.index == _touch_id:
			var admitted: bool = not _panning and not _touch_long_pressed and _touch_displacement.length() <= 8.0 and _touch_revision == projection.revision and _index_at(event.position) == _touch_index
			var action: StringName = _mode_action(_touch_index) if admitted else &""
			var index: int = _touch_index
			var revision: int = _touch_revision
			_cancel_touch()
			if action != &"": cell_action_requested.emit(action,index,revision)
	elif event is InputEventScreenDrag and event.index == _touch_id:
		_touch_displacement += event.relative
		if _panning or _touch_displacement.length() > 8.0:
			_set_panning(true)
			pan_requested.emit(event.relative)
		_refresh_contacts()

func _pointer_action(index: int, button: int) -> StringName:
	if index < 0: return &""
	var actions: Array = projection.cells[index].actions
	if button == MOUSE_BUTTON_RIGHT:
		if "unflag" in actions: return &"unflag"
		if "flag" in actions: return &"flag"
		return &""
	return _mode_action(index)

func _mode_action(index: int) -> StringName:
	if index < 0 or projection.is_empty() or index >= projection.get("cells", []).size(): return &""
	var actions: Array = projection.cells[index].actions
	if "activate" in actions: return &"activate"
	if mode == &"drag": return &""
	if "chord" in actions: return &"chord"
	if mode == &"reveal":
		if "reveal" in actions: return &"reveal"
	elif mode == &"flag":
		if "unflag" in actions: return &"unflag"
		if "flag" in actions: return &"flag"
	return &""

func _index_at(point: Vector2) -> int:
	var target: int = 64 if _large else 48
	var local_point: Vector2 = point-Vector2(2,2)
	if local_point.x < 0 or local_point.y < 0: return -1
	var column: int = int(local_point.x/target)
	var row: int = int(local_point.y/target)
	if column >= projection.width or row >= projection.height: return -1
	return row*projection.width+column

func _clear_hold() -> void:
	_held_index = -1
	_held_revision = -1
	_held_action = &""
	_held_button = 0
	_refresh_contacts()

func _cancel_contacts() -> void:
	_hovered_index = -1
	_clear_hold()

func _cancel_touch() -> void:
	_touch_id = -1
	_touch_index = -1
	_touch_revision = -1
	_touch_elapsed = 0.0
	_touch_displacement = Vector2.ZERO
	_touch_long_pressed = false
	_set_panning(false)
	_refresh_contacts()

func _cancel_gestures() -> void:
	_cancel_contacts()
	_mouse_dragging = false
	_mouse_drag_displacement = Vector2.ZERO
	_cancel_touch()

func _cancel_for_projection() -> void:
	if not _longpress_callback_active:
		cancel_pointer_gesture()
		return
	_cancel_contacts()
	_mouse_dragging = false
	_mouse_drag_displacement = Vector2.ZERO
	_set_panning(false)

func _set_panning(active: bool) -> void:
	if _panning == active: return
	_panning = active
	panning_changed.emit(active)

func _set_focused(index: int) -> void:
	if focused_index == index: return
	focused_index = index
	_refresh_contacts()
	focused_cell_changed.emit(index)

func _on_focus_entered() -> void:
	_retain_toggle_contacts()
	_refresh_contacts()
	if focused_index >= 0: focused_cell_changed.emit(focused_index)

func _on_focus_exited() -> void:
	_retain_toggle_contacts()
	_cancel_gestures()
	_confirm_held = false
	_joy_direction = &""

func _refresh_contacts() -> void:
	for index in cell_nodes.size():
		var touch_pressed: bool = index == _touch_index and _touch_revision == projection.get("revision",-1) and not _panning and not _touch_long_pressed and _touch_displacement.length() <= 8.0 and _mode_action(index) != &""
		cell_nodes[index].set_contact(has_focus() and index == focused_index,index == _hovered_index,index == _held_index or touch_pressed)
	_refresh_accessibility()

func _refresh_accessibility() -> void:
	if projection.is_empty() or focused_index < 0:
		accessibility_name = ""
		return
	var row: int = focused_index/projection.width+1
	var column: int = focused_index%projection.width+1
	var visible: String = cell_nodes[focused_index].accessibility_name
	if visible.is_empty():
		var covered: bool = projection.cells[focused_index].face == "covered"
		match _locale:
			"zh-CN": visible = "未揭开" if covered else "空白"
			"zh-HK": visible = "未揭開" if covered else "空白"
			_: visible = "Covered" if covered else "Blank"
	match _locale:
		"zh-CN": accessibility_name = "第%d行，第%d列，%s" % [row,column,visible]
		"zh-HK": accessibility_name = "第%d行，第%d欄，%s" % [row,column,visible]
		_: accessibility_name = "Row %d, column %d, %s" % [row,column,visible]

func _draw() -> void:
	if projection.is_empty(): return
	draw_rect(Rect2(Vector2.ZERO,size),get_theme_color(&"controlled_face",&"Minesweeper"))
	draw_rect(Rect2(Vector2.ZERO,size),get_theme_color(&"dark_registration",&"Minesweeper"),false,2)
