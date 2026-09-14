extends GutTest

const RAIL := preload("res://scripts/ui/witnessed/WitnessedTransportRail.gd")
const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const NAMES := ["History", "Skip", "Auto", "Save", "Load", "Next"]
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const LEFTS := [0, 212, 426, 640, 852, 1066]
const WIDTHS := [212, 214, 214, 212, 214, 214]
const COPY := {
	"en": ["History", "Skip", "Auto", "Save", "Load", "Next", "On", "Off"],
	"zh-CN": ["\u5386\u53f2", "\u8df3\u8fc7", "\u81ea\u52a8", "\u4fdd\u5b58", "\u8bfb\u53d6", "\u4e0b\u4e00\u6b65", "\u5f00", "\u5173"],
	"zh-HK": ["\u6b77\u53f2", "\u8df3\u904e", "\u81ea\u52d5", "\u5132\u5b58", "\u8f09\u5165", "\u4e0b\u4e00\u6b65", "\u958b", "\u95dc"],
}


var _localization: Node


func before_each() -> void:
	var profile: Node = autofree(PROFILE.new())
	assert_true(profile.initialize(STORAGE.new("witnessed-rail-localization", FILES.new())).get("ok", false))
	_localization = autofree(LOCALIZATION.new())
	assert_true(_localization.initialize(profile).get("ok", false))


func _new_rail(locale: String = "en") -> RAIL:
	assert_true(_localization.set_locale(locale.replace("-", "_")).get("ok", false))
	var rail := RAIL.new()
	assert_true(rail.bind_localization(_localization))
	return rail


class Admission extends RefCounted:
	var allowed := true
	func is_admitted() -> bool:
		return allowed


class InputOwner extends Node:
	signal source_input_custody_changed
	signal input_bindings_changed
	func get_physical_contacts() -> Dictionary:
		return {}
	func observe_physical_contact(_event: InputEvent) -> void:
		pass
	func get_physical_contact_id(_event: InputEvent) -> String:
		return ""
	func is_source_input_admitted() -> bool:
		return true


func _has_load_contract(rail: Control) -> bool:
	if not rail.has_method("bind_load_admission"):
		return false
	for method: Dictionary in rail.get_method_list():
		if method.name == "project":
			return (method.get("args", []) as Array).size() >= 5
	return false


func test_six_controls_cover_the_exact_scaled_native_hit_rectangles() -> void:
	var rail := _new_rail()
	assert_true(rail.configure_presentation(CAPTION_THEME.build("en", 100, "AfterHours"), "en"))
	add_child_autofree(rail)
	assert_eq(rail.position, Vector2(0, 656))
	assert_eq(rail.size, Vector2(1280, 64))
	assert_eq(rail.get_child_count(), 6, "the rail contains only the six physical controls")
	for index: int in NAMES.size():
		var button := rail.get_child(index) as Button
		assert_not_null(button)
		assert_eq(button.name, NAMES[index])
		assert_eq(button.position, Vector2(LEFTS[index], 0), NAMES[index])
		assert_eq(button.size, Vector2(WIDTHS[index], 64), NAMES[index])
		assert_eq(button.position.x + button.size.x,
			1280.0 if index == NAMES.size() - 1 else float(LEFTS[index + 1]),
			NAMES[index] + " shares its exact boundary")


func test_projection_keeps_placeholders_visible_disabled_and_modes_truthful() -> void:
	var rail := _new_rail()
	assert_true(rail.configure_presentation(CAPTION_THEME.build("en", 100, "AfterHours"), "en"))
	add_child_autofree(rail)
	assert_true(rail.project(true, false, true))
	for name: String in NAMES:
		var button := rail.get_node(name) as Button
		assert_true(button.visible)
		assert_eq(button.disabled, name != "Skip", name)
		assert_eq(button.focus_mode, Control.FOCUS_ALL if name == "Skip" else Control.FOCUS_NONE, name)
	assert_eq((rail.get_node("Skip") as Button).text, "Skip \u00b7 Off")
	assert_eq((rail.get_node("Auto") as Button).text, "Auto \u00b7 On",
		"profile Auto remains visibly On although its unowned command is disabled")
	assert_eq((rail.get_node("Auto") as Button).theme_type_variation, &"WitnessedTransportMode")
	assert_false(rail.project(true, true, true), "the forbidden Auto-plus-Skip projection is refused")
	assert_eq((rail.get_node("Skip") as Button).text, "Skip \u00b7 Off", "a refused projection changes nothing")
	assert_eq((rail.get_node("Auto") as Button).text, "Auto \u00b7 On")
	assert_true(rail.project(true, true, false))
	assert_eq((rail.get_node("Skip") as Button).text, "Skip \u00b7 On")
	assert_eq((rail.get_node("Auto") as Button).text, "Auto \u00b7 Off")
	assert_true(rail.project(false, false, false))
	assert_true((rail.get_node("Skip") as Button).disabled)
	assert_eq((rail.get_node("Skip") as Button).focus_mode, Control.FOCUS_NONE)
	assert_true((rail.get_node("Auto") as Button).disabled,
		"the compatible three-argument projection does not claim an Auto owner")
	assert_true(rail.project(false, false, false, true))
	assert_true((rail.get_node("Skip") as Button).disabled)
	assert_false((rail.get_node("Auto") as Button).disabled,
		"Auto admission is independent from Skip availability")
	assert_eq((rail.get_node("Auto") as Button).focus_mode, Control.FOCUS_ALL)


