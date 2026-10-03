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
var _continued_art_entries: Array[String] = []
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
	_continued_art_entries.clear()
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
		_continue_drawn_art_if_ready()
		await get_tree().create_timer(0.01).timeout
	assert_eq(navigation.returns, 1,
		"ending flow completes after player Continue; native starts/ends=%d/%d, continued art=%s, retry=%s"
		% [_native_starts, _native_ends, _continued_art_entries, ending_scene._retry_available])


## Installed return-only artwork waits for the player before its original DTL starts.
## Use the real drawn, enabled button; never manufacture a native completion or draw receipt.
func _continue_drawn_art_if_ready() -> void:
	var view: Node = bridge.get_art_hold_view()
	if view == null or not view.has_drawn_art() or view.next_button.disabled: return
	_continued_art_entries.append(str(view._entry_id))
	view.next_button.pressed.emit()
	assert_ne(bridge.get_art_hold_view(), view, "real Continue retires this displayed art card")


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
	assert_eq(_continued_art_entries, ["ending.sylvia.special.full", "ending.sylvia.dark",
		"ending.priscilla_lavinia.sweet", "ending.priscilla_lavinia.observer.full"] as Array[String],
		"the player continues each exact canonical artwork before its native ending")
	assert_eq(_native_starts, 4)
	assert_eq(_native_ends, 4)
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
		_continue_drawn_art_if_ready()
		await get_tree().process_frame
	assert_false(replay.is_playing(),"the shipped no-dialogue label completes naturally")
	assert_eq(_native_starts,starts_before+1)
	assert_eq(_native_ends,ends_before+1)
	assert_eq(_continued_art_entries.size(), 5, "Gallery replay needs its own fresh Continue")
	assert_eq(_continued_art_entries.back(), "ending.sylvia.special.full")
	assert_eq(profile.get_profile_snapshot(),profile_before)
	assert_eq(state.capture_restore_state().value.backup,run_before)
	assert_eq(runtime.current_state_info.get("variables",{}),variables_before)
	assert_eq(navigation.returns,1,"Gallery never advances the completed ending or returns its run again")


## Boundary-order tests isolate physical startup; the existing tests above and
## rendered ending journey own native playback, pixels and durable Run admission.
class ReadingBoundaryBridge extends BRIDGE:
	var starts: Array[Dictionary] = []
	var fail_start := false
	func start_ending_presentation(ending_id: String, context: Dictionary, signature: Dictionary, presentation: Dictionary = {}) -> Dictionary:
		return _start_ending_reading(ending_id, context, signature, presentation)
	func validate_reading_checkpoint(_checkpoint: Dictionary, _frames: Dictionary = {}) -> Dictionary:
		return {"ok": true}
	func _begin_entry_playback(entry_id: String, context: Dictionary, execution_mode: StringName,
			token_kind: String, _expected_version: int = -1) -> Dictionary:
		var admitted: Dictionary = _reading_session.admit(entry_id, context)
		if not admitted.ok: return admitted
		if fail_start:
			fail_start = false
			return {"ok": false, "code": &"fixture_native_start_failed"}
		starts.append({"entry_id": entry_id, "kind": token_kind,
			"frontier": _reading_resume_frontier.duplicate(true)})
		_active_entry = {"entry_id": entry_id, "token": "native-%d" % starts.size(),
			"frozen_context": context.duplicate(true), "execution_mode": execution_mode}
		return {"ok": true, "receipt": {"playback_token": _active_entry.token}}

