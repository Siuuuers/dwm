extends Control
## Centered action dock. Selection and action availability are presented, never inferred.

signal action_requested(action: StringName)

const BUTTON := preload("res://scripts/ui/minesweeper/MinesweeperActionButton.gd")
const FLAG_BUTTON := preload("res://scripts/ui/minesweeper/MinesweeperFlagButton.gd")
const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const COPY := preload("res://scripts/ui/minesweeper/MinesweeperChromeCopy.gd")
const MODES := [&"reveal",&"flag",&"drag"]
const DESKTOP := ["flag","drag","new_board","assignments","rules"]
const CANONICAL := ["flag","drag","rules","pause"]
const GAP := 8

var buttons: Dictionary = {}
var mode: StringName = &"reveal"
var _enabled: Array = []
var _custody := false
var _host := "desktop_app"
var _selected_copy := ""
var _copy: Dictionary = {}
var _view := "board"

func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	focus_mode = Control.FOCUS_NONE
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED

func configure(host: String = "desktop_app", locale: String = "en", percent: int = 100,
		large: bool = false, palette: StringName = &"after_hours",
		high_contrast: bool = false, colour_preset: String = "standard") -> bool:
	if host not in ["desktop_app","canonical_solo","canonical_pair"]: return false
	var next_theme := MS_THEME.build(locale,percent,palette,high_contrast,colour_preset)
	if next_theme == null: return false
	var copy := COPY.get_copy(locale)
	var actions: Array = DESKTOP if host == "desktop_app" else CANONICAL
	var dock_width := 800 if host == "desktop_app" else 960
	var widths: Dictionary = {}
	var group_width := (actions.size()-1)*GAP
	for key: String in actions:
		var width := 80 if key == "flag" else BUTTON.single_line_width(copy[key],next_theme,large)
		if width == 0: return false
		widths[key] = width
		group_width += width
	if group_width > dock_width: return false
	var candidates: Dictionary = {}
	var height := 64 if large else 48
	for key: String in actions:
		var button: Button = FLAG_BUTTON.new() if key == "flag" else BUTTON.new()
		if not button.configure(copy[key],next_theme,large,widths[key]):
			button.free()
			for prior: Button in candidates.values(): prior.free()
			return false
		candidates[key] = button
		height = maxi(height,int(button.custom_minimum_size.y))
	var focused := ""
	for key: String in buttons:
		if buttons[key].has_focus(): focused = key
		remove_child(buttons[key])
		buttons[key].queue_free()
	buttons = candidates
	_host = host
	_selected_copy = copy.selected
	_copy = copy
	theme = next_theme
	var inset := 6 if large else 4
	custom_minimum_size = Vector2(dock_width,height+inset*2)
	size = custom_minimum_size
	var left := floorf((dock_width-group_width)/4.0)*2.0
	for key: String in actions:
		var button: Button = buttons[key]
		button.custom_minimum_size.y = height
		button.position = Vector2(left,inset)
		left += widths[key]+GAP
		add_child(button)
		button.pressed.connect(_request.bind(key))
	_apply_state()
	if buttons.has(focused) and not buttons[focused].disabled: buttons[focused].grab_focus()
	queue_redraw()
	return true

func present(next_mode: StringName, enabled_actions: Array, custody: bool = false, active_view: String = "board") -> bool:
	if next_mode not in MODES or active_view not in ["board", "rules", "assignments"]: return false
	var allowed := ["reveal","flag","drag","new_board","assignments","rules"] if _host == "desktop_app" else ["reveal","flag","drag","rules","pause"]
	var seen: Array = []
	for action: Variant in enabled_actions:
		if typeof(action) != TYPE_STRING or action not in allowed or action in seen: return false
		seen.append(action)
	mode = next_mode
	_view = active_view
	_enabled = enabled_actions.duplicate()
	_custody = custody
	_apply_state()
	return true

func _apply_state() -> void:
	for key: String in buttons:
		var selected: bool = key == mode if key in ["flag", "drag"] else key == _view
		var enabled: bool = key in _enabled
		if key == "flag": enabled = ("reveal" if mode == &"flag" else "flag") in _enabled
		buttons[key].present_state(not _custody and enabled,selected)
		buttons[key].accessibility_description = _selected_copy if selected else ""
		if key == "flag":
			buttons[key].accessibility_name = _copy.flag + ": " + _copy[String(mode)]
			buttons[key].tooltip_text = buttons[key].accessibility_name

func _request(action: String) -> void:
	if action == "flag": action = "reveal" if mode == &"flag" else "flag"
	if not _custody and action in _enabled:
		action_requested.emit(StringName(action))

func _draw() -> void:
	if theme == null: return
	draw_rect(Rect2(Vector2.ZERO,size),theme.get_color(&"controlled_face",&"Minesweeper"))
	draw_rect(Rect2(0,0,size.x,2),theme.get_color(&"dark_registration",&"Minesweeper"))

