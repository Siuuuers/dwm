extends "res://addons/gut/test.gd"
## RED/GREEN coverage for the production ScheduleDepartureViewPort (Plan 03, the action-only frozen
## subset at plan02-frozen-contracts.md lines 369-381; created under the dwm-oyo.3 slice authority
## recorded 2026-08-24 on dwm-p2r.21 / dwm-oyo.3).
##
## THE FROZEN SURFACE. `prepare_condition_departure({condition_receipt, causal_sequence_receipt})`
## returns exactly `value={schedule_view_before, schedule_view_after}` with `receipt={}` and no
## mutation. `commit_condition_departure({condition_receipt, schedule_view_before,
## schedule_view_before_sha256, schedule_view_after, schedule_view_after_sha256})` verifies both
## hashes under the retained `causal_transaction` lease, applies before->after atomically, adopts an
## already-departed live view without replay, refuses any third state, retains the receipt keyed by
## `source_condition_receipt_id`, and returns the exact five-key deterministic receipt.
##
## DETERMINISM IS THE CRASH LAW. The receipt carries no minted nonce, so a fresh process retrying
## the same frozen candidate reproduces byte-identical receipt bytes -- proven below across two
## independent port instances.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PORT_PATH := "res://scripts/application/schedule/ScheduleDepartureViewPort.gd"
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## The exact frozen commit-receipt member set (plan02-frozen-contracts.md line 371), sorted.
const RECEIPT_KEYS: Array = [
	"disposition", "schedule_view_after_sha256", "schedule_view_before_sha256",
	"source_condition_receipt_id", "source_condition_receipt_provenance",
]

var _port_script: Script = null
var _gate: ApplicationMutationGate
var _gate_token := ""
var _port: Object = null


func before_each() -> void:
	var loaded: Dictionary = PROBE.load_script(PORT_PATH)
	_port_script = loaded["value"] if loaded.get("ok", false) else null
	_gate = ApplicationMutationGate.new()
	_gate_token = ""
	if _port_script != null:
		_port = _port_script.new()
		assert_true(_port.configure(_gate).get("ok", false))


func _require_port() -> bool:
	if _port_script == null:
		assert_true(false, "the view-port module is absent: " + PORT_PATH)
		return false
	return true


func _acquire_lease() -> void:
	if not _gate.is_internal_owner_active(&"causal_transaction"):
		var acquired: Dictionary = _gate.acquire(&"causal_transaction")
		assert_true(acquired.get("ok", false), JSON.stringify(acquired))
		_gate_token = str((acquired["value"] as Dictionary)["token"])


func _condition_receipt(marker: String) -> Dictionary:
	return {
		"receipt_id": "condition.receipt." + marker,
		"receipt_provenance": {"schema_version": 1, "parent_receipt_id": "root." + marker,
			"child_kind": "condition", "ordinal": 0, "source_ids": ["source." + marker],
			"child_id": "condition.receipt." + marker},
		"decision": "hospital_day",
	}


func _sequence_receipt(marker: String) -> Dictionary:
	return {"receipt_id": "sequence.receipt." + marker, "causal_sequence": 1,
		"causal_day_instance": "causal-day-view-1"}


func _candidate(port: Object, marker: String) -> Dictionary:
	var prepared: Dictionary = port.prepare_condition_departure({
		"condition_receipt": _condition_receipt(marker),
		"causal_sequence_receipt": _sequence_receipt(marker),
	})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var value: Dictionary = prepared["value"]
	var before: Dictionary = value["schedule_view_before"]
	var after: Dictionary = value["schedule_view_after"]
	return {
		"condition_receipt": _condition_receipt(marker),
		"schedule_view_before": before, "schedule_view_before_sha256": _sha(before),
		"schedule_view_after": after, "schedule_view_after_sha256": _sha(after),
	}


