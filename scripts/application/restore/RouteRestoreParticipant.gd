class_name RouteRestoreParticipant
extends RefCounted

## Restore participant wrapping SceneRouter's semantic route + target-layout
## readiness (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
## apply_silent does not succeed until the registered target scene reports its
## narrative layout ready, and returns the route-ready token the narrative
## participant validates before touching Dialogic.

var _owner: Object = null
var _desktop_host: Object = null
var _desktop_backup: Dictionary = {}

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
	if _desktop_host != null and input.has("active_app_id") and input.has("day"):
		_desktop_backup = _desktop_host.get_state().duplicate(true)
		var restored: Dictionary = _desktop_host.prepare_restore(input["active_app_id"], int(input["day"]))
		if not restored.get("ok", false):
			return restored
		value["desktop"] = restored.get("value", {})
	return {"ok": true, "code": &"ok", "value": value}

func capture() -> Dictionary:
	return _owner.capture_restore_state()

func apply_silent(plan: Dictionary) -> Dictionary:
	# Succeeds only once the registered target scene reports its narrative layout
	# ready; the returned route_ready_token gates the narrative participant.
	var applied: Dictionary = _owner.apply_route_restore_silent(plan)
	if not applied.get("ok", false):
		return applied
	if _desktop_host != null and plan.has("desktop"):
		var candidate: Dictionary = plan["desktop"].get("candidate_state", {})
		var day: int = int(candidate.get("current_day", 1))
		var active: Variant = candidate.get("active_app_id", null)
		if active != null:
			var opened: Dictionary = _desktop_host.open_app(StringName(active), day)
			if not opened.get("ok", false):
				return opened
	return applied

func rollback_silent(backup: Dictionary) -> Dictionary:
	var rolled: Dictionary = _owner.rollback_restore_silent(backup)
	if not rolled.get("ok", false):
		return rolled
	if _desktop_host != null and not _desktop_backup.is_empty():
		# Reconstruct the captured host state deterministically from its get_state() snapshot.
		var captured: Dictionary = _desktop_backup.duplicate(true)
		var day: int = int(captured.get("current_day", 1))
		_desktop_host.reset(day)
		for cached_id in captured.get("cached_app_ids", []):
			var reopened: Dictionary = _desktop_host.open_app(StringName(cached_id), day)
			if not reopened.get("ok", false):
				return reopened
		var active: Variant = captured.get("active_app_id", null)
		if active != null:
			var reopened: Dictionary = _desktop_host.open_app(StringName(active), day)
			if not reopened.get("ok", false):
				return reopened
		else:
			var closed: Dictionary = _desktop_host.close_app()
			if not closed.get("ok", false):
				return closed
		_desktop_backup = {}
	return rolled

func finalize() -> Dictionary:
	return _owner.finalize_restore()

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
