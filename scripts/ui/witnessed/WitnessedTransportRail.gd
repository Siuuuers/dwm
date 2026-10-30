extends Control
## Presentation-only projection of the canonical witnessed-scene transport rail.
## Transport owners decide admission and perform every command.

signal skip_requested
signal auto_requested
signal load_requested
signal history_requested
signal save_requested
signal next_requested
signal settings_requested

const MATERIAL := preload("res://scripts/ui/MaterialDecoration.gd")
const TRANSPORT_BUTTON := preload("res://scripts/ui/witnessed/WitnessedTransportButton.gd")
const SETTINGS_PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")

class PaperPlate extends StyleBox:
	var base: StyleBoxFlat
	var ink: Color

	func _get_minimum_size() -> Vector2:
		return base.get_minimum_size()

	func _draw(canvas_item: RID, rect: Rect2) -> void:
		base.draw(canvas_item, rect)
		var border := maxi(maxi(base.border_width_left, base.border_width_right), maxi(base.border_width_top, base.border_width_bottom))
		MATERIAL.paper_texture().draw_rect(canvas_item, rect.grow(-PLATE_INSET - border), true, ink)

const RAIL_POSITION := Vector2(0, 592)
const RAIL_SIZE := Vector2(1280, 128)
const BAR_TOP := 612.0
const BAY_WIDTH := 1280.0 / 7.0
const CONTROL_RECTS := {
	&"history": Rect2(0, 64, BAY_WIDTH, 64), &"save": Rect2(BAY_WIDTH, 64, BAY_WIDTH, 64),
	&"load": Rect2(BAY_WIDTH * 2, 64, BAY_WIDTH, 64), &"skip": Rect2(BAY_WIDTH * 3, 64, BAY_WIDTH, 64),
	&"auto": Rect2(BAY_WIDTH * 4, 64, BAY_WIDTH, 64), &"next": Rect2(BAY_WIDTH * 5, 64, BAY_WIDTH, 64),
	&"settings": Rect2(BAY_WIDTH * 6, 64, BAY_WIDTH, 64),
}
const CONTROL_TOP: float = RAIL_POSITION.y + CONTROL_RECTS[&"history"].position.y
var ending_layout := false
const PLATE_INSET := 4.0
const CONTROL_IDS: Array[StringName] = [&"history", &"save", &"load", &"skip", &"auto", &"next", &"settings"]
const LOCALES := ["en", "zh-CN", "zh-HK", "ja", "ko"]
const COPY_IDS: Array[StringName] = [&"history", &"skip", &"auto", &"save", &"load", &"next", &"settings", &"on", &"off", &"next_help"]


var _locale := "en"
var _localization: Object
var _copy: Dictionary = {}
var _buttons: Dictionary = {}
var _skip_button: TRANSPORT_BUTTON
var _auto_button: TRANSPORT_BUTTON
var _load_button: TRANSPORT_BUTTON
var _history_button: TRANSPORT_BUTTON
var _save_button: TRANSPORT_BUTTON
var _next_button: TRANSPORT_BUTTON
var _settings_button: TRANSPORT_BUTTON
var _admission: Callable
var _auto_admission: Callable
var _load_admission: Callable
var _history_admission: Callable
var _save_admission: Callable
var _next_admission: Callable
var _settings_admission: Callable
var _input_owner: Node
var _auto_input_owner: Node
var _load_input_owner: Node
var _can_skip := false
var _can_auto := false
var _can_load := false
var _can_history := false
var _can_save := false
var _can_next := false
var _can_settings := false
var _skip_active := false
var _auto_enabled := false
var _projection_initialized := false
var _roles: Dictionary = {}
var _filed := Color.TRANSPARENT
var _material_owner: Node


func _ready() -> void:
	position = RAIL_POSITION
	size = RAIL_SIZE
	custom_minimum_size = RAIL_SIZE
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	_ensure_controls()
	_material_owner = get_node_or_null("/root/GameState")
	if _material_owner != null:
		_material_owner.inventory_changed.connect(_refresh_material)
	visibility_changed.connect(retire_input)
	_apply_projection()
	queue_redraw()


func configure_presentation(presentation_theme: Theme, locale: String, text_percent: int = 100, font_style: String = "pixel") -> bool:
	var normalized := locale.replace("_", "-")
	if presentation_theme == null or normalized not in LOCALES:
		return false
	var roles := _read_roles(presentation_theme)
	if roles.is_empty():
		return false
	var filed := _resolve_filed(roles)
	if filed.a <= 0.0:
		return false
	var next_copy := _copy
	if is_instance_valid(_localization):
		if String(_localization.call("get_locale")).replace("_", "-") != normalized:
			return false
		next_copy = _read_copy(_localization)
		if next_copy.is_empty(): return false
	if normalized != _locale or next_copy != _copy:
		retire_input()
	_copy = next_copy
	_locale = normalized
	_roles = roles
	_filed = filed
	theme = presentation_theme
	_ensure_controls()
	_apply_projection()
	queue_redraw()
	return true


