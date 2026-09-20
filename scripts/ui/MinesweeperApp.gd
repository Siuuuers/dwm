extends AppWindowBase
class_name MinesweeperApp
## Cached desktop body. Lifecycle admission precedes visibility; gameplay stays in the injected port.

signal recovery_requested(code: StringName)
signal foreground_availability_changed()

const PANEL := preload("res://scripts/ui/minesweeper/MinesweeperPanel.gd")
const GRID := preload("res://scripts/ui/minesweeper/MinesweeperGrid.gd")
const RETRY_BUTTON := preload("res://scripts/ui/minesweeper/MinesweeperActionButton.gd")
const PREFERENCE_KEYS := ["preferences.accessibility.text_size","preferences.accessibility.large_targets",
	"preferences.accessibility.font_scale","preferences.accessibility.large_click_targets",
	"preferences.accessibility.high_contrast","preferences.accessibility.colour_differentiation",
	"preferences.accessibility.colorblind_mode"]
const LEGACY_COLOUR_PRESETS := {"none":"standard","protanopia":"protan","deuteranopia":"deutan","tritanopia":"tritan"}

var panel: Control
var last_result: Dictionary = {"ok":false,"code":&"minesweeper_unconfigured"}
var _port: Object
var _localization: Object
var _profile: Object
var _input_owner: Object
var _palette: StringName = &"after_hours"
var _home: Button
var _busy := false
var _show_prepared := false
var _hide_prepared := false
var _focus_key := "grid"
var _cell := 0
var _scroll := Vector2i.ZERO
var _restoring_focus := false
var _has_cached_navigation := false
var _preparation_retry: Button
var _preparation_retry_needed := false
var _preparation_foreground := false
var _desktop_layout_height := 0

func _ready() -> void:
	super._ready()
	var window := get_window()
	_preparation_foreground = window != null and window.has_focus()
	custom_minimum_size = Vector2(800,656)
	add_theme_stylebox_override("panel",StyleBoxEmpty.new())
	$VBoxContainer/TopBar.hide()
	$VBoxContainer.add_theme_constant_override("separation",0)
	_content_host.custom_minimum_size = custom_minimum_size
	panel = PANEL.new()
	panel.name = "MinesweeperPanel"
	_content_host.add_child(panel)
	_preparation_retry = RETRY_BUTTON.new()
	_preparation_retry.name = "PreparationRetry"
	_preparation_retry.hide()
	_content_host.add_child(_preparation_retry)
	_preparation_retry.pressed.connect(_retry_preparation)
	panel.presentation_failed.connect(_on_failure)
	panel.presentation_changed.connect(_on_presented)
	panel.dock.action_requested.connect(func(_action: StringName): _update_home())
	panel.worksheet.information_closed.connect(_update_home)
	get_viewport().gui_focus_changed.connect(func(_control: Control): remember_focus())
	visibility_changed.connect(_on_visibility_changed)
	_on_visibility_changed()
	if get_parent() is Control: get_parent().resized.connect(_fit_host)
	_fit_host()

func set_desktop_height(height: int) -> void:
	if height <= 0 or height == _desktop_layout_height: return
	_desktop_layout_height = height
	_fit_host()


func _fit_host() -> void:
	var host := get_parent() as Control
	if host == null or host.size.x <= 0 or host.size.y <= 0: return
	# Desktop enlargement belongs to the shared canvas; small standalone hosts
	# still fit the complete app without adding another enlargement factor.
	var factor := minf(1.0, minf(host.size.x / 800.0, host.size.y / 656.0))
	var height := floori(host.size.y / factor / 2.0) * 2
	if _desktop_layout_height > 0:
		factor = 1.0
		height = _desktop_layout_height / 2 * 2
	if not panel.set_layout_height(height):
		panel.set_layout_height(656)
	custom_minimum_size = Vector2(800, panel.layout_height)
	_content_host.custom_minimum_size = custom_minimum_size
	size = custom_minimum_size
	scale = Vector2.ONE * factor

func set_footer_host(host: Control) -> void:
	if panel == null: return
	panel.worksheet.set_footer_host(host)
	panel.configure(panel._locale, panel._percent, panel._large, panel._palette,
		panel._high_contrast, panel._colour_preset)
	_fit_host()
	_update_home()

