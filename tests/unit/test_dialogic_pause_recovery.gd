extends "res://addons/gut/test.gd"

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const HANDLE := {
	"generation": 1,
	"handle_id": "pause.dialogic.fixture.1",
	"holder": &"pause-fixture",
	"reason": &"universal_pause",
}
const TIMELINE_ID := "hospital.faint"


class RuntimeDouble extends RefCounted:
	signal timeline_ended_signal
	signal runtime_signal_event(argument)
	signal playback_start_failed(result: Dictionary, halt_runtime: bool)

	var frontier := {
		"generation": 7,
		"event_index": 3,
		"request_id": "runtime-double:7",
		"paused": false,
	}
	var active := true
	var fail_next_set := false
	var mutate_before_set_failure := false
	var set_calls: Array[bool] = []
	var start_calls := 0

	func start_timeline(_path: String, _label: String) -> Dictionary:
		start_calls += 1
		active = true
		frontier.generation += 1
		frontier.event_index = 0
		frontier.request_id = "runtime-double:%d" % int(frontier.generation)
		return {"ok": true}

	func capture_pause_frontier() -> Dictionary:
		if not active:
			return _failure(&"pause_frontier_unavailable")
		return {"ok": true, "code": &"ok", "value": frontier.duplicate(true)}

	func set_paused(value: bool) -> Dictionary:
		set_calls.append(value)
		if fail_next_set:
			fail_next_set = false
			if mutate_before_set_failure:
				frontier.paused = value
			return _failure(&"runtime_pause_not_applied")
		frontier.paused = value
		return {"ok": true, "code": &"ok", "value": {"paused": value}}

	func has_active_playback() -> bool:
		return active

	var halts := 0
	func halt_with_error(_result: Dictionary) -> Dictionary:
		halts += 1
		active = false
		timeline_ended_signal.emit()
		return {"ok": false, "code": &"runtime_halted"}

	func _failure(code: StringName) -> Dictionary:
		return {"ok": false, "code": code, "message": "fixture failure", "details": {}}


var _bridge: Node
var _runtime: RuntimeDouble


func before_each() -> void:
	_runtime = RuntimeDouble.new()
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)
	assert_true(_bridge.initialize(null, _runtime).get("ok", false))


func _retain_hospital_owner() -> void:
	_bridge.set("_ordinary_playback", {
		"timeline_id": TIMELINE_ID,
		"context": {},
		"cache_before": {"id": "", "context": {}},
	})

func test_only_retained_pause_handle_can_request_explicit_reading_completion() -> void:
	_retain_hospital_owner()
	assert_true(_bridge.begin_suspend(HANDLE).get("ok", false))
	var frontier := _runtime.frontier.duplicate(true)
	var native := DialogicNode_DialogText.new()
	assert_eq(_bridge.complete_paused_reading_reveal({}, native).get("code"), &"invalid_suspension_handle")
	var foreign := HANDLE.duplicate(true)
	foreign.generation += 1
	assert_eq(_bridge.complete_paused_reading_reveal(foreign, native).get("code"), &"invalid_suspension_handle")
	assert_eq(_bridge.capture_reading_checkpoint(true).get("code"), &"narrative_suspended",
		"generic reveal capture cannot bypass the retained view owner")
	assert_eq(_bridge.complete_paused_reading_reveal(HANDLE, native).get("code"), &"reading_frontier_unavailable",
		"an exact handle still cannot invent an admitted reading session")
	assert_eq(_runtime.frontier, frontier)
	assert_eq(_runtime.set_calls, [true])
	assert_true(_bridge.resume(HANDLE).get("ok", false))
	native.free()


func _entry_context(role: String = "hospital") -> Dictionary:
	return {
		"expected_stage": "fixture-stage",
		"playback_id": "fixture-playback",
		"role": role,
		"transaction_id": "fixture-transaction",
	}


