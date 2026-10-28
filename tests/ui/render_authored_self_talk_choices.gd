extends "res://tests/integration/authored_week_child.gd"
## Shipped Day1, real Title/input, physical Save/Load and the authored Yes/default fork.

func test_production_thought_and_yes_share_panel_and_restore_together() -> void:
	_phase = "create"
	if not _setup_authored(): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1): return
	if not await _walk_authored(1, 29): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.Day1.030")
	for frame: int in 12: await get_tree().process_frame
	var pane: Control = _caption().self_talk
	var yes: Button = get_tree().current_scene.get_node("SceneControlsLayer/Surface/ThoughtYes")
	assert_true(pane.is_visible_in_tree())
	assert_true(yes.is_visible_in_tree())
	assert_true(pane.get_global_rect().encloses(yes.get_global_rect()))
	var thoughts: Dictionary = bridge.capture_self_talk_presentation()
	if not _ok(thoughts): return
	assert_eq(thoughts.value.rows.size(), 1)
	assert_eq(thoughts.value.rows[0].text, "Ask for another photograph.")
	assert_eq(_caption().caption_text.get_parsed_text(), "Her face in this one, too.")
	assert_false(observed_lines.has("line.Day1.031"), "attached thought is not a second reading step")
	var speech: Dictionary = bridge.capture_current_speech_presentation()
	if not _ok(speech): return
	assert_eq(speech.value.primary_text, "Her face in this one, too.\nAsk for another photograph.")
	await _screenshot("authored-self-talk-offer")
	var saved: Dictionary = await _save_authored(1, "self-talk-offer")
	if saved.is_empty(): return
	await _accept()
	if not await _wait_line("line.Day1.photo.default.001"): return
	assert_eq(game.scene_choices.get("Day1.photo"), "pass")
	await _click(_caption().transport_rail.get_node("Load"))
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	var prepared: Dictionary = sheet._backup_port.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	ready_count = 0
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return
	if not await _await_ready() or not await _wait_line("line.Day1.030"): return
	for frame: int in 12: await get_tree().process_frame
	pane = _caption().self_talk
	yes = get_tree().current_scene.get_node("SceneControlsLayer/Surface/ThoughtYes")
	assert_eq(bridge.capture_self_talk_presentation(), thoughts, "Load restores the same paired thought")
	assert_true(pane.is_visible_in_tree())
	assert_true(yes.is_visible_in_tree())
	assert_true(pane.get_global_rect().encloses(yes.get_global_rect()))
	assert_false(game.scene_choices.has("Day1.photo"), "earlier save restores unresolved choice")
	await _screenshot("authored-self-talk-restored")
	await _click(yes)
	if not await _wait_line("line.Day1.photo.yes.001"): return
	assert_eq(game.scene_choices.get("Day1.photo"), "yes")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), saved.slot_sha256)
	print("AUTHORED_SELF_TALK_CHOICES_COMPLETED")
