extends GutTest

const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const LONG_GALLERY := preload("res://tests/support/GalleryLongRecord.gd")
const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")


class ReplayBridge extends RefCounted:
	signal reached_replay_finished(result: Dictionary)
	var starts: Array[String] = []
	func configure_reached_replay(_profile: Object) -> Dictionary:
		return {"ok": true}
	func replay_reached_signature(_signature_id: String) -> Dictionary:
		starts.append(_signature_id)
		return {"ok": true, "receipt": {"playback_token": "gallery-navigation"}}
	func cancel_reached_replay(_signature_id: String) -> Dictionary:
		return {"ok": true}


class QueryProfile extends PROFILE:
	var query_unavailable := false
	func get_reached_presentations(entry_id: String = "") -> Dictionary:
		if query_unavailable: return {"ok": false, "code": &"unavailable"}
		return super.get_reached_presentations(entry_id)


class PracticeGame extends RefCounted:
	func capture_run_snapshot_input() -> Dictionary: return {}


var _surface: SubViewport
var _profile: Node
var _files: RefCounted
var _bridge: ReplayBridge
var _localization: Node
var _home: Button
var _gallery: Control


func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.handle_input_locally = true
	add_child(_surface)
	_profile = QueryProfile.new()
	_surface.add_child(_profile)
	_files = FILES.new()
	assert_true(_profile.initialize(STORAGE.new("gallery-navigation.memory", _files)).get("ok", false))
	_localization = LOCALIZATION.new()
	_surface.add_child(_localization)
	assert_true(_localization.initialize(_profile).get("ok", false))
	_home = Button.new()
	_home.name = "Return"
	_home.position = Vector2(320, 0)
	_home.size = Vector2(208, 64)
	_surface.add_child(_home)


func after_each() -> void:
	_surface.free()


func test_single_version_spatial_and_sequential_navigation_reaches_replay_and_return() -> void:
	_record(_alone(false))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-navigation:single").get("ok", false))
	await _mount()
	var row := _selected_row()
	var replay := _replay()
	assert_not_null(row)
	assert_false(replay.disabled)
	assert_false(_selector().visible)
	var before: Dictionary = _profile.get_profile_snapshot()
	var persisted: Dictionary = _files.snapshot_persisted()

	row.grab_focus()
	await _key(KEY_RIGHT)
	assert_true(replay.has_focus(), "Right reaches the sole available Replay action")
	row.grab_focus()
	await _dpad(JOY_BUTTON_DPAD_RIGHT)
	assert_true(replay.has_focus(), "controller Right reaches the sole available Replay action")
	replay.grab_focus()
	await _key(KEY_LEFT)
	assert_true(row.has_focus(), "Left from Replay returns to the selected record")

	row.grab_focus()
	await _tab()
	assert_true(replay.has_focus(), "Tab reaches enabled Replay")
	await _tab()
	assert_true(_home.has_focus(), "Tab reaches the shell-owned Return after Gallery actions")
	await _tab(true)
	assert_true(replay.has_focus(), "Shift-Tab reverses from Return to Replay")
	assert_eq(_bridge.starts.size(), 0, "navigation never starts playback")
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_files.snapshot_persisted(), persisted)


func test_plural_versions_follow_record_selector_replay_spatial_and_tab_order() -> void:
	_record(_alone(false))
	_record(_alone(true))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-navigation:plural").get("ok", false))
	await _mount()
	var row := _selected_row()
	var selector := _selector()
	var replay := _replay()
	assert_true(selector.visible)
	assert_false(replay.disabled)
	var before: Dictionary = _profile.get_profile_snapshot()
	var version: int = _gallery.get("_selected_version")

	row.grab_focus()
	await _key(KEY_RIGHT)
	assert_true(selector.has_focus(), "Right enters the current plural-version selector")
	selector.grab_focus()
	await _key(KEY_RIGHT)
	assert_true(replay.has_focus(), "Right continues from the version selector to Replay")
	replay.grab_focus()
	await _key(KEY_LEFT)
	assert_true(row.has_focus(), "Left from Replay returns directly to the selected record")
	selector.grab_focus()
	await _key(KEY_LEFT)
	assert_true(row.has_focus(), "Left from the version selector returns to the selected record")
	row.grab_focus()
	await _dpad(JOY_BUTTON_DPAD_RIGHT)
	assert_true(selector.has_focus(), "controller Right follows the same plural-version path")

	row.grab_focus()
	await _tab()
	assert_true(selector.has_focus())
	await _tab()
	assert_true(replay.has_focus())
	await _tab()
	assert_true(_home.has_focus())
	await _tab(true)
	assert_true(replay.has_focus())
	await _tab(true)
	assert_true(selector.has_focus())
	assert_eq(_gallery.get("_selected_version"), version, "directional navigation retains the exact version")
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_bridge.starts.size(), 0)
	assert_true(_localization.set_locale("zh_HK").get("ok", false))
	assert_true(_profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false))
	await _settle()
	_gallery.refresh_return_navigation() # The title host republishes this shell edge.
	_home.grab_focus()
	await _tab(true)
	assert_true(replay.has_focus(), "locale, size, and shell refresh retain the reverse action path")


