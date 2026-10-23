extends "res://addons/gut/test.gd"
# Saved ScheduleView schema law (Amendment Plan 03 Task 2 Step 1, dwm-oyo.3).
#
# The top-level view is EXACTLY the seven-key shape the plan freezes; each entry is exactly
# the seven-key draft entry; the condition-departure receipt index is an append-only
# Dictionary keyed by exact source_condition_receipt_id with the exact five-key value shape.
# Registry-owned facts (route, effects, cost) and commit-owned facts (state, transaction) are
# never legal view members. validate() resolves every action ID through the injected
# immutable registry at the expected fingerprint -- a fingerprint string alone is never proof
# -- and a null fingerprint is legal only for an empty view during accepted legacy-empty
# restore. The optimistic fingerprint excludes only condition_departure_receipts.
#
# RED VALIDITY (plan Global Constraints line 40): the compiling ScheduleViewState skeleton
# exists and every method returns the typed not_implemented envelope, so every failure below
# is a typed wrong-behavior result, never a missing file/preload/parse error.

const VIEW_STATE := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const REGISTRY_FIXTURES := preload("res://tests/support/ScheduleRegistryFixtures.gd")

const CAUSAL_DAY := "causal_day_instance.1111111111111111111111111111111111111111111111111111111111111111"
const ENVELOPE_SUCCESS_KEYS: Array = ["code", "ok", "receipt", "value"]
const VIEW_KEYS: Array = [
	"causal_day_instance", "condition_departure_receipts", "consumed_warning_receipts",
	"date_entry_seen", "day", "entries", "pending_warning",
]
const RECEIPT_KEYS: Array = [
	"disposition", "schedule_view_after_sha256", "schedule_view_before_sha256",
	"source_condition_receipt_id", "source_condition_receipt_provenance",
]

var _registry: Object = null
var _fingerprint := ""


func before_each() -> void:
	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded.get("value", {}) as Dictionary).get("registry_fingerprint", ""))


# ---- builders ----

func _entry(draft_entry_id: String, day: int, slot_index: int, action_id: String,
		action_kind: String, participants: Array, source_receipt_id: Variant) -> Dictionary:
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": action_kind,
		"participants": participants.duplicate(),
		"source_receipt_id": source_receipt_id,
	}


func _ordinary(draft_entry_id: String, slot: int, action_id: String, day := 3) -> Dictionary:
	return _entry(draft_entry_id, day, slot, action_id, "ordinary", [], null)


func _solo(draft_entry_id: String, slot: int, friend_id: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend_id, day]
	return _entry(draft_entry_id, day, slot, action_id, "solo", [friend_id], "src:" + action_id)


func _group(draft_entry_id: String, slot: int, day: int) -> Dictionary:
	var action_id := "group:priscilla_lavinia:day%d" % day
	return _entry(draft_entry_id, day, slot, action_id, "group", ["priscilla", "lavinia"],
		"src:" + action_id)


func _view(day: int, entries: Array, overrides: Dictionary = {}) -> Dictionary:
	var has_date := false
	for entry: Dictionary in entries:
		if str(entry.get("action_kind", "")) != "ordinary":
			has_date = true
	var view := {
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"entries": entries.duplicate(true),
		"date_entry_seen": has_date,
		"pending_warning": null,
		"consumed_warning_receipts": {},
		"condition_departure_receipts": {},
	}
	for key: String in overrides:
		view[key] = overrides[key]
	return view


func _condition_receipt(source_id: String) -> Dictionary:
	return {
		"source_condition_receipt_id": source_id,
		"source_condition_receipt_provenance": {
			"schema_version": 1, "parent_receipt_id": "cmd-root",
			"child_kind": "condition_departure", "ordinal": 0, "source_ids": [],
			"child_id": source_id,
		},
		"schedule_view_before_sha256": "a".repeat(64),
		"schedule_view_after_sha256": "b".repeat(64),
		"disposition": "condition_departure_view_committed",
	}


