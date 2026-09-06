extends "res://addons/gut/test.gd"

const ROW := preload("res://scripts/ui/minesweeper/MinesweeperSheetRow.gd")
const RETURN := preload("res://scripts/ui/minesweeper/MinesweeperSheetReturn.gd")
const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")


func _row(copy: String = "Complete Beginner — Unclaimed", width: int = 400) -> Control:
	var row: Control = ROW.new()
	add_child_autofree(row)
	assert_true(row.configure(copy,MS_THEME.build("en",100,&"after_hours"),width,48))
	return row


func test_row_is_real_focusable_fact_without_activation_api() -> void:
	var row := _row()
	assert_eq(row.focus_mode,Control.FOCUS_ALL)
	assert_false(row is BaseButton)
	assert_false(row.has_signal("pressed"))
	assert_false(row.has_signal("activated"))
	row.grab_focus()
	assert_same(get_viewport().gui_get_focus_owner(),row)
	var confirm := InputEventAction.new()
	confirm.action = "ui_accept"
	confirm.pressed = true
	row._gui_input(confirm)
	confirm.pressed = false
	row._gui_input(confirm)
	assert_eq(row.public_copy,"Complete Beginner — Unclaimed")
	assert_eq(row.accessibility_name,row.public_copy)
	assert_same(get_viewport().gui_get_focus_owner(),row)


func test_pointer_and_touch_transfer_inspection_focus() -> void:
	var first := _row()
	var second := _row("Flag marks or unmarks a covered cell")
	first.grab_focus()
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.pressed = true
	second._gui_input(click)
	assert_same(get_viewport().gui_get_focus_owner(),second)
	var touch := InputEventScreenTouch.new()
	touch.pressed = true
	first._gui_input(touch)
	assert_same(get_viewport().gui_get_focus_owner(),first)


func test_multiline_copy_preserves_full_locale_font_and_measured_bounds() -> void:
	var row := _row()
	for locale: String in ["en","zh-CN","zh-HK"]:
		for percent: int in [100,125,150]:
			var copy := "Reveal opens a covered cell. Flag marks or unmarks a covered cell."
			if locale != "en": copy = "揭开一个覆盖的方格。旗帜标记或取消标记一个覆盖的方格。"
			var next_theme: Theme = MS_THEME.build(locale,percent,&"midnight")
			assert_true(row.configure(copy,next_theme,160,48))
			assert_gt(row._paragraph.get_line_count(),1)
			assert_same(row.theme.default_font,next_theme.default_font)
			assert_eq(row.get_theme_default_font_size(),int(percent*20/100.0))
			assert_eq(row.custom_minimum_size.x,160.0)
			assert_gte(row.custom_minimum_size.y,row._text_height+24)
			assert_eq(fmod(row.custom_minimum_size.y,2.0),0.0)
			for baseline: float in row._baselines: assert_eq(fmod(baseline,2.0),0.0)
			for line: int in row._paragraph.get_line_count(): assert_lte(row._paragraph.get_line_width(line),136.0)
			assert_eq(row.accessibility_name,copy)


func test_invalid_row_configuration_retains_every_public_state() -> void:
	var row := _row()
	var retained_theme: Theme = row.theme
	var retained_size: Vector2 = row.custom_minimum_size
	var retained_paragraph: TextParagraph = row._paragraph
	assert_false(row.configure("",retained_theme,400,48))
	assert_false(row.configure("Changed",null,400,48))
	assert_false(row.configure("Changed",Theme.new(),400,48))
	assert_false(row.configure("Changed",retained_theme,399,48))
	assert_false(row.configure("Changed",retained_theme,24,48))
	assert_false(row.configure("Changed",retained_theme,400,47))
	assert_same(row.theme,retained_theme)
	assert_same(row._paragraph,retained_paragraph)
	assert_eq(row.custom_minimum_size,retained_size)
	assert_eq(row.public_copy,"Complete Beginner — Unclaimed")
	assert_eq(row.accessibility_name,row.public_copy)


