extends Control
class_name GalleryRecordPaper
## One clipped written record; its owner retains selection, actions, and replay.

signal presentation_changed
signal focus_target_removed(hide_focus: bool)

const VIEW_SIZE := Vector2(520, 512)
const COPY := {"en": "Record details", "zh-CN": "记录详情", "zh-HK": "記錄詳情", "ja": "記録の詳細", "ko": "기록 상세"}

class RecordMedia extends Node2D:
	# Paint only: no hit area, focus, image control, or assistive target.
	var texture: Texture2D
	var ink := Color.BLACK
	func _draw() -> void:
		if texture == null: return
		draw_rect(Rect2(1, 1, 518, 158), ink, false, 2)
		draw_texture_rect(texture, Rect2(2, 2, 516, 156), false)

var title_label: Label
var sentence_label: Label
var content_extent := 0.0
var scroll_offset := 0.0
var _locale := "en"
var _interactive := true
var _body: Control
var _pointer: Control
var _selector: Control
var _practice: Control
var _register: Control
var _repeat: Timer
var _stick_direction := 0
var _visual_focus := false
var _media: RecordMedia

func _init() -> void:
	custom_minimum_size = VIEW_SIZE
	size = VIEW_SIZE
	clip_contents = true
	focus_mode = Control.FOCUS_NONE
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	# Separate pointer custody from semantic focus, so a touch drag never steals it.
	_pointer = Control.new()
	_pointer.name = "PaperPointer"
	_pointer.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	_pointer.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_pointer.focus_mode = Control.FOCUS_NONE
	_pointer.gui_input.connect(_gui_input)
	add_child(_pointer)
	_body = Control.new()
	_body.name = "RecordBody"
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.focus_mode = Control.FOCUS_NONE
	_pointer.add_child(_body)
	_media = RecordMedia.new()
	_media.name = "RecordMedia"
	_media.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	_body.add_child(_media)
	title_label = _make_label("RecordTitle")
	sentence_label = _make_label("RecordSentence")
	_repeat = Timer.new()
	_repeat.one_shot = true
	_repeat.timeout.connect(_repeat_stick)
	add_child(_repeat)
	focus_entered.connect(_focus_changed)
	focus_exited.connect(_focus_changed)
	visibility_changed.connect(_retire_stick)

func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_viewport_focus_changed)
	refresh_layout(true)
	queue_accessibility_update()

func _make_label(node_name: String) -> Label:
	var label := Label.new()
	label.name = node_name
	label.size = Vector2(504, 0)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.clip_text = false
	label.focus_mode = Control.FOCUS_NONE
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_body.add_child(label)
	return label

func set_copy(title: String, sentence: String, locale: String, reset_scroll: bool = false,
		media: Texture2D = null) -> void:
	var normalized := locale.replace("_", "-")
	var eligible: Texture2D = media if media != null and media.get_size() == Vector2(258, 78) else null
	var changed := title_label.text != title or sentence_label.text != sentence or _locale != normalized or _media.texture != eligible
	_media.texture = eligible
	_locale = normalized
	for label: Label in [title_label, sentence_label]: label.language = _locale
	title_label.text = title
	sentence_label.text = sentence
	title_label.visible = not title.is_empty()
	sentence_label.visible = not sentence.is_empty()
	accessibility_name = COPY.get(_locale, COPY.en)
	refresh_layout(reset_scroll)
	if changed: presentation_changed.emit()

func set_interactive(value: bool) -> void:
	if _interactive == value: return
	_interactive = value
	if not value:
		_retire_stick()
	_sync_focus_mode()
	queue_accessibility_update()
	presentation_changed.emit()

