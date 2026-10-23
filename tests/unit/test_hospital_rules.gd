extends "res://addons/gut/test.gd"
# Pure Schedule-Done Hospital law (Plan 01 Task 7 Step 7.3, dwm-p2r.14).
#
# HospitalRules owns the exact Hospital completion envelope and the immutable witness/care receipt.
# It is PURE: it emits no relationship or caring-message application command, touches no owner, and
# derives no identity. It returns the ordered derivation PLAN that the resolution transaction then
# turns into P01.hospital.resolution -> P01.hospital.miss[] -> optional P01.hospital.sylvia_witness.
#
# Plan 01 changes no affection, dark, attitude, tier, caring-message history, board result, or
# mastery. The witness record CARRIES those deltas as frozen facts for dwm-oyo.4 to apply later;
# nothing here applies them.

const RULES_PATH := "res://scripts/domain/hospital/HospitalRules.gd"


func _rules_exist() -> bool:
	return ResourceLoader.exists(RULES_PATH, "Script")


## A committed entry as the canonical aggregate carries it.
func _entry(entry_id: String, slot_index: int, action_kind: String, action_id: String,
		participants: Array, source_receipt_id: Variant) -> Dictionary:
	return {
		"schedule_entry_id": entry_id,
		"slot_index": slot_index,
		"action_kind": action_kind,
		"action_id": action_id,
		"participants": participants.duplicate(),
		"source_receipt_id": source_receipt_id,
	}


func _ordinary(entry_id: String, slot_index: int) -> Dictionary:
	return _entry(entry_id, slot_index, "ordinary", "rest", [], null)


func _solo(entry_id: String, slot_index: int, friend: String, day: int) -> Dictionary:
	return _entry(entry_id, slot_index, "solo", "solo:%s:day%d" % [friend, day], [friend],
		"source." + entry_id)


func _plan(required: bool, source_day: int, entries: Array) -> Dictionary:
	return load(RULES_PATH).plan_resolution({
		"required": required,
		"source_day": source_day,
		"committed_entries": entries.duplicate(true),
	})


# ---- the aggregate envelope ----

func test_hospital_supersedes_every_committed_date_exactly_once_in_slot_order() -> void:
	assert_true(_rules_exist(), "HospitalRules must exist")
	if not _rules_exist():
		return
	# Interleaved so slot order and array order genuinely differ from the date-only filter.
	var entries: Array = [
		_ordinary("e-work", 0),
		_solo("e-lav", 1, "lavinia", 3),
		_ordinary("e-rest", 2),
		_solo("e-pri", 4, "priscilla", 3),
	]
	var result: Dictionary = _plan(true, 3, entries)
	assert_true(result.get("ok", false), JSON.stringify(result))
	if not result.get("ok", false):
		return
	var value: Dictionary = result["value"]

	assert_true(bool(value["required"]), "Hospital is required")
	assert_eq(value["date_schedule_entry_ids"], ["e-lav", "e-pri"],
		"every committed DATE, in committed slot order; ordinary entries are not dates")

	var misses: Array = value["misses"]
	assert_eq(misses.size(), 2, "each committed date is superseded exactly once")
	assert_eq(int(misses[0]["ordinal"]), 0, "miss ordinals are zero-based over the filtered dates")
	assert_eq(int(misses[1]["ordinal"]), 1, "and follow committed slot order, not the raw slot")
	assert_eq(str(misses[0]["schedule_entry_id"]), "e-lav")
	assert_eq(str(misses[1]["schedule_entry_id"]), "e-pri")
	for miss: Dictionary in misses:
		assert_eq(str(miss["reason"]), "prevented_by_fainting",
			"a Hospital supersession is always prevented_by_fainting")
		assert_false(str(miss["source_receipt_id"]).is_empty(),
			"each miss carries the exact source receipt of the date it superseded")


