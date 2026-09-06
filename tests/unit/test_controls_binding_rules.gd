extends "res://addons/gut/test.gd"
const RULES := preload("res://scripts/settings/ControlsBindingRules.gd")

func _key(code: int) -> Dictionary:
	return {"kind": "key", "physical_keycode": code, "keycode": 0, "shift": false, "alt": false, "ctrl": false, "meta": false}

func test_defaults_validate_and_reads_are_detached() -> void:
	var bindings := RULES.defaults()
	assert_true(RULES.validate(bindings).ok)
	bindings.game_quick_save.keyboard.physical_keycode = KEY_F6
	assert_eq(RULES.defaults().game_quick_save.keyboard.physical_keycode, KEY_F5)

func test_invalid_inventory_and_slot_shapes_fail_without_mutating_input() -> void:
	var missing := RULES.defaults()
	missing.erase("game_quick_load")
	var extra := RULES.defaults()
	extra.unknown = extra.game_quick_load.duplicate(true)
	var missing_slot := RULES.defaults()
	missing_slot.game_quick_save.erase("controller")
	var extra_slot := RULES.defaults()
	extra_slot.game_quick_save.mouse = {}
	var wrong_slot := RULES.defaults()
	wrong_slot.game_quick_save.keyboard = []
	for bindings in [missing, extra, missing_slot, extra_slot, wrong_slot, [], null]:
		var before: Variant = bindings.duplicate(true) if bindings is Dictionary else bindings
		var checked := RULES.validate(bindings)
		assert_false(checked.ok)
		assert_ne(checked.code, &"not_implemented")
		assert_eq(bindings, before)

func test_keyboard_shape_codes_and_unarbitrated_modifiers_are_refused() -> void:
	var bad_records: Array = [_key(0), _key(-1), _key(0x7fffffff)]
	for field in ["kind", "physical_keycode", "keycode", "shift", "alt", "ctrl", "meta"]:
		var missing := _key(KEY_F6)
		missing.erase(field)
		bad_records.append(missing)
	var logical := _key(KEY_F6)
	logical.keycode = KEY_F6
	bad_records.append(logical)
	var chord := _key(KEY_ENTER)
	chord.ctrl = true
	bad_records.append(chord)
	var masked := _key(KEY_F6 | KEY_MASK_CTRL)
	bad_records.append(masked)
	var float_code := _key(KEY_F6)
	float_code.physical_keycode = float(KEY_F6)
	bad_records.append(float_code)
	for binding in bad_records:
		var bindings := RULES.defaults()
		bindings.game_quick_save.keyboard = binding
		assert_false(RULES.validate(bindings).ok)

func test_protected_navigation_cannot_be_displaced() -> void:
	for code in [KEY_ENTER, KEY_KP_ENTER, KEY_ESCAPE, KEY_TAB, KEY_UP, KEY_DOWN, KEY_LEFT, KEY_RIGHT, KEY_HOME, KEY_END, KEY_PAGEUP, KEY_PAGEDOWN, KEY_SHIFT, KEY_CTRL, KEY_ALT, KEY_META]:
		var result := RULES.propose(RULES.defaults(), "game_quick_save", "keyboard", _key(code), 3)
		assert_false(result.ok)
		assert_eq(result.code, &"protected_binding")

func test_controller_records_are_semantic_and_navigation_is_protected() -> void:
	for button in [JOY_BUTTON_A, JOY_BUTTON_B, JOY_BUTTON_DPAD_UP, JOY_BUTTON_DPAD_DOWN, JOY_BUTTON_DPAD_LEFT, JOY_BUTTON_DPAD_RIGHT, JOY_BUTTON_LEFT_SHOULDER, JOY_BUTTON_RIGHT_SHOULDER, JOY_BUTTON_BACK, JOY_BUTTON_START, JOY_BUTTON_GUIDE]:
		var bindings := RULES.defaults()
		bindings.game_quick_save.controller.button_index = button
		assert_eq(RULES.validate(bindings).code, &"protected_binding")
	for mutation in [{"device": 4}, {"device": -2}, {"button_index": -1}, {"button_index": JOY_BUTTON_SDL_MAX}, {"button_index": JOY_BUTTON_MAX - 1}, {"button_index": JOY_BUTTON_MAX}, {"button_index": 2.0}, {"kind": "key"}, {"extra": true}]:
		var bindings := RULES.defaults()
		bindings.game_quick_save.controller.merge(mutation, true)
		assert_false(RULES.validate(bindings).ok)

