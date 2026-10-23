extends "res://addons/gut/test.gd"
# Accepted-schema Schedule validation (Plan 01 Task 1, dwm-p2r.12).
#
# This suite replaces the quarantined nine-key strict slice (evidence branch
# feat/p2r7-strict-schedule-validation, base 49947e5, tip 5e9ab64). What carries over is the
# THINKING, not the transport: master envelopes, exact types, existing-state failure winning before
# candidate failure, duplicate identity/slot law, Day-7 structure, detached outputs.
#
# Deliberately NOT ported, per Step 1.6: the nine-key caller route/effects shape, global duplicate
# action IDs (Training/Working/Rest are repeatable), add-time motivation, the Day-4 Priscilla
# placement rule, unlock/eligibility dictionaries, and date_completed proof.
#
# The registry is INJECTED. ScheduleRules never reaches for DataCatalog, GameState, Contacts,
# scenes, or files.

const REGISTRY_FIXTURES := preload("res://tests/support/ScheduleRegistryFixtures.gd")
const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const RULES_PATH := "res://scripts/domain/schedule/ScheduleRules.gd"

const ACCEPTED_INTERFACE: Array[String] = [
	"validate_draft_candidate", "validate_draft", "validate_committed", "build_route_plan",
]

var _registry: RefCounted = null
# Untyped on purpose: GDScript resolves statically typed calls at PARSE time, so a typed preload
# would turn "the accepted interface does not exist yet" into a load failure instead of the failing
# assertion Step 1.4 requires. The probe instance defers dispatch to runtime.
var _rules = null


func before_each() -> void:
	_registry = REGISTRY_FIXTURES.new()
	var loaded: Dictionary = PROBE.instantiate(RULES_PATH)
	_rules = loaded["value"] if loaded.get("ok", false) else null


func _fingerprint() -> String:
	return _registry.fingerprint()


# The accepted interface is absent until Step 1.5 lands. Every test reports that as an ASSERTION
# naming the missing surface, so RED is a real failing expectation rather than a parser crash.
func _missing_interface() -> bool:
	var absent: Array[String] = []
	for method_name: String in ACCEPTED_INTERFACE:
		if not _rules.has_method(method_name):
			absent.append(method_name)
	if absent.is_empty():
		return false
	assert_true(false, "accepted ScheduleRules interface absent: " + str(absent))
	return true


# ---- builders ----

func _draft(draft_entry_id: String, slot_index: int, action_id: String, action_kind: String,
		participants: Array, source_receipt_id: Variant, day := 3) -> Dictionary:
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": action_kind,
		"participants": participants,
		"source_receipt_id": source_receipt_id,
	}


func _ordinary(draft_entry_id: String, slot_index: int, action_id: String, day := 3) -> Dictionary:
	return _draft(draft_entry_id, slot_index, action_id, "ordinary", [], null, day)


func _solo(draft_entry_id: String, slot_index: int, friend_id: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend_id, day]
	return _draft(draft_entry_id, slot_index, action_id, "solo", [friend_id],
		"src:" + action_id, day)


func _group_date(draft_entry_id: String, slot_index: int, day: int) -> Dictionary:
	var action_id := "group:priscilla_lavinia:day%d" % day
	return _draft(draft_entry_id, slot_index, action_id, "group", ["priscilla", "lavinia"],
		"src:" + action_id, day)


func _source(action_id: String, day: int, participants: Array, kind: String) -> Dictionary:
	return {
		"receipt_id": "src:" + action_id,
		"receipt_provenance": {"schema_version": 1, "parent_receipt_id": "cmd-root",
			"child_kind": "contact_source", "ordinal": 0, "source_ids": [],
			"child_id": "src:" + action_id},
		"kind": kind,
		"action_id": action_id,
		"day": day,
		"participants": participants,
		"previous_receipt_id": "offer:" + action_id,
	}


