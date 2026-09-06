extends Control
## Presentation-only viewport. All positions and scroll values are integer native pixels.

signal cell_action_requested(action: StringName, index: int, revision: int)
signal new_board_requested()
signal information_closed()
signal information_closing()

const GRID := preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd")
const RAIL := preload("res://scripts/ui/minesweeper/MinesweeperScrollRail.gd")
const LAYOUT := preload("res://scripts/ui/minesweeper/MinesweeperWorksheetLayout.gd")
const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const SHEET := preload("res://scripts/ui/minesweeper/MinesweeperInformationSheet.gd")

class ContactSeam extends Control:
	func _draw() -> void:
		draw_rect(Rect2(size.x - 4, 4, 2, maxi(0, int(size.y) - 8)), get_theme_color(&"dark_registration", &"Minesweeper"))

var grid: Control
var well: Control
var vertical_rail: Control
var horizontal_rail: Control
var information_sheet: Control
var geometry: Dictionary = {}
var _seam: Control
var _band := Vector2i(400, 246)
var _large := false
var _locale := "en"
var _host := "desktop_app"
var _percent := 100
var _palette: StringName = &"after_hours"
var _source_focus: WeakRef
var _grid_process_mode: ProcessMode
var _scroll := Vector2i.ZERO
var _pan_remainder := Vector2.ZERO
var _panning := false
var _applying := false
var _interaction_blocked := false

func _init() -> void:
	clip_contents = true
	well = Control.new()
	well.name = "ContentWell"
	well.clip_contents = true
	well.mouse_filter = Control.MOUSE_FILTER_PASS
	add_child(well)
	grid = GRID.new()
	grid.name = "Grid"
	well.add_child(grid)
	_seam = ContactSeam.new()
	_seam.name = "WorksheetContactSeam"
	_seam.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_seam.visible = false
	add_child(_seam)
	grid.cell_action_requested.connect(func(action: StringName, index: int, revision: int): cell_action_requested.emit(action, index, revision))
	grid.new_board_requested.connect(func(): new_board_requested.emit())
	grid.focused_cell_changed.connect(_reveal_focus)
	grid.pan_requested.connect(_pan)
	grid.panning_changed.connect(_set_panning)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	if theme == null: configure()
	_apply_geometry()

func configure(host: String = "desktop_app", locale: String = "en", percent: int = 100,
		large: bool = false, palette: StringName = &"after_hours", native_band: Vector2i = Vector2i.ZERO) -> bool:
	if host not in ["desktop_app", "canonical_solo", "canonical_pair"]: return false
	var candidate_theme := MS_THEME.build(locale, percent, palette)
	var candidate_band := native_band
	if candidate_band == Vector2i.ZERO: candidate_band = Vector2i(400 if host == "desktop_app" else 480, 232 if large else 246)
	if candidate_theme == null or not LAYOUT.measure(1, 1, candidate_band, large).ok: return false
	if information_sheet != null and not information_sheet.configure(host,locale,percent,large,palette,candidate_band): return false
	grid.cancel_pointer_gesture()
	if not grid.configure(locale, percent, large, palette): return false
	_locale = locale.replace("_", "-")
	_host = host
	_percent = percent
	_palette = palette
	_large = large
	_band = candidate_band
	theme = candidate_theme
	_pan_remainder = Vector2.ZERO
	_apply_geometry()
	_reveal_focus(grid.focused_index)
	return true

func present(projection: Dictionary) -> bool:
	_applying = true
	var accepted: bool = grid.present(projection)
	_applying = false
	if not accepted: return false
	_pan_remainder = Vector2.ZERO
	_apply_geometry()
	if grid.has_focus(): _reveal_focus(grid.focused_index)
	return true

func set_mode(mode: StringName) -> bool:
	if _interaction_blocked or information_sheet != null: return false
	return grid.set_mode(mode)

func set_interaction_blocked(blocked: bool) -> void:
	if _interaction_blocked == blocked: return
	_interaction_blocked = blocked
	grid.set_interaction_blocked(blocked)
	_pan_remainder = Vector2.ZERO
	_apply_geometry()

func open_rules(source: Control = null) -> bool:
	return _open_information("rules",[],source)

func open_assignments(claimed: Array, source: Control = null) -> bool:
	return _open_information("assignments",claimed,source)

func _open_information(kind: String, claimed: Array, source: Control) -> bool:
	if _interaction_blocked or information_sheet != null or grid.projection.is_empty() or grid.projection.custody: return false
	var sheet: Control = SHEET.new()
	sheet.hide()
	add_child(sheet)
	var accepted: bool = sheet.configure(_host,_locale,_percent,_large,_palette,_band)
	if accepted: accepted = sheet.present_rules() if kind == "rules" else sheet.present_assignments(claimed)
	if not accepted:
		remove_child(sheet)
		sheet.queue_free()
		return false
	var focused: Control = source if source != null else get_viewport().gui_get_focus_owner()
	_source_focus = weakref(focused) if focused != null else null
	information_sheet = sheet
	grid.cancel_pointer_gesture()
	_grid_process_mode = grid.process_mode
	grid.process_mode = Node.PROCESS_MODE_DISABLED
	well.hide()
	if vertical_rail != null: vertical_rail.hide()
	if horizontal_rail != null: horizontal_rail.hide()
	sheet.return_requested.connect(close_information)
	sheet.show()
	sheet.rows[0].grab_focus()
	return true

