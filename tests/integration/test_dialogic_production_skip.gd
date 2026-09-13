extends "res://addons/gut/test.gd"

## Native Dialogic skip path: an authored #id on a physical Text event reaches the real
## runtime adapter, bridge, and memory-backed ProfileManager. Only the entry locator is a
## test seam; the adapter, runtime, history writer, and policy are production objects.
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const LOCALIZATION := preload("res://autoload/LocalizationManager.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://tests/support/FakeFileOps.gd")
const IDS := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const FIXTURE := "res://tests/fixtures/dialogic/production_skip.dtl"
const ENTRY := "contact.ordinary.lavinia.day1"
const LINE_A := "line.contact.ordinary.lavinia.day1.reply.a"
const LINE_B := "line.contact.ordinary.lavinia.day1.reply.b"
const LINE_C := "line.contact.ordinary.lavinia.day1.reply.c"

class FixtureCatalog:
	static var fixture_label := "contact.ordinary.lavinia.day1"
	static func get_entry(entry_id: String, _locale: String = "en") -> Dictionary:
		if entry_id != "contact.ordinary.lavinia.day1":
			return {"ok": false, "code": &"unknown_entry"}
		return {"ok": true, "value": {"entry_id": entry_id, "locale": "en",
			"requested_locale": "en", "path": "res://tests/fixtures/dialogic/production_skip.dtl",
			"label": fixture_label,
			"used_fallback": false}}


class RetryableProfileWriteOps extends "res://tests/support/FakeFileOps.gd":
	var reject_next_profile_marker := false
	var rejected_paths: Array[String] = []
	func fail_next_profile_marker_write() -> void:
		reject_next_profile_marker = true
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if reject_next_profile_marker \
				and path.replace("\\", "/").ends_with("/profile.json.txn.json"):
			reject_next_profile_marker = false
			rejected_paths.append(path)
			return {"ok": false, "code": &"fixture_profile_marker_write_failure"}
		return super.write_bytes(path, bytes)

var _runtime: DialogicGameHandler
var _adapter: RefCounted
var _bridge: Node
var _profile: Node
var _files: RefCounted
var _localization: Node
var _original_localization: Node
var _original_localization_index := 0
var _original_runtime: Node
var _original_runtime_index := 0
var _original_profile: Node
var _original_profile_index := 0
var _original_bridge: Node
var _original_bridge_index := 0
var _fixture_owners_at_root := false
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _style_directory: Dictionary = {}
var _ready_fixture := false
var _native_signals: Array = []
var _profile_write_failures: Array[Dictionary] = []


func before_each() -> void:
	_ready_fixture = false
	_profile_write_failures.clear()
	var wrapper := OS.get_environment("DWM_TEST_ROOT").strip_edges()
	assert_false(wrapper.is_empty(), "DWM_TEST_ROOT is required before fixture I/O")
	if wrapper.is_empty(): return
	assert_true(FileAccess.file_exists(FIXTURE), "dedicated native skip fixture exists")
	var loaded := IDS.load_ids_default()
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false): return
	_files = RetryableProfileWriteOps.new()
	_profile = autofree(MANAGER.new())
	_profile.profile_write_failed.connect(func(result: Dictionary) -> void:
		_profile_write_failures.append(result.duplicate(true)))
	var registered: Dictionary = _profile.configure_line_registry(loaded.value)
	assert_true(registered.get("ok", false), str(registered))
	if not registered.get("ok", false): return
	var storage := STORAGE.new(wrapper.path_join("dialogic-production-skip"), _files)
	assert_true(storage.describe_root().begins_with(wrapper), "all profile writes stay under isolated root")
	var initialized: Dictionary = _profile.initialize(storage)
	assert_true(initialized.get("ok", false), str(initialized))
	if not initialized.get("ok", false): return
	_localization = LOCALIZATION.new()
	assert_true(_localization.initialize(_profile).get("ok", false))
	_original_localization = get_node("/root/LocalizationManager")
	_original_localization_index = _original_localization.get_index()
	get_tree().root.remove_child(_original_localization)
	_localization.name = "LocalizationManager"
	get_tree().root.add_child(_localization)
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info", {})
	_style_directory = DialogicStylesUtil.style_directory.duplicate(true)
	_original_runtime = get_node("/root/Dialogic")
	_original_runtime_index = _original_runtime.get_index()
	_original_layout = _original_runtime.Styles.get_layout_node()
	if is_instance_valid(_original_layout) and _original_layout.is_inside_tree():
		_original_layout_parent = _original_layout.get_parent()
		_original_layout_index = _original_layout.get_index()
		_original_layout_parent.remove_child(_original_layout)
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.remove_child(_original_runtime)
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	_runtime = DialogicGameHandler.new()
	_runtime.name = "Dialogic"
	get_tree().root.add_child(_runtime)
	_runtime.History.simple_history_enabled = true
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_runtime.signal_event.connect(func(argument: Variant) -> void: _native_signals.append(argument))
	_adapter = ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).get("ok", false))
	_bridge = BRIDGE.new()
	add_child(_bridge)
	assert_true(_bridge.initialize(FixtureCatalog, _adapter).get("ok", false))
	var bound: Dictionary = _bridge.bind_profile_preferences(_profile)
	assert_true(bound.get("ok", false), str(bound))
	_ready_fixture = bound.get("ok", false)


func after_each() -> void:
	_restore_fixture_owners()
	if is_instance_valid(_bridge): _bridge.free()
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	if is_instance_valid(_runtime):
		await _runtime.clear()
		var layout: Node = _runtime.Styles.get_layout_node()
		if is_instance_valid(layout): layout.queue_free()
		await get_tree().process_frame
		_runtime.free()
	_adapter = null
	if is_instance_valid(_localization): _localization.free()
	if is_instance_valid(_original_localization):
		get_tree().root.add_child(_original_localization)
		get_tree().root.move_child(_original_localization, _original_localization_index)
	if _original_runtime == null: return
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	if is_instance_valid(_original_layout) and is_instance_valid(_original_layout_parent):
		_original_layout_parent.add_child(_original_layout)
		_original_layout_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	for key: String in _settings:
		ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null


