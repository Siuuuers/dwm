extends Control
## Fixed-bay action dock. Selection and action availability are presented, never inferred.

signal action_requested(action: StringName)

const BUTTON := preload("res://scripts/ui/minesweeper/MinesweeperActionButton.gd")
const FLAG_BUTTON := preload("res://scripts/ui/minesweeper/MinesweeperFlagButton.gd")
const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const COPY := preload("res://scripts/ui/minesweeper/MinesweeperChromeCopy.gd")
const MODES := [&"reveal",&"flag",&"drag"]
const LEFT := [["flag",4,40],["drag",48,40],["board",92,48]]
const DESKTOP := [["new_board",144,64],["assignments",212,80],["rules",296,48]]
const CANONICAL := [["rules",376,48],["pause",428,48]]

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
	var allocations: Array = LEFT+(DESKTOP if host == "desktop_app" else CANONICAL)
	var candidates: Dictionary = {}
	var height := 64 if large else 48
	for allocation: Array in allocations:
		var button: Button = FLAG_BUTTON.new() if allocation[0] == "flag" else BUTTON.new()
		if not button.configure(copy[allocation[0]],next_theme,large,allocation[2]*2):
			button.free()
			for prior: Button in candidates.values(): prior.free()
			return false
		candidates[allocation[0]] = button
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
	custom_minimum_size = Vector2(800 if host == "desktop_app" else 960,height+inset*2)
	size = custom_minimum_size
	for allocation: Array in allocations:
		var key: String = allocation[0]
		var button: Button = buttons[key]
		button.custom_minimum_size.y = height
		button.position = Vector2(allocation[1]*2,inset)
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
		var enabled: bool = key in _enabled or (key == "board" and _view != "board")
		if key == "flag": enabled = ("reveal" if mode == &"flag" else "flag") in _enabled
		buttons[key].present_state(not _custody and enabled,selected)
		buttons[key].accessibility_description = _selected_copy if selected else ""
		if key == "flag":
			buttons[key].accessibility_name = _copy.flag + ": " + _copy[String(mode)]
			buttons[key].tooltip_text = buttons[key].accessibility_name

func _request(action: String) -> void:
	if action == "flag": action = "reveal" if mode == &"flag" else "flag"
	if not _custody and (action in _enabled or (action == "board" and _view != "board")):
		action_requested.emit(StringName(action))

func _draw() -> void:
	if theme == null: return
	draw_rect(Rect2(Vector2.ZERO,size),theme.get_color(&"controlled_face",&"Minesweeper"))
	draw_rect(Rect2(0,0,size.x,2),theme.get_color(&"dark_registration",&"Minesweeper"))

