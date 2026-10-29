extends Control
## View only. The host supplies the admitted command and trusted presentation port.
## No physical tokens, board identities, retry policy, or save authority live here.

signal presentation_failed(code: StringName)
signal presentation_changed()
signal closed()
signal home_requested()

const WORKSHEET := preload("res://scripts/ui/minesweeper/MinesweeperWorksheet.gd")
const DOCK := preload("res://scripts/ui/minesweeper/MinesweeperDock.gd")
const PANEL_SIZE := Vector2(960, 656)
const CELL_ACTIONS := [&"reveal", &"flag", &"unflag", &"chord"]

var home_button: Button
var toolbar: HBoxContainer
var worksheet: Control
var dock: Control
var public_view: Dictionary = {}
var _port: Object
var _command: Dictionary = {}
var _blocked := false
var _failed := true
var _dispatching := false
var _host := ""
var _locale := "en"
var _percent := 100
var _large := false
var _palette: StringName = &"after_hours"
var _high_contrast := false
var _colour_preset := "standard"
var _font_style := "pixel"

func _init() -> void:
	name = "SceneChallengePanel"
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	clip_contents = true
	custom_minimum_size = PANEL_SIZE
	size = PANEL_SIZE
	worksheet = WORKSHEET.new()
	worksheet.name = "Worksheet"
	add_child(worksheet)
	dock = DOCK.new()
	dock.name = "Dock"
	add_child(dock)
	toolbar = HBoxContainer.new()
	toolbar.name = "ChallengeToolbar"
	toolbar.add_theme_constant_override("separation", 8)
	add_child(toolbar)
	home_button = preload("res://scripts/ui/desktop/DesktopHomeButton.gd").new()
	home_button.name = "Home"
	home_button.current_on_launcher = false
	home_button.custom_minimum_size = Vector2(64, 64)
	home_button.pressed.connect(func():
		if _can_interact(): home_requested.emit())
	toolbar.add_child(home_button)
	worksheet.cell_action_requested.connect(_dispatch)
	worksheet.grid.mode_changed.connect(func(_mode: StringName): _apply_availability())
	worksheet.information_closed.connect(_apply_availability)
	dock.action_requested.connect(_action)
	visibility_changed.connect(_apply_availability)
	hide()

func _ready() -> void:
	_apply_availability()

func bind(port: Object, presentation_command: Dictionary) -> bool:
	if not is_instance_valid(port) or presentation_command.is_empty() \
			or not port.has_method("pull_scene_panel") or not port.has_method("dispatch_scene_panel_action"):
		return false
	if _port != null:
		return _port == port and _command == presentation_command
	_port = port
	_command = presentation_command.duplicate(true)
	return true

func bind_view_preferences(profile: Object) -> bool:
	return worksheet.bind_view_preferences(profile, "challenge")

func configure_input(input_owner: Object) -> bool:
	return worksheet.grid.configure_input(input_owner)

func configure_scene(locale: String = "en", percent: int = 100, large: bool = false,
		palette: StringName = &"after_hours", high_contrast: bool = false,
		colour_preset: String = "standard", font_style: String = "pixel") -> bool:
	_locale = locale
	_percent = percent
	_large = large
	_palette = palette
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	_font_style = font_style
	_host = ""
	return refresh() if _port != null else true

func open_panel() -> bool:
	if not refresh(): return false
	show()
	_apply_availability()
	return true

func close_panel() -> void:
	worksheet.grid.cancel_input()
	worksheet.close_information()
	hide()
	closed.emit()

func set_interaction_blocked(blocked: bool) -> void:
	_blocked = blocked
	_apply_availability()

