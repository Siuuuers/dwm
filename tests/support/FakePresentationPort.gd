extends RefCounted

## The minimum object `DayResolutionCoordinator.configure_presentation_ports` will adopt, so the
## coordinator's own completion path can be driven without a Dialogic runtime (dwm-p2r.18).
##
## WHY THIS EXISTS. `complete_presentation_stage()` -- the seam dwm-p2r.14's acceptance criteria
## name, where the port's completion receipt is checkpointed BEFORE the stage advances -- had no
## caller anywhere in the repo: not in production, where Plan 03 still owns the Done dispatch, and
## not in any test. The suites that drive real presentations call the state port's
## `presentation_stage_receipt()` and then complete the stage through `RunLifecycle` directly, which
## bypasses the coordinator's ordering entirely. This fake exists to reach that path.
##
## IT PUBLISHES, IT DOES NOT DECIDE. The real ports validate the physical owner's receipt before
## emitting; nothing here models that, because the coordinator's contract is only that it accepts a
## completion from the exact configured object identity and checkpoints it before advancing. A fake
## that also re-validated would be testing the port again rather than the coordinator.

signal completion_ready(completion_result: Dictionary)
signal completion_failed(failure: Dictionary)


## The exact capability set the coordinator requires (`PRESENTATION_PORT_METHODS`). Never called by
## the coordinator's completion path; present so the port is adoptable at all.
func begin(_request: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


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
