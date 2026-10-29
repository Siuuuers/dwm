extends "res://tests/integration/scene_inline_audio_child.gd"

func test_manual_cues_save_target_music_and_silence_during_fades() -> void:
	if not await _begin_inline(): return
	if not await _advance_to("two"): return
	_assert_selection("TEST.inline.b")
	_assert_music_players(2)
	assert_eq(_starts("SFX"), 2)
	if not _save_inline(1, "TEST.inline.b"): return
	if not await _advance_to("three"): return
	_assert_selection("")
	assert_eq(_starts("SFX"), 3)
	if not _save_inline(2, ""): return
	if not await _advance_to("four"): return
	_assert_selection("TEST.inline.a")
	_assert_music_players(1)
	assert_eq(_starts("SFX"), 4)
	var music_starts := _starts("Music")
	if not await _advance_to("five"): return
	assert_eq(_starts("Music"), music_starts, "same-ID cue keeps native playback")
	var context: Dictionary = get_node("/root/AudioManager").get_semantic_audio_context()
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	var history := _history_ids()
	for locale: String in ["zh_HK", "en"]:
		if not _ok(get_node("/root/LocalizationManager").set_locale(locale)): return
		for frame: int in 3: await get_tree().process_frame
	assert_eq(_starts("Music"), music_starts)
	assert_eq(_starts("SFX"), 4)
	assert_eq(get_node("/root/AudioManager").get_semantic_audio_context(), context)
	assert_eq(bridge.capture_reading_checkpoint(false), reading)
	assert_eq(_history_ids(), history)
	await _click(_controls(get_tree().current_scene, "CheckComputer"))
	await _click(_controls(get_tree().current_scene, "CheckComputer"))
	assert_eq(_starts("Music"), music_starts)
	assert_eq(_starts("SFX"), 4)
	if not await _advance_to("four"): return
	assert_eq(_starts("SFX"), 5, "genuine backward encounter plays the cue again")
	_assert_selection("TEST.inline.a")
	await _screenshot("inline-audio-manual")
	_write_json(PROOF, {"process_id": OS.get_process_id(),
		"slot_1_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"slot_2_sha256": FileAccess.get_sha256("user://saves/slot_2.json"), "starts": observed.starts})
	_write_json("res://.godot/ci/inline-audio-create.json", {"starts": observed.starts, "renderer": DisplayServer.get_name()})