func bind_localization(localization: Object) -> bool:
	if not is_instance_valid(localization): return false
	for method: StringName in [&"has_key", &"t", &"get_locale"]:
		if not localization.has_method(method): return false
	var locale := String(localization.call("get_locale")).replace("_", "-")
	if locale not in LOCALES: return false
	var next_copy := _read_copy(localization)
	if next_copy.is_empty(): return false
	# A newly bound language becomes visible only with its matching theme tuple.
	if locale != _locale: next_copy = {}
	if _localization != localization or _copy != next_copy:
		retire_input()
	_localization = localization
	_copy = next_copy
	_ensure_controls()
	_apply_projection()
	return true


func _read_copy(localization: Object) -> Dictionary:
	var result := {}
	for id: StringName in COPY_IDS:
		var key := "ui.pause.settings" if id == &"settings" else "witnessed.transport." + String(id)
		if localization.call("has_key", key) != true: return {}
		var copy: Variant = localization.call("t", key)
		if typeof(copy) != TYPE_STRING or String(copy).strip_edges().is_empty(): return {}
		result[id] = copy
	return result


func bind_admission(admission: Callable, input_owner: Node) -> bool:
	if not admission.is_valid() or not is_instance_valid(input_owner):
		return false
	_ensure_controls()
	if not _skip_button.bind_admission(admission, input_owner):
		return false
	_admission = admission
	_input_owner = input_owner
	return true


func bind_auto_admission(admission: Callable, input_owner: Node) -> bool:
	if not admission.is_valid() or not is_instance_valid(input_owner):
		return false
	_ensure_controls()
	if not _auto_button.bind_admission(admission, input_owner):
		return false
	_auto_admission = admission
	_auto_input_owner = input_owner
	return true


func bind_load_admission(admission: Callable, input_owner: Node) -> bool:
	if not admission.is_valid() or not is_instance_valid(input_owner):
		return false
	_ensure_controls()
	if not _load_button.bind_admission(admission, input_owner):
		return false
	_load_admission = admission
	_load_input_owner = input_owner
	return true


func bind_history_admission(admission: Callable, input_owner: Node) -> bool:
	if not admission.is_valid() or not is_instance_valid(input_owner): return false
	_ensure_controls()
	if not _history_button.bind_admission(admission, input_owner): return false
	_history_admission = admission
	return true


func bind_save_admission(admission: Callable, input_owner: Node) -> bool:
	if not admission.is_valid() or not is_instance_valid(input_owner): return false
	_ensure_controls()
	if not _save_button.bind_admission(admission, input_owner): return false
	_save_admission = admission
	return true


func bind_next_admission(admission: Callable, input_owner: Node) -> bool:
	if not admission.is_valid() or not is_instance_valid(input_owner): return false
	_ensure_controls()
	if not _next_button.bind_admission(admission, input_owner): return false
	_next_admission = admission
	return true


func bind_settings_admission(admission: Callable, input_owner: Node) -> bool:
	if not admission.is_valid() or not is_instance_valid(input_owner): return false
	_ensure_controls()
	if not _settings_button.bind_admission(admission, input_owner): return false
	_settings_admission = admission
	return true


func project(can_skip: bool, skip_active: bool, auto_enabled: bool, can_auto: bool = false,
		can_load: bool = false, can_history: bool = false, can_save: bool = false, can_next: bool = false, can_settings: bool = false) -> bool:
	if skip_active and auto_enabled:
		return false
	_ensure_controls()
	if _projection_initialized and can_skip == _can_skip \
			and skip_active == _skip_active and auto_enabled == _auto_enabled \
			and can_auto == _can_auto and can_load == _can_load \
			and can_history == _can_history and can_save == _can_save and can_next == _can_next and can_settings == _can_settings:
		return true
	# Every semantic state change is an input-generation boundary. If disabling
	# the focused command releases Focus, its focus_exited signal performs this
	# one retirement; otherwise retire explicitly before publishing the change.
	if not can_skip and _skip_button.has_focus():
		_skip_button.release_focus()
	else:
		_skip_button.retire_input()
	if not can_auto and _auto_button.has_focus():
		_auto_button.release_focus()
	else:
		_auto_button.retire_input()
	if not can_load and _load_button.has_focus():
		_load_button.release_focus()
	else:
		_load_button.retire_input()
	if not can_history and _history_button.has_focus():
		_history_button.release_focus()
	else:
		_history_button.retire_input()
	if not can_save and _save_button.has_focus():
		_save_button.release_focus()
	else:
		_save_button.retire_input()
	if not can_next and _next_button.has_focus():
		_next_button.release_focus()
	else:
		_next_button.retire_input()
	if not can_settings and _settings_button.has_focus():
		_settings_button.release_focus()
	else:
		_settings_button.retire_input()
	_can_settings = can_settings
	_can_next = can_next
	_can_history = can_history
	_can_save = can_save
	_can_skip = can_skip
	_can_auto = can_auto
	_can_load = can_load
	_skip_active = skip_active
	_auto_enabled = auto_enabled
	_projection_initialized = true
	_apply_projection()
	return true


