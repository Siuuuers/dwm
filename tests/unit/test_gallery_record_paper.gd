extends GutTest

const PAPER := preload("res://scripts/ui/gallery/GalleryRecordPaper.gd")

var _viewport: SubViewport
var _paper: Control
var _other: Button

func before_each() -> void:
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(720, 640)
	_viewport.handle_input_locally = true
	add_child_autofree(_viewport)
	_paper = PAPER.new()
	_paper.position = Vector2(24, 24)
	_viewport.add_child(_paper)
	_other = Button.new()
	_other.position = Vector2(576, 24)
	_other.size = Vector2(120, 64)
	_other.focus_mode = Control.FOCUS_ALL
	_viewport.add_child(_other)

func _long(word: String = "record") -> String:
	return (word + " ").repeat(420)

func _point() -> Vector2:
	return _paper.position + Vector2(500, 240)

func _max_scroll() -> float:
	return maxf(0, _paper.content_extent - 512)

func _push(event: InputEvent) -> bool:
	_viewport.push_input(event, true)
	return _viewport.is_input_handled()

func _key(code: Key) -> bool:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = true
	return _push(event)

func _joy(button: JoyButton) -> bool:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = true
	return _push(event)

func _wheel(button: MouseButton, factor: float = 1.0, pressed: bool = true,
		point: Vector2 = Vector2.INF) -> bool:
	var event := InputEventMouseButton.new()
	var at := _point() if point == Vector2.INF else point
	event.position = at
	event.global_position = at
	event.button_index = button
	event.factor = factor
	event.pressed = pressed
	return _push(event)

func _stick(value: float) -> bool:
	var event := InputEventJoypadMotion.new()
	event.axis = JOY_AXIS_LEFT_Y
	event.axis_value = value
	return _push(event)

func test_long_copy_uses_even_natural_layout_and_optional_sentence_gap() -> void:
	_paper.set_copy(_long("title"), _long("sentence"), "en", true)
	assert_eq(_paper.size, Vector2(520, 512))
	assert_true(_paper.clip_contents)
	assert_eq(_paper.title_label.name, &"RecordTitle")
	assert_eq(_paper.title_label.position, Vector2.ZERO)
	assert_eq(_paper.title_label.size.x, 504.0)
	assert_eq(_paper.sentence_label.position.y, _paper.title_label.size.y + 16)
	assert_eq(_paper.content_extent,
		_paper.sentence_label.position.y + _paper.sentence_label.size.y)
	assert_eq(fmod(_paper.title_label.size.y, 2), 0.0)
	assert_eq(fmod(_paper.sentence_label.size.y, 2), 0.0)
	assert_eq(fmod(_paper.content_extent, 2), 0.0)
	assert_true(_paper.has_overflow())
	assert_eq(_paper.focus_mode, Control.FOCUS_ALL)

	_paper.set_copy(_long("title"), "", "en", true)
	assert_false(_paper.sentence_label.visible)
	assert_eq(_paper.content_extent, _paper.title_label.size.y,
		"absent sentence contributes neither its gap nor a line box")

func test_actions_share_clipped_body_and_reveal_only_the_detached_ring() -> void:
	_paper.set_copy(_long(), "", "en", true)
	var selector := OptionButton.new()
	var practice := Button.new()
	_paper.set_actions(selector, practice)
	assert_same(selector.get_parent(), practice.get_parent())
	assert_ne(selector.get_parent(), _paper)
	assert_true(_paper.is_ancestor_of(selector))
	assert_eq(selector.position.x, 16.0)
	assert_eq(selector.size, Vector2(288, 64))
	assert_eq(practice.position.x, 328.0)
	assert_eq(practice.size, Vector2(160, 64))
	assert_eq(selector.position.y, _paper.title_label.size.y + 32)
	assert_eq(_paper.content_extent, selector.position.y + 72)
	_paper.scroll_to(0)
	_paper.reveal_control(practice)
	assert_eq(_paper.scroll_offset, practice.position.y + practice.size.y + 8 - 512)
	var text_extent: float = _paper.title_label.size.y
	selector.hide()
	practice.hide()
	_paper.refresh_layout()
	assert_eq(_paper.content_extent, text_extent, "hidden actions leave no row or gap")

func test_pointer_scrolls_are_consumed_at_boundaries_without_stealing_focus() -> void:
	_paper.set_copy(_long(), "", "en", true)
	_other.grab_focus()
	assert_true(_wheel(MOUSE_BUTTON_WHEEL_DOWN))
	assert_eq(_paper.scroll_offset, 72.0)
	assert_true(_other.has_focus())
	var pan := InputEventPanGesture.new()
	pan.position = _point()
	pan.delta = Vector2(0, 1)
	assert_true(_push(pan))
	assert_eq(_paper.scroll_offset, 104.0)
	assert_true(_other.has_focus())
	var drag := InputEventScreenDrag.new()
	drag.position = _point()
	drag.relative = Vector2(0, -20)
	assert_true(_push(drag))
	assert_eq(_paper.scroll_offset, 124.0)
	assert_true(_other.has_focus())
	_paper.scroll_to(_paper.content_extent)
	assert_true(_wheel(MOUSE_BUTTON_WHEEL_DOWN), "wheel is consumed at the lower boundary")
	assert_eq(_paper.scroll_offset, _max_scroll())
	assert_true(_push(pan), "pan is consumed at the lower boundary")
	assert_eq(_paper.scroll_offset, _max_scroll())
	assert_true(_push(drag), "touch drag is consumed at the lower boundary")
	assert_eq(_paper.scroll_offset, _max_scroll())

