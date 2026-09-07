extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PORT_PATH := "res://scripts/application/schedule/ScheduleCommandPort.gd"
const REGISTRY_FINGERPRINT := "registry.fixture"


class ViewOwner extends RefCounted:
	var warning: Variant = null
	var activation_calls: Array = []
	var view := {
		"day": 3,
		"causal_day_instance": "causal-day-3",
		"entries": [{"draft_entry_id": "draft-1", "slot_index": 0, "action_id": "training"}],
	}

	func snapshot() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"view": view.duplicate(true)}, "receipt": {}}

	func fingerprint() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"fingerprint": "schedule-view-3"}, "receipt": {}}

	func request_warning_activation(transaction_id: String, issuer_receipt: Dictionary, context: Dictionary) -> Dictionary:
		activation_calls.append({"transaction_id": transaction_id, "issuer_receipt": issuer_receipt.duplicate(true), "context": context.duplicate(true)})
		return {"ok": true, "code": &"ok", "value": {"warning": warning}, "receipt": {}}


class WarningContext extends RefCounted:
	var calls: Array = []
	func snapshot_for(view: Dictionary) -> Dictionary:
		calls.append(view.duplicate(true))
		return {"ok": true, "code": &"ok", "value": {"context": {"day": int(view["day"])}}, "receipt": {}}


class Issuer extends RefCounted:
	var calls := 0
	func issue(purpose: StringName) -> Dictionary:
		calls += 1
		var token := "done-tx-%d" % calls
		return {"ok": true, "code": &"ok", "value": {
			"token": token,
			"issuer_receipt": {"receipt_id": "issuer-%d" % calls, "token": token, "purpose": str(purpose)},
		}, "receipt": {}}


class CommitPort extends RefCounted:
	var prepare_calls: Array = []
	var capture_calls := 0
	var commit_calls := 0
	var rollback_calls: Array = []
	var publish_calls: Array = []
	var publish_results: Array = []

	func prepare_commit(request: Dictionary) -> Dictionary:
		prepare_calls.append(request.duplicate(true))
		return {"ok": true, "code": &"ok", "value": {
			"game_state_candidate": {"candidate": "prepared"},
			"committed_schedule": {"day": int(request["day"]), "transaction_id": str(request["transaction_id"])},
			"schedule_commit_receipt": {"transaction_id": str(request["transaction_id"])},
		}, "receipt": {}}

	func capture() -> Dictionary:
		capture_calls += 1
		return {"ok": true, "code": &"ok", "value": {"backup": {"motivation": 4, "committed_schedule": {}}}, "receipt": {}}

	func commit(candidate: Dictionary) -> Dictionary:
		commit_calls += 1
		return {"ok": true, "code": &"ok", "value": {"candidate": candidate.duplicate(true)}, "receipt": {}}

	func rollback(backup: Dictionary) -> Dictionary:
		rollback_calls.append(backup.duplicate(true))
		return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}

	func publish(publication: Dictionary) -> Dictionary:
		publish_calls.append(publication.duplicate(true))
		if not publish_results.is_empty():
			return publish_results.pop_front()
		return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


class DoneDispatcher extends RefCounted:
	var command_ids: Array[String] = []
	var results: Array = []
	func dispatch_done(command_id: String) -> Dictionary:
		command_ids.append(command_id)
		if not results.is_empty():
			return results.pop_front()
		return {"ok": true, "code": &"plan_complete", "value": {"day": 4}, "receipt": {}}


var _script: Script
var _view: ViewOwner
var _context: WarningContext
var _issuer: Issuer
var _commit: CommitPort
var _dispatcher: DoneDispatcher
var _port: Object


func before_each() -> void:
	var loaded: Dictionary = PROBE.load_script(PORT_PATH)
	_script = loaded.get("value") if loaded.get("ok", false) else null
	_view = ViewOwner.new()
	_context = WarningContext.new()
	_issuer = Issuer.new()
	_commit = CommitPort.new()
	_dispatcher = DoneDispatcher.new()
	if _script != null:
		_port = _script.new()
		var configured: Dictionary = _port.configure(_view, _context, _issuer, _commit, _dispatcher, REGISTRY_FINGERPRINT)
		assert_true(configured.get("ok", false), str(configured))


func _require_port() -> bool:
	assert_not_null(_script, "ScheduleCommandPort must exist")
	assert_not_null(_port, "ScheduleCommandPort must configure")
	return _port != null


