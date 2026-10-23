extends "res://addons/gut/test.gd"

const HOST_TEST := preload("res://tests/integration/test_run_palette_host.gd")
const DESKTOP := preload("res://scenes/desktop/ComputerDesktop.tscn")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")


func _fixture(with_preferences: bool = false) -> Dictionary:
	var run: Dictionary = HOST_TEST.make_captured_run(true)
	assert_true(run.get("ok", false), JSON.stringify(run))
	if not run.get("ok", false):
		return {}
	add_child_autofree(run.value.state)
	var viewport := SubViewport.new()
	viewport.size = Vector2i(800, 720)
	add_child_autofree(viewport)
	var desktop: Control = DESKTOP.instantiate()
	desktop.set_script(HOST_TEST.IsolatedDesktop)
	assert_true(desktop.configure_run_configuration(run.value.state).ok)
	viewport.add_child(desktop)
	var result := {"desktop": desktop, "state": run.value.state}
	if with_preferences:
		var profile := HOST_TEST.PROFILE.new()
		add_child_autofree(profile)
		assert_true(profile.initialize(HOST_TEST.STORAGE.new("desktop-week-memory", HOST_TEST.FILES.new())).ok)
		var locale := HOST_TEST.LOCALIZATION.new()
		add_child_autofree(locale)
		assert_true(locale.initialize(profile).ok)
		var host := HOST_TEST.HOST.new()
		host.reset(1)
		assert_true(HOST_TEST.bind_apps(desktop, run.value.state, run.value.issuer, locale, profile, host).ok)
		result.profile = profile
	return result


func _settle() -> void:
	for frame in 3:
		await get_tree().process_frame


func test_day_one_desktop_theme_is_the_shipped_midnight_face() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	await _settle()
	assert_eq(f.desktop.theme.get_color("face", "Desktop"), Color("14201d"))
	assert_eq(f.desktop.theme.get_color("habitat", "Desktop"), Color("0d1514"))


func test_day_advance_eviction_rebuilds_the_theme_with_the_day_seven_tint() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	await _settle()
	var evicted: Dictionary = f.desktop.dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 7})
	assert_true(evicted.get("ok", false), str(evicted))
	await _settle()
	var expected := DESKTOP_THEME.build("en", 100, &"midnight", WEEK_TINT.tint_for_day(7))
	assert_eq(f.desktop.theme.get_color("face", "Desktop"), expected.get_color("face", "Desktop"))
	assert_ne(f.desktop.theme.get_color("face", "Desktop"), Color("14201d"), "Day 7 is colder than Day 1")
	assert_eq(f.desktop.theme.get_color("ink", "Desktop"), Color("d8cfb7"), "ink never tints")


func test_ordinary_refresh_reuses_the_same_day_tint() -> void:
	var f := _fixture()
	if f.is_empty():
		return
	await _settle()
	assert_true(f.desktop.dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 3}).ok)
	await _settle()
	var day_three: Color = f.desktop.theme.get_color("face", "Desktop")
	f.desktop._refresh_launcher()
	await _settle()
	assert_eq(f.desktop.theme.get_color("face", "Desktop"), day_three, "an ordinary refresh reuses the same day, so the tint is unchanged")
	assert_eq(day_three, DESKTOP_THEME.build("en", 100, &"midnight", WEEK_TINT.tint_for_day(3)).get_color("face", "Desktop"))


func test_live_accessibility_preferences_reach_installed_dark_desktop_without_mutating_run() -> void:
	var f := _fixture(true)
	if f.is_empty(): return
	await _settle()
	var before: Dictionary = f.state.capture_run_snapshot_input()
	assert_true(f.desktop.dispatch_desktop_eviction({"kind": &"evict_cached_apps", "day": 7}).ok)
	assert_true(f.profile.set_preference(&"preferences.accessibility.high_contrast", true).ok)
	await _settle()
	var high: Dictionary = PALETTES.resolve(&"midnight", true, "standard")
	assert_eq(f.desktop.theme.get_color("face", "Desktop"), high.face)
	assert_true(f.profile.set_preference(&"preferences.accessibility.colour_differentiation", "deutan").ok)
	await _settle()
	assert_eq(f.desktop.theme.get_color("focus", "Desktop"), PALETTES.resolve(&"midnight", true, "deutan").focus)
	assert_true(f.profile.set_preference(&"preferences.accessibility.high_contrast", false).ok)
	await _settle()
	var cvd: Dictionary = PALETTES.resolve(&"midnight", false, "deutan")
	assert_lt(f.desktop.theme.get_color("face", "Desktop").ok_hsl_l, cvd.face.ok_hsl_l)
	assert_eq(f.desktop.theme.get_color("structure", "Desktop"), cvd.structure)
	assert_eq(f.state.capture_run_snapshot_input(), before, "theme refresh cannot rewrite gameplay state")
