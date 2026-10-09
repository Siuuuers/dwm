extends "res://addons/gut/test.gd"
## DEPENDENT suite: compose A's installed successor B2 validator before running.
## Isolated process; real issuer but fake root/in-memory checkpoint, no rendered proof.
const STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const FIXTURE := preload("res://tests/support/SceneContactFixture.gd")
const ECHO := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
var fixture: RefCounted

func before_all() -> void:
	assert_true(FIXTURE.install_registration().get("ok", false), "requires A successor B2 registration admission")

func before_each() -> void:
	fixture = FIXTURE.new()
	assert_true(fixture.setup().ok)

func test_exact_definition_fields_and_fact_ownership() -> void:
	var good: Dictionary = FIXTURE.definitions()
	assert_true(STATE.validate_scene_definitions(good).ok)
	for key: String in ["messages", "replies"]:
		var extra: Dictionary = good.duplicate(true)
		extra[key][0].day = 1
		assert_false(STATE.validate_scene_definitions(extra).ok)
	var duplicate: Dictionary = good.duplicate(true)
	duplicate.replies[0].source_fact_ids = duplicate.messages[0].read_fact_ids.duplicate()
	assert_false(STATE.validate_scene_definitions(duplicate).ok)
	var alias: Dictionary = good.duplicate(true)
	alias.messages[0].friend_id = &"lavinia"
	assert_false(STATE.validate_scene_definitions(alias).ok)

func test_message_read_reply_resolve_only_actual_committed_receipts() -> void:
	assert_true(fixture.emit_message().ok)
	assert_false(STATE.validate_scene_facts(fixture.contacts, ["TEST.fact.read"], fixture.registration, fixture.issuer).ok)
	var port: RefCounted = fixture.make_port()
	assert_true(port.request_open_contact("lavinia").ok)
	var prepared: Dictionary = port.prepare_ordinary_reply("lavinia", "TEST.reply")
	assert_true(prepared.ok)
	assert_false(STATE.validate_scene_facts(fixture.contacts, ["TEST.fact.reply"], fixture.registration, fixture.issuer).ok)
	var command: Dictionary = prepared.value.command
	assert_true(port.acknowledge_ordinary_reply(command, command.rendered_line).ok)
	var facts: Dictionary = STATE.validate_scene_facts(fixture.contacts,
		["TEST.fact.message", "TEST.fact.read", "TEST.fact.reply"], fixture.registration, fixture.issuer)
	assert_true(facts.ok)
	assert_eq(facts.value.receipts.size(), 3)
	assert_eq(fixture.contacts.next_sequence, 3)
	assert_true(STATE.validate_scene_state(fixture.contacts, fixture.registration, fixture.issuer).ok)

func test_preparation_wrong_draw_and_failed_checkpoint_create_no_reply_fact() -> void:
	assert_true(fixture.emit_message().ok)
	var port: RefCounted = fixture.make_port()
	assert_true(port.request_open_contact("lavinia").ok)
	var before: Dictionary = fixture.contacts.duplicate(true)
	var prepared: Dictionary = port.prepare_ordinary_reply("lavinia", "TEST.reply")
	assert_true(prepared.ok)
	var command: Dictionary = prepared.value.command
	var wrong: Dictionary = command.rendered_line.duplicate(true)
	wrong.text = "forged"
	assert_false(port.acknowledge_ordinary_reply(command, wrong).ok)
	fixture.refuse_checkpoint = true
	assert_false(port.acknowledge_ordinary_reply(command, command.rendered_line).ok)
	assert_eq(fixture.contacts, before)
	fixture.refuse_checkpoint = false
	assert_true(port.acknowledge_ordinary_reply(command, command.rendered_line).ok)
	var calls: int = fixture.checkpoint_calls
	assert_true(port.acknowledge_ordinary_reply(command, command.rendered_line).ok)
	assert_eq(fixture.checkpoint_calls, calls, "duplicate ack returns retained result")

func test_selected_session_change_and_preflight_callback_mutation_refuse() -> void:
	assert_true(fixture.emit_message().ok)
	var port: RefCounted = fixture.make_port()
	var before: Dictionary = fixture.contacts.duplicate(true)
	var result: Dictionary = port.request_open_contact("lavinia", func(_preview: Dictionary) -> Dictionary:
		fixture.occurrence = "TEST.changed"
		return {"ok": true})
	assert_false(result.ok)
	assert_eq(fixture.contacts, before)
	assert_true(port.request_open_contact("lavinia").ok)
	var prepared: Dictionary = port.prepare_ordinary_reply("lavinia", "TEST.reply")
	assert_true(prepared.ok)
	fixture.live_session = RefCounted.new()
	assert_false(port.acknowledge_ordinary_reply(prepared.value.command, prepared.value.command.rendered_line).ok)

func test_state_chain_rejects_fact_result_watermark_and_foreign_issuer_forgery() -> void:
	assert_true(fixture.emit_message().ok)
	var original: Dictionary = fixture.contacts.duplicate(true)
	var command: String = original.transaction_receipts.keys()[0]
	for field: String in ["source_fact_ids", "definitions_sha256", "registration_sha256", "result"]:
		var bad: Dictionary = original.duplicate(true)
		bad.transaction_receipts[command][field] = {"wrong": true}
		assert_false(STATE.validate_scene_state(bad, fixture.registration, fixture.issuer).ok, field)
	var changed: Dictionary = original.duplicate(true)
	changed.read_watermarks.lavinia = 1
	assert_false(STATE.validate_scene_state(changed, fixture.registration, fixture.issuer).ok)
	changed = original.duplicate(true)
	changed.transaction_receipts[command].command_issuer_receipt.counter += 1
	assert_false(STATE.validate_scene_state(changed, fixture.registration, fixture.issuer).ok)

