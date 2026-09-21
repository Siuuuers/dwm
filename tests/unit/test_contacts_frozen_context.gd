extends "res://addons/gut/test.gd"

const FROZEN := preload("res://scripts/narrative/ContactsFrozenContext.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const ORDINARY := preload("res://scripts/domain/contact/OrdinaryReplyEchoState.gd")
const GAME := preload("res://autoload/GameState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const PORT := preload("res://scripts/application/contact/ContactsPresentationPort.gd")
const SURFACE := preload("res://scripts/ui/Day7PreludeSurface.gd")

class Commands extends RefCounted:
	func request_open_contact(_friend: String, _guard: Callable) -> Dictionary: return {"ok": false}
	func request_reply_invitation(_friend: String) -> Dictionary: return {"ok": false}
	func prepare_ordinary_reply(_friend: String, _reply: String, _locale: String) -> Dictionary: return {"ok": false}

class Writer extends RefCounted:
	var game: Node
	var gate: RefCounted
	var fail := false
	var saved: Array[Dictionary] = []
	func write() -> Dictionary:
		if not gate.is_internal_owner_active(&"causal_transaction"): return {"ok": false, "code": &"no_custody"}
		if fail: return {"ok": false, "code": &"fixture_write_failed"}
		saved.append({"gameplay": game.to_save_dict(), "contacts": game.contacts.duplicate(true)})
		return {"ok": true}

func _game() -> Node:
	var game: Node = autofree(GAME.new())
	game.reset_game()
	return game

func _issuer() -> RefCounted:
	var issuer := ISSUER.new()
	assert_true(issuer.configure(ROOT.new("73".repeat(32), 1)).ok)
	return issuer

func _capture(before: Dictionary, candidate: Dictionary, gameplay: Dictionary, day: int) -> Dictionary:
	var captured := FROZEN.capture_candidate(before, candidate, gameplay, day)
	assert_true(captured.ok, str(captured))
	return captured.value if captured.ok else {}

func test_offer_freezes_generation_facts_and_missing_history_is_not_recreated() -> void:
	var game := _game()
	game.dating_route_state.priscilla.relationship_state = "ambiguous"
	game.dating_route_state.priscilla.dark_points = 4
	game.friend_attitude.priscilla = "seen"
	var offered := CONTACTS.prepare_offer_solo(game.contacts, "priscilla", 1, "solo:priscilla:day1", "fixture:offer")
	assert_true(offered.ok, str(offered))
	if not offered.ok: return
	var gameplay := _capture(game.contacts, offered.value.candidate, game.to_save_dict(), 1)
	if gameplay.is_empty(): return
	var entry := "contact.invitation.solo.priscilla.day1.offer"
	var cached: Dictionary = gameplay.route_context[FROZEN.CACHE_KEY]
	var snapshot := FROZEN.read(cached, entry)
	assert_true(snapshot.ok, str(snapshot))
	if not snapshot.ok: return
	assert_eq(snapshot.value.fields.tier, "ambiguous")
	assert_eq(snapshot.value.fields.tone, "dark")
	assert_eq(snapshot.value.fields.attitude, "seen")
	assert_true(snapshot.value.is_read_only())
	assert_true(snapshot.value.fields.is_read_only())
	gameplay.dating_route_state.priscilla.relationship_state = "love"
	gameplay.friend_attitude.priscilla = "hostile"
	var again := FROZEN.capture_candidate(offered.value.candidate, offered.value.candidate, gameplay, 2)
	assert_true(again.ok, str(again))
	if not again.ok: return
	assert_eq(again.value.route_context[FROZEN.CACHE_KEY], cached)
	assert_true(FROZEN.validate_cache(cached, offered.value.candidate, true, [], 2).ok)
	assert_false(FROZEN.validate_cache(FROZEN.empty_cache(), offered.value.candidate, true, [], 2).ok)
	gameplay.route_context.erase(FROZEN.CACHE_KEY)
	var historical := FROZEN.prepare_projection(offered.value.candidate, gameplay, 2, "priscilla")
	assert_true(historical.ok, str(historical))
	if historical.ok: assert_false(FROZEN.read(historical.value.route_context[FROZEN.CACHE_KEY], entry).ok)

func test_ordinary_after_selection_and_echo_use_exact_saved_reply_and_original_tier() -> void:
	var game := _game()
	var issuer := _issuer()
	var friend: String = ORDINARY.DAYS[1]
	var awaiting := FROZEN.prepare_projection(game.contacts, game.to_save_dict(), 1, friend)
	assert_true(awaiting.ok, str(awaiting))
	if not awaiting.ok: return
	var available := ORDINARY.available(game.contacts, 1, friend)
	assert_true(available.ok, str(available))
	if not available.ok: return
	var choice: Dictionary = available.value.choices[1]
	var issued: Dictionary = issuer.issue(&"transaction_id").value
	var line := {"view_token": issued.token, "line_id": choice.line_id, "text": choice.text}
	var replied := ORDINARY.prepare_reply(game.contacts, 1, choice.reply_id, "en", issued.token, issued.issuer_receipt, line)
	assert_true(replied.ok, str(replied))
	if not replied.ok: return
	awaiting.value.dating_route_state[friend].relationship_state = "love"
	var gameplay := _capture(game.contacts, replied.value.candidate, awaiting.value, 1)
	if gameplay.is_empty(): return
	var cache: Dictionary = gameplay.route_context[FROZEN.CACHE_KEY]
	var selected := FROZEN.read(cache, choice.entry_id, "after_selection")
	assert_true(selected.ok, str(selected))
	if not selected.ok: return
	assert_eq(selected.value.fields.tier, "friend")
	assert_eq(selected.value.fields.selected_reply_id, choice.reply_id)
	assert_eq(selected.value.fields.witnessed_line_id, choice.line_id)
	assert_eq(selected.value.fields.due_echoes, [])
	assert_true(FROZEN.validate_cache(cache, replied.value.candidate, true, [], 1).ok)
	var day7 := FROZEN.prepare_projection(replied.value.candidate, gameplay, 7)
	assert_true(day7.ok, str(day7))
	if not day7.ok: return
	var echo := FROZEN.read(day7.value.route_context[FROZEN.CACHE_KEY], "echo.fallback.day7", choice.echo_id)
	assert_true(echo.ok, str(echo))
	if not echo.ok: return
	assert_eq(echo.value.fields.due_echoes, [{"echo_id": choice.echo_id, "presentation_atom_id": choice.presentation_atom_id}])
	var echo_cache: Dictionary = FROZEN.retain(FROZEN.empty_cache(), echo.value).value
	var forged: Dictionary = replied.value.candidate.duplicate(true)
	forged.transaction_receipts[issued.token].erase("command_issuer_receipt")
	assert_false(FROZEN.validate_cache(echo_cache, forged, false, [], 7).ok,
		"A registered echo ID is insufficient without the actual witnessed-reply proof")
	var card := {"receipt": {"entry_id": "echo.fallback.day7", "view_token": "fixture:view",
		"echo_id": choice.echo_id, "presentation_atom_id": choice.presentation_atom_id},
		"title": "Reply", "body": choice.text, "presentation": echo.value}
	assert_true(SURFACE._validate_card(card).ok)
	card.receipt.echo_id = "invented"
	assert_false(SURFACE._validate_card(card).ok)
	cache.entries.erase(choice.entry_id + "|awaiting_reply")
	assert_false(FROZEN.validate_cache(cache, replied.value.candidate, true, [], 1).ok)

func test_group_history_keeps_generation_phase_after_resolution_and_next_group() -> void:
	var game := _game()
	var state: Dictionary = game.contacts.duplicate(true)
	var gameplay: Dictionary = game.to_save_dict()
	for friend: String in CONTACTS.GROUP_PAIR:
		var offered := CONTACTS.prepare_offer_solo(state, friend, 2, "solo:%s:day2" % friend, "fixture:offer:" + friend)
		assert_true(offered.ok, str(offered))
		if not offered.ok: return
		gameplay = _capture(state, offered.value.candidate, gameplay, 2)
		if gameplay.is_empty(): return
		state = offered.value.candidate
	var activated := CONTACTS.prepare_activate_group_after_round(state, 2, 2, 3, "fixture:group")
	assert_true(activated.ok, str(activated))
	if not activated.ok: return
	var missing_history: Dictionary = gameplay.duplicate(true)
	missing_history.route_context.erase(FROZEN.CACHE_KEY)
	var hidden := FROZEN.capture_candidate(state, activated.value.candidate, missing_history, 2)
	assert_true(hidden.ok, str(hidden))
	if hidden.ok:
		assert_false(FROZEN.read(hidden.value.route_context[FROZEN.CACHE_KEY],
			"contact.invitation.solo.priscilla.day2.offer").ok,
			"Hiding an existing offer is not a new generation boundary")
	gameplay = _capture(state, activated.value.candidate, gameplay, 2)
	if gameplay.is_empty(): return
	state = activated.value.candidate
	var issuer := _issuer()
	var issued: Dictionary = issuer.issue(&"transaction_id").value
	var opened := CONTACTS.prepare_open_contact(state, "lavinia", 2, issued.token, issued.issuer_receipt, issuer, {})
	assert_true(opened.ok, str(opened))
	if not opened.ok: return
	gameplay = _capture(state, opened.value.candidate, gameplay, 2)
	if gameplay.is_empty(): return
	state = opened.value.candidate
	var id := "contact.invitation.group.priscilla_lavinia.day2.first_open_lavinia"
	var original: Dictionary = FROZEN.read(gameplay.route_context[FROZEN.CACHE_KEY], id).value
	assert_eq(original.fields.group_action_state, "REPLY_REQUIRED")
	assert_eq(original.fields.opened_ids, ["lavinia"])
	assert_eq(original.fields.replied_ids, [])
	var closed := CONTACTS.prepare_resolve_day_end(state, 2, {}, "fixture:close")
	assert_true(closed.ok, str(closed))
	if not closed.ok: return
	gameplay = _capture(state, closed.value.candidate, gameplay, 2)
	if gameplay.is_empty(): return
	state = closed.value.candidate
	for friend: String in CONTACTS.GROUP_PAIR:
		var offered := CONTACTS.prepare_offer_solo(state, friend, 6, "solo:%s:day6" % friend, "fixture:later:" + friend)
		assert_true(offered.ok, str(offered))
		if not offered.ok: return
		gameplay = _capture(state, offered.value.candidate, gameplay, 6)
		if gameplay.is_empty(): return
		state = offered.value.candidate
	var later := CONTACTS.prepare_activate_group_after_round(state, 6, 2, 3, "fixture:later-group")
	assert_true(later.ok, str(later))
	if not later.ok: return
	gameplay = _capture(state, later.value.candidate, gameplay, 6)
	if gameplay.is_empty(): return
	var cache: Dictionary = gameplay.route_context[FROZEN.CACHE_KEY]
	assert_true(FROZEN.validate_cache(cache, later.value.candidate, true, [], 6).ok)
	assert_eq(FROZEN.read(cache, id).value, original)
	var forged: Dictionary = cache.duplicate(true)
	forged.entries[id].fields.merge({"contact_variation": "offer", "group_action_state": "AVAILABLE_UNOPENED",
		"inviter_id": null, "target_participant_id": null, "opened_ids": [], "replied_ids": []}, true)
	assert_true(preload("res://scripts/narrative/FrozenPresentationContext.gd").validate(id, forged.entries[id]).ok)
	assert_false(FROZEN.validate_cache(forged, later.value.candidate, true, [], 6).ok,
		"A first-open card cannot borrow the virtual offer's activation receipt")
	cache.entries[id].fields.opened_ids = ["priscilla", "lavinia"]
	assert_false(FROZEN.validate_cache(cache, later.value.candidate, true, [], 6).ok)

func test_current_ordinary_freeze_is_durable_before_native_projection_and_failed_write_rolls_back() -> void:
	var game := _game()
	var gate := GATE.new()
	assert_true(game.configure_mutation_gate(gate).ok)
	game._lifecycle_set_playing_day(1)
	assert_true(game.configure_frozen_contacts_contexts().ok)
	var writer := Writer.new()
	writer.game = game
	writer.gate = gate
	assert_true(game.configure_contact_checkpoint_writer(writer.write).ok)
	var port := PORT.new()
	assert_true(port.configure(game, Commands.new()).ok)
	var friend: String = ORDINARY.DAYS[1]
	var before: Dictionary = game.route_context.duplicate(true)
	writer.fail = true
	var failed := port.get_projection(friend)
	assert_false(failed.ok, str(failed))
	assert_eq(game.route_context, before)
	assert_true(writer.saved.is_empty())
	assert_false(gate.is_active())
	writer.fail = false
	var projected := port.get_projection(friend)
	assert_true(projected.ok, str(projected))
	if not projected.ok: return
	assert_eq(writer.saved.size(), 1)
	assert_eq(projected.value.entries.size(), 1)
	var frozen: Dictionary = projected.value.entries[0].presentation
	assert_true(frozen.fields.is_read_only())
	assert_eq(frozen.fields.phase, "awaiting_reply")
	game.dating_route_state[friend].relationship_state = "love"
	game.friend_attitude[friend] = "hostile"
	var restored := port.get_projection(friend)
	assert_true(restored.ok, str(restored))
	if restored.ok: assert_eq(restored.value.entries[0].presentation, frozen)
	assert_eq(writer.saved.size(), 1, "A retained card does not checkpoint or recapture again")

func test_care_snapshot_names_real_witness_source_before_native_read_and_refuses_forgery() -> void:
	var game := _game()
	var issuer := _issuer()
	var offered := CONTACTS.prepare_offer_solo(game.contacts, "sylvia", 1, "solo:sylvia:day1", "fixture:care-offer")
	assert_true(offered.ok, str(offered))
	if not offered.ok: return
	var gameplay := _capture(game.contacts, offered.value.candidate, game.to_save_dict(), 1)
	if gameplay.is_empty(): return
	var issued: Dictionary = issuer.issue(&"transaction_id").value
	var accepted := CONTACTS.prepare_open_contact(offered.value.candidate, "sylvia", 1, issued.token,
		issued.issuer_receipt, issuer, game._schedule_action_record("solo:sylvia:day1"))
	assert_true(accepted.ok, str(accepted))
	if not accepted.ok: return
	var root: Dictionary = issuer.issue(&"transaction_id").value
	var resolution: Dictionary = issuer.derive_child({"child_kind": "hospital_resolution",
		"parent_receipt_id": root.issuer_receipt.receipt_id, "ordinal": 0, "source_ids": ["fixture:condition"]})
	assert_true(resolution.ok, str(resolution))
	if not resolution.ok: return
	var plan := {"source_day": 1, "accepted_sources": [{"receipt_id": accepted.receipt.receipt_id,
		"action_id": "solo:sylvia:day1"}], "resolution_receipt": {"receipt_id": resolution.value.child_id,
		"receipt_provenance": resolution.value.provenance}}
	var closed := preload("res://scripts/application/run/ConditionHospitalContactsAdapter.gd").prepare(accepted.value.candidate, plan, issuer)
	assert_true(closed.ok, str(closed))
	if not closed.ok: return
	gameplay = _capture(accepted.value.candidate, closed.value.contacts, gameplay, 1)
	if gameplay.is_empty(): return
	var cache: Dictionary = gameplay.route_context[FROZEN.CACHE_KEY]
	var care := FROZEN.read(cache, "contact.hospital_care.sylvia.day2")
	assert_true(care.ok, str(care))
	if not care.ok: return
	assert_eq(care.value.fields.source_invitation_id, "solo:sylvia:day1")
	assert_eq(care.value.fields.closure_state, "hospital_care")
	assert_eq(care.value.fields.miss_reason, "hospital_care")
	assert_true(care.value.fields.witnessed_hospital)
	assert_true(FROZEN.validate_cache(cache, closed.value.contacts, true, [], 1).ok)
	assert_false(FROZEN.validate_cache(cache, accepted.value.candidate, false, [], 1).ok)
	cache.entries["contact.hospital_care.sylvia.day2"].fields.source_invitation_id = "solo:priscilla:day1"
	assert_false(FROZEN.validate_cache(cache, closed.value.contacts, false, [], 1).ok)

func test_desktop_board_detached_candidate_carries_generated_offer_before_checkpoint() -> void:
	var game := _game()
	var gate := GATE.new()
	assert_true(game.configure_mutation_gate(gate).ok)
	assert_true(game.configure_frozen_contacts_contexts().ok)
	game.dating_route_state.priscilla.relationship_state = "ambiguous"
	var port := preload("res://scripts/application/minesweeper/GameStateMinesweeperPort.gd").new(game)
	assert_true(port.configure(gate).ok)
	var before: Dictionary = game.contacts.duplicate(true)
	var route: Dictionary = game.route_context.duplicate(true)
	var prepared: Dictionary = port.prepare_complete({"round_id": "fixture:round", "context": "app",
		"difficulty": "easy"}, {"outcome": "cleared"}, "fixture:complete")
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var candidate: Dictionary = prepared.value.prepared_candidate
	var cache: Dictionary = candidate.gameplay.route_context[FROZEN.CACHE_KEY]
	assert_true(FROZEN.validate_cache(cache, candidate.contacts, true, [], 1).ok)
	var offer := FROZEN.read(cache, "contact.invitation.solo.priscilla.day1.offer")
	assert_true(offer.ok, str(offer))
	if offer.ok: assert_eq(offer.value.fields.tier, "ambiguous")
	assert_eq(game.contacts, before)
	assert_eq(game.route_context, route, "Preparation cannot publish the detached snapshot")

func test_failed_generation_freeze_leaves_live_unlock_and_contacts_untouched() -> void:
	var game := _game()
	assert_true(game.configure_frozen_contacts_contexts().ok)
	game.minesweeper_app_rounds_finished_today = 1
	game.dating_route_state.priscilla.relationship_state = "unregistered"
	var before: Dictionary = game.contacts.duplicate(true)
	var unlocked: Dictionary = game.contact_message_unlocks.duplicate(true)
	watch_signals(game)
	var refused: Dictionary = game.unlock_contact_message_after_minesweeper_finished({"outcome": "cleared"})
	assert_false(refused.get("ok", true), str(refused))
	assert_eq(game.contacts, before)
	assert_eq(game.contact_message_unlocks, unlocked)
	assert_signal_not_emitted(game, "contact_message_unlocked")
	assert_signal_not_emitted(game, "save_relevant_state_changed")
