extends "res://tests/integration/scene_computer_child.gd"
## FINAL Bootstrap, native caption, real save and owners; no synthetic publication.
const COMPACT_READING := preload("res://scripts/narrative/SoloReadingSession.gd")
const CAPTION_CONTENT := preload("res://tests/support/SceneCaptionChallengeFixture.gd")

func _install_content_registration() -> Dictionary:
	return CAPTION_CONTENT.new()._install_registration()

func create_caption_challenge() -> void:
	if not _start_services(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var started: Dictionary = saves.start_scene_new_run("target_b", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	var host: Control = get_tree().current_scene
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.b.one")
	assert_false(game.capture_scene_challenge_command().get("ok", false))
	# No preliminary Continue: the existing Computer input admits this cue.
	await _click(_controls(host, "CheckComputer"))
	assert_true(host.is_computer_open())
	if not host.is_computer_open(): return
	assert_true(bridge.is_computer_caption_held(), "Computer owns the current caption")
	assert_true(bridge._runtime_adapter._dialogic.paused, "Computer suspends native playback")
	assert_false(get_tree().paused, "Computer leaves the scene tree running")
	# The active-playback completion query excludes paused sources. Inspect the
	# same held native cue to prove its reveal completed before Computer took it.
	var cue_event: DialogicTextEvent = bridge._runtime_adapter._current_skip_text(true)
	assert_not_null(cue_event, "The held cue remains available for read-only native inspection")
	if cue_event == null: return
	assert_eq(bridge._runtime_adapter._authored_line_id(cue_event), "line.scene.test.b.one",
		"Computer retains the original cue")
	assert_eq(cue_event.state, DialogicTextEvent.States.DONE, "Opening Computer completes the cue")
	var cue_caption: Node = _caption()
	assert_not_null(cue_caption, "Computer retains the native caption presentation")
	if cue_caption == null: return
	assert_false(cue_caption.caption_text.revealing, "The held cue has finished revealing")
	assert_eq(float(cue_caption.caption_text.visible_ratio), 1.0, "The entire held cue is revealed")
	assert_false(bridge.can_next_current_line(), "Computer custody blocks caption continuation")
	if not _ok(game.capture_scene_challenge_command()): return
	assert_true(game.capture_dating_challenge_state().value.is_empty())
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.b.one", "Closing alone retains the cue.")
	var held: Dictionary = bridge.capture_current_line_presentation_frontier()
	if not _ok(held): return
	var marker: Dictionary = bridge.capture_scene_pending_marker()
	if not _ok(marker): return
	assert_eq(marker.value.kind, "challenge.end")
	if not _ok(saves.save_latest_to_slot(1)): return
	var manual_sha := FileAccess.get_sha256("user://saves/slot_1.json")
	var cue_document: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(cue_document): return
	var cue_snapshot: Dictionary = cue_document.value.current_snapshot.snapshot
	for key: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_false(cue_snapshot.has(key), "player snapshot omits " + key)
	assert_false(cue_snapshot.scene.active_challenge.is_empty(), "available Challenge is current saved state")
	assert_eq(cue_snapshot.narrative_checkpoint.reading_session.schema_version, 7)
	assert_false(cue_snapshot.narrative_checkpoint.reading_session.has("ledger"))
	assert_false(cue_snapshot.narrative_checkpoint.reading_session.has("next_operation"))
	var next_results: Array = []
	var capture_next := func(_frontier: Dictionary, result: Dictionary): next_results.append(result.duplicate(true))
	bridge.next_request_finished.connect(capture_next)
	await _click(_caption().caption_text)
	var deadline := Time.get_ticks_msec() + 15000
	while bridge._runtime_adapter.current_line_id() != "line.scene.test.a.one" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	bridge.next_request_finished.disconnect(capture_next)
	if bridge._runtime_adapter.current_line_id() != "line.scene.test.a.one":
		var caption: Node = _caption()
		var diagnostic := {"next_results": next_results, "presented_matches": caption._presented_line == held,
			"next_admitted": caption._next_admitted(), "recovery": caption._reading_recovery}
		if next_results.is_empty(): diagnostic["explicit_next"] = await bridge.request_next(held)
		fail_test("Caption Continue refused: " + str(diagnostic))
		return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.one")
	assert_false(game.capture_scene_challenge_command().get("ok", false))
	assert_false((await bridge.request_next(held)).get("ok", false), "Old cue cannot advance the new outcome.")
	var outcomes: Dictionary = game.scene_challenge_outcomes.duplicate(true)
	assert_eq(outcomes.size(), 1)
	if outcomes.size() != 1: return
	assert_eq(outcomes.values()[0].outcome, "never_started")
	assert_true(game.capture_run_snapshot_input().scene.active_challenge.is_empty(), "Finish closes the opportunity")
	assert_true(profile.get_profile_snapshot().dating_attempts.is_empty())
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), manual_sha)
	for row: Dictionary in bridge._reading_session.ledger.snapshot().captions:
		assert_ne(row.beat.line_id, "line.scene.test.b.two", "No invented bridging caption.")

	if not await _wait_caption("line.scene.test.a.one"): return
	var visible: Dictionary = bridge.capture_current_line_presentation_frontier()
	if not _ok(visible) or not _ok(bridge.acknowledge_current_line_presentation(visible)): return
	if not _ok(saves.save_latest_to_slot(2)): return
	var closed_document: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_2.json"))
	if not _ok(closed_document): return
	var closed_snapshot: Dictionary = closed_document.value.current_snapshot.snapshot
	for key: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_false(closed_snapshot.has(key), "closed snapshot omits " + key)
	assert_eq(closed_snapshot.gameplay.scene_challenge_outcomes, outcomes)
	assert_true(closed_snapshot.scene.active_challenge.is_empty())
	assert_eq(closed_snapshot.narrative_checkpoint.reading_session.schema_version, 7)
	assert_false(closed_snapshot.narrative_checkpoint.reading_session.has("ledger"))
	var proof := {"creator_process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"cue_sha256": manual_sha, "closed_sha256": FileAccess.get_sha256("user://saves/slot_2.json"),
		"outcomes": outcomes, "profile": profile.get_profile_snapshot(),
		"cue_checkpoint": cue_snapshot.narrative_checkpoint, "cue_gameplay": cue_snapshot.gameplay,
		"closed_checkpoint": closed_snapshot.narrative_checkpoint, "closed_gameplay": closed_snapshot.gameplay}
	if not _write_json("user://caption-challenge-proof.json", proof): return
	_write_json("res://.godot/ci/caption-challenge-create-proof.json", proof)

