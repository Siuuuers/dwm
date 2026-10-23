extends "res://addons/gut/test.gd"

const CONTROLLER := preload("res://scripts/application/schedule/ScheduleViewController.gd")
const RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const CAUSAL_DAY := "docket-edit-day"

var _registry: Object
var _registry_fingerprint := ""


func before_each() -> void:
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = loaded["value"]["registry"]
	_registry_fingerprint = loaded["value"]["registry_fingerprint"]


func test_move_packs_by_existing_slot_then_inserts_at_final_ordinal() -> void:
	var controller := _open(3)
	_add_old(controller, "rest", null, 5, "rest-id")
	_add_old(controller, "training", null, 1, "training-id")
	_add_old(controller, "working", null, 6, "working-id")

	var result: Dictionary = controller.apply_docket_edit({
		"kind": "move", "draft_entry_id": "rest-id", "target_index": 0,
	}, _fingerprint(controller))
	assert_true(result.get("ok", false), str(result))
	_assert_entries(result["value"]["view"], ["rest-id", "training-id", "working-id"])


func test_remove_closes_gap_preserves_ids_and_date_latch() -> void:
	var controller := _open(2)
	_add_old(controller, "solo:lavinia:day2", "receipt-lavinia", 4, "date-id")
	_add_old(controller, "rest", null, 6, "rest-id")
	var result: Dictionary = controller.apply_docket_edit({
		"kind": "remove", "draft_entry_id": "date-id",
	}, _fingerprint(controller))
	assert_true(result.get("ok", false), str(result))
	var view: Dictionary = result["value"]["view"]
	_assert_entries(view, ["rest-id"])
	assert_true(view["date_entry_seen"], "the date latch survives removal")


func test_repeatable_append_uses_registry_law_and_publishes_stable_ids() -> void:
	var controller := _open(3)
	_add_old(controller, "training", null, 4, "training-id")
	var first: Dictionary = controller.apply_docket_edit({
		"kind": "append", "action_id": "rest", "source_receipt_id": null,
		"draft_entry_id": "rest-one",
	}, _fingerprint(controller))
	assert_true(first.get("ok", false), str(first))
	var second: Dictionary = controller.apply_docket_edit({
		"kind": "append", "action_id": "rest", "source_receipt_id": null,
		"draft_entry_id": "rest-two",
	}, _fingerprint(controller))
	assert_true(second.get("ok", false), str(second))
	_assert_entries(second["value"]["view"], ["training-id", "rest-one", "rest-two"])


func test_stale_fingerprint_invalid_commands_and_missing_targets_do_not_mutate() -> void:
	var controller := _open(3)
	_add_old(controller, "rest", null, 0, "rest-id")
	var before := _snapshot(controller)
	_refused(controller.apply_docket_edit({
		"kind": "remove", "draft_entry_id": "rest-id",
	}, "stale"), "stale_view_fingerprint")
	_refused(controller.apply_docket_edit({
		"kind": "move", "draft_entry_id": "rest-id", "target_index": 0, "extra": true,
	}, _fingerprint(controller)), "invalid_docket_command")
	_refused(controller.apply_docket_edit({
		"kind": "move", "draft_entry_id": "rest-id", "target_index": 0.0,
	}, _fingerprint(controller)), "invalid_docket_command")
	_refused(controller.apply_docket_edit({
		"kind": "remove", "draft_entry_id": "missing",
	}, _fingerprint(controller)), "draft_entry_not_found")
	_refused(controller.apply_docket_edit({
		"kind": "move", "draft_entry_id": "rest-id", "target_index": 1,
	}, _fingerprint(controller)), "invalid_target_index")
	assert_eq(_snapshot(controller), before)


