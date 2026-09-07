extends "res://addons/gut/test.gd"
# Fail-closed narrative gate summary (dwm-p2r.8, Plan-05 Task 6). The writer must reject any
# missing file, non-GREEN result, count mismatch, or duplicate requirement id rather than
# emitting evidence that overstates what was proven.

const WRITER_PATH := "res://tools/dialogic/WriteDialogicGateSummary.gd"

var _writer: GDScript


func before_all() -> void:
	if ResourceLoader.exists(WRITER_PATH, "Script"):
		_writer = load(WRITER_PATH)


func _fixture_counts() -> Dictionary:
	return {"line": 3, "choice": 1, "marker": 1, "effect": 1, "variable": 1, "completion": 1, "restore": 1, "failures": 0}


func _inputs() -> Dictionary:
	return {
		"manifests": ["data/manifests/timelines.json", "data/manifests/endings.json"],
		"logs": ["data/manifests/effects.json"],
		"fixture_counts": _fixture_counts(),
		"requirement_ids": ["req.dialogic.authority", "req.dialogic.skip"],
	}


func test_gate_summary_writer_is_required() -> void:
	assert_true(ResourceLoader.exists(WRITER_PATH, "Script"), "missing gate summary writer")


func test_build_succeeds_on_complete_green_inputs() -> void:
	if _writer == null:
		return
	var result: Dictionary = _writer.call(&"build", _inputs())
	assert_true(result.get("ok", false), str(result))
	var value: Dictionary = result["value"]
	assert_eq(int((value["production_counts"] as Dictionary)["total"]), 59, "59 production records")
	assert_eq(int((value["production_counts"] as Dictionary)["placeholder"]), 24)
	assert_eq(int((value["production_counts"] as Dictionary)["draft"]), 35)
	assert_eq(value["fixture_counts"], _fixture_counts(), "exact fixture counts")
	assert_true(value.has("manifest_hashes"), "records exact manifest hashes")


func test_build_rejects_wrong_input_key_set() -> void:
	if _writer == null:
		return
	var short_inputs := _inputs()
	short_inputs.erase("logs")
	assert_eq(str(_writer.call(&"build", short_inputs).get("code")), "gate_evidence_invalid", "missing key rejects")
	var extra := _inputs()
	extra["unexpected"] = true
	assert_eq(str(_writer.call(&"build", extra).get("code")), "gate_evidence_invalid", "extra key rejects")


func test_build_rejects_a_missing_or_escaping_path() -> void:
	if _writer == null:
		return
	var missing := _inputs()
	missing["manifests"] = ["data/manifests/does_not_exist.json"]
	assert_eq(str(_writer.call(&"build", missing).get("code")), "gate_evidence_invalid", "missing file rejects")
	var escaping := _inputs()
	escaping["manifests"] = ["../outside.json"]
	assert_eq(str(_writer.call(&"build", escaping).get("code")), "gate_evidence_invalid", "path escape rejects")


func test_build_rejects_fixture_count_mismatch() -> void:
	if _writer == null:
		return
	for bad_key in ["line", "choice", "marker", "effect", "variable", "completion", "restore"]:
		var inputs := _inputs()
		(inputs["fixture_counts"] as Dictionary)[bad_key] = 99
		assert_eq(str(_writer.call(&"build", inputs).get("code")), "gate_evidence_invalid", bad_key + " mismatch rejects")


func test_build_rejects_any_fixture_failure() -> void:
	if _writer == null:
		return
	var inputs := _inputs()
	(inputs["fixture_counts"] as Dictionary)["failures"] = 1
	assert_eq(str(_writer.call(&"build", inputs).get("code")), "gate_evidence_invalid", "a failing fixture cannot pass the gate")


func test_build_rejects_duplicate_or_empty_requirement_ids() -> void:
	if _writer == null:
		return
	var duplicated := _inputs()
	duplicated["requirement_ids"] = ["req.dialogic.skip", "req.dialogic.skip"]
	assert_eq(str(_writer.call(&"build", duplicated).get("code")), "gate_evidence_invalid", "duplicates reject")
	var empty := _inputs()
	empty["requirement_ids"] = []
	assert_eq(str(_writer.call(&"build", empty).get("code")), "gate_evidence_invalid", "an empty requirement set rejects")


func test_summary_links_dwm_p2r_8_and_claims_no_authorization() -> void:
	if _writer == null:
		return
	var value: Dictionary = _writer.call(&"build", _inputs())["value"]
	assert_eq(str(value.get("issue_id", "")), "dwm-p2r.8", "evidence is linked to its issue")
	var serialized := str(value)
	assert_false("implementation_authorized" in serialized, "the summary never claims authorization")


func test_summary_contains_only_sorted_primitive_records() -> void:
	if _writer == null:
		return
	var value: Dictionary = _writer.call(&"build", _inputs())["value"]
	var hashes: Dictionary = value["manifest_hashes"]
	var keys: Array = hashes.keys()
	var sorted_keys: Array = keys.duplicate()
	sorted_keys.sort()
	assert_eq(keys, sorted_keys, "hash records are sorted")
	for key: Variant in hashes:
		assert_eq(str(hashes[key]).length(), 64, "lowercase sha256 hex per path")
		assert_eq(str(hashes[key]), str(hashes[key]).to_lower(), "hashes are lowercase")
