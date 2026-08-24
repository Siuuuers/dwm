class_name ScheduleDoneDispatcher
extends RefCounted

## The production Schedule-Done dispatch surface Plan 03 owns (dwm-p2r.21's recorded resolution;
## built under the dwm-oyo.3 slice authority recorded 2026-08-24 on dwm-p2r.21 / dwm-oyo.3).
##
## WHY THIS OBJECT EXISTS. `DayResolutionCoordinator.complete_presentation_stage()` had no
## production caller: a configured presentation port PUBLISHES its completion, the coordinator
## retains the receipt, and "the signal alone advances nothing" -- something in production must
## drive the settle-and-resume. dwm-p2r.21's recorded direction rejects a GameState facade for
## this; the Done dispatch is its own application object, composed by Bootstrap.
##
## THE TWO DOORS. `dispatch_done(command_id)` issues one Schedule-Done command into
## `request_schedule_done` -- the walk begins, pauses at the first presentation, and the routed
## scene plays. When the player finishes the presentation, the scene settles its port; the port
## publishes `completion_ready`; and THIS object -- connected AFTER the coordinator's own
## connections, so the receipt is already retained when its handler runs -- drives exactly one
## `complete_presentation_stage()`, which checkpoints the receipt and resumes the walk atomically.
##
## RE-ENTRANCY IS QUEUED AWAY. A physical owner that completes synchronously inside `begin()` would
## otherwise publish a completion while the previous dispatch's `resume()` is still unwinding, and
## a nested `complete_presentation_stage()` would settle a stage underneath its own walk. The
## dispatcher therefore never dispatches while a dispatch is running: a mid-dispatch completion is
## queued and dispatched immediately after the running call returns.

const _COORDINATOR_METHODS: Array[String] = [
	"request_schedule_done", "complete_presentation_stage",
]
const _PORT_METHODS: Array[String] = ["begin", "complete", "is_ready"]

var _coordinator: Object = null
var _hospital_port: Object = null
var _dating_port: Object = null
## The result of the most recent completion dispatch, retained for the composing caller -- a signal
## handler has nobody to return to.
var _last_dispatch_result: Dictionary = {}
var _dispatching := false
var _queued_completions := 0


func configure(day_resolution_coordinator: Object, hospital_port: Object,
		dating_port: Object) -> Dictionary:
	if day_resolution_coordinator == null \
			or not _has_methods(day_resolution_coordinator, _COORDINATOR_METHODS):
		return {"ok": false, "code": &"invalid_day_resolution_coordinator",
			"message": "an exact request/complete coordinator capability is required", "details": {}}
	for port: Object in [hospital_port, dating_port]:
		if port == null or not _has_methods(port, _PORT_METHODS) \
				or not port.has_signal("completion_ready") \
				or not port.has_signal("completion_failed"):
			return {"ok": false, "code": &"invalid_presentation_port",
				"message": "an exact signalling presentation-port capability is required",
				"details": {}}
	if hospital_port == dating_port:
		return {"ok": false, "code": &"invalid_presentation_port",
			"message": "one object may not claim both presentation roles", "details": {}}
	if _coordinator != null:
		if _coordinator != day_resolution_coordinator or _hospital_port != hospital_port \
				or _dating_port != dating_port:
			return {"ok": false, "code": &"schedule_done_dispatcher_conflict",
				"message": "a configured dispatcher never adopts a replacement owner", "details": {}}
		return {"ok": true, "code": &"ok",
			"value": {"configured": true, "already_configured": true}, "receipt": {}}
	_coordinator = day_resolution_coordinator
	_hospital_port = hospital_port
	_dating_port = dating_port
	for port: Object in [hospital_port, dating_port]:
		var handler := _on_completion_ready.bind(port)
		if not port.is_connected("completion_ready", handler):
			port.connect("completion_ready", handler)
	return {"ok": true, "code": &"ok",
		"value": {"configured": true, "already_configured": false}, "receipt": {}}


## Issues ONE Schedule-Done command. The coordinator owns every validation and the whole walk; the
## dispatcher adds nothing to the result.
func dispatch_done(command_id: String) -> Dictionary:
	if _coordinator == null:
		return {"ok": false, "code": &"port_not_configured", "message": "", "details": {}}
	return _coordinator.call(&"request_schedule_done", command_id)


## The most recent completion dispatch's own result, detached.
func get_last_dispatch_result() -> Dictionary:
	return _last_dispatch_result.duplicate(true)


## One retained port published a completion. The coordinator's own handler already retained the
## receipt (its connection precedes this one); this drives the settle exactly once, after any
## already-running dispatch has fully unwound.
func _on_completion_ready(_completion_result: Dictionary, port: Object) -> void:
	if port != _hospital_port and port != _dating_port:
		return
	_queued_completions += 1
	if _dispatching:
		return
	_dispatching = true
	while _queued_completions > 0:
		_queued_completions -= 1
		_last_dispatch_result = _coordinator.call(&"complete_presentation_stage")
	_dispatching = false


static func _has_methods(target: Object, methods: Array[String]) -> bool:
	for method_name: String in methods:
		if not target.has_method(method_name):
			return false
	return true
