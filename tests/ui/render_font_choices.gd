extends "res://tests/ui/render_japanese_korean_ui.gd"
## Exercise the real font selector and mounted production surfaces with isolated owners.
## Existing localization render helpers provide bootstrap isolation, never player data.
const TYPOGRAPHY := preload("res://scripts/ui/UiTypography.gd")
const ACTION_BUTTON := preload("res://scripts/ui/minesweeper/MinesweeperActionButton.gd")
const FONT_STYLE := &"preferences.accessibility.font_style"
const LANGUAGES := ["en", "zh_CN", "zh_HK", "ja", "ko"]
const STYLES := ["pixel", "readable"]
const FONT_CHOICES_CAPTURE_COUNT := 30

var active_style := "pixel"
var settings_content: Control
var mine_app: Control
var mine_port: RefCounted
var initial_cells: Array
var grid_identity := 0

func _run() -> void:
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://evidence/font_choices")
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "evidence directory")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	await settle()
	_mount_locale_owners()
	check(profile.get_preference(FONT_STYLE) == "pixel", "fresh profile defaults to Pixel")
	check(profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false), "150 percent text")
	check(profile.set_preference(&"preferences.accessibility.large_targets", true).get("ok", false), "large pointer targets")
	for language: String in LANGUAGES:
		if not check(locale.set_locale(language).get("ok", false), language + ": actual locale commit"): break
		await _mount_font_desktop()
		for font_style: String in STYLES:
			await _choose_font(font_style)
			await _capture_font("settings-accessibility", language, main)
			check(desktop.return_home().get("ok", false), "leave Settings through Home")
			check(desktop.open_app(&"minesweeper").get("ok", false), "return to same board")
			await settle()
			_check_board_preserved()
			desktop.app_scroll.ensure_control_visible(mine_app.panel.dock)
			await settle()
			for issue: String in DESKTOP_RENDER.mines_control_layout_failures(mine_app.panel): check(false, font_style + ": " + issue)
			_check_mines_footer(mine_app.panel.worksheet)
			check(desktop.app_scroll.get_global_rect().grow(0.01).encloses(mine_app.panel.dock.get_global_rect()), "dock remains reachable")
			await _capture_font("minesweeper", language, main)
		main.hide()
		var gallery: Control = GALLERY.instantiate()
		viewport.add_child(gallery)
		await _capture_font("gallery", language, gallery)
		gallery.queue_free()
		await settle()
		await _readable_caption(language)
		main.queue_free()
		await settle()
	check(samples.size() == FONT_CHOICES_CAPTURE_COUNT, "all 30 font-choice states checked")
	if DisplayServer.get_name() != "headless": check(captures == FONT_CHOICES_CAPTURE_COUNT, "all 30 native captures")
	var report := {"ok": failures.is_empty(), "renderer": DisplayServer.get_name(),
		"samples": samples.size(), "captures": captures, "failures": failures, "states": samples,
		"fixture": "Real Settings selector, Profile/Localization and production desktop, Gallery and witnessed captions. Synthetic public board and English dialogue; no player commands."}
	var file := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	print("FONT_CHOICES_RENDER_VERIFIED " if failures.is_empty() and captures == FONT_CHOICES_CAPTURE_COUNT else "FONT_CHOICES_GEOMETRY_CHECKED ", JSON.stringify(report))
	viewport.queue_free()
	await settle()
	locale.free()
	profile.free()
	for retained: Dictionary in retained_owners:
		root.add_child(retained.node)
		root.move_child(retained.node, retained.index)
	quit(0 if failures.is_empty() else 1)

