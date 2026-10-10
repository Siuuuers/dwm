extends "res://addons/gut/test.gd"

const HUD := preload("res://scenes/shared/StatHud.tscn")
const DESKTOP_THEME := preload("res://scripts/ui/desktop/DesktopTheme.gd")
const WEEK_TINT := preload("res://scripts/ui/theme/WeekTint.gd")
const PALETTES := preload("res://scripts/settings/SettingsPaletteRegistry.gd")


class OwnerFixture extends Node:
	signal day_changed(day: int)
	signal save_relevant_state_changed()
	var configuration: Dictionary = {"ok": false}
	var day: int = 1
	var money: int = 0
	var coins: int = 0
	var condition_effects_today: Array = []
	var penalty_points_today: int = 0
	func get_stat_display_value(_stat: String) -> int: return 0
	func get_stat_display_max(_stat: String) -> int: return 9
	func get_run_configuration() -> Dictionary: return configuration.duplicate(true)
	func advance_to(new_day: int) -> void:
		day = new_day
		day_changed.emit(new_day)


class ProfileFixture extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	var values: Dictionary = {}
	func get_preference(path: String, fallback: Variant = null) -> Variant:
		return values.get(path, fallback)
	func change(path: StringName, value: Variant) -> void:
		values[String(path)] = value
		preference_changed.emit(path, value)


func _fixture(configuration: Dictionary = {"ok": false}) -> Dictionary:
	var owner := OwnerFixture.new()
	owner.configuration = configuration
	var profile := ProfileFixture.new()
	var hud: Control = HUD.instantiate()
	hud.configure(owner, null, profile)
	add_child_autofree(hud)
	add_child_autofree(owner)
	return {"hud": hud, "owner": owner, "profile": profile}


func test_day_one_hud_theme_is_the_shipped_face() -> void:
	var f := _fixture()
	assert_eq(f.hud.theme.get_color("face", "Desktop"), Color("151b25"))


func test_day_changed_rebuilds_the_hud_theme_with_the_tint() -> void:
	var f := _fixture()
	f.owner.advance_to(7)
	var expected := DESKTOP_THEME.build("en", 100, &"after_hours", WEEK_TINT.tint_for_day(7))
	assert_eq(f.hud.theme.get_color("face", "Desktop"), expected.get_color("face", "Desktop"))
	assert_ne(f.hud.theme.get_color("face", "Desktop"), Color("151b25"))
	assert_eq(f.hud.theme.get_color("ink", "Desktop"), Color("d8cfb7"), "ink never tints")


func test_same_day_refresh_keeps_the_cached_theme_instance() -> void:
	var f := _fixture()
	f.owner.advance_to(4)
	var built: Theme = f.hud.theme
	f.hud.refresh_all()
	assert_true(f.hud.theme == built, "no rebuild when locale, size and day are unchanged")


func test_installed_run_selects_palette_and_next_run_preference_cannot_change_it() -> void:
	for dark: bool in [false, true]:
		var f := _fixture({"ok": true, "value": {"dark_mode": dark}})
		var face := Color("14201d") if dark else Color("151b25")
		assert_eq(f.hud.theme.get_color("face", "Desktop"), face)
		var built: Theme = f.hud.theme
		f.profile.change(&"preferences.dark_mode.next_run_enabled", not dark)
		assert_same(f.hud.theme, built, "a preference for the next account is not current run state")
		f.owner.advance_to(7)
		assert_lt(f.hud.theme.get_color("face", "Desktop").ok_hsl_l, face.ok_hsl_l)


func test_installation_refreshes_same_day_cached_fallback() -> void:
	var f := _fixture()
	assert_eq(f.hud.theme.get_color("face", "Desktop"), Color("151b25"))
	f.owner.configuration = {"ok": true, "value": {"dark_mode": true}}
	f.owner.save_relevant_state_changed.emit()
	assert_eq(f.hud.theme.get_color("face", "Desktop"), Color("14201d"))


func test_silent_installation_boundaries_refresh_without_owner_stat_signals() -> void:
	var f := _fixture()
	var bootstrap := get_node_or_null("/root/ApplicationBootstrap")
	var saves := get_node_or_null("/root/SaveManager")
	assert_not_null(bootstrap)
	assert_not_null(saves)
	if bootstrap == null or saves == null: return
	f.owner.configuration = {"ok": true, "value": {"dark_mode": true}}
	bootstrap.application_ready.emit()
	assert_eq(f.hud.theme.get_color("face", "Desktop"), Color("14201d"))
	f.owner.configuration = {"ok": true, "value": {"dark_mode": false}}
	saves.live_session_ready.emit()
	assert_eq(f.hud.theme.get_color("face", "Desktop"), Color("151b25"))


func test_live_accessibility_changes_rebuild_hud_and_high_contrast_has_no_week_tint() -> void:
	var f := _fixture({"ok": true, "value": {"dark_mode": true}})
	f.owner.advance_to(7)
	f.profile.change(&"preferences.accessibility.high_contrast", true)
	for preset: String in ["standard", "protan", "deutan", "tritan"]:
		f.profile.change(&"preferences.accessibility.colour_differentiation", preset)
		var roles: Dictionary = PALETTES.resolve(&"midnight", true, preset)
		for role: String in ["face", "habitat", "ink", "focus", "structure"]:
			assert_eq(f.hud.theme.get_color(role, "Desktop"), roles[role])
		assert_eq(f.hud.get_theme_stylebox("panel").bg_color, roles.habitat)
	f.profile.change(&"preferences.accessibility.high_contrast", false)
	var base: Dictionary = PALETTES.resolve(&"midnight", false, "tritan")
	assert_lt(f.hud.theme.get_color("face", "Desktop").ok_hsl_l, base.face.ok_hsl_l)
	assert_eq(f.hud.theme.get_color("structure", "Desktop"), base.structure, "CVD suppresses saturation drift")
	assert_eq(f.hud.theme.get_color("focus", "Desktop"), base.focus)

func test_font_style_alone_rebuilds_cached_hud_and_pixel_day_heading_uses_whole_pixels() -> void:
	var f := _fixture()
	var typography := preload("res://scripts/ui/UiTypography.gd")
	var original_copy: String = f.hud.get_node("%PressureRow").text
	for percent: int in [100,125,150]:
		f.profile.change(&"preferences.accessibility.text_size",percent)
		for style: String in ["readable","pixel"]:
			var previous: Theme = f.hud.theme
			f.profile.change(&"preferences.accessibility.font_style",style)
			assert_not_same(f.hud.theme,previous)
			assert_same(f.hud.theme.default_font.base_font,typography.font("en",percent,style))
			assert_eq(f.hud.get_node("%PressureRow").text,original_copy)
			if style == "pixel":
				assert_eq(f.hud.get_node("%DayLabel").get_theme_font_size("font_size"),32*percent/100)
			var installed: Theme = f.hud.theme
			f.hud.refresh_all()
			assert_same(f.hud.theme,installed,"Ordinary stat refresh retains the chosen style cache.")
