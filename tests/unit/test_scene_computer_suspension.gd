extends "res://addons/gut/test.gd"
## Computer custody with a fake physical frontier, real Bridge and mutation gate.
## Native Dialogic timing and rendered app/checkpoint cooperation require cloud E2E.
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const HANDLE := {"generation": 1, "handle_id": "TEST.pause", "holder": &"TEST", "reason": &"universal_pause"}
class Session extends RefCounted:
	var family := "scene"
	var ledger := RefCounted.new()
class Bridge extends "res://autoload/DialogicBridge.gd":
	var native := {"generation": 1, "event_index": 2, "request_id": "TEST.native", "paused": false}
	var writes: Array[bool] = []
	var fail_next := false
	var replace_next := false
	func capture_pause_frontier(_timeline_id: String = "") -> Dictionary:
		var value := native.duplicate(true)
		value.erase("paused")
		return {"ok": true, "value": value}
	# Explicit semantic marker fixture; this does not qualify native marker binding.
	func _marker_source_valid() -> bool:
		return true
	func _capture_presentation_frontier() -> Dictionary:
		return {"ok": true, "value": native.duplicate(true)}
	func _set_presentation_paused(value: bool) -> Dictionary:
		writes.append(value)
		native.paused = value
		if replace_next:
			replace_next = false
			native.generation += 1
		if fail_next:
			fail_next = false
			return {"ok": false, "code": &"TEST.refused_after_write"}
		return {"ok": true}
var bridge: Bridge
var host: Node
var gate: RefCounted

func before_each() -> void:
	bridge = Bridge.new()
	host = Node.new()
	gate = GATE.new()
	bridge._mutation_gate = gate
	bridge._reading_session = Session.new()

func after_each() -> void:
	bridge.free()
	host.free()

func test_native_hold_keeps_causal_gate_available_and_restores_prior_bit() -> void:
	for prior: bool in [false, true]:
		bridge.native.paused = prior
		assert_true(bridge.hold_computer_captions(host).ok)
		assert_true(bridge.native.paused)
		assert_true(bridge.is_computer_caption_held())
		assert_true(bridge._pause_handle.is_empty(), "Computer never impersonates universal Pause")
		assert_true(gate.guard_external(&"scene_shop").ok)
		var acquired: Dictionary = gate.acquire(&"causal_transaction")
		assert_true(acquired.ok)
		assert_false(bridge.release_computer_captions(host).ok, "close cannot release source inside a transaction")
		assert_true(gate.release(&"causal_transaction", acquired.value.token).ok)
		assert_true(bridge.release_computer_captions(host).ok)
		assert_eq(bridge.native.paused, prior)
		assert_false(bridge.is_computer_caption_held())

func test_timed_and_art_frontier_identity_survives_repeat_open_without_reacquiring() -> void:
	for extra: Dictionary in [{"kind": "timed_hold", "execution_token": 17}, {"event_index": -1, "request_id": "TEST.art"}]:
		bridge.native = {"generation": 1, "event_index": 2, "request_id": "TEST.native", "paused": false}
		bridge.native.merge(extra, true)
		var before := bridge.native.duplicate(true)
		assert_true(bridge.hold_computer_captions(host).ok)
		var writes: int = bridge.writes.size()
		assert_true(bridge.hold_computer_captions(host).ok)
		assert_eq(bridge.writes.size(), writes)
		assert_true(bridge.release_computer_captions(host).ok)
		assert_eq(bridge.native, before)

func test_foreign_host_or_changed_source_never_resumes_a_replacement() -> void:
	assert_true(bridge.hold_computer_captions(host).ok)
	var foreign := Node.new()
	assert_false(bridge.hold_computer_captions(foreign).ok)
	assert_false(bridge.release_computer_captions(foreign).ok)
	foreign.free()
	bridge.native.event_index += 1
	var writes: int = bridge.writes.size()
	assert_false(bridge.release_computer_captions(host).ok)
	assert_eq(bridge.writes.size(), writes)
	assert_true(bridge.native.paused)
	bridge._reading_session = Session.new()
	assert_false(bridge.hold_computer_captions(host).ok)

