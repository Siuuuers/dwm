extends GutTest
## Fixture-only authored cues exercise the real Gallery/Profile/catalogue owners.
## Viewport key events are not native OS input or production-content acceptance.

const GALLERY := preload("res://scenes/menu/GalleryScene.tscn")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const CATALOG := preload("res://scripts/ui/gallery/GalleryRecordCatalog.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")

class ReplayBridge extends RefCounted:
	signal reached_replay_finished(result: Dictionary)
	var starts: Array[String] = []
	var fail_start := false
	func configure_reached_replay(_profile: Object) -> Dictionary: return {"ok": true}
	func replay_reached_signature(signature_id: String) -> Dictionary:
		starts.append(signature_id)
		var token := "version-register:%d" % starts.size()
		if fail_start:
			return {"ok": false, "code": &"runtime_start_failed", "failure_phase": &"start",
				"signature_id": signature_id, "playback_token": token}
		return {"ok": true, "receipt": {"playback_token": token}}
	func cancel_reached_replay(_signature_id: String) -> Dictionary: return {"ok": true}

var _surface: SubViewport
var _host: Control
var _home: Button
var _profile: Node
var _localization: Node
var _files: RefCounted
var _bridge: ReplayBridge
var _gallery: Control

func before_each() -> void:
	_surface = SubViewport.new()
	_surface.size = Vector2i(1280, 720)
	_surface.handle_input_locally = true
	add_child(_surface)
	_profile = PROFILE.new()
	_surface.add_child(_profile)
	_files = FILES.new()
	assert_true(_profile.initialize(STORAGE.new("gallery-version-register.memory", _files)).get("ok", false))
	_localization = LOCALIZATION.new()
	_surface.add_child(_localization)
	assert_true(_localization.initialize(_profile).get("ok", false))
	_home = Button.new()
	_home.position = Vector2(320, 0)
	_home.size = Vector2(208, 64)
	_surface.add_child(_home)
	_host = Control.new()
	_host.position = Vector2(320, 64)
	_host.size = Vector2(960, 656)
	_surface.add_child(_host)
	assert_true(_profile.unlock_ending("ending.alone", "version-register:fixture").get("ok", false))

func after_each() -> void:
	_surface.free()

func test_register_requires_plural_versions_and_complete_exact_cues_without_disabling_legacy_replay() -> void:
	var definitions := [_definition(_alone(false), "TEST first", "TEST first record."),
		_definition(_alone(true), "TEST second", "TEST second record.")]
	await _mount(definitions)
	assert_false(_register().visible, "zero witnessed versions reserve no register")
	assert_true(_register().get_rows().is_empty())
	assert_eq(_register().size, Vector2.ZERO)
	assert_false(_gallery._version_selector.visible)
	_record(_alone(false))
	await _mount(definitions)
	assert_false(_register().visible, "one witnessed version needs no register")
	assert_true(_register().get_rows().is_empty())
	assert_eq(_register().size, Vector2.ZERO)
	assert_false(_gallery._version_selector.visible)
	assert_false(_replay().disabled)
	_record(_alone(true))
	await _mount([definitions[0]])
	assert_false(_register().visible, "one missing exact cue retains the existing selector")
	assert_true(_gallery._version_selector.visible)
	assert_eq(_gallery._version_selector.item_count, 2)
	assert_false(_replay().disabled, "missing authored cues cannot revoke existing Replay")
	await _mount(definitions)
	assert_true(_register().visible)
	assert_eq(_register().get_rows().size(), 2)
	assert_false(_gallery._version_selector.visible)
	assert_false(_replay().disabled)
	assert_true(_bridge.starts.is_empty())

