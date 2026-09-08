extends GutTest
const MASTERY := preload("res://scripts/domain/ending/CanonicalDatingMastery.gd")
const FIXTURE := preload("res://tests/support/CanonicalDatingMasteryFixture.gd")
const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")

func _scope(scope: String) -> Dictionary:
	var made: Dictionary = FIXTURE.for_scope("mastery-run", scope)
	assert_true(made.ok, str(made))
	return made.get("value", {})

func test_all_required_solo_boards_are_perfect_even_after_dark_and_inputs_stay_detached() -> void:
	var priscilla := _scope("priscilla")
	var lavinia := _scope("lavinia")
	if priscilla.is_empty() or lavinia.is_empty(): return
	priscilla.heads.merge(lavinia.heads)
	priscilla.attempts.merge(lavinia.attempts)
	var before := priscilla.duplicate(true)
	var result: Dictionary = MASTERY.evaluate("mastery-run", priscilla.heads, priscilla.attempts)
	assert_eq(result, {"priscilla": true, "lavinia": true, "priscilla_lavinia": false})
	for attempt: Dictionary in priscilla.attempts.values():
		assert_eq(attempt.record.outcome, "perfect")
		assert_eq(attempt.record.relationship_outcome, "dark")
	assert_eq(priscilla, before)
	result.priscilla = false
	assert_true(MASTERY.evaluate("mastery-run", priscilla.heads, priscilla.attempts).priscilla)

func test_each_missing_head_or_completion_refuses_mastery_without_filling_from_history() -> void:
	for scope: String in MASTERY.WINDOWS:
		var evidence := _scope(scope)
		if evidence.is_empty(): return
		for slot: String in MASTERY.slots_for(scope):
			var missing: Dictionary = evidence.heads.duplicate(true)
			missing.erase(slot)
			assert_false(MASTERY.evaluate("mastery-run", missing, evidence.attempts)[scope], slot)
			var unfinished: Dictionary = evidence.attempts.duplicate(true)
			unfinished[slot].record.phase = "post_challenge"
			unfinished[slot].completion_receipt = null
			assert_true(LEDGER.validate_attempt(unfinished[slot]).ok)
			assert_false(MASTERY.evaluate("mastery-run", evidence.heads, unfinished)[scope], slot)

func test_exact_saved_branch_heads_allow_inheritance_but_refuse_siblings_other_runs_and_attempts() -> void:
	var evidence := _scope("priscilla")
	if evidence.is_empty(): return
	assert_true(MASTERY.evaluate("mastery-run", evidence.heads, evidence.attempts).priscilla,
		"a prior completed head keeps its original progress branch")
	assert_false(MASTERY.evaluate("another-run", evidence.heads, evidence.attempts).priscilla)
	var slot: String = MASTERY.slots_for("priscilla")[0]
	for key: String in ["run_id", "branch_id", "attempt_id", "slot_id"]:
		var foreign: Dictionary = evidence.attempts.duplicate(true)
		foreign[slot][key] = "foreign-" + key
		assert_false(MASTERY.evaluate("mastery-run", evidence.heads, foreign).priscilla, key)
	var missing: Dictionary = evidence.heads.duplicate(true)
	missing[slot].branch_id = "sibling-perfect"
	assert_false(MASTERY.evaluate("mastery-run", missing, evidence.attempts).priscilla,
		"the selected losing branch cannot borrow a completed sibling")
	missing[slot] = [evidence.heads[slot], evidence.heads[slot]]
	assert_false(MASTERY.evaluate("mastery-run", missing, evidence.attempts).priscilla,
		"a union is not a canonical slot head")

func test_real_solved_and_exploded_boards_do_not_replace_perfect_evidence() -> void:
	var evidence := _scope("priscilla")
	if evidence.is_empty(): return
	for outcome: String in ["cleared", "exploded"]:
		var made: Dictionary = FIXTURE.completed("mastery-run", "priscilla", 1, "original-progress", outcome)
		assert_true(made.ok, str(made))
		if not made.ok: return
		var attempt: Dictionary = made.value.attempt
		assert_true(LEDGER.validate_attempt(attempt).ok)
		assert_eq(attempt.record.outcome, outcome)
		var heads: Dictionary = evidence.heads.duplicate(true)
		var attempts: Dictionary = evidence.attempts.duplicate(true)
		heads[attempt.slot_id] = {"attempt_id": attempt.attempt_id, "branch_id": attempt.branch_id}
		attempts[attempt.slot_id] = attempt
		assert_false(MASTERY.evaluate("mastery-run", heads, attempts).priscilla)

