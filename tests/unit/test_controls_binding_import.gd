extends "res://addons/gut/test.gd"
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const IMPORT := preload("res://scripts/settings/ControlsBindingImport.gd")
const RULES := preload("res://scripts/settings/ControlsBindingRules.gd")
const JSON_RULES := preload("res://scripts/validation/JsonSchemaValidator.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")


func _key(code: int) -> Dictionary:
	return {"kind": "key", "physical_keycode": code, "keycode": 0, "shift": false, "alt": false, "ctrl": false, "meta": false}


func _pad(button: int, device: int = -1) -> Dictionary:
	return {"kind": "joypad_button", "button_index": button, "device": device}


func _profile_with_mappings() -> Dictionary:
	var profile := SCHEMA.make_defaults()
	profile.input_mappings = SCHEMA._default_input_mappings()
	return profile


func test_fresh_profile_is_v10_without_manufactured_legacy_provenance() -> void:
	var profile := SCHEMA.make_defaults()
	assert_eq(profile.schema_version, 10)
	assert_eq(profile.displayed_artwork_ids, [])
	assert_eq(profile.input_mappings, {})
	assert_false(profile.controls_import_pending)
	assert_eq(profile.controls_bindings, RULES.defaults())
	assert_true(SCHEMA.validate(profile).ok)


func test_cross_swapped_imports_validate_after_all_transfers() -> void:
	var source := _profile_with_mappings()
	source.input_mappings.game_quick_save = [_key(KEY_F9), _pad(JOY_BUTTON_RIGHT_STICK)]
	source.input_mappings.game_quick_load = [_key(KEY_F5), _pad(JOY_BUTTON_LEFT_STICK)]
	var before := source.duplicate(true)
	var imported := IMPORT.prepare(source.input_mappings)
	assert_false(imported.pending)
	assert_eq(imported.issues, [])
	assert_eq(imported.bindings.game_quick_save.keyboard, _key(KEY_F9))
	assert_eq(imported.bindings.game_quick_load.keyboard, _key(KEY_F5))
	assert_eq(imported.bindings.game_quick_save.controller, _pad(JOY_BUTTON_RIGHT_STICK))
	assert_eq(imported.bindings.game_quick_load.controller, _pad(JOY_BUTTON_LEFT_STICK))
	assert_true(RULES.validate(imported.bindings).ok)
	assert_eq(source, before)


func test_missing_slots_use_defaults_without_replacing_existing_n() -> void:
	var source := _profile_with_mappings()
	source.input_mappings.game_quick_save = []
	source.input_mappings.game_quick_load = [_pad(JOY_BUTTON_RIGHT_STICK)]
	var imported := IMPORT.prepare(source.input_mappings)
	assert_false(imported.pending)
	assert_eq(imported.bindings.game_quick_save, RULES.defaults().game_quick_save)
	assert_eq(imported.bindings.game_quick_load, RULES.defaults().game_quick_load)
	assert_eq(imported.bindings.game_new_board.keyboard, _key(KEY_N))
	assert_eq(imported.bindings.game_toggle_board_mode, RULES.defaults().game_toggle_board_mode)


func test_unsupported_records_preserve_source_and_make_entire_import_pending() -> void:
	var logical := _key(0)
	logical.keycode = KEY_F6
	var both := _key(KEY_F6)
	both.keycode = KEY_F6
	var modified := _key(KEY_F6)
	modified.ctrl = true
	for record in [logical, both, modified, _key(0), _key(KEY_ENTER), _pad(JOY_BUTTON_LEFT_STICK, 4), _pad(JOY_BUTTON_SDL_MAX), _pad(JOY_BUTTON_A)]:
		var source := _profile_with_mappings()
		source.input_mappings.game_quick_save = [record]
		var before := source.duplicate(true)
		var imported := IMPORT.prepare(source.input_mappings)
		assert_true(imported.pending, str(record))
		assert_false(imported.issues.is_empty())
		assert_eq(imported.issues[0].action, "game_quick_save")
		assert_eq(imported.bindings, RULES.defaults(), "No partial import or inferred event conversion")
		assert_true(RULES.validate(imported.bindings).ok)
		assert_eq(source, before)


func test_multiple_same_kind_records_never_choose_a_winner() -> void:
	for records in [[_key(KEY_F6), _key(KEY_F7)], [_key(KEY_F6), _key(KEY_F6)], [_pad(JOY_BUTTON_LEFT_STICK), _pad(JOY_BUTTON_RIGHT_STICK)]]:
		var source := _profile_with_mappings()
		source.input_mappings.game_quick_save = records
		var before := source.duplicate(true)
		var imported := IMPORT.prepare(source.input_mappings)
		assert_true(imported.pending)
		assert_eq(imported.issues[0].code, &"multiple_legacy_records")
		assert_eq(imported.issues[0].count, 2)
		assert_eq(imported.bindings, RULES.defaults())
		assert_eq(source, before)


