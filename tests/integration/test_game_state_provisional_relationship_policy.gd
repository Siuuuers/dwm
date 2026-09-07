extends GutTest

const GAME_STATE := preload("res://autoload/GameState.gd")


func _owner() -> Node:
	var owner: Node = add_child_autofree(GAME_STATE.new())
	owner.reset_game()
	return owner


func _issuer_receipt() -> Dictionary:
	return {"receipt_id": "issuer_receipt.provisional-rules", "purpose": "causal_day_instance",
		"namespace": "fixture", "counter": 1, "token": "causal-provisional", "numeric_value": null}


func test_new_run_preparation_freezes_pair_form_from_supplied_unwitnessed_pool() -> void:
	var owner := _owner()
	var witnessed: Array[String] = ["ambiguous_sweet", "ambiguous_dark", "love_sweet"]
	var prepared: Dictionary = owner.prepare_new_run_snapshot_input(
		"run-provisional-pair", "branch-provisional", 0, "causal-provisional",
		_issuer_receipt(), false, witnessed)

	assert_true(prepared.get("ok", false), str(prepared))
	var pair: Dictionary = prepared.value.snapshot_input.gameplay.inter_friend_route_state.priscilla_lavinia
	assert_eq(pair.frozen_form, "love_dark")
	assert_eq(pair.form_ruleset_id, "provisional.relationship.2026-09-07.v1")
	assert_eq(witnessed, ["ambiguous_sweet", "ambiguous_dark", "love_sweet"])


func test_board_fact_is_resolved_by_code_and_committed_once_with_durable_progression() -> void:
	var owner := _owner()
	owner.affection.priscilla = 3
	var entry := {"type": "solo", "friend_id": "priscilla", "day": 4}
	var fact := {"transaction_id": "dating-board-4-p", "outcome": "perfect"}
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
		{"transaction_id": "dating-board-pair-6", "outcome": "exploded"})

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


func test_day7_accessor_freezes_special_core_pair_and_observer_from_owned_facts() -> void:
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
		"ending.priscilla_lavinia.sweet", "ending.priscilla_lavinia.observer",
	])
	assert_eq(owner.route_context.provisional_ending_plan, frozen.value)

	owner.daily_opened_contacts.clear()
	assert_eq(frozen.value.steps[0].ending_id, "ending.sylvia.special",
		"the returned eligibility snapshot is detached from later GameState changes")
