extends GutTest
## Real Bridge/Styles selection, with optional artwork deliberately unavailable.
## Authored dating masters currently contain return stubs, so named prose uses a fixture.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const ART := preload("res://scripts/data/ArtManifest.gd")
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
const LAYER := "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd"
const ART_LAYER := "res://scripts/ui/witnessed/WitnessedArtLayer.gd"
const ART_VIEW := preload("res://scripts/ui/art/SceneArtView.gd")
const ART_FIXTURES := preload("res://tests/unit/test_scene_art_bindings.gd")
const DATING := "dating.solo.priscilla.day1.pre_challenge"

class Completion extends RefCounted:
	var calls: Array[Dictionary] = []
	func complete_entry(intent: Dictionary) -> Dictionary:
		calls.append(intent.duplicate(true))
		return {"ok": true}

var runtime: DialogicGameHandler
var bridge: Node
var completion: Completion
var _original_runtime: Node
var _original_index := 0
var _original_bridge: Node
var _original_bridge_index := 0
var _original_layout: Node
var _original_parent: Node
var _original_layout_index := 0
var _settings := {}
var _persistent: Variant
var _had_persistent := false
var _style_directory := {}
var _art := {}
var _art_loaded := false
var _selected: Array[String] = []
var _text_events: Array[Dictionary] = []
var _root_size: Vector2i
var _root_content_size: Vector2i
var _mouse_from_touch := false
var _width_profile: RefCounted

func before_each() -> void:
	_root_size = get_tree().root.size
	_root_content_size = get_tree().root.content_scale_size
	_mouse_from_touch = Input.emulate_mouse_from_touch
	_width_profile = ART_FIXTURES.ViewProfile.new()
	_selected.clear()
	_text_events.clear()
	_art = ART._placements.duplicate(true)
	_art_loaded = ART._placements_loaded
	ART._placements = {"schema_version": 1, "assets": {}, "scenes": {}}
	ART._placements_loaded = true
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info", {})
	_style_directory = DialogicStylesUtil.style_directory.duplicate(true)
	_original_runtime = get_node("/root/Dialogic")
	_original_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_original_parent = _original_layout.get_parent()
		_original_layout_index = _original_layout.get_index()
		_original_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	runtime = DialogicGameHandler.new()
	runtime.name = "Dialogic"
	get_tree().root.add_child(runtime)
	runtime.Styles.style_changed.connect(func(info): _selected.append(str(info.style)))
	runtime.Text.text_started.connect(func(info): _text_events.append(info.duplicate()))
	var adapter := ADAPTER.new()
	assert_true(adapter.bind_runtime(runtime).get("ok", false))
	_original_bridge = get_node("/root/DialogicBridge")
	_original_bridge_index = _original_bridge.get_index()
	get_tree().root.remove_child(_original_bridge)
	bridge = BRIDGE.new()
	bridge.name = "DialogicBridge"
	get_tree().root.add_child(bridge)
	assert_true(bridge.initialize(null, adapter).get("ok", false))
	completion = Completion.new()
	assert_true(bridge.configure_playback_completion_port(completion).get("ok", false))

func after_each() -> void:
	Input.emulate_mouse_from_touch = _mouse_from_touch
	get_tree().root.size = _root_size
	get_tree().root.content_scale_size = _root_content_size
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	bridge.free()
	await runtime.clear()
	var remaining: Node = runtime.Styles.get_layout_node()
	if is_instance_valid(remaining): remaining.queue_free()
	await get_tree().process_frame
	runtime.free()
	get_tree().root.add_child(_original_bridge)
	get_tree().root.move_child(_original_bridge, _original_bridge_index)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_original_parent):
			_original_parent.add_child(_original_layout)
			_original_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	_original_parent = null
	for key: String in _settings:
		ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	ART._placements = _art
	ART._placements_loaded = _art_loaded

func _context() -> Dictionary:
	return {"expected_stage": "dating_pre", "playback_id": "caption-fixture",
		"role": "solo_pre_challenge", "transaction_id": "caption-fixture"}

func _settle() -> void:
	for frame in 4: await get_tree().process_frame