func _install_fixture_owners_at_root() -> bool:
	if _fixture_owners_at_root: return true
	var root := get_tree().root
	_original_profile = root.get_node_or_null("ProfileManager")
	_original_bridge = root.get_node_or_null("DialogicBridge")
	assert_not_null(_original_profile, "the production ProfileManager autoload is installed")
	assert_not_null(_original_bridge, "the production DialogicBridge autoload is installed")
	if _original_profile == null or _original_bridge == null: return false
	_original_profile_index = _original_profile.get_index()
	_original_bridge_index = _original_bridge.get_index()
	root.remove_child(_original_profile)
	root.remove_child(_original_bridge)
	_profile.name = "ProfileManager"
	root.add_child(_profile)
	_bridge.get_parent().remove_child(_bridge)
	_bridge.name = "DialogicBridge"
	root.add_child(_bridge)
	_fixture_owners_at_root = true
	return true


func _restore_fixture_owners() -> void:
	if not _fixture_owners_at_root: return
	var root := get_tree().root
	if is_instance_valid(_bridge) and _bridge.get_parent() == root: root.remove_child(_bridge)
	if is_instance_valid(_profile) and _profile.get_parent() == root: root.remove_child(_profile)
	if is_instance_valid(_original_profile): root.add_child(_original_profile)
	if is_instance_valid(_original_bridge): root.add_child(_original_bridge)
	if is_instance_valid(_original_profile): root.move_child(_original_profile, _original_profile_index)
	if is_instance_valid(_original_bridge): root.move_child(_original_bridge, _original_bridge_index)
	_fixture_owners_at_root = false


func _start(label: String = ENTRY) -> bool:
	if not _ready_fixture: return false
	FixtureCatalog.fixture_label = label
	var context := {"expected_stage": "current_entry", "playback_id": "skip-native-fixture",
		"role": "primary", "transaction_id": "skip-native-transaction"}
	var started: Dictionary = _bridge.start_entry(ENTRY, context)
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return false
	for frame: int in 4: await get_tree().process_frame
	assert_true(_runtime.current_timeline != null, "the native fixture is running")
	return _runtime.current_timeline != null


func _current_text_key() -> String:
	var index: int = _runtime.current_event_idx
	if index < 0 or index >= _runtime.current_timeline_events.size(): return ""
	var event: Variant = _runtime.current_timeline_events[index]
	return event.get_property_translation_key("text") if event is DialogicTextEvent else ""


func _mounted_caption_layer() -> Node:
	var layout: Node = _runtime.Styles.get_layout_node()
	if layout == null: return null
	for candidate: Node in layout.get_layers():
		if candidate.get_script() != null \
				and candidate.get_script().resource_path == "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd":
			return candidate
	return null


func _press_focused_enter(frames: int = 4) -> void:
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		Input.parse_input_event(key)
	Input.flush_buffered_events()
	for frame: int in frames: await get_tree().process_frame


func _fail_next_retryable_profile_write() -> void:
	_files.call("fail_next_profile_marker_write")


func _assert_retryable_profile_failure(expected_count: int) -> void:
	assert_eq(_profile_write_failures.size(), expected_count,
		"the Profile owner reports each rejected presentation write")
	var rejected_paths: Array = _files.get("rejected_paths")
	assert_eq(rejected_paths.size(), expected_count,
		"the fixture fault occurred only at the requested Profile marker write")
	if not rejected_paths.is_empty():
		assert_true(str(rejected_paths.back()).replace("\\", "/").ends_with(
			"/profile.json.txn.json"))
	if _profile_write_failures.is_empty(): return
	var failure: Dictionary = _profile_write_failures.back()
	assert_eq(failure.get("code"), &"write_not_committed",
		"the fixture rejects the first marker write before durable intent")
	assert_false(failure.get("fatal", true), "the rejected write remains explicitly retryable")


func _enable_zero_delay_native_auto() -> void:
	assert_true(_profile.set_preference(
		&"preferences.reading.auto_enabled", true).get("ok", false))
	var native_auto: DialogicAutoAdvance = _runtime.Inputs.auto_advance
	native_auto.fixed_delay = 0.0
	native_auto.per_word_delay = 0.0
	native_auto.per_character_delay = 0.0
	native_auto.await_playing_voice = false
	assert_true(native_auto.enabled_until_user_input)


func test_native_fixture_setup_without_skip() -> void:
	if not await _start(): return
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_A)
	assert_false(_profile.is_line_visited(LINE_A), "setup has not requested a skip")


func test_mounted_text_started_durably_acknowledges_registered_line_without_skip() -> void:
	if not _install_fixture_owners_at_root(): return
	if not await _start(): return
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_A)
	assert_eq(_runtime.current_state, DialogicGameHandler.States.REVEALING_TEXT,
		"the mounted authored line is accepted and revealing")
	assert_true(_profile.is_line_visited(LINE_A),
		"mounted text_started acknowledges the registered line without a Skip command")
	var restarted: Node = autofree(MANAGER.new())
	assert_true(restarted.configure_line_registry(IDS.load_ids_default().value).get("ok", false))
	assert_true(restarted.initialize(STORAGE.new(
		OS.get_environment("DWM_TEST_ROOT").path_join("dialogic-production-skip"), _files)).get("ok", false))
	assert_true(restarted.is_line_visited(LINE_A),
		"a fresh profile owner reads the mounted presentation acknowledgement")