func test_auto_signal_has_its_own_binding_and_final_admission() -> void:
	var rail := _new_rail()
	assert_true(rail.configure_presentation(CAPTION_THEME.build("en", 100, "AfterHours"), "en"))
	var skip_admission := Admission.new()
	var auto_admission := Admission.new()
	var input_owner := InputOwner.new()
	add_child_autofree(input_owner)
	add_child_autofree(rail)
	assert_true(rail.bind_admission(skip_admission.is_admitted, input_owner))
	assert_true(rail.bind_auto_admission(auto_admission.is_admitted, input_owner))
	assert_true(rail.project(true, false, false, true))
	watch_signals(rail)
	(rail.get_node("Auto") as Button).pressed.emit()
	assert_signal_not_emitted(rail, "auto_requested",
		"programmatic Button.pressed is not Auto command admission")
	(rail.get_node("Auto") as Node).emit_signal(&"activated")
	assert_signal_emit_count(rail, "auto_requested", 1)
	skip_admission.allowed = false
	(rail.get_node("Skip") as Node).emit_signal(&"activated")
	assert_signal_not_emitted(rail, "skip_requested",
		"Auto admission cannot authorize Skip")
	auto_admission.allowed = false
	(rail.get_node("Auto") as Node).emit_signal(&"activated")
	assert_signal_emit_count(rail, "auto_requested", 1,
		"the rail rechecks the Auto owner at the activation boundary")
	skip_admission.allowed = true
	(rail.get_node("Skip") as Node).emit_signal(&"activated")
	assert_signal_emit_count(rail, "skip_requested", 1,
		"Auto refusal does not disable the independent Skip owner")


func test_load_signal_has_its_own_binding_projection_and_final_admission() -> void:
	var rail := _new_rail()
	assert_true(rail.configure_presentation(CAPTION_THEME.build("en", 100, "AfterHours"), "en"))
	var skip_admission := Admission.new()
	var load_admission := Admission.new()
	var input_owner := InputOwner.new()
	add_child_autofree(input_owner)
	add_child_autofree(rail)
	assert_true(rail.bind_admission(skip_admission.is_admitted, input_owner))
	if not _has_load_contract(rail):
		assert_true(false, "the rail must expose independent Load binding and projection")
		return
	assert_true(rail.call("bind_load_admission", load_admission.is_admitted, input_owner))
	assert_true(rail.call("project", false, false, false, false, true))
	var load := rail.get_node("Load") as Button
	assert_false(load.disabled, "Load has independent projected availability")
	assert_eq(load.focus_mode, Control.FOCUS_ALL)
	assert_true((rail.get_node("Save") as Button).disabled, "Save remains an unowned placeholder")
	assert_true((rail.get_node("Next") as Button).disabled, "Next remains an unowned placeholder")
	watch_signals(rail)
	load.pressed.emit()
	assert_signal_not_emitted(rail, "load_requested",
		"programmatic Button.pressed is not Load command admission")
	load.emit_signal(&"activated")
	assert_signal_emit_count(rail, "load_requested", 1)
	skip_admission.allowed = false
	load.emit_signal(&"activated")
	assert_signal_emit_count(rail, "load_requested", 2,
		"Skip admission cannot deny independently admitted Load")
	load_admission.allowed = false
	load.emit_signal(&"activated")
	assert_signal_emit_count(rail, "load_requested", 2,
		"the rail rechecks the Load owner at the activation boundary")


