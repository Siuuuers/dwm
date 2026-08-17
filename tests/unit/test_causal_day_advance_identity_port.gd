extends "res://addons/gut/test.gd"

# Contract tests for the day-advance identity port (Plan 02 Task 1, dwm-p2r.16).
# Step 1.3 pins:
#   * exact request/receipt shapes
#   * deterministic prepare semantics
#   * stale/conflict failure mapping

const PORT := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

const PORT_PATH := "res://scripts/application/run/CausalDayAdvanceIdentityPort.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"

const NAMESPACE := "1111111111111111111111111111111111111111111111111111111111111111"

var _root: FAKE_ROOT_STORE
var _issuer: ISSUER
var _port: PORT


func before_each() -> void:
	_root = FAKE_ROOT_STORE.new(NAMESPACE, 1)
	_issuer = ISSUER.new()
	_port = PORT.new()
	var configured := _issuer.configure(_root)
	if not configured.get("ok", false):
		assert_true(false, "test setup requires issuer configure to succeed: %s" % configured)


func test_causal_day_advance_identity_port_skeleton_loads() -> void:
	var probe := DynamicScriptProbe.load_script(PORT_PATH)
	assert_true(probe.get("ok", false),
		"CausalDayAdvanceIdentityPort must parse and load: %s" % str(probe.get("message", "")))


func test_port_configuration_legacy_semantics() -> void:
	var probe: Dictionary = _port.configure(_issuer)
	assert_true(probe.get("ok", false), "configure() on first issuer must succeed")
	assert_false(probe.get("value", {})["already_configured"], "first configure marks first assignment")
	var replay: Dictionary = _port.configure(_issuer)
	assert_true(replay.get("ok", false), "configure same issuer again is idempotent")
	assert_true(replay.get("value", {}).get("already_configured"), "idempotent configure marks already_configured")

	var other_issuer := ISSUER.new()
	other_issuer.configure(_root)
	var replaced: Dictionary = _port.configure(other_issuer)
	assert_false(replaced.get("ok", true),
		"configure may not swap a retained identity issuer")
	assert_eq(replaced.get("code", &""), &"causal_day_advance_identity_already_configured",
		"configure replacement keeps its own code")


func test_prepare_advance_requires_configuration() -> void:
	var prepared: Dictionary = _port.prepare_advance(_request("schedule_done"))
	_assert_rejected(prepared, "prepare_advance before configure")
	assert_eq(prepared.get("code", &""), &"causal_day_advance_identity_not_configured")


func test_prepare_advance_rejects_request_shape() -> void:
	var port: Object = _configured_port()
	if port == null:
		return

	var missing_member: Dictionary = _request("schedule_done")
	missing_member.erase("run_id")
	var missing_result: Dictionary = port.prepare_advance(missing_member)
	_assert_rejected(missing_result, "prepare_advance with missing request members")
	assert_eq(missing_result.get("code", &""), &"causal_day_advance_request_member_set_invalid")

	var extra_member: Dictionary = _request("schedule_done")
	extra_member["extra"] = "unexpected"
	var extra_result: Dictionary = port.prepare_advance(extra_member)
	_assert_rejected(extra_result, "prepare_advance with extra request members")
	assert_eq(extra_result.get("code", &""), &"causal_day_advance_request_member_set_invalid")


func test_prepare_advance_rejects_bad_request_fields() -> void:
	var port: Object = _configured_port()
	if port == null:
		return

	var blank_run_id: Dictionary = _request("schedule_done")
	blank_run_id["run_id"] = ""
	var blank_run_id_result: Dictionary = port.prepare_advance(blank_run_id)
	_assert_rejected(blank_run_id_result, "prepare_advance with blank run_id")
	assert_eq(blank_run_id_result.get("code", &""), &"causal_day_advance_request_field_invalid")

	var bad_resolution: Dictionary = _request("bad-kind")
	var bad_resolution_result: Dictionary = port.prepare_advance(bad_resolution)
	_assert_rejected(bad_resolution_result, "prepare_advance with unsupported resolution_kind")
	assert_eq(bad_resolution_result.get("code", &""), &"causal_day_advance_resolution_kind_invalid")

	var source_day_too_low: Dictionary = _request("schedule_done")
	source_day_too_low["source_day"] = 0
	var low_result: Dictionary = port.prepare_advance(source_day_too_low)
	_assert_rejected(low_result, "prepare_advance with source_day below 1")
	assert_eq(low_result.get("code", &""), &"causal_day_advance_source_day_invalid")

	var source_day_too_high: Dictionary = _request("schedule_done")
	source_day_too_high["source_day"] = 7
	var high_result: Dictionary = port.prepare_advance(source_day_too_high)
	_assert_rejected(high_result, "prepare_advance with source_day above 6")
	assert_eq(high_result.get("code", &""), &"causal_day_advance_source_day_invalid")