func test_key_navigation_visits_every_row_but_right_enters_selected_version_only() -> void:
	await _mount_pair()
	var before := _baseline()
	var rows: Array = _register().get_rows()
	var newest := _id(_alone(true))
	var oldest := _id(_alone(false))
	assert_same(rows[0], _register().row_for_signature(newest))
	assert_same(rows[1], _register().row_for_signature(oldest))
	_selected_record().grab_focus()
	await _right_to_version()
	assert_true(_register().row_for_signature(newest).has_focus())
	await _key(KEY_DOWN)
	assert_eq(_gallery._selected_signature_id(), oldest)
	await _key(KEY_LEFT)
	assert_true(_selected_record().has_focus())
	await _right_to_version()
	assert_true(_register().row_for_signature(oldest).has_focus(), "Right reenters the selected version, not the first row")
	await _key(KEY_RIGHT)
	assert_true(_replay().has_focus())
	await _key(KEY_LEFT)
	assert_true(_selected_record().has_focus())
	await _key(KEY_TAB)
	if _gallery._record_paper.has_overflow():
		assert_true(_gallery._record_paper.has_focus())
		await _key(KEY_TAB)
	assert_true(_register().row_for_signature(newest).has_focus(), "Tab enters visible row order")
	await _key(KEY_TAB)
	assert_true(_register().row_for_signature(oldest).has_focus())
	await _key(KEY_TAB)
	assert_true(_replay().has_focus())
	await _key(KEY_TAB)
	assert_true(_home.has_focus())
	await _key(KEY_TAB, true)
	assert_true(_replay().has_focus())
	await _key(KEY_TAB, true)
	assert_true(_register().row_for_signature(oldest).has_focus())
	await _key(KEY_TAB, true)
	assert_true(_register().row_for_signature(newest).has_focus())
	_assert_unchanged(before)

func test_up_down_clamp_and_republish_exact_copy_without_playback_or_writes() -> void:
	await _mount_pair()
	var before := _baseline()
	_selected_record().grab_focus()
	await _right_to_version()
	var newest := _id(_alone(true))
	var oldest := _id(_alone(false))
	await _key(KEY_UP)
	assert_eq(_gallery._selected_signature_id(), newest)
	assert_true(_register().row_for_signature(newest).has_focus(), "Up cannot wrap from the first version")
	await _key(KEY_DOWN)
	assert_eq(_gallery._selected_signature_id(), oldest)
	assert_eq(_gallery._record_paper.sentence_label.text, "TEST first record.")
	await _key(KEY_DOWN)
	assert_true(_register().row_for_signature(oldest).has_focus(), "Down cannot wrap from the last version")
	await _key(KEY_ENTER)
	await _key(KEY_SPACE)
	assert_eq(_gallery._selected_signature_id(), oldest)
	await _key(KEY_UP)
	assert_eq(_gallery._selected_signature_id(), newest)
	assert_eq(_gallery._record_paper.sentence_label.text, "TEST second record.")
	_assert_visible(_register().row_for_signature(newest))
	_assert_unchanged(before)

func test_pointer_release_cancellation_double_activation_and_dpad_keep_inspection_write_free() -> void:
	await _mount_pair()
	var newest := _id(_alone(true))
	var oldest := _id(_alone(false))
	var first: Button = _register().row_for_signature(newest)
	var second: Button = _register().row_for_signature(oldest)
	first.grab_focus()
	await _settle()
	_assert_visible(first)
	_assert_visible(second)
	var before := _baseline()
	var activations: Array = []
	second.pressed.connect(func() -> void: activations.append(true))
	var point := second.get_global_rect().get_center()
	await _move(point)
	assert_true(first.has_focus(), "hover does not select or focus a version")
	assert_eq(_gallery._selected_signature_id(), newest)
	await _mouse(point, true)
	assert_true(first.has_focus(), "pointer hold is Press only")
	assert_eq(_gallery._selected_signature_id(), newest)
	var outside := Vector2(100, 640)
	await _move(outside)
	await _mouse(outside, false)
	assert_true(activations.is_empty(), "release outside cancels the held version command")
	assert_eq(_gallery._selected_signature_id(), newest)
	await _move(point)
	await _mouse(point, true)
	assert_eq(_gallery._selected_signature_id(), newest)
	await _mouse(point, false)
	assert_eq(activations.size(), 1)
	assert_eq(_gallery._selected_signature_id(), oldest)
	assert_true(second.has_focus())
	assert_false(second.has_focus(true), "pointer release preserves hidden semantic focus")
	# The double-click continuation follows the first completed click above.
	await _mouse(point, true, true)
	await _mouse(point, false)
	assert_eq(activations.size(), 1, "double-click continuation adds no second version command")
	assert_eq(_gallery._selected_signature_id(), oldest)
	await _dpad(JOY_BUTTON_DPAD_DOWN)
	assert_true(second.has_focus(), "controller Down clamps at the last row")
	assert_true(second.has_focus(true), "controller navigation restores visible focus")
	await _dpad(JOY_BUTTON_DPAD_UP)
	assert_true(first.has_focus())
	assert_eq(_gallery._selected_signature_id(), newest)
	await _dpad(JOY_BUTTON_DPAD_UP)
	assert_true(first.has_focus(), "controller Up clamps at the first row")
	_assert_unchanged(before)

