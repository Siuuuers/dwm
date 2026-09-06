extends "res://addons/gut/test.gd"

const ACTION := preload("res://scripts/ui/minesweeper/MinesweeperActionButton.gd")
const MS_THEME := preload("res://scripts/ui/minesweeper/MinesweeperTheme.gd")


func _button() -> Button:
	var viewport := SubViewport.new()
	viewport.size = Vector2i(640,480)
	add_child_autofree(viewport)
	var button: Button = ACTION.new()
	viewport.add_child(button)
	assert_true(button.configure("Reveal",MS_THEME.build("en",100,&"after_hours"),false))
	return button


func _confirm(button: Button, pressed: bool, echo: bool = false) -> void:
	var event := InputEventKey.new()
	event.keycode = KEY_ENTER
	event.pressed = pressed
	event.echo = echo
	button.get_viewport().push_input(event,true)


func test_released_input_requests_never_commit_selection() -> void:
	var button := _button()
	button.grab_focus()
	watch_signals(button)
	assert_false(button.toggle_mode)
	for index: int in 2:
		_confirm(button,true)
		assert_signal_emit_count(button,"pressed",index)
		_confirm(button,true,true)
		assert_signal_emit_count(button,"pressed",index)
		_confirm(button,false)
		assert_signal_emit_count(button,"pressed",index+1)
		assert_false(button.selected)
	button.present_state(true,true)
	assert_true(button.selected)
	_confirm(button,true)
	_confirm(button,false)
	assert_signal_emit_count(button,"pressed",3)
	assert_true(button.selected,"Repeated activation retains the owner's commitment.")
	button.present_state(true,false)
	assert_false(button.selected)


func test_disabled_retains_selection_copy_and_geometry_without_focus_or_activation() -> void:
	var button := _button()
	button.present_state(true,true)
	button.accessibility_description = "已选择"
	button.grab_focus()
	_confirm(button,true)
	watch_signals(button)
	button.present_state(false,true)
	assert_true(button.disabled)
	assert_true(button.selected)
	assert_false(button.has_focus())
	assert_eq(button.focus_mode,Control.FOCUS_NONE)
	assert_false(button.is_pressed())
	_confirm(button,false)
	var click := InputEventMouseButton.new()
	click.button_index = MOUSE_BUTTON_LEFT
	click.position = Vector2(20,20)
	click.pressed = true
	button.get_viewport().push_input(click,true)
	click.pressed = false
	button.get_viewport().push_input(click,true)
	assert_signal_emit_count(button,"pressed",0)
	assert_eq(button.public_copy,"Reveal")
	assert_eq(button.accessibility_description,"已选择")
	assert_eq(button.size,Vector2(128,48))
	button.present_state(true,true)
	assert_eq(button.focus_mode,Control.FOCUS_ALL)
	assert_true(button.selected)


func test_exact_allocations_and_native_face_insets() -> void:
	var button := _button()
	for width: int in [80,96,112,128,144,160]:
		for large: bool in [false,true]:
			assert_true(button.configure("Flag",button.theme,large,width))
			var height: int = 64 if large else 48
			var inset: int = 8 if large else 6
			assert_eq(button.size,Vector2(width,height))
			assert_eq(button.custom_minimum_size,button.size)
			assert_eq(button._face_rect(),Rect2(inset,inset,width-inset*2,height-inset*2))
			assert_eq(button._face_rect().position/2,(button._face_rect().position/2).round())
			assert_eq(button._face_rect().size/2,(button._face_rect().size/2).round())


