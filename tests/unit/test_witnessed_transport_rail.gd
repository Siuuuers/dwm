extends GutTest

const RAIL := preload("res://scripts/ui/witnessed/WitnessedTransportRail.gd")
const CAPTION_THEME := preload("res://scripts/ui/witnessed/WitnessedCaptionTheme.gd")
const NAMES := ["History", "Skip", "Auto", "Save", "Load", "Next"]
const LEFTS := [0, 212, 426, 640, 852, 1066]
const WIDTHS := [212, 214, 214, 212, 214, 214]
const COPY := {
	"en": ["History", "Skip", "Auto", "Save", "Load", "Next", "On", "Off"],
	"zh-CN": ["\u5386\u53f2", "\u8df3\u8fc7", "\u81ea\u52a8", "\u4fdd\u5b58", "\u8bfb\u53d6", "\u4e0b\u4e00\u6b65", "\u5f00", "\u5173"],
	"zh-HK": ["\u6b77\u53f2", "\u8df3\u904e", "\u81ea\u52d5", "\u5132\u5b58", "\u8f09\u5165", "\u4e0b\u4e00\u6b65", "\u958b", "\u95dc"],
}


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


func test_six_controls_cover_the_exact_scaled_native_hit_rectangles() -> void:
	var rail := RAIL.new()
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
	var rail := RAIL.new()
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


func test_all_locales_and_text_sizes_keep_complete_labels_inside_their_plates() -> void:
	for locale: String in COPY:
		for percent: int in [100, 125, 150]:
			var context := "%s/%d%%/large-targets" % [locale, percent]
			var presentation: Theme = CAPTION_THEME.build(locale, percent,
				"AfterHours", false, "standard", true)
			assert_not_null(presentation, context)
			var rail := RAIL.new()
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
	var rail := RAIL.new()
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
	var rail := RAIL.new()
	assert_true(rail.configure_presentation(presentation, "en"))
	var admission := Admission.new()
	var input_owner := InputOwner.new()
	add_child_autofree(input_owner)
	add_child_autofree(rail)
	assert_true(rail.bind_admission(admission.is_admitted, input_owner))
	assert_true(rail.project(true, false, false))
	await get_tree().process_frame
	var skip := rail.get_node("Skip") as Button
	var first_generation: int = int(skip.get("_generation"))
	var first_plate: StyleBox = skip.get_theme_stylebox(&"normal")
	assert_true(rail.project(true, false, false))
	assert_eq(int(skip.get("_generation")), first_generation,
		"an identical per-frame projection does not retire the input generation")
	assert_same(skip.get_theme_stylebox(&"normal"), first_plate,
		"an identical per-frame projection does not allocate replacement material")

	skip.grab_focus()
	assert_true(skip.has_focus())
	assert_true(rail.project(false, false, false))
	assert_false(skip.has_focus(), "a disabled Skip command leaves Focus traversal")
	assert_eq(int(skip.get("_generation")), first_generation + 1,
		"the changed projection retires exactly one input generation")
	var disabled_generation: int = int(skip.get("_generation"))
	assert_true(rail.project(true, false, false))
	await get_tree().process_frame
	watch_signals(rail)
	skip.call("_on_accessibility_click", null, first_generation)
	assert_signal_not_emitted(rail, "skip_requested",
		"a native callback queued before disable cannot activate after re-enable")
	skip.call("_on_accessibility_click", null, disabled_generation + 1)
	assert_signal_emit_count(rail, "skip_requested", 1,
		"the current post-projection generation remains operable")

	await get_tree().process_frame
	var before_hide: int = int(skip.get("_generation"))
	rail.hide()
	rail.show()
	await get_tree().process_frame
	assert_gt(int(skip.get("_generation")), before_hide,
		"each actual visibility boundary retires the transport generation")
	skip.call("_on_accessibility_click", null, before_hide)
	assert_signal_emit_count(rail, "skip_requested", 1,
		"a native callback queued before hide cannot activate after show")
	skip.call("_on_accessibility_click", null, int(skip.get("_generation")))
	assert_signal_emit_count(rail, "skip_requested", 2,
		"the current post-visibility generation remains operable")