func test_return_has_fixed_width_native_release_activation_and_growing_height() -> void:
	var button: Button = RETURN.new()
	add_child_autofree(button)
	for large: bool in [false,true]:
		assert_true(button.configure("Return",MS_THEME.build("en",100,&"after_hours"),large))
		assert_eq(button.custom_minimum_size,Vector2(128,64 if large else 48))
		assert_eq(button.action_mode,BaseButton.ACTION_MODE_BUTTON_RELEASE)
		assert_eq(button.focus_mode,Control.FOCUS_ALL)
	assert_true(button.configure("Return to the worksheet",MS_THEME.build("en",150,&"midnight"),false))
	assert_eq(button.custom_minimum_size.x,128.0)
	assert_gt(button.custom_minimum_size.y,48.0)
	assert_gt(button._paragraph.get_line_count(),1)
	assert_eq(button.get_theme_default_font_size(),30)
	button.grab_focus()
	assert_same(get_viewport().gui_get_focus_owner(),button)
	assert_eq(button.accessibility_name,"Return to the worksheet")
	assert_eq(button.text,"","Custom shaped copy owns measurement and drawing.")


func test_invalid_return_configuration_is_atomic() -> void:
	var button: Button = RETURN.new()
	add_child_autofree(button)
	var retained_theme: Theme = MS_THEME.build("en",100,&"after_hours")
	assert_true(button.configure("Return",retained_theme,false))
	var retained_paragraph: TextParagraph = button._paragraph
	assert_false(button.configure("",retained_theme,true))
	assert_false(button.configure("Changed",null,true))
	assert_false(button.configure("Changed",Theme.new(),true))
	assert_same(button.theme,retained_theme)
	assert_same(button._paragraph,retained_paragraph)
	assert_eq(button.custom_minimum_size,Vector2(128,48))
	assert_eq(button.public_copy,"Return")
	assert_eq(button.accessibility_name,"Return")


func test_native_return_input_activates_on_release_and_ignores_repeat() -> void:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(320,240)
	add_child_autofree(viewport)
	var button: Button = RETURN.new()
	viewport.add_child(button)
	assert_true(button.configure("Return",MS_THEME.build("en",100,&"after_hours"),false))
	button.grab_focus()
	watch_signals(button)
	var key := InputEventKey.new()
	key.keycode = KEY_ENTER
	key.pressed = true
	viewport.push_input(key,true)
	assert_signal_emit_count(button,"pressed",0)
	key.echo = true
	viewport.push_input(key,true)
	assert_signal_emit_count(button,"pressed",0)
	key.echo = false
	key.pressed = false
	viewport.push_input(key,true)
	assert_signal_emit_count(button,"pressed",1)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(20,20)
	click.pressed = true
	click.double_click = true
	viewport.push_input(click,true)
	click.pressed = false
	click.double_click = false
	viewport.push_input(click,true)
	assert_signal_emit_count(button,"pressed",1,"The second click in a double click does not activate.")


func test_reconfigured_controls_shrink_to_measured_bounds_on_mount_and_in_tree() -> void:
	var next_theme: Theme = MS_THEME.build("en",100,&"after_hours")
	var row: Control = ROW.new()
	assert_true(row.configure("Complete Beginner — Unclaimed",next_theme,768,64))
	assert_true(row.configure("Complete Beginner — Unclaimed",next_theme,720,48))
	assert_eq(row.custom_minimum_size.x,720.0)
	add_child_autofree(row)
	assert_eq(row.size,row.custom_minimum_size,"Mount discards the old wider off-tree minimum cache.")
	assert_true(row.configure("Complete Beginner — Unclaimed",next_theme,680,48))
	assert_eq(row.size,row.custom_minimum_size,"In-tree shrink is immediate.")
	var button: Button = RETURN.new()
	assert_true(button.configure("Return to the worksheet",MS_THEME.build("en",150,&"after_hours"),true))
	assert_gt(button.custom_minimum_size.y,48.0)
	assert_true(button.configure("Return",next_theme,false))
	add_child_autofree(button)
	assert_eq(button.size,Vector2(128,48),"Mount discards the taller off-tree minimum cache.")
	assert_true(button.configure("Return",next_theme,true))
	assert_eq(button.size,Vector2(128,64))
	assert_true(button.configure("Return",next_theme,false))
	assert_eq(button.size,Vector2(128,48))