func _mount_font_desktop() -> void:
	main = SPLIT.MAIN.instantiate()
	desktop = SPLIT.DESKTOP.instantiate()
	desktop.set_script(SHELL.IsolatedDesktop)
	desktop.configure_run_configuration(SHELL.RunConfigurationFixture.new())
	main._computer_desktop_instance = desktop
	main.get_node("%ComputerPanel").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	main.get_node("%ComputerPanel").add_child(desktop)
	viewport.add_child(main)
	check(main.get_node_or_null("%StatHud") == null, "mounted shell has no retired HUD")
	var host := SCHEDULE.HOST.new()
	host.reset(1)
	check(desktop.configure_contacts(ContactPort.new(), locale, profile, host).get("ok", false), "desktop locale/profile owners")
	desktop._foreground_eligible = true
	main.get_node("RootHBox").set_angela_width(320)
	var fixture := MINES.new()
	mine_port = SPLIT.ShellMinesweeperPort.new()
	mine_port.desktop_owner = desktop
	mine_port.view = fixture._view()
	mine_port.live_view = mine_port.view.duplicate(true)
	fixture.free()
	check(desktop.configure_minesweeper(mine_port, locale, profile).get("ok", false), "Mines owners")
	var opened: Dictionary = desktop.open_app(&"minesweeper")
	if not check(opened.get("ok", false), "Mines opens"): return
	mine_app = opened.value.app
	await settle()
	initial_cells = mine_port.view.board.cells.duplicate(true)
	grid_identity = mine_app.panel.worksheet.grid.get_instance_id()
	var settings: Control = preload("res://scenes/apps/SettingsApp.tscn").instantiate()
	settings_content = settings.get_node("SettingsContent")
	settings_content.configure_services({"profile": profile, "localization": locale, "volume": SETTINGS.MemoryVolume.new(),
		"audio": null, "tts": null, "input": null, "window": null})
	desktop.app_window_host.add_child(settings)
	desktop._cached_app_windows[&"settings"] = settings

func _choose_font(font_style: String) -> void:
	check(desktop.return_home().get("ok", false), "leave Mines through Home")
	if not check(desktop.open_app(&"settings").get("ok", false), "open actual Settings"): return
	settings_content.select_category("accessibility")
	await settle()
	var picker: OptionButton = settings_content.control_for(FONT_STYLE)
	if not check(picker != null and picker.item_count == 2, "actual two-choice font picker"): return
	var selected := -1
	for index in picker.item_count:
		if picker.get_item_metadata(index) == font_style: selected = index
	if not check(selected >= 0, "font style exists in picker"): return
	picker.grab_focus()
	picker.select(selected)
	picker.item_selected.emit(selected)
	await settle()
	active_style = font_style
	check(profile.get_preference(FONT_STYLE) == font_style, "selector commits actual font preference")
	check(picker.has_focus(), "font selector keeps focus after presentation refresh")
	check(picker.get_item_metadata(picker.selected) == font_style, "selector reflects committed style")
	var restored := PROFILE.new()
	check(restored.initialize(profile._storage).get("ok", false), "reopen persisted profile")
	check(restored.get_preference(FONT_STYLE) == font_style, "font choice survives profile reload")
	restored.free()
	settings_content.sheet_scroll.ensure_control_visible(picker)
	await settle()
	check(settings_content.sheet_scroll.get_global_rect().grow(0.01).encloses(picker.get_global_rect()), "font selector is visible")
	_check_language_names(settings_content)

func _check_language_names(content: Control) -> void:
	var option: OptionButton = content.control_for(&"preferences.language.primary_locale_id")
	check(option.item_count == 5, "five native language names")
	var font := option.get_theme_font("font")
	for index in option.item_count:
		for character: String in option.get_item_text(index):
			if not character.strip_edges().is_empty(): check(font.has_char(character.unicode_at(0)), "language option glyph " + character)

func _check_board_preserved() -> void:
	check(desktop._cached_app_windows[&"minesweeper"] == mine_app, "font choice keeps mounted Mines app")
	check(mine_app.panel.worksheet.grid.get_instance_id() == grid_identity, "font choice keeps board view identity")
	check(mine_port.view.board.cells == initial_cells, "font choice keeps public board cells")
	check(mine_port.commands.is_empty(), "presentation change dispatches no game commands")
	check(mine_app.last_result.get("ok", false), "Mines accepts selected font style")

