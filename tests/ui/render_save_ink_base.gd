extends "res://tests/integration/scene_apps_connected_child.gd"
const INK_PROOF := "user://save-ink-proof.json"

func _begin_ink_run() -> bool:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless" or not _start_services(): return false
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return false
	var started: Dictionary = saves.start_scene_new_run("target_b", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending")
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return false
	return await _wait_line("scene.test.b", "line.scene.test.b.one")

func _ink_document(file: String) -> Dictionary:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/" + file))
	if not _ok(parsed): return {}
	return parsed.value

func _ink_sheet() -> Node:
	var button: Control = _controls(get_tree().current_scene, "Save")
	var deadline := Time.get_ticks_msec() + 10000
	await RenderingServer.frame_post_draw
	while not button._admitted() and Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
	assert_true(button._admitted())
	if not button._admitted(): return null
	await _click(button)
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(sheet.can_save_backup())
	return sheet if sheet.can_save_backup() else null

func _ink_action(sheet: Node, action: String, locator: String) -> bool:
	var prepared: Dictionary = sheet._backup_port.prepare_action(action, locator)
	if not _ok(prepared): return false
	var result: Dictionary = await sheet._backup_port.commit_action(prepared.value.token)
	if not _ok(result): return false
	for frame: int in 3: await get_tree().process_frame
	return true

func _leave_ink_sheet(sheet: Node) -> void:
	sheet.surface.leave_host()
	for frame: int in 5: await get_tree().process_frame
