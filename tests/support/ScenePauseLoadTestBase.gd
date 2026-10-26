extends "res://addons/gut/test.gd"
## One case per fresh Godot process: registration and issuer authority are immutable.
## Connected Text Pause -> selected schema-5 Load. No fake positive native,
## restore, route, suspension, Profile or Run acknowledgement is supplied.
const FIXTURE := preload("res://tests/support/ScenePauseLoadFixture.gd")
const WITNESSED_CAPTION := preload("res://scripts/ui/witnessed/WitnessedCaptionLayer.gd")
var fixture: RefCounted
var fixture_ready := false
var prior_root := ""
var sequence := 0
var _watchdog: Timer
var _watch_finished := false
var _test_stage := "before_setup"
var _watch_started := 0

func _on_test_timeout() -> void:
	if _watch_finished: return
	var state := {"stage": _test_stage, "elapsed_ms": Time.get_ticks_msec() - _watch_started,
		"tree_paused": get_tree().paused}
	if fixture != null: state["owners"] = fixture.diagnostic_state()
	print("DWM_PAUSE_TEST_TIMEOUT " + JSON.stringify(state))
	get_tree().quit(1)

func before_each() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	_watch_finished = false
	_watch_started = Time.get_ticks_msec()
	_test_stage = "setup"
	_watchdog = Timer.new()
	_watchdog.process_mode = Node.PROCESS_MODE_ALWAYS
	_watchdog.one_shot = true
	_watchdog.wait_time = 30.0
	add_child(_watchdog)
	_watchdog.timeout.connect(_on_test_timeout)
	_watchdog.start()
	prior_root = OS.get_environment("DWM_TEST_ROOT")
	sequence += 1
	if prior_root.is_empty():
		assert_false(prior_root.is_empty(), "cloud wrapper must isolate test storage")
		return
	OS.set_environment("DWM_TEST_ROOT", prior_root.path_join("scene_pause_%d" % sequence))
	fixture = FIXTURE.new()
	var checked: Dictionary = await fixture.setup_pause(get_tree())
	fixture_ready = checked.get("ok", false)
	assert_true(fixture_ready, str(checked))
	if fixture_ready:
		assert_false(fixture.runtime.Styles.has_active_layout_node(), "initial activation starts without a preinstalled layout")
		assert_eq(fixture.default_style_projection(), fixture.default_style_before)

func after_each() -> void:
	_test_stage = "cleanup"
	if fixture_ready: assert_eq(fixture.default_style_projection(), fixture.default_style_before,
		"scene activation must not change the global default style")
	if fixture != null: await fixture.close_restart()
	fixture = null
	fixture_ready = false
	OS.set_environment("DWM_TEST_ROOT", prior_root)
	_watch_finished = true
	if is_instance_valid(_watchdog):
		_watchdog.stop()
		_watchdog.queue_free()

func _ok(result: Dictionary) -> bool:
	assert_true(result.get("ok", false), str(result))
	return result.get("ok", false)

func _witnessed_caption(phase: String) -> bool:
	var caption: Node = fixture.pause._find_caption(get_tree().root)
	assert_true(is_instance_valid(caption), phase + " publishes the genuine witnessed caption")
	if not is_instance_valid(caption): return false
	assert_eq(caption.get_script(), WITNESSED_CAPTION)
	assert_eq(caption.get_viewport(), get_tree().root)
	assert_eq(fixture.default_style_projection(), fixture.default_style_before)
	return caption.get_script() == WITNESSED_CAPTION and caption.get_viewport() == get_tree().root

