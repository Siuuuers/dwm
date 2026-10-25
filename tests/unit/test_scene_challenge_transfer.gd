extends GutTest
## Frozen physical A and current story B have independent identities.
const FIXTURE := preload("res://tests/support/SceneChallengeFixture.gd")
const GAME := preload("res://autoload/GameState.gd")
const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")

class TransferAuthority extends FIXTURE.Authority:
	var binding := {"challenge_id": "TEST.replacement", "scene_occurrence": "TEST.destination",
		"playable_command_id": "TEST.destination.playable"}
	func capture_scene_challenge_binding(candidate: Dictionary) -> Dictionary:
		if not validate_scene_challenge_command(candidate, bundle).ok: return {"ok": false}
		return {"ok": true, "value": binding.duplicate(true)}

class HeldMarker extends RefCounted:
	var marker: Dictionary
	func capture_scene_pending_marker() -> Dictionary:
		return {"ok": true, "value": marker.duplicate(true)}
	func capture_scene_challenge_control() -> Dictionary:
		return {"ok": false, "code": &"TEST.not_at_control"}

var f: RefCounted
func before_each() -> void:
	f = FIXTURE.new()
	assert_true(f.setup().ok)
func after_each() -> void:
	f.dispose()

func _transfer() -> TransferAuthority:
	var authority := TransferAuthority.new()
	authority.state = f.state
	authority.profile = f.profile
	authority.command = f.command.duplicate(true)
	authority.bundle = JSON.parse_string(JSON.stringify(f.authority.bundle).replace("TEST.challenge", "TEST.replacement"))
	f.authority = authority
	assert_true(f.recreate_owner().ok)
	return authority

func test_current_binding_retains_exact_physical_command_and_stays_suspended_without_native_control() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("flag", 0).ok)
	var record: Dictionary = f.record()
	var game: Node = autofree(GAME.new())
	game.route_context = f.state.route_context.duplicate(true)
	game._scene_snapshot_references = {"active_occurrence_id": "TEST.destination", "entry_id": "TEST.new.entry",
		"registration_sha256": "f".repeat(64),
		"active_challenge": {"challenge_id": "TEST.replacement", "playable_command_id": "TEST.destination.playable"}}
	var physical: Dictionary = game._current_scene_challenge_command(game._scene_snapshot_references)
	assert_true(physical.ok)
	assert_eq(physical.value, f.command, "current story does not rename frozen physical command")
	assert_eq(game.capture_scene_challenge_binding(physical.value).value,
		{"challenge_id": "TEST.replacement", "scene_occurrence": "TEST.destination", "playable_command_id": "TEST.destination.playable"})
	var bridge := HeldMarker.new()
	game._scene_event_bridge = bridge
	assert_false(game.capture_scene_challenge_command().ok, "retained board alone cannot grant interactivity")
	assert_eq(game.route_context.active_dating_challenge, record)

func test_ready_board_transfer_retains_flags_spec_reference_and_closes_for_new_story_binding() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("flag", 0).ok)
	var record: Dictionary = f.record()
	var reference: Dictionary = f.state.route_context.dating_active_attempt_ref.duplicate(true)
	var authority := _transfer()
	assert_true(f.begin().ok)
	assert_eq(f.record(), record)
	assert_eq(f.state.route_context.dating_active_attempt_ref, reference)
	authority.reject_closure = true
	assert_false(f.owner.close_scene_challenge(f.token).ok, "failed story binding write remains retryable")
	assert_eq(f.record(), record)
	authority.reject_closure = false
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	if not closed.ok: return
	assert_eq(closed.value.outcome, "unfinished")
	assert_eq(closed.value.challenge_occurrence, CONTRACT._sha(["TEST.destination", "TEST.replacement"]))
	assert_eq(closed.value.playable_command_id, "TEST.destination.playable")
	assert_eq(closed.value.attempt_proof.slot_id, LEDGER.semantic_slot(record.context))
	assert_eq(f.record(), record, "closure does not rewrite frozen physics")
	assert_eq(f.state.effects, 0)

func test_terminal_board_transfer_keeps_terminal_state_and_closes_new_story_without_reveal() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("reveal", 323).ok)
	var record: Dictionary = f.record()
	assert_eq(record.phase, "terminal")
	_transfer()
	assert_true(f.begin().ok)
	assert_eq(f.record(), record)
	assert_eq(f.owner.pull_physical(f.token).value.actions, [])
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	if not closed.ok: return
	assert_eq(closed.value.outcome, "won")
	assert_eq(closed.value.challenge_occurrence, CONTRACT._sha(["TEST.destination", "TEST.replacement"]))
	assert_eq(f.record(), record)
	assert_eq(f.state.effects, 0)

