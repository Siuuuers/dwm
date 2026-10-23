extends "res://addons/gut/test.gd"
## Data-independent label and executable-event checks for the current validator.
## Retired registry fixtures are pinned in canonical-test-disposition.json.

const VALIDATOR := preload("res://tools/dialogic/DtlStructureValidator.gd")


func _entry() -> Array:
	return [{"label": "scene.entry", "role": "ordinary_message", "allowed_signals": ["history.line.witness"]}]


func _scene() -> String:
	return "# timeline_id: scene\n# locale: en\n# type: contact\nreturn\n\nlabel history\n# TODO\nreturn\n\nlabel scene.entry\n# PURPOSE: ordinary_message\n# ALLOWED SIGNALS: history.line.witness\nreturn\n"


func _has_code(result: Dictionary, code: StringName) -> bool:
	for failure: Dictionary in result["failures"]:
		if failure["code"] == code: return true
	return false


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
