extends "res://tests/integration/authored_week_child.gd"
## Genuine interrupted Day7 root from run39920770730, staged byte-for-byte by cloud.
## Restore its held control, preserve prior consequences, then save and finish the ending.
const RECOVERY_TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")
const RECOVERY_SEED := "res://.godot/ci/authored-recovery-seed.json"
const RECOVERY_RESULT := "res://.godot/ci/authored-late-recovery.json"
const RECOVERY_LINE := "line.Day7.untouched.impulse.004"
var _recovery_proof: Dictionary = {}

func _recovery_begin(label: String) -> int:
	_recovery_proof["pending_phase"] = label
	_write_json(RECOVERY_RESULT, _recovery_proof)
	print("AUTHORED_LATE_RECOVERY_BEGIN " + label + " ticks_us=" + str(Time.get_ticks_usec()))
	assert_true(RECOVERY_TIMING.begin_scope("authored_late_recovery_" + label, "PLAYING", "", 66), "profiling enabled")
	return Time.get_ticks_usec()

func _recovery_end(label: String, started: int, succeeded: bool) -> void:
	var elapsed := Time.get_ticks_usec() - started
	RECOVERY_TIMING.end_scope(succeeded)
	var row := {"phase": label, "elapsed_us": elapsed, "ok": succeeded}
	_recovery_proof.phases.append(row)
	_recovery_proof["pending_phase"] = ""
	_recovery_proof["observed_lines"] = observed_lines.duplicate()
	_recovery_proof["timings"] = _timings.duplicate(true)
	print("AUTHORED_LATE_RECOVERY_TIMING " + JSON.stringify(row))
	_write_json(RECOVERY_RESULT, _recovery_proof)

func _recovery_hashes() -> Dictionary:
	var result := {}
	for path: String in _recovery_proof.source_hashes:
		result[path] = FileAccess.get_sha256("user://" + path)
	return result

func _unchanged_receipts(source: Dictionary, current: Dictionary) -> void:
	for transaction_id: String in source:
		assert_eq(current.get(transaction_id), source[transaction_id], "existing command remains unchanged: " + transaction_id)

func _wait_recovery_control() -> bool:
	# A held control reuses an already witnessed predecessor. Ordinary-line
	# acknowledgement intentionally refuses this distinct logical boundary.
	var deadline := Time.get_ticks_msec() + 30000
	while Time.get_ticks_msec() < deadline:
		var caption: Node = _caption()
		if is_instance_valid(caption) and caption.caption_text.is_visible_in_tree() \
				and caption._presented_line.get("value", {}).get("kind") == "scene_optional_control" \
				and caption._next_admitted() and bridge._runtime_adapter.current_line_id() == RECOVERY_LINE \
				and bridge._runtime_adapter.is_current_line_complete() and not caption.caption_text.revealing:
			await RenderingServer.frame_post_draw
			assert_eq(float(caption.caption_text.visible_ratio), 1.0)
			assert_eq(caption.caption_text.get_parsed_text(), _texts[RECOVERY_LINE])
			observed_lines.append(RECOVERY_LINE)
			return true
		await get_tree().process_frame
	await _screenshot("authored-late-recovery-control-timeout")
	fail_test("Restored held control was not rendered and available for real Next")
	return false

