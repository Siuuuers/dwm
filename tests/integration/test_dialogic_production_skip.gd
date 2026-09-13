extends "res://addons/gut/test.gd"

## Native Dialogic skip path: an authored #id on a physical Text event reaches the real
## runtime adapter, bridge, and memory-backed ProfileManager. Only the entry locator is a
## test seam; the adapter, runtime, history writer, and policy are production objects.
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
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

var _runtime: DialogicGameHandler
var _adapter: RefCounted
var _bridge: Node
var _profile: Node
var _files: RefCounted
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _style_directory: Dictionary = {}
var _ready_fixture := false
var _native_signals: Array = []


func before_each() -> void:
	_ready_fixture = false
	var wrapper := OS.get_environment("DWM_TEST_ROOT").strip_edges()
	assert_false(wrapper.is_empty(), "DWM_TEST_ROOT is required before fixture I/O")
	if wrapper.is_empty(): return
	assert_true(FileAccess.file_exists(FIXTURE), "dedicated native skip fixture exists")
	var loaded := IDS.load_ids_default()
	assert_true(loaded.get("ok", false), str(loaded))
	if not loaded.get("ok", false): return
	_files = FILES.new()
	_profile = autofree(MANAGER.new())
	var registered: Dictionary = _profile.configure_line_registry(loaded.value)
	assert_true(registered.get("ok", false), str(registered))
	if not registered.get("ok", false): return
	var storage := STORAGE.new(wrapper.path_join("dialogic-production-skip"), _files)
	assert_true(storage.describe_root().begins_with(wrapper), "all profile writes stay under isolated root")
	var initialized: Dictionary = _profile.initialize(storage)
	assert_true(initialized.get("ok", false), str(initialized))
	if not initialized.get("ok", false): return
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


func test_native_fixture_setup_without_skip() -> void:
	if not await _start(): return
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_A)
	assert_false(_profile.is_line_visited(LINE_A), "setup has not requested a skip")


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
	assert_eq(_current_text_key(), "Text/%s/text" % LINE_B, "normal Accept advances exactly once")
	assert_false(_profile.is_line_visited(LINE_B), "no queued Skip step consumes the new line")
