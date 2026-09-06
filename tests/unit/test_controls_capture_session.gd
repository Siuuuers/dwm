extends "res://addons/gut/test.gd"
const SESSION := preload("res://scripts/settings/ControlsCaptureSession.gd")
const RULES := preload("res://scripts/settings/ControlsBindingRules.gd")
const ACTION := "game_quick_save"


func _key(code: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	event.echo = echo
	return event


func _button(button: int, device: int = 0, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = device
	event.pressed = pressed
	return event


func _mouse(button: int = MOUSE_BUTTON_LEFT, pressed: bool = true) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = pressed
	return event


func test_activation_identity_waits_for_its_release_without_inventing_input() -> void:
	var session := SESSION.new()
	assert_eq(session.begin(ACTION, "keyboard", _key(KEY_ENTER)).state, &"waiting")
	assert_eq(session.handle_event(_key(KEY_ENTER, true, true)).code, &"held_input")
	assert_eq(session.handle_event(_key(KEY_F6, false)).code, &"release_ignored")
	assert_eq(session.handle_event(_key(KEY_ENTER)).code, &"held_input")
	assert_eq(session.handle_event(_key(KEY_ENTER, false)).code, &"held_released")
	assert_true(session.is_active(), "A release cannot synthesize a candidate")
	assert_eq(session.handle_event(_key(KEY_F6, true, true)).code, &"echo_ignored")
	var result := session.handle_event(_key(KEY_F6))
	assert_eq(result.state, &"captured")
	assert_eq(result.binding.physical_keycode, KEY_F6)
	assert_false(session.is_active())


func test_held_events_are_independent_and_snapshot_physical_identity() -> void:
	var session := SESSION.new()
	var held_key := _key(KEY_F6)
	held_key.ctrl_pressed = true
	var held: Array[InputEvent] = [held_key, _button(JOY_BUTTON_X, 3), _mouse()]
	session.begin(ACTION, "keyboard", null, held)
	held.clear()
	held_key.physical_keycode = KEY_F7
	assert_eq(session.handle_event(_key(KEY_F6)).code, &"held_input")
	assert_eq(session.handle_event(_button(JOY_BUTTON_X, 4, false)).code, &"release_ignored")
	assert_eq(session.handle_event(_button(JOY_BUTTON_X, 3)).code, &"held_input")
	assert_eq(session.handle_event(_mouse(MOUSE_BUTTON_RIGHT, false)).code, &"release_ignored")
	assert_eq(session.handle_event(_mouse()).code, &"held_input")
	assert_eq(session.handle_event(_mouse(MOUSE_BUTTON_LEFT, false)).code, &"held_released")
	assert_eq(session.handle_event(_button(JOY_BUTTON_X, 3, false)).code, &"held_released")
	assert_eq(session.handle_event(_key(KEY_F6, false)).code, &"held_released")
	assert_eq(session.handle_event(_key(KEY_F6)).state, &"captured")


func test_keyboard_captures_physical_identity_and_explicit_modifiers_without_mutating_event() -> void:
	var session := SESSION.new()
	session.begin(ACTION, "keyboard")
	var event := _key(KEY_F6)
	event.keycode = KEY_Z
	event.shift_pressed = true
	event.alt_pressed = true
	event.ctrl_pressed = true
	event.meta_pressed = true
	var result := session.handle_event(event)
	assert_eq(result.binding, {"kind": "key", "physical_keycode": KEY_F6, "keycode": 0,
		"shift": true, "alt": true, "ctrl": true, "meta": true})
	assert_eq(event.physical_keycode, KEY_F6)
	assert_eq(event.keycode, KEY_Z)
	assert_true(event.ctrl_pressed)
	assert_false(RULES.propose(RULES.defaults(), ACTION, "keyboard", result.binding, 1).ok,
		"Capture reports contact; the binding rules decide whether this chord is admitted")


func test_captured_result_is_single_use_and_detached_from_later_sessions() -> void:
	var session := SESSION.new()
	session.begin(ACTION, "keyboard")
	var result := session.handle_event(_key(KEY_F6))
	result.binding.physical_keycode = KEY_F7
	result.action = "changed"
	var later := session.handle_event(_key(KEY_F8))
	assert_eq(later.code, &"inactive")
	assert_false(later.has("binding"))
	assert_eq(later.action, ACTION)
	assert_eq(session.cancel(&"depart").code, &"inactive")
	session.begin(ACTION, "keyboard")
	assert_eq(session.handle_event(_key(KEY_F6)).binding.physical_keycode, KEY_F6)


func test_back_requires_a_fresh_press_after_held_release() -> void:
	for activation in [_key(KEY_ESCAPE), _button(JOY_BUTTON_B, 2)]:
		var session := SESSION.new()
		session.begin(ACTION, "keyboard", activation)
		assert_eq(session.handle_event(activation).code, &"held_input")
		var release: InputEvent = activation.duplicate()
		release.set("pressed", false)
		assert_eq(session.handle_event(release).code, &"held_released")
		assert_true(session.is_active())
		var result := session.handle_event(activation)
		assert_eq(result.state, &"cancelled")
		assert_eq(result.code, &"back")
		assert_false(result.has("binding"))
		assert_false(session.is_active())


func test_controller_activation_pins_device_and_matching_disconnect_cancels() -> void:
	var session := SESSION.new()
	session.begin(ACTION, "controller", _button(JOY_BUTTON_A, 4))
	assert_eq(session.handle_event(_button(JOY_BUTTON_B, 5)).code, &"other_controller")
	assert_eq(session.handle_event(_button(JOY_BUTTON_X, 5)).code, &"other_controller")
	assert_eq(session.disconnect_device(5).code, &"other_device")
	assert_eq(session.handle_event(_button(JOY_BUTTON_A, 4, false)).code, &"held_released")
	var result := session.disconnect_device(4)
	assert_eq(result.state, &"cancelled")
	assert_eq(result.code, &"capture_device_disconnected")
	assert_false(session.is_active())
	assert_eq(session.handle_event(_button(JOY_BUTTON_X, 4)).code, &"inactive")


func test_controller_capture_stores_semantic_button_without_physical_device() -> void:
	for activation in [_key(KEY_ENTER), _mouse()]:
		var session := SESSION.new()
		session.begin(ACTION, "controller", activation)
		assert_eq(session.disconnect_device(7).code, &"other_device")
		var result := session.handle_event(_button(JOY_BUTTON_PADDLE4, 7))
		assert_eq(result.state, &"captured")
		assert_eq(result.binding, {"kind": "joypad_button", "button_index": JOY_BUTTON_PADDLE4, "device": -1})
		assert_eq(session.disconnect_device(7).code, &"inactive")


func test_unsupported_controller_contact_keeps_waiting_but_owns_device_until_disconnect() -> void:
	var session := SESSION.new()
	session.begin(ACTION, "controller")
	assert_eq(session.handle_event(_button(JOY_BUTTON_X, -1)).code, &"invalid_capture_device")
	assert_eq(session.handle_event(_button(JOY_BUTTON_SDL_MAX, 3)).code, &"unsupported_button")
	assert_eq(session.handle_event(_button(JOY_BUTTON_X, 4)).code, &"other_controller")
	assert_eq(session.disconnect_device(3).code, &"capture_device_disconnected")


func test_unsupported_events_and_malformed_keyboard_never_end_capture() -> void:
	var session := SESSION.new()
	session.begin(ACTION, "keyboard")
	for event in [null, InputEventMouseMotion.new(), InputEventJoypadMotion.new(), _mouse()]:
		assert_eq(session.handle_event(event).code, &"unsupported_event")
		assert_true(session.is_active())
	var logical_only := _key(0)
	logical_only.keycode = KEY_F6
	for event in [logical_only, _key(0), _key(KEY_F6 | KEY_MASK_CTRL), _key(0x7fffffff)]:
		assert_eq(session.handle_event(event).code, &"unsupported_key")
		assert_true(session.is_active())
	assert_eq(session.handle_event(_button(JOY_BUTTON_X)).code, &"other_input_slot")
	assert_eq(session.handle_event(_key(KEY_F6, false)).code, &"release_ignored")
	assert_eq(session.cancel(&"depart").code, &"depart")


func test_other_slot_is_ignored_except_explicit_back() -> void:
	var session := SESSION.new()
	session.begin(ACTION, "controller")
	assert_eq(session.handle_event(_key(KEY_F6)).code, &"other_input_slot")
	assert_eq(session.handle_event(_key(KEY_ESCAPE)).code, &"back")
	session.begin(ACTION, "keyboard")
	assert_eq(session.handle_event(_button(JOY_BUTTON_B)).code, &"back")


func test_registration_and_overlapping_begin_cannot_replace_live_capture() -> void:
	var session := SESSION.new()
	assert_eq(session.begin("invented_action", "keyboard").code, &"unknown_action")
	assert_false(session.is_active())
	assert_eq(session.begin(ACTION, "mouse").code, &"invalid_slot")
	assert_false(session.is_active())
	session.begin(ACTION, "keyboard", _key(KEY_ENTER))
	var overlap := session.begin("game_quick_load", "controller")
	assert_eq(overlap.code, &"already_active")
	assert_eq(overlap.action, ACTION)
	assert_eq(overlap.slot, "keyboard")
	assert_eq(session.handle_event(_key(KEY_ENTER)).code, &"held_input")
	assert_eq(session.handle_event(_key(KEY_F6)).state, &"captured",
		"Only already-held identities are barred; a genuinely fresh different input is admitted")


func test_protected_navigation_candidate_remains_subject_to_owner_rules() -> void:
	var session := SESSION.new()
	session.begin(ACTION, "keyboard")
	var result := session.handle_event(_key(KEY_TAB))
	assert_eq(result.state, &"captured")
	assert_eq(RULES.propose(RULES.defaults(), ACTION, "keyboard", result.binding, 1).code, &"protected_binding")
