extends "res://addons/gut/test.gd"
## TEST-only activation protocol diagnostics: real scene registration/session and
## Bridge, simulated native transport. Not a complete Run, disk, or rendered proof.
const BASE := preload("res://tests/support/SceneDayReadingFixture.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const PARTICIPANT := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd")

class Native extends RefCounted:
	signal reading_frontier_restored(result: Dictionary)
	signal playback_start_failed(result: Dictionary)
	var frontier: Dictionary = {}
	var starts := 0
	var mode := "async"
	func has_active_playback() -> bool: return false
	func capture_reading_frontier() -> Dictionary:
		return {"ok": true, "value": frontier.duplicate(true)}
	func restore_scene_frontier(_session: RefCounted, checkpoint: Dictionary) -> Dictionary:
		starts += 1
		frontier = checkpoint.reading_session.frontier.duplicate(true)
		if mode != "async": reading_frontier_restored.emit(capture_reading_frontier())
		if mode == "success_then_return_failure": return {"ok": false, "code": &"TEST.native_failed"}
		if mode == "success_then_signal_failure": playback_start_failed.emit({"ok": false, "code": &"TEST.native_failed"})
		return {"ok": true, "value": {"pending": mode == "async"}}

class ControlNative extends Native:
	var saved: Dictionary = {}
	var retained_session: RefCounted
	func capture_scene_control_position(session: RefCounted) -> Dictionary:
		return {"ok": session == retained_session, "value": saved.duplicate(true)}
	func restore_scene_frontier(session: RefCounted, value: Dictionary) -> Dictionary:
		starts += 1
		retained_session = session
		saved = value.reading_session.duplicate(true)
		return {"ok": true}

var bridge: Node
var native: Native
var checkpoint: Dictionary
var confirmations: Array[String] = []
var failures: Array[String] = []

func before_all() -> void:
	assert_true(BASE.configure().ok)

func before_each() -> void:
	var created: Dictionary = BASE.create_session()
	assert_true(created.ok)
	var session: RefCounted = created.value
	assert_true(BASE.enter(session, BASE.A, "TEST.restore.occurrence").ok)
	var captured: Dictionary = BASE.checkpoint(session)
	assert_true(captured.ok)
	checkpoint = captured.value
	bridge = BRIDGE.new()
	autofree(bridge)
	native = Native.new()
	bridge._runtime_adapter = native
	confirmations = []
	failures = []
	bridge.scene_activation_confirmed.connect(func(id: String) -> void: confirmations.append(id))
	bridge.scene_activation_failed.connect(func(id: String, _result: Dictionary) -> void: failures.append(id))

func test_async_native_proof_requires_exact_operation_and_actual_frontier() -> void:
	assert_true(bridge.stage_scene_reading_restore(checkpoint, "restore.current").ok)
	assert_eq(native.starts, 0)
	assert_false(bridge.validate_scene_activation("restore.current").ok)
	assert_false(bridge.begin_scene_activation("restore.foreign").ok)
	assert_true(bridge.begin_scene_activation("restore.current").ok)
	assert_eq(native.starts, 1)
	bridge.reading_session_changed.emit()
	assert_eq(confirmations, [], "generic session change is not native proof")
	assert_false(bridge.validate_scene_activation("restore.current").ok)
	native.reading_frontier_restored.emit(native.capture_reading_frontier())
	assert_eq(confirmations, ["restore.current"])
	assert_true(bridge.validate_scene_activation("restore.current").ok)
	assert_false(bridge.validate_scene_activation("restore.foreign").ok)
	assert_true(bridge.begin_scene_activation("restore.current").ok)
	assert_eq(native.starts, 1)
	native.frontier.publication_id = "TEST.wrong"
	assert_false(bridge.validate_scene_activation("restore.current").ok)

func test_wrong_native_callback_fences_target_and_never_retries() -> void:
	assert_true(bridge.stage_scene_reading_restore(checkpoint, "restore.current").ok)
	assert_true(bridge.begin_scene_activation("restore.current").ok)
	native.reading_frontier_restored.emit({"ok": true, "value": {"line_id": "wrong", "publication_id": "wrong"}})
	assert_eq(confirmations, [])
	assert_eq(failures, ["restore.current"])
	assert_false(bridge.begin_scene_activation("restore.current").ok)
	assert_eq(native.starts, 1)
	assert_eq(bridge._scene_restore.checkpoint, checkpoint, "committed target retained")

