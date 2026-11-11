extends "res://tests/integration/test_scene_inline_presentation.gd"
# Headless semantic diagnostic only; does not qualify rendered acceptance.

func _begin_inline() -> bool:
	if not _start_services(): return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci"))
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return false
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending")
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return false
	for frame: int in 5: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.one")
	_assert_selection("TEST.inline.a")
	assert_eq(_starts("Music"), 1, "entry cue starts exactly once")
	assert_eq(_starts("SFX"), 1, "new entry plays its one-shot once")
	assert_eq(_autosave_sha256(), "", "audio entry does not create Autosave")
	return true