func _wait_for_completion(count: int) -> void:
	for frame in 60:
		if completion.calls.size() == count and not runtime.Styles.has_active_layout_node(): return
		await get_tree().create_timer(0.05).timeout
	assert_eq(completion.calls.size(), count, "authored return completed through the real runtime")

func test_artless_solo_group_and_twofriends_pre_and_post_select_nameless_style() -> void:
	var count := 0
	for route: String in ["solo.priscilla.day1", "group.priscilla_lavinia.day2", "twofriends.priscilla_lavinia.day2"]:
		for phase: String in ["pre_challenge", "post_challenge"]:
			var entry_id := "dating." + route + "." + phase
			_selected.clear()
			var started: Dictionary = bridge.start_entry(entry_id, _context())
			assert_true(started.get("ok", false), str(started))
			assert_true(STYLE in _selected, entry_id + " owns captions even without optional art")
			assert_null(bridge.get_art_hold_view(), "unavailable art cannot substitute a hold card")
			count += 1
			await _wait_for_completion(count)
			assert_eq(completion.calls[-1].entry_id, entry_id)
			assert_eq(completion.calls[-1].completion_kind, &"natural_end")
	assert_true(_text_events.is_empty(), "current authored dating stubs contain no prose")

func test_resumed_dating_entry_selects_same_style_without_optional_art() -> void:
	var context := _context()
	var checkpoint := {"entry_id": DATING, "content_version": 1, "frozen_context": context,
		"stage": context.expected_stage, "transaction_id": context.transaction_id}
	var resumed: Dictionary = bridge.resume_entry(checkpoint)
	assert_true(resumed.get("ok", false), str(resumed))
	assert_true(STYLE in _selected)
	await _wait_for_completion(1)
	assert_eq(completion.calls[0].entry_id, DATING)
	assert_eq(completion.calls[0].transaction_id, context.transaction_id)

func test_named_dialogue_in_dating_style_keeps_identity_but_has_no_speaker_plate() -> void:
	# Physical fixture prose exercises the same selector without editing an authored master.
	bridge.set("_ordinary_playback", {"timeline_id": DATING, "context": {}})
	bridge.call("_prepare_scene_art")
	assert_true(STYLE in _selected)
	var timeline := DialogicTimeline.new()
	timeline.from_text("Narrator: A dating caption fixture.")
	var layout: Node = runtime.start(timeline)
	await _settle()
	var event := runtime.current_timeline_events[0] as DialogicTextEvent
	assert_not_null(event.character, "speaker identity is retained by Dialogic")
	if event.character != null: assert_eq(event.character.display_name, "Narrator")
	assert_true(get_tree().get_nodes_in_group("dialogic_name_label").is_empty(), "dating has no speaker plate")
	assert_true(layout.find_children("*NameLabel*", "", true, false).is_empty())
	var texts := get_tree().get_nodes_in_group("dialogic_dialog_text")
	assert_eq(texts.size(), 1)
	if texts.size() == 1: assert_eq(texts[0].get_parsed_text(), "A dating caption fixture.")
	var captions := 0
	for layer: Node in layout.get_layers():
		if layer.get_script().resource_path == LAYER: captions += 1
	assert_eq(captions, 1, "the established three-caption presentation owns the text")

func test_dating_natural_end_restores_ordinary_default_style() -> void:
	var default_before: Variant = ProjectSettings.get_setting("dialogic/layout/default_style")
	assert_true(bridge.start_entry(DATING, _context()).get("ok", false))
	assert_true(STYLE in _selected)
	await _wait_for_completion(1)
	assert_eq(ProjectSettings.get_setting("dialogic/layout/default_style"), default_before)
	assert_true(get_tree().get_nodes_in_group("dialogic_input_policy").is_empty())
	var timeline := DialogicTimeline.new()
	timeline.from_text("Ordinary follow-up fixture.")
	var layout: Node = runtime.start(timeline)
	for frame in 60:
		if not _text_events.is_empty(): break
		await get_tree().create_timer(0.05).timeout
	assert_ne(layout.get_meta("style").resource_path, STYLE, "dating style has no global effect")
	assert_eq(_text_events.size(), 1)

