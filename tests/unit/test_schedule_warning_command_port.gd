extends "res://addons/gut/test.gd"

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const PORT_PATH := "res://scripts/application/schedule/ScheduleWarningCommandPort.gd"


class ViewOwner extends RefCounted:
	var pending := {
		"activation_id": "activation-1",
		"warning_kind": "unread_invitation",
	}
	var resolutions: Array = []

	func snapshot() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"view": {
			"pending_warning": null if pending == null else pending.duplicate(true),
		}}, "receipt": {}}

	func resolve_warning(transaction_id: String, issuer_receipt: Dictionary,
			resolution: Dictionary) -> Dictionary:
		resolutions.append({
			"transaction_id": transaction_id,
			"issuer_receipt": issuer_receipt.duplicate(true),
			"resolution": resolution.duplicate(true),
		})
		return {"ok": true, "code": &"ok", "value": {
			"receipt": {"terminal_result": resolution["outcome"]},
		}, "receipt": {}}


class Issuer extends RefCounted:
	var calls := 0

	func issue(purpose: StringName) -> Dictionary:
		calls += 1
		var token := "warning-tx-%d" % calls
		return {"ok": true, "code": &"ok", "value": {
			"token": token,
			"issuer_receipt": {
				"receipt_id": "issuer-%d" % calls,
				"token": token,
				"purpose": str(purpose),
			},
		}, "receipt": {}}


class DesktopOwner extends RefCounted:
	var prepare_calls: Array[StringName] = []
	var commit_calls: Array = []
	var prepare_result := {"ok": true, "code": &"ok", "value": {
		"receipt": {
			"navigation_id": "warning-navigation-1",
			"intent": "open_contacts_list",
			"source_app_id": "schedule",
			"target_app_id": "contacts",
			"day": 3,
		},
	}, "receipt": {}}
	var commit_result := {"ok": true, "code": &"ok", "value": {
		"target_app_id": "contacts",
	}, "receipt": {"navigation_id": "warning-navigation-1"}}

	func prepare_warning_navigation(intent: StringName) -> Dictionary:
		prepare_calls.append(intent)
		return prepare_result.duplicate(true)

	func commit_warning_navigation(receipt: Dictionary) -> Dictionary:
		commit_calls.append(receipt.duplicate(true))
		return commit_result.duplicate(true)


var _script: Script
var _view: ViewOwner
var _issuer: Issuer
var _desktop: DesktopOwner
var _port: Object


func before_each() -> void:
	var loaded: Dictionary = PROBE.load_script(PORT_PATH)
	_script = loaded.get("value") if loaded.get("ok", false) else null
	_view = ViewOwner.new()
	_issuer = Issuer.new()
	_desktop = DesktopOwner.new()
	if _script != null:
		_port = _script.new()
		var configured: Dictionary = _port.configure(_view, _issuer, _desktop)
		assert_true(configured.get("ok", false), str(configured))


func _require_port() -> bool:
	assert_not_null(_script, "ScheduleWarningCommandPort must exist")
	assert_not_null(_port, "ScheduleWarningCommandPort must configure")
	return _port != null


func test_dismiss_resolves_the_exact_activation_without_navigation() -> void:
	if not _require_port(): return
	var result: Dictionary = _port.resolve_warning("activation-1", &"dismiss")
	assert_true(result.get("ok", false), str(result))
	assert_eq(_issuer.calls, 1)
	assert_eq(_desktop.prepare_calls, [])
	assert_eq(_desktop.commit_calls, [])
	assert_eq(_view.resolutions, [{
		"transaction_id": "warning-tx-1",
		"issuer_receipt": {"receipt_id": "issuer-1", "token": "warning-tx-1", "purpose": "transaction_id"},
		"resolution": {"outcome": "dismissed"},
	}])


func test_unavailable_go_records_the_real_preflight_failure_and_stays_retryable() -> void:
	if not _require_port(): return
	_desktop.prepare_result = {"ok": false, "code": &"contacts_unavailable", "details": {}}
	var result: Dictionary = _port.resolve_warning("activation-1", &"open_contacts_list")
	assert_true(result.get("ok", false), str(result))
	assert_eq(_desktop.prepare_calls, [&"open_contacts_list"])
	assert_eq(_desktop.commit_calls, [])
	assert_eq(_view.resolutions[0].resolution, {
		"outcome": "navigation_failed",
		"intent": "open_contacts_list",
		"failure_code": "contacts_unavailable",
	})
	assert_eq(_view.pending.activation_id, "activation-1")


func test_successful_go_commits_the_exact_prepared_route_before_recording_success() -> void:
	if not _require_port(): return
	var result: Dictionary = _port.resolve_warning("activation-1", &"open_contacts_list")
	assert_true(result.get("ok", false), str(result))
	assert_eq(_desktop.prepare_calls, [&"open_contacts_list"])
	assert_eq(_desktop.commit_calls, [_desktop.prepare_result.value.receipt])
	assert_eq(_view.resolutions.size(), 1)
	assert_eq(_view.resolutions[0].resolution, {
		"outcome": "navigation_committed",
		"intent": "open_contacts_list",
	})


func test_failed_commit_records_navigation_failed_and_never_claims_committed() -> void:
	if not _require_port(): return
	_desktop.commit_result = {"ok": false, "code": &"desktop_open_rejected", "details": {}}
	var result: Dictionary = _port.resolve_warning("activation-1", &"open_contacts_list")
	assert_true(result.get("ok", false), str(result))
	assert_eq(_desktop.commit_calls.size(), 1)
	assert_eq(_view.resolutions.size(), 1)
	assert_eq(_view.resolutions[0].resolution, {
		"outcome": "navigation_failed",
		"intent": "open_contacts_list",
		"failure_code": "desktop_open_rejected",
	})


func test_wrong_intent_for_live_warning_is_refused_before_identity_or_navigation() -> void:
	if not _require_port(): return
	var result: Dictionary = _port.resolve_warning("activation-1", &"open_minesweeper")
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"warning_intent_mismatch")
	assert_eq(_issuer.calls, 0)
	assert_eq(_desktop.prepare_calls, [])
	assert_eq(_view.resolutions, [])