func set_actions(selector: Control, practice: Control, version_register: Control = null) -> void:
	_selector = selector
	_practice = practice
	_register = version_register
	for action: Control in [_selector, _practice, _register]:
		if not is_instance_valid(action): continue
		if action.get_parent() != _body:
			if action.get_parent() != null: action.get_parent().remove_child(action)
			_body.add_child(action)
		if not action.gui_input.is_connected(_forward_action_drag):
			action.gui_input.connect(_forward_action_drag)
		if not action.visibility_changed.is_connected(refresh_layout):
			action.visibility_changed.connect(refresh_layout)
	if is_instance_valid(_register) and not _register.layout_changed.is_connected(refresh_layout):
		_register.layout_changed.connect(refresh_layout)
	refresh_layout()

func _forward_action_drag(event: InputEvent) -> void:
	# Native buttons forward wheel events, but stop touch/pan at their hit area.
	if event is InputEventScreenDrag or event is InputEventPanGesture: _gui_input(event)

func refresh_layout(reset_scroll: bool = false) -> void:
	if not is_instance_valid(title_label): return
	var old := Vector2(content_extent, scroll_offset)
	var title_height := _natural_height(title_label) if title_label.visible else 0.0
	var title_top := 176.0 if _media.texture != null else 0.0
	_media.ink = get_theme_color("paper_ink", "Gallery") if has_theme_color("paper_ink", "Gallery") else Color.BLACK
	_media.queue_redraw()
	title_label.position = Vector2(0, title_top)
	title_label.size = Vector2(504, title_height)
	var text_bottom := title_top + title_height
	var sentence_height := _natural_height(sentence_label) if sentence_label.visible else 0.0
	sentence_label.position = Vector2(0, text_bottom + 16)
	sentence_label.size = Vector2(504, sentence_height)
	if sentence_label.visible: text_bottom = sentence_label.position.y + sentence_height
	if _visible(_register):
		_register.position = Vector2(0, sentence_label.position.y + sentence_height + 32)
		content_extent = _even(_register.position.y + _register.size.y)
		if _visible(_practice):
			_place_action(_practice, Vector2(328, content_extent + 24), Vector2(160, 64))
			content_extent = _even(_practice.position.y + 72)
	elif _visible(_selector) or _visible(_practice):
		var row_y := text_bottom + 32
		_place_action(_selector, Vector2(16, row_y), Vector2(288, 64))
		_place_action(_practice, Vector2(328, row_y), Vector2(160, 64))
		content_extent = _even(row_y + 72)
	else: content_extent = _even(text_bottom)
	scroll_offset = 0.0 if reset_scroll else _clamped_even(scroll_offset)
	_apply_offset()
	_sync_focus_mode()
	if is_inside_tree():
		var focused := get_viewport().gui_get_focus_owner()
		# Localized row wrapping can move the focused row while total height stays equal.
		var version_focus := focused != null and is_instance_valid(_register) and _register.is_ancestor_of(focused)
		if focused != null and _body.is_ancestor_of(focused) and (content_extent != old.x or version_focus):
			reveal_control(focused)
	queue_accessibility_update()
	if old != Vector2(content_extent, scroll_offset): presentation_changed.emit()

func _visible(control: Control) -> bool:
	return is_instance_valid(control) and control.visible

func _place_action(control: Control, at: Vector2, extent: Vector2) -> void:
	if not is_instance_valid(control): return
	control.position = at
	control.size = extent

func scroll_to(value: float) -> void:
	var next := _clamped_even(value)
	if is_equal_approx(next, scroll_offset): return
	scroll_offset = next
	_apply_offset()
	queue_accessibility_update()
	presentation_changed.emit()

func has_overflow() -> bool:
	return content_extent > VIEW_SIZE.y

func reveal_control(control: Control) -> void:
	if not _visible(control) or not _body.is_ancestor_of(control): return
	var local_transform := _body.get_global_transform().affine_inverse() * control.get_global_transform()
	var rect: Rect2 = (local_transform * Rect2(Vector2.ZERO, control.size)).grow(8)
	if rect.size.y > VIEW_SIZE.y:
		# A long wrapped cue cannot fit at once. Keep the visible interior stable
		# instead of alternating between its two edges on repeated layout/reveal.
		scroll_to(clampf(scroll_offset, rect.position.y, rect.end.y - VIEW_SIZE.y))
		return
	if rect.position.y < scroll_offset: scroll_to(rect.position.y)
	elif rect.end.y > scroll_offset + VIEW_SIZE.y: scroll_to(rect.end.y - VIEW_SIZE.y)