func close_information() -> void:
	if information_sheet == null: return
	var sheet := information_sheet
	information_sheet = null
	remove_child(sheet)
	sheet.queue_free()
	grid.process_mode = _grid_process_mode
	well.show()
	if vertical_rail != null: vertical_rail.show()
	if horizontal_rail != null: horizontal_rail.show()
	var source: Control = _source_focus.get_ref() if _source_focus != null else null
	_source_focus = null
	# Returning from a sheet restores its exact pan, even if the retained cell is
	# offscreen. A subsequent grid navigation resumes normal focus revelation.
	_applying = true
	information_closing.emit()
	if source != null and source.is_visible_in_tree() and source.focus_mode != Control.FOCUS_NONE: source.grab_focus()
	elif grid.focus_mode != Control.FOCUS_NONE: grid.grab_focus()
	_applying = false
	information_closed.emit()

func set_scroll(native_offset: Vector2i) -> void:
	if _interaction_blocked or information_sheet != null or grid.projection.is_empty() or grid.projection.custody: return
	grid.cancel_pointer_gesture()
	_scroll = native_offset
	_pan_remainder = Vector2.ZERO
	_apply_geometry()

func get_scroll() -> Vector2i:
	return _scroll

func _apply_geometry() -> void:
	custom_minimum_size = Vector2(_band * 2)
	size = custom_minimum_size
	if grid.projection.is_empty(): return
	var result := LAYOUT.measure(grid.projection.width, grid.projection.height, _band, _large, _scroll)
	if not result.ok: return
	geometry = result.value
	_scroll = geometry.scroll
	well.position = Vector2.ZERO
	well.size = Vector2(geometry.well.size * 2)
	grid.position = Vector2(geometry.mount.position * 2)
	_seam.size = well.size
	var interactive: bool = not _interaction_blocked and not grid.projection.custody
	vertical_rail = _update_rail(vertical_rail, geometry.vertical, true, interactive)
	horizontal_rail = _update_rail(horizontal_rail, geometry.horizontal, false, interactive)
	if vertical_rail != null: vertical_rail.visible = information_sheet == null
	if horizontal_rail != null: horizontal_rail.visible = information_sheet == null
	_update_seam()
	queue_redraw()

func _update_rail(existing: Control, public_rail: Variant, vertical: bool, interactive: bool) -> Control:
	if public_rail == null:
		if existing != null:
			remove_child(existing)
			existing.queue_free()
		return null
	var rail := existing
	if rail == null:
		rail = RAIL.new()
		rail.name = "VerticalRail" if vertical else "HorizontalRail"
		add_child(rail)
		rail.scroll_requested.connect(func(value: int): _scroll_axis(value, vertical))
	var axis := 1 if vertical else 0
	rail.configure(vertical, _locale, theme)
	rail.present(public_rail, geometry.maximum_scroll[axis], _scroll[axis], geometry.well.size[axis], interactive)
	return rail

func _scroll_axis(value: int, vertical: bool) -> void:
	var next := _scroll
	next[1 if vertical else 0] = value
	set_scroll(next)

func _reveal_focus(index: int) -> void:
	if _interaction_blocked or information_sheet != null or _applying or grid.projection.is_empty() or grid.projection.custody or index < 0: return
	var result := LAYOUT.reveal_cell(grid.projection.width, grid.projection.height, index, _band, _large, _scroll)
	if result.ok:
		_scroll = result.value.scroll
		_apply_geometry()

func _pan(delta: Vector2) -> void:
	if _interaction_blocked or information_sheet != null or grid.projection.is_empty() or grid.projection.custody: return
	_pan_remainder -= delta / 2.0
	var whole := Vector2i(int(_pan_remainder.x), int(_pan_remainder.y))
	_pan_remainder -= Vector2(whole)
	_scroll += whole
	_apply_geometry()

func _set_panning(active: bool) -> void:
	_panning = active
	if not active: _pan_remainder = Vector2.ZERO
	_update_seam()

func _update_seam() -> void:
	_seam.visible = not grid.projection.is_empty() and (grid.projection.custody or _panning)
	_seam.queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if _interaction_blocked: return
	if not event is InputEventMouseButton or not event.pressed or geometry.is_empty(): return
	if not Rect2(Vector2.ZERO, well.size).has_point(event.position): return
	var direction := Vector2i.ZERO
	match event.button_index:
		MOUSE_BUTTON_WHEEL_UP: direction = Vector2i.UP
		MOUSE_BUTTON_WHEEL_DOWN: direction = Vector2i.DOWN
		MOUSE_BUTTON_WHEEL_LEFT: direction = Vector2i.LEFT
		MOUSE_BUTTON_WHEEL_RIGHT: direction = Vector2i.RIGHT
	if direction != Vector2i.ZERO:
		if not grid.has_held_touch(): set_scroll(_scroll + direction * int(geometry.target))
		accept_event()

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, size), get_theme_color(&"habitat", &"Minesweeper"))
