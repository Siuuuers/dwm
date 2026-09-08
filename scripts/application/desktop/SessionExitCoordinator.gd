class_name SessionExitCoordinator
extends RefCounted
## One owner for confirmed no-save Return and save-then-Logout.
## After retirement, a route failure retains custody and can only retry forward.

const OWNER := &"session_abandonment"
var _game_state: Object
var _saves: Object
var _router: Object
var _gate: Object
var _capture_inputs := Callable()
var _handle: Dictionary = {}
var _pending: Dictionary = {}
var _busy := false
var _retirement := Callable()

func configure(game_state: Object, saves: Object, router: Object, gate: Object,
		capture_inputs: Callable) -> Dictionary:
	if _game_state != null: return {"ok": false, "code": &"exit_already_configured"}
	if not is_instance_valid(game_state) or not is_instance_valid(saves) \
			or not is_instance_valid(router) or not is_instance_valid(gate) \
			or not capture_inputs.is_valid() or capture_inputs.get_argument_count() != 0:
		return {"ok": false, "code": &"invalid_exit_dependencies"}
	var captured: Dictionary = game_state.capture_live_session()
	if not captured.get("ok", false): return captured
	var admitted: Dictionary = game_state.validate_live_session(captured.value)
	if not admitted.get("ok", false): return admitted
	_game_state = game_state
	_saves = saves
	_router = router
	_gate = gate
	_capture_inputs = capture_inputs
	_handle = captured.value.duplicate(true)
	return {"ok": true}

## Optional retained Pause custody cleanup. It runs after irreversible session retirement,
## before route publication; failure keeps the same forward-only exit operation.
func configure_retirement(callback: Callable) -> Dictionary:
	if not callback.is_valid() or callback.get_argument_count() != 0:
		return {"ok": false, "code": &"invalid_exit_retirement"}
	if not _retirement.is_null() and _retirement != callback:
		return {"ok": false, "code": &"exit_retirement_already_configured"}
	_retirement = callback
	return {"ok": true}

func return_to_title(save_before_exit: bool) -> Dictionary:
	if _busy: return {"ok": false, "code": &"exit_busy"}
	if _game_state == null: return {"ok": false, "code": &"exit_unconfigured"}
	_busy = true
	var result := _execute(save_before_exit)
	_busy = false
	return result

func _execute(save_before_exit: bool) -> Dictionary:
	if not _pending.is_empty():
		if _pending.save_before_exit != save_before_exit:
			return {"ok": false, "code": &"exit_retry_mismatch"}
		return _publish_retired()
	var admitted: Dictionary = _game_state.validate_live_session(_handle)
	if not admitted.get("ok", false): return admitted
	var prepared: Dictionary = _router.prepare_return_to_title()
	if not prepared.get("ok", false): return prepared
	var acquired: Dictionary = _gate.acquire(OWNER)
	if not acquired.get("ok", false):
		_router.cancel_prepared_return_to_title(str(prepared.value.token))
		return acquired
	_pending = {"route_token": str(prepared.value.token), "gate_token": str(acquired.value.token),
		"save_before_exit": save_before_exit, "retired": false}
	var valid: Dictionary = _router.validate_prepared_return_to_title(_pending.route_token)
	if not valid.get("ok", false): return _cancel_before_retirement(valid)
	# Recheck the captured lifetime under custody; ordinary external admission is now closed.
	if _game_state.capture_live_session().value != _handle:
		return _cancel_before_retirement({"ok": false, "code": &"stale_live_session"})
	if save_before_exit:
		var inputs: Variant = _capture_inputs.call()
		if not inputs is Dictionary or not inputs.get("ok", false):
			return _cancel_before_retirement(inputs if inputs is Dictionary else {"ok": false, "code": &"exit_capture_failed"})
		var saved: Dictionary = _saves.save_session_exit_checkpoint(inputs.value, _handle)
		if not saved.get("ok", false): return _cancel_before_retirement(saved)
	var retired: Dictionary = _game_state.retire_live_session(_handle)
	if not retired.get("ok", false): return _cancel_before_retirement(retired)
	_pending.retired = true
	return _publish_retired()

func _publish_retired() -> Dictionary:
	if not _retirement.is_null() and not _pending.get("custody_retired", false):
		var retired: Variant = _retirement.call()
		if not retired is Dictionary or not retired.get("ok", false):
			return {"ok": false, "code": &"exit_route_retry_required", "details": {"cause": retired}}
		_pending["custody_retired"] = true
	var published: Dictionary = _router.publish_prepared_return_to_title(_pending.route_token)
	if not published.get("ok", false):
		return {"ok": false, "code": &"exit_route_retry_required", "details": {"cause": published.get("code")}}
	var released: Dictionary = _gate.release(OWNER, _pending.gate_token)
	if not released.get("ok", false): return released
	_pending = {}
	return {"ok": true, "value": {"route_id": "menu"}}

func _cancel_before_retirement(failure: Dictionary) -> Dictionary:
	_router.cancel_prepared_return_to_title(_pending.route_token)
	var released: Dictionary = _gate.release(OWNER, _pending.gate_token)
	_pending = {}
	return failure if released.get("ok", false) else released
