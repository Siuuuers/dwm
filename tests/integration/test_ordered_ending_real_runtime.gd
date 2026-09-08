extends GutTest
## Shipped scene-oriented ending files, real Dialogic runtime, Bridge, ending port and GameState.
## Only disk failure injection and the final navigation destination are recorded fixtures.
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")

class Navigation extends RefCounted:
	var returns := 0
	func goto_menu() -> void: returns += 1

class Checkpoint extends RefCounted:
	var state: Node
	var fail_next := false
	var snapshots: Array[Dictionary] = []
	func write() -> Dictionary:
		if fail_next:
			fail_next = false
			return {"ok": false, "code": &"fixture_disk_failure"}
		snapshots.append(state.capture_restore_state().value.backup.duplicate(true))
		return {"ok": true, "code": &"ok"}

var runtime: DialogicGameHandler
var bridge: Node
var adapter: RefCounted
var _original_runtime: Node
var _original_runtime_index := 0
var _original_layout: Node
var _original_layout_parent: Node
var _original_layout_index := 0
var _settings: Dictionary = {}
var _persistent: Variant
var _had_persistent := false
var _style_directory: Dictionary = {}
var _native_starts := 0
var _native_ends := 0
var _finished: Array[Dictionary] = []
var state: Node
var profile: Node
var _original_profile: Node
var _original_profile_index: int
var playback: RefCounted
var ending_scene: Node
var navigation: Navigation
var checkpoint: Checkpoint

func before_each() -> void:
	_native_starts = 0
	_native_ends = 0
	_finished.clear()
	_had_persistent = Engine.has_meta("dialogic_persistent_style_info")
	_persistent = Engine.get_meta("dialogic_persistent_style_info",{})
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
	for key: String in ["dialogic/save/autosave","dialogic/layout/end_behaviour"]:
		_settings[key] = {"exists":ProjectSettings.has_setting(key),"value":ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave",false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour",0)
	runtime = DialogicGameHandler.new()
	runtime.name = "Dialogic"
	get_tree().root.add_child(runtime)
	runtime.History.simple_history_enabled = true
	runtime.History.save_visited_history_on_save = false
	runtime.History.save_visited_history_on_autosave = false
	runtime.timeline_started.connect(func(): _native_starts += 1)
	runtime.timeline_ended.connect(func(): _native_ends += 1)
	adapter = ADAPTER.new()
	assert_true(adapter.bind_runtime(runtime).get("ok",false))
	bridge = BRIDGE.new()
	add_child(bridge)
	assert_true(bridge.initialize(null,adapter).get("ok",false))
	bridge.timeline_finished.connect(func(id: String, result: Dictionary):
		_finished.append({"timeline_id":id,"result":result.duplicate(true)}))

	_original_profile = get_node("/root/ProfileManager")
	_original_profile_index = _original_profile.get_index()
	get_tree().root.remove_child(_original_profile)
	profile = load("res://autoload/ProfileManager.gd").new()
	profile.name = "ProfileManager"
	get_tree().root.add_child(profile)
	var ops: RefCounted = load("res://tests/support/FakeFileOps.gd").new()
	var storage: RefCounted = load("res://scripts/infrastructure/storage/JsonFileStorage.gd").new("ordered-physical/root", ops)
	assert_true(profile.initialize(storage).ok)
	for form: String in ["ambiguous_sweet", "ambiguous_dark", "love_dark"]:
		assert_true(profile.record_pair_form_witness(form,"fixture:prior-pair:"+form).ok)
	state = load("res://autoload/GameState.gd").new()
	add_child(state)
	state.reset_game()
	state._lifecycle_set_playing_day(7)
	checkpoint = Checkpoint.new()
	checkpoint.state = state
	assert_true(state.configure_ending_checkpoint_writer(checkpoint.write).ok)
	assert_true(state._run_lifecycle.enter_ending(_ordered_plan()).ok)
	playback = load("res://scripts/application/ending/DialogicEndingPlaybackPort.gd").new()
	assert_true(playback.initialize(bridge).ok)
	navigation = Navigation.new()
	ending_scene = load("res://scripts/ui/EndingScene.gd").new()
	assert_true(ending_scene.configure_ending_ports(state, playback).ok)
	assert_true(ending_scene.configure_ending_navigation(navigation).ok)
	add_child(ending_scene)