func _ledger_view(receipt: Dictionary, key: Variant = null) -> Dictionary:
	var ledger_key := str(receipt["source_condition_receipt_id"]) if key == null else str(key)
	return _view(3, [_ordinary("d1", 0, "rest")],
		{"condition_departure_receipts": {ledger_key: receipt}})


func _stale_registry() -> Dictionary:
	var built: Dictionary = REGISTRY.from_manifest({
		"schema_version": 1, "kind": "schedule_actions", "registry_version": 1,
		"records": REGISTRY_FIXTURES.stale_records(),
	})
	assert_true(built.get("ok", false), str(built))
	var value: Dictionary = built.get("value", {})
	return {"registry": value.get("registry"),
		"fingerprint": str(value.get("registry_fingerprint", ""))}


func _day7_group_registry() -> Dictionary:
	var records: Array = REGISTRY_FIXTURES.default_records()
	records.append({
		"action_id": "group:priscilla_lavinia:day7", "allowed_days": [7],
		"action_kind": "group", "participants": ["priscilla", "lavinia"],
		"repeatable": false, "motivation_cost": 1, "route_id": null, "effect_ids": [],
		"source_receipt_kind": "group_reply_acceptance",
	})
	records.sort_custom(func(left: Dictionary, right: Dictionary) -> bool:
		return str(left["action_id"]) < str(right["action_id"]))
	var built: Dictionary = REGISTRY.from_manifest({
		"schema_version": 1, "kind": "schedule_actions", "registry_version": 1,
		"records": records,
	})
	assert_true(built.get("ok", false), str(built))
	var value: Dictionary = built.get("value", {})
	return {"registry": value.get("registry"),
		"fingerprint": str(value.get("registry_fingerprint", ""))}


func _validate(view: Dictionary) -> Dictionary:
	return VIEW_STATE.validate(view, _registry, _fingerprint)


func _code(result: Dictionary) -> String:
	return str(result.get("code", ""))


func _keys_of(value: Dictionary) -> Array:
	var keys: Array = value.keys()
	keys.sort()
	return keys


func _canonical(value: Variant) -> String:
	var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted.get("value", ""))


func _fingerprint_value(view: Dictionary, registry: Object, expected: Variant) -> String:
	var result: Dictionary = VIEW_STATE.fingerprint(view, registry, expected)
	assert_true(result.get("ok", false), "fingerprint: " + str(result))
	return str((result.get("value", {}) as Dictionary).get("fingerprint", ""))


# ---- make_empty ----

func test_make_empty_returns_the_exact_seven_key_empty_view() -> void:
	var made: Dictionary = VIEW_STATE.make_empty(3, CAUSAL_DAY)
	assert_true(made.get("ok", false), str(made))
	assert_eq(_keys_of(made), ENVELOPE_SUCCESS_KEYS, "the master success envelope")
	var value: Dictionary = made.get("value", {})
	assert_eq(_keys_of(value), ["view"], "the success value is exactly {view}")
	var view: Dictionary = value.get("view", {})
	assert_eq(_keys_of(view), VIEW_KEYS, "the view is exactly the seven-key shape")
	assert_eq(int(view.get("day", -1)), 3, "day")
	assert_eq(str(view.get("causal_day_instance", "")), CAUSAL_DAY, "causal day instance")
	assert_eq((view.get("entries", ["x"]) as Array).size(), 0, "entries start empty")
	assert_eq(view.get("date_entry_seen", true), false, "date_entry_seen starts false")
	assert_null(view.get("pending_warning", "x"), "pending_warning starts null")
	assert_eq((view.get("consumed_warning_receipts", {"x": 1}) as Dictionary).size(), 0,
		"consumed_warning_receipts starts empty")
	assert_eq((view.get("condition_departure_receipts", {"x": 1}) as Dictionary).size(), 0,
		"condition_departure_receipts starts empty")


func test_make_empty_rejects_days_zero_and_eight() -> void:
	assert_eq(_code(VIEW_STATE.make_empty(0, CAUSAL_DAY)), "invalid_day", "day zero refused")
	assert_eq(_code(VIEW_STATE.make_empty(8, CAUSAL_DAY)), "invalid_day", "day eight refused")


