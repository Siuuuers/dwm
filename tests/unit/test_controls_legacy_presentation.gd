extends "res://addons/gut/test.gd"
const PRESENTATION := preload("res://scripts/settings/ControlsLegacyPresentation.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

func _lookup(locale: String) -> Callable:
	var document := STRICT_JSON.parse_object(FileAccess.get_file_as_string("res://localization/ui/" + locale + ".json"))
	assert_true(document.ok)
	var messages := {}
	for message in document.value.messages: messages[message.id] = message.text
	return func(key: String, parameters: Dictionary = {}) -> String:
		var text: String = messages.get(key, key)
		for parameter: String in parameters:
			text = text.replace("{" + parameter + "}", str(parameters[parameter]))
		return text

func _row(rows: Array[Dictionary], action: String) -> Dictionary:
	for row in rows:
		if row.action_id == action: return row
	return {}

func test_every_stored_action_and_duplicate_record_is_visible_and_source_unchanged() -> void:
	var source := SCHEMA._default_input_mappings()
	source.game_quick_save.append(source.game_quick_save[0].duplicate(true))
	var before := source.duplicate(true)
	for locale in ["en", "zh_CN", "zh_HK"]:
		var records := PRESENTATION.rows(source, locale, _lookup(locale))
		assert_eq(records.size(), source.size())
		assert_eq(_row(records, "game_quick_save").bindings.size(), 2)
		assert_eq(_row(records, "game_quick_save").bindings[0], _row(records, "game_quick_save").bindings[1])
		assert_true(_row(records, "game_hint").retired, "Hint is not silently reinterpreted as Flag/Reveal")
		assert_false(_row(records, "game_new_board").retired)
		assert_eq(_row(records, "game_new_board").bindings, [OS.get_keycode_string(KEY_N)])
		for row in records:
			assert_false(row.label.begins_with("settings."))
			for binding in row.bindings: assert_false(binding.contains("settings."))
		records[0].bindings.append("changed")
		assert_eq(source, before)

func test_physical_and_logical_identity_modifiers_and_empty_records_are_not_inferred() -> void:
	var source := SCHEMA._default_input_mappings()
	var record: Dictionary = source.game_quick_save[0]
	record.physical_keycode = KEY_F6
	record.keycode = KEY_Z
	record.ctrl = true
	record.shift = true
	source.game_quick_load = []
	var records := PRESENTATION.rows(source, "en", _lookup("en"))
	var caption: String = _row(records, "game_quick_save").bindings[0]
	assert_true(caption.contains("Ctrl"))
	assert_true(caption.contains("Shift"))
	assert_true(caption.contains("F6"))
	assert_true(caption.contains("Z"))
	assert_true(caption.contains("Physical"))
	assert_true(caption.contains("Logical"))
	assert_eq(_row(records, "game_quick_load").bindings, ["No stored binding"])

func test_controller_records_keep_device_and_raw_button_truth_without_semantic_guess() -> void:
	var source := SCHEMA._default_input_mappings()
	source.game_quick_save = [{"kind": "joypad_button", "button_index": JOY_BUTTON_X, "device": 4}, {"kind": "joypad_button", "button_index": 127, "device": -1}]
	var records := PRESENTATION.rows(source, "en", _lookup("en"))
	var labels: Array = _row(records, "game_quick_save").bindings
	assert_eq(labels.size(), 2)
	assert_true(labels[0].contains("2"))
	assert_true(labels[0].contains("4"))
	assert_false(labels[0].contains("West"))
	assert_true(labels[1].contains("127"))
	assert_true(labels[1].contains("Any controller"))

func test_unknown_and_unspecified_keys_are_described_without_manufactured_names() -> void:
	var source := SCHEMA._default_input_mappings()
	source.game_quick_save[0].physical_keycode = -7
	source.game_quick_load[0].physical_keycode = 0
	var records := PRESENTATION.rows(source, "en", _lookup("en"))
	assert_eq(_row(records, "game_quick_save").bindings, ["Unknown key (-7)"])
	assert_eq(_row(records, "game_quick_load").bindings, ["Unspecified key"])
