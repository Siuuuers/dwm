extends SceneTree
## Real UI, locale/profile owners and fonts; domain records are isolated fixtures.
## Narrative fixture text stays English. Headless runs verify geometry, never claim pixels.
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const SPLIT := preload("res://tests/desktop_shell/test_desktop_split_touch.gd")
const SHELL := preload("res://tests/desktop_shell/test_desktop_shell.gd")
const CONTACT := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const HUD := preload("res://tests/unit/test_stat_hud_week_tint.gd")
const SETTINGS := preload("res://tests/unit/test_settings_panel_resize.gd")
const SHOP := preload("res://tests/manual/verify_shop_desktop_native.gd")
const SCHEDULE := preload("res://tests/manual/verify_schedule_desktop_native.gd")
const SCHEDULE_COPY := preload("res://scripts/ui/schedule/ScheduleCopy.gd")
const QUICK := preload("res://tests/manual/verify_quick_status_native.gd")
const MINES := preload("res://tests/unit/test_minesweeper_app.gd")
const DESKTOP_RENDER := preload("res://tests/ui/render_desktop_scaling.gd")
const MENU := preload("res://scenes/menu/MenuScene.tscn")
const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const EXPECTED_CAPTURES := 30

class ContactPort extends CONTACT.FakePort:
	func get_projection(friend_id: String, primary: String, secondary: String = "") -> Dictionary:
		var result: Dictionary = super.get_projection(friend_id, primary, secondary)
		for entry: Dictionary in result.value.entries:
			for language: String in ["ja", "ko"]: entry.texts[language] = entry.texts.en
		return result

var viewport: SubViewport
var profile: Node
var locale: Node
var main: Control
var desktop: Control
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var captures := 0
var folder := OS.get_environment("DWM_RENDER_OUTPUT")
var retained_owners: Array[Dictionary] = []
var runtime: DialogicGameHandler
var layout: Node
var caption: Node
var original_runtime: Node
var original_layout: Node
var original_layout_parent: Node
var original_runtime_index := 0
var settings_backup: Dictionary = {}
var persistent_style: Variant
var had_persistent_style := false

func _initialize() -> void: _run.call_deferred()

func check(condition: bool, message: String) -> bool:
	if not condition:
		failures.append(message)
		printerr("JAPANESE_KOREAN_UI_FAIL ", message)
	return condition

func settle() -> void:
	for frame in 6: await process_frame

func _run() -> void:
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://evidence/japanese_korean_ui")
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "evidence directory")
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	# Let the real bootstrap finish binding its own owners before the fixture swaps them.
	await settle()
	_mount_locale_owners()
	for language: String in ["ja", "ko"]:
		if not check(locale.set_locale(language).get("ok", false), language + " actual locale commit"): break
		check(profile.set_preference(&"preferences.accessibility.text_size", 100).get("ok", false), "ordinary text preference")
		await _title_and_gallery(language)
		await _desktop_samples(language)
	await _caption_samples()
	check(samples.size() == EXPECTED_CAPTURES, "all 30 UI states checked")
	if DisplayServer.get_name() != "headless": check(captures == EXPECTED_CAPTURES, "all 30 native screenshots captured")
	var report := {"ok": failures.is_empty(), "renderer": DisplayServer.get_name(),
		"samples": samples.size(), "captures": captures, "failures": failures, "states": samples,
		"fixture": "Real production UI, active locale/profile providers and Fusion fonts; synthetic shop/contact/board records, empty Gallery, English dialogue fixture. No player commands."}
	var file := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	file.store_string(JSON.stringify(report, "\t"))
	file.close()
	if failures.is_empty() and captures == EXPECTED_CAPTURES:
		print("JAPANESE_KOREAN_UI_RENDER_VERIFIED ", JSON.stringify(report))
	else:
		print("JAPANESE_KOREAN_UI_GEOMETRY_CHECKED ", JSON.stringify(report))
	viewport.queue_free()
	await settle()
	locale.free()
	profile.free()
	for retained: Dictionary in retained_owners:
		root.add_child(retained.node)
		root.move_child(retained.node, retained.index)
	quit(0 if failures.is_empty() else 1)