func _check_desktop_chrome() -> void:
	var bounds: Rect2 = desktop.desktop_canvas.get_global_rect()
	var height: float = 64.0 * desktop.desktop_canvas.scale.y
	var footer := Rect2(bounds.position + Vector2(0, bounds.size.y - height), Vector2(bounds.size.x, height))
	var clock: Label = desktop.clock_label
	check(clock.visible and clock.is_visible_in_tree(), "clock remains visible in every app")
	check(clock.get_index() == clock.get_parent().get_child_count() - 1, "clock is rightmost footer child")
	check(footer.grow(0.01).encloses(clock.get_global_rect()), "clock stays inside visible footer")
	if desktop.app_footer_slot.is_visible_in_tree():
		check(not clock.get_global_rect().intersects(desktop.app_footer_slot.get_global_rect()), "clock does not overlap app controls")
	check(not desktop.status_label.visible, "no desktop presentation failure")

func _check_mines_footer(worksheet: Control) -> void:
	var canvas: Rect2 = desktop.desktop_canvas.get_global_rect()
	var height: float = 64.0 * desktop.desktop_canvas.scale.y
	var footer := Rect2(canvas.position + Vector2(0, canvas.size.y - height), Vector2(canvas.size.x, height))
	check(footer.grow(0.01).encloses(worksheet.view_controls.get_global_rect()), "Mines controls stay inside the scaled footer")
	var fit: Button = worksheet.zoom_controls[1]
	check(footer.grow(0.01).encloses(fit.get_global_rect()), "Mines Fit button stays inside footer and viewport")
	check(fit._paragraph.get_line_count() == 1, "Mines compact Fit label stays on one line")
	var top := floorf((fit.size.y - fit._text_height) / 4.0) * 2.0
	check(top >= 0 and top + fit._text_height <= fit.size.y, "Mines Fit paragraph stays inside button")
	check(fit._paragraph.get_line_width(0) <= fit.size.x - 2 * fit._inset, "Mines Fit paragraph width fits")

func _capture_font(surface: String, language: String, scene: Node) -> void:
	await settle()
	check(locale.get_locale() == language, surface + ": active locale")
	check(profile.get_preference(FONT_STYLE) == active_style, surface + ": active style")
	var expected: Font = TYPOGRAPHY.font(language, 150, active_style)
	check(expected != null, surface + ": selected resource exists")
	if scene == main:
		_check_desktop_chrome()
		check(_base_face(desktop.theme.default_font) == expected, surface + ": desktop uses selected face")
	var measured := {"labels": 0, "missing_glyphs": []}
	_measure_text(scene, measured)
	check(measured.labels > 0, surface + ": visible production text")
	check(measured.missing_glyphs.is_empty(), surface + ": glyph coverage " + str(measured.missing_glyphs))
	var filename := "%s-%s-%s-150.png" % [active_style, language.replace("_", "-"), surface]
	samples.append({"locale": language, "font_style": active_style, "percent": 150, "large_targets": true,
		"surface": surface, "font_resource": expected.resource_path if expected != null else "", "visible_text_nodes": measured.labels, "file": filename})
	if DisplayServer.get_name() != "headless":
		for frame in 3: await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		check(not pixels.is_empty() and pixels.get_size() == Vector2i(1280, 720), filename + ": native image")
		if check(pixels.save_png(folder.path_join(filename)) == OK, filename + ": saved PNG"): captures += 1
	print("FONT_CHOICES_SAMPLE ", language, " ", active_style, " ", surface)

func _base_face(font: Font) -> Font:
	while font is FontVariation: font = font.base_font
	return font