func test_mounted_read_only_first_activation_preserves_pre_presentation_unread_state() -> void:
	if not _install_fixture_owners_at_root(): return
	if not await _start(): return
	assert_true(_profile.is_line_visited(LINE_A),
		"normal mounted presentation is durable before the first Skip activation")
	var layer := _mounted_caption_layer()
	assert_not_null(layer, "native production style mounts the caption rail")
	if layer == null: return
	var first_index: int = _runtime.current_event_idx
	var skip: Button = layer.transport_rail.get_node("Skip")
	skip.grab_focus()
	await _press_focused_enter()
	assert_false(layer.skip_controller.is_skip_active(),
		"Read Only stops after revealing a line that was unread before this presentation")
	assert_eq(_runtime.current_event_idx, first_index,
		"the first activation cannot cross the newly presented line")
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_A)
	skip.grab_focus()
	await _press_focused_enter(6)
	assert_false(layer.skip_controller.is_skip_active(),
		"the second explicit activation settles at the next newly presented line")
	assert_gt(_runtime.current_event_idx, first_index,
		"the second activation may cross the line acknowledged by the first activation")
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_B)


func test_duplicate_mounted_presentation_acknowledgement_is_write_free() -> void:
	if not _install_fixture_owners_at_root(): return
	if not await _start(): return
	assert_true(_profile.is_line_visited(LINE_A))
	assert_true(_bridge.has_method("acknowledge_current_line_presentation"),
		"DialogicBridge owns explicit presentation acknowledgement and retry")
	if not _bridge.has_method("acknowledge_current_line_presentation"): return
	var frontier: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	assert_true(frontier.get("ok", false), str(frontier))
	var operations: int = _files.operation_count()
	_runtime.Text.text_started.emit({"text": "duplicate", "character": null,
		"portrait": "", "append": false})
	await get_tree().process_frame
	assert_eq(_files.operation_count(), operations,
		"a repeated native text_started signal cannot write an identical receipt again")
	for attempt: int in 2:
		var duplicate: Dictionary = _bridge.call("acknowledge_current_line_presentation", frontier)
		assert_true(duplicate.get("ok", false), "duplicate %d: %s" % [attempt, str(duplicate)])
		assert_eq(_files.operation_count(), operations,
			"an explicit duplicate acknowledgement remains write-free")


func test_explicit_presentation_acknowledgement_refuses_a_stale_frontier() -> void:
	if not _install_fixture_owners_at_root(): return
	if not await _start(): return
	assert_true(_bridge.has_method("acknowledge_current_line_presentation"),
		"DialogicBridge owns exact-frontier acknowledgement")
	if not _bridge.has_method("acknowledge_current_line_presentation"): return
	var stale: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	assert_true(stale.get("ok", false), str(stale))
	stale["value"]["frontier"]["value"]["event_index"] = \
		int(stale["value"]["frontier"]["value"]["event_index"]) + 1
	var operations: int = _files.operation_count()
	var refused: Dictionary = _bridge.call("acknowledge_current_line_presentation", stale)
	assert_false(refused.get("ok", true), "a stale presentation frontier must fail closed")
	assert_eq(_files.operation_count(), operations, "frontier refusal performs no profile write")
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_A)


func test_failed_mounted_acknowledgement_blocks_normal_accept_until_fresh_retry_commits() -> void:
	if not _install_fixture_owners_at_root(): return
	_fail_next_retryable_profile_write()
	if not await _start(): return
	assert_false(_profile.is_line_visited(LINE_A), "the injected presentation commit failed")
	_assert_retryable_profile_failure(1)
	assert_true(_bridge.has_method("requires_line_presentation_acknowledgement"),
		"DialogicBridge exposes the pending acknowledgement gate")
	if not _bridge.has_method("requires_line_presentation_acknowledgement"): return
	assert_true(bool(_bridge.call("requires_line_presentation_acknowledgement")))
	var layer := _mounted_caption_layer()
	assert_not_null(layer)
	if layer == null: return
	_runtime.Text.skip_text_reveal()
	_runtime.Inputs.input_block_timer.stop()
	var first_index: int = _runtime.current_event_idx
	_fail_next_retryable_profile_write()
	layer.caption_text.grab_focus()
	await _press_focused_enter()
	assert_eq(_runtime.current_event_idx, first_index,
		"Normal Accept cannot cross the line while its durable acknowledgement still fails")
	assert_false(_profile.is_line_visited(LINE_A))
	_assert_retryable_profile_failure(2)
	assert_true(bool(_bridge.call("requires_line_presentation_acknowledgement")))
	_runtime.Inputs.input_block_timer.stop()
	layer.caption_text.grab_focus()
	await _press_focused_enter()
	assert_true(_profile.is_line_visited(LINE_A),
		"a fresh accepted input retries and durably acknowledges the same frontier")
	assert_gt(_runtime.current_event_idx, first_index,
		"the successful fresh retry may then perform its native Normal Accept")
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_B)


func test_failed_mounted_acknowledgement_blocks_zero_delay_native_auto_advance() -> void:
	if not _install_fixture_owners_at_root(): return
	_enable_zero_delay_native_auto()
	_fail_next_retryable_profile_write()
	if not await _start(): return
	_assert_retryable_profile_failure(1)
	var first_index: int = _runtime.current_event_idx
	_runtime.Text.skip_text_reveal()
	for frame: int in 6: await get_tree().process_frame
	assert_eq(_runtime.current_event_idx, first_index,
		"zero-delay native Auto cannot cross a line whose presentation acknowledgement failed")
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_A)
	assert_false(_profile.is_line_visited(LINE_A))
	assert_true(bool(_profile.get_preference(&"preferences.reading.auto_enabled", false)),
		"the committed Auto preference stays on while acknowledgement is pending")
	assert_true(_bridge.has_method("requires_line_presentation_acknowledgement"))
	if _bridge.has_method("requires_line_presentation_acknowledgement"):
		assert_true(bool(_bridge.call("requires_line_presentation_acknowledgement")))


