extends GutTest

const GAME_STATE := preload("res://autoload/GameState.gd")


func _owner() -> Node:
	var owner: Node = add_child_autofree(GAME_STATE.new())
	owner.reset_game()
	return owner


func _issuer_receipt() -> Dictionary:
	return {"receipt_id": "issuer_receipt.provisional-rules", "purpose": "causal_day_instance",
		"namespace": "fixture", "counter": 1, "token": "causal-provisional", "numeric_value": null}


func test_new_run_preparation_defers_pair_draw_until_first_counted_encounter() -> void:
	var owner := _owner()
	var witnessed: Array[String] = ["ambiguous_sweet", "ambiguous_dark", "love_sweet"]
	var prepared: Dictionary = owner.prepare_new_run_snapshot_input(
		"run-provisional-pair", "branch-provisional", 0, "causal-provisional",
		_issuer_receipt(), false, witnessed)

	assert_true(prepared.get("ok", false), str(prepared))
	var pair: Dictionary = prepared.value.snapshot_input.gameplay.inter_friend_route_state.priscilla_lavinia
	assert_false(pair.has("frozen_form"))
	assert_false(pair.has("pair_deck_draw"))
	assert_eq(pair.date_count, 0)
	assert_eq(witnessed, ["ambiguous_sweet", "ambiguous_dark", "love_sweet"])


func test_board_fact_is_resolved_by_code_and_committed_once_with_durable_progression() -> void:
	var owner := _owner()
	owner.affection.priscilla = 3
	var entry := {"type": "solo", "friend_id": "priscilla", "day": 4}
	var fact := {"transaction_id": "dating-board-4-p", "outcome": "perfect", "relationship_outcome": "foresight", "perfect_reasons": ["no_flag"]}
	var committed: Dictionary = owner.apply_dating_challenge_result(entry, fact)

	assert_true(committed.get("ok", false), str(committed))
	assert_false(committed.value.replayed)
	assert_eq(owner.affection.priscilla, 5, "Perfect's provisional momentum is code-owned")
	assert_eq(owner.dating_route_state.priscilla.relationship_state, "ambiguous")
	assert_true(owner.dating_route_state.priscilla.progression_event_ids.has("dating-board-4-p"))
	assert_eq(owner.dating_route_state.priscilla.provisional_receipts["dating-board-4-p"].outcome, "perfect")

	var after_first: Dictionary = owner.to_save_dict()
	var replay: Dictionary = owner.apply_dating_challenge_result(entry, fact)
	assert_true(replay.get("ok", false), str(replay))
	assert_true(replay.value.replayed)
	assert_eq(owner.to_save_dict(), after_first, "same board receipt cannot apply twice")

	var restored := _owner()
	assert_true(restored.apply_save_dict(after_first).get("ok", false))
	assert_eq(restored.dating_route_state.priscilla.relationship_state, "ambiguous")
	assert_true(restored.apply_dating_challenge_result(entry, fact).value.replayed,
		"idempotency survives the existing save round trip")

	var arbitrary := fact.duplicate(true)
	arbitrary["affection_delta"] = 99
	var before_invalid: Dictionary = restored.to_save_dict()
	var refused: Dictionary = restored.apply_dating_challenge_result(entry, arbitrary)
	assert_false(refused.get("ok", true))
	assert_eq(refused.get("code"), &"invalid_dating_terminal_fact")
	assert_eq(restored.to_save_dict(), before_invalid)


func test_pair_board_commit_preserves_run_frozen_form() -> void:
	var owner := _owner()
	owner.inter_friend_route_state.priscilla_lavinia = {
		"frozen_form": "ambiguous_dark",
		"form_ruleset_id": "provisional.relationship.2026-09-07.v1",
		"date_count": 0,
		"dark_points": 0,
		"provisional_receipts": {},
	}
	var result: Dictionary = owner.apply_dating_challenge_result(
		{"type": "twofriends", "friend_ids": ["priscilla", "lavinia"], "day": 6},
		{"transaction_id": "dating-board-pair-6", "outcome": "perfect", "relationship_outcome": "dark", "perfect_reasons": ["no_flag"]})

	assert_true(result.get("ok", false), str(result))
	assert_eq(owner.inter_friend_route_state.priscilla_lavinia.frozen_form, "ambiguous_dark")
	assert_eq(owner.inter_friend_route_state.priscilla_lavinia.date_count, 1)
	assert_eq(owner.inter_friend_route_state.priscilla_lavinia.dark_points, 1)