func after_each() -> void:
	if is_instance_valid(ending_scene): ending_scene.free()
	if is_instance_valid(state): state.free()
	if is_instance_valid(profile): profile.free()
	get_tree().root.add_child(_original_profile)
	get_tree().root.move_child(_original_profile, _original_profile_index)
	if is_instance_valid(bridge): bridge.free()
	for text_node: Node in get_tree().get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	if is_instance_valid(runtime):
		await runtime.clear()
		var remaining: Node = runtime.Styles.get_layout_node()
		if is_instance_valid(remaining): remaining.queue_free()
		await get_tree().process_frame
		runtime.free()
	adapter = null
	get_tree().remove_meta("dialogic_layout_node")
	get_tree().root.add_child(_original_runtime)
	get_tree().root.move_child(_original_runtime,_original_runtime_index)
	if is_instance_valid(_original_layout):
		if is_instance_valid(_original_layout_parent):
			_original_layout_parent.add_child(_original_layout)
			_original_layout_parent.move_child(_original_layout,_original_layout_index)
		get_tree().set_meta("dialogic_layout_node",_original_layout)
	for key: String in _settings:
		ProjectSettings.set_setting(key,_settings[key].value if _settings[key].exists else null)
	if _had_persistent: Engine.set_meta("dialogic_persistent_style_info",_persistent)
	else: Engine.remove_meta("dialogic_persistent_style_info")
	DialogicStylesUtil.style_directory = _style_directory
	_original_layout_parent = null

func _ordered_plan() -> Dictionary:
	return {"ending_id": "ending.sylvia.special", "epilogue_ending_id": "ending.priscilla_lavinia",
		"source_day": 7, "playback_stage": "PRIMARY_PENDING", "playback_receipts": {},
		"next_step_index": 0, "steps": [
			{"ending_id": "ending.sylvia.special", "role": "special_prefix"},
			{"ending_id": "ending.sylvia.dark", "role": "core"},
			{"ending_id": "ending.priscilla_lavinia.sweet", "role": "pair_coda", "pair_form": "love_sweet"},
			{"ending_id": "ending.priscilla_lavinia.observer", "role": "observer_coda", "presentation_variant": "full"}]}


func _wait_for_completion() -> void:
	for attempt in 200:
		if navigation.returns > 0: return
		await get_tree().create_timer(0.01).timeout
	assert_eq(navigation.returns, 1, "all shipped mechanical ending timelines finish naturally")


func test_real_four_step_playback_records_each_discovery_then_saves_completed_run() -> void:
	await _wait_for_completion()
	assert_eq(_native_starts, 4)
	assert_eq(_native_ends, 4)
	assert_eq(state._run_lifecycle.get_state(), &"COMPLETED")
	assert_eq(navigation.returns, 1)
	assert_eq(checkpoint.snapshots.size(), 6, "four physical completions, Gallery and terminal state")
	assert_eq(profile.get_profile_snapshot().gallery_unlocks, ["ending.sylvia.special", "ending.sylvia.dark",
		"ending.priscilla_lavinia.sweet", "ending.priscilla_lavinia.observer"])
	assert_eq(checkpoint.snapshots.back().lifecycle.state, "COMPLETED")
	assert_eq(checkpoint.snapshots[0].lifecycle.ending_plan.next_step_index, 1)
	var first: Dictionary = checkpoint.snapshots[0].lifecycle.ending_plan.playback_receipts["step:0"].value
	var duplicate: Dictionary = state.complete_ending_playback_stage("run-local:ending:0:complete", &"PRIMARY_PENDING", first)
	assert_true(duplicate.ok, str(duplicate))
	assert_eq(checkpoint.snapshots.size(), 6, "durable exact replay does not write or advance again")
	first.timeline_completion_receipt_id = "different-physical-receipt"
	assert_false(state.complete_ending_playback_stage("run-local:ending:0:complete", &"PRIMARY_PENDING", first).ok)


func test_failed_step_save_retries_exact_completion_without_replaying_timeline() -> void:
	checkpoint.fail_next = true
	for attempt in 100:
		if ending_scene._retry_available: break
		await get_tree().create_timer(0.01).timeout
	assert_true(ending_scene._retry_available)
	assert_eq(_native_ends, 1)
	assert_eq(state._run_lifecycle.to_dict().ending_plan.next_step_index, 0,
		"an unsaved cursor rolls back while Profile remains monotonically ahead")
	assert_true(profile.has_gallery_unlock("ending.sylvia.special"))
	assert_false(profile.has_gallery_unlock("ending.sylvia.dark"))
	assert_eq(navigation.returns, 0)
	ending_scene._on_return_pressed()
	await _wait_for_completion()
	assert_eq(_native_starts, 4, "retry persists the retained completion instead of playing the first step twice")
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts.size(), 4)
	assert_eq(checkpoint.snapshots.size(), 6)