func test_complete_import_collision_including_new_mode_stays_pending() -> void:
	for collision in [_key(KEY_F9), _key(KEY_F), _pad(JOY_BUTTON_X)]:
		var source := _profile_with_mappings()
		source.input_mappings.game_quick_save = [collision]
		var before := source.duplicate(true)
		var imported := IMPORT.prepare(source.input_mappings)
		assert_true(imported.pending)
		assert_eq(imported.issues[-1].code, &"binding_conflict")
		assert_eq(imported.issues[-1].action, "game_quick_save")
		assert_eq(imported.bindings, RULES.defaults())
		assert_eq(source, before)


func test_retired_actions_do_not_claim_new_semantics_or_block_import() -> void:
	var source := _profile_with_mappings()
	source.input_mappings.game_hint = [_key(KEY_F), _key(KEY_H)]
	source.input_mappings.game_skip_text = [_key(KEY_CTRL), _pad(JOY_BUTTON_A, 27)]
	var before := source.duplicate(true)
	var result := IMPORT.prepare(source.input_mappings)
	assert_false(result.pending)
	assert_eq(result.bindings.game_toggle_board_mode.keyboard, _key(KEY_F))
	assert_eq(source, before)


func test_multiple_independent_import_issues_are_retained() -> void:
	var source := _profile_with_mappings()
	source.input_mappings.game_quick_save = [_key(KEY_ENTER)]
	source.input_mappings.game_quick_load = [_pad(JOY_BUTTON_RIGHT_STICK, 9)]
	source.input_mappings.game_new_board = [_key(KEY_N), _key(KEY_F8)]
	var imported := IMPORT.prepare(source.input_mappings)
	assert_true(imported.pending)
	assert_eq(imported.issues.size(), 3)
	assert_eq(imported.issues[0].action, "game_quick_save")
	assert_eq(imported.issues[1].action, "game_quick_load")
	assert_eq(imported.issues[2].action, "game_new_board")


func test_current_profile_requires_closed_roots_valid_controls_and_boolean_pending() -> void:
	var source := SCHEMA.make_defaults()
	for value in [0, "false", null]:
		var invalid := source.duplicate(true)
		invalid.controls_import_pending = value
		assert_false(SCHEMA.validate(invalid).ok)
	for field in ["controls_bindings", "controls_import_pending"]:
		var missing := source.duplicate(true)
		missing.erase(field)
		assert_false(SCHEMA.validate(missing).ok)
	var extra := source.duplicate(true)
	extra.controls_extra = {}
	assert_false(SCHEMA.validate(extra).ok)
	var collision := source.duplicate(true)
	collision.controls_bindings.game_quick_save.keyboard = _key(KEY_F9)
	assert_false(SCHEMA.validate(collision).ok)
	var pending := source.duplicate(true)
	pending.input_mappings = _profile_with_mappings().input_mappings
	pending.controls_import_pending = true
	assert_true(SCHEMA.validate(pending).ok, "Pending retains a legal inactive draft and complete provenance")


func test_machine_schema_closes_controls_slots_and_accepts_both_provenance_forms() -> void:
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string("res://schemas/profile.schema.json"))
	assert_true(parsed.ok)
	if not parsed.ok:
		return
	var machine: Dictionary = parsed.value
	assert_true(JSON_RULES.validate(SCHEMA.make_defaults(), machine).ok)
	assert_true(JSON_RULES.validate(_profile_with_mappings(), machine).ok)
	for mutation in [{"device": 2}, {"button_index": JOY_BUTTON_SDL_MAX}, {"button_index": -1}, {"extra": true}]:
		var invalid := SCHEMA.make_defaults()
		invalid.controls_bindings.game_quick_save.controller.merge(mutation, true)
		assert_false(JSON_RULES.validate(invalid, machine).ok)
	var partial := SCHEMA.make_defaults()
	partial.input_mappings = {"game_quick_save": [_key(KEY_F5)]}
	assert_true(JSON_RULES.validate(partial, machine).ok, "v5 retains validated sparse v1 provenance")
	var malformed_record := partial.duplicate(true)
	malformed_record.input_mappings.game_quick_save = [{"kind":"key","physical_keycode":KEY_F5}]
	assert_false(JSON_RULES.validate(malformed_record, machine).ok, "sparse provenance still validates every stored record")
	var modified := SCHEMA.make_defaults()
	modified.controls_bindings.game_quick_save.keyboard.ctrl = true
	assert_false(JSON_RULES.validate(modified, machine).ok)
	var missing := SCHEMA.make_defaults()
	missing.controls_bindings.game_new_board.erase("controller")
	assert_false(JSON_RULES.validate(missing, machine).ok)
	var pending := SCHEMA.make_defaults()
	pending.controls_import_pending = "false"
	assert_false(JSON_RULES.validate(pending, machine).ok)
