extends Control
## Presentation-only viewport. All positions and scroll values are integer native pixels.

signal cell_action_requested(action: StringName, index: int, revision: int)
signal new_board_requested()
signal information_closed()
signal information_closing()
signal view_controls_changed()

const GRID := preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd")
const RAIL := preload("res://scripts/ui/minesweeper/MinesweeperScrollRail.gd")
const LAYOUT := preload("res://scripts/ui/minesweeper/MinesweeperWorksheetLayout.gd")
const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const SHEET := preload("res://scripts/ui/minesweeper/MinesweeperInformationSheet.gd")
const VIEW_BUTTON := preload("res://scripts/ui/minesweeper/MinesweeperActionButton.gd")
const FIT_WIDTH := 112
const FIT_COPY := {"en": "Fit", "zh-CN": "适应", "zh-HK": "適應",
	"ja": "全体",
	"ko": "맞춤",
}
const VIEW_SCOPES := ["app_beginner", "app_intermediate", "app_expert", "challenge"]
const VIEW_COPY := {
	"en": ["Fit entire board", "Cell: %s px", "Fit: %s px", "Could not save view", "Zoom: Ctrl + wheel, pinch, or LT / RT. Pan: wheel, Drag mode, or right stick."],
	"zh-CN": ["完整显示棋盘", "格子：%s 像素", "适应：%s 像素", "无法保存视图", "缩放：Ctrl + 滚轮、双指捏合或 LT / RT。平移：滚轮、拖动模式或右摇杆。"],
	"zh-HK": ["完整顯示棋盤", "格子：%s 像素", "適應：%s 像素", "無法儲存檢視", "縮放：Ctrl + 滾輪、雙指捏合或 LT / RT。平移：滾輪、拖曳模式或右搖桿。"],
	"ja": ["盤面に合わせる", "マス：%s px", "全体表示：%s px", "表示設定を保存できません", "拡大・縮小：Ctrl + ホイール、ピンチ、LT / RT。移動：ホイール、ドラッグモード、右スティック。"],
	"ko": ["보드에 맞추기", "칸 크기: %s px", "맞춤: %s px", "보기 설정을 저장할 수 없어요", "확대/축소: Ctrl + 휠, 두 손가락 모으기/벌리기, LT / RT. 이동: 휠, 드래그 모드, 오른쪽 스틱."],
}

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
var _high_contrast := false
var _colour_preset := "standard"
var _font_style := "pixel"
var _source_focus: WeakRef
var _grid_process_mode: ProcessMode
var _grid_focus_behavior: Control.FocusBehaviorRecursive
var _scroll := Vector2i.ZERO
var _pan_remainder := Vector2.ZERO
var _panning := false
var _applying := false
var _interaction_blocked := false
var cell_size := 36
var always_fit := false
var view_save_failed := false
var zoom_controls: Array[Control] = []
var view_controls: HBoxContainer
var cell_size_menu: OptionButton
var view_controls_external := false
var _view_profile: Object
var _view_scope := "app_beginner"
var _view_dirty := false
var _writing_view := false
var _saved_view := Vector2i(36, 0)
var _view_flush: Timer
var _pinch_base := -1.0
var _view_height := 48

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
	grid.cell_action_requested.connect(func(action: StringName, index: int, revision: int):
		if information_sheet == null: cell_action_requested.emit(action, index, revision))
	grid.new_board_requested.connect(func():
		if information_sheet == null: new_board_requested.emit())
	grid.focused_cell_changed.connect(reveal_focus)
	grid.pan_requested.connect(_pan)
	grid.panning_changed.connect(_set_panning)
	grid.zoom_step_requested.connect(_grid_zoom_step)
	grid.pinch_zoom_requested.connect(_pinch_zoom)
	grid.pinch_zoom_finished.connect(_finish_pinch)
	grid.view_input_changed.connect(_refresh_view_controls)
	view_controls = HBoxContainer.new()
	view_controls.name = "BoardViewControls"
	view_controls.add_theme_constant_override("separation", 8)
	add_child(view_controls)
	cell_size_menu = OptionButton.new()
	cell_size_menu.name = "CellSize"
	cell_size_menu.item_selected.connect(_select_cell_size)
	view_controls.add_child(cell_size_menu)
	zoom_controls.append(cell_size_menu)
	var fit_button: Button = VIEW_BUTTON.new()
	fit_button.name = "FitBoard"
	fit_button.pressed.connect(func(): set_always_fit(not always_fit))
	view_controls.add_child(fit_button)
	zoom_controls.append(fit_button)
	_view_flush = Timer.new()
	_view_flush.one_shot = true
	_view_flush.wait_time = 0.25
	_view_flush.timeout.connect(flush_view_preferences)
	add_child(_view_flush)
	visibility_changed.connect(func():
		if not is_visible_in_tree(): flush_view_preferences()
		view_controls.visible = is_visible_in_tree() and information_sheet == null)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	if theme == null: configure()
	_apply_geometry()