func _process(_delta: float) -> void:
	if _busy or _port == null or not _port.has_method("advance_preparation") or panel == null \
			or not last_result.get("ok",false) or not panel.has_valid_presentation(): return
	# dwm-634.1: a terminal click paints first; its settlement runs here on the next frame and
	# waits for nothing (not focus, not a held contact), because it is a durable save.
	var settling: bool = _port.has_method("has_pending_settlement") and _port.has_pending_settlement()
	if not settling:
		if not _preparation_foreground or not is_visible_in_tree() or get_tree().paused \
				or panel.worksheet.information_sheet != null or panel.worksheet.grid.has_held_touch(): return
		var grid: Control = panel.worksheet.grid
		if int(grid.get("_held_index")) >= 0 or bool(grid.get("_mouse_dragging")) or bool(grid.get("_confirm_held")): return
	_busy = true
	var result: Dictionary = _port.call("advance_preparation",int(panel.public_view.board.revision))
	_busy = false
	if not result.get("ok",false):
		panel._receive(result)
		_preparation_retry_needed = true
		_refresh_preparation_retry()
		_preparation_retry.grab_focus()
	elif result.get("advanced",false):
		panel._receive(result)

func _retry_preparation() -> void:
	if not _preparation_retry_needed or _busy or not _preparation_foreground or not is_visible_in_tree() or get_tree().paused: return
	_preparation_retry_needed = false
	_refresh_preparation_retry()
	if not refresh_view().get("ok",false):
		_preparation_retry_needed = true
		_refresh_preparation_retry()
		return
	_process(0.0)

func _refresh_preparation_retry() -> void:
	if _preparation_retry == null: return
	if not _preparation_retry_needed:
		_preparation_retry.hide()
		return
	var locale := str(_localization.get_locale()).replace("_","-") if _localization != null else "en"
	var copy: String = {"en":"Retry","zh-CN":"\u91cd\u8bd5","zh-HK":"\u91cd\u8a66", "ja": "再試行", "ko": "다시 시도"}.get(locale,"Retry")
	if not _preparation_retry.configure(copy,panel.register.theme,bool(panel.get("_large")),160): return
	_preparation_retry.present_state(true,false)
	_preparation_retry.position = Vector2(320,300)
	_preparation_retry.show()

func configure_presentation(port: Object, localization: Object = null, profile: Object = null,
		input_owner: Object = null, palette: StringName = &"after_hours") -> Dictionary:
	if palette not in [&"after_hours",&"midnight"]: return {"ok":false,"code":&"invalid_minesweeper_palette"}
	if not is_node_ready() or not is_instance_valid(port): return _fail(&"minesweeper_unconfigured")
	for method: String in ["pull","dispatch","set_foreground"]:
		if not port.has_method(method): return _fail(&"invalid_minesweeper_presentation")
	if localization != null and not localization.has_method("get_locale"): return _fail(&"invalid_minesweeper_preferences")
	if profile != null and not profile.has_method("get_preference"): return _fail(&"invalid_minesweeper_preferences")
	var candidate_input: Object = input_owner if input_owner != null else get_node_or_null("/root/InputManager")
	if candidate_input != null and not GRID.accepts_input_owner(candidate_input): return _fail(&"invalid_minesweeper_input")
	if _port != null and (_port != port or _localization != localization or _profile != profile or _input_owner != candidate_input or _palette != palette):
		return {"ok":false,"code":&"minesweeper_already_configured"}
	if not panel.bind(port): return _fail(&"invalid_minesweeper_presentation")
	if candidate_input != null and not panel.worksheet.grid.configure_input(candidate_input): return _fail(&"invalid_minesweeper_input")
	_port = port
	_localization = localization
	_profile = profile
	if not panel.worksheet.bind_view_preferences(profile, "app_" + str(panel.public_view.get("register", {}).get("difficulty", "beginner"))):
		return _fail(&"invalid_minesweeper_preferences")
	_input_owner = candidate_input
	_palette = palette
	if localization != null and localization.has_signal("locale_changed") and not localization.is_connected("locale_changed",_on_locale_changed):
		localization.connect("locale_changed",_on_locale_changed)
	if profile != null and profile.has_signal("preference_changed") and not profile.is_connected("preference_changed",_on_preference_changed):
		profile.connect("preference_changed",_on_preference_changed)
	if not _apply_preferences(): return _fail(&"invalid_minesweeper_preferences")
	return refresh_view()

func refresh_view() -> Dictionary:
	if _port == null or not panel.refresh(): return _fail(&"minesweeper_presentation_unavailable")
	last_result = {"ok":true}
	_update_home()
	return last_result.duplicate()

