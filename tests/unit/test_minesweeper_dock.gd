extends "res://addons/gut/test.gd"

const DOCK := preload("res://scripts/ui/minesweeper/MinesweeperDock.gd")
const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")
const COPY := preload("res://scripts/ui/minesweeper/MinesweeperChromeCopy.gd")

func _dock() -> Control:
	var dock: Control = DOCK.new()
	add_child_autofree(dock)
	assert_true(dock.configure())
	return dock

func test_desktop_actions_fit_without_board_or_separate_reveal_buttons() -> void:
	var dock := _dock()
	assert_eq(dock.size.x,800.0)
	assert_false(dock.buttons.has("reveal"))
	assert_false(dock.buttons.has("board"))
	for action: String in ["flag","drag","new_board","assignments","rules"]:
		assert_true(dock.buttons.has(action))
	for button: Button in dock.buttons.values():
		assert_true(Rect2(Vector2.ZERO,dock.size).encloses(Rect2(button.position,button.size)))
		assert_true(button.disabled)

func test_mode_selection_waits_for_owner_and_disabled_new_board_is_inert() -> void:
	var dock := _dock()
	watch_signals(dock)
	assert_true(dock.present(&"reveal",["reveal","flag","drag","assignments","rules"]))
	assert_false(dock.buttons.flag.button_pressed)
	assert_string_contains(dock.buttons.flag.accessibility_name,"Reveal")
	dock.buttons.flag.pressed.emit()
	assert_signal_emitted_with_parameters(dock,"action_requested",[&"flag"])
	assert_eq(dock.mode,&"reveal")
	assert_false(dock.buttons.flag.selected)
	dock.buttons.new_board.pressed.emit()
	assert_signal_emit_count(dock,"action_requested",1)
	assert_eq(dock.buttons.new_board.focus_mode,Control.FOCUS_NONE)
	assert_true(dock.present(&"flag",["reveal","flag","drag"]))
	assert_true(dock.buttons.flag.selected)
	assert_true(dock.buttons.flag.button_pressed)
	assert_string_contains(dock.buttons.flag.accessibility_name,"Flag")
	dock.buttons.flag.pressed.emit()
	assert_signal_emitted_with_parameters(dock,"action_requested",[&"reveal"])
	assert_eq(dock.mode,&"flag","The UI requests a toggle; the owning panel commits its mode.")
	assert_true(dock.present(&"drag",["reveal","flag","drag"]))
	dock.buttons.flag.pressed.emit()
	assert_signal_emitted_with_parameters(dock,"action_requested",[&"flag"])

func test_all_languages_keep_dock_centered_evenly_spaced_and_readable_at_full_font_size() -> void:
	var dock := _dock()
	for host: String in ["desktop_app","canonical_solo","canonical_pair"]:
		var actions: Array = ["flag","drag","new_board","assignments","rules"] if host == "desktop_app" else ["flag","drag","rules","pause"]
		for locale: String in ["en","zh-CN","zh-HK","ja","ko"]:
			for percent: int in [100,125,150]:
				var authored_theme: Theme = MS_THEME.build(locale,percent,&"midnight")
				for large: bool in [false,true]:
					var context := "%s %s %d%% large=%s" % [host,locale,percent,large]
					assert_true(dock.configure(host,locale,percent,large,&"midnight"),context)
					assert_eq(dock.buttons.keys(),actions,context)
					assert_eq(dock.size.x,800.0 if host == "desktop_app" else 960.0,context)
					var previous: Button
					var first_face: Rect2
					var gap := -1.0
					for action: String in actions:
						var button: Button = dock.buttons[action]
						var face: Rect2 = button._face_rect()
						face.position += button.position
						assert_same(button.theme.default_font,authored_theme.default_font,context)
						assert_eq(button.theme.default_font_size,authored_theme.default_font_size,context)
						assert_gte(button.size.x,64.0 if large else 48.0,context)
						assert_gte(button.size.y,64.0 if large else 48.0,context)
						assert_true(Rect2(Vector2.ZERO,dock.size).encloses(Rect2(button.position,button.size)),context)
						if previous == null:
							first_face = face
						else:
							assert_lte(previous.position.x+previous.size.x,button.position.x,context+" hit targets cannot overlap")
							var previous_face: Rect2 = previous._face_rect()
							previous_face.position += previous.position
							var next_gap: float = face.position.x-previous_face.end.x
							if gap < 0: gap = next_gap
							else: assert_almost_eq(next_gap,gap,2.0,context+" visible gaps")
						if action != "flag":
							assert_eq(button._paragraph.get_line_count(),1,context+" "+action+" stays on one line")
							assert_lte(button._paragraph.get_line_width(0),face.size.x,context+" caption fits its face")
						previous = button
					var last_face: Rect2 = previous._face_rect()
					last_face.position += previous.position
					assert_almost_eq(first_face.position.x,dock.size.x-last_face.end.x,2.0,context+" equal outer margins")