func _mount_locale_owners() -> void:
	for name: String in ["ProfileManager", "LocalizationManager"]:
		var original := root.get_node(name)
		retained_owners.append({"node": original, "index": original.get_index()})
		root.remove_child(original)
	profile = PROFILE.new()
	profile.name = "ProfileManager"
	root.add_child(profile)
	check(profile.initialize(STORAGE.new("japanese-korean-render.memory", FILES.new())).get("ok", false), "real Profile initialization")
	locale = LOCALIZATION.new()
	locale.name = "LocalizationManager"
	root.add_child(locale)
	check(locale.initialize(profile).get("ok", false), "real Localization initialization")

func capture(name: String, language: String, percent: int, scene: Node) -> void:
	await settle()
	check(locale.get_locale() == language, name + ": active locale provider")
	check(profile.get_preference(&"preferences.accessibility.text_size") == percent, name + ": actual text preference")
	if name == "minesweeper":
		for issue: String in DESKTOP_RENDER.mines_control_layout_failures(desktop._cached_app_windows[&"minesweeper"].panel):
			check(false,name+": "+issue)
	var measured := {"labels": 0, "missing_glyphs": []}
	_measure_text(scene, measured)
	check(measured.labels > 0, name + ": visible production text")
	check(measured.missing_glyphs.is_empty(), name + ": missing glyphs " + str(measured.missing_glyphs))
	var filename := "%s-%s-%d.png" % [language, name, percent]
	samples.append({"locale": language, "percent": percent, "surface": name,
		"visible_text_nodes": measured.labels, "file": filename})
	if DisplayServer.get_name() != "headless":
		for frame in 3: await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		check(not pixels.is_empty() and pixels.get_size() == Vector2i(1280, 720), filename + ": native image")
		if check(pixels.save_png(folder.path_join(filename)) == OK, filename + ": save PNG"): captures += 1
	print("JAPANESE_KOREAN_UI_SAMPLE ", language, " ", percent, " ", name)

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
	if not copy.is_empty() and node.get_global_rect().intersects(Rect2(0, 0, 1280, 720)):
		result.labels += 1
		check(not copy.begins_with("[missing:") and not copy.begins_with("[format_error:"), "catalog lookup " + copy)
		var needs_cjk_face := false
		for character: String in copy:
			var code := character.unicode_at(0)
			needs_cjk_face = needs_cjk_face or (code >= 0x3040 and code <= 0x30ff) \
				or (code >= 0x4e00 and code <= 0x9fff) or (code >= 0xac00 and code <= 0xd7af)
			if not character.strip_edges().is_empty() and (font == null or not font.has_char(character.unicode_at(0))):
				var detail := "%s U+%04X" % [node.name, character.unicode_at(0)]
				if detail not in result.missing_glyphs: result.missing_glyphs.append(detail)
		if needs_cjk_face:
			check(font != null and font.get_font_name().to_lower().contains("fusion"), str(node.name) + ": draft UI uses actual Fusion face")
	for child: Node in node.get_children(): _measure_text(child, result)

func _check_backup_geometry(backup: Control) -> void:
	for key: Button in backup.mode_buttons.values() + backup.action_buttons.values():
		if not key.is_visible_in_tree(): continue
		check(Rect2(Vector2.ZERO, key.size).grow(0.01).encloses(key.caption.get_rect()),
			"Backup caption stays within its button: " + key.caption.text)
	for mode: String in backup.mode_buttons:
		check(backup.mode_buttons[mode].accessibility_name == backup._t(mode), "Backup full accessible mode: " + mode)
	for locator: String in backup.drawer_buttons:
		var drawer: Button = backup.drawer_buttons[locator]
		var bounds := Rect2(Vector2.ZERO, drawer.size).grow(0.01)
		check(bounds.encloses(drawer.identity_label.get_rect()), "Backup identity stays within drawer: " + drawer.identity_label.text)
		check(bounds.encloses(drawer.state_label.get_rect()), "Backup state stays within drawer: " + drawer.state_label.text)
		check(not drawer.identity_label.get_rect().intersects(drawer.state_label.get_rect()),
			"Backup identity and state do not overlap: " + drawer.identity_label.text)
		check(drawer.accessibility_name.begins_with(backup._identity(locator) + ", "), "Backup full accessible identity: " + locator)