func test_direct_proposal_preserves_other_slots_before_map_and_revision() -> void:
	var before := RULES.defaults()
	var expected := before.duplicate(true)
	expected.game_quick_save.keyboard = _key(KEY_F6)
	var result := RULES.propose(before, "game_quick_save", "keyboard", _key(KEY_F6), 17)
	assert_true(result.ok)
	if not result.ok: return
	assert_true(result.value.can_commit)
	assert_eq(result.value.operation, &"rebind")
	assert_eq(result.value.revision, 17)
	assert_eq(result.value.conflicts, [])
	assert_eq(result.value.before, before)
	assert_eq(result.value.after, expected)
	result.value.before.game_quick_save.keyboard.physical_keycode = KEY_F7
	result.value.after.game_quick_load.controller.device = 7
	assert_eq(before, RULES.defaults(), "The proposal owns detached before/after snapshots")

func test_single_conflict_swap_validates_entire_result() -> void:
	var before := RULES.defaults()
	var expected := before.duplicate(true)
	expected.game_quick_save.keyboard = _key(KEY_F9)
	expected.game_quick_load.keyboard = _key(KEY_F5)
	var result := RULES.propose(before, "game_quick_save", "keyboard", _key(KEY_F9), 4)
	assert_true(result.ok)
	if not result.ok: return
	assert_eq(result.value.operation, &"swap")
	assert_eq(result.value.conflicts, ["game_quick_load"])
	assert_true(result.value.can_commit)
	assert_eq(result.value.after, expected)
	assert_true(RULES.validate(result.value.after).ok)
	assert_eq(before, RULES.defaults())

func test_swap_refuses_to_push_grid_space_into_global_quick_action() -> void:
	var result := RULES.propose(RULES.defaults(), "game_new_board", "keyboard", _key(KEY_F5), 4)
	assert_true(result.ok, "The conflict can be displayed even when Swap is unavailable")
	if not result.ok: return
	assert_eq(result.value.conflicts, ["game_quick_save"])
	assert_false(result.value.can_commit)
	assert_eq(result.value.validation.code, &"protected_binding")
	assert_eq(result.value.validation.action, "game_quick_save")
	assert_eq(result.value.after.game_quick_save.keyboard.physical_keycode, KEY_SPACE, "Before/after table retains the precise rejected displacement")

func test_space_is_available_to_grid_mode_when_new_board_moves() -> void:
	var result := RULES.propose(RULES.defaults(), "game_toggle_board_mode", "keyboard", _key(KEY_SPACE), 4)
	assert_true(result.ok)
	if not result.ok: return
	assert_true(result.value.can_commit)
	assert_eq(result.value.after.game_toggle_board_mode.keyboard.physical_keycode, KEY_SPACE)
	assert_eq(result.value.after.game_new_board.keyboard.physical_keycode, KEY_F)
	assert_true(RULES.validate(result.value.after).ok)
	assert_eq(RULES.propose(RULES.defaults(), "game_quick_save", "keyboard", _key(KEY_SPACE), 4).code, &"protected_binding")

func test_same_controller_position_conflicts_without_touching_keyboard() -> void:
	var before := RULES.defaults()
	var result := RULES.propose(before, "game_quick_save", "controller", before.game_toggle_board_mode.controller, 2)
	assert_true(result.ok)
	if not result.ok: return
	assert_true(result.value.can_commit)
	assert_eq(result.value.conflicts, ["game_toggle_board_mode"])
	assert_eq(result.value.after.game_quick_save.controller.button_index, JOY_BUTTON_X)
	assert_eq(result.value.after.game_toggle_board_mode.controller.button_index, JOY_BUTTON_LEFT_STICK)
	for action in before:
		assert_eq(result.value.after[action].keyboard, before[action].keyboard)

func test_invalid_prior_map_cannot_be_partially_repaired_by_a_proposal() -> void:
	var before := RULES.defaults()
	before.game_quick_load.controller = before.game_quick_save.controller.duplicate(true)
	var result := RULES.propose(before, "game_new_board", "keyboard", _key(KEY_N), 2)
	assert_false(result.ok)
	assert_eq(result.code, &"binding_conflict")
	assert_false(result.has("value"))

func test_unknown_action_slot_and_revision_are_refused() -> void:
	assert_false(RULES.propose(RULES.defaults(), "game_hint", "keyboard", _key(KEY_H), 2).ok)
	assert_false(RULES.propose(RULES.defaults(), "game_quick_save", "mouse", {}, 2).ok)
	for revision in [-1, 2.0, true, null]:
		assert_false(RULES.propose(RULES.defaults(), "game_quick_save", "keyboard", _key(KEY_F6), revision).ok)
