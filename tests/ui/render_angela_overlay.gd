extends SceneTree
## Mounted production shell after HUD retirement; retained art, divider and desktop.
## Headless execution checks geometry only; screenshots require a native renderer.

const SPLIT := preload("res://tests/desktop_shell/test_desktop_split_touch.gd")
const SHELL := preload("res://tests/desktop_shell/test_desktop_shell.gd")
const CONTACT := preload("res://tests/contacts_shell/test_contacts_shell.gd")
const QUICK := preload("res://tests/manual/verify_quick_status_native.gd")
const HOST := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
const EXPECTED_CAPTURES := 10

class Preferences extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	var values: Dictionary = {}
	func get_preference(path: String, fallback: Variant = null) -> Variant:
		return values.get(path, fallback)
	func set_preference(path: StringName, value: Variant) -> Dictionary:
		values[String(path)] = value
		preference_changed.emit(path, value)
		return {"ok": true}

var viewport: SubViewport
var main: Control
var desktop: Control
var angela: Control
var art: Control
var locale: Node
var profile := Preferences.new()
var host := HOST.new()
var contact_port := CONTACT.FakePort.new()
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
		{"name": "narrow-en150", "width": 320, "locale": "en", "percent": 150},
		{"name": "narrow-en150-high-contrast", "width": 320, "locale": "en", "percent": 150, "contrast": true},
		{"name": "narrow-zh-CN150-high-contrast", "width": 320, "locale": "zh-CN", "percent": 150, "contrast": true},
		{"name": "narrow-zh-HK150", "width": 320, "locale": "zh-HK", "percent": 150},
		{"name": "wide-zh-HK150", "width": 480, "locale": "zh-HK", "percent": 150},
		{"name": "wide-en100-day1", "width": 480, "locale": "en", "percent": 100},
		{"name": "wide-en100-day7", "width": 480, "locale": "en", "percent": 100, "day": 7},
		{"name": "wide-en100-day7-high-contrast", "width": 480, "locale": "en", "percent": 100, "day": 7, "contrast": true},
	]:
		await _show(fixture)
	await _check_centered_crop()
	check(samples.size() == EXPECTED_CAPTURES, "all expected states checked")
	if DisplayServer.get_name() != "headless": check(captures == EXPECTED_CAPTURES, "all expected screenshots saved")
	var report := {"ok": failures.is_empty(), "renderer": DisplayServer.get_name(), "samples": samples.size(),
		"captures": captures, "failures": failures, "evidence": samples, "crop_checks": crop_checks,
		"scope": "mounted Main without HUD; retained authored artwork, real divider and ComputerDesktop theme propagation"}
	var file := FileAccess.open(folder.path_join("results.json"), FileAccess.WRITE)
	check(file != null, "results file opened")
	if file != null:
		file.store_string(JSON.stringify(report, "\t") + "\n")
		file.close()
	print("HUD_RETIREMENT_RENDER_VERIFIED ", JSON.stringify(report)) if captures == EXPECTED_CAPTURES else print("HUD_RETIREMENT_GEOMETRY_CHECKED ", JSON.stringify(report))
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
	main = SPLIT.MAIN.instantiate()
	check(main.bind_view_preferences(profile), "isolated panel preferences bound")
	desktop = SPLIT.DESKTOP.instantiate()
	desktop.set_script(SHELL.IsolatedDesktop)
	check(desktop.configure_run_configuration(SHELL.RunConfigurationFixture.new()).get("ok", false), "explicit run palette configured")
	main._computer_desktop_instance = desktop
	main.get_node("%ComputerPanel").add_theme_stylebox_override("panel", StyleBoxEmpty.new())
	main.get_node("%ComputerPanel").add_child(desktop)
	viewport.add_child(main)
	host.reset(1)
	check(desktop.configure_contacts(contact_port, locale, profile, host).get("ok", false), "desktop fixture configured")
	desktop._foreground_eligible = true
	angela = main.get_node("%AngelaPanel")
	art = main.get_node("%AngelaImage")
	await settle()

