extends GutTest
## Real installed Dialogic, with the application's runtime and layout restored after each test.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const PHYSICAL_OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const ENTRY := "contact.ordinary.lavinia.day1"

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
var _original_contacts: Dictionary = {}

func before_each() -> void:
	_native_starts = 0
	_native_ends = 0
	_finished.clear()
	_original_contacts = GameState.contacts.duplicate(true)
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

func after_each() -> void:
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
	GameState.contacts = _original_contacts.duplicate(true)
	_original_layout_parent = null

func test_runtime_failure_cancels_pending_hospital_without_a_natural_completion() -> void:
	var owner: RefCounted = PHYSICAL_OWNER.new()
	assert_true(owner.configure(bridge).get("ok",false))
	var completed: Array = []
	var failed: Array = []
	owner.physical_completion_ready.connect(func(receipt): completed.append(receipt))
	owner.physical_completion_failed.connect(func(failure): failed.append(failure))
	assert_true(owner.begin_physical(_sylvia_hospital_command()).get("ok",false))
	assert_eq(_native_starts,0)
	runtime.signal_event.emit({"unregistered":"failure injection"})
	for frame in 6: await get_tree().process_frame
	assert_eq(_native_starts,0,"canceled pending work never starts")
	assert_true(completed.is_empty(),"the halt must not issue a natural completion receipt")
	assert_true(_finished.is_empty())
	assert_eq(failed.size(),1,"the owning physical command receives one failure")
	assert_false(bridge.has_active_playback())
	assert_true(owner.begin_physical(_sylvia_hospital_command()).get("ok",false),"same command may retry after failure")
	await _wait_for_natural_end()
	assert_eq(completed.size(),1)
	assert_eq(failed.size(),1)

func _context() -> Dictionary:
	return {"expected_stage":"current_entry","playback_id":"live-admission-fixture",
		"role":"primary","transaction_id":"tx-live-admission-fixture"}

func _hospital_command() -> Dictionary:
	return {"resolution_id":"resolution.day3","resolution_issuer_receipt":{"receipt_id":"root.day3"},
		"stage_id":"stage.hospital","substage_id":"intent.hospital","route_id":"hospital",
		"timeline_id":"hospital.faint","context":{"kind":"hospital","day":3,"source_entry_ids":[],"miss_receipt_ids":[]},
		"completion_transaction_id":"completion.hospital.day3","completion_transaction_provenance":{"child_id":"completion.hospital.day3"},
		"command_sha256":"c".repeat(64)}

func _sylvia_hospital_command() -> Dictionary:
	# The owner requires the same-day saved witness and frozen source IDs. A normal
	# faint with the empty context above intentionally takes the notice-only path.
	var command: Dictionary = _hospital_command()
	command.context.source_entry_ids = ["accepted.3"]
	command.context.miss_receipt_ids = ["miss.3"]
	var contacts: Dictionary = GameState.contacts.duplicate(true)
	var witnesses: Dictionary = contacts.get("sylvia_hospital_witness_receipts", {}).duplicate(true)
	witnesses["hospital-live-admission.3"] = {"kind":"sylvia_hospital_witness",
		"resolution_kind":"condition_hospital","care_followup_day":4,
		"source_receipt_id":"accepted.3","hospital_miss_receipt_id":"miss.3"}
	contacts["sylvia_hospital_witness_receipts"] = witnesses
	GameState.contacts = contacts
	assert_eq(HospitalScene.art_participants(GameState.contacts, command.context), ["sylvia"])
	return command

func _continue_art_hold_if_present() -> bool:
	var art_view: Node = bridge.get_art_hold_view()
	if art_view == null: return true
	var deadline := get_tree().create_timer(3.0)
	while is_instance_valid(art_view) and (not art_view.has_drawn_art() or art_view.next_button.disabled) \
			and deadline.time_left > 0.0:
		await get_tree().process_frame
	var ready: bool = is_instance_valid(art_view) and art_view.has_drawn_art() \
		and not art_view.next_button.disabled
	assert_true(ready, "installed art must draw and enable its real Continue")
	if not ready: return false
	art_view.next_button.pressed.emit()
	assert_null(bridge.get_art_hold_view(), "real Continue retires the art hold")
	return true

func test_normal_faint_uses_notice_acknowledgment_without_native_playback_or_gameplay_effects() -> void:
	var owner: RefCounted = PHYSICAL_OWNER.new()
	assert_true(owner.configure(bridge).get("ok",false))
	var receipts: Array[Dictionary] = []
	owner.physical_completion_ready.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	var before := {"day":GameState._run_lifecycle.get_day(),"health":GameState.get_stat("health"),
		"pressure":GameState.get_stat("pressure"),"contacts":GameState.contacts.duplicate(true)}
	var command: Dictionary = _hospital_command()
	var begun: Dictionary = owner.begin_physical(command)
	assert_true(begun.get("ok",false),str(begun))
	if not begun.get("ok",false): return
	assert_eq(_native_starts,0,"normal fainting shows a notice without starting a DTL")
	assert_false(bridge.has_active_playback())
	assert_true(receipts.is_empty(),"a notice needs its own Continue acknowledgment")
	command["physical_token"] = begun.value.physical_token
	var forged: Dictionary = command.duplicate(true)
	forged["physical_token"] = str(command.physical_token) + ".foreign"
	assert_false(owner.complete_notice(forged).get("ok",false))
	assert_true(owner.complete_notice(command).get("ok",false))
	assert_eq(receipts.size(),1)
	if receipts.size() == 1:
		assert_eq(receipts[0].result,{"notice_acknowledged":true})
		assert_eq(receipts[0].physical_token,begun.value.physical_token)
	assert_eq(_native_starts,0)
	assert_true(_finished.is_empty())
	assert_eq({"day":GameState._run_lifecycle.get_day(),"health":GameState.get_stat("health"),
		"pressure":GameState.get_stat("pressure"),"contacts":GameState.contacts.duplicate(true)},before,
		"the presentation owner neither applies recovery nor advances the day")

