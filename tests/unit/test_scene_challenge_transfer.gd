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

class HeldSelectedState extends FIXTURE.State:
	var held := false
	func scene_challenge_is_suspended(record: Dictionary, _require_pause: bool = false) -> bool:
		return held and record == route_context.get("active_dating_challenge", {})

class HeldMarker extends RefCounted:
	var paused := false
	var marker: Dictionary
	func get_state() -> Dictionary:
		return {"ok": true, "value": {"state": &"Suspended" if paused else &"Active"}}
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
	authority.bundle = f.authority.bundle.duplicate(true)
	authority.bundle.challenges[0].challenge_id = "TEST.replacement"
	for marker: Dictionary in authority.bundle.scene_programme.entries[0].markers:
		marker.payload.challenge_id = "TEST.replacement"
	f.authority = authority
	var configured: Dictionary = f.recreate_owner()
	assert_true(configured.ok, str(configured))
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
	var panel_before: Dictionary = f.owner.pull_scene_panel(f.token).value
	var reference: Dictionary = f.state.route_context.dating_active_attempt_ref.duplicate(true)
	var authority := _transfer()
	assert_true(f.begin().ok)
	var panel_after: Dictionary = f.owner.pull_scene_panel(f.token)
	assert_true(panel_after.ok, str(panel_after))
	if not panel_after.ok: return
	assert_eq(panel_after.value, panel_before, "rendered host, cells, flags and dimensions come from frozen A")
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
	var panel_before: Dictionary = f.owner.pull_scene_panel(f.token).value
	assert_eq(record.phase, "terminal")
	var source_reference: Dictionary = f.state.route_context.dating_active_attempt_ref.duplicate(true)
	f.state.lifecycle.branch_id = "TEST.terminal.transfer.branch"
	_transfer()
	assert_true(f.begin().ok)
	assert_eq(f.state.route_context.dating_active_attempt_ref, source_reference, "opening only plans the selected continuation")
	var panel_after: Dictionary = f.owner.pull_scene_panel(f.token)
	assert_true(panel_after.ok, str(panel_after))
	if not panel_after.ok: return
	assert_eq(panel_after.value, panel_before, "terminal panel still renders the frozen board without old authored profile")
	var departure: Dictionary = f.owner.prepare_scene_departure(f.command)
	assert_true(departure.ok, str(departure))
	assert_eq(f.state.route_context.dating_active_attempt_ref.branch_id, "TEST.terminal.transfer.branch")
	assert_eq(f.record(), record, "automatic departure commits the selected prefix without revealing again")
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
	var future: Dictionary = f.profile.get_profile_snapshot()
	selected.lifecycle.branch_id = "TEST.selected.transfer.branch"
	assert_true(f.state.rollback_restore_silent(selected).ok)
	_transfer()
	assert_true(f.begin().ok)
	assert_eq(f.record(), selected_record, "transfer uses selected flags and unrevealed board")
	assert_eq(f.profile.get_profile_snapshot(), future, "Profile stays unchanged")
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
		var snapshot := {"lifecycle": {"state": "COMPLETED", "completed_registration_sha256": "a".repeat(64)},
			"scene": {"return_to": null, "registration_sha256": "b".repeat(64)},
			"narrative_checkpoint": {"entry_id": "TEST.current", "reading_session":
				{"boundary": "line", "frontier": {"line_id": restored_line}}}}
		var before := snapshot.duplicate(true)
		assert_true(game._validate_scene_passage_completion(snapshot, {}).ok)
		assert_eq(snapshot, before, "completion validation cannot reactivate or award effects")
		assert_eq(snapshot.lifecycle.state, "COMPLETED")
		snapshot.lifecycle.completed_registration_sha256 = snapshot.scene.registration_sha256
		assert_false(game._validate_scene_passage_completion(snapshot, {}).ok, "current completion must still prove its final caption")
		snapshot.lifecycle.erase("completed_registration_sha256")
		assert_false(game._validate_scene_passage_completion(snapshot, {}).ok, "no provenance cannot bypass current final caption")
	assert_false(game._validate_scene_passage_completion(
		{"lifecycle": {"state": "COMPLETED"}, "scene": {"return_to": {"entry_id": "TEST.parent"}}}, {}).ok)

func test_suspended_save_requires_exact_unconsumed_record_and_no_current_native_custody() -> void:
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var game: Node = autofree(GAME.new())
	var record: Dictionary = f.record()
	game.route_context = f.state.route_context.duplicate(true)
	var bridge := HeldMarker.new()
	game._scene_event_bridge = bridge
	assert_true(game.scene_challenge_is_suspended(record))
	assert_false(game.scene_challenge_is_suspended(record, true), "unavailable native control alone is not pause custody")
	bridge.paused = true
	assert_true(game.scene_challenge_is_suspended(record, true))
	assert_false(game.scene_challenge_is_suspended({}))
	var changed := record.duplicate(true)
	changed.command_sha256 = "f".repeat(64)
	assert_false(game.scene_challenge_is_suspended(changed))
	game.scene_challenge_outcomes = {"saved.B": {"challenge_id": "TEST.replacement",
		"outcome": "unfinished", "physical_slot": LEDGER.semantic_slot(record.context)}}
	assert_false(game.scene_challenge_is_suspended(record), "a closed board must use validated closure custody")

func test_paused_save_of_opened_selected_prefix_keeps_source_reference_without_forking_profile() -> void:
	var state := HeldSelectedState.new()
	f.state = state
	f.authority.state = state
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	assert_true(f.action("start").ok)
	var selected: Dictionary = state.capture_restore_state().value.backup
	assert_true(f.action("reveal", 323).ok)
	selected.lifecycle.branch_id = "TEST.paused.selected"
	assert_true(state.rollback_restore_silent(selected).ok)
	assert_true(f.recreate_owner().ok)
	assert_true(f.begin().ok)
	var run_before: Dictionary = state.capture_restore_state()
	var profile_before: Dictionary = f.profile.get_profile_snapshot()
	state.held = true
	f.authority.presentation_held = true
	var saved: Dictionary = f.owner.flush_pending_attempt()
	assert_true(saved.ok, str(saved))
	if saved.ok: assert_false(saved.value.committed)
	assert_eq(state.capture_restore_state(), run_before)
	assert_eq(f.profile.get_profile_snapshot(), profile_before)
	assert_false(f.action("reveal", 36).ok, "paused save authority grants no board input")
	state.held = false
	f.authority.presentation_held = false
	assert_true(f.owner.flush_pending_attempt().ok, "unchanged selected Run needs no new checkpoint")
	assert_eq(state.route_context, run_before.value.backup.route_context)
