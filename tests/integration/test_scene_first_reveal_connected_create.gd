extends "res://tests/integration/scene_first_reveal_connected_child.gd"
func test_first_reveal_live_checkpoint_and_explicit_save() -> void:
	if not fixture_ready: return
	if not _ok(await fixture.begin_playable_source()): return
	if not _ok(fixture.dispatch()): return
	if not _ok(fixture.admit_challenge()): return
	assert_eq(fixture.panel().value.phase, "never_started")
	var checkpoint: Dictionary = fixture.bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	var profile_before: Dictionary = fixture.profile_bytes()
	if not _ok(fixture.reveal()): return
	var record: Dictionary = fixture.challenge_record().duplicate(true)
	assert_eq(record.phase, "active")
	assert_true(record.board.revealed_indices.has(323))
	assert_eq(fixture.panel().value.phase, "active")
	assert_eq(fixture.challenge_attempt().value, {})
	assert_eq(fixture.bridge.capture_reading_checkpoint(false).value, checkpoint.value)
	assert_eq(fixture.files.autosave_writes, 0)
	assert_false(fixture.storage.exists("autosave.json"))
	if not _ok(fixture.reveal()): return
	assert_eq(fixture.challenge_record(), record)
	assert_eq(fixture.profile_bytes(), profile_before)
	assert_eq(fixture.files.autosave_writes, 0)
	var snapshot_input: Dictionary = fixture.game.capture_run_snapshot_input()
	snapshot_input.desktop.board["command_receipts"] = {}
	var recorded: Dictionary = fixture.manager.record_stable_checkpoint({
		"snapshot_input": snapshot_input, "route_id": "scene",
		"active_app_id": null, "audio_context": {}, "content_version": 1,
		"dialogic_checkpoint": checkpoint.value}, &"manual_save")
	if not _ok(recorded): return
	if not _ok(fixture.manager.autosave_latest()): return
	var saved: Dictionary = fixture.storage.read_text("autosave.json")
	if not _ok(saved): return
	var document: Dictionary = PARSER.parse_object(saved.value)
	if not _ok(document): return
	if not _ok(SAVE_SCHEMA.validate(document.value)): return
	var snapshot: Dictionary = document.value.current_snapshot.snapshot
	assert_eq(snapshot.gameplay.route_context.active_dating_challenge, record)
	var projected: Dictionary = fixture.RUN.SCENE_READING.project_player_checkpoint(checkpoint.value)
	if not _ok(projected): return
	assert_eq(snapshot.narrative_checkpoint, projected.value)
	write_proof({"phase": "create", "mode": "normal", "process_id": OS.get_process_id(),
		"storage_root": fixture.storage.describe_root(), "autosave_sha256": str(saved.value).sha256_text(),
		"attempt": {"record": record}, "saved_record": record, "checkpoint": snapshot.narrative_checkpoint,
		"profile_files": fixture.profile_bytes(), "source_branch": snapshot.lifecycle.branch_id,
		"scope": "real_Profile_Run_native_owners_live_Challenge_checkpoint_explicit_Save_no_rendered_panel"}, true)