func test_make_empty_rejects_a_blank_causal_day_instance() -> void:
	assert_eq(_code(VIEW_STATE.make_empty(3, "")), "invalid_causal_day_instance",
		"a blank causal day instance is refused")


# ---- validate: acceptance ----

func test_validate_accepts_the_empty_view_and_null_fingerprint_only_when_empty() -> void:
	var empty := _view(3, [])
	assert_true(_validate(empty).get("ok", false), str(_validate(empty)))
	assert_true(VIEW_STATE.validate(empty, _registry, null).get("ok", false),
		"a null fingerprint is legal for an empty view during accepted legacy-empty restore")
	var populated := _view(3, [_ordinary("d1", 0, "rest")])
	assert_eq(_code(VIEW_STATE.validate(populated, _registry, null)),
		"invalid_expected_fingerprint",
		"a null fingerprint is refused for any nonempty view")


func test_validate_accepts_a_full_ordinary_day_and_a_two_date_day() -> void:
	var entries: Array = []
	for slot: int in range(7):
		entries.append(_ordinary("d%d" % slot, slot, ["rest", "training", "working"][slot % 3]))
	var full := _validate(_view(3, entries))
	assert_true(full.get("ok", false), "seven ordinary slots fill Days 1-6: " + str(full))
	var dates := _validate(_view(6, [_solo("a", 0, "priscilla", 6), _solo("b", 1, "lavinia", 6)]))
	assert_true(dates.get("ok", false), "two dates are legal: " + str(dates))


# ---- validate: top-level shape ----

func test_validate_rejects_a_missing_an_unknown_and_an_aliased_top_level_key() -> void:
	var missing := _view(3, [])
	missing.erase("entries")
	assert_eq(_code(_validate(missing)), "invalid_schedule_view", "a missing member is refused")
	var unknown := _view(3, [])
	unknown["route_plan"] = []
	assert_eq(_code(_validate(unknown)), "invalid_schedule_view", "an unknown member is refused")
	var aliased := _view(3, [])
	aliased.erase("condition_departure_receipts")
	aliased["condition_departure_receipt"] = {}
	assert_eq(_code(_validate(aliased)), "invalid_schedule_view", "an aliased member is refused")


func test_validate_rejects_non_strict_top_level_types() -> void:
	assert_eq(_code(_validate(_view(3, [], {"day": 3.0}))), "invalid_schedule_view",
		"day is a strict int, never coerced")
	assert_eq(_code(_validate(_view(3, [], {"causal_day_instance": ""}))),
		"invalid_schedule_view", "the causal day instance is a nonempty String")
	assert_eq(_code(_validate(_view(3, [], {"date_entry_seen": 1}))), "invalid_schedule_view",
		"date_entry_seen is a strict bool")
	assert_eq(_code(_validate(_view(3, [], {"entries": {}}))), "invalid_schedule_view",
		"entries is an Array")
	assert_eq(_code(_validate(_view(3, [], {"consumed_warning_receipts": []}))),
		"invalid_schedule_view", "consumed_warning_receipts is a Dictionary")
	assert_eq(_code(_validate(_view(3, [], {"condition_departure_receipts": []}))),
		"invalid_schedule_view", "condition_departure_receipts is a Dictionary")


# ---- validate: entry shape ----

func test_validate_rejects_registry_owned_and_commit_owned_entry_keys() -> void:
	for stray_key: String in ["route_id", "effect_ids", "motivation_cost", "state",
			"commit_transaction_id", "unlock_receipt_id"]:
		var entry := _ordinary("d1", 0, "rest")
		entry[stray_key] = []
		assert_eq(_code(_validate(_view(3, [entry]))), "invalid_draft_entry",
			stray_key + " is registry- or commit-owned, never a view entry member")