func test_begin_setter_failure_retains_custody_until_exact_compensation() -> void:
	_retain_hospital_owner()
	_runtime.fail_next_set = true
	var failed: Dictionary = _bridge.begin_suspend(HANDLE)
	assert_eq(failed, {
		"ok": false, "code": &"pause_source_changed", "value": null,
	})
	assert_false(_runtime.frontier.paused,
		"a refused native setter left the runtime physically unpaused")
	assert_eq(_bridge.get_state(), {
		"ok": false, "code": &"narrative_runtime_indeterminate", "value": null,
	})
	assert_eq(_bridge.resume(HANDLE), {
		"ok": true, "code": &"ok", "value": {"resumed": true},
	}, "the exact retained handle can compensate the failed acquire")
	assert_eq(_runtime.set_calls, [true, false])
	assert_eq(_bridge.get_state(), {
		"ok": true, "code": &"ok", "value": {"state": &"Active"},
	})


func test_resume_failure_after_mutation_is_indeterminate_and_exactly_retryable() -> void:
	_retain_hospital_owner()
	assert_true(_bridge.begin_suspend(HANDLE).get("ok", false))
	assert_true(_runtime.frontier.paused)
	_runtime.fail_next_set = true
	_runtime.mutate_before_set_failure = true
	assert_eq(_bridge.resume(HANDLE), {
		"ok": false, "code": &"pause_resume_failed", "value": null,
	})
	assert_false(_runtime.frontier.paused,
		"the injected resume failure occurs after physical unpause")
	assert_eq(_bridge.get_state(), {
		"ok": false, "code": &"narrative_runtime_indeterminate", "value": null,
	})
	var replacement := HANDLE.duplicate(true)
	replacement.generation = 2
	assert_eq(_bridge.resume(replacement).get("code"), &"invalid_suspension_handle")
	assert_true(_bridge.resume(HANDLE).get("ok", false),
		"only the exact retained handle can complete a retry")
	assert_eq(_runtime.set_calls, [true, false, false])
	assert_eq(_bridge.get_state().value.state, &"Active")


func test_changed_source_keeps_custody_blocks_all_starts_and_resumes_after_repair() -> void:
	_retain_hospital_owner()
	assert_true(_bridge.begin_suspend(HANDLE).get("ok", false))
	var original_index := int(_runtime.frontier.event_index)
	_runtime.frontier.event_index = original_index + 1
	assert_eq(_bridge.get_state().get("code"), &"narrative_runtime_indeterminate")
	assert_eq(_bridge.resume(HANDLE).get("code"), &"pause_source_changed")

	assert_eq(_bridge.start_timeline_id(TIMELINE_ID).get("reason"),
		"narrative_suspended")
	assert_eq(_bridge.start_entry("hospital.faint", _entry_context()).get("code"),
		&"narrative_suspended")
	assert_eq(_bridge.start_ending_id("ending.alone", _entry_context("primary")).get("code"),
		&"narrative_suspended")
	assert_eq(_runtime.set_calls, [true],
		"lost source identity cannot cause a replacement start or physical release")

	_runtime.frontier.event_index = original_index
	assert_true(_bridge.resume(HANDLE).get("ok", false),
		"restoring the original source permits the exact release retry")
	assert_false(_runtime.frontier.paused)
	assert_eq(_bridge.get_state().value.state, &"Active")


func test_unowned_runtime_frontier_cannot_open_pause() -> void:
	assert_true(_runtime.capture_pause_frontier().get("ok", false),
		"the double exposes a live runtime frontier")
	assert_eq(_bridge.capture_pause_frontier().get("code"),
		&"pause_frontier_unavailable")
	assert_eq(_bridge.begin_suspend(HANDLE), {
		"ok": false, "code": &"pause_frontier_unavailable", "value": null,
	})
	assert_eq(_runtime.set_calls, [],
		"an unowned runtime is never physically paused")
	assert_eq(_bridge.get_state().value.state, &"Active")


