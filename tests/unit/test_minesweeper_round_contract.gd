extends "res://addons/gut/test.gd"

const CONTRACT := preload("res://scripts/domain/minesweeper/MinesweeperRoundContract.gd")


func test_difficulties_are_exact() -> void:
	assert_eq(CONTRACT.DIFFICULTIES, [&"beginner", &"intermediate", &"expert"])


func test_outcomes_are_exact() -> void:
	assert_eq(CONTRACT.OUTCOMES, [&"exploded", &"cleared", &"perfect", &"no_flag", &"foresight"])


func test_validate_start_request_accepts_app() -> void:
	var r := CONTRACT.validate_start_request({"context": &"app", "difficulty": &"beginner"})
	assert_true(r.ok)
	assert_eq(r.code, &"ok")
	assert_eq(r.value.context, &"app")
	assert_eq(r.value.difficulty, &"beginner")


func test_validate_start_request_accepts_dating_with_string_variants() -> void:
	var r := CONTRACT.validate_start_request({"context": "dating", "difficulty": "expert"})
	assert_true(r.ok)
	assert_eq(r.value.context, &"dating")
	assert_eq(r.value.difficulty, &"expert")


func test_validate_start_request_rejects_bad_context() -> void:
	var r := CONTRACT.validate_start_request({"context": &"shop", "difficulty": &"beginner"})
	assert_false(r.ok)
	assert_eq(r.code, &"invalid_request")


func test_validate_start_request_rejects_bad_difficulty() -> void:
	var r := CONTRACT.validate_start_request({"context": &"app", "difficulty": &"ludicrous"})
	assert_false(r.ok)
	assert_eq(r.code, &"invalid_request")


func test_validate_start_request_rejects_non_dict() -> void:
	assert_false(CONTRACT.validate_start_request("nope").ok)
	assert_false(CONTRACT.validate_start_request(null).ok)


func test_build_round_id_format() -> void:
	assert_eq(CONTRACT.build_round_id("run-1", 2, 3), "run-1:day-2:round-3")
	assert_eq(CONTRACT.build_round_id("run-x", 7, 1), "run-x:day-7:round-1")


func test_validate_result_normalizes_app_outcome() -> void:
	var ar := {"context": &"app", "dating_evidence": null}
	var r := CONTRACT.validate_result(ar, {"outcome": &"cleared"})
	assert_true(r.ok)
	assert_eq(r.value.outcome, "cleared")


func test_validate_result_normalizes_stringname_outcome() -> void:
	var ar := {"context": &"app", "dating_evidence": null}
	var r := CONTRACT.validate_result(ar, {"outcome": &"perfect"})
	assert_true(r.ok)
	assert_eq(r.value.outcome, "perfect")


func test_validate_result_rejects_extra_keys() -> void:
	var ar := {"context": &"app", "dating_evidence": null}
	var r := CONTRACT.validate_result(ar, {"outcome": &"cleared", "extra": 1})
	assert_false(r.ok)
	assert_eq(r.code, &"invalid_result")


func test_validate_result_rejects_bad_outcome() -> void:
	var ar := {"context": &"app", "dating_evidence": null}
	var r := CONTRACT.validate_result(ar, {"outcome": &"win"})
	assert_false(r.ok)
	assert_eq(r.code, &"invalid_result")


func test_validate_result_rejects_dating_without_evidence() -> void:
	var ar := {"context": &"dating", "dating_evidence": null}
	var r := CONTRACT.validate_result(ar, {"outcome": &"cleared"})
	assert_false(r.ok)
	assert_eq(r.code, &"invalid_result")


func test_validate_result_rejects_app_with_evidence() -> void:
	var ar := {"context": &"app", "dating_evidence": {"entry_id": "x", "route_transaction_id": "y", "friend_ids": []}}
	var r := CONTRACT.validate_result(ar, {"outcome": &"cleared"})
	assert_false(r.ok)
	assert_eq(r.code, &"invalid_result")
