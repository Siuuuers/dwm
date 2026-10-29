extends "res://tests/ui/render_japanese_korean_ui.gd"
## Current production UI at the primary output size; no narrative or save mutations.
## Reuses the isolated desktop fixtures. Connected choices/library have separate tests.
const READING_FIXTURE := preload("res://tests/unit/test_witnessed_reading_rail.gd")
const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
var _visited: Dictionary = {}
var _sample_id := ""

func _run() -> void:
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://evidence/ui_readability")
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "evidence directory")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1920, 1080)
	viewport.size_2d_override = Vector2i(1280, 720)
	viewport.size_2d_override_stretch = true
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	await settle()
	_mount_locale_owners()
	for language: String in ["en", "zh_HK", "zh_CN", "ja", "ko"]:
		check(locale.set_locale(language).get("ok", false), "locale " + language)
		check(profile.set_preference(&"preferences.accessibility.text_size", 100).get("ok", false), "initial size")
		await _title_and_gallery(language)
		await _desktop_samples(language)
		await _history_samples(language)
	var report := {"ok": failures.is_empty(), "renderer": DisplayServer.get_name(),
		"physical_size": [1920, 1080], "logical_size": [1280, 720],
		"failures": failures, "captures": captures, "states": samples,
		"scope": "Real UI with isolated synthetic records; five locales, both font styles, 125/150%. Settings sheets, Save/Load, Shop, empty Gallery tabs, Mines app and History. Connected populated library, choices, Challenge and bottom controls use their existing separate fixtures. No native Windows display proof."}
	var file := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("UI_READABILITY_RESULT ", JSON.stringify({"ok": report.ok, "captures": captures, "failures": failures}))
	viewport.queue_free()
	await settle()
	locale.free()
	profile.free()
	for retained: Dictionary in retained_owners:
		root.add_child(retained.node)
		root.move_child(retained.node, retained.index)
	quit(0 if failures.is_empty() else 1)

func capture(surface: String, language: String, _percent: int, scene: Node) -> void:
	if surface not in ["gallery", "backup", "settings", "shop", "minesweeper"]: return
	var key := language + ":" + surface
	if _visited.has(key): return
	_visited[key] = true
	var previous_size: int = profile.get_preference(&"preferences.accessibility.text_size")
	var previous_style: String = profile.get_preference(&"preferences.accessibility.font_style")
	for style: String in ["pixel", "readable"]:
		check(profile.set_preference(&"preferences.accessibility.font_style", style).get("ok", false), "style " + style)
		for percent: int in [125, 150]:
			check(profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false), "size " + str(percent))
			await settle()
			if surface == "settings":
				var content: Control = desktop._cached_app_windows[&"settings"].settings_content
				for category: String in content.get_category_ids():
					content.select_category(category)
					await _record(surface + "-" + category, language, percent, style, scene)
					check(content.sheet_scroll.get_h_scroll_bar().max_value <= content.sheet_scroll.size.x + 0.5, "Settings needs no horizontal scrolling")
					var bar: VScrollBar = content.sheet_scroll.get_v_scroll_bar()
					if bar.max_value > bar.page + 0.5:
						content.sheet_scroll.scroll_vertical = int(bar.max_value)
						await _record(surface + "-" + category + "-bottom", language, percent, style, scene)
				content.select_category("language")
			elif surface == "gallery":
				for tab: Button in scene._gallery_tabs.get_children():
					check(tab.get_theme_font_size("font_size") == scene.theme.default_font_size, "Gallery tab honors its canonical text scale: " + tab.text)
				for tab: String in ["records", "artwork", "dialogue"]:
					scene._show_gallery_tab(tab)
					await _record(surface + "-" + tab, language, percent, style, scene)
			else:
				await _record(surface, language, percent, style, scene)
	check(profile.set_preference(&"preferences.accessibility.text_size", previous_size).get("ok", false), "restore size")
	check(profile.set_preference(&"preferences.accessibility.font_style", previous_style).get("ok", false), "restore style")
	await settle()

