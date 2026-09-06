extends DialogicLayoutLayer
## Transient public caption copies, not canonical History, receipts, or restore ownership.

const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const FIELD_TOP := {100: 448, 125: 392, 150: 328}
const FIELD_BOTTOM := 656
const PROFILE_COLOUR_PRESETS := {
	"none": "standard", "protanopia": "protan", "deuteranopia": "deutan", "tritanopia": "tritan",
}

var _locale := "en"
var _text_percent := 100
var _palette := "AfterHours"
var _high_contrast := false
var _colour_preset := "standard"
var _large_targets := false
var _caption_theme: Theme
var _last_text := ""
var _last_content_height := -1
var _had_caption := false
var _profile: Node
var _localization: Node
var _retained: Array[String] = []
var _current_copy := ""
var _layout_generation := 0
var _layout_pending := false
var _publication_pending := false
var _scroll_restore_waiting := false
var _scroll_restore_value := 0.0
var _scroll_restore_retries := 0

@onready var canvas: Control = $Canvas
@onready var scroll: ScrollContainer = $Canvas/Scroll
@onready var stack: Control = $Canvas/Scroll/Stack
@onready var caption_text: DialogicNode_DialogText = $Canvas/Scroll/Stack/Caption
@onready var older: RichTextLabel = $Canvas/Scroll/Stack/Older
@onready var previous: RichTextLabel = $Canvas/Scroll/Stack/Previous
@onready var overlay: Control = $Canvas/Overlay
@onready var accept_input: Node = $AcceptInput

func _ready() -> void:
	super._ready()
	if caption_text.gui_input.is_connected(caption_text.on_gui_input):
		caption_text.gui_input.disconnect(caption_text.on_gui_input)
	caption_text.gui_input.connect(_on_caption_input)
	caption_text.visibility_changed.connect(_on_caption_visibility_changed)
	caption_text.started_revealing_text.connect(_sync_native_processing)
	caption_text.focus_entered.connect(caption_text.queue_redraw)
	caption_text.focus_exited.connect(caption_text.queue_redraw)
	caption_text.draw.connect(_draw_current_frame)
	scroll.gui_input.connect(_on_passive_input)
	stack.gui_input.connect(_on_passive_input)
	canvas.draw.connect(_draw_canvas)
	overlay.draw.connect(_draw_seam)
	get_scroll_bar().focus_mode = Control.FOCUS_NONE
	configure_presentation(_locale, _text_percent, _palette, _high_contrast, _colour_preset, _large_targets)
	_profile = get_node_or_null("/root/ProfileManager")
	_localization = get_node_or_null("/root/LocalizationManager")
	if _profile != null and _profile.has_signal("preference_changed"):
		_profile.connect("preference_changed", _on_preference_changed)
	if _localization != null and _localization.has_signal("locale_changed"):
		_localization.connect("locale_changed", _on_locale_changed)
	_apply_preferences()
	var runtime := get_node_or_null("/root/Dialogic")
	accept_input.bind(caption_text, scroll, runtime)
	if runtime != null and runtime.has_method("get_subsystem"):
		var text_owner: Object = runtime.call("get_subsystem", "Text")
		if text_owner != null:
			text_owner.connect("about_to_show_text", _on_about_to_show_text)
			text_owner.connect("text_started", _on_text_started)
		if runtime.has_signal("timeline_started"):
			runtime.connect("timeline_started", reset_caption_stack)

func configure_presentation(locale: String = "en", text_percent: int = 100, palette: String = "AfterHours", high_contrast: bool = false, colour_preset: String = "standard", large_targets: bool = false) -> bool:
	var next_theme := CAPTION_THEME.build(locale, text_percent, palette, high_contrast, colour_preset, large_targets)
	if next_theme == null:
		return false
	var metrics_changed := _caption_theme == null or _locale != locale.replace("_", "-") or _text_percent != text_percent or _large_targets != large_targets
	_locale = locale.replace("_", "-")
	_text_percent = text_percent
	_palette = palette
	_high_contrast = high_contrast
	_colour_preset = colour_preset
	_large_targets = large_targets
	_caption_theme = next_theme
	if is_instance_valid(canvas):
		var first_mount := canvas.theme == null
		if metrics_changed:
			var bar := get_scroll_bar()
			if bar.visible:
				# Native ScrollBar retires its held drag on hide. Restore visibility
				# synchronously before layout, keeping its value and focus owner.
				bar.hide()
				bar.show()
		canvas.theme = next_theme
		# Colour-only updates preserve native reveal, scroll and pending contacts.
		if metrics_changed or first_mount:
			accept_input.cancel_pending_accept()
			_layout_stack()
		canvas.queue_redraw()
		overlay.queue_redraw()
		caption_text.queue_redraw()
	return true