func test_failed_acknowledgement_blocks_automatic_choice_open_until_fresh_accept_retry() -> void:
	if not _install_fixture_owners_at_root(): return
	_fail_next_retryable_profile_write()
	if not await _start("choice_boundary"): return
	_assert_retryable_profile_failure(1)
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_C)
	var first_index: int = _runtime.current_event_idx
	_runtime.Text.skip_text_reveal()
	for frame: int in 6: await get_tree().process_frame
	assert_eq(_runtime.current_event_idx, first_index,
		"native text completion cannot open the choice before durable acknowledgement")
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_C)
	assert_false(_profile.is_line_visited(LINE_C))
	assert_true(_bridge.has_method("requires_line_presentation_acknowledgement"))
	if _bridge.has_method("requires_line_presentation_acknowledgement"):
		assert_true(bool(_bridge.call("requires_line_presentation_acknowledgement")))
	var layer := _mounted_caption_layer()
	assert_not_null(layer)
	if layer == null: return
	_runtime.Inputs.input_block_timer.stop()
	layer.caption_text.grab_focus()
	await _press_focused_enter()
	assert_true(_profile.is_line_visited(LINE_C),
		"fresh explicit Accept retries the exact presented line")
	assert_gt(_runtime.current_event_idx, first_index)
	assert_true(_runtime.current_timeline_events[_runtime.current_event_idx] is DialogicChoiceEvent,
		"the accepted retry may then open the authored choice")


func test_failed_acknowledgement_blocks_native_auto_skip_timer_and_choice() -> void:
	if not _install_fixture_owners_at_root(): return
	_fail_next_retryable_profile_write()
	if not await _start("choice_boundary"): return
	_assert_retryable_profile_failure(1)
	var first_index: int = _runtime.current_event_idx
	_runtime.Inputs.auto_skip.time_per_event = 0.001
	_runtime.Inputs.auto_skip.disable_on_unread_text = false
	_runtime.Inputs.auto_skip.enabled = true
	for frame: int in 12: await get_tree().process_frame
	assert_true(_runtime.Inputs.auto_skip.enabled)
	assert_eq(_runtime.current_event_idx, first_index,
		"native Auto-Skip timer cannot advance a line whose presentation acknowledgement failed")
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_C)
	assert_false(_runtime.current_timeline_events[_runtime.current_event_idx] is DialogicChoiceEvent,
		"neither Auto-Skip completion path may open the pending choice")
	assert_false(_profile.is_line_visited(LINE_C))


func test_failed_acknowledgement_blocks_native_auto_skip_armed_after_text_is_done() -> void:
	if not _install_fixture_owners_at_root(): return
	_fail_next_retryable_profile_write()
	if not await _start("choice_boundary"): return
	_assert_retryable_profile_failure(1)
	var first_index: int = _runtime.current_event_idx
	_runtime.Text.skip_text_reveal()
	for frame: int in 2: await get_tree().process_frame
	assert_eq(_runtime.current_event_idx, first_index)
	var text_event := _runtime.current_timeline_events[first_index] as DialogicTextEvent
	assert_not_null(text_event)
	if text_event == null: return
	assert_eq(text_event.state, DialogicTextEvent.States.DONE,
		"the second path arms Auto-Skip after the local text event reaches DONE")
	_runtime.Inputs.auto_skip.time_per_event = 0.001
	_runtime.Inputs.auto_skip.disable_on_unread_text = false
	_runtime.Inputs.auto_skip.enabled = true
	for frame: int in 12: await get_tree().process_frame
	assert_true(_runtime.Inputs.auto_skip.enabled)
	assert_eq(_runtime.current_event_idx, first_index,
		"arming native Auto-Skip after reveal cannot bypass the pending acknowledgement")
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_C)
	assert_false(_runtime.current_timeline_events[_runtime.current_event_idx] is DialogicChoiceEvent)
	assert_false(_profile.is_line_visited(LINE_C))


func test_canonical_line_without_an_id_retains_native_manual_accept() -> void:
	if not _install_fixture_owners_at_root(): return
	if not await _start("no_id"): return
	assert_false(_bridge.requires_line_presentation_acknowledgement(),
		"prose without a semantic ID stays outside the durable acknowledgement owner")
	var layer := _mounted_caption_layer()
	assert_not_null(layer)
	if layer == null: return
	var first_index: int = _runtime.current_event_idx
	_runtime.Text.skip_text_reveal()
	_runtime.Inputs.input_block_timer.stop()
	layer.caption_text.grab_focus()
	await _press_focused_enter()
	assert_true(_runtime.current_timeline == null or _runtime.current_event_idx > first_index,
		"legacy no-ID prose retains native manual progression")


func test_canonical_unregistered_line_retains_native_zero_delay_auto() -> void:
	if not _install_fixture_owners_at_root(): return
	_enable_zero_delay_native_auto()
	if not await _start("unregistered"): return
	assert_false(_bridge.requires_line_presentation_acknowledgement(),
		"unregistered prose stays outside the durable acknowledgement owner")
	var first_index: int = _runtime.current_event_idx
	_runtime.Text.skip_text_reveal()
	for frame: int in 6: await get_tree().process_frame
	assert_true(_runtime.current_timeline == null or _runtime.current_event_idx > first_index,
		"legacy unregistered prose retains native Auto progression")
	assert_false(_profile.is_line_visited("fixture.skip.unregistered"))