func _show(fixture: Dictionary) -> void:
	var width: int = fixture.width
	main.get_node("RootHBox").set_angela_width(width)
	await settle()
	if not art_geometry.has(width): art_geometry[width] = _art_geometry()
	var before_width := angela.size.x
	var before_theme: Theme = desktop.theme
	check(locale.present(str(fixture.locale).replace("-", "_")), fixture.name + ": locale loaded")
	profile.set_preference(&"preferences.accessibility.text_size", fixture.percent)
	profile.set_preference(&"preferences.accessibility.high_contrast", fixture.get("contrast", false))
	var day: int = fixture.get("day", 1)
	host.reset(day)
	check(desktop.configure_contacts(contact_port, locale, profile, host, day).get("ok", false), fixture.name + ": live day configured")
	await settle()
	check(angela.size.x == before_width, fixture.name + ": live presentation changes preserve divider width")
	check(desktop.theme != before_theme, fixture.name + ": desktop replaced its live theme")
	if fixture.name in ["narrow-en150-high-contrast", "wide-en100-day7", "wide-en100-day7-high-contrast"]:
		check(desktop.theme.get_color("face", "Desktop") != before_theme.get_color("face", "Desktop"), fixture.name + ": live palette/day change is observable at unchanged width")
	_check_geometry(fixture)
	var sample := fixture.duplicate()
	sample["art_rect"] = str(art.get_global_rect())
	sample["divider_rect"] = str(main.get_node("RootHBox")._handle.get_global_rect())
	sample["face"] = desktop.theme.get_color("face", "Desktop").to_html()
	sample["hud_absent"] = main.find_child("StatHud", true, false) == null
	if DisplayServer.get_name() != "headless":
		for frame in 3: await RenderingServer.frame_post_draw
		var pixels: Image = viewport.get_texture().get_image()
		check(not pixels.is_empty() and pixels.get_size() == Vector2i(1280, 720), fixture.name + ": full framebuffer")
		var art_image := pixels.get_region(Rect2i(0, 0, width - 64, 720))
		if not art_pixels.has(width): art_pixels[width] = art_image
		check(art_image.get_data() == art_pixels[width].get_data(), fixture.name + ": same-width unobstructed artwork pixels unchanged")
		check(pixels.save_png(folder.path_join(fixture.name + ".png")) == OK, fixture.name + ": screenshot saved")
		captures += 1
	samples.append(sample)
	print("ANGELA_OVERLAY_SAMPLE ", JSON.stringify(sample))

func _check_geometry(fixture: Dictionary) -> void:
	var name: String = fixture.name
	check(main.find_child("StatHud", true, false) == null, name + ": retired HUD absent from mounted tree")
	check(angela.get_global_rect() == Rect2(0, 0, fixture.width, 720), name + ": requested Angela width")
	check(art.get_global_rect() == angela.get_global_rect(), name + ": artwork fills panel from top to bottom")
	check(_art_geometry() == art_geometry[fixture.width], name + ": preferences and day preserve artwork framing")
	var split: Control = main.get_node("RootHBox")
	var handle: Control = split._handle
	check(split.theme == desktop.theme, name + ": divider mirrors retained desktop theme")
	check(handle.size == Vector2(64, 64), name + ": divider retains safe hit target")
	check(angela.get_global_rect().encloses(handle.get_global_rect()), name + ": divider stays on Angela side")
	check(handle.grip_color == desktop.theme.get_color("face", "Desktop"), name + ": actual divider backing follows palette")
	check(handle.separator_color == desktop.theme.get_color("ink", "Desktop"), name + ": actual divider cue follows palette")
	check(handle.focus_color == desktop.theme.get_color("focus", "Desktop"), name + ": actual divider focus follows palette")
	check(art.get_child_count() > 0, name + ": authored art layers present")
	for layer: Node in art.get_children():
		if layer is TextureRect:
			check(layer.texture != null and layer.get_global_rect() == art.get_global_rect(), name + ": aligned full-panel art layer")
			check(layer.stretch_mode == TextureRect.STRETCH_KEEP_ASPECT_COVERED, name + ": artwork covers panel without reserved strip")
	check(desktop.theme.default_font_size == int(24 * int(fixture.percent) / 100), name + ": requested retained desktop text size")
	check(desktop.get_global_rect().encloses(desktop.home_button.get_global_rect()), name + ": desktop Home remains visible")

func _art_geometry() -> Array:
	var geometry := [art.get_global_rect()]
	for layer: Node in art.get_children():
		if layer is TextureRect: geometry.append([layer.get_global_rect(), layer.stretch_mode, layer.texture])
	return geometry

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
		for frame in 3: await RenderingServer.frame_post_draw
		var reference: Image = viewport.get_texture().get_image()
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