func reset_caption_stack() -> void:
	_retained.clear()
	_current_copy = ""
	_publication_pending = false
	if is_instance_valid(stack):
		_layout_stack()

func reproject_retained_captions(captions: Array) -> bool:
	if captions.size() > 2:
		return false
	for copy: Variant in captions:
		if typeof(copy) != TYPE_STRING or String(copy).strip_edges().is_empty():
			return false
	_retained.assign(captions)
	if is_instance_valid(stack):
		_current_copy = caption_text.get_parsed_text()
		_layout_stack()
	return true

func get_scroll_bar() -> VScrollBar:
	return scroll.get_v_scroll_bar() if is_instance_valid(scroll) else null

func get_caption_projection() -> Dictionary:
	var mounted := is_instance_valid(caption_text)
	var bar := get_scroll_bar()
	var leaves: Array[Rect2] = []
	var visible_leaves: Array[Rect2] = []
	if mounted:
		for leaf: RichTextLabel in [older, previous, caption_text]:
			if not leaf.visible or leaf.get_parsed_text().is_empty():
				continue
			var rect := _leaf_rect(leaf)
			leaves.append(rect)
			var visible_rect := rect.intersection(_field_rect())
			if visible_rect.has_area():
				visible_leaves.append(visible_rect)
	var current_rect := _leaf_rect(caption_text) if mounted else Rect2()
	return {
		"locale": _locale, "text_percent": _text_percent, "palette": _palette,
		"high_contrast": _high_contrast, "colour_preset": _colour_preset,
		"large_targets": _large_targets,
		"font_size": int(20 * _text_percent / 100.0),
		"text": caption_text.get_parsed_text() if mounted else "",
		"visible_characters": caption_text.visible_characters if mounted else 0,
		"total_characters": caption_text.get_total_character_count() if mounted else 0,
		"revealing": caption_text.revealing and _has_caption() if mounted else false,
		"caption_visible": _has_caption() if mounted else false,
		"field_rect": _field_rect(), "caption_rect": current_rect,
		"caption_visible_rect": current_rect.intersection(_field_rect()) if mounted and _has_caption() else Rect2(),
		"retained_captions": _retained.duplicate(), "leaf_rects": leaves,
		"visible_leaf_rects": visible_leaves,
		"scroll_offset": bar.value if bar != null else 0.0,
		"scroll_extent": maxf(0.0, bar.max_value - bar.page) if bar != null else 0.0,
	}

func _on_about_to_show_text(_info: Dictionary) -> void:
	# Runs before replacement, catching a clear even when its native node was already hidden.
	if caption_text.get_parsed_text().is_empty():
		reset_caption_stack()

func _on_text_started(info: Dictionary) -> void:
	if not _has_caption():
		return
	if not bool(info.get("append", false)) and not _current_copy.is_empty():
		_retained.append(_current_copy)
		if _retained.size() > 2:
			_retained.pop_front()
	# Only already-parsed display text crosses this seam; never character/portrait data.
	_current_copy = caption_text.get_parsed_text()
	_layout_stack(true)

func _on_caption_visibility_changed() -> void:
	_sync_native_processing()
	if caption_text.get_parsed_text().is_empty():
		_retained.clear()
		_current_copy = ""
		_publication_pending = false
		older.hide()
		previous.hide()
	_sync_focus()
	_request_layout()

func _sync_native_processing() -> void:
	if caption_text.get_parsed_text().is_empty():
		# Native empty clears can leave revealing true; cancellation must emit no finish.
		caption_text.revealing = false
		caption_text.visible_characters = -1
		caption_text.set_process(false)
		if not _retained.is_empty() or not _current_copy.is_empty():
			_retained.clear()
			_current_copy = ""
			_publication_pending = false
			older.hide()
			previous.hide()
			_request_layout()
	else:
		# Hidden real text pauses without discarding its native reveal position.
		caption_text.set_process(caption_text.is_visible_in_tree())

