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


func _v2() -> Dictionary:
	var profile := SCHEMA.make_defaults()
	profile.erase("pair_form_witness_receipts")
	profile.erase("dating_attempts")
	profile.erase("controls_bindings")
	profile.erase("controls_import_pending")
	profile.erase("migration_receipts")
	profile.erase("legacy_preferences_v1")
	profile.schema_version = 2
	profile.erase("observer_evidence")
	profile.erase("pair_deck_draws")
	profile.erase("reached_presentations")
	profile.erase("reached_presentation_chronology")
	profile.erase("witnessed_caption_variants")
	profile.input_mappings = SCHEMA._default_input_mappings()
	profile.preferences.audio.music_volume = 0.37
	profile.gallery_unlocks = ["ending.alone"]
	profile.gallery_transaction_receipts = {"retained": {"ending_id": "ending.alone", "unlocked": true}}
	profile.visited_line_ids = ["retained.line"]
	return profile


func test_fresh_profile_is_v10_without_manufactured_legacy_provenance() -> void:
	var profile := SCHEMA.make_defaults()
	assert_eq(profile.schema_version, 10)
	assert_eq(profile.keys().size(), 17)
	assert_eq(profile.input_mappings, {})
	assert_false(profile.controls_import_pending)
	assert_eq(profile.controls_bindings, RULES.defaults())
	assert_true(SCHEMA.validate(profile).ok)
	assert_false(SCHEMA.prepare_v2_upgrade(profile).ok)


func test_default_v2_keeps_n_and_every_original_field() -> void:
	var source := _v2()
	var before := source.duplicate(true)
	var result := SCHEMA.prepare_v2_upgrade(source)
	assert_true(result.ok)
	if not result.ok:
		return
	var expected := before.duplicate(true)
	expected.schema_version = 10
	expected["observer_evidence"] = {}
	expected["pair_deck_draws"] = {}
	expected["reached_presentations"] = {}
	expected["reached_presentation_chronology"] = {"first_witnessed": [], "legacy_unordered": []}
	expected["witnessed_caption_variants"] = {}
	expected.pair_form_witness_receipts = {}
	expected["dating_attempts"] = {}
	expected.migration_receipts = {"legacy_game_state_profile_v1":true,
		"legacy_input_bindings_v1":true,"invalid_persisted_skip_mode_v1":false}
	expected.legacy_preferences_v1 = {}
	expected.controls_bindings = RULES.defaults()
	expected.controls_bindings.game_new_board.keyboard = _key(KEY_N)
	expected.controls_import_pending = false
	assert_eq(result.value, expected)
	assert_eq(source, before)
	assert_true(SCHEMA.validate(result.value).ok)
	assert_false(SCHEMA.validate(source).ok, "Current validation never silently upgrades")
	result.value.input_mappings.game_hint[0].physical_keycode = KEY_J
	result.value.preferences.audio.music_volume = 0.2
	assert_eq(source, before, "Prepared migration is fully detached from the source")


func test_cross_swapped_imports_validate_after_all_transfers() -> void:
	var source := _v2()
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
	var source := _v2()
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
		var source := _v2()
		source.input_mappings.game_quick_save = [record]
		var before := source.duplicate(true)
		var imported := IMPORT.prepare(source.input_mappings)
		assert_true(imported.pending, str(record))
		assert_false(imported.issues.is_empty())
		assert_eq(imported.issues[0].action, "game_quick_save")
		assert_eq(imported.bindings, RULES.defaults(), "No partial import or inferred event conversion")
		assert_true(RULES.validate(imported.bindings).ok)
		var result := SCHEMA.prepare_v2_upgrade(source)
		assert_true(result.ok)
		if result.ok:
			assert_true(result.value.controls_import_pending)
			assert_eq(result.value.input_mappings, before.input_mappings)
		assert_eq(source, before)


