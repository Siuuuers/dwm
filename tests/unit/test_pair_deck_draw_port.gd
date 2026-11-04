extends GutTest
const GAME := preload("res://autoload/GameState.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const DRAW := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const PORT := preload("res://scripts/application/run/PairDeckDrawPort.gd")
const HOSPITAL := preload("res://scripts/application/run/GameStateConditionHospitalPort.gd")
const COORDINATOR := preload("res://scripts/application/run/ConditionHospitalCoordinator.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const BOARD_FIXTURE := preload("res://tests/support/CanonicalDatingMasteryFixture.gd")

class Nonces extends RefCounted:
	var values: Array[int] = [1]
	var calls := 0
	func next() -> int:
		var result: int = values[mini(calls, values.size() - 1)]
		calls += 1
		return result

func _wired() -> Dictionary:
	var game: Node = autofree(GAME.new())
	game.reset_game()
	var gate := GATE.new()
	assert_true(game.configure_mutation_gate(gate).ok)
	var storage := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"pair-deck-profile", preload("res://tests/support/FakeFileOps.gd").new())
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(storage).ok)
	assert_true(profile.configure_mutation_gate(gate).ok)
	var condition := COORDINATOR.new()
	condition._gate = gate
	var nonces := Nonces.new()
	var draw := PORT.new()
	assert_true(draw.configure(game, profile, gate, condition, nonces.next).ok)
	var hospital := HOSPITAL.new()
	hospital._game = game
	assert_true(hospital.configure_pair_deck(draw).ok)
	return {"game": game, "gate": gate, "profile": profile, "storage": storage,
		"condition": condition, "nonces": nonces, "draw": draw, "hospital": hospital,
		"run_id": str(game._run_lifecycle.to_dict().run_id)}

func test_selected_pre_pair_save_imports_form_already_reached_in_original_profile_history() -> void:
	var f := _wired()
	var made: Dictionary = BOARD_FIXTURE.completed(f.run_id, "priscilla_lavinia", 2)
	assert_true(made.ok, str(made))
	if not made.ok: return
	var candidate: Dictionary = f.profile.get_profile_snapshot()
	candidate.dating_attempts = made.value.ledger
	assert_true(f.profile.commit_prepared_profile(candidate).ok)
	# Old New Run placeholder is not itself reached evidence.
	f.game.inter_friend_route_state.priscilla_lavinia = {"frozen_form": "ambiguous_dark", "date_count": 0}
	assert_eq(f.game.get_counted_pair_window_count(), 0)
	var drawn: Dictionary = f.draw.prepare_schedule(true)
	assert_true(drawn.ok, str(drawn))
	if not drawn.ok: return
	assert_eq(drawn.value.draw_receipt.selection_kind, "legacy_established")
	assert_eq(drawn.value.draw_receipt.form, "love_sweet")
	assert_eq(f.game.inter_friend_route_state.priscilla_lavinia.frozen_form, "love_sweet")
	assert_eq(f.nonces.calls, 0)

func test_existing_offscreen_count_imports_established_form_without_witness_or_rng() -> void:
	var f := _wired()
	var closed: Dictionary = CONTACTS.prepare_resolve_day_end(f.game.contacts, 2, {}, "old-offscreen-count")
	assert_true(closed.ok, str(closed))
	if not closed.ok: return
	f.game.contacts = closed.value.candidate
	f.game.inter_friend_route_state.priscilla_lavinia = {"frozen_form": "love_dark", "date_count": 0}
	var drawn: Dictionary = f.draw.prepare_schedule()
	assert_true(drawn.ok, str(drawn))
	if not drawn.ok: return
	assert_eq(drawn.value.draw_receipt, DRAW.build_legacy("love_dark").value)
	assert_eq(f.profile.get_pair_form_witnesses().value, [])
	assert_eq(f.nonces.calls, 0)

