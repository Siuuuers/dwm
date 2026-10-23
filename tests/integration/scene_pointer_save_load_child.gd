extends "res://tests/integration/scene_manual_entry_child.gd"
## One ordinary rendered, same-process journey. TEST content and real FINAL owners.
## Save/Load selection and consent use Viewport input, never direct port commands.
const SLOT := "slot:2"
const SLOT_PATH := "user://saves/slot_2.json"
var _pointer_actions: Array[String] = []

func _screenshot(label: String) -> void:
	assert_ne(DisplayServer.get_name(), "headless", "This lane requires a real renderer.")
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	assert_false(pixels.is_empty())
	assert_eq(pixels.save_png("res://.godot/ci/pointer-save-load-" + label + ".png"), OK)

func _press(button: Button, label: String) -> bool:
	assert_true(is_instance_valid(button), label)
	if not is_instance_valid(button): return false
	assert_true(button.is_visible_in_tree(), label + " visible")
	assert_false(button.disabled, label + " enabled")
	if not button.is_visible_in_tree() or button.disabled: return false
	var bounds := Rect2(button.get_global_transform_with_canvas() * Vector2.ZERO,
		button.get_global_transform_with_canvas().get_scale() * button.size)
	assert_true(get_viewport().get_visible_rect().encloses(bounds), label + " on screen")
	var observed := [0]
	button.pressed.connect(func(): observed[0] += 1, CONNECT_ONE_SHOT)
	# The inherited helper sends fresh press/release packets and neutral frames.
	# Do not retain/dereference the control after Load may have replaced its scene.
	await _click(button)
	assert_eq(observed[0], 1, label + " receives pointer activation")
	if observed[0] != 1: return false
	_pointer_actions.append(label)
	return true

func _sheet() -> Node:
	return get_node("/root/SceneRouter")._production_pause

func _backup_view() -> Control:
	return _sheet().surface._hosts[&"backup"]

func _wait_saved(backup: Control, previous_hash: String) -> bool:
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if not backup._in_operation and backup._status_key == "saved" \
				and FileAccess.file_exists(SLOT_PATH) and FileAccess.get_sha256(SLOT_PATH) != previous_hash:
			assert_true(backup.last_result.get("ok", false), str(backup.last_result))
			assert_true(backup.status_label.is_visible_in_tree())
			assert_eq(backup.status_label.text, "Saved")
			return backup.last_result.get("ok", false)
		await get_tree().process_frame
	fail_test("Pointer Save did not publish Saved and changed durable slot bytes.")
	return false

func _open_sheet(action: String) -> Control:
	if not await _press(_controls(get_tree().current_scene, action), "scene " + action): return null
	var backup: Control = _backup_view()
	assert_true(backup.is_visible_in_tree())
	assert_eq(backup.active_mode, action.to_lower())
	if not backup.is_visible_in_tree() or backup.active_mode != action.to_lower(): return null
	if not await _press(backup.drawer_buttons[SLOT], "select " + SLOT + " for " + action): return null
	assert_eq(backup.selected_locator, SLOT)
	return backup

func _return_to_board() -> Control:
	if not await _press(_sheet().surface._sheet_back, "sheet Back"): return null
	assert_false(_sheet().surface.visible)
	if _sheet().surface.visible: return null
	if not await _press(_controls(get_tree().current_scene, "CheckComputer"), "scene CheckComputer"): return null
	var host: Control = get_tree().current_scene
	assert_true(host.is_computer_open())
	if not host.is_computer_open(): return null
	return host.get_challenge_mount().get_node("SceneChallengePanel")

func _flag_cell(panel: Control, index: int) -> bool:
	if panel.dock.mode != &"flag":
		if not await _press(panel.dock.buttons.flag, "board Flag mode"): return false
	assert_eq(panel.dock.mode, &"flag")
	if not panel.worksheet.grid.focus_cell(index):
		fail_test("Flag target could not be scrolled into view.")
		return false
	await get_tree().process_frame
	var before: Dictionary = panel.public_view.board.duplicate(true)
	await _click(panel.worksheet.grid.cell_nodes[index])
	assert_ne(panel.public_view.board, before, "Actual cell input changes the board.")
	return panel.public_view.board != before

