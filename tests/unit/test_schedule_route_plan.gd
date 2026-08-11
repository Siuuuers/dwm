extends "res://addons/gut/test.gd"
# ScheduleRules.build_route_plan (Plan-04 Task 4, contract amended 2026-08-10).
#
# Routing is CLOSED: action -> no route and omitted entirely; solo -> "dating"; group -> "dating";
# twofriends is never schedulable and never emitted here. "none" and "advance" are retired control
# sentinels, not route IDs. A "registered semantic route ID" means a key in SceneRouter._SCENE_PATHS,
# mirrored by data/manifests/routes.json.

const SCHEDULE_RULES := preload("res://scripts/domain/schedule/ScheduleRules.gd")


func _entry(entry_id: String, slot: int, type: String, day: int, route_id: Variant) -> Dictionary:
	return {
		"entry_id": entry_id,
		"slot_index": slot,
		"day": day,
		"type": type,
		"action_id": "%s:%s" % [type, entry_id],
		# A group date is the distinct Priscilla-Lavinia pair; a solo date is one friend. Corrected
		# in commit E1, which makes friend arity a validated rule rather than a fixture accident.
		"friend_ids": ([] if type == "action"
			else (["priscilla", "lavinia"] if type == "group" else ["priscilla"])),
		"route_id": route_id,
		"effect_ids": [],
		"unlock_receipt_id": null,
	}


func _plan(schedule: Array, day: int) -> Dictionary:
	return SCHEDULE_RULES.build_route_plan(schedule, day)


# ---- success shape ----

func test_a_solo_entry_routes_to_dating() -> void:
	var result := _plan([_entry("solo-p", 0, "solo", 3, "dating")], 3)
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("code"), &"ok", "typed ok code")
	assert_eq(result.get("receipt"), {}, "build_route_plan issues no receipt")
	assert_eq(result["value"]["route_plan"], [
		{"entry_id": "solo-p", "slot_index": 0, "route_id": "dating"},
	], "exactly the three contracted keys, nothing more")


func test_a_group_entry_routes_to_dating() -> void:
	var result := _plan([_entry("grp", 0, "group", 3, "dating")], 3)
	assert_true(result.get("ok", false), str(result))
	assert_eq(str(result["value"]["route_plan"][0]["route_id"]), "dating", "group shares the dating route")


func test_action_entries_are_omitted_entirely() -> void:
	var result := _plan([_entry("rest", 0, "action", 3, null)], 3)
	assert_true(result.get("ok", false), str(result))
	assert_eq(result["value"]["route_plan"], [], "an action carries no route and is not emitted")


func test_only_routed_entries_are_emitted_in_slot_order() -> void:
	# Distinct friends: commit C made two solo dates with the SAME friend an invalid schedule, and
	# build_route_plan validates before it routes, so this fixture would fail for an unrelated
	# reason and stop proving anything about slot ordering.
	var solo_b := _entry("solo-b", 2, "solo", 3, "dating")
	solo_b["friend_ids"] = ["lavinia"]
	var schedule := [
		solo_b,
		_entry("rest", 1, "action", 3, null),
		_entry("solo-a", 0, "solo", 3, "dating"),
	]
	var result := _plan(schedule, 3)
	assert_true(result.get("ok", false), str(result))
	var ids: Array = []
	for element: Dictionary in result["value"]["route_plan"]:
		ids.append(str(element["entry_id"]))
	assert_eq(ids, ["solo-a", "solo-b"], "ascending slot_index, action dropped")


func test_an_empty_schedule_produces_an_empty_plan() -> void:
	var result := _plan([], 3)
	assert_true(result.get("ok", false), str(result))
	assert_eq(result["value"]["route_plan"], [], "no entries, no routes, still ok")


# ---- detachment ----

func test_the_plan_is_recursively_detached_from_the_schedule() -> void:
	var schedule := [_entry("solo-p", 0, "solo", 3, "dating")]
	var result := _plan(schedule, 3)
	(result["value"]["route_plan"][0] as Dictionary)["route_id"] = "tampered"
	var again := _plan(schedule, 3)
	assert_eq(str(again["value"]["route_plan"][0]["route_id"]), "dating",
		"mutating a returned plan cannot reach the caller's schedule")


