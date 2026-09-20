extends SceneTree
## Production shell, authored Angela artwork and synthetic read-only public facts.
## Headless execution checks geometry only; screenshots require a native renderer.

const SPLIT := preload("res://tests/desktop_shell/test_desktop_split_touch.gd")
const SHELL := preload("res://tests/desktop_shell/test_desktop_shell.gd")
const CONTACT := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const HUD := preload("res://tests/unit/test_stat_hud_week_tint.gd")
const QUICK := preload("res://tests/manual/verify_quick_status_native.gd")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const EXPECTED_CAPTURES := 10

class PublicStats extends HUD.OwnerFixture:
	func get_stat_display_value(stat: String) -> int:
		return {"pressure": 6, "health": 7, "motivation": 4}.get(stat, 0)

var viewport: SubViewport
var main: Control
var desktop: Control
var hud: Control
var angela: Control
var art: Control
var scroll: ScrollContainer
var locale: Node
var profile: RefCounted
var stats: Node
var folder := OS.get_environment("DWM_RENDER_OUTPUT")
var failures: Array[String] = []
var samples: Array[Dictionary] = []
var captures := 0
var art_geometry := {}
var art_pixels := {}
var crop_checks: Array[Dictionary] = []

func _initialize() -> void: _run.call_deferred()

func check(condition: bool, message: String) -> void:
	if not condition:
		failures.append(message)
		printerr("ANGELA_OVERLAY_CHECK_FAIL ", message)

func settle() -> void:
	for frame in 6: await process_frame

func _run() -> void:
	if folder.is_empty(): folder = ProjectSettings.globalize_path("user://evidence/angela_overlay")
	check(DirAccess.make_dir_recursive_absolute(folder) == OK, "evidence directory")
	await _mount()
	for fixture: Dictionary in [
		{"name": "wide-en100", "width": 480, "locale": "en", "percent": 100},
		{"name": "narrow-en100", "width": 320, "locale": "en", "percent": 100},
		{"name": "wide-en150-conditions", "width": 480, "locale": "en", "percent": 150, "conditions": true},
		{"name": "narrow-en150-conditions", "width": 320, "locale": "en", "percent": 150, "conditions": true},
		{"name": "narrow-en150-last-row", "width": 320, "locale": "en", "percent": 150, "conditions": true, "bottom": true},
		{"name": "narrow-zh-CN150-conditions", "width": 320, "locale": "zh-CN", "percent": 150, "conditions": true},
		{"name": "wide-zh-HK150-conditions", "width": 480, "locale": "zh-HK", "percent": 150, "conditions": true},
		{"name": "narrow-en150-high-contrast", "width": 320, "locale": "en", "percent": 150, "conditions": true, "contrast": true, "bottom": true},
		{"name": "narrow-zh-HK150-high-contrast", "width": 320, "locale": "zh-HK", "percent": 150, "conditions": true, "contrast": true},
		{"name": "wide-en100-day7-conditions", "width": 480, "locale": "en", "percent": 100, "conditions": true, "day": 7},
	]:
		await _show(fixture)
	await _check_centered_crop()
	check(samples.size() == EXPECTED_CAPTURES, "all expected states checked")
	if DisplayServer.get_name() != "headless": check(captures == EXPECTED_CAPTURES, "all expected screenshots saved")
	var report := {"ok": failures.is_empty(), "renderer": DisplayServer.get_name(), "samples": samples.size(),
		"captures": captures, "failures": failures, "evidence": samples, "crop_checks": crop_checks,
		"scope": "production Main/StatHud and authored artwork; synthetic public stat values"}
	var file := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	check(file != null, "results file opened")
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("ANGELA_OVERLAY_RENDER_VERIFIED ", JSON.stringify(report)) if captures == EXPECTED_CAPTURES else print("ANGELA_OVERLAY_GEOMETRY_CHECKED ", JSON.stringify(report))
	viewport.queue_free()
	await settle()
	quit(0 if failures.is_empty() else 1)

func _mount() -> void:
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.handle_input_locally = true
	viewport.gui_embed_subwindows = true
	root.add_child(viewport)
	locale = QUICK.CatalogLocale.new()
	viewport.add_child(locale)
	check(locale.present("en"), "initial locale")
	profile = HUD.ProfileFixture.new()
	stats = PublicStats.new()
	stats.configuration = {"ok": true, "value": {"dark_mode": false}}
	stats.money = 12450
	stats.coins = 360
	viewport.add_child(stats)
	main = SPLIT.MAIN.instantiate()
	hud = main.get_node("%StatHud")
	hud.configure(stats, locale, profile)
	desktop = SPLIT.DESKTOP.instantiate()
	desktop.set_script(SHELL.IsolatedDesktop)
	desktop.configure_run_configuration(SHELL.RunConfigurationFixture.new())
	main._computer_desktop_instance = desktop
	main.get_node("%ComputerPanel").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	main.get_node("%ComputerPanel").add_child(desktop)
	viewport.add_child(main)
	var host := HOST.new()
	host.reset(1)
	check(desktop.configure_contacts(CONTACT.FakePort.new(), locale, profile, host).get("ok", false), "desktop fixture configured")
	desktop._foreground_eligible = true
	angela = main.get_node("%AngelaPanel")
	art = main.get_node("%AngelaImage")
	scroll = hud.get_node("%StatScroll")
	await settle()