func configure(host: String = "desktop_app", locale: String = "en", percent: int = 100,
		large: bool = false, palette: StringName = &"after_hours", native_band: Vector2i = Vector2i.ZERO,
		high_contrast: bool = false, colour_preset: String = "standard", font_style: String = "pixel") -> bool:
	if host not in ["desktop_app", "canonical_solo", "canonical_pair"]: return false
	var candidate_theme := MS_THEME.build(locale, percent, palette, high_contrast, colour_preset, font_style)
	var candidate_band := native_band
	if candidate_band == Vector2i.ZERO: candidate_band = Vector2i(400 if host == "desktop_app" else 480, 232 if large else 246)
	if candidate_theme == null or not LAYOUT.measure(1, 1, candidate_band, large).ok: return false
	var sheet_band := candidate_band + Vector2i(0, (0 if view_controls_external else view_controls_height(locale, candidate_theme, large)) / 2)
	if information_sheet != null and not information_sheet.configure(host,locale,percent,large,palette,sheet_band,high_contrast,colour_preset,font_style): return false
	var geometry_changed: bool = candidate_band != _band or large != _large
	if geometry_changed: grid.cancel_pointer_gesture()
	if not grid.configure(locale, percent, large, palette, high_contrast, colour_preset, font_style): return false
	_locale = locale.replace("_", "-")
	_host = host
	_percent = percent
	_palette = palette
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	_font_style = font_style
	_large = large
	_band = candidate_band
	theme = candidate_theme
	_configure_view_controls()
	if geometry_changed: _pan_remainder = Vector2.ZERO
	_apply_geometry()
	if geometry_changed: reveal_focus(grid.focused_index)
	return true

func present(projection: Dictionary) -> bool:
	var prior_focus: int = grid.focused_index
	_applying = true
	var accepted: bool = grid.present(projection)
	_applying = false
	if not accepted: return false
	_pan_remainder = Vector2.ZERO
	_apply_geometry()
	var initial_cell: bool = grid.focused_index >= 0 and bool(grid.projection.cells[grid.focused_index].bracketed)
	if grid.has_focus() or grid.focused_index != prior_focus or initial_cell: reveal_focus(grid.focused_index)
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
	if _interaction_blocked or grid.projection.is_empty() or grid.projection.custody: return false
	if information_sheet != null:
		# Switching documents keeps the board, focus index and pan completely untouched.
		return information_sheet.present_rules() if kind == "rules" else information_sheet.present_assignments(claimed)
	if not flush_view_preferences(): return false
	var sheet: Control = SHEET.new()
	sheet.hide()
	add_child(sheet)
	var accepted: bool = sheet.configure(_host,_locale,_percent,_large,_palette,_band + Vector2i(0, _view_height / 2),_high_contrast,_colour_preset,_font_style)
	if accepted: accepted = sheet.present_rules() if kind == "rules" else sheet.present_assignments(claimed)
	if not accepted:
		remove_child(sheet)
		sheet.queue_free()
		return false
	var focused: Control = source if source != null else get_viewport().gui_get_focus_owner()
	_source_focus = weakref(focused) if focused != null else null
	information_sheet = sheet
	grid.cancel_input()
	_grid_process_mode = grid.process_mode
	_grid_focus_behavior = grid.focus_behavior_recursive
	grid.process_mode = Node.PROCESS_MODE_DISABLED
	grid.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
	view_controls.hide()
	if vertical_rail != null: vertical_rail.hide()
	if horizontal_rail != null: horizontal_rail.hide()
	sheet.return_requested.connect(close_information)
	sheet.show()
	sheet.rows[0].grab_focus()
	return true

