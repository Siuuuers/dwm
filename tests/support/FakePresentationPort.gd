extends RefCounted

## The minimum object `DayResolutionCoordinator.configure_presentation_ports` will adopt, so the
## coordinator's own completion path can be driven without a Dialogic runtime (dwm-p2r.18).
##
## WHY THIS EXISTS. `complete_presentation_stage()` -- the seam dwm-p2r.14's acceptance criteria
## name, where the port's completion receipt is checkpointed BEFORE the stage advances -- had no
## caller anywhere in the repo WHEN THIS FAKE WAS WRITTEN: not in production, and not in any test.
## (Production reached it in the dwm-oyo.3 slice -- `ScheduleDoneDispatcher` now drives it from the
## presentation ports' `completion_ready`. This fake still isolates the coordinator's own ordering.) The suites that drive real presentations call the state port's
## `presentation_stage_receipt()` and then complete the stage through `RunLifecycle` directly, which
## bypasses the coordinator's ordering entirely. This fake exists to reach that path.
##
## IT PUBLISHES, IT DOES NOT DECIDE. The real ports validate the physical owner's receipt before
## emitting; nothing here models that, because the coordinator's contract is only that it accepts a
## completion from the exact configured object identity and checkpoints it before advancing. A fake
## that also re-validated would be testing the port again rather than the coordinator.

signal completion_ready(completion_result: Dictionary)
signal completion_failed(failure: Dictionary)

## Shared ordering log, so a test can prove `port.begin` precedes `router.route_presentation`.
var _calls: Array[String] = []
## Every request `begin()` was handed, in call order.
var _requests: Array[Dictionary] = []
var _begin_failure_code := &""


func _init(calls: Array[String] = []) -> void:
	_calls = calls


## Makes `begin()` refuse the way a port with no configured physical owner does.
func set_begin_failure(code: StringName) -> void:
	_begin_failure_code = code


## The exact capability set the coordinator requires (`PRESENTATION_PORT_METHODS`).
##
## dwm-p2r.18 gave this a body: the walk now LAUNCHES a presentation, so `begin()` is on the
## dispatch path rather than merely present for adoptability. It returns the same envelope the real
## ports return -- `value.presentation_command` is the request plus the two members only a started
## presentation can carry -- because that canonical command, not the raw request, is what the router
## hands the scene.
func begin(request: Dictionary) -> Dictionary:
	_calls.append("port.begin")
	_requests.append(request.duplicate(true))
	if _begin_failure_code != &"":
		return {"ok": false, "code": _begin_failure_code, "message": "", "details": {}}
	var command: Dictionary = request.duplicate(true)
	command["command_sha256"] = "sha256:%s" % str(request.get("completion_transaction_id", ""))
	command["physical_token"] = "token:%s" % str(request.get("completion_transaction_id", ""))
	return {"ok": true, "code": &"ok", "value": {"presentation_command": command}, "receipt": {}}


## Detached copies: reading what the port was handed never lets a test mutate the record.
func get_requests() -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for request: Dictionary in _requests:
		copied.append(request.duplicate(true))
	return copied


func complete(_request: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func is_ready() -> bool:
	return true


## Publishes exactly what a real port publishes on success: a CommandResult whose `receipt` is the
## completion receipt the coordinator must checkpoint.
func publish_completion(receipt: Dictionary) -> void:
	completion_ready.emit({"ok": true, "code": &"ok", "value": {"completion_receipt": receipt},
		"receipt": receipt.duplicate(true)})


func publish_failure(failure: Dictionary) -> void:
	completion_failed.emit(failure)