static func _sha(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	return str(emitted["value"]).sha256_text()


# ---- module presence ----

func test_view_port_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script(PORT_PATH)
	assert_true(loaded.get("ok", false), "ScheduleDepartureViewPort.gd must load")


# ---- configure ----

func test_configure_rejects_null_and_refuses_a_replacement_gate() -> void:
	if not _require_port():
		return
	var fresh: Object = _port_script.new()
	var null_result: Dictionary = fresh.configure(null)
	assert_false(null_result.get("ok", true))
	var replay: Dictionary = _port.configure(_gate)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_true(bool((replay.get("value", {}) as Dictionary).get("already_configured", false)))
	var replaced: Dictionary = _port.configure(ApplicationMutationGate.new())
	assert_false(replaced.get("ok", true))


# ---- prepare_condition_departure ----

func test_prepare_rejects_extra_or_missing_keys() -> void:
	if not _require_port():
		return
	var extra: Dictionary = _port.prepare_condition_departure({
		"condition_receipt": _condition_receipt("a"),
		"causal_sequence_receipt": _sequence_receipt("a"), "extra": 1})
	assert_false(extra.get("ok", true))
	var missing: Dictionary = _port.prepare_condition_departure({
		"condition_receipt": _condition_receipt("a")})
	assert_false(missing.get("ok", true))


func test_prepare_is_pure_and_projects_before_as_the_live_view() -> void:
	if not _require_port():
		return
	var first: Dictionary = _port.prepare_condition_departure({
		"condition_receipt": _condition_receipt("a"),
		"causal_sequence_receipt": _sequence_receipt("a")})
	assert_true(first.get("ok", false), JSON.stringify(first))
	assert_eq(first["receipt"], {})
	var value: Dictionary = first["value"]
	var value_keys: Array = value.keys()
	value_keys.sort()
	assert_eq(value_keys, ["schedule_view_after", "schedule_view_before"])
	var second: Dictionary = _port.prepare_condition_departure({
		"condition_receipt": _condition_receipt("a"),
		"causal_sequence_receipt": _sequence_receipt("a")})
	assert_eq(second["value"], value, "prepare is pure: identical inputs, identical bytes")
	assert_ne(value["schedule_view_before"], value["schedule_view_after"],
		"the departed view differs from the live view")
	assert_eq(str((value["schedule_view_after"] as Dictionary)["source_condition_receipt_id"]),
		"condition.receipt.a")


# ---- commit_condition_departure ----

func test_commit_requires_the_causal_transaction_lease() -> void:
	if not _require_port():
		return
	var candidate := _candidate(_port, "a")
	var refused: Dictionary = _port.commit_condition_departure(candidate)
	assert_false(refused.get("ok", true))
	assert_eq(refused.get("code"), &"causal_transaction_lease_required")


func test_commit_rejects_extra_or_missing_keys_and_hash_mismatch() -> void:
	if not _require_port():
		return
	_acquire_lease()
	var candidate := _candidate(_port, "a")
	var extra: Dictionary = candidate.duplicate(true)
	extra["extra"] = 1
	var extra_result: Dictionary = _port.commit_condition_departure(extra)
	assert_false(extra_result.get("ok", true))
	var mismatched: Dictionary = candidate.duplicate(true)
	mismatched["schedule_view_after_sha256"] = "00".repeat(32)
	var mismatch_result: Dictionary = _port.commit_condition_departure(mismatched)
	assert_false(mismatch_result.get("ok", true))
	assert_eq(mismatch_result.get("code"), &"schedule_view_hash_mismatch")


func test_commit_applies_the_departure_and_returns_the_exact_receipt() -> void:
	if not _require_port():
		return
	_acquire_lease()
	var candidate := _candidate(_port, "a")
	var committed: Dictionary = _port.commit_condition_departure(candidate)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	var receipt: Dictionary = committed["receipt"]
	var keys: Array = receipt.keys()
	keys.sort()
	assert_eq(keys, RECEIPT_KEYS)
	assert_eq(str(receipt["source_condition_receipt_id"]), "condition.receipt.a")
	assert_eq(str(receipt["disposition"]), "condition_departure_view_committed")
	assert_eq(str(receipt["schedule_view_before_sha256"]),
		str(candidate["schedule_view_before_sha256"]))
	assert_eq(str(receipt["schedule_view_after_sha256"]),
		str(candidate["schedule_view_after_sha256"]))
	# The live view is now the departed view: a fresh prepare's BEFORE equals the committed AFTER.
	var next_prepare: Dictionary = _port.prepare_condition_departure({
		"condition_receipt": _condition_receipt("b"),
		"causal_sequence_receipt": _sequence_receipt("b")})
	assert_eq((next_prepare["value"] as Dictionary)["schedule_view_before"],
		candidate["schedule_view_after"])


func test_commit_replay_returns_the_original_receipt_without_reapplying() -> void:
	if not _require_port():
		return
	_acquire_lease()
	var candidate := _candidate(_port, "a")
	var first: Dictionary = _port.commit_condition_departure(candidate)
	assert_true(first.get("ok", false), JSON.stringify(first))
	var replay: Dictionary = _port.commit_condition_departure(candidate.duplicate(true))
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay["receipt"], first["receipt"], "replay returns the retained receipt bytes")


