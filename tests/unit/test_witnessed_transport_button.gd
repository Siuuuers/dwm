extends GutTest

const BUTTON := preload("res://scripts/ui/witnessed/WitnessedTransportButton.gd")
const MANAGER := preload("res://autoload/InputManager.gd")
const HANDLE := {"generation": 1, "handle_id": "transport-fixture-1",
	"holder": &"transport_fixture", "reason": &"universal_pause"}

class Admission extends RefCounted:
	var admitted := true
	func is_admitted() -> bool: return admitted

class ReleaseProbe extends Node:
	var releases := 0
	func _unhandled_input(event: InputEvent) -> void:
		if event is InputEventKey and not event.pressed and event.is_action(&"ui_accept"):
			releases += 1

var _viewport: SubViewport
var _manager: Node
var _button
var _other: Button
var _admission: Admission
var _release_probe: ReleaseProbe
var _activated := 0
var _old_process_mode: int


func before_each() -> void:
	_old_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	_activated = 0
	_viewport = SubViewport.new()
	_viewport.size = Vector2i(640, 360)
	_viewport.handle_input_locally = true
	add_child(_viewport)
	_manager = MANAGER.new()
	_viewport.add_child(_manager)
	_release_probe = ReleaseProbe.new()
	_viewport.add_child(_release_probe)
	_button = BUTTON.new()
	_button.position = Vector2(100, 100)
	_button.size = Vector2(200, 64)
	_button.focus_mode = Control.FOCUS_ALL
	_button.text = "Skip"
	_viewport.add_child(_button)
	_other = Button.new()
	_other.position = Vector2(320, 100)
	_other.size = Vector2(160, 64)
	_other.focus_mode = Control.FOCUS_ALL
	_viewport.add_child(_other)
	_admission = Admission.new()
	assert_true(_button.bind_admission(_admission.is_admitted, _manager))
	_button.activated.connect(func(): _activated += 1)
	var deadline := Time.get_ticks_msec() + 1000
	for _frame: int in 60:
		if _button._admitted() or Time.get_ticks_msec() >= deadline: break
		await get_tree().process_frame
	assert_true(_button._admitted(), "the real mounted button reaches its source-admitted boundary")


func after_each() -> void:
	get_tree().paused = false
	_viewport.free()
	process_mode = _old_process_mode