func test_hospital_uses_joint_boundary_and_recovery_does_not_accumulate_special() -> void:
	var owner := _owner()
	owner.set_stat(owner.STAT_PRESSURE, 10)
	owner.set_stat(owner.STAT_HEALTH, 1)
	assert_false(owner.resolve_pressure_health_condition_end_of_day().needs_hospital)

	owner.condition_resolved_day = 0
	owner.set_stat(owner.STAT_PRESSURE, 10)
	owner.set_stat(owner.STAT_HEALTH, 0)
	var hospital: Dictionary = owner.resolve_pressure_health_condition_end_of_day()
	assert_true(hospital.needs_hospital)
	assert_true(owner.should_route_hospital())
	owner.hospital_skipped_sylvia_solo_count = 1
	owner.apply_hospital_recovery_and_advance_day()
	assert_eq(owner.get_stat(owner.STAT_PRESSURE), 3)
	assert_eq(owner.get_stat(owner.STAT_HEALTH), 6)
	assert_eq(owner.hospital_skipped_sylvia_solo_count, 1,
		"earlier Hospital events never accumulate toward Sylvia Special")


func test_day7_accessor_freezes_special_core_pair_and_refuses_unproven_observer() -> void:
	var owner := _owner()
	owner._lifecycle_set_playing_day(7)
	owner.set_stat(owner.STAT_PRESSURE, 10)
	owner.set_stat(owner.STAT_HEALTH, 0)
	owner.daily_opened_contacts["day:7:friend:sylvia"] = true
	owner.inter_friend_route_state.priscilla_lavinia = {
		"frozen_form": "love_sweet", "ending_eligible": true,
		"form_ruleset_id": "provisional.relationship.2026-09-07.v1",
	}
	owner.route_context["observer_variant_by_scope"] = {"priscilla_lavinia": "full"}
	assert_true(owner.resolve_pressure_health_condition_end_of_day().needs_hospital)

	var frozen: Dictionary = owner.capture_provisional_day7_ending_plan()
	assert_true(frozen.get("ok", false), str(frozen))
	assert_eq(frozen.value.steps.map(func(step: Dictionary) -> String: return step.ending_id), [
		"ending.sylvia.special", "ending.sylvia.dark",
		"ending.priscilla_lavinia.sweet",
	])
	assert_false(frozen.value.eligibility_snapshot.board_mastery_by_scope.priscilla_lavinia,
		"an Observer variant request cannot substitute for both current completed pair boards")
	assert_eq(owner.route_context.provisional_ending_plan, frozen.value)

	owner.daily_opened_contacts.clear()
	assert_eq(frozen.value.steps[0].ending_id, "ending.sylvia.special",
		"the returned eligibility snapshot is detached from later GameState changes")


func test_all_six_promised_relationship_outcomes_apply_exact_stats_and_attitudes() -> void:
	var cases := [
		["exploded", "hatred", [], -1, 0, "hostile"],
		["exploded", "upset", [], 0, 0, "upset"],
		["exploded", "amused", [], 1, 0, "amused"],
		["cleared", "loved", [], 2, 0, "affectionate"],
		["perfect", "foresight", ["no_flag"], 2, 0, "seen"],
		["perfect", "dark", ["efficiency_gt_100", "no_flag"], 2, 1, "fixated"],
	]
	for row: Array in cases:
		var owner := _owner()
		owner.affection.priscilla = 3
		var fact := {"transaction_id": "outcome-" + str(row[1]), "outcome": row[0],
			"relationship_outcome": row[1], "perfect_reasons": row[2]}
		var entry := {"type": "solo", "friend_id": "priscilla", "day": 1}
		var result: Dictionary = owner.apply_dating_challenge_result(entry, fact)
		assert_true(result.get("ok", false), str(result))
		if not result.get("ok", false): continue
		assert_eq(owner.affection.priscilla, 3 + int(row[3]))
		assert_eq(owner.dating_route_state.priscilla.dark_points, row[4])
		assert_eq(owner.friend_attitude.priscilla, row[5])
		var changed := fact.duplicate(true)
		changed.relationship_outcome = "upset" if row[0] == "exploded" and row[1] != "upset" else "hatred"
		assert_false(owner.apply_dating_challenge_result(entry, changed).get("ok", true), "one terminal ID never changes its relationship result")


func test_pair_ending_counts_distinct_contacts_windows_including_offscreen_meetings() -> void:
	var contacts_owner := preload("res://scripts/domain/contact/ContactInvitationState.gd")
	GameState.reset_game()
	for pair: Array in [[2, "window-two"], [2, "window-two-replay"], [6, "window-six"]]:
		var resolved: Dictionary = contacts_owner.prepare_resolve_day_end(GameState.contacts,
			int(pair[0]), {}, str(pair[1]))
		assert_true(resolved.get("ok", false), str(resolved))
		GameState.contacts = resolved.value.candidate
		assert_eq(GameState.get_counted_pair_window_count(), 2 if int(pair[0]) == 6 else 1)
	assert_true(GameState.should_route_priscilla_lavinia_post_ending())
	assert_false(GameState.inter_friend_route_state.get("priscilla_lavinia", {}).get("ending_eligible", false),
		"eligibility reads existing receipts without a duplicate mutable counter")


