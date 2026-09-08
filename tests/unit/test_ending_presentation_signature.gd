extends GutTest
const GAME := preload("res://autoload/GameState.gd")

func _game(steps: Array) -> Node:
	var game: Node = autofree(GAME.new())
	game.reset_game()
	game._lifecycle_set_playing_day(7)
	game.dating_route_state.priscilla = {"relationship_state": "love", "dark_points": 0}
	game.dating_route_state.sylvia = {"relationship_state": "ambiguous", "dark_points": 0}
	game.friend_attitude.priscilla = "fixated"
	game.inter_friend_route_state.priscilla_lavinia = {"frozen_form": "love_sweet"}
	game.route_context.provisional_ending_plan = {"eligibility_snapshot": {
		"presentation_by_scope": game._capture_ending_presentation_inputs()}}
	var entered: Dictionary = game._run_lifecycle.enter_ending(game._ordered_plan_from_provisional({"steps": steps}))
	assert_true(entered.ok, str(entered))
	return game

func _read(game: Node) -> Dictionary:
	var command: Dictionary = game.request_next_ending_command()
	assert_true(command.ok, str(command))
	return game.capture_ending_presentation_signature(command.value.ending_id, command.value.playback_context)

func test_signature_uses_frozen_role_facts_and_refuses_changed_command() -> void:
	var game := _game([{"ending_id": "ending.priscilla.sweet", "role": "core"}])
	var first := _read(game)
	assert_true(first.ok, str(first))
	if not first.ok: return
	assert_eq(first.value.entry_id, "ending.priscilla.sweet")
	assert_eq(first.value.fields.tier, "love")
	assert_eq(first.value.fields.attitude, "fixated")
	game.dating_route_state.priscilla.relationship_state = "friend"
	game.friend_attitude.priscilla = "distant"
	assert_eq(_read(game), first, "a frozen ending does not track later mutable state")
	var context: Dictionary = game.request_next_ending_command().value.playback_context
	context.transaction_id += ":stale"
	assert_false(game.capture_ending_presentation_signature("ending.priscilla.sweet", context).ok)
	first.value.fields.tier = "friend"
	assert_eq(_read(game).value.fields.tier, "love", "caller cannot mutate frozen inputs")

func test_alone_and_pair_signatures_have_only_their_real_role_fields() -> void:
	var game := _game([{"ending_id": "ending.alone", "role": "core"},
		{"ending_id": "ending.priscilla_lavinia.sweet", "role": "pair_coda", "pair_form": "love_sweet"}])
	var alone := _read(game)
	assert_true(alone.ok, str(alone))
	if not alone.ok: return
	assert_eq(alone.value, {"entry_id": "ending.alone.normal", "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": "alone_normal"}})
	assert_true(game._run_lifecycle.complete_ending_playback_stage("ending:step:0", &"PRIMARY_PENDING", {"value": {}}).ok)
	var pair := _read(game)
	assert_true(pair.ok, str(pair))
	if not pair.ok: return
	assert_eq(pair.value.fields, {"pair_form": "love_sweet", "ending_role": "pair_coda",
		"ending_form": "deck_sweet", "residue": false})
	assert_false(pair.value.fields.has("tier"))

func test_special_maps_exact_full_entry_then_forced_dark_without_rewriting_stored_tone() -> void:
	var game := _game([{"ending_id": "ending.sylvia.special", "role": "special_prefix"},
		{"ending_id": "ending.sylvia.dark", "role": "core"}])
	var special := _read(game)
	assert_true(special.ok, str(special))
	if not special.ok: return
	assert_eq(special.value.entry_id, "ending.sylvia.special.full")
	assert_eq(special.value.fields.ending_form, "special_full")
	assert_true(game._run_lifecycle.complete_ending_playback_stage("ending:step:0", &"PRIMARY_PENDING", {"value": {}}).ok)
	var dark := _read(game)
	assert_true(dark.ok, str(dark))
	if not dark.ok: return
	assert_eq(dark.value.fields.ending_form, "special_forced_dark")
	assert_eq(dark.value.fields.tone, "sweet", "presentation override preserves stored tone")
	assert_eq(game.dating_route_state.sylvia.dark_points, 0)

func test_compatible_plan_records_only_its_current_saved_presentation() -> void:
	var game := _game([{"ending_id": "ending.alone", "role": "core"}])
	game.route_context.provisional_ending_plan = {}
	var before: Dictionary = game.to_save_dict()
	var result := _read(game)
	assert_true(result.ok, str(result))
	assert_eq(game.to_save_dict(), before, "read-only compatibility capture does not fabricate run history")

func test_predicted_fourth_pair_form_cannot_start_observer_until_actual_sweet_completion_is_durable() -> void:
	var game := _game([{"ending_id": "ending.alone", "role": "core"},
		{"ending_id": "ending.priscilla_lavinia.sweet", "role": "pair_coda", "pair_form": "love_sweet"},
		{"ending_id": "ending.priscilla_lavinia.observer", "role": "observer_coda", "presentation_variant": "full"}])
	var profile: Node = autofree(preload("res://autoload/ProfileManager.gd").new())
	assert_true(profile.initialize(preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"pair-admission", preload("res://tests/support/FakeFileOps.gd").new())).ok)
	for form: String in ["ambiguous_sweet", "ambiguous_dark", "love_dark"]:
		assert_true(profile.record_pair_form_witness(form, "previous:" + form).ok)
	assert_true(game._run_lifecycle.complete_ending_playback_stage("ending:step:0", &"PRIMARY_PENDING", {"value": {
		"outcome": "completed", "timeline_completion_receipt_id": "actual-alone"}}).ok)
	assert_true(game._run_lifecycle.complete_ending_playback_stage("ending:step:1", &"PRIMARY_PENDING", {"value": {
		"outcome": "completed", "timeline_completion_receipt_id": "actual-pair-sweet"}}).ok)
	var snapshot: Dictionary = game._run_lifecycle.to_dict()
	assert_eq(game._validate_pair_observer_admission(snapshot, snapshot.ending_plan, profile).code,
		&"pair_observer_persistence_pending", "a planned or displayed fourth form cannot substitute for its durable receipt")
	var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	assert_true(profile.configure_mutation_gate(gate).ok)
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(profile.record_ending_completion("ending.priscilla_lavinia.sweet",
		"ending:%s:gallery:ending.priscilla_lavinia.sweet" % snapshot.run_id, "love_sweet").ok)
	assert_true(gate.release(&"causal_transaction", lease.value.token).ok)
	assert_true(game._validate_pair_observer_admission(snapshot, snapshot.ending_plan, profile).ok)
	var missing_physical: Dictionary = snapshot.ending_plan.duplicate(true)
	missing_physical.playback_receipts.erase("step:1")
	assert_eq(game._validate_pair_observer_admission(snapshot, missing_physical, profile).code,
		&"pair_observer_sweet_completion_pending")
	var other_run := snapshot.duplicate(true)
	other_run.run_id += ":other"
	assert_eq(game._validate_pair_observer_admission(other_run, snapshot.ending_plan, profile).code,
		&"pair_observer_sweet_completion_pending", "other-run discovery cannot stand in for this run's Sweet completion")
