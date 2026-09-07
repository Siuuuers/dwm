extends GutTest

const RULES := preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd")

var rules: RefCounted


func before_each() -> void:
	rules = RULES.new()


func test_pair_form_uses_unwitnessed_pool_then_all_four_without_mutating_profile_input() -> void:
	var witnessed: Array[String] = ["ambiguous_sweet"]
	var result: Dictionary = rules.select_pair_form(witnessed, 0)

	assert_true(result.get("ok", false), str(result))
	assert_eq(result.value.form, "ambiguous_dark")
	assert_eq(result.value.eligible_pool, ["ambiguous_dark", "love_sweet", "love_dark"])
	assert_eq(witnessed, ["ambiguous_sweet"])

	result = rules.select_pair_form(RULES.PAIR_FORMS.duplicate(), 3)
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.value.eligible_pool, RULES.PAIR_FORMS)
	assert_eq(result.value.form, "love_dark")


func test_progression_runs_once_only_at_attended_unsuperseded_provisional_windows() -> void:
	var input := {
		"window_id": "dating.solo.priscilla.day4",
		"event_id": "date-event-4-p",
		"friend_id": "priscilla",
		"attended": true,
		"hospital_superseded": false,
		"current_state": "friend",
		"relational_momentum": 4,
		"response_qualifies": true,
		"committed_event_ids": [],
	}
	var advanced: Dictionary = rules.evaluate_progression(input)

	assert_true(advanced.get("ok", false), str(advanced))
	assert_true(advanced.value.evaluated)
	assert_eq(advanced.value.previous_state, "friend")
	assert_eq(advanced.value.state, "ambiguous")
	assert_eq(advanced.value.commit_event_id, "date-event-4-p")

	input.current_state = "ambiguous"
	input.relational_momentum = 7
	input.committed_event_ids = ["date-event-4-p"]
	var replay: Dictionary = rules.evaluate_progression(input)
	assert_true(replay.get("ok", false), str(replay))
	assert_false(replay.value.evaluated)
	assert_eq(replay.value.state, "ambiguous")
	assert_eq(replay.value.reason, "already_evaluated")

	input.event_id = "date-event-6-p"
	input.window_id = "dating.solo.priscilla.day6"
	input.committed_event_ids = []
	var love: Dictionary = rules.evaluate_progression(input)
	assert_true(love.get("ok", false), str(love))
	assert_eq(love.value.state, "love")

	input.event_id = "date-event-5-s"
	input.window_id = "dating.solo.sylvia.day5"
	input.friend_id = "sylvia"
	input.current_state = "friend"
	input.hospital_superseded = true
	var superseded: Dictionary = rules.evaluate_progression(input)
	assert_true(superseded.get("ok", false), str(superseded))
	assert_false(superseded.value.evaluated)
	assert_eq(superseded.value.reason, "hospital_superseded")

	input.hospital_superseded = false
	input.window_id = "dating.solo.sylvia.day3"
	var closed: Dictionary = rules.evaluate_progression(input)
	assert_true(closed.get("ok", false), str(closed))
	assert_false(closed.value.evaluated)
	assert_eq(closed.value.reason, "not_progression_window")


func test_hospital_requires_both_boundaries_and_selects_only_the_owned_branch() -> void:
	var base := {"day": 4, "pressure": 10, "health": 0,
		"sylvia_encounter_committed": false, "sylvia_invitation_read": false}
	var code_only: Dictionary = rules.resolve_hospital(base)
	assert_true(code_only.get("ok", false), str(code_only))
	assert_true(code_only.value.required)
	assert_eq(code_only.value.branch, "code_only")
	assert_eq(code_only.value.recovery, {"pressure": 3, "health": 6})

	base.sylvia_encounter_committed = true
	var variant: Dictionary = rules.resolve_hospital(base)
	assert_true(variant.get("ok", false), str(variant))
	assert_eq(variant.value.branch, "sylvia_variant")

	base.pressure = 9
	assert_eq(rules.resolve_hospital(base).value.branch, "none")
	base.pressure = 10
	base.health = 1
	assert_eq(rules.resolve_hospital(base).value.branch, "none")

	base.day = 7
	base.health = 0
	base.sylvia_invitation_read = false
	assert_eq(rules.resolve_hospital(base).value.branch, "ending_alone")
	base.sylvia_invitation_read = true
	assert_eq(rules.resolve_hospital(base).value.branch, "ending_special")