func test_attended_solo_window_does_not_count_toward_pair_ending() -> void:
	var contacts_owner := preload("res://scripts/domain/contact/ContactInvitationState.gd")
	GameState.reset_game()
	for source_day: int in [2, 6]:
		var attendance := {"solo_attended_action_ids": ["solo:priscilla:day2"]} if source_day == 2 else {}
		var resolved: Dictionary = contacts_owner.prepare_resolve_day_end(GameState.contacts,
			source_day, attendance, "window-%d" % source_day)
		assert_true(resolved.get("ok", false), str(resolved))
		GameState.contacts = resolved.value.candidate
	assert_eq(GameState.get_counted_pair_window_count(), 1)
	assert_false(GameState.should_route_priscilla_lavinia_post_ending())


func test_frozen_held_promotion_does_not_recompute_against_a_different_loaded_branch() -> void:
	var source := _owner()
	var entry := {"type": "solo", "friend_id": "priscilla", "day": 4}
	var fact := {"transaction_id": "attempt-first:effect", "outcome": "cleared",
		"relationship_outcome": "loved", "perfect_reasons": []}
	var before: Dictionary = source.to_save_dict()
	var prepared: Dictionary = source.prepare_dating_challenge_effect(entry, fact)
	assert_true(prepared.get("ok", false), str(prepared))
	assert_eq(source.to_save_dict(), before, "preparing a commitment has no live effect")
	var receipt: Dictionary = prepared.value.receipt
	assert_true(receipt.progression_evaluated)
	assert_false(receipt.promotion_applied)
	var restored := _owner()
	restored.affection["priscilla"] = 6
	restored.dating_route_state["priscilla"]["relationship_state"] = "ambiguous"
	var applied: Dictionary = restored.apply_dating_challenge_effect_receipt(entry, receipt)
	assert_true(applied.get("ok", false), str(applied))
	assert_eq(restored.affection["priscilla"], 8)
	assert_eq(restored.dating_route_state["priscilla"]["relationship_state"], "ambiguous",
		"frozen held decision must not become a fresh Love promotion")
	var after: Dictionary = restored.to_save_dict()
	assert_true(restored.apply_dating_challenge_effect_receipt(entry, receipt).value.replayed)
	assert_eq(restored.to_save_dict(), after)
	var altered := receipt.duplicate(true)
	altered["momentum_delta"] = 99
	assert_false(restored.apply_dating_challenge_effect_receipt(entry, altered).ok)
	assert_eq(restored.to_save_dict(), after, "conflicting commitment changes nothing")


func test_frozen_earned_promotion_survives_lower_momentum_and_save_reload_without_second_effect() -> void:
	var source := _owner()
	source.affection["priscilla"] = 3
	var entry := {"type": "solo", "friend_id": "priscilla", "day": 4}
	var fact := {"transaction_id": "attempt-earned:effect", "outcome": "perfect",
		"relationship_outcome": "foresight", "perfect_reasons": ["no_flag"]}
	var receipt: Dictionary = source.prepare_dating_challenge_effect(entry, fact).value.receipt
	assert_true(receipt.promotion_applied)
	var restored := _owner()
	assert_true(restored.apply_dating_challenge_effect_receipt(entry, receipt).ok)
	assert_eq(restored.affection["priscilla"], 2)
	assert_eq(restored.dating_route_state["priscilla"]["relationship_state"], "ambiguous")
	var cold := _owner()
	cold.apply_save_dict(restored.to_save_dict())
	var before: Dictionary = cold.to_save_dict()
	assert_true(cold.apply_dating_challenge_effect_receipt(entry, receipt).value.replayed)
	assert_eq(cold.to_save_dict(), before)
	assert_false(cold.apply_dating_challenge_effect_receipt(
		{"type": "solo", "friend_id": "lavinia", "day": 5}, receipt).ok)
	assert_eq(cold.to_save_dict(), before, "effect cannot move into another slot")


func test_canonical_solo_effect_clamps_affection_and_permanent_dark_to_design_limits() -> void:
	var owner := _owner()
	owner.affection.priscilla = -4
	var entry := {"type": "solo", "friend_id": "priscilla", "day": 1}
	var hated: Dictionary = owner.apply_dating_challenge_result(entry, {
		"transaction_id": "bounded-hatred", "outcome": "exploded", "relationship_outcome": "hatred", "perfect_reasons": []})
	assert_true(hated.get("ok", false), str(hated))
	assert_eq(owner.affection.priscilla, -4, "the fifth negative point is not applied")
	owner.affection.priscilla = 10
	owner.dating_route_state.priscilla.dark_points = 4
	var dark: Dictionary = owner.apply_dating_challenge_result(entry, {
		"transaction_id": "bounded-dark", "outcome": "perfect", "relationship_outcome": "dark", "perfect_reasons": ["no_flag"]})
	assert_true(dark.get("ok", false), str(dark))
	assert_eq(owner.affection.priscilla, 10)
	assert_eq(owner.dating_route_state.priscilla.dark_points, 4, "terminal Dark cannot exceed the permanent cap")
	assert_eq(owner.dating_route_state.priscilla.get("relationship_state", "friend"), "friend",
		"high affection and dark do not invent a promotion outside its valve")
