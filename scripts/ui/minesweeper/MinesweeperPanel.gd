extends Control
## Desktop composition over a public application port. Hosts explicitly refresh external changes.

signal presentation_failed(code: StringName)
signal presentation_changed()

const REGISTER := preload("res://scripts/ui/minesweeper/MinesweeperRegister.gd")
const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")
const DOCK := preload("res://scripts/ui/minesweeper/MinesweeperDock.gd")
const SHEET := preload("res://scripts/ui/minesweeper/MinesweeperInformationSheet.gd")
const LAYOUT := preload("res://scripts/ui/minesweeper/MinesweeperWorksheetLayout.gd")
const PLAY_ACTIONS := ["reveal","flag","drag","assignments","rules"]
const SETTLED_ACTIONS := ["new_board","assignments","rules"]
const ACTIONS := PLAY_ACTIONS+SETTLED_ACTIONS

var register: Control
var worksheet: Control
var dock: Control
var public_view: Dictionary = {}
var _port: Object
var _locale := "en"
var _percent := 100
var _large := false
var _palette: StringName = &"after_hours"
var _high_contrast := false
var _colour_preset := "standard"
var _band := Vector2i.ZERO
var _failed := true
var _sheet_source := ""
var _previous_focus: WeakRef
var _next_focus: WeakRef

func _init() -> void:
	focus_mode = Control.FOCUS_NONE
	register = REGISTER.new()
	register.name = "Register"
	add_child(register)
	worksheet = WORKSHEET.new()
	worksheet.name = "Worksheet"
	add_child(worksheet)
	dock = DOCK.new()
	dock.name = "Dock"
	add_child(dock)
	dock.action_requested.connect(_action)
	register.difficulty_requested.connect(_select_difficulty)
	worksheet.cell_action_requested.connect(_dispatch)
	worksheet.new_board_requested.connect(func(): _action(&"new_board"))
	worksheet.grid.mode_changed.connect(func(_mode: StringName): _apply_availability())
	worksheet.information_closing.connect(_apply_availability)
	worksheet.information_closed.connect(_information_closed)
	worksheet.view_controls_changed.connect(_wire_focus)

func configure(locale: String = "en", percent: int = 100, large: bool = false,
		palette: StringName = &"after_hours", high_contrast: bool = false, colour_preset: String = "standard") -> bool:
	var measured := _measure(public_view,locale,percent,large,palette,high_contrast,colour_preset)
	if measured.is_empty(): return false
	if not worksheet.configure("desktop_app",locale,percent,large,palette,measured.band,high_contrast,colour_preset): return false
	register.configure("desktop_app",locale,percent,large,palette,high_contrast,colour_preset)
	dock.configure("desktop_app",locale,percent,large,palette,high_contrast,colour_preset)
	_locale = locale
	_percent = percent
	_large = large
	_palette = palette
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	_band = measured.band
	_place(measured.register_height)
	_apply_availability()
	return true

func bind(port: Object) -> bool:
	if not is_instance_valid(port) or not port.has_method("pull") or not port.has_method("dispatch"): return false
	if _port != null: return _port == port
	_port = port
	return true

func refresh() -> bool:
	if not is_instance_valid(_port): return _fail(&"minesweeper_panel_unavailable")
	return _receive(_port.call("pull"))

func has_valid_presentation() -> bool:
	return not _failed and not public_view.is_empty()

func connect_host_focus(previous: Control, next: Control) -> bool:
	if not is_inside_tree(): return false
	for control: Control in [previous,next]:
		if control != null and (not control.is_inside_tree() or control == self or is_ancestor_of(control) or control.get_viewport() != get_viewport()): return false
	_previous_focus = weakref(previous) if previous != null else null
	_next_focus = weakref(next) if next != null else null
	_wire_focus()
	return true