func test_registered_wrong_owner_blocks_native_auto_and_manual_accept() -> void:
	if not _install_fixture_owners_at_root(): return
	_enable_zero_delay_native_auto()
	if not await _start("cross_owner"): return
	assert_true(_bridge.requires_line_presentation_acknowledgement(),
		"a registered line cannot bypass acknowledgement merely because its owner is wrong")
	var first_index: int = _runtime.current_event_idx
	_runtime.Text.skip_text_reveal()
	for frame: int in 6: await get_tree().process_frame
	assert_eq(_runtime.current_event_idx, first_index,
		"automatic progression is blocked for a registered line from another entry")
	var layer := _mounted_caption_layer()
	assert_not_null(layer)
	if layer == null: return
	_runtime.Inputs.input_block_timer.stop()
	layer.caption_text.grab_focus()
	await _press_focused_enter()
	assert_eq(_runtime.current_event_idx, first_index,
		"manual Accept cannot cross the wrong-owner registered line")
	assert_false(_profile.is_line_visited("line.contact.ordinary.priscilla.day3.reply.a"))


func test_mounted_rehearsal_text_started_never_mutates_the_root_profile() -> void:
	if not _install_fixture_owners_at_root(): return
	var before: Dictionary = _profile.get_profile_snapshot()
	var operations: int = _files.operation_count()
	FixtureCatalog.fixture_label = ENTRY
	var started: Dictionary = _bridge.start_entry(ENTRY, {
		"expected_stage": "current_entry", "playback_id": "skip-mounted-rehearsal-fixture",
		"role": "primary", "transaction_id": "skip-mounted-rehearsal-transaction"}, &"rehearsal")
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	for frame: int in 4: await get_tree().process_frame
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_A)
	assert_true(_bridge.is_rehearsal_playback())
	assert_eq(_profile.get_profile_snapshot(), before,
		"mounted replay presentation has zero direct canonical profile mutation")
	assert_eq(_files.operation_count(), operations)
	assert_true(_bridge.has_method("acknowledge_current_line_presentation"))
	if not _bridge.has_method("acknowledge_current_line_presentation"): return
	var rehearsal_frontier: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	assert_false(rehearsal_frontier.get("ok", true))
	var refused: Dictionary = _bridge.call("acknowledge_current_line_presentation", rehearsal_frontier)
	assert_false(refused.get("ok", true), "direct replay acknowledgement is denied")
	assert_eq(_profile.get_profile_snapshot(), before)
	assert_eq(_files.operation_count(), operations)


func test_native_fixture_binding_without_playback() -> void:
	assert_true(_ready_fixture)


func test_read_only_reveals_persists_and_only_then_advances() -> void:
	if not await _start(): return
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_A, "the native #id is the semantic source")
	var first_index: int = _runtime.current_event_idx
	var first: Dictionary = _bridge.request_skip_step()
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	assert_eq(first.receipt.line_id, LINE_A)
	assert_false(first.receipt.was_visited_before_reveal)
	assert_false(first.value.advance, "unread line stops read_only after reveal")
	assert_eq(_runtime.current_event_idx, first_index)
	assert_true(_profile.is_line_visited(LINE_A))
	var restarted: Node = autofree(MANAGER.new())
	assert_true(restarted.configure_line_registry(IDS.load_ids_default().value).get("ok", false))
	assert_true(restarted.initialize(STORAGE.new(
		OS.get_environment("DWM_TEST_ROOT").path_join("dialogic-production-skip"), _files)).get("ok", false))
	assert_true(restarted.is_line_visited(LINE_A), "fresh profile owner reads the durable visited line")
	var text_node: DialogicNode_DialogText = get_tree().get_first_node_in_group("dialogic_dialog_text") as DialogicNode_DialogText
	assert_not_null(text_node)
	if text_node != null: assert_almost_eq(text_node.visible_ratio, 1.0, 0.001, "native text fully revealed")
	var again: Dictionary = _bridge.request_skip_step()
	assert_true(again.get("ok", false), str(again))
	if not again.get("ok", false): return
	assert_true(again.receipt.was_visited_before_reveal)
	assert_true(again.value.advance, "the persisted line may now advance to known text")
	assert_gt(_runtime.current_event_idx, first_index)
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_B)
	var second: Dictionary = _bridge.request_skip_step()
	assert_true(second.get("ok", false), str(second))
	if second.get("ok", false):
		assert_false(second.value.advance, "second unread line also stops")
		assert_true(_profile.is_line_visited(LINE_B))


func test_live_all_text_preference_advances_and_read_only_takes_effect_immediately() -> void:
	if not await _start(): return
	assert_true(_profile.set_preference(&"preferences.reading.skip_mode", "all_text").get("ok", false))
	var first_index: int = _runtime.current_event_idx
	var step: Dictionary = _bridge.request_skip_step()
	assert_true(step.get("ok", false), str(step))
	if not step.get("ok", false): return
	assert_true(step.value.advance)
	assert_gt(_runtime.current_event_idx, first_index)
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_B)
	assert_true(_profile.set_preference(&"preferences.reading.skip_mode", "read_only").get("ok", false))
	var second_index: int = _runtime.current_event_idx
	var stopped: Dictionary = _bridge.request_skip_step()
	assert_true(stopped.get("ok", false), str(stopped))
	if stopped.get("ok", false):
		assert_eq(stopped.value.mode, &"read_only")
		assert_false(stopped.value.advance)
		assert_eq(_runtime.current_event_idx, second_index)


