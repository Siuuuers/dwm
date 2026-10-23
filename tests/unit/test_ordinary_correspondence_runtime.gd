extends "res://addons/gut/test.gd"

const GAME := preload("res://autoload/GameState.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ORDINARY := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const FOLLOWUPS := preload("res://scripts/domain/contact/Day7FollowupState.gd")
const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SNAPSHOT := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const VIEW := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const CHECKPOINT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/CheckpointJournal.gd")
const AUDIO := {"ambience_context": {}, "ambience_context_id": "", "music_context": {}, "music_context_id": ""}

# Fault injection stays below the real checkpoint owner: write_atomic genuinely succeeds,
# then the very next physical read fails and invalidates JsonFileStorage's lease.
class FinalRereadFailureStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var fail_next_final_reread := false
	var injected := false
	var durable_failed_text := ""
	func write_atomic(relative_path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary:
		var result: Dictionary = super.write_atomic(relative_path, text, validator, keep_backup)
		if fail_next_final_reread and result.get("ok", false) and relative_path == "autosave.json":
			fail_next_final_reread = false
			injected = true
			durable_failed_text = text
			_file_ops.fail_after(_file_ops.operation_count() + 1)
		return result

class Manager extends RefCounted:
	var _journal := JOURNAL.new()
	var _storage: RefCounted
	var _restore_participants := {}

class CheckpointInputs extends RefCounted:
	var game: Node
	func _checkpoint_inputs(lifecycle: Dictionary) -> Dictionary:
		var input: Dictionary = game.capture_run_snapshot_input()
		input["lifecycle"] = lifecycle.duplicate(true)
		input["schedule_view"] = VIEW.make_empty(int(lifecycle.day), str(lifecycle.causal_day_instance)).value.view
		return {"snapshot_input": input, "dialogic_checkpoint": {}, "route_id": "main", "active_app_id": null,
			"audio_context": AUDIO.duplicate(true), "content_version": 1}

# This out-of-tree fixture executes the actual production writer, including its compensation.
# Only owner discovery and pure checkpoint inputs are supplied locally; startup is never run.
class Writer extends "res://autoload/ApplicationBootstrap.gd":
	var game: Node
	var gate: RefCounted
	var port: RefCounted
	var saved: Array[Dictionary] = []
	var calls := 0
	func _target(target_name: StringName) -> Node:
		return game if target_name == &"GameState" else null
	func write() -> Dictionary:
		calls += 1
		if not gate.is_internal_owner_active(&"causal_transaction"):
			return {"ok": false, "code": &"fixture_checkpoint_custody_missing"}
		_retained_checkpoint_port = port
		if _retained_day_resolution_state_port == null:
			var inputs := CheckpointInputs.new()
			inputs.game = game
			_retained_day_resolution_state_port = inputs
		var committed: Dictionary = _commit_presentation_checkpoint("main")
		if committed.get("ok", false):
			var current: Dictionary = port._journal().get_current_bundle()
			saved.append(current.value.bundle.snapshot.duplicate(true))
		return committed

func _wired() -> Dictionary:
	var root := ROOT.new()
	assert_true(root.configure(STORAGE.new("ordinary-issuer", FakeFileOps.new()),
		preload("res://tests/support/FakeDesktopNamespaceSource.gd").new("72".repeat(32))).ok)
	assert_true(root.load_or_create().ok)
	var issuer := ISSUER.new()
	assert_true(issuer.configure(root).ok)
	var run: Dictionary = issuer.issue(&"run_id").value
	var branch: Dictionary = issuer.issue(&"branch_id").value
	var causal: Dictionary = root.issue(&"causal_day_instance").value
	var game: Node = autofree(GAME.new())
	game.reset_game()
	var gate := GATE.new()
	assert_true(game.configure_mutation_gate(gate).ok)
	assert_true(game.configure_identity_issuer(issuer).ok)
	var prepared: Dictionary = game.prepare_new_run_snapshot_input(run.token, branch.token, 0,
		causal.token, causal.issuer_receipt, false)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return {}
	prepared.value.snapshot_input["schedule_view"] = VIEW.make_empty(1, causal.token).value.view
	var built: Dictionary = SNAPSHOT.build(prepared.value.snapshot_input, {}, "main", null, AUDIO.duplicate(true), 1, 1)
	assert_true(built.ok, str(built))
	if not built.ok: return {}
	var files := FakeFileOps.new()
	var manager := Manager.new()
	manager._storage = STORAGE.new("ordinary-run", files)
	assert_true(manager._journal.reset(run.token).ok)
	var checkpoint := CHECKPOINT.new(manager)
	assert_true(checkpoint.configure_fatal_latch(gate).ok)
	var writer: Node = autofree(Writer.new())
	writer.game = game
	writer.gate = gate
	writer.port = checkpoint
	assert_true(game.configure_contact_checkpoint_writer(writer.write).ok)
	var f := {"game": game, "gate": gate, "issuer": issuer, "root": root,
		"files": files, "manager": manager, "writer": writer}
	_install(f, built.value.snapshot, &"new_run")
	return f

func _install(f: Dictionary, snapshot: Dictionary, custody: StringName = &"restore") -> void:
	var session: Dictionary = f.game.capture_live_session().value
	var operation: Dictionary = f.issuer.issue(&"transaction_id").value
	var ticket := {"operation_id": operation.token, "expected_generation": session.generation,
		"owner_id": session.owner_id, "run_id": snapshot.run_id}
	var lease: Dictionary = f.gate.acquire(custody)
	assert_true(lease.ok, str(lease))
	assert_true(f.game.apply_restore_silent({"snapshot": snapshot}).ok)
	assert_true(f.game.activate_live_session(ticket).ok)
	assert_true(f.gate.release(custody, lease.value.token).ok)
	assert_true(f.game.validate_live_session(f.game.capture_live_session().value).ok)

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

func test_reply_full_checkpoint_failure_rolls_back_exactly_then_same_command_retries_once() -> void:
	var f := _wired()
	if f.is_empty(): return
	var command := _preview(f, 1)
	if command.is_empty(): return
	var before: Dictionary = f.game.capture_restore_state().value.backup
	var files: Dictionary = f.files.snapshot_persisted()
	var journal: Dictionary = f.manager._journal.capture_state()
	f.files.fail_after(f.files.operation_count() + 1)
	var failed: Dictionary = f.game.commit_ordinary_reply(command, command.rendered_line)
	assert_false(failed.ok, str(failed))
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_eq(f.files.snapshot_persisted(), files)
	assert_eq(f.manager._journal.capture_state(), journal)
	assert_false(f.gate.is_active())
	assert_true(f.game.commit_ordinary_reply(command, command.rendered_line).ok)
	assert_eq(f.writer.saved.size(), 1)
	assert_eq(f.writer.saved[0].contacts, f.game.contacts)
	assert_eq(f.game.get_pending_ordinary_echoes().size(), 1)
	var writes: int = f.writer.calls
	assert_true(f.game.commit_ordinary_reply(command, command.rendered_line).ok)
	assert_eq(f.writer.calls, writes)
	assert_eq(f.game.capture_restore_state().value.backup.gameplay, before.gameplay, "ordinary correspondence changes no gameplay stats")

func test_reply_rejects_wrong_issuer_stale_session_changed_contacts_and_unrendered_line() -> void:
	var f := _wired()
	if f.is_empty(): return
	var command := _preview(f, 1)
	if command.is_empty(): return
	var before: Dictionary = f.game.capture_restore_state().value.backup
	for field: String in ["command_issuer_receipt", "live_session", "source_contacts_sha256"]:
		var wrong := command.duplicate(true)
		if field == "command_issuer_receipt": wrong[field]["token"] = "forged"
		elif field == "live_session": wrong[field]["generation"] += 1
		else: wrong[field] = "0".repeat(64)
		assert_false(f.game.commit_ordinary_reply(wrong, command.rendered_line).ok, field)
	var line: Dictionary = command.rendered_line.duplicate(true)
	line["text"] += " changed"
	assert_false(f.game.commit_ordinary_reply(command, line).ok)
	var forged := command.duplicate(true)
	forged["rendered_line"] = line
	assert_false(f.game.commit_ordinary_reply(forged, line).ok, "self-consistent forged command must fail registered line validation")
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_eq(f.writer.saved.size(), 0)
	var held: Dictionary = f.gate.acquire(&"causal_transaction")
	assert_false(f.game.commit_ordinary_reply(command, command.rendered_line).ok)
	assert_true(f.gate.release(&"causal_transaction", held.value.token).ok)

func test_echo_accepts_only_oldest_registered_atom_and_failed_full_checkpoint_keeps_it_pending() -> void:
	var f := _wired()
	if f.is_empty(): return
	if _choose(f, 1).is_empty() or _choose(f, 2).is_empty(): return
	f.game._lifecycle_set_playing_day(7)
	var later := _echo(f, 1)
	assert_false(f.game.commit_ordinary_echo(later.command, later.receipt).ok)
	var first := _echo(f)
	var forged := first.duplicate(true)
	forged.command["presentation_atom_id"] = "atom.forged"
	forged.receipt["presentation_atom_id"] = "atom.forged"
	assert_false(f.game.commit_ordinary_echo(forged.command, forged.receipt).ok)
	var before: Dictionary = f.game.capture_restore_state().value.backup
	f.files.fail_after(f.files.operation_count() + 1)
	var failed: Dictionary = f.game.commit_ordinary_echo(first.command, first.receipt)
	assert_false(failed.ok, str(failed))
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_eq(f.game.get_pending_ordinary_echoes().size(), 2)
	var retry: Dictionary = f.game.commit_ordinary_echo(first.command, first.receipt)
	assert_true(retry.ok, str(retry))
	if not retry.ok:
		gut.p("Injected failure result: " + str(failed))
		gut.p("Storage trace: " + str(f.files.operation_trace()))
		return
	assert_eq(f.game.get_pending_ordinary_echoes().size(), 1)
	var writes: int = f.writer.calls
	assert_true(f.game.commit_ordinary_echo(first.command, first.receipt).ok)
	assert_eq(f.writer.calls, writes)
	assert_false(f.game.commit_ordinary_echo(later.command, later.receipt).ok, "old Contacts hash cannot jump to newly exposed second echo")
	var second := _echo(f)
	assert_true(f.game.commit_ordinary_echo(second.command, second.receipt).ok)
	assert_true(f.game.get_pending_ordinary_echoes().is_empty())

func test_restored_earlier_snapshot_owns_its_pending_echoes_and_rejects_old_session_without_profile_change() -> void:
	var f := _wired()
	if f.is_empty(): return
	var profile: Node = get_node("/root/ProfileManager")
	var profile_before: Dictionary = profile.get_profile_snapshot()
	if _choose(f, 1).is_empty(): return
	var selected: Dictionary = f.writer.saved.back().duplicate(true)
	if _choose(f, 2).is_empty(): return
	f.game._lifecycle_set_playing_day(7)
	var stale := _echo(f)
	assert_true(f.game.commit_ordinary_echo(stale.command, stale.receipt).ok)
	_install(f, selected)
	assert_eq(f.game.get_pending_ordinary_echoes().size(), 1)
	assert_eq(f.game.get_pending_ordinary_echoes()[0].day, 1)
	f.game._lifecycle_set_playing_day(7)
	assert_false(f.game.commit_ordinary_echo(stale.command, stale.receipt).ok)
	var resumed := _echo(f)
	assert_true(f.game.commit_ordinary_echo(resumed.command, resumed.receipt).ok)
	assert_true(f.game.get_pending_ordinary_echoes().is_empty())
	assert_eq(profile.get_profile_snapshot(), profile_before)

func test_followup_ack_uses_registered_source_rolls_back_and_only_advances_read_watermark() -> void:
	var f := _wired()
	if f.is_empty(): return
	_due_solo(f)
	var command := _followup(f)
	assert_eq(command.receipt.entry_id, "contact.invitation.solo.priscilla.day6.nevermind")
	assert_true(SIGNATURE.entry_record(command.receipt.entry_id).ok)
	var before: Dictionary = f.game.capture_restore_state().value.backup
	var forged: Dictionary = command.receipt.duplicate(true)
	forged["entry_id"] = "contact.invitation.group.priscilla_lavinia.day6.nevermind_priscilla"
	assert_false(f.game.commit_day7_followup(command.command, forged).ok)
	f.files.fail_after(f.files.operation_count() + 1)
	assert_false(f.game.commit_day7_followup(command.command, command.receipt).ok)
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_true(f.game.commit_day7_followup(command.command, command.receipt).ok)
	var expected: Dictionary = before.contacts.duplicate(true)
	expected.read_watermarks.priscilla = command.command.sequence
	assert_eq(f.game.contacts, expected, "no invitation acceptance, effect, receipt kind, or queued message")
	assert_eq(f.game.capture_restore_state().value.backup.gameplay, before.gameplay)
	assert_true(f.game.get_pending_day7_followups().is_empty())

func test_reusing_ordinary_transaction_id_cannot_falsely_acknowledge_followup() -> void:
	var f := _wired()
	if f.is_empty(): return
	var reply := _choose(f, 1)
	if reply.is_empty(): return
	_due_solo(f)
	var card := _followup(f)
	card.command["command_id"] = reply.command_id
	card.command["command_issuer_receipt"] = reply.command_issuer_receipt.duplicate(true)
	card.receipt["view_token"] = reply.command_id
	var before: Dictionary = f.game.contacts.duplicate(true)
	assert_false(f.game.commit_day7_followup(card.command, card.receipt).ok)
	assert_eq(f.game.contacts, before)

func test_cached_schedule_commit_cannot_skip_pending_echo_and_succeeds_after_drain() -> void:
	var f := _wired()
	if f.is_empty(): return
	if _choose(f, 1).is_empty(): return
	f.game._lifecycle_set_playing_day(7)
	var aggregate: Dictionary = f.game._canonical_committed_schedule()
	var motivation: int = f.game.get_stat("motivation")
	# Structurally exact candidate prepared against current Schedule/motivation; Contacts is
	# intentionally absent from this old fingerprint, so the new explicit guard is essential.
	var candidate := {"before_fingerprint": f.game._schedule_commit_fingerprint(motivation, aggregate),
		"motivation": motivation, "committed_schedule": aggregate.duplicate(true)}
	assert_eq(f.game.commit_schedule_commit_candidate(candidate).code, &"day7_presentations_pending")
	var echo := _echo(f)
	assert_true(f.game.commit_ordinary_echo(echo.command, echo.receipt).ok)
	assert_true(f.game.commit_schedule_commit_candidate(candidate).ok)

func test_group_followup_entry_uses_saved_supersession_and_registered_day6_source() -> void:
	var f := _wired()
	if f.is_empty(): return
	for friend: String in ["priscilla", "lavinia"]:
		var offered: Dictionary = CONTACTS.prepare_offer_solo(f.game.contacts, friend, 6,
			"solo:%s:day6" % friend, "offer:" + friend)
		assert_true(offered.ok, str(offered))
		if not offered.ok: return
		f.game.contacts = offered.value.candidate
	var activated: Dictionary = CONTACTS.prepare_activate_group_after_round(f.game.contacts, 6, 2, 3, "group:day6")
	assert_true(activated.ok, str(activated))
	if not activated.ok: return
	var resolved: Dictionary = CONTACTS.prepare_resolve_day_end(activated.value.candidate, 6, {}, "close:day6")
	assert_true(resolved.ok, str(resolved))
	if not resolved.ok: return
	var state: Dictionary = resolved.value.candidate
	for row: Dictionary in FOLLOWUPS.pending_day7_followups(state):
		var entry: String = FOLLOWUPS.entry_id_for(state, row)
		assert_eq(entry, "contact.invitation.group.priscilla_lavinia.day6.busy_" + row.friend_id)
		assert_true(SIGNATURE.entry_record(entry).ok)
		var missing := state.duplicate(true)
		missing.solo_actions.erase("solo:%s:day6" % row.friend_id)
		assert_eq(FOLLOWUPS.entry_id_for(missing, row), "")

func test_direct_echo_command_cannot_skip_due_followup_even_with_legitimate_current_proof() -> void:
	var f := _wired()
	if f.is_empty(): return
	if _choose(f, 1).is_empty(): return
	_due_solo(f)
	var echo := _echo(f)
	var before: Dictionary = f.game.capture_restore_state().value.backup
	var writes: int = f.writer.calls
	var refused: Dictionary = f.game.commit_ordinary_echo(echo.command, echo.receipt)
	assert_eq(refused.code, &"day7_followups_pending", str(refused))
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_eq(f.writer.calls, writes)
	var followup := _followup(f)
	assert_true(f.game.commit_day7_followup(followup.command, followup.receipt).ok)
	var current := _echo(f)
	assert_true(f.game.commit_ordinary_echo(current.command, current.receipt).ok)
	assert_true(f.game.require_day7_presentations_complete().ok)

func test_missing_saved_followup_source_cannot_authorize_matching_empty_entry_id() -> void:
	var f := _wired()
	if f.is_empty(): return
	_due_solo(f)
	# A malformed source never becomes presentation authority, even when the caller
	# mirrors the empty projection. The source-specific refusal precedes candidate save.
	f.game.contacts.solo_actions.erase("solo:priscilla:day6")
	var card := _followup(f)
	assert_eq(card.receipt.entry_id, "")
	var before: Dictionary = f.game.contacts.duplicate(true)
	var writes: int = f.writer.calls
	var refused: Dictionary = f.game.commit_day7_followup(card.command, card.receipt)
	assert_eq(refused.code, &"day7_followup_source_mismatch", str(refused))
	assert_eq(f.game.contacts, before)
	assert_eq(f.writer.calls, writes)

func test_final_reread_failure_restores_existing_autosave_and_cancelled_reply_cannot_resurrect() -> void:
	_assert_final_reread_compensation(true)

func test_final_reread_failure_removes_first_autosave_and_cancelled_reply_cannot_resurrect() -> void:
	_assert_final_reread_compensation(false)

func _assert_final_reread_compensation(prior_save_exists: bool) -> void:
	var f := _wired()
	if f.is_empty(): return
	var storage := FinalRereadFailureStorage.new("ordinary-run", f.files)
	f.manager._storage = storage
	if prior_save_exists:
		var lease: Dictionary = f.gate.acquire(&"causal_transaction")
		assert_true(lease.ok, str(lease))
		var seeded: Dictionary = f.writer.write()
		assert_true(seeded.ok, str(seeded))
		assert_true(f.gate.release(&"causal_transaction", lease.value.token).ok)
		if not seeded.ok: return
	var files_before: Dictionary = f.files.snapshot_persisted()
	var prior_text := ""
	if prior_save_exists:
		prior_text = (files_before["ordinary-run/autosave.json"] as PackedByteArray).get_string_from_utf8()
	var command_port: RefCounted = preload("res://scripts/application/contact/ContactCommandPort.gd").new()
	assert_true(command_port.configure(f.game, f.issuer).ok)
	var prepared: Dictionary = command_port.prepare_ordinary_reply("lavinia", "reply.ordinary.lavinia.day1.a")
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var command: Dictionary = prepared.value.command
	var before: Dictionary = f.game.capture_restore_state().value.backup
	var journal_before: Dictionary = f.manager._journal.capture_state()
	var saved_count: int = f.writer.saved.size()
	storage.fail_next_final_reread = true
	var failed: Dictionary = command_port.acknowledge_ordinary_reply(command, command.rendered_line)
	assert_false(failed.ok, str(failed))
	assert_true(storage.injected and storage.durable_failed_text.contains(command.command_id),
		"the fault follows a genuinely durable outgoing reply, not preparation or validation")
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_eq(f.manager._journal.capture_state(), journal_before)
	assert_eq(f.writer.saved.size(), saved_count)
	assert_false(f.gate.is_fatal_latched(), str(failed))
	assert_false(f.gate.is_active(), str(failed))
	assert_eq(command_port.get_pending_ordinary_reply().value.command, command)
	assert_true(command_port.cancel_pending_ordinary_reply(command).ok)
	assert_true(command_port.get_pending_ordinary_reply().value.is_empty())
	# The public save picker resolves only the canonical final file. A fresh storage instance
	# proves recovery cannot select the failed outgoing content from an auxiliary .bak artifact.
	var fresh: RefCounted = STORAGE.new("ordinary-run", f.files)
	var reconciled: Dictionary = fresh.reconcile("autosave.json", f.writer.port._document_text_validator)
	assert_true(reconciled.ok, str(reconciled))
	if not reconciled.ok: return
	assert_eq(reconciled.exists, prior_save_exists)
	if prior_save_exists:
		var read: Dictionary = fresh.read_text("autosave.json")
		assert_true(read.ok, str(read))
		if not read.ok: return
		assert_eq(read.value, prior_text, "compensation restores the exact previous Autosave bytes")
		var restored_snapshot: Dictionary = reconciled.value.current_snapshot.snapshot
		assert_eq(restored_snapshot.contacts, before.contacts)
		_install(f, restored_snapshot)
		assert_true(f.game.get_pending_ordinary_echoes().is_empty(), "fresh Load cannot resurrect the cancelled choice")
		assert_false(f.game.contacts.transaction_receipts.has(command.command_id))
	else:
		assert_false(fresh.exists("autosave.json"), "first-save compensation restores absence")
		assert_true(f.game.get_pending_ordinary_echoes().is_empty())