func _wait_caption(line: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while Time.get_ticks_msec() < deadline:
		if bridge._runtime_adapter.current_line_id() == line and bridge._runtime_adapter.is_current_line_complete(): return true
		await get_tree().process_frame
	return _ok({"ok": false, "code": "TEST.caption_timeout", "line": line})

func load_caption_challenge() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://caption-challenge-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.creator_process_id)
	assert_eq(ProjectSettings.globalize_path("user://"), proof.user_dir)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.cue_sha256)
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.closed_sha256)
	if not _start_services(): return
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_caption("line.scene.test.b.one"): return
	assert_true(game.scene_challenge_outcomes.is_empty(), "Selected cue precedes Finish.")
	assert_eq(bridge.capture_reading_checkpoint(false).value.reading_session.boundary, "control")
	var cue_expected: Dictionary = COMPACT_READING.expand_player_checkpoint(proof.cue_checkpoint)
	if not _ok(cue_expected): return
	assert_true(bridge.capture_reading_checkpoint(false).value == cue_expected.value,
		"Load restores the exact held control and full preceding caption")
	assert_true(game.capture_run_snapshot_input().gameplay == proof.cue_gameplay,
		"Load restores cue economy and counters without replay")
	var pending: Dictionary = bridge.capture_scene_pending_marker()
	if not _ok(pending): return
	assert_eq(pending.value.kind, "challenge.end")
	await _click(_caption().caption_text)
	if not await _wait_caption("line.scene.test.a.one"): return
	assert_eq(game.scene_challenge_outcomes, proof.outcomes, "Finish selects the same outcome after Load")
	assert_true(game.capture_run_snapshot_input().scene.active_challenge.is_empty())
	assert_true(profile.get_profile_snapshot().dating_attempts.is_empty())
	# Select the creator's already-closed save. Restore its exact outcome and
	# destination without rerunning Finish or adopting the abandoned branch.
	var pause: Node = get_node("/root/SceneRouter")._production_pause
	if not _ok(await pause.request_pause()): return
	prepared = pause._backup_port.prepare_action("load", "slot:2")
	if not _ok(prepared): return
	if not _ok(await pause._backup_port.commit_action(prepared.value.token)): return
	var deadline := Time.get_ticks_msec() + 20000
	while ready_count < 2 and Time.get_ticks_msec() < deadline: await get_tree().process_frame
	assert_eq(ready_count, 2)
	if ready_count != 2 or not await _wait_caption("line.scene.test.a.one"): return
	assert_eq(game.scene_challenge_outcomes, proof.outcomes, "Closed-save Load restores the recorded outcome directly.")
	assert_true(game.capture_run_snapshot_input().command_receipts.is_empty(), "Load starts a fresh live command session")
	var closed_expected: Dictionary = COMPACT_READING.expand_player_checkpoint(proof.closed_checkpoint)
	if not _ok(closed_expected): return
	assert_true(bridge.capture_reading_checkpoint(false).value == closed_expected.value,
		"Load restores the closed branch caption directly")
	assert_true(game.capture_run_snapshot_input().gameplay == proof.closed_gameplay,
		"Closed-save Load restores exact economy and counters")
	assert_false(game.capture_scene_challenge_command().get("ok", false))
	assert_true(profile.get_profile_snapshot().dating_attempts.is_empty())
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.cue_sha256)
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.closed_sha256)
	proof["loader_process_id"] = OS.get_process_id()
	proof["ready_count"] = ready_count
	_write_json("res://.godot/ci/caption-challenge-load-proof.json", proof)