func test_validate_rejects_malformed_entry_shape_and_nested_aliasing() -> void:
	var missing := _ordinary("d1", 0, "rest")
	missing.erase("participants")
	assert_eq(_code(_validate(_view(3, [missing]))), "invalid_draft_entry",
		"an entry carries exactly seven keys")
	var aliased := _ordinary("d2", 0, "rest")
	aliased.erase("draft_entry_id")
	aliased["entry_id"] = "d2"
	assert_eq(_code(_validate(_view(3, [aliased]))), "invalid_draft_entry",
		"a nested aliased key is refused")
	assert_eq(_code(_validate(_view(3, [_ordinary("", 0, "rest")]))), "invalid_draft_entry",
		"draft_entry_id is a nonempty String")
	var stringy := _ordinary("d3", 0, "rest")
	stringy["slot_index"] = "0"
	assert_eq(_code(_validate(_view(3, [stringy]))), "invalid_draft_entry",
		"slot_index is a strict int")
	var nested := _solo("d4", 1, "lavinia", 3)
	nested["participants"] = [{"id": "lavinia"}]
	assert_eq(_code(_validate(_view(3, [nested]))), "invalid_draft_entry",
		"participant elements are primitive nonempty Strings")


# ---- validate: registry resolution ----

func test_validate_resolves_every_action_id_through_the_registry() -> void:
	var result := _validate(_view(3, [_ordinary("d1", 0, "nap")]))
	assert_eq(_code(result), "unregistered_action",
		"a correct fingerprint alone is never proof; the ID must resolve")


func test_validate_rejects_a_stale_or_non_string_fingerprint() -> void:
	var view := _view(3, [_ordinary("d1", 0, "rest")])
	assert_eq(_code(VIEW_STATE.validate(view, _registry, "0".repeat(64))),
		"stale_registry_fingerprint", "a mismatched fingerprint is refused")
	assert_eq(_code(VIEW_STATE.validate(view, _registry, 42)),
		"invalid_expected_fingerprint", "a non-String fingerprint is refused")


func test_validate_rechecks_kind_participants_and_day_window() -> void:
	var wrong_kind := _solo("d1", 0, "lavinia", 3)
	wrong_kind["action_kind"] = "ordinary"
	wrong_kind["participants"] = []
	wrong_kind["source_receipt_id"] = null
	assert_eq(_code(_validate(_view(3, [wrong_kind]))), "draft_registry_mismatch",
		"the duplicated kind must reproduce the registry record")
	var reversed_pair := _group("d2", 0, 2)
	reversed_pair["participants"] = ["lavinia", "priscilla"]
	assert_eq(_code(_validate(_view(2, [reversed_pair]))), "draft_registry_mismatch",
		"a reversed group pair is a tamper, not a synonym")
	var off_day := _solo("d3", 0, "lavinia", 3)
	off_day["day"] = 5
	assert_eq(_code(_validate(_view(5, [off_day]))), "action_not_allowed_on_day",
		"an entry may not sit outside its registered days")


func test_validate_rechecks_the_source_receipt_class() -> void:
	var sourced_ordinary := _ordinary("d1", 0, "rest")
	sourced_ordinary["source_receipt_id"] = "src:rest"
	assert_eq(_code(_validate(_view(3, [sourced_ordinary]))), "invalid_source_receipt",
		"an ordinary action carries a null source receipt")
	var unsourced_date := _solo("d2", 0, "lavinia", 3)
	unsourced_date["source_receipt_id"] = null
	assert_eq(_code(_validate(_view(3, [unsourced_date]))), "invalid_source_receipt",
		"a date carries its nonempty acceptance receipt id")


# ---- validate: day law ----