func test_acquisition_refusal_compensates_exact_native_source() -> void:
	bridge.fail_next = true
	var before := bridge.native.duplicate(true)
	assert_eq(bridge.hold_computer_captions(host).code, &"computer_suspend_failed")
	assert_eq(bridge.native, before)
	assert_false(bridge.is_computer_caption_held())
	assert_true(bridge._computer_hold_frontier.is_empty())
	assert_true(bridge.hold_computer_captions(host).ok, "safe refusal leaves retry available")

func test_replaced_source_during_acquisition_retains_uncertain_custody() -> void:
	bridge.replace_next = true
	var result: Dictionary = bridge.hold_computer_captions(host)
	assert_false(result.ok)
	assert_true(result.recovery_required)
	assert_eq(bridge.writes, [true], "foreign source must never be compensated")
	assert_false(bridge._computer_hold_frontier.is_empty())
	assert_false(bridge.release_computer_captions(host).ok)

func test_failed_release_reholds_exact_source_and_can_retry() -> void:
	assert_true(bridge.hold_computer_captions(host).ok)
	bridge.fail_next = true
	var result: Dictionary = bridge.release_computer_captions(host)
	assert_false(result.ok)
	assert_true(bridge.is_computer_caption_held())
	assert_true(bridge.native.paused)
	assert_true(bridge.release_computer_captions(host).ok)
	assert_false(bridge.native.paused)

func test_full_pause_restore_and_busy_gate_conflict_before_writing() -> void:
	bridge._pause_handle = HANDLE.duplicate(true)
	assert_false(bridge.hold_computer_captions(host).ok)
	bridge._pause_handle = {}
	bridge._pause_restore = {"applied": false}
	assert_false(bridge.hold_computer_captions(host).ok)
	bridge._pause_restore = {}
	var acquired: Dictionary = gate.acquire(&"restore")
	assert_false(bridge.hold_computer_captions(host).ok)
	assert_eq(bridge.writes.size(), 0)
	gate.release(&"restore", acquired.value.token)
	assert_true(bridge.hold_computer_captions(host).ok)
	assert_eq(bridge.begin_suspend(HANDLE).code, &"computer_caption_held")
	assert_true(bridge.release_computer_captions(host).ok)

func test_checkpoint_reads_held_source_under_lease_but_refuses_same_semantic_native_replacement() -> void:
	bridge._marker_context = {"checkpoint": {"TEST.semantic_line": "unchanged"},
		"anchor": {"TEST.publication": "same"}, "playback_token": "TEST.playback"}
	var semantic := bridge._marker_context.duplicate(true)
	assert_true(bridge.hold_computer_captions(host).ok)
	var acquired: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(acquired.ok)
	var held: Dictionary = bridge.capture_scene_event_boundary()
	assert_true(held.ok, "read-only source proof remains available during a causal checkpoint")
	if held.ok: assert_eq(held.value, semantic)
	assert_true(gate.is_lease_active(&"causal_transaction", acquired.value.token))
	bridge._computer_hold_changing = true
	assert_eq(bridge.capture_scene_event_boundary().code, &"computer_source_changed")
	bridge._computer_hold_changing = false
	bridge.native.generation += 1 # Fault: native replacement with identical saved semantic line.
	var changed: Dictionary = bridge.capture_scene_event_boundary()
	assert_false(changed.ok)
	assert_eq(changed.code, &"computer_source_changed")
	assert_eq(bridge._marker_context, semantic, "semantic equality alone cannot authorize the checkpoint")
	assert_true(gate.is_lease_active(&"causal_transaction", acquired.value.token))
	assert_true(gate.release(&"causal_transaction", acquired.value.token).ok)
