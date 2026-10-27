extends "res://tests/support/ScenePauseLoadTestBase.gd"
## Real native source and retained sheet/save owners. The capture callback supplies
## the fixture's canonical owners; no successful Save/Load acknowledgement is faked.
var _capture_calls := 0
var _desktop_board := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd").new()

func _capture_desktop_inputs() -> Dictionary:
	return {"board": _desktop_board.capture(), "consequence": fixture.game._desktop_snapshot.consequence.duplicate(true)}

func _capture_scene_inputs() -> Dictionary:
	_capture_calls += 1
	var checkpoint: Dictionary = fixture.bridge.capture_reading_checkpoint(false)
	if not checkpoint.get("ok", false): return checkpoint
	return {"ok": true, "value": {"snapshot_input": fixture.game.capture_run_snapshot_input(),
		"route_id": "scene", "active_app_id": null, "audio_context": fixture.audio_context(),
		"content_version": 1, "dialogic_checkpoint": checkpoint.value}}

func test_direct_scene_sheets_save_and_load_without_pause_menu() -> void:
	if not fixture_ready: return
	# Restore the player board through its real owner before capturing live Save inputs.
	fixture.participants.desktop_board = preload("res://scripts/application/restore/DesktopBoardRestoreParticipant.gd").new(_desktop_board, fixture.issuer)
	if not _ok(fixture.manager.configure_scene_restore_participants(fixture.participants)): return
	if not _ok(await fixture.start_text()): return
	if not _ok(fixture.game.configure_desktop_snapshot_provider(_capture_desktop_inputs)): return
	fixture.pause._services["backup_capture"] = Callable(self, "_capture_scene_inputs")
	if not _ok(fixture.manager.configure_backup_capture_provider(
		Callable(fixture.pause, "capture_backup_checkpoint_inputs"), Callable(),
		Callable(fixture.pause, "can_save_backup"))): return
	if not _ok(await fixture.pause.open_scene_settings()): return
	assert_eq(fixture.pause.surface.entered_action, &"settings")
	assert_false(fixture.pause.surface.get_node("Actions").visible)
	fixture.pause.surface.leave_host()
	for frame: int in 4: await get_tree().process_frame
	assert_false(get_tree().paused)
	assert_false(fixture.pause.surface.visible)
	if not _ok(await fixture.pause.open_scene_backup("save")): return
	assert_eq(fixture.pause.surface.entered_action, &"backup")
	assert_false(fixture.pause.surface.get_node("Actions").visible)
	assert_true(fixture.pause.can_save_backup())
	var captures_before: int = _capture_calls
	assert_true(fixture.manager.get_backup_save_capability().enabled)
	assert_eq(_capture_calls, captures_before, "Save availability does not capture the reading state")
	var prepared: Dictionary = fixture.pause._backup_port.prepare_action("save", "slot:2")
	if not _ok(prepared): return
	assert_gt(_capture_calls, captures_before, "Save activation captures the current canonical owners")
	if not _ok(await fixture.pause._backup_port.commit_action(prepared.value.token)): return
	fixture.pause.surface.leave_host()
	for frame: int in 4: await get_tree().process_frame
	assert_false(get_tree().paused)
	if not _ok(await fixture.pause.open_scene_backup("load")): return
	assert_false(fixture.pause.surface.get_node("Actions").visible)
	prepared = fixture.pause._backup_port.prepare_action("load", "slot:2")
	if not _ok(prepared): return
	if not _ok(await fixture.pause._backup_port.commit_action(prepared.value.token)): return
	if not _ok(await fixture.settle_load()): return
	assert_false(get_tree().paused)
	assert_false(fixture.pause.surface.visible)
	assert_eq(fixture.bridge._reading_session.boundary, "line")
	# Exercise native F5 after the connected manual Save/Load journey above.
	_test_stage = "quick_save_completion"
	if not _ok(await fixture.pause.open_scene_backup("save")): return
	var quick: Node = fixture.pause._quick_commands
	var edge: Label = quick.edge
	edge.set_process(false)
	var draws := [0]
	edge.draw.connect(func() -> void: draws[0] += 1)
	captures_before = _capture_calls
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_F5
		key.physical_keycode = KEY_F5
		key.pressed = pressed
		get_tree().root.push_input(key, true)
	if not _ok(quick.last_result): return
	assert_true(fixture.storage.exists("quicksave.json"))
	assert_gt(_capture_calls, captures_before, "native Quick Save captures the restored live reading state")
	await RenderingServer.frame_post_draw
	assert_gt(draws[0], 0, "Saved reaches an actual rendered frame")
	assert_true(edge.is_visible_in_tree())
	assert_eq(edge.key, &"saved")
	assert_eq(edge.remaining_seconds, 2.0)
	captures_before = _capture_calls
	await get_tree().create_timer(0.3, true).timeout
	edge.advance_eligible_time(0.3)
	await RenderingServer.frame_post_draw
	assert_true(edge.is_visible_in_tree())
	assert_eq(edge.key, &"saved")
	assert_eq(_capture_calls, captures_before, "visible completion does not recapture reading after the condition-poll interval")
	edge.advance_eligible_time(1.7)
	assert_eq(edge.key, &"")
	assert_false(edge.visible, "completion expires after two eligible seconds")
