extends "res://addons/gut/test.gd"
## A superseded count gate must never rewrite historical evidence for the current scene layout.

const WRITER := preload("res://tools/dialogic/WriteDialogicGateSummary.gd")


func test_historical_gate_reports_supersession_and_directs_current_validation() -> void:
	var result: Dictionary = WRITER.build({})
	assert_false(result["ok"])
	assert_eq(result["code"], &"historical_gate_superseded")
	assert_true(str(result["message"]).contains("validate_dialogic_contract.gd"))
	assert_false(result.has("value"), "no new evidence claim is emitted")


func test_retired_manifest_and_evidence_commands_have_no_write_path() -> void:
	for path: String in ["res://tools/dialogic/validate_manifests.gd",
			"res://tools/dialogic/WriteDialogicGateSummary.gd"]:
		assert_false(FileAccess.get_file_as_string(path).contains("FileAccess.WRITE"), path)