func test_focused_keyboard_scrolls_clamps_and_consumes_accept_without_activation() -> void:
	_paper.set_copy(_long(), "", "en", true)
	var presentations: Array[bool] = []
	_paper.presentation_changed.connect(func(): presentations.append(true))
	_paper.grab_focus()
	assert_true(_key(KEY_END))
	assert_eq(_paper.scroll_offset, _max_scroll())
	assert_true(_key(KEY_DOWN), "Down is consumed at the boundary")
	var held := InputEventKey.new()
	held.keycode = KEY_DOWN
	held.pressed = true
	held.echo = true
	assert_true(_push(held), "held key repeat remains consumed at the boundary")
	assert_true(_paper.has_focus())
	assert_eq(_paper.scroll_offset, _max_scroll())
	assert_true(_key(KEY_HOME))
	assert_eq(_paper.scroll_offset, 0.0)
	assert_true(_key(KEY_UP), "Up is consumed at the boundary")
	assert_true(_key(KEY_PAGEDOWN))
	assert_eq(_paper.scroll_offset, minf(512, _max_scroll()))
	assert_true(_key(KEY_PAGEUP))
	assert_eq(_paper.scroll_offset, 0.0)
	assert_true(_key(KEY_DOWN))
	var one_line: float = _paper.scroll_offset
	assert_gt(one_line, 0.0)
	assert_true(_key(KEY_UP))
	assert_eq(_paper.scroll_offset, 0.0)
	var before := presentations.size()
	assert_true(_key(KEY_ENTER))
	assert_true(_key(KEY_SPACE))
	assert_eq(_paper.scroll_offset, 0.0)
	assert_true(_paper.has_focus())
	assert_eq(presentations.size(), before, "accept inputs have no presentation side effect")

func test_dpad_and_held_stick_repeat_then_retire_on_release_and_focus_loss() -> void:
	_paper.set_copy(_long(), "", "en", true)
	_paper.grab_focus()
	assert_true(_joy(JOY_BUTTON_DPAD_DOWN))
	var line: float = _paper.scroll_offset
	assert_gt(line, 0.0)
	assert_true(_joy(JOY_BUTTON_DPAD_UP))
	assert_eq(_paper.scroll_offset, 0.0)
	assert_true(_stick(1.0))
	var immediate: float = _paper.scroll_offset
	assert_gt(immediate, 0.0)
	await get_tree().create_timer(0.40).timeout
	assert_gt(_paper.scroll_offset, immediate)
	assert_true(_stick(0.0))
	var released: float = _paper.scroll_offset
	await get_tree().create_timer(0.20).timeout
	assert_eq(_paper.scroll_offset, released)
	assert_true(_stick(1.0))
	_other.grab_focus()
	var unfocused: float = _paper.scroll_offset
	await get_tree().create_timer(0.40).timeout
	assert_eq(_paper.scroll_offset, unfocused)

func test_fit_copy_removes_focus_target_and_localizes_inert_labels() -> void:
	_paper.set_copy(_long(), "", "en", true)
	_paper.scroll_to(37)
	assert_eq(fmod(_paper.scroll_offset, 2), 0.0)
	_paper.grab_focus()
	_paper.set_copy("一份简短记录", "", "zh_CN")
	assert_false(_paper.has_overflow())
	assert_eq(_paper.scroll_offset, 0.0)
	assert_eq(_paper.focus_mode, Control.FOCUS_NONE)
	assert_false(_paper.has_focus())
	assert_eq(_paper.title_label.language, "zh-CN")
	assert_eq(_paper.sentence_label.language, "zh-CN")
	assert_eq(_paper.accessibility_name, "记录详情")
	assert_false(_paper.sentence_label.visible)
	assert_eq(_paper.content_extent, _paper.title_label.size.y)
	_paper.set_copy(_long(), "", "zh_HK")
	_paper.set_interactive(false)
	assert_eq(_paper.focus_mode, Control.FOCUS_NONE)
	_paper.set_interactive(true)
	assert_eq(_paper.focus_mode, Control.FOCUS_ALL)
	_paper.scroll_to(1.0e9)
	assert_eq(_paper.scroll_offset, _max_scroll())

