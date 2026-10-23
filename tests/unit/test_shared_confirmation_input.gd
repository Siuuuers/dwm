extends GutTest

class BackObserver extends Node:
	var retreats := 0

	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_cancel") and not event.is_echo():
			retreats += 1
			get_viewport().set_input_as_handled()

const CONFIRMATION := preload("res://scripts/ui/desktop/DesktopConfirmation.gd")
const BACKUP_THEME := preload("res://scripts/ui/backup/BackupTheme.gd")
var viewport: SubViewport
var host: Control
var lower: Control
var lower_button: Button
var modal: Control
var results: Array[bool] = []
var lower_commands := 0
var _saved_accept: Array[InputEvent] = []
var _saved_cancel: Array[InputEvent] = []
var _emulation := false

func before_each() -> void:
	results.clear()
	lower_commands = 0
	_saved_accept.assign(InputMap.action_get_events(&"ui_accept"))
	_saved_cancel.assign(InputMap.action_get_events(&"ui_cancel"))
	_emulation = Input.emulate_mouse_from_touch
	var accept := InputEventJoypadButton.new()
	accept.button_index = JOY_BUTTON_X
	InputMap.action_add_event(&"ui_accept",accept)
	var cancel := InputEventJoypadButton.new()
	cancel.button_index = JOY_BUTTON_Y
	InputMap.action_add_event(&"ui_cancel",cancel)
	viewport = SubViewport.new()
	viewport.size = Vector2i(800,656)
	add_child(viewport)
	host = Control.new()
	host.size = Vector2(800,656)
	viewport.add_child(host)
	lower = Control.new()
	lower.size = host.size
	lower.mouse_filter = Control.MOUSE_FILTER_PASS
	host.add_child(lower)
	lower_button = Button.new()
	lower_button.text = "Source action"
	lower_button.size = Vector2(180,64)
	lower_button.position = Vector2(16,16)
	lower_button.mouse_filter = Control.MOUSE_FILTER_PASS
	lower.add_child(lower_button)
	lower_button.pressed.connect(func(): lower_commands += 1)

func after_each() -> void:
	if is_instance_valid(viewport): viewport.free()
	InputMap.action_erase_events(&"ui_accept")
	InputMap.action_erase_events(&"ui_cancel")
	for event: InputEvent in _saved_accept: InputMap.action_add_event(&"ui_accept",event)
	for event: InputEvent in _saved_cancel: InputMap.action_add_event(&"ui_cancel",event)
	Input.emulate_mouse_from_touch = _emulation
	await get_tree().process_frame

func _mount() -> void:
	modal = CONFIRMATION.new()
	modal.theme = BACKUP_THEME.build("en",100)
	modal.request = {"title":"Load this save?","body":"Unsaved progress will be replaced.","cancel":"Cancel","confirm":"Load","risk":"danger"}
	modal.finished.connect(func(accepted: bool): results.append(accepted))
	host.add_child(modal)
	for frame in 3: await get_tree().process_frame
	assert_true(modal.cancel_button.has_focus())
	assert_eq(modal.get_node("ConfirmationSheet").position,Vector2(120,112))

