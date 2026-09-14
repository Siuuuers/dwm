extends "res://addons/gut/test.gd"
## Real installed Dialogic, Bridge, and runtime/physical adapters. All caption prose and
## command provenance below are synthetic fixtures, not authored Hospital content.
## The shipped Hospital timeline currently has no reading caption. A temporary resource-cache
## override at its catalog-resolved path tests its real public start seam without editing content.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const RUNTIME_ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PHYSICAL_OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const COORDINATOR := preload("res://scripts/application/lifecycle/ApplicationLifecycleCoordinator.gd")
const PRODUCTION_PAUSE := preload("res://scripts/application/lifecycle/ProductionPauseController.gd")
const MUTATION_GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const INPUT_OWNER := preload("res://autoload/InputManager.gd")
const PROFILE_OWNER := preload("res://autoload/ProfileManager.gd")
const LOCALIZATION_OWNER := preload("res://autoload/LocalizationManager.gd")
const MEMORY_STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FAKE_FILES := preload("res://tests/support/FakeFileOps.gd")
const HOSPITAL_SCENE := preload("res://scripts/ui/HospitalScene.gd")
const CAPTION_SCENE := preload("res://scenes/ui/witnessed/WitnessedCaptionLayer.tscn")
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

class MountedRunOwner extends RefCounted:
	var day := 3
	var session_captures := 0
	var handle := {"active": true, "generation": 1, "run_id": "mounted-reading-load", "owner_id": 73}
	func capture_live_session() -> Dictionary:
		session_captures += 1
		return {"ok": true, "value": handle.duplicate(true)}
	func validate_live_session(expected: Dictionary) -> Dictionary:
		return {"ok": expected == handle and handle.active}
	func get_run_configuration() -> Dictionary:
		return {"ok": true, "value": {"dark_mode": false}}

class MountedSaves extends RefCounted:
	var inspections := 0
	var pending := {}
	var fail_load := true
	var on_load := Callable()
	var loads := 0
	func get_backup_save_capability() -> Dictionary:
		return {"enabled": false, "reason": "mounted_load_only"}
	func inspect_backup(locator: String) -> Dictionary:
		inspections += 1
		return {"ok": true, "value": {"locator": locator, "revision": "mounted-slot",
			"state": "occupied", "day": 2, "saved_time": "12:30", "fallback": false,
			"load_day": 2, "load_saved_time": "12:30", "reason": "", "loadable": true,
			"operation_allowed": true}}
	func prepare_backup_action(action: String, locator: String) -> Dictionary:
		var record: Dictionary = inspect_backup(locator)
		if not record.get("ok", false): return record
		var token := "mounted-%s-%s" % [action, locator]
		pending[token] = action
		return {"ok": true, "value": {"token": token, "record": record.value}}
	func commit_backup_action(token: String) -> Dictionary:
		if not pending.has(token): return {"ok": false, "code": &"stale_backup_action"}
		pending.erase(token)
		loads += 1
		if on_load.is_valid(): on_load.call()
		return {"ok": not fail_load, "code": &"mounted_load_failed" if fail_load else &"ok"}
	func cancel_backup_action(token: String) -> void:
		pending.erase(token)

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
var _profile_owner: Node
var _localization_owner: Node
var _original_profile: Node
var _original_profile_index := 0
var _original_localization: Node
var _original_localization_index := 0
var _original_scene: Node
var _old_process_mode: int
var _window_size: Vector2i
var _window_content_size: Vector2i
var _original_contacts: Dictionary = {}
# Coordinator dependencies are Object-typed, so the fixture retains its RefCounted ports.
var _pause_route: PauseRoute
var _pause_gate: PauseGate
var _pause_audio: AudioFixture
var _load_controller: Node
var _load_run: MountedRunOwner
var _load_saves: MountedSaves
var _load_route: RestoreRoute
var _load_gate: RefCounted
var _global_router: Node
var _original_global_pause: Node
var _mounted_restore_stage: Dictionary