func _check_mines_footer(worksheet: Control) -> void:
	var canvas: Rect2 = desktop.desktop_canvas.get_global_rect()
	var footer := Rect2(canvas.position + Vector2(0, canvas.size.y - 64), Vector2(canvas.size.x, 64))
	check(footer.grow(0.01).encloses(worksheet.view_controls.get_global_rect()), "Mines controls stay inside the visible 64px footer")
	var fit: Button = worksheet.zoom_controls[1]
	check(footer.grow(0.01).encloses(fit.get_global_rect()), "Mines Fit button stays inside footer and viewport")
	check(fit._paragraph.get_line_count() == 1, "Mines compact Fit label stays on one line")
	var top := floorf((fit.size.y - fit._text_height) / 4.0) * 2.0
	check(top >= 0 and top + fit._text_height <= fit.size.y, "Mines Fit paragraph stays inside button")
	check(fit._paragraph.get_line_width(0) <= fit.size.x - 2 * fit._inset, "Mines Fit paragraph width fits")

func _check_transport_labels() -> void:
	var rail: Control = caption.transport_rail
	var original := [rail._can_skip, rail._skip_active, rail._auto_enabled, rail._can_auto, rail._can_load]
	var visible_states := {"skip": {}, "auto": {}}
	for states: Array in [[false, false], [true, false], [false, true]]:
		check(rail.project(true, states[0], states[1], true, true), "transport state projection")
		for id: String in ["skip", "auto"]:
			var button: Button = rail.get_node(id.capitalize())
			var style: StyleBox = button.get_theme_stylebox("normal")
			var available := button.size.x - style.get_content_margin(SIDE_LEFT) - style.get_content_margin(SIDE_RIGHT)
			var width := button.get_theme_font("font").get_string_size(button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, button.get_theme_font_size("font_size")).x
			check(width <= available + 0.01, "transport complete state label fits: %s (%spx text, %spx available, %spx font)" % [button.text, width, available, button.get_theme_font_size("font_size")])
			var enabled: bool = states[0] if id == "skip" else states[1]
			visible_states[id][enabled] = button.text
			var full_copy := "%s · %s" % [locale.t("witnessed.transport." + id), locale.t("witnessed.transport.on" if enabled else "witnessed.transport.off")]
			check(button.accessibility_name == full_copy, "transport full accessible state: " + full_copy)
	for id: String in visible_states:
		check(visible_states[id][false] != visible_states[id][true], "transport on and off remain visibly distinct: " + id)
	check(rail.project(original[0], original[1], original[2], original[3], original[4]), "restore transport projection")

func _title_and_gallery(language: String) -> void:
	var menu: Control = MENU.instantiate()
	menu.configure_settings_services({"profile": profile, "localization": locale})
	menu.configure_startup_recovery_owner(null)
	viewport.add_child(menu)
	await capture("title", language, 100, menu)
	menu.queue_free()
	await settle()
	var gallery: Control = GALLERY.instantiate()
	viewport.add_child(gallery)
	await capture("gallery", language, 100, gallery)
	check(profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false), "Gallery large preference")
	await capture("gallery", language, 150, gallery)
	gallery.queue_free()
	await settle()
	check(profile.set_preference(&"preferences.accessibility.text_size", 100).get("ok", false), "restore ordinary preference")