# ---- failure: validate_existing runs first and propagates unchanged ----

func test_it_validates_the_existing_schedule_first() -> void:
	var duplicate_slots := [
		_entry("a", 0, "solo", 3, "dating"),
		_entry("b", 0, "action", 3, null),
	]
	var result := _plan(duplicate_slots, 3)
	assert_false(result.get("ok", false), "a structurally invalid schedule cannot be routed")
	assert_eq(result.get("code"), &"duplicate_slot_index", "validate_existing's code propagates unchanged")
	assert_false(result.has("value"), "no partial plan is returned on failure")


func test_a_malformed_entry_fails_before_routing() -> void:
	var result := _plan([{"entry_id": "loose"}], 3)
	assert_false(result.get("ok", false), "a loose dictionary is not routable")
	assert_eq(result.get("code"), &"invalid_entry", "the shape failure propagates")


# ---- failure: routing contradictions ----
#
# HONEST NAMING (commit E2): these three assert that build_route_plan PROPAGATES a routing
# rejection, not that build_route_plan detects one. Since E2, route semantics live in
# _entry_shape_error, so validate_existing rejects first and build_route_plan's own route checks
# can no longer be reached through the public API. They are retained as defensive invariant
# checks by plan-author ruling. The observable code is invalid_route either way, which is exactly
# why these tests would otherwise keep passing while silently testing a different code path.

func test_an_action_carrying_a_route_is_rejected_before_routing() -> void:
	var result := _plan([_entry("rest", 0, "action", 3, "dating")], 3)
	assert_false(result.get("ok", false), "an action must not carry a route")
	assert_eq(result.get("code"), &"invalid_route", "typed routing rejection")
	assert_false(result.has("value"), "no partial plan")


func test_a_date_routed_anywhere_but_dating_is_rejected_before_routing() -> void:
	for stray: String in (["menu", "hospital", "none", "advance", "twofriends"] as Array[String]):
		var result := _plan([_entry("solo-p", 0, "solo", 3, stray)], 3)
		assert_false(result.get("ok", false), "a solo date may not route to " + stray)
		assert_eq(result.get("code"), &"invalid_route", "typed rejection for " + stray)


func test_a_date_with_a_null_route_is_rejected_before_routing() -> void:
	var result := _plan([_entry("solo-p", 0, "solo", 3, null)], 3)
	assert_false(result.get("ok", false), "a date must carry its route")
	assert_eq(result.get("code"), &"invalid_route", "typed rejection")


# ---- day 7 ----

func test_the_day_seven_ending_date_still_routes_to_dating() -> void:
	# For the current .7 contract Day-7 solo follows the existing Phase-2R dating route. The
	# boardless Day-7 model belongs to the seven-day reconciliation plan, not here.
	var entry := _entry("ending-sylvia", 0, "solo", 7, "dating")
	entry["unlock_receipt_id"] = "unlock:sylvia:day7"
	var result := _plan([entry], 7)
	assert_true(result.get("ok", false), str(result))
	assert_eq(str(result["value"]["route_plan"][0]["route_id"]), "dating", "Day 7 keeps the dating route")


# ---- registered-route parity ----

func test_every_emitted_route_id_is_a_registered_scene_route() -> void:
	# "Registered semantic route ID" means a key in SceneRouter._SCENE_PATHS; routes.json is its
	# generated, parity-checked mirror and is the seam a pure domain test can read. This guards
	# against build_route_plan emitting a retired sentinel or an unregistered id.
	var text := FileAccess.get_file_as_string("res://data/manifests/routes.json")
	assert_false(text.is_empty(), "the routes manifest is readable")
	var registered: Array = (JSON.parse_string(text) as Dictionary)["ids"]
	assert_true("dating" in registered, "dating is a registered route")
	for sentinel: String in (["none", "advance", "twofriends"] as Array[String]):
		assert_false(sentinel in registered, sentinel + " is not a registered route id")
	var result := _plan([_entry("solo-p", 0, "solo", 3, "dating")], 3)
	assert_true(result.get("ok", false), str(result))
	for element: Dictionary in result["value"]["route_plan"]:
		assert_true(str(element["route_id"]) in registered,
			"emitted route must be registered: " + str(element["route_id"]))
