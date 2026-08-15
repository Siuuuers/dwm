extends "res://addons/gut/test.gd"

const CONTACT_APP := preload("res://scripts/ui/ContactListApp.gd")


class CommandPortSpy:
	extends RefCounted
	var calls: Array[Dictionary] = []

	func request_open_contact(friend_id: String) -> Dictionary:
		calls.append({"method": "request_open_contact", "friend_id": friend_id})
		return {"ok": true, "code": &"ok", "value": {"receipt": {}, "replayed": false}, "receipt": {}}

	func request_reply_invitation(friend_id: String) -> Dictionary:
		calls.append({"method": "request_reply_invitation", "friend_id": friend_id})
		return {"ok": true, "code": &"ok", "value": {"receipt": {}, "replayed": false}, "receipt": {}}


func test_contact_scene_exposes_only_the_injected_semantic_port_seam() -> void:
	var app: Node = autofree(CONTACT_APP.new())
	assert_true(app.has_method("configure_command_port"),
		"RED: presentation requires an explicit typed command-port injection seam")
	assert_true(app.has_method("reply_to_group"),
		"RED: presentation names the group-only reply action")


func test_unconfigured_input_fails_closed_and_configured_input_delegates() -> void:
	var app: Node = autofree(CONTACT_APP.new())
	if not app.has_method("configure_command_port") or not app.has_method("reply_to_group"):
		return
	var before: Dictionary = app.call(&"open_friend", "priscilla")
	assert_false(before.get("ok", true))
	assert_eq(before.get("code"), &"contact_command_port_unconfigured")
	var port := CommandPortSpy.new()
	var configured: Dictionary = app.call(&"configure_command_port", port)
	assert_true(configured.get("ok", false), str(configured))
	assert_true(app.call(&"configure_command_port", port).get("value", {}).get("already_configured", false))
	assert_false(app.call(&"configure_command_port", CommandPortSpy.new()).get("ok", true))
	assert_true(app.call(&"open_friend", "priscilla").get("ok", false))
	assert_true(app.call(&"reply_to_group", "lavinia").get("ok", false))
	assert_eq(port.calls, [
		{"method": "request_open_contact", "friend_id": "priscilla"},
		{"method": "request_reply_invitation", "friend_id": "lavinia"},
	])


func test_contact_scene_authors_no_identity_or_global_state_fallback() -> void:
	var source := FileAccess.get_file_as_string("res://scripts/ui/ContactListApp.gd")
	for forbidden: String in [
		"/root", "GameState", "ApplicationBootstrap", "open:", "reply:", "day%d",
		"Time", "randi", "issue(", ".open_contact(", ".reply_invitation(",
	]:
		assert_false(source.contains(forbidden),
			"ContactListApp must not contain presentation-authored identity/global path: " + forbidden)
