extends "res://addons/gut/test.gd"
## RED/GREEN coverage for ScheduleDoneDispatcher -- the production Schedule-Done dispatch surface
## Plan 03 owns (dwm-p2r.21's recorded resolution: the Done dispatch drives
## `complete_presentation_stage`; the GameState facade option is REJECTED). Created under the
## dwm-oyo.3 slice authority recorded 2026-08-24 on dwm-p2r.21 / dwm-oyo.3.
##
## THE DISPATCH LAW. `dispatch_done(command_id)` forwards ONE Done command to the coordinator's
## `request_schedule_done`. Each completion a RETAINED presentation port publishes drives exactly
## one `complete_presentation_stage()` call -- after the coordinator's own connection has already
## retained the receipt (the dispatcher is configured AFTER `configure_presentation_ports`, and
## Godot delivers signal connections in connection order). A completion published while a dispatch
## is still running is queued and dispatched afterward, never nested -- the coordinator's walk must
## finish unwinding before the next stage settles.
##
## Unit-level proof over a recording fake coordinator plus the established FakePresentationPort;
## the real-graph composition is proven end to end in the dwm-p2r.21 acceptance suite.

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const DISPATCHER_PATH := "res://scripts/application/schedule/ScheduleDoneDispatcher.gd"
const PRESENTATION_PORT := preload("res://tests/support/FakePresentationPort.gd")


## Records the dispatcher's two coordinator calls; can publish a nested completion from inside
## complete_presentation_stage() to prove the dispatcher never re-enters the coordinator.
class FakeDayResolutionCoordinator:
	var request_calls: Array[String] = []
	var complete_calls := 0
	var complete_depth := 0
	var max_complete_depth := 0
	var request_result: Dictionary = {"ok": true, "code": &"await_registered_command",
		"value": {}}
	var complete_result: Dictionary = {"ok": true, "code": &"plan_complete",
		"value": {"checkpoint_id": "run:1"}}
	## When set, the FIRST complete_presentation_stage() call publishes this receipt on this port
	## mid-call -- the synchronous next-presentation hazard the dispatcher must not recurse into.
	var nested_publish_port: Object = null
	var nested_publish_receipt: Dictionary = {}

	func request_schedule_done(command_id: String) -> Dictionary:
		request_calls.append(command_id)
		return request_result.duplicate(true)

	func complete_presentation_stage() -> Dictionary:
		complete_calls += 1
		complete_depth += 1
		max_complete_depth = maxi(max_complete_depth, complete_depth)
		if nested_publish_port != null:
			var port: Object = nested_publish_port
			nested_publish_port = null
			port.call(&"publish_completion", nested_publish_receipt)
		complete_depth -= 1
		return complete_result.duplicate(true)


var _dispatcher_script: Script = null
var _coordinator: FakeDayResolutionCoordinator
var _hospital_port: PRESENTATION_PORT
var _dating_port: PRESENTATION_PORT
var _dispatcher: Object = null


func before_each() -> void:
	var loaded: Dictionary = PROBE.load_script(DISPATCHER_PATH)
	_dispatcher_script = loaded["value"] if loaded.get("ok", false) else null
	_coordinator = FakeDayResolutionCoordinator.new()
	_hospital_port = PRESENTATION_PORT.new()
	_dating_port = PRESENTATION_PORT.new()
	if _dispatcher_script != null:
		_dispatcher = _dispatcher_script.new()
		var configured: Dictionary = _dispatcher.configure(
			_coordinator, _hospital_port, _dating_port)
		assert_true(configured.get("ok", false), JSON.stringify(configured))


func _require_dispatcher() -> bool:
	if _dispatcher_script == null:
		assert_true(false, "the dispatcher module is absent: " + DISPATCHER_PATH)
		return false
	return true


# ---- module presence ----

func test_dispatcher_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script(DISPATCHER_PATH)
	assert_true(loaded.get("ok", false), "ScheduleDoneDispatcher.gd must load")


# ---- configure ----

func test_configure_rejects_null_and_signalless_owners() -> void:
	if not _require_dispatcher():
		return
	var fresh: Object = _dispatcher_script.new()
	var null_coordinator: Dictionary = fresh.configure(null, _hospital_port, _dating_port)
	assert_false(null_coordinator.get("ok", true))
	var signalless: Dictionary = fresh.configure(_coordinator, RefCounted.new(), _dating_port)
	assert_false(signalless.get("ok", true))
	var same_port: Dictionary = fresh.configure(_coordinator, _hospital_port, _hospital_port)
	assert_false(same_port.get("ok", true), "one object may not claim both presentation roles")


func test_configure_identical_replay_is_idempotent_and_replacement_is_refused() -> void:
	if not _require_dispatcher():
		return
	var replay: Dictionary = _dispatcher.configure(_coordinator, _hospital_port, _dating_port)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_true(bool((replay.get("value", {}) as Dictionary).get("already_configured", false)))
	var replaced: Dictionary = _dispatcher.configure(
		FakeDayResolutionCoordinator.new(), _hospital_port, _dating_port)
	assert_false(replaced.get("ok", true))


func test_dispatch_before_configure_fails_closed() -> void:
	if not _require_dispatcher():
		return
	var fresh: Object = _dispatcher_script.new()
	var result: Dictionary = fresh.dispatch_done("done-1")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"port_not_configured")


# ---- dispatch_done ----

func test_dispatch_done_forwards_the_command_and_returns_the_walk_result() -> void:
	if not _require_dispatcher():
		return
	var result: Dictionary = _dispatcher.dispatch_done("done-1")
	assert_eq(_coordinator.request_calls, ["done-1"])
	assert_eq(result, _coordinator.request_result)


# ---- the completion dispatch ----

func test_a_published_completion_drives_complete_presentation_stage_exactly_once() -> void:
	if not _require_dispatcher():
		return
	_hospital_port.publish_completion({"receipt_id": "completion-1"})
	assert_eq(_coordinator.complete_calls, 1)
	assert_eq(_dispatcher.get_last_dispatch_result(), _coordinator.complete_result)


func test_both_retained_ports_drive_the_dispatch() -> void:
	if not _require_dispatcher():
		return
	_hospital_port.publish_completion({"receipt_id": "completion-1"})
	_dating_port.publish_completion({"receipt_id": "completion-2"})
	assert_eq(_coordinator.complete_calls, 2)


func test_a_failed_completion_dispatch_is_retained_not_raised() -> void:
	if not _require_dispatcher():
		return
	_coordinator.complete_result = {"ok": false, "code": &"no_presentation_completion",
		"message": "", "details": {}}
	_hospital_port.publish_completion({"receipt_id": "completion-1"})
	assert_eq(_coordinator.complete_calls, 1)
	assert_eq(_dispatcher.get_last_dispatch_result().get("code"), &"no_presentation_completion")


func test_a_completion_published_mid_dispatch_is_queued_never_nested() -> void:
	if not _require_dispatcher():
		return
	_coordinator.nested_publish_port = _dating_port
	_coordinator.nested_publish_receipt = {"receipt_id": "completion-2"}
	_hospital_port.publish_completion({"receipt_id": "completion-1"})
	assert_eq(_coordinator.complete_calls, 2,
		"the mid-dispatch completion still gets dispatched afterward")
	assert_eq(_coordinator.max_complete_depth, 1,
		"the dispatcher never re-enters complete_presentation_stage")