func test_recover_interrupted_authored_day7_to_ending() -> void:
	_phase = "late-recovery"
	_ending_phase_timing = true
	var seeded: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(RECOVERY_SEED))
	if not _ok(seeded): return
	assert_eq(int(seeded.value.source_run), 39920770730)
	assert_ne(OS.get_process_id(), int(seeded.value.process_id), "fresh process after byte-for-byte staging")
	assert_eq(ProjectSettings.globalize_path("user://"), seeded.value.user_dir)
	var source_hashes := {}
	for path: String in seeded.value.files:
		if path.ends_with(".json") or path.ends_with(".json.bak"):
			source_hashes[path] = seeded.value.files[path]
	assert_eq(source_hashes.size(), 12, "whole durable root includes authority, Profile, publications, saves, backups and prior Day4 proof")
	_recovery_proof = {"source_run": 39920770730, "seed_process_id": seeded.value.process_id,
		"process_id": OS.get_process_id(), "user_dir": seeded.value.user_dir,
		"source_hashes": source_hashes, "phases": [], "complete": false}
	_write_json(RECOVERY_RESULT, _recovery_proof)
	for path: String in seeded.value.files:
		assert_eq(FileAccess.get_sha256("user://" + path), seeded.value.files[path], "staged source byte identity: " + path)
	assert_eq(_recovery_hashes(), source_hashes, "fresh process receives the genuine complete durable root")
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _ok(parsed): return
	var source: Dictionary = parsed.value.current_snapshot.snapshot
	var checkpoint: Dictionary = source.narrative_checkpoint
	var reading: Dictionary = checkpoint.reading_session
	assert_eq(source.checkpoint_sequence, 66)
	assert_eq(source.command_receipts.size(), 58)
	assert_eq(checkpoint.entry_id, "Day7.untouched.impulse")
	assert_eq(reading.boundary, "control")
	assert_eq(reading.program_index, 4)
	assert_eq(reading.ledger.captions.size(), 806)
	assert_eq(reading.next_operation.phase, "destination")
	assert_eq(reading.next_operation.plan.source_reading.frontier.line_id, RECOVERY_LINE)
	var profile_file: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://profile.json"))
	if not _ok(profile_file): return
	var profile_before: Dictionary = profile_file.value
	var started := _recovery_begin("boot")
	var succeeded := _setup_authored()
	_recovery_end("boot", started, succeeded)
	if not succeeded: return
	assert_eq(profile.get_profile_snapshot(), profile_before, "startup preserves existing consequences")
	assert_eq(_recovery_hashes(), source_hashes, "completed creation journal requires no replacement history")
	assert_eq(AUTHORED_MANIFEST.scene_registration_fingerprint(), reading.registration_sha256)

	started = _recovery_begin("title_backup")
	get_node("/root/SceneRouter").goto_menu()
	succeeded = await _wait_route(MENU)
	var menu: Node = get_tree().current_scene
	if succeeded: succeeded = await _press_authored(menu.get_node("%LogInButton"))
	_recovery_end("title_backup", started, succeeded)
	if not succeeded: return
	var app: Control = menu._backup_app_instance
	assert_not_null(app, "real Title Backup is mounted")
	if not is_instance_valid(app): return
	started = _recovery_begin("select_autosave")
	succeeded = await _press_authored(app.drawer_buttons.get("autosave"))
	_recovery_end("select_autosave", started, succeeded)
	if not succeeded: return
	saves.live_session_ready.connect(func() -> void: _ready_observation = _native_observation())
	started = _recovery_begin("load")
	succeeded = await _press_authored(app.action_buttons.get("load"))
	if succeeded and is_instance_valid(app) and is_instance_valid(app.confirmation):
		succeeded = await _press_authored(app.confirmation.confirm_button)
	if succeeded: succeeded = await _await_ready()
	if succeeded: succeeded = await _wait_recovery_control()
	_recovery_end("load", started, succeeded)
	if not succeeded: return
	assert_eq(ready_count, 1)
	assert_eq(_ready_observation.line_id, RECOVERY_LINE)
	assert_true(_ready_observation.visible)
	assert_false(_ready_observation.revealing)
	assert_true(_ready_observation.event_done)
	assert_eq(float(_ready_observation.visible_ratio), 1.0)
	assert_eq(_ready_observation.ledger, reading.ledger, "Load allocates no publication")
	assert_eq(bridge.capture_reading_checkpoint(false).value, checkpoint, "logical control and pending traversal survive exactly")
	assert_eq(bridge._runtime_adapter.capture_scene_control_position(bridge._reading_session).value, reading)
	var restored: Dictionary = game.capture_run_snapshot_input()
	assert_eq(restored.lifecycle.run_id, source.lifecycle.run_id)
	assert_ne(restored.lifecycle.branch_id, source.lifecycle.branch_id, "selected Load creates its own branch")
	for key: String in ["gameplay", "scene", "command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_eq(restored[key], source[key], "Load preserves " + key)
	assert_eq(profile.get_profile_snapshot(), profile_before, "Load repeats no Profile consequences")
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), source_hashes["saves/autosave.json"], "Load preserves selected source bytes")
	await _screenshot("authored-late-recovery-held-control")
	_write_json("res://.godot/ci/authored-late-recovery-restored.json", {"source_snapshot": source,
		"restored_snapshot": restored, "ready_native": _ready_observation,
		"profile": profile.get_profile_snapshot(), "hashes": _recovery_hashes()})
	started = _recovery_begin("control_departure")
	succeeded = await _walk_authored(806, 806)
	_recovery_end("control_departure", started, succeeded)
	if not succeeded: return
	var continued: Dictionary = game.capture_run_snapshot_input()
	_unchanged_receipts(source.command_receipts, continued.command_receipts)
	assert_eq(continued.command_receipts.size(), source.command_receipts.size() + 2,
		"one Challenge End and one destination admission; existing playable receipt is reused")
	var new_events: Array[String] = []
	var new_admissions: Array[String] = []
	for transaction_id: String in continued.command_receipts:
		if source.command_receipts.has(transaction_id): continue
		var receipt: Dictionary = continued.command_receipts[transaction_id]
		if receipt.kind == "scene_event": new_events.append(receipt.scene_event.semantic.event_id)
		if receipt.kind == "scene_admission": new_admissions.append(receipt.scene_admission.result.entry_id)
	assert_eq(new_events, ["Day7.untouched.impulse.end"])
	assert_eq(new_admissions, ["Day7.A"])
	for key: String in ["applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_eq(continued[key], source[key], "continuation repeats no existing effect")
	var current_profile: Dictionary = profile.get_profile_snapshot()
	for key: String in ["dating_attempts", "gallery_transaction_receipts", "gallery_unlocks", "pair_deck_draws", "pair_form_witness_receipts"]:
		assert_eq(current_profile[key], profile_before[key], "continuation repeats no " + key)
	var continued_reading: Dictionary = bridge.capture_reading_checkpoint(false).value.reading_session
	assert_eq(continued_reading.ledger.captions.size(), 807)
	assert_eq(continued_reading.ledger.captions.slice(0, 806), reading.ledger.captions, "earlier caption publications are preserved")
	assert_eq(observed_lines, [RECOVERY_LINE, "line.Day7.A.001"])
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "unstarted challenge creates no board")
	await _screenshot("authored-late-recovery-continued")
	_write_json("res://.godot/ci/authored-late-recovery-continued.json", {"snapshot": continued,
		"reading": continued_reading, "profile": current_profile, "hashes": _recovery_hashes()})
	# Continue only the unverified suffix; the earlier genuine history stays intact.
	for index: int in range(807, ENDING_INDEX + 1):
		var label := "caption_%d" % index
		started = _recovery_begin(label)
		succeeded = await _walk_authored(index, index)
		_recovery_end(label, started, succeeded)
		if not succeeded: return
	assert_true(get_tree().current_scene is EndingScene)
	started = _recovery_begin("save_ending")
	var ending_proof: Dictionary = await _save_authored(2, "ending")
	_recovery_end("save_ending", started, not ending_proof.is_empty())
	if ending_proof.is_empty(): return
	for index: int in range(ENDING_INDEX + 1, _expected.size()):
		var label := "ending_caption_%d" % index
		started = _recovery_begin(label)
		succeeded = await _walk_authored(index, index)
		_recovery_end(label, started, succeeded)
		if not succeeded: return
	var expected_lines: Array = [RECOVERY_LINE]
	for index: int in range(806, _expected.size()): expected_lines.append(_expected[index].line_id)
	assert_eq(observed_lines, expected_lines, "complete exact remaining authored suffix")
	assert_eq(observed_lines.size(), 31)
	started = _recovery_begin("complete_ending")
	var finished: Dictionary = await _complete_authored()
	_recovery_end("complete_ending", started, not finished.is_empty())
	if finished.is_empty(): return
	var completed_profile: Dictionary = profile.get_profile_snapshot()
	var gallery_id := "ending:%s:gallery:ending.alone" % str(source.lifecycle.run_id)
	assert_eq(completed_profile.gallery_transaction_receipts.get(gallery_id), {"ending_id": "ending.alone", "unlocked": true})
	assert_eq(completed_profile.gallery_transaction_receipts.size(), profile_before.gallery_transaction_receipts.size() + 1)
	for receipt_id: String in profile_before.gallery_transaction_receipts:
		assert_eq(completed_profile.gallery_transaction_receipts.get(receipt_id), profile_before.gallery_transaction_receipts[receipt_id])
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), source_hashes["saves/slot_1.json"], "prior Day4 Save remains unchanged")
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), ending_proof.slot_sha256)
	_recovery_proof["observed_lines"] = observed_lines
	_recovery_proof["timings"] = _timings
	_recovery_proof["completed_lifecycle"] = finished
	_recovery_proof["completed_profile"] = completed_profile
	_recovery_proof["window_size"] = [get_window().size.x, get_window().size.y]
	_recovery_proof["viewport_size"] = [get_viewport().get_visible_rect().size.x, get_viewport().get_visible_rect().size.y]
	_recovery_proof["complete"] = true
	_write_json(RECOVERY_RESULT, _recovery_proof)
