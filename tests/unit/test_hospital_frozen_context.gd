extends "res://addons/gut/test.gd"

# Isolate retained semantic fixture dependencies from the authored startup registry.
var _retained_scope := preload("res://tests/support/SceneValidationScope.gd").new()

const FROZEN := preload("res://scripts/narrative/HospitalFrozenContext.gd")
const CONTEXT := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const CONDITION := preload("res://scripts/application/run/ConditionHospitalContactsAdapter.gd")
const GAME := preload("res://autoload/GameState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const SCENE := preload("res://scripts/ui/HospitalScene.gd")
const CANON := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

class CheckpointWriter extends RefCounted:
	var game: Node
	var gate: RefCounted
	var fail := false
	var snapshots: Array[Dictionary] = []
	func write() -> Dictionary:
		if not gate.is_internal_owner_active(&"causal_transaction"):
			return {"ok": false, "code": &"fixture_missing_custody"}
		if fail: return {"ok": false, "code": &"fixture_write_failed"}
		snapshots.append(game.capture_restore_state().value.backup)
		return {"ok": true}

class Bridge extends Node:
	signal timeline_finished(timeline_id: String, result: Dictionary)
	var starts: Array[Dictionary] = []
	func is_dialogic_available() -> bool: return true
	func start_timeline_id(id: String, context: Dictionary) -> Dictionary:
		starts.append({"timeline_id": id, "context": context.duplicate(true)})
		return {"ok": true}

func _accepted_sylvia() -> Dictionary:
	var game: Node = autofree(GAME.new())
	game.reset_game()
	var issuer := ISSUER.new()
	assert_true(issuer.configure(ROOT.new("91".repeat(32), 1)).ok)
	var action := "solo:sylvia:day1"
	var offered := CONTACTS.prepare_offer_solo(game.contacts, "sylvia", 1, action, "fixture:offer")
	assert_true(offered.ok, str(offered))
	if not offered.ok: return {}
	var issued: Dictionary = issuer.issue(&"transaction_id").value
	var accepted := CONTACTS._prepare_invitation_open(offered.value.candidate, "sylvia", 1,
		issued.token, issued.issuer_receipt, issuer, game._schedule_action_record(action))
	assert_true(accepted.ok, str(accepted))
	if not accepted.ok: return {}
	game.contacts = accepted.value.candidate
	return {"game": game, "issuer": issuer, "source_id": str(accepted.receipt.receipt_id),
		"entry": {"slot_index": 0, "action_kind": "solo", "participants": ["sylvia"],
			"schedule_entry_id": "fixture:schedule", "action_id": action,
			"source_receipt_id": str(accepted.receipt.receipt_id)}}

func test_schedule_freezes_eligible_scene_without_claiming_a_future_witness() -> void:
	var fixture := _accepted_sylvia()
	if fixture.is_empty(): return
	var transport := {"kind": "hospital", "day": 1,
		"source_entry_ids": ["fixture:schedule"], "miss_receipt_ids": ["fixture:miss"]}
	var before: Dictionary = fixture.game.contacts.duplicate(true)
	var frozen := FROZEN.from_schedule(transport, fixture.game.contacts, [fixture.entry])
	assert_true(frozen.ok, str(frozen))
	if not frozen.ok: return
	var fields: Dictionary = frozen.value.presentation.fields
	assert_true(fields.sylvia_eligible)
	assert_null(fields.sylvia_witness_receipt_id)
	assert_eq(fields.accepted_record_ids, [fixture.source_id])
	assert_eq(fields.unfulfilled_record_ids, [fixture.source_id])
	assert_eq(fixture.game.contacts, before, "freezing does not manufacture a witness or a miss")
	fixture.game.contacts = CONTACTS.make_defaults()
	assert_eq(SCENE.art_participants(fixture.game.contacts, frozen.value), ["sylvia"],
		"later Contacts cannot choose another saved presentation")
	assert_false(FROZEN.from_schedule(transport, fixture.game.contacts, [fixture.entry]).ok,
		"a missing source is refused on first capture")

func test_condition_hospital_names_only_its_already_committed_witness() -> void:
	var fixture := _accepted_sylvia()
	if fixture.is_empty(): return
	var issued: Dictionary = fixture.issuer.issue(&"transaction_id").value
	var resolution: Dictionary = fixture.issuer.derive_child({"child_kind": "hospital_resolution",
		"parent_receipt_id": issued.issuer_receipt.receipt_id, "ordinal": 0,
		"source_ids": ["fixture:condition"]})
	assert_true(resolution.ok, str(resolution))
	if not resolution.ok: return
	var plan := {"source_day": 1, "accepted_sources": [{"receipt_id": fixture.source_id,
		"action_id": "solo:sylvia:day1"}], "resolution_receipt": {"receipt_id": resolution.value.child_id,
		"receipt_provenance": resolution.value.provenance}}
	var closed := CONDITION.prepare(fixture.game.contacts, plan, fixture.issuer)
	assert_true(closed.ok, str(closed))
	if not closed.ok: return
	var context := {"kind": "hospital", "day": 1,
		"source_entry_ids": closed.value.output.source_receipt_ids,
		"miss_receipt_ids": closed.value.output.miss_receipt_ids}
	var frozen := FROZEN.from_condition(context, closed.value.contacts, closed.value.output)
	assert_true(frozen.ok, str(frozen))
	if not frozen.ok: return
	assert_eq(frozen.value.presentation.fields.qualifying_cause, "condition_hospital")
	assert_eq(frozen.value.presentation.fields.sylvia_witness_receipt_id,
		closed.value.output.sylvia_witness.receipt_id)
	assert_false(FROZEN.from_condition(context, fixture.game.contacts, closed.value.output).ok,
		"planned witness bytes cannot stand in for the committed Contacts witness")

func _context(eligible: bool) -> Dictionary:
	var entry_id := "hospital.faint.day1"
	var built := CONTEXT.build(entry_id, {"entry_id": entry_id, "entry_role": "hospital", "day": 1,
		"qualifying_cause": "schedule_done", "accepted_record_ids": ["fixture:accepted"] if eligible else [],
		"unfulfilled_record_ids": ["fixture:accepted"] if eligible else [],
		"sylvia_eligible": eligible, "sylvia_witness_receipt_id": null})
	assert_true(built.ok, str(built))
	if not built.ok: return {}
	return {"kind": "hospital", "day": 1, "source_entry_ids": [], "miss_receipt_ids": [],
		"presentation": built.value}

func _command(context: Dictionary, suffix: String) -> Dictionary:
	var request := {"resolution_id": "fixture:resolution", "resolution_issuer_receipt": {},
		"stage_id": "fixture:stage", "substage_id": "fixture:intent:" + suffix,
		"route_id": "hospital", "timeline_id": "hospital.faint", "context": context,
		"completion_transaction_id": "fixture:complete:" + suffix, "completion_transaction_provenance": {}}
	request["command_sha256"] = CANON.canonical_sha256(request).value.sha256
	return request

func test_owner_uses_shared_timeline_for_both_frozen_sylvia_variants() -> void:
	var bridge: Node = autofree(Bridge.new())
	var owner := OWNER.new()
	assert_true(owner.configure(bridge).ok)
	assert_true(owner.configure_frozen_hospital_contexts().ok)
	var ordinary := _context(false)
	if ordinary.is_empty(): return
	var ordinary_command := _command(ordinary, "ordinary")
	var started := owner.begin_physical(ordinary_command)
	assert_true(started.ok, str(started))
	assert_eq(bridge.starts.size(), 1, "ordinary fainting starts the same native timeline")
	assert_eq(bridge.starts[0].context, ordinary)
	var sylvia := _context(true)
	if sylvia.is_empty(): return
	assert_true(owner.begin_physical(_command(sylvia, "sylvia")).ok)
	assert_eq(bridge.starts.size(), 2)
	assert_eq(bridge.starts[1].context, sylvia)
	var malformed := sylvia.duplicate(true)
	malformed.presentation.fields.erase("sylvia_eligible")
	assert_false(owner.begin_physical(_command(malformed, "malformed")).ok)
	assert_eq(bridge.starts.size(), 2)

func test_context_requires_exact_schema_source_set_and_matching_day() -> void:
	var context := _context(false)
	if context.is_empty(): return
	var port := PORT.new()
	assert_true(port.configure_frozen_hospital_contexts().ok)
	assert_eq(port._context_error(context), "")
	var wrong_day := context.duplicate(true)
	wrong_day.day = 2
	assert_false(FROZEN.validate(wrong_day).ok)
	var missing := context.duplicate(true)
	missing.erase("presentation")
	assert_false(port._context_error(missing).is_empty())
	var fake_witness := context.duplicate(true)
	fake_witness.presentation.fields.sylvia_witness_receipt_id = "fixture:invented"
	assert_false(FROZEN.validate(fake_witness).ok)
	var extra := context.duplicate(true)
	extra.presentation.fields["live_game"] = autofree(GAME.new())
	assert_false(FROZEN.validate(extra).ok)

func test_game_owner_hospital_request_is_bound_durable_detached_and_idempotent() -> void:
	var game: Node = autofree(GAME.new())
	game.reset_game()
	var gate := GATE.new()
	assert_true(game.configure_mutation_gate(gate).ok)
	var writer := CheckpointWriter.new()
	writer.game = game
	writer.gate = gate
	assert_true(game.configure_contact_checkpoint_writer(writer.write).ok)
	var issuer := ISSUER.new()
	assert_true(issuer.configure(ROOT.new("93".repeat(32), 1)).ok)
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.ok, str(issued))
	if not issued.ok: return
	var root: Dictionary = issued.value
	var derived: Dictionary = issuer.derive_child({"child_kind": "day_resolution_stage", "ordinal": 0,
		"parent_receipt_id": root.issuer_receipt.receipt_id, "source_ids": ["fixture:hospital-start"]})
	assert_true(derived.ok, str(derived))
	if not derived.ok: return
	var start := {"receipt_id": derived.value.child_id, "receipt_provenance": derived.value.provenance,
		"resolution_id": root.token, "causal_day_instance": game._run_lifecycle.to_dict().causal_day_instance,
		"source_day": 1, "schedule_entry_ids": [], "schedule_commit_receipt_id": null, "board_fate_receipt_id": null}
	var begun: Dictionary = game._run_lifecycle.begin_day_resolution(root.token, {"entries": []}, [], null, null,
		{"command_id": "fixture:hospital-done", "resolution_issuer_receipt": root.issuer_receipt,
		"day_resolution_start_receipt": start})
	assert_true(begun.ok, str(begun))
	if not begun.ok: return
	var request := _command(_context(false), "owner")
	request.erase("command_sha256")
	request.resolution_id = root.token
	request.resolution_issuer_receipt = root.issuer_receipt.duplicate(true)
	for stage: Dictionary in begun.value.plan.stages:
		if stage.stage_id == "hospital_if_triggered": request.stage_id = stage.transaction_id
	var before: Dictionary = game.capture_restore_state().value.backup
	assert_eq(game.read_hospital_presentation_request(root.token).value, {})
	var wrong_stage := request.duplicate(true)
	wrong_stage.stage_id = "fixture:unrelated-stage"
	assert_eq(game.retain_hospital_presentation_request(wrong_stage).get("code"), &"hospital_frozen_request_mismatch")
	assert_eq(game.capture_restore_state().value.backup, before)
	assert_true(writer.snapshots.is_empty())
	assert_false(gate.is_active())
	writer.fail = true
	assert_eq(game.retain_hospital_presentation_request(request).get("code"), &"fixture_write_failed")
	assert_eq(game.capture_restore_state().value.backup, before)
	assert_true(writer.snapshots.is_empty())
	assert_false(gate.is_active())
	writer.fail = false
	var retained: Dictionary = game.retain_hospital_presentation_request(request)
	assert_true(retained.ok, str(retained))
	if not retained.ok: return
	assert_eq(writer.snapshots.size(), 1)
	assert_eq(writer.snapshots[0].gameplay.route_context.hospital_frozen_contexts_v1.requests[root.token], request)
	assert_false(gate.is_active())
	var original := request.duplicate(true)
	retained.value.substage_id = "fixture:changed-return"
	request.context.presentation.fields.qualifying_cause = "condition_hospital"
	var read: Dictionary = game.read_hospital_presentation_request(root.token)
	assert_true(read.ok, str(read))
	if not read.ok: return
	assert_eq(read.value, original, "input and output dictionaries cannot mutate the saved request")
	read.value.substage_id = "fixture:changed-read"
	assert_eq(game.read_hospital_presentation_request(root.token).value, original)
	assert_eq(game.retain_hospital_presentation_request(original).value, original)
	assert_eq(writer.snapshots.size(), 1, "exact replay does not checkpoint twice")
	var conflict := original.duplicate(true)
	conflict.substage_id = "fixture:conflicting-intent"
	assert_eq(game.retain_hospital_presentation_request(conflict).get("code"), &"hospital_frozen_request_conflict")
	game.route_context.hospital_frozen_contexts_v1.requests[root.token].resolution_issuer_receipt = {}
	assert_eq(game.read_hospital_presentation_request(root.token).get("code"), &"hospital_frozen_request_mismatch")
	assert_eq(writer.snapshots.size(), 1)

func before_each() -> void:
	_retained_scope.install(true)

func after_each() -> void:
	_retained_scope.restore()