func retire_input() -> void:
	if is_instance_valid(_skip_button):
		_skip_button.retire_input()
	if is_instance_valid(_auto_button):
		_auto_button.retire_input()
	if is_instance_valid(_load_button):
		_load_button.retire_input()
	if is_instance_valid(_history_button):
		_history_button.retire_input()
	if is_instance_valid(_save_button):
		_save_button.retire_input()
	if is_instance_valid(_next_button):
		_next_button.retire_input()
	if is_instance_valid(_settings_button):
		_settings_button.retire_input()


func set_ending_layout(enabled: bool) -> void:
	if ending_layout == enabled: return
	retire_input()
	ending_layout = enabled
	_ensure_controls()
	position = Vector2(0, 656) if enabled else RAIL_POSITION
	custom_minimum_size = Vector2(1280, 64) if enabled else RAIL_SIZE
	size = custom_minimum_size
	for id: StringName in CONTROL_IDS:
		var bay: Rect2 = CONTROL_RECTS[id]
		_buttons[id].position = Vector2(bay.position.x, 0) if enabled else bay.position
	queue_redraw()


func _draw() -> void:
	if not ending_layout and not _roles.is_empty():
		draw_rect(Rect2(0, CONTROL_TOP - RAIL_POSITION.y, 1280, 720 - CONTROL_TOP), _roles[&"deep"])


func _ensure_controls() -> void:
	if not _buttons.is_empty():
		return
	for index: int in CONTROL_IDS.size():
		var id := CONTROL_IDS[index]
		var button: TRANSPORT_BUTTON = TRANSPORT_BUTTON.new()
		var bay: Rect2 = CONTROL_RECTS[id]
		button.name = String(id).capitalize()
		button.position = bay.position
		button.size = bay.size
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
		button.draw.connect(_draw_button_state.bind(button))
		add_child(button)
		_buttons[id] = button
	_skip_button = _buttons[&"skip"] as TRANSPORT_BUTTON
	_auto_button = _buttons[&"auto"] as TRANSPORT_BUTTON
	_load_button = _buttons[&"load"] as TRANSPORT_BUTTON
	_history_button = _buttons[&"history"] as TRANSPORT_BUTTON
	_save_button = _buttons[&"save"] as TRANSPORT_BUTTON
	_next_button = _buttons[&"next"] as TRANSPORT_BUTTON
	_settings_button = _buttons[&"settings"] as TRANSPORT_BUTTON
	_skip_button.activated.connect(_on_skip_activated)
	_auto_button.activated.connect(_on_auto_activated)
	_load_button.activated.connect(_on_load_activated)
	_history_button.activated.connect(_on_history_activated)
	_save_button.activated.connect(_on_save_activated)
	_next_button.activated.connect(_on_next_activated)
	_settings_button.activated.connect(_on_settings_activated)


func _apply_projection() -> void:
	if _buttons.is_empty():
		return
	for id: StringName in CONTROL_IDS:
		var button: Button = _buttons[id]
		button.language = _locale
		var enabled_mode := (id == &"skip" and _skip_active) or (id == &"auto" and _auto_enabled)
		button.text = String(_copy.get(id, ""))
		button.accessibility_name = _full_label(id, enabled_mode)
		button.tooltip_text = button.accessibility_name if button.text != button.accessibility_name else ""
		if id == &"next":
			button.accessibility_description = String(_copy.get("next_help", ""))
			button.tooltip_text = button.accessibility_description
		var command_available := (id == &"skip" and _can_skip) \
			or (id == &"auto" and _can_auto) or (id == &"load" and _can_load) \
			or (id == &"history" and _can_history) or (id == &"save" and _can_save) \
			or (id == &"next" and _can_next) or (id == &"settings" and _can_settings)
		button.disabled = not command_available or _copy.is_empty() or not is_instance_valid(_localization)
		button.focus_mode = Control.FOCUS_NONE if button.disabled else Control.FOCUS_ALL
		button.theme_type_variation = &"WitnessedTransportMode" if enabled_mode else &"WitnessedTransportButton"
		if not _roles.is_empty():
			_apply_button_material(button, enabled_mode)
		# Native minimum-size updates can grow a mounted button during a theme
		# transition. Reapply its fixed bay after publishing the final material.
		button.size = button.custom_minimum_size
		button.queue_redraw()


