extends "res://tests/ui/render_delivery_dialogue.gd"
## Production text controls with sampled committed prose; no story-state acceptance.
## Prefixes measure this corpus, never a universal per-language character limit.
const STORY := preload("res://scripts/localization/StoryLocalization.gd")
const TYPE := preload("res://scripts/ui/UiTypography.gd")
const SAMPLE_IDS := ["line.Day1.one", "line.Day1.007", "line.Day1.022"]
var measurements: Array[Dictionary] = []

func _run() -> void:
	if folder.is_empty(): folder = ProjectSettings.globalize_path("res://.godot/ci/readability")
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "evidence directory")
	check(DisplayServer.get_name() != "headless", "real renderer required")
	if DisplayServer.get_name() == "headless":
		quit(1)
		return
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.size_2d_override = Vector2i(1280, 720)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	root.add_child(viewport)
	locale = QUICK.CatalogLocale.new()
	viewport.add_child(locale)
	await _mount_dialogue()
	if not is_instance_valid(caption):
		quit(1)
		return
	for child: Node in viewport.get_children():
		if child is Label: child.hide()
	caption.set_process(false)
	caption.caption_text.set_process(false)
	caption.caption_text.show()
	caption.caption_text.visible_characters = -1
	caption._retained.clear()
	for language: String in STORY.LOCALES:
		for style: String in ["pixel", "readable"]:
			for percent: int in [125, 150]:
				for dual: bool in [false, true]:
					await _measure_profile(language, style, percent, dual)
	var report := {"ok": failures.is_empty(), "failures": failures, "renderer": DisplayServer.get_name(),
		"godot": Engine.get_version_info().string, "revision": OS.get_environment("GITHUB_SHA"),
		"render_pixels": [1920, 1080], "logical_viewport": [1280, 720], "render_scale": 1.5,
		"monitor_pixels": [DisplayServer.screen_get_size().x, DisplayServer.screen_get_size().y],
		"window_client_pixels": [root.size.x, root.size.y],
		"screen_scale": DisplayServer.screen_get_scale(), "captures": captures, "profiles": measurements,
		"scope": "Production caption and thought owners, projected committed corpus; 1920x1080 offscreen rendering, not native Windows display-mode proof. Boundary text is returned for grapheme counting; source_codepoints is not a user-visible character count."}
	var file := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	check(file != null, "results file")
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("READABILITY_MEASUREMENTS_VERIFIED profiles=", measurements.size(), " captures=", captures)
	await _restore_runtime()
	viewport.queue_free()
	await settle()
	quit(0 if failures.is_empty() and measurements.size() == 40 and captures == 40 else 1)

func _measure_profile(language: String, style: String, percent: int, dual: bool) -> void:
	var secondary := "zh_HK" if language == "en" else "en"
	check(locale.present(language), "catalogue locale " + language)
	check(caption.transport_rail.bind_localization(locale), "matching rail locale")
	caption._dual_enabled = dual
	caption._bilingual = {"content_locale": language, "secondary_locale": secondary, "secondary_text": ""}
	check(caption.configure_presentation(language, percent, "AfterHours", false, "standard", false, 1, style), "presentation tuple")
	await settle()
	var detail := {"locale": language, "font_style": style, "text_percent": percent, "dual": dual,
		"secondary_locale": secondary if dual else "", "corpus": "res://localization/story/" + language + ".json",
		"corpus_sha256": FileAccess.get_sha256("res://localization/story/" + language + ".json"),
		"reference_layout": "Default 480-unit portrait pane; one-row caption without a scrollbar gutter",
		"caption": [], "thought": []}
	var corpus := STORY.catalog(language)
	for index: int in SAMPLE_IDS.size():
		var parts := PackedStringArray()
		for offset: int in SAMPLE_IDS.size(): parts.append(str(corpus[SAMPLE_IDS[(index + offset) % SAMPLE_IDS.size()]]))
		var text := " ".join(parts)
		# Long mixed-word/punctuation samples cross a real row boundary in every font.
		var primary: RichTextLabel = caption.caption_text
		primary.text = "."
		caption._layout_stack()
		primary.text = STORY.display_markup(text)
		var reading := _caption_measure(primary, text, language, style, percent)
		reading["source_ids_rotated_from"] = SAMPLE_IDS[index]
		detail.caption.append(reading)
		var thought: Control = caption.self_talk
		thought.project([{"id": SAMPLE_IDS[index], "text": text, "content_locale": language}], 0)
		var thought_reading := _thought_measure(thought, text, language, style, percent)
		thought_reading["source_ids_rotated_from"] = SAMPLE_IDS[index]
		detail.thought.append(thought_reading)
	# Capture representative boundary prefixes together using the actual layout.
	var primary_text: String = detail.caption[0].one_row.text
	var thought_text: String = detail.thought[0].one_row.text
	var secondary_text := str(STORY.catalog(secondary)[SAMPLE_IDS[0]]) if dual else ""
	caption._bilingual.secondary_text = secondary_text
	caption.caption_text.text = STORY.display_markup(primary_text)
	caption._layout_stack()
	caption._layout_self_talk()
	caption.self_talk.project([{"id": SAMPLE_IDS[0], "text": thought_text, "content_locale": language,
		"secondary_text": secondary_text, "secondary_locale": secondary}], 0)
	await settle()
	detail["visible_thought_rows"] = caption.self_talk.get_projection().visible_rows
	detail["thought_total_rows"] = caption.self_talk.get_projection().row_count
	detail["secondary_caption_rows"] = caption.secondary_caption.get_line_count() if dual else 0
	detail["secondary_caption_text"] = secondary_text
	detail["caption_rect"] = str(caption.caption_text.get_rect())
	detail["thought_rect"] = str(caption.self_talk.get_rect())
	var filename := "%s-%s-%d-%s.png" % [language, style, percent, "dual" if dual else "single"]
	detail["capture"] = filename
	await RenderingServer.frame_post_draw
	var pixels := viewport.get_texture().get_image()
	check(pixels.get_size() == Vector2i(1920, 1080), "physical capture dimensions")
	check(pixels.save_png(folder.path_join(filename)) == OK, "capture saved")
	captures += 1
	measurements.append(detail)

