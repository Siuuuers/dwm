extends GutTest
const GAME := preload("res://autoload/GameState.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const HOSPITAL := preload("res://scripts/domain/hospital/HospitalRules.gd")
const CONDITION := preload("res://scripts/application/run/ConditionHospitalContactsAdapter.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const COMMAND := preload("res://scripts/application/contact/ContactCommandPort.gd")
const PRESENTATION := preload("res://scripts/application/contact/ContactsPresentationPort.gd")
const COPY := preload("res://scripts/application/contact/ProvisionalCorrespondenceCatalog.gd")

class Writer extends RefCounted:
	var game: Node
	var gate: RefCounted
	var fail_next := false
	var saved: Array[Dictionary] = []
	func write() -> Dictionary:
		if not gate.is_internal_owner_active(&"causal_transaction"):
			return {"ok": false, "code": &"care_lease_missing"}
		var checked: Dictionary = CONTACTS.validate_state(game.contacts)
		if not checked.ok: return checked
		if fail_next:
			fail_next = false
			return {"ok": false, "code": &"fixture_care_checkpoint_failure"}
		saved.append(game.capture_restore_state().value.backup)
		return {"ok": true}

func _wired() -> Dictionary:
	var files := FakeFileOps.new()
	var root := ROOT.new()
	assert_true(root.configure(STORAGE.new("care-issuer", files),
		preload("res://tests/support/FakeDesktopNamespaceSource.gd").new("64".repeat(32))).ok)
	assert_true(root.load_or_create().ok)
	var issuer := ISSUER.new()
	assert_true(issuer.configure(root).ok)
	var game: Node = autofree(GAME.new())
	game.reset_game()
	var gate := GATE.new()
	assert_true(game.configure_mutation_gate(gate).ok)
	var command := COMMAND.new()
	assert_true(command.configure(game, issuer).ok)
	var writer := Writer.new()
	writer.game = game
	writer.gate = gate
	assert_true(game.configure_contact_checkpoint_writer(writer.write).ok)
	var presentation := PRESENTATION.new()
	assert_true(presentation.configure(game, command, COPY.build()).ok)
	return {"game": game, "gate": gate, "issuer": issuer, "root": root,
		"writer": writer, "command": command, "presentation": presentation}

func _offer(f: Dictionary, day: int, friend_id: String = "sylvia") -> Dictionary:
	var action := "solo:%s:day%d" % [friend_id, day]
	var offered: Dictionary = CONTACTS.prepare_offer_solo(f.game.contacts, friend_id, day, action, "offer." + action)
	assert_true(offered.ok, str(offered))
	if offered.ok: f.game.contacts = offered.value.candidate
	return offered

func _witness(f: Dictionary, source_day: int, condition: bool = false) -> String:
	if not _offer(f, source_day).ok: return ""
	var action := "solo:sylvia:day%d" % source_day
	var issued: Dictionary = f.issuer.issue(&"transaction_id").value
	# Isolate the Hospital producer prerequisite. Care consumption is exercised separately
	# through the public command/presentation path in every test below.
	var accepted: Dictionary = CONTACTS._prepare_invitation_open(f.game.contacts, "sylvia", source_day,
		issued.token, issued.issuer_receipt, f.issuer, f.game._schedule_action_record(action))
	assert_true(accepted.ok, str(accepted))
	if not accepted.ok: return ""
	f.game.contacts = accepted.value.candidate
	var source_id: String = accepted.receipt.receipt_id
	var transaction: Dictionary = f.issuer.issue(&"transaction_id").value
	var witness_id: String
	if condition:
		var resolution: Dictionary = f.issuer.derive_child({"parent_receipt_id": transaction.issuer_receipt.receipt_id,
			"child_kind": "hospital_resolution", "ordinal": 0, "source_ids": ["fixture-real-hospital"]})
		assert_true(resolution.ok, str(resolution))
		if not resolution.ok: return ""
		var plan := {"source_day": source_day, "accepted_sources": [{"receipt_id": source_id, "action_id": action}],
			"resolution_receipt": {"receipt_id": resolution.value.child_id, "receipt_provenance": resolution.value.provenance}}
		var prepared: Dictionary = CONDITION.prepare(f.game.contacts, plan, f.issuer)
		assert_true(prepared.ok, str(prepared))
		if not prepared.ok: return ""
		f.game.contacts = prepared.value.contacts
		witness_id = prepared.value.output.sylvia_witness.receipt_id
	else:
		var planned: Dictionary = HOSPITAL.plan_resolution({"required": true, "source_day": source_day,
			"committed_entries": [{"slot_index": 0, "action_kind": "solo", "participants": ["sylvia"],
				"schedule_entry_id": "fixture-schedule-entry-" + str(source_day), "action_id": action, "source_receipt_id": source_id}]})
		assert_true(planned.ok, str(planned))
		if not planned.ok: return ""
		witness_id = str(transaction.token) + ":hospital_if_triggered"
		f.game.contacts.sylvia_hospital_witness_receipts[witness_id] = planned.value.witness
		var closed: Dictionary = CONTACTS.prepare_resolve_day_end(f.game.contacts, source_day, {}, str(transaction.token) + ":close")
		assert_true(closed.ok, str(closed))
		if not closed.ok: return ""
		f.game.contacts = closed.value.candidate
	assert_true(CONTACTS.validate_state(f.game.contacts).ok)
	return witness_id

func _care_messages(game: Node) -> Array:
	return game.contacts.messages.sylvia.filter(func(message: Dictionary) -> bool: return message.type == "hospital_care")

func test_care_is_prospective_no_choice_copy_until_next_day_and_projection_has_no_effect() -> void:
	var f := _wired()
	assert_false(_witness(f, 1).is_empty())
	var before: Dictionary = f.game.capture_restore_state().value.backup
	assert_eq(CONTACTS.get_pending_sylvia_care(f.game.contacts, 1), [])
	assert_eq(_care_messages(f.game), [])
	assert_false(f.command.request_open_contact("sylvia").ok, "same-day premature read has no effect")
	assert_eq(f.game.capture_restore_state().value.backup, before)
	f.game._lifecycle_set_playing_day(2)
	before = f.game.capture_restore_state().value.backup
	var view: Dictionary = f.presentation.get_projection("sylvia")
	assert_true(view.ok, str(view))
	if not view.ok: return
	assert_false(view.value.reply_required)
	assert_true(view.value.unread.sylvia)
	var care_entries: Array = view.value.entries.filter(func(entry: Dictionary) -> bool: return entry.id == "care.sylvia.day2")
	assert_eq(care_entries.size(), 1, "care remains present beside the independent ordinary message")
	if not care_entries.is_empty(): assert_false(str(care_entries[0].texts.en).is_empty())
	assert_eq(view.value.ordinary_choices.size(), 3)
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_eq(f.writer.saved.size(), 0)

func test_care_and_current_invitation_preflight_rollback_and_commit_as_one_candidate() -> void:
	var f := _wired()
	assert_false(_witness(f, 3).is_empty())
	f.game._lifecycle_set_playing_day(4)
	assert_true(_offer(f, 4).ok)
	var before: Dictionary = f.game.capture_restore_state().value.backup
	var incomplete := COPY.build()
	incomplete.erase("care.sylvia.day4")
	var refused := PRESENTATION.new()
	assert_true(refused.configure(f.game, f.command, incomplete).ok)
	assert_false(refused.open_friend("sylvia").ok)
	assert_eq(f.game.capture_restore_state().value.backup, before)
	f.writer.fail_next = true
	var failed: Dictionary = f.presentation.open_friend("sylvia")
	assert_eq(failed.get("code"), &"fixture_care_checkpoint_failure", str(failed))
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_false(f.gate.is_active())
	var completed: Dictionary = f.presentation.open_friend("sylvia")
	assert_true(completed.ok, str(completed))
	if not completed.ok: return
	assert_eq(f.writer.saved.size(), 1)
	assert_eq(f.game.contacts.solo_actions["solo:sylvia:day4"].state, "ACCEPTED")
	assert_eq(_care_messages(f.game).size(), 1)
	assert_eq(f.game.affection.sylvia, int(before.gameplay.affection.sylvia) + 2)
	assert_eq(f.game.dating_route_state.sylvia.dark_points, 1)
	assert_eq(f.game.dating_route_state.sylvia.relationship_state, "ambiguous")
	assert_eq(f.game.friend_attitude.sylvia, "fixated")
	assert_true(CONTACTS.validate_state(f.game.contacts).ok)
	assert_true(f.presentation.open_friend("sylvia").ok)
	assert_eq(f.writer.saved.size(), 1)

func test_care_only_replay_and_fresh_loaded_owner_do_not_repeat_or_add_board_or_invitation_truth() -> void:
	var f := _wired()
	assert_false(_witness(f, 1).is_empty())
	f.game._lifecycle_set_playing_day(2)
	var before: Dictionary = f.game.capture_restore_state().value.backup
	var command: Dictionary = f.issuer.issue(&"transaction_id").value
	var result: Dictionary = f.game.open_contact("sylvia", command.token, command.issuer_receipt)
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_false(f.game.daily_opened_contacts.has("day:2:friend:sylvia"))
	assert_eq(f.game._desktop_snapshot, before.desktop)
	assert_eq(f.game.dating_route_state.sylvia.date_count, before.gameplay.dating_route_state.sylvia.date_count)
	assert_eq(f.game.route_context, before.gameplay.route_context)
	assert_true(f.game.open_contact("sylvia", command.token, command.issuer_receipt).value.replayed)
	assert_eq(f.writer.saved.size(), 1)
	var restored: Node = autofree(GAME.new())
	restored.reset_game()
	assert_true(restored.rollback_restore_silent(f.writer.saved[0]).ok)
	assert_true(restored.configure_identity_issuer(f.issuer).ok)
	var after: Dictionary = restored.capture_restore_state().value.backup
	assert_true(restored.open_contact("sylvia", command.token, command.issuer_receipt).value.replayed)
	assert_eq(restored.capture_restore_state().value.backup, after)
	assert_eq(CONTACTS.get_pending_sylvia_care(restored.contacts, 2), [])
	assert_eq(CONTACTS.get_unread_count(restored.contacts, "sylvia", 2), 0)

func test_independent_witnesses_each_advance_once_with_caps_and_no_date_count() -> void:
	var f := _wired()
	var first: String = _witness(f, 1)
	var second: String = _witness(f, 3, true)
	assert_ne(first, second)
	f.game._lifecycle_set_playing_day(4)
	f.game.affection.sylvia = 9
	f.game.dating_route_state.sylvia.dark_points = 3
	f.game.dating_route_state.sylvia.date_count = 5
	f.game.dating_route_state.sylvia.relationship_state = "friend"
	var result: Dictionary = f.presentation.open_friend("sylvia")
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(f.game.affection.sylvia, 10)
	assert_eq(f.game.dating_route_state.sylvia.dark_points, 4)
	assert_eq(f.game.dating_route_state.sylvia.relationship_state, "love")
	assert_eq(f.game.dating_route_state.sylvia.date_count, 5)
	assert_eq(_care_messages(f.game).size(), 2)
	assert_eq(f.game.contacts.sylvia_hospital_witness_receipts.size(), 2, "handoffs stay immutable")
	assert_true(f.presentation.open_friend("sylvia").ok)
	assert_eq(f.writer.saved.size(), 1)

func test_one_witness_advances_ambiguous_to_love_and_keeps_love_at_low_affection() -> void:
	for tier: String in ["ambiguous", "love"]:
		var f := _wired()
		assert_false(_witness(f, 1).is_empty())
		f.game._lifecycle_set_playing_day(2)
		f.game.affection.sylvia = -4
		f.game.dating_route_state.sylvia.relationship_state = tier
		var read: Dictionary = f.presentation.open_friend("sylvia")
		assert_true(read.ok, str(read))
		if not read.ok: return
		assert_eq(f.game.affection.sylvia, -2)
		assert_eq(f.game.dating_route_state.sylvia.relationship_state, "love")

func test_changed_source_fixed_amount_or_consumed_history_is_refused() -> void:
	for field: String in ["source_receipt_id", "affection_delta", "care_followup_day"]:
		var f := _wired()
		var witness_id: String = _witness(f, 1)
		f.game._lifecycle_set_playing_day(2)
		f.game.contacts.sylvia_hospital_witness_receipts[witness_id][field] = "foreign-source" if field == "source_receipt_id" else 3
		var before: Dictionary = f.game.capture_restore_state().value.backup
		assert_false(f.command.request_open_contact("sylvia").ok, field)
		assert_eq(f.game.capture_restore_state().value.backup, before)
	var f := _wired()
	var witness_id: String = _witness(f, 1)
	f.game._lifecycle_set_playing_day(2)
	assert_true(f.presentation.open_friend("sylvia").ok)
	var changed: Dictionary = f.game.contacts.duplicate(true)
	changed.sylvia_hospital_witness_receipts[witness_id].schedule_entry_id += ".changed"
	assert_false(CONTACTS.validate_state(changed).ok, "consumed history retains the exact witness bytes")

func test_foreign_causal_custody_and_changed_condition_proof_cannot_commit_care() -> void:
	var f := _wired()
	var witness_id: String = _witness(f, 1, true)
	f.game._lifecycle_set_playing_day(2)
	var command: Dictionary = f.issuer.issue(&"transaction_id").value
	var before: Dictionary = f.game.capture_restore_state().value.backup
	var foreign: Dictionary = f.gate.acquire(&"causal_transaction")
	assert_true(foreign.ok)
	assert_false(f.game.open_contact("sylvia", command.token, command.issuer_receipt).ok)
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_true(f.gate.release(&"causal_transaction", foreign.value.token).ok)
	f.game.contacts.sylvia_hospital_witness_receipts[witness_id].receipt_provenance.parent_receipt_id = "issuer_receipt.foreign"
	assert_false(f.game.open_contact("sylvia", command.token, command.issuer_receipt).ok)
	assert_eq(f.writer.saved.size(), 0)

func test_care_promoted_tier_unlocks_day7_invitation_despite_low_affection() -> void:
	var f := _wired()
	assert_false(_witness(f, 1).is_empty())
	f.game._lifecycle_set_playing_day(2)
	f.game.affection.sylvia = -4
	var read: Dictionary = f.presentation.open_friend("sylvia")
	assert_true(read.ok, str(read))
	if not read.ok: return
	assert_eq(f.game.affection.sylvia, -2)
	assert_eq(f.game.dating_route_state.sylvia.relationship_state, "ambiguous")
	f.game._lifecycle_set_playing_day(7)
	f.game.minesweeper_app_rounds_finished_today = 3
	f.game.minesweeper_round_floor = -1
	var unlocked: Dictionary = f.game.unlock_contact_message_after_minesweeper_finished({})
	assert_eq(unlocked, {"friend_id": "sylvia", "day": 7})
	assert_true(f.game.contacts.solo_actions.has("solo:sylvia:day7"))
	assert_true(f.game.is_date_unlocked("sylvia", 7))
	assert_eq(f.game.affection.sylvia, -2, "eligibility reads never adjust affection")

func test_raw_high_affection_friend_cannot_unlock_any_day7_invitation() -> void:
	var f := _wired()
	f.game._lifecycle_set_playing_day(7)
	f.game.minesweeper_round_floor = -1
	var friends: Array[String] = ["priscilla", "lavinia", "sylvia"]
	for index: int in range(friends.size()):
		var friend_id: String = friends[index]
		f.game.affection[friend_id] = 10
		f.game.dating_route_state[friend_id].relationship_state = "friend"
		f.game.minesweeper_app_rounds_finished_today = index + 1
		assert_eq(f.game.unlock_contact_message_after_minesweeper_finished({}), {}, friend_id)
		assert_false(f.game.contacts.solo_actions.has("solo:%s:day7" % friend_id))
		assert_false(f.game.is_contact_message_unlocked(friend_id, 7))
		# A legacy unlock flag must not bypass the current canonical tier gate.
		f.game.contact_message_unlocks["day:7:friend:" + friend_id] = true
		assert_false(f.game.is_date_unlocked(friend_id, 7))