func test_identity_move_returns_current_view_and_full_docket_refuses_append() -> void:
	var identity := _open(3)
	_add_old(identity, "rest", null, 5, "rest-id")
	var before := _snapshot(identity)
	var unchanged: Dictionary = identity.apply_docket_edit({
		"kind": "move", "draft_entry_id": "rest-id", "target_index": 0,
	}, _fingerprint(identity))
	assert_true(unchanged.get("ok", false), str(unchanged))
	assert_eq(unchanged["value"]["view"], before)

	var full := _open(3)
	for slot: int in range(7):
		_add_old(full, "rest", null, slot, "rest-%d" % slot)
	var full_before := _snapshot(full)
	_refused(full.apply_docket_edit({
		"kind": "append", "action_id": "rest", "source_receipt_id": null,
		"draft_entry_id": "overflow",
	}, _fingerprint(full)), "too_many_entries")
	assert_eq(_snapshot(full), full_before)


func test_day_seven_append_replaces_atomically_and_identical_source_is_unchanged() -> void:
	var controller := _open(7)
	var first: Dictionary = controller.apply_docket_edit({
		"kind": "append", "action_id": "solo:sylvia:day7",
		"source_receipt_id": "source-sylvia", "draft_entry_id": "sylvia-id",
	}, _fingerprint(controller))
	assert_true(first.get("ok", false), str(first))
	var unchanged_before := _snapshot(controller)
	var unchanged: Dictionary = controller.apply_docket_edit({
		"kind": "append", "action_id": "solo:sylvia:day7",
		"source_receipt_id": "source-sylvia", "draft_entry_id": "unused-new-id",
	}, _fingerprint(controller))
	assert_true(unchanged.get("ok", false), str(unchanged))
	assert_eq(unchanged["value"]["view"], unchanged_before)
	for invalid_action: String in ["unregistered", "rest", "solo:lavinia:day2"]:
		var refused: Dictionary = controller.apply_docket_edit({
			"kind": "append", "action_id": invalid_action,
			"source_receipt_id": "source-other", "draft_entry_id": "rejected-id",
		}, _fingerprint(controller))
		assert_false(refused.get("ok", true), str(refused))
		assert_eq(_snapshot(controller), unchanged_before,
			"a failed replacement retains the existing Day-7 destination")

	var replaced: Dictionary = controller.apply_docket_edit({
		"kind": "append", "action_id": "solo:lavinia:day7",
		"source_receipt_id": "source-lavinia", "draft_entry_id": "lavinia-id",
	}, _fingerprint(controller))
	assert_true(replaced.get("ok", false), str(replaced))
	_assert_entries(replaced["value"]["view"], ["lavinia-id"])
	assert_true(replaced["value"]["view"]["date_entry_seen"])
	_refused(controller.apply_docket_edit({
		"kind": "move", "draft_entry_id": "lavinia-id", "target_index": 0,
	}, _fingerprint(controller)), "day7_move_refused")
	var removed: Dictionary = controller.apply_docket_edit({
		"kind": "remove", "draft_entry_id": "lavinia-id",
	}, _fingerprint(controller))
	assert_true(removed.get("ok", false), str(removed))
	_assert_entries(removed["value"]["view"], [])
	assert_true(removed["value"]["view"]["date_entry_seen"])


func _open(day: int) -> Object:
	var controller := CONTROLLER.new()
	assert_true(controller.configure(_registry, RULES, _registry_fingerprint)["ok"])
	assert_true(controller.open_day(day, CAUSAL_DAY)["ok"])
	return controller


func _add_old(controller: Object, action_id: String, source: Variant, slot: int,
		draft_id: String) -> void:
	var prepared: Dictionary = controller.prepare_add(action_id, source, slot, draft_id)
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(controller.commit(prepared["value"]["candidate"])["ok"])


func _fingerprint(controller: Object) -> String:
	return controller.fingerprint()["value"]["fingerprint"]


func _snapshot(controller: Object) -> Dictionary:
	return controller.snapshot()["value"]["view"]


func _assert_entries(view: Dictionary, expected_ids: Array) -> void:
	var entries: Array = view["entries"]
	assert_eq(entries.size(), expected_ids.size())
	for index: int in range(expected_ids.size()):
		assert_eq(entries[index]["draft_entry_id"], expected_ids[index])
		assert_eq(entries[index]["slot_index"], index)


func _refused(result: Dictionary, code: String) -> void:
	assert_false(result.get("ok", true), str(result))
	assert_eq(str(result.get("code", "")), code)