func prepare_show_window() -> Dictionary:
	if _show_prepared: return {"ok":true}
	var result := _foreground(true)
	_show_prepared = result.get("ok",false)
	return result

func prepare_return_home() -> Dictionary:
	if _hide_prepared: return {"ok":true}
	if not can_return_home(): return {"ok":false,"code":&"desktop_modal_active"}
	panel.worksheet.close_information()
	if not panel.worksheet.flush_view_preferences(): return {"ok":false,"code":&"minesweeper_view_preferences_unavailable"}
	remember_focus()
	_cell = maxi(0,panel.worksheet.grid.focused_index)
	_scroll = panel.worksheet.get_scroll()
	_has_cached_navigation = true
	var result := _foreground(false)
	_hide_prepared = result.get("ok",false)
	return result

func _foreground(foreground: bool) -> Dictionary:
	if _busy or _port == null or not panel.has_valid_presentation(): return _fail(&"minesweeper_presentation_unavailable")
	_busy = true
	var result: Variant = _port.call("set_foreground",foreground,panel.public_view.board.revision)
	_busy = false
	if not result is Dictionary:
		panel.present({})
		return _fail(&"minesweeper_presentation_unavailable")
	if result.get("value") is Dictionary: panel.present(result.value)
	else: panel.present({})
	if not result.get("ok",false): return _fail(&"minesweeper_foreground_refused")
	if not result.get("value") is Dictionary or not panel.has_valid_presentation(): return _fail(&"minesweeper_presentation_unavailable")
	last_result = {"ok":true}
	return last_result.duplicate()

func show_window() -> void:
	if not prepare_show_window().get("ok",false): return
	_show_prepared = false
	_hide_prepared = false
	show()
	panel.process_mode = Node.PROCESS_MODE_INHERIT
	_restore_focus()
	_update_home()

func hide_window() -> void:
	if not prepare_return_home().get("ok",false): return
	_show_prepared = false
	hide()
	window_hidden.emit()

func can_return_home() -> bool:
	if _hide_prepared: return true
	if _busy or panel == null or not panel.has_valid_presentation(): return false
	if panel.public_view.settled or not panel.public_view.board.custody: return true
	return last_result.get("ok",false) and _port != null \
		and _port.has_method("can_park_preparation") \
		and _port.call("can_park_preparation",int(panel.public_view.board.revision))

func configure_desktop_home(home: Button) -> void:
	_home = home
	if is_node_ready(): _update_home()

func _update_home() -> void:
	if not is_instance_valid(_home) or not is_visible_in_tree(): return
	var enabled := can_return_home()
	_home.disabled = not enabled
	_home.focus_mode = Control.FOCUS_ALL if enabled else Control.FOCUS_NONE
	panel.connect_host_focus(_home,_home)
	var first: Control = panel.worksheet.grid
	for button: Control in panel.register.difficulties.values():
		if button.focus_mode != Control.FOCUS_NONE:
			first = button
			break
	_home.focus_next = _home.get_path_to(first)
	_home.focus_neighbor_bottom = _home.focus_next
	_home.focus_previous = _home.get_path_to(panel.dock.buttons.rules) if panel.dock.buttons.has("rules") else NodePath()
	if panel.worksheet.view_controls_external:
		for control: Control in panel.worksheet.zoom_controls:
			if control.is_visible_in_tree() and control.focus_mode != Control.FOCUS_NONE:
				_home.focus_previous = _home.get_path_to(control)
	foreground_availability_changed.emit()

func remember_focus() -> void:
	if panel == null or not is_visible_in_tree() or _restoring_focus or _busy: return
	var focused: Control = get_viewport().gui_get_focus_owner()
	if focused == panel.worksheet.grid: _focus_key = "grid"
	elif focused != null and focused == panel.worksheet.vertical_rail: _focus_key = "vertical"
	elif focused != null and focused == panel.worksheet.horizontal_rail: _focus_key = "horizontal"
	else:
		for key: String in panel.dock.buttons:
			if focused == panel.dock.buttons[key]: _focus_key = key
		for key: String in panel.register.difficulties:
			if focused == panel.register.difficulties[key]: _focus_key = "difficulty:"+key