func _full_label(id: StringName, enabled_mode: bool) -> String:
	if _copy.is_empty(): return ""
	if id in [&"skip", &"auto"]:
		return "%s \u00b7 %s" % [_copy[id], _copy[&"on"] if enabled_mode else _copy[&"off"]]
	return _copy[id]


func _apply_button_material(button: Button, mode_on: bool) -> void:
	var face: Color = _filed if mode_on else _roles[&"field"]
	var ink: Color = _roles[&"field"] if mode_on else _roles[&"text"]
	var paper_owned := is_instance_valid(_material_owner) and int(_material_owner.inventory.get("letter_with_wax_seal", 0)) > 0
	if paper_owned and not mode_on:
		face = _roles[&"text"]
		ink = _roles[&"field"]
	var state_edge: Color = ink if paper_owned else (_roles[&"field"] if mode_on else _roles[&"rule"])
	button.add_theme_stylebox_override(&"normal", _plate(face, Color.TRANSPARENT, 0))
	button.add_theme_stylebox_override(&"hover", _plate(face, state_edge, 2))
	button.add_theme_stylebox_override(&"pressed", _plate(face, state_edge, 4))
	button.add_theme_stylebox_override(&"hover_pressed", _plate(face, state_edge, 4))
	var disabled := _plate(face, state_edge, 0)
	disabled.border_width_bottom = 4
	button.add_theme_stylebox_override(&"disabled", disabled)
	button.add_theme_stylebox_override(&"focus", StyleBoxEmpty.new())
	# Measure the native shaped line, including fallback glyphs, before adding
	# padding. Font.get_height() alone can undercount that line at 150%.
	var padding := minf(8.0, floorf(maxf(0.0, button.custom_minimum_size.y - button.get_minimum_size().y) / 2.0))
	for state: StringName in [&"normal", &"hover", &"pressed", &"hover_pressed", &"disabled"]:
		var plate := button.get_theme_stylebox(state)
		plate.content_margin_top = padding
		plate.content_margin_bottom = padding
		if paper_owned:
			var paper := PaperPlate.new()
			paper.base = plate
			paper.ink = ink
			for side: int in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
				paper.set_content_margin(side, plate.get_content_margin(side))
			button.add_theme_stylebox_override(state, paper)
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
		result.set_content_margin(side, 0.0 if side in [SIDE_TOP, SIDE_BOTTOM] else 10.0)
	return result


func _refresh_material() -> void:
	_apply_projection()
	queue_redraw()


func _draw_button_state(button: TRANSPORT_BUTTON) -> void:
	if button.disabled or _roles.is_empty():
		return
	var mode_on := button.theme_type_variation == &"WitnessedTransportMode"
	if not button._candidate.is_empty():
		var edge: Color = _roles[&"field"] if mode_on else _roles[&"rule"]
		if button.get_theme_stylebox(&"normal") is PaperPlate:
			edge = button.get_theme_color(&"font_color")
		button.draw_rect(Rect2(Vector2(6, 6), button.size - Vector2(12, 12)), edge, false, 4.0)
	if not button.has_focus(): return
	var colours := [_roles[&"deep"], _roles[&"field"]] if mode_on \
		else [_roles[&"focus_outer"], _roles[&"focus_inner"]]
	if button.get_theme_stylebox(&"normal") is PaperPlate and not mode_on:
		colours[0] = _roles[&"field"]
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


func _on_auto_activated() -> void:
	if not _can_auto or not _auto_admission.is_valid() or not bool(_auto_admission.call()):
		return
	auto_requested.emit()


func _on_load_activated() -> void:
	if not _can_load or not _load_admission.is_valid() or not bool(_load_admission.call()):
		return
	load_requested.emit()


func _on_history_activated() -> void:
	if not _can_history or not _history_admission.is_valid() or not bool(_history_admission.call()):
		return
	history_requested.emit()


func _on_save_activated() -> void:
	if not _can_save or not _save_admission.is_valid() or not bool(_save_admission.call()):
		return
	save_requested.emit()


func _on_next_activated() -> void:
	if not _can_next or not _next_admission.is_valid() or not bool(_next_admission.call()):
		return
	next_requested.emit()


func _on_settings_activated() -> void:
	if not _can_settings or not _settings_admission.is_valid() or not bool(_settings_admission.call()):
		return
	settings_requested.emit()
