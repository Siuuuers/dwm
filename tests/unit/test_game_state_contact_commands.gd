extends "res://addons/gut/test.gd"
## Retained calendar-domain commands only. Lifecycle presence is explicit fixture
## state; the sink captures contacts, with no save schema, storage or restore claim.
const GAME := preload("res://autoload/GameState.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ORDINARY := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const FOLLOWUPS := preload("res://scripts/domain/contact/Day7FollowupState.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

var _ordinary_registry := preload("res://tests/support/RetainedOrdinaryRegistryFixture.gd").new()

func before_each() -> void:
	var installed: Dictionary = _ordinary_registry.install()
	assert_true(installed.get("ok", false), str(installed))

func after_each() -> void:
	_ordinary_registry.restore()

func _wired() -> Dictionary:
	var issuer := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd").new()
	var root := preload("res://tests/support/FakeDesktopIssuerRootStore.gd").new("72".repeat(32), 1)
	assert_true(issuer.configure(root).ok)
	var game: Node = autofree(GAME.new())
	game.reset_game()
	var gate := preload("res://scripts/application/transaction/ApplicationMutationGate.gd").new()
	assert_true(game.configure_mutation_gate(gate).ok)
	assert_true(game.configure_identity_issuer(issuer).ok)
	var run: Dictionary = issuer.issue(&"run_id").value
	var branch: Dictionary = issuer.issue(&"branch_id").value
	var causal: Dictionary = root.issue(&"causal_day_instance").value
	game._run_lifecycle.reset(run.token, branch.token, 0, causal.token,
		{"causal_day_instance_issuer_receipt": causal.issuer_receipt}, false)
	game._run_configuration_installed = true
	var session: Dictionary = game.capture_live_session().value
	var operation: Dictionary = issuer.issue(&"transaction_id").value
	var lease: Dictionary = gate.acquire(&"new_run")
	assert_true(lease.ok)
	assert_true(game.activate_live_session({"operation_id": operation.token,
		"expected_generation": session.generation, "owner_id": session.owner_id, "run_id": run.token}).ok)
	assert_true(gate.release(&"new_run", lease.value.token).ok)
	var saved: Array = []
	assert_true(game.configure_contact_checkpoint_writer(func() -> Dictionary:
		saved.append(game.contacts.duplicate(true))
		return {"ok": true}).ok)
	return {"game": game, "gate": gate, "issuer": issuer, "saved": saved}

func _preview(f: Dictionary, day: int, choice: int = 0) -> Dictionary:
	f.game._lifecycle_set_playing_day(day)
	var friend: String = ORDINARY.DAYS[day]
	var available: Dictionary = ORDINARY.available(f.game.contacts, day, friend, "en")
	assert_true(available.ok, str(available))
	if not available.ok or available.value.is_empty(): return {}
	var issued: Dictionary = f.issuer.issue(&"transaction_id").value
	var preview: Dictionary = f.game.preview_ordinary_reply(friend, available.value.choices[choice].reply_id,
		"en", issued.token, issued.issuer_receipt)
	assert_true(preview.ok, str(preview))
	return preview.value.command if preview.ok else {}

func _choose(f: Dictionary, day: int) -> Dictionary:
	var command := _preview(f, day)
	if command.is_empty(): return {}
	var result: Dictionary = f.game.commit_ordinary_reply(command, command.rendered_line)
	assert_true(result.ok, str(result))
	return command

func _base_command(f: Dictionary) -> Dictionary:
	var issued: Dictionary = f.issuer.issue(&"transaction_id").value
	return {"command_id": issued.token, "command_issuer_receipt": issued.issuer_receipt,
		"live_session": f.game.capture_live_session().value,
		"source_contacts_sha256": str(JSON_WRITER.stringify(f.game.contacts).value).sha256_text()}

func _echo(f: Dictionary, index: int = 0) -> Dictionary:
	var pending: Array = f.game.get_pending_ordinary_echoes()
	var row: Dictionary = pending[index]
	var command := _base_command(f)
	command.merge({"echo_id": row.echo_id, "presentation_atom_id": row.presentation_atom_id})
	return {"command": command, "receipt": {"entry_id": "echo.fallback.day7", "view_token": command.command_id,
		"echo_id": row.echo_id, "presentation_atom_id": row.presentation_atom_id}}

func _followup(f: Dictionary) -> Dictionary:
	var row: Dictionary = f.game.get_pending_day7_followups()[0]
	var command := _base_command(f)
	command.merge({"friend_id": row.friend_id, "message_id": row.message.message_id, "sequence": row.message.sequence})
	return {"command": command, "receipt": {"kind": "day7_followup", "view_token": command.command_id,
		"entry_id": FOLLOWUPS.entry_id_for(f.game.contacts, row), "friend_id": row.friend_id,
		"message_id": row.message.message_id, "sequence": row.message.sequence}}

func _due_solo(f: Dictionary) -> void:
	var offered: Dictionary = CONTACTS.prepare_offer_solo(f.game.contacts, "priscilla", 6, "solo:priscilla:day6", "offer-day6")
	assert_true(offered.ok, str(offered))
	if not offered.ok: return
	var resolved: Dictionary = CONTACTS.prepare_resolve_day_end(offered.value.candidate, 6, {}, "close-day6")
	assert_true(resolved.ok, str(resolved))
	if resolved.ok: f.game.contacts = resolved.value.candidate
	f.game._lifecycle_set_playing_day(7)

func test_retained_reply_then_echo_commit_once_through_the_contact_owner() -> void:
	var f := _wired()
	var command := _choose(f, 1)
	if command.is_empty(): return
	assert_eq(f.saved.size(), 1)
	assert_eq(f.saved[0], f.game.contacts)
	assert_true(f.game.commit_ordinary_reply(command, command.rendered_line).ok)
	assert_eq(f.saved.size(), 1)
	assert_eq(f.game.get_pending_ordinary_echoes().size(), 1)
	f.game._lifecycle_set_playing_day(7)
	assert_eq(f.game.require_day7_presentations_complete().code, &"day7_presentations_pending")
	var echo := _echo(f)
	var result: Dictionary = f.game.commit_ordinary_echo(echo.command, echo.receipt)
	assert_true(result.ok, str(result))
	assert_true(f.game.get_pending_ordinary_echoes().is_empty())
	assert_eq(f.saved.size(), 2)
	assert_eq(f.saved.back(), f.game.contacts)
	assert_true(f.game.commit_ordinary_echo(echo.command, echo.receipt).ok)
	assert_eq(f.saved.size(), 2)
	assert_true(f.game.require_day7_presentations_complete().ok)

func test_retained_followup_commit_advances_only_its_read_watermark() -> void:
	var f := _wired()
	_due_solo(f)
	assert_eq(f.game.get_pending_day7_followups().size(), 1)
	var shown := _followup(f)
	var before: Dictionary = f.game.contacts.duplicate(true)
	var result: Dictionary = f.game.commit_day7_followup(shown.command, shown.receipt)
	assert_true(result.ok, str(result))
	assert_eq(f.saved.size(), 1)
	before.read_watermarks[shown.command.friend_id] = shown.command.sequence
	assert_eq(f.game.contacts, before)
	assert_eq(f.saved[0], before)
	assert_true(f.game.get_pending_day7_followups().is_empty())
	assert_true(f.game.require_day7_presentations_complete().ok)
