extends GutTest
## Real Profile/storage publication, with the process-global InputMap restored per test.
const PROFILE := preload("res://autoload/ProfileManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const RULES := preload("res://scripts/settings/ControlsBindingRules.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const HANDLE := {"generation":1,"handle_id":"controls-publication","holder":&"pause_fixture","reason":&"universal_pause"}
var _backup: Dictionary = {}

func before_each() -> void:
	_backup.clear()
	for action: StringName in InputMap.get_actions():
		_backup[action] = {"deadzone":InputMap.action_get_deadzone(action),"events":InputMap.action_get_events(action).duplicate(true)}

func after_each() -> void:
	for action: StringName in InputMap.get_actions():
		if not _backup.has(action): InputMap.erase_action(action)
	for action: StringName in _backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action,_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _backup[action].events: InputMap.action_add_event(action,event)

func _fixture() -> Dictionary:
	var ops := FILES.new()
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(STORAGE.new("controls-publication.memory",ops)).get("ok",false))
	var input := INPUT.new()
	add_child_autofree(input)
	assert_true(input.initialize(profile).get("ok",false))
	return {"profile":profile,"input":input,"ops":ops}

func _key(code: int, pressed: bool = true) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	event.pressed = pressed
	return event

func _live_map() -> Dictionary:
	var result := {}
	for action: String in RULES.defaults():
		result[action] = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				result[action].append({"kind":"key","physical_keycode":event.physical_keycode,"keycode":event.keycode,
					"shift":event.shift_pressed,"alt":event.alt_pressed,"ctrl":event.ctrl_pressed,"meta":event.meta_pressed})
			elif event is InputEventJoypadButton:
				result[action].append({"kind":"joypad_button","button_index":event.button_index,"device":event.device})
	return result

func test_committed_multi_action_reset_is_published_once_as_a_complete_map() -> void:
	var f := _fixture()
	assert_true(f.input.rebind_action("game_quick_save",_key(KEY_F6)).ok)
	assert_true(f.input.rebind_action("game_quick_load",_key(KEY_F10)).ok)
	var observations: Array = []
	f.input.input_bindings_changed.connect(func():
		observations.append(_live_map())
		assert_eq(_live_map(),f.profile.get_input_mappings()))
	assert_true(f.profile.reset_controls(f.profile.get_profile_revision()).ok)
	assert_eq(observations.size(),1)
	assert_eq(_live_map(),f.profile.get_input_mappings())

func test_failed_binding_commit_keeps_live_slots_and_publishes_nothing() -> void:
	var f := _fixture()
	var before := _live_map()
	var profile_before: Dictionary = f.profile.get_profile_snapshot()
	var observations: Array = []
	f.input.input_bindings_changed.connect(func(): observations.append(_live_map()))
	f.ops.fail_after(f.ops.operation_count()+1)
	assert_false(f.input.rebind_action("game_quick_save",_key(KEY_F6)).ok)
	assert_eq(_live_map(),before)
	assert_eq(f.profile.get_profile_snapshot(),profile_before)
	assert_true(observations.is_empty())

func test_controller_rebind_preserves_keyboard_and_uses_any_device_position() -> void:
	var f := _fixture()
	var before := _live_map()
	var event := InputEventJoypadButton.new()
	event.device = 7
	event.button_index = JOY_BUTTON_PADDLE1
	assert_true(f.input.rebind_action("game_quick_save",event).ok)
	assert_eq(_live_map().game_quick_save[0],before.game_quick_save[0])
	assert_eq(_live_map().game_quick_save[1],{"kind":"joypad_button","button_index":JOY_BUTTON_PADDLE1,"device":-1})

func test_canonical_cutover_preserves_native_ui_and_refuses_unconfirmed_reset() -> void:
	var f := _fixture()
	for action: StringName in _backup:
		if not String(action).begins_with("ui_"): continue
		var actual := InputMap.action_get_events(action)
		assert_eq(actual.size(),_backup[action].events.size())
		for index in mini(actual.size(),_backup[action].events.size()):
			assert_eq(actual[index].as_text(),_backup[action].events[index].as_text())
	for action: String in f.input._RETIRED_GAME_ACTIONS: assert_false(InputMap.has_action(action))
	assert_eq(_live_map(),f.profile.get_input_mappings())
	var before := _live_map()
	assert_eq(f.input.reset_bindings_to_default().code,&"controls_reset_confirmation_required")
	assert_false(f.input.rebind_action("ui_accept",_key(KEY_F6)).ok)
	assert_eq(_live_map(),before)

func test_binding_publication_during_pause_preserves_physical_release_quarantine() -> void:
	var f := _fixture()
	f.input._input(_key(KEY_F5))
	assert_true(f.input.begin_suspend(HANDLE).ok)
	assert_true(f.input.rebind_action("game_quick_save",_key(KEY_F6)).ok)
	assert_false(f.input.is_source_input_admitted())
	assert_true(f.input.resume(HANDLE).ok)
	await get_tree().process_frame
	assert_false(f.input.is_source_input_admitted(),"rebinding cannot erase the old held physical contact")
	f.input._input(_key(KEY_F6,false))
	assert_false(f.input.is_source_input_admitted(),"release of the replacement mapping cannot clear the old contact")
	f.input._input(_key(KEY_F5,false))
	assert_true(f.input.is_source_input_admitted())

func test_pending_import_removes_all_live_canonical_bindings_without_inventing_defaults() -> void:
	var f := _fixture()
	var candidate: Dictionary = f.profile.get_profile_snapshot()
	candidate.input_mappings = SCHEMA._default_input_mappings()
	candidate.input_mappings.game_quick_save[0].physical_keycode = 0
	candidate.input_mappings.game_quick_save[0].keycode = KEY_F6
	candidate.controls_import_pending = true
	assert_true(f.profile.commit_prepared_profile(candidate).ok)
	assert_eq(f.profile.get_input_mappings(),{})
	for records: Array in _live_map().values(): assert_true(records.is_empty())