func test_cursor_restore_resumes_next_exact_physical_branch() -> void:
	# Prevent the deferred scene start until the first completed step has been saved and restored.
	ending_scene.free()
	ending_scene = null
	var command: Dictionary = state.request_next_ending_command().value
	assert_true(state.complete_ending_playback_stage(str(command.playback_context.transaction_id),
		&"PRIMARY_PENDING", {"outcome": "completed", "timeline_completion_receipt_id": "witnessed-before-restart"}).ok)
	var backup: Dictionary = checkpoint.snapshots.back()
	assert_true(state.rollback_restore_silent(backup).ok)
	assert_eq(state.request_next_ending_command().value.ending_id, "ending.sylvia.dark")
	ending_scene = load("res://scripts/ui/EndingScene.gd").new()
	assert_true(ending_scene.configure_ending_ports(state, playback).ok)
	assert_true(ending_scene.configure_ending_navigation(navigation).ok)
	add_child(ending_scene)
	await _wait_for_completion()
	assert_eq(_native_starts, 3, "restore starts only the three remaining scene files")
	assert_eq(state._run_lifecycle.to_dict().ending_plan.next_step_index, 4)


func test_enter_envelope_preserves_the_complete_already_resolved_ordered_plan() -> void:
	var port: GDScript = load("res://scripts/application/run/GameStateDayResolutionPort.gd")
	var plan := _ordered_plan()
	var snapshot := {"active_resolution_plan": {"stages": [{"stage_id": "resolve_ending_plan",
		"state": "completed", "receipt": {"value": {"ending_plan": plan}}}]}}
	var envelope := {"kind": "enter_ending", "value": {"state": "ENDING",
		"primary_id": plan.ending_id, "epilogue_id": plan.epilogue_ending_id}}
	assert_eq(port._plan_receipt_for_snapshot(envelope, snapshot), {"value": {"ending_plan": plan}})
	envelope.value.primary_id = "ending.alone"
	assert_eq(port._plan_receipt_for_snapshot(envelope, snapshot), {"value": {"ending_plan": {}}})


func test_completed_snapshot_returns_without_replaying_or_rewriting_rewards() -> void:
	await _wait_for_completion()
	var before_profile: Dictionary = profile.get_profile_snapshot()
	var before_plan: Dictionary = state._run_lifecycle.to_dict()
	var writes := checkpoint.snapshots.size()
	ending_scene.free()
	ending_scene = load("res://scripts/ui/EndingScene.gd").new()
	assert_true(ending_scene.configure_ending_ports(state, playback).ok)
	assert_true(ending_scene.configure_ending_navigation(navigation).ok)
	add_child(ending_scene)
	await get_tree().process_frame
	await get_tree().process_frame
	assert_eq(navigation.returns, 2, "fresh scene with a completed snapshot returns directly")
	assert_eq(_native_starts, 4, "no ending is physically replayed")
	assert_eq(checkpoint.snapshots.size(), writes, "no duplicate completion save")
	assert_eq(profile.get_profile_snapshot(), before_profile)
	assert_eq(state._run_lifecycle.to_dict(), before_plan)
	assert_false(state.complete_ending_playback_stage("invented", &"COMPLETED", {}).ok)


func test_exact_canonical_labels_record_then_native_gallery_replay_preserves_run_and_profile() -> void:
	# The fixture's original New Run pair form matches its frozen pair-ending step.
	state.inter_friend_route_state = {"priscilla_lavinia":{"frozen_form":"love_sweet"}}
	assert_true(playback.configure_reached_presentations(profile,state.capture_ending_presentation_signature).ok)
	await _wait_for_completion()
	var records: Dictionary = profile.get_reached_presentations()
	assert_true(records.get("ok",false),str(records))
	if not records.get("ok",false): return
	assert_eq(records.value.records.size(),4,"each physically completed ending label has one exact reached record")
	var selected := ""
	for record: Dictionary in records.value.records:
		if record.signature.entry_id == "ending.sylvia.special.full": selected = str(record.signature_id)
	assert_false(selected.is_empty(),"Special's full semantic label physically played")
	if selected.is_empty(): return
	var replay := preload("res://scripts/application/ending/GalleryReplayOwner.gd").new()
	assert_true(replay.configure(profile,bridge).ok)
	var profile_before: Dictionary = profile.get_profile_snapshot()
	var run_before: Dictionary = state.capture_restore_state().value.backup
	var starts_before := _native_starts
	var ends_before := _native_ends
	var variables_before: Dictionary = runtime.current_state_info.get("variables",{}).duplicate(true)
	var started: Dictionary = replay.begin(selected)
	assert_true(started.get("ok",false),str(started))
	if not started.get("ok",false): return
	for frame in 120:
		if not replay.is_playing(): break
		await get_tree().process_frame
	assert_false(replay.is_playing(),"the shipped no-dialogue label completes naturally")
	assert_eq(_native_starts,starts_before+1)
	assert_eq(_native_ends,ends_before+1)
	assert_eq(profile.get_profile_snapshot(),profile_before)
	assert_eq(state.capture_restore_state().value.backup,run_before)
	assert_eq(runtime.current_state_info.get("variables",{}),variables_before)
	assert_eq(navigation.returns,1,"Gallery never advances the completed ending or returns its run again")