func test_load_projection_retires_stale_native_actions_without_steady_state_churn() -> void:
	var rail := _new_rail()
	assert_true(rail.configure_presentation(CAPTION_THEME.build("en", 100, "AfterHours"), "en"))
	var admission := Admission.new()
	var input_owner := InputOwner.new()
	add_child_autofree(input_owner)
	add_child_autofree(rail)
	if not _has_load_contract(rail):
		assert_true(false, "the rail must expose independent Load binding and projection")
		return
	assert_true(rail.call("bind_load_admission", admission.is_admitted, input_owner))
	assert_true(rail.call("project", false, false, false, false, true))
	await get_tree().process_frame
	var load := rail.get_node("Load") as Button
	var enabled_generation: int = int(load.get("_generation"))
	assert_true(rail.call("project", false, false, false, false, true))
	assert_eq(int(load.get("_generation")), enabled_generation,
		"an identical projection does not churn the Load input generation")
	load.grab_focus()
	assert_true(load.has_focus())
	assert_true(rail.call("project", false, false, false, false, false))
	assert_false(load.has_focus(), "disabled Load leaves Focus traversal")
	assert_eq(int(load.get("_generation")), enabled_generation + 1,
		"disabling Load retires exactly one input generation")
	var disabled_generation: int = int(load.get("_generation"))
	assert_true(rail.call("project", false, false, false, false, true))
	await get_tree().process_frame
	watch_signals(rail)
	load.call("_on_accessibility_click", null, enabled_generation)
	assert_signal_not_emitted(rail, "load_requested",
		"a native callback queued before disable cannot activate after re-enable")
	load.call("_on_accessibility_click", null, disabled_generation + 1)
	assert_signal_emit_count(rail, "load_requested", 1,
		"the current post-projection Load generation remains operable")
	var before_hide: int = int(load.get("_generation"))
	rail.hide()
	rail.show()
	await get_tree().process_frame
	assert_gt(int(load.get("_generation")), before_hide,
		"visibility retires Load with the rail")
	load.call("_on_accessibility_click", null, before_hide)
	assert_signal_emit_count(rail, "load_requested", 1,
		"a native Load callback queued before hide cannot activate after show")


func test_all_locales_and_text_sizes_keep_complete_labels_inside_their_plates() -> void:
	for locale: String in COPY:
		for percent: int in [100, 125, 150]:
			var context := "%s/%d%%/large-targets" % [locale, percent]
			var presentation: Theme = CAPTION_THEME.build(locale, percent,
				"AfterHours", false, "standard", true)
			assert_not_null(presentation, context)
			var rail := _new_rail(locale)
			assert_true(rail.configure_presentation(presentation, locale), context)
			add_child(rail)
			assert_true(rail.project(true, false, true), context)
			for index: int in NAMES.size():
				var button := rail.get_child(index) as Button
				var expected: String = COPY[locale][index]
				if index == 1: expected += " \u00b7 " + COPY[locale][7]
				if index == 2: expected += " \u00b7 " + COPY[locale][6]
				assert_eq(button.text, expected, context + "/" + NAMES[index])
				assert_false(button.clip_text, context + "/" + NAMES[index])
				assert_eq(button.text_overrun_behavior, TextServer.OVERRUN_NO_TRIMMING,
					context + "/" + NAMES[index])
				var text_size := presentation.default_font.get_string_size(
					button.text, HORIZONTAL_ALIGNMENT_LEFT, -1, presentation.default_font_size)
				assert_lte(text_size.x, button.size.x - 8.0, context + "/" + NAMES[index] + " width")
				assert_lte(text_size.y, button.size.y - 8.0, context + "/" + NAMES[index] + " height")
				assert_lte(button.get_minimum_size().x, button.size.x, context + "/" + NAMES[index] + " minimum width")
				assert_lte(button.get_minimum_size().y, button.size.y, context + "/" + NAMES[index] + " minimum height")
			rail.free()