func _natural_height(label: Label) -> float:
	label.size = Vector2(504, 0)
	return _even(label.get_minimum_size().y)

func _line_height() -> float:
	var font := title_label.get_theme_font("font")
	return maxf(2.0, _even(font.get_height(title_label.get_theme_font_size("font_size"))))

func _even(value: float) -> float:
	return ceilf(maxf(0.0, value) / 2.0) * 2.0

func _clamped_even(value: float) -> float:
	return clampf(roundf(value / 2.0) * 2.0, 0.0, maxf(0.0, content_extent - VIEW_SIZE.y))

func _apply_offset() -> void:
	_body.position = Vector2(0, -scroll_offset)

func _sync_focus_mode() -> void:
	var next := Control.FOCUS_ALL if _interactive and has_overflow() else Control.FOCUS_NONE
	_pointer.mouse_filter = Control.MOUSE_FILTER_STOP if next == Control.FOCUS_ALL else Control.MOUSE_FILTER_IGNORE
	if focus_mode == next: return
	var focused := has_focus()
	var hide_focus := not has_focus(true)
	focus_mode = next
	_retire_stick()
	if focused and next == Control.FOCUS_NONE: focus_target_removed.emit(hide_focus)

func _gui_input(event: InputEvent) -> void:
	if not _interactive or not has_overflow(): return
	if has_focus():
		var keyboard: bool = event is InputEventKey and event.pressed
		var controller: bool = (event is InputEventJoypadButton and event.pressed) or (
			event is InputEventJoypadMotion and absf(event.axis_value) > 0.55)
		if keyboard or controller:
			grab_focus()
			_viewport_focus_changed(self)
		var accept: bool = event.is_action(&"ui_accept") or (
			event is InputEventKey and event.keycode in [KEY_ENTER, KEY_KP_ENTER, KEY_SPACE]) or (
			event is InputEventJoypadButton and event.button_index == JOY_BUTTON_A)
		if accept:
			accept_event()
			return
	if event is InputEventMouseButton:
		if event.button_index in [MOUSE_BUTTON_WHEEL_UP, MOUSE_BUTTON_WHEEL_DOWN]:
			var direction := -1.0 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1.0
			if event.pressed: scroll_to(scroll_offset + direction * 72.0 * event.factor)
			accept_event()
	elif event is InputEventPanGesture:
		scroll_to(scroll_offset + event.delta.y * 32.0)
		accept_event()
	elif event is InputEventScreenDrag:
		scroll_to(scroll_offset - event.relative.y)
		accept_event()
	elif event is InputEventKey and event.pressed and has_focus():
		if _key_scroll(event.keycode): accept_event()
	elif event is InputEventJoypadButton and event.pressed and has_focus():
		if _joy_scroll(event.button_index): accept_event()
	elif event is InputEventJoypadMotion and event.axis == JOY_AXIS_LEFT_Y and has_focus():
		_stick(event.axis_value)
		accept_event()

func _key_scroll(code: Key) -> bool:
	match code:
		KEY_UP: scroll_to(scroll_offset - _line_height())
		KEY_DOWN: scroll_to(scroll_offset + _line_height())
		KEY_PAGEUP: scroll_to(scroll_offset - VIEW_SIZE.y)
		KEY_PAGEDOWN: scroll_to(scroll_offset + VIEW_SIZE.y)
		KEY_HOME: scroll_to(0)
		KEY_END: scroll_to(content_extent)
		KEY_ENTER, KEY_KP_ENTER, KEY_SPACE: pass
		_: return false
	return true