func test_no_dates_yields_a_required_hospital_with_no_misses() -> void:
	assert_true(_rules_exist(), "HospitalRules must exist")
	if not _rules_exist():
		return
	var result: Dictionary = _plan(true, 3, [_ordinary("e-work", 0)])
	assert_true(result.get("ok", false), JSON.stringify(result))
	if not result.get("ok", false):
		return
	var value: Dictionary = result["value"]
	assert_true(bool(value["required"]))
	assert_eq(value["date_schedule_entry_ids"], [],
		"an empty date list is legal and explicit, never omitted")
	assert_eq((value["misses"] as Array).size(), 0)
	assert_eq(value["witness"], null)


func test_an_untriggered_hospital_supersedes_nothing() -> void:
	assert_true(_rules_exist(), "HospitalRules must exist")
	if not _rules_exist():
		return
	var entries: Array = [_solo("e-lav", 1, "lavinia", 3), _solo("e-pri", 4, "priscilla", 3)]
	var result: Dictionary = _plan(false, 3, entries)
	assert_true(result.get("ok", false), JSON.stringify(result))
	if not result.get("ok", false):
		return
	var value: Dictionary = result["value"]
	assert_false(bool(value["required"]), "no faint, no Hospital")
	assert_eq(value["date_schedule_entry_ids"], ["e-lav", "e-pri"],
		"the committed dates are still reported, so the date stage can run them in order")
	assert_eq((value["misses"] as Array).size(), 0,
		"an untriggered Hospital supersedes NOTHING; the dates survive")
	assert_eq(value["witness"], null, "no witness without a faint")


# ---- the Sylvia witness ----

func test_a_committed_sourced_sylvia_solo_produces_the_exact_witness_record() -> void:
	assert_true(_rules_exist(), "HospitalRules must exist")
	if not _rules_exist():
		return
	var entries: Array = [
		_solo("e-lav", 0, "lavinia", 3),
		_solo("e-syl", 2, "sylvia", 3),
	]
	var result: Dictionary = _plan(true, 3, entries)
	assert_true(result.get("ok", false), JSON.stringify(result))
	if not result.get("ok", false):
		return
	var witness: Variant = result["value"]["witness"]
	assert_false(witness == null, "a superseded, sourced Sylvia solo witnesses the faint")
	if witness == null:
		return
	var record: Dictionary = witness

	assert_eq(str(record["kind"]), "sylvia_hospital_witness")
	assert_eq(str(record["resolution_kind"]), "schedule_done",
		"Plan 01 only ever writes the Schedule-Done witness, never the condition-Hospital one")
	assert_eq(str(record["schedule_entry_id"]), "e-syl")
	assert_eq(str(record["action_id"]), "solo:sylvia:day3")
	assert_eq(str(record["source_receipt_id"]), "source.e-syl")
	# The witness names the NEXT day's caring entry; it does not create or apply it.
	assert_eq(int(record["care_followup_day"]), 4, "care lands the day after the faint")
	assert_false(str(record["care_followup_entry_id"]).is_empty(),
		"the exact next-day caring entry is named")
	# Frozen facts for dwm-oyo.4. Plan 01 applies none of them.
	assert_eq(int(record["affection_delta"]), 2)
	assert_eq(int(record["dark_delta"]), 1)
	assert_eq(str(record["attitude"]), "fixated")
	assert_eq(str(record["tier_transition"]), "advance_one_or_stay_love")
	# The witness is anchored to the miss that superseded that exact Sylvia date.
	assert_eq(int(record["hospital_miss_ordinal"]), 1,
		"Sylvia sat at the second committed date slot, so she is miss ordinal 1")