func _assert_stopped_boundary(label: String, boundary: StringName) -> void:
	if not await _start(label): return
	assert_true(_profile.set_preference(&"preferences.reading.skip_mode", "all_text").get("ok", false))
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_C)
	var index: int = _runtime.current_event_idx
	var signals_before: int = _native_signals.size()
	var step: Dictionary = _bridge.request_skip_step()
	assert_true(step.get("ok", false), "%s: %s" % [label, str(step)])
	if not step.get("ok", false): return
	assert_eq(step.receipt.next_boundary, boundary, label)
	assert_false(step.value.advance, label)
	assert_true(step.value.stop_before_boundary, label)
	assert_eq(_runtime.current_event_idx, index, label)
	assert_eq(_native_signals.size(), signals_before, "boundary signal must not execute: " + label)
	assert_true(_profile.is_line_visited(LINE_C), "current line was marked: " + label)


func test_choice_stops_during_reveal_then_normal_next_opens_it() -> void:
	if not await _start("choice_boundary"): return
	assert_eq(_runtime.current_state, DialogicGameHandler.States.REVEALING_TEXT,
		"skip begins on revealing text before the native choice opens")
	assert_true(_profile.set_preference(&"preferences.reading.skip_mode", "all_text").get("ok", false))
	var index: int = _runtime.current_event_idx
	var step: Dictionary = _bridge.request_skip_step()
	assert_true(step.get("ok", false), str(step))
	if not step.get("ok", false): return
	assert_eq(step.receipt.next_boundary, &"choice")
	assert_false(step.value.advance)
	assert_eq(_runtime.current_event_idx, index, "held skip did not open native choice")
	_runtime.Inputs.input_block_timer.stop()
	_runtime.Inputs.handle_input()
	for frame: int in 2: await get_tree().process_frame
	assert_gt(_runtime.current_event_idx, index, "ordinary Next opens the pending choice")
	assert_true(_runtime.current_timeline_events[_runtime.current_event_idx] is DialogicChoiceEvent,
		"the successor is the native choice event")


func test_default_adapter_reveal_retains_native_next_behavior() -> void:
	if not await _start("choice_boundary"): return
	var index: int = _runtime.current_event_idx
	assert_true(_adapter.reveal_current_line().get("ok", false), "default reveal remains the restore path")
	for frame: int in 2: await get_tree().process_frame
	assert_gt(_runtime.current_event_idx, index, "unprotected native reveal opens the choice")
	assert_true(_runtime.current_timeline_events[_runtime.current_event_idx] is DialogicChoiceEvent)


func test_effect_signal_stops_before_execution() -> void:
	await _assert_stopped_boundary("effect_boundary", &"effect_transaction")


func test_variable_signal_stops_before_execution() -> void:
	await _assert_stopped_boundary("variable_boundary", &"variable_transaction")


func test_return_stops_before_departure() -> void:
	await _assert_stopped_boundary("return_boundary", &"scene_transition")


func test_unknown_wait_stops_as_validation_error() -> void:
	await _assert_stopped_boundary("unknown_boundary", &"validation_error")


func _assert_refused_id(label: String, line_id: String) -> void:
	if not await _start(label): return
	var index: int = _runtime.current_event_idx
	var before: Dictionary = _profile.get_profile_snapshot()
	var refused: Dictionary = _bridge.request_skip_step()
	assert_false(refused.get("ok", true), "%s must fail closed" % label)
	assert_eq(_runtime.current_event_idx, index, label)
	assert_eq(_profile.get_profile_snapshot().visited_line_ids, before.visited_line_ids,
		"no history write for " + label)
	if not line_id.is_empty(): assert_false(_profile.is_line_visited(line_id))


func test_no_id_refuses_without_history_write() -> void:
	await _assert_refused_id("no_id", "")
	assert_eq(_adapter.current_line_id(), "", "no #id never becomes an inferred identifier")


func test_unregistered_id_refuses_without_history_write() -> void:
	await _assert_refused_id("unregistered", "fixture.skip.unregistered")


func test_registered_cross_owner_id_refuses_without_history_write() -> void:
	await _assert_refused_id("cross_owner", "line.contact.ordinary.priscilla.day3.reply.a")


func test_skip_availability_reads_without_revealing_or_writing() -> void:
	assert_false(_bridge.can_skip_current_line())
	if not await _start(): return
	var before: Dictionary = _profile.get_profile_snapshot()
	var frontier: Dictionary = _adapter.capture_pause_frontier()
	assert_true(_bridge.can_skip_current_line())
	assert_false(_bridge.is_rehearsal_playback())
	assert_true(_bridge.can_skip_current_line())
	assert_eq(_profile.get_profile_snapshot(), before, "availability cannot witness a line")
	assert_eq(_adapter.capture_pause_frontier(), frontier, "availability cannot advance or reveal")


func test_rehearsal_has_no_skip_history_mutation() -> void:
	if not _ready_fixture: return
	FixtureCatalog.fixture_label = ENTRY
	var started: Dictionary = _bridge.start_entry(ENTRY, {
		"expected_stage": "current_entry", "playback_id": "skip-rehearsal-fixture",
		"role": "primary", "transaction_id": "skip-rehearsal-transaction"}, &"rehearsal")
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	for frame: int in 4: await get_tree().process_frame
	var before: Dictionary = _profile.get_profile_snapshot()
	assert_true(_bridge.is_rehearsal_playback())
	assert_false(_bridge.can_skip_current_line())
	assert_eq(_bridge.request_skip_step().get("code"), &"rehearsal_commit_denied")
	assert_eq(_profile.get_profile_snapshot(), before)


