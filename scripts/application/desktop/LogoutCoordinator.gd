class_name LogoutCoordinator
extends RefCounted

## Desktop Logout continuation (Plan 02 Task 6, dwm-p2r.32, req.desktop.logout), amendment SS9.2.
##
## Logout request is exactly {transaction_id,transaction_issuer_receipt,confirmed} and the receipt
## must ledger-verify (brief line 289). Like RunLifecycle's own desktop-identity check, this object
## has no root-store access, so "ledger-verify" here means the same structural self-consistency law
## used throughout this task: the exact frozen issuer-receipt shape, purpose transaction_id, and a
## token equal to the adjacent transaction_id -- real root-ledger verification happens wherever the
## receipt was originally issued, not here.
##
## confirmed=false is a no-op. A confirmed request awaits only the currently EXECUTING bounded
## board/preparation slice -- never an internal busy-wait/await loop, which would block a whole
## engine frame; instead a slice in progress returns one typed retryable failure
## (logout_busy_bounded_slice) and the caller re-invokes retry_logout() with the same transaction
## identity once it settles. Once idle, the latest stable board is captured, SaveManager.
## save_for_logout() persists the normal logout/autosave document (numbered slots are never
## called), and only a proven committed write routes to the title/menu scene.
##
## stable_board_port's contract is not written down anywhere in the Task-6 brief's own Interfaces
## block; it was frozen by controller ruling on the bead instead (amendment SS9.2 + plan lines
## 984-986):
##   func is_slice_executing() -> Dictionary   # success value = {executing: bool}
##   func capture_stable_board() -> Dictionary # success value = the latest stable board capture
## Production binding for stable_board_port arrives at Task 9; here it is duck-typed and validated
## by configure().

const _ISSUER_RECEIPT_KEYS: Array[String] = ["counter", "namespace", "numeric_value", "purpose", "receipt_id", "token"]
const _REQUEST_KEYS: Array[String] = ["confirmed", "transaction_id", "transaction_issuer_receipt"]

var _save_manager: Object = null
var _route_port: Object = null
var _stable_board_port: Object = null
## transaction_id -> {"transaction_issuer_receipt": Dictionary}. Retained for the lifetime of this
## coordinator so a retry or an identical replay can be told apart from a changed-bytes conflict;
## cancel_logout() is the only way to forget one.
var _transactions: Dictionary = {}


func configure(save_manager: Object, route_port: Object, stable_board_port: Object) -> Dictionary:
	if save_manager == null or not save_manager.has_method("save_for_logout"):
		return _fail(&"invalid_save_manager", "save_manager must expose save_for_logout")
	if route_port == null or not route_port.has_method("goto_menu"):
		return _fail(&"invalid_route_port", "route_port must expose goto_menu")
	if stable_board_port == null or not stable_board_port.has_method("is_slice_executing") \
			or not stable_board_port.has_method("capture_stable_board"):
		return _fail(&"invalid_stable_board_port",
			"stable_board_port must expose is_slice_executing and capture_stable_board")
	if _save_manager != null:
		if _save_manager == save_manager and _route_port == route_port and _stable_board_port == stable_board_port:
			return {"ok": true, "code": &"ok", "value": {"already_configured": true}, "receipt": {}}
		return _fail(&"logout_coordinator_already_configured", "configure may not replace an existing configuration")
	_save_manager = save_manager
	_route_port = route_port
	_stable_board_port = stable_board_port
	return {"ok": true, "code": &"ok", "value": {"already_configured": false}, "receipt": {}}


func request_logout(request: Dictionary) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	var shape := _validate_request(request)
	if not shape.get("ok", false):
		return shape
	var transaction_id := str(request["transaction_id"])
	var receipt: Dictionary = request["transaction_issuer_receipt"]
	if _transactions.has(transaction_id):
		var recorded: Dictionary = _transactions[transaction_id]
		if recorded["transaction_issuer_receipt"] != receipt:
			return _fail(&"logout_transaction_conflict",
				"transaction_id was already used with a different receipt: " + transaction_id)
	else:
		_transactions[transaction_id] = {"transaction_issuer_receipt": receipt.duplicate(true)}
	if not bool(request["confirmed"]):
		return {"ok": true, "code": &"ok", "value": {"confirmed": false, "transaction_id": transaction_id}, "receipt": {}}
	return _attempt_logout(transaction_id)