func _apply_preferences() -> void:
	var locale := str(_localization.call("get_locale")) if _localization != null and _localization.has_method("get_locale") else _locale
	var scale_value: Variant = _profile.call("get_preference", &"preferences.accessibility.font_scale", 1.0) if _profile != null and _profile.has_method("get_preference") else _text_percent / 100.0
	if typeof(scale_value) not in [TYPE_INT, TYPE_FLOAT] or scale_value not in [1.0, 1.25, 1.5]:
		return
	var high_contrast: Variant = _high_contrast
	var large_targets: Variant = _large_targets
	var colour_preset := _colour_preset
	if _profile != null and _profile.has_method("get_preference"):
		high_contrast = _profile.call("get_preference", &"preferences.accessibility.high_contrast", false)
		large_targets = _profile.call("get_preference", &"preferences.accessibility.large_click_targets", false)
		var colour_mode: Variant = _profile.call("get_preference", &"preferences.accessibility.colorblind_mode", "none")
		if typeof(colour_mode) != TYPE_STRING or not PROFILE_COLOUR_PRESETS.has(colour_mode):
			return
		colour_preset = PROFILE_COLOUR_PRESETS[colour_mode]
	if typeof(high_contrast) != TYPE_BOOL or typeof(large_targets) != TYPE_BOOL:
		return
	configure_presentation(locale, int(float(scale_value) * 100), _palette, high_contrast, colour_preset, large_targets)

func _on_locale_changed(_locale_id: String) -> void:
	_apply_preferences()

func _on_preference_changed(path: StringName, _value: Variant) -> void:
	if path in [&"preferences.accessibility.font_scale", &"preferences.accessibility.high_contrast", &"preferences.accessibility.colorblind_mode", &"preferences.accessibility.large_click_targets"]:
		_apply_preferences()

func _process(_delta: float) -> void:
	if _caption_theme == null:
		return
	_sync_native_processing()
	if _scroll_restore_waiting:
		_scroll_restore_waiting = false
		_restore_scroll(_layout_generation, _scroll_restore_value, _publication_pending)
	if caption_text.text != _last_text or caption_text.get_content_height() != _last_content_height:
		_request_layout()
	_sync_focus()

func _request_layout() -> void:
	if _layout_pending:
		return
	_layout_pending = true
	call_deferred("_settle_layout")

func _settle_layout() -> void:
	_layout_pending = false
	_layout_stack()

func _layout_stack(publication: bool = false) -> void:
	if not is_instance_valid(stack) or _caption_theme == null:
		return
	_publication_pending = _publication_pending or publication
	var retained_scroll := get_scroll_bar().value
	scroll.position = Vector2(16, FIELD_TOP[_text_percent])
	scroll.size = Vector2(1248, FIELD_BOTTOM - FIELD_TOP[_text_percent])
	older.text = _retained[0] if _retained.size() == 2 else ""
	previous.text = _retained.back() if not _retained.is_empty() else ""
	older.visible = _has_caption() and _retained.size() == 2
	previous.visible = _has_caption() and not _retained.is_empty()
	var leaves: Array[RichTextLabel] = []
	for leaf: RichTextLabel in [older, previous, caption_text]:
		if leaf.visible and not leaf.get_parsed_text().is_empty():
			leaves.append(leaf)
	var width := 1248.0
	var total := _measure_leaves(leaves, width)
	if total > scroll.size.y:
		width -= get_scroll_bar().get_combined_minimum_size().x
		total = _measure_leaves(leaves, width)
	var cursor := maxf(0, scroll.size.y - total)
	for leaf: RichTextLabel in leaves:
		leaf.position = Vector2(0, cursor)
		cursor += leaf.size.y
	stack.custom_minimum_size = Vector2(0, maxf(scroll.size.y, total))
	stack.update_minimum_size()
	stack.size = Vector2(width, maxf(scroll.size.y, total))
	_last_text = caption_text.text
	_last_content_height = caption_text.get_content_height()
	_sync_focus()
	_layout_generation += 1
	_scroll_restore_waiting = false
	_scroll_restore_retries = 3
	call_deferred("_restore_scroll", _layout_generation, retained_scroll, publication)

func _measure_leaves(leaves: Array[RichTextLabel], width: float) -> float:
	var total := 0.0
	for leaf: RichTextLabel in leaves:
		leaf.size.x = width
		var minimum := 64 if _large_targets and leaf == caption_text else 52
		var height := maxi(minimum, int(ceil((leaf.get_content_height() + 32) / 2.0)) * 2)
		leaf.update_minimum_size()
		leaf.size = Vector2(width, height)
		total += leaf.size.y
	return total