func _desktop_samples(language: String) -> void:
	main = SPLIT.MAIN.instantiate()
	var stats := HUD.OwnerFixture.new()
	viewport.add_child(stats)
	main.get_node("%StatHud").configure(stats, locale, profile)
	desktop = SPLIT.DESKTOP.instantiate()
	desktop.set_script(SHELL.IsolatedDesktop)
	desktop.configure_run_configuration(SHELL.RunConfigurationFixture.new())
	main._computer_desktop_instance = desktop
	main.get_node("%ComputerPanel").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	main.get_node("%ComputerPanel").add_child(desktop)
	viewport.add_child(main)
	var host := SCHEDULE.HOST.new()
	host.reset(1)
	check(desktop.configure_contacts(ContactPort.new(), locale, profile, host).get("ok", false), "Contacts owners")
	desktop._foreground_eligible = true
	await capture("launcher", language, 100, main)
	var opened: Dictionary = desktop.open_contacts()
	if check(opened.get("ok", false), "Contacts open"):
		opened.value.app.contacts_panel.open_requested.emit("lavinia")
		await capture("contacts", language, 100, main)
	desktop.return_home()
	check(desktop.configure_backup_port(QUICK.RecordsFixture.new()).get("ok", false), "Backup records")
	if check(desktop.open_app(&"backup").get("ok", false), "Backup open"):
		await capture("backup", language, 100, main)
		_check_backup_geometry(desktop._cached_app_windows[&"backup"])
		check(profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false), "Backup large preference")
		await capture("backup", language, 150, main)
		var backup: Control = desktop._cached_app_windows[&"backup"]
		_check_backup_geometry(backup)
		desktop.app_scroll.ensure_control_visible(backup.drawer_buttons["slot:7"])
		await settle()
		check(desktop.app_scroll.get_global_rect().grow(0.01).encloses(backup.drawer_buttons["slot:7"].get_global_rect()), "Backup150 final drawer reachable")
		check(profile.set_preference(&"preferences.accessibility.text_size", 100).get("ok", false), "Backup ordinary preference")
	desktop.return_home()
	var settings: Control = preload("res://scenes/apps/SettingsApp.tscn").instantiate()
	var content: Control = settings.get_node("SettingsContent")
	content.configure_services({"profile": profile, "localization": locale, "volume": SETTINGS.MemoryVolume.new(),
		"audio": null, "tts": null, "input": null, "window": null})
	desktop.app_window_host.add_child(settings)
	desktop._cached_app_windows[&"settings"] = settings
	if check(desktop.open_app(&"settings").get("ok", false), "Settings open"):
		content.select_category("language")
		await capture("settings", language, 100, main)
		var language_menu: OptionButton = content.control_for(&"preferences.language.primary_locale_id")
		check(language_menu.item_count == 5 and language_menu.get_item_metadata(language_menu.selected) == language, "five selectable languages and active choice")
		check(profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false), "Settings large preference")
		await capture("settings", language, 150, main)
		check(profile.set_preference(&"preferences.accessibility.text_size", 100).get("ok", false), "Settings ordinary preference")
	desktop.return_home()
	var shop_fixture := SHOP.FIXTURES.new()
	var catalog := SHOP.CatalogFixture.new()
	catalog.rows = shop_fixture._valid_rows()
	shop_fixture.free()
	check(desktop.configure_shop(catalog, locale, profile, host, 1).get("ok", false), "Shop catalog")
	opened = desktop.open_app(&"shop")
	if check(opened.get("ok", false), "Shop open"):
		await settle()
		opened.value.app.cards.wine.grab_focus()
		await capture("shop", language, 100, main)
	desktop.return_home()
	var registry: Dictionary = SCHEDULE.REGISTRY.load_current()
	var draft := SCHEDULE.VIEW.new()
	check(draft.configure(registry.value.registry, SCHEDULE.RULES, registry.value.registry_fingerprint).ok, "real schedule draft")
	check(draft.open_day(1, "japanese-korean-ui-day").ok, "schedule day")
	var issuer := SCHEDULE.ISSUER.new()
	check(issuer.configure(SCHEDULE.ROOT_STORE.new("73".repeat(32), 23)).ok, "isolated schedule issuer")
	var port := SCHEDULE.PORT.new()
	var owner := SCHEDULE.DraftSource.new()
	owner.day = 1
	var records: Dictionary = registry.value.registry.snapshot(registry.value.registry_fingerprint)
	check(port.configure(owner, draft, registry.value.registry, registry.value.registry_fingerprint, issuer,
		SCHEDULE_COPY.action_names(records.value.records)).ok, "real schedule presentation")
	for id: String in ["training", "working", "rest"]:
		var projected: Dictionary = port.project(language)
		check(projected.get("ok", false), "schedule locale " + language)
		if projected.get("ok", false): check(port.append(id, projected.value.fingerprint, language).ok, "schedule append " + id)
	check(desktop.configure_schedule(port, locale, profile, host, 1).get("ok", false), "Schedule owners")
	if check(desktop.open_app(&"schedule").get("ok", false), "Schedule open"):
		await capture("schedule", language, 100, main)
	desktop.return_home()
	var mine_fixture := MINES.new()
	var mine_port := SPLIT.ShellMinesweeperPort.new()
	mine_port.desktop_owner = desktop
	mine_port.view = mine_fixture._view()
	mine_port.live_view = mine_port.view.duplicate(true)
	mine_fixture.free()
	check(desktop.configure_minesweeper(mine_port, locale, profile).get("ok", false), "Mines owners")
	opened = desktop.open_app(&"minesweeper")
	if check(opened.get("ok", false), "Mines open"):
		await capture("minesweeper", language, 100, main)
		check(profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false), "Mines large preference")
		await settle()
		desktop.app_scroll.ensure_control_visible(opened.value.app.panel.dock)
		await capture("minesweeper", language, 150, main)
		_check_mines_footer(opened.value.app.panel.worksheet)
		check(opened.value.app.last_result.get("ok", false), "Mines large projection " + str(opened.value.app.last_result))
		check(profile.set_preference(&"preferences.accessibility.large_targets", true).get("ok", false), "Mines enlarged pointer targets")
		await settle()
		check(opened.value.app.last_result.get("ok", false), "Mines150 enlarged-target projection " + str(opened.value.app.last_result))
		check(opened.value.app.panel._percent == 150 and opened.value.app.panel._large, "Mines applies both accessibility preferences")
		for issue: String in DESKTOP_RENDER.mines_control_layout_failures(opened.value.app.panel): check(false,"Mines large targets: "+issue)
		_check_mines_footer(opened.value.app.panel.worksheet)
		desktop.app_scroll.ensure_control_visible(opened.value.app.panel.dock)
		await settle()
		check(desktop.app_scroll.get_global_rect().grow(0.01).encloses(opened.value.app.panel.dock.get_global_rect()), "Mines150 enlarged dock remains reachable")
		check(profile.set_preference(&"preferences.accessibility.large_targets", false).get("ok", false), "restore ordinary pointer targets")
	main.queue_free()
	stats.queue_free()
	await settle()
	check(profile.set_preference(&"preferences.accessibility.text_size", 100).get("ok", false), "desktop ordinary preference")

func _caption_samples() -> void:
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
		for language: String in ["ja", "ko"]:
			check(locale.set_locale(language).get("ok", false), "caption active locale")
			for percent: int in [100, 150]:
				check(profile.set_preference(&"preferences.accessibility.text_size", percent).get("ok", false), "caption text preference")
				await runtime.clear()
				var timeline := DialogicTimeline.new()
				for text: String in ["A neutral presentation fixture.", "The interface uses the selected language.", "Story dialogue remains in English."]:
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
				check(caption.get_caption_projection().locale == language, "caption UI language")
				check(caption.get_caption_projection().caption_window.size() == 3, "three English fixture captions")
				await capture("witnessed", language, percent, layout)
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
