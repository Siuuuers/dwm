extends "res://addons/gut/test.gd"

# Visible-deduction ("no guess") verifier suite (Plan 02 Task 3, dwm-p2r13). Layouts were
# designed and cross-checked against a throwaway Python reference oracle implementing the same
# four-rule fixpoint (adjacent_zero, adjacent_full, subset_difference, global_remaining); see
# task-3-report.md. Only high-level, implementation-order-independent properties are asserted
# (certified/code, rules_used as a covering subset, operation_count self-consistency) rather than
# exact trace equality, since canonical-byte constraint ordering can legitimately interleave
# differently from the Python oracle's tie-breaking while still reaching the same certified result.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const VERIFIER := preload("res://scripts/domain/minesweeper/MinesweeperNoGuessVerifier.gd")

const ALLOWED_RULES: Array[StringName] = [
	&"adjacent_zero", &"adjacent_full", &"subset_difference", &"global_remaining",
]

const FIXTURE_PATH := "res://tests/fixtures/minesweeper/verifier_cases.v1.json"

var _fixture: Dictionary


func before_each() -> void:
	_fixture = JSON.parse_string(FileAccess.get_file_as_string(FIXTURE_PATH))


func _case(case_id: String) -> Dictionary:
	for entry: Variant in (_fixture["cases"] as Array):
		var record: Dictionary = entry
		if String(record["case_id"]) == case_id:
			return record
	fail_test("fixture case not found: %s" % case_id)
	return {}


func _int_array(source: Array) -> Array[int]:
	var result: Array[int] = []
	for entry: Variant in source:
		result.append(int(entry))
	return result


func _layout_from_case(record: Dictionary) -> Dictionary:
	var mine_indices := _int_array(record["mine_indices"])
	return {
		"schema_version": 1, "width": int(record["width"]), "height": int(record["height"]),
		"mine_indices": mine_indices,
		"mine_count": mine_indices.size(),
	}


# ---- Step 3.1 parse proof ----

func test_verifier_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script("res://scripts/domain/minesweeper/MinesweeperNoGuessVerifier.gd")
	assert_true(loaded.get("ok", false), "MinesweeperNoGuessVerifier.gd must load")


# ---- shared structural assertions for every certified case ----

func _assert_certified_shape(result: Dictionary, record: Dictionary) -> void:
	assert_true(result.get("ok", false), JSON.stringify(result))
	var value: Dictionary = result["value"]
	assert_eq(value.keys(), ["certified", "operation_count", "proof_trace", "proof_trace_sha256"])
	assert_true(value["certified"])
	var trace: Array = value["proof_trace"]
	assert_eq(value["operation_count"], trace.size(), "operation_count must equal the trace length")
	var rules_seen: Dictionary = {}
	for entry: Variant in trace:
		var step: Dictionary = entry
		assert_eq(step.keys(), ["rule", "source_constraint_ids", "proven_safe", "proven_mine"])
		assert_true(ALLOWED_RULES.has(StringName(step["rule"])), "trace rule must be one of the four allowed rules")
		assert_false((step["source_constraint_ids"] as Array).is_empty(), "every trace step names its source constraints")
		rules_seen[String(step["rule"])] = true
	for expected_rule: Variant in (record["expected_rules_used"] as Array):
		assert_true(rules_seen.has(String(expected_rule)),
			"expected rule %s to appear in the proof trace" % expected_rule)


func _assert_all_safe_cells_revealed(record: Dictionary) -> void:
	var width: int = int(record["width"])
	var height: int = int(record["height"])
	var mines: Dictionary = {}
	for m: Variant in (record["mine_indices"] as Array):
		mines[int(m)] = true
	var layout := _layout_from_case(record)
	var result: Dictionary = VERIFIER.verify(layout, int(record["forced_cell"]), int(record["operation_budget"]))
	var trace: Array = result["value"]["proof_trace"]
	var proven_safe: Dictionary = {}
	proven_safe[int(record["forced_cell"])] = true
	for entry: Variant in trace:
		for cell: Variant in ((entry as Dictionary)["proven_safe"] as Array):
			proven_safe[int(cell)] = true
	for index in range(width * height):
		if not mines.has(index):
			assert_true(proven_safe.has(index), "cell %d must be deduced/revealed safe" % index)


func _run_case(case_id: String) -> Dictionary:
	var record := _case(case_id)
	var layout := _layout_from_case(record)
	var result: Dictionary = VERIFIER.verify(layout, int(record["forced_cell"]), int(record["operation_budget"]))
	return {"record": record, "result": result}