func _sources(entries: Array) -> Dictionary:
	# The exact contacts.schedule_source_receipts index each date entry resolves against.
	var index: Dictionary = {}
	for entry: Dictionary in entries:
		var kind := str(entry.get("action_kind", ""))
		if kind == "ordinary":
			continue
		var receipt := _source(str(entry.get("action_id", "")), int(entry.get("day", 0)),
			(entry.get("participants", []) as Array).duplicate(),
			"solo_read_acceptance" if kind == "solo" else "group_reply_acceptance")
		index[str(receipt["receipt_id"])] = receipt
	return index


func _validate(day: int, entries: Array) -> Dictionary:
	return _rules.validate_draft(day, entries, _registry, _fingerprint(), _sources(entries))


func _validate_candidate(day: int, existing: Array, candidate: Dictionary) -> Dictionary:
	var prospective: Array = existing.duplicate()
	prospective.append(candidate)
	return _rules.validate_draft_candidate(day, existing, candidate, _registry,
		_fingerprint(), _sources(prospective))


func _code(result: Dictionary) -> String:
	return str(result.get("code", ""))


# ---- Step 1.1: exact schema ----

func test_the_accepted_validator_interface_exists() -> void:
	# The first RED names the absent accepted interface, as Step 1.4 requires.
	for method_name: String in ACCEPTED_INTERFACE:
		assert_true(_rules.has_method(method_name),
			"accepted interface must expose " + method_name)


func test_a_caller_supplied_route_is_not_a_legal_draft_field() -> void:
	if _missing_interface():
		return
	var entry := _ordinary("d1", 0, "rest")
	entry["route_id"] = "dating"
	var result := _validate(3, [entry])
	assert_false(result.get("ok", false), "route is registry-derived, never caller-supplied")
	assert_eq(_code(result), "invalid_draft_entry", "typed rejection")


func test_caller_supplied_effects_cost_and_unlock_fields_are_rejected() -> void:
	if _missing_interface():
		return
	for stray_key: String in ["effect_ids", "motivation_cost", "unlock_receipt_id", "state"]:
		var entry := _ordinary("d1", 0, "rest")
		entry[stray_key] = []
		assert_false(_validate(3, [entry]).get("ok", false),
			stray_key + " is registry- or commit-owned, never a draft field")


func test_a_missing_draft_key_is_rejected() -> void:
	if _missing_interface():
		return
	var entry := _ordinary("d1", 0, "rest")
	entry.erase("participants")
	assert_false(_validate(3, [entry]).get("ok", false),
		"a draft entry carries exactly seven keys")


func test_day_and_slot_must_be_strict_ints() -> void:
	if _missing_interface():
		return
	var floated := _ordinary("d1", 0, "rest")
	floated["slot_index"] = 0.0
	assert_false(_validate(3, [floated]).get("ok", false), "slot_index is a strict int")
	var stringy := _ordinary("d2", 1, "rest")
	stringy["day"] = "3"
	assert_false(_validate(3, [stringy]).get("ok", false), "day is a strict int, never coerced")


func test_identifiers_and_elements_must_be_nonempty_strings() -> void:
	if _missing_interface():
		return
	assert_false(_validate(3, [_ordinary("", 0, "rest")]).get("ok", false),
		"draft_entry_id must be nonempty")
	var blank_participant := _solo("d1", 0, "lavinia", 3)
	blank_participant["participants"] = [""]
	assert_false(_validate(3, [blank_participant]).get("ok", false),
		"participant elements are nonempty Strings")


func test_draft_entry_ids_are_unique() -> void:
	if _missing_interface():
		return
	var result := _validate(3, [_ordinary("same", 0, "rest"), _ordinary("same", 1, "training")])
	assert_false(result.get("ok", false), "draft entry ids are unique within one draft")
	assert_eq(_code(result), "duplicate_draft_entry_id", "typed rejection")