func test_temporarily_unavailable_replay_query_keeps_record_and_history_while_repairing_focus() -> void:
	_record(_alone(false))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-navigation:query").get("ok", false))
	await _mount()
	_replay().grab_focus()
	var before: Dictionary = _profile.get_profile_snapshot()
	var persisted: Dictionary = _files.snapshot_persisted()
	var offset: float = _gallery.get("_index_offset")
	_profile.query_unavailable = true
	_profile.publish_restore()
	await _settle()
	assert_eq(_gallery.get("_selected_id"), "ending.alone")
	assert_true(_replay().disabled)
	assert_true(_selected_row().has_focus())
	assert_eq(_gallery.get("_index_offset"), offset)
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_files.snapshot_persisted(), persisted)
	_profile.query_unavailable = false
	_profile.publish_restore()
	await _settle()
	await _key(KEY_RIGHT)
	assert_true(_replay().has_focus(), "a recovered public query restores the available action path")
	assert_eq(_bridge.starts.size(), 0)


func test_existing_practice_action_remains_in_the_reversible_tab_path() -> void:
	_record(_alone(false))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-navigation:practice").get("ok", false))
	await _mount()
	assert_true(_gallery.configure_rehearsal(PracticeGame.new(), null).get("ok", false))
	var practice: Button = _gallery.get("_practice_button")
	assert_true(practice.visible)
	_selected_row().grab_focus()
	await _tab()
	assert_true(_replay().has_focus())
	await _tab()
	assert_true(practice.has_focus())
	await _tab()
	assert_true(_home.has_focus())
	await _tab(true)
	assert_true(practice.has_focus())
	assert_eq(_bridge.starts.size(), 0)


func test_authoritative_refresh_disabling_replay_repairs_focus_to_fallback_record() -> void:
	_record(_alone(false))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-navigation:reached").get("ok", false))
	assert_true(_profile.unlock_ending("ending.sylvia.sweet", "gallery-navigation:fallback").get("ok", false))
	await _mount()
	var replay := _replay()
	replay.grab_focus()
	var offset_before: float = _gallery.get("_index_offset")

	# A public Profile publication removes the focused record from discovery while
	# retaining its immutable reached receipt. The surviving record has no Replay.
	var candidate: Dictionary = _profile.get_profile_snapshot()
	candidate.gallery_unlocks.erase("ending.alone")
	assert_true(_profile.commit_prepared_profile(candidate).get("ok", false))
	await _settle()
	var fallback := _selected_row()
	assert_not_null(fallback)
	assert_eq(fallback.get_meta(&"gallery_record_id"), "ending.sylvia.sweet")
	assert_true(_replay().disabled)
	assert_eq(_replay().focus_mode, Control.FOCUS_NONE)
	assert_true(fallback.has_focus(), "disabled Replay repairs focus to the selected fallback record")
	assert_eq(_gallery.get("_index_offset"), offset_before, "focus repair does not drift the valid index offset")