func close_information(focus_board: bool = false) -> void:
	if information_sheet == null: return
	var sheet := information_sheet
	information_sheet = null
	remove_child(sheet)
	sheet.queue_free()
	grid.process_mode = _grid_process_mode
	grid.focus_behavior_recursive = _grid_focus_behavior
	view_controls.visible = is_visible_in_tree()
	if vertical_rail != null: vertical_rail.show()
	if horizontal_rail != null: horizontal_rail.show()
	var source: Control = _source_focus.get_ref() if _source_focus != null else null
	_source_focus = null
	# Returning from a sheet restores its exact pan, even if the retained cell is
	# offscreen. A subsequent grid navigation resumes normal focus revelation.
	_applying = true
	information_closing.emit()
	if focus_board and grid.focus_mode != Control.FOCUS_NONE: grid.grab_focus()
	elif source != null and source.is_visible_in_tree() and source.focus_mode != Control.FOCUS_NONE: source.grab_focus()
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
	custom_minimum_size = Vector2(_band * 2) + Vector2(0, _view_height)
	size = custom_minimum_size
	_place_view_controls()
	if grid.projection.is_empty(): return
	var result := LAYOUT.measure_view(grid.projection.width, grid.projection.height, _band, _large, cell_size, always_fit, _scroll)
	if not result.ok: return
	geometry = result.value
	_scroll = geometry.scroll
	well.position = Vector2.ZERO
	well.size = Vector2(geometry.well.size * 2)
	grid.position = Vector2(geometry.mount.position * 2)
	grid.scale = Vector2.ONE * float(geometry.scale)
	_seam.size = well.size
	var interactive: bool = not _interaction_blocked and not grid.projection.custody
	vertical_rail = _update_rail(vertical_rail, geometry.vertical, true, interactive)
	horizontal_rail = _update_rail(horizontal_rail, geometry.horizontal, false, interactive)
	if vertical_rail != null: vertical_rail.visible = information_sheet == null
	if horizontal_rail != null: horizontal_rail.visible = information_sheet == null
	_update_seam()
	_refresh_view_controls()
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
	rail.configure(vertical, _locale, theme, _large)
	rail.present(public_rail, geometry.maximum_scroll[axis], _scroll[axis], geometry.well.size[axis], interactive)
	return rail

func _scroll_axis(value: int, vertical: bool) -> void:
	var next := _scroll
	next[1 if vertical else 0] = value
	set_scroll(next)

func reveal_focus(index: int) -> void:
	if _interaction_blocked or information_sheet != null or _applying or grid.projection.is_empty() or grid.projection.custody or index < 0: return
	var result := LAYOUT.reveal_view(grid.projection.width, grid.projection.height, index, _band, _large, cell_size, always_fit, _scroll)
	if result.ok:
		_scroll = result.value.scroll
		_apply_geometry()