func run_pointer_save_load() -> void:
	if not await _start_playable(): return
	assert_false(FileAccess.file_exists(SLOT_PATH), "Fresh isolated manual slot")
	if not await _press(_controls(get_tree().current_scene, "CheckComputer"), "scene CheckComputer"): return
	var host: Control = get_tree().current_scene
	assert_true(host.is_computer_open())
	if not host.is_computer_open(): return
	var panel: Control = host.get_challenge_mount().get_node("SceneChallengePanel")
	assert_true(panel.worksheet.grid.focus_cell(323))
	await get_tree().process_frame
	await _click(panel.worksheet.grid.cell_nodes[323])
	assert_eq(panel.public_view.phase, "active")
	if panel.public_view.phase != "active": return
	var unflagged_board: Dictionary = panel.public_view.board.duplicate(true)
	var flag_index := -1
	for index: int in unflagged_board.cells.size():
		if "flag" in unflagged_board.cells[index].get("actions", []):
			flag_index = index
			break
	assert_gte(flag_index, 0)
	if flag_index < 0: return
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	await _screenshot("initial-board")
	var backup: Control = await _open_sheet("Save")
	if backup == null: return
	if not await _press(backup.action_buttons.save, "save empty slot"): return
	if not await _wait_saved(backup, ""): return
	assert_false(is_instance_valid(backup.confirmation), "Empty-slot Save requires no invented confirmation.")
	var initial_hash := FileAccess.get_sha256(SLOT_PATH)
	panel = await _return_to_board()
	if panel == null or not await _flag_cell(panel, flag_index): return
	var saved_board: Dictionary = panel.public_view.board.duplicate(true)
	var saved_record: Dictionary = game.capture_dating_challenge_state().value.duplicate(true)
	assert_ne(saved_board, unflagged_board)
	assert_eq(saved_board.cells[flag_index].mark, "flag")
	backup = await _open_sheet("Save")
	if backup == null: return
	if not await _press(backup.action_buttons.save, "request overwrite"): return
	assert_true(is_instance_valid(backup.confirmation), "Occupied-slot Save presents consent.")
	if not is_instance_valid(backup.confirmation): return
	assert_eq(backup._confirmation_kind, "overwrite")
	assert_eq(FileAccess.get_sha256(SLOT_PATH), initial_hash, "No overwrite before pointer consent.")
	await _screenshot("overwrite-confirmation")
	if not await _press(backup.confirmation.confirm_button, "confirm overwrite"): return
	if not await _wait_saved(backup, initial_hash): return
	var saved_hash := FileAccess.get_sha256(SLOT_PATH)
	await _screenshot("saved-status")
	panel = await _return_to_board()
	if panel == null: return
	assert_eq(panel.public_view.board, saved_board)
	await _screenshot("saved-board")
	if not await _flag_cell(panel, flag_index): return
	var changed_board: Dictionary = panel.public_view.board.duplicate(true)
	var changed_record: Dictionary = game.capture_dating_challenge_state().value.duplicate(true)
	assert_ne(changed_board, saved_board, "Load has an observable board difference to undo.")
	assert_eq(changed_board.cells[flag_index].mark, "none")
	assert_eq(bridge.capture_reading_checkpoint(false), checkpoint)
	await _screenshot("unsaved-board")
	var source_branch: String = game.capture_run_snapshot_input().lifecycle.branch_id
	var before_load_profile: Dictionary = profile.get_profile_snapshot().duplicate(true)
	backup = await _open_sheet("Load")
	if backup == null: return
	if not await _press(backup.action_buttons.load, "request selected Load"): return
	assert_true(is_instance_valid(backup.confirmation))
	if not is_instance_valid(backup.confirmation): return
	assert_eq(backup._confirmation_kind, "replace_progress")
	assert_eq(game.capture_dating_challenge_state().value, changed_record, "Selection alone preserves the live board.")
	assert_eq(game.capture_run_snapshot_input().lifecycle.branch_id, source_branch, "Selection alone does not Load.")
	await _screenshot("load-confirmation")
	ready_count = 0
	if not await _press(backup.confirmation.confirm_button, "confirm selected Load"): return
	# Observe only. Production owns activation/retry; do not invoke a restore API.
	var deadline := Time.get_ticks_msec() + 15000
	while Time.get_ticks_msec() < deadline:
		if ready_count == 1 and not _sheet()._loading and not _sheet().surface.visible: break
		await get_tree().process_frame
	assert_eq(ready_count, 1)
	assert_false(_sheet()._loading)
	assert_false(_sheet().surface.visible)
	if ready_count != 1 or _sheet()._loading or _sheet().surface.visible: return
	assert_eq(_sheet().coordinator.get_state().value.state, &"Active")
	assert_false(get_tree().paused)
	var restored: Control = get_tree().current_scene
	assert_eq(restored.scene_file_path, HOST)
	if not await _press(_controls(restored, "CheckComputer"), "restored CheckComputer"): return
	assert_true(restored.is_computer_open())
	if not restored.is_computer_open(): return
	panel = restored.get_challenge_mount().get_node("SceneChallengePanel")
	assert_eq(panel.public_view.board, saved_board)
	assert_eq(game.capture_dating_challenge_state().value, saved_record)
	assert_eq(bridge.capture_reading_checkpoint(false), checkpoint)
	assert_eq(profile.get_profile_snapshot(), before_load_profile, "Load replays no Profile/History consequences.")
	assert_eq(FileAccess.get_sha256(SLOT_PATH), saved_hash, "Load preserves the selected save.")
	assert_ne(game.capture_run_snapshot_input().lifecycle.branch_id, source_branch)
	assert_true(panel._can_interact())
	assert_true(panel.worksheet.grid.focus_cell(flag_index), "Show the restored flag in the capture.")
	await get_tree().process_frame
	await _screenshot("restored-board")
	_write_json("res://.godot/ci/pointer-save-load-proof.json", {
		"process_id": OS.get_process_id(), "renderer": DisplayServer.get_name(),
		"slot": SLOT, "initial_slot_sha256": initial_hash, "saved_slot_sha256": saved_hash,
		"pointer_actions": _pointer_actions, "saved_board": saved_board, "unsaved_board": changed_board,
		"restored_board": panel.public_view.board, "saved_record": saved_record,
		"checkpoint": checkpoint.value, "source_branch": source_branch,
		"restored_branch": game.capture_run_snapshot_input().lifecycle.branch_id,
		"ready_count": ready_count, "scope": "same-process TEST scene; Viewport Save/Load selection and consent, real disk/services"})
