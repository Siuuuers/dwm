extends "res://tests/integration/test_witnessed_caption_runtime.gd"

func test_trimmed_style_choice() -> void:
	if not _mount(): return
	assert_eq(layout.get_layers().size(), 5)
	runtime.start(_timeline("Choose now.\n- Continue\n\tSelected branch.\nreturn"))
	await _settle()
	_assert_single_text()
	assert_true(get_tree().get_nodes_in_group("dialogic_text_input").is_empty())
	caption.caption_text.finish_text()
	await _settle()
	var buttons := get_tree().get_nodes_in_group("dialogic_choice_button")
	var selected: Button
	for button: Node in buttons:
		if button is Button and button.is_visible_in_tree() and not button.disabled:
			selected = button
			break
	assert_not_null(selected, "native choice remains available")
	if selected == null: return
	await get_tree().create_timer(0.25).timeout
	selected._pressed()
	await _settle()
	assert_eq(caption.caption_text.get_parsed_text(), "Selected branch.")
