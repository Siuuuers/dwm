extends "res://tests/integration/authored_week_child.gd"

func test_caption_defers_recovery_styling_until_requested() -> void:
	_phase = "create"
	if not _setup_authored(false): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1, _expected[0].line_id): return
	assert_true(profile.set_preference(&"preferences.accessibility.high_contrast", true).get("ok", false))
	var caption: Node = _caption()
	var recovery: Control = caption.recovery_overlay
	assert_false(recovery._configured)
	assert_false(recovery.visible)
	caption._configure_recovery_presentation()
	assert_false(recovery._configured)
	caption._reading_recovery = {"stage": &"preference"}
	caption._configure_recovery_presentation()
	caption._reading_recovery.clear()
	assert_true(recovery._configured)
	assert_true(recovery.present(true, true))
	await get_tree().process_frame
	assert_true(recovery.visible)
	assert_false(recovery.retry_button.disabled)
	assert_false(recovery.cancel_button.disabled)
	assert_true(recovery.retry_button.has_focus())
	assert_eq(recovery.retry_button.text, get_node("/root/LocalizationManager").t("witnessed.recovery.retry"))
	assert_eq(recovery.theme.get_color("paper_ink", "Settings"), preload("res://scripts/ui/SettingsTheme.gd").build("en", 125, &"after_hours", true).get_color("paper_ink", "Settings"))
	recovery.dismiss()
	caption._reading_recovery.clear()
