extends "res://tests/integration/scene_inline_presentation_child.gd"
## A second OS process consumes only the first process's saved bytes.

func test_fresh_load_restores_composition_and_music_without_story_commands() -> void:
	var proof: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://inline-presentation-proof.json"))
	if not _ok(proof): return
	assert_ne(OS.get_process_id(), proof.value.process_id)
	if not _start_services(): return
	var storage: RefCounted = saves._storage
	var original_files: RefCounted = storage._file_ops
	var files := CountingFiles.new()
	storage._file_ops = files
	if not await _load_inline(4, true): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.two")
	assert_eq(game.capture_run_snapshot_input().scene.presentation, proof.value.presentation)
	_assert_art("template.art", ["portrait", "letter"])
	_assert_selection("TEST.inline.b")
	_assert_music_players(1)
	assert_eq(_starts("Music"), 1)
	assert_eq(observed.starts[0].position, 0.0, "Load starts selected BGM at its authored entrance")
	assert_eq(_starts("SFX"), 0, "no one-shot command replays in the new process")
	assert_eq(files.autosave_writes, 0, "restoring state does not execute checkpoint commands")
	assert_eq(FileAccess.get_sha256("user://saves/slot_4.json"), proof.value.slot_4_sha256)
	assert_eq(_autosave_sha256(), proof.value.autosave_sha256)
	await _screenshot("inline-presentation-fresh-load")
	_write_json("res://.godot/ci/inline-presentation-fresh-load.json", {
		"process_id": OS.get_process_id(), "creator_process_id": proof.value.process_id,
		"presentation": game.capture_run_snapshot_input().scene.presentation,
		"starts": observed.starts, "autosave_writes": files.autosave_writes,
		"slot_4_sha256": FileAccess.get_sha256("user://saves/slot_4.json"),
		"autosave_sha256": _autosave_sha256(), "renderer": DisplayServer.get_name()})
	# Earlier compatible saves omitted presentation. Keep the stable caption and
	# saved BGM, resolving only its entry's declared base without replaying cues.
	var legacy_input: Dictionary = game.capture_run_snapshot_input()
	legacy_input.scene.erase("presentation")
	var legacy_checkpoint: Dictionary = bridge.capture_reading_checkpoint()
	if not _ok(legacy_checkpoint): return
	var recorded: Dictionary = saves.record_stable_checkpoint({
		"snapshot_input": legacy_input, "dialogic_checkpoint": legacy_checkpoint.value,
		"route_id": "scene", "active_app_id": null,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context(),
		"content_version": legacy_checkpoint.value.content_version}, &"manual_save")
	if not _ok(recorded): return
	if not _ok(saves.save_latest_to_slot(5)): return
	var legacy_path := "user://saves/slot_5.json"
	var legacy_sha := FileAccess.get_sha256(legacy_path)
	var legacy: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(legacy_path))
	if not _ok(legacy): return
	assert_false(legacy.value.current_snapshot.snapshot.scene.has("presentation"))
	if legacy.value.current_snapshot.snapshot.scene.has("presentation"): return
	if not await _load_inline(5, false): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.two")
	_assert_art("template.background", [])
	var base: Dictionary = game.capture_run_snapshot_input().scene.presentation
	assert_eq(base.scene_entry_id, "template.scene")
	assert_eq(base.checkpoint_id, "")
	assert_eq(base.portraits, [])
	assert_false(base.split_panels)
	_assert_selection("TEST.inline.b")
	assert_eq(_starts("SFX"), 0)
	assert_eq(files.autosave_writes, 0)
	assert_eq(FileAccess.get_sha256(legacy_path), legacy_sha)
	assert_eq(_autosave_sha256(), proof.value.autosave_sha256)
	await _screenshot("compatible-presentation-default-loaded")
	storage._file_ops = original_files
	ART.reload_placements()