# ---- positive: each allowed rule ----

func test_adjacent_zero_and_adjacent_full_case_certifies() -> void:
	var run := _run_case("adjacent_zero_and_full")
	_assert_certified_shape(run["result"], run["record"])
	_assert_all_safe_cells_revealed(run["record"])


func test_subset_difference_case_certifies() -> void:
	var run := _run_case("subset_difference")
	_assert_certified_shape(run["result"], run["record"])
	_assert_all_safe_cells_revealed(run["record"])


func test_global_remaining_isolated_room_case_certifies() -> void:
	var run := _run_case("global_remaining_isolated_room")
	_assert_certified_shape(run["result"], run["record"])
	_assert_all_safe_cells_revealed(run["record"])


# ---- positive: combination to fixpoint (all four rules together) ----

func test_all_four_rules_combination_case_certifies() -> void:
	var run := _run_case("all_four_rules_combination")
	_assert_certified_shape(run["result"], run["record"])
	assert_eq((run["record"]["expected_rules_used"] as Array).size(), 4)
	_assert_all_safe_cells_revealed(run["record"])


# ---- determinism under permuted mine_indices ordering ----

func test_determinism_under_permuted_mine_index_order() -> void:
	var canonical := _run_case("subset_difference")
	var permuted := _run_case("subset_difference_permuted_mine_order")
	assert_true(canonical["result"].get("ok", false), JSON.stringify(canonical["result"]))
	assert_true(permuted["result"].get("ok", false), JSON.stringify(permuted["result"]))
	assert_eq(permuted["result"]["value"]["certified"], canonical["result"]["value"]["certified"])
	assert_eq(permuted["result"]["value"]["operation_count"], canonical["result"]["value"]["operation_count"])
	assert_eq(permuted["result"]["value"]["proof_trace"], canonical["result"]["value"]["proof_trace"])
	assert_eq(permuted["result"]["value"]["proof_trace_sha256"], canonical["result"]["value"]["proof_trace_sha256"])


func test_determinism_under_permuted_layout_dict_key_order() -> void:
	var record := _case("subset_difference")
	var mine_indices := _int_array(record["mine_indices"])
	var layout_a := {
		"schema_version": 1, "width": int(record["width"]), "height": int(record["height"]),
		"mine_indices": mine_indices, "mine_count": 3,
	}
	var layout_b := {
		"mine_count": 3, "mine_indices": mine_indices.duplicate(),
		"height": int(record["height"]), "width": int(record["width"]), "schema_version": 1,
	}
	var result_a: Dictionary = VERIFIER.verify(layout_a, int(record["forced_cell"]), int(record["operation_budget"]))
	var result_b: Dictionary = VERIFIER.verify(layout_b, int(record["forced_cell"]), int(record["operation_budget"]))
	assert_eq(result_a["value"]["proof_trace_sha256"], result_b["value"]["proof_trace_sha256"])


func test_calling_verify_twice_on_the_same_layout_is_fully_deterministic() -> void:
	var run_a := _run_case("all_four_rules_combination")
	var run_b := _run_case("all_four_rules_combination")
	assert_eq(run_a["result"]["value"]["proof_trace_sha256"], run_b["result"]["value"]["proof_trace_sha256"])


# ---- negative: requires probability / speculative branches / contradiction search ----

func test_guess_required_negative_case_does_not_certify() -> void:
	var run := _run_case("guess_required_negative")
	assert_false(run["result"].get("ok", true), "a layout that requires guessing must never certify")
	assert_eq(run["result"].get("code"), &"guess_required")
	assert_false(run["result"].has("value"), "a failure result carries no value member")


# ---- negative: operation budget exhaustion ----

func test_budget_exhausted_negative_case_reports_no_partial_proof() -> void:
	var run := _run_case("budget_exhausted_negative")
	assert_false(run["result"].get("ok", true))
	assert_eq(run["result"].get("code"), &"generation_budget_exhausted")
	assert_false(run["result"].has("value"), "budget exhaustion must carry no partial proof in value")


# ---- forced-cell safety ----

func test_verify_rejects_a_forced_cell_that_is_a_mine() -> void:
	var layout := {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [4], "mine_count": 1}
	var result: Dictionary = VERIFIER.verify(layout, 4, 25)
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"forced_cell_is_mine")


func test_verify_rejects_a_negative_operation_budget() -> void:
	var layout := {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [8], "mine_count": 1}
	var result: Dictionary = VERIFIER.verify(layout, 0, -1)
	assert_false(result.get("ok", true))