func test_late_transport_configuration_acknowledges_visible_canonical_line_once() -> void:
	if not await _start(): return
	assert_false(_profile.is_line_visited(LINE_A),
		"the non-root fixture bridge has not yet owned the visible caption")
	var layer := _mounted_caption_layer()
	assert_not_null(layer)
	if layer == null: return
	var publications: Array[String] = []
	_profile.visited_history_changed.connect(func(line_id: String, visited: bool) -> void:
		if visited: publications.append(line_id))
	var operations_before: int = _files.operation_count()
	assert_true(layer.configure_reading_transport(_profile, _bridge))
	assert_true(_profile.is_line_visited(LINE_A),
		"late binding acknowledges the canonical caption that is already visible")
	assert_eq(publications, [LINE_A])
	var operations_after_first: int = _files.operation_count()
	assert_gt(operations_after_first, operations_before)
	assert_true(layer.configure_reading_transport(_profile, _bridge))
	assert_eq(publications, [LINE_A], "rebinding cannot publish a second visited event")
	assert_eq(_files.operation_count(), operations_after_first,
		"the duplicate late acknowledgement performs no FileOps write")


func test_ancestor_hidden_text_started_waits_for_visible_fresh_accept() -> void:
	if not _install_fixture_owners_at_root(): return
	if not await _start(): return
	assert_true(_profile.is_line_visited(LINE_A))
	var layer := _mounted_caption_layer()
	assert_not_null(layer)
	if layer == null: return
	_runtime.Text.skip_text_reveal()
	for frame: int in 2: await get_tree().process_frame
	var first_event := _runtime.current_timeline_events[_runtime.current_event_idx] as DialogicTextEvent
	assert_not_null(first_event)
	if first_event == null: return
	assert_eq(first_event.state, DialogicTextEvent.States.DONE,
		"the setup advances only after the real first Text event has settled")
	layer.canvas.hide()
	first_event.advance.emit()
	for frame: int in 4: await get_tree().process_frame
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_B,
		"the native fixture reached the next line while its caption ancestor was hidden")
	assert_false(layer.caption_text.is_visible_in_tree())
	assert_false(_profile.is_line_visited(LINE_B),
		"a hidden text_started signal is not a witnessed presentation")
	layer.caption_text.hide()
	layer.canvas.show()
	layer.caption_text.show()
	for frame: int in 2: await get_tree().process_frame
	_runtime.Text.skip_text_reveal()
	_runtime.Inputs.input_block_timer.stop()
	layer.caption_text.grab_focus()
	await _press_focused_enter()
	assert_true(_profile.is_line_visited(LINE_B),
		"fresh input on the actually visible caption acknowledges the exact current source")


func test_source_cleared_during_normal_accept_rejects_old_caption_proof() -> void:
	if not _install_fixture_owners_at_root(): return
	if not await _start(): return
	var layer := _mounted_caption_layer()
	assert_not_null(layer)
	if layer == null: return
	assert_true(_bridge.is_current_line_presentation_acknowledged())
	_runtime.Text.skip_text_reveal()
	_runtime.Inputs.input_block_timer.stop()
	var first_index: int = _runtime.current_event_idx
	layer.accept_input.normal_accept_requested.connect(func() -> void:
		_bridge._active_entry.clear())
	layer.caption_text.grab_focus()
	await _press_focused_enter()
	assert_false(_bridge.requires_line_presentation_acknowledgement(),
		"the listener removed the live semantic source during the accepted input")
	assert_eq(_runtime.current_event_idx, first_index,
		"the stale canonical caption proof cannot authorize manual progression")
	assert_false(layer.accept_input.is_automatic_advance_admitted(_runtime),
		"the same stale proof cannot authorize a later automatic callback")


func test_source_replacement_announced_during_accept_cancels_old_caption_before_generation_change() -> void:
	if not _install_fixture_owners_at_root(): return
	if not await _start(): return
	var layer := _mounted_caption_layer()
	assert_not_null(layer)
	if layer == null: return
	assert_true(_bridge.is_current_line_presentation_acknowledged())
	_runtime.Text.skip_text_reveal()
	_runtime.Inputs.input_block_timer.stop()
	var first_index: int = _runtime.current_event_idx
	layer.accept_input.normal_accept_requested.connect(func() -> void:
		_bridge._active_entry.clear()
		layer._on_about_to_show_text({}))
	layer.caption_text.grab_focus()
	await _press_focused_enter()
	assert_eq(_runtime.current_event_idx, first_index,
		"a synchronously announced replacement cancels the in-flight old-caption Accept")
	assert_false(layer.accept_input.is_automatic_advance_admitted(_runtime),
		"cleared replacement state cannot authorize an automatic callback on the old caption")


func test_mounted_rail_uses_real_skip_and_keeps_unimplemented_owners_disabled() -> void:
	if not await _start(): return
	var layout: Node = _runtime.Styles.get_layout_node()
	var layer: Node
	for candidate: Node in layout.get_layers():
		if candidate.get_script().resource_path == "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd":
			layer = candidate
	assert_not_null(layer, "native production style mounts the caption rail")
	if layer == null: return
	assert_true(layer.configure_reading_transport(_profile, _bridge))
	var rail: Control = layer.transport_rail
	assert_true(rail.visible)
	assert_eq(rail.get_child_count(), 6)
	var skip: Button = rail.get_node("Skip")
	assert_false(skip.disabled)
	assert_eq(layer.caption_text.get_node(layer.caption_text.focus_next), skip)
	assert_eq(skip.get_node(skip.focus_next), layer.caption_text)
	for command: String in ["History", "Auto", "Save", "Load", "Next"]:
		var button: Button = rail.get_node(command)
		assert_true(button.disabled, command + " has no completed owner yet")
		assert_eq(button.focus_mode, Control.FOCUS_NONE)
	var index: int = _runtime.current_event_idx
	await get_tree().process_frame
	skip.grab_focus()
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		Input.parse_input_event(key)
	Input.flush_buffered_events()
	assert_true(layer.skip_controller.is_skip_active(), "the actual focused rail button starts Skip")
	for frame: int in 4: await get_tree().process_frame
	assert_false(layer.skip_controller.is_skip_active(), "read-only stops at unseen prose")
	assert_true(_profile.is_line_visited(LINE_A), "the existing bridge durably marks the revealed line")
	assert_eq(_runtime.current_event_idx, index, "first unseen line is revealed, never crossed")
	for candidate: Node in layout.get_layers():
		if candidate.has_method("get_show_history_button"):
			assert_false(candidate.get_show_history_button().visible, "no seventh addon History control")
	assert_true(_profile.set_preference(&"preferences.reading.skip_mode", "all_text").get("ok", false))
	var button_generation: int = skip._generation
	assert_true(layer.skip_controller.toggle_skip().get("ok", false))
	for frame: int in 6: await get_tree().process_frame
	assert_true(_profile.is_line_visited(LINE_B), "the pump continues across ordinary prose")
	assert_false(layer.skip_controller.is_skip_active(), "the pump stops before native Return")
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_B)
	assert_gt(skip._generation, button_generation, "a new beat retires pending rail activation")