func refresh() -> bool:
	if not is_instance_valid(_port): return _fail(&"scene_panel_unbound")
	var response: Variant = _port.call("pull_scene_panel", _command.duplicate(true))
	if not response is Dictionary or not response.get("ok", false):
		return _fail(StringName(response.get("code", "scene_panel_unavailable")) if response is Dictionary else &"scene_panel_unavailable")
	var value: Variant = response.get("value")
	if not value is Dictionary or value.get("host") not in ["canonical_solo", "canonical_pair"] \
			or not value.get("board") is Dictionary or not value.get("actions") is Array:
		return _fail(&"scene_panel_invalid_view")
	if not worksheet.grid.can_present(value.board): return _fail(&"scene_panel_invalid_view")
	if _host != value.host:
		for button: Button in dock.buttons.values():
			if button.get_parent() != dock: button.reparent(dock, false)
		if not dock.configure_scene(value.host, _locale, _percent, _large, _palette,
				_high_contrast, _colour_preset, _font_style): return _fail(&"scene_panel_invalid_view")
		# The scene host provides direct controls; no Pause surface here.
		dock.buttons.pause.hide()
		for key: String in ["flag", "drag", "rules"]:
			dock.buttons[key].reparent(toolbar, false)
		home_button.theme = preload("res://scripts/ui/desktop/DesktopTheme.gd").build(_locale, _percent, &"midnight", 0.0, false, "standard", _font_style)
		home_button.accessibility_name = {"en": "Home", "zh_CN": "主頁", "zh_HK": "主頁", "ja": "ホーム", "ko": "홈"}.get(_locale.replace("-", "_"), "Home")
		home_button.tooltip_text = home_button.accessibility_name
		worksheet.set_footer_host(toolbar)
		toolbar.move_child(worksheet.view_controls, -1)
		var bar_height := maxi(64, WORKSHEET.view_controls_height(_locale, dock.theme, _large))
		for key: String in ["flag", "drag", "rules"]:
			bar_height = maxi(bar_height, int(dock.buttons[key].custom_minimum_size.y))
		var band := Vector2i(480, (int(PANEL_SIZE.y) - bar_height - 8) / 2)
		if not worksheet.configure_scene(value.host, _locale, _percent, _large, _palette, band,
				_high_contrast, _colour_preset, _font_style):
			return _fail(&"scene_panel_invalid_view")
		_host = value.host
		dock.hide()
		toolbar.position = Vector2(8, worksheet.size.y + 4)
		toolbar.size = Vector2(PANEL_SIZE.x - 16, bar_height)
		queue_redraw()
	# Detach the publication once; never derive a substitute board after refusal.
	var publication: Dictionary = value.duplicate(true)
	if not worksheet.present(publication.board): return _fail(&"scene_panel_invalid_view")
	public_view = publication
	_failed = false
	_apply_availability()
	presentation_changed.emit()
	return true

func _can_interact() -> bool:
	return not _blocked and not _failed and not _dispatching and is_visible_in_tree() \
		and is_inside_tree() and not get_tree().paused

func _apply_availability() -> void:
	if worksheet == null or dock == null or not is_inside_tree(): return
	var blocked := not _can_interact()
	worksheet.set_interaction_blocked(blocked)
	home_button.disabled = blocked
	var actions: Array = []
	if not blocked and not public_view.get("board", {}).get("custody", true):
		actions = ["reveal", "flag", "drag", "rules"]
		if worksheet.information_sheet != null: actions = ["rules"]
	dock.present(worksheet.grid.mode, actions, false,
		"rules" if worksheet.information_sheet != null else "board")

func _action(action: StringName) -> void:
	if not _can_interact(): return
	match action:
		&"reveal", &"flag", &"drag": worksheet.set_mode(action)
		&"rules": worksheet.open_rules(dock.buttons.get("rules"))
	_apply_availability()

func _dispatch(action: StringName, index: int, revision: int) -> void:
	if not _can_interact() or worksheet.information_sheet != null or action not in CELL_ACTIONS: return
	if String(action) not in public_view.get("actions", []): return
	_dispatching = true
	var result: Variant = _port.call("dispatch_scene_panel_action", _command.duplicate(true), String(action), index, revision)
	_dispatching = false
	if not result is Dictionary or not result.get("ok", false):
		_fail(StringName(result.get("code", "scene_panel_action_refused")) if result is Dictionary else &"scene_panel_action_refused")
		return
	# Dispatch envelopes need not contain the panel host. Pull the authoritative view.
	refresh()

func _fail(code: StringName) -> bool:
	_failed = true
	_apply_availability()
	presentation_failed.emit(code)
	return false

func _draw() -> void:
	if toolbar == null or dock.theme == null: return
	draw_rect(Rect2(0, toolbar.position.y - 4, PANEL_SIZE.x, PANEL_SIZE.y - toolbar.position.y + 4),
		dock.theme.get_color("controlled_face", "Minesweeper"))