func present(value: Dictionary) -> bool:
	if not _valid(value): return _fail(&"minesweeper_panel_invalid_view")
	var measured := _measure(value,_locale,_percent,_large,_palette,_high_contrast,_colour_preset)
	if measured.is_empty(): return _fail(&"minesweeper_panel_invalid_view")
	# Reconfigure only for changed geometry: a synchronous Flag publication must
	# retain the grid's touch-release latch and all existing cell nodes.
	if worksheet.theme == null or measured.band != _band:
		if not worksheet.configure("desktop_app",_locale,_percent,_large,_palette,measured.band,_high_contrast,_colour_preset):
			return _fail(&"minesweeper_panel_invalid_view")
		_band = measured.band
	if register.theme == null: register.configure("desktop_app",_locale,_percent,_large,_palette,_high_contrast,_colour_preset)
	if dock.theme == null: dock.configure("desktop_app",_locale,_percent,_large,_palette,_high_contrast,_colour_preset)
	var assignments_changed: bool = public_view.get("assignments") != value.assignments
	register.present(value.register)
	if not worksheet.set_view_scope("app_" + str(value.register.difficulty)): return _fail(&"minesweeper_view_preferences_unavailable")
	worksheet.present(value.board)
	public_view = value.duplicate(true)
	_failed = false
	_place(measured.register_height)
	if assignments_changed and worksheet.information_sheet != null and _sheet_source == "assignments":
		worksheet.information_sheet.present_assignments(public_view.assignments)
	_apply_availability()
	presentation_changed.emit()
	return true

func _valid(value: Dictionary) -> bool:
	if value.size() != 5: return false
	for key in ["board","register","assignments","actions","settled"]:
		if not value.has(key): return false
	if not value.board is Dictionary or not value.register is Dictionary \
			or not value.assignments is Array or not value.actions is Array \
			or typeof(value.settled) != TYPE_BOOL: return false
	if not worksheet.grid.can_present(value.board): return false
	if value.register.get("custody") != value.board.custody or value.register.get("mine_estimate") != value.board.mine_estimate: return false
	if value.assignments.size() != 9: return false
	for claimed: Variant in value.assignments:
		if typeof(claimed) != TYPE_BOOL: return false
	var seen: Array = []
	for action: Variant in value.actions:
		if typeof(action) != TYPE_STRING or action not in ACTIONS or action in seen: return false
		seen.append(action)
	if value.settled:
		return value.board.terminal and value.board.custody and seen == SETTLED_ACTIONS
	if value.board.custody:
		return value.actions.is_empty() and value.register.get("difficulty_enabled") == []
	var expected: Array = PLAY_ACTIONS.duplicate()
	if "new_board" in seen:
		var touched := false
		for cell: Dictionary in value.board.cells:
			if cell.face == "revealed": touched = true
		if not touched: return false
		expected.append("new_board")
	return not value.board.terminal and seen == expected

func _measure(value: Dictionary, locale: String, percent: int, large: bool, palette: StringName,
		high_contrast: bool = false, colour_preset: String = "standard") -> Dictionary:
	var probe_register: Control = REGISTER.new()
	var probe_dock: Control = DOCK.new()
	var probe_sheet: Control = SHEET.new()
	var facts: Dictionary = value.get("register",{"difficulty":"beginner","rounds":2,"mine_estimate":null,
		"foresight":null,"no_flag":"intact","custody":false,"difficulty_enabled":[]})
	var valid: bool = probe_register.configure("desktop_app",locale,percent,large,palette,high_contrast,colour_preset)
	if valid: valid = probe_register.present(facts)
	if valid: valid = probe_dock.configure("desktop_app",locale,percent,large,palette,high_contrast,colour_preset)
	var result: Dictionary = {}
	if valid:
		var sheet_band := Vector2i(400,328-int(probe_register.size.y/2)-int(probe_dock.size.y/2))
		var band := sheet_band - Vector2i(0, WORKSHEET.view_controls_height(locale, probe_dock.theme, large) / 2)
		valid = LAYOUT.measure(1,1,band,large).ok
		if valid: valid = probe_sheet.configure("desktop_app",locale,percent,large,palette,sheet_band,high_contrast,colour_preset)
		if valid: valid = probe_sheet.present_assignments(value.get("assignments",[false,false,false,false,false,false,false,false,false]))
		if valid: result = {"band":band,"register_height":probe_register.size.y}
	probe_register.free()
	probe_dock.free()
	probe_sheet.free()
	return result

func _place(register_height: float) -> void:
	custom_minimum_size = Vector2(800,656)
	size = custom_minimum_size
	worksheet.position = Vector2(0,register_height)
	dock.position = Vector2(0,register_height+worksheet.size.y)

func _apply_availability() -> void:
	var settled: bool = bool(public_view.get("settled",false))
	var blocked: bool = _failed or worksheet.information_sheet != null \
		or (public_view.get("board",{}).get("custody",true) and not settled)
	worksheet.set_interaction_blocked(_failed or settled)
	for key: String in register.difficulties:
		register.difficulties[key].present_state(not blocked \
			and key in register.public_view.difficulty_enabled,key == register.public_view.difficulty)
	dock.present(worksheet.grid.mode,public_view.get("actions",[]),blocked)
	_wire_focus()