func _ending_boundary_fixture() -> Dictionary:
	var frozen := preload("res://scripts/narrative/EndingFrozenContext.gd")
	var inputs := {"dark_mode": false, "pair_form": "love_sweet", "special_variant": "full"}
	for friend: String in frozen.FRIENDS:
		inputs[friend] = {"tier": "love", "tone": "sweet", "attitude": "affectionate", "echo_ids": [], "miss_reasons": []}
	var seed: Dictionary = frozen.make_seed(inputs,
		{"priscilla": [], "lavinia": [], "sylvia": [], "priscilla_lavinia": []}, [], "empty_done").value
	var plan := _ordered_plan()
	plan.steps = plan.steps.slice(0, 2)
	var session := preload("res://scripts/narrative/SoloReadingSession.gd").new()
	assert_true(session.configure(preload("res://tests/support/EndingReadingFixture.gd").catalogue()).ok)
	assert_true(session.begin("fixture:ending", "ending.sylvia.special.full").ok)
	var frames: Array[Dictionary] = []
	var signatures: Array[Dictionary] = []
	var frontier := {}
	for index: int in range(2):
		var id := "fixture:ending:%d" % index
		var built: Dictionary = frozen.build(plan, index, seed, id).value
		var frame := {"playback_id": id, "transaction_id": id + ":complete",
			"expected_stage": "PRIMARY_PENDING", "role": str(plan.steps[index].role), "presentation": built.presentation}
		frames.append(frame)
		signatures.append(built.signature)
		var entry_id: String = built.signature.entry_id
		assert_true(session.admit(entry_id, frame).ok)
		var allocated: Dictionary = session.ledger.allocate_publication("fixture:ending", entry_id)
		var line_id: String = session.catalogue[entry_id].lines[0].line_id
		assert_true(session.ledger.publish_line("fixture:ending", allocated.value, entry_id, line_id).ok)
		frontier = {"line_id": line_id, "publication_id": allocated.value}
		if index == 0:
			session.completed(entry_id)
			plan.playback_receipts["step:0"] = {"value": {"outcome": "completed", "timeline_completion_receipt_id": id + ":complete"}}
	var saved: Dictionary = session.capture(frontier).value
	return {"first_frame": frames[0], "signature": signatures[1], "frame": frames[1], "checkpoint": {
		"content_version": 1, "entry_id": "ending.sylvia.dark", "frozen_context": frames[1],
		"stage": "PRIMARY_PENDING", "transaction_id": frames[1].transaction_id,
		"manifest_fingerprint": "fixture-admission-is-tested-separately", "reading_session": saved}}

func test_ending_reading_restore_adopts_same_caption_in_both_route_orders() -> void:
	ending_scene.free()
	ending_scene = null
	var fixture := _ending_boundary_fixture()
	for route_first: bool in [true, false]:
		var subject := ReadingBoundaryBridge.new()
		assert_true(subject.configure_reading_catalogue(preload("res://tests/support/EndingReadingFixture.gd").catalogue()).ok)
		assert_true(subject.stage_reading_restore(fixture.checkpoint).ok)
		var command: Dictionary = fixture.frame.duplicate(true)
		command.erase("presentation")
		var joined := {}
		if route_first:
			joined = subject._start_ending_reading("ending.sylvia.dark", command, fixture.signature, fixture.frame.presentation)
			assert_true(joined.ok, str(joined))
			assert_eq(subject.starts.size(), 0, "route publication cannot start before finalize")
		assert_true(subject._resume_reading_checkpoint(fixture.checkpoint, &"canonical").ok)
		if not route_first:
			joined = subject._start_ending_reading("ending.sylvia.dark", command, fixture.signature, fixture.frame.presentation)
			assert_true(joined.ok, str(joined))
		assert_eq(subject.starts.size(), 1)
		assert_eq(subject.starts[0].frontier, fixture.checkpoint.reading_session.frontier)
		assert_eq(subject._reading_session.ledger.snapshot(), fixture.checkpoint.reading_session.ledger)
		assert_false(subject._reading_restore_adoption)
		var completions: Array[Dictionary] = []
		subject.ending_playback_finished.connect(func(token: String, id: String, receipt: Dictionary):
			completions.append({"token": token, "id": id, "receipt": receipt}))
		subject._on_runtime_timeline_ended()
		subject._on_runtime_timeline_ended()
		assert_eq(completions.size(), 1)
		assert_eq(completions[0].token, joined.receipt.playback_token)
		assert_eq(completions[0].receipt.receipt_id, "fixture:ending:1:complete")
		assert_eq(subject._reading_session.boundary, "between_entries")
		subject.free()

