extends "res://tests/ui/render_font_choices.gd"
## Root-window captures, real Settings selectors and retained production Mines board.
## Mount directly in the Window so viewport signal bindings match real rendering.
const TEXT_SIZE := &"preferences.accessibility.text_size"
const MOUNTED_CAPTURE_COUNT := 32
var active_percent := 100
var requested_size := Vector2i(1280, 720)

func _run() -> void:
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://evidence/mounted-font-scale")
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "evidence directory")
	root.content_scale_size = Vector2i(1280, 720)
	root.content_scale_mode = Window.CONTENT_SCALE_MODE_CANVAS_ITEMS
	root.content_scale_aspect = Window.CONTENT_SCALE_ASPECT_KEEP
	root.gui_embed_subwindows = true
	await settle()
	_mount_locale_owners()
	for language: String in ["zh_HK", "en", "zh_CN", "ja", "ko"]:
		check(locale.set_locale(language).get("ok", false), "actual locale commit " + language)
		await _mount_font_desktop()
		# Public fixture only: show 1–8 in the first 16 cells without game commands.
		for index in 16:
			var cell: Dictionary = mine_port.view.board.cells[index]
			cell.face = "revealed"
			cell.number = index % 8 + 1
			cell.actions = ["chord"]
			cell.pressable = true
			cell.inspectable = true
		mine_port.live_view = mine_port.view.duplicate(true)
		check(mine_app.refresh_view().get("ok", false), "public numeral fixture accepted")
		initial_cells = mine_port.view.board.cells.duplicate(true)
		await settle()
		var widths: Array = [1280, 1600, 1920] if language == "zh_HK" else [1920]
		var styles: Array = ["pixel", "readable"] if language == "zh_HK" else ["pixel"]
		var percentages: Array = [125, 150] if language == "zh_HK" else [150]
		for width: int in widths:
			requested_size = Vector2i(width, int(width * 0.5625))
			root.size = requested_size
			await settle()
			check(root.size == requested_size, "requested native window dimensions")
			for style: String in styles:
				await _choose_font(style)
				for percent: int in percentages:
					await _choose_percent(percent)
					await _capture_mounted("settings", language)
					check(desktop.return_home().get("ok", false), "leave Settings")
					check(desktop.open_app(&"minesweeper").get("ok", false), "same Mines board")
					await settle()
					_check_board_preserved()
					await _capture_mounted("minesweeper", language)
		main.queue_free()
		await settle()
	check(captures == MOUNTED_CAPTURE_COUNT and samples.size() == MOUNTED_CAPTURE_COUNT, "32 mounted native captures")
	var rendering := {}
	for method: String in ["get_current_rendering_method", "get_current_rendering_driver_name", "get_video_adapter_name", "get_video_adapter_vendor", "get_video_adapter_api_version"]:
		if RenderingServer.has_method(method): rendering[method] = RenderingServer.call(method)
	var report := {"complete": failures.is_empty(), "captures": captures, "samples": samples,
		"failures": failures, "rendering": rendering, "argv": OS.get_cmdline_args(), "engine": Engine.get_version_info(),
		"scope": "Real Settings font/text selectors, production desktop and retained synthetic Mines board. Root canvas_items stretch at 1280/1600/1920; no SubViewport captures. zh_HK full two-style/two-size matrix; other four locales Pixel150 at1920. Diagnostic pixels need visual review; no exported-package or user-device acceptance."}
	var file := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	else:
		check(false, "write report")
	await settle()
	locale.free()
	profile.free()
	for retained: Dictionary in retained_owners:
		root.add_child(retained.node)
		root.move_child(retained.node, retained.index)
	print("MOUNTED_FONT_SCALE_COMPLETE ", captures, " failures=", failures.size())
	quit(0 if failures.is_empty() else 1)