func test_fractional_wheel_release_touch_and_retained_selector_preserve_focus_and_selection() -> void:
	_paper.set_copy(_long(), "", "en", true)
	var selector := OptionButton.new()
	selector.add_item("First")
	selector.add_item("Second")
	selector.select(1)
	_paper.set_actions(selector, Button.new())
	_other.grab_focus()
	assert_true(_wheel(MOUSE_BUTTON_WHEEL_DOWN, 0.25))
	assert_eq(_paper.scroll_offset, 18.0, "fractional wheel factor is retained")
	assert_true(_wheel(MOUSE_BUTTON_WHEEL_DOWN, 0.25, false))
	assert_eq(_paper.scroll_offset, 18.0, "wheel release cannot scroll twice")
	_paper.reveal_control(selector)
	var before_selector: float = _paper.scroll_offset
	var selector_point := selector.get_global_rect().get_center()
	assert_true(_wheel(MOUSE_BUTTON_WHEEL_UP, 1.0, true, selector_point))
	assert_eq(_paper.scroll_offset, before_selector - 72.0,
		"wheel over retained action bubbles to its paper")
	assert_eq(selector.selected, 1, "paper wheel does not change the retained selection")
	assert_true(_other.has_focus(), "pointer scrolling never steals semantic focus")
	var touch := InputEventScreenTouch.new()
	touch.index = 0
	touch.position = _point()
	touch.pressed = true
	assert_true(_push(touch))
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = _point() + Vector2(0, -24)
	drag.relative = Vector2(0, -24)
	assert_true(_push(drag))
	assert_eq(_paper.scroll_offset, before_selector - 48.0)
	assert_true(_other.has_focus(), "touch drag retains the other control's focus")

func test_accept_releases_visualize_hidden_focus_and_accessibility_callbacks_clamp() -> void:
	_paper.set_copy(_long(), "", "en", true)
	var presentations: Array[bool] = []
	_paper.presentation_changed.connect(func(): presentations.append(true))
	_paper.grab_focus(true)
	assert_true(_paper.has_focus())
	assert_false(_paper.has_focus(true))
	_paper.scroll_to(_paper.content_extent)
	var before := presentations.size()
	assert_true(_key(KEY_DOWN), "boundary key remains owned")
	assert_true(_paper.has_focus(true), "same-owner keyboard input publishes visible focus")
	assert_gt(presentations.size(), before)
	for code: Key in [KEY_ENTER, KEY_SPACE]:
		var release := InputEventKey.new()
		release.keycode = code
		release.physical_keycode = code
		release.pressed = false
		assert_true(_push(release), "accept key release remains consumed")
	var joy_release := InputEventJoypadButton.new()
	joy_release.button_index = JOY_BUTTON_A
	joy_release.pressed = false
	assert_true(_push(joy_release), "accept button release remains consumed")
	_paper.scroll_to(0)
	_paper._accessibility_scroll(DisplayServer.SCROLL_UNIT_ITEM, 1)
	var item: float = _paper.scroll_offset
	assert_gt(item, 0.0)
	_paper._accessibility_scroll(DisplayServer.SCROLL_UNIT_PAGE, 1)
	assert_eq(_paper.scroll_offset, minf(item + 512, _max_scroll()))
	_paper._accessibility_page(-1)
	assert_eq(_paper.scroll_offset, maxf(0, minf(item + 512, _max_scroll()) - 512))
	_paper._accessibility_page(-1)
	assert_eq(_paper.scroll_offset, 0.0, "accessibility backward clamps at the start")
	_paper._accessibility_page(1)
	_paper._accessibility_set_offset(Vector2(0, 1.0e9))
	assert_eq(_paper.scroll_offset, _max_scroll(), "accessibility forward/set-offset clamp at the end")

func test_touch_drag_over_retained_actions_scrolls_without_activation_or_focus_theft() -> void:
	_paper.set_copy(_long(), "", "en", true)
	var selector := OptionButton.new()
	selector.add_item("First")
	selector.add_item("Second")
	var practice := Button.new()
	var activations: Array[bool] = []
	practice.pressed.connect(func(): activations.append(true))
	selector.item_selected.connect(func(_index: int): activations.append(true))
	_paper.set_actions(selector, practice)
	for action: Control in [selector, practice]:
		_paper.reveal_control(action)
		_other.grab_focus()
		var point := action.get_global_rect().get_center()
		var before: float = _paper.scroll_offset
		var touch := InputEventScreenTouch.new()
		touch.position = point
		touch.pressed = true
		_push(touch)
		var drag := InputEventScreenDrag.new()
		drag.position = point + Vector2(0, 24)
		drag.relative = Vector2(0, 24)
		_push(drag)
		touch.position = drag.position
		touch.pressed = false
		_push(touch)
		assert_eq(_paper.scroll_offset, before - 24.0, "touch over retained action reaches paper")
		assert_true(_other.has_focus(), "touch scrolling over action does not steal focus")
	assert_true(activations.is_empty())
