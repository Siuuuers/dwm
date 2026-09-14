extends "res://addons/gut/test.gd"
## Registrar cases adapted from pinned 26de279's tests/scene/test_gallery_registrar.
## Real Profile and localization; memory storage. No replay service is injected.
const SCENE := preload("res://scenes/menu/GalleryScene.tscn")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
var _surface: SubViewport
var _profile: Node
var _locale: Node
var _home: Button
var _scene: Control

class BrokenProjection extends Node:
	signal profile_restored(snapshot: Dictionary)
	var result: Variant = {"ok": true, "value": {"revision": 1, "ending_ids": ["ending.alone"]}}
	func get_gallery_discovery_snapshot() -> Variant: return result
	func get_preference(_path: StringName, fallback: Variant = null) -> Variant: return fallback

func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.handle_input_locally = true
	add_child(_surface)
	_profile = PROFILE.new()
	_surface.add_child(_profile)
	assert_true(_profile.initialize(STORAGE.new("gallery-registrar.memory", FILES.new())).ok)
	_locale = LOCALIZATION.new()
	_surface.add_child(_locale)
	assert_true(_locale.initialize(_profile).ok)
	_home = Button.new()
	_home.text = "Return"
	_home.position = Vector2(320, 0)
	_home.size = Vector2(64, 64)
	_surface.add_child(_home)

func after_each() -> void:
	_surface.free()

func _settle() -> void:
	for frame: int in range(3): await get_tree().process_frame

func _mount(owner: Object = null, seed: bool = true) -> void:
	if seed:
		assert_true(_profile.unlock_ending("ending.sylvia.sweet", "gallery-fixture-first").ok)
		assert_true(_profile.unlock_ending("ending.alone", "gallery-fixture-second").ok)
	var host := Control.new()
	host.position = Vector2(320, 64)
	host.size = Vector2(960, 656)
	_surface.add_child(host)
	_scene = SCENE.instantiate()
	assert_true(_scene.configure_title_host(_home, _locale, _profile if owner == null else owner).ok)
	host.add_child(_scene)
	await _settle()

func _rows() -> GridContainer:
	return _scene.get_node("%EndingTileGrid")

func _key(code: int) -> void:
	for held: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = held
		_surface.push_input(event, true)
		await _settle()

func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	_surface.push_input(event, true)
	await _settle()