func _wire_focus() -> void:
	if not is_inside_tree(): return
	var controls: Array[Control] = []
	for control: Control in register.difficulties.values():
		if control.focus_mode != Control.FOCUS_NONE: controls.append(control)
	for control: Control in [worksheet.grid,worksheet.vertical_rail,worksheet.horizontal_rail]:
		if control != null and control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree(): controls.append(control)
	for control: Control in worksheet.zoom_controls:
		if control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree(): controls.append(control)
	for control: Control in dock.buttons.values():
		if control.focus_mode != Control.FOCUS_NONE: controls.append(control)
	for index in controls.size():
		controls[index].focus_previous = controls[index].get_path_to(controls[index-1]) if index > 0 else NodePath()
		controls[index].focus_next = controls[index].get_path_to(controls[index+1]) if index+1 < controls.size() else NodePath()
	if controls.is_empty(): return
	var previous: Control = _previous_focus.get_ref() if _previous_focus != null else null
	var next: Control = _next_focus.get_ref() if _next_focus != null else null
	if previous != null and previous.is_inside_tree(): controls[0].focus_previous = controls[0].get_path_to(previous)
	if next != null and next.is_inside_tree(): controls[-1].focus_next = controls[-1].get_path_to(next)

func _action(action: StringName) -> void:
	if _failed or worksheet.information_sheet != null or action not in public_view.get("actions",[]): return
	if action in [&"reveal",&"flag",&"drag"]:
		worksheet.set_mode(action)
		return
	if action == &"new_board":
		if _receive(_port.call("dispatch","new_board",-1,int(public_view.board.revision))):
			worksheet.set_mode(&"reveal")
			worksheet.reveal_focus(worksheet.grid.focused_index)
		return
	var opened := false
	if action == &"rules": opened = worksheet.open_rules(dock.buttons.rules)
	elif action == &"assignments": opened = worksheet.open_assignments(public_view.assignments,dock.buttons.assignments)
	if opened:
		_sheet_source = String(action)
		_apply_availability()

func _information_closed() -> void:
	if not _failed and dock.buttons.has(_sheet_source) and not dock.buttons[_sheet_source].disabled:
		dock.buttons[_sheet_source].grab_focus()
	_sheet_source = ""
	_wire_focus()

func _dispatch(action: StringName, index: int, revision: int) -> void:
	if _failed or worksheet.information_sheet != null or not is_instance_valid(_port): return
	_receive(_port.call("dispatch",String(action),index,revision))

func _select_difficulty(difficulty: StringName) -> void:
	if _failed or worksheet.information_sheet != null or not is_instance_valid(_port) \
			or not _port.has_method("select_difficulty") \
			or (public_view.board.custody and not public_view.settled) or String(difficulty) == public_view.register.difficulty \
			or String(difficulty) not in public_view.register.difficulty_enabled: return
	if not worksheet.flush_view_preferences(): return
	if _receive(_port.call("select_difficulty",String(difficulty),int(public_view.board.revision))):
		worksheet.set_mode(&"reveal")
		worksheet.reveal_focus(worksheet.grid.focused_index)

func _receive(result: Variant) -> bool:
	if result is Dictionary and result.get("value") is Dictionary:
		if not present(result.value): return false
		if result.get("ok",false): return true
		presentation_failed.emit(result.get("code",&"minesweeper_panel_command_refused"))
		return false
	return _fail(&"minesweeper_panel_unavailable")

func _fail(code: StringName) -> bool:
	_failed = true
	_apply_availability()
	presentation_failed.emit(code)
	return false

func _input(event: InputEvent) -> void:
	# A settled board has no cell focus. Space uses its published New Board action.
	if not event is InputEventKey or not event.pressed or event.echo or event.keycode != KEY_SPACE: return
	if not is_visible_in_tree() or not can_process() or _failed or public_view.is_empty() \
			or not public_view.settled or worksheet.information_sheet != null: return
	var grid: Control = worksheet.grid
	var input_owner: Object = grid.get("_input_owner")
	if not bool(grid.get("_foreground_input")) or input_owner == null \
			or not input_owner.is_source_input_admitted(): return
	if grid.has_held_touch() or int(grid.get("_held_index")) >= 0 \
			or bool(grid.get("_mouse_dragging")) or bool(grid.get("_confirm_held")): return
	get_viewport().set_input_as_handled()
	_action(&"new_board")
