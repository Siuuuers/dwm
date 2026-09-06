extends DialogicLayoutLayer
## One live native Dialogic caption. Semantic memory and transport stay with their owners.

const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const FIELD_TOP := {100: 448, 125: 392, 150: 328}
const FIELD_BOTTOM := 656

var _locale := "en"
var _text_percent := 100
var _palette := "AfterHours"
var _caption_theme: Theme
var _last_text := ""
var _last_content_height := -1
var _had_caption := false
var _profile: Node
var _localization: Node

@onready var canvas: Control = $Canvas
@onready var caption_text: DialogicNode_DialogText = $Canvas/Caption

func _ready() -> void:
	super._ready()
	# Intercept scroll before forwarding ordinary mouse acceptance to the installed node.
	if caption_text.gui_input.is_connected(caption_text.on_gui_input):
		caption_text.gui_input.disconnect(caption_text.on_gui_input)
	caption_text.gui_input.connect(_on_caption_input)
	caption_text.visibility_changed.connect(_sync_focus)
	caption_text.focus_entered.connect(caption_text.queue_redraw)
	caption_text.focus_exited.connect(caption_text.queue_redraw)
	canvas.draw.connect(_draw_canvas)
	caption_text.draw.connect(_draw_focus)
	caption_text.get_v_scroll_bar().focus_mode = Control.FOCUS_NONE
	configure_presentation(_locale, _text_percent, _palette)
	_profile = get_node_or_null("/root/ProfileManager")
	_localization = get_node_or_null("/root/LocalizationManager")
	if _profile != null and _profile.has_signal("preference_changed"):
		_profile.connect("preference_changed", _on_preference_changed)
	if _localization != null and _localization.has_signal("locale_changed"):
		_localization.connect("locale_changed", _on_locale_changed)
	_apply_preferences()

func configure_presentation(locale: String = "en", text_percent: int = 100, palette: String = "AfterHours") -> bool:
	var next_theme := CAPTION_THEME.build(locale, text_percent, palette)
	if next_theme == null:
		return false
	_locale = locale.replace("_", "-")
	_text_percent = text_percent
	_palette = palette
	_caption_theme = next_theme
	if is_instance_valid(canvas):
		canvas.theme = next_theme
		_last_content_height = -1
		_layout_caption()
		canvas.queue_redraw()
	return true

func get_caption_projection() -> Dictionary:
	var mounted := is_instance_valid(caption_text)
	var bar: VScrollBar = caption_text.get_v_scroll_bar() if mounted else null
	return {
		"locale": _locale, "text_percent": _text_percent, "palette": _palette,
		"font_size": int(20 * _text_percent / 100.0),
		"text": caption_text.get_parsed_text() if mounted else "",
		"visible_characters": caption_text.visible_characters if mounted else 0,
		"total_characters": caption_text.get_total_character_count() if mounted else 0,
		"revealing": caption_text.revealing and caption_text.visible and not caption_text.get_parsed_text().is_empty() if mounted else false,
		"caption_visible": caption_text.visible if mounted else false,
		"field_rect": Rect2(0, FIELD_TOP[_text_percent], 1280, FIELD_BOTTOM - FIELD_TOP[_text_percent]),
		"caption_rect": caption_text.get_rect() if mounted else Rect2(),
		"scroll_offset": bar.value if mounted else 0.0,
		"scroll_extent": maxf(0.0, bar.max_value - bar.page) if mounted else 0.0,
	}

func _apply_preferences() -> void:
	var locale := str(_localization.call("get_locale")) if _localization != null and _localization.has_method("get_locale") else _locale
	var scale_value: Variant = _profile.call("get_preference", &"preferences.accessibility.font_scale", 1.0) if _profile != null and _profile.has_method("get_preference") else _text_percent / 100.0
	if typeof(scale_value) not in [TYPE_INT, TYPE_FLOAT] or scale_value not in [1.0, 1.25, 1.5]:
		return
	configure_presentation(locale, int(float(scale_value) * 100), _palette)

func _on_locale_changed(_locale_id: String) -> void:
	_apply_preferences()

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path == &"preferences.accessibility.font_scale":
		_apply_preferences()

func _input(event: InputEvent) -> void:
	# Consume page navigation before RichTextLabel or Dialogic can also interpret it.
	if caption_text.has_focus() and event is InputEventKey and event.pressed \
			and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		_on_caption_input(event)
		get_viewport().set_input_as_handled()

func _process(_delta: float) -> void:
	if _caption_theme == null:
		return
	var content_height := caption_text.get_content_height()
	if caption_text.text != _last_text or content_height != _last_content_height:
		_layout_caption()
	_sync_focus()