func _key(key: Key, down: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.pressed = down
	event.echo = echo
	viewport.push_input(event,true)

func _pad(button: JoyButton, down: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.pressed = down
	viewport.push_input(event,true)

func _mouse(point: Vector2, down: bool, double_click: bool = false, device: int = 0) -> void:
	var motion := InputEventMouseMotion.new()
	motion.device = device
	motion.position = point
	viewport.push_input(motion,true)
	var event := InputEventMouseButton.new()
	event.device = device
	event.position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = down
	event.double_click = double_click
	viewport.push_input(event,true)

func _touch(point: Vector2, down: bool, canceled: bool = false, double_tap: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 2
	event.position = point
	event.pressed = down
	event.canceled = canceled
	event.double_tap = double_tap
	viewport.push_input(event,true)

func test_keyboard_accept_is_released_and_echo_unrelated_events_cannot_submit() -> void:
	await _mount()
	_key(KEY_ENTER,true)
	assert_true(results.is_empty(),"fresh key press only arms the native Cancel button")
	_key(KEY_ENTER,true,true)
	_key(KEY_ENTER,true)
	_key(KEY_Q,true)
	_key(KEY_Q,false)
	assert_true(results.is_empty(),"echo/repeated press/unrelated release cannot activate")
	_key(KEY_ENTER,false)
	assert_eq(results,[false],"the actual matching release activates Cancel once")
	_key(KEY_ENTER,false)
	assert_eq(results,[false])
	assert_eq(lower_commands,0)

func test_native_focus_navigation_does_not_toggle_on_echo_or_repeated_hold() -> void:
	await _mount()
	_key(KEY_RIGHT,true)
	assert_true(modal.confirm_button.has_focus())
	_key(KEY_RIGHT,true,true)
	_key(KEY_RIGHT,true)
	assert_true(modal.confirm_button.has_focus())
	_key(KEY_RIGHT,false)
	_key(KEY_TAB,true)
	assert_true(modal.cancel_button.has_focus(),"Tab remains inside the native two-button focus graph")
	_key(KEY_TAB,false)
	assert_true(results.is_empty())
	_key(KEY_ESCAPE,true)
	_key(KEY_ESCAPE,true,true)
	_key(KEY_ESCAPE,false)
	assert_eq(results,[false],"one Back cancels, and never also activates lower content")
	assert_eq(lower_commands,0)

func test_configured_controller_accept_releases_to_the_focused_semantic_action() -> void:
	await _mount()
	modal.confirm_button.grab_focus()
	_pad(JOY_BUTTON_X,true)
	_pad(JOY_BUTTON_X,true)
	assert_true(results.is_empty())
	_pad(JOY_BUTTON_X,false)
	assert_eq(results,[true])
	assert_eq(lower_commands,0)

func test_pointer_double_click_and_release_outside_are_inert_then_fresh_release_confirms() -> void:
	await _mount()
	var point: Vector2 = modal.confirm_button.get_global_rect().get_center()
	_mouse(point,true,true)
	_mouse(point,false)
	assert_true(results.is_empty(),"the second contact of a double-click cannot accept")
	_mouse(point,true)
	assert_true(results.is_empty())
	_mouse(Vector2(20,620),false)
	assert_true(results.is_empty(),"native release outside the pressed button cancels")
	_mouse(point,true)
	_mouse(point,false)
	assert_eq(results,[true])
	assert_eq(lower_commands,0)

func test_touch_drag_cancel_double_tap_and_emulated_mouse_do_not_duplicate_short_tap() -> void:
	await _mount()
	Input.emulate_mouse_from_touch = true
	var point: Vector2 = modal.confirm_button.get_global_rect().get_center()
	_touch(point,true)
	var drag := InputEventScreenDrag.new()
	drag.index = 2
	drag.position = point+Vector2(0,20)
	drag.relative = Vector2(0,20)
	viewport.push_input(drag,true)
	_touch(point,false)
	assert_true(results.is_empty())
	_touch(point,true)
	_touch(point,false,true)
	_touch(point,true,false,true)
	_touch(point,false)
	assert_true(results.is_empty(),"canceled and double-tap contacts do not accept")
	_touch(point,true)
	_mouse(point,true,false,InputEvent.DEVICE_ID_EMULATION)
	assert_true(results.is_empty())
	_touch(point,false)
	_mouse(point,false,false,InputEvent.DEVICE_ID_EMULATION)
	assert_eq(results,[true],"one real short touch release accepts despite its emulated mouse stream")
	assert_eq(lower_commands,0)

func test_custody_restores_saved_root_flags_without_rewriting_descendant_control_modes() -> void:
	lower.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
	lower.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
	lower_button.focus_mode = Control.FOCUS_CLICK
	await _mount()
	assert_eq(lower.focus_behavior_recursive,Control.FOCUS_BEHAVIOR_DISABLED)
	assert_eq(lower.mouse_behavior_recursive,Control.MOUSE_BEHAVIOR_DISABLED)
	assert_eq(lower_button.focus_mode,Control.FOCUS_CLICK)
	assert_eq(lower_button.mouse_filter,Control.MOUSE_FILTER_PASS)
	modal.free()
	assert_eq(lower.focus_behavior_recursive,Control.FOCUS_BEHAVIOR_ENABLED)
	assert_eq(lower.mouse_behavior_recursive,Control.MOUSE_BEHAVIOR_INHERITED)
	assert_eq(lower_button.focus_mode,Control.FOCUS_CLICK)
	assert_eq(lower_button.mouse_filter,Control.MOUSE_FILTER_PASS)
	assert_true(results.is_empty(),"external removal releases custody without fabricating an answer")

func test_back_consumes_the_event_before_finished_observers_restore_source_focus() -> void:
	await _mount()
	modal.finished.connect(func(_accepted: bool): lower_button.grab_focus())
	_pad(JOY_BUTTON_Y,true)
	_pad(JOY_BUTTON_Y,false)
	assert_eq(results,[false])
	assert_eq(lower.focus_behavior_recursive,Control.FOCUS_BEHAVIOR_INHERITED)
	assert_true(lower_button.has_focus())
	assert_eq(lower_commands,0)

func test_settled_confirmation_consumes_closing_back_but_not_a_fresh_back_before_deletion() -> void:
	var observer := BackObserver.new()
	host.add_child(observer)
	await _mount()
	_key(KEY_ESCAPE,true)
	assert_eq(results,[false])
	assert_eq(observer.retreats,0,"the closing Back is consumed before restoring the parent")
	assert_true(is_instance_valid(modal),"the regression exercises the deferred deletion interval")
	_key(KEY_ESCAPE,false)
	_key(KEY_ESCAPE,true)
	assert_eq(observer.retreats,1,"a distinct fresh Back can retreat the parent in the same frame")
	assert_eq(results,[false],"the settled confirmation never answers again")
	_key(KEY_ESCAPE,false)

func test_touch_confirmation_is_canceled_by_page_navigation() -> void:
	await _mount()
	var point: Vector2 = modal.confirm_button.get_global_rect().get_center()
	_touch(point,true)
	_key(KEY_PAGEDOWN,true)
	_key(KEY_PAGEDOWN,false)
	_touch(point,false)
	assert_true(results.is_empty(),"paging cannot leave the earlier touch consent armed")
	_touch(point,true)
	_touch(point,false)
	assert_eq(results,[true],"a fresh touch works after all earlier contacts release")

func test_mixed_accept_cancels_the_original_touch_and_requires_both_releases() -> void:
	await _mount()
	var point: Vector2 = modal.confirm_button.get_global_rect().get_center()
	_touch(point,true)
	_key(KEY_ENTER,true)
	_touch(point,false)
	assert_true(results.is_empty(),"a mixed Accept contact invalidates the original touch")
	_key(KEY_ENTER,false)
	assert_true(results.is_empty(),"the second contact cannot inherit the original consent")
	_key(KEY_ENTER,true)
	_key(KEY_ENTER,false)
	assert_eq(results,[true])

func test_explicit_custody_invalidation_cancels_touch_and_native_hold_through_disable_enable() -> void:
	await _mount()
	var point: Vector2 = modal.confirm_button.get_global_rect().get_center()
	for touch_input: bool in [true,false]:
		modal.confirm_button.grab_focus()
		if touch_input: _touch(point,true)
		else: _key(KEY_ENTER,true)
		modal.invalidate_pending_input()
		modal.set_process_input(false)
		modal.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_DISABLED
		modal.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_DISABLED
		modal.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_INHERITED
		modal.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_INHERITED
		modal.set_process_input(true)
		if touch_input: _touch(point,false)
		else: _key(KEY_ENTER,false)
		assert_true(results.is_empty(),"custody restoration cannot re-arm an old contact")
	modal.confirm_button.grab_focus()
	_key(KEY_ENTER,true)
	_key(KEY_ENTER,false)
	assert_eq(results,[true],"fresh native Accept remains usable after cancellation")

func test_hiding_and_showing_confirmation_does_not_revive_pending_touch() -> void:
	await _mount()
	var point: Vector2 = modal.confirm_button.get_global_rect().get_center()
	_touch(point,true)
	modal.hide()
	modal.show()
	_touch(point,false)
	assert_true(results.is_empty())
	_touch(point,true)
	_touch(point,false)
	assert_eq(results,[true])
