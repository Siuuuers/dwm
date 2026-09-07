extends "res://addons/gut/test.gd"

const FIXTURE := preload("res://tests/unit/test_new_run_replacement_baseline.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
var fixture: Node
var run_owner: Node
var gate: RefCounted

func before_each() -> void:
	fixture = add_child_autofree(FIXTURE.new())
	fixture.gut = gut
	run_owner = fixture._owner()
	gate = GATE.new()
	assert_true(run_owner.configure_mutation_gate(gate).ok)

func _supported() -> bool:
	for method: String in ["capture_live_session", "validate_live_session", "validate_live_session_activation", "activate_live_session", "retire_live_session", "capture_live_run_snapshot_input"]:
		if not run_owner.has_method(method):
			fail_test("Missing session ownership: " + method)
			return false
	return true

func _ticket(operation: String, run_id: String) -> Dictionary:
	var session: Dictionary = run_owner.capture_live_session().value
	return {"operation_id": operation, "expected_generation": session.generation,
		"owner_id": session.owner_id, "run_id": run_id}

func _install(run_id: String) -> void:
	assert_true(run_owner.apply_restore_silent({"snapshot": fixture._snapshot(run_owner, run_id)}).ok)

func _activate(operation: String, run_id: String) -> Dictionary:
	var ticket := _ticket(operation, run_id)
	var custody: Dictionary = gate.acquire(&"new_run")
	assert_true(custody.ok)
	_install(run_id)
	assert_true(run_owner.validate_live_session_activation(ticket).ok)
	assert_true(run_owner.activate_live_session(ticket).ok)
	assert_true(gate.release(&"new_run", custody.value.token).ok)
	return ticket

func test_installation_alone_never_publishes_a_session_and_activation_requires_custody() -> void:
	if not _supported(): return
	var empty: Dictionary = run_owner.capture_live_session()
	assert_false(empty.value.active)
	var ticket := _ticket("operation-A", "run-A")
	_install("run-A")
	assert_eq(run_owner.capture_live_session(), empty, "participant apply does not invalidate the old session")
	assert_false(run_owner.activate_live_session(ticket).ok)
	var lease: Dictionary = gate.acquire(&"new_run")
	assert_true(run_owner.activate_live_session(ticket).ok)
	var live: Dictionary = run_owner.capture_live_session().value
	assert_true(live.active)
	assert_false(run_owner.validate_live_session(live).ok, "gate still blocks callbacks after activation")
	assert_true(gate.release(&"new_run", lease.value.token).ok)
	assert_true(run_owner.validate_live_session(live).ok)
	assert_eq(run_owner.capture_live_run_snapshot_input(live).value, run_owner.capture_run_snapshot_input())

func test_exact_activation_replay_is_idempotent_but_old_tickets_cannot_replace_later_sessions() -> void:
	if not _supported(): return
	var first := _activate("operation-A", "run-A")
	var first_handle: Dictionary = run_owner.capture_live_session().value
	var lease: Dictionary = gate.acquire(&"restore")
	assert_true(run_owner.activate_live_session(first).ok)
	assert_eq(run_owner.capture_live_session().value, first_handle)
	assert_true(gate.release(&"restore", lease.value.token).ok)
	_activate("operation-B", "run-B")
	var second_handle: Dictionary = run_owner.capture_live_session().value
	assert_gt(second_handle.generation, first_handle.generation)
	assert_false(run_owner.validate_live_session(first_handle).ok)
	lease = gate.acquire(&"restore")
	assert_false(run_owner.activate_live_session(first).ok)
	assert_eq(run_owner.capture_live_session().value, second_handle)

func test_compensated_candidate_apply_and_rollback_preserve_the_original_session() -> void:
	if not _supported(): return
	_activate("operation-A", "run-A")
	var handle: Dictionary = run_owner.capture_live_session().value
	var backup: Dictionary = run_owner.capture_restore_state().value
	var lease: Dictionary = gate.acquire(&"restore")
	_install("run-B")
	assert_false(run_owner.validate_live_session(handle).ok)
	assert_eq(run_owner.capture_live_session().value, handle)
	assert_true(run_owner.rollback_restore_silent(backup).ok)
	assert_true(gate.release(&"restore", lease.value.token).ok)
	assert_eq(run_owner.capture_live_session().value, handle)
	assert_true(run_owner.validate_live_session(handle).ok, "fully compensated Load leaves Pause resumable")

func test_retirement_is_quiet_preserves_dormant_facts_and_refuses_old_capture_and_backup() -> void:
	if not _supported(): return
	var ticket := _activate("operation-A", "run-A")
	var handle: Dictionary = run_owner.capture_live_session().value
	var raw: Dictionary = run_owner.capture_run_snapshot_input()
	var backup: Dictionary = run_owner.capture_restore_state().value
	var counts := {}
	for signal_name: String in FIXTURE.SIGNALS: counts[signal_name] = get_signal_emit_count(run_owner, signal_name)
	assert_false(run_owner.retire_live_session(handle).ok)
	var lease: Dictionary = gate.acquire(&"session_abandonment")
	assert_true(run_owner.retire_live_session(handle).ok)
	var retired: Dictionary = run_owner.capture_live_session().value
	assert_false(retired.active)
	assert_gt(retired.generation, handle.generation)
	assert_true(run_owner.retire_live_session(handle).ok)
	assert_eq(run_owner.capture_live_session().value, retired)
	assert_eq(run_owner.capture_run_snapshot_input(), raw, "no run/board/RNG/receipt reset belongs to Return")
	assert_false(run_owner.get_new_run_replacement_baseline().value.present)
	assert_false(run_owner.rollback_restore_silent(backup).ok, "old backups cannot rewind retirement")
	for signal_name: String in FIXTURE.SIGNALS: assert_eq(get_signal_emit_count(run_owner, signal_name), counts[signal_name])
	assert_true(gate.release(&"session_abandonment", lease.value.token).ok)
	assert_false(run_owner.validate_live_session(handle).ok)
	assert_false(run_owner.capture_live_run_snapshot_input(handle).ok)
	lease = gate.acquire(&"new_run")
	assert_false(run_owner.activate_live_session(ticket).ok)

func test_new_session_after_retirement_never_revives_old_handles_or_retirement_receipts() -> void:
	if not _supported(): return
	_activate("operation-A", "run-A")
	var handle: Dictionary = run_owner.capture_live_session().value
	var lease: Dictionary = gate.acquire(&"session_abandonment")
	assert_true(run_owner.retire_live_session(handle).ok)
	assert_true(gate.release(&"session_abandonment", lease.value.token).ok)
	_activate("operation-B", "run-B")
	var current: Dictionary = run_owner.capture_live_session().value
	assert_true(run_owner.validate_live_session(current).ok)
	assert_false(run_owner.validate_live_session(handle).ok)
	lease = gate.acquire(&"session_abandonment")
	assert_false(run_owner.retire_live_session(handle).ok)
	assert_eq(run_owner.capture_live_session().value, current)

func test_malformed_foreign_and_candidate_mismatched_activation_refuse_before_mutation() -> void:
	if not _supported(): return
	var ticket := _ticket("operation-A", "run-A")
	_install("run-A")
	assert_true(gate.acquire(&"new_run").ok)
	var before: Dictionary = run_owner.capture_live_session()
	var cases: Array = [null, {}, {"operation_id": "operation-A"}]
	for patch: Dictionary in [{"owner_id": 0}, {"expected_generation": -1}, {"expected_generation": true}, {"run_id": "different"}, {"operation_id": ""}, {"extra": 1}]:
		var invalid := ticket.duplicate(true)
		invalid.merge(patch, true)
		cases.append(invalid)
	for invalid: Variant in cases:
		assert_false(run_owner.activate_live_session(invalid).ok)
		assert_eq(run_owner.capture_live_session(), before)

func test_reset_retires_session_without_allowing_old_owner_backups_to_reactivate_it() -> void:
	if not _supported(): return
	_activate("operation-A", "run-A")
	var handle: Dictionary = run_owner.capture_live_session().value
	var backup: Dictionary = run_owner.capture_restore_state().value
	run_owner.reset_game()
	assert_false(run_owner.capture_live_session().value.active)
	assert_false(run_owner.validate_live_session(handle).ok)
	assert_false(run_owner.rollback_restore_silent(backup).ok)