func _layout_caption() -> void:
	if not is_instance_valid(caption_text):
		return
	var changed := caption_text.text != _last_text
	_last_text = caption_text.text
	var maximum_height: int = FIELD_BOTTOM - FIELD_TOP[_text_percent]
	# Full text is shaped before reveal; the owning label never changes its font to fit.
	caption_text.size = Vector2(1248, maximum_height)
	var content_height := caption_text.get_content_height()
	var measured_height := int(ceil((content_height + 32) / 2.0)) * 2
	var leaf_height := mini(maximum_height, maxi(52, measured_height))
	caption_text.position = Vector2(16, FIELD_BOTTOM - leaf_height)
	caption_text.size = Vector2(1248, leaf_height)
	_last_content_height = caption_text.get_content_height()
	if changed:
		caption_text.get_v_scroll_bar().value = 0
	_sync_focus()
	caption_text.queue_redraw()

func _sync_focus() -> void:
	var has_caption := caption_text.visible and not caption_text.get_parsed_text().is_empty()
	caption_text.focus_mode = Control.FOCUS_ALL if has_caption else Control.FOCUS_NONE
	caption_text.mouse_filter = Control.MOUSE_FILTER_STOP if has_caption else Control.MOUSE_FILTER_IGNORE
	if has_caption and not _had_caption:
		caption_text.grab_focus()
	_had_caption = has_caption
	if not has_caption and caption_text.has_focus():
		caption_text.release_focus()

func _on_caption_input(event: InputEvent) -> void:
	# A touch press generates an emulated mouse press before its eventual drag.
	# It must never reach native narrative acceptance while the gesture is undecided.
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		caption_text.accept_event()
		return
	var bar := caption_text.get_v_scroll_bar()
	if event is InputEventKey and event.pressed and event.keycode in [KEY_PAGEUP, KEY_PAGEDOWN]:
		bar.value += bar.page * (-1 if event.keycode == KEY_PAGEUP else 1)
		caption_text.accept_event()
	elif event is InputEventMouseButton and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN, MOUSE_BUTTON_WHEEL_LEFT, MOUSE_BUTTON_WHEEL_RIGHT]:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			bar.value += direction * _caption_theme.default_font_size * 3.0 * event.factor
		# Control emits gui_input before its native handler. Consume here to prevent a second scroll.
		caption_text.accept_event()
	elif event is InputEventPanGesture:
		bar.value += event.delta.y * 20
		caption_text.accept_event()
	elif event is InputEventScreenTouch:
		if event.pressed and event.device != InputEvent.DEVICE_ID_EMULATION:
			caption_text.grab_focus()
		caption_text.accept_event()
	elif event is InputEventScreenDrag:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			bar.value -= event.relative.y
		caption_text.accept_event()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			caption_text.grab_focus()
		caption_text.on_gui_input(event)
		caption_text.accept_event()

func _draw_canvas() -> void:
	if _caption_theme == null:
		return
	var top: int = FIELD_TOP[_text_percent]
	canvas.draw_rect(Rect2(0, top, 1280, FIELD_BOTTOM - top), _color(&"field"))
	canvas.draw_rect(Rect2(0, top, 1280, 2), _color(&"rule"))
	canvas.draw_rect(Rect2(0, FIELD_BOTTOM, 1280, 64), _color(&"deep"))

func _draw_focus() -> void:
	if _caption_theme == null:
		return
	var bar := caption_text.get_v_scroll_bar()
	var gutter_width := bar.size.x if bar.visible else 0.0
	var frame_size := caption_text.size - Vector2(gutter_width, 0)
	# Native scrolling clips to the whole label, including its style padding. Cover
	# that padding after text drawing so clipped glyphs cannot enter the seam or Focus.
	caption_text.draw_rect(Rect2(0, 2, frame_size.x, 14), _color(&"current"))
	caption_text.draw_rect(Rect2(0, frame_size.y - 16, frame_size.x, 16), _color(&"current"))
	caption_text.draw_rect(Rect2(0, 2, 16, frame_size.y - 2), _color(&"current"))
	caption_text.draw_rect(Rect2(frame_size.x - 16, 2, 16, frame_size.y - 2), _color(&"current"))
	caption_text.draw_rect(Rect2(0, 0, frame_size.x, 2), _color(&"rule"))
	if gutter_width > 0:
		# Its native child draws the track and thumb later, clear of the leaf's rails.
		caption_text.draw_rect(Rect2(frame_size.x, 0, gutter_width, frame_size.y), _color(&"deep"))
	if not caption_text.has_focus():
		return
	# Centered 2-logical strokes: perimeter row, Bone, Plum gap, Gold, then ink padding.
	caption_text.draw_rect(Rect2(Vector2(3, 3), frame_size - Vector2(6, 6)), _color(&"focus_outer"), false, 2)
	caption_text.draw_rect(Rect2(Vector2(7, 7), frame_size - Vector2(14, 14)), _color(&"focus_inner"), false, 2)

func _color(role: StringName) -> Color:
	return _caption_theme.get_color(role, &"WitnessedCaption")