func before_each() -> void:
	_original_contacts = GameState.contacts.duplicate(true)
	_old_process_mode = process_mode
	process_mode = Node.PROCESS_MODE_ALWAYS
	_original_scene = get_tree().current_scene
	_window_size = get_tree().root.size
	_window_content_size = get_tree().root.content_scale_size
	_coordinator = null
	_pause_scene = null
	_input_owner = null
	_original_input = null
	_profile_owner = null
	_localization_owner = null
	_original_profile = null
	_original_localization = null
	_load_controller = null
	_load_run = null
	_load_saves = null
	_load_route = null
	_load_gate = null
	_global_router = null
	_original_global_pause = null
	_mounted_restore_stage = {}
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
	if is_instance_valid(_global_router):
		_global_router._production_pause = _original_global_pause
	if is_instance_valid(_load_controller): _load_controller.free()
	if is_instance_valid(_load_route):
		if is_instance_valid(_load_route.target):
			get_tree().current_scene = _original_scene
			_load_route.target.free()
		_load_route.free()
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
	if is_instance_valid(_localization_owner): _localization_owner.free()
	if is_instance_valid(_profile_owner): _profile_owner.free()
	if is_instance_valid(_original_input):
		get_tree().root.add_child(_original_input)
		get_tree().root.move_child(_original_input, _original_input_index)
	if is_instance_valid(_original_profile):
		get_tree().root.add_child(_original_profile)
		get_tree().root.move_child(_original_profile, _original_profile_index)
	if is_instance_valid(_original_localization):
		get_tree().root.add_child(_original_localization)
		get_tree().root.move_child(_original_localization, _original_localization_index)
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
	GameState.contacts = _original_contacts.duplicate(true)

