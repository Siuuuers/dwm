extends "res://tests/integration/scene_bootstrap_restart_child.gd"
## FINAL Bootstrap and actual mounted host; only the authored registration is TEST.
## Creator and loader run in distinct OS processes sharing real Save/Profile files.
const CAPTION := preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
const BOARD_READING := preload("res://scripts/narrative/SoloReadingSession.gd")

func _screenshot(label: String) -> void:
	if DisplayServer.get_name() == "headless": return
	await RenderingServer.frame_post_draw
	var pixels := get_viewport().get_texture().get_image()
	assert_false(pixels.is_empty())
	assert_eq(pixels.save_png("res://.godot/ci/computer-" + label + ".png"), OK)

func _click(control: Control) -> void:
	# GUT's layer 128 otherwise intercepts the production board's mouse packets.
	var test_overlay := get_tree().root.find_child("GutLayer", true, false)
	if test_overlay is CanvasLayer: test_overlay.hide()
	var point := control.get_global_transform_with_canvas() * (control.size / 2.0)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_LEFT
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	for frame: int in 3: await get_tree().process_frame

func _keyboard(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func _controller(button: JoyButton, pressed: bool) -> void:
	var event := InputEventJoypadButton.new()
	event.button_index = button
	event.device = 0
	event.pressed = pressed
	get_viewport().push_input(event, true)
	await get_tree().process_frame

func _caption() -> Node:
	return get_node("/root/SceneRouter")._production_pause._find_caption(get_tree().root)

func _controls(host: Node, name: String) -> Control:
	if name in ["History", "Save", "Load", "Skip", "Auto", "Next", "Settings"]:
		return _caption().transport_rail.get_node(name)
	return host.get_node("SceneControlsLayer/Surface/Controls/" + name)

func _start_playable() -> bool:
	if not _start_services(): return false
	var started: Dictionary = saves.start_scene_new_run("target_b", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return false
	if not _ok(bridge._runtime_adapter.reveal_current_line(true)): return false
	for frame: int in 4: await get_tree().process_frame
	var context: Dictionary = game.scene_event_context()
	if not _ok(context): return false
	var issued: Dictionary = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
	if not _ok(issued): return false
	var event := {"schema_version": 2, "source": context.value.source.duplicate(true),
		"event_id": "scene.test.b.playable", "kind": "challenge.playable", "payload": {"challenge_id": "TEST.challenge"},
		"ordinal": context.value.next_ordinal, "predecessor": context.value.predecessor,
		"command_id": issued.value.token, "issuer_receipt": issued.value.issuer_receipt.duplicate(true),
		"playback_token": context.value.playback_token}
	var live: Dictionary = game.capture_live_session()
	return _ok(bridge.dispatch_scene_event(live.value, event))

## Computer custody pauses playback; inspect the retained native cue without
## asking the active-input API to admit it or modifying its reveal state.
func _computer_caption_observation() -> Dictionary:
	var event: DialogicTextEvent = bridge._runtime_adapter._current_skip_text(true)
	var caption: Node = _caption()
	assert_not_null(event)
	assert_not_null(caption)
	if event == null or caption == null: return {}
	return {"line_id": bridge._runtime_adapter._authored_line_id(event),
		"event_done": event.state == DialogicTextEvent.States.DONE,
		"text": caption.caption_text.get_parsed_text(),
		"revealing": caption.caption_text.revealing,
		"visible_ratio": float(caption.caption_text.visible_ratio)}

func create_computer_board() -> void:
	if not await _start_playable(): return
	# Exercise the previously unverified enabled preference through its real owner.
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", true)): return
	var host: Control = get_tree().current_scene
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	var auto_before: bool = profile.get_preference(&"preferences.reading.auto_enabled", false)
	assert_true(auto_before)
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	await _click(_controls(host, "CheckComputer"))
	assert_true(host.is_computer_open())
	if not host.is_computer_open(): return
	assert_false(get_tree().paused)
	assert_true(bridge.is_computer_caption_held())
	var caption: Node = _caption()
	assert_not_null(caption)
	if caption == null: return
	assert_true(caption.auto_controller.is_auto_enabled())
	assert_false(caption._reading_source_admitted())
	assert_true(caption.transport_rail.visible, "computer overlays the retained rail")
	for command: String in ["History", "Save", "Load", "Skip", "Auto", "Next", "Settings"]:
		var button: Button = caption.transport_rail.get_node(command)
		assert_true(button.visible)
		assert_true(button.disabled)
		await _click(button)
		button.emit_signal("activated")
		assert_true(host.is_computer_open())
		assert_eq(bridge.capture_reading_checkpoint(false), checkpoint, command + " cannot advance held reading")
		assert_eq(profile.get_profile_snapshot(), profile_before, command + " cannot mutate held preferences or History")
		assert_false(caption._history_open)
		assert_false(caption._load_pending)
	# Disabled commands leave focus traversal. Physical acceptance and the
	# supported Save/Load shortcuts must not escape into the reading beneath.
	get_viewport().gui_release_focus()
	var quick_before := FileAccess.get_sha256("user://saves/quicksave.json") if FileAccess.file_exists("user://saves/quicksave.json") else ""
	for key: Key in [KEY_ENTER, KEY_SPACE, KEY_F5, KEY_F9]:
		await _keyboard(key, true)
		await _keyboard(key, false)
	for button: JoyButton in [JOY_BUTTON_A, JOY_BUTTON_LEFT_STICK, JOY_BUTTON_RIGHT_STICK]:
		await _controller(button, true)
		await _controller(button, false)
	assert_eq(bridge.capture_reading_checkpoint(false), checkpoint, "keyboard, controller and shortcuts cannot advance held reading")
	assert_eq(profile.get_profile_snapshot(), profile_before, "alternate inputs cannot toggle Auto or add History")
	assert_false(caption._history_open)
	assert_false(caption._load_pending)
	assert_true(host.is_computer_open())
	assert_eq(FileAccess.get_sha256("user://saves/quicksave.json") if FileAccess.file_exists("user://saves/quicksave.json") else "", quick_before,
		"held Save shortcut cannot write a Quick save")
	assert_false(caption.caption_text.is_processing())
	assert_false(bridge.can_auto_advance_current_line())
	# Longer than the default Auto delay; this checkpoint is an authored control
	# boundary, so this proves preservation there, not line-timer resumption.
	await get_tree().create_timer(2.5).timeout
	assert_true(caption.auto_controller.is_auto_enabled())
	assert_true(bridge.is_computer_caption_held())
	assert_eq(bridge.capture_reading_checkpoint(false), checkpoint)
	assert_eq(profile.get_profile_snapshot(), profile_before, "opening grants no History or attempt")
	var panel: Control = host.get_challenge_mount().get_node("SceneChallengePanel")
	panel.presentation_failed.connect(func(code: StringName): fail_test("panel action refused: " + String(code)))
	assert_eq(panel.public_view.phase, "never_started")
	assert_true(game.capture_dating_challenge_state().value.is_empty())
	assert_false(panel.dock.buttons.pause.visible)
	var grid: Control = panel.worksheet.grid
	# Real grid GUI press/release, after scrolling its owner to the selected cell.
	assert_true(grid.focus_cell(323))
	await get_tree().process_frame
	assert_true(panel._can_interact())
	assert_true("reveal" in panel.public_view.board.cells[323].actions)
	var clicked := [false]
	grid.gui_input.connect(func(_event: InputEvent): clicked[0] = true, CONNECT_ONE_SHOT)
	await _click(grid.cell_nodes[323])
	assert_true(clicked[0], "viewport click reaches the grid")
	assert_eq(panel.public_view.phase, "active", str({"failed": panel._failed, "blocked": grid._interaction_blocked,
		"cell_rect": grid.cell_nodes[323].get_global_rect(), "grid_rect": grid.get_global_rect(),
		"panel_rect": panel.get_global_rect(), "viewport": get_viewport().get_visible_rect()}))
	if panel.public_view.phase != "active": return
	var saved_board: Dictionary = panel.public_view.board.duplicate(true)
	await _screenshot("active")
	assert_eq(bridge.capture_reading_checkpoint(false), checkpoint, "board click cannot advance captions")
	var record: Dictionary = game.capture_dating_challenge_state().value.duplicate(true)
	assert_false(record.is_empty())
	get_viewport().gui_release_focus()
	await _keyboard(KEY_ENTER, true)
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	assert_false(bridge.is_computer_caption_held())
	_controls(host, "Save").grab_focus()
	await _keyboard(KEY_ENTER, false)
	for frame: int in 3: await get_tree().process_frame
	assert_false(caption._load_pending, "held acceptance cannot activate Save after the overlay closes")
	assert_false(get_tree().paused)
	assert_true(caption.transport_rail.visible, "closing restores dialogue controls")
	assert_eq(profile.get_preference(&"preferences.reading.auto_enabled", false), auto_before)
	assert_true(caption.auto_controller.is_auto_enabled())
	assert_eq(bridge.capture_reading_checkpoint(false), checkpoint)
	await _click(_controls(host, "CheckComputer"))
	assert_eq(panel.public_view.board, saved_board)
	assert_eq(game.capture_dating_challenge_state().value, record)
	# Return from the computer, then enter the actual bottom-rail Save sheet.
	await _click(_controls(host, "CheckComputer"))
	await _click(_controls(host, "Save"))
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	assert_false(host.is_computer_open())
	assert_true(sheet.can_save_backup(), str(sheet.last_result))
	assert_false(sheet.surface.get_node("Actions").visible)
	if not sheet.can_save_backup(): return
	await _screenshot("save-sheet")
	var prepared: Dictionary = sheet._backup_port.prepare_action("save", "slot:1")
	if not _ok(prepared): return
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return
	sheet.surface.leave_host()
	for frame: int in 5: await get_tree().process_frame
	assert_false(get_tree().paused)
	var proof := {"process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"record": record, "board": saved_board, "checkpoint": checkpoint.value,
		"native_caption": _computer_caption_observation(),
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"auto": auto_before, "profile": profile.get_profile_snapshot(),
		"source_branch": game.capture_run_snapshot_input().lifecycle.branch_id}
	assert_false(proof.native_caption.is_empty())
	if proof.native_caption.is_empty(): return
	assert_false(str(proof.native_caption.text).is_empty())
	assert_true(proof.native_caption.event_done)
	assert_false(proof.native_caption.revealing)
	assert_eq(proof.native_caption.visible_ratio, 1.0)
	assert_eq(str(proof.slot_sha256).length(), 64)
	if not _write_json("user://computer-board-proof.json", proof): return
	_write_json("res://.godot/ci/computer-create-proof.json", proof)

func load_computer_board() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://computer-board-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	if not _start_services(): return
	assert_true(proof.auto)
	assert_eq(profile.get_preference(&"preferences.reading.auto_enabled", false), proof.auto)
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	var host: Control = get_tree().current_scene
	await _click(_controls(host, "CheckComputer"))
	assert_true(host.is_computer_open())
	if not host.is_computer_open(): return
	assert_true(_caption().auto_controller.is_auto_enabled())
	var panel: Control = host.get_challenge_mount().get_node("SceneChallengePanel")
	assert_eq(panel.public_view.board, proof.board)
	assert_eq(game.capture_dating_challenge_state().value, proof.record)
	assert_eq(profile.get_profile_snapshot(), proof.profile, "opening restored board is read-only")
	assert_eq(game.capture_run_snapshot_input().lifecycle.branch_id, proof.source_branch)
	var restored: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(restored): return
	var expected_position: Dictionary = BOARD_READING.project_player_checkpoint(proof.checkpoint)
	var restored_position: Dictionary = BOARD_READING.project_player_checkpoint(restored.value)
	if not _ok(expected_position) or not _ok(restored_position): return
	assert_eq(restored_position.value, expected_position.value,
		"Load retains the complete player position; historical live traversal is not persisted")
	var native: Dictionary = _computer_caption_observation()
	assert_false(native.is_empty())
	if native.is_empty(): return
	assert_eq(native.line_id, expected_position.value.reading_session.captions.back().line_id,
		"Native cue is the saved held-control predecessor")
	assert_eq(native.text, proof.native_caption.text, "The complete native caption text is restored")
	assert_true(native.event_done)
	assert_false(native.revealing)
	assert_eq(native.visible_ratio, 1.0, "The restored cue is fully revealed while Computer holds input")
	await _screenshot("restored")
	var hidden := -1
	for index: int in panel.public_view.board.cells.size():
		if "flag" in panel.public_view.board.cells[index].get("actions", []):
			hidden = index
			break
	assert_gte(hidden, 0)
	if hidden < 0: return
	panel.worksheet.set_mode(&"flag")
	assert_true(panel.worksheet.grid.focus_cell(hidden))
	await get_tree().process_frame
	await _click(panel.worksheet.grid.cell_nodes[hidden])
	assert_gt(int(panel.public_view.board.revision), int(proof.board.revision), "restored board remains playable")
	assert_false(get_tree().paused)
	proof["loader_process_id"] = OS.get_process_id()
	await _screenshot("continued")
	proof["continued_board"] = panel.public_view.board
	_write_json("res://.godot/ci/computer-load-proof.json", proof)