func test_semantic_and_ending_pause_require_the_owned_runtime_frontier() -> void:
	for member: String in ["_active_entry", "_active_playback"]:
		_bridge.set(member, {"entry_id": "hospital.faint", "timeline_id": "ending.alone", "token": "owned-pause"})
		assert_true(_bridge.capture_pause_frontier().ok)
		assert_true(_bridge.begin_suspend(HANDLE).ok)
		assert_true(_runtime.frontier.paused)
		assert_true(_bridge.resume(HANDLE).ok)
		_bridge.set(member, {})
	assert_false(_bridge.capture_pause_frontier().ok, "A runtime frontier with no owning playback stays refused")

func test_retirement_cancels_native_ending_without_emitting_completion_and_can_retry_release() -> void:
	var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	assert_true(_bridge.configure_mutation_gate(gate).ok)
	_bridge.set("_active_playback", {"ending_id": "ending.alone", "timeline_id": "ending.alone", "token": "ending-pause"})
	_bridge.set("_current_timeline_id", "ending.alone")
	watch_signals(_bridge)
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	assert_false(_bridge.retire_suspended_source(HANDLE).ok, "Return needs real session-abandonment custody")
	var acquired: Dictionary = gate.acquire(&"session_abandonment")
	assert_true(acquired.ok)
	_runtime.fail_next_set = true
	assert_false(_bridge.retire_suspended_source(HANDLE).ok)
	assert_eq(_runtime.halts, 1)
	assert_true(_bridge.retire_suspended_source(HANDLE).ok)
	assert_true(_bridge.retire_suspended_source(HANDLE).ok)
	assert_eq(_runtime.halts, 1, "Retry never cancels a new runtime or repeats native end")
	assert_eq(_bridge.get_current_narrative_checkpoint(), {})
	assert_signal_not_emitted(_bridge, "ending_playback_finished")
	assert_signal_not_emitted(_bridge, "timeline_finished")
	assert_false(_runtime.frontier.paused)
	assert_true(gate.release(&"session_abandonment", acquired.value.token).ok)


func test_retired_ending_releases_retained_adapter_without_completion_and_can_start_next_run() -> void:
	var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	assert_true(_bridge.configure_mutation_gate(gate).ok)
	var playback := preload("res://scripts/application/ending/DialogicEndingPlaybackPort.gd").new()
	assert_true(playback.initialize(_bridge).ok)
	watch_signals(_bridge)
	watch_signals(playback)
	_runtime.active = false
	var context := {"expected_stage": &"PRIMARY_PENDING", "role": "primary",
		"playback_id": "run-one:ending", "transaction_id": "run-one:ending:complete"}
	var first: Dictionary = playback.start_ending_id("ending.alone", context)
	assert_true(first.get("ok", false), str(first))
	if not first.get("ok", false): return
	var first_token := str(first.receipt.playback_token)
	# A foreign cancellation cannot release this binding.
	_bridge.ending_playback_retired.emit(first_token, "ending.sylvia.dark")
	assert_true(playback.start_ending_id("ending.alone", context).ok)
	assert_eq(_runtime.start_calls, 1)
	assert_true(_bridge.begin_suspend(HANDLE).ok)
	var acquired: Dictionary = gate.acquire(&"session_abandonment")
	assert_true(acquired.ok)
	_runtime.fail_next_set = true
	assert_false(_bridge.retire_suspended_source(HANDLE).ok)
	assert_true(playback._active.is_empty(), "physical cancellation already released the outer owner")
	assert_true(_bridge.retire_suspended_source(HANDLE).ok)
	assert_true(_bridge.retire_suspended_source(HANDLE).ok)
	assert_eq(_runtime.halts, 1)
	assert_signal_emit_count(_bridge, "ending_playback_retired", 2,
		"one foreign signal plus exactly one real retirement; release retries never re-notify")
	assert_signal_not_emitted(playback, "playback_completed")
	assert_signal_not_emitted(playback, "playback_failed")
	assert_signal_not_emitted(_bridge, "ending_playback_finished")
	assert_true(playback._completed.is_empty(), "Return records no completion receipt")
	assert_true(gate.release(&"session_abandonment", acquired.value.token).ok)
	context.playback_id = "run-two:ending"
	context.transaction_id = "run-two:ending:complete"
	var second: Dictionary = playback.start_ending_id("ending.alone", context)
	assert_true(second.get("ok", false), str(second))
	if not second.get("ok", false): return
	assert_ne(str(second.receipt.playback_token), first_token)
	assert_eq(_runtime.start_calls, 2, "the same retained adapter starts the next run")
	_bridge.ending_playback_finished.emit(first_token, "ending.alone", {"receipt_id": "late-old-completion"})
	assert_signal_not_emitted(playback, "playback_completed", "a stale old token cannot advance the new run")
	_runtime.active = false
	_runtime.timeline_ended_signal.emit()
	assert_signal_emit_count(playback, "playback_completed", 1, "only the second playback naturally completes")
	assert_signal_not_emitted(playback, "playback_failed")