func test_commit_conflicts_on_changed_bytes_under_the_same_source_condition() -> void:
	if not _require_port():
		return
	_acquire_lease()
	var candidate := _candidate(_port, "a")
	var committed: Dictionary = _port.commit_condition_departure(candidate)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	var changed: Dictionary = candidate.duplicate(true)
	(changed["schedule_view_after"] as Dictionary)["state"] = "forged"
	changed["schedule_view_after_sha256"] = _sha(changed["schedule_view_after"])
	var conflicted: Dictionary = _port.commit_condition_departure(changed)
	assert_false(conflicted.get("ok", true))
	assert_eq(conflicted.get("code"), &"schedule_view_conflict")


func test_commit_refuses_a_third_live_state() -> void:
	if not _require_port():
		return
	_acquire_lease()
	var stale := _candidate(_port, "a")
	var interloper := _candidate(_port, "b")
	assert_true(_port.commit_condition_departure(interloper).get("ok", false))
	var refused: Dictionary = _port.commit_condition_departure(stale)
	assert_false(refused.get("ok", true))
	assert_eq(refused.get("code"), &"schedule_view_state_conflict")


func test_the_receipt_is_deterministic_across_independent_instances() -> void:
	if not _require_port():
		return
	_acquire_lease()
	var candidate := _candidate(_port, "a")
	var first: Dictionary = _port.commit_condition_departure(candidate)
	assert_true(first.get("ok", false), JSON.stringify(first))
	# A fresh process retrying the same frozen candidate: same bytes in, same receipt out.
	var second_port: Object = _port_script.new()
	assert_true(second_port.configure(_gate).get("ok", false))
	var retried: Dictionary = second_port.commit_condition_departure(candidate.duplicate(true))
	assert_true(retried.get("ok", false), JSON.stringify(retried))
	assert_eq(retried["receipt"], first["receipt"],
		"the receipt derives from candidate bytes alone, so crash-retry reproduces it")

# Production uses the same saved controller for drafting, restore, and condition departure.
func _saved_controller(saved: Variant = null) -> Object:
	var loaded: Dictionary = preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd").load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	var controller: Object = preload("res://scripts/application/schedule/ScheduleViewController.gd").new()
	assert_true(controller.configure(loaded["value"]["registry"],
		preload("res://scripts/domain/schedule/ScheduleRules.gd"),
		str(loaded["value"]["registry"].fingerprint())).get("ok", false))
	if saved == null:
		assert_true(controller.open_day(1, "causal-day-view-1").get("ok", false))
	else:
		assert_true(controller.install_restored_view(saved).get("ok", false))
	return controller


func _owner_port(controller: Object) -> Object:
	var port: Object = _port_script.new()
	assert_true(port.configure(_gate).get("ok", false))
	assert_true(port.configure_view_controller(controller).get("ok", false))
	return port


func _owner_candidate(port: Object, controller: Object, marker: String) -> Dictionary:
	var view: Dictionary = controller.snapshot()["value"]["view"]
	var condition := _condition_receipt(marker)
	condition["day"] = view["day"]
	condition["causal_day_instance"] = view["causal_day_instance"]
	condition["causal_sequence_receipt_id"] = "sequence.receipt." + marker
	var sequence := _sequence_receipt(marker)
	sequence["causal_day_instance"] = view["causal_day_instance"]
	var prepared: Dictionary = port.prepare_condition_departure({
		"condition_receipt": condition, "causal_sequence_receipt": sequence,
	})
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return {}
	return {"condition_receipt": condition,
		"schedule_view_before": prepared["value"]["schedule_view_before"],
		"schedule_view_before_sha256": _sha(prepared["value"]["schedule_view_before"]),
		"schedule_view_after": prepared["value"]["schedule_view_after"],
		"schedule_view_after_sha256": _sha(prepared["value"]["schedule_view_after"])}


func _add_docket_entry(controller: Object, action_id: String, slot: int, draft_id: String) -> void:
	var added: Dictionary = controller.prepare_add(action_id, null, slot, draft_id)
	assert_true(added.get("ok", false), str(added))
	if added.get("ok", false):
		assert_true(controller.commit(added["value"]["candidate"]).get("ok", false))


