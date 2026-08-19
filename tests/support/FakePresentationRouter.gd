extends RefCounted

## The minimum object `DayResolutionCoordinator.configure_presentation_router` will adopt, so the
## walk's presentation DISPATCH can be driven without a SceneTree (dwm-p2r.18).
##
## WHY THIS EXISTS. `SceneRouter.route_presentation()` had no caller anywhere in production: the
## walk paused on `await_registered_command` carrying a `route_id` and a `presentation_request`, and
## nothing ever handed those to a router, so no Hospital or Dating adapter was ever launched. The
## real router instantiates a PackedScene and mutates `tree.current_scene`, which a unit suite has no
## business doing; this fake records the exact call instead.
##
## IT RECORDS, IT DOES NOT DECIDE. Route legality, port readiness and scene configuration are the
## real router's contract and are proved against the real router in
## `tests/integration/test_schedule_presentation_bootstrap_wiring.gd`. What the coordinator owes is
## narrower: that it calls the configured router exactly once per launched presentation, with the
## route the command names and the canonical command the port returned, and only after the physical
## presentation has started.

const _METHODS: Array[String] = ["route_presentation", "is_schedule_presentation_ports_configured"]

## Shared ordering log, so a test can prove `port.begin` precedes `router.route_presentation`.
var _calls: Array[String] = []
## Every (route_id, presentation_command) pair this router was handed, in call order.
var _routes: Array[Dictionary] = []
var _failure_code := &""
var _ports_configured := true


func _init(calls: Array[String] = []) -> void:
	_calls = calls


## Makes the next and every later route refuse, the way an unready port or a missing scene does.
func set_failure(code: StringName) -> void:
	_failure_code = code


func set_ports_configured(configured: bool) -> void:
	_ports_configured = configured


func is_schedule_presentation_ports_configured() -> bool:
	return _ports_configured


func route_presentation(route_id: String, presentation_command: Dictionary) -> Dictionary:
	_calls.append("router.route_presentation")
	_routes.append({"route_id": route_id, "command": presentation_command.duplicate(true)})
	if _failure_code != &"":
		return {"ok": false, "code": _failure_code, "message": route_id}
	return {"ok": true, "code": &"ok", "value": {
		"route_id": route_id,
		"scene_instance_id": get_instance_id(),
	}, "receipt": {}}


## Detached copies: reading what the router was handed never lets a test mutate the record.
func get_routes() -> Array[Dictionary]:
	var copied: Array[Dictionary] = []
	for route: Dictionary in _routes:
		copied.append(route.duplicate(true))
	return copied


static func capability_methods() -> Array[String]:
	return _METHODS.duplicate()
