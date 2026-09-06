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