class OrdinaryBridgeDouble extends RefCounted:
	signal timeline_finished(timeline_id: String, result: Dictionary)
	signal ordinary_playback_retired(timeline_id: String)
	var starts := 0
	func is_dialogic_available() -> bool: return true
	func start_timeline_id(_timeline_id: String, _context: Dictionary) -> Dictionary:
		starts += 1
		return {"ok": true}


func test_ordinary_retirement_releases_only_matching_pending_owner_without_failure() -> void:
	var bridge := OrdinaryBridgeDouble.new()
	var narrative := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd").new()
	assert_true(narrative.configure(bridge).ok)
	assert_true(narrative.configure_frozen_hospital_contexts().ok)
	watch_signals(narrative)
	# The retirement subject is an actual Hospital timeline. Ordinary fainting
	# without Sylvia eligibility owns a notice, which correctly ignores DTL signals.
	var frozen: Dictionary = preload("res://scripts/narrative/FrozenPresentationContext.gd").build(
		"hospital.faint.day3", {"entry_id": "hospital.faint.day3", "entry_role": "hospital",
			"day": 3, "qualifying_cause": "condition_hospital",
			"accepted_record_ids": ["synthetic.accepted.3"], "unfulfilled_record_ids": ["synthetic.accepted.3"],
			"sylvia_eligible": true, "sylvia_witness_receipt_id": "synthetic.witness.3"})
	assert_true(frozen.get("ok", false), str(frozen))
	if not frozen.get("ok", false): return
	var command := {"resolution_id": "resolution.day3", "resolution_issuer_receipt": {},
		"stage_id": "stage.hospital", "substage_id": "intent.hospital", "route_id": "hospital",
		"timeline_id": TIMELINE_ID, "context": {"kind": "hospital", "day": 3,
			"source_entry_ids": ["synthetic.accepted.3"], "miss_receipt_ids": ["synthetic.miss.3"],
			"presentation": frozen.value},
		"completion_transaction_id": "completion.hospital.day3", "completion_transaction_provenance": {},
		"command_sha256": "c".repeat(64)}
	var first: Dictionary = narrative.begin_physical(command)
	assert_true(first.ok)
	bridge.ordinary_playback_retired.emit("unrelated.timeline")
	assert_true(narrative.begin_physical(command).ok)
	assert_eq(bridge.starts, 1, "an unrelated retirement cannot discard the binding")
	bridge.ordinary_playback_retired.emit(TIMELINE_ID)
	bridge.ordinary_playback_retired.emit(TIMELINE_ID)
	assert_true(narrative._in_flight.is_empty())
	assert_true(narrative._completed.is_empty())
	assert_signal_not_emitted(narrative, "physical_completion_ready")
	assert_signal_not_emitted(narrative, "physical_completion_failed")
	var restarted: Dictionary = narrative.begin_physical(command)
	assert_true(restarted.ok)
	assert_eq(bridge.starts, 2, "Load may reconstruct the same unfinished command after Return")
	assert_eq(restarted.value.physical_token, first.value.physical_token)
	bridge.timeline_finished.emit(TIMELINE_ID, {"outcome": "completed"})
	assert_signal_emit_count(narrative, "physical_completion_ready", 1)
	assert_signal_not_emitted(narrative, "physical_completion_failed")
