extends "res://tests/support/ScenePauseLoadTestBase.gd"
## Real native source and retained sheet/save owners. The capture callback supplies
## the fixture's canonical owners; no successful Save/Load acknowledgement is faked.
func _capture_scene_inputs() -> Dictionary:
	var checkpoint: Dictionary = fixture.bridge.capture_reading_checkpoint(false)
	if not checkpoint.get("ok", false): return checkpoint
	return {"ok": true, "value": {"snapshot_input": fixture.game.capture_run_snapshot_input(),
		"route_id": "scene", "active_app_id": null, "audio_context": fixture.audio_context(),
		"content_version": 1, "dialogic_checkpoint": checkpoint.value}}

func test_direct_scene_sheets_save_and_load_without_pause_menu() -> void:
	if not fixture_ready or not _ok(await fixture.start_text()): return
	fixture.pause._services["backup_capture"] = Callable(self, "_capture_scene_inputs")
	if not _ok(fixture.manager.configure_backup_capture_provider(
		Callable(fixture.pause, "capture_backup_checkpoint_inputs"))): return
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
	var prepared: Dictionary = fixture.pause._backup_port.prepare_action("save", "slot:2")
	if not _ok(prepared): return
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