func test_drag_over_version_reaches_paper_and_cancels_pointer_activation() -> void:
	_record(_alone(false))
	_record(_alone(true))
	await _mount([_definition(_alone(false), "TEST first", "TEST short record."),
		_definition(_alone(true), "TEST second", "TEST long record. ".repeat(55))])
	_selected_record().grab_focus()
	await _right_to_version()
	var signature: String = _gallery._selected_signature_id()
	var row: Button = _register().row_for_signature(signature)
	var paper: Control = _gallery._record_paper
	assert_gt(paper.scroll_offset, 24.0)
	var offset: float = paper.scroll_offset
	var before := _baseline()
	var activations: Array = []
	row.pressed.connect(func() -> void: activations.append(true))
	var point := row.get_global_rect().get_center()
	await _move(point)
	await _mouse(point, true)
	var drag := InputEventScreenDrag.new()
	drag.index = 1
	drag.position = point
	drag.relative = Vector2(0, 24)
	_surface.push_input(drag, true)
	await _settle()
	await _mouse(point, false)
	assert_lt(paper.scroll_offset, offset, "drag over a version reaches the existing paper scroll owner")
	assert_true(row.has_focus(), "drag does not move semantic focus")
	assert_eq(_gallery._selected_signature_id(), signature)
	assert_true(activations.is_empty(), "drag cancels the preceding pointer hold")
	_assert_unchanged(before)

func test_missing_cue_reprojection_repairs_removed_version_focus_to_selected_record() -> void:
	await _mount_pair()
	var signature := _id(_alone(false))
	_register().row_for_signature(signature).grab_focus(true)
	await _settle()
	assert_eq(_gallery._selected_signature_id(), signature)
	var before := _baseline()
	# Replace injected presentation metadata, never the supported saved chronology.
	_gallery._record_catalog = CATALOG.new({}, [_definition(_alone(false), "TEST first", "TEST first record.")])
	_profile.publish_restore()
	await _settle()
	assert_false(_register().visible)
	assert_true(_register().get_rows().is_empty())
	assert_eq(_register().size, Vector2.ZERO)
	assert_eq(_gallery._selected_signature_id(), signature)
	assert_true(_selected_record().has_focus(), "removed version focus falls back to its selected record")
	assert_false(_selected_record().has_focus(true), "metadata fallback does not invent keyboard focus paint")
	assert_true(_gallery._version_selector.visible)
	assert_eq(_gallery._version_selector.item_count, 2)
	assert_false(_replay().disabled)
	await _key(KEY_RIGHT)
	assert_true(_gallery._version_selector.has_focus(), "the existing available selector remains keyboard reachable")
	_assert_unchanged(before)

