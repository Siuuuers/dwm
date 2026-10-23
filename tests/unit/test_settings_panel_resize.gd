extends GutTest

const SETTINGS := preload("res://scenes/apps/SettingsApp.tscn")
const VOLUME_PATH := &"preferences.audio.music_volume"

class MemoryProfile extends RefCounted:
	signal preference_changed(path: StringName, value: Variant)
	const PREFERENCES := preload("res://scripts/settings/SettingsPreferenceRegistry.gd")
	var values: Dictionary = {}
	var commits: Array[Dictionary] = []

	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		var value: Variant = PREFERENCES.default_value(path)
		return values.get(path, fallback if value == null else value)

	func set_preference(path: StringName, value: Variant) -> Dictionary:
		values[path] = value
		commits.append({"path": path, "value": value})
		preference_changed.emit(path, value)
		return {"ok": true}

	func get_profile_revision() -> int:
		return commits.size()

class MemoryLocalization extends RefCounted:
	signal locale_changed(locale: String)

	func has_key(_key: String) -> bool:
		return false

	func t(key: String, _parameters: Dictionary = {}) -> String:
		return key

	func get_selectable_locales() -> Array[Dictionary]:
		return [{"id": "en", "native_name": "English", "release_status": "complete"}]

class MemoryVolume extends RefCounted:
	var previews: Array[Dictionary] = []
	var commits: Array[Dictionary] = []
	var cancellations: Array = []

	func get_settings_audio_capability() -> Dictionary:
		return {"ok": true, "value": {"volume": true}}

	func preview_settings_volume(holder: StringName, path: StringName, value: float,
			handle: Variant = null) -> Dictionary:
		if handle == null:
			handle = {"holder": holder, "path": path, "id": previews.size() + 1}
		previews.append({"value": value, "handle": handle})
		return {"ok": true, "value": {"preview_handle": handle}}

	func commit_settings_audio_preference(holder: StringName, path: StringName,
			value: Variant, handle: Variant = null) -> Dictionary:
		commits.append({"holder": holder, "path": path, "value": value, "handle": handle})
		return {"ok": true}

	func cancel_settings_volume_preview(handle: Variant) -> Dictionary:
		cancellations.append(handle)
		return {"ok": true}

var _host: Control
var _app: Control
var _content: Control
var _profile: MemoryProfile
var _volume: MemoryVolume


func before_each() -> void:
	_host = Control.new()
	_host.size = Vector2(800, 656)
	add_child_autofree(_host)
	_profile = MemoryProfile.new()
	_volume = MemoryVolume.new()
	_app = SETTINGS.instantiate()
	_content = _app.get_node("SettingsContent")
	_content.configure_services({
		"profile": _profile,
		"localization": MemoryLocalization.new(),
		"audio": null,
		"tts": null,
		"volume": _volume,
		"input": null,
		"window": null,
	})
	_host.add_child(_app)
	await _settle()


func _settle() -> void:
	for _frame: int in range(3):
		await get_tree().process_frame


func _assert_panel_geometry(width: float) -> void:
	assert_eq(_app.size, Vector2(width, 656), "the app follows its plain host without manual sizing")
	assert_eq(_content.size, Vector2(width, 656))
	assert_eq(_content.rail_scroll.position, Vector2(16, 16))
	assert_eq(_content.rail_scroll.size, Vector2(208, 624))
	assert_eq(_content.get_node("Heading").get_rect(), Rect2(240, 16, width - 256, 80))
	# Language hides the accessibility specimen footer, reclaiming its 144 pixels.
	assert_eq(_content.sheet_scroll.get_rect(), Rect2(240, 96, width - 256, 544))
	assert_eq(_content.get_node("Footer").get_rect(), Rect2(240, 496, width - 256, 144))
	assert_eq(_content.get_node("Heading/CategoryHeading").get_rect(),
		Rect2(16, 8, width - 288, 64))
	assert_eq(_content.get_node("Footer/ControlSample").get_rect(),
		Rect2(16, 8, width - 288, 128))
	assert_eq(_content.get_node("SelectedExtension").size, Vector2(width, 656))


func test_panel_keeps_the_canonical_layout_at_800_and_expands_only_the_reading_side() -> void:
	_assert_panel_geometry(800)
	var rail: ScrollContainer = _content.rail_scroll
	var heading := _content.get_node("Heading")
	var sheet: ScrollContainer = _content.sheet_scroll
	var footer := _content.get_node("Footer")

	for width: float in [880.0, 960.0]:
		_host.size.x = width
		await _settle()
		_assert_panel_geometry(width)
	assert_same(_content.rail_scroll, rail)
	assert_same(_content.get_node("Heading"), heading)
	assert_same(_content.sheet_scroll, sheet)
	assert_same(_content.get_node("Footer"), footer)

	_host.size.x = 800
	await _settle()
	_assert_panel_geometry(800)


func test_focus_scroll_uses_the_same_logical_distance_when_the_panel_is_enlarged() -> void:
	_content.select_category("accessibility")
	var target: Control = _content.control_for(&"preferences.accessibility.steady_interface")
	target.grab_focus()
	await _settle()
	var scroll: ScrollContainer = _content.sheet_scroll
	var corrected: Array[int] = []
	for factor: float in [1.0, 1.2]:
		_host.scale = Vector2.ONE * factor
		scroll.scroll_vertical = 0
		await _settle()
		_content._clear_focus_perimeter(scroll, target)
		corrected.append(scroll.scroll_vertical)
	assert_gt(corrected[0], 0, "The lower reading row needs scrolling.")
	assert_eq(corrected[1], corrected[0], "Magnification must not overscroll the same focused row.")


func test_live_resize_preserves_category_focus_and_uncommitted_volume_preview() -> void:
	_content.select_category("audio")
	var audio_category: Button = _content.find_child("AudioCategory", true, false)
	var slider: HSlider = _content.control_for(VOLUME_PATH)
	var controller: RefCounted = _content.get_controller()
	slider.grab_focus()
	controller.begin_volume_drag(VOLUME_PATH)
	slider.set_value_no_signal(0.37)
	await controller._on_volume_changed(0.37, VOLUME_PATH)
	var drag_before: Dictionary = controller.get("_drag").duplicate(true)
	assert_false(drag_before.is_empty())
	assert_eq(_profile.commits, [], "a held preview is not a committed preference")

	_host.size.x = 960
	await _settle()
	assert_true(audio_category.button_pressed)
	assert_true(_content.get_node("SheetScroll/Sheets/AudioSheet").visible)
	assert_same(get_viewport().gui_get_focus_owner(), slider)
	assert_eq(slider.value, 0.37)
	assert_eq(controller.get("_drag"), drag_before)
	assert_eq(_profile.commits, [], "layout changes do not publish held settings")

	await controller.cancel_volume_drag()
