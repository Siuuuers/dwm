extends "res://addons/gut/test.gd"
## The old eight-master gate is superseded by scene-oriented label and hook coverage.

const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const VALIDATOR := preload("res://tools/dialogic/DtlStructureValidator.gd")
const BUILDER := preload("res://tools/dialogic/TimelineManifestBuilder.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const ROOT := "res://dialogic/timelines/en/"


func _document() -> Dictionary:
	return MANIFEST.load_default()["value"]


func _timelines() -> Array:
	return STRICT_JSON.parse_object(FileAccess.get_file_as_string(
		"res://data/manifests/timelines.json"))["value"]["records"]


func _entry() -> Array:
	return [{"label": "scene.entry", "role": "ordinary_message", "allowed_signals": ["history.line.witness"]}]


func _scene() -> String:
	return "# timeline_id: scene\n# locale: en\n# type: contact\nreturn\n\nlabel history\n# TODO\nreturn\n\nlabel scene.entry\n# PURPOSE: ordinary_message\n# ALLOWED SIGNALS: history.line.witness\nreturn\n"


func _has_code(result: Dictionary, code: StringName) -> bool:
	for failure: Dictionary in result["failures"]:
		if failure["code"] == code: return true
	return false


func test_all_137_semantic_entries_resolve_to_scene_files_with_isolated_hooks() -> void:
	var document := _document()
	assert_true(MANIFEST.validate_document(document).get("ok", false))
	assert_eq(document["entry_count"], 137)
	var partition: Dictionary = VALIDATOR.partition_by_master(document)
	var records := _timelines()
	assert_eq(records.size(), 64, "original 61 plus two group contacts and one neutral echo scene")
	var total := 0
	for record: Dictionary in records:
		var path := "res://" + str(record["path"])
		assert_true(path.trim_prefix(ROOT).contains("/"), path)
		var expected: Array = partition.get(path, [])
		total += expected.size()
		var result := VALIDATOR.validate_file(path, expected, record["labels"])
		assert_true(result["ok"], str(result["failures"]))
	assert_eq(total, 137, "no semantic entry is orphaned outside the scene registry")


func test_followup_uses_delivery_day_and_shared_scenes_keep_distinct_entries() -> void:
	var cases := {
		"contact.invitation.solo.priscilla.day1.nevermind": "contacts/priscilla_day2.dtl",
		"contact.invitation.group.priscilla_lavinia.day6.busy_lavinia": "contacts/group/priscilla_lavinia_day6.dtl",
		"echo.fallback.day7": "core/echo_fallback_day7.dtl",
		"hospital.faint.day7": "core/hospital_faint.dtl",
		"ending.priscilla_lavinia.observer.residue": "ending/priscilla_lavinia.dtl",
		"dating.group.priscilla_lavinia.day2.pre_challenge": "dating/group/priscilla_lavinia_day2_pre_challenge.dtl",
		"dating.twofriends.priscilla_lavinia.day2.pre_challenge": "dating/twofriends/priscilla_lavinia_day2_pre_challenge.dtl",
	}
	for entry_id: String in cases:
		var result: Dictionary = MANIFEST.resolve_entry(_document(), entry_id, "en")
		assert_true(result.get("ok", false), str(result))
		assert_eq(result["value"]["path"], ROOT + cases[entry_id])
		assert_eq(result["value"]["label"], entry_id)


func test_original_opening_and_tutorial_are_registered_dialogue_free_files() -> void:
	var by_id := {}
	for record: Dictionary in _timelines(): by_id[record["id"]] = record
	for entry_id: String in ["opening.day1", "tutorial.desktop_day1"]:
		assert_true(by_id.has(entry_id), entry_id)
		var record: Dictionary = by_id[entry_id]
		assert_true(VALIDATOR.validate_file("res://" + record["path"], [], []).get("ok", false))


func test_scene_metadata_and_registered_legacy_labels_are_allowed() -> void:
	assert_true(VALIDATOR.validate_text("fixture", _scene(), _entry(), ["history"]).get("ok", false))


func test_missing_duplicate_unregistered_and_fallthrough_labels_are_refused() -> void:
	var text := _scene()
	assert_true(_has_code(VALIDATOR.validate_text("fixture", text.replace("label scene.entry", "label wrong"), _entry(), ["history"]), VALIDATOR.DTL_MISSING_LABEL))
	assert_true(_has_code(VALIDATOR.validate_text("fixture", text + "label scene.entry\nreturn\n", _entry(), ["history"]), VALIDATOR.DTL_DUPLICATE_LABEL))
	assert_true(_has_code(VALIDATOR.validate_text("fixture", text, _entry()), VALIDATOR.DTL_UNREGISTERED_LABEL))
	assert_true(_has_code(VALIDATOR.validate_text("fixture", text.replace("# TODO\nreturn", "# TODO"), _entry(), ["history"]), VALIDATOR.DTL_LABEL_FALLTHROUGH))
	assert_true(_has_code(VALIDATOR.validate_text("fixture", text.trim_suffix("return\n"), _entry(), ["history"]), VALIDATOR.DTL_TRAILING_FALLTHROUGH))


func test_unlabeled_execution_dialogue_and_changed_hook_contracts_are_refused() -> void:
	assert_true(_has_code(VALIDATOR.validate_text("fixture", _scene().replace("# type: contact\nreturn", "# type: contact"), _entry(), ["history"]), VALIDATOR.DTL_LEADING_RETURN_MISSING))
	assert_true(_has_code(VALIDATOR.validate_text("fixture", _scene() + "Someone: prose\n", _entry(), ["history"]), VALIDATOR.DTL_DIALOGUE_LINE))
	assert_true(_has_code(VALIDATOR.validate_text("fixture", _scene().replace("history.line.witness", "message.reply.commit"), _entry(), ["history"]), VALIDATOR.DTL_SIGNAL_COMMENT_MISMATCH))


func test_scene_builder_preserves_the_current_manifest_and_master_generator_cannot_overwrite() -> void:
	var built: Dictionary = BUILDER.build()
	assert_true(built.get("ok", false), str(built))
	assert_eq(built["value"]["records"], _timelines())
	var generator := FileAccess.get_file_as_string("res://tools/dialogic/generate_master_skeletons.gd")
	assert_false(generator.contains("FileAccess.WRITE"))
	assert_true(generator.contains("Master generation is retired"))
	for stem: String in ["day_1", "day_2", "day_3", "day_4", "day_5", "day_6", "day_7", "endings"]:
		assert_false(FileAccess.file_exists(ROOT + stem + ".dtl"), "superseded master: " + stem)


func test_trailing_fallthrough_reports_unterminated_label_line() -> void:
	var text := _scene().trim_suffix("return\n") + "\n\n"
	var result := VALIDATOR.validate_text("fixture", text, _entry(), ["history"])
	assert_false(result["ok"])
	assert_eq(result["failures"].size(), 1)
	var failure: Dictionary = result["failures"][0]
	assert_eq(failure["code"], VALIDATOR.DTL_TRAILING_FALLTHROUGH)
	assert_eq(failure["line"], 10, "name the unterminated label, not trailing blank lines")


func _assert_executable_code(event: String, expected_code: StringName) -> void:
	var result := VALIDATOR.validate_text("fixture", _scene() + event + "\n", _entry(), ["history"])
	assert_false(result["ok"], event)
	assert_eq(result["failures"].size(), 1, event)
	assert_eq(result["failures"][0]["code"], expected_code, event)


func test_resource_path_event_is_classified_without_other_hazard_terms() -> void:
	_assert_executable_code("res://asset", VALIDATOR.DTL_DYNAMIC_RESOURCE_PATH)


func test_user_path_event_is_classified_without_other_hazard_terms() -> void:
	_assert_executable_code("user://asset", VALIDATOR.DTL_DYNAMIC_RESOURCE_PATH)


func test_load_event_is_classified_without_a_resource_path() -> void:
	_assert_executable_code("load(asset)", VALIDATOR.DTL_DYNAMIC_RESOURCE_PATH)


func test_direct_domain_call_is_classified_without_a_resource_path() -> void:
	_assert_executable_code("GameState.change()", VALIDATOR.DTL_DIRECT_DOMAIN_CALL)


func test_direct_call_classifier_requires_open_parenthesis() -> void:
	_assert_executable_code("name.value)", VALIDATOR.DTL_DIALOGUE_LINE)


func test_direct_call_classifier_requires_close_parenthesis() -> void:
	_assert_executable_code("name.value(", VALIDATOR.DTL_DIALOGUE_LINE)


func test_direct_call_classifier_requires_member_separator() -> void:
	_assert_executable_code("invoke()", VALIDATOR.DTL_DIALOGUE_LINE)


func test_comments_with_hazard_text_remain_inert() -> void:
	var comments := "# res://asset\n# user://asset\n# load(asset)\n# GameState.change()\n"
	var result := VALIDATOR.validate_text("fixture", comments + _scene() + comments, _entry(), ["history"])
	assert_true(result["ok"], str(result["failures"]))
