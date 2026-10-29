extends "res://tests/integration/scene_inline_audio_child.gd"

func test_fresh_load_restores_track_start_then_silence_without_old_sfx() -> void:
	var proof: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(PROOF))
	if not _ok(proof): return
	assert_ne(OS.get_process_id(), proof.value.process_id)
	if not _start_services(): return
	if not await _load_inline(1, true): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.two")
	_assert_selection("TEST.inline.b")
	_assert_music_players(1)
	assert_eq(_starts("Music"), 1)
	assert_eq(observed.starts[0].position, 0.0, "Load starts at authored entrance, not old anchor or saved playhead")
	assert_eq(_starts("SFX"), 0, "Load does not execute crossed one-shots")
	if not await _load_inline(2, false): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.three")
	_assert_selection("")
	_assert_music_players(0)
	assert_eq(_starts("Music"), 1)
	assert_eq(_starts("SFX"), 0)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.value.slot_1_sha256)
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.value.slot_2_sha256)
	await _screenshot("inline-audio-restored-silence")
	_write_json("res://.godot/ci/inline-audio-load.json", {"process_id": OS.get_process_id(),
		"creator_process_id": proof.value.process_id, "starts": observed.starts, "renderer": DisplayServer.get_name()})