func test_bound_departure_uses_the_saved_docket_and_appends_its_receipt_to_that_owner() -> void:
	if not _require_port(): return
	var controller := _saved_controller()
	var port := _owner_port(controller)
	assert_true(port.configure_view_controller(controller).get("ok", false))
	assert_false(port.configure_view_controller(_saved_controller()).get("ok", true),
		"the production owner cannot be replaced")
	_add_docket_entry(controller, "rest", 0, "draft-rest")
	var source: Dictionary = controller.snapshot()["value"]["view"]
	var candidate := _owner_candidate(port, controller, "saved-a")
	assert_eq(controller.snapshot()["value"]["view"], source, "preparation is read-only")
	assert_eq(candidate["schedule_view_before"], source)
	assert_eq(candidate["schedule_view_after"]["entries"], [])
	assert_eq(candidate["schedule_view_after"]["condition_departure_receipts"],
		source["condition_departure_receipts"], "frozen views share the exact predecessor ledger")
	_acquire_lease()
	var committed: Dictionary = port.commit_condition_departure(candidate)
	assert_true(committed.get("ok", false), str(committed))
	var after: Dictionary = controller.snapshot()["value"]["view"]
	assert_eq(after["entries"], [])
	assert_eq(after["condition_departure_receipts"]["condition.receipt.saved-a"], committed["receipt"])
	assert_eq(port._retained, {}, "production keeps no duplicate receipt ledger")
	assert_eq(port._live_view, {"schema_version": 1, "state": "empty"},
		"the legacy private view is never involved")


func test_second_departure_recovers_with_fresh_controller_and_retries_after_a_later_day() -> void:
	if not _require_port(): return
	var controller := _saved_controller()
	var port := _owner_port(controller)
	_acquire_lease()
	assert_true(port.commit_condition_departure(_owner_candidate(port, controller, "first")).get("ok", false))
	assert_true(controller.open_day(2, "causal-day-view-2").get("ok", false))
	_add_docket_entry(controller, "rest", 0, "day-two-rest")
	var source: Dictionary = controller.capture()["value"]["backup"]
	var second := _owner_candidate(port, controller, "second")
	var recovered_controller := _saved_controller(source)
	var recovered_port := _owner_port(recovered_controller)
	var recovered: Dictionary = recovered_port.commit_condition_departure(second)
	assert_true(recovered.get("ok", false), str(recovered))
	var completed: Dictionary = recovered_controller.capture()["value"]["backup"]
	assert_eq(completed["condition_departure_receipts"].size(), 2,
		"the same saved owner keeps both the prior and recovered departure")
	assert_eq(completed["entries"], [])
	var after_restart := _saved_controller(completed)
	var after_port := _owner_port(after_restart)
	assert_true(after_restart.open_day(3, "causal-day-view-3").get("ok", false))
	_add_docket_entry(after_restart, "rest", 0, "day-three-rest")
	var later_day: Dictionary = after_restart.capture()["value"]["backup"]
	var retry: Dictionary = after_port.commit_condition_departure(second)
	assert_true(retry.get("ok", false), str(retry))
	assert_eq(retry["receipt"], recovered["receipt"])
	assert_eq(after_restart.capture()["value"]["backup"], later_day,
		"the saved receipt proves replay without rewinding or clearing a later day's docket")


func test_bound_departure_refuses_a_third_view_or_conflicting_saved_receipt_without_mutation() -> void:
	if not _require_port(): return
	var controller := _saved_controller()
	var port := _owner_port(controller)
	_add_docket_entry(controller, "rest", 0, "draft-rest")
	var candidate := _owner_candidate(port, controller, "conflict")
	_add_docket_entry(controller, "training", 1, "draft-training")
	var third: Dictionary = controller.capture()["value"]["backup"]
	_acquire_lease()
	var refused: Dictionary = port.commit_condition_departure(candidate)
	assert_false(refused.get("ok", true))
	assert_eq(refused.get("code"), &"schedule_view_state_conflict")
	assert_eq(controller.capture()["value"]["backup"], third)
	assert_true(controller.install_restored_view(candidate["schedule_view_before"]).get("ok", false))
	assert_true(port.commit_condition_departure(candidate).get("ok", false))
	var after: Dictionary = controller.capture()["value"]["backup"]
	var changed := candidate.duplicate(true)
	changed["schedule_view_after"]["date_entry_seen"] = true
	changed["schedule_view_after_sha256"] = _sha(changed["schedule_view_after"])
	refused = port.commit_condition_departure(changed)
	assert_false(refused.get("ok", true))
	assert_eq(refused.get("code"), &"schedule_view_conflict")
	assert_eq(controller.capture()["value"]["backup"], after)
