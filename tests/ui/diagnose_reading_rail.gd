extends "res://tests/ui/render_delivery_dialogue.gd"
## Cloud-only diagnostic: compare settled native labels with forced reshaping.

func _caption_capture(name: String, language: String, percent: int, offset: int, indices: Array) -> void:
	await super._caption_capture(name, language, percent, offset, indices)
	var rail: Control = caption.transport_rail
	var records: Array[Dictionary] = []
	for button: Button in rail.get_children():
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		records.append({"name": button.name, "text": button.text,
			"font": font.resource_path, "font_size": font_size,
			"width": font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x,
			"rect": str(button.get_rect()), "minimum": str(button.get_minimum_size()),
			"theme_font": rail.theme.default_font.resource_path})
	print("RAIL_DIAGNOSTIC ", name, " ", JSON.stringify(records))
	if language != "zh-CN": return
	var before := _native_state()
	for button: Button in rail.get_children():
		var text := button.text
		button.text = ""
		button.text = text
	await settle()
	for frame in 3: await RenderingServer.frame_post_draw
	DirAccess.make_dir_recursive_absolute(folder.path_join("diagnostic"))
	viewport.get_texture().get_image().save_png(folder.path_join("diagnostic/" + name + "-reshaped.png"))
	check(_native_state() == before, "diagnostic reshaping preserves narrative state")