func test_materials_use_caption_roles_and_skip_signal_stays_admission_bound() -> void:
	var presentation: Theme = CAPTION_THEME.build("en", 100, "Midnight")
	var rail := _new_rail()
	assert_true(rail.configure_presentation(presentation, "en"))
	var admission := Admission.new()
	var input_owner := InputOwner.new()
	add_child_autofree(input_owner)
	add_child_autofree(rail)
	assert_true(rail.bind_admission(admission.is_admitted, input_owner))
	assert_true(rail.project(true, false, true))
	var history := rail.get_node("History") as Button
	var auto := rail.get_node("Auto") as Button
	var history_plate := history.get_theme_stylebox(&"disabled") as StyleBoxFlat
	var auto_plate := auto.get_theme_stylebox(&"disabled") as StyleBoxFlat
	assert_eq(history_plate.bg_color, presentation.get_color(&"field", &"WitnessedCaption"))
	assert_eq(history_plate.border_color, presentation.get_color(&"rule", &"WitnessedCaption"))
	assert_eq(auto_plate.bg_color, Color("789083"), "Auto On uses the registered Filed plane")
	assert_eq(auto.get_theme_color(&"font_disabled_color"),
		presentation.get_color(&"field", &"WitnessedCaption"))
	assert_true((rail.get_node("Skip") as Button).get_theme_stylebox(&"focus") is StyleBoxEmpty,
		"native Focus adds no exterior pixels behind the rail-owned double frame")
	assert_eq(rail._focus_rects(Vector2(212, 64)), [
		Rect2(5, 5, 202, 54), Rect2(9, 9, 194, 46)],
		"two focus rails stay inside the four-pixel plate edge with a protected gap")
	watch_signals(rail)
	(rail.get_node("Skip") as Node).emit_signal(&"activated")
	assert_signal_emit_count(rail, "skip_requested", 1)
	admission.allowed = false
	(rail.get_node("Skip") as Node).emit_signal(&"activated")
	assert_signal_emit_count(rail, "skip_requested", 1, "the rail does not bypass owner admission")


func test_projection_and_visibility_retire_stale_native_actions_without_steady_state_churn() -> void:
	var presentation: Theme = CAPTION_THEME.build("en", 100, "AfterHours")
	var rail := _new_rail()
	assert_true(rail.configure_presentation(presentation, "en"))
	var admission := Admission.new()
	var input_owner := InputOwner.new()
	var auto_admission := Admission.new()
	add_child_autofree(input_owner)
	add_child_autofree(rail)
	assert_true(rail.bind_admission(admission.is_admitted, input_owner))
	assert_true(rail.bind_auto_admission(auto_admission.is_admitted, input_owner))
	assert_true(rail.project(true, false, false, true))
	await get_tree().process_frame
	var skip := rail.get_node("Skip") as Button
	var auto := rail.get_node("Auto") as Button
	var first_generation: int = int(skip.get("_generation"))
	var first_auto_generation: int = int(auto.get("_generation"))
	var first_plate: StyleBox = skip.get_theme_stylebox(&"normal")
	assert_true(rail.project(true, false, false, true))
	assert_eq(int(skip.get("_generation")), first_generation,
		"an identical per-frame projection does not retire the input generation")
	assert_eq(int(auto.get("_generation")), first_auto_generation,
		"an identical per-frame projection does not retire Auto")
	assert_same(skip.get_theme_stylebox(&"normal"), first_plate,
		"an identical per-frame projection does not allocate replacement material")

	skip.grab_focus()
	assert_true(skip.has_focus())
	assert_true(rail.project(false, false, false, true))
	assert_false(skip.has_focus(), "a disabled Skip command leaves Focus traversal")
	assert_eq(int(skip.get("_generation")), first_generation + 1,
		"the changed projection retires exactly one input generation")
	assert_eq(int(auto.get("_generation")), first_auto_generation + 1,
		"a changed rail projection retires the independent Auto generation")
	var disabled_generation: int = int(skip.get("_generation"))
	var projected_auto_generation: int = int(auto.get("_generation"))
	assert_true(rail.project(true, false, false, true))
	await get_tree().process_frame
	watch_signals(rail)
	skip.call("_on_accessibility_click", null, first_generation)
	assert_signal_not_emitted(rail, "skip_requested",
		"a native callback queued before disable cannot activate after re-enable")
	skip.call("_on_accessibility_click", null, disabled_generation + 1)
	assert_signal_emit_count(rail, "skip_requested", 1,
		"the current post-projection generation remains operable")
	auto.call("_on_accessibility_click", null, projected_auto_generation)
	assert_signal_not_emitted(rail, "auto_requested",
		"Auto's native callback cannot cross a Skip-only projection change")
	auto.call("_on_accessibility_click", null, int(auto.get("_generation")))
	assert_signal_emit_count(rail, "auto_requested", 1,
		"the current Auto generation remains operable")

	await get_tree().process_frame
	var before_hide: int = int(skip.get("_generation"))
	var auto_before_hide: int = int(auto.get("_generation"))
	rail.hide()
	rail.show()
	await get_tree().process_frame
	assert_gt(int(skip.get("_generation")), before_hide,
		"each actual visibility boundary retires the transport generation")
	assert_gt(int(auto.get("_generation")), auto_before_hide,
		"visibility retires Auto with the rest of the rail")
	skip.call("_on_accessibility_click", null, before_hide)
	assert_signal_emit_count(rail, "skip_requested", 1,
		"a native callback queued before hide cannot activate after show")
	skip.call("_on_accessibility_click", null, int(skip.get("_generation")))
	assert_signal_emit_count(rail, "skip_requested", 2,
		"the current post-visibility generation remains operable")
	auto.call("_on_accessibility_click", null, auto_before_hide)
	assert_signal_emit_count(rail, "auto_requested", 1,
		"a native Auto callback queued before hide cannot activate after show")
	auto.call("_on_accessibility_click", null, int(auto.get("_generation")))
	assert_signal_emit_count(rail, "auto_requested", 2,
		"the current post-visibility Auto generation remains operable")