func _font_record(language: String, style: String, percent: int, font: Font, font_size: int, text: String, width: float) -> Dictionary:
	var line := TextLine.new()
	line.add_string(text, font, font_size, language)
	var fallbacks := PackedStringArray()
	for fallback: Font in font.fallbacks: fallbacks.append(fallback.resource_path)
	return {"text": text, "font": TYPE.font(language, percent, style).resource_path, "fallbacks": fallbacks,
		"font_size": font_size, "available_width": width, "unwrapped_width": line.get_size().x,
		"width_use_percent": 100.0 * line.get_size().x / width}

func _caption_measure(leaf: RichTextLabel, text: String, language: String, style: String, percent: int) -> Dictionary:
	var material := leaf.get_theme_stylebox("normal")
	var width := leaf.size.x - material.get_content_margin(SIDE_LEFT) - material.get_content_margin(SIDE_RIGHT)
	var result := _font_record(language, style, percent, leaf.get_theme_font("normal_font"), leaf.get_theme_font_size("normal_font_size"), text, width)
	result["wrapped_rows"] = leaf.get_line_count()
	result["content_height"] = leaf.get_content_height()
	var low := 0
	var high := text.length()
	while low < high:
		var middle := (low + high + 1) / 2
		leaf.text = STORY.display_markup(text.substr(0, middle))
		if leaf.get_line_count() <= 1: low = middle
		else: high = middle - 1
	leaf.text = STORY.display_markup(text.substr(0, low + 1))
	result["one_row"] = {"text": text.substr(0, low), "source_codepoints": low, "next_prefix_rows": leaf.get_line_count()}
	check(low > 0 and low < text.length() and leaf.get_line_count() > 1, "caption corpus crosses one-row boundary")
	leaf.text = STORY.display_markup(text)
	return result

func _thought_measure(panel: Control, text: String, language: String, style: String, percent: int) -> Dictionary:
	var result := _font_record(language, style, percent, TYPE.story_font(language, percent, style), panel._font_size, text, panel.size.x)
	result["wrapped_rows"] = panel._paragraphs[0].get_line_count()
	var low := 0
	var high := text.length()
	while low < high:
		var middle := (low + high + 1) / 2
		panel.project([{"id": "measurement", "text": text.substr(0, middle), "content_locale": language}], 0)
		if panel._paragraphs[0].get_line_count() <= 1: low = middle
		else: high = middle - 1
	panel.project([{"id": "measurement", "text": text.substr(0, low + 1), "content_locale": language}], 0)
	result["one_row"] = {"text": text.substr(0, low), "source_codepoints": low, "next_prefix_rows": panel._paragraphs[0].get_line_count()}
	check(low > 0 and low < text.length() and panel._paragraphs[0].get_line_count() > 1, "thought corpus crosses one-row boundary")
	return result
