extends "res://addons/gut/test.gd"
## Real installed Dialogic, Bridge, and runtime/physical adapters. All caption prose and
## command provenance below are synthetic fixtures, not authored Hospital content.
## The shipped Hospital timeline currently has no reading caption. A temporary resource-cache
## override at its catalog-resolved path tests its real public start seam without editing content.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const RUNTIME_ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PHYSICAL_OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const COORDINATOR := preload("res://scripts/application/lifecycle/ApplicationLifecycleCoordinator.gd")
const INPUT_OWNER := preload("res://autoload/InputManager.gd")
const LAYER := "res://scripts/ui/witnessed/WitnessedCaptionLayer.gd"
const TIMELINE_ID := "hospital.faint"
const HANDLE := {"generation": 1, "handle_id": "synthetic-pause-frontier", "holder": &"pause_fixture", "reason": &"universal_pause"}

class PauseScene extends Control:
	var projection: Dictionary
	func get_presentation_projection() -> Dictionary: return projection.duplicate(true)

class PauseRoute extends RefCounted:
	func get_current_route_id() -> String: return "hospital"

class PauseGate extends RefCounted:
	func guard_external(_command: StringName) -> Dictionary: return {"ok": true, "code": &"ok", "value": {}}

class AudioFixture extends RefCounted:
	# Only an orchestration dependency; actual audio cursor tests are separate.
	var held: Dictionary = {}
	func begin_suspend(handle: Dictionary) -> Dictionary:
		held = handle.duplicate(true)
		return {"ok": true, "code": &"ok", "value": {"frontier_id": "synthetic-audio"}}
	func resume(handle: Dictionary) -> Dictionary:
		if handle != held: return {"ok": false, "code": &"invalid_suspension_handle", "value": null}
		held.clear()
		return {"ok": true, "code": &"ok", "value": {"resumed": true}}
	func get_state() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"state": &"Active" if held.is_empty() else &"Suspended"}}

var _runtime: DialogicGameHandler
var _adapter: RefCounted
var _bridge: Node
var _owner: RefCounted
var _caption: Node
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _style_directory: Dictionary = {}
var _path := ""
var _original_timeline: Resource
var _synthetic: DialogicTimeline
var _finished := 0
var _ended := 0
var _receipts: Array = []
var _coordinator: Node
var _pause_scene: PauseScene
var _input_owner: Node
var _original_input: Node
var _original_input_index := 0
var _original_scene: Node
var _old_process_mode: int
var _window_size: Vector2i
var _window_content_size: Vector2i
# Coordinator dependencies are Object-typed, so the fixture retains its RefCounted ports.
var _pause_route: PauseRoute
var _pause_gate: PauseGate
var _pause_audio: AudioFixture

func before_each() -> void:
	_old_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	_original_scene = get_tree().current_scene
	_window_size = get_tree().root.size
	_window_content_size = get_tree().root.content_scale_size
	_coordinator = null
	_pause_scene = null
	_input_owner = null
	_original_input = null
	await get_tree().process_frame
	await get_tree().process_frame
	_finished = 0
	_ended = 0
	_receipts = []
	_caption = null
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
	_settings.clear()
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	_runtime = DialogicGameHandler.new()
	_runtime.name = "Dialogic"
	get_tree().root.add_child(_runtime)
	_runtime.History.simple_history_enabled = true
	_runtime.History.full_event_history_enabled = true
	_runtime.History.visited_event_history_enabled = true
	_runtime.History.save_visited_history_on_save = false
	_runtime.History.save_visited_history_on_autosave = false
	_runtime.Text.text_finished.connect(func(_info: Dictionary): _finished += 1)
	_runtime.timeline_ended.connect(func(): _ended += 1)
	_adapter = RUNTIME_ADAPTER.new()
	assert_true(_adapter.bind_runtime(_runtime).ok)
	_bridge = BRIDGE.new()
	add_child(_bridge)
	assert_true(_bridge.initialize(null, _adapter).ok)
	_owner = PHYSICAL_OWNER.new()
	assert_true(_owner.configure(_bridge).ok)
	_owner.physical_completion_ready.connect(func(receipt: Dictionary): _receipts.append(receipt.duplicate(true)))
	var located: Dictionary = DialogicTimelineCatalog.get_path_for_id(TIMELINE_ID)
	assert_true(located.ok)
	_path = located.value.path
	_original_timeline = load(_path)
	assert_not_null(_original_timeline)

