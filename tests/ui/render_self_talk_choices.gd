extends "res://tests/integration/scene_multiple_thoughts_child.gd"
## One real authored offer; layout changes must not create a second choice owner.

func test_choice_row_occupies_self_talk_panel_before_any_paired_thought() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless" or not _start_services(): return
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var started: Dictionary = saves.start_scene_new_run("partner.shared", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending")
	if not await _await_ready() or not await _wait_line("line.scene.test.partner.shared.before"): return
	await _accept()
	if not await _wait_line(OFFER): return
	for frame: int in 12: await get_tree().process_frame
	var host: Control = get_tree().current_scene
	var pane: Control = _caption().self_talk
	var choices: ScrollContainer = host.get_node("SceneControlsLayer/Surface/ThoughtOptions")
	var row: HBoxContainer = choices.get_node("Options")
	assert_false(pane.has_history(), "fixture has no invented paired thought")
	assert_true(pane.is_visible_in_tree(), "a choice reveals the self-talk area before thought history exists")
	assert_true(choices.is_visible_in_tree())
	assert_true(pane.get_global_rect().encloses(choices.get_global_rect()), "choice row belongs within the thought panel")
	assert_eq(row.get_child_count(), 2)
	if row.get_child_count() != 2: return
	assert_eq(row.get_child(0).global_position.y, row.get_child(1).global_position.y, "choices share one row")
	assert_false(host.get_node("SceneControlsLayer/Surface/ThoughtYes").visible)
	assert_eq(choices.vertical_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED)
	assert_eq(pane.get_node(pane.focus_next), row.get_child(0), "thought panel's keyboard order reaches its choices")
	await _screenshot("self-talk-choice-row")
	var before: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(profile.set_preference(&"preferences.accessibility.text_size", 150)): return
	for frame: int in 12: await get_tree().process_frame
	assert_true(pane.get_global_rect().encloses(choices.get_global_rect()), "large text keeps the row in its panel")
	assert_eq(row.get_child(0).global_position.y, row.get_child(1).global_position.y)
	assert_eq(bridge.capture_reading_checkpoint(false), before, "reflow never resolves the choice")
	var second: Button = row.get_child(1)
	second.grab_focus()
	for frame: int in 4: await get_tree().process_frame
	assert_true(second.has_focus())
	assert_gt(choices.scroll_horizontal, 0, "focus exposes later options without stacking rows")
	await _screenshot("self-talk-choice-row-large")
	await _click(second)
	if not await _wait_line("line.scene.test.partner.lavinia.after"): return
	assert_eq(game.scene_choices, {"TEST.partner": "second"}, "existing owner commits exactly the selected answer")
	for frame: int in 12: await get_tree().process_frame
	assert_false(choices.visible, "resolved choices leave no stale buttons")
	print("SELF_TALK_CHOICES_COMPLETED")