func _restore_scroll(generation: int, value: float, publication: bool) -> void:
	if generation != _layout_generation:
		return
	var bar := get_scroll_bar()
	var expected_extent := maxf(0, stack.size.y - scroll.size.y)
	if not is_equal_approx(maxf(0, bar.max_value - bar.page), expected_extent):
		# Container range updates can follow this deferred callback. Keep publication
		# intent until a later frame sees the real range; never spin in deferred calls.
		if _scroll_restore_retries > 0:
			_scroll_restore_retries -= 1
			_scroll_restore_value = value
			_scroll_restore_waiting = true
		return
	if (publication or _publication_pending) and _has_caption():
		var top := caption_text.position.y
		var bottom := top + caption_text.size.y
		if caption_text.size.y > scroll.size.y or top < value:
			value = top
		elif bottom > value + scroll.size.y:
			value = bottom - scroll.size.y
	bar.value = clampf(value, 0, maxf(0, stack.size.y - scroll.size.y))
	_publication_pending = false

func _has_caption() -> bool:
	return caption_text.visible and not caption_text.get_parsed_text().is_empty()

func _sync_focus() -> void:
	var has_caption := _has_caption()
	caption_text.focus_mode = Control.FOCUS_ALL if has_caption else Control.FOCUS_NONE
	caption_text.mouse_filter = Control.MOUSE_FILTER_STOP if has_caption else Control.MOUSE_FILTER_IGNORE
	if has_caption and not _had_caption:
		caption_text.grab_focus()
	_had_caption = has_caption
	if not has_caption and caption_text.has_focus():
		caption_text.release_focus()

func _on_passive_input(event: InputEvent) -> void:
	_handle_input(event, false)

func _on_caption_input(event: InputEvent) -> void:
	_handle_input(event, true)

func _handle_input(event: InputEvent, current: bool) -> void:
	if event is InputEventMouse and event.device == InputEvent.DEVICE_ID_EMULATION:
		scroll.accept_event()
		return
	var bar := get_scroll_bar()
	if current and accept_input.handle_page_input(event):
		scroll.accept_event()
		return
	elif event is InputEventMouseButton:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			accept_input.cancel_pending_accept()
			var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			bar.value += direction * _caption_theme.default_font_size * 3.0 * event.factor
		elif current and event.button_index == MOUSE_BUTTON_LEFT:
			accept_input.handle_caption_gui_input(event)
	elif event is InputEventPanGesture:
		accept_input.cancel_pending_accept()
		bar.value += event.delta.y * 20
	elif event is InputEventScreenTouch:
		if current:
			accept_input.handle_caption_gui_input(event)
	elif event is InputEventScreenDrag:
		if event.device != InputEvent.DEVICE_ID_EMULATION:
			accept_input.cancel_pending_accept()
			bar.value -= event.relative.y
	else:
		return
	scroll.accept_event()

func _field_rect() -> Rect2:
	return Rect2(0, FIELD_TOP[_text_percent], 1280, FIELD_BOTTOM - FIELD_TOP[_text_percent])

func _leaf_rect(leaf: RichTextLabel) -> Rect2:
	return Rect2(scroll.position + stack.position + leaf.position, leaf.size)

func _draw_canvas() -> void:
	if _caption_theme == null:
		return
	canvas.draw_rect(_field_rect(), _color(&"field"))
	canvas.draw_rect(Rect2(0, FIELD_BOTTOM, 1280, 64), _color(&"deep"))

func _draw_seam() -> void:
	if _caption_theme != null:
		overlay.draw_rect(Rect2(0, FIELD_TOP[_text_percent], 1280, 2), _color(&"rule"))

func _draw_current_frame() -> void:
	if _caption_theme == null:
		return
	var frame_size := caption_text.size
	# These rails and protected padding belong to the full leaf and scroll with it.
	caption_text.draw_rect(Rect2(0, 2, frame_size.x, 14), _color(&"current"))
	caption_text.draw_rect(Rect2(0, frame_size.y - 16, frame_size.x, 16), _color(&"current"))
	caption_text.draw_rect(Rect2(0, 2, 16, frame_size.y - 2), _color(&"current"))
	caption_text.draw_rect(Rect2(frame_size.x - 16, 2, 16, frame_size.y - 2), _color(&"current"))
	caption_text.draw_rect(Rect2(0, 0, frame_size.x, 2), _color(&"rule"))
	if caption_text.has_focus():
		caption_text.draw_rect(Rect2(Vector2(3, 3), frame_size - Vector2(6, 6)), _color(&"focus_outer"), false, 2)
		caption_text.draw_rect(Rect2(Vector2(7, 7), frame_size - Vector2(14, 14)), _color(&"focus_inner"), false, 2)

func _color(role: StringName) -> Color:
	return _caption_theme.get_color(role, &"WitnessedCaption")