func _record(surface: String, language: String, percent: int, style: String, scene: Node) -> void:
	await settle()
	_sample_id = "%s-%s-%d-%s" % [surface, language, percent, style]
	var metrics: Array[Dictionary] = []
	_measure_readability(scene, metrics)
	check(not metrics.is_empty(), _sample_id + ": visible text exists")
	# Measure the full matrix; retain bounded Latin/pixel and CJK/readable captures.
	var filename := ""
	if (language == "en" and style == "pixel") or (language == "zh_HK" and style == "readable"):
		for frame: int in 2: await RenderingServer.frame_post_draw
		var image := viewport.get_texture().get_image()
		check(image.get_size() == Vector2i(1920, 1080), _sample_id + ": output size")
		filename = _sample_id + ".png"
		check(image.save_png(folder.path_join(filename)) == OK, _sample_id + ": capture")
		captures += 1
	samples.append({"id": _sample_id, "file": filename, "text_metrics": metrics})

func _measure_readability(node: Node, metrics: Array[Dictionary]) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	if node is Control:
		var visible_rect := Rect2(0, 0, 1280, 720)
		var parent := node.get_parent()
		while parent != viewport and parent != null:
			if parent is Control and parent.clip_contents:
				visible_rect = visible_rect.intersection(parent.get_global_rect())
			parent = parent.get_parent()
		if not visible_rect.intersects(node.get_global_rect()): return
	if node is Label and not node.text.is_empty():
		var label := node as Label
		var minimum := label.get_minimum_size()
		check(label.size.y + 0.5 >= minimum.y, _sample_id + ": label height " + str(label.get_path()))
		if label.autowrap_mode == TextServer.AUTOWRAP_OFF:
			check(label.size.x + 0.5 >= minimum.x, _sample_id + ": label width " + label.text)
		metrics.append({"node": str(label.get_path()), "text": label.text, "font_size": label.get_theme_font_size("font_size"),
			"size": [label.size.x, label.size.y], "minimum": [minimum.x, minimum.y], "rows": label.get_line_count()})
	elif node is Button and not node.text.is_empty():
		var button := node as Button
		var font := button.get_theme_font("font")
		var font_size := button.get_theme_font_size("font_size")
		var aperture := button.size.x - button.get_theme_stylebox("normal").get_minimum_size().x
		if button is OptionButton: aperture -= button.get_theme_icon("arrow").get_width() + button.get_theme_constant("h_separation")
		elif button is CheckBox: aperture -= button.get_theme_icon("unchecked").get_width() + button.get_theme_constant("h_separation")
		var width := font.get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
		if button.autowrap_mode == TextServer.AUTOWRAP_OFF:
			check(width <= aperture + 0.5, _sample_id + ": button width " + button.text)
		check(button.size.y + 0.5 >= button.get_minimum_size().y, _sample_id + ": button height " + button.text)
		metrics.append({"node": str(button.get_path()), "text": button.text, "font_size": font_size, "width": width, "aperture": aperture})
	elif node is RichTextLabel and not node.get_parsed_text().is_empty():
		if node.fit_content and not node.scroll_active:
			check(node.size.y + 0.5 >= node.get_content_height(), _sample_id + ": rich text height " + str(node.get_path()))
		metrics.append({"node": str(node.get_path()), "text": node.get_parsed_text(), "rows": node.get_line_count(), "content_height": node.get_content_height()})
	for child: Node in node.get_children():
		if not child is Window: _measure_readability(child, metrics)

func _history_samples(language: String) -> void:
	var input := READING_FIXTURE.InputOwner.new()
	root.add_child(input)
	var history := READING_FIXTURE.HISTORY.new()
	viewport.add_child(history)
	for style: String in ["pixel", "readable"]:
		check(profile.set_preference(&"preferences.accessibility.font_style", style).get("ok", false), "History style")
		for percent: int in [125, 150]:
			check(profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false), "History size")
			check(history.configure(CAPTION_THEME.build(language, percent, "AfterHours", false, "standard", false, 1, false, style), locale, input, func() -> bool: return true), "History configure")
			check(history.present([{"text": "A remembered caption, with punctuation and a second clause to exercise ordinary wrapping.", "content_locale": "en", "secondary_text": "記憶中的對白，包含標點與第二句，檢查正常換行。", "secondary_locale": "zh_HK"}]), "History present")
			await _record("history", language, percent, style, history)
	history.queue_free()
	input.queue_free()
	await settle()
	check(profile.set_preference(&"preferences.accessibility.font_style", "pixel").get("ok", false), "restore History style")
	check(profile.set_preference(&"preferences.accessibility.text_size", 100).get("ok", false), "restore History size")