func _snapshot() -> Dictionary:
	return {"timeline":runtime.current_timeline,"event":runtime.current_event_idx,
		"layout":runtime.Styles.get_layout_node(),"starts":_native_starts,"ends":_native_ends,
		"history":runtime.History.simple_history_content.duplicate(true),
		"timeline_id":bridge.get_current_timeline_id(),"context":bridge.get_current_timeline_context()}

func _wait_for_natural_end(previous_ends: int = 0) -> void:
	for attempt in 100:
		if _native_ends > previous_ends: return
		await get_tree().create_timer(0.02).timeout
	assert_gt(_native_ends,previous_ends,"the shipped return-only presentation naturally ends")

func _find_queued_native_start(layout: Node, path: String, label_or_index: Variant) -> Callable:
	for connection: Dictionary in layout.ready.get_connections():
		var callback: Callable = connection.callable
		if callback.get_object() != runtime or callback.get_method() != &"start_timeline":
			continue
		var arguments: Array = callback.get_bound_arguments()
		if arguments.size() != 3 or str(arguments[0]) != path or arguments[1] != label_or_index:
			continue
		assert_false(str(arguments[2]).is_empty(),"the adapter qualifies its queued native start with a request id")
		return callback
	return Callable()

func _assert_all_starts_refused() -> void:
	var before := _snapshot()
	var ordinary: Dictionary = bridge.start_timeline_id("hospital.faint")
	assert_false(ordinary.get("ok",true),"another ordinary Hospital cannot replace standing playback")
	assert_eq(_snapshot(),before,"ordinary refusal performs no runtime or cache mutation")
	var semantic: Dictionary = bridge.start_entry(ENTRY,_context())
	assert_false(semantic.get("ok",true),"a valid semantic entry cannot replace standing playback")
	assert_eq(_snapshot(),before,"semantic refusal performs no runtime or cache mutation")
	var ending: Dictionary = bridge.start_ending_id("ending.alone",_context())
	assert_false(ending.get("ok",true),"a valid ending cannot replace standing playback")
	assert_eq(_snapshot(),before,"ending refusal performs no runtime or cache mutation")

func test_real_hospital_deferred_start_reserves_admission_until_one_physical_completion() -> void:
	var owner: RefCounted = PHYSICAL_OWNER.new()
	assert_true(owner.configure(bridge).get("ok",false))
	var receipts: Array[Dictionary] = []
	owner.physical_completion_ready.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	var command := _sylvia_hospital_command()
	var begun: Dictionary = owner.begin_physical(command)
	assert_true(begun.get("ok",false),str(begun))
	assert_eq(_native_starts,0,"the real layout is still awaiting deferred mount")
	assert_null(runtime.current_timeline)
	assert_true(bridge.has_active_playback(),"admitted Hospital startup already occupies playback")
	_assert_all_starts_refused()
	await _wait_for_natural_end()
	assert_false(bridge.has_active_playback(),"natural completion retires live admission")
	assert_eq(_native_starts,1)
	assert_eq(_finished.size(),1)
	assert_eq(receipts.size(),1,"the real physical owner emits exactly one completion")
	if receipts.size() == 1:
		assert_eq(receipts[0].physical_token,begun.value.physical_token)
		assert_eq(receipts[0].completion_transaction_id,command.completion_transaction_id)
	assert_eq(bridge.get_current_timeline_id(),"")
	runtime.timeline_ended.emit()
	assert_eq(_finished.size(),1,"a duplicate native end cannot complete the old presentation again")
	assert_eq(receipts.size(),1)

func test_real_semantic_deferred_start_refuses_other_playback_vocabularies() -> void:
	var completion: RefCounted = preload("res://tests/support/FakeDialogicPlaybackCompletionPort.gd").new()
	assert_true(bridge.configure_playback_completion_port(completion).get("ok",false))
	assert_true(bridge.start_entry(ENTRY,_context()).get("ok",false))
	assert_true(bridge.has_active_playback())
	_assert_all_starts_refused()
	if not await _continue_art_hold_if_present(): return
	await _wait_for_natural_end()
	assert_false(bridge.has_active_playback())
	assert_eq(completion.intents.size(),1)
	assert_true(_finished.is_empty(),"semantic completion never becomes ordinary Hospital completion")