func test_projection_does_not_issue_read_or_reply_facts() -> void:
	assert_true(fixture.emit_message().ok)
	var before: Dictionary = fixture.contacts.duplicate(true)
	var port: RefCounted = fixture.make_port()
	var presentation: RefCounted = fixture.make_presentation(port)
	var projected: Dictionary = presentation.get_projection("lavinia")
	assert_true(projected.ok)
	assert_true(projected.value.unread.lavinia)
	assert_eq(projected.value.entries[0].texts.en, "TEST incoming.")
	assert_eq(fixture.contacts, before)
	assert_true(presentation.open_friend("lavinia").ok)
	assert_false(presentation.get_projection("lavinia").value.unread.lavinia)

func test_same_command_replay_and_new_command_duplicate_facts() -> void:
	var command: Dictionary = fixture.command()
	var prepared: Dictionary = STATE.prepare_scene_message(fixture.contacts, "TEST.message", command.command_id,
		command.proof, command.context, fixture.issuer)
	assert_true(fixture.commit_candidate(prepared).ok)
	var replay: Dictionary = STATE.prepare_scene_message(fixture.contacts, "TEST.message", command.command_id,
		command.proof, command.context, fixture.issuer)
	assert_true(replay.ok)
	assert_eq(replay.value.candidate, fixture.contacts)
	fixture.occurrence = "TEST.another"
	assert_false(fixture.emit_message().ok, "same authored fact cannot gain a second operation owner")

func test_scene_rendered_line_requires_exact_strings_and_semantic_identity() -> void:
	var line := {"view_token": "TEST.command", "line_id": "TEST.line", "text": "TEST"}
	assert_true(ECHO.validate_scene_rendered_line("TEST.command", "TEST.line", "TEST", line).ok)
	line.view_token = &"TEST.command"
	assert_false(ECHO.validate_scene_rendered_line("TEST.command", "TEST.line", "TEST", line).ok)

func test_reply_ack_guard_precedes_owner_callbacks_and_checks_live_context_again() -> void:
	assert_true(fixture.emit_message().ok)
	var port: RefCounted = fixture.make_port()
	assert_true(port.request_open_contact("lavinia").ok)
	var prepared: Dictionary = port.prepare_ordinary_reply("lavinia", "TEST.reply")
	assert_true(prepared.ok)
	var command: Dictionary = prepared.value.command
	var nested := {}
	fixture.live_validation_hook = func() -> void:
		nested.result = port.acknowledge_ordinary_reply(command, command.rendered_line)
		fixture.occurrence = "TEST.other"
	var before: Dictionary = fixture.contacts.duplicate(true)
	assert_false(port.acknowledge_ordinary_reply(command, command.rendered_line).ok)
	assert_false(nested.result.ok)
	assert_eq(nested.result.code, &"scene_contact_reentrant")
	assert_eq(fixture.contacts, before)

func test_malformed_public_projection_inputs_refuse_without_nested_access() -> void:
	for invalid: Variant in [null, [], {"bad": 7}]:
		var state: Dictionary = STATE.make_scene_defaults()
		state.transaction_receipts = invalid
		assert_false(STATE.scene_reply_choices(state, "lavinia", "en", fixture.registration).ok)
	var state: Dictionary = STATE.make_scene_defaults()
	state.messages = null
	assert_false(STATE.scene_reply_choices(state, "lavinia", "en", fixture.registration).ok)
	state = STATE.make_scene_defaults()
	state.read_watermarks.lavinia = 1.0
	assert_false(STATE.scene_reply_choices(state, "lavinia", "en", fixture.registration).ok)

func test_calendar_extra_wrong_registration_and_float_generation_refuse() -> void:
	var state: Dictionary = STATE.make_scene_defaults()
	state.solo_actions = {}
	assert_false(STATE.validate_scene_state(state, fixture.registration, fixture.issuer).ok)
	var command: Dictionary = fixture.command()
	command.context.identity.desktop_timeline_generation = 0.0
	assert_false(STATE.prepare_scene_message(fixture.contacts, "TEST.message", command.command_id,
		command.proof, command.context, fixture.issuer).ok)
	assert_false(STATE.validate_scene_facts(fixture.contacts, [], "0".repeat(64), fixture.issuer).ok)

func test_ack_detaches_public_command_and_line_before_live_callback() -> void:
	assert_true(fixture.emit_message().ok)
	var port: RefCounted = fixture.make_port()
	assert_true(port.request_open_contact("lavinia").ok)
	var prepared: Dictionary = port.prepare_ordinary_reply("lavinia", "TEST.reply")
	assert_true(prepared.ok)
	var command: Dictionary = prepared.value.command
	var line: Dictionary = command.rendered_line
	var original_id: String = command.command_id
	fixture.live_validation_hook = func() -> void:
		command.reply_id = "TEST.forged"
		line.text = "TEST altered during callback"
	assert_true(port.acknowledge_ordinary_reply(command, line).ok)
	var saved: Dictionary = fixture.contacts.transaction_receipts[original_id]
	assert_eq(saved.result.reply_id, "TEST.reply")
	assert_eq(saved.result.rendered_line.text, "TEST reply.")
