class_name ScheduleWarningCommandPort
extends RefCounted

## Adapts ScheduleApp's activation/intent callback to the retained warning transaction owner.
## A Go terminal is recorded only after the desktop has opened the requested real app.

const _GO_INTENTS := {
	"unread_invitation": &"open_contacts_list",
	"accepted_date": &"dismiss",
	"base_minesweeper": &"open_minesweeper",
}

var _view_controller: Object = null
var _identity_issuer: Object = null
var _desktop: Object = null


func configure(view_controller: Object, identity_issuer: Object, desktop: Object) -> Dictionary:
	if not _has_methods(view_controller, ["snapshot", "resolve_warning"]):
		return _fail(&"invalid_schedule_warning_owner")
	if not _has_methods(identity_issuer, ["issue"]):
		return _fail(&"invalid_schedule_warning_identity_issuer")
	if not _has_methods(desktop,
			["prepare_warning_navigation", "commit_warning_navigation"]):
		return _fail(&"invalid_schedule_warning_desktop")
	if _view_controller != null:
		if _view_controller == view_controller and _identity_issuer == identity_issuer \
				and _desktop == desktop:
			return _ok({"configured": true, "already_configured": true})
		return _fail(&"schedule_warning_command_port_already_configured")
	_view_controller = view_controller
	_identity_issuer = identity_issuer
	_desktop = desktop
	return _ok({"configured": true, "already_configured": false})


func resolve_warning(activation_id: String, intent: StringName) -> Dictionary:
	if _view_controller == null:
		return _fail(&"schedule_warning_command_port_unconfigured")
	var pending_result := _pending_warning(activation_id, intent)
	if not pending_result.get("ok", false):
		return pending_result
	var issued: Variant = _identity_issuer.call(&"issue", &"transaction_id")
	if not _is_success_value(issued, ["token", "issuer_receipt"]):
		return _typed_result(issued, &"invalid_schedule_warning_transaction")
	var issued_value := (issued as Dictionary)["value"] as Dictionary
	var transaction_id: Variant = issued_value["token"]
	var issuer_receipt: Variant = issued_value["issuer_receipt"]
	if typeof(transaction_id) != TYPE_STRING or str(transaction_id).is_empty() \
			or typeof(issuer_receipt) != TYPE_DICTIONARY \
			or (issuer_receipt as Dictionary).is_empty():
		return _fail(&"invalid_schedule_warning_transaction")
	if intent == &"dismiss":
		return _resolve(str(transaction_id), issuer_receipt as Dictionary,
			{"outcome": "dismissed"})

	var prepared: Variant = _desktop.call(&"prepare_warning_navigation", intent)
	if typeof(prepared) != TYPE_DICTIONARY:
		return _fail(&"invalid_warning_navigation_preparation")
	if not (prepared as Dictionary).get("ok", false):
		return _record_navigation_failure(str(transaction_id), issuer_receipt as Dictionary,
			intent, StringName((prepared as Dictionary).get("code",
				&"warning_navigation_preflight_failed")))
	if not _is_success_value(prepared, ["receipt"]):
		return _fail(&"invalid_warning_navigation_preparation")
	var navigation_receipt: Variant = ((prepared as Dictionary)["value"] as Dictionary)["receipt"]
	if typeof(navigation_receipt) != TYPE_DICTIONARY \
			or (navigation_receipt as Dictionary).is_empty():
		return _fail(&"invalid_warning_navigation_preparation")
	var committed: Variant = _desktop.call(&"commit_warning_navigation",
		(navigation_receipt as Dictionary).duplicate(true))
	if not _is_success(committed):
		var failure_code := &"invalid_warning_navigation_commit"
		if typeof(committed) == TYPE_DICTIONARY:
			failure_code = StringName((committed as Dictionary).get("code", failure_code))
		return _record_navigation_failure(str(transaction_id), issuer_receipt as Dictionary,
			intent, failure_code)
	return _resolve(str(transaction_id), issuer_receipt as Dictionary, {
		"outcome": "navigation_committed",
		"intent": str(intent),
	})


func _pending_warning(activation_id: String, intent: StringName) -> Dictionary:
	if activation_id.is_empty():
		return _fail(&"invalid_warning_activation")
	var captured: Variant = _view_controller.call(&"snapshot")
	if not _is_success_value(captured, ["view"]):
		return _typed_result(captured, &"invalid_schedule_warning_snapshot")
	var view: Variant = ((captured as Dictionary)["value"] as Dictionary)["view"]
	if typeof(view) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_warning_snapshot")
	var pending: Variant = (view as Dictionary).get("pending_warning")
	if typeof(pending) != TYPE_DICTIONARY:
		return _fail(&"no_pending_warning")
	if str((pending as Dictionary).get("activation_id", "")) != activation_id:
		return _fail(&"warning_activation_mismatch")
	var warning_kind := str((pending as Dictionary).get("warning_kind", ""))
	if not _GO_INTENTS.has(warning_kind):
		return _fail(&"invalid_warning_kind")
	if intent != &"dismiss" and intent != _GO_INTENTS[warning_kind]:
		return _fail(&"warning_intent_mismatch")
	return _ok({"warning": (pending as Dictionary).duplicate(true)})


func _record_navigation_failure(transaction_id: String, issuer_receipt: Dictionary,
		intent: StringName, failure_code: StringName) -> Dictionary:
	var code := str(failure_code)
	if code.is_empty():
		code = "warning_navigation_failed"
	return _resolve(transaction_id, issuer_receipt, {
		"outcome": "navigation_failed",
		"intent": str(intent),
		"failure_code": code,
	})


func _resolve(transaction_id: String, issuer_receipt: Dictionary,
		resolution: Dictionary) -> Dictionary:
	var resolved: Variant = _view_controller.call(&"resolve_warning", transaction_id,
		issuer_receipt.duplicate(true), resolution.duplicate(true))
	return _typed_result(resolved, &"invalid_schedule_warning_resolution")


static func _has_methods(target: Object, methods: Array) -> bool:
	if target == null:
		return false
	for method_name: Variant in methods:
		if not target.has_method(str(method_name)):
			return false
	return true


static func _is_success(result: Variant) -> bool:
	return typeof(result) == TYPE_DICTIONARY and (result as Dictionary).get("ok", false)


static func _is_success_value(result: Variant, fields: Array) -> bool:
	if not _is_success(result) or typeof((result as Dictionary).get("value")) != TYPE_DICTIONARY:
		return false
	var value := (result as Dictionary)["value"] as Dictionary
	for field: Variant in fields:
		if not value.has(field):
			return false
	return true


static func _typed_result(result: Variant, fallback_code: StringName) -> Dictionary:
	if typeof(result) == TYPE_DICTIONARY:
		return result as Dictionary
	return _fail(fallback_code)


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": "", "details": {}}