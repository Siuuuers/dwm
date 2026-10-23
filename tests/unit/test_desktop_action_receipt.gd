extends "res://addons/gut/test.gd"

## RED/GREEN coverage for DesktopActionReceipt (Plan 02 Task 7, dwm-p2r.32.7).

const _RECEIPT_SCRIPT := preload("res://scripts/domain/desktop/DesktopActionReceipt.gd")

func _provenance(seed: String) -> Dictionary:
	return {
		"child_id": seed + ".child", "child_kind": "desktop_action", "ordinal": 0,
		"parent_receipt_id": "issuer_receipt.fixture-" + seed, "schema_version": 1,
		"source_ids": [seed],
	}


func _condition(health: int = 8, pressure: int = 2, carried_sequela: bool = false) -> Dictionary:
	return {"health": health, "pressure": pressure, "carried_sequela": carried_sequela}


func _valid_receipt() -> Dictionary:
	var condition := _condition()
	return {
		"schema_version": 1, "action_id": "desktop_action.fixture-1",
		"action_id_provenance": _provenance("fixture-1"), "action_kind": "shop_purchase",
		"run_id": "run-1", "branch_id": "branch-1", "desktop_timeline_generation": 0,
		"causal_day_instance": "causal-day-1", "day": 2, "transaction_id": "txn-1",
		"transaction_issuer_receipt": {"receipt_id": "issuer_receipt.fixture-txn-1", "purpose": "transaction_id"},
		"source_commit_receipt_id": "shop_quote.fixture-1",
		"source_commit_receipt_provenance": _provenance("quote-1"),
		"condition_before": condition.duplicate(true), "condition_after": condition.duplicate(true),
		"unlock_receipt_ids": [], "commit_receipt_id": "desktop_action.fixture-1",
		"commit_receipt_provenance": _provenance("fixture-1"),
	}


func test_validate_accepts_a_well_formed_receipt() -> void:
	var validated: Dictionary = _RECEIPT_SCRIPT.validate(_valid_receipt())
	assert_true(validated.get("ok", false), JSON.stringify(validated))


func test_validate_rejects_extra_and_missing_keys() -> void:
	var extra := _valid_receipt()
	extra["bogus"] = 1
	assert_false(_RECEIPT_SCRIPT.validate(extra).get("ok", true), "extra key must reject")
	var missing := _valid_receipt()
	missing.erase("day")
	assert_false(_RECEIPT_SCRIPT.validate(missing).get("ok", true), "missing key must reject")


func test_validate_rejects_blank_identity_strings() -> void:
	for field: String in ["action_id", "run_id", "branch_id", "causal_day_instance", "transaction_id",
			"source_commit_receipt_id", "commit_receipt_id"]:
		var receipt := _valid_receipt()
		receipt[field] = ""
		assert_false(_RECEIPT_SCRIPT.validate(receipt).get("ok", true), "%s must reject blank" % field)


func test_validate_rejects_an_unknown_action_kind() -> void:
	var receipt := _valid_receipt()
	receipt["action_kind"] = "schedule_done"
	assert_false(_RECEIPT_SCRIPT.validate(receipt).get("ok", true))


func test_validate_accepts_minesweeper_round_action_kind_too() -> void:
	var receipt := _valid_receipt()
	receipt["action_kind"] = "minesweeper_round"
	assert_true(_RECEIPT_SCRIPT.validate(receipt).get("ok", false))


func test_validate_rejects_a_negative_desktop_timeline_generation() -> void:
	var receipt := _valid_receipt()
	receipt["desktop_timeline_generation"] = -1
	assert_false(_RECEIPT_SCRIPT.validate(receipt).get("ok", true))


func test_validate_rejects_malformed_provenance() -> void:
	var receipt := _valid_receipt()
	var provenance: Dictionary = (receipt["action_id_provenance"] as Dictionary).duplicate(true)
	provenance.erase("child_id")
	receipt["action_id_provenance"] = provenance
	assert_false(_RECEIPT_SCRIPT.validate(receipt).get("ok", true))


func test_validate_rejects_a_malformed_condition() -> void:
	var missing_key := _valid_receipt()
	var condition: Dictionary = (missing_key["condition_before"] as Dictionary).duplicate(true)
	condition.erase("pressure")
	missing_key["condition_before"] = condition
	assert_false(_RECEIPT_SCRIPT.validate(missing_key).get("ok", true), "missing condition key must reject")

	var wrong_type := _valid_receipt()
	var bad_condition: Dictionary = (wrong_type["condition_after"] as Dictionary).duplicate(true)
	bad_condition["carried_sequela"] = 1
	wrong_type["condition_after"] = bad_condition
	assert_false(_RECEIPT_SCRIPT.validate(wrong_type).get("ok", true), "non-bool carried_sequela must reject")


func test_validate_accepts_byte_equal_condition_before_and_after() -> void:
	var receipt := _valid_receipt()
	assert_eq(receipt["condition_before"], receipt["condition_after"],
		"Lucky/Debug/Supportz never directly change the condition triple")
	assert_true(_RECEIPT_SCRIPT.validate(receipt).get("ok", false))


func test_validate_accepts_a_changed_condition_for_a_future_kind() -> void:
	# The shape itself does not forbid a changed condition (that is a caller law, not a structural
	# one) -- only Lucky/Debug/Supportz's OWN participant guarantees byte-equality.
	var receipt := _valid_receipt()
	receipt["condition_after"] = _condition(6, 4, true)
	assert_true(_RECEIPT_SCRIPT.validate(receipt).get("ok", false))


func test_validate_rejects_unsorted_or_duplicate_unlock_receipt_ids() -> void:
	var unsorted := _valid_receipt()
	unsorted["unlock_receipt_ids"] = ["b", "a"]
	assert_false(_RECEIPT_SCRIPT.validate(unsorted).get("ok", true))

	var duplicate := _valid_receipt()
	duplicate["unlock_receipt_ids"] = ["a", "a"]
	assert_false(_RECEIPT_SCRIPT.validate(duplicate).get("ok", true))

	var blank := _valid_receipt()
	blank["unlock_receipt_ids"] = [""]
	assert_false(_RECEIPT_SCRIPT.validate(blank).get("ok", true))

	var sorted_ok := _valid_receipt()
	sorted_ok["unlock_receipt_ids"] = ["a", "b"]
	assert_true(_RECEIPT_SCRIPT.validate(sorted_ok).get("ok", false))


func test_fingerprint_is_deterministic_and_changes_with_content() -> void:
	var receipt := _valid_receipt()
	var first: Dictionary = _RECEIPT_SCRIPT.fingerprint(receipt)
	assert_true(first.get("ok", false), JSON.stringify(first))
	var replay: Dictionary = _RECEIPT_SCRIPT.fingerprint(receipt.duplicate(true))
	assert_eq((first["value"] as Dictionary)["fingerprint"], (replay["value"] as Dictionary)["fingerprint"],
		"identical bytes fingerprint identically")

	var changed := receipt.duplicate(true)
	changed["day"] = 3
	var second: Dictionary = _RECEIPT_SCRIPT.fingerprint(changed)
	assert_true(second.get("ok", false))
	assert_ne((first["value"] as Dictionary)["fingerprint"], (second["value"] as Dictionary)["fingerprint"],
		"a changed field changes the fingerprint")


func test_fingerprint_rejects_an_invalid_receipt() -> void:
	var invalid := _valid_receipt()
	invalid.erase("day")
	var fingerprinted: Dictionary = _RECEIPT_SCRIPT.fingerprint(invalid)
	assert_false(fingerprinted.get("ok", true))