func test_warning_is_activated_before_commit_or_dispatch() -> void:
	if not _require_port(): return
	_view.warning = {"activation_id": "warning-1"}
	var expected := {"ok": true, "code": &"ok", "value": {"warning": _view.warning}, "receipt": {}}
	var result: Dictionary = _port.dispatch_done()
	assert_eq(result, expected, "the controller's typed warning outcome is returned unchanged")
	assert_eq(_issuer.calls, 1)
	assert_eq(_view.activation_calls.size(), 1)
	assert_eq(_context.calls, [_view.view])
	assert_eq(_commit.prepare_calls.size(), 0, "a warning does not commit or spend the docket")
	assert_eq(_commit.capture_calls, 0)
	assert_eq(_commit.commit_calls, 0)
	assert_eq(_commit.publish_calls.size(), 0)
	assert_eq(_dispatcher.command_ids, [])


func test_no_warning_commits_and_publishes_the_actual_docket_then_dispatches_done() -> void:
	if not _require_port(): return
	var result: Dictionary = _port.dispatch_done()
	assert_true(result.get("ok", false), str(result))
	assert_eq(result.get("code"), &"plan_complete")
	assert_eq(_commit.prepare_calls.size(), 1)
	var request: Dictionary = _commit.prepare_calls[0]
	assert_eq(request, {
		"transaction_id": "done-tx-1",
		"transaction_issuer_receipt": {"receipt_id": "issuer-1", "token": "done-tx-1", "purpose": "transaction_id"},
		"expected_view_fingerprint": "schedule-view-3",
		"day": 3,
		"causal_day_instance": "causal-day-3",
		"draft_entries": _view.view.entries,
		"registry_fingerprint": REGISTRY_FINGERPRINT,
	})
	assert_eq(_commit.capture_calls, 1)
	assert_eq(_commit.commit_calls, 1)
	assert_eq(_commit.publish_calls, [{
		"committed_schedule": {"day": 3, "transaction_id": "done-tx-1"},
		"schedule_commit_receipt": {"transaction_id": "done-tx-1"},
	}])
	assert_eq(_dispatcher.command_ids, ["done-tx-1:resolution"])


func test_retry_after_done_refusal_reuses_the_published_transaction_without_charging_twice() -> void:
	if not _require_port(): return
	_dispatcher.results = [
		{"ok": false, "code": &"presentation_temporarily_unavailable", "details": {}},
		{"ok": true, "code": &"await_registered_command", "value": {}, "receipt": {}},
	]
	var first: Dictionary = _port.dispatch_done()
	assert_eq(first.get("code"), &"presentation_temporarily_unavailable")
	var second: Dictionary = _port.dispatch_done()
	assert_eq(second.get("code"), &"await_registered_command")
	assert_eq(_issuer.calls, 1, "retry reuses the frozen issued root")
	assert_eq(_view.activation_calls.size(), 1, "warning eligibility is frozen with the command")
	assert_eq(_commit.prepare_calls.size(), 1)
	assert_eq(_commit.capture_calls, 1)
	assert_eq(_commit.commit_calls, 1, "motivation is charged once")
	assert_eq(_commit.publish_calls.size(), 1, "published state is never rolled back or republished")
	assert_eq(_commit.rollback_calls, [])
	assert_eq(_dispatcher.command_ids, ["done-tx-1:resolution", "done-tx-1:resolution"])


func test_failed_publication_rolls_back_unpublished_state_and_retries_the_same_transaction() -> void:
	if not _require_port(): return
	_commit.publish_results = [
		{"ok": false, "code": &"publication_unavailable", "details": {}},
		{"ok": true, "code": &"ok", "value": {}, "receipt": {}},
	]
	var first: Dictionary = _port.dispatch_done()
	assert_eq(first.get("code"), &"publication_unavailable")
	assert_eq(_commit.rollback_calls.size(), 1)
	assert_eq(_dispatcher.command_ids, [])
	var second: Dictionary = _port.dispatch_done()
	assert_true(second.get("ok", false), str(second))
	assert_eq(_issuer.calls, 1)
	assert_eq(_commit.prepare_calls.size(), 1, "the prepared bytes stay frozen")
	assert_eq(_commit.commit_calls, 2, "rollback makes one safe recommit necessary")
	assert_eq(_commit.publish_calls.size(), 2)
	assert_eq(_commit.rollback_calls.size(), 1)
	assert_eq(_dispatcher.command_ids, ["done-tx-1:resolution"])