func _show(fixture: Dictionary) -> void:
	var width: int = fixture.width
	main.get_node("RootHBox").set_angela_width(width)
	await settle()
	if not art_geometry.has(width): art_geometry[width] = _art_geometry()
	check(locale.present(str(fixture.locale).replace("-", "_")), fixture.name + ": locale loaded")
	profile.change(&"preferences.accessibility.text_size", fixture.percent)
	profile.change(&"preferences.accessibility.high_contrast", fixture.get("contrast", false))
	stats.condition_effects_today = ["nausea", "dizzy", "sequela", "faint"] if fixture.get("conditions", false) else []
	stats.penalty_points_today = 10 if fixture.get("conditions", false) else 0
	stats.day = fixture.get("day", 1)
	stats.save_relevant_state_changed.emit()
	await settle()
	scroll.scroll_vertical = 0
	if fixture.get("bottom", false):
		await _scroll_to_last_row()
	await settle()
	_check_geometry(fixture)
	var sample := fixture.duplicate()
	sample["hud_rect"] = str(hud.get_global_rect())
	sample["art_rect"] = str(art.get_global_rect())
	sample["scroll"] = scroll.scroll_vertical
	sample["scroll_extent"] = maxf(0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	if DisplayServer.get_name() != "headless":
		for frame in 3: await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		check(not pixels.is_empty() and pixels.get_size() == Vector2i(1280, 720), fixture.name + ": full framebuffer")
		await _check_material_pixels(pixels, fixture)
		check(pixels.save_png(folder.path_join(fixture.name + ".png")) == OK, fixture.name + ": screenshot saved")
		captures += 1
	samples.append(sample)
	print("ANGELA_OVERLAY_SAMPLE ", JSON.stringify(sample))

func _check_geometry(fixture: Dictionary) -> void:
	var name: String = fixture.name
	check(angela.get_global_rect() == Rect2(0, 0, fixture.width, 720), name + ": requested Angela width")
	check(art.get_global_rect() == angela.get_global_rect(), name + ": artwork fills panel from top to bottom")
	check(_art_geometry() == art_geometry[fixture.width], name + ": facts and font changes preserve artwork framing")
	check(angela.get_global_rect().encloses(hud.get_global_rect()), name + ": overlay fits Angela panel")
	check(not hud.get_global_rect().intersects(main.get_node("RootHBox")._handle.get_global_rect()), name + ": glass card clears divider hitbox")
	check(hud.get_global_rect().position.y > angela.get_global_rect().position.y, name + ": artwork remains above inset overlay")
	check(art.get_child_count() > 0, name + ": authored art layers present")
	for layer: Node in art.get_children():
		if layer is TextureRect:
			check(layer.texture != null and layer.get_global_rect() == art.get_global_rect(), name + ": aligned full-panel art layer")
			check(layer.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, name + ": artwork covers panel without reserved strip")
	var material: StyleBoxFlat = hud.get_theme_stylebox("panel")
	if fixture.get("contrast", false):
		check(material.bg_color.a == 1.0, name + ": opaque high-contrast backing")
	else:
		check(material.bg_color.a > 0.5 and material.bg_color.a < 0.9, name + ": translucent readable backing")
	check(hud.theme.default_font_size == int(24 * int(fixture.percent) / 100), name + ": full requested text size")
	for row: Node in hud.get_node("%Rows").get_children():
		if row is Label and row.visible:
			check(row.get_theme_font_size("font_size") >= hud.theme.default_font_size, name + ": visible fact not reduced")
			check(row.size.y >= row.get_minimum_size().y, name + ": complete wrapped fact height")
			check(row.mouse_filter == Control.MOUSE_FILTER_IGNORE and row.focus_mode == Control.FOCUS_NONE, name + ": read-only fact does not take input")
	if fixture.get("conditions", false):
		check(hud.get_node("%ConditionDisplay").visible and hud.get_node("%PenaltyLabel").visible, name + ": all public condition/penalty facts retained")
	if fixture.get("bottom", false):
		check(scroll.get_global_rect().encloses(hud.get_node("%PenaltyLabel").get_global_rect()), name + ": final fact reachable")
	check(desktop.get_global_rect().encloses(desktop.home_button.get_global_rect()), name + ": desktop Home remains visible")

func _art_geometry() -> Array:
	var geometry := [art.get_global_rect()]
	for layer: Node in art.get_children():
		if layer is TextureRect: geometry.append([layer.get_global_rect(), layer.stretch_mode, layer.texture])
	return geometry

func _scroll_to_last_row() -> void:
	var extent := maxf(0, scroll.get_v_scroll_bar().max_value - scroll.get_v_scroll_bar().page)
	if extent > 0:
		var before := scroll.scroll_vertical
		var event := InputEventMouseButton.new()
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN
		event.pressed = true
		event.position = scroll.get_global_rect().get_center()
		viewport.push_input(event, true)
		await settle()
		check(scroll.scroll_vertical > before, "native mouse wheel scrolls cramped stats")
	scroll.ensure_control_visible(hud.get_node("%PenaltyLabel"))
	await settle()

func _art_reference(name: String) -> Image:
	# Alpha-only reference changes no visibility, layout, ownership or facts.
	var original: Color = hud.modulate
	var focus: Control = viewport.gui_get_focus_owner()
	var geometry := _art_geometry()
	hud.modulate.a = 0.0
	for frame in 3: await RenderingServer.frame_post_draw
	var reference: Image = viewport.get_texture().get_image()
	hud.modulate = original
	for frame in 3: await RenderingServer.frame_post_draw
	check(_art_geometry() == geometry and viewport.gui_get_focus_owner() == focus, name + ": reference preserves geometry/focus")
	return reference

func _check_material_pixels(pixels: Image, fixture: Dictionary) -> void:
	var reference := await _art_reference(fixture.name)
	# Omit only the split handle's 64px hit area, whose theme can change independently.
	var art_image := reference.get_region(Rect2i(0, 0, int(fixture.width) - 64, 720))
	if not art_pixels.has(fixture.width): art_pixels[fixture.width] = art_image
	check(art_image.get_data() == art_pixels[fixture.width].get_data(), fixture.name + ": same-width artwork pixels do not move with stats or preferences")
	var bounds := hud.get_global_rect()
	var rendered_colors := {}
	var underlying_colors := {}
	var changed := 0
	# Outer right padding stays outside every label and the inset native scroll rail.
	var x := int(bounds.end.x) - 8
	for y: int in range(int(bounds.position.y) + 24, int(bounds.end.y) - 24, 4):
		var point := Vector2i(x, y)
		var actual := pixels.get_pixelv(point)
		var background := reference.get_pixelv(point)
		rendered_colors[actual.to_html()] = true
		underlying_colors[background.to_html()] = true
		if actual != background: changed += 1
	check(underlying_colors.size() > 12, fixture.name + ": varied artwork exists beneath the stats")
	check(changed > 12, fixture.name + ": stats backing is visibly present")
	if fixture.get("contrast", false):
		check(rendered_colors.size() == 1, fixture.name + ": high-contrast padding fully masks artwork")
	else:
		check(rendered_colors.size() > 5, fixture.name + ": glass retains artwork variation through blank padding")

func _check_centered_crop() -> void:
	if DisplayServer.get_name() != "headless":
		_compare_crop(art_pixels[480], art_pixels[320], 80, 320)
	main.get_node("RootHBox").set_angela_width(478)
	await settle()
	check(angela.size == Vector2(478, 720), "minimum divider step commits exactly two pixels")
	check(art.get_global_rect() == Rect2(0, 0, 478, 720), "minimum step preserves full artwork height")
	for layer: Node in art.get_children():
		if layer is TextureRect: check(layer.get_global_rect() == art.get_global_rect(), "minimum step preserves aligned full-height art layers")
	if DisplayServer.get_name() != "headless":
		var reference := await _art_reference("minimum two-pixel step")
		_compare_crop(art_pixels[480], reference.get_region(Rect2i(0, 0, 478 - 64, 720)), 1, 478)
	main.get_node("RootHBox").set_angela_width(480)
	await settle()

func _compare_crop(wide: Image, narrow: Image, source_x: int, width: int) -> void:
	var expected := wide.get_region(Rect2i(source_x, 0, narrow.get_width(), 720)).get_data()
	var actual := narrow.get_data()
	var identical := actual == expected
	var largest_difference := 0
	if not identical:
		for index: int in actual.size():
			largest_difference = maxi(largest_difference, absi(int(actual[index]) - int(expected[index])))
	var record := {"source_width": 480, "target_width": width, "source_x": source_x,
		"sample_width": narrow.get_width(), "sample_height": 720, "identical": identical,
		"maximum_channel_difference": largest_difference}
	crop_checks.append(record)
	print("ANGELA_ART_CROP_CHECK ", JSON.stringify(record))
	check(identical, "480 to %d: constant-height artwork exactly matches centered crop at x=%d" % [width, source_x])