func _mount_dating_captions(current: String = "Four still revealing.") -> Dictionary:
	bridge.set("_ordinary_playback", {"timeline_id": DATING, "context": {}})
	bridge.call("_prepare_scene_art")
	var timeline := DialogicTimeline.new()
	timeline.from_text("One.\nTwo.\nThree.\n" + current)
	var layout: Node = runtime.start(timeline)
	await _settle()
	var result := {"layout": layout}
	for layer: Node in layout.get_layers():
		if layer.get_script().resource_path == LAYER: result.caption = layer
		if layer.get_script().resource_path == ART_LAYER: result.art = layer.get_node("SceneArt")
	assert_has(result, "caption")
	assert_has(result, "art")
	if not result.has("caption") or not result.has("art"): return {}
	assert_true(result.art.bind_view_preferences(_width_profile))
	for step in 3:
		runtime.Text.skip_text_reveal()
		await _settle()
		runtime.Inputs.input_block_timer.stop()
		runtime.Inputs.handle_input()
		await _settle()
	result.caption.caption_text.set_process(false)
	result.caption.set_process(false)
	return result

func _native_snapshot(caption: Node) -> Dictionary:
	return {"event": runtime.current_event_idx, "text": caption.caption_text.get_parsed_text(),
		"revealing": caption.caption_text.revealing,
		"visible": caption.caption_text.visible_characters,
		"generation": caption.caption_text.get_reveal_generation(),
		"history": runtime.History.simple_history_content.duplicate(true),
		"full_history": runtime.History.full_event_history_content.duplicate(),
		"visited": runtime.History.visited_event_history_content.duplicate(true)}

func _assert_dating_leaf(leaf: RichTextLabel, percent: int) -> void:
	assert_eq(leaf.horizontal_alignment, HORIZONTAL_ALIGNMENT_CENTER, str(leaf.name))
	assert_true(leaf.get_theme_stylebox(&"normal") is StyleBoxEmpty, "transparent subtitle leaf: " + str(leaf.name))
	assert_true(leaf.get_theme_stylebox(&"focus") is StyleBoxEmpty, "no focus rectangle: " + str(leaf.name))
	for side in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		assert_eq(leaf.get_theme_stylebox(&"normal").get_content_margin(side), 16.0)
	assert_eq(leaf.get_theme_color(&"default_color"), Color.WHITE)
	assert_eq(leaf.get_theme_constant(&"outline_size"), 2)
	var outline := leaf.get_theme_color(&"font_outline_color")
	assert_lt(outline.get_luminance(), 0.1, "readable dark outline")
	assert_gt(outline.a, 0.0)
	assert_eq(leaf.get_theme_font_size(&"normal_font_size"), int(24 * percent / 100.0))

func test_dating_subtitles_keep_all_four_labels_transparent_and_centered_at_each_text_size() -> void:
	var mounted := await _mount_dating_captions()
	if mounted.is_empty(): return
	var caption: Node = mounted.caption
	assert_true(caption.get_caption_projection().get("dating_overlay", false), "real Bridge ownership selects the overlay")
	var before := _native_snapshot(caption)
	for percent: int in [100, 125, 150]:
		assert_true(caption.configure_presentation("en", percent))
		await _settle()
		for leaf: RichTextLabel in [caption.older, caption.previous, caption.review_current, caption.caption_text]:
			_assert_dating_leaf(leaf, percent)
		var projection: Dictionary = caption.get_caption_projection()
		assert_eq(projection.caption_window, ["Two.", "Three.", "Four still revealing."])
		assert_eq(projection.visible_leaf_rects.size(), 3)
		assert_almost_eq(projection.caption_rect.end.y, caption.transport_rail.position.y, 0.01, "caption stack sits just above controls")
		for rect: Rect2 in projection.leaf_rects:
			assert_almost_eq(rect.get_center().x, 640.0, 0.01, "subtitle region is centered")
			assert_lte(rect.end.y, 656.0)
		assert_eq(_native_snapshot(caption), before, "material publication cannot change native reading")