func test_locale_relayout_retains_focused_action_owner_selection_and_custody() -> void:
	var dock := _dock()
	watch_signals(dock)
	var requests := 0
	for host: String in ["desktop_app","canonical_solo","canonical_pair"]:
		assert_true(dock.configure(host))
		var actions: Array = ["reveal","flag","drag","new_board","assignments","rules"] if host == "desktop_app" else ["reveal","flag","drag","rules","pause"]
		assert_true(dock.present(&"drag",actions))
		for locale: String in ["en","zh-CN","zh-HK","ja","ko"]:
			dock.buttons.rules.grab_focus()
			assert_true(dock.configure(host,locale,150,true))
			assert_true(dock.buttons.rules.has_focus())
			assert_eq(dock.mode,&"drag")
			assert_true(dock.buttons.drag.selected)
			var copy: Dictionary = COPY.get_copy(locale)
			for action: String in dock.buttons:
				var button: Button = dock.buttons[action]
				assert_false(button.disabled)
				assert_eq(button.focus_mode,Control.FOCUS_ALL)
				assert_string_contains(button.accessibility_name,copy[action])
			dock.buttons.rules.pressed.emit()
			requests += 1
			assert_signal_emit_count(dock,"action_requested",requests)
			assert_signal_emitted_with_parameters(dock,"action_requested",[&"rules"])
			assert_true(dock.present(&"drag",actions,true))
			assert_true(dock.configure(host,locale,100,false))
			for button: Button in dock.buttons.values():
				assert_true(button.disabled)
				assert_eq(button.focus_mode,Control.FOCUS_NONE)
				button.pressed.emit()
			assert_signal_emit_count(dock,"action_requested",requests)
			assert_true(dock.present(&"drag",actions))

func test_custody_and_invalid_updates_preserve_selection_without_command() -> void:
	var dock := _dock()
	assert_true(dock.present(&"drag",["reveal","flag","drag"],true))
	assert_true(dock.buttons.drag.selected)
	for button: Button in dock.buttons.values(): assert_true(button.disabled)
	assert_false(dock.present(&"reveal",["leave"]))
	assert_false(dock.present(&"reveal",["rules","rules"]))
	assert_false(dock.present(&"guess",[]))
	assert_eq(dock.mode,&"drag")

func test_flag_icon_height_is_independent_of_its_hidden_localized_label() -> void:
	var flag: Button = preload("res://scripts/ui/minesweeper/MinesweeperFlagButton.gd").new()
	add_child_autofree(flag)
	for locale: String in ["en","zh-CN","zh-HK"]:
		var copy: Dictionary = preload("res://scripts/ui/minesweeper/MinesweeperChromeCopy.gd").get_copy(locale)
		for percent: int in [100,125,150]:
			for large: bool in [false,true]:
				var next_theme: Theme = preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd").build(locale,percent,&"after_hours")
				assert_true(flag.configure(copy.flag,next_theme,large,80))
				assert_eq(flag.get_combined_minimum_size().y,64.0 if large else 48.0)
				assert_eq(flag.accessibility_name,copy.flag)
