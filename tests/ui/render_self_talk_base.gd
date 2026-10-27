extends "res://tests/integration/scene_later_caption_child.gd"
## Synthetic DTL, actual FINAL services, native input, renderer and physical Save/Load.
## This is a player journey, not production story or platform speech acceptance.
const SELF_TALK_DTL := "res://tests/fixtures/dialogic/scene_self_talk_render.dtl"
const AUTHORING := preload("res://tools/authoring/AuthoredWeekRegistration.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
var _captures := 0

func _self_talk_markers() -> Array:
	return []

func _install_content_registration() -> Dictionary:
	var content: RefCounted = CONTENT.new()
	var built: Dictionary = content._registration_bundle()
	if not built.ok: return built
	var bundle: Dictionary = built.value
	var markers: Array = _self_talk_markers()
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		labels.append(entry.entry_id)
		if entry.entry_id == "scene.test.a":
			entry.locators.en.path = SELF_TALK_DTL
			for marker: Dictionary in markers:
				if marker.kind not in entry.allowed_signals: entry.allowed_signals.append(marker.kind)
	var compiled: Dictionary = ADAPTER.compile_scene_programme(SELF_TALK_DTL, "scene.test.a", labels, markers)
	if not compiled.ok: return compiled
	var lines: Array = AUTHORING.caption_lines(compiled.value.events, {})
	for row: Dictionary in bundle.caption_registry.entries:
		if row.entry_id == "scene.test.a": row.lines = lines
	var registered: Array = []
	for row: Dictionary in bundle.ids_registry.lines:
		if row.owning_entry_id != "scene.test.a": registered.append(row)
	for line: Dictionary in lines:
		registered.append({"line_id": line.line_id, "owning_entry_id": "scene.test.a"})
	registered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	bundle.ids_registry.lines = registered
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == "scene.test.a":
			programme.markers = markers
			programme.content_sha256 = compiled.value.content_sha256
			programme.program_sha256 = compiled.value.program_sha256
	for row: Dictionary in bundle.targets:
		if row.target.entry_id == "scene.test.a": row.target.program_sha256 = compiled.value.program_sha256
	return MANIFEST.configure_test_scene_registration(bundle)

func _capture_self_talk(label: String) -> void:
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var pixels: Image = get_viewport().get_texture().get_image()
	assert_false(pixels.is_empty(), "actual renderer supplies pixels")
	assert_eq(pixels.save_png("res://.godot/ci/self-talk-" + label + ".png"), OK)
	_captures += 1

func _history_ids() -> Array:
	var captured: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(captured): return []
	var ids: Array = []
	var caption_ids: Array = []
	for section: Array in captured.value.player_progress.history_sections:
		for id: String in section:
			ids.append(id)
			if not id.begins_with("line.scene.test.a.thought_"): caption_ids.append(id)
	var history: Dictionary = bridge.get_reading_history()
	if not _ok(history): return ids
	var visible_ids: Array = []
	for row: Dictionary in history.value.captions: visible_ids.append(row.line_id)
	assert_eq(visible_ids, caption_ids, "general History contains captions only; paired IDs remain in saved encounters")
	return ids

func _wheel_thought(older: bool) -> void:
	var panel: Control = _caption().self_talk
	var point: Vector2 = panel.get_global_transform_with_canvas() * (panel.size / 2)
	for pressed: bool in [true, false]:
		var event := InputEventMouseButton.new()
		event.position = point
		event.global_position = point
		event.button_index = MOUSE_BUTTON_WHEEL_DOWN if older else MOUSE_BUTTON_WHEEL_UP
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame

func _advance_to(suffix: String) -> bool:
	if _caption().caption_text.revealing: await _accept()
	await _accept()
	var actual: String = bridge._runtime_adapter.current_line_id()
	assert_eq(actual, "line.scene.test.a." + suffix, "one Advance passes the paired thought")
	return actual == "line.scene.test.a." + suffix

func _resize_review(caption: Node, panel: Control) -> void:
	# Synthetic plain portrait activates the existing production divider; only art
	# presentation is supplied here. Reading, History and input owners remain real.
	var surface: Control = caption._dating_split_surface
	assert_not_null(surface)
	if surface == null: return
	var pixels := Image.create(8, 8, false, Image.FORMAT_RGB8)
	pixels.fill(Color("313845"))
	var portraits: Array[Texture2D] = [ImageTexture.create_from_image(pixels)]
	surface.configure_textures(null, portraits, null, 100, false, true, &"solo", true)
	caption.configure_dating_overlay(true)
	for frame: int in 3: await get_tree().process_frame
	var handle: Control = surface.get_split_handle()
	assert_not_null(handle)
	if handle == null: return
	var before: Dictionary = bridge.capture_reading_checkpoint(false)
	var anchor: Dictionary = panel.get_projection().visible_rows[0].duplicate(true)
	var width_before: float = panel.size.x
	handle.grab_focus()
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_HOME
		event.physical_keycode = KEY_HOME
		event.pressed = pressed
		get_viewport().push_input(event, true)
		await get_tree().process_frame
	for frame: int in 3: await get_tree().process_frame
	assert_lt(panel.size.x, width_before, "keyboard divider resize reflows the actual thought panel")
	assert_true(panel.is_reviewing(), "reflow preserves review mode")
	var resized: Dictionary = panel.get_projection()
	assert_lte(resized.visible_rows.size(), 3)
	assert_eq(resized.visible_rows[0].id, anchor.id, "reflow preserves the reviewed stable line")
	assert_lte(resized.visible_rows[0].start, anchor.start)
	assert_gte(resized.visible_rows[0].end, anchor.start)
	assert_eq(bridge.capture_reading_checkpoint(false), before, "divider input never advances")
	await _capture_self_talk("resized-review")
	var localization: Node = get_node("/root/LocalizationManager")
	for locale: String in ["zh_HK", "ja", "en"]:
		# The rail and captions share the actual locale owner; a foreign tuple is
		# deliberately refused. Exercise its normal change path before resizing text.
		if not _ok(localization.set_locale(locale)): return
		for frame: int in 3: await get_tree().process_frame
		assert_true(caption.configure_presentation(locale, 150, "AfterHours"), "accepted locale/font tuple " + locale)
		await get_tree().process_frame
		assert_lte(panel.get_projection().visible_rows.size(), 3, "three-row budget after " + locale + " font reflow")
		assert_eq(bridge.capture_reading_checkpoint(false), before, "locale/font reflow does not republish")
	assert_true(caption.configure_presentation("en", 100, "AfterHours"), "restore matching English 100% presentation")

