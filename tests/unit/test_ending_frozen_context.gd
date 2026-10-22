extends "res://addons/gut/test.gd"

const FROZEN := preload("res://scripts/narrative/EndingFrozenContext.gd")
const STATE := preload("res://autoload/GameState.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")

class Writer extends RefCounted:
	var state: Node
	var fail_next := false
	var snapshots: Array = []
	func write() -> Dictionary:
		if fail_next:
			fail_next = false
			return {"ok": false, "code": &"fixture_write_failed"}
		snapshots.append(state.capture_restore_state().value.backup)
		return {"ok": true}

func _inputs() -> Dictionary:
	var values := {"dark_mode": false, "pair_form": "love_sweet", "special_variant": "full"}
	for friend: String in FROZEN.FRIENDS:
		values[friend] = {"tier": "love", "tone": "sweet", "attitude": "affectionate", "echo_ids": [], "miss_reasons": []}
	return values

func _seed(cause: String = "empty_done") -> Dictionary:
	return FROZEN.make_seed(_inputs(), {"priscilla": ["committed:board:complete"], "lavinia": [], "sylvia": [], "priscilla_lavinia": []},
		["committed:pair-window"], cause).value

func _plan(steps: Array) -> Dictionary:
	return {"steps": steps, "next_step_index": 0, "playback_receipts": {}}

func test_ending_seed_detaches_facts_and_has_no_future_step_identity() -> void:
	var inputs := _inputs()
	var built := FROZEN.make_seed(inputs, {"priscilla": [], "lavinia": [], "sylvia": [], "priscilla_lavinia": []}, [], "empty_done")
	assert_true(built.ok)
	inputs.priscilla.tone = "dark"
	inputs.special_variant = "residue"
	assert_eq(built.value.presentation_by_scope.priscilla.tone, "sweet")
	assert_eq(built.value.presentation_by_scope.special_variant, "full")
	assert_false(built.value.has("step_token"))
	assert_false(built.value.has("prerequisite_receipt_ids"))

func test_later_step_requires_actual_preceding_completion_and_keeps_frozen_variant() -> void:
	var plan := _plan([{"ending_id": "ending.priscilla.sweet", "role": "core"},
		{"ending_id": "ending.priscilla.observation", "role": "observer_coda", "presentation_variant": "residue"}])
	var seed := _seed()
	var first := FROZEN.build(plan, 0, seed, "run:ending:0")
	assert_true(first.ok, str(first))
	assert_eq(first.value.presentation.fields.prerequisite_receipt_ids, [])
	assert_eq(first.value.presentation.fields.evidence_receipt_ids, ["committed:board:complete"])
	assert_eq(FROZEN.build(plan, 1, seed, "run:ending:1").get("code"), &"ending_frozen_prerequisite_missing")
	plan.playback_receipts["step:0"] = {"value": {"outcome": "completed", "timeline_completion_receipt_id": "actual:playback:complete"}}
	var later := FROZEN.build(plan, 1, seed, "run:ending:1")
	assert_true(later.ok, str(later))
	assert_eq(later.value.presentation.fields.prerequisite_receipt_ids, ["actual:playback:complete"])
	assert_eq(later.value.presentation.fields.playback_mode, "residue")
	assert_eq(later.value.presentation.fields.ending_form, "observer_residue")

func test_special_forced_dark_retains_stored_tone_and_alone_pair_omit_solo_fields() -> void:
	var plan := _plan([{"ending_id": "ending.sylvia.special", "role": "special_prefix"}, {"ending_id": "ending.sylvia.dark", "role": "core"}])
	plan.playback_receipts["step:0"] = {"value": {"outcome": "completed", "timeline_completion_receipt_id": "actual:special:complete"}}
	var dark := FROZEN.build(plan, 1, _seed("hospital_faint"), "run:ending:1")
	assert_true(dark.ok, str(dark))
	assert_eq(dark.value.presentation.fields.ending_form, "special_forced_dark")
	assert_eq(dark.value.presentation.fields.stored_tone, "sweet")
	for step: Dictionary in [{"ending_id": "ending.alone", "role": "core"}, {"ending_id": "ending.priscilla_lavinia.sweet", "role": "pair_coda"}]:
		var built := FROZEN.build(_plan([step]), 0, _seed("hospital_faint"), "run:ending:0")
		assert_true(built.ok, str(built))
		for key: String in ["friend_id", "tier", "attitude"]: assert_false(built.value.presentation.fields.has(key))
		if step.ending_id == "ending.alone": assert_eq(built.value.presentation.fields.alone_cause, "hospital_faint")

func test_cache_rejects_missing_reached_step_and_changed_seed_or_context() -> void:
	var plan := _plan([{"ending_id": "ending.priscilla.sweet", "role": "core"}, {"ending_id": "ending.priscilla_lavinia.sweet", "role": "pair_coda"}])
	var cache := {"schema_version": 1, "seed": _seed(), "presentations": {}}
	var lifecycle := {"run_id": "run", "ending_plan": plan}
	cache.presentations["run:ending:0"] = FROZEN.build(plan, 0, cache.seed, "run:ending:0").value
	assert_true(FROZEN.validate_cache(cache, lifecycle).ok)
	cache.seed.presentation_by_scope.priscilla.attitude = "fixated"
	assert_false(FROZEN.validate_cache(cache, lifecycle).ok, "typed saved fields cannot drift from their admission seed")
	cache.seed = _seed()
	plan.next_step_index = 1
	plan.playback_receipts["step:0"] = {"value": {"outcome": "completed", "timeline_completion_receipt_id": "actual:first:complete"}}
	assert_true(FROZEN.validate_cache(cache, lifecycle).ok)
	cache.presentations.clear()
	assert_eq(FROZEN.validate_cache(cache, lifecycle).get("code"), &"ending_frozen_snapshot_required")