func _joy_scroll(button: JoyButton) -> bool:
	match button:
		JOY_BUTTON_DPAD_UP: scroll_to(scroll_offset - _line_height())
		JOY_BUTTON_DPAD_DOWN: scroll_to(scroll_offset + _line_height())
		JOY_BUTTON_A: pass
		_: return false
	return true

func _stick(value: float) -> void:
	var direction := 1 if value > 0.55 else (-1 if value < -0.55 else 0)
	if direction == 0: _retire_stick()
	elif direction != _stick_direction:
		_stick_direction = direction
		scroll_to(scroll_offset + direction * _line_height())
		_repeat.start(0.35)

func _repeat_stick() -> void:
	if _stick_direction == 0 or not _interactive or not has_overflow() \
			or not has_focus() or not is_visible_in_tree():
		_retire_stick()
		return
	scroll_to(scroll_offset + _stick_direction * _line_height())
	_repeat.start(0.10)

func _retire_stick() -> void:
	_stick_direction = 0
	if is_instance_valid(_repeat): _repeat.stop()

func _focus_changed() -> void:
	_retire_stick()
	presentation_changed.emit()

func _viewport_focus_changed(_control: Control) -> void:
	var focused := has_focus(true)
	if focused == _visual_focus: return
	_visual_focus = focused
	presentation_changed.emit()

func _notification(what: int) -> void:
	if what == NOTIFICATION_THEME_CHANGED and is_node_ready(): refresh_layout()
	elif what in [NOTIFICATION_WM_WINDOW_FOCUS_OUT, NOTIFICATION_APPLICATION_FOCUS_OUT,
			NOTIFICATION_DISABLED, NOTIFICATION_VISIBILITY_CHANGED]: _retire_stick()
	if what != NOTIFICATION_ACCESSIBILITY_UPDATE: return
	var element := get_accessibility_element()
	if not element.is_valid(): return
	DisplayServer.accessibility_update_set_role(element,
		DisplayServer.ROLE_SCROLL_VIEW if has_overflow() else DisplayServer.ROLE_CONTAINER)
	DisplayServer.accessibility_update_set_name(element, COPY.get(_locale, COPY.en) if has_overflow() else "")
	DisplayServer.accessibility_update_set_language(element, _locale)
	DisplayServer.accessibility_update_set_scroll_y(element, scroll_offset)
	DisplayServer.accessibility_update_set_scroll_y_range(element, 0,
		maxf(0.0, content_extent - VIEW_SIZE.y))
	if not _interactive or not has_overflow(): return
	for pair: Array in [[DisplayServer.ACTION_SCROLL_UP, -1], [DisplayServer.ACTION_SCROLL_DOWN, 1]]:
		DisplayServer.accessibility_update_add_action(element, pair[0],
			_accessibility_scroll.bind(pair[1]))
	for pair: Array in [[DisplayServer.ACTION_SCROLL_BACKWARD, -1],
		[DisplayServer.ACTION_SCROLL_FORWARD, 1]]:
		DisplayServer.accessibility_update_add_action(element, pair[0],
			_accessibility_page.bind(pair[1]))
	DisplayServer.accessibility_update_add_action(element, DisplayServer.ACTION_SET_SCROLL_OFFSET,
		_accessibility_set_offset)

func _accessibility_scroll(unit: Variant, direction: int) -> void:
	if not _interactive or not has_overflow(): return
	var amount := VIEW_SIZE.y if unit == DisplayServer.SCROLL_UNIT_PAGE else _line_height()
	scroll_to(scroll_offset + direction * amount)

func _accessibility_page(_request: Variant, direction: int) -> void:
	if _interactive and has_overflow(): scroll_to(scroll_offset + direction * VIEW_SIZE.y)

func _accessibility_set_offset(value: Variant) -> void:
	if _interactive and has_overflow() and value is Vector2: scroll_to(value.y)
