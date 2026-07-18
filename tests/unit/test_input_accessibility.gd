extends "res://addons/gut/test.gd"
# Input + accessibility unit tests (prompt_docs/requirements/verification.md).

const REQUIRED_ACTIONS := [
	"ui_accept", "ui_cancel", "ui_up", "ui_down", "ui_left", "ui_right",
	"game_quick_save", "game_quick_load", "game_skip_text", "game_toggle_auto",
	"game_hint", "game_new_board", "game_close_window", "game_next_tab", "game_prev_tab",
	"game_page_next", "game_page_prev", "game_open_settings", "game_open_schedule", "game_open_contacts",
]


func before_each() -> void:
	GameState.reset_game()
	InputManager.ensure_default_input_map()


func test_required_actions_exist() -> void:
	for action in REQUIRED_ACTIONS:
		assert_true(InputMap.has_action(action), "input action exists: %s" % action)


func test_make_button_focusable() -> void:
	var b := Button.new()
	b.focus_mode = Control.FOCUS_NONE
	InputManager.make_button_focusable(b)
	assert_eq(b.focus_mode, Control.FOCUS_ALL)
	b.free()


func test_focus_first_control_finds_button() -> void:
	var root := Control.new()
	var btn := Button.new()
	btn.focus_mode = Control.FOCUS_ALL
	root.add_child(btn)
	add_child(root)
	var found := InputManager.focus_first_control(root)
	assert_true(found, "focus_first_control finds a focusable button")
	root.queue_free()


func test_rebind_unknown_action_safe() -> void:
	var res := InputManager.rebind_action("no_such_action", InputEventKey.new())
	assert_false(bool(res["ok"]), "rebinding an unknown action fails safely")


func test_permanent_settings_are_not_owned_by_game_state() -> void:
	assert_false("settings" in GameState)
	assert_false("audio_state" in GameState)
	assert_false("seen_endings" in GameState)


func test_accessibility_apply_no_crash() -> void:
	var root := Control.new()
	var lbl := Label.new()
	root.add_child(lbl)
	add_child(root)
	AccessibilityManager.apply_font_scale(root, 1.5)
	AccessibilityManager.apply_high_contrast(root, true)
	AccessibilityManager.apply_reduced_motion_to_tree(root)
	AccessibilityManager.apply_settings_to_tree(root)
	LocalizationManager.refresh_tree(root)
	assert_true(true, "accessibility + localization application did not crash")
	root.queue_free()


func test_minimum_click_size_positive() -> void:
	var size := AccessibilityManager.get_minimum_click_size()
	assert_true(size.x > 0 and size.y > 0, "minimum click size is a positive target")