func _source() -> Dictionary:
	return {"ok": true, "value": {"source_kind": "schedule_done"}}

func test_game_owner_admits_ending_with_real_nullable_day_closures_and_retains_only_counted_pair_receipts() -> void:
	var state: Node = autofree(STATE.new())
	state.reset_game()
	var gate := GATE.new()
	assert_true(state.configure_mutation_gate(gate).ok)
	var profile: Node = autofree(preload("res://autoload/ProfileManager.gd").new())
	var storage := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"ending-nullable-closures", preload("res://tests/support/FakeFileOps.gd").new())
	assert_true(profile.initialize(storage).ok)
	assert_true(profile.configure_mutation_gate(gate).ok)
	var condition := preload("res://scripts/application/run/ConditionHospitalCoordinator.gd").new()
	condition._gate = gate
	var draw := preload("res://scripts/application/run/PairDeckDrawPort.gd").new()
	assert_true(draw.configure(state, profile, gate, condition, func() -> int: return 0).ok)
	for closed_day: int in range(1, 8):
		var closed := CONTACTS.prepare_resolve_day_end(state.contacts, closed_day, {}, "fixture:close:%d" % closed_day)
		assert_true(closed.ok, str(closed))
		if not closed.ok: return
		if closed_day == 2:
			# The first counted encounter selects and persists its form before the
			# closure is installed, just as the production day-resolution owner does.
			var selected := draw.prepare_schedule(true)
			assert_true(selected.ok, str(selected))
			if not selected.ok: return
			assert_eq(profile.get_pair_deck_draw("run-local").value, selected.value.draw_receipt)
		state.contacts = closed.value.candidate
	assert_null(state.contacts.transaction_receipts["fixture:close:1"].pl_window)
	assert_true(state.contacts.transaction_receipts["fixture:close:2"].pl_window.counts)
	assert_true(state.contacts.transaction_receipts["fixture:close:6"].pl_window.counts)
	var retained_receipts: Dictionary = state.contacts.transaction_receipts.duplicate(true)
	state._lifecycle_set_playing_day(7)
	assert_true(state.configure_frozen_ending_contexts().ok)
	var writer := Writer.new()
	writer.state = state
	assert_true(state.configure_ending_source_reader(_source).ok)
	assert_true(state.configure_ending_checkpoint_writer(writer.write).ok)
	var admitted: Dictionary = state.resume_terminal_ending()
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return
	var cache: Dictionary = state.route_context.ending_frozen_contexts_v1
	assert_eq(cache.seed.pair_count_receipt_ids, ["fixture:close:2", "fixture:close:6"])
	assert_true(cache.presentations.is_empty())
	assert_eq(state.contacts.transaction_receipts, retained_receipts)
	assert_eq(writer.snapshots.size(), 1)
	assert_eq(writer.snapshots[0].gameplay.route_context.ending_frozen_contexts_v1, cache)
	var command: Dictionary = state.request_next_ending_command().value
	assert_true(state.capture_ending_frozen_presentation(command.ending_id, command.playback_context).ok)

func test_game_owner_freezes_admission_then_checkpoints_exact_current_step_and_refuses_missing_seed() -> void:
	var state: Node = autofree(STATE.new())
	state.reset_game()
	state._lifecycle_set_playing_day(7)
	var gate: RefCounted = GATE.new()
	assert_true(state.configure_mutation_gate(gate).ok)
	assert_true(state.configure_frozen_ending_contexts().ok)
	var writer := Writer.new()
	writer.state = state
	assert_true(state.configure_ending_source_reader(_source).ok)
	assert_true(state.configure_ending_checkpoint_writer(writer.write).ok)
	assert_true(state.resume_terminal_ending().ok)
	assert_true(state.route_context.ending_frozen_contexts_v1.presentations.is_empty())
	var command: Dictionary = state.request_next_ending_command().value
	var before: Dictionary = state.capture_restore_state().value.backup
	writer.fail_next = true
	assert_eq(state.capture_ending_frozen_presentation(command.ending_id, command.playback_context).get("code"), &"fixture_write_failed")
	assert_eq(state.capture_restore_state().value.backup, before)
	assert_false(gate.is_active())
	var frozen: Dictionary = state.capture_ending_frozen_presentation(command.ending_id, command.playback_context)
	assert_true(frozen.ok, str(frozen))
	if not frozen.ok: return
	var durable: Dictionary = state.capture_restore_state().value.backup
	state.pending_hospital = true
	state.friend_attitude.sylvia = "fixated"
	assert_eq(state.capture_ending_frozen_presentation(command.ending_id, command.playback_context).value, frozen.value)
	assert_true(state.rollback_restore_silent(durable).ok)
	assert_eq(state.capture_ending_frozen_presentation(command.ending_id, command.playback_context).value, frozen.value)
	state.route_context.erase("ending_frozen_contexts_v1")
	var broken: Dictionary = state.capture_restore_state().value.backup
	assert_false(state.capture_ending_presentation_signature(command.ending_id, command.playback_context).ok)
	assert_false(state.capture_ending_frozen_presentation(command.ending_id, command.playback_context).ok)
	assert_eq(state.capture_restore_state().value.backup, broken)
