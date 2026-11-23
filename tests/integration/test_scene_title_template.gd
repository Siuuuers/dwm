extends "res://tests/integration/scene_computer_child.gd"
## FINAL owners, template content, and actual Viewport input.
const TEMPLATE := preload("res://tests/templates/scene_startup/Registration.gd")
var actions: Array[String] = []

func _install_content_registration() -> Dictionary:
	return TEMPLATE.new()._install_registration()

func _title() -> Node:
	if get_tree().current_scene != null and get_tree().current_scene.scene_file_path == HOST:
		var pause: Node = get_node("/root/SceneRouter")._production_pause
		if not _ok(await pause.request_pause(false)): return null
		if not _ok(pause.request_return()): return null
	else:
		get_node("/root/SceneRouter").goto_menu()
	for frame: int in 12: await get_tree().process_frame
	return get_tree().current_scene

func _press(button: Button, label: String) -> bool:
	assert_true(is_instance_valid(button), label)
	if not is_instance_valid(button): return false
	assert_true(button.is_visible_in_tree(), label)
	assert_false(button.disabled, label)
	if not button.is_visible_in_tree() or button.disabled: return false
	var observed := [0]
	button.pressed.connect(func(): observed[0] += 1, CONNECT_ONE_SHOT)
	await _click(button)
	assert_eq(observed[0], 1, label)
	actions.append(label)
	return observed[0] == 1

func _wait_opening(count: int) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while true:
		if ready_count == count and get_tree().current_scene != null and get_tree().current_scene.scene_file_path == HOST \
				and bridge._runtime_adapter.current_line_id() == "line.scene.test.b.one" \
				and bridge._runtime_adapter.is_current_line_complete(): return true
		if Time.get_ticks_msec() >= deadline:
			await _screenshot("title-template-timeout")
			fail_test("Title did not reach template opening: " + str({"activation": saves._scene_restore_activation,
				"ready": ready_count, "scene": get_tree().current_scene.scene_file_path if get_tree().current_scene != null else "",
				"line": bridge._runtime_adapter.current_line_id()}))
			return false
		await get_tree().process_frame
	return false

func _wait_confirmation(menu: Node) -> bool:
	for frame: int in 120:
		if is_instance_valid(menu._confirmation) and not menu._title_transition: return true
		await get_tree().process_frame
	fail_test("Title confirmation did not appear")
	return false

func test_title_template_cancel_then_confirm_replacement() -> void:
	if not _start_services(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	assert_false(saves.configure_scene_title_new_run("TEST.missing").ok)
	if not _ok(saves.configure_scene_title_new_run(TEMPLATE.OPENING_TARGET)): return
	assert_true(saves.configure_scene_title_new_run(TEMPLATE.OPENING_TARGET).ok)
	assert_false(saves.configure_scene_title_new_run("target_a").ok)
	var menu: Node = await _title()
	if menu == null: return
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	await _screenshot("title-template-fresh")
	if not await _press(menu._new_acc_button, "fresh New Acc"): return
	if not await _wait_opening(1): return
	assert_true("TEST TEMPLATE: opening caption." in _caption().caption_text.text)
	assert_true(saves._prepared_new_run_token.is_empty())
	assert_true(saves._new_run_transaction_id.is_empty())
	var first: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return
	assert_eq(first.scene.active_occurrence_id, reading.value.reading_session.occurrence_id)
	if not _ok(saves.save_latest_to_slot(1)): return
	var slot_hash := FileAccess.get_sha256("user://saves/slot_1.json")
	assert_false(FileAccess.file_exists("user://saves/autosave.json"))
	assert_eq(slot_hash.length(), 64, "physical slot exists before replacement")
	if not _ok(saves.autosave_latest()): return
	var auto_hash := FileAccess.get_sha256("user://saves/autosave.json")
	await _screenshot("title-template-opening")
	menu = await _title()
	if menu == null: return
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var live_before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	if not await _press(menu._new_acc_button, "replacement New Acc"): return
	if not await _wait_confirmation(menu): return
	assert_true(menu._confirmation.cancel_button.has_focus())
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), auto_hash)
	await _screenshot("title-template-consent")
	if not await _press(menu._confirmation.cancel_button, "Cancel replacement"): return
	assert_true(saves._prepared_new_run_token.is_empty())
	assert_eq(profile.get_profile_snapshot(), profile_before)
	assert_eq(game.capture_run_snapshot_input(), live_before)
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), auto_hash)
	assert_eq(ready_count, 1)
	if not await _press(menu._new_acc_button, "prepare replacement"): return
	if not await _wait_confirmation(menu): return
	if not await _press(menu._confirmation.confirm_button, "confirm replacement"): return
	if not await _wait_opening(2): return
	var second: Dictionary = game.capture_run_snapshot_input()
	assert_ne(second.lifecycle.run_id, first.lifecycle.run_id)
	assert_false(second.lifecycle.has("scene_assignment"))
	assert_eq(profile.get_profile_snapshot(), profile_before)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), slot_hash)
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), auto_hash)
	assert_eq(ready_count, 2)
	assert_true("TEST TEMPLATE: opening caption." in _caption().caption_text.text)
	await _screenshot("title-template-replacement-opening")
	_write_json("res://.godot/ci/title-template-proof.json", {"process_id": OS.get_process_id(),
		"ready_count": ready_count, "actions": actions, "preserved_slot_sha256": slot_hash})
