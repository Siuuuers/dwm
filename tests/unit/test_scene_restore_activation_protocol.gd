extends "res://addons/gut/test.gd"

# Protocol diagnostics: actual SaveManager and continuation state machine,
# memory storage plus explicit participant/Save9-admission fakes. No filesystem,
# rendered/native or full Save9 acceptance claim is made by this suite.
const MANAGER := preload("res://autoload/SaveManager.gd")
const JOURNAL_TEST := preload("res://tests/unit/test_scene_restore_journal.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")

class Gate:
	extends RefCounted
	var fatal := false
	var released := false
	func is_lease_active(_owner: StringName, token: String) -> bool: return token == "lease" and not released and not fatal
	func release(_owner: StringName, _token: String) -> Dictionary:
		released = true
		return {"ok": true}
	func is_fatal_latched() -> bool: return fatal
	func latch_fatal(_failure: Dictionary) -> void: fatal = true
	func guard_external(_owner: StringName) -> Dictionary:
		return {"ok": not fatal, "code": &"APPLICATION_FATAL" if fatal else &"ok"}

class Checkpoints:
	extends RefCounted
	var rollbacks := 0
	func capture_state() -> Dictionary: return {"ok": true, "value": {"backup": {}}}
	func commit_prepared(_candidate: Dictionary) -> Dictionary: return {"ok": true}
	func restore_state(_backup: Dictionary) -> Dictionary:
		rollbacks += 1
		return {"ok": true}

class Participant:
	extends RefCounted
	signal scene_activation_confirmed(operation_id: String)
	signal scene_activation_failed(operation_id: String, result: Dictionary)
	var confirmed := false
	var started := false
	var published := 0
	var rollbacks := 0
	var activated := 0
	var silent_applies := 0
	var route_generation := 1
	var last_plan: Dictionary = {}
	var begin_observer := Callable()
	func capture() -> Dictionary: return {"ok": true, "value": {}}
	func apply_silent(plan: Dictionary) -> Dictionary:
		silent_applies += 1
		last_plan = plan.duplicate(true)
		return {"ok": true, "value": {"route_ready_token": {"generation": route_generation}}}
	func rollback_silent(_backup: Dictionary) -> Dictionary:
		rollbacks += 1
		return {"ok": true}
	func finalize() -> Dictionary: return {"ok": true}
	func begin_scene_publication_hold(_operation: String) -> Dictionary: return {"ok": true}
	func cancel_scene_publication_hold(_operation: String) -> Dictionary: return {"ok": true}
	func begin_scene_activation(operation: String) -> Dictionary:
		started = true
		if begin_observer.is_valid(): begin_observer.call(operation)
		return {"ok": true}
	func validate_scene_activation(_operation: String) -> Dictionary: return {"ok": confirmed}
	func publish_scene_activation(_operation: String) -> Dictionary:
		published += 1
		return {"ok": true}
	func validate_live_session_activation(_ticket: Dictionary) -> Dictionary: return {"ok": true}
	func activate_live_session(_ticket: Dictionary) -> Dictionary:
		activated += 1
		return {"ok": true}
	func confirm(operation: String) -> void:
		confirmed = true
		scene_activation_confirmed.emit(operation)

var manager: Node
var journal: RefCounted
var storage: RefCounted
var operation: Dictionary
var participants: Dictionary
var plans: Dictionary
var gate: Gate
var route_crash_text := ""

