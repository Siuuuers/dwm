extends "res://addons/gut/test.gd"

const RULES_PATH := "res://scripts/domain/ending/DatingEndingRules.gd"

func _rules_exist() -> bool:
	return ResourceLoader.exists(RULES_PATH, "Script")

func _inputs(overrides: Dictionary = {}) -> Dictionary:
	var base := {
		"candidate_friend_id": "",
		"dating_route_state": {},
		"affection_tiers": {},
		"sylvia_special": false,
		"pl_post_ending": false,
	}
	for key: Variant in overrides:
		base[key] = overrides[key]
	return base

func test_dating_ending_rules_exists() -> void:
	assert_true(_rules_exist(), "DatingEndingRules must exist")

func test_primary_selection_precedence() -> void:
	assert_true(_rules_exist(), "DatingEndingRules must exist")
	if not _rules_exist():
		return
	var rules: Script = load(RULES_PATH)
	# Sylvia special outranks everything, including a qualified pair epilogue.
	var special: Dictionary = rules.select_primary_ending(_inputs({"sylvia_special": true, "pl_post_ending": true}))
	assert_eq(special["value"]["ending_id"], "ending.sylvia.special")
	assert_eq(special["value"]["epilogue_ending_id"], "ending.priscilla_lavinia",
		"a qualified pair ending still plays as the epilogue behind the special")
	# Pair post-ending when nothing else qualifies.
	var pair: Dictionary = rules.select_primary_ending(_inputs({"pl_post_ending": true}))
	assert_eq(pair["value"]["ending_id"], "ending.priscilla_lavinia")
	assert_eq(pair["value"]["epilogue_ending_id"], "", "pair primary needs no epilogue of itself")
	# Alone when no candidate and no flags.
	assert_eq(rules.select_primary_ending(_inputs())["value"]["ending_id"], "ending.alone")

func test_friend_ending_tiers() -> void:
	assert_true(_rules_exist(), "DatingEndingRules must exist")
	if not _rules_exist():
		return
	var rules: Script = load(RULES_PATH)
	var true_end: Dictionary = rules.select_primary_ending(_inputs({
		"candidate_friend_id": "priscilla",
		"dating_route_state": {"priscilla": {"true_path_count": 4, "dark_points": 0}},
		"affection_tiers": {"priscilla": "love"},
	}))
	assert_eq(true_end["value"]["ending_id"], "ending.priscilla.true", "4 true clears at love wins true")
	var dark_end: Dictionary = rules.select_primary_ending(_inputs({
		"candidate_friend_id": "lavinia",
		"dating_route_state": {"lavinia": {"true_path_count": 1, "dark_points": 2}},
		"affection_tiers": {"lavinia": "ambiguous"},
	}))
	assert_eq(dark_end["value"]["ending_id"], "ending.lavinia.dark", "2 dark points wins dark")
	var sweet_end: Dictionary = rules.select_primary_ending(_inputs({
		"candidate_friend_id": "sylvia",
		"dating_route_state": {"sylvia": {"true_path_count": 0, "dark_points": 0}},
		"affection_tiers": {"sylvia": "love"},
	}))
	assert_eq(sweet_end["value"]["ending_id"], "ending.sylvia.sweet", "ordinary play wins sweet")

func test_recompute_synchronized_primary_demotes_pair_to_epilogue() -> void:
	assert_true(_rules_exist(), "DatingEndingRules must exist")
	if not _rules_exist():
		return
	var rules: Script = load(RULES_PATH)
	var recomputed: Dictionary = rules.recompute_synchronized_primary(_inputs({
		"candidate_friend_id": "priscilla",
		"dating_route_state": {"priscilla": {"true_path_count": 0, "dark_points": 3}},
		"affection_tiers": {"priscilla": "love"},
		"pl_post_ending": true,
	}))
	assert_true(recomputed.get("ok", false), JSON.stringify(recomputed))
	assert_eq(recomputed["value"]["ending_id"], "ending.priscilla.dark",
		"the synchronized primary is the Angela pairing, never the group")
	assert_eq(recomputed["value"]["epilogue_ending_id"], "ending.priscilla_lavinia",
		"the group ending is demoted to the epilogue slot")

func test_invalid_inputs_reject() -> void:
	assert_true(_rules_exist(), "DatingEndingRules must exist")
	if not _rules_exist():
		return
	var rules: Script = load(RULES_PATH)
	assert_false(rules.select_primary_ending({"candidate_friend_id": ""}).get("ok", true),
		"missing keys reject")
	assert_false(rules.select_primary_ending(_inputs({"sylvia_special": "yes"})).get("ok", true),
		"non-bool flag rejects")
	assert_true(rules.is_canonical_ending("ending.sylvia.special"))
	assert_false(rules.is_canonical_ending("sylvia.special"), "legacy dotted ids are not canonical")