func test_synchronous_success_then_failure_never_confirms() -> void:
	for mode: String in ["success_then_return_failure", "success_then_signal_failure"]:
		var owner: Node = BRIDGE.new()
		autofree(owner)
		var adapter := Native.new()
		adapter.mode = mode
		owner._runtime_adapter = adapter
		var seen: Array = []
		owner.scene_activation_confirmed.connect(func(id: String) -> void: seen.append(id))
		assert_true(owner.stage_scene_reading_restore(checkpoint, "restore.current").ok)
		assert_false(owner.begin_scene_activation("restore.current").ok)
		assert_eq(seen, [], mode)
		assert_false(owner.validate_scene_activation("restore.current").ok)
		assert_false(owner.begin_scene_activation("restore.current").ok)
		assert_eq(adapter.starts, 1)

func test_silent_rollback_removes_activation_permission() -> void:
	var backup: Dictionary = bridge.capture_restore_state()
	assert_true(bridge.stage_scene_reading_restore(checkpoint, "restore.current").ok)
	assert_true(bridge.rollback_restore_silent(backup.value).ok)
	assert_eq(native.starts, 0)
	assert_false(bridge.begin_scene_activation("restore.current").ok)

func test_participant_holds_native_until_completion_and_subscribes_before_sync_start() -> void:
	var participant := PARTICIPANT.new(bridge)
	# Explicit protocol injection only: complete saved-Run admission has separate tests.
	participant._prepared_scene_checkpoint = checkpoint.duplicate(true)
	var plan := checkpoint.duplicate(true)
	plan["route_ready_token"] = {"TEST": true}
	plan["scene_restore_operation_id"] = "restore.current"
	assert_true(participant.apply_silent(plan).ok)
	assert_true(participant.finalize().ok)
	assert_eq(native.starts, 0)
	var publications: Array = []
	bridge.reading_session_changed.connect(func() -> void: publications.append(true))
	var seen: Array = []
	participant.scene_activation_confirmed.connect(func(id: String) -> void: seen.append(id))
	native.mode = "sync"
	assert_true(participant.begin_scene_activation("restore.current").ok)
	assert_eq(seen, ["restore.current"])
	assert_true(participant.validate_scene_activation("restore.current").ok)
	assert_false(participant.validate_scene_activation("restore.foreign").ok)
	assert_true(participant.begin_scene_activation("restore.current").ok)
	assert_eq(seen.size(), 1)
	assert_eq(native.starts, 1)
	assert_eq(publications, [], "native proof is not publication permission")
	assert_true(participant.publish_scene_activation("restore.current").ok)
	assert_true(participant.publish_scene_activation("restore.current").ok)
	assert_eq(publications.size(), 1)

func test_participant_rejects_changed_checkpoint_or_missing_private_operation() -> void:
	var participant := PARTICIPANT.new(bridge)
	participant._prepared_scene_checkpoint = checkpoint.duplicate(true)
	var plan := checkpoint.duplicate(true)
	plan["route_ready_token"] = {}
	assert_false(participant.apply_silent(plan).ok)
	plan["scene_restore_operation_id"] = "restore.current"
	plan.transaction_id = "TEST.forged"
	assert_false(participant.apply_silent(plan).ok)
	assert_eq(native.starts, 0)

func _control_checkpoint() -> Dictionary:
	var created: Dictionary = BASE.create_session()
	assert_true(created.ok)
	var session: RefCounted = created.value
	assert_true(BASE.enter(session, BASE.B, "TEST.protocol.control").ok)
	assert_true(BASE.advance_detached(session).ok)
	var caption: Dictionary = BASE.checkpoint(session)
	assert_true(caption.ok)
	assert_true(BASE.advance_detached(session).ok)
	var captured: Dictionary = session.capture({})
	assert_true(captured.ok)
	var result: Dictionary = caption.value.duplicate(true)
	result.reading_session = captured.value
	return result

