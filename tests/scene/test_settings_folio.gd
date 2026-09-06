extends "res://addons/gut/test.gd"
## Real SettingsContent and controller with existing isolated service doubles.

const FIXTURES := preload("res://tests/scene/test_settings_localization_scene.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FAKE_OPS := preload("res://tests/support/FakeFileOps.gd")
const CONTENT := preload("res://scenes/shared/SettingsContent.tscn")
const CATEGORIES := ["language", "reading", "audio", "display", "controls", "accessibility", "records"]
const LOCALES := ["en", "zh_CN", "zh_HK"]
const SIZES := [100, 125, 150]

var _surface: SubViewport
var _original_locale := "en"


func before_all() -> void:
	var profile := get_node("/root/ProfileManager")
	if not bool(profile.get("_initialized")):
		assert_true(profile.initialize(STORAGE.new("settings-folio-tests", FAKE_OPS.new())).get("ok", false))
	var localization := get_node("/root/LocalizationManager")
	if localization.get_readiness() == &"uninitialized":
		assert_true(localization.initialize(profile).get("ok", false))
	_original_locale = localization.get_locale()


func after_all() -> void:
	assert_true(get_node("/root/LocalizationManager").set_locale(_original_locale).get("ok", false))


func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(800, 656)
	_surface.gui_embed_subwindows = true
	add_child_autofree(_surface)


func _fixture(locale: String = "en", percent: int = 100, large_targets: bool = false) -> Dictionary:
	var localization := get_node("/root/LocalizationManager")
	assert_true(localization.set_locale(locale).get("ok", false), locale)
	var profile := FIXTURES.FakeSettingsProfile.new()
	profile.values[&"preferences.language.primary_locale_id"] = locale
	profile.values[&"preferences.accessibility.text_size"] = percent
	profile.values[&"preferences.accessibility.large_targets"] = large_targets
	profile.values[&"preferences.language.dual_enabled"] = true
	profile.values[&"preferences.reading.auto_enabled"] = true
	profile.values[&"preferences.exceptional_replay.available"] = true
	var volume := FIXTURES.FakeVolumeSink.new()
	volume.profile = profile
	var audio := FIXTURES.FakeSettingsAudio.new()
	var tts := FIXTURES.FakeSettingsTts.new()
	var content: Control = CONTENT.instantiate()
	content.configure_services({"profile": profile, "localization": localization, "audio": audio, "tts": tts, "volume": volume, "input": null})
	_surface.add_child(content)
	return {"content": content, "profile": profile, "audio": audio, "tts": tts, "volume": volume}


func _settle() -> void:
	for frame: int in range(4):
		await get_tree().process_frame


func test_fixed_geometry_fonts_and_targets_in_all_eighteen_presentations() -> void:
	for locale: String in LOCALES:
		for percent: int in SIZES:
			for large: bool in [false, true]:
				var fixture := _fixture(locale, percent, large)
				var content: Control = fixture.content
				await _settle()
				var context := "%s %d%% large=%s" % [locale, percent, large]
				assert_eq(content.size, Vector2(800, 656), context)
				for entry: Array in [
					["RailScroll", Rect2(16, 16, 208, 624)],
					["SheetScroll", Rect2(240, 96, 544, 400)],
					["Heading", Rect2(240, 16, 544, 80)],
					["Footer", Rect2(240, 496, 544, 144)],
				]:
					assert_eq(content.get_node(entry[0]).get_rect(), entry[1], context + ": " + entry[0])
				assert_eq(_scrolls(content).size(), 2, context + ": exactly two scroll owners")
				for scroll: ScrollContainer in _scrolls(content):
					assert_eq(scroll.horizontal_scroll_mode, ScrollContainer.SCROLL_MODE_DISABLED, context)
					assert_eq(scroll.scroll_horizontal, 0, context)
				var expected_size := int(24 * percent / 100.0)
				var option: OptionButton = content.control_for(&"preferences.language.primary_locale_id")
				assert_eq(option.get_theme_font_size("font_size"), expected_size, context)
				var rail_style: StyleBoxFlat = content.get_node("RailScroll").get_theme_stylebox("panel")
				var folio_style: StyleBoxFlat = content.get_node("SheetScroll").get_theme_stylebox("panel")
				assert_eq(rail_style.bg_color, content.theme.get_color("face", "Settings"), context + ": dark directory")
				assert_eq(folio_style.bg_color, content.theme.get_color("paper", "Settings"), context + ": cream folio")
				assert_ne(rail_style.bg_color, folio_style.bg_color, context + ": paper does not spill into directory")
				assert_eq(option.get_theme_color("font_color"), content.theme.get_color("paper_ink", "Settings"), context + ": folio ink")
				var directory_label: Label = content.get_node("RailScroll/Rail/AudioCategory").get_child(0)
				assert_eq(directory_label.get_theme_color("font_color"), content.theme.get_color("ink", "Settings"), context + ": directory ink")
				var font: Font = option.get_theme_font("font")
				for character: String in ["A", "a", "0", "语", "言", "語", "中", "文", "漢", "字"]:
					assert_true(font.has_char(character.unicode_at(0)), context + ": glyph " + character)
				for control: Control in content.controls.values():
					assert_gte(control.custom_minimum_size.y, 64.0 if large else 48.0, context + ": " + control.name)
				for label: Label in content.wrapping_labels():
					assert_eq(label.autowrap_mode, TextServer.AUTOWRAP_WORD_SMART, context)
					assert_eq(label.get_theme_font_size("font_size"), expected_size, context)
					if label.get_parent() is Button:
						assert_true(label.get_parent().get_global_rect().encloses(label.get_global_rect()), context + ": complete rail caption " + label.text)
				assert_eq(fixture.profile.commits, [], context + ": presentation does not write preferences")
				content.free()


func test_every_enabled_control_can_be_revealed_at_all_locales_and_sizes() -> void:
	for locale: String in LOCALES:
		for percent: int in SIZES:
			var fixture := _fixture(locale, percent, true)
			var content: Control = fixture.content
			for category: String in CATEGORIES:
				content.select_category(category)
				await _settle()
				var rail: ScrollContainer = content.get_node("RailScroll")
				var category_button: Button = content.get_node("RailScroll/Rail/" + category.to_pascal_case() + "Category")
				category_button.grab_focus()
				await _settle()
				_assert_inside(category_button.get_global_rect().grow(8), rail.get_global_rect(), "%s %d%% %s directory Focus" % [locale, percent, category])
				var sheet: ScrollContainer = content.get_node("SheetScroll")
				for control: Control in _focusables(sheet):
					control.grab_focus()
					await _settle()
					var context := "%s %d%% %s/%s" % [locale, percent, category, control.name]
					assert_true(control.has_focus(), context)
					_assert_inside(control.get_global_rect().grow(8), sheet.get_global_rect(), context + ": complete detached Focus")
					assert_eq(sheet.scroll_horizontal, 0, context)
				for label: Label in content.wrapping_labels():
					if label.is_visible_in_tree() and sheet.is_ancestor_of(label) and not label.text.is_empty():
						assert_gte(label.size.y + 1.0, label.get_minimum_size().y, category + ": full wrapped height")
			assert_eq(fixture.profile.commits, [], "Navigation must not commit values")
			assert_eq(fixture.audio.starts, [], "Inspecting Audio must not start a sample")
			assert_eq(fixture.tts.requests, [], "Inspecting Reading must not start speech")
			content.free()


func test_selected_category_and_focus_have_independent_evidence() -> void:
	var fixture := _fixture()
	var content: Control = fixture.content
	content.select_category("audio")
	await _settle()
	var selected: Button = content.get_node("RailScroll/Rail/AudioCategory")
	var inspected: Button = content.get_node("RailScroll/Rail/LanguageCategory")
	inspected.grab_focus()
	await _settle()
	assert_true(selected.button_pressed)
	assert_false(inspected.button_pressed)
	assert_true(inspected.has_focus())
	assert_false(selected.has_focus())
	var selected_style: StyleBox = selected.get_theme_stylebox("pressed")
	var focus_style: StyleBox = inspected.get_theme_stylebox("focus")
	assert_ne(selected_style, focus_style, "Selection and Focus use separate paint carriers")
	if selected_style is StyleBoxFlat:
		assert_eq(selected_style.bg_color, content.theme.get_color("filed", "Settings"))
	if focus_style is StyleBoxFlat:
		assert_true(not focus_style.draw_center or focus_style.bg_color.a == 0.0, "Focus must not become another selected face")
	assert_true(content.get_node("SheetScroll/Sheets/AudioSheet").visible)
	assert_false(content.get_node("SheetScroll/Sheets/LanguageSheet").visible)


func test_real_input_enters_sheet_and_back_returns_to_selected_directory_row() -> void:
	var fixture := _fixture("en", 150, true)
	var content: Control = fixture.content
	content.select_category("audio")
	content.focus_rail()
	await _settle()
	await _press("ui_right")
	assert_true(content.sheet_has_focus(), "Right enters the selected folio")
	await _press("ui_cancel")
	assert_false(content.sheet_has_focus(), "One Back returns to the directory")
	assert_true(content.get_node("RailScroll/Rail/AudioCategory").has_focus())
	assert_eq(fixture.profile.commits, [])
	assert_eq(fixture.volume.previews, [])


func test_scroll_owners_keep_their_offsets_independent() -> void:
	var fixture := _fixture("zh_HK", 150, true)
	var content: Control = fixture.content
	content.select_category("audio")
	await _settle()
	var rail: ScrollContainer = content.get_node("RailScroll")
	var sheet: ScrollContainer = content.get_node("SheetScroll")
	sheet.scroll_vertical = 120
	await _settle()
	assert_gt(sheet.scroll_vertical, 0, "Audio has genuine overflow at 150%")
	var sheet_offset := sheet.scroll_vertical
	var rail_offset := rail.scroll_vertical
	content.get_node("RailScroll/Rail/RecordsCategory").grab_focus()
	await _settle()
	assert_eq(sheet.scroll_vertical, sheet_offset, "Directory focus must not scroll the folio")
	assert_gte(rail.scroll_vertical, rail_offset)
	rail_offset = rail.scroll_vertical
	sheet.scroll_vertical = 240
	await _settle()
	assert_eq(rail.scroll_vertical, rail_offset, "Folio scrolling must not scroll the directory")


func test_control_sample_is_noninteractive_and_only_in_accessibility_footer() -> void:
	var fixture := _fixture()
	var content: Control = fixture.content
	var sample: Control = content.get_node("Footer/ControlSample")
	for category: String in CATEGORIES:
		content.select_category(category)
		await _settle()
		assert_eq(sample.is_visible_in_tree(), category == "accessibility", category)
	assert_eq(sample.get_child_count(), 4, "Four fixed visual specimens")
	for name: String in ["Selected", "Focus", "Warning", "Unavailable"]:
		var specimen: Control = sample.get_node(name)
		assert_eq(specimen.focus_mode, Control.FOCUS_NONE, name)
		assert_eq(specimen.mouse_filter, Control.MOUSE_FILTER_IGNORE, name)
	assert_eq(_focusables(sample), [], "Specimens must not enter keyboard navigation")


func test_title_and_desktop_hosts_fit_the_complete_plate_without_close_overlap() -> void:
	_surface.size = Vector2i(1000, 760)
	for path: String in ["res://scenes/menu/Setting.tscn", "res://scenes/apps/SettingsApp.tscn"]:
		var host: Control = load(path).instantiate()
		_surface.add_child(host)
		host.show()
		await _settle()
		var content: Control = host.find_child("SettingsContent", true, false)
		assert_not_null(content, path)
		assert_gte(content.size.x, 800.0, path + ": complete plate width")
		assert_gte(content.size.y, 656.0, path + ": complete plate height")
		_assert_inside(Rect2(content.global_position, Vector2(800, 656)), host.get_global_rect(), path)
		assert_null(host.find_child("CloseButton", true, false), "Close belongs to the shell, not the plate")
		assert_null(host.find_child("TopBar", true, false), "Settings adds no second title bar")
		host.free()


func test_boolean_captions_use_localized_on_off_and_follow_committed_values() -> void:
	var expected := {"en": ["Off", "On"], "zh_CN": ["关闭", "开启"], "zh_HK": ["關閉", "開啟"]}
	for locale: String in LOCALES:
		var fixture := _fixture(locale)
		var content: Control = fixture.content
		content.select_category("accessibility")
		await _settle()
		for control: Control in content.controls.values():
			if control is CheckBox:
				assert_eq(control.text, expected[locale][1 if control.button_pressed else 0], locale + ": literal Boolean caption")
				assert_false(control.text.begins_with("settings."), "No localization key is player copy")
		var checkbox: CheckBox = content.control_for(&"preferences.accessibility.reduced_motion")
		assert_eq(checkbox.text, expected[locale][0])
		checkbox.button_pressed = true
		await _settle()
		assert_eq(checkbox.text, expected[locale][1], locale + ": committed On")
		assert_true(fixture.profile.get_preference(&"preferences.accessibility.reduced_motion"))
		checkbox.button_pressed = false
		await _settle()
		assert_eq(checkbox.text, expected[locale][0], locale + ": committed Off")
		assert_false(fixture.profile.get_preference(&"preferences.accessibility.reduced_motion"))
		assert_eq(fixture.profile.commits.size(), 2, "One owner commit per actual toggle")
		content.free()


func _press(action: String) -> void:
	var event := InputEventAction.new()
	event.action = action
	event.pressed = true
	_surface.push_input(event)
	await _settle()
	event = InputEventAction.new()
	event.action = action
	event.pressed = false
	_surface.push_input(event)
	await _settle()


func _assert_inside(inner: Rect2, outer: Rect2, context: String) -> void:
	assert_gte(inner.position.x + 1.0, outer.position.x, context + ": left")
	assert_gte(inner.position.y + 1.0, outer.position.y, context + ": top")
	assert_lte(inner.end.x - 1.0, outer.end.x, context + ": right")
	assert_lte(inner.end.y - 1.0, outer.end.y, context + ": bottom")


func _scrolls(node: Node) -> Array[ScrollContainer]:
	var found: Array[ScrollContainer] = []
	for child: Node in node.get_children():
		# Modal reviews own a separate viewport; they are not folio scroll areas.
		if child is Window:
			continue
		if child is ScrollContainer:
			found.append(child)
		found.append_array(_scrolls(child))
	return found


func _focusables(node: Node) -> Array[Control]:
	var found: Array[Control] = []
	for child: Node in node.get_children():
		if child is Control and child.is_visible_in_tree() and child.focus_mode == Control.FOCUS_ALL:
			if not (child is BaseButton and child.disabled) and not (child is Slider and not child.editable):
				found.append(child)
		found.append_array(_focusables(child))
	return found
