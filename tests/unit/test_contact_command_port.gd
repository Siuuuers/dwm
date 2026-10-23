extends "res://addons/gut/test.gd"

const PORT_PATH := "res://scripts/application/contact/ContactCommandPort.gd"
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")


class ContactStateSpy:
	extends RefCounted
	var identity_issuer: Object = null
	var calls: Array[Dictionary] = []

	func configure_identity_issuer(candidate: Object) -> Dictionary:
		if identity_issuer != null and identity_issuer != candidate:
			return {"ok": false, "code": &"identity_issuer_already_configured", "message": "", "details": {}}
		var already := identity_issuer != null
		identity_issuer = candidate
		return {"ok": true, "code": &"ok", "value": {
			"issuer_instance_id": candidate.get_instance_id(), "already_configured": already,
		}, "receipt": {}}

	func open_contact(friend_id: String, command_id: String,
			command_issuer_receipt: Dictionary) -> Dictionary:
		calls.append({"method": "open_contact", "friend_id": friend_id,
			"command_id": command_id, "command_issuer_receipt": command_issuer_receipt.duplicate(true)})
		return {"ok": true, "code": &"ok", "value": {"receipt": {}, "replayed": false}, "receipt": {}}

	func reply_invitation(friend_id: String, command_id: String,
			command_issuer_receipt: Dictionary) -> Dictionary:
		calls.append({"method": "reply_invitation", "friend_id": friend_id,
			"command_id": command_id, "command_issuer_receipt": command_issuer_receipt.duplicate(true)})
		return {"ok": true, "code": &"ok", "value": {"receipt": {}, "replayed": false}, "receipt": {}}


func _port_script() -> Script:
	if not FileAccess.file_exists(PORT_PATH):
		return null
	return load(PORT_PATH)


func _issuer() -> RefCounted:
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(FAKE_ROOT.new("33".repeat(32), 19)).get("ok", false))
	return issuer


func test_contact_command_port_exists_at_the_application_boundary() -> void:
	assert_true(FileAccess.file_exists(PORT_PATH),
		"RED: Task 3 must create the semantic ContactCommandPort")


func test_port_issues_and_verifies_one_full_root_before_delegating_semantic_input() -> void:
	var script := _port_script()
	if script == null:
		return
	var port: RefCounted = script.new()
	var issuer := _issuer()
	var state := ContactStateSpy.new()
	assert_true(port.configure(state, issuer).get("ok", false))
	var result: Dictionary = port.request_open_contact("sylvia")
	assert_true(result.get("ok", false), str(result))
	assert_eq(state.calls.size(), 1)
	var call: Dictionary = state.calls[0]
	assert_eq(call["method"], "open_contact")
	assert_eq(call["friend_id"], "sylvia")
	assert_eq(call["command_id"], call["command_issuer_receipt"]["token"])
	assert_eq(call["command_issuer_receipt"]["purpose"], "transaction_id")
	assert_eq(call["command_issuer_receipt"].keys().size(), 6)


func test_port_configuration_is_identity_stable_and_reply_delegates_only_group_semantics() -> void:
	var script := _port_script()
	if script == null:
		return
	var port: RefCounted = script.new()
	var issuer := _issuer()
	var state := ContactStateSpy.new()
	var first: Dictionary = port.configure(state, issuer)
	assert_true(first.get("ok", false), str(first))
	assert_true(port.configure(state, issuer).get("value", {}).get("already_configured", false))
	assert_false(port.configure(ContactStateSpy.new(), issuer).get("ok", true))
	assert_false(port.configure(state, _issuer()).get("ok", true))
	var reply: Dictionary = port.request_reply_invitation("priscilla")
	assert_true(reply.get("ok", false), str(reply))
	assert_eq(state.calls[-1]["method"], "reply_invitation")


func test_issue_failure_returns_before_game_state_is_called() -> void:
	var script := _port_script()
	if script == null:
		return
	var root := FAKE_ROOT.new("44".repeat(32), 4)
	root.fail_next_issue()
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(root).get("ok", false))
	var state := ContactStateSpy.new()
	var port: RefCounted = script.new()
	assert_true(port.configure(state, issuer).get("ok", false))
	var result: Dictionary = port.request_open_contact("priscilla")
	assert_false(result.get("ok", true))
	assert_eq(state.calls, [], "a failed durable issue never reaches GameState")