func test_real_ending_deferred_start_refuses_other_playback_vocabularies() -> void:
	var receipts: Array[Dictionary] = []
	bridge.ending_playback_finished.connect(func(_token: String, _id: String, receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	assert_true(bridge.start_ending_id("ending.alone",_context()).get("ok",false))
	assert_true(bridge.has_active_playback())
	_assert_all_starts_refused()
	await _wait_for_natural_end()
	assert_false(bridge.has_active_playback())
	assert_eq(receipts.size(),1)
	assert_true(_finished.is_empty())

func test_metadata_only_restore_cache_never_claims_live_activity_or_completion() -> void:
	for position: String in ["external_route","timeline_complete"]:
		var checkpoint := {"timeline_id":"hospital.faint","position":position}
		var restored: Dictionary = bridge.apply_restore_silent({"route_ready_token":{"fixture":true},
			"narrative_checkpoint":checkpoint,"position":position})
		assert_true(restored.get("ok",false),str(restored))
		assert_eq(bridge.get_current_timeline_id(),"hospital.faint","restore retains its checkpoint cache")
		assert_eq(bridge.get_current_timeline_context(),checkpoint)
		assert_false(bridge.has_active_playback(),"dormant checkpoint identity is not live activity")
		assert_null(runtime.current_timeline)
		assert_eq(_native_starts,0)
		var before := _snapshot()
		runtime.timeline_ended.emit()
		runtime.timeline_ended.emit()
		assert_true(_finished.is_empty(),"end packets without standing playback mint no completion")
		var after := _snapshot()
		before.ends = after.ends
		assert_eq(after,before,"unowned end signals cannot consume dormant restored identity")

func test_abort_pending_semantic_start_cancels_native_ready_work_before_fresh_hospital() -> void:
	var completion: RefCounted = preload("res://tests/support/FakeDialogicPlaybackCompletionPort.gd").new()
	assert_true(bridge.configure_playback_completion_port(completion).get("ok",false))
	var text_publications: Array[Dictionary] = []
	runtime.Text.text_started.connect(func(info: Dictionary): text_publications.append(info.duplicate(true)))
	var started: Dictionary = bridge.start_entry(ENTRY,_context())
	assert_true(started.get("ok",false),str(started))
	assert_eq(_native_starts,0,"the real semantic start is waiting on the native layout ready edge")
	assert_null(runtime.current_timeline)
	assert_true(bridge.has_active_playback())
	var aborted: Dictionary = bridge.abort_current_entry(&"fixture_pending_abort")
	assert_true(aborted.get("ok",false),str(aborted))
	for frame in 6: await get_tree().process_frame
	assert_eq(_native_starts,0,"aborted deferred ready callbacks never start the semantic timeline")
	assert_eq(_native_ends,0,"canceling unstarted work does not invent a native natural end")
	assert_true(text_publications.is_empty())
	assert_true(completion.intents.is_empty(),"pending abort cannot emit semantic completion")
	assert_true(_finished.is_empty())
	assert_null(runtime.current_timeline)
	assert_false(bridge.has_active_playback(),"canceled pending admission is released")
	var hospital: Dictionary = bridge.start_timeline_id("hospital.faint")
	assert_true(hospital.get("ok",false),str(hospital))
	assert_true(bridge.has_active_playback())
	await _wait_for_natural_end()
	assert_eq(_native_starts,1,"only the fresh Hospital actually started")
	assert_eq(_native_ends,1)
	assert_eq(_finished.size(),1)
	assert_true(completion.intents.is_empty())
	assert_false(bridge.has_active_playback())

func test_real_natural_cleanup_keeps_admission_until_native_end_signal() -> void:
	var cleanup_observed: Array[bool] = []
	# The shipped return event begins end_timeline(), which clears current_timeline
	# before publishing IDLE and awaiting timeline.clean(). Observe that exact edge.
	runtime.state_changed.connect(func(state: int):
		if state == DialogicGameHandler.States.IDLE and _native_starts > 0 and runtime.current_timeline == null and _native_ends == 0 and cleanup_observed.is_empty():
			cleanup_observed.append(true)
			assert_true(bridge.has_active_playback(),"native cleanup still owns admission after its timeline pointer clears")
			_assert_all_starts_refused())
	assert_true(bridge.start_timeline_id("hospital.faint").get("ok",false))
	await _wait_for_natural_end()
	assert_eq(cleanup_observed.size(),1,"the assertion ran inside real native asynchronous cleanup")
	assert_eq(_native_starts,1)
	assert_eq(_native_ends,1)
	assert_eq(_finished.size(),1)
	assert_false(bridge.has_active_playback(),"the actual end signal finally releases admission")

func test_pending_before_event_restore_rollback_cancels_unstarted_native_work() -> void:
	await _assert_before_event_restore_rollback(false)

func test_live_paused_before_event_restore_rollback_drains_without_executing_old_event() -> void:
	await _assert_before_event_restore_rollback(true)

func test_pending_before_event_restore_rollback_restores_prior_paused_true() -> void:
	await _assert_before_event_restore_rollback(false,true)

func test_live_before_event_restore_rollback_restores_prior_paused_true() -> void:
	await _assert_before_event_restore_rollback(true,true)

func _assert_before_event_restore_rollback(wait_until_live: bool, prior_paused := false) -> void:
	var previous_checkpoint := {"timeline_id":"hospital.faint","position":"external_route"}
	assert_true(bridge.apply_restore_silent({"route_ready_token":{"fixture":true},
		"narrative_checkpoint":previous_checkpoint,"position":"external_route"}).get("ok",false))
	runtime.paused = prior_paused
	var captured: Dictionary = bridge.capture_restore_state()
	assert_true(captured.get("ok",false))
	var text_publications: Array[Dictionary] = []
	var handled_events: Array[Variant] = []
	runtime.Text.text_started.connect(func(info: Dictionary): text_publications.append(info.duplicate(true)))
	runtime.event_handled.connect(func(event: Variant): handled_events.append(event))
	var restore_checkpoint := {"timeline_id":"contact.ordinary.lavinia.day1","position":"before_event"}
	var staged: Dictionary = bridge.apply_restore_silent({"route_ready_token":{"fixture":true},
		"narrative_checkpoint":restore_checkpoint,"position":"before_event",
		"timeline_path":"res://dialogic/timelines/en/contacts/lavinia_day1.dtl","resume_event_index":0})
	assert_true(staged.get("ok",false),str(staged))
	assert_true(bridge.has_active_playback())
	assert_true(runtime.paused)
	assert_eq(_native_starts,0,"restore initially owns a deferred layout start")
	if wait_until_live:
		for frame in 20:
			if _native_starts > 0: break
			await get_tree().process_frame
		assert_eq(_native_starts,1,"real timeline started but its before-event continuation remains paused")
		assert_not_null(runtime.current_timeline)
		assert_eq(runtime.current_event_idx,-1)
		assert_true(handled_events.is_empty(),"no native event executes before the suspended frontier")
	var rolled_back: Dictionary = bridge.rollback_restore_silent(captured.value)
	assert_true(rolled_back.get("ok",false),str(rolled_back))
	assert_eq(bridge.get_current_timeline_id(),previous_checkpoint.timeline_id)
	assert_eq(bridge.get_current_timeline_context(),previous_checkpoint)
	# The rollback can unpause native state; an old handle_event coroutine must not
	# resume into its canceled timeline while end_timeline drains timeline.clean().
	for frame in 8: await get_tree().process_frame
	assert_null(runtime.current_timeline)
	assert_eq(runtime.paused,prior_paused,"rollback restores the exact pause state captured before staging")
	assert_false(bridge.has_active_playback(),"restore-owned admission retires after pending cancellation or real physical drain")
	assert_eq(_native_starts,1 if wait_until_live else 0)
	assert_true(text_publications.is_empty(),"rollback publishes no replacement or old caption")
	assert_true(handled_events.is_empty(),"canceled before-event coroutine never executes its return event")
	assert_true(_finished.is_empty(),"restore rollback cannot mint ordinary completion")
	assert_eq(bridge.get_current_timeline_id(),previous_checkpoint.timeline_id)
	assert_eq(bridge.get_current_timeline_context(),previous_checkpoint)
	var previous_ends := _native_ends
	# Also release a deliberately restored paused state. Any old before-event
	# coroutine resumed here must already have been invalidated by rollback.
	runtime.paused = false
	var fresh: Dictionary = bridge.start_timeline_id("hospital.faint")
	assert_true(fresh.get("ok",false),str(fresh))
	await _wait_for_natural_end(previous_ends)
	assert_eq(_finished.size(),1,"only fresh Hospital reaches ordinary natural completion")
	assert_eq(_native_starts,2 if wait_until_live else 1)
	assert_false(bridge.has_active_playback())


func test_invalid_runtime_event_halts_live_paused_restore_before_restoring_unpaused_backup() -> void:
	var previous_checkpoint := {"timeline_id":"hospital.faint","position":"external_route"}
	assert_true(bridge.apply_restore_silent({"route_ready_token":{"fixture":true},
		"narrative_checkpoint":previous_checkpoint,"position":"external_route"}).get("ok",false))
	runtime.paused = false
	var ordinary_failures: Array[Dictionary] = []
	var validation_failures: Array[Dictionary] = []
	var resumed_timelines: Array[Variant] = []
	var text_publications: Array[Dictionary] = []
	var handled_events: Array[Variant] = []
	bridge.ordinary_playback_failed.connect(func(_id: String, failure: Dictionary): ordinary_failures.append(failure.duplicate(true)))
	bridge.narrative_validation_failed.connect(func(failure: Dictionary): validation_failures.append(failure.duplicate(true)))
	runtime.dialogic_resumed.connect(func(): resumed_timelines.append(runtime.current_timeline))
	runtime.Text.text_started.connect(func(info: Dictionary): text_publications.append(info.duplicate(true)))
	runtime.event_handled.connect(func(event: Variant): handled_events.append(event))
	var staged: Dictionary = bridge.apply_restore_silent({"route_ready_token":{"fixture":true},
		"narrative_checkpoint":{"timeline_id":"contact.ordinary.lavinia.day1","position":"before_event"},
		"position":"before_event","timeline_path":"res://dialogic/timelines/en/contacts/lavinia_day1.dtl",
		"resume_event_index":0})
	assert_true(staged.get("ok",false),str(staged))
	for frame in 20:
		if _native_starts == 1: break
		await get_tree().process_frame
	assert_eq(_native_starts,1)
	assert_true(runtime.paused)
	assert_not_null(runtime.current_timeline)
	assert_eq(runtime.current_event_idx,-1)
	assert_true(handled_events.is_empty())
	runtime.signal_event.emit({"unregistered":"live paused restore failure injection"})
	await _wait_for_natural_end()
	assert_eq(ordinary_failures.size(),1)
	assert_eq(validation_failures.size(),1)
	if not ordinary_failures.is_empty(): assert_eq(ordinary_failures[0].code,&"invalid_runtime_event")
	if not validation_failures.is_empty(): assert_eq(validation_failures[0].code,&"invalid_runtime_event")
	assert_eq(resumed_timelines.size(),1,"the captured unpaused state is restored exactly once")
	if not resumed_timelines.is_empty(): assert_null(resumed_timelines[0],"halt clears the failed timeline before restoring pause")
	assert_false(runtime.paused,"failure restores the exact unpaused backup")
	assert_null(runtime.current_timeline)
	assert_true(text_publications.is_empty(),"unpausing after halt cannot publish old text")
	assert_true(handled_events.is_empty(),"unpausing after halt cannot execute the canceled event")
	assert_eq(_native_starts,1)
	assert_eq(_native_ends,1)
	assert_true(_finished.is_empty(),"the canceled restore never becomes ordinary completion")
	assert_eq(bridge.get_current_timeline_id(),previous_checkpoint.timeline_id)
	assert_eq(bridge.get_current_timeline_context(),previous_checkpoint)
	assert_false(bridge.has_active_playback())

func test_deferred_hospital_start_failure_releases_physical_owner_for_same_command_retry() -> void:
	var previous_checkpoint := {"timeline_id":"contact.ordinary.lavinia.day1","position":"external_route"}
	assert_true(bridge.apply_restore_silent({"route_ready_token":{"fixture":true},
		"narrative_checkpoint":previous_checkpoint,"position":"external_route"}).get("ok",false))
	var owner: RefCounted = PHYSICAL_OWNER.new()
	assert_true(owner.configure(bridge).get("ok",false))
	var failures: Array[Dictionary] = []
	var receipts: Array[Dictionary] = []
	owner.physical_completion_failed.connect(func(failure: Dictionary): failures.append(failure.duplicate(true)))
	owner.physical_completion_ready.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	var command := _sylvia_hospital_command()
	var begun: Dictionary = owner.begin_physical(command)
	assert_true(begun.get("ok",false),str(begun))
	assert_eq(_native_starts,0)
	assert_true(bridge.has_active_playback())
	var pending_layout: Node = runtime.Styles.get_layout_node()
	assert_not_null(pending_layout)
	if pending_layout == null: return
	assert_false(pending_layout.is_node_ready())
	var located: Dictionary = DialogicTimelineCatalog.get_path_for_id("hospital.faint")
	assert_true(located.get("ok",false))
	var native_start := _find_queued_native_start(pending_layout,str(located.value.path),"")
	assert_true(native_start.is_valid(),"the fixture targets only the actual queued native start")
	if not native_start.is_valid(): return
	# Controlled failure injection: retain actual layout mounting and adapter ready
	# verification, but prevent only the native timeline-start callback from running.
	pending_layout.ready.disconnect(native_start)
	for frame in 20:
		if not failures.is_empty(): break
		await get_tree().process_frame
	assert_eq(failures.size(),1,"deferred startup failure reaches its configured physical owner exactly once")
	assert_true(receipts.is_empty())
	assert_true(_finished.is_empty())
	assert_eq(_native_starts,0)
	assert_eq(_native_ends,0)
	assert_false(bridge.has_active_playback())
	assert_eq(bridge.get_current_timeline_id(),previous_checkpoint.timeline_id)
	assert_eq(bridge.get_current_timeline_context(),previous_checkpoint,"failed startup restores the prior metadata-only checkpoint")
	for frame in 4: await get_tree().process_frame
	assert_false(is_instance_valid(pending_layout),"the failed real layout is freed after its deferred mount settles")
	assert_null(runtime.Styles.get_layout_node())
	var retried: Dictionary = owner.begin_physical(command)
	assert_true(retried.get("ok",false),str(retried))
	assert_eq(retried.value.physical_token,begun.value.physical_token,"retry retains the command-derived identity")
	assert_true(bridge.has_active_playback(),"retry starts new physical work rather than replaying a stranded in-flight token")
	await _wait_for_natural_end()
	assert_eq(_native_starts,1)
	assert_eq(_native_ends,1)
	assert_eq(receipts.size(),1)
	assert_eq(failures.size(),1)
	assert_eq(_finished.size(),1)
	assert_false(bridge.has_active_playback())


func test_fresh_adapter_bound_during_real_cleanup_remains_busy_until_qualified_end() -> void:
	var fresh_adapters: Array[RefCounted] = []
	var forwarded_ends: Array[bool] = []
	var located: Dictionary = DialogicTimelineCatalog.get_path_for_id("hospital.faint")
	assert_true(located.get("ok",false))
	runtime.state_changed.connect(func(state: int):
		if state != DialogicGameHandler.States.IDLE or not runtime.is_ending_timeline() or not fresh_adapters.is_empty(): return
		assert_null(runtime.current_timeline,"the fresh adapter binds after native state clears")
		assert_eq(_native_ends,0,"the native cleanup has not published its completion")
		var fresh: RefCounted = ADAPTER.new()
		fresh_adapters.append(fresh)
		assert_true(fresh.bind_runtime(runtime).get("ok",false))
		fresh.timeline_ended_signal.connect(func(): forwarded_ends.append(true))
		assert_true(fresh.has_active_playback(),"binding during cleanup must recover native stopping activity")
		var before := _snapshot()
		assert_false(fresh.start_timeline(str(located.value.path),"").get("ok",true))
		assert_eq(_snapshot(),before,"fresh-adapter refusal cannot mutate the draining runtime"))
	assert_true(bridge.start_timeline_id("hospital.faint").get("ok",false))
	await _wait_for_natural_end()
	assert_eq(fresh_adapters.size(),1,"the real native cleanup edge was observed")
	assert_eq(forwarded_ends.size(),1)
	if not fresh_adapters.is_empty():
		assert_false(fresh_adapters[0].has_active_playback(),"the matching qualified end releases the fresh adapter")
	assert_eq(_finished.size(),1)


func test_late_older_qualified_end_cannot_consume_new_pending_or_live_hospital() -> void:
	var completed_generations: Array[int] = []
	runtime.timeline_ended_with_generation.connect(func(generation: int): completed_generations.append(generation))
	assert_true(bridge.start_timeline_id("hospital.faint").get("ok",false))
	await _wait_for_natural_end()
	assert_eq(completed_generations.size(),1)
	if completed_generations.is_empty(): return
	var old_generation: int = completed_generations[0]
	assert_eq(_finished.size(),1)
	runtime.paused = true
	assert_true(bridge.start_timeline_id("hospital.faint").get("ok",false))
	assert_eq(_native_starts,1,"the next Hospital is still waiting for its real layout mount")
	assert_null(runtime.current_timeline)
	var pending := _snapshot()
	# Replay the identity captured from a real completed native session, not an
	# invented generation or a direct invocation of the adapter's private handler.
	runtime.timeline_ended_with_generation.emit(old_generation)
	assert_eq(_snapshot(),pending)
	assert_true(adapter.has_active_playback())
	assert_true(bridge.has_active_playback())
	assert_eq(_finished.size(),1,"an older end cannot complete newly admitted startup")
	for frame in 20:
		if _native_starts == 2: break
		await get_tree().process_frame
	assert_eq(_native_starts,2)
	assert_not_null(runtime.current_timeline)
	assert_ne(runtime.get_timeline_generation(),old_generation)
	var live := _snapshot()
	runtime.timeline_ended_with_generation.emit(old_generation)
	assert_eq(_snapshot(),live)
	assert_true(adapter.has_active_playback())
	assert_true(bridge.has_active_playback())
	assert_eq(_finished.size(),1,"an older end cannot complete the newer live session")
	runtime.paused = false
	await _wait_for_natural_end(1)
	assert_eq(_native_ends,2)
	assert_eq(_finished.size(),2,"only the newer session's actual end completes its owner")
	assert_false(bridge.has_active_playback())


func test_direct_native_replacement_never_completes_the_old_physical_hospital() -> void:
	var owner: RefCounted = PHYSICAL_OWNER.new()
	assert_true(owner.configure(bridge).get("ok",false))
	var receipts: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	owner.physical_completion_ready.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	owner.physical_completion_failed.connect(func(failure: Dictionary): failures.append(failure.duplicate(true)))
	runtime.paused = true
	assert_true(owner.begin_physical(_sylvia_hospital_command()).get("ok",false))
	for frame in 20:
		if _native_starts == 1: break
		await get_tree().process_frame
	assert_eq(_native_starts,1)
	assert_not_null(runtime.current_timeline)
	var owned_generation := runtime.get_timeline_generation()
	var located: Dictionary = DialogicTimelineCatalog.get_path_for_id("hospital.faint")
	assert_true(located.get("ok",false))
	# Same path is intentionally insufficient identity: this actual native API
	# replaces the paused owner session with a distinct native generation.
	runtime.start_timeline(str(located.value.path),"")
	assert_eq(_native_starts,2)
	assert_ne(runtime.get_timeline_generation(),owned_generation)
	assert_eq(failures.size(),1,"replacement fails the old physical command exactly once")
	assert_true(receipts.is_empty())
	assert_true(_finished.is_empty())
	assert_true(bridge.has_active_playback(),"foreign native replacement still occupies admission")
	_assert_all_starts_refused()
	runtime.paused = false
	await _wait_for_natural_end()
	assert_eq(_native_ends,1)
	assert_true(receipts.is_empty(),"foreign natural end cannot mint the old physical receipt")
	assert_true(_finished.is_empty(),"foreign natural end cannot complete the old Bridge identity")
	assert_eq(failures.size(),1)
	assert_false(bridge.has_active_playback())


func test_reentrant_same_path_native_start_during_preference_reapply_fails_the_old_owner() -> void:
	var owner: RefCounted = PHYSICAL_OWNER.new()
	assert_true(owner.configure(bridge).get("ok",false))
	var receipts: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	owner.physical_completion_ready.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	owner.physical_completion_failed.connect(func(failure: Dictionary): failures.append(failure.duplicate(true)))
	var located: Dictionary = DialogicTimelineCatalog.get_path_for_id("hospital.faint")
	assert_true(located.get("ok",false))
	if not located.get("ok",false): return
	runtime.paused = true
	adapter.preference_reapply_requested.connect(func():
		runtime.start_timeline(str(located.value.path),""),CONNECT_ONE_SHOT)
	var begun: Dictionary = owner.begin_physical(_sylvia_hospital_command())
	assert_false(begun.get("ok",true),"the admitted start reports its synchronous native replacement")
	assert_eq(_native_starts,1,"only the reentrant foreign native generation starts")
	assert_eq(failures.size(),1,"the replaced physical owner receives one failure")
	assert_true(receipts.is_empty())
	assert_true(_finished.is_empty())
	assert_true(bridge.has_active_playback(),"the foreign native generation still occupies admission")
	_assert_all_starts_refused()
	runtime.paused = false
	await _wait_for_natural_end()
	assert_eq(_native_starts,1,"the canceled admitted start never runs after reentrant replacement")
	assert_eq(_native_ends,1)
	assert_eq(failures.size(),1)
	assert_true(receipts.is_empty(),"the foreign natural end cannot complete the replaced physical owner")
	assert_true(_finished.is_empty())
	assert_false(bridge.has_active_playback())


func test_pending_same_path_native_start_cancels_the_queued_admitted_start() -> void:
	var owner: RefCounted = PHYSICAL_OWNER.new()
	assert_true(owner.configure(bridge).get("ok",false))
	var receipts: Array[Dictionary] = []
	var failures: Array[Dictionary] = []
	owner.physical_completion_ready.connect(func(receipt: Dictionary): receipts.append(receipt.duplicate(true)))
	owner.physical_completion_failed.connect(func(failure: Dictionary): failures.append(failure.duplicate(true)))
	runtime.paused = true
	var begun: Dictionary = owner.begin_physical(_sylvia_hospital_command())
	assert_true(begun.get("ok",false),str(begun))
	assert_eq(_native_starts,0)
	var pending_layout: Node = runtime.Styles.get_layout_node()
	assert_not_null(pending_layout)
	if pending_layout == null: return
	assert_false(pending_layout.is_node_ready())
	var located: Dictionary = DialogicTimelineCatalog.get_path_for_id("hospital.faint")
	assert_true(located.get("ok",false))
	if not located.get("ok",false): return
	var native_start := _find_queued_native_start(pending_layout,str(located.value.path),"")
	assert_true(native_start.is_valid())
	if not native_start.is_valid(): return
	runtime.start_timeline(str(located.value.path),"")
	assert_eq(_native_starts,1,"the same-path direct call creates a foreign native generation")
	assert_false(pending_layout.ready.is_connected(native_start),"replacement disconnects the admitted queued start")
	assert_eq(failures.size(),1,"the pending physical owner receives one replacement failure")
	assert_true(receipts.is_empty())
	assert_true(_finished.is_empty())
	for frame in 8: await get_tree().process_frame
	assert_eq(_native_starts,1,"layout readiness cannot revive the disconnected admitted start")
	assert_true(bridge.has_active_playback(),"the foreign native generation remains admission-active")
	_assert_all_starts_refused()
	runtime.paused = false
	await _wait_for_natural_end()
	assert_eq(_native_starts,1)
	assert_eq(_native_ends,1)
	assert_eq(failures.size(),1)
	assert_true(receipts.is_empty(),"the foreign natural end cannot complete the replaced physical owner")
	assert_true(_finished.is_empty())
	assert_false(bridge.has_active_playback())


func test_failed_deferred_before_event_restore_preserves_cache_pause_and_cancels_queued_resume() -> void:
	var previous_checkpoint := {"timeline_id":"hospital.faint","position":"timeline_complete"}
	assert_true(bridge.apply_restore_silent({"route_ready_token":{"fixture":true},
		"narrative_checkpoint":previous_checkpoint,"position":"timeline_complete"}).get("ok",false))
	var failures: Array[Dictionary] = []
	var text_publications: Array[Dictionary] = []
	bridge.ordinary_playback_failed.connect(func(_id: String, failure: Dictionary): failures.append(failure.duplicate(true)))
	runtime.Text.text_started.connect(func(info: Dictionary): text_publications.append(info.duplicate(true)))
	var finalizations: Array[Dictionary] = []
	for prior_paused: bool in [false,true]:
		runtime.paused = prior_paused
		var previous_failure_count := failures.size()
		var path := "res://dialogic/timelines/en/contacts/lavinia_day1.dtl"
		var staged: Dictionary = bridge.apply_restore_silent({"route_ready_token":{"fixture":true},
			"narrative_checkpoint":{"timeline_id":"contact.ordinary.lavinia.day1","position":"before_event"},
			"position":"before_event","timeline_path":path,"resume_event_index":0})
		assert_true(staged.get("ok",false),str(staged))
		assert_true(runtime.paused,"the successor is staged before its first event")
		assert_true(bridge.has_active_playback())
		var pending_layout: Node = runtime.Styles.get_layout_node()
		assert_not_null(pending_layout)
		if pending_layout == null: return
		assert_false(pending_layout.is_node_ready())
		var native_start := _find_queued_native_start(pending_layout,path,0)
		assert_true(native_start.is_valid())
		if not native_start.is_valid(): return
		pending_layout.ready.disconnect(native_start)
		# Native ready queues adapter verification first. Finalize then queues resume;
		# the ensuing deferred failure must invalidate that already-queued resume.
		pending_layout.ready.connect(func(): finalizations.append(bridge.finalize_restore()),CONNECT_ONE_SHOT)
		for frame in 8: await get_tree().process_frame
		assert_eq(failures.size(),previous_failure_count + 1)
		assert_eq(finalizations.size(),previous_failure_count + 1,"finalize actually ran on the real ready edge")
		if finalizations.is_empty(): return
		assert_true(finalizations.back().get("ok",false))
		assert_eq(runtime.paused,prior_paused,"failure restores the exact prior pause state despite queued resume")
		assert_eq(bridge.get_current_timeline_id(),previous_checkpoint.timeline_id)
		assert_eq(bridge.get_current_timeline_context(),previous_checkpoint)
		assert_false(is_instance_valid(pending_layout))
		assert_null(runtime.Styles.get_layout_node())
		assert_null(runtime.current_timeline)
		assert_false(bridge.has_active_playback())
		assert_eq(_native_starts,0)
		assert_eq(_native_ends,0)
		assert_true(text_publications.is_empty())
		assert_true(_finished.is_empty(),"failed restoration cannot become ordinary completion")
		assert_true(bridge.finalize_restore().get("ok",false))
		for frame in 2: await get_tree().process_frame
		assert_eq(runtime.paused,prior_paused,"finalizing again cannot revive the canceled resume")
		assert_eq(bridge.get_current_timeline_context(),previous_checkpoint)
		assert_false(bridge.has_active_playback())


func test_deferred_semantic_start_failure_reports_exact_token_preserves_cache_and_allows_retry() -> void:
	var previous_checkpoint := {"timeline_id":"hospital.faint","position":"external_route"}
	assert_true(bridge.apply_restore_silent({"route_ready_token":{"fixture":true},
		"narrative_checkpoint":previous_checkpoint,"position":"external_route"}).get("ok",false))
	var completion: RefCounted = preload("res://tests/support/FakeDialogicPlaybackCompletionPort.gd").new()
	assert_true(bridge.configure_playback_completion_port(completion).get("ok",false))
	var failures: Array[Dictionary] = []
	bridge.entry_playback_failed.connect(func(token: String, entry_id: String, result: Dictionary):
		failures.append({"token":token,"entry_id":entry_id,"result":result.duplicate(true)}))
	var started: Dictionary = bridge.start_entry(ENTRY,_context())
	assert_true(started.get("ok",false),str(started))
	if not started.get("ok",false): return
	var receipt: Dictionary = started.receipt
	assert_false(str(receipt.playback_token).is_empty())
	assert_eq(_native_starts,0)
	if not await _continue_art_hold_if_present(): return
	var pending_layout: Node = runtime.Styles.get_layout_node()
	assert_not_null(pending_layout)
	if pending_layout == null: return
	assert_false(pending_layout.is_node_ready())
	var native_start := _find_queued_native_start(pending_layout,str(receipt.path),str(receipt.label))
	assert_true(native_start.is_valid(),"cancel only the admitted real native semantic start")
	if not native_start.is_valid(): return
	pending_layout.ready.disconnect(native_start)
	for frame in 8: await get_tree().process_frame
	assert_eq(failures.size(),1)
	if not failures.is_empty():
		assert_eq(failures[0].token,receipt.playback_token)
		assert_eq(failures[0].entry_id,ENTRY)
		assert_eq(failures[0].result.code,&"runtime_start_failed")
	assert_eq(_native_starts,0)
	assert_eq(_native_ends,0)
	assert_true(completion.intents.is_empty(),"failed startup sends no natural completion intent")
	assert_true(_finished.is_empty())
	assert_eq(bridge.get_current_timeline_id(),previous_checkpoint.timeline_id)
	assert_eq(bridge.get_current_timeline_context(),previous_checkpoint)
	assert_false(is_instance_valid(pending_layout))
	assert_null(runtime.Styles.get_layout_node())
	assert_false(bridge.has_active_playback())
	var retried: Dictionary = bridge.start_entry(ENTRY,_context())
	assert_true(retried.get("ok",false),str(retried))
	if not retried.get("ok",false): return
	assert_ne(retried.receipt.playback_token,receipt.playback_token,"retry receives a new live token")
	if not await _continue_art_hold_if_present(): return
	await _wait_for_natural_end()
	assert_eq(_native_starts,1)
	assert_eq(_native_ends,1)
	assert_eq(failures.size(),1)
	assert_eq(completion.intents.size(),1,"only the real retry completes through the configured port")
	if not completion.intents.is_empty():
		assert_eq(completion.intents[0].playback_token,retried.receipt.playback_token)
		assert_eq(completion.intents[0].entry_id,ENTRY)
		assert_eq(completion.intents[0].completion_kind,&"natural_end")
	assert_true(_finished.is_empty())
	assert_false(bridge.has_active_playback())
