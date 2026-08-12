extends "res://addons/gut/test.gd"
# Registry-derived route projection (Plan 01 Task 1, dwm-p2r.12).
#
# build_route_plan(committed_schedule, registry) is a TRANSIENT projection recomputed from saved
# committed IDs plus their saved fingerprint. It is never persisted as a second authority, and it
# never echoes a caller-supplied route, effect, or cost -- every routing fact comes from the
# registry record for that action_id.
#
# Ordinary actions carry a null route and their registered effects. Days 1-6 dates route to
# "dating". Day-7 solo destinations carry a null route and emit NO physical route descriptor, so
# both legal Day-7 aggregates project an empty physical plan.

const REGISTRY_FIXTURES := preload("res://tests/support/ScheduleRegistryFixtures.gd")
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const RULES_PATH := "res://scripts/domain/schedule/ScheduleRules.gd"

const PROJECTION_KEYS := [
	"action_id", "action_kind", "effect_ids", "participants", "route_id", "schedule_entry_id",
	"slot_index",
]

var _registry: RefCounted = null
# Untyped on purpose: see the note in test_schedule_strict_validation.gd. A typed preload turns a
# missing accepted interface into a parse failure rather than a failing assertion.
var _rules = null


func before_each() -> void:
	_registry = REGISTRY_FIXTURES.new()
	var loaded: Dictionary = PROBE.instantiate(RULES_PATH)
	_rules = loaded["value"] if loaded.get("ok", false) else null


func _missing_interface() -> bool:
	# The accepted projection takes (committed_schedule, registry); the quarantined one took
	# (schedule, day). Presence of the name alone is not proof, so the shape assertions decide.
	if _rules != null and _rules.has_method("build_route_plan") \
			and _rules.has_method("validate_committed"):
		return false
	assert_true(false, "accepted ScheduleRules projection interface absent")
	return true


# ---- builders ----

func _committed_entry(schedule_entry_id: String, slot_index: int, action_id: String,
		action_kind: String, participants: Array, source_receipt_id: Variant,
		day := 3) -> Dictionary:
	return {
		"schedule_entry_id": schedule_entry_id,
		"schedule_entry_provenance": {
			"schema_version": 1, "parent_receipt_id": "txn-root", "child_kind": "schedule_entry",
			"ordinal": slot_index, "source_ids": [], "child_id": schedule_entry_id,
		},
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": action_kind,
		"participants": participants,
		"source_receipt_id": source_receipt_id,
		"commit_transaction_id": "txn-1",
		"state": "committed",
	}


func _ordinary(schedule_entry_id: String, slot_index: int, action_id: String,
		day := 3) -> Dictionary:
	return _committed_entry(schedule_entry_id, slot_index, action_id, "ordinary", [], null, day)


func _solo(schedule_entry_id: String, slot_index: int, friend_id: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend_id, day]
	return _committed_entry(schedule_entry_id, slot_index, action_id, "solo", [friend_id],
		"src:" + action_id, day)


func _group(schedule_entry_id: String, slot_index: int, day: int) -> Dictionary:
	var action_id := "group:priscilla_lavinia:day%d" % day
	return _committed_entry(schedule_entry_id, slot_index, action_id, "group",
		["priscilla", "lavinia"], "src:" + action_id, day)


func _aggregate(day: int, entries: Array, fingerprint: Variant = null) -> Dictionary:
	return {
		"schema_version": 1,
		"day": day,
		"registry_fingerprint": _registry.fingerprint() if fingerprint == null else fingerprint,
		"entries": entries,
		"commit_receipt": {"receipt_id": "commit-1"} if not entries.is_empty() else null,
	}


func _plan(committed: Dictionary) -> Dictionary:
	return _rules.build_route_plan(committed, _registry)


func _routes(result: Dictionary) -> Array:
	return ((result.get("value", {}) as Dictionary).get("route_plan", []) as Array)


# ---- shape ----

func test_the_projection_emits_exactly_the_seven_contracted_keys() -> void:
	if _missing_interface():
		return
	var result := _plan(_aggregate(3, [_solo("e1", 0, "lavinia", 3)]))
	assert_true(result.get("ok", false), "a valid committed aggregate projects: " + str(result))
	var routed: Array = _routes(result)
	assert_eq(routed.size(), 1, "one date projects one descriptor")
	var keys: Array = (routed[0] as Dictionary).keys()
	keys.sort()
	assert_eq(keys, PROJECTION_KEYS, "exactly the contracted projection keys, nothing more")