func test_native_normal_accept_stops_skip_before_the_dialogic_command() -> void:
	if not await _start(): return
	var layer: Node
	for candidate: Node in _runtime.Styles.get_layout_node().get_layers():
		if candidate.get_script().resource_path == "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd":
			layer = candidate
	assert_not_null(layer)
	if layer == null: return
	assert_true(layer.configure_reading_transport(_profile, _bridge))
	_runtime.Text.skip_text_reveal()
	_runtime.Inputs.input_block_timer.stop()
	layer.caption_text.grab_focus()
	var before_index: int = _runtime.current_event_idx
	var observed: Array[Dictionary] = []
	layer.accept_input.normal_accept_requested.connect(func():
		observed.append({"skip_active": layer.skip_controller.is_skip_active(), "index": _runtime.current_event_idx}))
	assert_true(layer.skip_controller.toggle_skip().get("ok", false))
	assert_true(layer.skip_controller.is_skip_active())
	for pressed: bool in [true, false]:
		var key := InputEventKey.new()
		key.keycode = KEY_ENTER
		key.physical_keycode = KEY_ENTER
		key.pressed = pressed
		Input.parse_input_event(key)
	Input.flush_buffered_events()
	for frame: int in 3: await get_tree().process_frame
	assert_eq(observed, [{"skip_active": false, "index": before_index}],
		"the mounted policy retires Skip before calling the real Inputs owner")
	assert_false(layer.skip_controller.is_skip_active())
	assert_eq(_runtime.current_event_idx, before_index + 1, "normal Accept advances exactly one event")
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_B, "normal Accept advances exactly once")


func test_mounted_rail_uses_committed_catalog_locale_without_advancing_dialogue() -> void:
	if not await _start(): return
	var layer: Node
	for candidate: Node in _runtime.Styles.get_layout_node().get_layers():
		if candidate.get_script().resource_path == "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd":
			layer = candidate
	assert_not_null(layer)
	if layer == null: return
	assert_true(layer.configure_reading_transport(_profile, _bridge))
	var rail: Node = layer.transport_rail
	var skip: Button = rail.get_node("Skip")
	assert_eq(skip.text, "Skip \u00b7 Off")
	var before: Dictionary = layer.get_caption_projection()
	var theme_before: Theme = layer.canvas.theme
	assert_false(layer.configure_presentation("zh-CN", 100, "Midnight"),
		"the whole caption/rail tuple refuses an uncommitted locale")
	assert_eq(layer.get_caption_projection(), before)
	assert_same(layer.canvas.theme, theme_before)
	assert_eq(skip.text, "Skip \u00b7 Off")
	var index: int = _runtime.current_event_idx
	var line := _current_text_key()
	var visited_before: Array = _profile.get_profile_snapshot().visited_line_ids.duplicate()
	var generation: int = skip._generation
	assert_true(_localization.set_locale("zh_HK").get("ok", false))
	assert_same(layer.transport_rail, rail)
	assert_same(rail.get_node("Skip"), skip)
	assert_eq(skip.text, "\u8df3\u904e \u00b7 \u95dc")
	assert_eq((rail.get_node("History") as Button).text, "\u6b77\u53f2")
	assert_gt(skip._generation, generation)
	assert_eq(_runtime.current_event_idx, index)
	assert_eq(_current_text_key(), line)
	assert_eq(_profile.get_profile_snapshot().visited_line_ids, visited_before,
		"changing UI copy does not alter the visited-line set")


class InstalledChineseRun extends Node:
	var day := 7
	func get_run_configuration() -> Dictionary:
		return {"ok": true, "value": {"dark_mode": true}}


func test_chinese_initial_mount_keeps_the_installed_run_day_and_palette() -> void:
	if not _ready_fixture: return
	assert_true(_localization.set_locale("zh_CN").get("ok", false))
	var original := get_node("/root/GameState")
	var original_index := original.get_index()
	get_tree().root.remove_child(original)
	var run := InstalledChineseRun.new()
	run.name = "GameState"
	get_tree().root.add_child(run)
	var started := await _start()
	get_tree().root.remove_child(run)
	get_tree().root.add_child(original)
	get_tree().root.move_child(original, original_index)
	run.free()
	if not started: return
	var layer: Node
	for candidate: Node in _runtime.Styles.get_layout_node().get_layers():
		if candidate.get_script().resource_path == "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd":
			layer = candidate
	assert_not_null(layer)
	if layer == null: return
	var projection: Dictionary = layer.get_caption_projection()
	assert_eq(projection.locale, "zh-CN")
	assert_eq(projection.palette, "Midnight")
	assert_eq(projection.day, 7)
	assert_eq((layer.transport_rail.get_node("Skip") as Button).text, "\u8df3\u8fc7 \u00b7 \u5173")