func test_only_a_sourced_committed_sylvia_date_can_witness() -> void:
	assert_true(_rules_exist(), "HospitalRules must exist")
	if not _rules_exist():
		return
	# OTHER FRIEND: a superseded Priscilla date is not a Sylvia witness.
	var other: Dictionary = _plan(true, 3, [_solo("e-pri", 0, "priscilla", 3)])
	assert_true(other.get("ok", false))
	assert_eq(other["value"]["witness"], null, "another friend cannot witness")

	# UNSOURCED: an entry with no source receipt was never an accepted, read offer.
	var unsourced: Array = [_entry("e-syl", 0, "solo", "solo:sylvia:day3", ["sylvia"], null)]
	var without_source: Dictionary = _plan(true, 3, unsourced)
	assert_true(without_source.get("ok", false))
	assert_eq(without_source["value"]["witness"], null,
		"an unsourced Sylvia entry cannot witness; the source receipt IS the acceptance proof")

	# NOT SUPERSEDED: no faint means no witness even with a perfect Sylvia date.
	var untriggered: Dictionary = _plan(false, 3, [_solo("e-syl", 0, "sylvia", 3)])
	assert_true(untriggered.get("ok", false))
	assert_eq(untriggered["value"]["witness"], null,
		"a date that was never superseded witnessed no faint")

	# NOT A DATE: an ordinary entry never witnesses, whatever it is named.
	var ordinary_only: Array = [_entry("e-x", 0, "ordinary", "solo:sylvia:day3", ["sylvia"], "s")]
	var ordinary_result: Dictionary = _plan(true, 3, ordinary_only)
	assert_true(ordinary_result.get("ok", false))
	assert_eq(ordinary_result["value"]["witness"], null,
		"the registry-owned kind decides, never the action id text")


func test_at_most_one_witness_even_with_two_sylvia_dates() -> void:
	assert_true(_rules_exist(), "HospitalRules must exist")
	if not _rules_exist():
		return
	# The registry forbids repeating a date action, but the rules must still be total: if two
	# Sylvia dates ever reached a committed day, exactly one witness exists (ordinal stays zero).
	var entries: Array = [_solo("e-syl-a", 0, "sylvia", 3), _solo("e-syl-b", 1, "sylvia", 3)]
	var result: Dictionary = _plan(true, 3, entries)
	assert_true(result.get("ok", false))
	var witness: Variant = result["value"]["witness"]
	assert_false(witness == null)
	if witness == null:
		return
	assert_eq(str((witness as Dictionary)["schedule_entry_id"]), "e-syl-a",
		"the FIRST committed Sylvia date in slot order is the witness")


# ---- purity and determinism ----

func test_the_plan_is_deterministic_and_detached() -> void:
	assert_true(_rules_exist(), "HospitalRules must exist")
	if not _rules_exist():
		return
	var entries: Array = [_solo("e-syl", 0, "sylvia", 3), _ordinary("e-rest", 1)]
	var first: Dictionary = _plan(true, 3, entries)
	var second: Dictionary = _plan(true, 3, entries)
	assert_eq(first, second, "the same committed input yields byte-identical output")

	# Mutating the returned plan cannot reach back into a later call's result.
	(first["value"]["misses"] as Array).clear()
	var third: Dictionary = _plan(true, 3, entries)
	assert_eq((third["value"]["misses"] as Array).size(), 1, "the returned plan is detached")


func test_invalid_requests_fail_closed_without_a_partial_plan() -> void:
	assert_true(_rules_exist(), "HospitalRules must exist")
	if not _rules_exist():
		return
	var rules: Script = load(RULES_PATH)
	for bad: Dictionary in [
		{"required": true, "source_day": 3},
		{"required": true, "source_day": 0, "committed_entries": []},
		{"required": true, "source_day": 8, "committed_entries": []},
		{"required": "yes", "source_day": 3, "committed_entries": []},
		{"required": true, "source_day": 3, "committed_entries": {}},
		{"required": true, "source_day": 3, "committed_entries": [], "extra": 1},
	]:
		var result: Dictionary = rules.plan_resolution(bad)
		assert_false(result.get("ok", true), "must reject: " + JSON.stringify(bad))
		assert_false(result.has("value"), "a rejection carries no partial plan")