func test_screen_drag_over_row_scrolls_owner_and_cancels_held_pointer_selection() -> void:
	_record(_alone(false))
	for ending_id: String in SCHEMA.ENDING_IDS:
		assert_true(_profile.unlock_ending(ending_id, "gallery-navigation:overflow:" + ending_id).get("ok", false))
	await _mount()
	assert_gt(float(_gallery.get("_index_extent")), 592.0)
	var row := _selected_row()
	var point := row.get_global_rect().get_center()
	var activations: Array = []
	row.pressed.connect(func() -> void: activations.append(true))
	row.grab_focus()
	await _move(point)
	await _mouse(point, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = point
	drag.relative = Vector2(0, -80)
	_surface.push_input(drag, true)
	await _settle()
	await _mouse(point, false)
	assert_gt(float(_gallery.get("_index_offset")), 0.0, "touch drag over a row reaches the index scroll owner")
	assert_eq(_gallery.get("_selected_id"), "ending.alone")
	assert_true(row.has_focus(), "scrolling alone does not move semantic focus")
	assert_eq(activations.size(), 0, "the drag cancels the preceding pointer press")


func test_overflow_paper_owns_navigation_boundaries_and_retained_action_reveal() -> void:
	_record(_alone(false))
	_record(_alone(true))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-paper:inputs").get("ok", false))
	await _mount(true)
	var paper: Control = _gallery._record_paper
	var before: Dictionary = _profile.get_profile_snapshot()
	var signature: String = _gallery._selected_signature_id()
	var index_offset: float = _gallery._index_offset
	assert_true(paper.has_overflow())
	assert_eq(paper.focus_mode, Control.FOCUS_ALL)
	_selected_row().grab_focus()
	await _key(KEY_RIGHT)
	assert_true(paper.has_focus(), "Right enters overflow details before its actions")
	await _key(KEY_END)
	assert_eq(paper.scroll_offset, paper.content_extent - 512.0)
	await _key(KEY_DOWN)
	await _key(KEY_PAGEDOWN)
	await _dpad(JOY_BUTTON_DPAD_DOWN)
	assert_true(paper.has_focus(), "boundary keys cannot escape the scroll owner")
	await _key(KEY_ENTER)
	await _key(KEY_SPACE)
	await _dpad(JOY_BUTTON_A)
	assert_eq(_bridge.starts.size(), 0)
	assert_eq(_gallery._index_offset, index_offset)
	await _key(KEY_HOME)
	assert_eq(paper.scroll_offset, 0.0)
	await _tab()
	assert_true(_selector().has_focus())
	var action := _selector().get_global_rect().grow(8)
	assert_true(paper.get_global_rect().encloses(action), "focusing the retained action reveals its complete ring")
	var offset: float = paper.scroll_offset
	await _key(KEY_LEFT)
	assert_true(_selected_row().has_focus())
	assert_eq(paper.scroll_offset, offset, "returning to the same record keeps the paper anchor")
	assert_eq(_gallery._selected_signature_id(), signature)
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_bridge.starts.size(), 0)

func test_same_record_refresh_locale_and_replay_keep_paper_anchor_new_record_resets() -> void:
	_record(_alone(false))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-paper:anchor").get("ok", false))
	assert_true(_profile.unlock_ending("ending.sylvia.sweet", "gallery-paper:other").get("ok", false))
	await _mount(true)
	var paper: Control = _gallery._record_paper
	paper.scroll_to(180)
	paper.grab_focus()
	_profile.publish_restore()
	await _settle()
	assert_eq(paper.scroll_offset, 180.0, "same identity publication preserves the exact anchor")
	assert_true(paper.has_focus())
	assert_true(_localization.set_locale("zh_HK").get("ok", false))
	assert_true(_profile.set_preference(&"preferences.accessibility.text_size", 150).get("ok", false))
	await _settle()
	assert_eq(paper.scroll_offset, 180.0)
	assert_eq(paper.accessibility_name, "\u8a18\u9304\u8a73\u60c5")
	var signature: String = _gallery._selected_signature_id()
	_gallery._on_replay_pressed()
	assert_eq(paper.scroll_offset, 180.0)
	assert_eq(paper.focus_mode, Control.FOCUS_NONE, "replay retires paper input")
	_bridge.reached_replay_finished.emit({"signature_id": signature, "playback_token": "gallery-navigation", "outcome": "completed"})
	await _settle()
	assert_eq(paper.scroll_offset, 180.0, "Replay roundtrip restores paper without moving it")
	assert_true(_replay().has_focus())
	for row: Button in _gallery.get_node("%EndingTileGrid").get_children():
		if row.get_meta(&"gallery_record_id") == "ending.sylvia.sweet": row.grab_focus()
	await _settle()
	assert_eq(paper.scroll_offset, 0.0)
	assert_false(paper.has_overflow())
	assert_eq(paper.focus_mode, Control.FOCUS_NONE)

func test_overflow_loss_repairs_focus_and_pointer_selection_has_no_keyboard_ring() -> void:
	_record(_alone(false))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-paper:focus").get("ok", false))
	await _mount(true)
	var paper: Control = _gallery._record_paper
	paper.grab_focus()
	paper.scroll_to(200)
	_gallery.long_record = false
	_gallery._refresh_record_copy()
	await _settle()
	assert_false(paper.has_overflow())
	assert_eq(paper.scroll_offset, 0.0)
	assert_true(_selected_row().has_focus(), "loss of overflow repairs focus to its selected record")
	_replay().grab_focus()
	# The long row remains taller than the clipped index after the paper shrinks.
	# Its origin can be scrolled offscreen; click its actual visible intersection.
	var index: Control = _gallery.get_node("%IndexViewport")
	var visible_row := _selected_row().get_global_rect().intersection(index.get_global_rect())
	assert_true(visible_row.has_area(), "selected row has a visible pointer target")
	var point := visible_row.get_center()
	await _move(point)
	await _mouse(point, true)
	await _mouse(point, false)
	assert_true(_selected_row().has_focus())
	assert_false(_selected_row().has_focus(true), "pointer selection retains semantic focus without the keyboard ring")
	await _key(KEY_RIGHT)
	assert_true(_replay().has_focus(true))


