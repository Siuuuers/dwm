extends Control
## Presentation-only projection of the canonical witnessed-scene transport rail.
## Transport owners decide admission and perform every command.

signal skip_requested

const TRANSPORT_BUTTON := preload("res://scripts/ui/witnessed/WitnessedTransportButton.gd")
const SETTINGS_PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")

const RAIL_POSITION := Vector2(0, 656)
const RAIL_SIZE := Vector2(1280, 64)
const PLATE_INSET := 4.0
const CONTROL_IDS: Array[StringName] = [&"history", &"skip", &"auto", &"save", &"load", &"next"]
const COPY := {
	"en": {
		&"history": "History", &"skip": "Skip", &"auto": "Auto",
		&"save": "Save", &"load": "Load", &"next": "Next",
		&"on": "On", &"off": "Off",
	},
	"zh-CN": {
		&"history": "\u5386\u53f2", &"skip": "\u8df3\u8fc7", &"auto": "\u81ea\u52a8",
		&"save": "\u4fdd\u5b58", &"load": "\u8bfb\u53d6", &"next": "\u4e0b\u4e00\u6b65",
		&"on": "\u5f00", &"off": "\u5173",
	},
	"zh-HK": {
		&"history": "\u6b77\u53f2", &"skip": "\u8df3\u904e", &"auto": "\u81ea\u52d5",
		&"save": "\u5132\u5b58", &"load": "\u8f09\u5165", &"next": "\u4e0b\u4e00\u6b65",
		&"on": "\u958b", &"off": "\u95dc",
	},
}

var _locale := "en"
var _buttons: Dictionary = {}
var _skip_button: TRANSPORT_BUTTON
var _admission: Callable
var _input_owner: Node
var _can_skip := false
var _skip_active := false
var _auto_enabled := false
var _projection_initialized := false
var _roles: Dictionary = {}
var _filed := Color.TRANSPARENT


func _ready() -> void:
	position = RAIL_POSITION
	size = RAIL_SIZE
	custom_minimum_size = RAIL_SIZE
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	_ensure_controls()
	visibility_changed.connect(retire_input)
	_apply_projection()
	queue_redraw()


func configure_presentation(presentation_theme: Theme, locale: String) -> bool:
	var normalized := locale.replace("_", "-")
	if presentation_theme == null or normalized not in COPY:
		return false
	var roles := _read_roles(presentation_theme)
	if roles.is_empty():
		return false
	var filed := _resolve_filed(roles)
	if filed.a <= 0.0:
		return false
	_locale = normalized
	_roles = roles
	_filed = filed
	theme = presentation_theme
	_ensure_controls()
	_apply_projection()
	queue_redraw()
	return true


func bind_admission(admission: Callable, input_owner: Node) -> bool:
	if not admission.is_valid() or not is_instance_valid(input_owner):
		return false
	_ensure_controls()
	if not _skip_button.bind_admission(admission, input_owner):
		return false
	_admission = admission
	_input_owner = input_owner
	return true


func project(can_skip: bool, skip_active: bool, auto_enabled: bool) -> bool:
	if skip_active and auto_enabled:
		return false
	_ensure_controls()
	if _projection_initialized and can_skip == _can_skip \
			and skip_active == _skip_active and auto_enabled == _auto_enabled:
		return true
	# Every semantic state change is an input-generation boundary. If disabling
	# the focused command releases Focus, its focus_exited signal performs this
	# one retirement; otherwise retire explicitly before publishing the change.
	if not can_skip and _skip_button.has_focus():
		_skip_button.release_focus()
	else:
		_skip_button.retire_input()
	_can_skip = can_skip
	_skip_active = skip_active
	_auto_enabled = auto_enabled
	_projection_initialized = true
	_apply_projection()
	return true


func retire_input() -> void:
	if is_instance_valid(_skip_button):
		_skip_button.retire_input()


func _draw() -> void:
	if not _roles.is_empty():
		draw_rect(Rect2(Vector2.ZERO, RAIL_SIZE), _roles[&"deep"])


func _ensure_controls() -> void:
	if not _buttons.is_empty():
		return
	for index: int in CONTROL_IDS.size():
		var id := CONTROL_IDS[index]
		var button: TRANSPORT_BUTTON = TRANSPORT_BUTTON.new()
		var left := floori(640.0 * index / 6.0) * 2
		var right := floori(640.0 * (index + 1) / 6.0) * 2
		button.name = String(id).capitalize()
		button.position = Vector2(left, 0)
		button.size = Vector2(right - left, 64)
		button.custom_minimum_size = button.size
		button.focus_mode = Control.FOCUS_NONE
		button.mouse_default_cursor_shape = Control.CURSOR_ARROW
		button.alignment = HORIZONTAL_ALIGNMENT_CENTER
		button.text_direction = Control.TEXT_DIRECTION_AUTO
		button.language = _locale
		button.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
		button.text_overrun_behavior = TextServer.OVERRUN_NO_TRIMMING
		button.clip_text = false
		button.toggle_mode = false
		button.disabled = true
		button.focus_entered.connect(button.queue_redraw)
		button.focus_exited.connect(button.queue_redraw)
		button.draw.connect(_draw_button_focus.bind(button))
		add_child(button)
		_buttons[id] = button
	_skip_button = _buttons[&"skip"] as TRANSPORT_BUTTON
	_skip_button.activated.connect(_on_skip_activated)