func test_prepare_advance_rejects_source_token_mismatch() -> void:
	var port: Object = _configured_port()
	if port == null:
		return
	var mismatch: Dictionary = _request("schedule_done")
	mismatch["source_causal_day_instance"] = "wrong-token"
	var rejected: Dictionary = port.prepare_advance(mismatch)
	_assert_rejected(rejected, "prepare_advance with mismatched source token")
	assert_eq(rejected.get("code", &""), &"causal_day_advance_source_token_mismatch")


func test_prepare_advance_rejects_invalid_resolution_ancestry() -> void:
	var port: Object = _configured_port()
	if port == null:
		return
	var wrong_child: Dictionary = _request("schedule_done")
	(wrong_child["source_resolution_receipt"] as Dictionary)["provenance"]["child_kind"] = "sylvia_hospital_witness"
	var rejected: Dictionary = port.prepare_advance(wrong_child)
	_assert_rejected(rejected, "prepare_advance with ancestry child mismatch")
	assert_eq(rejected.get("code", &""), &"child_kind_mismatch")


func test_prepare_advance_rejects_occupied_source_tuple() -> void:
	var port: Object = _configured_port()
	if port == null:
		return

	var baseline_request: Dictionary = _request("schedule_done")
	var tuple_key: String = "schedule_done:" + str((baseline_request["source_resolution_receipt"] as Dictionary).get("receipt_id", ""))
	_root.day_advance_allocation_receipts["other-allocation-key"] = {
		"run_id": str(baseline_request["run_id"]),
		"branch_id": str(baseline_request["branch_id"]),
		"desktop_timeline_generation": int(baseline_request["desktop_timeline_generation"]),
		"source_causal_day_instance": str(baseline_request["source_causal_day_instance"]),
		"source_day": int(baseline_request["source_day"]),
	}

	var rejected: Dictionary = port.prepare_advance(baseline_request)
	_assert_rejected(rejected, "prepare_advance at an occupied source tuple key")
	assert_eq(rejected.get("code", &""), &"causal_day_advance_identity_conflict")
	assert_eq(_root.calls_to(&"prepare_causal_day_advance").size(), 0,
		"conflict must be detected before any root prepare attempt")


func test_prepare_advance_returns_reproducible_receipt_and_does_not_mutate_request() -> void:
	var port: Object = _configured_port()
	if port == null:
		return

	var source_request: Dictionary = _request("condition_hospital")
	var source_request_snapshot: Dictionary = source_request.duplicate(true)
	var target_receipt: Dictionary = _target_receipt()
	var allocation_key: String = "condition_hospital:" + str((source_request["source_resolution_receipt"] as Dictionary).get("receipt_id", ""))

	_root.arm(&"prepare_causal_day_advance", {"ok": true, "value": {
		"schema_version": 1,
		"allocation_key": allocation_key,
		"root_next_counter": 9,
		"target_causal_day_instance_issuer_receipt": target_receipt.duplicate(true),
	}})

	var prepared: Dictionary = port.prepare_advance(source_request)
	if not _require_ok(prepared, "prepare_advance with a valid request"):
		return

	assert_eq(source_request, source_request_snapshot,
		"prepare_advance must be mutation-free")
	var prepared_receipt: Dictionary = prepared["value"]["day_advance_identity_receipt"]
	assert_eq(str(prepared_receipt.get("disposition", "")),
		"causal_day_advance_identity_allocated", "prepare_advance allocates the day-advance receipt")
	assert_eq(prepared_receipt.get("resolution_kind"), "condition_hospital")
	assert_eq(prepared_receipt.get("source_day"), int(source_request["source_day"]))
	assert_eq(prepared_receipt.get("target_day"), int(source_request["source_day"]) + 1)
	assert_eq(prepared_receipt.get("target_causal_day_instance"), str(target_receipt["token"]),
		"target token comes from the root proposal")
	assert_eq(typeof(prepared_receipt.get("root_before_fingerprint", "")), TYPE_STRING,
		"root_before_fingerprint is a canonical fingerprint string")

	var candidate_calls: Array[Dictionary] = _root.calls_to(&"prepare_causal_day_advance")
	assert_eq(candidate_calls.size(), 1,
		"prepare_advance must call root.prepare_causal_day_advance exactly once for valid input")
	var candidate_argument: Dictionary = candidate_calls[0]["argument"]
	assert_eq(candidate_argument.get("resolution_kind", ""), "condition_hospital")
	assert_eq(candidate_argument.get("source_resolution_receipt_id", ""),
		str((source_request["source_resolution_receipt"] as Dictionary).get("receipt_id", "")))

	var duplicated_receipt: Dictionary = (prepared["value"]["day_advance_identity_candidate"] as Dictionary).get("day_advance_identity_receipt", {})
	assert_eq(duplicated_receipt, prepared_receipt,
		"prepare returns both candidate and receipt with identical content")