func test_selected_old_prefix_transfer_never_imports_newer_profile_moves() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	assert_true(f.action("flag", 0).ok)
	var selected: Dictionary = f.state.capture_restore_state().value.backup
	var selected_record: Dictionary = f.record()
	assert_true(f.action("unflag", 0).ok)
	assert_true(f.action("reveal", 323).ok)
	var future: Dictionary = f.attempt().value
	selected.lifecycle.branch_id = "TEST.selected.transfer.branch"
	assert_true(f.state.rollback_restore_silent(selected).ok)
	_transfer()
	assert_true(f.begin().ok)
	assert_eq(f.record(), selected_record, "transfer uses selected flags and unrevealed board")
	assert_eq(f.attempt(future.branch_id).value, future, "source Profile prefix stays intact")
	var closed: Dictionary = f.owner.close_scene_challenge(f.token)
	assert_true(closed.ok, str(closed))
	if closed.ok: assert_eq(closed.value.outcome, "unfinished")
	assert_eq(f.record(), selected_record)

func test_consumed_physical_slot_prevents_second_transfer_even_after_story_id_changes() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var record: Dictionary = f.record()
	var slot := LEDGER.semantic_slot(record.context)
	assert_false(GAME.scene_physical_consumed(record, {}))
	assert_true(GAME.scene_physical_consumed(record,
		{"saved.B": {"challenge_id": "TEST.replacement", "outcome": "unfinished", "physical_slot": slot}}))
	assert_true(GAME.scene_physical_consumed(record,
		{"legacy.A": {"challenge_id": record.context.challenge_id, "outcome": "unfinished"}}), "legacy resolved unfinished never reopens")
	assert_false(GAME.scene_physical_consumed(record,
		{"saved.B": {"challenge_id": "TEST.replacement", "outcome": "never_started", "physical_slot": ""}}))

func test_saved_choice_projection_selects_stored_route_without_mutating_progress() -> void:
	var game: Node = autofree(GAME.new())
	var bridge := HeldMarker.new()
	bridge.marker = {"kind": "thought.options", "payload": {"opportunity_id": "TEST.choice",
		"pass_target_id": "TEST.pass", "options": [{"choice_id": "kept", "target_id": "TEST.kept"}]}}
	game._scene_event_bridge = bridge
	game.scene_choices = {"TEST.choice": "kept"}
	var selected: Dictionary = game.capture_resolved_scene_marker()
	assert_true(selected.ok, str(selected))
	if selected.ok: assert_eq(selected.value.target_id, "TEST.kept")
	assert_eq(game.scene_choices, {"TEST.choice": "kept"})

func test_resolved_story_challenge_cannot_reopen_an_unfinished_board() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var game: Node = autofree(GAME.new())
	game.route_context = f.state.route_context.duplicate(true)
	game.scene_challenge_outcomes = {"saved.A": {"challenge_id": "TEST.challenge",
		"outcome": "unfinished", "physical_slot": LEDGER.semantic_slot(f.record().context)}}
	var result: Dictionary = game._current_scene_challenge_command({"active_challenge":
		{"challenge_id": "TEST.challenge", "playable_command_id": "TEST.playable"}})
	assert_false(result.ok)
	assert_eq(result.code, &"scene_challenge_already_closed")

func test_completed_lifecycle_survives_removed_or_appended_final_caption_without_reactivation() -> void:
	var game: Node = autofree(GAME.new())
	for restored_line: String in ["TEST.earlier.day.start", "TEST.former.final"]:
		var snapshot := {"lifecycle": {"state": "COMPLETED"}, "scene": {"return_to": null},
			"narrative_checkpoint": {"entry_id": "TEST.current", "reading_session":
				{"boundary": "line", "frontier": {"line_id": restored_line}}}}
		var before := snapshot.duplicate(true)
		assert_true(game._validate_scene_passage_completion(snapshot, {}).ok)
		assert_eq(snapshot, before, "completion validation cannot reactivate or award effects")
		assert_eq(snapshot.lifecycle.state, "COMPLETED")
	assert_false(game._validate_scene_passage_completion(
		{"lifecycle": {"state": "COMPLETED"}, "scene": {"return_to": {"entry_id": "TEST.parent"}}}, {}).ok)
