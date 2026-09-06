extends "res://addons/gut/test.gd"
## Real profile/input/storage owners. Disk is in-memory; the global InputMap is restored.
const PROFILE := preload("res://autoload/ProfileManager.gd")
const INPUT := preload("res://autoload/InputManager.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
var _input_backup: Dictionary = {}

func before_each() -> void:
	_input_backup.clear()
	for action: StringName in InputMap.get_actions():
		_input_backup[action] = {"deadzone": InputMap.action_get_deadzone(action), "events": InputMap.action_get_events(action).duplicate(true)}

func after_each() -> void:
	for action: StringName in InputMap.get_actions():
		if not _input_backup.has(action): InputMap.erase_action(action)
	for action: StringName in _input_backup:
		if not InputMap.has_action(action): InputMap.add_action(action)
		InputMap.action_set_deadzone(action, _input_backup[action].deadzone)
		InputMap.action_erase_events(action)
		for event: InputEvent in _input_backup[action].events:
			InputMap.action_add_event(action, event)

func _fixture() -> Dictionary:
	var ops := FILES.new()
	var storage := STORAGE.new("settings-controls.memory", ops)
	var profile := PROFILE.new()
	add_child_autofree(profile)
	assert_true(profile.initialize(storage).get("ok", false))
	var input := INPUT.new()
	add_child_autofree(input)
	assert_true(input.initialize(profile).get("ok", false))
	return {"profile": profile, "input": input, "ops": ops, "storage": storage}

func _customize(profile: Node) -> void:
	var candidate: Dictionary = profile.get_profile_snapshot()
	candidate.controls_bindings.game_quick_save.keyboard.physical_keycode = KEY_F6
	candidate.controls_bindings.game_quick_load.keyboard.physical_keycode = KEY_F10
	candidate.controls_bindings.game_toggle_board_mode.controller.button_index = JOY_BUTTON_PADDLE1
	candidate.input_mappings = SCHEMA._default_input_mappings()
	candidate.input_mappings.game_open_log = [{"kind": "joypad_button", "button_index": JOY_BUTTON_X, "device": 4}]
	candidate.preferences.audio.music_volume = 0.37
	candidate.preferences.dark_mode.available = true
	candidate.preferences.dark_mode.next_run_enabled = true
	candidate.gallery_unlocks = ["ending.alone"]
	candidate.gallery_transaction_receipts = {"ending-retained": {"ending_id": "ending.alone", "unlocked": true}}
	candidate.visited_line_ids = ["opening.controls.retained"]
	assert_true(profile.commit_prepared_profile(candidate).get("ok", false))

func _live_map() -> Dictionary:
	var result := {}
	for action: String in SCHEMA.make_defaults().controls_bindings:
		result[action] = []
		for event: InputEvent in InputMap.action_get_events(action):
			if event is InputEventKey:
				result[action].append({"kind": "key", "physical_keycode": event.physical_keycode, "keycode": event.keycode, "shift": event.shift_pressed, "alt": event.alt_pressed, "ctrl": event.ctrl_pressed, "meta": event.meta_pressed})
			elif event is InputEventJoypadButton:
				result[action].append({"kind": "joypad_button", "button_index": event.button_index, "device": event.device})
	return result

func _array_map(bindings: Dictionary) -> Dictionary:
	var result := {}
	for action: String in bindings:
		result[action] = [bindings[action].keyboard, bindings[action].controller]
	return result

func test_valid_reset_preserves_every_other_profile_field_and_persists_on_reload() -> void:
	var f := _fixture()
	_customize(f.profile)
	var before: Dictionary = f.profile.get_profile_snapshot()
	var expected := before.duplicate(true)
	expected.controls_bindings = SCHEMA.make_defaults().controls_bindings
	var revision: int = f.profile.get_profile_revision()
	var summaries: Array = []
	f.profile.profile_reset.connect(func(section: StringName) -> void: summaries.append(section))
	assert_true(f.profile.reset_controls(revision).get("ok", false))
	assert_eq(f.profile.get_profile_snapshot(), expected)
	assert_eq(_live_map(), _array_map(expected.controls_bindings))
	assert_eq(f.profile.get_profile_revision(), revision + 1)
	assert_eq(summaries, [&"controls"])
	var reloaded := PROFILE.new()
	add_child_autofree(reloaded)
	assert_true(reloaded.initialize(f.storage).get("ok", false))
	assert_eq(reloaded.get_profile_snapshot(), expected)

func test_every_binding_listener_sees_complete_committed_multi_action_map() -> void:
	var f := _fixture()
	_customize(f.profile)
	var observed: Array = []
	f.input.input_bindings_changed.connect(func() -> void:
		observed.append(_live_map())
		assert_eq(_live_map(), f.profile.get_input_mappings()))
	assert_true(f.profile.reset_controls(f.profile.get_profile_revision()).get("ok", false))
	assert_eq(observed.size(), 1, "One publication installs the complete multi-action map")
	for snapshot: Dictionary in observed:
		assert_eq(snapshot, _array_map(SCHEMA.make_defaults().controls_bindings))

func test_stale_reset_changes_neither_disk_profile_nor_live_input() -> void:
	var f := _fixture()
	_customize(f.profile)
	var revision: int = f.profile.get_profile_revision()
	assert_true(f.profile.mark_line_visited("opening.controls.newer").get("ok", false))
	var before: Dictionary = f.profile.get_profile_snapshot()
	var live := _live_map()
	var disk: Dictionary = f.ops.snapshot_persisted()
	var operations: int = f.ops.operation_count()
	var signals: Array = []
	f.input.input_bindings_changed.connect(func() -> void: signals.append(true))
	assert_eq(f.profile.reset_controls(revision).get("code"), &"profile_revision_changed")
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(_live_map(), live)
	assert_eq(f.ops.snapshot_persisted(), disk)
	assert_eq(f.ops.operation_count(), operations)
	assert_true(signals.is_empty())

func test_persistence_refusal_preserves_prior_live_input_and_revision() -> void:
	var f := _fixture()
	_customize(f.profile)
	var before: Dictionary = f.profile.get_profile_snapshot()
	var live := _live_map()
	var disk: Dictionary = f.ops.snapshot_persisted()
	var revision: int = f.profile.get_profile_revision()
	var signals: Array = []
	f.input.input_bindings_changed.connect(func() -> void: signals.append(true))
	f.ops.fail_after(f.ops.operation_count() + 1)
	assert_false(f.profile.reset_controls(revision).get("ok", true))
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(_live_map(), live)
	assert_eq(f.ops.snapshot_persisted(), disk)
	assert_true(signals.is_empty())

func test_detached_candidate_has_only_registered_defaults_and_does_not_commit() -> void:
	var f := _fixture()
	_customize(f.profile)
	var before: Dictionary = f.profile.get_profile_snapshot()
	var revision: int = f.profile.get_profile_revision()
	var prepared: Dictionary = f.profile._prepare_controls_reset()
	assert_true(prepared.get("ok", false))
	assert_eq(prepared.value.controls_bindings, SCHEMA.make_defaults().controls_bindings)
	assert_eq(prepared.value.input_mappings, before.input_mappings, "Legacy provenance is not a reset target")
	prepared.value.controls_bindings.game_quick_save.clear()
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_true(f.profile.reset_controls().get("ok", false), "Unbound legacy-style calls remain supported")

func _key(code: int) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = code
	return event

func _pad(button: int, device: int) -> InputEventJoypadButton:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = device
	return event

func test_rebind_keeps_other_device_and_reloads_both_slots() -> void:
	var f := _fixture()
	_customize(f.profile)
	var before: Dictionary = f.profile.get_profile_snapshot()
	var expected := before.duplicate(true)
	expected.controls_bindings.game_quick_save.controller = {"kind": "joypad_button", "button_index": JOY_BUTTON_PADDLE2, "device": -1}
	assert_true(f.input.rebind_action("game_quick_save", _pad(JOY_BUTTON_PADDLE2, 7)).get("ok", false))
	assert_eq(f.profile.get_profile_snapshot(), expected, "Controller capture keeps the keyboard and unrelated profile data")
	assert_eq(_live_map(), _array_map(expected.controls_bindings))
	expected.controls_bindings.game_quick_save.keyboard.physical_keycode = KEY_F7
	var event := _key(KEY_F7)
	assert_true(f.input.rebind_action("game_quick_save", event).get("ok", false))
	assert_eq(f.profile.get_profile_snapshot(), expected, "Keyboard capture keeps the semantic controller slot")
	assert_eq(_live_map(), _array_map(expected.controls_bindings))
	var reloaded := PROFILE.new()
	add_child_autofree(reloaded)
	assert_true(reloaded.initialize(f.storage).get("ok", false))
	assert_eq(reloaded.get_profile_snapshot(), expected)

func test_controller_rebind_matches_any_connected_device_without_changing_event() -> void:
	var f := _fixture()
	var event := _pad(JOY_BUTTON_PADDLE1, 9)
	assert_true(f.input.rebind_action("game_quick_save", event).get("ok", false))
	assert_eq(event.device, 9, "Do not mutate the caller's event")
	var events := InputMap.action_get_events("game_quick_save")
	assert_eq(events.size(), 2)
	for device in [0, 3, 19]:
		var pressed := _pad(JOY_BUTTON_PADDLE1, device)
		pressed.pressed = true
		assert_true(pressed.is_action_pressed("game_quick_save"), "Semantic binding follows the controller position after reconnection")

func test_pending_multi_event_import_cannot_be_activated_by_one_row_rebind() -> void:
	var f := _fixture()
	var candidate: Dictionary = f.profile.get_profile_snapshot()
	candidate.input_mappings = SCHEMA._default_input_mappings()
	var first_key: Dictionary = candidate.input_mappings.game_quick_save[0].duplicate(true)
	var second_key := first_key.duplicate(true)
	second_key.physical_keycode = KEY_F6
	var pads := [{"kind": "joypad_button", "button_index": JOY_BUTTON_X, "device": 4}, {"kind": "joypad_button", "button_index": JOY_BUTTON_Y, "device": 6}]
	candidate.input_mappings.game_quick_save = [pads[0], first_key, pads[1], second_key]
	candidate.controls_import_pending = true
	assert_true(f.profile.commit_prepared_profile(candidate).get("ok", false))
	assert_eq(f.profile.get_input_mappings(), {})
	assert_false(f.input.rebind_action("game_quick_save", _key(KEY_F7)).get("ok", true))
	assert_eq(f.profile.get_profile_snapshot(), candidate)
	assert_eq(f.profile.prepare_controls_change("game_quick_save", "keyboard", first_key).code, &"controls_import_required")
	assert_true(f.profile.reset_controls(f.profile.get_profile_revision()).ok)
	assert_eq(f.profile.get_profile_snapshot().input_mappings, candidate.input_mappings, "Complete original records survive resolution through Restore")
	assert_false(f.profile.get_profile_snapshot().controls_import_pending)
	assert_eq(_live_map(), _array_map(SCHEMA.make_defaults().controls_bindings))

func test_rebind_persistence_failure_keeps_both_slots_and_emits_no_publication() -> void:
	var f := _fixture()
	assert_true(f.input.rebind_action("game_quick_save", _pad(JOY_BUTTON_PADDLE1, 0)).get("ok", false))
	var before: Dictionary = f.profile.get_profile_snapshot()
	var disk: Dictionary = f.ops.snapshot_persisted()
	var live := _live_map()
	var revision: int = f.profile.get_profile_revision()
	var signals: Array = []
	f.input.input_bindings_changed.connect(func() -> void: signals.append(true))
	f.ops.fail_after(f.ops.operation_count() + 1)
	assert_false(f.input.rebind_action("game_quick_save", _key(KEY_F7)).get("ok", true))
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(f.profile.get_profile_revision(), revision)
	assert_eq(f.ops.snapshot_persisted(), disk)
	assert_eq(_live_map(), live)
	assert_true(signals.is_empty())

func test_invalid_rebinding_never_reaches_storage_or_changes_navigation() -> void:
	var f := _fixture()
	var before: Dictionary = f.profile.get_profile_snapshot()
	var live := _live_map()
	var navigation := InputMap.action_get_events("ui_cancel").duplicate(true)
	var operations: int = f.ops.operation_count()
	for event in [InputEventKey.new(), _pad(-1, 0), _pad(JOY_BUTTON_SDL_MAX, 0), _pad(JOY_BUTTON_MAX - 1, 0), _pad(JOY_BUTTON_MAX, 0), InputEventMouseButton.new(), null]:
		assert_false(f.input.rebind_action("game_quick_save", event).get("ok", true))
	assert_false(f.input.rebind_action("ui_cancel", _key(KEY_F7)).get("ok", true))
	assert_eq(f.profile.get_profile_snapshot(), before)
	assert_eq(_live_map(), live)
	assert_eq(f.ops.operation_count(), operations)
	assert_eq(InputMap.action_get_events("ui_cancel"), navigation)
