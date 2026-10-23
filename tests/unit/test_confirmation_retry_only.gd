extends GutTest

const CONFIRMATION := preload("res://scripts/ui/desktop/DesktopConfirmation.gd")
const THEME := preload("res://scripts/ui/backup/BackupTheme.gd")

class BackObserver extends Node:
	var count := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event.is_action_pressed(&"ui_cancel"): count += 1

var viewport: SubViewport
var host: Control
var lower: Button
var modal: Control
var observer: BackObserver
var results: Array[bool] = []
var lower_commands := 0

func before_each() -> void:
	results.clear()
	lower_commands = 0
	viewport = SubViewport.new()
	viewport.size = Vector2i(800, 656)
	add_child(viewport)
	host = Control.new()
	host.size = Vector2(800, 656)
	viewport.add_child(host)
	observer = BackObserver.new()
	host.add_child(observer)
	lower = Button.new()
	lower.text = "Source action"
	lower.size = Vector2(180, 64)
	lower.position = Vector2(16, 16)
	lower.focus_behavior_recursive = Control.FOCUS_BEHAVIOR_ENABLED
	lower.mouse_behavior_recursive = Control.MOUSE_BEHAVIOR_ENABLED
	host.add_child(lower)
	lower.pressed.connect(func(): lower_commands += 1)
	lower.grab_focus()

func after_each() -> void:
	if is_instance_valid(viewport): viewport.free()
	await get_tree().process_frame

func _mount(cancelable: bool = false) -> void:
	modal = CONFIRMATION.new()
	modal.theme = THEME.build("en", 150)
	modal.request = {"title": "Recovery required", "body": "Retry the retained operation.",
		"confirm": "Retry", "cancel": "Cancel", "risk": "danger", "warning": false}
	if not cancelable: modal.request["cancelable"] = false
	modal.finished.connect(func(accepted: bool): results.append(accepted))
	host.add_child(modal)
	for frame in 3: await get_tree().process_frame

func _key(code: Key, down: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = code
	event.physical_keycode = code
	event.pressed = down
	event.echo = echo
	viewport.push_input(event, true)

func _touch(point: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 2
	event.position = point
	event.pressed = down
	viewport.push_input(event, true)

func test_retry_is_the_only_visible_focusable_neutral_action_and_navigation_stays_inside() -> void:
	await _mount()
	assert_false(modal.cancel_button.visible)
	assert_true(modal.cancel_button.disabled)
	assert_eq(modal.cancel_button.focus_mode, Control.FOCUS_NONE)
	assert_true(modal.confirm_button.has_focus())
	assert_eq(modal.confirm_button.risk, "neutral")
	assert_eq(modal.confirm_button.caption.text, "Retry")
	assert_eq(modal.theme.default_font_size, 36)
	assert_gte(modal.confirm_button.size.x, 496.0)
	assert_gte(modal.confirm_button.size.y, 64.0)
	for direction: Key in [KEY_TAB, KEY_LEFT, KEY_RIGHT]:
		_key(direction, true)
		_key(direction, false)
		assert_true(modal.confirm_button.has_focus())
	assert_true(results.is_empty())
	assert_eq(lower.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	assert_eq(lower.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED)

func test_back_and_direct_false_cannot_dismiss_or_release_lower_custody() -> void:
	await _mount()
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	modal._finish(false)
	await get_tree().process_frame
	assert_true(is_instance_valid(modal))
	assert_true(modal.is_visible_in_tree())
	assert_true(modal.confirm_button.has_focus())
	assert_eq(results, [])
	assert_eq(observer.count, 0, "Back is consumed rather than reaching the source")
	assert_eq(lower.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	assert_eq(lower.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_DISABLED)

func test_matching_native_accept_release_finishes_once_and_restores_saved_custody() -> void:
	await _mount()
	_key(KEY_ENTER, true)
	_key(KEY_ENTER, true, true)
	_key(KEY_ENTER, true)
	assert_eq(results, [])
	assert_eq(lower.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_DISABLED)
	_key(KEY_ENTER, false)
	assert_eq(results, [true])
	assert_eq(lower.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_ENABLED)
	assert_eq(lower.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_ENABLED)
	_key(KEY_ENTER, false)
	assert_eq(results, [true])
	assert_eq(lower_commands, 0)

func test_back_cancels_armed_touch_without_dismissing_then_fresh_touch_retries() -> void:
	await _mount()
	var point: Vector2 = modal.confirm_button.get_global_rect().get_center()
	_touch(point, true)
	assert_eq(results, [])
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	_touch(point, false)
	assert_eq(results, [])
	assert_true(modal.is_visible_in_tree())
	_touch(point, true)
	assert_eq(results, [])
	_touch(point, false)
	assert_eq(results, [true])
	assert_eq(lower_commands, 0)

func test_default_two_action_confirmation_retains_cancel_focus_and_back_cancellation() -> void:
	await _mount(true)
	assert_true(modal.cancel_button.visible)
	assert_true(modal.cancel_button.has_focus())
	assert_eq(modal.confirm_button.risk, "danger")
	_key(KEY_ESCAPE, true)
	_key(KEY_ESCAPE, false)
	assert_eq(results, [false])
	assert_eq(lower.focus_behavior_recursive, Control.FOCUS_BEHAVIOR_ENABLED)
	assert_eq(lower.mouse_behavior_recursive, Control.MOUSE_BEHAVIOR_ENABLED)