func test_commit_advance_requires_configuration() -> void:
	var candidate: Dictionary = _candidate("schedule_done")
	var committed: Dictionary = _port.commit_advance(candidate)
	_assert_rejected(committed, "commit_advance before configure")
	assert_eq(committed.get("code", &""), &"causal_day_advance_identity_not_configured")


func test_commit_advance_rejects_request_shape() -> void:
	var port: Object = _configured_port()
	if port == null:
		return

	var missing_candidate_key: Dictionary = {"day_advance_identity_receipt": {}}
	var missing_candidate: Dictionary = {}
	var missing_key_result: Dictionary = port.commit_advance(missing_candidate)
	_assert_rejected(missing_key_result, "commit_advance with missing candidate key")
	assert_eq(missing_key_result.get("code", &""), &"causal_day_advance_request_member_set_invalid")

	var missing_receipt_key: Dictionary = _candidate("schedule_done")
	missing_receipt_key["day_advance_identity_receipt"].erase("schema_version")
	var missing_receipt_result: Dictionary = port.commit_advance(missing_receipt_key)
	_assert_rejected(missing_receipt_result, "commit_advance with malformed receipt")
	assert_eq(missing_receipt_result.get("code", &""), &"causal_day_advance_request_member_set_invalid")


func test_commit_advance_rejects_stale_root_state_as_identity_stale() -> void:
	var port: Object = _configured_port()
	if port == null:
		return

	var candidate: Dictionary = _candidate("schedule_done")
	_root.arm(&"commit_causal_day_advance", {"ok": false, "code": &"allocation_counter_superseded", "message": "superseded"})
	var committed: Dictionary = port.commit_advance(candidate)
	_assert_rejected(committed, "commit_advance with stale root candidate")
	assert_eq(committed.get("code", &""), &"causal_day_advance_identity_stale")


func test_commit_advance_rejects_conflict_as_identity_conflict() -> void:
	var port: Object = _configured_port()
	if port == null:
		return

	var candidate: Dictionary = _candidate("schedule_done")
	_root.arm(&"commit_causal_day_advance", {"ok": false, "code": &"causal_day_advance_conflict", "message": "conflict"})
	var committed: Dictionary = port.commit_advance(candidate)
	_assert_rejected(committed, "commit_advance with root conflict")
	assert_eq(committed.get("code", &""), &"causal_day_advance_identity_conflict")


func test_commit_advance_accepts_a_legitimate_candidate() -> void:
	var port: Object = _configured_port()
	if port == null:
		return

	var candidate: Dictionary = _candidate("schedule_done")
	var expected_receipt: Dictionary = candidate.get("day_advance_identity_receipt", {}).duplicate(true)
	_root.arm(&"commit_causal_day_advance", {
		"ok": true,
		"value": {"day_advance_identity_receipt": {"schema_version": 1}},
	})
	var committed: Dictionary = port.commit_advance(candidate)
	if not _require_ok(committed, "commit_advance with a valid candidate"):
		return

	var committed_receipt: Dictionary = committed["value"]["day_advance_identity_receipt"]
	assert_eq(committed_receipt, expected_receipt,
		"commit_advance returns the exact receipt candidate payload")
	assert_eq(_root.calls_to(&"commit_causal_day_advance").size(), 1,
		"commit_advance must call root.commit_causal_day_advance once")