func _pan(delta: Vector2) -> void:
	if _interaction_blocked or information_sheet != null or grid.projection.is_empty() or grid.projection.custody: return
	_pan_remainder -= delta * grid.scale / 2.0
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
	if _interaction_blocked or information_sheet != null: return
	if event is InputEventScreenTouch or event is InputEventScreenDrag:
		# The board can be smaller than the well. A second finger in that blank
		# space still belongs to the same gesture and must cancel the pending tap.
		if Rect2(Vector2.ZERO, well.size).has_point(event.position) or grid.has_held_touch():
			var forwarded: InputEvent = event.duplicate()
			forwarded.position = (event.position - grid.position) / grid.scale
			if forwarded is InputEventScreenDrag: forwarded.relative /= grid.scale
			grid._gui_input(forwarded)
			accept_event()
		return
	if not event is InputEventMouseButton or not event.pressed or geometry.is_empty(): return
	if not Rect2(Vector2.ZERO, well.size).has_point(event.position): return
	if event.ctrl_pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
		step_zoom(1 if event.button_index == MOUSE_BUTTON_WHEEL_UP else -1, event.position / 2.0, true)
		accept_event()
		return
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

static func view_controls_height(locale: String, next_theme: Theme, large: bool) -> int:
	var measured: Dictionary = VIEW_BUTTON.ROW.measure_copy(FIT_COPY[locale.replace("_", "-")], next_theme, FIT_WIDTH - 20)
	# The 36px pixel face has a 50px line box; retain it inside the 64px footer.
	var vertical_padding := 14 if next_theme.default_font_size == 36 else 16
	return 2 * ceili(maxf(64 if large else 48, float(measured.height) + vertical_padding) / 2.0)

func set_footer_host(host: Control) -> void:
	if not is_instance_valid(host) or view_controls.get_parent() == host: return
	view_controls.reparent(host, false)
	view_controls_external = true
	_view_height = 0
	view_controls.visible = is_visible_in_tree() and information_sheet == null
	_apply_geometry()
	view_controls_changed.emit()

func _configure_view_controls() -> void:
	view_controls.theme = theme
	var fit_copy: String = FIT_COPY[_locale]
	# Compact face padding keeps the footer within its bar; large targets still get 64px.
	zoom_controls[1].configure(fit_copy, theme, false, FIT_WIDTH)
	zoom_controls[1].custom_minimum_size.y = view_controls_height(_locale, theme, _large)
	zoom_controls[1].accessibility_name = VIEW_COPY[_locale][0]
	cell_size_menu.clear()
	cell_size_menu.add_item(fit_copy, 0)
	for pixels in range(10, 61, 2): cell_size_menu.add_item(str(pixels) + " px", pixels)
	cell_size_menu.custom_minimum_size = Vector2(152 if _percent == 100 else 192, 64 if _large else 48)
	cell_size_menu.add_theme_color_override("font_color", theme.get_color(&"primary_dark_copy", &"Minesweeper"))
	var face := StyleBoxFlat.new()
	face.bg_color = theme.get_color(&"controlled_face", &"Minesweeper")
	face.border_color = theme.get_color(&"dark_registration", &"Minesweeper")
	face.set_border_width_all(2)
	face.content_margin_left = 12
	face.content_margin_right = 24
	face.content_margin_top = 6
	face.content_margin_bottom = 6
	for state: String in ["normal", "hover", "pressed", "disabled"]:
		cell_size_menu.add_theme_stylebox_override(state, face)
		if state != "normal":
			cell_size_menu.add_theme_color_override("font_" + state + "_color", theme.get_color(&"secondary_dark_copy" if state == "disabled" else &"primary_dark_copy", &"Minesweeper"))
	var focus_face: StyleBoxFlat = face.duplicate()
	focus_face.draw_center = false
	focus_face.border_color = theme.get_color(&"dark_focus_outer", &"Minesweeper")
	cell_size_menu.add_theme_stylebox_override("focus", focus_face)
	var popup := cell_size_menu.get_popup()
	popup.max_size = Vector2i(0, 360)
	popup.add_theme_stylebox_override("panel", face)
	popup.add_theme_color_override("font_color", theme.get_color(&"primary_dark_copy", &"Minesweeper"))
	var selected_face: StyleBoxFlat = face.duplicate()
	selected_face.bg_color = theme.get_color(&"selected_plane", &"Minesweeper")
	popup.add_theme_stylebox_override("hover", selected_face)
	popup.add_theme_color_override("font_hover_color", theme.get_color(&"selected_ink", &"Minesweeper"))
	cell_size_menu.accessibility_name = VIEW_COPY[_locale][1] % str(cell_size)
	_view_height = 0 if view_controls_external else view_controls_height(_locale, theme, _large)
	_place_view_controls()
	_refresh_view_controls()

