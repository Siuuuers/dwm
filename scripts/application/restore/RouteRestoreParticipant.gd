class_name RouteRestoreParticipant
extends RefCounted

## Restore participant wrapping SceneRouter's semantic route + target-layout
## readiness (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
## apply_silent does not succeed until the registered target scene reports its
## narrative layout ready, and returns the route-ready token the narrative
## participant validates before touching Dialogic.

var _owner: Object = null

func _init(owner: Object) -> void:
	_owner = owner

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("route_id")) != TYPE_STRING or str(input["route_id"]).is_empty():
		return _fail(&"invalid_route_input", "route participant requires a route_id")
	if typeof(input.get("route_context")) != TYPE_DICTIONARY:
		return _fail(&"invalid_route_input", "route participant requires a route_context")
	var prepared: Dictionary = _owner.prepare_route_restore(str(input["route_id"]), input["route_context"])
	if not prepared.get("ok", false):
		return prepared
	return {"ok": true, "code": &"ok", "value": {"route_plan": prepared.get("value", {})}}

func capture() -> Dictionary:
	return _owner.capture_restore_state()

func apply_silent(plan: Dictionary) -> Dictionary:
	# Succeeds only once the registered target scene reports its narrative layout
	# ready; the returned route_ready_token gates the narrative participant.
	return _owner.apply_route_restore_silent(plan)

func rollback_silent(backup: Dictionary) -> Dictionary:
	return _owner.rollback_restore_silent(backup)

func finalize() -> Dictionary:
	return _owner.finalize_restore()

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