func test_slots_are_unique_within_zero_to_six_and_gaps_are_legal() -> void:
	if _missing_interface():
		return
	assert_eq(_code(_validate(3, [_ordinary("a", 2, "rest"), _ordinary("b", 2, "training")])),
		"duplicate_slot_index", "a slot holds one entry")
	assert_false(_validate(3, [_ordinary("a", 7, "rest")]).get("ok", false),
		"Days 1-6 expose slots 0..6 only")
	assert_false(_validate(3, [_ordinary("a", -1, "rest")]).get("ok", false),
		"a negative slot is not a slot")
	assert_true(_validate(3, [_ordinary("a", 0, "rest"), _ordinary("b", 5, "training")])
		.get("ok", false), "gaps between occupied slots are legal")


func test_the_registry_must_reproduce_kind_and_participants() -> void:
	if _missing_interface():
		return
	var wrong_kind := _solo("d1", 0, "lavinia", 3)
	wrong_kind["action_kind"] = "ordinary"
	assert_false(_validate(3, [wrong_kind]).get("ok", false),
		"the duplicated draft kind is a tamper check, not authority")
	var wrong_participants := _solo("d2", 1, "lavinia", 3)
	wrong_participants["participants"] = ["sylvia"]
	assert_false(_validate(3, [wrong_participants]).get("ok", false),
		"participants equal the registry record exactly")


func test_an_unregistered_action_is_rejected() -> void:
	if _missing_interface():
		return
	var result := _validate(3, [_ordinary("d1", 0, "nap")])
	assert_false(result.get("ok", false), "only registered actions are schedulable")
	assert_eq(_code(result), "unregistered_action", "typed rejection")


func test_an_action_outside_its_allowed_days_is_rejected() -> void:
	if _missing_interface():
		return
	# solo:lavinia:day3 is registered for day 3 only.
	assert_false(_validate(5, [_solo("d1", 0, "lavinia", 3)]).get("ok", false),
		"an entry may not sit outside its allowed days")


func test_a_stale_registry_fingerprint_is_rejected() -> void:
	if _missing_interface():
		return
	var stale: RefCounted = REGISTRY_FIXTURES.new(REGISTRY_FIXTURES.stale_records())
	var entries: Array = [_ordinary("d1", 0, "rest")]
	var result: Dictionary = _rules.validate_draft(3, entries, stale, _fingerprint(),
		_sources(entries))
	assert_false(result.get("ok", false), "a draft validated against a stale registry rejects")
	assert_eq(_code(result), "stale_registry_fingerprint", "typed rejection")


func test_ordinary_entries_require_a_null_source_and_dates_require_one() -> void:
	if _missing_interface():
		return
	var sourced_ordinary := _ordinary("d1", 0, "rest")
	sourced_ordinary["source_receipt_id"] = "src:rest"
	assert_false(_validate(3, [sourced_ordinary]).get("ok", false),
		"an ordinary action carries no source receipt")
	var unsourced_date := _solo("d2", 1, "lavinia", 3)
	unsourced_date["source_receipt_id"] = null
	assert_false(_validate(3, [unsourced_date]).get("ok", false),
		"a date requires its acceptance receipt")


func test_a_date_source_receipt_must_match_the_entry_exactly() -> void:
	if _missing_interface():
		return
	var entry := _solo("d1", 0, "lavinia", 3)
	var tampered := _sources([entry])
	(tampered["src:solo:lavinia:day3"] as Dictionary)["participants"] = ["sylvia"]
	var result: Dictionary = _rules.validate_draft(3, [entry], _registry, _fingerprint(),
		tampered)
	assert_false(result.get("ok", false), "the source receipt must name the same participants")


func test_a_date_source_receipt_of_the_wrong_kind_is_rejected() -> void:
	if _missing_interface():
		return
	var entry := _solo("d1", 0, "lavinia", 3)
	var wrong_kind := _sources([entry])
	(wrong_kind["src:solo:lavinia:day3"] as Dictionary)["kind"] = "group_reply_acceptance"
	var result: Dictionary = _rules.validate_draft(3, [entry], _registry, _fingerprint(),
		wrong_kind)
	assert_false(result.get("ok", false), "the receipt kind equals the registry's source kind")


