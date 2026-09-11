class_name ScheduleCommandPort
extends RefCounted

## Zero-argument Schedule Done command owner used by ScheduleApp. It freezes one issued root and
## the exact displayed docket until the command either opens a warning or reaches Done dispatch.

const _VIEW_METHODS: Array[String] = [
	"snapshot", "fingerprint", "request_warning_activation",
]
const _COMMIT_METHODS: Array[String] = [
	"prepare_commit", "capture", "commit", "rollback", "publish",
]

var _view_controller: Object = null
var _warning_context: Object = null
var _identity_issuer: Object = null
var _commit_port: Object = null
var _done_dispatcher: Object = null
var _registry_fingerprint := ""
var _inflight: Dictionary = {}


func configure(view_controller: Object, warning_context: Object, identity_issuer: Object,
		commit_port: Object, done_dispatcher: Object, registry_fingerprint: String) -> Dictionary:
	if not _has_methods(view_controller, _VIEW_METHODS):
		return _fail(&"invalid_schedule_view_controller")
	if not _has_methods(warning_context, ["snapshot_for"]):
		return _fail(&"invalid_schedule_warning_context")
	if not _has_methods(identity_issuer, ["issue"]):
		return _fail(&"invalid_schedule_identity_issuer")
	if not _has_methods(commit_port, _COMMIT_METHODS):
		return _fail(&"invalid_schedule_commit_port")
	if not _has_methods(done_dispatcher, ["dispatch_done"]):
		return _fail(&"invalid_schedule_done_dispatcher")
	if registry_fingerprint.strip_edges().is_empty():
		return _fail(&"invalid_schedule_registry_fingerprint")
	if _view_controller != null:
		if _view_controller == view_controller and _warning_context == warning_context \
				and _identity_issuer == identity_issuer and _commit_port == commit_port \
				and _done_dispatcher == done_dispatcher \
				and _registry_fingerprint == registry_fingerprint:
			return _ok({"configured": true, "already_configured": true})
		return _fail(&"schedule_command_port_already_configured")
	_view_controller = view_controller
	_warning_context = warning_context
	_identity_issuer = identity_issuer
	_commit_port = commit_port
	_done_dispatcher = done_dispatcher
	_registry_fingerprint = registry_fingerprint
	return _ok({"configured": true, "already_configured": false})


## Suitable for ScheduleApp.configure_presentation(done_handler=...): no arguments, one typed result.
func dispatch_done() -> Dictionary:
	if _view_controller == null:
		return _fail(&"schedule_command_port_unconfigured")
	if _inflight.is_empty():
		var begun := _begin_command()
		if not begun.get("ok", false):
			return begun
	return _resume_command()


func _begin_command() -> Dictionary:
	var captured: Variant = _view_controller.call(&"snapshot")
	if not _is_success_with_dictionary(captured, "view"):
		return _typed_result(captured, &"invalid_schedule_view_snapshot")
	var view: Variant = (captured as Dictionary)["value"]["view"]
	if typeof(view) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_view_snapshot")
	var view_map := view as Dictionary
	if typeof(view_map.get("day")) != TYPE_INT \
			or typeof(view_map.get("causal_day_instance")) != TYPE_STRING \
			or str(view_map.get("causal_day_instance", "")).is_empty() \
			or typeof(view_map.get("entries")) != TYPE_ARRAY:
		return _fail(&"invalid_schedule_view_snapshot")

	var fingerprinted: Variant = _view_controller.call(&"fingerprint")
	if not _is_success_with_dictionary(fingerprinted, "fingerprint"):
		return _typed_result(fingerprinted, &"invalid_schedule_view_fingerprint")
	var view_fingerprint: Variant = (fingerprinted as Dictionary)["value"]["fingerprint"]
	if typeof(view_fingerprint) != TYPE_STRING or str(view_fingerprint).is_empty():
		return _fail(&"invalid_schedule_view_fingerprint")

	var contextualized: Variant = _warning_context.call(&"snapshot_for", view_map.duplicate(true))
	if not _is_success_with_dictionary(contextualized, "context"):
		return _typed_result(contextualized, &"invalid_schedule_warning_context")
	var context: Variant = (contextualized as Dictionary)["value"]["context"]
	if typeof(context) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_warning_context")

	var issued: Variant = _identity_issuer.call(&"issue", &"transaction_id")
	if not _is_success_with_dictionary(issued, "token") \
			or not ((issued as Dictionary)["value"] as Dictionary).has("issuer_receipt"):
		return _typed_result(issued, &"invalid_schedule_transaction")
	var token: Variant = (issued as Dictionary)["value"]["token"]
	var issuer_receipt: Variant = (issued as Dictionary)["value"]["issuer_receipt"]
	if typeof(token) != TYPE_STRING or str(token).is_empty() \
			or typeof(issuer_receipt) != TYPE_DICTIONARY \
			or (issuer_receipt as Dictionary).is_empty():
		return _fail(&"invalid_schedule_transaction")

	_inflight = {
		"transaction_id": str(token),
		"transaction_issuer_receipt": (issuer_receipt as Dictionary).duplicate(true),
		"view": view_map.duplicate(true),
		"view_fingerprint": str(view_fingerprint),
		"context": (context as Dictionary).duplicate(true),
		"phase": &"warning",
	}
	return _ok({"begun": true})