func _mouse(point: Vector2, held: bool, double_click: bool = false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = held
	event.double_click = double_click
	_surface.push_input(event, true)
	await _settle()

func test_discovery_order_is_detached_and_visible_copy_contains_no_private_class_or_replay_command() -> void:
	await _mount()
	var before: Dictionary = _profile.get_profile_snapshot()
	assert_eq(_rows().get_child_count(), 2)
	assert_eq(_rows().get_child(0).get_meta("gallery_record_id"), "ending.sylvia.sweet")
	assert_eq(_rows().get_child(1).get_meta("gallery_record_id"), "ending.alone")
	for row: Button in _rows().get_children():
		assert_eq(row.text, _locale.t("gallery.record.unavailable"))
		assert_eq(row.accessibility_name, row.text)
		assert_eq(row.caption.text, row.text)
		assert_false(row.text.contains("sweet"))
	assert_true(_scene.get_node("%ReplayButton").disabled)
	assert_eq(_scene.get_node("%ReplayButton").focus_mode, Control.FOCUS_NONE)
	await _key(KEY_DOWN)
	await _key(KEY_ENTER)
	assert_eq(_scene.get("_selected_id"), "ending.alone")
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_false(_scene.has_method("_configure_replay"))

func test_native_keyboard_controller_navigation_stops_at_bounds_and_skips_disabled_replay() -> void:
	await _mount()
	assert_true(_rows().get_child(0).has_focus())
	await _key(KEY_UP)
	await _key(KEY_RIGHT)
	assert_true(_rows().get_child(0).has_focus())
	for held: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = JOY_BUTTON_DPAD_DOWN
		event.pressed = held
		_surface.push_input(event, true)
		await _settle()
	assert_true(_rows().get_child(1).has_focus())
	await _key(KEY_DOWN)
	assert_true(_rows().get_child(1).has_focus())
	await _key(KEY_TAB)
	assert_true(_home.has_focus())

func test_pointer_selection_is_release_only_and_exit_return_or_target_loss_cannot_revive_press() -> void:
	await _mount()
	var first: Button = _rows().get_child(0)
	var second: Button = _rows().get_child(1)
	var point := second.get_global_rect().get_center()
	var activations: Array = []
	second.pressed.connect(func(): activations.append(true))
	await _move(point)
	await _mouse(point, true)
	assert_true(first.has_focus())
	await _mouse(point, false)
	assert_true(second.has_focus())
	assert_eq(activations.size(), 1)
	await _mouse(point, true, true)
	await _mouse(point, false)
	assert_eq(activations.size(), 1)
	first.grab_focus()
	await _mouse(point, true)
	await _move(Vector2(20, 20))
	await _move(point)
	await _mouse(point, false)
	assert_true(first.has_focus())
	assert_eq(activations.size(), 1, "leaving and reentering cannot rearm the original press")
	await _mouse(point, true)
	second.hide()
	second.show()
	await _mouse(point, false)
	assert_eq(activations.size(), 1)

func test_wheel_and_trackpad_cancel_pointer_press_even_at_scroll_boundary() -> void:
	await _mount()
	var second: Button = _rows().get_child(1)
	var point := second.get_global_rect().get_center()
	for kind: String in ["wheel", "pan"]:
		_rows().get_child(0).grab_focus()
		await _move(point)
		await _mouse(point, true)
		var event: InputEvent
		if kind == "wheel":
			var wheel := InputEventMouseButton.new()
			wheel.position = point
			wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
			wheel.pressed = true
			event = wheel
		else:
			var pan := InputEventPanGesture.new()
			pan.position = point
			pan.delta = Vector2(0, 2)
			event = pan
		_surface.push_input(event, true)
		await _settle()
		await _mouse(point, false)
		assert_true(_rows().get_child(0).has_focus())
		assert_eq(_scene.get("_selected_id"), "ending.sylvia.sweet")

func test_geometry_and_actual_wrapped_font_metrics_at_three_locales_and_sizes() -> void:
	await _mount()
	for locale_id: String in ["en", "zh_CN", "zh_HK"]:
		assert_true(_locale.set_locale(locale_id).ok)
		for percent: int in [100, 125, 150]:
			assert_true(_profile.set_preference(&"preferences.accessibility.text_size", percent).ok)
			await _settle()
			assert_eq(_scene.get_node("%GalleryHost").get_global_rect(), Rect2(320, 64, 960, 656))
			assert_eq(_scene.get_node("%IndexViewport").get_rect(), Rect2(32, 32, 312, 592))
			assert_eq(_scene.get_node("%ReplayButton").get_rect(), Rect2(776, 568, 160, 64))
			assert_eq(_scene.theme.default_font_size, {100: 16, 125: 20, 150: 24}[percent])
			for row: Button in _rows().get_children():
				assert_eq(row.size.x, 296.0)
				assert_gte(row.size.y, 80.0)
				assert_eq(fmod(row.size.y, 2), 0.0)
				assert_eq(row.caption.size.x, 264.0)
				assert_lte(row.caption.get_rect().end.y, row.size.y)
			assert_lte(_scene.get_node("%ReplayStatus").get_rect().end.y, 544.0)
			assert_eq(_scene.get("_selected_id"), "ending.sylvia.sweet")

func test_refresh_preserves_selection_and_clear_gallery_has_true_empty_geometry() -> void:
	await _mount()
	_rows().get_child(1).grab_focus()
	assert_true(_profile.unlock_ending("ending.lavinia.sweet", "gallery-fixture-third").ok)
	await _settle()
	assert_eq(_scene.get("_selected_id"), "ending.alone")
	assert_true(_rows().get_child(1).has_focus())
	assert_true(_profile.reset_gallery().ok)
	await _settle()
	assert_eq(_rows().get_child_count(), 0)
	assert_eq(_scene.get("_status_key"), "gallery.empty")
	assert_false(_scene.get_node("%ReplayButton").visible)
	assert_eq(_scene.get("_index_extent"), 0.0)
	assert_true(_home.has_focus())

func test_hidden_publications_and_navigation_refresh_do_not_mutate_shared_return() -> void:
	await _mount()
	assert_true(_scene.close_for_title_host())
	_home.grab_focus()
	var sentinel := Theme.new()
	_home.theme = sentinel
	_home.focus_next = NodePath(".")
	_home.focus_previous = NodePath(".")
	_home.accessibility_name = "Other host Return"
	assert_true(_profile.set_preference(&"preferences.accessibility.text_size", 150).ok)
	assert_true(_profile.reset_gallery().ok)
	_scene.refresh_return_navigation()
	await _settle()
	assert_same(_home.theme, sentinel)
	assert_eq(_home.focus_next, NodePath("."))
	assert_eq(_home.focus_previous, NodePath("."))
	assert_eq(_home.accessibility_name, "Other host Return")
	assert_true(_home.has_focus())
	_scene.open_in_title_host()
	await _settle()
	assert_eq(_rows().get_child_count(), 0)
	assert_eq(_scene.theme.default_font_size, 24)

func test_malformed_discovery_is_technical_failure_not_empty_or_partial_records() -> void:
	var broken := BrokenProjection.new()
	_surface.add_child(broken)
	await _mount(broken, false)
	var bad: Array = [null, {"ok": false}, {"ok": true, "value": {}},
		{"ok": true, "value": {"revision": -1, "ending_ids": []}},
		{"ok": true, "value": {"revision": 1, "ending_ids": ["ending.alone", "ending.alone"]}},
		{"ok": true, "value": {"revision": 1, "ending_ids": ["ending.alone", "private.unknown"]}},
		{"ok": true, "value": {"revision": 1, "ending_ids": [], "private": true}}]
	for result: Variant in bad:
		broken.result = result
		broken.profile_restored.emit({})
		await _settle()
		assert_eq(_rows().get_child_count(), 0)
		assert_eq(_scene.get("_status_key"), "gallery.archive.unavailable")
		assert_false(_scene.get_node("%ReplayButton").visible)
		assert_true(_home.has_focus())

func test_invalid_host_localization_refuses_atomically_and_rebinding_is_rejected() -> void:
	var scene: Control = SCENE.instantiate()
	var invalid := Node.new()
	_surface.add_child(invalid)
	assert_false(scene.configure_title_host(_home, invalid, _profile).ok)
	assert_null(scene.get("_host_return"))
	assert_eq(scene.get_node("%GalleryHost").position, Vector2(320, 64))
	assert_true(scene.configure_title_host(_home, _locale, _profile).ok)
	assert_false(scene.configure_title_host(_home, _locale, _profile).ok)
	scene.free()

func test_overflow_scroll_clamps_without_changing_selection_and_uses_standard_palettes() -> void:
	await _mount()
	for id: String in SCHEMA.ENDING_IDS:
		assert_true(_profile.unlock_ending(id, "gallery-all-" + id).ok)
	await _settle()
	_rows().get_child(0).grab_focus()
	var selected: String = _scene.get("_selected_id")
	assert_gt(_scene.get("_index_extent"), 592.0)
	var wheel := InputEventMouseButton.new()
	wheel.position = _rows().get_child(0).get_global_rect().get_center()
	wheel.button_index = MOUSE_BUTTON_WHEEL_DOWN
	wheel.factor = 100
	wheel.pressed = true
	_surface.push_input(wheel, true)
	await _settle()
	assert_eq(_scene.get("_index_offset"), _scene.get("_index_extent") - 592)
	assert_eq(_scene.get("_selected_id"), selected)
	assert_true(_rows().get_child(0).has_focus())
	var registry := preload("res://scripts/settings/SettingsPaletteRegistry.gd")
	for midnight: bool in [false, true]:
		var candidate: Dictionary = _profile.get_profile_snapshot()
		candidate.preferences.dark_mode.available = true
		candidate.preferences.dark_mode.next_run_enabled = midnight
		assert_true(_profile.commit_prepared_profile(candidate).ok)
		await _settle()
		var roles: Dictionary = registry.resolve(&"midnight" if midnight else &"after_hours", false, "standard")
		for role: String in ["face", "paper", "paper_ink", "filed", "ink", "focus"]:
			assert_eq(_scene.theme.get_color(role, "Gallery"), roles[role])