func test_removed_overflow_record_returns_to_fallback_row_without_moving_its_paper() -> void:
	_record(_alone(false))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-paper:removed").get("ok", false))
	assert_true(_profile.unlock_ending("ending.sylvia.sweet", "gallery-paper:survivor").get("ok", false))
	await _mount(true)
	_gallery.long_record_ids.append("ending.sylvia.sweet")
	var paper: Control = _gallery._record_paper
	paper.scroll_to(200)
	paper.grab_focus()
	var candidate: Dictionary = _profile.get_profile_snapshot()
	candidate.gallery_unlocks.erase("ending.alone")
	assert_true(_profile.commit_prepared_profile(candidate).get("ok", false))
	await _settle()
	assert_eq(_gallery._selected_id, "ending.sylvia.sweet")
	assert_true(paper.has_overflow())
	assert_eq(paper.scroll_offset, 0.0)
	assert_true(_selected_row().has_focus(), "removed details return to the surviving record, not its different paper")

func test_pointer_replay_focus_stays_hidden_through_refresh_and_replay_return() -> void:
	_record(_alone(false))
	assert_true(_profile.unlock_ending("ending.alone", "gallery-paper:pointer-replay").get("ok", false))
	await _mount()
	_replay().grab_focus(true)
	_profile.publish_restore()
	await _settle()
	assert_true(_replay().has_focus())
	assert_false(_replay().has_focus(true))
	var signature: String = _gallery._selected_signature_id()
	_gallery._on_replay_pressed()
	_bridge.reached_replay_finished.emit({"signature_id": signature, "playback_token": "gallery-navigation", "outcome": "completed"})
	await _settle()
	assert_true(_replay().has_focus())
	assert_false(_replay().has_focus(true), "pointer replay returns without adding a keyboard ring")


func _mount(long_record := false) -> void:
	var host := Control.new()
	host.position = Vector2(320, 64)
	host.size = Vector2(960, 656)
	_surface.add_child(host)
	_gallery = GALLERY.instantiate()
	_gallery.set_script(LONG_GALLERY)
	_gallery.long_record = long_record
	assert_true(_gallery.configure_title_host(_home, _localization, _profile).get("ok", false))
	_bridge = ReplayBridge.new()
	assert_true(_gallery.configure_replay(_bridge).get("ok", false))
	host.add_child(_gallery)
	_gallery.open_in_title_host()
	await _settle()


func _record(signature: Dictionary) -> void:
	assert_true(_profile.record_reached_presentation(signature).get("ok", false))


func _alone(dark: bool) -> Dictionary:
	return {"entry_id": "ending.alone.dark_mode" if dark else "ending.alone.normal", "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": "alone_dark_mode" if dark else "alone_normal"}}


func _selected_row() -> Button:
	for child: Node in _gallery.get_node("%EndingTileGrid").get_children():
		if child.get_meta(&"gallery_record_id") == _gallery.get("_selected_id"):
			return child as Button
	return null


func _replay() -> Button:
	return _gallery.get_node("%ReplayButton")


func _selector() -> OptionButton:
	return _gallery.get("_version_selector") as OptionButton


func _settle() -> void:
	for frame: int in range(3):
		await get_tree().process_frame


func _key(code: Key) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
		event.pressed = pressed
		_surface.push_input(event, true)
		await get_tree().process_frame
	await _settle()


func _dpad(button_index: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button_index
		event.pressed = pressed
		_surface.push_input(event, true)
		await get_tree().process_frame
	await _settle()


func _tab(shifted := false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_TAB
		event.physical_keycode = KEY_TAB
		event.shift_pressed = shifted
		event.pressed = pressed
		_surface.push_input(event, true)
		await get_tree().process_frame
	await _settle()


func _move(point: Vector2) -> void:
	var event := InputEventMouseMotion.new()
	event.position = point
	event.global_position = point
	_surface.push_input(event, true)
	await _settle()


func _mouse(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	_surface.push_input(event, true)
	await _settle()