func test_ending_reading_abort_retires_port_without_completion() -> void:
	ending_scene.free()
	ending_scene = null
	var fixture := _ending_boundary_fixture()
	var subject := ReadingBoundaryBridge.new()
	assert_true(subject.configure_reading_catalogue(preload("res://tests/support/EndingReadingFixture.gd").catalogue()).ok)
	assert_true(subject._resume_reading_checkpoint(fixture.checkpoint, &"canonical").ok)
	var retired: Array[String] = []
	var completed: Array[String] = []
	subject.ending_playback_retired.connect(func(token: String, _id: String): retired.append(token))
	subject.ending_playback_finished.connect(func(token: String, _id: String, _receipt: Dictionary): completed.append(token))
	var expected: String = subject._ending_reading.token
	assert_true(subject.abort_current_entry(&"fixture_retirement").ok)
	subject._on_runtime_timeline_ended()
	assert_eq(retired, [expected])
	assert_eq(completed, [])
	assert_true(subject._ending_reading.is_empty())
	subject.free()


func test_ending_boundary_restore_rollback_retires_started_successor() -> void:
	ending_scene.free()
	ending_scene = null
	var fixture := _ending_boundary_fixture()
	var saved: Dictionary = fixture.checkpoint.duplicate(true)
	saved.entry_id = "ending.sylvia.special.full"
	saved.frozen_context = fixture.first_frame
	saved.transaction_id = fixture.first_frame.transaction_id
	saved.reading_session.boundary = "between_entries"
	saved.reading_session.frontier = {}
	saved.reading_session.ledger.entry_contexts.erase("ending.sylvia.dark")
	saved.reading_session.ledger.captions.resize(1)
	var subject := ReadingBoundaryBridge.new()
	assert_true(subject.configure_reading_catalogue(preload("res://tests/support/EndingReadingFixture.gd").catalogue()).ok)
	var backup: Dictionary = subject.capture_restore_state().value.backup
	assert_true(subject.stage_reading_restore(saved).ok)
	var command: Dictionary = fixture.frame.duplicate(true)
	command.erase("presentation")
	assert_true(subject._start_ending_reading("ending.sylvia.dark", command, fixture.signature, fixture.frame.presentation).ok)
	assert_eq(subject.starts.size(), 0)
	assert_true(subject._resume_reading_checkpoint(saved, &"canonical").ok)
	assert_eq(subject.starts.size(), 1)
	assert_eq(subject._reading_restore_token, subject._active_entry.token)
	var retired: Array[String] = []
	subject.ending_playback_retired.connect(func(token: String, _id: String): retired.append(token))
	assert_true(subject.rollback_restore_silent(backup).ok)
	assert_eq(retired.size(), 1)
	assert_true(subject._active_entry.is_empty(), "failed finalize retires the started successor")
	assert_false(subject.has_reading_session())
	subject.free()

func test_ending_start_refusal_retry_preserves_preceding_history() -> void:
	ending_scene.free()
	ending_scene = null
	var fixture := _ending_boundary_fixture()
	var saved: Dictionary = fixture.checkpoint.reading_session.duplicate(true)
	saved.boundary = "between_entries"
	saved.frontier = {}
	saved.ledger.entry_contexts.erase("ending.sylvia.dark")
	saved.ledger.captions.resize(1)
	var subject := ReadingBoundaryBridge.new()
	assert_true(subject.configure_reading_catalogue(preload("res://tests/support/EndingReadingFixture.gd").catalogue()).ok)
	var session := preload("res://scripts/narrative/SoloReadingSession.gd").new()
	assert_true(session.configure(preload("res://tests/support/EndingReadingFixture.gd").catalogue()).ok)
	assert_true(session.restore(saved, "ending.sylvia.special.full").ok)
	subject._reading_session = session
	var command: Dictionary = fixture.frame.duplicate(true)
	command.erase("presentation")
	subject.fail_start = true
	var refused: Dictionary = subject._start_ending_reading("ending.sylvia.dark", command, fixture.signature, fixture.frame.presentation)
	assert_false(refused.ok)
	assert_eq(subject._reading_session.ledger.snapshot().captions, saved.ledger.captions)
	assert_true(subject._ending_reading.is_empty())
	var retried: Dictionary = subject._start_ending_reading("ending.sylvia.dark", command, fixture.signature, fixture.frame.presentation)
	assert_true(retried.ok, str(retried))
	assert_eq(subject.starts.size(), 1, "refused native startup does not create a physical occurrence")
	assert_eq(subject._reading_session.ledger.snapshot().captions, saved.ledger.captions)
	subject.free()