func _measure_text(node: Node, result: Dictionary) -> void:
	if node is Control and not node.is_visible_in_tree(): return
	var copy := ""
	var font: Font
	if node is RichTextLabel:
		copy = node.get_parsed_text()
		font = node.get_theme_font("normal_font")
	elif node is Label or node is Button:
		copy = node.text
		font = node.get_theme_font("font")
		if node.get_script() == ACTION_BUTTON: copy = node.public_copy
	if not copy.is_empty() and node.get_global_rect().intersects(Rect2(0, 0, 1280, 720)):
		result.labels += 1
		check(not copy.begins_with("[missing:") and not copy.begins_with("[format_error:"), "catalog copy " + copy)
		var face := _base_face(font)
		var family := face.get_font_name().to_lower() if face != null else ""
		# Icon-only navigation keys may use their own glyph face; visible words must use the chosen family.
		var words := false
		for character: String in copy:
			var code := character.unicode_at(0)
			words = words or (code >= 0x30 and code <= 0x39) or (code >= 0x41 and code <= 0x7a) or code >= 0x3000
			if not character.strip_edges().is_empty() and (font == null or not font.has_char(code)):
				var detail := "%s U+%04X" % [node.name, code]
				if detail not in result.missing_glyphs: result.missing_glyphs.append(detail)
		if words:
			check(family.contains("fusion") if active_style == "pixel" else family.contains("source"), str(node.name) + ": selected primary family (" + family + ")")
	for child: Node in node.get_children(): _measure_text(child, result)

func _readable_caption(language: String) -> void:
	original_runtime = root.get_node("Dialogic")
	original_runtime_index = original_runtime.get_index()
	original_layout = original_runtime.Styles.get_layout_node()
	if is_instance_valid(original_layout) and original_layout.is_inside_tree():
		original_layout_parent = original_layout.get_parent()
		original_layout_parent.remove_child(original_layout)
	remove_meta("dialogic_layout_node")
	root.remove_child(original_runtime)
	had_persistent_style = Engine.has_meta("dialogic_persistent_style_info")
	persistent_style = Engine.get_meta("dialogic_persistent_style_info", {})
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		settings_backup[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	runtime = DialogicGameHandler.new()
	runtime.name = "Dialogic"
	root.add_child(runtime)
	layout = runtime.Styles.load_style("res://dialogic/styles/witnessed_caption_style.tres", viewport)
	for layer: Node in layout.get_layers():
		if layer.get_script().resource_path == "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd": caption = layer
	if check(is_instance_valid(caption), "actual witnessed caption layer"):
		var timeline := DialogicTimeline.new()
		for text: String in ["A neutral presentation fixture.", "The interface uses the selected font.", "Story dialogue remains in English."]:
			var event := DialogicTextEvent.new()
			event.text = text
			timeline.events.append(event)
		timeline.events_processed = true
		runtime.start_timeline(timeline)
		await settle()
		for index in 3:
			if caption.caption_text.revealing: runtime.Text.skip_text_reveal()
			await settle()
			if index < 2:
				runtime.Inputs.input_block_timer.stop()
				runtime.Inputs.handle_input()
				await settle()
		check(caption.get_caption_projection().locale == language.replace("_", "-"), "caption UI locale")
		check(caption.get_caption_projection().caption_window.size() == 3, "three witnessed fixture captions")
		await _capture_font("witnessed", language, layout)
		_check_transport_labels()
	await runtime.clear()
	if is_instance_valid(layout): layout.queue_free()
	await settle()
	runtime.free()
	remove_meta("dialogic_layout_node")
	root.add_child(original_runtime)
	root.move_child(original_runtime, original_runtime_index)
	if is_instance_valid(original_layout):
		if is_instance_valid(original_layout_parent): original_layout_parent.add_child(original_layout)
		set_meta("dialogic_layout_node", original_layout)
	for key: String in settings_backup:
		ProjectSettings.set_setting(key, settings_backup[key].value if settings_backup[key].exists else null)
	if had_persistent_style: Engine.set_meta("dialogic_persistent_style_info", persistent_style)
	else: Engine.remove_meta("dialogic_persistent_style_info")