func test_an_unresolvable_source_receipt_is_rejected() -> void:
	if _missing_interface():
		return
	var entry := _solo("d1", 0, "lavinia", 3)
	var result: Dictionary = _rules.validate_draft(3, [entry], _registry, _fingerprint(), {})
	assert_false(result.get("ok", false), "a source id resolving to nothing is not evidence")


# ---- Step 1.2: law matrices ----

func test_zero_through_seven_day_one_to_six_entries_are_legal() -> void:
	if _missing_interface():
		return
	assert_true(_validate(3, []).get("ok", false), "an empty draft is legal")
	var entries: Array = []
	for slot: int in range(7):
		entries.append(_ordinary("d%d" % slot, slot, ["rest", "training", "working"][slot % 3]))
		var result := _validate(3, entries)
		assert_true(result.get("ok", false),
			"%d entries fill the seven Days-1-6 boxes: %s" % [entries.size(), str(result)])


func test_an_eighth_day_one_to_six_entry_is_rejected() -> void:
	if _missing_interface():
		return
	var entries: Array = []
	for slot: int in range(7):
		entries.append(_ordinary("d%d" % slot, slot, ["rest", "training", "working"][slot % 3]))
	entries.append(_ordinary("d7", 7, "rest"))
	assert_false(_validate(3, entries).get("ok", false), "there are exactly seven Days-1-6 boxes")


func test_zero_one_and_two_dates_are_legal_and_a_third_is_rejected() -> void:
	if _missing_interface():
		return
	var one: Array = [_solo("a", 0, "lavinia", 3)]
	assert_true(_validate(3, one).get("ok", false), "one date is legal: " + str(_validate(3, one)))
	var two: Array = [_solo("a", 0, "lavinia", 3), _solo("b", 1, "sylvia", 3)]
	assert_true(_validate(3, two).get("ok", false), "two dates are legal: " + str(_validate(3, two)))
	# Day 6 carries the third-date law: two solos plus the group are three registered dates.
	var three: Array = [
		_solo("a", 0, "priscilla", 6), _solo("b", 1, "lavinia", 6), _group_date("c", 2, 6),
	]
	var result := _validate(6, three)
	assert_false(result.get("ok", false), "a third date exceeds the daily allowance")


func test_repeatable_ordinary_actions_repeat_with_distinct_draft_ids() -> void:
	if _missing_interface():
		return
	# The quarantined slice rejected this as a global duplicate action_id. The accepted law allows it.
	var entries: Array = [
		_ordinary("a", 0, "training"), _ordinary("b", 1, "training"), _ordinary("c", 2, "training"),
	]
	var result := _validate(3, entries)
	assert_true(result.get("ok", false),
		"Training, Working and Rest repeat within one day: " + str(result))


func test_a_nonrepeatable_date_cannot_repeat() -> void:
	if _missing_interface():
		return
	var result := _validate(3, [_solo("a", 0, "lavinia", 3), _solo("b", 1, "lavinia", 3)])
	assert_false(result.get("ok", false), "a date is not repeatable")
	assert_eq(_code(result), "action_not_repeatable", "typed rejection")


func test_priscilla_may_occupy_any_legal_day_four_slot() -> void:
	if _missing_interface():
		return
	# The retired Day-4 first-slot rule is inverted: the accepted law PROVES she may sit anywhere.
	for slot: int in range(7):
		var result := _validate(4, [_solo("p", slot, "priscilla", 4)])
		assert_true(result.get("ok", false),
			"Priscilla is legal in Day-4 slot %d: %s" % [slot, str(result)])


func test_the_group_pair_must_be_in_canonical_order() -> void:
	if _missing_interface():
		return
	var reversed_pair := _group_date("g", 0, 2)
	reversed_pair["participants"] = ["lavinia", "priscilla"]
	assert_false(_validate(2, [reversed_pair]).get("ok", false),
		"a reversed pair is a tamper, not a synonym")