func _place_view_controls() -> void:
	if not view_controls_external:
		view_controls.position = Vector2(8, _band.y * 2)
		view_controls.size = Vector2(_band.x * 2 - 16, _view_height)
		view_controls.alignment = BoxContainer.ALIGNMENT_END
	if not is_inside_tree(): return
	for index in zoom_controls.size():
		var control: Control = zoom_controls[index]
		control.focus_neighbor_left = control.get_path_to(zoom_controls[maxi(0, index - 1)])
		control.focus_neighbor_right = control.get_path_to(zoom_controls[mini(zoom_controls.size() - 1, index + 1)])
		control.focus_neighbor_top = control.get_path_to(grid)
	grid.focus_neighbor_bottom = grid.get_path_to(zoom_controls[0])

func _refresh_view_controls() -> void:
	var enabled: bool = _view_allowed()
	cell_size_menu.disabled = not enabled
	cell_size_menu.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	cell_size_menu.select(0 if always_fit else cell_size_menu.get_item_index(cell_size))
	zoom_controls[1].present_state(enabled, always_fit)
	var displayed: String = ("%.1f" % (float(geometry.get("target", cell_size / 2.0)) * 2.0)) if always_fit else str(cell_size)
	var description: String = VIEW_COPY[_locale][2 if always_fit else 1] % displayed
	if view_save_failed:
		description += "\n" + VIEW_COPY[_locale][3]
		if cell_size_menu.selected >= 0: cell_size_menu.text = cell_size_menu.get_item_text(cell_size_menu.selected) + " !"
	for control: Control in zoom_controls:
		control.accessibility_description = description
		control.tooltip_text = description + "\n" + VIEW_COPY[_locale][4]
	cell_size_menu.accessibility_name = description

func _select_cell_size(index: int) -> void:
	var selected_size := cell_size_menu.get_item_id(index)
	if selected_size == 0: set_always_fit(true)
	else: set_cell_size(selected_size)
	_refresh_view_controls()

func set_cell_size(pixels: int) -> bool:
	if pixels < 10 or pixels > 60 or pixels % 2 != 0 or not _view_allowed(): return false
	return _change_view(pixels, false, _view_anchor(), false)

func bind_view_preferences(profile: Object, scope: String) -> bool:
	if scope not in VIEW_SCOPES or (profile != null and not profile.has_method("get_preference")): return false
	if _view_profile == profile: return set_view_scope(scope)
	if not flush_view_preferences(): return false
	if is_instance_valid(_view_profile) and _view_profile.has_signal("preference_changed") and _view_profile.is_connected("preference_changed", _view_preference_changed):
		_view_profile.disconnect("preference_changed", _view_preference_changed)
	_view_profile = profile
	_view_scope = scope
	if profile != null and profile.has_signal("preference_changed"):
		profile.connect("preference_changed", _view_preference_changed)
	_load_view_preferences()
	return true

func set_view_scope(scope: String) -> bool:
	if scope not in VIEW_SCOPES: return false
	if scope == _view_scope: return true
	if not flush_view_preferences(): return false
	_view_scope = scope
	_load_view_preferences()
	return true

func _view_path(suffix: String) -> StringName:
	return StringName("preferences.display.minesweeper_%s_%s" % [_view_scope, suffix])

