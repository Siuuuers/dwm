extends "res://addons/gut/test.gd"

const MANAGER := preload("res://autoload/InputManager.gd")
const POLICY := preload("res://scripts/ui/witnessed/WitnessedAcceptInput.gd")
const ACTION := &"pause_custody_fixture_accept"
const HANDLE := {"generation": 1, "handle_id": "pause-fixture-1", "holder": &"pause_fixture", "reason": &"universal_pause"}

class Caption extends DialogicNode_DialogText:
	# Keep native Control input/focus and text geometry; no global Dialogic reveal owner.
	func _ready() -> void:
		pass
	func _process(_delta: float) -> void:
		pass

class Executor extends RefCounted:
	var accepted := 0
	var input_was_mouse_input := false
	func handle_input() -> void:
		accepted += 1

class Runtime extends Node:
	signal dialogic_paused()
	var paused := false
	var inputs := Executor.new()
	func get_subsystem(_name: String) -> Object:
		return inputs

var _viewport: SubViewport
var _manager: Node
var _policy: Node
var _runtime: Runtime
var _caption: Caption
var _old_action: Variant
var _old_process_mode: int

func before_each() -> void:
	_old_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	_old_action = ProjectSettings.get_setting("dialogic/text/input_action")
	ProjectSettings.set_setting("dialogic/text/input_action", ACTION)
	InputMap.add_action(ACTION)
	var key := InputEventKey.new()
	key.physical_keycode = KEY_F8
	InputMap.action_add_event(ACTION, key)
	var joy := InputEventJoypadButton.new()
	joy.button_index = JOY_BUTTON_A
	InputMap.action_add_event(ACTION, joy)
	_viewport = SubViewport.new()
	_viewport.process_mode = Node.PROCESS_MODE_PAUSABLE
	_viewport.size = Vector2i(400, 240)
	_viewport.handle_input_locally = true
	add_child(_viewport)
	_manager = MANAGER.new()
	_viewport.add_child(_manager)

func after_each() -> void:
	get_tree().paused = false
	_viewport.free()
	Input.action_release(ACTION)
	InputMap.erase_action(ACTION)
	ProjectSettings.set_setting("dialogic/text/input_action", _old_action)
	process_mode = _old_process_mode

func _mount_source() -> void:
	_runtime = Runtime.new()
	_viewport.add_child(_runtime)
	var scroll := ScrollContainer.new()
	scroll.size = Vector2(320, 120)
	_viewport.add_child(scroll)
	_caption = Caption.new()
	_caption.text = "A source caption with no semantic command fixture."
	_caption.custom_minimum_size = Vector2(300, 100)
	_caption.focus_mode = Control.FOCUS_ALL
	_caption.mouse_filter = Control.MOUSE_FILTER_STOP
	scroll.add_child(_caption)
	_policy = POLICY.new()
	_viewport.add_child(_policy)
	assert_true(_policy.bind_input_custody(_manager))
	_policy.bind(_caption, scroll, _runtime)
	_caption.gui_input.connect(_policy.handle_caption_gui_input)
	_caption.grab_focus()

func _event(kind: String, pressed: bool) -> InputEvent:
	if kind == "key":
		var event := InputEventKey.new()
		event.physical_keycode = KEY_F8
		event.pressed = pressed
		return event
	if kind == "joy":
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_A
		event.pressed = pressed
		return event
	if kind == "touch":
		var event := InputEventScreenTouch.new()
		event.index = 3
		event.position = Vector2(40, 40)
		event.pressed = pressed
		return event
	if kind == "action":
		var event := InputEventAction.new()
		event.action = ACTION
		event.pressed = pressed
		return event
	var event := InputEventMouseButton.new()
	event.button_index = MOUSE_BUTTON_LEFT
	event.position = Vector2(40, 40)
	event.pressed = pressed
	return event

func _push(kind: String, pressed: bool) -> void:
	_viewport.push_input(_event(kind, pressed), true)

func test_exact_handle_admission_idempotence_and_refusal_are_atomic() -> void:
	assert_eq(_manager.get_state(), {"ok": true, "code": &"ok", "value": {"state": &"Active"}})
	var expected := {"ok": true, "code": &"ok", "value": {"frontier_id": "input:pause-fixture-1"}}
	assert_eq(_manager.begin_suspend(HANDLE), expected)
	assert_eq(_manager.begin_suspend(HANDLE.duplicate(true)), expected)
	var replacement := HANDLE.duplicate(true)
	replacement.generation = 2
	assert_false(_manager.begin_suspend(replacement).ok)
	assert_false(_manager.resume(replacement).ok)
	assert_eq(_manager.get_state().value.state, &"Suspended")
	assert_eq(_manager.resume(HANDLE), {"ok": true, "code": &"ok", "value": {"resumed": true}})
	assert_false(_manager.resume(HANDLE).ok)
	assert_false(get_tree().paused, "InputManager never owns the SceneTree pause flag")