func test_unreached_old_placeholder_uses_current_unseen_pool_and_independent_nonce() -> void:
	var f := _wired()
	f.game.inter_friend_route_state.priscilla_lavinia = {"frozen_form": "love_dark", "date_count": 0}
	assert_true(f.profile.record_pair_form_witness("ambiguous_dark", "presented-earlier-run").ok)
	f.nonces.values.assign([4294967295, 0])
	var drawn: Dictionary = f.draw.prepare_schedule()
	assert_true(drawn.ok, str(drawn))
	if not drawn.ok: return
	assert_eq(drawn.value.draw_receipt.form, "ambiguous_sweet")
	assert_eq(drawn.value.draw_receipt.rng_nonce, 0)
	assert_eq(f.nonces.calls, 2, "the incomplete three-form bucket is retried")
	assert_eq(f.game.inter_friend_route_state.priscilla_lavinia.frozen_form, "love_dark", "preparing does not install")

func test_loaded_older_branch_reuses_original_run_draw_even_after_profile_discoveries() -> void:
	var f := _wired()
	var before: Dictionary = f.game.capture_restore_state().value.backup
	var first: Dictionary = f.draw.prepare_schedule(true)
	assert_true(first.ok, str(first))
	if not first.ok: return
	assert_true(f.game.rollback_restore_silent(before).ok)
	var lifecycle: Dictionary = f.game._run_lifecycle.to_dict()
	lifecycle.branch_id = "selected-older-branch"
	assert_true(f.game._run_lifecycle.commit_restore(f.game._run_lifecycle.prepare_restore(lifecycle).value.candidate).ok)
	assert_true(f.profile.record_pair_form_witness(first.value.draw_receipt.form, "later-discovery").ok)
	var restored_draw := PORT.new()
	assert_true(restored_draw.configure(f.game, f.profile, f.gate, f.condition, f.nonces.next).ok)
	var second: Dictionary = restored_draw.prepare_schedule(true)
	assert_true(second.ok, str(second))
	assert_eq(second.value.draw_receipt, first.value.draw_receipt)
	assert_eq(f.nonces.calls, 1)

func test_condition_count_candidate_uses_same_draw_without_borrowing_or_releasing_foreign_lease() -> void:
	var f := _wired()
	var closed: Dictionary = CONTACTS.prepare_resolve_day_end(f.game.contacts, 2, {}, "hospital-pair-count")
	assert_true(closed.ok, str(closed))
	if not closed.ok: return
	var stage := {"stage_id": "close_invitation_sources", "prepared": {
		"owner_candidate": {"contacts": closed.value.candidate, "gameplay": f.game.capture_run_snapshot_input().gameplay},
		"output": {"pl_window": closed.receipt.pl_window}}}
	var foreign: Dictionary = f.gate.acquire(&"causal_transaction")
	assert_eq(f.hospital.execute_stage({}, stage).code, &"pair_deck_condition_custody_required")
	assert_true(f.gate.is_lease_active(&"causal_transaction", foreign.value.token))
	assert_true(f.gate.release(&"causal_transaction", foreign.value.token).ok)
	assert_true(f.condition._ensure_gate().ok)
	var before: Dictionary = f.game.capture_restore_state().value.backup
	var result: Dictionary = f.hospital.execute_stage({}, stage)
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_true(f.condition.has_owned_causal_lease(f.gate))
	assert_eq(result.value.owner_candidate.gameplay.inter_friend_route_state.priscilla_lavinia.pair_deck_draw,
		f.profile.get_pair_deck_draw(f.run_id).value)
	assert_true(f.hospital.commit_stage("close_invitation_sources", result.value.owner_candidate).ok)
	assert_eq(f.game.get_counted_pair_window_count(), 1)
	assert_true(f.condition._release_gate().ok)

