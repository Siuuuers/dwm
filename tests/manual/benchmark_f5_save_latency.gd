extends "res://tests/support/ScenePauseLoadTestBase.gd"
## Rendered Save-sheet F5, one sample per fresh process. Repeated means fourth Save
## at the same real reading position, not longer reading history. No faults are armed.
var _desktop_board := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()
var _capture_calls := 0
var _capture_us := 0
var _measuring := false
var _last_frame_us := 0
var _max_frame_gap_us := 0
var _saved_draw_us := 0
var _edge: Label

func _capture_desktop_inputs() -> Dictionary:
	return {"board": _desktop_board.capture(), "consequence": fixture.game._desktop_snapshot.consequence.duplicate(true)}

func _capture_scene_inputs() -> Dictionary:
	var started := Time.get_ticks_usec()
	var checkpoint: Dictionary = fixture.bridge.capture_reading_checkpoint(false)
	var result: Dictionary = checkpoint
	if checkpoint.get("ok", false):
		result = {"ok": true, "value": {"snapshot_input": fixture.game.capture_run_snapshot_input(),
			"route_id": "scene", "active_app_id": null, "audio_context": fixture.audio_context(),
			"content_version": 1, "dialogic_checkpoint": checkpoint.value}}
	if _measuring:
		_capture_calls += 1
		_capture_us += Time.get_ticks_usec() - started
	return result

func _observe_frame() -> void:
	var now := Time.get_ticks_usec()
	if _measuring: _max_frame_gap_us = maxi(_max_frame_gap_us, now - _last_frame_us)
	_last_frame_us = now

func _observe_saved_draw() -> void:
	if _measuring and _saved_draw_us == 0 and _edge.key == &"saved" and _edge.is_visible_in_tree():
		_saved_draw_us = Time.get_ticks_usec()

func _f5() -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_F5
		key.physical_keycode = KEY_F5
		key.pressed = pressed
		get_tree().root.push_input(key, true)

func test_rendered_f5_latency() -> void:
	if not fixture_ready: return
	_watchdog.start(90.0)
	var scenario := OS.get_environment("DWM_F5_CASE")
	assert_true(scenario in ["fresh", "repeated"], "explicit benchmark scenario")
	if scenario not in ["fresh", "repeated"]: return
	var diagnostic := OS.get_environment("DWM_F5_HEADLESS_DIAGNOSTIC") == "1"
	assert_true(diagnostic or DisplayServer.get_name() != "headless", "canonical measurement requires a renderer")
	if not diagnostic and DisplayServer.get_name() == "headless": return
	OS.set_environment("DWM_SAVE_LOAD_PROFILE", "")
	fixture.participants.desktop_board = preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd").new(_desktop_board, fixture.issuer)
	if not _ok(fixture.manager.configure_scene_restore_participants(fixture.participants)): return
	_test_stage = "activate_source"
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending")
	if started.get("code") != &"scene_activation_pending": return
	if not _ok(await fixture.await_activation()): return
	if not _ok(fixture.game.configure_desktop_snapshot_provider(_capture_desktop_inputs)): return
	fixture.pause._services["backup_capture"] = Callable(self, "_capture_scene_inputs")
	if not _ok(fixture.manager.configure_backup_capture_provider(
		Callable(fixture.pause, "capture_backup_checkpoint_inputs"), Callable(),
		Callable(fixture.pause, "can_save_backup"))): return
	if not _ok(await fixture.pause.open_scene_backup("save")): return
	var quick: Node = fixture.pause._quick_commands
	_edge = quick.edge
	var prior_saves := 3 if scenario == "repeated" else 0
	for index: int in prior_saves:
		_f5()
		if not _ok(quick.last_result): return
		# Let each genuine completion expire and its deferred slot refresh settle.
		await get_tree().create_timer(2.2, true).timeout
	for frame: int in 4: await get_tree().process_frame
	var reading_before: Dictionary = fixture.bridge.capture_reading_checkpoint(false)
	if not _ok(reading_before): return
	var projected: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").project_player_checkpoint(reading_before.value)
	if not _ok(projected): return
	var source: Dictionary = fixture.game.capture_run_snapshot_input().duplicate(true)
	var history: Dictionary = fixture.bridge.get_reading_history()
	if not _ok(history): return
	get_tree().process_frame.connect(_observe_frame)
	_edge.draw.connect(_observe_saved_draw)
	await get_tree().process_frame
	_test_stage = "measured_f5"
	var profile_enabled := OS.get_environment("DWM_F5_PROFILE") != "0"
	OS.set_environment("DWM_SAVE_LOAD_PROFILE", "1" if profile_enabled else "")
	_measuring = true
	var input_us := Time.get_ticks_usec()
	_f5()
	var dispatched_us := Time.get_ticks_usec()
	var presented_us := 0
	if not diagnostic:
		while _saved_draw_us == 0: await RenderingServer.frame_post_draw
		presented_us = Time.get_ticks_usec()
	# Include the first following process-frame boundary to witness the full stall.
	await get_tree().process_frame
	_measuring = false
	OS.set_environment("DWM_SAVE_LOAD_PROFILE", "")
	get_tree().process_frame.disconnect(_observe_frame)
	_edge.draw.disconnect(_observe_saved_draw)
	if not _ok(quick.last_result): return
	assert_gt(_capture_calls, 0)
	assert_eq(_edge.key, &"saved")
	if not diagnostic: assert_gt(_saved_draw_us, input_us)
	assert_eq(fixture.bridge.capture_reading_checkpoint(false), reading_before, "Save preserves live reading")
	assert_eq(fixture.game.capture_run_snapshot_input(), source, "Save preserves gameplay and scene consequences")
	var disk: Dictionary = fixture.storage.read_text("quicksave.json")
	if not _ok(disk): return
	var parsed: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(disk.value)
	if not _ok(parsed): return
	var validated: Dictionary = preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(parsed.value)
	if not _ok(validated): return
	var document: Dictionary = validated.value.candidate
	assert_eq(document.current_snapshot.snapshot.narrative_checkpoint, projected.value, "durable Save retains the same player position")
	print("DWM_F5_LATENCY " + JSON.stringify({"case": scenario, "prior_quick_saves": prior_saves,
		"diagnostic_only": diagnostic, "renderer": DisplayServer.get_name(), "engine": Engine.get_version_info().string,
		"profile_enabled": profile_enabled, "input_dispatch_us": dispatched_us - input_us,
		"input_to_saved_draw_us": _saved_draw_us - input_us if not diagnostic else null,
		"input_to_frame_post_draw_us": presented_us - input_us if not diagnostic else null,
		"max_process_frame_gap_us": _max_frame_gap_us,
		"frame_gap_window": "preceding process frame through first process frame after Saved presentation",
		"capture_callback_calls": _capture_calls, "capture_callback_inclusive_us": _capture_us,
		"capture_scope": "fixture canonical reading, run and audio input callback only; excludes enclosing save work",
		"reading_history_entries": history.value.captions.size(), "recovery_journal_entries": document.recovery_journal.size(),
		"quicksave_bytes": str(disk.value).to_utf8_buffer().size(), "quicksave_sha256": str(disk.value).sha256_text(),
		"fixture_limit": "test-authored short scene and empty host; repeated saves do not model longer reading history"}))