class RefusingReachedProfile extends RefCounted:
	var writes := 0
	func record_reached_presentation(_signature: Dictionary) -> Dictionary:
		writes += 1
		return {"ok": writes > 1, "code": &"fixture_profile_write_failed"}

func test_reached_write_failure_retries_completed_ending_without_native_replay() -> void:
	ending_scene.free()
	ending_scene = null
	var fixture := _ending_boundary_fixture()
	var subject := ReadingBoundaryBridge.new()
	assert_true(subject.configure_reading_catalogue(preload("res://tests/support/EndingReadingFixture.gd").catalogue()).ok)
	assert_true(subject._resume_reading_checkpoint(fixture.checkpoint, &"canonical").ok)
	var recorder := RefusingReachedProfile.new()
	var port := preload("res://scripts/application/ending/DialogicEndingPlaybackPort.gd").new()
	assert_true(port.initialize(subject).ok)
	assert_true(port.configure_reached_presentations(recorder,
		func(_id: String, _context: Dictionary) -> Dictionary: return {"ok": true, "value": fixture.signature},
		func(_id: String, _context: Dictionary) -> Dictionary:
			return {"ok": true, "value": {"signature": fixture.signature, "presentation": fixture.frame.presentation}}).ok)
	var failures: Array[Dictionary] = []
	var completions: Array[Dictionary] = []
	port.playback_failed.connect(func(failure: Dictionary): failures.append(failure))
	port.playback_completed.connect(func(completion: Dictionary): completions.append(completion))
	var command: Dictionary = fixture.frame.duplicate(true)
	command.erase("presentation")
	assert_true(port.start_ending_id("ending.sylvia.dark", command).ok)
	subject._on_runtime_timeline_ended()
	assert_eq(failures.size(), 1)
	assert_eq(completions.size(), 0)
	assert_eq(subject._reading_session.boundary, "between_entries")
	var history: Dictionary = subject._reading_session.ledger.snapshot()
	assert_true(port.start_ending_id("ending.sylvia.dark", command).ok)
	await get_tree().process_frame
	assert_eq(recorder.writes, 2)
	assert_eq(completions.size(), 1)
	assert_eq(completions[0].timeline_completion_receipt_id, "fixture:ending:1:complete")
	assert_eq(subject.starts.size(), 1, "retry only persists the completed physical occurrence")
	assert_eq(subject._reading_session.ledger.snapshot(), history)
	subject.free()


func test_retired_textbox_listener_cannot_block_successor_caption_animation() -> void:
	# Native end removes its layout before queue_free; the retained signal
	# subscriber must not start an animation which can no longer process.
	ending_scene.free()
	ending_scene = null
	var animation := preload("res://addons/dialogic/Modules/DefaultLayoutParts/Layer_VN_Textbox/animations.gd").new()
	animation.animation_in = animation.AnimationsIn.POP_IN
	animation.animation_out = animation.AnimationsOut.POP_OUT
	animation.animation_new_text = animation.AnimationsNewText.WIGGLE
	add_child(animation)
	remove_child(animation)
	animation.queue_free()
	assert_false(animation.is_inside_tree())
	runtime.Animations.stop_animation()
	runtime.Text.animation_textbox_show.emit()
	assert_false(runtime.Animations.is_animating(), "removed show listener cannot strand the new caption")
	runtime.Text.animation_textbox_hide.emit()
	assert_false(runtime.Animations.is_animating())
	runtime.Text.animation_textbox_new_text.emit()
	assert_false(runtime.Animations.is_animating())
	await get_tree().process_frame