func retry_logout(transaction_id: String) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if not _transactions.has(transaction_id):
		return _fail(&"logout_transaction_unknown", transaction_id)
	return _attempt_logout(transaction_id)


func cancel_logout(transaction_id: String) -> Dictionary:
	var ready := _require_configured()
	if not ready.get("ok", false):
		return ready
	if not _transactions.has(transaction_id):
		return _fail(&"logout_transaction_unknown", transaction_id)
	_transactions.erase(transaction_id)
	return {"ok": true, "code": &"ok", "value": {"cancelled": true, "transaction_id": transaction_id}, "receipt": {}}


## The one durable side effect, shared by request_logout(confirmed=true) and retry_logout(). Exactly
## one is_slice_executing() probe per call -- never an internal spin -- so a busy slice always
## returns control to the caller instead of blocking.
func _attempt_logout(transaction_id: String) -> Dictionary:
	var executing: Dictionary = _stable_board_port.is_slice_executing()
	if not executing.get("ok", false):
		return executing
	if bool((executing.get("value", {}) as Dictionary).get("executing", false)):
		return _fail(&"logout_busy_bounded_slice",
			"a bounded board/preparation slice is executing; retry_logout once it settles")
	var captured: Dictionary = _stable_board_port.capture_stable_board()
	if not captured.get("ok", false):
		return captured
	var saved: Dictionary = _save_manager.save_for_logout()
	if not saved.get("ok", false):
		# A disk failure keeps the run, board, consequence state, and issuer high-water byte-equal
		# (nothing above this line mutated anything durable); retry reuses this same transaction.
		return {"ok": false, "code": &"logout_save_failed",
			"message": str(saved.get("message", "")), "details": {"cause": saved.get("code", &"")}}
	_route_port.goto_menu()
	return {"ok": true, "code": &"ok", "value": {
		"transaction_id": transaction_id, "routed": true,
		"checkpoint_id": str((saved.get("value", {}) as Dictionary).get("checkpoint_id", "")),
	}, "receipt": {}}


func _require_configured() -> Dictionary:
	if _save_manager == null:
		return _fail(&"logout_coordinator_not_configured", "LogoutCoordinator.configure before use")
	return {"ok": true}


func _validate_request(request: Dictionary) -> Dictionary:
	var keys: Array = request.keys()
	keys.sort()
	var expected := _REQUEST_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return _fail(&"invalid_logout_request", "unexpected request keys: " + str(keys))
	if typeof(request["confirmed"]) != TYPE_BOOL:
		return _fail(&"invalid_logout_request", "confirmed must be a boolean")
	if typeof(request["transaction_id"]) != TYPE_STRING or str(request["transaction_id"]).strip_edges().is_empty():
		return _fail(&"invalid_logout_request", "transaction_id must be nonblank")
	if typeof(request["transaction_issuer_receipt"]) != TYPE_DICTIONARY:
		return _fail(&"invalid_logout_request", "transaction_issuer_receipt must be an object")
	var receipt: Dictionary = request["transaction_issuer_receipt"]
	var receipt_keys: Array = receipt.keys()
	receipt_keys.sort()
	var expected_receipt_keys: Array = _ISSUER_RECEIPT_KEYS.duplicate()
	expected_receipt_keys.sort()
	if receipt_keys != expected_receipt_keys:
		return _fail(&"invalid_logout_request", "transaction_issuer_receipt has an unexpected member set")
	if str(receipt.get("purpose", "")) != "transaction_id":
		return _fail(&"invalid_logout_request", "transaction_issuer_receipt.purpose must be transaction_id")
	if str(receipt.get("token", "")) != str(request["transaction_id"]):
		return _fail(&"invalid_logout_request", "transaction_issuer_receipt.token must equal transaction_id")
	return {"ok": true}


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}
