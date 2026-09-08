extends GutTest

const REMAP := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
const BOARD := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const SOURCE := preload("res://scripts/application/ending/Day7ConditionEndingSource.gd")
const MASTERY_FIXTURE := preload("res://tests/support/CanonicalDatingMasteryFixture.gd")
const STATE := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SEQUENCE := preload("res://scripts/application/desktop/DesktopCausalSequencePort.gd")
const CHECKPOINT := preload("res://tests/support/FakeDesktopConsequenceCheckpointPort.gd")
const CONTEXT := preload("res://scripts/application/desktop/GameStateDesktopConditionContextPort.gd")
const POLICY := preload("res://scripts/application/desktop/DesktopConditionPolicyPort.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

class Ledger extends RefCounted:
	func record_before_emit(_request: Dictionary) -> Dictionary:
		return {"ok": false, "code": &"unexpected_publication_during_prepare"}

class Writer extends RefCounted:
	var game: Node
	var consequence: RefCounted
	var gate: RefCounted
	var fail_next := false
	var snapshots: Array[Dictionary] = []
	func write() -> Dictionary:
		if not gate.is_internal_owner_active(&"causal_transaction"):
			return {"ok": false, "code": &"causal_lease_missing"}
		if fail_next:
			fail_next = false
			return {"ok": false, "code": &"fixture_disk_failure"}
		var valid: Dictionary = CONTACTS.validate_state(game.contacts)
		if not valid.ok: return valid
		snapshots.append({"game": game.capture_restore_state().value.backup,
			"consequence": consequence.capture().value.state})
		return {"ok": true}


func _child(issuer: RefCounted, root: Dictionary, kind: String, sources: Array) -> Dictionary:
	sources.sort()
	var result: Dictionary = issuer.derive_child({"parent_receipt_id": root.receipt_id,
		"child_kind": kind, "ordinal": 0, "source_ids": sources})
	assert_true(result.ok, str(result))
	return result.value


func _open(game: Node, issuer: RefCounted, friend_id: String) -> void:
	var action_id := "solo:%s:day7" % friend_id
	if not game.contacts.solo_actions.has(action_id):
		var offer: Dictionary = CONTACTS.prepare_offer_solo(game.contacts, friend_id, 7,
			"fixture-offer:" + friend_id, "fixture-offer-transaction:" + friend_id)
		assert_true(offer.ok, str(offer))
		game.contacts = offer.value.candidate
	var command: Dictionary = issuer.issue(&"transaction_id").value
	var record := {"action_id": action_id, "action_kind": "solo", "allowed_days": [7],
		"effect_ids": [], "motivation_cost": 1, "participants": [friend_id], "repeatable": false,
		"route_id": null, "source_receipt_kind": "solo_read_acceptance"}
	var opened: Dictionary = CONTACTS.prepare_open_contact(game.contacts, friend_id, 7,
		command.token, command.issuer_receipt, issuer, record)
	assert_true(opened.ok, str(opened))
	game.contacts = opened.value.candidate


func _fixture(dark_mode: bool = false, sylvia_read: bool = false) -> Dictionary:
	var root := ROOT.new("37".repeat(32), 1)
	var issuer := ISSUER.new()
	assert_true(issuer.configure(root).ok)
	var game: Node = autofree(MASTERY_FIXTURE.Game.new())
	game.reset_game()
	game.inter_friend_route_state = {"priscilla_lavinia": {"frozen_form": "love_sweet", "ending_eligible": false}}
	var run: Dictionary = root.mint(&"run_id")
	var branch: Dictionary = root.mint(&"branch_id")
	var day_root: Dictionary = root.mint(&"causal_day_instance")
	var provenance := {"causal_day_instance": day_root.token, "causal_day_instance_issuer_receipt": day_root}
	game._run_lifecycle.reset(run.token, branch.token, 0, day_root.token,
		{"causal_day_instance_issuer_receipt": day_root}, dark_mode)
	var lifecycle: Dictionary = game._run_lifecycle.to_dict()
	lifecycle.day = 7
	assert_true(game._run_lifecycle.commit_restore(game._run_lifecycle.prepare_restore(lifecycle).value.candidate).ok)
	assert_true(game.configure_identity_issuer(issuer).ok)
	var gate := GATE.new()
	assert_true(game.configure_mutation_gate(gate).ok)
	var consequence := STATE.new()
	assert_true(consequence.commit(consequence.prepare_restore(STATE.make_empty(provenance).value.state).value.candidate).ok)
	var offered: Dictionary = CONTACTS.prepare_offer_solo(game.contacts, "priscilla", 7, "fixture-priscilla", "fixture-p-offer")
	assert_true(offered.ok)
	game.contacts = offered.value.candidate
	if sylvia_read: _open(game, issuer, "sylvia")
	var issued: Dictionary = issuer.issue(&"transaction_id").value
	var quote := _child(issuer, issued.issuer_receipt, "shop_quote", ["fixture-quote"])
	var action := {"schema_version": 1, "action_kind": "shop_purchase", "run_id": run.token,
		"branch_id": branch.token, "desktop_timeline_generation": 0, "causal_day_instance": day_root.token,
		"day": 7, "transaction_id": issued.token, "transaction_issuer_receipt": issued.issuer_receipt,
		"source_commit_receipt_id": quote.child_id, "source_commit_receipt_provenance": quote.provenance,
		"condition_before": {"health": 1, "pressure": 9, "carried_sequela": true},
		"condition_after": {"health": 0, "pressure": 10, "carried_sequela": true}, "unlock_receipt_ids": []}
	var action_child := _child(issuer, issued.issuer_receipt, "desktop_action",
		["shop_purchase", quote.child_id, _hash(action)])
	action["action_id"] = action_child.child_id
	action["action_id_provenance"] = action_child.provenance
	action["commit_receipt_id"] = action_child.child_id
	action["commit_receipt_provenance"] = action_child.provenance.duplicate(true)
	var sequence := SEQUENCE.new()
	assert_true(sequence.configure_publication_ledger(Ledger.new()).ok)
	assert_true(sequence.configure(consequence, gate, CHECKPOINT.new()).ok)
	var request := {"transaction_id": action.transaction_id, "transaction_issuer_receipt": action.transaction_issuer_receipt,
		"run_id": action.run_id, "branch_id": action.branch_id, "desktop_timeline_generation": 0,
		"causal_day_instance": action.causal_day_instance, "source_kind": action.action_kind,
		"source_commit_receipt_id": action.commit_receipt_id, "source_commit_receipt_provenance": action.commit_receipt_provenance,
		"expected_last_sequence": 0, "expected_run_revision": 0}
	var reserved: Dictionary = sequence.prepare_reservation(request)
	assert_true(reserved.ok, str(reserved))
	var context := CONTEXT.new()
	assert_true(context.configure(game, issuer).ok)
	var policy := POLICY.new()
	assert_true(policy.configure(context).ok)
	var evaluated: Dictionary = policy.evaluate({"action_receipt": action,
		"causal_sequence_receipt": reserved.value.causal_sequence_receipt})
	assert_true(evaluated.ok, str(evaluated))
	var intent: Dictionary = evaluated.value.destination_intent
	var record := {"key": intent.intent_id, "payload_hash": _hash(intent), "provenance": intent.intent_id_provenance,
		"consumer": "day7_terminal", "status": "pending", "payload": intent,
		"action_receipt": action, "condition_receipt": evaluated.value.condition_receipt, "causal_sequence": 1}
	var detached: Dictionary = consequence.capture().value.state
	detached.run_revision = 1
	detached.causal_sequence = 1
	detached["outbox"]["hospital"] = record
	var prepared_outbox: Dictionary = consequence.prepare_restore(detached)
	assert_true(prepared_outbox.ok, str(prepared_outbox))
	if prepared_outbox.get("ok", false):
		assert_true(consequence.commit(prepared_outbox.value.candidate).ok)
	var writer := Writer.new()
	writer.game = game
	writer.consequence = consequence
	writer.gate = gate
	return {"game": game, "consequence": consequence, "issuer": issuer, "root": root,
		"writer": writer, "gate": gate, "context": context, "action": action,
		"sequence": reserved.value.causal_sequence_receipt}


func _validate(f: Dictionary, detached: Dictionary = {}) -> Dictionary:
	return SOURCE.validate(f.consequence.capture().value.state if detached.is_empty() else detached,
		f.game._run_lifecycle.to_dict(), f.game._canonical_committed_schedule(), f.game.contacts, f.issuer)


func _bind(f: Dictionary) -> void:
	assert_true(f.game.configure_ending_condition_source(f.consequence).ok)
	assert_true(f.game.configure_ending_checkpoint_writer(f.writer.write).ok)


func test_real_policy_captured_dark_mode_wins_and_raw_friend_tone_is_not_dark_mode() -> void:
	var normal := _fixture(false, true)
	normal.game.dating_route_state["sylvia"] = {"dark_points": 9}
	var captured: Dictionary = normal.context.snapshot_for({"action_receipt": normal.action, "causal_sequence_receipt": normal.sequence})
	assert_false(captured.value.context.dark_mode)
	assert_eq(_validate(normal).value.terminal_cause, "sylvia_special")
	var dark := _fixture(true, true)
	assert_eq(_validate(dark).value.terminal_cause, "dark_mode_alone")
	assert_eq(_validate(_fixture()).value.terminal_cause, "hospital_alone")


func test_source_refuses_changed_identity_sequence_prerequisites_and_condition() -> void:
	var f := _fixture(false, true)
	assert_true(_validate(f).ok)
	var original: Dictionary = f.consequence.capture().value.state
	for field: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance"]:
		var changed: Dictionary = original.duplicate(true)
		changed.outbox.hospital.action_receipt[field] = 9 if field == "desktop_timeline_generation" else "another"
		assert_false(_validate(f, changed).ok, field)
	var changed: Dictionary = original.duplicate(true)
	changed.run_revision += 1
	assert_false(_validate(f, changed).ok, "sequence preimage must retain the current revision")
	changed = original.duplicate(true)
	changed.outbox.hospital.payload.prerequisite_receipt_ids.reverse()
	changed.outbox.hospital.payload_hash = _hash(changed.outbox.hospital.payload)
	assert_false(_validate(f, changed).ok, "same sources in a noncanonical order are refused")
	changed = original.duplicate(true)
	changed.outbox.hospital.condition_receipt.sylvia_read_receipt_id = null
	assert_false(_validate(f, changed).ok)
	changed = original.duplicate(true)
	changed.outbox.hospital.condition_receipt.causal_sequence_receipt_provenance.transaction_id = "another"
	assert_false(_validate(f, changed).ok)
	changed = original.duplicate(true)
	changed.outbox.hospital.status = "published"
	assert_false(_validate(f, changed).ok, "consumed evidence cannot admit a new plan")


func test_later_sylvia_read_does_not_rewrite_the_frozen_hospital_cause() -> void:
	var f := _fixture()
	_open(f.game, f.issuer, "sylvia")
	f.game.daily_opened_contacts["day:7:friend:sylvia"] = true
	assert_eq(_validate(f).value.terminal_cause, "hospital_alone")
	_bind(f)
	assert_true(f.game.resume_terminal_ending().ok)
	assert_eq(f.game._run_lifecycle.to_dict().ending_plan.steps[0].ending_id, "ending.alone")
	assert_eq(f.game.route_context.day7_condition_ending.terminal_cause, "hospital_alone")


func test_failed_admission_rolls_back_outbox_contacts_and_run_then_saves_one_ordered_plan() -> void:
	var f := _fixture(false, true)
	f.game.inter_friend_route_state.priscilla_lavinia.ending_eligible = true
	f.game.route_context["observer_variant_by_scope"] = {"priscilla_lavinia": "full"}
	var evidence: Dictionary = MASTERY_FIXTURE.profile_for_scope(f.game, "priscilla_lavinia")
	assert_true(evidence.ok, str(evidence))
	if not evidence.ok: return
	autofree(evidence.value.profile)
	_bind(f)
	var before: Dictionary = f.game.capture_restore_state().value.backup
	var outbox_before: Dictionary = f.consequence.capture().value
	f.writer.fail_next = true
	assert_eq(str(f.game.resume_terminal_ending().code), "fixture_disk_failure")
	assert_eq(f.game.capture_restore_state().value.backup, before)
	assert_eq(f.consequence.capture().value, outbox_before)
	assert_false(f.gate.is_active())
	assert_true(f.game.resume_terminal_ending().ok)
	assert_eq(f.writer.snapshots.size(), 1)
	var saved: Dictionary = f.writer.snapshots[0]
	assert_eq(saved.consequence.outbox.hospital.status, "published")
	assert_eq(saved.game.lifecycle.state, "ENDING")
	assert_eq(saved.game.lifecycle.day, 7)
	assert_eq(saved.game.lifecycle.ending_plan.steps.size(), 4)
	assert_eq(saved.game.lifecycle.ending_plan.steps[0].ending_id, "ending.sylvia.special")
	assert_eq(saved.game.lifecycle.ending_plan.steps[1].ending_id, "ending.sylvia.dark")
	assert_eq(saved.game.lifecycle.ending_plan.steps[2].ending_id, "ending.priscilla_lavinia.sweet")
	assert_eq(saved.game.lifecycle.ending_plan.steps[3].presentation_variant, "full")
	assert_eq(saved.game.contacts.solo_actions["solo:priscilla:day7"].state, "RESOLVED_RUN_END")
	assert_eq(saved.game.contacts.solo_actions["solo:sylvia:day7"].state, "RESOLVED_RUN_END")
	assert_eq(saved.game.contacts.messages, before.contacts.messages, "no missed record or Day 8 message")
	assert_eq(saved.game.gameplay.dating_route_state, before.gameplay.dating_route_state, "forced Dark does not mutate raw tone")
	assert_eq(saved.game.gameplay.route_context.day7_condition_ending.ending_form, "special_forced_dark")
	assert_true(f.game.resume_terminal_ending().ok)
	assert_eq(f.writer.snapshots.size(), 1)
	assert_eq(f.consequence.capture().value.state.outbox.hospital, saved.consequence.outbox.hospital)


func test_fresh_owner_resumes_saved_pending_source_and_published_ending_without_rechoosing() -> void:
	var original := _fixture(true, true)
	var game_backup: Dictionary = original.game.capture_restore_state().value.backup
	var consequence_backup: Dictionary = original.consequence.capture().value
	var restored := _fixture(true, true)
	assert_true(restored.game.rollback_restore_silent(game_backup).ok)
	assert_true(restored.consequence.rollback(consequence_backup).ok)
	_bind(restored)
	assert_true(restored.game.resume_terminal_ending().ok)
	var saved: Dictionary = restored.writer.snapshots[0]
	assert_eq(saved.game.lifecycle.ending_plan.steps[0].ending_id, "ending.alone")
	assert_eq(saved.game.gameplay.route_context.day7_condition_ending.terminal_cause, "dark_mode_alone")
	var ending_reload := _fixture(true, true)
	assert_true(ending_reload.game.rollback_restore_silent(saved.game).ok)
	assert_true(ending_reload.consequence.rollback({"state": saved.consequence}).ok)
	_bind(ending_reload)
	assert_true(ending_reload.game.resume_terminal_ending().ok)
	assert_eq(ending_reload.writer.snapshots.size(), 0, "saved ENDING resumes its existing cursor")
	assert_eq(ending_reload.game._run_lifecycle.to_dict().ending_plan, saved.game.lifecycle.ending_plan)


func test_condition_admission_refuses_done_and_keeps_raw_unknown_terminal_packet_refused() -> void:
	var f := _fixture()
	var lifecycle: Dictionary = f.game._run_lifecycle.to_dict()
	assert_false(SOURCE.validate(f.consequence.capture().value.state, lifecycle,
		{"commit_receipt": {"receipt_id": "already-done"}}, f.game.contacts, f.issuer).ok)
	lifecycle.state = "TERMINAL_PENDING"
	assert_false(SOURCE.validate(f.consequence.capture().value.state, lifecycle,
		{}, f.game.contacts, f.issuer).ok)
	var changed: Dictionary = f.consequence.capture().value.state
	changed.outbox.hospital.erase("condition_receipt")
	assert_false(_validate(f, changed).ok, "unknown or incomplete saved records are never reinterpreted")


static func _hash(value: Dictionary) -> String:
	return str(JSON_WRITER.stringify(value).value).sha256_text()


func _remap_snapshot(f: Dictionary) -> Dictionary:
	return {"lifecycle": f.game._run_lifecycle.to_dict(), "contacts": f.game.contacts.duplicate(true),
		"desktop": {"board": BOARD.new().capture(), "consequence": f.consequence.capture().value.state}}


func _allocation(f: Dictionary, snapshot: Dictionary) -> Dictionary:
	var collected: Dictionary = REMAP.collect_rewindable_transaction_ids(snapshot)
	assert_true(collected.ok, str(collected))
	var command: Dictionary = f.issuer.issue(&"transaction_id").value
	var prepared: Dictionary = f.issuer.prepare_continuation_allocation({"kind": "restore",
		"transaction_id": command.token, "transaction_issuer_receipt": command.issuer_receipt,
		"existing_run_id": snapshot.lifecycle.run_id,
		"source_desktop_timeline_generation": snapshot.lifecycle.desktop_timeline_generation,
		"remap_source_transaction_ids": collected.value.transaction_ids})
	assert_true(prepared.ok, str(prepared))
	assert_true(f.issuer.commit_continuation_allocation(prepared.value).ok)
	# The established FakeDesktopIssuerRootStore exposes the minted receipts before the production
	# root's final transaction_remap projection (same adapter used by the issuer's own tests).
	var roots: Dictionary = prepared.value.remap_transaction_issuer_receipts
	var mappings := {}
	for source: String in collected.value.transaction_ids:
		mappings[source] = {"source_transaction_id": source, "new_transaction_id": roots[source].token,
			"new_transaction_issuer_receipt": roots[source]}
	return {"transaction_id": command.token, "transaction_issuer_receipt": command.issuer_receipt,
		"run_id": snapshot.lifecycle.run_id, "branch_id": prepared.value.branch_id,
		"desktop_timeline_generation": prepared.value.desktop_timeline_generation,
		"causal_day_instance": prepared.value.causal_day_instance,
		"causal_day_instance_issuer_receipt": prepared.value.causal_day_instance_issuer_receipt,
		"transaction_remap": mappings}


func test_boardless_shop_pending_load_rebuilds_all_live_children_and_can_load_twice_then_enter_ending() -> void:
	var f := _fixture(false, true)
	var source := _remap_snapshot(f)
	assert_null(source.desktop.board.identity, "a real untouched board has no identity")
	assert_eq(REMAP.collect_rewindable_transaction_ids(source).value.transaction_ids, [f.action.transaction_id])
	var bundle := _allocation(f, source)
	var remapped: Dictionary = REMAP.prepare(source, bundle.transaction_id, bundle)
	assert_true(remapped.ok, str(remapped))
	if not remapped.get("ok", false): return
	var candidate: Dictionary = remapped.value.snapshot
	var validated: Dictionary = REMAP.validate_remap(source, candidate)
	assert_true(validated.ok, str(validated))
	validated = SOURCE.validate(candidate.desktop.consequence, candidate.lifecycle,
		f.game._canonical_committed_schedule(), candidate.contacts, f.issuer)
	assert_true(validated.ok, str(validated))
	var old: Dictionary = source.desktop.consequence.outbox.hospital
	var new_record: Dictionary = candidate.desktop.consequence.outbox.hospital
	assert_ne(new_record.action_receipt.transaction_id, old.action_receipt.transaction_id)
	assert_ne(new_record.key, old.key)
	assert_ne(new_record.condition_receipt.receipt_id, old.condition_receipt.receipt_id)
	assert_ne(new_record.condition_receipt.causal_sequence_receipt_id, old.condition_receipt.causal_sequence_receipt_id)
	assert_eq(new_record.action_receipt.source_commit_receipt_id, old.action_receipt.source_commit_receipt_id,
		"the already-paid source stays historical")
	assert_eq(new_record.condition_receipt.source_receipt_ids, old.condition_receipt.source_receipt_ids)
	assert_eq(new_record.condition_receipt.sylvia_read_receipt_id, old.condition_receipt.sylvia_read_receipt_id)
	assert_eq(new_record.payload.terminal_cause, "sylvia_special")
	assert_eq(candidate.contacts, source.contacts)
	assert_eq(candidate.desktop.consequence.causal_sequence, source.desktop.consequence.causal_sequence)
	var second_bundle := _allocation(f, candidate)
	var second: Dictionary = REMAP.prepare(candidate, second_bundle.transaction_id, second_bundle)
	assert_true(second.ok, str(second))
	if not second.get("ok", false): return
	assert_true(REMAP.validate_remap(candidate, second.value.snapshot).ok)
	var saved: Dictionary = second.value.snapshot
	assert_eq(saved.lifecycle.desktop_timeline_generation, 2)
	validated = SOURCE.validate(saved.desktop.consequence, saved.lifecycle,
		f.game._canonical_committed_schedule(), saved.contacts, f.issuer)
	assert_true(validated.ok, str(validated))
	var backup: Dictionary = f.game.capture_restore_state().value.backup
	backup.lifecycle = saved.lifecycle
	backup.desktop = saved.desktop
	assert_true(f.game.rollback_restore_silent(backup).ok)
	assert_true(f.consequence.rollback({"state": saved.desktop.consequence}).ok)
	_bind(f)
	assert_true(f.game.resume_terminal_ending().ok)
	assert_eq(f.game._run_lifecycle.to_dict().ending_plan.steps[0].ending_id, "ending.sylvia.special")
	assert_eq(f.game._run_lifecycle.to_dict().ending_plan.steps[1].ending_id, "ending.sylvia.dark")


func test_pending_load_refuses_altered_source_and_candidate_but_leaves_published_ending_evidence_historical() -> void:
	var f := _fixture(true, true)
	var source := _remap_snapshot(f)
	var bundle := _allocation(f, source)
	var changed: Dictionary = source.duplicate(true)
	changed.desktop.consequence.outbox.hospital.condition_receipt.receipt_id = "another-condition"
	assert_false(REMAP.prepare(changed, bundle.transaction_id, bundle).ok)
	changed = source.duplicate(true)
	changed.desktop.consequence.outbox.hospital.action_receipt.branch_id = "another-branch"
	assert_false(REMAP.prepare(changed, bundle.transaction_id, bundle).ok)
	var remapped: Dictionary = REMAP.prepare(source, bundle.transaction_id, bundle)
	assert_true(remapped.ok, str(remapped))
	if not remapped.get("ok", false): return
	changed = remapped.value.snapshot.duplicate(true)
	changed.desktop.consequence.outbox.hospital.payload.terminal_cause = "sylvia_special"
	changed.desktop.consequence.outbox.hospital.payload_hash = _hash(changed.desktop.consequence.outbox.hospital.payload)
	assert_false(REMAP.validate_remap(source, changed).ok, "changed playback cause cannot pass independent reproduction")
	_bind(f)
	assert_true(f.game.resume_terminal_ending().ok)
	var published := _remap_snapshot(f)
	assert_eq(REMAP.collect_rewindable_transaction_ids(published).value.transaction_ids, [])
	var published_bundle := _allocation(f, published)
	var historical: Dictionary = REMAP.prepare(published, published_bundle.transaction_id, published_bundle)
	assert_true(historical.ok, str(historical))
	if not historical.get("ok", false): return
	assert_eq(historical.value.snapshot.desktop.consequence.outbox.hospital, published.desktop.consequence.outbox.hospital)
	assert_eq(historical.value.snapshot.lifecycle.ending_plan, published.lifecycle.ending_plan)
