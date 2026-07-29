extends "res://addons/gut/test.gd"

# Canonical primary ending resolver (dwm-p2r.7 Task 6, req.ending.primary).
# A primary ending is chosen from validated Day-7 state: a completed candidate is only real
# when its unlock -> schedule_add -> date_completed(attended) receipt chain agrees exactly.
# Tone is binary (story/05 §1): Sylvia Special, then Dark, then Sweet, then Alone.

const RULES_PATH := "res://scripts/domain/ending/DatingEndingRules.gd"

func _valid_chain(friend: String) -> Dictionary:
	var action := "ending-date:%s:day7" % friend
	var u := "unlock:%s:d7" % friend
	var s := "schedule:%s:d7" % friend
	var c := "complete:%s:d7" % friend
	var receipt_index := {}
	receipt_index[u] = {"receipt_id": u, "kind": "day7_unlock", "action_id": action, "friend_id": friend, "day": 7, "previous_receipt_id": null}
	receipt_index[s] = {"receipt_id": s, "kind": "schedule_add", "action_id": action, "friend_id": friend, "day": 7, "previous_receipt_id": u}
	receipt_index[c] = {"receipt_id": c, "kind": "date_completed", "action_id": action, "friend_id": friend, "day": 7, "previous_receipt_id": s, "outcome": "attended"}
	return {
		"candidate": {
			"friend_id": friend, "action_id": action,
			"unlock_receipt_id": u, "schedule_receipt_id": s, "completion_receipt_id": c,
		},
		"receipt_index": receipt_index,
	}

func _make_input(skip: int, dark: int, candidate: Variant, receipt_index: Dictionary) -> Dictionary:
	return {
		"day": 7,
		"hospital_skipped_sylvia_solo_count": skip,
		"dark_points": dark,
		"completed_candidate": candidate,
		"receipt_index": receipt_index,
	}

func test_sylvia_special_precedes_a_valid_completed_candidate() -> void:
	var rules: Script = load(RULES_PATH)
	assert_not_null(rules)
	if rules == null:
		return
	var chain: Dictionary = _valid_chain("priscilla")
	var result: Dictionary = rules.resolve_primary_ending(_make_input(2, 0, chain["candidate"], chain["receipt_index"]))
	assert_true(result.get("ok", false))
	assert_eq(result["value"], "ending.sylvia.special")
	assert_eq(result["receipt"]["rule"], "sylvia_special")

func test_completed_candidate_resolves_dark() -> void:
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var chain: Dictionary = _valid_chain("lavinia")
	var result: Dictionary = rules.resolve_primary_ending(_make_input(0, 2, chain["candidate"], chain["receipt_index"]))
	assert_true(result.get("ok", false))
	assert_eq(result["value"], "ending.lavinia.dark")

func test_completed_candidate_resolves_sweet() -> void:
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var chain: Dictionary = _valid_chain("priscilla")
	var result: Dictionary = rules.resolve_primary_ending(_make_input(0, 0, chain["candidate"], chain["receipt_index"]))
	assert_true(result.get("ok", false))
	assert_eq(result["value"], "ending.priscilla.sweet")

func test_no_candidate_resolves_alone() -> void:
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var result: Dictionary = rules.resolve_primary_ending(_make_input(0, 3, null, {}))
	assert_true(result.get("ok", false))
	assert_eq(result["value"], "ending.alone")

func test_non_attended_completion_is_not_a_candidate() -> void:
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var chain: Dictionary = _valid_chain("sylvia")
	chain["receipt_index"]["complete:sylvia:d7"]["outcome"] = "not_attended"
	var result: Dictionary = rules.resolve_primary_ending(_make_input(0, 0, chain["candidate"], chain["receipt_index"]))
	assert_true(result.get("ok", false))
	assert_eq(result["value"], "ending.alone", "a scheduled-but-unattended date is not a primary")

func test_broken_chain_link_rejects() -> void:
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var chain: Dictionary = _valid_chain("priscilla")
	chain["receipt_index"]["complete:priscilla:d7"]["previous_receipt_id"] = "unlock:priscilla:d7"
	var result: Dictionary = rules.resolve_primary_ending(_make_input(0, 0, chain["candidate"], chain["receipt_index"]))
	assert_false(result.get("ok", true), "a completion that does not chain to its schedule rejects")

func test_candidate_friend_must_be_a_dateable_friend() -> void:
	var rules: Script = load(RULES_PATH)
	if rules == null:
		return
	var chain: Dictionary = _valid_chain("mystery")
	var result: Dictionary = rules.resolve_primary_ending(_make_input(0, 0, chain["candidate"], chain["receipt_index"]))
	assert_false(result.get("ok", true), "only priscilla, lavinia, or sylvia can be a primary candidate")