func _restore_focus() -> void:
	_restoring_focus = true
	var restore_scroll := _has_cached_navigation
	var target: Control = panel.dock.buttons.get(_focus_key)
	if _focus_key.begins_with("difficulty:"): target = panel.register.difficulties.get(_focus_key.trim_prefix("difficulty:"))
	if _focus_key == "vertical": target = panel.worksheet.vertical_rail
	elif _focus_key == "horizontal": target = panel.worksheet.horizontal_rail
	if _focus_key == "grid" or target == null or target.focus_mode == Control.FOCUS_NONE:
		var index: int = _cell if _has_cached_navigation else panel.worksheet.grid.focused_index
		if not panel.worksheet.grid.focus_cell(index):
			restore_scroll = false
			if not panel.worksheet.grid.focus_cell(panel.worksheet.grid.focused_index) and is_instance_valid(_home): _home.grab_focus()
	else: target.grab_focus()
	if restore_scroll: panel.worksheet.set_scroll(_scroll)
	_restoring_focus = false

func _on_visibility_changed() -> void:
	if panel == null: return
	if not is_visible_in_tree():
		panel.worksheet.grid.cancel_input()
		panel.process_mode = Node.PROCESS_MODE_DISABLED
	else: panel.process_mode = Node.PROCESS_MODE_INHERIT

func _unhandled_input(event: InputEvent) -> void:
	if not is_visible_in_tree(): return
	if panel.worksheet.information_sheet != null: return
	if event.is_action_pressed("ui_cancel"):
		hide_window()
		get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT,NOTIFICATION_APPLICATION_FOCUS_OUT]:
		_preparation_foreground = false
		if is_instance_valid(panel): panel.worksheet.grid.cancel_input()
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_IN,NOTIFICATION_APPLICATION_FOCUS_IN]:
		_preparation_foreground = true

func _apply_preferences() -> bool:
	var locale := str(_localization.get_locale()).replace("_","-") if _localization != null else "en"
	var percent: Variant = _profile.get_preference("preferences.accessibility.text_size",null) if _profile != null else 100
	if percent == null:
		var scale_value: Variant = _profile.get_preference("preferences.accessibility.font_scale",1.0)
		if typeof(scale_value) not in [TYPE_INT,TYPE_FLOAT]: return false
		percent = 150 if scale_value >= 1.5 else (125 if scale_value >= 1.25 else 100)
	var large: Variant = _profile.get_preference("preferences.accessibility.large_targets",null) if _profile != null else false
	if large == null: large = _profile.get_preference("preferences.accessibility.large_click_targets",false)
	if typeof(percent) != TYPE_INT or typeof(large) != TYPE_BOOL: return false
	var high_contrast: Variant = _profile.get_preference("preferences.accessibility.high_contrast",false) if _profile != null else false
	var colour: Variant = _profile.get_preference("preferences.accessibility.colour_differentiation",null) if _profile != null else "standard"
	if colour == null:
		var legacy: Variant = _profile.get_preference("preferences.accessibility.colorblind_mode","none")
		if typeof(legacy) != TYPE_STRING or not LEGACY_COLOUR_PRESETS.has(legacy): return false
		colour = LEGACY_COLOUR_PRESETS[legacy]
	if typeof(high_contrast) != TYPE_BOOL or typeof(colour) != TYPE_STRING: return false
	var retained_scroll: Vector2i = panel.worksheet.get_scroll()
	if not panel.configure(locale,percent,large,_palette,high_contrast,colour):
		var previous_height: int = panel.layout_height
		# Large text can outgrow the compact board. Keep its readable layout and
		# let the desktop scroll the page instead of rejecting valid preferences.
		if _desktop_layout_height <= 0 or previous_height >= 656 or not panel.set_layout_height(656): return false
		if not panel.configure(locale,percent,large,_palette,high_contrast,colour):
			panel.set_layout_height(previous_height)
			return false
	_fit_host()
	if panel.worksheet.get_scroll() != retained_scroll: panel.worksheet.set_scroll(retained_scroll)
	return true

func _on_locale_changed(_locale: String) -> void:
	if not _apply_preferences(): _fail(&"invalid_minesweeper_preferences")
	elif last_result.get("code") == &"invalid_minesweeper_preferences" and panel.has_valid_presentation():
		last_result = {"ok":true}
	_refresh_preparation_retry()
	_update_home()

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if String(path) in PREFERENCE_KEYS: _on_locale_changed("")

func _on_presented() -> void:
	_preparation_retry_needed = false
	_refresh_preparation_retry()
	last_result = {"ok":true}
	_update_home()

func _on_failure(code: StringName) -> void:
	last_result = {"ok":false,"code":code}
	recovery_requested.emit(code)
	_update_home()

func _fail(code: StringName) -> Dictionary:
	_on_failure(code)
	return last_result.duplicate()