func _resume_command() -> Dictionary:
	if _inflight["phase"] == &"warning":
		var activated: Variant = _view_controller.call(&"request_warning_activation",
			_inflight["transaction_id"], _inflight["transaction_issuer_receipt"],
			_inflight["context"])
		if not _is_success_with_dictionary(activated, "warning"):
			return _typed_result(activated, &"invalid_schedule_warning_activation")
		var warning: Variant = (activated as Dictionary)["value"]["warning"]
		if warning != null:
			if typeof(warning) != TYPE_DICTIONARY:
				return _fail(&"invalid_schedule_warning_activation")
			_inflight = {}
			return activated as Dictionary
		_inflight["phase"] = &"prepare"

	if _inflight["phase"] == &"prepare":
		var prepared: Variant = _commit_port.call(&"prepare_commit", {
			"transaction_id": _inflight["transaction_id"],
			"transaction_issuer_receipt":
				(_inflight["transaction_issuer_receipt"] as Dictionary).duplicate(true),
			"expected_view_fingerprint": _inflight["view_fingerprint"],
			"day": int((_inflight["view"] as Dictionary)["day"]),
			"causal_day_instance":
				str((_inflight["view"] as Dictionary)["causal_day_instance"]),
			"draft_entries":
				((_inflight["view"] as Dictionary)["entries"] as Array).duplicate(true),
			"registry_fingerprint": _registry_fingerprint,
		})
		if not _is_success_with_dictionary(prepared, "game_state_candidate"):
			var refusal := _typed_result(prepared, &"invalid_schedule_commit_preparation")
			# Affordability refuses before creating a candidate or charging Motivation.
			# The player may amend the docket; their next Done must capture that draft.
			if not refusal.get("ok", false) and refusal.get("code") == &"insufficient_motivation":
				_inflight = {}
			return refusal
		var prepared_value := (prepared as Dictionary)["value"] as Dictionary
		if typeof(prepared_value.get("game_state_candidate")) != TYPE_DICTIONARY \
				or typeof(prepared_value.get("committed_schedule")) != TYPE_DICTIONARY \
				or typeof(prepared_value.get("schedule_commit_receipt")) != TYPE_DICTIONARY:
			return _fail(&"invalid_schedule_commit_preparation")
		_inflight["prepared"] = prepared_value.duplicate(true)
		_inflight["phase"] = &"prepared"

	if _inflight["phase"] == &"prepared":
		var captured: Variant = _commit_port.call(&"capture")
		if not _is_success_with_dictionary(captured, "backup"):
			return _typed_result(captured, &"invalid_schedule_commit_backup")
		var backup: Variant = (captured as Dictionary)["value"]["backup"]
		if typeof(backup) != TYPE_DICTIONARY:
			return _fail(&"invalid_schedule_commit_backup")
		var committed: Variant = _commit_port.call(&"commit",
			(_inflight["prepared"] as Dictionary)["game_state_candidate"])
		if not _is_success(committed):
			return _typed_result(committed, &"invalid_schedule_commit_result")
		_inflight["backup"] = (backup as Dictionary).duplicate(true)
		_inflight["phase"] = &"committed"

	if _inflight["phase"] == &"committed":
		var prepared_value := _inflight["prepared"] as Dictionary
		var published: Variant = _commit_port.call(&"publish", {
			"committed_schedule":
				(prepared_value["committed_schedule"] as Dictionary).duplicate(true),
			"schedule_commit_receipt":
				(prepared_value["schedule_commit_receipt"] as Dictionary).duplicate(true),
		})
		if not _is_success(published):
			var rolled_back: Variant = _commit_port.call(&"rollback",
				(_inflight["backup"] as Dictionary).duplicate(true))
			if not _is_success(rolled_back):
				return _typed_result(rolled_back, &"invalid_schedule_rollback_result")
			_inflight.erase("backup")
			_inflight["phase"] = &"prepared"
			return _typed_result(published, &"invalid_schedule_publish_result")
		_inflight.erase("backup")
		_inflight["phase"] = &"published"

	var done_result: Variant = _done_dispatcher.call(&"dispatch_done",
		str(_inflight["transaction_id"]) + ":resolution")
	if typeof(done_result) != TYPE_DICTIONARY:
		return _fail(&"invalid_schedule_done_result")
	if (done_result as Dictionary).get("ok", false):
		_inflight = {}
	return done_result as Dictionary


static func _has_methods(target: Object, methods: Array) -> bool:
	if target == null:
		return false
	for method_name: Variant in methods:
		if not target.has_method(str(method_name)):
			return false
	return true


static func _is_success(result: Variant) -> bool:
	return typeof(result) == TYPE_DICTIONARY and (result as Dictionary).get("ok", false)


static func _is_success_with_dictionary(result: Variant, field: String) -> bool:
	return _is_success(result) and typeof((result as Dictionary).get("value")) == TYPE_DICTIONARY \
		and ((result as Dictionary)["value"] as Dictionary).has(field)


static func _typed_result(result: Variant, fallback_code: StringName) -> Dictionary:
	if typeof(result) == TYPE_DICTIONARY:
		return result as Dictionary
	return _fail(fallback_code)


static func _ok(value: Dictionary) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value, "receipt": {}}


static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": "", "details": {}}