func _apply_projection() -> void:
	if _buttons.is_empty():
		return
	for id: StringName in CONTROL_IDS:
		var button: Button = _buttons[id]
		button.language = _locale
		var enabled_mode := (id == &"skip" and _skip_active) or (id == &"auto" and _auto_enabled)
		button.text = _label(id, enabled_mode)
		button.disabled = id != &"skip" or not _can_skip
		button.focus_mode = Control.FOCUS_ALL if id == &"skip" and _can_skip else Control.FOCUS_NONE
		button.theme_type_variation = &"WitnessedTransportMode" if enabled_mode else &"WitnessedTransportButton"
		if not _roles.is_empty():
			_apply_button_material(button, enabled_mode)
		button.queue_redraw()


func _label(id: StringName, enabled_mode: bool) -> String:
	var copy: Dictionary = COPY[_locale]
	if id in [&"skip", &"auto"]:
		return "%s \u00b7 %s" % [copy[id], copy[&"on"] if enabled_mode else copy[&"off"]]
	return copy[id]


func _apply_button_material(button: Button, mode_on: bool) -> void:
	var face: Color = _filed if mode_on else _roles[&"field"]
	var ink: Color = _roles[&"field"] if mode_on else _roles[&"text"]
	var state_edge: Color = _roles[&"field"] if mode_on else _roles[&"rule"]
	button.add_theme_stylebox_override(&"normal", _plate(face, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override(&"hover", _plate(face, state_edge, 2))
	button.add_theme_stylebox_override(&"pressed", _plate(face, state_edge, 4))
	button.add_theme_stylebox_override(&"hover_pressed", _plate(face, state_edge, 4))
	button.add_theme_stylebox_override(&"disabled", _plate(face, state_edge, 4))
	button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	for state: StringName in [
		&"font_color", &"font_hover_color", &"font_pressed_color",
		&"font_hover_pressed_color", &"font_focus_color", &"font_disabled_color",
	]:
		button.add_theme_color_override(state, ink)
	button.add_theme_color_override(&"font_outline_color", Color.TRANSPARENT)
	button.add_theme_constant_override(&"outline_size", 0)


func _plate(fill: Color, edge: Color, edge_width: int) -> StyleBoxFlat:
	var result := StyleBoxFlat.new()
	result.bg_color = fill
	result.border_color = edge
	result.set_border_width_all(edge_width)
	for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		result.set_expand_margin(side, -PLATE_INSET)
		result.set_content_margin(side, 10.0)
	return result


func _draw_button_focus(button: Button) -> void:
	if button.disabled or not button.has_focus() or _roles.is_empty():
		return
	var mode_on := button.theme_type_variation == &"WitnessedTransportMode"
	var colours := [_roles[&"deep"], _roles[&"field"]] if mode_on \
		else [_roles[&"focus_outer"], _roles[&"focus_inner"]]
	var frames := _focus_rects(button.size)
	button.draw_rect(frames[0], colours[0], false, 2.0)
	button.draw_rect(frames[1], colours[1], false, 2.0)


func _focus_rects(control_size: Vector2) -> Array[Rect2]:
	# A two-pixel stroke centered at 5 begins exactly at the four-pixel plate
	# inset. The next stroke begins after one untouched two-pixel gap.
	return [
		Rect2(Vector2(5, 5), control_size - Vector2(10, 10)),
		Rect2(Vector2(9, 9), control_size - Vector2(18, 18)),
	]


func _read_roles(presentation_theme: Theme) -> Dictionary:
	var result := {}
	for role: StringName in [&"field", &"deep", &"text", &"rule", &"focus_outer", &"focus_inner"]:
		if not presentation_theme.has_color(role, &"WitnessedCaption"):
			return {}
		result[role] = presentation_theme.get_color(role, &"WitnessedCaption")
	return result


func _resolve_filed(roles: Dictionary) -> Color:
	for value: Variant in SETTINGS_PALETTES.TUPLES.values():
		if value is Dictionary and value.get("ink") == roles[&"text"] \
				and value.get("focus") == roles[&"focus_inner"]:
			return value.get("filed", Color.TRANSPARENT)
	return Color.TRANSPARENT


func _on_skip_activated() -> void:
	if not _can_skip or not _admission.is_valid() or not bool(_admission.call()):
		return
	skip_requested.emit()