func test_control_requires_distinct_transport_proof_and_rejects_poisoned_callback() -> void:
	var control := _control_checkpoint()
	assert_false(bridge.stage_scene_reading_restore(control, "restore.control").ok,
		"line-only transport cannot start committed control restoration")
	var transport := ControlNative.new()
	bridge._runtime_adapter = transport
	assert_true(bridge.stage_scene_reading_restore(control, "restore.control").ok)
	assert_true(bridge.begin_scene_activation("restore.control").ok)
	transport.reading_frontier_restored.emit({"ok": true, "value": {}})
	assert_eq(confirmations, [])
	assert_eq(failures, ["restore.control"])
	assert_false(bridge.begin_scene_activation("restore.control").ok)
	assert_eq(transport.starts, 1)
	assert_eq(bridge._scene_restore.checkpoint, control)

func test_duplicate_control_proof_never_publishes_and_changed_physical_proof_refuses() -> void:
	var control := _control_checkpoint()
	var transport := ControlNative.new()
	bridge._runtime_adapter = transport
	var publications: Array = []
	bridge.reading_session_changed.connect(func() -> void: publications.append(true))
	assert_true(bridge.stage_scene_reading_restore(control, "restore.control").ok)
	assert_true(bridge.begin_scene_activation("restore.control").ok)
	transport.reading_frontier_restored.emit({"ok": true, "value": control.reading_session})
	assert_eq(confirmations, ["restore.control"])
	transport.reading_frontier_restored.emit({"ok": true, "value": control.reading_session})
	assert_eq(publications, [])
	assert_true(bridge.validate_scene_activation("restore.control").ok)
	transport.saved.program_index += 1
	assert_false(bridge.validate_scene_activation("restore.control").ok)
	assert_false(bridge.publish_scene_activation("restore.control").ok)
	assert_eq(publications, [])

func test_control_proof_refuses_changed_candidate_or_runtime() -> void:
	for mutation: String in ["candidate", "runtime", "missing_runtime"]:
		var owner: Node = BRIDGE.new()
		autofree(owner)
		var transport := ControlNative.new()
		owner._runtime_adapter = transport
		var control := _control_checkpoint()
		var seen: Array = []
		owner.scene_activation_confirmed.connect(func(id: String) -> void: seen.append(id))
		assert_true(owner.stage_scene_reading_restore(control, "restore.control").ok)
		assert_true(owner.begin_scene_activation("restore.control").ok)
		if mutation == "candidate": owner._scene_restore.candidate.scene_index += 1
		elif mutation == "missing_runtime": owner._runtime_adapter = null
		else: owner._runtime_adapter = ControlNative.new()
		transport.reading_frontier_restored.emit({"ok": true, "value": control.reading_session})
		assert_eq(seen, [], mutation)
		assert_false(owner.validate_scene_activation("restore.control").ok, mutation)
		assert_false(owner.begin_scene_activation("restore.control").ok, mutation)
		assert_eq(transport.starts, 1)

func test_control_refuses_real_first_caption_as_terminal_predecessor_before_staging() -> void:
	var end_checkpoint := _control_checkpoint()
	var created: Dictionary = BASE.create_session()
	assert_true(created.ok)
	var first: RefCounted = created.value
	assert_true(BASE.enter(first, BASE.B, "TEST.protocol.control").ok)
	var captured: Dictionary = BASE.checkpoint(first)
	assert_true(captured.ok)
	var unsupported: Dictionary = captured.value.duplicate(true)
	unsupported.reading_session.program_index = end_checkpoint.reading_session.program_index
	unsupported.reading_session.boundary = "control"
	unsupported.reading_session.frontier = {}
	unsupported.reading_session.next_operation = null
	assert_true(first.validate_saved(unsupported.reading_session, BASE.B).ok,
		"base Reading5 validity alone does not prove the native predecessor")
	var transport := ControlNative.new()
	bridge._runtime_adapter = transport
	assert_false(bridge.stage_scene_reading_restore(unsupported, "restore.control").ok)
	assert_eq(transport.starts, 0)
	assert_eq(bridge._scene_restore, {})
	assert_eq(bridge._reading_restore_pending, {})
