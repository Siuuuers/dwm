extends "res://addons/gut/test.gd"

const PORT := preload("res://scripts/application/contact/ContactCommandPort.gd")
const PRESENTATION := preload("res://scripts/application/contact/ContactsPresentationPort.gd")
const REPLIES := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const FAKE_ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")

class ReplyState:
	extends RefCounted
	var day := 1
	var session := {"generation": 1}
	var contacts: Dictionary = CONTACTS.make_defaults()
	var missed_invitations: Array = []
	var fail_save := false
	var commits := 0
	func configure_identity_issuer(issuer: Object) -> Dictionary:
		return {"ok": true, "value": {"issuer_instance_id": issuer.get_instance_id()}}
	func open_contact(_friend: String, _id: String, _proof: Dictionary) -> Dictionary:
		return {"ok": true}
	func reply_invitation(_friend: String, _id: String, _proof: Dictionary) -> Dictionary:
		return {"ok": true}
	func get_contact_view(friend: String) -> Dictionary:
		return CONTACTS.get_contact_view(contacts, friend, day)
	func validate_live_session(expected: Dictionary) -> Dictionary:
		return {"ok": expected == session, "code": &"stale_session"}
	func preview_ordinary_reply(friend: String, reply: String, locale: String, id: String, proof: Dictionary) -> Dictionary:
		var definition: Dictionary = REPLIES.reply_definition(reply, locale)
		if not definition.ok: return definition
		var line := {"view_token": id, "line_id": definition.value.line_id, "text": definition.value.text}
		var prepared: Dictionary = REPLIES.prepare_reply(contacts, day, reply, locale, id, proof, line)
		if not prepared.ok: return prepared
		prepared.value["command"] = {"command_id": id, "command_issuer_receipt": proof.duplicate(true),
			"live_session": session.duplicate(true), "source_contacts_sha256": JSON.stringify(contacts).sha256_text(),
			"source_day": day, "friend_id": friend, "reply_id": reply, "locale": locale, "rendered_line": line}
		return prepared
	func commit_ordinary_reply(command: Dictionary, line: Dictionary) -> Dictionary:
		commits += 1
		if fail_save: return {"ok": false, "code": &"save_failed"}
		if not validate_live_session(command.live_session).ok or command.source_contacts_sha256 != JSON.stringify(contacts).sha256_text():
			return {"ok": false, "code": &"stale_source"}
		var prepared: Dictionary = REPLIES.prepare_reply(contacts, day, command.reply_id, command.locale,
			command.command_id, command.command_issuer_receipt, line)
		if prepared.ok: contacts = prepared.value.candidate.duplicate(true)
		return prepared

func _fixture() -> Dictionary:
	var issuer: RefCounted = ISSUER.new()
	assert_true(issuer.configure(FAKE_ROOT.new("34".repeat(32), 1)).ok)
	var state := ReplyState.new()
	var port: RefCounted = PORT.new()
	assert_true(port.configure(state, issuer).ok)
	return {"port": port, "state": state}

func test_exact_draw_ack_save_failure_retry_and_duplicate_callback() -> void:
	var deps := _fixture()
	var prepared: Dictionary = deps.port.prepare_ordinary_reply("lavinia", "reply.ordinary.lavinia.day1.a")
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var command: Dictionary = prepared.value.command
	assert_eq(deps.state.commits, 0)
	assert_eq(deps.state.contacts, CONTACTS.make_defaults())
	var forged := command.duplicate(true)
	forged.reply_id = "reply.ordinary.lavinia.day1.b"
	assert_false(deps.port.acknowledge_ordinary_reply(forged, command.rendered_line).ok)
	var wrong_line: Dictionary = command.rendered_line.duplicate(true)
	wrong_line.text = "different line"
	assert_false(deps.port.acknowledge_ordinary_reply(command, wrong_line).ok)
	assert_eq(deps.state.commits, 0)
	deps.state.fail_save = true
	assert_false(deps.port.acknowledge_ordinary_reply(command, command.rendered_line).ok)
	assert_eq(deps.port.get_pending_ordinary_reply().value.command, command)
	assert_false(deps.port.prepare_ordinary_reply("lavinia", "reply.ordinary.lavinia.day1.b").ok)
	assert_eq(deps.port.prepare_ordinary_reply("lavinia", command.reply_id).value.command, command)
	deps.state.fail_save = false
	assert_true(deps.port.acknowledge_ordinary_reply(command, command.rendered_line).ok)
	assert_true(deps.port.acknowledge_ordinary_reply(command, command.rendered_line).ok)
	assert_eq(deps.state.commits, 2, "completed callback is local exact replay")
	assert_eq(deps.state.contacts.messages.lavinia.size(), 3)
	assert_eq(deps.port.get_pending_ordinary_reply().value, {})