func _load_view_preferences() -> void:
	cell_size = int(_view_profile.get_preference(_view_path("cell_size"), 36)) if is_instance_valid(_view_profile) else 36
	always_fit = bool(_view_profile.get_preference(_view_path("always_fit"), false)) if is_instance_valid(_view_profile) else false
	_saved_view = Vector2i(cell_size, int(always_fit))
	_scroll = Vector2i.ZERO
	view_save_failed = false
	_apply_geometry()
	view_controls_changed.emit()

func _view_preference_changed(path: StringName, _value: Variant) -> void:
	if not _writing_view and path in [_view_path("cell_size"), _view_path("always_fit")]: _load_view_preferences()

func _view_allowed(pinch: bool = false) -> bool:
	return not _interaction_blocked and information_sheet == null and not grid.projection.is_empty() \
		and grid.is_view_input_admitted() and (pinch or not grid.has_held_action())

func _view_anchor() -> Vector2:
	if grid.focused_index >= 0 and grid.focused_index < grid.cell_nodes.size():
		var cell: Control = grid.cell_nodes[grid.focused_index]
		var point: Vector2 = (grid.position + (cell.position + cell.size / 2.0) * grid.scale) / 2.0
		if Rect2(Vector2.ZERO, well.size / 2.0).has_point(point): return point
	return well.size / 4.0

func set_always_fit(enabled: bool) -> bool:
	if not _view_allowed(): return false
	if enabled == always_fit: return true
	return _change_view(cell_size, enabled, _view_anchor(), false)

func step_zoom(steps: int, anchor_native: Vector2 = Vector2(-1, -1), coalesce: bool = false) -> bool:
	if not _view_allowed(): return false
	var current: int = roundi(float(geometry.target)) * 2 if always_fit else cell_size
	var next := clampi(current + steps * 2, 10, 60)
	return _change_view(next, false, _view_anchor() if anchor_native.x < 0 else anchor_native, coalesce)

func _change_view(next: int, fit: bool, anchor: Vector2, coalesce: bool) -> bool:
	if next == cell_size and fit == always_fit: return true
	var old: Dictionary = geometry
	cell_size = next
	always_fit = fit
	view_save_failed = false
	_apply_geometry()
	if not old.is_empty():
		_scroll = LAYOUT.anchored_scroll(old, geometry, anchor)
		_apply_geometry()
	_view_dirty = true
	view_controls_changed.emit()
	if coalesce:
		_view_flush.start()
		return true
	return flush_view_preferences()

func _grid_zoom_step(steps: int, local_anchor: Vector2, source: StringName) -> void:
	var anchor := _view_anchor() if source == &"controller" else (grid.position + local_anchor * grid.scale) / 2.0
	step_zoom(steps, anchor, source == &"wheel")

func _pinch_zoom(ratio: float, local_anchor: Vector2) -> void:
	if not _view_allowed(true): return
	if _pinch_base < 0:
		_pinch_base = float(geometry.target) * 2.0
		return
	var next := clampi(roundi(_pinch_base * ratio / 2.0) * 2, 10, 60)
	_change_view(next, false, (grid.position + local_anchor * grid.scale) / 2.0, true)
	# A pinch is one transaction, regardless of how long fingers pause mid-gesture.
	_view_flush.stop()

func _finish_pinch() -> void:
	_pinch_base = -1.0
	flush_view_preferences()

func flush_view_preferences() -> bool:
	_view_flush.stop()
	if not _view_dirty: return true
	_writing_view = true
	var ok := true
	if is_instance_valid(_view_profile):
		ok = _view_profile.has_method("set_preferences") and _view_profile.set_preferences({
			_view_path("cell_size"): cell_size, _view_path("always_fit"): always_fit}).get("ok", false)
	_writing_view = false
	_view_dirty = false
	view_save_failed = not ok
	if ok: _saved_view = Vector2i(cell_size, int(always_fit))
	else:
		cell_size = _saved_view.x
		always_fit = bool(_saved_view.y)
		_apply_geometry()
	_refresh_view_controls()
	return ok

func _exit_tree() -> void:
	flush_view_preferences()
	if view_controls_external and is_instance_valid(view_controls): view_controls.queue_free()