func test_dating_art_extends_behind_subtitles_without_consuming_control_or_challenge_space() -> void:
	var view := ART_VIEW.new()
	assert_true(view.bind_view_preferences(_width_profile))
	add_child_autofree(view)
	var pixels := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	for percent: int in [100, 125, 150]:
		view.configure_entry(DATING, percent)
		assert_eq(view.size, Vector2(1280, 656), "dating entry controls art geometry without optional images")
		if not view.size.is_equal_approx(Vector2(1280, 656)): continue
		view.configure_textures(texture, [texture, texture], null, percent, false, true)
		assert_true(view.visible)
		assert_true(view.clip_contents)
		for control: Control in [view, view._background, view._portraits[0], view._portraits[1], view._cg]:
			assert_eq(control.size.y, 656.0)
			assert_eq(control.mouse_filter, Control.MOUSE_FILTER_IGNORE)
			assert_eq(control.focus_mode, Control.FOCUS_NONE)
		view.configure_entry("hospital.faint", percent)
		assert_eq(view.size.y, float(ART_VIEW.APERTURE_HEIGHT[percent]), "Hospital keeps its existing art aperture")
		view.configure_textures(texture, [texture], null, percent, true, true)
		assert_eq(view.size, Vector2(1280, 720), "challenge retains its full worksheet space")
		assert_eq(view._portraits[0].size.y, 720.0, "challenge portrait retains full panel height")
		assert_eq(view.get_right_rect(), Rect2(view.get_portrait_width(), 0, 1280 - view.get_portrait_width(), 720))

func test_long_dating_caption_stays_centered_and_scrollable_with_both_scrollbar_sizes() -> void:
	var mounted := await _mount_dating_captions("A long dating caption remains centered while scrolling. ".repeat(160))
	if mounted.is_empty(): return
	var caption: Node = mounted.caption
	var before := _native_snapshot(caption)
	for large_targets: bool in [false, true]:
		assert_true(caption.configure_presentation("en", 150, "AfterHours", false, "standard", large_targets))
		await _settle()
		var bar: VScrollBar = caption.get_scroll_bar()
		assert_true(bar.visible, "long text uses the actual native scrollbar")
		assert_eq(bar.size.x, 64.0 if large_targets else 48.0)
		var projection: Dictionary = caption.get_caption_projection()
		assert_gt(projection.scroll_extent, 0.0)
		for rect: Rect2 in projection.leaf_rects:
			assert_almost_eq(rect.get_center().x, 640.0, 0.01, "native right scrollbar cannot shift dating text left")
			assert_gte(rect.position.x, 16.0)
			assert_lte(rect.end.x, 1264.0)
		bar.value = projection.scroll_extent
		await _settle()
		projection = caption.get_caption_projection()
		assert_almost_eq(projection.caption_rect.end.y, 656.0, 0.01, "the final words remain reachable above controls")
		assert_gt(projection.visible_leaf_rects.size(), 0)
		for rect: Rect2 in projection.visible_leaf_rects:
			assert_true(projection.field_rect.encloses(rect))
		bar.value = 0
		await _settle()
		assert_eq(bar.value, 0.0, "scrolling back reaches the start of the three-caption window")
		assert_eq(_native_snapshot(caption), before, "layout and manual scrolling preserve reveal and narrative history")

func test_dating_review_and_hospital_scope_reset_preserve_native_text_and_history() -> void:
	var mounted := await _mount_dating_captions()
	if mounted.is_empty(): return
	var caption: Node = mounted.caption
	var native: Node = caption.caption_text
	var before := _native_snapshot(caption)
	caption.call("_set_review_offset", 1)
	await _settle()
	assert_eq(caption.get_caption_projection().caption_window, ["One.", "Two.", "Three."])
	assert_false(native.visible)
	_assert_dating_leaf(caption.review_current, 100)
	assert_eq(_native_snapshot(caption), before, "review remains a projection of already-seen text")
	assert_false(caption.call("_before_normal_accept"), "first accept returns to live without advancing")
	native.set_process(false)
	assert_eq(caption.get_caption_projection().review_offset, 0)
	assert_eq(caption.caption_text, native)
	assert_eq(_native_snapshot(caption), before)

	# The reused layout must reset from the same authoritative scene-art publication.
	bridge.set("_ordinary_playback", {"timeline_id": "hospital.faint", "context": {}})
	bridge.scene_art_changed.emit()
	await _settle()
	assert_false(caption.get_caption_projection().get("dating_overlay", true))
	for leaf: RichTextLabel in [caption.older, caption.previous, caption.review_current, caption.caption_text]:
		assert_eq(leaf.horizontal_alignment, HORIZONTAL_ALIGNMENT_LEFT)
		assert_true(leaf.get_theme_stylebox(&"normal") is StyleBoxFlat)
		assert_eq(leaf.get_theme_constant(&"outline_size"), 0)
	assert_eq(mounted.art.size, Vector2(1280, 448))
	assert_eq(_native_snapshot(caption), before, "scope changes do not replay or advance text")
	bridge.set("_ordinary_playback", {"timeline_id": DATING, "context": {}})
	bridge.scene_art_changed.emit()
	await _settle()
	assert_true(caption.get_caption_projection().get("dating_overlay", false))
	assert_eq(mounted.art.size, Vector2(1280, 656))
	_assert_dating_leaf(native, 100)
	assert_eq(_native_snapshot(caption), before)