func test_retry_retains_exact_selected_identity_and_only_a_different_version_clears_it() -> void:
	await _mount_pair()
	_bridge.fail_start = true
	var signature: String = _gallery._selected_signature_id()
	_replay().grab_focus()
	await _key(KEY_SPACE)
	assert_eq(_bridge.starts, [signature])
	assert_eq(_replay().text, _localization.t("gallery.retry"))
	assert_eq(_gallery._retry_signature_id, signature)
	_profile.publish_restore()
	await _settle()
	assert_eq(_gallery._selected_signature_id(), signature)
	assert_eq(_gallery._retry_signature_id, signature)
	var before := _baseline()
	_register().row_for_signature(signature).grab_focus()
	await _key(KEY_SPACE)
	assert_eq(_gallery._retry_signature_id, signature, "same version is not a fresh target")
	assert_eq(_replay().text, _localization.t("gallery.retry"))
	await _key(KEY_RIGHT)
	assert_true(_replay().has_focus())
	await _key(KEY_SPACE)
	assert_eq(_bridge.starts, [signature, signature], "Retry reuses the exact failed signature")
	assert_eq(_gallery._retry_signature_id, signature)
	# Replay attempts do not alter Profile; establish a new inspection-only baseline.
	assert_eq(_profile.get_profile_snapshot(), before.profile)
	assert_eq(_files.snapshot_persisted(), before.bytes)
	before = _baseline()
	_register().row_for_signature(signature).grab_focus()
	await _key(KEY_DOWN)
	assert_eq(_gallery._selected_signature_id(), _id(_alone(false)))
	assert_eq(_gallery._retry_signature_id, "")
	assert_eq(_replay().text, _localization.t("gallery.replay"))
	_assert_unchanged(before)

func test_newest_witness_insertion_retains_focused_signature_and_newest_first_rows() -> void:
	var signatures := [_date("friend"), _date("ambiguous"), _date("love")]
	var definitions: Array = []
	for index: int in range(signatures.size()):
		definitions.append(_definition(signatures[index], "TEST cue %d" % index, "TEST record %d." % index))
	_record(signatures[0])
	_record(signatures[1])
	await _mount(definitions)
	_record_row(str(signatures[0].entry_id)).grab_focus()
	await _settle()
	await _right_to_version()
	await _key(KEY_DOWN)
	var retained := _id(signatures[0])
	assert_eq(_gallery._selected_signature_id(), retained)
	_record(signatures[2])
	var before := _baseline()
	_profile.publish_restore()
	await _settle()
	assert_eq(_register().get_rows().size(), 3)
	for index: int in range(3):
		assert_same(_register().get_rows()[index], _register().row_for_signature(_id(signatures[2 - index])))
	assert_eq(_gallery._selected_signature_id(), retained)
	assert_true(_register().row_for_signature(retained).has_focus(), "focus survives replacement by exact identity")
	_assert_visible(_register().row_for_signature(retained))
	_assert_unchanged(before)

func test_projection_height_changes_preserve_focus_and_apply_only_needed_scroll_correction() -> void:
	var long_copy := "TEST long record. ".repeat(55)
	_record(_alone(false))
	_record(_alone(true))
	await _mount([_definition(_alone(false), "TEST first", "TEST short record."),
		_definition(_alone(true), "TEST second", long_copy)])
	var before := _baseline()
	var paper: Control = _gallery._record_paper
	assert_true(paper.has_overflow())
	_selected_record().grab_focus()
	await _right_to_version()
	var newest := _id(_alone(true))
	var oldest := _id(_alone(false))
	_assert_visible(_register().row_for_signature(newest))
	assert_gt(paper.scroll_offset, 0.0)
	await _key(KEY_DOWN)
	assert_eq(paper.sentence_label.text, "TEST short record.")
	assert_true(_register().row_for_signature(oldest).has_focus())
	_assert_visible(_register().row_for_signature(oldest))
	var offset: float = paper.scroll_offset
	_profile.publish_restore()
	await _settle()
	assert_true(_register().row_for_signature(oldest).has_focus())
	assert_eq(paper.scroll_offset, offset, "same projection refresh keeps its visible paper anchor")
	await _key(KEY_LEFT)
	assert_true(_selected_record().has_focus())
	assert_eq(paper.scroll_offset, offset, "Left does not move the same record's paper")
	await _right_to_version()
	await _key(KEY_UP)
	assert_eq(paper.sentence_label.text, long_copy)
	assert_true(_register().row_for_signature(newest).has_focus())
	_assert_visible(_register().row_for_signature(newest))
	var body: Control = paper.get_node("PaperPointer/RecordBody")
	var row: Control = _register().row_for_signature(newest)
	var local_rect: Rect2 = body.get_global_transform().affine_inverse() * row.get_global_rect()
	assert_eq(paper.scroll_offset, local_rect.end.y + 8.0 - paper.size.y,
		"growing copy moves only enough to clear the focused row's lower perimeter")
	_assert_unchanged(before)