func _key(pressed: bool, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.physical_keycode = KEY_ENTER
	event.pressed = pressed
	event.echo = echo
	return event


func _joy(pressed: bool) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = JOY_BUTTON_A
	event.pressed = pressed
	return event


func _mouse(pressed: bool, point: Vector2 = Vector2(140, 132)) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = point
	event.pressed = pressed
	return event


func _touch(pressed: bool, index: int = 3, point: Vector2 = Vector2(140, 132)) -> InputEventScreenTouch:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = point
	event.pressed = pressed
	return event


func _action(pressed: bool) -> InputEventAction:
	var event := InputEventAction.new()
	event.action = &"ui_accept"
	event.pressed = pressed
	return event


func _push(event: InputEvent) -> void:
	_viewport.push_input(event, true)


func test_programmatic_pressed_is_inert_and_native_action_is_generation_bound() -> void:
	_button.pressed.emit()
	assert_eq(_activated, 0, "Button.pressed is never command admission")
	var stale_generation: int = _button._generation
	_button.retire_input()
	await get_tree().process_frame
	_button._on_accessibility_click(null, stale_generation)
	assert_eq(_activated, 0, "a queued native action cannot cross retirement")
	_admission.admitted = false
	_button._on_accessibility_click(null, _button._generation)
	assert_eq(_activated, 0, "native action uses the same source admission")
	_admission.admitted = true
	_button._on_accessibility_click(null, _button._generation)
	assert_eq(_activated, 1)
	_button._on_accessibility_click(null, stale_generation + 1)
	assert_eq(_activated, 1, "the accepted native action retires its generation")


func test_real_keyboard_controller_mouse_and_touch_each_activate_once() -> void:
	print("TRANSPORT_UI_ACCEPT_MAP ", InputMap.action_get_events(&"ui_accept").map(func(event: InputEvent) -> String: return event.as_text()))
	_button.grab_focus()
	for sample: Dictionary in [
		{"label": "keyboard", "events": [_key(true), _key(false)]},
		{"label": "controller", "events": [_joy(true), _joy(false)]},
		{"label": "mouse", "events": [_mouse(true), _mouse(false)]},
		{"label": "touch", "events": [_touch(true), _touch(false)]},
	]:
		await get_tree().process_frame
		_button.grab_focus()
		var before := _activated
		var events: Array = sample.events
		if sample.label == "keyboard":
			assert_true(events[0].is_action(&"ui_accept"), "keyboard press maps to ui_accept")
			assert_true(events[1].is_action(&"ui_accept"), "keyboard release maps to ui_accept")
		elif sample.label == "controller":
			var configured := StringName(ProjectSettings.get_setting(
				"dialogic/text/input_action", "dialogic_default_action"))
			assert_true(events[0].is_action(configured), "controller press maps to configured caption Accept")
			assert_true(events[1].is_action(configured), "controller release maps to configured caption Accept")
		_push(events[0])
		_push(events[1])
		assert_eq(_activated, before + 1, "%s activates exactly once" % sample.label)


func test_logical_input_action_is_not_physical_activation_proof() -> void:
	_button.grab_focus()
	assert_true(_action(true).is_action(&"ui_accept"))
	_push(_action(true))
	_push(_action(false))
	assert_eq(_activated, 0)


func test_release_begun_on_another_focus_owner_is_not_consumed() -> void:
	_other.grab_focus()
	_push(_key(true))
	_button.grab_focus()
	_push(_key(false))
	assert_eq(_activated, 0)
	assert_eq(_release_probe.releases, 1, "an unowned release remains visible to source cleanup")


func test_duplicate_focus_loss_drag_and_multiple_contacts_cannot_finish_stale_candidates() -> void:
	_button.grab_focus()
	_push(_key(true))
	_push(_key(true))
	_push(_key(false))
	assert_eq(_activated, 1, "a duplicate press cannot create a second activation")
	await get_tree().process_frame
	_button.grab_focus()
	_push(_key(true))
	_other.grab_focus()
	_push(_key(false))
	assert_eq(_activated, 1, "focus loss retires the armed key")
	await get_tree().process_frame
	_push(_mouse(true))
	var motion := InputEventMouseMotion.new()
	motion.position = Vector2(360, 132)
	motion.relative = Vector2(220, 0)
	_push(motion)
	_push(_mouse(false, Vector2(360, 132)))
	assert_eq(_activated, 1, "pointer motion outside the button cancels its press")
	await get_tree().process_frame
	_button.grab_focus()
	_push(_key(true))
	_push(_joy(true))
	_push(_key(false))
	_push(_joy(false))
	assert_eq(_activated, 1, "two simultaneous physical contacts retire the candidate")


func test_pause_resume_with_a_held_contact_requires_release_then_a_fresh_edge() -> void:
	_button.grab_focus()
	_push(_key(true))
	assert_true(_manager.begin_suspend(HANDLE).ok)
	get_tree().paused = true
	assert_true(_manager.resume(HANDLE).ok)
	get_tree().paused = false
	await get_tree().process_frame
	_push(_key(false))
	assert_eq(_activated, 0)
	await get_tree().process_frame
	_button.grab_focus()
	_push(_key(true))
	_push(_key(false))
	assert_eq(_activated, 1, "only the fresh post-resume contact activates")


func test_native_action_requires_neutral_physical_contacts() -> void:
	var held := _key(true)
	_manager.observe_physical_contact(held)
	_button._on_accessibility_click(null, _button._generation)
	assert_eq(_activated, 0)
	_manager.observe_physical_contact(_key(false))
	await get_tree().process_frame
	_button._on_accessibility_click(null, _button._generation)
	assert_eq(_activated, 1)