func _mount_root_split_fixture() -> Dictionary:
	var mounted := await _mount_dating_captions("Four still revealing.\nFollowing guard caption.")
	if mounted.is_empty(): return {}
	if mounted.layout.get_parent() != get_tree().root: mounted.layout.reparent(get_tree().root)
	mounted.layout.layer = 129 # Real input above GUT's own CanvasLayer128.
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	var pixels := Image.create(8, 8, false, Image.FORMAT_RGBA8)
	pixels.fill(Color.WHITE)
	var texture := ImageTexture.create_from_image(pixels)
	var portraits: Array[Texture2D] = [texture, texture]
	mounted.art.configure_textures(texture, portraits, null, 100, false, true)
	mounted.art.set_portrait_width(480)
	mounted.caption.configure_dating_overlay(true)
	mounted.caption.call("_sync_transport")
	mounted.caption.caption_text.grab_focus()
	runtime.Inputs.input_block_timer.stop()
	await _settle()
	return mounted

func _root_control_point(control: Control, point: Vector2) -> Vector2:
	return get_tree().root.get_final_transform() * (control.get_global_transform_with_canvas() * point)

func _split_mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _split_touch(point: Vector2, pressed: bool, canceled: bool = false) -> void:
	var event := InputEventScreenTouch.new()
	event.index = 0
	event.position = point
	event.pressed = pressed
	event.canceled = canceled
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func _split_key(key: Key, pressed: bool) -> void:
	var event := InputEventKey.new()
	event.keycode = key
	event.physical_keycode = key
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func test_dating_split_mouse_commits_on_release_without_advancing_caption() -> void:
	var mounted := await _mount_root_split_fixture()
	if mounted.is_empty(): return
	var caption: Node = mounted.caption
	var art: Control = mounted.art
	var handle: Control = art.get_split_handle()
	assert_same(caption.get("_dating_split_surface"), art, "caption binds its sibling art layer")
	assert_true(caption.is_dating_split_input_admitted())
	var before := _native_snapshot(caption)
	var point := _root_control_point(handle, handle.size * 0.5)
	_split_mouse(point, true)
	assert_true(art.is_split_dragging(), "background input forwards grip press")
	_split_key(KEY_ENTER, true)
	_split_key(KEY_ENTER, false)
	assert_true(art.is_split_dragging(), "secondary Accept cannot interrupt divider ownership")
	assert_eq(_native_snapshot(caption), before, "Enter during a drag cannot accept dialogue")
	var motion := InputEventMouseMotion.new()
	motion.position = point + Vector2(72, 0)
	motion.global_position = motion.position
	motion.relative = Vector2(72, 0)
	motion.button_mask = MOUSE_BUTTON_MASK_LEFT
	Input.parse_input_event(motion)
	Input.flush_buffered_events()
	assert_eq(art.get_portrait_width(), 480.0, "drag only previews its boundary")
	_split_mouse(motion.position, false)
	await _settle()
	assert_false(art.is_split_dragging())
	assert_true(get_node("/root/InputManager").get_physical_contacts().is_empty(), "consumed mouse and secondary key releases leave no held contacts")
	assert_eq(art.get_portrait_width(), 552.0)
	assert_eq(_width_profile.writes, [{"path": &"preferences.display.dating_group_portrait_width", "value": 552}])
	assert_eq(_native_snapshot(caption), before, "divider cannot reveal, advance, or write history")
	for rect: Rect2 in caption.get_caption_projection().leaf_rects:
		assert_almost_eq(rect.get_center().x, 640.0, 0.01, "captions stay centered across both panels")
	# Crossing only four pixels onto the grip must not turn a background press
	# into an accepted caption release, even below the ordinary drag threshold.
	_split_mouse(_root_control_point(handle, Vector2(-2, 32)), true)
	_split_mouse(_root_control_point(handle, Vector2(2, 32)), false)
	await _settle()
	assert_eq(_native_snapshot(caption), before, "release belongs to the grip hit area")
	var background_point := _root_control_point(caption.background_input, Vector2(900, 200))
	_split_mouse(background_point, true)
	_split_mouse(background_point, false)
	await _settle()
	assert_false(caption.caption_text.revealing, "a later ordinary scene click still finishes reveal")
	assert_eq(runtime.current_event_idx, before.event, "one click never also advances")
	assert_eq(runtime.History.simple_history_content, before.history)