func test_narrow_wrapping_retains_all_copy_at_full_locale_font_size() -> void:
	var button := _button()
	for locale: String in ["en","zh-CN","zh-HK"]:
		var copy := "Intermediate" if locale == "en" else "中等难度"
		for percent: int in [100,125,150]:
			var next_theme: Theme = MS_THEME.build(locale,percent,&"midnight")
			assert_true(button.configure(copy,next_theme,true,80))
			assert_eq(button.size.x,80.0)
			assert_gt(button._paragraph.get_line_count(),1)
			assert_same(button.theme.default_font,next_theme.default_font)
			assert_eq(button.get_theme_default_font_size(),int(percent*20/100.0))
			assert_gte(button.size.y,button._text_height+20)
			assert_eq(fmod(button.size.y,2.0),0.0)
			for baseline: float in button._baselines: assert_eq(fmod(baseline,2.0),0.0)
			for line: int in button._paragraph.get_line_count(): assert_lte(button._paragraph.get_line_width(line),56.0)
			assert_eq(button.public_copy,copy)
			assert_eq(button.accessibility_name,copy)


func test_invalid_configuration_preserves_selected_disabled_state_and_measurement() -> void:
	var button := _button()
	button.present_state(false,true)
	var retained_theme: Theme = button.theme
	var retained_paragraph: TextParagraph = button._paragraph
	for width: int in [0,79,81,100,127,162]:
		assert_false(button.configure("Changed",retained_theme,true,width))
	assert_false(button.configure("",retained_theme,true,80))
	assert_false(button.configure("Changed",null,true,80))
	var missing_role: Theme = retained_theme.duplicate()
	missing_role.clear_color(&"filed_focus_inner",&"Minesweeper")
	assert_false(button.configure("Changed",missing_role,true,80))
	assert_same(button.theme,retained_theme)
	assert_same(button._paragraph,retained_paragraph)
	assert_eq(button.size,Vector2(128,48))
	assert_eq(button.public_copy,"Reveal")
	assert_true(button.disabled)
	assert_true(button.selected)
	assert_true(button.configure("Flag",retained_theme,false,96))
	assert_true(button.disabled,"Configuration does not overwrite owner-published state.")
	assert_true(button.selected)

func test_english_word_breaks_preserve_plain_copy_full_font_and_fixed_bounds() -> void:
	var button := _button()
	for sample: Array in [["Intermediate",100,false,96,"Interme-"],["Expert",150,true,96,"Ex-"],
		["Reveal",150,true,96,"Re-"],["Assignments",150,true,160,"Assign-"]]:
		var next_theme: Theme = MS_THEME.build("en",sample[1],&"after_hours")
		assert_true(button.configure(sample[0],next_theme,sample[2],sample[3]))
		assert_eq(button.size.x,float(sample[3]))
		assert_same(button.theme.default_font,next_theme.default_font)
		assert_eq(button.get_theme_default_font_size(),next_theme.default_font_size)
		assert_eq(button.public_copy,sample[0])
		assert_eq(button.accessibility_name,sample[0])
		assert_almost_eq(button._paragraph.get_line_width(0),next_theme.default_font.get_string_size(sample[4],HORIZONTAL_ALIGNMENT_LEFT,-1,next_theme.default_font_size).x,0.01)
		for line: int in button._paragraph.get_line_count():
			var line_width: float = button._paragraph.get_line_width(line)
			var x: float = floorf((button.size.x-line_width)/4.0)*2.0
			assert_gte(x,button._face_rect().position.x+2,"Text starts inside the border.")
			assert_lte(x+line_width,button._face_rect().end.x-4,"Text ends before the Selected seam.")


func test_off_tree_reconfiguration_shrinks_to_measured_size_on_mount() -> void:
	var button: Button = ACTION.new()
	var next_theme: Theme = MS_THEME.build("en",100,&"after_hours")
	assert_true(button.configure("Intermediate",MS_THEME.build("en",150,&"after_hours"),true,160))
	assert_true(button.configure("Flag",next_theme,false,80))
	assert_eq(button.custom_minimum_size,Vector2(80,48))
	add_child_autofree(button)
	assert_eq(button.size,Vector2(80,48))
	assert_true(button.configure("Flag",next_theme,true,160))
	assert_eq(button.size,Vector2(160,64))
	assert_true(button.configure("Flag",next_theme,false,80))
	assert_eq(button.size,Vector2(80,48))
