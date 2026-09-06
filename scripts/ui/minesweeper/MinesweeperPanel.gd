extends Control
## Desktop composition over a public application port. Hosts explicitly refresh external changes.

signal presentation_failed(code: StringName)

const REGISTER := preload("res://scripts/ui/minesweeper/MinesweeperRegister.gd")
const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")
const DOCK := preload("res://scripts/ui/minesweeper/MinesweeperDock.gd")
const SHEET := preload("res://scripts/ui/minesweeper/MinesweeperInformationSheet.gd")
const LAYOUT := preload("res://scripts/ui/minesweeper/MinesweeperWorksheetLayout.gd")
const ACTIONS := ["reveal","flag","drag","assignments","rules"]

var register: Control
var worksheet: Control
var dock: Control
var public_view: Dictionary = {}
var _port: Object
var _locale := "en"
var _percent := 100
var _large := false
var _palette: StringName = &"after_hours"
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
	worksheet.cell_action_requested.connect(_dispatch)
	worksheet.grid.mode_changed.connect(func(_mode: StringName): _apply_availability())
	worksheet.information_closing.connect(_apply_availability)
	worksheet.information_closed.connect(_information_closed)

func configure(locale: String = "en", percent: int = 100, large: bool = false,
		palette: StringName = &"after_hours") -> bool:
	var measured := _measure(public_view,locale,percent,large,palette)
	if measured.is_empty(): return false
	if not worksheet.configure("desktop_app",locale,percent,large,palette,measured.band): return false
	register.configure("desktop_app",locale,percent,large,palette)
	dock.configure("desktop_app",locale,percent,large,palette)
	_locale = locale
	_percent = percent
	_large = large
	_palette = palette
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
	var measured := _measure(value,_locale,_percent,_large,_palette)
	if measured.is_empty(): return _fail(&"minesweeper_panel_invalid_view")
	# Reconfigure only for changed geometry: a synchronous Flag publication must
	# retain the grid's touch-release latch and all existing cell nodes.
	if worksheet.theme == null or measured.band != _band:
		if not worksheet.configure("desktop_app",_locale,_percent,_large,_palette,measured.band):
			return _fail(&"minesweeper_panel_invalid_view")
		_band = measured.band
	if register.theme == null: register.configure("desktop_app",_locale,_percent,_large,_palette)
	if dock.theme == null: dock.configure("desktop_app",_locale,_percent,_large,_palette)
	var assignments_changed: bool = public_view.get("assignments") != value.assignments
	register.present(value.register)
	worksheet.present(value.board)
	public_view = value.duplicate(true)
	_failed = false
	_place(measured.register_height)
	if assignments_changed and worksheet.information_sheet != null and _sheet_source == "assignments":
		worksheet.information_sheet.present_assignments(public_view.assignments)
	_apply_availability()
	return true

func _valid(value: Dictionary) -> bool:
	if value.size() != 4: return false
	for key in ["board","register","assignments","actions"]:
		if not value.has(key): return false
	if not value.board is Dictionary or not value.register is Dictionary or not value.assignments is Array or not value.actions is Array: return false
	if not worksheet.grid.can_present(value.board): return false
	if value.register.get("custody") != value.board.custody or value.register.get("mine_estimate") != value.board.mine_estimate: return false
	if value.assignments.size() != 9: return false
	for claimed: Variant in value.assignments:
		if typeof(claimed) != TYPE_BOOL: return false
	var seen: Array = []
	for action: Variant in value.actions:
		if typeof(action) != TYPE_STRING or action not in ACTIONS or action in seen: return false
		seen.append(action)
	# Replacement and tier selection require application owners that do not yet exist.
	if value.register.get("difficulty_enabled") != []: return false
	return value.actions.is_empty() if value.board.custody else seen.size() == ACTIONS.size()

func _measure(value: Dictionary, locale: String, percent: int, large: bool, palette: StringName) -> Dictionary:
	var probe_register: Control = REGISTER.new()
	var probe_dock: Control = DOCK.new()
	var probe_sheet: Control = SHEET.new()
	var facts: Dictionary = value.get("register",{"difficulty":"beginner","rounds":2,"mine_estimate":null,
		"foresight":null,"no_flag":"intact","custody":false,"difficulty_enabled":[]})
	var valid: bool = probe_register.configure("desktop_app",locale,percent,large,palette)
	if valid: valid = probe_register.present(facts)
	if valid: valid = probe_dock.configure("desktop_app",locale,percent,large,palette)
	var result: Dictionary = {}
	if valid:
		var band := Vector2i(400,328-int(probe_register.size.y/2)-int(probe_dock.size.y/2))
		valid = LAYOUT.measure(1,1,band,large).ok
		if valid: valid = probe_sheet.configure("desktop_app",locale,percent,large,palette,band)
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
	dock.position = Vector2(0,register_height+_band.y*2)

func _apply_availability() -> void:
	var blocked: bool = _failed or worksheet.information_sheet != null or public_view.get("board",{}).get("custody",true)
	worksheet.set_interaction_blocked(_failed)
	for key: String in register.difficulties:
		register.difficulties[key].present_state(false,key == register.public_view.difficulty)
	dock.present(worksheet.grid.mode,public_view.get("actions",[]),blocked)
	_wire_focus()

func _wire_focus() -> void:
	if not is_inside_tree(): return
	var controls: Array[Control] = []
	for control: Control in [worksheet.grid,worksheet.vertical_rail,worksheet.horizontal_rail]:
		if control != null and control.focus_mode != Control.FOCUS_NONE and control.is_visible_in_tree(): controls.append(control)
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