func test_dating_split_touch_keyboard_and_reading_custody_preserve_native_text() -> void:
	var foreign_art := ART_VIEW.new()
	add_child_autofree(foreign_art)
	foreign_art.configure_entry(DATING)
	var mounted := await _mount_root_split_fixture()
	if mounted.is_empty(): return
	var caption: Node = mounted.caption
	var art: Control = mounted.art
	var handle: Control = art.get_split_handle()
	assert_same(caption.get("_dating_split_surface"), art, "another scene's earlier art surface cannot acquire caption custody")
	var before := _native_snapshot(caption)
	Input.emulate_mouse_from_touch = true
	var point := _root_control_point(handle, handle.size * 0.5)
	_split_touch(point, true)
	assert_true(art.is_split_dragging())
	var drag := InputEventScreenDrag.new()
	drag.index = 0
	drag.position = point - Vector2(64, 0)
	drag.relative = Vector2(-64, 0)
	Input.parse_input_event(drag)
	Input.flush_buffered_events()
	assert_eq(art.get_portrait_width(), 480.0)
	_split_touch(drag.position, false)
	await _settle()
	assert_true(get_node("/root/InputManager").get_physical_contacts().is_empty(), "consumed touch release leaves no held contacts")
	assert_eq(art.get_portrait_width(), 416.0, "real touch and its emulated mouse commit once")
	assert_eq(_native_snapshot(caption), before)
	caption.call("_sync_transport")
	assert_same(caption.caption_text.get_node(caption.caption_text.focus_next), handle, "divider participates in caption focus order")
	handle.grab_focus()
	_split_key(KEY_RIGHT, true)
	_split_key(KEY_RIGHT, false)
	await _settle()
	assert_eq(art.get_portrait_width(), 432.0, "keyboard adjusts the focused divider")
	assert_eq(_width_profile.writes.size(), 2, "touch and keyboard each save once without emulation duplicates")
	assert_eq(_width_profile.values[&"preferences.display.dating_group_portrait_width"], 432)
	assert_eq(_native_snapshot(caption), before)
	point = _root_control_point(handle, handle.size * 0.5)
	_split_touch(point, true)
	assert_true(art.is_split_dragging())
	caption.set("_load_pending", true)
	await _settle()
	assert_false(art.is_split_dragging(), "losing reading custody retires an unfinished drag")
	_split_touch(point - Vector2(48, 0), false)
	caption.set("_load_pending", false)
	await _settle()
	assert_eq(art.get_portrait_width(), 432.0, "late release cannot commit after custody returns")
	assert_eq(_native_snapshot(caption), before)
	handle.grab_focus()
	var captured: Dictionary = caption.capture_pause_view({"fixture": "dating-split"})
	assert_true(captured.get("ok", false))
	if not captured.get("ok", false): return
	assert_true(caption.cover_pause_view(captured.value))
	await _settle()
	assert_eq(handle.focus_mode, Control.FOCUS_NONE, "covered captions also withdraw the sibling divider")
	assert_true(caption.restore_pause_view(captured.value))
	await _settle()
	assert_same(get_viewport().gui_get_focus_owner(), handle, "uncover restores keyboard focus to the divider")
	assert_eq(_native_snapshot(caption), before)