func test_pair_mastery_requires_both_visible_group_or_deferred_physical_boards() -> void:
	var evidence := _scope("priscilla_lavinia")
	if evidence.is_empty(): return
	assert_eq(MASTERY.evaluate("mastery-run", evidence.heads, evidence.attempts),
		{"priscilla": false, "lavinia": false, "priscilla_lavinia": true})
	for kind: String in ["offscreen", "rehearsal", "hospital_superseded", "missed"]:
		var changed: Dictionary = evidence.attempts.duplicate(true)
		changed[MASTERY.slots_for("priscilla_lavinia")[0]].record.context.kind = kind
		assert_false(MASTERY.evaluate("mastery-run", evidence.heads, changed).priscilla_lavinia, kind)
	assert_eq(MASTERY.slots_for("sylvia"), [], "Sylvia has no Observer mastery route")

func test_game_state_uses_explicit_profile_heads_and_never_manufactures_observer_behavior() -> void:
	var game: Node = autofree(FIXTURE.Game.new())
	game.reset_game()
	game._lifecycle_set_playing_day(7)
	game.inter_friend_route_state.priscilla_lavinia = {"frozen_form": "love_sweet", "ending_eligible": true}
	var installed: Dictionary = FIXTURE.profile_for_scope(game, "priscilla_lavinia")
	assert_true(installed.ok, str(installed))
	if not installed.ok: return
	autofree(installed.value.profile)
	var before: Dictionary = game.route_context.duplicate(true)
	var no_behavior: Dictionary = game.prepare_provisional_day7_ending_plan()
	assert_true(no_behavior.ok, str(no_behavior))
	if not no_behavior.ok: return
	assert_true(no_behavior.value.eligibility_snapshot.board_mastery_by_scope.priscilla_lavinia)
	assert_eq(no_behavior.value.steps.size(), 2, "mastery alone has no Observer coda")
	assert_eq(game.route_context, before)
	for lookup: Dictionary in game.mastery_lookups:
		assert_eq(lookup.run_id, "run-local")
		assert_eq(lookup.branch_id, "original-progress")
		assert_eq(lookup.attempt_id, before.dating_canonical_heads[lookup.slot_id].attempt_id)
	game.route_context.observer_variant_by_scope = {"priscilla_lavinia": "residue"}
	assert_eq(game.prepare_provisional_day7_ending_plan().value.steps.size(), 2, "caller variant flags are not Profile behavior evidence")
	for form: String in ["ambiguous_sweet", "ambiguous_dark", "love_sweet", "love_dark"]:
		assert_true(installed.value.profile.record_pair_form_witness(form, "physical:" + form).ok)
	assert_true(installed.value.profile.unlock_ending("ending.priscilla_lavinia.observer", "ending:earlier:gallery:ending.priscilla_lavinia.observer").ok)
	var eligible: Dictionary = game.prepare_provisional_day7_ending_plan()
	assert_eq(eligible.value.steps.size(), 3)
	assert_eq(eligible.value.steps.back().presentation_variant, "residue")
	game.inter_friend_route_state.priscilla_lavinia.frozen_form = "love_dark"
	assert_eq(game.prepare_provisional_day7_ending_plan().value.steps.size(), 2, "Dark does not append Observer")
	game.inter_friend_route_state.priscilla_lavinia.frozen_form = "love_sweet"
	game.route_context.dating_canonical_heads.erase(MASTERY.slots_for("priscilla_lavinia")[0])
	var missing: Dictionary = game.prepare_provisional_day7_ending_plan()
	assert_eq(missing.value.steps.size(), 2, "a requested coda cannot replace missing board proof")
	assert_false(missing.value.eligibility_snapshot.board_mastery_by_scope.priscilla_lavinia)

func test_pair_observer_predicts_only_sole_missing_sweet_form_with_explicit_precondition() -> void:
	var game: Node = autofree(FIXTURE.Game.new())
	game.reset_game()
	game._lifecycle_set_playing_day(7)
	game.inter_friend_route_state.priscilla_lavinia = {"frozen_form": "love_sweet", "ending_eligible": true}
	var installed: Dictionary = FIXTURE.profile_for_scope(game, "priscilla_lavinia")
	assert_true(installed.ok, str(installed))
	if not installed.ok: return
	autofree(installed.value.profile)
	for form: String in ["ambiguous_sweet", "ambiguous_dark"]:
		assert_true(installed.value.profile.record_pair_form_witness(form, "physical:" + form).ok)
	assert_eq(game.prepare_provisional_day7_ending_plan().value.steps.size(), 2)
	assert_true(installed.value.profile.record_pair_form_witness("love_dark", "physical:love_dark").ok)
	var planned: Dictionary = game.prepare_provisional_day7_ending_plan()
	assert_true(planned.ok, str(planned))
	if not planned.ok: return
	assert_eq(planned.value.steps.size(), 3)
	assert_eq(planned.value.steps.back().presentation_variant, "full", "behavior discovery is not a previous full postscript")
	assert_eq(planned.value.eligibility_snapshot.pair_observer_witness_precondition,
		{"required_forms": ["ambiguous_sweet", "ambiguous_dark", "love_sweet", "love_dark"],
		"supplied_by_ending": "ending.priscilla_lavinia.sweet", "form": "love_sweet"})