func before_each() -> void:
	storage = JOURNAL_TEST.MemoryStorage.new()
	journal = JOURNAL_TEST.StateMachineOnly.new()
	assert_true(journal.configure(storage, JOURNAL_TEST.SourceLoader.new()).ok)
	var tx := "transaction_id." + "a".repeat(64)
	var request := {"allocation_candidate_fingerprint": "b".repeat(64), "initial_context": null,
		"initial_context_sha256": null, "kind": "scene_restore", "new_run_materials": null,
		"request_fingerprint": "c".repeat(64), "source_locator": {"bundle_id": "d".repeat(64),
			"checkpoint_id": "selected", "document_sha256": "e".repeat(64), "slot_id": "slot:1"},
		"transaction_id": tx, "transaction_issuer_receipt": {"counter": 0, "namespace": "e".repeat(64),
			"numeric_value": null, "purpose": "transaction_id", "receipt_id": "issuer_receipt." + "f".repeat(64), "token": tx},
		"selected_document": {"fixture": "journal-transition-only"}}
	var intent: Dictionary = journal.prepare_intent(request)
	assert_true(intent.ok)
	operation = journal.commit_intent(intent.value).value
	_advance(JOURNAL.STAGE_ALLOCATED, {"diagnostic": true})
	_advance(JOURNAL.STAGE_APPLYING)
	participants = {}
	plans = {}
	for name: String in JOURNAL.SCENE_PARTICIPANT_ORDER:
		participants[name] = Participant.new()
		plans[name] = {}
		var result: Dictionary = journal.advance({"transaction_id": tx, "request_fingerprint": operation.request_fingerprint,
			"expected_stage": JOURNAL.STAGE_APPLYING, "next_stage": JOURNAL.STAGE_APPLYING,
			"expected_next_participant_index": operation.next_participant_index,
			"allocation_receipt": null, "participant_name": name,
			"participant_receipt": {"route_ready_token": {"generation": 1}} if name == "route" else {}, "failure": null})
		assert_true(result.ok)
		operation = result.value
		if name == "route": route_crash_text = storage.text
	_advance(JOURNAL.STAGE_APPLIED)
	manager = MANAGER.new()
	manager._continuation_journal = journal
	manager._journal = Checkpoints.new()
	manager._restore_participants = participants
	gate = Gate.new()
	manager._mutation_gate = gate
	manager._lock_owner = &"restore"

func after_each() -> void:
	manager.free()

func _advance(stage: String, allocation: Variant = null) -> void:
	var result: Dictionary = journal.advance({"transaction_id": operation.transaction_id,
		"request_fingerprint": operation.request_fingerprint, "expected_stage": operation.stage,
		"next_stage": stage, "expected_next_participant_index": operation.next_participant_index,
		"allocation_receipt": allocation, "participant_name": null, "participant_receipt": null, "failure": null})
	assert_true(result.ok)
	operation = result.value

func _start() -> Dictionary:
	return manager._run_scene_restore_transaction(plans, {}, "scene", "selected", true,
		{"kind": "scene_restore", "transaction_id": operation.transaction_id,
			"request_fingerprint": operation.request_fingerprint}, "lease", true)

func test_completion_precedes_route_then_native_and_ack_precedes_publication() -> void:
	participants.route.begin_observer = func(_id: String):
		var retained: Dictionary = journal.get_operation(operation.transaction_id).value
		assert_eq(retained.stage, JOURNAL.STAGE_COMPLETED)
		assert_eq(retained.activation_state, "pending")
	var result := _start()
	assert_eq(result.code, &"scene_activation_pending")
	assert_true(participants.route.started)
	assert_false(participants.narrative.started)
	participants.route.confirm(operation.transaction_id)
	assert_true(participants.narrative.started)
	assert_eq(participants.run.activated, 0)
	participants.narrative.confirm(operation.transaction_id)
	assert_eq(journal.get_operation(operation.transaction_id).value.activation_state, "acknowledged")
	assert_eq(participants.run.activated, 1)
	assert_eq(participants.route.published, 1)
	assert_true(gate.released)
	participants.narrative.confirm(operation.transaction_id)
	assert_eq(participants.run.activated, 1, "duplicate confirmation cannot adopt twice")

func test_promoted_completion_with_refused_ack_never_rolls_back() -> void:
	storage.promote_then_refuse = true
	var result := _start()
	assert_eq(result.code, &"scene_activation_pending")
	assert_true(participants.route.started, "durable reread proves completed pending")
	assert_eq(participants.run.rollbacks, 0)
	assert_eq(manager._journal.rollbacks, 0)
	assert_false(gate.released)