func test_malformed_handles_never_change_custody_or_expose_partial_values() -> void:
	var cases: Array = [null, {}, {"handle_id": "only-id"}]
	for field: String in HANDLE:
		var malformed := HANDLE.duplicate(true)
		malformed[field] = null
		cases.append(malformed)
	for patch: Dictionary in [{"generation": 0}, {"generation": true}, {"holder": "pause_fixture"}, {"reason": &"other"}, {"extra": 1}]:
		var malformed := HANDLE.duplicate(true)
		malformed.merge(patch, true)
		cases.append(malformed)
	for handle: Variant in cases:
		assert_eq(_manager.begin_suspend(handle), {"ok": false, "code": &"invalid_suspension_handle", "value": null})
		assert_eq(_manager.get_state().value.state, &"Active")

func test_native_held_contacts_require_all_releases_after_resume() -> void:
	for kind: String in ["key", "mouse", "touch", "joy", "action"]:
		_push(kind, true)
	assert_true(_manager.begin_suspend(HANDLE).ok)
	get_tree().paused = true
	assert_false(_manager.is_source_input_admitted())
	assert_true(_manager.resume(HANDLE).ok)
	get_tree().paused = false
	await get_tree().process_frame
	for kind: String in ["key", "mouse", "touch", "joy"]:
		_push(kind, false)
		assert_false(_manager.is_source_input_admitted(), "remaining held contacts retain quarantine")
	_push("action", false)
	assert_true(_manager.is_source_input_admitted())

func test_release_observed_while_tree_paused_does_not_poison_fresh_input() -> void:
	_push("touch", true)
	assert_true(_manager.begin_suspend(HANDLE).ok)
	get_tree().paused = true
	_push("touch", false)
	assert_true(_manager.resume(HANDLE).ok)
	assert_false(_manager.is_source_input_admitted(), "the closing frame is consumed")
	get_tree().paused = false
	await get_tree().process_frame
	assert_true(_manager.is_source_input_admitted())

func test_source_policy_refuses_paused_and_held_contacts_then_accepts_fresh_contacts() -> void:
	_mount_source()
	await get_tree().process_frame
	for kind: String in ["mouse", "touch", "key", "joy"]:
		var before := _runtime.inputs.accepted
		assert_true(_manager.begin_suspend(HANDLE).ok)
		get_tree().paused = true
		_push(kind, true)
		assert_eq(_runtime.inputs.accepted, before)
		assert_true(_manager.resume(HANDLE).ok)
		get_tree().paused = false
		await get_tree().process_frame
		_push(kind, true)
		_push(kind, false)
		assert_eq(_runtime.inputs.accepted, before, "held " + kind + " does not become resumed Accept")
		await get_tree().process_frame
		_caption.grab_focus()
		_push(kind, true)
		_push(kind, false)
		assert_eq(_runtime.inputs.accepted, before + 1, "fresh " + kind + " activates once")
		await get_tree().process_frame

func test_pending_pointer_is_canceled_and_pause_always_button_still_operates() -> void:
	_mount_source()
	var button := Button.new()
	button.process_mode = Node.PROCESS_MODE_ALWAYS
	button.position = Vector2(0, 150)
	button.size = Vector2(150, 64)
	button.text = "Pause fixture"
	_viewport.add_child(button)
	watch_signals(button)
	await get_tree().process_frame
	_push("mouse", true)
	assert_true(_manager.begin_suspend(HANDLE).ok)
	get_tree().paused = true
	_push("mouse", false)
	for pressed: bool in [true, false]:
		var event := _event("mouse", pressed) as InputEventMouseButton
		event.position = Vector2(40, 180)
		_viewport.push_input(event, true)
	assert_signal_emit_count(button, "pressed", 1, "source custody never consumes the Pause GUI button")
	assert_true(_manager.resume(HANDLE).ok)
	get_tree().paused = false
	await get_tree().process_frame
	_push("mouse", false)
	assert_eq(_runtime.inputs.accepted, 0, "old caption press cannot finish after Pause")