func test_a_tampered_group_pair_is_rejected() -> void:
	if _missing_interface():
		return
	var tampered := _group_date("g", 0, 2)
	tampered["participants"] = ["priscilla", "sylvia"]
	assert_false(_validate(2, [tampered]).get("ok", false),
		"the group is exactly the Priscilla-Lavinia pair")


func test_a_group_date_cannot_coexist_with_a_superseded_solo() -> void:
	if _missing_interface():
		return
	var entries: Array = [_group_date("g", 0, 2), _solo("s", 1, "priscilla", 2)]
	assert_false(_validate(2, entries).get("ok", false),
		"the group supersedes its participants' solos and cannot coexist with them")


func test_day_seven_accepts_an_empty_draft() -> void:
	if _missing_interface():
		return
	assert_true(_validate(7, []).get("ok", false), "Day 7 Alone is a legal empty draft")


func test_day_seven_accepts_exactly_one_solo_at_slot_zero() -> void:
	if _missing_interface():
		return
	var result := _validate(7, [_solo("d7", 0, "sylvia", 7)])
	assert_true(result.get("ok", false), "one Day-7 solo at slot zero: " + str(result))


func test_day_seven_rejects_ordinary_and_group_entries() -> void:
	if _missing_interface():
		return
	assert_false(_validate(7, [_ordinary("a", 0, "rest", 7)]).get("ok", false),
		"Day 7 carries no ordinary action")
	assert_false(_validate(7, [_group_date("g", 0, 7)]).get("ok", false),
		"Day 7 carries no group date")


func test_day_seven_rejects_a_nonzero_slot_and_a_second_entry() -> void:
	if _missing_interface():
		return
	assert_false(_validate(7, [_solo("d7", 1, "sylvia", 7)]).get("ok", false),
		"the Day-7 solo sits at slot zero")
	assert_false(_validate(7, [_solo("a", 0, "sylvia", 7), _solo("b", 1, "lavinia", 7)])
		.get("ok", false), "Day 7 holds at most one entry")


# ---- candidate validation is the prospective whole draft ----

func test_existing_state_failure_wins_before_candidate_failure() -> void:
	if _missing_interface():
		return
	var broken_existing: Array = [_ordinary("a", 0, "rest"), _ordinary("a", 1, "training")]
	var result := _validate_candidate(3, broken_existing, _ordinary("b", 2, "nap"))
	assert_false(result.get("ok", false), "a broken existing draft rejects first")
	assert_eq(_code(result), "duplicate_draft_entry_id",
		"the existing-state failure surfaces, not the unregistered candidate")


func test_candidate_success_implies_the_whole_prospective_draft_is_valid() -> void:
	if _missing_interface():
		return
	# Add-accepts must never produce a draft that Done would reject.
	var existing: Array = [_solo("a", 0, "priscilla", 6), _solo("b", 1, "lavinia", 6)]
	assert_false(_validate_candidate(6, existing, _group_date("c", 2, 6)).get("ok", false),
		"a candidate that would break the whole draft is refused at add time")


func test_a_valid_candidate_returns_a_detached_candidate_value() -> void:
	if _missing_interface():
		return
	var candidate := _ordinary("b", 1, "training")
	var result := _validate_candidate(3, [_ordinary("a", 0, "rest")], candidate)
	assert_true(result.get("ok", false), "a legal candidate is accepted: " + str(result))
	assert_eq((result.get("value", {}) as Dictionary).keys(), ["candidate"],
		"the success value is exactly {candidate}")
	var returned: Dictionary = (result["value"] as Dictionary)["candidate"]
	returned["action_id"] = "tampered"
	assert_eq(str(candidate["action_id"]), "training", "the caller's dictionary is never aliased")


func test_no_validator_charges_motivation() -> void:
	if _missing_interface():
		return
	# Motivation is charged once at commit, never at add time.
	var value: Dictionary = _validate_candidate(3, [], _ordinary("a", 0, "rest")).get("value", {})
	assert_false(value.has("motivation"), "validation never touches motivation")
	assert_false(value.has("motivation_charged"), "motivation is a commit-time fact")