func _mount_pair() -> void:
	_record(_alone(false))
	_record(_alone(true))
	await _mount([_definition(_alone(false), "TEST first", "TEST first record."),
		_definition(_alone(true), "TEST second", "TEST second record.")])

func _mount(definitions: Array) -> void:
	if is_instance_valid(_gallery): _gallery.free()
	_gallery = GALLERY.instantiate()
	_gallery._record_catalog = CATALOG.new({}, definitions)
	assert_true(_gallery._record_catalog.valid)
	_bridge = ReplayBridge.new()
	assert_true(_gallery.configure_title_host(_home, _localization, _profile).get("ok", false))
	assert_true(_gallery.configure_replay(_bridge).get("ok", false))
	_host.add_child(_gallery)
	_gallery.open_in_title_host()
	await _settle()

func _definition(signature: Dictionary, cue: String, sentence: String) -> Dictionary:
	return {"signature": signature, "version_cue": [cue, cue, cue], "sentence": [sentence, sentence, sentence]}

func _alone(dark: bool) -> Dictionary:
	return {"entry_id": "ending.alone.dark_mode" if dark else "ending.alone.normal", "schema_version": 1,
		"fields": {"ending_role": "core", "ending_form": "alone_dark_mode" if dark else "alone_normal"}}

func _date(tier: String) -> Dictionary:
	return {"entry_id": "dating.solo.lavinia.day2.pre_challenge", "schema_version": 1,
		"fields": {"tier": tier, "tone": "sweet", "attitude": "neutral", "echo_ids": []}}

func _id(signature: Dictionary) -> String:
	return str(SIGNATURE.validate(signature).value.signature_id)

func _record(signature: Dictionary) -> void:
	assert_true(_profile.record_reached_presentation(signature).get("ok", false))

func _register() -> Control: return _gallery.get("_version_register")
func _replay() -> Button: return _gallery.get_node("%ReplayButton")
func _selected_record() -> Button: return _record_row(str(_gallery._selected_id))
func _record_row(record_id: String) -> Button:
	for row: Button in _gallery.get_node("%EndingTileGrid").get_children():
		if str(row.get_meta(&"gallery_record_id")) == record_id: return row
	return null

func _baseline() -> Dictionary:
	return {"profile": _profile.get_profile_snapshot(), "revision": _profile.get_profile_revision(),
		"bytes": _files.snapshot_persisted(), "operations": _files.operation_count(), "starts": _bridge.starts.duplicate()}

func _assert_unchanged(before: Dictionary) -> void:
	assert_eq(_profile.get_profile_snapshot(), before.profile)
	assert_eq(_profile.get_profile_revision(), before.revision)
	assert_eq(_files.snapshot_persisted(), before.bytes)
	assert_eq(_files.operation_count(), before.operations, "inspection performs no storage operation")
	assert_eq(_bridge.starts, before.starts, "only Replay can start playback")

func _assert_visible(row: Control) -> void:
	assert_true(_gallery._record_paper.get_global_rect().encloses(row.get_global_rect().grow(8)),
		"the complete focused row and detached perimeter fit inside the one paper viewport")

func _right_to_version() -> void:
	await _key(KEY_RIGHT)
	if _gallery._record_paper.has_focus(): await _key(KEY_RIGHT)

func _settle() -> void:
	for frame: int in range(4): await get_tree().process_frame

func _key(code: Key, shifted := false) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = code
		event.physical_keycode = code
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

func _mouse(point: Vector2, pressed: bool, double_click := false) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.pressed = pressed
	event.double_click = double_click
	_surface.push_input(event, true)
	await _settle()

func _dpad(button_index: JoyButton) -> void:
	for pressed: bool in [true, false]:
		var event := InputEventJoypadButton.new()
		event.button_index = button_index
		event.pressed = pressed
		_surface.push_input(event, true)
		await get_tree().process_frame
	await _settle()