# Mirrors the existing font-choice fixture mount; root ownership is the sole mounting difference.
func _mount_font_desktop() -> void:
	main = SPLIT.MAIN.instantiate()
	desktop = SPLIT.DESKTOP.instantiate()
	desktop.set_script(SHELL.IsolatedDesktop)
	desktop.configure_run_configuration(SHELL.RunConfigurationFixture.new())
	main._computer_desktop_instance = desktop
	main.get_node("%ComputerPanel").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	main.get_node("%ComputerPanel").add_child(desktop)
	root.add_child(main)
	main.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
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

func _choose_percent(percent: int) -> void:
	check(desktop.return_home().get("ok", false), "leave Mines")
	check(desktop.open_app(&"settings").get("ok", false), "open actual Settings")
	settings_content.select_category("accessibility")
	await settle()
	var picker: OptionButton = settings_content.control_for(TEXT_SIZE)
	if not check(picker != null, "actual text-size picker"): return
	var selected := -1
	for index in picker.item_count:
		if picker.get_item_metadata(index) == percent: selected = index
	if not check(selected >= 0, "percentage is available"): return
	picker.select(selected)
	picker.item_selected.emit(selected)
	await settle()
	active_percent = percent
	check(profile.get_preference(TEXT_SIZE) == percent, "selector commits percentage")
	check(picker.get_item_metadata(picker.selected) == percent, "picker reflects percentage")
	settings_content.sheet_scroll.ensure_control_visible(picker)
	await settle()

func _font_record(font: Font) -> Dictionary:
	var result := {"class": font.get_class(), "name": font.get_font_name(), "path": font.resource_path}
	if font is FontVariation:
		result.base = _font_record(font.base_font)
	if font is FontFile:
		result.antialiasing = font.antialiasing
		result.hinting = font.hinting
		result.subpixel = font.subpixel_positioning
		result.oversampling = font.oversampling
		result.fixed_size = font.fixed_size
		result.system_fallback = font.allow_system_fallback
		result.sha256 = FileAccess.get_sha256(font.resource_path)
	var fallback_records: Array = []
	for fallback: Font in font.fallbacks: fallback_records.append(_font_record(fallback))
	result.fallbacks = fallback_records
	return result

func _capture_mounted(surface: String, language: String) -> void:
	await settle()
	var expected: Font = TYPOGRAPHY.font(language, active_percent, active_style)
	check(_base_face(desktop.theme.default_font) == expected, "desktop selected face")
	var picker: OptionButton = settings_content.control_for(TEXT_SIZE)
	check(_base_face(picker.get_theme_font("font")) == expected, "Settings selected primary face")
	var measured := {"labels": 0, "missing_glyphs": []}
	_measure_text(main, measured)
	check(measured.labels > 0 and measured.missing_glyphs.is_empty(), "visible text glyph coverage")
	var grid: Control = mine_app.panel.worksheet.grid
	var cell: Control = grid.cell_nodes[0]
	var filename := "%s-%s-%d-%d-%s.png" % [language, active_style, active_percent, requested_size.x, surface]
	for frame in 3: await RenderingServer.frame_post_draw
	var pixels: Image = root.get_texture().get_image()
	check(not pixels.is_empty() and pixels.get_size() == requested_size, "root physical pixel dimensions " + filename)
	if check(pixels.save_png(folder.path_join(filename)) == OK, "save " + filename): captures += 1
	samples.append({"file": filename, "locale": language, "style": active_style, "percent": active_percent, "surface": surface,
		"window_size": [root.size.x, root.size.y], "image_size": [pixels.get_width(), pixels.get_height()],
		"content_scale_size": str(root.content_scale_size), "root_stretch": str(root.get_stretch_transform()),
		"desktop_scale": str(desktop.desktop_canvas.scale), "grid_scale": str(grid.scale),
		"grid_canvas_transform": str(grid.get_global_transform_with_canvas()), "cell_size": str(cell.size),
		"cell_font_size": cell.get_theme_default_font_size(), "settings_font_size": picker.get_theme_font_size("font_size"),
		"settings_font": _font_record(picker.get_theme_font("font")), "cell_font": _font_record(cell.get_theme_default_font()),
		"measured_text": measured, "public_cells": mine_port.view.board.cells})