func test_validate_enforces_slot_uniqueness_and_the_seven_boxes() -> void:
	assert_eq(_code(_validate(_view(3,
		[_ordinary("same", 0, "rest"), _ordinary("same", 1, "training")]))),
		"duplicate_draft_entry_id", "draft ids are unique")
	assert_eq(_code(_validate(_view(3,
		[_ordinary("a", 2, "rest"), _ordinary("b", 2, "training")]))),
		"duplicate_slot_index", "a slot holds one entry")
	assert_eq(_code(_validate(_view(3, [_ordinary("a", 7, "rest")]))), "invalid_slot_index",
		"Days 1-6 expose slots 0..6 only")
	var crowded: Array = []
	for index: int in range(8):
		crowded.append(_ordinary("c%d" % index, index, "rest"))
	assert_eq(_code(_validate(_view(3, crowded))), "too_many_entries",
		"an eighth entry exceeds the seven Days-1-6 boxes")


func test_validate_enforces_date_and_repeat_law() -> void:
	var three_dates := _view(6,
		[_solo("a", 0, "priscilla", 6), _solo("b", 1, "lavinia", 6), _group("c", 2, 6)])
	assert_eq(_code(_validate(three_dates)), "too_many_dates",
		"Days 1-6 allow at most two dates")
	var coexisting := _view(2, [_group("g", 0, 2), _solo("s", 1, "priscilla", 2)])
	assert_eq(_code(_validate(coexisting)), "superseded_solo_date",
		"the group supersedes its participants' solos")
	var repeated_date := _view(3, [_solo("a", 0, "lavinia", 3), _solo("b", 1, "lavinia", 3)])
	assert_eq(_code(_validate(repeated_date)), "action_not_repeatable",
		"a date never repeats")
	var repeated_ordinary := _validate(_view(3,
		[_ordinary("a", 0, "training"), _ordinary("b", 1, "training")]))
	assert_true(repeated_ordinary.get("ok", false),
		"Training repeats as distinct draft entries: " + str(repeated_ordinary))


func test_validate_enforces_day_seven_structure() -> void:
	assert_true(_validate(_view(7, [])).get("ok", false), "Day 7 Alone is a legal empty view")
	var one_solo := _solo("d7", 0, "sylvia", 7)
	assert_true(_validate(_view(7, [one_solo])).get("ok", false),
		"one Day-7 solo at slot zero is legal")
	assert_eq(_code(_validate(_view(7,
		[_solo("a", 0, "sylvia", 7), _solo("b", 1, "lavinia", 7)]))), "too_many_entries",
		"Day 7 holds at most one entry")
	assert_eq(_code(_validate(_view(7, [_solo("c", 1, "sylvia", 7)]))), "invalid_day7_entry",
		"the Day-7 destination sits at slot zero")
	var custom := _day7_group_registry()
	var group_entry := _group("g7", 0, 7)
	assert_eq(str(VIEW_STATE.validate(_view(7, [group_entry]), custom["registry"],
		custom["fingerprint"]).get("code", "")), "invalid_day7_entry",
		"Day 7 carries only a solo destination even for a day-7-registered group")


# ---- validate: condition-departure receipt index ----

func test_validate_accepts_an_exact_condition_departure_ledger() -> void:
	var result := _validate(_ledger_view(_condition_receipt("cond-1")))
	assert_true(result.get("ok", false), str(result))


func test_validate_rejects_a_malformed_condition_departure_receipt() -> void:
	var missing := _condition_receipt("cond-1")
	missing.erase("disposition")
	assert_eq(_code(_validate(_ledger_view(missing, "cond-1"))),
		"invalid_condition_departure_receipt", "the value carries exactly five keys")
	var widened := _condition_receipt("cond-2")
	widened["extra"] = true
	assert_eq(_code(_validate(_ledger_view(widened))),
		"invalid_condition_departure_receipt", "an extra member is refused")
	var aliased := _condition_receipt("cond-3")
	aliased.erase("source_condition_receipt_id")
	aliased["receipt_id"] = "cond-3"
	assert_eq(_code(_validate(_ledger_view(aliased, "cond-3"))),
		"invalid_condition_departure_receipt", "a nested aliased key is refused")
	var wrong_disposition := _condition_receipt("cond-4")
	wrong_disposition["disposition"] = "condition_departure_committed"
	assert_eq(_code(_validate(_ledger_view(wrong_disposition))),
		"invalid_condition_departure_receipt",
		"the disposition is exactly condition_departure_view_committed")
	var uppercase := _condition_receipt("cond-5")
	uppercase["schedule_view_before_sha256"] = "A".repeat(64)
	assert_eq(_code(_validate(_ledger_view(uppercase))),
		"invalid_condition_departure_receipt", "hashes are lowercase sha256 hex")