func test_multiple_same_kind_records_never_choose_a_winner() -> void:
	for records in [[_key(KEY_F6), _key(KEY_F7)], [_key(KEY_F6), _key(KEY_F6)], [_pad(JOY_BUTTON_LEFT_STICK), _pad(JOY_BUTTON_RIGHT_STICK)]]:
		var source := _v2()
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
		var source := _v2()
		source.input_mappings.game_quick_save = [collision]
		var before := source.duplicate(true)
		var imported := IMPORT.prepare(source.input_mappings)
		assert_true(imported.pending)
		assert_eq(imported.issues[-1].code, &"binding_conflict")
		assert_eq(imported.issues[-1].action, "game_quick_save")
		assert_eq(imported.bindings, RULES.defaults())
		assert_eq(source, before)


func test_retired_actions_do_not_claim_new_semantics_or_block_import() -> void:
	var source := _v2()
	source.input_mappings.game_hint = [_key(KEY_F), _key(KEY_H)]
	source.input_mappings.game_skip_text = [_key(KEY_CTRL), _pad(JOY_BUTTON_A, 27)]
	var before := source.duplicate(true)
	var result := SCHEMA.prepare_v2_upgrade(source)
	assert_true(result.ok)
	if not result.ok:
		return
	assert_false(result.value.controls_import_pending)
	assert_eq(result.value.controls_bindings.game_toggle_board_mode.keyboard, _key(KEY_F))
	assert_eq(result.value.input_mappings, before.input_mappings)
	assert_eq(source, before)


func test_multiple_independent_import_issues_are_retained() -> void:
	var source := _v2()
	source.input_mappings.game_quick_save = [_key(KEY_ENTER)]
	source.input_mappings.game_quick_load = [_pad(JOY_BUTTON_RIGHT_STICK, 9)]
	source.input_mappings.game_new_board = [_key(KEY_N), _key(KEY_F8)]
	var imported := IMPORT.prepare(source.input_mappings)
	assert_true(imported.pending)
	assert_eq(imported.issues.size(), 3)
	assert_eq(imported.issues[0].action, "game_quick_save")
	assert_eq(imported.issues[1].action, "game_quick_load")
	assert_eq(imported.issues[2].action, "game_new_board")


func test_upgrade_rejects_malformed_v2_before_any_conversion() -> void:
	var malformed: Array[Dictionary] = []
	var empty := _v2()
	empty.input_mappings = {}
	malformed.append(empty)
	var missing := _v2()
	missing.input_mappings.erase("game_hint")
	malformed.append(missing)
	var unknown := _v2()
	unknown.input_mappings.unknown = []
	malformed.append(unknown)
	var mixed_version := _v2()
	mixed_version.controls_import_pending = false
	malformed.append(mixed_version)
	var invalid_event := _v2()
	invalid_event.input_mappings.game_hint = [{"kind": "mouse"}]
	malformed.append(invalid_event)
	var invalid_preference := _v2()
	invalid_preference.preferences.audio.music_volume = 2.0
	malformed.append(invalid_preference)
	for source in malformed:
		var before := source.duplicate(true)
		assert_false(SCHEMA.prepare_v2_upgrade(source).ok)
		assert_eq(source, before)
	assert_true(IMPORT.prepare({}).pending, "Empty fresh provenance is not a legacy import")


func test_v4_requires_closed_roots_valid_controls_and_boolean_pending() -> void:
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
	pending.input_mappings = _v2().input_mappings
	pending.controls_import_pending = true
	assert_true(SCHEMA.validate(pending).ok, "Pending retains a legal inactive draft and complete provenance")


func test_machine_schema_closes_v5_slots_and_accepts_both_provenance_forms() -> void:
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string("res://schemas/profile.schema.json"))
	assert_true(parsed.ok)
	if not parsed.ok:
		return
	var machine: Dictionary = parsed.value
	assert_true(JSON_RULES.validate(SCHEMA.make_defaults(), machine).ok)
	var upgraded := SCHEMA.prepare_v2_upgrade(_v2())
	assert_true(upgraded.ok)
	if upgraded.ok:
		assert_true(JSON_RULES.validate(upgraded.value, machine).ok)
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
