extends "res://addons/gut/test.gd"
## Accepted Standard palettes through actual Settings/Profile/Localization owners.

const OWNERS := preload("res://tests/unit/test_settings_controls_reset.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const CONTENT := preload("res://scenes/shared/SettingsContent.tscn")
const THEME := preload("res://scripts/ui/SettingsTheme.gd")
const EXPECTED := {
	&"after_hours": {"habitat": Color("0b0d13"), "face": Color("151b25"), "paper_ink": Color("151b25")},
	&"midnight": {"habitat": Color("0d1514"), "face": Color("14201d"), "paper_ink": Color("14201d")},
}
const SHARED := {
	"paper": Color("c3baa3"), "secondary_ink": Color("2f2936"), "ink": Color("d8cfb7"),
	"structure": Color("657d89"), "filed": Color("789083"), "focus": Color("a9935f"),
	"paper_focus": Color("644000"), "danger": Color("c9846e"), "destructive": Color("dd7a7f"),
	"secondary_dark_ink": Color("9ea8a2"), "inward_preview": Color("2f2936"),
}
var _surface: SubViewport
var _fixtures: Array[Dictionary] = []


class PaletteProfile extends "res://autoload/ProfileManager.gd":
	var dark_reads: Array[StringName] = []
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		if String(path).begins_with("preferences.dark_mode."):
			dark_reads.append(path)
		return super.get_preference(path, fallback)


func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(800, 656)
	_surface.gui_embed_subwindows = true
	add_child_autofree(_surface)


func after_each() -> void:
	for fixture: Dictionary in _fixtures:
		for id: String in ["content", "localization", "profile"]:
			if is_instance_valid(fixture[id]):
				fixture[id].free()
	_fixtures.clear()


func _fixture(palette: StringName = &"after_hours", locale: String = "en", percent: int = 100, host: String = "title") -> Dictionary:
	var ops := OWNERS.FILES.new()
	var profile := PaletteProfile.new()
	add_child(profile)
	assert_true(profile.initialize(OWNERS.STORAGE.new("settings-palette.memory", ops)).get("ok", false))
	var localization := LOCALIZATION.new()
	add_child(localization)
	assert_true(localization.initialize(profile).get("ok", false))
	assert_true(localization.set_locale(locale).get("ok", false))
	var candidate: Dictionary = profile.get_profile_snapshot()
	candidate.preferences.accessibility.text_size = percent
	candidate.preferences.accessibility.large_targets = true
	candidate.preferences.dark_mode.available = true
	candidate.preferences.dark_mode.next_run_enabled = palette == &"midnight"
	assert_true(profile.commit_prepared_profile(candidate).get("ok", false))
	profile.dark_reads.clear()
	var before: Dictionary = profile.get_profile_snapshot()
	var revision: int = profile.get_profile_revision()
	var disk: Dictionary = ops.snapshot_persisted()
	var content: Control = CONTENT.instantiate()
	content.host_context = host
	content.configure_services({"profile": profile, "localization": localization, "audio": null, "tts": null, "volume": null, "input": null, "profile_reset_admission": func() -> bool: return true})
	_surface.add_child(content)
	var fixture := {"content": content, "profile": profile, "localization": localization, "ops": ops, "before": before, "revision": revision, "disk": disk}
	_fixtures.append(fixture)
	return fixture


func _settle() -> void:
	for frame: int in range(4):
		await get_tree().process_frame


func _key(keycode: int) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = keycode
		event.physical_keycode = keycode
		event.pressed = pressed
		_surface.push_input(event)
		await _settle()


func test_both_standard_palettes_preserve_geometry_and_native_bindings_in_nine_presentations() -> void:
	for palette: StringName in EXPECTED:
		for locale: String in ["en", "zh_CN", "zh_HK"]:
			for percent: int in [100, 125, 150]:
				var fixture := _fixture(palette, locale, percent)
				var content: Control = fixture.content
				await _settle()
				var context := "%s %s %d%%" % [palette, locale, percent]
				assert_eq(content.get_palette_id(), palette, context)
				assert_eq(content.get_rect(), Rect2(0, 0, 800, 656), context)
				for entry: Array in [
					["RailScroll", Rect2(16, 16, 208, 624)], ["SheetScroll", Rect2(240, 96, 544, 400)],
					["Heading", Rect2(240, 16, 544, 80)], ["Footer", Rect2(240, 496, 544, 144)],
				]:
					assert_eq(content.get_node(entry[0]).get_rect(), entry[1], context + ": " + entry[0])
				assert_eq(content.theme.default_font_size, int(24 * percent / 100.0), context)
				_assert_roles(content, palette)
				_assert_component_roles(content, palette)
				_assert_next_run_control_without_palette_selector(content)
				assert_eq(fixture.profile.get_profile_snapshot(), fixture.before, context + ": projection preserves profile")
				assert_eq(fixture.profile.get_profile_revision(), fixture.revision, context + ": no presentation commit")
				assert_eq(fixture.ops.snapshot_persisted(), fixture.disk, context + ": no disk rewrite")
				content.free()


func test_simultaneous_palettes_do_not_recolour_other_instances_or_their_native_resources() -> void:
	var first := _fixture(&"after_hours", "en", 100)
	var second := _fixture(&"midnight", "zh_HK", 150)
	var light: Control = first.content
	var dark: Control = second.content
	await _settle()
	assert_ne(light.theme, dark.theme)
	var original_light_theme: Theme = light.theme
	var light_check: Texture2D = light.control_for(&"preferences.accessibility.large_targets").get_theme_icon("checked")
	var original_light_pixels: PackedByteArray = light_check.get_image().get_data()
	assert_ne(light.confirmations.controls.theme, dark.confirmations.controls.theme)
	_assert_component_roles(light, &"after_hours")
	_assert_component_roles(dark, &"midnight")
	assert_true(second.profile.set_preference(&"preferences.dark_mode.next_run_enabled", false).get("ok", false))
	await _settle()
	assert_eq(light.theme, original_light_theme, "Refreshing another instance cannot replace this instance's theme")
	assert_eq(light_check.get_image().get_data(), original_light_pixels, "No mutation of shared icon resources")
	_assert_roles(light, &"after_hours")
	_assert_component_roles(light, &"after_hours")
	_assert_component_roles(dark, &"after_hours")
	assert_true(first.profile.set_preference(&"preferences.dark_mode.next_run_enabled", true).get("ok", false))
	await _settle()
	_assert_component_roles(light, &"midnight")
	_assert_component_roles(dark, &"after_hours")


func test_title_pending_dark_changes_existing_native_popup_without_extra_profile_writes() -> void:
	var fixture := _fixture()
	var content: Control = fixture.content
	await _settle()
	content.focus_sheet()
	var option: OptionButton = content.control_for(&"preferences.language.primary_locale_id")
	await _key(KEY_SPACE)
	assert_true(option.get_popup().visible, "An actual native popup participates in palette changes")
	assert_true(fixture.profile.set_preference(&"preferences.dark_mode.next_run_enabled", true).get("ok", false))
	var expected: Dictionary = fixture.profile.get_profile_snapshot()
	var revision: int = fixture.profile.get_profile_revision()
	var disk: Dictionary = fixture.ops.snapshot_persisted()
	await _settle()
	assert_eq(content.get_palette_id(), &"midnight")
	_assert_component_roles(content, &"midnight")
	_assert_next_run_control_without_palette_selector(content)
	assert_eq(fixture.profile.get_profile_snapshot(), expected)
	assert_eq(fixture.profile.get_profile_revision(), revision, "Only the explicit title intent write occurred")
	assert_eq(fixture.ops.snapshot_persisted(), disk, "Palette refresh has no persistence side effect")
	await _key(KEY_ESCAPE)
	assert_false(option.get_popup().visible)


func test_desktop_and_pause_never_project_pending_title_intent_as_captured_run_dark() -> void:
	for host: String in ["desktop", "pause"]:
		var fixture := _fixture(&"midnight", "zh_CN", 125, host)
		var content: Control = fixture.content
		await _settle()
		_assert_captured_palette_lookup(fixture, &"after_hours")
		_assert_roles(content, &"after_hours")
		_assert_next_run_control_without_palette_selector(content)
		assert_true(fixture.profile.set_preference(&"preferences.dark_mode.next_run_enabled", false).get("ok", false))
		await _settle()
		_assert_captured_palette_lookup(fixture, &"after_hours")
		_assert_roles(content, &"after_hours")
		content.free()


func test_run_hosts_follow_captured_palette_and_day_while_pending_title_dark_changes() -> void:
	for host: String in ["desktop", "pause"]:
		var fixture := _fixture(&"after_hours", "en", 100, host)
		var content: Control = fixture.content
		assert_true(content.configure_run_presentation(&"midnight", 6).get("ok", false))
		await _settle()
		var expected: Theme = THEME.build("en", 100, &"midnight", false, "standard", 6)
		assert_eq(content.get_palette_id(), &"midnight", host)
		assert_eq(content.theme.get_color("paper", "Settings"), expected.get_color("paper", "Settings"), host)
		assert_eq(content.theme.get_color("face", "Settings"), expected.get_color("face", "Settings"), host)
		_assert_captured_palette_lookup(fixture, &"midnight")
		assert_true(fixture.profile.set_preference(&"preferences.dark_mode.next_run_enabled", true).get("ok", false))
		await _settle()
		assert_eq(content.get_palette_id(), &"midnight", host + ": pending title intent cannot replace captured palette")
		assert_eq(content.theme.get_color("paper", "Settings"), expected.get_color("paper", "Settings"))
		_assert_captured_palette_lookup(fixture, &"midnight")
		content.free()


func test_rejected_run_context_leaves_visible_settings_presentation_atomic() -> void:
	var fixture := _fixture(&"after_hours", "en", 100, "desktop")
	var content: Control = fixture.content
	assert_true(content.configure_run_presentation(&"midnight", 7).get("ok", false))
	await _settle()
	var theme: Theme = content.theme
	var profile: Dictionary = fixture.profile.get_profile_snapshot()
	var revision: int = fixture.profile.get_profile_revision()
	var disk: Dictionary = fixture.ops.snapshot_persisted()
	for request: Array in [[&"unregistered", 7], [&"after_hours", 0]]:
		assert_false(content.configure_run_presentation(request[0], request[1]).get("ok", false))
		assert_eq(content.theme, theme)
		assert_eq(content.get_palette_id(), &"midnight")
		assert_eq(content.get("_run_day"), 7)
	assert_eq(fixture.profile.get_profile_snapshot(), profile)
	assert_eq(fixture.profile.get_profile_revision(), revision)
	assert_eq(fixture.ops.snapshot_persisted(), disk)


func test_title_preview_keeps_day_one_even_if_a_run_day_is_supplied() -> void:
	var fixture := _fixture(&"after_hours", "en", 100, "title")
	var content: Control = fixture.content
	assert_true(content.configure_run_presentation(&"midnight", 7).get("ok", false))
	await _settle()
	var expected: Theme = THEME.build("en", 100, &"after_hours", false, "standard", 1)
	assert_eq(content.get_palette_id(), &"after_hours")
	assert_eq(content.theme.get_color("paper", "Settings"), expected.get_color("paper", "Settings"))
	assert_true(fixture.profile.set_preference(&"preferences.dark_mode.next_run_enabled", true).get("ok", false))
	await _settle()
	expected = THEME.build("en", 100, &"midnight", false, "standard", 1)
	assert_eq(content.get_palette_id(), &"midnight")
	assert_eq(content.theme.get_color("paper", "Settings"), expected.get_color("paper", "Settings"))


func _assert_roles(content: Control, palette: StringName) -> void:
	for role: String in EXPECTED[palette]:
		assert_eq(content.theme.get_color(role, "Settings"), EXPECTED[palette][role], "%s %s" % [palette, role])
	for role: String in SHARED:
		assert_eq(content.theme.get_color(role, "Settings"), SHARED[role], "%s invariant %s" % [palette, role])


func _assert_component_roles(content: Control, palette: StringName) -> void:
	var roles: Dictionary = EXPECTED[palette]
	var option: OptionButton = content.control_for(&"preferences.language.primary_locale_id")
	var popup := option.get_popup()
	var popup_panel: StyleBoxFlat = popup.get_theme_stylebox("panel")
	assert_eq(popup_panel.bg_color, SHARED.paper)
	assert_eq(popup_panel.border_color, roles.paper_ink, "Native popup inherits the current paper structure")
	assert_eq(popup.get_theme_color("font_color"), roles.paper_ink)
	var checkbox: CheckBox = content.control_for(&"preferences.accessibility.large_targets")
	for state: String in ["checked", "checked_disabled", "unchecked", "unchecked_disabled"]:
		var icon: Texture2D = checkbox.get_theme_icon(state)
		assert_eq(icon.get_image().get_pixel(2, 2), roles.paper_ink, String(palette) + ": checkbox border " + state)
	assert_eq(option.get_theme_icon("arrow").get_image().get_pixel(2, 6), roles.paper_ink, "Arrow is painted from the instance palette")
	var selected: Button = content.get_node("RailScroll/Rail/LanguageCategory")
	var selected_label: Label = selected.get_child(0)
	assert_eq(selected_label.get_theme_color("font_color"), roles.paper_ink, "Selected directory ink")
	var ordinary: Button = content.get_node("RailScroll/Rail/AudioCategory")
	var face: StyleBoxFlat = ordinary.get_theme_stylebox("normal")
	assert_eq(face.bg_color, roles.face, "Directory style overrides refresh with the palette")
	for entry: Array in [[content.rail_scroll, false], [content.sheet_scroll, true]]:
		var scroll: ScrollContainer = entry[0]
		var paper: bool = entry[1]
		var panel: StyleBoxFlat = scroll.get_theme_stylebox("panel")
		var track: StyleBoxFlat = scroll.get_v_scroll_bar().get_theme_stylebox("scroll")
		var thumb: StyleBoxFlat = scroll.get_v_scroll_bar().get_theme_stylebox("grabber")
		assert_eq(panel.bg_color, SHARED.paper if paper else roles.face)
		assert_eq(track.border_color, roles.paper_ink if paper else SHARED.structure)
		assert_eq(thumb.bg_color, SHARED.paper_focus if paper else SHARED.ink)
	for dialog: ConfirmationDialog in content.confirmations.values():
		var panel: StyleBoxFlat = dialog.theme.get_stylebox("panel", "AcceptDialog")
		var border: StyleBoxFlat = dialog.theme.get_stylebox("embedded_border", "Window")
		assert_eq(panel.bg_color, SHARED.paper)
		assert_eq(border.border_color, roles.paper_ink, "Reset native frame inherits the palette")
		for button: Button in [dialog.get_cancel_button(), dialog.get_ok_button()]:
			var normal: StyleBoxFlat = button.get_theme_stylebox("normal")
			assert_eq(normal.bg_color, roles.face, "Reset action override stays on the selected controlled face")
			assert_eq(button.get_theme_color("font_color"), SHARED.ink)


func _assert_captured_palette_lookup(fixture: Dictionary, palette: StringName) -> void:
	# The discovered next-run row legitimately reads Profile during a refresh.
	# Resolving the current run's palette must not consult that pending intent.
	fixture.profile.dark_reads.clear()
	assert_eq(fixture.content.get_palette_id(), palette)
	assert_eq(fixture.profile.dark_reads, [], "captured palette lookup is independent of pending next-run intent")


func _assert_next_run_control_without_palette_selector(content: Control) -> void:
	# The September 12 amendment retains the discovery-controlled next-run row.
	# It selects a future run mode, never the base palette of an installed run.
	assert_false(content.controls.has(&"preferences.dark_mode.available"))
	assert_true(content.controls.has(&"preferences.dark_mode.next_run_enabled"))
	assert_true(content.rows[&"preferences.dark_mode.next_run_enabled"].visible, "fixture has discovered Dark mode")
	assert_false(content.get_category_ids().has("dark_mode"))
	for path: StringName in content.controls:
		assert_false(String(path).contains("palette"), "no independent base-palette selector")