func test_validate_rejects_ledger_key_mismatch_and_malformed_provenance() -> void:
	assert_eq(_code(_validate(_ledger_view(_condition_receipt("cond-1"), "cond-other"))),
		"invalid_condition_departure_receipt", "the map key equals the value's source id")
	var empty_provenance := _condition_receipt("cond-2")
	empty_provenance["source_condition_receipt_provenance"] = {}
	assert_eq(_code(_validate(_ledger_view(empty_provenance))),
		"invalid_condition_departure_receipt", "provenance is a nonempty Dictionary")
	var stringy_provenance := _condition_receipt("cond-3")
	stringy_provenance["source_condition_receipt_provenance"] = "prov"
	assert_eq(_code(_validate(_ledger_view(stringy_provenance))),
		"invalid_condition_departure_receipt", "provenance is never a primitive")


# ---- fingerprint ----

func test_fingerprint_returns_a_lowercase_sha256_envelope() -> void:
	var result: Dictionary = VIEW_STATE.fingerprint(_view(3, []), _registry, _fingerprint)
	assert_true(result.get("ok", false), str(result))
	assert_eq(_keys_of(result.get("value", {})), ["fingerprint"],
		"the success value is exactly {fingerprint}")
	var digest := str((result.get("value", {}) as Dictionary).get("fingerprint", ""))
	assert_eq(digest.length(), 64, "a sha256 digest is 64 hex characters")
	var hex := RegEx.create_from_string("^[0-9a-f]{64}$")
	assert_not_null(hex.search(digest), "the digest is lowercase hex: " + digest)


func test_fingerprint_excludes_only_the_condition_departure_ledger() -> void:
	var base := _view(3, [_ordinary("d1", 0, "rest")])
	var grown := _view(3, [_ordinary("d1", 0, "rest")],
		{"condition_departure_receipts": {"cond-1": _condition_receipt("cond-1")}})
	assert_eq(_fingerprint_value(base, _registry, _fingerprint),
		_fingerprint_value(grown, _registry, _fingerprint),
		"appending recovery evidence never stales an issued view expectation")
	var different_entries := _view(3, [_ordinary("d2", 1, "training")])
	assert_ne(_fingerprint_value(base, _registry, _fingerprint),
		_fingerprint_value(different_entries, _registry, _fingerprint),
		"the fingerprint covers entries")
	var latched := _view(3, [_ordinary("d1", 0, "rest")], {"date_entry_seen": true})
	assert_ne(_fingerprint_value(base, _registry, _fingerprint),
		_fingerprint_value(latched, _registry, _fingerprint),
		"the fingerprint covers date_entry_seen")


func test_fingerprint_covers_the_expected_registry_fingerprint() -> void:
	var stale := _stale_registry()
	assert_ne(str(stale["fingerprint"]), _fingerprint, "the stale fixture really differs")
	var view := _view(3, [])
	assert_ne(_fingerprint_value(view, _registry, _fingerprint),
		_fingerprint_value(view, stale["registry"], stale["fingerprint"]),
		"the expected registry fingerprint is part of the digest preimage")


func test_fingerprint_refuses_an_invalid_view() -> void:
	var unknown := _view(3, [])
	unknown["route_plan"] = []
	assert_eq(str(VIEW_STATE.fingerprint(unknown, _registry, _fingerprint).get("code", "")),
		"invalid_schedule_view", "no digest is issued over an invalid view")


# ---- detached ----

