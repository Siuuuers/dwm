extends "res://addons/gut/test.gd"
# DialogicBridge -> GameState effect/variable transaction boundary (dwm-p2r.8, Plan-05 Task 3).
# The injected shared gate is consulted FIRST: a gate failure must return before manifest lookup,
# transient-boundary creation, provider exposure, or any GameState invocation.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const FAKE_GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")

var _bridge: Node


class _FakeAdapter extends RefCounted:
	signal timeline_started_signal
	signal timeline_ended_signal
	signal event_handled_signal(resource)
	signal runtime_signal_event(argument)
	signal preference_reapply_requested
	var halted := false
	func start_timeline(path: String, event_index: Variant = 0) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"path": path, "event_index": event_index}}
	func halt_with_error(_r: Dictionary) -> Dictionary:
		halted = true
		return {"ok": false, "code": &"runtime_halted"}


func before_each() -> void:
	GameState.reset_game()
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)


func _adapter() -> _FakeAdapter:
	var adapter := _FakeAdapter.new()
	_bridge.initialize(null, adapter)
	return adapter


func _effect_payload(transaction_id: String = "run:effect:boundary") -> Dictionary:
	return {"kind": "effect_transaction", "transaction_id": transaction_id,
		"effect_ids": ["pressure:+2"], "source_id": "boundary_test"}


func test_effect_transaction_payload_commits_through_game_state() -> void:
	var adapter := _adapter()
	assert_eq(GameState.get_stat("pressure"), 3, "baseline")
	adapter.runtime_signal_event.emit(_effect_payload())
	assert_eq(GameState.get_stat("pressure"), 5, "the bridge routed the effect into the atomic commit")
	assert_false(adapter.halted, "a registered payload never halts the timeline")


func test_effect_transaction_is_idempotent_across_repeat_signals() -> void:
	var adapter := _adapter()
	adapter.runtime_signal_event.emit(_effect_payload())
	adapter.runtime_signal_event.emit(_effect_payload())
	assert_eq(GameState.get_stat("pressure"), 5, "a duplicate transaction id applies exactly once")


func test_gate_failure_blocks_before_any_mutation() -> void:
	var adapter := _adapter()
	var gate: Object = FAKE_GATE.new()
	assert_true(_bridge.configure_mutation_gate(gate).get("ok", false), "gate injected")
	var acquired: Dictionary = gate.acquire(&"restore")
	adapter.runtime_signal_event.emit(_effect_payload())
	assert_eq(GameState.get_stat("pressure"), 3, "a blocked gate mutates nothing")
	gate.release(&"restore", str(acquired["value"]["token"]))


func test_gate_release_allows_the_same_transaction_afterwards() -> void:
	var adapter := _adapter()
	var gate: Object = FAKE_GATE.new()
	_bridge.configure_mutation_gate(gate)
	var acquired: Dictionary = gate.acquire(&"restore")
	adapter.runtime_signal_event.emit(_effect_payload())
	gate.release(&"restore", str(acquired["value"]["token"]))
	adapter.runtime_signal_event.emit(_effect_payload())
	assert_eq(GameState.get_stat("pressure"), 5, "the blocked transaction is not consumed and applies after release")


func test_unknown_effect_in_payload_leaves_state_unchanged() -> void:
	var adapter := _adapter()
	var payload := _effect_payload("run:effect:bad")
	payload["effect_ids"] = ["pressure:+2", "not:a:real:effect"]
	adapter.runtime_signal_event.emit(payload)
	assert_eq(GameState.get_stat("pressure"), 3, "an invalid batch member applies nothing")


func test_unregistered_payload_kind_halts_without_mutation() -> void:
	var adapter := _adapter()
	var failures: Array = []
	_bridge.narrative_validation_failed.connect(func(result: Dictionary) -> void: failures.append(result))
	adapter.runtime_signal_event.emit({"kind": "not_a_registered_kind"})
	assert_eq(failures.size(), 1, "narrative_validation_failed emitted")
	assert_true(adapter.halted, "runtime halted through the adapter")
	assert_eq(GameState.get_stat("pressure"), 3, "no domain mutation")


func test_malformed_transaction_payload_rejects_without_mutation() -> void:
	var adapter := _adapter()
	var payload := _effect_payload("")
	adapter.runtime_signal_event.emit(payload)
	assert_eq(GameState.get_stat("pressure"), 3, "an empty transaction id mutates nothing")


func test_transaction_checkpoint_provider_serves_only_the_active_event() -> void:
	_adapter()
	# With no transient transaction in flight the provider must refuse.
	var idle: Dictionary = _bridge.provide_transaction_narrative_checkpoint("run:effect:x", "src", &"effect_transaction")
	assert_false(idle.get("ok", false), "provider refuses outside an active transaction")
	assert_false(idle.has("value"), "no checkpoint is exposed on refusal")


func test_variable_transaction_payload_rejects_unregistered_variable() -> void:
	var adapter := _adapter()
	adapter.runtime_signal_event.emit({"kind": "variable_transaction", "transaction_id": "run:variable:boundary",
		"variable_id": "unregistered.variable", "value": 1, "source_id": "boundary_test"})
	var captured: Dictionary = GameState.capture_run_snapshot_input()
	assert_eq(captured["applied_variable_transaction_ids"], [], "no variable transaction recorded")
	assert_eq(captured["command_receipts"], {}, "no receipt recorded for an unregistered variable")