func test_missing_catalog_owner_disables_commands_and_invalid_rebind_preserves_labels() -> void:
	var rail := RAIL.new()
	add_child_autofree(rail)
	assert_true(rail.configure_presentation(CAPTION_THEME.build("en", 100, "AfterHours"), "en"))
	assert_true(rail.project(true, false, false))
	var skip := rail.get_node("Skip") as Button
	assert_true(skip.disabled, "a control without a registered label cannot activate")
	assert_eq(skip.text, "")
	assert_false(rail.bind_localization(null))
	assert_true(rail.bind_localization(_localization))
	assert_false(skip.disabled)
	assert_eq(skip.text, "Skip \u00b7 Off")
	assert_false(rail.bind_localization(RefCounted.new()))
	assert_eq(skip.text, "Skip \u00b7 Off", "a refused replacement retains the valid owner")
	var theme_before: Theme = rail.theme
	assert_false(rail.configure_presentation(CAPTION_THEME.build("zh-CN", 100, "AfterHours"), "zh-CN"),
		"a font locale cannot get ahead of the committed catalog locale")
	assert_same(rail.theme, theme_before)
	assert_eq(skip.text, "Skip \u00b7 Off")


func test_live_catalog_switch_retires_old_input_and_keeps_controls_and_modes() -> void:
	var rail := _new_rail()
	add_child_autofree(rail)
	assert_true(rail.configure_presentation(CAPTION_THEME.build("en", 100, "AfterHours"), "en"))
	assert_true(rail.project(true, true, false))
	var skip := rail.get_node("Skip") as Button
	var auto := rail.get_node("Auto") as Button
	var generation: int = skip._generation
	var auto_generation: int = auto._generation
	assert_true(_localization.set_locale("zh_CN").get("ok", false))
	assert_true(rail.configure_presentation(CAPTION_THEME.build("zh-CN", 100, "AfterHours"), "zh-CN"))
	assert_same(rail.get_node("Skip"), skip)
	assert_same(rail.get_node("Auto"), auto)
	assert_eq(skip.text, "\u8df3\u8fc7 \u00b7 \u5f00")
	assert_eq(auto.text, "\u81ea\u52a8 \u00b7 \u5173")
	assert_gt(skip._generation, generation, "a prior-language activation is retired")
	assert_gt(auto._generation, auto_generation, "Auto retires with its prior-language label")


func test_binding_a_different_catalog_locale_waits_for_the_matching_theme_tuple() -> void:
	var rail := _new_rail()
	add_child_autofree(rail)
	assert_true(rail.configure_presentation(CAPTION_THEME.build("en", 100, "AfterHours"), "en"))
	assert_true(rail.project(true, false, false))
	var theme_before: Theme = rail.theme
	assert_true(_localization.set_locale("zh_HK").get("ok", false))
	assert_true(rail.bind_localization(_localization))
	var skip := rail.get_node("Skip") as Button
	assert_true(skip.disabled)
	assert_eq(skip.text, "", "new copy does not appear under the old language/font")
	assert_same(rail.theme, theme_before)
	assert_true(rail.configure_presentation(CAPTION_THEME.build("zh-HK", 100, "AfterHours"), "zh-HK"))
	assert_eq(skip.text, "\u8df3\u904e \u00b7 \u95dc")
	assert_false(skip.disabled)
