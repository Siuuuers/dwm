class_name RouteRestoreParticipant
extends RefCounted

## Restore participant wrapping SceneRouter's semantic route + target-layout
## readiness (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
## SceneRouter owns the route-ready token and physical transition. This participant
## carries the saved desktop host state within the same prepared route transaction.

var _owner: Object = null
var _desktop_host: Object = null

func _init(owner: Object) -> void:
	_owner = owner

## One Bootstrap-owned DesktopAppHostState. When configured, prepare() derives the desktop
## subplan from the supplied active_app_id/day and apply/rollback rebuild the host state
## (dwm-p2r.9 Plan 02 Task 1). A second configuration with the same object is idempotent;
## a different object is rejected.
func configure_desktop_host(host: Object) -> Dictionary:
	if host == null or not host.has_method("prepare_restore") or not host.has_method("get_state") \
			or not host.has_method("reset") or not host.has_method("open_app") \
			or not host.has_method("close_app") or not host.has_method("capture_persistent_state"):
		return _fail(&"invalid_desktop_host", "host must expose the DesktopAppHostState contract")
	if not host.has_method("commit_restore"):
		return _fail(&"invalid_desktop_host", "host must expose explicit restore commit")
	if _desktop_host != null:
		if host == _desktop_host:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"desktop_host_already_configured", "a desktop host is already configured")
	_desktop_host = host
	return {"ok": true, "code": &"ok", "value": {"host_instance_id": _desktop_host.get_instance_id()}, "receipt": {}}

func prepare(input: Dictionary) -> Dictionary:
	if typeof(input.get("route_id")) != TYPE_STRING or str(input["route_id"]).is_empty():
		return _fail(&"invalid_route_input", "route participant requires a route_id")
	if typeof(input.get("route_context")) != TYPE_DICTIONARY:
		return _fail(&"invalid_route_input", "route participant requires a route_context")
	var prepared: Dictionary = _owner.prepare_route_restore(str(input["route_id"]), input["route_context"])
	if not prepared.get("ok", false):
		return prepared
	var value := {"route_plan": prepared.get("value", {})}
	var desktop_context: Dictionary = input["route_context"]
	if input.has("active_app_id") and input.has("day"):
		desktop_context = input
	if _desktop_host != null and desktop_context.has("active_app_id") and desktop_context.has("day"):
		if typeof(desktop_context["day"]) != TYPE_INT:
			return _fail(&"invalid_route_input", "saved desktop day must be an integer")
		var restored: Dictionary = _desktop_host.prepare_restore(desktop_context["active_app_id"], desktop_context["day"])
		if not restored.get("ok", false):
			return restored
		value["route_plan"]["desktop"] = restored["value"]["candidate_state"]
	return {"ok": true, "code": &"ok", "value": value}

func capture() -> Dictionary:
	var captured: Dictionary = _owner.capture_restore_state()
	if captured.get("ok", false) and _desktop_host != null:
		captured["value"]["desktop_backup"] = _desktop_host.get_state().duplicate(true)
	return captured

func apply_silent(plan: Dictionary) -> Dictionary:
	# Preserve SceneRouter's token contract; no scene is instantiated by this adapter.
	var desktop_backup := {}
	if _desktop_host != null and plan.has("desktop"):
		if typeof(plan["desktop"]) != TYPE_DICTIONARY:
			return _fail(&"invalid_route_input", "desktop restore plan must be an object")
		desktop_backup = _desktop_host.get_state().duplicate(true)
		var committed: Dictionary = _desktop_host.commit_restore(plan["desktop"])
		if not committed.get("ok", false):
			return committed
	var applied: Dictionary = _owner.apply_route_restore_silent(plan)
	if not applied.get("ok", false) and not desktop_backup.is_empty():
		var rolled: Dictionary = _desktop_host.commit_restore(desktop_backup)
		if not rolled.get("ok", false):
			return rolled
	return applied

func rollback_silent(backup: Dictionary) -> Dictionary:
	var rolled: Dictionary = _owner.rollback_restore_silent(backup)
	if not rolled.get("ok", false):
		return rolled
	if _desktop_host != null and backup.has("desktop_backup"):
		return _desktop_host.commit_restore(backup["desktop_backup"])
	return rolled

func finalize() -> Dictionary:
	return _owner.finalize_restore()

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