func _configured_port() -> Object:
	var configured := _port.configure(_issuer)
	if not _require_ok(configured, "configure in _configured_port"):
		return null
	return _port


func _request(resolution_kind: String = "schedule_done") -> Dictionary:
	var source_receipt := _source_receipt()
	var resolution_receipt := _source_resolution_receipt(resolution_kind)
	return {
		"branch_id": "branch-id-1",
		"run_id": "run-id-1",
		"desktop_timeline_generation": 2,
		"resolution_kind": resolution_kind,
		"source_day": 3,
		"source_causal_day_instance": str(source_receipt["token"]),
		"source_causal_day_instance_issuer_receipt": source_receipt.duplicate(true),
		"source_resolution_receipt": resolution_receipt.duplicate(true),
	}


func _source_resolution_receipt(resolution_kind: String) -> Dictionary:
	var parent := _transaction_receipt()
	var child_kind := _expected_resolution_child_kind(resolution_kind)
	return {
		"receipt_id": "source-resolution-%s" % resolution_kind,
		"provenance": {
			"schema_version": 1,
			"child_kind": child_kind,
			"parent_receipt_id": str(parent.get("receipt_id", "")),
			"ordinal": 0,
			"source_ids": [],
			"child_id": "source-resolution.%s" % str(parent.get("receipt_id", "")),
		},
	}


func _expected_resolution_child_kind(resolution_kind: String) -> String:
	if resolution_kind == "schedule_done":
		return "day_resolution_stage"
	if resolution_kind == "condition_hospital":
		return "hospital_resolution"
	return "day_resolution_stage"


func _source_receipt() -> Dictionary:
	var source := _root.mint(&"causal_day_instance")
	var parent := _transaction_receipt()
	source["provenance"] = {
		"schema_version": 1,
		"child_kind": "day_resolution_stage",
		"parent_receipt_id": str(parent.get("receipt_id", "")),
		"ordinal": 0,
		"source_ids": [],
		"child_id": "source.%s" % str(source.get("token", "")),
	}
	_root.receipts[str(source["receipt_id"])] = source.duplicate(true)
	return source


func _transaction_receipt() -> Dictionary:
	return _root.mint(&"transaction_id")


func _target_receipt() -> Dictionary:
	return _root.mint(&"causal_day_instance").duplicate(true)


func _candidate(resolution_kind: String) -> Dictionary:
	var request: Dictionary = _request(resolution_kind)
	var source_receipt: Dictionary = request["source_causal_day_instance_issuer_receipt"]
	var resolution_receipt: Dictionary = request["source_resolution_receipt"]
	var target_receipt := _target_receipt()
	return {
		"day_advance_identity_receipt": {
			"schema_version": 1,
			"allocation_key": "%s:%s" % [resolution_kind, str(resolution_receipt.get("receipt_id", ""))],
			"resolution_kind": resolution_kind,
			"source_resolution_receipt_id": str(resolution_receipt.get("receipt_id", "")),
			"source_resolution_receipt_provenance": {},
			"source_resolution_receipt_sha256": "source-resolution-sha256",
			"run_id": str(request["run_id"]),
			"branch_id": str(request["branch_id"]),
			"desktop_timeline_generation": int(request["desktop_timeline_generation"]),
			"source_day": int(request["source_day"]),
			"target_day": int(request["source_day"]) + 1,
			"source_causal_day_instance": str(source_receipt.get("token", "")),
			"source_causal_day_instance_receipt_id": str(source_receipt.get("receipt_id", "")),
			"source_causal_day_instance_issuer_receipt": source_receipt.duplicate(true),
			"target_causal_day_instance": str(target_receipt.get("token", "")),
			"target_causal_day_instance_issuer_receipt": target_receipt,
			"request_sha256": "request-sha256",
			"root_before_fingerprint": "before-fingerprint",
			"counter_start": 3,
			"counter_end": 4,
			"disposition": "causal_day_advance_identity_allocated",
		},
	}


func _require_ok(result: Dictionary, label: String) -> bool:
	var ok: bool = result.get("ok", false)
	assert_true(ok, "%s must succeed: %s" % [label, result])
	return ok


func _assert_rejected(result: Dictionary, label: String) -> void:
	assert_false(result.get("ok", true), "%s must be rejected" % label)
	assert_ne(result.get("code", &"not_implemented"), &"not_implemented",
		"%s must reject with a real production code, not the skeleton envelope" % label)
