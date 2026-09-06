extends GutTest

const INPUT := preload("res://autoload/InputManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const HANDLE := {"generation": 1, "handle_id": "input-contact-test", "holder": &"canonical-pause", "reason": &"universal_pause"}
var _map_backup: Dictionary = {}

func before_each() -> void:
	for action: StringName in InputMap.get_actions():
		_map_backup[action] = {"deadzone": InputMap.action_get_deadzone(action),
			"events": InputMap.action_get_events(action).duplicate(true)}

func after_each() -> void:
	for action: StringName in InputMap.get_actions():
		if not _map_backup.has(action): InputMap.erase_action(action)
	for action: StringName in _map_backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _map_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _map_backup[action].events: InputMap.action_add_event(action, event)
	_map_backup.clear()

func _manager() -> Node:
	var manager := INPUT.new()
	add_child_autofree(manager)
	return manager

func _key(code: int, pressed: bool = true, echo: bool = false) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.keycode = code
	event.pressed = pressed
	event.echo = echo
	return event

func _joy(device: int, pressed: bool = true) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.device = device
	event.button_index = JOY_BUTTON_X
	event.pressed = pressed
	return event

func test_snapshot_is_detached_and_query_does_not_create_contacts() -> void:
	var manager := _manager()
	var event := _key(KEY_F)
	var id: String = manager.get_physical_contact_id(event)
	assert_eq(id, "key:0:%s" % KEY_F)
	assert_true(manager.get_physical_contacts().is_empty())
	manager._input(event)
	var snapshot: Dictionary = manager.get_physical_contacts()
	assert_eq(typeof(snapshot[id]), TYPE_INT)
	assert_gt(snapshot[id], 0)
	var generation: int = snapshot[id]
	snapshot[id] = -1
	snapshot["invented"] = 99
	assert_eq(manager.get_physical_contacts(), {id: generation})
	snapshot.clear()
	assert_eq(manager.get_physical_contacts(), {id: generation})

func test_duplicate_press_echo_and_release_require_a_new_physical_generation() -> void:
	var manager := _manager()
	var event := _key(KEY_F)
	var id: String = manager.get_physical_contact_id(event)
	manager._input(event)
	var first: int = manager.get_physical_contacts()[id]
	manager._input(_key(KEY_F))
	manager._input(_key(KEY_F, true, true))
	assert_eq(manager.get_physical_contacts()[id], first)
	manager._input(_key(KEY_F, false))
	assert_true(manager.get_physical_contacts().is_empty())
	manager._input(_key(KEY_F, true, true))
	assert_true(manager.get_physical_contacts().is_empty(), "orphan echo cannot manufacture a fresh contact")
	manager._input(_key(KEY_F))
	assert_gt(manager.get_physical_contacts()[id], first)

func test_emulation_and_impulses_never_create_or_release_physical_contacts() -> void:
	var manager := _manager()
	var event := _key(KEY_F)
	manager._input(event)
	var before: Dictionary = manager.get_physical_contacts()
	var emulated := _key(KEY_F, false)
	emulated.device = InputEvent.DEVICE_ID_EMULATION
	assert_eq(manager.get_physical_contact_id(emulated), "")
	manager._input(emulated)
	var wheel := InputEventMouseButton.new()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.pressed = true
	assert_eq(manager.get_physical_contact_id(wheel), "")
	manager._input(wheel)
	assert_eq(manager.get_physical_contact_id(InputEventMouseMotion.new()), "")
	assert_eq(manager.get_physical_contact_id(InputEventJoypadMotion.new()), "")
	assert_eq(manager.get_physical_contact_id(null), "")
	assert_eq(manager.get_physical_contacts(), before)

func test_contact_types_and_devices_remain_distinct_and_generations_are_global() -> void:
	var manager := _manager()
	var mouse := InputEventMouseButton.new()
	mouse.button_index = MOUSE_BUTTON_LEFT
	mouse.pressed = true
	var touch := InputEventScreenTouch.new()
	touch.index = 2
	touch.pressed = true
	var action := InputEventAction.new()
	action.action = &"game_toggle_board_mode"
	action.pressed = true
	var events: Array[InputEvent] = [_key(KEY_F), mouse, touch, _joy(1), _joy(10), action]
	var previous := 0
	for event: InputEvent in events:
		manager._input(event)
		var id: String = manager.get_physical_contact_id(event)
		var generation: int = manager.get_physical_contacts()[id]
		assert_gt(generation, previous)
		previous = generation
	assert_eq(manager.get_physical_contacts().size(), events.size())
	manager._input(_joy(1, false))
	assert_false(manager.get_physical_contacts().has("joy:1:%s" % JOY_BUTTON_X))
	assert_true(manager.get_physical_contacts().has("joy:10:%s" % JOY_BUTTON_X))

func test_disconnect_cleans_only_that_device_before_notification_and_reconnect_is_fresh() -> void:
	var manager := _manager()
	manager._input(_joy(1))
	manager._input(_joy(10))
	manager._input(_key(KEY_F))
	var id: String = manager.get_physical_contact_id(_joy(1))
	var first: int = manager.get_physical_contacts()[id]
	assert_true(manager.begin_suspend(HANDLE).ok)
	assert_true(manager.resume(HANDLE).ok)
	var observed: Array = []
	manager.controller_disconnected.connect(func(device): observed.append([device, manager.get_physical_contacts(), manager._resume_quarantine.duplicate()]))
	manager._on_joy_connection_changed(1, false)
	assert_eq(observed.size(), 1)
	assert_false(observed[0][1].has(id))
	assert_false(observed[0][2].has(id))
	assert_true(observed[0][1].has("joy:10:%s" % JOY_BUTTON_X))
	assert_true(observed[0][2].has("joy:10:%s" % JOY_BUTTON_X))
	assert_false(manager.is_source_input_admitted())
	manager._on_joy_connection_changed(1, true)
	assert_false(manager.get_physical_contacts().has(id), "reconnect itself is not a press")
	manager._input(_joy(1))
	assert_gt(manager.get_physical_contacts()[id], first)

func test_pause_release_quarantine_retains_generations_and_disconnect_can_finish_neutrality() -> void:
	var manager := _manager()
	manager._input(_joy(2))
	var before: Dictionary = manager.get_physical_contacts()
	assert_true(manager.begin_suspend(HANDLE).ok)
	assert_false(manager.is_source_input_admitted())
	manager._input(_joy(2))
	assert_eq(manager.get_physical_contacts(), before)
	assert_true(manager.resume(HANDLE).ok)
	assert_eq(manager._resume_quarantine, before)
	await get_tree().process_frame
	assert_false(manager.is_source_input_admitted())
	manager._on_joy_connection_changed(2, false)
	assert_true(manager.get_physical_contacts().is_empty())
	assert_true(manager.is_source_input_admitted())

func test_real_controls_rebind_publication_retains_the_same_held_physical_generation() -> void:
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("input-contact.memory", FILES.new())).ok)
	var manager := _manager()
	assert_true(manager.initialize(profile).ok)
	manager._input(_key(KEY_F))
	var before: Dictionary = manager.get_physical_contacts()
	var snapshots: Array = []
	manager.input_bindings_changed.connect(func(): snapshots.append(manager.get_physical_contacts()))
	var binding := _key(KEY_F6)
	binding.keycode = 0 # Canonical physical binding record; native packets below carry both codes.
	var rebound: Dictionary = manager.rebind_action("game_toggle_board_mode", binding)
	assert_true(rebound.ok, str(rebound))
	if not rebound.ok: return
	assert_eq(snapshots, [before])
	assert_eq(manager.get_physical_contacts(), before)
	assert_true(_key(KEY_F6).is_action_pressed(&"game_toggle_board_mode"))
	assert_false(_key(KEY_F).is_action_pressed(&"game_toggle_board_mode"))
	manager._input(_key(KEY_F, false))
	assert_true(manager.get_physical_contacts().is_empty())
	manager._input(_key(KEY_F6))
	var id: String = manager.get_physical_contact_id(_key(KEY_F6))
	assert_gt(manager.get_physical_contacts()[id], before.values()[0])

func test_forwarded_and_parent_packets_share_one_generation_and_one_release() -> void:
	var manager := _manager()
	var press := _key(KEY_F)
	var id: String = manager.get_physical_contact_id(press)
	manager.observe_physical_contact(press)
	var first: int = manager.get_physical_contacts()[id]
	manager._input(press)
	manager.observe_physical_contact(press.duplicate())
	assert_eq(manager.get_physical_contacts()[id], first)
	manager.observe_physical_contact(_key(KEY_F, false))
	manager._input(_key(KEY_F, false))
	manager.observe_physical_contact(null)
	assert_true(manager.get_physical_contacts().is_empty())
	manager._input(_key(KEY_F))
	assert_gt(manager.get_physical_contacts()[id], first)