func happy_load(quick: bool) -> void:
	_test_stage = "start_text"
	if not fixture_ready or not _ok(await fixture.start_text()): return
	if not _witnessed_caption("source"): return
	if quick and not _ok(fixture.manager.quick_save_latest()): return
	var source: Dictionary = fixture.game.capture_run_snapshot_input().duplicate(true)
	var profile_before: Dictionary = fixture.profile_bytes()
	var selected: Dictionary = fixture.manager.get_latest_stable_checkpoint()
	if not _ok(selected): return
	var checkpoint: Dictionary = selected.value.bundle.snapshot.narrative_checkpoint.duplicate(true)
	assert_eq(checkpoint.reading_session.schema_version, 7)
	assert_false(checkpoint.reading_session.has("ledger"))
	assert_eq(checkpoint.reading_session.boundary, "line")
	_test_stage = "pause_source"
	if not _ok(await fixture.pause.request_pause()): return
	assert_true(get_tree().paused)
	assert_eq(fixture.pause.coordinator.get_state().value.state, &"Suspended")
	assert_eq(fixture.input_owner.get_state().value.state, &"Suspended")
	assert_eq(fixture.audio_owner.get_state().value.state, &"Suspended")
	var old_handle: Dictionary = fixture.pause._handle.duplicate(true)
	var prepared: Dictionary = fixture.pause._backup_port.prepare_quick_action("load") if quick \
		else fixture.pause._backup_port.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var token: String = prepared.value.token
	fixture.ready_count = 0
	var routes: int = fixture.route_confirmations.size()
	var narratives: int = fixture.narrative_confirmations.size()
	fixture.call_deferred("observe_pending_load")
	_test_stage = "commit_quick_load" if quick else "commit_slot_load"
	var committed: Dictionary = await fixture.pause._backup_port.commit_action(token)
	if not _ok(committed): return
	_test_stage = "settle_load"
	if not _ok(await fixture.settle_load()): return
	if not _witnessed_caption("destination"): return
	assert_eq(fixture.ready_count, 1, "one real destination readiness publication")
	assert_eq(fixture.route_confirmations.size(), routes + 1)
	assert_eq(fixture.narrative_confirmations.size(), narratives + 1)
	assert_eq(fixture.pause_closed_count, 1)
	assert_false(fixture.pending_observation.is_empty(), "real asynchronous activation retains operation identity")
	if not fixture.pending_observation.is_empty():
		assert_true(fixture.pending_observation.tree_paused)
		assert_eq(fixture.pending_observation.input_state, &"Suspended")
		assert_eq(fixture.pending_observation.ready_count, 0)
		assert_eq(fixture.pending_observation.closed_count, 0)
		assert_false(fixture.pending_observation.foreign_retry.get("ok", false))
	assert_false(get_tree().paused)
	assert_eq(fixture.pause.coordinator.get_state().value.state, &"Active")
	assert_eq(fixture.input_owner.get_state().value.state, &"Active")
	assert_eq(fixture.audio_owner.get_state().value.state, &"Active")
	assert_eq(fixture.bridge.get_state().value.state, &"Active")
	assert_false(fixture.router.is_restore_publication_held())
	assert_false(fixture.pause._loading)
	assert_false(fixture.pause.surface.visible)
	var destination: Dictionary = fixture.game.capture_run_snapshot_input()
	assert_eq(destination.lifecycle, source.lifecycle, "Load preserves selected lifecycle")
	assert_eq(fixture.bridge._reading_session.boundary, "line")
	var restored_checkpoint: Dictionary = fixture.bridge.capture_reading_checkpoint(false)
	if not _ok(restored_checkpoint): return
	assert_eq(restored_checkpoint.value.reading_session.entry_id, checkpoint.reading_session.entry_id)
	var projected: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").project_player_checkpoint(restored_checkpoint.value)
	if not _ok(projected): return
	assert_eq(projected.value, checkpoint, "Load restores the exact selected player position")
	assert_eq(fixture.profile_bytes(), profile_before, "Load and publication never repeat Profile consequences")
	assert_eq(fixture.native_markers, [], "no source challenge marker is replayed")
	assert_eq(fixture.challenge_record(), {})
	assert_true(destination.command_receipts.is_empty(), "selected Load starts a fresh command session")
	assert_eq(destination.gameplay, source.gameplay, "selected Load preserves consequences without replay")
	assert_eq(destination.scene, source.scene, "selected Load preserves current story controls")
	var after: Dictionary = destination.duplicate(true)
	_test_stage = "duplicate_consent"
	var duplicate: Dictionary = await fixture.pause._backup_port.commit_action(token)
	assert_false(duplicate.get("ok", false), "consumed consent cannot Load twice")
	for frame: int in 8: await get_tree().process_frame
	assert_eq(fixture.ready_count, 1)
	assert_eq(fixture.pause_closed_count, 1)
	assert_eq(fixture.game.capture_run_snapshot_input(), after)
	assert_eq(fixture.profile_bytes(), profile_before)
	if not quick: return
	# A completed old handle must never retire a newly suspended real native source,
	# including when the caller legitimately owns a later restore lease.
	_test_stage = "pause_destination"
	if not _ok(await fixture.pause.request_pause()): return
	var newer_handle: Dictionary = fixture.pause._handle.duplicate(true)
	assert_ne(newer_handle, old_handle)
	var frontier: Dictionary = fixture.bridge.capture_pause_frontier()
	if not _ok(frontier): return
	var lease: Dictionary = fixture.gate.acquire(&"restore")
	if not _ok(lease): return
	_test_stage = "refuse_old_handle"
	var stale: Dictionary = await fixture.bridge.complete_pause_restore(old_handle)
	fixture.gate.release(&"restore", lease.value.token)
	assert_false(stale.get("ok", false), "old completion cannot consume a new native pause")
	assert_eq(fixture.pause._handle, newer_handle)
	assert_eq(fixture.bridge.capture_pause_frontier(), frontier)
	assert_eq(fixture.pause.coordinator.get_state().value.state, &"Suspended")
	assert_true(get_tree().paused)
	_test_stage = "continue_destination"
	if not _ok(await fixture.pause.request_continue()): return
	assert_false(get_tree().paused)
	assert_eq(fixture.game.capture_run_snapshot_input(), after)
	assert_eq(fixture.profile_bytes(), profile_before)

