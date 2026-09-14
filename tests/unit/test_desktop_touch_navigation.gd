extends GutTest

const NAVIGATION := preload("res://scripts/ui/desktop/DesktopTouchNavigation.gd")

class EnterOnlyControl extends Control:
	var packets: Array[bool] = []
	var ui_accept_packets: Array[bool] = []
	var accepted := 0

	func _gui_input(event: InputEvent) -> void:
		if event is InputEventKey and event.keycode == KEY_ENTER:
			packets.append(event.pressed)
			ui_accept_packets.append(event.is_action(&"ui_accept"))
			if not event.pressed:
				accepted += 1
			accept_event()

var _scope: VBoxContainer
var _navigation: HBoxContainer
var _admitted := true


func before_each() -> void:
	_admitted = true
	_scope = VBoxContainer.new()
	_scope.position = Vector2(32, 32)
	_scope.size = Vector2(240, 320)
	add_child_autofree(_scope)
	_navigation = NAVIGATION.new()
	_navigation.position = Vector2(320, 400)
	_navigation.size = Vector2(240, 64)
	add_child_autofree(_navigation)
	var configured: Dictionary = _navigation.configure(
		func() -> Control: return _scope,
		func() -> bool: return _admitted)
	assert_true(configured.get("ok", false), str(configured))
	await get_tree().process_frame


func _button(name_value: String) -> Button:
	var button := Button.new()
	button.name = name_value
	button.text = name_value
	button.custom_minimum_size = Vector2(160, 56)
	button.focus_mode = Control.FOCUS_ALL
	_scope.add_child(button)
	return button


func _point(button: Button) -> Vector2:
	return button.get_global_transform_with_canvas() * (button.size * 0.5)


func _touch(button: Button, pressed: bool, index: int = 4, canceled: bool = false,
		point: Variant = null) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = _point(button) if point == null else point
	event.pressed = pressed
	event.canceled = canceled
	get_viewport().push_input(event, true)


func _click(button: Button, pressed: bool, point: Variant = null) -> void:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = _point(button) if point == null else point
	event.pressed = pressed
	get_viewport().push_input(event, true)


func _tap(button: Button) -> void:
	_touch(button, true)
	_touch(button, false)
	await get_tree().process_frame


func test_exposes_three_non_focusable_compact_controls_with_independent_labels() -> void:
	assert_not_null(_navigation.previous_button)
	assert_not_null(_navigation.next_button)
	assert_not_null(_navigation.confirm_button)
	assert_eq(_navigation.get_child_count(), 3)
	for button: Button in [_navigation.previous_button, _navigation.next_button,
			_navigation.confirm_button]:
		assert_eq(button.focus_mode, Control.FOCUS_NONE,
			"touch navigation never replaces the inspected control's focus")
		assert_gte(button.custom_minimum_size.x, 48.0)
		assert_gte(button.custom_minimum_size.y, 48.0)
	_navigation.previous_button.text = "←"
	_navigation.previous_button.accessibility_name = "Previous control"
	assert_eq(_navigation.previous_button.text, "←")
	assert_eq(_navigation.previous_button.accessibility_name, "Previous control")


func test_next_and_previous_follow_tab_order_and_skip_unusable_controls() -> void:
	var first := _button("First")
	var disabled := _button("Disabled")
	var hidden := _button("Hidden")
	var last := _button("Last")
	disabled.disabled = true
	hidden.hide()
	first.focus_next = first.get_path_to(last)
	last.focus_previous = last.get_path_to(first)
	first.grab_focus()

	await _tap(_navigation.next_button)
	assert_same(get_viewport().gui_get_focus_owner(), last,
		"Next preserves an explicit usable focus_next destination")
	await _tap(_navigation.previous_button)
	assert_same(get_viewport().gui_get_focus_owner(), first)
	first.focus_next = NodePath()
	last.focus_previous = NodePath()
	await _tap(_navigation.next_button)
	assert_same(get_viewport().gui_get_focus_owner(), last,
		"default Tab order skips hidden and disabled controls inside the scope")
	assert_false(disabled.has_focus())
	assert_false(hidden.has_focus())


func test_next_rejects_an_explicit_target_owned_by_an_embedded_viewport() -> void:
	var first := _button("First")
	var embedded := SubViewport.new()
	embedded.name = "EmbeddedViewport"
	embedded.size = Vector2i(160, 120)
	embedded.handle_input_locally = true
	_scope.add_child(embedded)
	var foreign := Button.new()
	foreign.name = "Foreign"
	foreign.focus_mode = Control.FOCUS_ALL
	foreign.size = Vector2(120, 56)
	embedded.add_child(foreign)
	var last := _button("Last")
	first.focus_next = first.get_path_to(foreign)
	first.grab_focus()

	await _tap(_navigation.next_button)
	assert_same(get_viewport().gui_get_focus_owner(), last,
		"an explicit path cannot move desktop focus into an embedded viewport")
	assert_false(foreign.has_focus())


func test_confirm_without_valid_focus_only_restores_focus_then_accepts_exactly_once() -> void:
	var first := _button("First")
	var accepted: Array[int] = [0]
	first.pressed.connect(func() -> void: accepted[0] += 1)
	first.release_focus()
	assert_null(get_viewport().gui_get_focus_owner())

	await _tap(_navigation.confirm_button)
	assert_same(get_viewport().gui_get_focus_owner(), first)
	assert_eq(accepted[0], 0, "restoring missing focus never activates the restored control")
	await _tap(_navigation.confirm_button)
	assert_eq(accepted[0], 1, "one touch release delivers one real ui_accept")