func test_the_success_value_is_exactly_the_route_plan() -> void:
	if _missing_interface():
		return
	var result := _plan(_aggregate(3, [_ordinary("e1", 0, "rest")]))
	assert_eq((result.get("value", {}) as Dictionary).keys(), ["route_plan"],
		"the success value is exactly {route_plan}")


# ---- registry-derived facts ----

func test_route_and_effects_come_from_the_registry_not_the_entry() -> void:
	if _missing_interface():
		return
	var result := _plan(_aggregate(3, [_ordinary("e1", 0, "training")]))
	var descriptor: Dictionary = _routes(result)[0]
	assert_null(descriptor["route_id"], "an ordinary action carries no route")
	assert_eq(descriptor["effect_ids"], ["pressure:+1", "health:+2"],
		"effects are the registry's, in registry order")


func test_days_one_to_six_dates_route_to_dating() -> void:
	if _missing_interface():
		return
	# Solo and group cannot share a day here: every Day-2 solo is a group participant, and the
	# group supersedes its participants' solos. So each kind is projected from its own aggregate.
	var solo_plan := _routes(_plan(_aggregate(3, [_solo("e1", 0, "lavinia", 3)])))
	assert_eq(solo_plan.size(), 1, "the solo date projects one descriptor")
	assert_eq(str((solo_plan[0] as Dictionary)["route_id"]), "dating", "a solo date routes to dating")
	var group_plan := _routes(_plan(_aggregate(2, [_group("e2", 0, 2)])))
	assert_eq(group_plan.size(), 1, "the group date projects one descriptor")
	assert_eq(str((group_plan[0] as Dictionary)["route_id"]), "dating",
		"a group date shares the dating route")


func test_a_caller_supplied_route_on_the_entry_is_never_echoed() -> void:
	if _missing_interface():
		return
	var entry := _ordinary("e1", 0, "rest")
	entry["route_id"] = "dating"
	var result := _plan(_aggregate(3, [entry]))
	assert_false(result.get("ok", false),
		"a committed entry carrying a caller route is malformed, not authoritative")


# ---- order and Day 7 ----

func test_descriptors_are_emitted_in_committed_slot_order() -> void:
	if _missing_interface():
		return
	var entries: Array = [
		_ordinary("e3", 4, "working"), _ordinary("e1", 0, "rest"), _ordinary("e2", 2, "training"),
	]
	var slots: Array = []
	for descriptor: Dictionary in _routes(_plan(_aggregate(3, entries))):
		slots.append(int(descriptor["slot_index"]))
	assert_eq(slots, [0, 2, 4], "ascending committed slot order regardless of array order")


func test_both_legal_day_seven_aggregates_project_an_empty_physical_plan() -> void:
	if _missing_interface():
		return
	var empty := _plan(_aggregate(7, []))
	assert_true(empty.get("ok", false), "the empty Day-7 Alone aggregate projects: " + str(empty))
	assert_eq(_routes(empty), [], "Alone emits no physical route")
	var solo := _plan(_aggregate(7, [_solo("e1", 0, "sylvia", 7)]))
	assert_true(solo.get("ok", false), "the Day-7 solo aggregate projects: " + str(solo))
	assert_eq(_routes(solo), [],
		"a Day-7 destination emits no physical route descriptor; provenance is its only output")


# ---- fingerprint and detachment ----

func test_a_stale_saved_fingerprint_is_rejected() -> void:
	if _missing_interface():
		return
	var stale := _aggregate(3, [_ordinary("e1", 0, "rest")], "0".repeat(64))
	var result := _plan(stale)
	assert_false(result.get("ok", false),
		"a committed aggregate whose saved fingerprint no longer matches cannot project")
	assert_eq(str(result.get("code", "")), "stale_registry_fingerprint", "typed rejection")


func test_the_projection_is_detached_from_both_inputs() -> void:
	if _missing_interface():
		return
	var committed := _aggregate(3, [_ordinary("e1", 0, "training")])
	var first := _plan(committed)
	(_routes(first)[0] as Dictionary)["effect_ids"] = ["tampered"]
	var second := _plan(committed)
	assert_eq((_routes(second)[0] as Dictionary)["effect_ids"], ["pressure:+1", "health:+2"],
		"mutating a returned descriptor cannot reach the registry or the aggregate")


func test_no_partial_plan_is_returned_on_failure() -> void:
	if _missing_interface():
		return
	var broken := _aggregate(3, [_ordinary("e1", 0, "rest"), _ordinary("e2", 0, "training")])
	var result := _plan(broken)
	assert_false(result.get("ok", false), "a colliding committed aggregate cannot project")
	assert_eq((result.get("value", {}) as Dictionary).get("route_plan", null), null,
		"failure returns no partial plan")