func refused_load() -> void:
	_test_stage = "start_text"
	if not fixture_ready or not _ok(await fixture.start_text()): return
	if not _witnessed_caption("source"): return
	_test_stage = "pause_source"
	if not _ok(await fixture.pause.request_pause()): return
	var source: Dictionary = fixture.game.capture_run_snapshot_input().duplicate(true)
	var session: Dictionary = fixture.game.capture_live_session().value.duplicate(true)
	var profile_before: Dictionary = fixture.profile_bytes()
	var frontier: Dictionary = fixture.bridge.capture_pause_frontier()
	if not _ok(frontier): return
	var handle: Dictionary = fixture.pause._handle.duplicate(true)
	var prepared: Dictionary = fixture.pause._backup_port.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	fixture.ready_count = 0
	fixture.write_fault.armed = true
	_test_stage = "commit_write_refusal"
	var refused: Dictionary = await fixture.pause._backup_port.commit_action(prepared.value.token)
	assert_false(refused.get("ok", false), str(refused))
	assert_eq(fixture.write_fault.refusal_count, 1, fixture.write_fault.refused_path)
	assert_false(refused.get("committed", false), "failure precedes destination ownership")
	assert_true(get_tree().paused)
	assert_eq(fixture.pause.coordinator.get_state().value.state, &"Suspended")
	assert_eq(fixture.pause._handle, handle)
	assert_false(fixture.pause._loading)
	assert_eq(fixture.ready_count, 0)
	assert_eq(fixture.pause_closed_count, 0)
	assert_eq(fixture.game.capture_live_session().value, session)
	assert_eq(fixture.game.capture_run_snapshot_input(), source)
	assert_eq(fixture.profile_bytes(), profile_before)
	assert_eq(fixture.bridge.capture_pause_frontier(), frontier)
	assert_eq(fixture.input_owner.get_state().value.state, &"Suspended")
	assert_eq(fixture.audio_owner.get_state().value.state, &"Suspended")
	assert_false(fixture.router.is_restore_publication_held())
	_test_stage = "continue_refused_source"
	if not _ok(await fixture.pause.request_continue()): return
	assert_false(get_tree().paused)
	assert_eq(fixture.pause_closed_count, 1)
	assert_eq(fixture.input_owner.get_state().value.state, &"Active")
	assert_eq(fixture.audio_owner.get_state().value.state, &"Active")
	assert_eq(fixture.bridge.get_state().value.state, &"Active")
	assert_eq(fixture.game.capture_run_snapshot_input(), source)
	assert_eq(fixture.profile_bytes(), profile_before)
	assert_eq(fixture.native_markers, [])
