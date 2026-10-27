extends "res://tests/ui/render_self_talk_base.gd"

func test_rendered_pair_review_clear_and_physical_save_load() -> void:
	assert_ne(DisplayServer.get_name(), "headless", "this acceptance requires a real renderer")
	if DisplayServer.get_name() == "headless": return
	if not _start_services(): return
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending")
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	for frame: int in 5: await get_tree().process_frame
	var caption: Node = _caption()
	var panel: Control = caption.self_talk
	assert_true(panel.is_visible_in_tree())
	assert_eq(panel.position, Vector2(16, 16), "historical top-left panel inset")
	assert_eq(panel.get_projection().visible_rows.size(), 1, "first thought fills from the top")
	assert_eq(_history_ids(), ["line.scene.test.a.one", "line.scene.test.a.thought_one"])
	await _capture_self_talk("first-pair")
	var native: Node = caption.caption_text
	get_node("/root/Dialogic").Text.text_started.connect(func(_info: Dictionary) -> void: native.active_speed = 10.0, CONNECT_ONE_SHOT)
	if not await _advance_to("two"): return
	assert_true(native.revealing, "ordinary caption is genuinely typewriting")
	assert_lt(native.visible_ratio, 1.0)
	var presentation: Dictionary = bridge.capture_self_talk_presentation()
	if not _ok(presentation): return
	assert_eq(presentation.value.rows.size(), 2, "attached thought is already complete during caption reveal")
	assert_true(str(presentation.value.rows.back().text).begins_with("SECOND"))
	var shaped: Dictionary = panel.get_projection()
	assert_gt(int(shaped.row_count), int(shaped.history_count), "wrapped rows consume the budget")
	assert_lte(shaped.visible_rows.size(), 3)
	var speech: Dictionary = bridge.capture_current_speech_presentation()
	if not _ok(speech): return
	assert_eq(speech.value.primary_text, native.get_parsed_text() + "\n" + str(presentation.value.rows.back().text),
		"one speech stream receives caption then thought")
	await _capture_self_talk("partial-caption-instant-thought")
	await _accept()
	if not await _advance_to("three"): return
	assert_eq(bridge.capture_self_talk_presentation().value.rows, presentation.value.rows, "caption without thought retains thoughts")
	if not await _advance_to("four"): return
	if not await _advance_to("five"): return
	if caption.caption_text.revealing: await _accept()
	var ids: Array = _history_ids()
	assert_eq(ids, ["line.scene.test.a.one", "line.scene.test.a.thought_one", "line.scene.test.a.two",
		"line.scene.test.a.thought_two", "line.scene.test.a.three", "line.scene.test.a.four",
		"line.scene.test.a.thought_three", "line.scene.test.a.five", "line.scene.test.a.thought_four"])
	assert_eq(panel.get_projection().visible_rows.size(), 3)
	assert_ne(panel.get_projection().visible_rows[0].id, "line.scene.test.a.thought_one", "oldest rows leave live window")
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	await _wheel_thought(true)
	assert_true(panel.is_reviewing(), "real wheel input enters thought review")
	assert_eq(caption._review_offset, 0, "caption review cursor stays independent")
	assert_false(caption._auto_button_admitted())
	assert_false(caption._next_admitted())
	assert_eq(bridge.capture_reading_checkpoint(false), checkpoint)
	assert_eq(profile.get_profile_snapshot(), profile_before)
	assert_eq(_history_ids(), ids)
	await _capture_self_talk("thought-review")
	await _resize_review(caption, panel)
	await _click(panel)
	assert_false(panel.is_reviewing(), "click returns to live without Advance")
	assert_eq(bridge.capture_reading_checkpoint(false), checkpoint)
	var rail: Control = caption.transport_rail
	var rail_y: float = rail.get_node("History").position.y
	for command: String in ["History", "Save", "Load", "Skip", "Auto", "Next"]:
		assert_eq(rail.get_node(command).position.y, rail_y, "all six controls share one bottom row")
	var host: Control = get_tree().current_scene
	var caret: Control = _controls(host, "CheckComputer")
	assert_lt(caret.get_global_rect().end.y, rail.get_node("Save").get_global_rect().end.y)
	await _click(caret)
	assert_true(host.is_computer_open())
	assert_true(bridge.is_computer_caption_held())
	assert_eq(bridge.capture_reading_checkpoint(false), checkpoint)
	await _click(caret)
	assert_false(host.is_computer_open())
	assert_eq(bridge.capture_reading_checkpoint(false), checkpoint)
	await _click(rail.get_node("Save"))
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(sheet.can_save_backup())
	if not sheet.can_save_backup(): return
	var prepared: Dictionary = sheet._backup_port.prepare_action("save", "slot:1")
	if not _ok(prepared): return
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return
	sheet.surface.leave_host()
	for frame: int in 5: await get_tree().process_frame
	assert_true(FileAccess.file_exists("user://saves/slot_1.json"), "physical slot exists")
	var saved_hash := FileAccess.get_sha256("user://saves/slot_1.json")
	var thoughts_before: Dictionary = bridge.capture_self_talk_presentation().value.duplicate(true)
	if not await _advance_to("six"): return
	assert_eq(panel.get_projection().visible_rows, [], "explicit clear empties the live view")
	assert_eq(panel.get_projection().history_count, 4, "clear retains encountered thoughts")
	await _wheel_thought(true)
	assert_true(panel.is_reviewing(), "thoughts remain reviewable after clear")
	assert_false(panel.get_projection().visible_rows.is_empty())
	await _capture_self_talk("review-after-clear")
	await _click(panel)
	if caption.caption_text.revealing: await _accept()
	await _click(rail.get_node("Load"))
	sheet = get_node("/root/SceneRouter")._production_pause
	prepared = sheet._backup_port.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	ready_count = 0
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return
	if not await _await_ready(): return
	for frame: int in 6: await get_tree().process_frame
	caption = _caption()
	panel = caption.self_talk
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.five")
	assert_eq(_history_ids(), ids, "Load restores encountered pair order without duplicate or future clear")
	assert_eq(bridge.capture_self_talk_presentation().value.rows, thoughts_before.rows)
	assert_eq(bridge.capture_self_talk_presentation().value.live_start, thoughts_before.live_start)
	assert_eq(panel.get_projection().visible_rows.size(), 3)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), saved_hash, "Load preserves source slot")
	assert_false(caption.caption_text.revealing, "restored pair is fully visible")
	await _capture_self_talk("restored-pair")
	var report := {"captures": _captures, "history_ids": ids, "slot_sha256": saved_hash,
		"renderer": DisplayServer.get_name(), "scope": "synthetic paired DTL; FINAL services; physical Save and same-process Load"}
	_write_json("res://.godot/ci/self-talk-journey.json", report)
	var final_checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(final_checkpoint): return
	var compact: Dictionary = COMPACT_READING.project_player_checkpoint(final_checkpoint.value)
	if not _ok(compact): return
	_write_json("user://self-talk-pair-proof.json", {"creator_process_id": OS.get_process_id(),
		"history_ids": ids, "slot_sha256": saved_hash, "checkpoint": compact.value,
		"thoughts": bridge.capture_self_talk_presentation().value, "profile": profile.get_profile_snapshot(),
		"profile_sha256": FileAccess.get_sha256("user://profile.json"),
		"gameplay": game.capture_run_snapshot_input().gameplay, "scene": game.capture_run_snapshot_input().scene})
	print("SELF_TALK_JOURNEY_COMPLETED ", JSON.stringify(report))