func test_definite_completion_refusal_rolls_back_without_native_start() -> void:
	storage.refuse = true
	var result := _start()
	assert_false(result.ok)
	assert_false(participants.route.started)
	assert_false(participants.narrative.started)
	assert_eq(participants.run.rollbacks, 1)
	assert_true(gate.released)

func test_native_failure_after_completed_retains_target_and_custody() -> void:
	assert_eq(_start().code, &"scene_activation_pending")
	participants.route.confirm(operation.transaction_id)
	participants.narrative.scene_activation_failed.emit(operation.transaction_id, {"ok": false, "code": &"diagnostic_native_failed"})
	assert_eq(journal.get_operation(operation.transaction_id).value.stage, JOURNAL.STAGE_COMPLETED)
	assert_eq(journal.get_operation(operation.transaction_id).value.activation_state, "pending")
	assert_eq(participants.run.rollbacks, 0)
	assert_eq(participants.route.published, 0)
	assert_false(gate.released)
	assert_true(gate.fatal)

func test_restart_after_recorded_route_reapplies_live_owners_without_rewriting_prefix() -> void:
	# Capture was produced by the real journal immediately after route's receipt,
	# before narrative/APPLIED. Reopen those exact bytes with fresh process owners.
	manager.free()
	storage = JOURNAL_TEST.MemoryStorage.new()
	storage.text = route_crash_text
	journal = JOURNAL_TEST.StateMachineOnly.new()
	assert_true(journal.configure(storage, JOURNAL_TEST.SourceLoader.new()).ok)
	var loaded: Dictionary = journal.get_operation(operation.transaction_id)
	assert_true(loaded.ok)
	if not loaded.ok:
		manager = MANAGER.new()
		return
	operation = loaded.value
	assert_eq(operation.stage, JOURNAL.STAGE_APPLYING)
	assert_eq(operation.next_participant_index, 7)
	var original_prefix: Dictionary = operation.participant_receipts.duplicate(true)
	var original_allocation: Dictionary = operation.allocation_receipt.duplicate(true)
	participants = {}
	for name: String in JOURNAL.SCENE_PARTICIPANT_ORDER:
		participants[name] = Participant.new()
	participants.route.route_generation = 77
	manager = MANAGER.new()
	manager._continuation_journal = journal
	manager._journal = Checkpoints.new()
	manager._restore_participants = participants
	gate = Gate.new()
	manager._mutation_gate = gate
	manager._lock_owner = &"restore"
	var result: Dictionary = manager._run_scene_restore_transaction(plans, {}, "scene", "selected", true,
		{"kind": "scene_restore", "transaction_id": operation.transaction_id,
			"request_fingerprint": operation.request_fingerprint}, "lease", false)
	assert_eq(result.get("code"), &"scene_activation_pending", str(result))
	var retained: Dictionary = journal.get_operation(operation.transaction_id).value
	assert_eq(retained.stage, JOURNAL.STAGE_COMPLETED)
	assert_eq(retained.activation_state, "pending")
	assert_eq(retained.transaction_id, operation.transaction_id)
	assert_eq(storage.writes, 3, "only narrative suffix, APPLIED and COMPLETED are newly recorded")
	assert_eq(retained.allocation_receipt, original_allocation)
	# The journal retains null placeholders for the unrecorded suffix too.
	assert_null(original_prefix.narrative)
	assert_not_null(retained.participant_receipts.narrative)
	for index: int in operation.next_participant_index:
		var name: String = JOURNAL.SCENE_PARTICIPANT_ORDER[index]
		assert_eq(retained.participant_receipts[name], original_prefix[name], "durable prefix stays exact: " + name)
	for participant: Participant in participants.values():
		assert_eq(participant.silent_applies, 1, "fresh process rebuilds each owner exactly once")
		assert_eq(participant.rollbacks, 0)
		assert_eq(participant.published, 0, "silent replay publishes no consequence")
	assert_eq(participants.narrative.last_plan.route_ready_token.generation, 77,
		"native staging receives the new process token rather than historical route receipt")
	assert_eq(participants.run.activated, 0)
	assert_false(participants.narrative.started)