func test_detached_returns_a_deep_copy_with_no_aliasing() -> void:
	var view := _ledger_view(_condition_receipt("cond-1"))
	var result: Dictionary = VIEW_STATE.detached(view)
	assert_true(result.get("ok", false), str(result))
	assert_eq(_keys_of(result.get("value", {})), ["view"],
		"the success value is exactly {view}")
	var copy: Dictionary = (result.get("value", {}) as Dictionary).get("view", {})
	assert_eq(_canonical(copy), _canonical(view), "the copy is byte-identical")
	(copy.get("entries", []) as Array).clear()
	var copied_receipt: Dictionary = (copy.get("condition_departure_receipts", {})
		as Dictionary).get("cond-1", {})
	copied_receipt["disposition"] = "tampered"
	assert_eq((view.get("entries", []) as Array).size(), 1,
		"mutating the copy never reaches the source entries")
	assert_eq(str(((view.get("condition_departure_receipts", {}) as Dictionary)
		.get("cond-1", {}) as Dictionary).get("disposition", "")),
		"condition_departure_view_committed",
		"mutating the copy never reaches the source ledger")


# ---- the Task-2 registry adapter (Ruling 18-A item 4; review Important-2) ----

func test_lookup_refuses_a_stale_and_a_non_string_fingerprint() -> void:
	var stale: Dictionary = _registry.lookup("rest", "0".repeat(64))
	assert_eq(_code(stale), "stale_registry_fingerprint",
		"a mismatched fingerprint serves no record")
	var typed: Dictionary = _registry.lookup("rest", 42)
	assert_eq(_code(typed), "invalid_expected_fingerprint",
		"a non-String fingerprint serves no record")


func test_snapshot_is_fingerprint_verified_and_detached() -> void:
	assert_eq(str(_registry.snapshot("0".repeat(64)).get("code", "")),
		"stale_registry_fingerprint", "a mismatched fingerprint yields no snapshot")
	var first: Dictionary = _registry.snapshot(_fingerprint)
	assert_true(first.get("ok", false), str(first))
	assert_eq(_keys_of(first.get("value", {})), ["records", "registry_fingerprint"],
		"the snapshot value is exactly {records, registry_fingerprint}")
	assert_eq(str((first.get("value", {}) as Dictionary).get("registry_fingerprint", "")),
		_fingerprint, "the snapshot names its verified fingerprint")
	var records: Dictionary = (first.get("value", {}) as Dictionary).get("records", {})
	assert_true(records.has("rest"), "the snapshot carries the manifest records")
	(records.get("rest", {}) as Dictionary)["motivation_cost"] = 99
	records.erase("training")
	var second: Dictionary = _registry.snapshot(_fingerprint)
	var fresh: Dictionary = (second.get("value", {}) as Dictionary).get("records", {})
	assert_eq(int((fresh.get("rest", {}) as Dictionary).get("motivation_cost", -1)), 1,
		"mutating a returned snapshot never reaches the retained registry")
	assert_true(fresh.has("training"), "erasing from a returned snapshot changes nothing")


# ---- ledger alias hardening (review Important-3) ----

func test_validate_rejects_a_string_name_disposition() -> void:
	var aliased := _condition_receipt("cond-1")
	aliased["disposition"] = &"condition_departure_view_committed"
	assert_eq(_code(_validate(_ledger_view(aliased))),
		"invalid_condition_departure_receipt",
		"a StringName disposition is an alias, not the exact String")


func test_validate_rejects_a_string_name_ledger_key() -> void:
	var view := _view(3, [_ordinary("d1", 0, "rest")],
		{"condition_departure_receipts": {&"cond-1": _condition_receipt("cond-1")}})
	assert_eq(_code(_validate(view)), "invalid_condition_departure_receipt",
		"a StringName index key is an alias, not the exact String")


func test_validate_rejects_an_object_bearing_provenance() -> void:
	var tainted := _condition_receipt("cond-1")
	(tainted["source_condition_receipt_provenance"] as Dictionary)["issuer"] = \
		RefCounted.new()
	assert_eq(_code(_validate(_ledger_view(tainted))),
		"invalid_condition_departure_receipt",
		"a retained receipt must canonicalize; an Object is a live aliasing channel")