func after_each() -> void:
	get_tree().paused = false
	if is_instance_valid(_input_owner): _native_pause_pointer(Vector2.ZERO, false)
	if is_instance_valid(_coordinator): _coordinator.free()
	get_tree().current_scene = _original_scene
	if is_instance_valid(_pause_scene): _pause_scene.free()
	if is_instance_valid(_bridge): _bridge.free()
	_owner = null
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	if is_instance_valid(_runtime):
		_runtime.paused = false
		await _runtime.clear()
		var layout: Node = _runtime.Styles.get_layout_node()
		if is_instance_valid(layout): layout.queue_free()
		await get_tree().process_frame
		_runtime.free()
	if is_instance_valid(_input_owner): _input_owner.free()
	if is_instance_valid(_original_input):
		get_tree().root.add_child(_original_input)
		get_tree().root.move_child(_original_input, _original_input_index)
	_adapter = null
	if _original_timeline != null: _original_timeline.take_over_path(_path)
	_synthetic = null
	_original_timeline = null
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime, _original_runtime_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_original_layout_parent):
			_original_layout_parent.add_child(_original_layout)
			_original_layout_parent.move_child(_original_layout, _original_layout_index)
		get_tree().set_meta("dialogic_layout_node", _original_layout)
	for key: String in _settings:
		ProjectSettings.set_setting(key, _settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info", _persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null
	get_tree().root.size = _window_size
	get_tree().root.content_scale_size = _window_content_size
	process_mode = _old_process_mode

func _fixture(copy: String) -> void:
	_synthetic = DialogicTimeline.new()
	_synthetic.from_text(copy)
	_synthetic.take_over_path(_path)

func _settle() -> void:
	for frame in 4: await get_tree().process_frame

func _find_caption() -> bool:
	var layout: Node = _runtime.Styles.get_layout_node()
	if is_instance_valid(layout):
		for layer: Node in layout.get_layers():
			if layer.get_script().resource_path == LAYER: _caption = layer
	assert_not_null(_caption, "real Hospital style selection mounts the owned caption")
	return _caption != null

func _start(copy: String) -> bool:
	_fixture(copy)
	var result: Dictionary = _bridge.start_timeline_id(TIMELINE_ID)
	assert_true(result.ok, str(result))
	await _settle()
	return result.ok and _find_caption()

func _reading_state() -> Dictionary:
	var native: DialogicNode_DialogText = _caption.caption_text
	return {"generation": _runtime.get_timeline_generation(), "event": _runtime.current_event_idx,
		"state": _runtime.current_state, "text": native.text, "reveal_generation": native.get_reveal_generation(),
		"visible_characters": native.visible_characters, "revealing": native.revealing,
		"simple": _runtime.History.simple_history_content.duplicate(true),
		"full": _runtime.History.full_event_history_content.duplicate(true),
		"visited": _runtime.History.visited_event_history_content.duplicate(true),
		"finished": _finished, "ended": _ended, "receipts": _receipts.duplicate(true)}

func test_live_reveal_handle_is_exact_idempotent_and_resumes_without_completion() -> void:
	if not await _start("Synthetic reading frontier remains on the original caption. ".repeat(20)): return
	_caption.caption_text.active_speed = 10.0
	assert_true(_caption.caption_text.revealing)
	var frontier: Dictionary = _bridge.capture_pause_frontier(TIMELINE_ID)
	assert_true(frontier.ok)
	assert_false(frontier.value.has("paused"), "the public source identity excludes mutable Pause state")
	var before := _reading_state()
	var admitted: Dictionary = _bridge.begin_suspend(HANDLE)
	assert_true(admitted.ok, str(admitted))
	assert_eq(_bridge.get_state().value.state, &"Suspended")
	assert_true(_runtime.paused)
	assert_eq(_bridge.begin_suspend(HANDLE.duplicate(true)), admitted)
	var other := HANDLE.duplicate(true)
	other.generation = 2
	assert_false(_bridge.begin_suspend(other).ok)
	assert_false(_bridge.resume(other).ok)
	assert_false(_bridge.start_timeline_id(TIMELINE_ID).ok, "new playback cannot replace suspended reading")
	assert_eq(_bridge.request_skip_step().code, &"narrative_suspended")
	await get_tree().create_timer(0.1).timeout
	assert_eq(_reading_state(), before)
	assert_eq(_bridge.capture_pause_frontier(TIMELINE_ID), frontier)
	assert_true(_bridge.resume(HANDLE).ok)
	assert_false(_runtime.paused)
	assert_eq(_bridge.get_state().value.state, &"Active")
	assert_eq(_reading_state(), before, "resume itself neither finishes nor advances the original generation")
	assert_false(_bridge.resume(HANDLE).ok)

func test_idle_text_frontier_preserves_an_existing_runtime_pause() -> void:
	if not await _start("Synthetic already revealed caption."): return
	_caption.caption_text.finish_text()
	await _settle()
	assert_eq(_runtime.current_state, DialogicGameHandler.States.IDLE)
	_runtime.paused = true
	var before := _reading_state()
	assert_true(_bridge.capture_pause_frontier(TIMELINE_ID).ok)
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	assert_true(_bridge.resume(HANDLE).ok)
	assert_true(_runtime.paused, "Continue restores the original paused value")
	assert_eq(_reading_state(), before)
	assert_eq(_ended, 0)
	assert_eq(_receipts, [])

func test_native_pause_effect_preserves_remaining_time_through_bridge_custody() -> void:
	var effects: Array[String] = []
	var times := {}
	_runtime.text_signal.connect(func(argument: String):
		effects.append(argument)
		times[argument] = Time.get_ticks_msec())
	if not await _start("[signal=synthetic-entered][pause=0.6!][signal=synthetic-resumed]Done."): return
	var native: DialogicNode_DialogText = _caption.caption_text
	for frame in 60:
		if effects == ["synthetic-entered"] and not native.revealing: break
		await get_tree().create_timer(0.01).timeout
	assert_eq(effects, ["synthetic-entered"])
	assert_false(native.revealing)
	if effects != ["synthetic-entered"] or native.revealing: return
	await get_tree().create_timer(0.22).timeout
	var spent := Time.get_ticks_msec() - int(times["synthetic-entered"])
	assert_gte(spent, 200)
	assert_lt(spent, 350)
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	var before := _reading_state()
	await get_tree().create_timer(0.8).timeout
	assert_eq(effects, ["synthetic-entered"])
	assert_eq(_reading_state(), before)
	var resumed_at := Time.get_ticks_msec()
	assert_true(_bridge.resume(HANDLE).ok)
	assert_eq(_reading_state(), before)
	await get_tree().create_timer(0.1).timeout
	assert_eq(effects, ["synthetic-entered"], "suspended wall time is not charged to the remaining native delay")
	for frame in 120:
		if _finished > 0: break
		await get_tree().create_timer(0.025).timeout
	assert_eq(effects, ["synthetic-entered", "synthetic-resumed"])
	var observed := int(times.get("synthetic-resumed", 0)) - resumed_at
	assert_gte(observed, 600 - spent - 120)
	assert_lte(observed, 600 - spent + 120, "resume retains the remainder rather than restarting the effect")
	assert_eq(_finished, 1)
	assert_eq(_runtime.current_event_idx, before.event)
	assert_eq(_runtime.get_timeline_generation(), before.generation)
	assert_eq(_runtime.History.simple_history_content, before.simple)
	assert_eq(_ended, 0)
	assert_eq(_receipts, [])

func test_no_playback_deferred_start_and_native_cleanup_have_no_frontier() -> void:
	assert_false(_adapter.capture_pause_frontier().ok)
	assert_false(_bridge.begin_suspend(HANDLE).ok)
	_fixture("Synthetic deferred first caption.")
	assert_true(_bridge.start_timeline_id(TIMELINE_ID).ok)
	assert_false(_adapter.capture_pause_frontier().ok, "a queued layout has not published a reading frontier")
	assert_false(_bridge.begin_suspend(HANDLE).ok)
	await _settle()
	assert_true(_bridge.capture_pause_frontier(TIMELINE_ID).ok)
	_runtime.end_timeline(true)
	assert_false(_adapter.capture_pause_frontier().ok, "native cleanup is not a stable source")
	assert_false(_bridge.begin_suspend(HANDLE).ok)
	await _settle()
	assert_false(_bridge.capture_pause_frontier().ok)
	assert_eq(_bridge.get_state().value.state, &"Active")

func test_native_nontext_wait_refuses_pause_without_changing_playback() -> void:
	if not await _start('[wait time="0.5" hide_text="true"]\nSynthetic later caption.'): return
	assert_true(_runtime.current_timeline_events[_runtime.current_event_idx] is DialogicWaitEvent)
	assert_eq(_runtime.current_state, DialogicGameHandler.States.WAITING)
	var generation := _runtime.get_timeline_generation()
	var index := _runtime.current_event_idx
	assert_false(_adapter.capture_pause_frontier().ok)
	assert_false(_bridge.begin_suspend(HANDLE).ok)
	assert_false(_runtime.paused)
	assert_eq(_runtime.get_timeline_generation(), generation)
	assert_eq(_runtime.current_event_idx, index)
	assert_eq(_bridge.get_state().value.state, &"Active")
	# Let the real Wait's unbound native tween finish before fixture teardown.
	await get_tree().create_timer(0.6).timeout

func test_retained_physical_owner_publishes_same_source_without_a_completion() -> void:
	_fixture("Synthetic Hospital-path reading fixture; not shipped Hospital prose. ".repeat(20))
	var command := {"resolution_id": "synthetic-resolution", "resolution_issuer_receipt": {"receipt_id": "synthetic-root"},
		"stage_id": "synthetic-stage", "substage_id": "synthetic-substage", "route_id": "hospital", "timeline_id": TIMELINE_ID,
		"context": {}, "completion_transaction_id": "synthetic-completion", "completion_transaction_provenance": {},
		"command_sha256": "c".repeat(64)}
	assert_false(_owner.capture_pause_source().ok)
	assert_true(_owner.begin_physical(command).ok)
	await _settle()
	if not _find_caption(): return
	_caption.caption_text.active_speed = 10.0
	var source: Dictionary = _owner.capture_pause_source()
	assert_true(source.ok, str(source))
	assert_eq(source.value.timeline_id, TIMELINE_ID)
	assert_eq(source.value.route_id, "hospital")
	assert_eq(source.value.completion_transaction_id, command.completion_transaction_id)
	assert_false(_bridge.capture_pause_frontier("opening.day1").ok)
	var before := _reading_state()
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	assert_eq(_owner.capture_pause_source(), source)
	assert_true(_bridge.resume(HANDLE).ok)
	assert_eq(_owner.capture_pause_source(), source, "owner revision/token/frontier are retained exactly")
	assert_eq(_reading_state(), before)
	assert_eq(_receipts, [])

func _start_combined_pause_fixture() -> bool:
	# The replacement is the real InputManager script, mounted at the actual source-policy
	# lookup. Its original autoload is restored after this isolated input experiment.
	_original_input = get_node("/root/InputManager")
	_original_input_index = _original_input.get_index()
	get_tree().root.remove_child(_original_input)
	_input_owner = INPUT_OWNER.new()
	_input_owner.name = "InputManager"
	get_tree().root.add_child(_input_owner)
	get_tree().root.size = Vector2i(1280, 720)
	get_tree().root.content_scale_size = Vector2i(1280, 720)
	_pause_scene = PauseScene.new()
	get_tree().root.add_child(_pause_scene)
	get_tree().current_scene = _pause_scene
	_fixture("Synthetic native Pause fixture preserves this overflowing current caption. ".repeat(30))
	var command := {"resolution_id": "synthetic-resolution", "resolution_issuer_receipt": {"receipt_id": "synthetic-root"},
		"stage_id": "synthetic-stage", "substage_id": "synthetic-substage", "route_id": "hospital", "timeline_id": TIMELINE_ID,
		"context": {}, "completion_transaction_id": "synthetic-pause-completion", "completion_transaction_provenance": {},
		"command_sha256": "d".repeat(64)}
	var started: Dictionary = _owner.begin_physical(command)
	assert_true(started.ok, str(started))
	await _settle()
	if not started.ok or not _find_caption(): return false
	var source: Dictionary = _owner.capture_pause_source()
	assert_true(source.ok, str(source))
	if not source.ok: return false
	_pause_scene.projection = source.value.duplicate(true)
	_pause_route = PauseRoute.new()
	_pause_gate = PauseGate.new()
	_pause_audio = AudioFixture.new()
	_coordinator = COORDINATOR.new()
	add_child(_coordinator)
	assert_true(_coordinator.configure(_owner, _bridge, _input_owner, _pause_audio, _pause_gate, _pause_route).ok)
	assert_true(_coordinator.bind_source(_pause_scene, _caption).ok)
	_caption.caption_text.active_speed = 10.0
	_caption.caption_text.grab_focus()
	await _settle()
	return true

func _native_pause_pointer(point: Vector2, pressed: bool) -> void:
	var event := InputEventMouseButton.new()
	event.position = point
	event.global_position = point
	event.button_index = MOUSE_BUTTON_LEFT
	event.button_mask = MOUSE_BUTTON_MASK_LEFT if pressed else 0
	event.pressed = pressed
	Input.parse_input_event(event)
	Input.flush_buffered_events()

func test_combined_native_pause_restores_caption_owner_and_quarantines_closing_contact() -> void:
	if not await _start_combined_pause_fixture(): return
	var native: DialogicNode_DialogText = _caption.caption_text
	var bar: VScrollBar = _caption.get_scroll_bar()
	assert_gt(bar.max_value - bar.page, 100.0, "the real caption has a feasible manual reading position")
	bar.value = 100
	await _settle()
	assert_true(native.has_focus())
	assert_true(native.revealing)
	var before := _reading_state()
	var source: Dictionary = _owner.capture_pause_source()
	var visible_rect: Rect2 = _caption.get_caption_projection().caption_visible_rect
	var point := visible_rect.get_center()
	point = _caption.canvas.get_global_transform_with_canvas() * point
	_native_pause_pointer(point, true)
	var paused: Dictionary = await _coordinator.request_pause(&"pause_fixture")
	assert_true(paused.ok, str(paused))
	if not paused.ok: return
	assert_true(get_tree().paused)
	assert_true(_runtime.paused)
	assert_eq(_input_owner.get_state().value.state, &"Suspended")
	assert_false(_caption.canvas.is_visible_in_tree())
	assert_false(native.has_focus())
	await get_tree().create_timer(0.15).timeout
	assert_eq(_reading_state(), before)
	assert_eq(_owner.capture_pause_source(), source)
	assert_false(_input_owner.is_source_input_admitted())
	# Release the opening contact while covered, then hold the contact that closes Pause.
	_native_pause_pointer(point, false)
	_native_pause_pointer(point, true)
	assert_true((await _coordinator.request_resume(paused.value)).ok)
	assert_false(get_tree().paused)
	assert_false(_runtime.paused)
	assert_true(_caption.canvas.is_visible_in_tree())
	assert_true(native.has_focus())
	assert_eq(bar.value, 100.0)
	assert_eq(_reading_state(), before, "Continue restores the same native event, text and reveal frontier")
	assert_eq(_owner.capture_pause_source(), source)
	await _settle()
	assert_false(_input_owner.is_source_input_admitted(), "a still-held closing contact remains quarantined beyond its frame")
	_native_pause_pointer(point, false)
	await _settle()
	assert_true(_input_owner.is_source_input_admitted())
	assert_eq(_reading_state(), before, "the stale release neither skips reveal nor advances the event")
	native.active_speed = 0.000001
	for frame in 120:
		if _finished > 0: break
		await get_tree().create_timer(0.01).timeout
	assert_eq(_finished, 1, "the original native reveal subsequently finishes naturally once")
	assert_eq(_runtime.current_event_idx, before.event)
	assert_eq(_runtime.get_timeline_generation(), before.generation)
	assert_eq(_runtime.History.simple_history_content, before.simple)
	assert_eq(_ended, 0)
	assert_eq(_receipts, [], "text completion is not physical timeline completion")

func test_combined_native_source_mismatch_refuses_before_any_suspension() -> void:
	if not await _start_combined_pause_fixture(): return
	var before := _reading_state()
	_pause_scene.projection.physical_token = "synthetic-stale-token"
	var refused: Dictionary = await _coordinator.request_pause(&"pause_fixture")
	assert_false(refused.ok)
	assert_eq(refused.code, &"pause_source_mismatch")
	assert_eq(_coordinator.get_state().value.state, &"Active")
	assert_eq(_bridge.get_state().value.state, &"Active")
	assert_eq(_input_owner.get_state().value.state, &"Active")
	assert_eq(_pause_audio.get_state().value.state, &"Active")
	assert_false(get_tree().paused)
	assert_false(_runtime.paused)
	assert_true(_caption.canvas.is_visible_in_tree())
	assert_eq(_reading_state(), before)