func test_stale_condition_token_cannot_authorize_same_kind_replacement_lease() -> void:
	var f := _wired()
	assert_true(f.condition._ensure_gate().ok)
	var stolen: String = f.condition._gate_token
	assert_true(f.gate.release(&"causal_transaction", stolen).ok)
	var foreign: Dictionary = f.gate.acquire(&"causal_transaction")
	assert_false(f.condition.has_owned_causal_lease())
	assert_eq(f.draw.prepare_condition().code, &"pair_deck_condition_custody_required")
	assert_false(f.condition._ensure_gate().ok)
	assert_false(f.condition._release_gate().ok)
	assert_true(f.gate.is_lease_active(&"causal_transaction", foreign.value.token))
	assert_null(f.profile.get_pair_deck_draw(f.run_id).value)
	assert_true(f.gate.release(&"causal_transaction", foreign.value.token).ok)

func _record_pair_ending(f: Dictionary, run_id: String, form: String) -> void:
	var ending_id: String = "ending.priscilla_lavinia." + ("dark" if form.ends_with("_dark") else "sweet")
	var acquired: Dictionary = f.gate.acquire(&"causal_transaction")
	assert_true(acquired.ok)
	var recorded: Dictionary = f.profile.record_ending_completion(ending_id,
		"ending:%s:gallery:%s" % [run_id, ending_id], form)
	assert_true(recorded.ok, str(recorded))
	assert_true(f.gate.release(&"causal_transaction", acquired.value.token).ok)

func test_legacy_offscreen_ending_preserves_its_form_from_an_older_save_after_clear_gallery() -> void:
	var f := _wired()
	_record_pair_ending(f, f.run_id, "love_dark")
	assert_true(f.profile.reset_gallery().ok)
	assert_null(f.profile.get_pair_deck_draw(f.run_id).value)
	assert_eq(f.profile.get_dating_attempt(f.run_id, "dating.pair.priscilla_lavinia.day2").value, {})
	assert_eq(f.game.get_counted_pair_window_count(), 0)
	f.game.inter_friend_route_state.priscilla_lavinia = {"frozen_form": "ambiguous_sweet", "date_count": 0}
	var drawn: Dictionary = f.draw.prepare_schedule(true)
	assert_true(drawn.ok, str(drawn))
	if not drawn.ok: return
	assert_eq(drawn.value.draw_receipt, DRAW.build_legacy("love_dark").value)
	assert_eq(f.game.inter_friend_route_state.priscilla_lavinia.frozen_form, "love_dark")
	assert_eq(f.nonces.calls, 0)

func test_another_runs_ending_cannot_supply_this_runs_legacy_form() -> void:
	var f := _wired()
	_record_pair_ending(f, f.run_id + "-other", "love_dark")
	var drawn: Dictionary = f.draw.prepare_schedule()
	assert_true(drawn.ok, str(drawn))
	if not drawn.ok: return
	assert_eq(drawn.value.draw_receipt.selection_kind, "draw")
	assert_eq(f.nonces.calls, 1)

func test_conflicting_or_unpaired_legacy_ending_witnesses_refuse_before_drawing() -> void:
	for malformed: String in ["conflicting_forms", "missing_completion"]:
		var f := _wired()
		_record_pair_ending(f, f.run_id, "love_sweet")
		# Model a schema-valid historical Profile inconsistency; the real current
		# record_ending_completion API already refuses a second form for the same run.
		var candidate: Dictionary = f.profile.get_profile_snapshot()
		if malformed == "conflicting_forms":
			candidate.pair_form_witness_receipts["ending:%s:pair-form:ambiguous_sweet" % f.run_id] = "ambiguous_sweet"
		else:
			candidate.gallery_transaction_receipts.erase("ending:%s:gallery:ending.priscilla_lavinia.sweet" % f.run_id)
		assert_true(f.profile.commit_prepared_profile(candidate).ok)
		var before: Dictionary = f.game.capture_restore_state().value.backup
		assert_false(f.draw.prepare_schedule(true).ok, malformed)
		assert_null(f.profile.get_pair_deck_draw(f.run_id).value)
		assert_eq(f.game.capture_restore_state().value.backup, before)
		assert_eq(f.nonces.calls, 0)