func _sylvia_hospital_context() -> Dictionary:
	var context := {"kind": "hospital", "day": 3,
		"source_entry_ids": ["accepted.3"], "miss_receipt_ids": ["miss.3"]}
	var contacts: Dictionary = GameState.contacts.duplicate(true)
	var witnesses: Dictionary = contacts.get("sylvia_hospital_witness_receipts", {}).duplicate(true)
	witnesses["pause-frontier.3"] = {"kind": "sylvia_hospital_witness",
		"resolution_kind": "condition_hospital", "care_followup_day": 4,
		"source_receipt_id": "accepted.3", "hospital_miss_receipt_id": "miss.3"}
	contacts["sylvia_hospital_witness_receipts"] = witnesses
	GameState.contacts = contacts
	assert_eq(HOSPITAL_SCENE.art_participants(GameState.contacts, context), ["sylvia"],
		"the saved condition-Hospital witness independently proves Sylvia attendance")
	assert_eq(HOSPITAL_SCENE.art_participants(GameState.contacts, context,
		GameState._canonical_committed_schedule()), ["sylvia"],
		"receipt-proven Sylvia attendance admits the physical Hospital timeline")
	return context

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
	var context := _sylvia_hospital_context()
	var command := {"resolution_id": "synthetic-resolution", "resolution_issuer_receipt": {"receipt_id": "synthetic-root"},
		"stage_id": "synthetic-stage", "substage_id": "synthetic-substage", "route_id": "hospital", "timeline_id": TIMELINE_ID,
		"context": context, "completion_transaction_id": "synthetic-completion", "completion_transaction_provenance": {},
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
	assert_false(_bridge.capture_pause_frontier("contact.ordinary.lavinia.day1").ok)
	var before := _reading_state()
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	assert_eq(_owner.capture_pause_source(), source)
	assert_true(_bridge.resume(HANDLE).ok)
	assert_eq(_owner.capture_pause_source(), source, "owner revision/token/frontier are retained exactly")
	assert_eq(_reading_state(), before)
	assert_eq(_receipts, [])

func _start_combined_pause_fixture(isolated_reading_services: bool = false) -> bool:
	# The replacement is the real InputManager script, mounted at the actual source-policy
	# lookup. Its original autoload is restored after this isolated input experiment.
	if isolated_reading_services:
		_original_profile = get_node("/root/ProfileManager")
		_original_profile_index = _original_profile.get_index()
		_original_localization = get_node("/root/LocalizationManager")
		_original_localization_index = _original_localization.get_index()
		get_tree().root.remove_child(_original_localization)
		get_tree().root.remove_child(_original_profile)
		_profile_owner = PROFILE_OWNER.new()
		_profile_owner.name = "ProfileManager"
		get_tree().root.add_child(_profile_owner)
		assert_true(_profile_owner.initialize(MEMORY_STORAGE.new("mounted-reading-load.memory", FAKE_FILES.new())).ok)
		_localization_owner = LOCALIZATION_OWNER.new()
		_localization_owner.name = "LocalizationManager"
		get_tree().root.add_child(_localization_owner)
		assert_true(_localization_owner.initialize(_profile_owner).ok)
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
	var context := _sylvia_hospital_context()
	var command := {"resolution_id": "synthetic-resolution", "resolution_issuer_receipt": {"receipt_id": "synthetic-root"},
		"stage_id": "synthetic-stage", "substage_id": "synthetic-substage", "route_id": "hospital", "timeline_id": TIMELINE_ID,
		"context": context, "completion_transaction_id": "synthetic-pause-completion", "completion_transaction_provenance": {},
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

func _mount_production_reading_load() -> bool:
	if not await _start_combined_pause_fixture(true): return false
	if is_instance_valid(_coordinator):
		_coordinator.free()
		_coordinator = null
	_pause_scene.scene_file_path = "res://scenes/hospital/HospitalScene.tscn"
	_load_gate = MUTATION_GATE.new()
	assert_true(_bridge.configure_mutation_gate(_load_gate).ok)
	assert_true(_input_owner.configure_mutation_gate(_load_gate).ok)
	_load_run = MountedRunOwner.new()
	_load_saves = MountedSaves.new()
	_load_route = RestoreRoute.new()
	add_child(_load_route)
	_load_route._current_scene_id = "hospital"
	_load_controller = PRODUCTION_PAUSE.new()
	add_child(_load_controller)
	var configured: Dictionary = _load_controller.configure({
		"game_state": _load_run, "saves": _load_saves, "bridge": _bridge,
		"input": _input_owner, "audio": _pause_audio, "gate": _load_gate,
		"profile": _profile_owner,
		"localization": _localization_owner,
		"settings_services": {"tts": null, "window": null,
			"profile_reset_admission": func() -> bool: return false},
	}, _load_route)
	assert_true(configured.get("ok", false), str(configured))
	if not configured.get("ok", false): return false
	_global_router = get_node("/root/SceneRouter")
	_original_global_pause = _global_router._production_pause
	_global_router._production_pause = _load_controller
	if _caption.has_method("_sync_transport"): _caption.call("_sync_transport")
	await get_tree().process_frame
	if _caption.has_method("_sync_transport"): _caption.call("_sync_transport")
	return true

func test_witnessed_recovery_refuses_pause_and_backup_before_session_capture() -> void:
	if not await _mount_production_reading_load(): return
	assert_true(_load_controller.capture_pause_source().get("ok", false),
		"the same mounted narrative source admits Pause before recovery")
	var reading := _reading_state()
	var revision: int = _profile_owner.get_profile_revision()
	for fatal: bool in [false, true]:
		# Inject only the logical recovery owner here. The production Skip integration
		# separately creates the same custody through a real failed Profile write.
		_caption.set("_reading_recovery", {"fatal": fatal})
		var captures: int = _load_run.session_captures
		assert_false(_global_router.can_open_witnessed_backup_load(_caption),
			"recovery has priority over direct Backup admission")
		var paused: Dictionary = _load_controller.capture_pause_source()
		assert_false(paused.get("ok", true), "determinate and fatal recovery both refuse Pause")
		assert_eq(_load_run.session_captures, captures,
			"a recovery refusal performs no session capture or suspension work")
		assert_false(_caption.capture_pause_view({"source": "recovery-probe"}).get("ok", true))
		if not paused.get("ok", true):
			var requested: Dictionary = await _load_controller.request_pause()
			assert_eq(requested.get("code"), &"pause_recovery_active")
			assert_false(get_tree().paused)
		assert_eq(_reading_state(), reading)
		assert_eq(_profile_owner.get_profile_revision(), revision)
		_caption.set("_reading_recovery", {})
	assert_true(_load_controller.capture_pause_source().get("ok", false),
		"the still-current source admits Pause after recovery custody is released")

func test_later_same_viewport_recovery_blocks_load_while_subviewport_recovery_does_not() -> void:
	if not await _mount_production_reading_load(): return
	var reading := _reading_state()
	var revision: int = _profile_owner.get_profile_revision()
	var later_caption: Node = CAPTION_SCENE.instantiate()
	get_tree().root.add_child(later_caption)
	await get_tree().process_frame
	later_caption.set_process(false)
	later_caption.set("_reading_recovery", {"fatal": false})
	assert_eq(_load_controller.call("_find_caption", get_tree().root), _caption,
		"the installed normal source precedes the later recovery in the same viewport")
	assert_true(_global_router.can_open_witnessed_backup_load(_caption),
		"cheap projection need not scan unrelated caption nodes")
	var captures: int = _load_run.session_captures
	var opened: Dictionary = await _global_router.open_witnessed_backup_load(_caption)
	assert_false(opened.get("ok", true), "the command boundary finds the later recovery")
	assert_eq(opened.get("code"), &"pause_recovery_active")
	assert_eq(_load_run.session_captures, captures, "refusal precedes live-session capture")
	if opened.get("ok", false):
		if _load_controller.surface.entered_action == &"backup":
			_load_controller.surface.handle_back()
		await _load_controller.request_continue()
	later_caption.set("_reading_recovery", {})
	later_caption.free()

	var foreign_viewport := SubViewport.new()
	foreign_viewport.size = Vector2i(1280, 720)
	_pause_scene.add_child(foreign_viewport)
	var foreign_caption: Node = CAPTION_SCENE.instantiate()
	foreign_viewport.add_child(foreign_caption)
	await get_tree().process_frame
	foreign_caption.set_process(false)
	foreign_caption.set("_reading_recovery", {"fatal": false})
	captures = _load_run.session_captures
	var captured: Dictionary = _load_controller.capture_pause_source()
	assert_true(captured.get("ok", false),
		"recovery in a foreign viewport cannot claim the main viewport's Pause custody")
	assert_eq(_load_run.session_captures, captures + 1)
	assert_eq(_reading_state(), reading)
	assert_eq(_profile_owner.get_profile_revision(), revision)
	foreign_caption.set("_reading_recovery", {})
	foreign_viewport.free()

func _open_mounted_backup_from_rail() -> bool:
	var load_button: Button = _caption.transport_rail.get_node("Load")
	if load_button.disabled: return false
	load_button.grab_focus()
	load_button.emit_signal("activated")
	for frame in 30:
		if _load_controller.surface.entered_action == &"backup": return true
		await get_tree().process_frame
	return false

func _commit_mounted_slot_one() -> Dictionary:
	var prepared: Dictionary = _load_controller._backup_port.prepare_action("load", "slot:1")
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return prepared
	return await _load_controller._backup_port.commit_action(prepared.value.token)

func _stage_mounted_changed_session() -> void:
	var participant := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd").new(_bridge)
	var prepared: Dictionary = participant.prepare({"narrative_checkpoint": {}, "content_version": 1})
	var route_plan: Dictionary = _load_route.prepare_route_restore("main", {})
	if not prepared.get("ok", false) or not route_plan.get("ok", false):
		_mounted_restore_stage = {"ok": false, "code": &"mounted_prepare_failed"}
		return
	var lease: Dictionary = _load_gate.acquire(&"restore")
	if not lease.get("ok", false):
		_mounted_restore_stage = lease
		return
	var applied_route: Dictionary = _load_route.apply_route_restore_silent(route_plan.value)
	var plan: Dictionary = prepared.value.narrative_plan
	if applied_route.get("ok", false): plan["route_ready_token"] = applied_route.value.route_ready_token
	var staged: Dictionary = participant.apply_silent(plan) if applied_route.get("ok", false) else applied_route
	var finalized: Dictionary = participant.finalize() if staged.get("ok", false) else staged
	var route_finalized: Dictionary = _load_route.finalize_restore() if finalized.get("ok", false) else finalized
	var released: Dictionary = _load_gate.release(&"restore", lease.value.token)
	_mounted_restore_stage = {"ok": applied_route.get("ok", false) and staged.get("ok", false) \
		and finalized.get("ok", false) and route_finalized.get("ok", false) and released.get("ok", false),
		"applied_route": applied_route, "staged": staged, "finalized": finalized,
		"route_finalized": route_finalized, "released": released}
	if _mounted_restore_stage.ok: _load_run.handle.generation += 1

func test_mounted_witnessed_load_is_cheap_then_opens_backup_and_continue_restores_exact_frontier() -> void:
	if not await _mount_production_reading_load(): return
	var rail: Control = _caption.transport_rail
	var load_button: Button = rail.get_node("Load")
	assert_true(rail.has_signal("load_requested"), "the mounted rail exposes one semantic Load command")
	assert_true(_global_router.can_open_witnessed_backup_load(_caption),
		"the production owner admits the exact mounted caption")
	assert_true(_caption.accept_input.is_source_admitted(),
		"the live partial caption retains ordinary source input custody")
	assert_true(_caption.call("_load_admitted"),
		"the caption composes its bound Load admission with the production owner")
	assert_false(load_button.disabled, "the exact current witnessed source admits Load")
	if not rail.has_signal("load_requested") or load_button.disabled: return
	_load_run.session_captures = 0
	for query in 100:
		assert_true(_global_router.can_open_witnessed_backup_load(_caption),
			"cheap projection remains truthful on query %d" % query)
	assert_eq(_load_run.session_captures, 0,
		"rail projection never copies the live session or native frontier")
	var bar: VScrollBar = _caption.get_scroll_bar()
	assert_gt(bar.max_value - bar.page, 100.0)
	bar.value = 100.0
	load_button.grab_focus()
	var before := _reading_state()
	var source: Dictionary = _owner.capture_pause_source()
	var source_frontier: Dictionary = _bridge.capture_pause_frontier(TIMELINE_ID)
	load_button.emit_signal("activated")
	for frame in 30:
		if is_instance_valid(_load_controller.surface) \
				and _load_controller.surface.entered_action == &"backup": break
		await get_tree().process_frame
	assert_true(get_tree().paused)
	assert_false(_caption.canvas.is_visible_in_tree())
	assert_eq(_load_controller.surface.entered_action, &"backup")
	var backup: Control = _load_controller.surface._hosts.get(&"backup")
	assert_not_null(backup, "the production Pause owns the real Backup host")
	if backup == null: return
	assert_eq(backup.active_mode, "load")
	assert_true(backup.drawer_buttons["slot:1"].has_focus(), "direct Load starts at Slot 1")
	assert_eq(_reading_state(), before, "opening Backup does not reveal, replay, acknowledge, or advance")
	assert_eq(_owner.capture_pause_source(), source)
	assert_eq(_bridge.capture_pause_frontier(TIMELINE_ID), source_frontier)
	assert_false(_global_router.can_open_witnessed_backup_load(_caption),
		"the retained source cannot open a duplicate Pause")
	assert_true(_load_controller.surface.handle_back(), "Back returns from Backup to Pause")
	assert_eq(_load_controller.surface.entered_action, &"")
	var resumed: Dictionary = await _load_controller.request_continue()
	assert_true(resumed.get("ok", false), str(resumed))
	assert_false(get_tree().paused)
	assert_true(_caption.canvas.is_visible_in_tree())
	assert_eq(bar.value, 100.0)
	assert_eq(_reading_state(), before, "Continue restores the exact partial native reading frontier")
	assert_eq(_owner.capture_pause_source(), source)
	assert_eq(_bridge.capture_pause_frontier(TIMELINE_ID), source_frontier)
	for frame in 3: await get_tree().process_frame
	assert_true(load_button.has_focus(), "Load focus returns after the resume-frame quarantine")
	assert_eq(bar.value, 100.0)

func test_mounted_witnessed_load_focus_repair_does_not_steal_a_new_caption_focus() -> void:
	if not await _mount_production_reading_load(): return
	var load_button: Button = _caption.transport_rail.get_node("Load")
	assert_false(load_button.disabled)
	if load_button.disabled: return
	load_button.grab_focus()
	load_button.emit_signal("activated")
	for frame in 30:
		if _load_controller.surface.entered_action == &"backup": break
		await get_tree().process_frame
	assert_eq(_load_controller.surface.entered_action, &"backup")
	if _load_controller.surface.entered_action != &"backup": return
	assert_true(_load_controller.surface.handle_back())
	var resumed: Dictionary = await _load_controller.request_continue()
	assert_true(resumed.get("ok", false), str(resumed))
	if not resumed.get("ok", false): return
	_caption.caption_text.grab_focus()
	for frame in 3: await get_tree().process_frame
	assert_true(_caption.caption_text.has_focus(),
		"a fresh post-Continue reader focus supersedes deferred Load-focus repair")
	assert_false(load_button.has_focus())

func test_mounted_witnessed_failed_load_keeps_suspension_and_exact_source() -> void:
	if not await _mount_production_reading_load(): return
	var bar: VScrollBar = _caption.get_scroll_bar()
	bar.value = 100.0
	var before := _reading_state()
	var source: Dictionary = _owner.capture_pause_source()
	assert_true(await _open_mounted_backup_from_rail())
	if _load_controller.surface.entered_action != &"backup": return
	var result: Dictionary = await _commit_mounted_slot_one()
	assert_false(result.get("ok", false))
	assert_eq(result.get("code"), &"mounted_load_failed")
	assert_eq(_load_saves.loads, 1)
	assert_true(get_tree().paused)
	assert_eq(_load_controller.coordinator.get_state().value.state, &"Suspended")
	assert_false(_caption.canvas.is_visible_in_tree())
	assert_eq(_reading_state(), before,
		"failed Load neither reveals, replays, acknowledges, nor advances the old prose")
	assert_eq(_owner.capture_pause_source(), source)
	var foreign := Node.new()
	assert_false(_global_router.can_open_witnessed_backup_load(foreign))
	foreign.free()
	assert_false(_global_router.can_open_witnessed_backup_load(_caption),
		"a suspended source refuses duplicate Load")
	assert_eq(_load_saves.loads, 1)
	assert_true(_load_controller.surface.handle_back())
	var resumed: Dictionary = await _load_controller.request_continue()
	assert_true(resumed.get("ok", false), str(resumed))
	assert_eq(_reading_state(), before)
	assert_eq(bar.value, 100.0)

func test_mounted_witnessed_successful_changed_session_never_restores_old_reveal() -> void:
	if not await _mount_production_reading_load(): return
	var before := _reading_state()
	assert_true(await _open_mounted_backup_from_rail())
	if _load_controller.surface.entered_action != &"backup": return
	_load_saves.fail_load = false
	_load_saves.on_load = Callable(self, "_stage_mounted_changed_session")
	var result: Dictionary = await _commit_mounted_slot_one()
	assert_true(_mounted_restore_stage.get("ok", false), str(_mounted_restore_stage))
	assert_true(result.get("ok", false), str(result))
	assert_eq(_load_saves.loads, 1)
	assert_eq(_load_route.publications, 1)
	assert_eq(get_tree().current_scene, _load_route.target)
	assert_false(get_tree().paused)
	assert_false(_bridge.has_active_playback())
	assert_true(_owner._in_flight.is_empty())
	assert_eq(_finished, before.finished)
	# RuntimeAdapter.halt_with_error ends the retired native timeline exactly once;
	# this cancellation signal is distinct from text completion or a physical receipt.
	assert_eq(_ended, before.ended + 1)
	assert_eq(_receipts, before.receipts,
		"retiring the old source fabricates no Hospital completion or acknowledgement")
	assert_false((await _load_controller.request_continue()).get("ok", false),
		"the activated destination cannot resume old Pause custody")
	var duplicate: Dictionary = await _global_router.open_witnessed_backup_load(_caption)
	assert_false(duplicate.get("ok", false))
	assert_eq(_load_route.publications, 1)
	assert_eq(_load_saves.loads, 1)

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


func test_production_pause_view_adapter_covers_actual_caption_layer_node_and_restores_its_anchor() -> void:
	if not await _start_combined_pause_fixture(): return
	var controller: Node = preload("res://scripts/application/lifecycle/ProductionPauseController.gd").new()
	add_child_autofree(controller)
	var source: Dictionary = _owner.capture_pause_source()
	controller._scene = _pause_scene
	controller._captured_source = source.value.duplicate(true)
	var captured: Dictionary = controller.capture_pause_view(source.value)
	assert_true(captured.get("ok", false), str(captured))
	if not captured.get("ok", false): return
	assert_eq(controller._caption, _caption, "Discovery follows the native layer's public canvas; the layer itself is a Node")
	var before := _reading_state()
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	assert_true(controller.cover_pause_view(captured.value))
	assert_false(_pause_scene.visible)
	assert_false(_caption.canvas.is_visible_in_tree())
	await get_tree().create_timer(0.12).timeout
	assert_eq(_reading_state(), before)
	assert_true(controller.restore_pause_view(captured.value))
	assert_true(_pause_scene.visible)
	assert_true(_caption.canvas.is_visible_in_tree())
	assert_true(_bridge.resume(HANDLE).ok)
	assert_eq(_reading_state(), before, "View restoration retains the exact native text, reveal, history and completion boundary")
	assert_eq(_receipts, [])


func test_witnessed_restore_failure_keeps_exact_native_reveal_and_original_pause_handle() -> void:
	if not await _start("Synthetic unchanged reading source during failed Load. ".repeat(24)): return
	_caption.caption_text.active_speed = 10.0
	var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	assert_true(_bridge.configure_mutation_gate(gate).ok)
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	var before := _reading_state()
	var frontier: Dictionary = _bridge.capture_pause_frontier(TIMELINE_ID)
	assert_true(_bridge.begin_pause_restore(HANDLE).ok)
	var participant := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd").new(_bridge)
	var backup: Dictionary = participant.capture()
	var prepared: Dictionary = participant.prepare({"narrative_checkpoint": {}, "content_version": 1})
	assert_true(prepared.ok)
	var plan: Dictionary = prepared.value.narrative_plan
	plan["route_ready_token"] = {"route_id": "main", "layout_id": "main_layout", "generation": 1}
	var lease: Dictionary = gate.acquire(&"restore")
	assert_true(lease.ok)
	var staged: Dictionary = participant.apply_silent(plan)
	assert_true(staged.get("ok", false), str(staged))
	var finalized: Dictionary = participant.finalize()
	assert_true(finalized.get("ok", false), str(finalized))
	await get_tree().create_timer(0.1).timeout
	assert_eq(_reading_state(), before, "even finalization has not replaced or revealed the source")
	assert_true(participant.rollback_silent(backup.value).ok, "a later participant failure only discards the staged target")
	assert_true(gate.release(&"restore", lease.value.token).ok)
	assert_true(_bridge.cancel_pause_restore(HANDLE).ok)
	assert_eq(_bridge.capture_pause_frontier(TIMELINE_ID), frontier)
	assert_eq(_reading_state(), before)
	assert_true(_runtime.paused)
	assert_true(_bridge.resume(HANDLE).ok, "the original handle resumes the original native coroutine")
	assert_eq(_reading_state(), before)
	assert_eq(_receipts, [])


class RestoreSource extends RefCounted:
	var physical: Object
	var session := {"run_id": "native-load-run", "generation": 1, "active": true}
	func capture_pause_source() -> Dictionary:
		var source: Dictionary = physical.capture_pause_source()
		if source.get("ok", false): source.value["session"] = session.duplicate(true)
		return source
	func capture_restore_destination_session() -> Dictionary:
		return {"ok": true, "value": session.duplicate(true)}


class RestoreRoute extends "res://autoload/SceneRouter.gd":
	var target: Control
	var publications := 0
	func _gs() -> Node: return null
	func _change_to(scene_id: String, _startup_publish: bool = false) -> Dictionary:
		publications += 1
		target = Control.new()
		target.name = "RestoredNativeLoadTarget"
		get_tree().root.add_child(target)
		get_tree().current_scene = target
		_current_scene_id = scene_id
		return {"ok": true}


func test_witnessed_load_publishes_only_after_new_session_and_never_completes_old_prose() -> void:
	if not await _start_combined_pause_fixture(): return
	_coordinator.free()
	var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	assert_true(_bridge.configure_mutation_gate(gate).ok)
	var source_owner := RestoreSource.new()
	source_owner.physical = _owner
	var route := RestoreRoute.new()
	add_child(route)
	route._current_scene_id = "hospital"
	var narrative := preload("res://scripts/application/lifecycle/ProductionPauseController.gd").NarrativeSuspension.new()
	narrative.bridge = _bridge
	_coordinator = COORDINATOR.new()
	add_child(_coordinator)
	assert_true(_coordinator.configure(source_owner, narrative, _input_owner, _pause_audio, gate, route).ok)
	assert_true(_coordinator.bind_source(_pause_scene, _caption).ok)
	var paused: Dictionary = await _coordinator.request_pause(&"native_load_fixture")
	assert_true(paused.get("ok", false), str(paused))
	if not paused.get("ok", false):
		route.free()
		return
	var handle: Dictionary = paused.value
	var before := _reading_state()
	assert_true(_coordinator.begin_restore_handoff(handle).ok)
	assert_true(route.is_restore_publication_held())
	assert_true(get_tree().paused)
	assert_eq(_input_owner.get_state().value.state, &"Suspended")
	var participant := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd").new(_bridge)
	var target_plan: Dictionary = participant.prepare({"narrative_checkpoint": {}, "content_version": 1}).value.narrative_plan
	var route_plan: Dictionary = route.prepare_route_restore("main", {}).value
	var lease: Dictionary = gate.acquire(&"restore")
	assert_true(lease.ok)
	var applied_route: Dictionary = route.apply_route_restore_silent(route_plan)
	assert_true(applied_route.ok)
	target_plan["route_ready_token"] = applied_route.value.route_ready_token
	var staged: Dictionary = participant.apply_silent(target_plan)
	assert_true(staged.get("ok", false), str(staged))
	var finalized: Dictionary = participant.finalize()
	assert_true(finalized.get("ok", false), str(finalized))
	assert_true(route.finalize_restore().ok)
	assert_true(gate.release(&"restore", lease.value.token).ok)
	assert_eq(route.publications, 0, "the old source remains in the tree during reversible finalization")
	assert_eq(_reading_state(), before)
	assert_eq((await _coordinator.complete_restore_handoff(handle)).get("code"), &"pause_restore_not_activated")
	assert_eq(_reading_state(), before, "a reported restore without activation cannot discard the source")
	source_owner.session.generation = 2
	watch_signals(route)
	var completed: Dictionary = await _coordinator.complete_restore_handoff(handle)
	assert_true(completed.get("ok", false), str(completed))
	assert_eq(route.publications, 1)
	assert_false(route.is_restore_publication_held())
	assert_signal_emit_count(route, "restore_publication_released", 1)
	assert_eq(get_tree().current_scene, route.target)
	assert_false(get_tree().paused)
	assert_eq(_input_owner.get_state().value.state, &"Active")
	assert_eq(_receipts, [], "cancelling the old caption is never a Hospital completion")
	assert_true(_owner._in_flight.is_empty(), "retirement releases the old physical binding")
	assert_true(_bridge.get_current_narrative_checkpoint().is_empty())
	assert_false(_bridge.has_active_playback())
	assert_false((await _coordinator.request_resume(handle)).ok, "old session custody cannot resume after activation")
	get_tree().current_scene = _pause_scene
	if is_instance_valid(route.target): route.target.free()
	route.free()