func test_leaving_cancels_only_exact_unsaved_preview_and_old_cleanup_cannot_cancel_replacement() -> void:
	var deps := _fixture()
	var first: Dictionary = deps.port.prepare_ordinary_reply("lavinia", "reply.ordinary.lavinia.day1.a")
	assert_true(first.ok, str(first))
	if not first.ok: return
	var command: Dictionary = first.value.command
	assert_true(deps.port.cancel_pending_ordinary_reply(command).ok)
	assert_true(deps.port.cancel_pending_ordinary_reply(command).ok)
	assert_false(deps.port.acknowledge_ordinary_reply(command, command.rendered_line).ok)
	var replacement: Dictionary = deps.port.prepare_ordinary_reply("lavinia", "reply.ordinary.lavinia.day1.b")
	assert_true(replacement.ok, str(replacement))
	if not replacement.ok: return
	assert_ne(command.command_id, replacement.value.command.command_id)
	assert_false(deps.port.cancel_pending_ordinary_reply(command).ok)
	assert_eq(deps.port.get_pending_ordinary_reply().value.command, replacement.value.command)
	assert_eq(deps.state.contacts, CONTACTS.make_defaults())
	assert_eq(deps.state.commits, 0)

func test_load_or_day_change_discards_old_pending_command_and_detached_preview_cannot_mutate_custody() -> void:
	var deps := _fixture()
	var first: Dictionary = deps.port.prepare_ordinary_reply("lavinia", "reply.ordinary.lavinia.day1.a")
	assert_true(first.ok, str(first))
	if not first.ok: return
	var command: Dictionary = first.value.command.duplicate(true)
	first.value.command.rendered_line.text = "caller mutation"
	assert_eq(deps.port.get_pending_ordinary_reply().value.command, command)
	deps.state.session.generation = 2
	assert_false(deps.port.acknowledge_ordinary_reply(command, command.rendered_line).ok)
	assert_eq(deps.port.get_pending_ordinary_reply().value, {})
	var next: Dictionary = deps.port.prepare_ordinary_reply("lavinia", "reply.ordinary.lavinia.day1.c")
	assert_true(next.ok, str(next))
	if not next.ok: return
	deps.state.day = 2
	assert_eq(deps.port.get_pending_ordinary_reply().value, {})
	assert_false(deps.port.acknowledge_ordinary_reply(next.value.command, next.value.command.rendered_line).ok)
	assert_eq(deps.state.commits, 0)

func test_projection_is_read_only_until_ack_then_shows_exact_three_rows_and_no_choices() -> void:
	var deps := _fixture()
	var view: RefCounted = PRESENTATION.new()
	assert_true(view.configure(deps.state, deps.port, {}).ok)
	var initial: Dictionary = view.get_projection("lavinia", "en", "zh-CN")
	assert_true(initial.ok, str(initial))
	if not initial.ok: return
	assert_eq(initial.value.entries.size(), 1)
	assert_eq(initial.value.ordinary_choices.size(), 3)
	assert_true(initial.value.unread.lavinia)
	assert_eq(deps.state.contacts, CONTACTS.make_defaults())
	var prepared: Dictionary = view.prepare_ordinary_reply("lavinia", initial.value.ordinary_choices[1].reply_id)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var command: Dictionary = prepared.value.command
	var shown: Dictionary = view.acknowledge_ordinary_reply(command, command.rendered_line, "en", "zh-CN")
	assert_true(shown.ok, str(shown))
	if not shown.ok: return
	assert_eq(shown.value.entries.size(), 3)
	assert_eq(shown.value.ordinary_choices, [])
	assert_eq(shown.value.entries[1].texts.en, command.rendered_line.text)
	assert_true(shown.value.entries[1].outgoing)
	assert_false(shown.value.entries[0].outgoing)
	assert_false(shown.value.entries[2].outgoing)
	assert_false(shown.value.unread.lavinia)