func test_scope_and_admission_prevent_background_or_suspended_navigation() -> void:
	var background := Button.new()
	background.text = "Background"
	background.focus_mode = Control.FOCUS_ALL
	add_child_autofree(background)
	var modal_first := _button("Modal first")
	var modal_second := _button("Modal second")
	background.grab_focus()

	await _tap(_navigation.next_button)
	assert_same(get_viewport().gui_get_focus_owner(), modal_first,
		"a focus owner outside the provided modal scope is replaced without advancing")
	_admitted = false
	await _tap(_navigation.next_button)
	await _tap(_navigation.confirm_button)
	assert_same(get_viewport().gui_get_focus_owner(), modal_first,
		"suspended source input cannot move or activate modal focus")
	assert_false(modal_second.has_focus())


func test_pointer_cancellation_and_release_outside_do_not_activate_but_mouse_release_does() -> void:
	var target := _button("Target")
	var accepted: Array[int] = [0]
	target.pressed.connect(func() -> void: accepted[0] += 1)
	target.grab_focus()
	var outside := Vector2(12, 12)

	_touch(_navigation.confirm_button, true, 7)
	_touch(_navigation.confirm_button, false, 7, false, outside)
	await get_tree().process_frame
	assert_eq(accepted[0], 0, "release outside cancels the held touch")
	_touch(_navigation.confirm_button, true, 8)
	_touch(_navigation.confirm_button, false, 8, true)
	await get_tree().process_frame
	assert_eq(accepted[0], 0, "a canceled touch never confirms")

	_click(_navigation.confirm_button, true)
	_click(_navigation.confirm_button, false)
	await get_tree().process_frame
	assert_eq(accepted[0], 1, "an admitted mouse release on the same control confirms once")


func test_confirm_delivers_an_enter_press_and_release_to_a_key_only_focused_control() -> void:
	var target := EnterOnlyControl.new()
	target.name = "KeyOnlyTarget"
	target.custom_minimum_size = Vector2(160, 56)
	target.focus_mode = Control.FOCUS_ALL
	_scope.add_child(target)
	target.grab_focus()

	await _tap(_navigation.confirm_button)
	assert_eq(target.packets, [true, false], "Confirm follows the real Enter input pipeline")
	assert_eq(target.ui_accept_packets, [true, true],
		"the normal-keyboard Enter pair resolves through the installed ui_accept mapping")
	assert_eq(target.accepted, 1)


func test_deferred_confirm_refuses_changed_focus_or_scope() -> void:
	var first := _button("First")
	var second := _button("Second")
	var accepted: Array[int] = [0]
	first.pressed.connect(func() -> void: accepted[0] += 1)
	first.grab_focus()
	_touch(_navigation.confirm_button, true, 12)
	_touch(_navigation.confirm_button, false, 12)
	second.grab_focus()
	await get_tree().process_frame
	assert_eq(accepted[0], 0, "focus changed after release invalidates the deferred confirmation")

	first.grab_focus()
	_touch(_navigation.confirm_button, true, 13)
	_touch(_navigation.confirm_button, false, 13)
	var replacement := VBoxContainer.new()
	replacement.size = Vector2(200, 200)
	add_child_autofree(replacement)
	_scope = replacement
	await get_tree().process_frame
	assert_eq(accepted[0], 0, "scope changed after release invalidates the deferred confirmation")


func test_pointer_press_custody_must_remain_admitted_with_the_same_focus_and_scope() -> void:
	var first := _button("First")
	var second := _button("Second")
	var accepted: Array[int] = [0]
	first.pressed.connect(func() -> void: accepted[0] += 1)
	second.pressed.connect(func() -> void: accepted[0] += 1)
	first.grab_focus()

	_admitted = false
	_touch(_navigation.confirm_button, true, 20)
	_admitted = true
	_touch(_navigation.confirm_button, false, 20)
	await get_tree().process_frame
	assert_eq(accepted[0], 0, "a press begun while suspended cannot become fresh after resume")

	_touch(_navigation.confirm_button, true, 21)
	second.grab_focus()
	_touch(_navigation.confirm_button, false, 21)
	await get_tree().process_frame
	assert_eq(accepted[0], 0, "focus changing while held cancels confirmation")

	first.grab_focus()
	_touch(_navigation.confirm_button, true, 22)
	var replacement := VBoxContainer.new()
	replacement.size = Vector2(200, 200)
	add_child_autofree(replacement)
	_scope = replacement
	_touch(_navigation.confirm_button, false, 22)
	await get_tree().process_frame
	assert_eq(accepted[0], 0, "scope changing while held cancels confirmation")


func test_focus_out_retires_a_queued_confirm_even_when_focus_and_scope_return() -> void:
	var target := _button("Target")
	var accepted: Array[int] = [0]
	target.pressed.connect(func() -> void: accepted[0] += 1)
	target.grab_focus()
	_touch(_navigation.confirm_button, true, 30)
	_touch(_navigation.confirm_button, false, 30)
	_navigation.notification(NOTIFICATION_APPLICATION_FOCUS_OUT)
	_navigation.notification(NOTIFICATION_APPLICATION_FOCUS_IN)
	target.grab_focus()

	await get_tree().process_frame
	assert_eq(accepted[0], 0,
		"focus returning before the deferred frame cannot revive the retired confirmation")