func test_day7_freezes_personal_pair_and_observer_in_promised_order() -> void:
	var input := {
		"day": 7,
		"committed_destination": "priscilla",
		"relationship_states": {"priscilla": "love", "lavinia": "friend", "sylvia": "friend"},
		"invitation_read": {"priscilla": true, "lavinia": false, "sylvia": false},
		"tone_points": 2,
		"hospital_required": false,
		"pair_ending_eligible": true,
		"pair_form": "love_sweet",
		"observer_variant_by_scope": {"priscilla_lavinia": "full"},
	}
	var frozen: Dictionary = rules.freeze_day7_ending_plan(input)

	assert_true(frozen.get("ok", false), str(frozen))
	assert_eq(frozen.value.steps.map(func(step: Dictionary) -> String: return step.ending_id),
		["ending.priscilla.dark", "ending.priscilla_lavinia.sweet", "ending.priscilla_lavinia.observer"])
	assert_eq(frozen.value.steps.map(func(step: Dictionary) -> String: return step.role),
		["core", "pair_coda", "observer_coda"])
	assert_eq(frozen.value.steps[2].presentation_variant, "full")

	input.committed_destination = "lavinia"
	assert_eq(frozen.value.eligibility_snapshot.committed_destination, "priscilla",
		"the frozen plan owns a detached eligibility snapshot")


func test_day7_special_prefix_forces_sylvia_dark_before_independent_codas() -> void:
	var input := {
		"day": 7,
		"committed_destination": "",
		"relationship_states": {"priscilla": "love", "lavinia": "love", "sylvia": "friend"},
		"invitation_read": {"priscilla": false, "lavinia": false, "sylvia": true},
		"tone_points": 0,
		"hospital_required": true,
		"pair_ending_eligible": true,
		"pair_form": "ambiguous_dark",
		"observer_variant_by_scope": {"priscilla_lavinia": "residue"},
	}
	var frozen: Dictionary = rules.freeze_day7_ending_plan(input)

	assert_true(frozen.get("ok", false), str(frozen))
	assert_eq(frozen.value.steps.map(func(step: Dictionary) -> String: return step.ending_id), [
		"ending.sylvia.special", "ending.sylvia.dark",
		"ending.priscilla_lavinia.dark", "ending.priscilla_lavinia.observer",
	])
	assert_eq(frozen.value.steps.map(func(step: Dictionary) -> String: return step.role),
		["special_prefix", "core", "pair_coda", "observer_coda"])

	input.invitation_read.sylvia = false
	input.pair_ending_eligible = false
	input.observer_variant_by_scope = {}
	var alone: Dictionary = rules.freeze_day7_ending_plan(input)
	assert_true(alone.get("ok", false), str(alone))
	assert_eq(alone.value.steps.map(func(step: Dictionary) -> String: return step.ending_id),
		["ending.alone"])


func test_day7_rejects_invalid_committed_destination_instead_of_silently_replacing_it() -> void:
	var result: Dictionary = rules.freeze_day7_ending_plan({
		"day": 7,
		"committed_destination": "lavinia",
		"relationship_states": {"priscilla": "friend", "lavinia": "friend", "sylvia": "friend"},
		"invitation_read": {"priscilla": false, "lavinia": true, "sylvia": false},
		"tone_points": 0,
		"hospital_required": false,
		"pair_ending_eligible": false,
		"pair_form": "",
		"observer_variant_by_scope": {},
	})

	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"ineligible_committed_destination")
