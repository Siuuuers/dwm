extends "res://addons/gut/test.gd"
# Held fast-forward through DialogicBridge (dwm-p2r.8, Plan-05 Task 4 Steps 4.2/4.3).
# Repeated request_skip_step() must reveal each line, mark it globally visited BEFORE deciding,
# and stop before every boundary WITHOUT consuming it.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const POLICY := preload("res://scripts/narrative/SkipPolicy.gd")
const ENTRY_ID := "contact.ordinary.lavinia.day1"
const LINE_A := "line.contact.ordinary.lavinia.day1.reply.a"
const LINE_B := "line.contact.ordinary.lavinia.day1.reply.b"
const LINE_C := "line.contact.ordinary.lavinia.day1.reply.c"

var _bridge: Node


class _FakeProfile extends Node:
	signal visited_history_changed(line_id: String, visited: bool)
	var auto_enabled := false
	func get_preference(path: StringName, fallback: Variant = null) -> Variant:
		return auto_enabled if path == &"preferences.reading.auto_enabled" else fallback
	var visited: Array[String] = []
	var fail_write := false
	var failure_result: Dictionary = {}
	var mark_calls: Array[String] = []
	func is_line_visited(line_id: String) -> bool:
		return line_id in visited
	func mark_line_visited(line_id: String) -> Dictionary:
		mark_calls.append(line_id)
		if not failure_result.is_empty(): return failure_result.duplicate(true)
		if fail_write:
			return {"ok": false, "code": &"profile_write_failed", "message": ""}
		if line_id in visited:
			return {"ok": true, "value": {"visited": true}, "unchanged": true}
		visited.append(line_id)
		visited_history_changed.emit(line_id, true)
		return {"ok": true, "value": {"visited": true}}


class _FakeAdapter extends RefCounted:
	signal timeline_started_signal
	signal timeline_ended_signal
	signal event_handled_signal(resource)
	signal runtime_signal_event(argument)
	signal preference_reapply_requested
	## Scripted playhead: each entry is [line_id, next_boundary_kind].
	var script_events: Array = []
	var cursor := 0
	var generation := 1
	var line_complete := true
	var calls: Array[String] = []
	var reveal_callback := Callable()
	var preserved_boundaries: Array[bool] = []
	func start_timeline(path: String, event_index: Variant = 0) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"path": path, "event_index": event_index}}
	func reveal_current_line(preserve_next_boundary: bool = false) -> Dictionary:
		calls.append("reveal:%d" % cursor)
		preserved_boundaries.append(preserve_next_boundary)
		# One-shot callback models synchronous Text.text_finished listeners without
		# allowing an unguarded nested request to recurse indefinitely in a regression.
		var callback := reveal_callback
		reveal_callback = Callable()
		if callback.is_valid():
			callback.call()
		return {"ok": true, "code": &"ok", "value": {}}
	func capture_pause_frontier() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {
			"generation": generation, "event_index": cursor,
			"request_id": "skip-fixture", "paused": false,
		}}
	func current_line_id() -> String:
		if cursor >= script_events.size():
			return ""
		return str(script_events[cursor][0])
	func is_current_line_complete() -> bool:
		return line_complete and not current_line_id().is_empty()
	func classify_next_event() -> StringName:
		if cursor >= script_events.size():
			return &"none"
		return StringName(str(script_events[cursor][1]))
	func advance_one_event() -> Dictionary:
		calls.append("advance:%d" % cursor)
		cursor += 1
		return {"ok": true, "code": &"ok", "value": {"current_event_idx": cursor}}
	func halt_with_error(_r: Dictionary) -> Dictionary:
		return {"ok": false}


class _FakeMutationGate extends Node:
	signal capability_changed
	var held := true
	func acquire(_owner: StringName) -> Dictionary: return {"ok": true}
	func release(_owner: StringName) -> Dictionary: return {"ok": true}
	func guard_external(_operation: StringName) -> Dictionary:
		return {"ok": false, "code": &"fixture_gate_held"} if held else {"ok": true, "code": &"ok"}
	func is_active() -> bool: return held
	func get_active_owner() -> StringName: return &"fixture" if held else &""
	func is_internal_owner_active(_owner: StringName) -> bool: return false
	func latch_fatal(_result: Dictionary) -> void: pass
	func is_fatal_latched() -> bool: return false


func before_each() -> void:
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)


func _active_entry_fixture(token: String = "skip-fixture-token") -> Dictionary:
	return {"entry_id": ENTRY_ID, "token": token, "stage": "current_entry",
		"execution_mode": &"canonical"}


func _has_presentation_acknowledgement_surface() -> bool:
	var available := _bridge.has_method("acknowledge_current_line_presentation") \
		and _bridge.has_method("requires_line_presentation_acknowledgement") \
		and _bridge.has_method("is_current_line_presentation_acknowledged") \
		and _bridge.has_method("capture_current_line_presentation_frontier")
	assert_true(available,
		"DialogicBridge exposes presentation acknowledgement and its pending gate")
	return available


func _wired(events: Array, mode: StringName, visited_seed: Array[String] = []) -> Dictionary:
	var adapter := _FakeAdapter.new()
	adapter.script_events = events
	var profile := _FakeProfile.new()
	profile.visited.assign(visited_seed)
	add_child_autofree(profile)
	assert_true(_bridge.initialize(null, adapter).get("ok", false))
	_bridge._active_entry = _active_entry_fixture()
	assert_true(_bridge.configure_skip_context(profile, mode).get("ok", false), "skip context configured")
	return {"adapter": adapter, "profile": profile}


func test_bridge_exposes_the_skip_command() -> void:
	assert_true(_bridge.has_method("request_skip_step"), "DialogicBridge.request_skip_step is required")
	assert_true(_bridge.has_method("configure_skip_context"), "DialogicBridge.configure_skip_context is required")


func test_all_text_fast_forwards_through_unread_text() -> void:
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"], [LINE_C, "choice"]], POLICY.ALL_TEXT)
	var adapter: RefCounted = wired["adapter"]
	assert_true(_bridge.request_skip_step().get("ok", false), "first skip step")
	assert_true(_bridge.request_skip_step().get("ok", false), "second skip step")
	assert_eq(adapter.cursor, 2, "all_text advanced through both unread lines")


func test_read_only_stops_at_the_first_unread_line() -> void:
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.READ_ONLY)
	var adapter: RefCounted = wired["adapter"]
	var decision: Dictionary = _bridge.request_skip_step()
	assert_true(decision.get("ok", false), str(decision))
	assert_false(decision["value"]["advance"], "read_only does not advance past an unread line")
	assert_eq(adapter.cursor, 0, "the playhead did not move")
	assert_true(("reveal:0" in adapter.calls), "but the line was still revealed")


func test_read_only_advances_through_previously_visited_text() -> void:
	var seed: Array[String] = [LINE_A]
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.READ_ONLY, seed)
	var adapter: RefCounted = wired["adapter"]
	assert_true(_bridge.request_skip_step()["value"]["advance"], "a globally visited line may be skipped")
	assert_eq(adapter.cursor, 1, "the playhead advanced")


func test_visited_is_read_before_it_is_marked() -> void:
	# read_only must decide from the PRE-reveal visited state, else every line would look visited.
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.READ_ONLY)
	var profile: Node = wired["profile"]
	var decision: Dictionary = _bridge.request_skip_step()
	assert_false(decision["value"]["advance"], "the pre-reveal state decided, not the post-mark state")
	assert_eq(profile.mark_calls, [LINE_A], "the current line was still marked visited")
	assert_true(profile.is_line_visited(LINE_A), "and persisted globally")


func test_every_boundary_stops_the_skip_without_being_consumed() -> void:
	for boundary in ["choice", "effect_transaction", "variable_transaction", "safe_marker", "scene_transition", "minesweeper_entry", "validation_error"]:
		var fresh: Node = BRIDGE.new()
		add_child_autofree(fresh)
		var adapter := _FakeAdapter.new()
		adapter.script_events = [[LINE_A, boundary]]
		var profile := _FakeProfile.new()
		profile.visited.assign([LINE_A] as Array[String])
		add_child_autofree(profile)
		assert_true(fresh.initialize(null, adapter).get("ok", false))
		fresh._active_entry = _active_entry_fixture("boundary-fixture-token")
		fresh.configure_skip_context(profile, POLICY.ALL_TEXT)
		var decision: Dictionary = fresh.request_skip_step()
		assert_true(decision["value"]["stop_before_boundary"], "must stop before " + boundary)
		assert_false(decision["value"]["advance"], "must not advance into " + boundary)
		assert_eq(adapter.cursor, 0, boundary + " was not consumed")
		assert_true(("reveal:0" in adapter.calls), "current text is fully revealed at " + boundary)


func test_profile_write_failure_halts_advancement() -> void:
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.ALL_TEXT)
	var adapter: RefCounted = wired["adapter"]
	(wired["profile"] as Node).fail_write = true
	var decision: Dictionary = _bridge.request_skip_step()
	assert_false(decision.get("ok", false), "a profile write failure fails the step")
	assert_eq(adapter.cursor, 0, "advancement halted")


func test_skip_requires_a_configured_context() -> void:
	var bare: Node = BRIDGE.new()
	add_child_autofree(bare)
	assert_false(bare.request_skip_step().get("ok", false), "skip without a profile/context rejects")


func test_reentrant_reveal_callback_cannot_run_a_second_skip_step() -> void:
	var wired := _wired([[LINE_A, "text"], [LINE_B, "choice"]], POLICY.ALL_TEXT)
	var adapter: RefCounted = wired["adapter"]
	var profile: Node = wired["profile"]
	var nested_results: Array[Dictionary] = []
	adapter.reveal_callback = func() -> void:
		nested_results.append(_bridge.request_skip_step())
	var result: Dictionary = _bridge.request_skip_step()
	assert_true(result.get("ok", false), str(result))
	assert_eq(nested_results.size(), 1)
	assert_false(nested_results[0].get("ok", true))
	assert_eq(nested_results[0].get("code"), &"skip_step_in_progress")
	assert_eq(adapter.calls, ["reveal:0", "advance:0"])
	assert_eq(adapter.preserved_boundaries, [true], "Skip requests a boundary-safe reveal")
	assert_eq(profile.mark_calls, [LINE_A])
	assert_eq(adapter.cursor, 1)
	assert_true(_bridge.request_skip_step().get("ok", false), "the guard releases after a completed step")


func test_frontier_moved_during_reveal_cannot_mark_or_advance_another_line() -> void:
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.ALL_TEXT)
	var adapter: RefCounted = wired["adapter"]
	var profile: Node = wired["profile"]
	adapter.reveal_callback = func() -> void:
		adapter.cursor = 1
	var result: Dictionary = _bridge.request_skip_step()
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"skip_frontier_changed")
	assert_eq(profile.mark_calls, [], "the old line is not marked after losing its frontier")
	assert_eq(adapter.calls, ["reveal:0"], "the callback's new frontier is not advanced")
	assert_eq(adapter.cursor, 1)


func test_replaced_runtime_during_visited_publication_cannot_advance() -> void:
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.ALL_TEXT)
	var adapter: RefCounted = wired["adapter"]
	var profile: Node = wired["profile"]
	profile.visited_history_changed.connect(func(_line_id: String, _visited: bool) -> void:
		adapter.generation += 1
	)
	var result: Dictionary = _bridge.request_skip_step()
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"skip_frontier_changed")
	assert_eq(profile.mark_calls, [LINE_A], "the current line was committed before publication")
	assert_true(profile.is_line_visited(LINE_A))
	assert_eq(adapter.calls, ["reveal:0"], "the replacement runtime is not advanced, even at the same index")
	assert_eq(adapter.cursor, 0)


func test_changed_entry_token_during_reveal_cannot_mark_or_advance() -> void:
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.ALL_TEXT)
	var adapter: RefCounted = wired["adapter"]
	var profile: Node = wired["profile"]
	adapter.reveal_callback = func() -> void:
		_bridge._active_entry["token"] = "replacement-entry-token"
	var result: Dictionary = _bridge.request_skip_step()
	assert_false(result.get("ok", true))
	assert_eq(result.get("code"), &"skip_frontier_changed")
	assert_eq(profile.mark_calls, [])
	assert_eq(adapter.calls, ["reveal:0"], "an unchanged runtime index cannot authorize a different entry")
	assert_eq(adapter.cursor, 0)


func test_failed_presentation_acknowledgement_stays_pending_for_exact_retry() -> void:
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.READ_ONLY)
	if not _has_presentation_acknowledgement_surface(): return
	var adapter: RefCounted = wired["adapter"]
	var profile: Node = wired["profile"]
	var frontier: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	profile.fail_write = true
	var failed: Dictionary = _bridge.call("acknowledge_current_line_presentation", frontier)
	assert_false(failed.get("ok", true), "a failed durable mark cannot acknowledge presentation")
	assert_true(bool(_bridge.call("requires_line_presentation_acknowledgement")),
		"the exact live frontier remains pending")
	assert_eq(profile.mark_calls, [LINE_A])
	assert_false(profile.is_line_visited(LINE_A))
	assert_eq(adapter.cursor, 0)
	profile.fail_write = false
	var retried: Dictionary = _bridge.call("acknowledge_current_line_presentation", frontier)
	assert_true(retried.get("ok", false), str(retried))
	assert_true(bool(_bridge.call("requires_line_presentation_acknowledgement")),
		"the registered canonical line always requires source validation")
	assert_true(bool(_bridge.call("is_current_line_presentation_acknowledged")))
	assert_eq(profile.mark_calls, [LINE_A, LINE_A])
	assert_true(profile.is_line_visited(LINE_A))
	assert_eq(adapter.cursor, 0, "acknowledgement never performs navigation")


func test_reentrant_presentation_acknowledgement_is_refused() -> void:
	var wired := _wired([[LINE_A, "text"]], POLICY.READ_ONLY)
	if not _has_presentation_acknowledgement_surface(): return
	var adapter: RefCounted = wired["adapter"]
	var profile: Node = wired["profile"]
	var frontier: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	var nested: Array[Dictionary] = []
	profile.visited_history_changed.connect(func(_line_id: String, _visited: bool) -> void:
		nested.append(_bridge.call("acknowledge_current_line_presentation", frontier)))
	var result: Dictionary = _bridge.call("acknowledge_current_line_presentation", frontier)
	assert_true(result.get("ok", false), str(result))
	assert_eq(nested.size(), 1)
	assert_false(nested[0].get("ok", true), "publication cannot nest a second acknowledgement")
	assert_eq(profile.mark_calls, [LINE_A], "the nested request performs no second profile call")
	assert_true(profile.is_line_visited(LINE_A))
	assert_eq(adapter.cursor, 0)


func test_stale_presentation_frontier_is_refused_before_profile_publication() -> void:
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.READ_ONLY)
	if not _has_presentation_acknowledgement_surface(): return
	var adapter: RefCounted = wired["adapter"]
	var profile: Node = wired["profile"]
	var empty: Dictionary = _bridge.call("acknowledge_current_line_presentation", {})
	assert_false(empty.get("ok", true), "an empty proof never falls back to the current source")
	if empty.get("ok", false): return
	assert_eq(empty.get("code"), &"presentation_frontier_changed")
	assert_eq(profile.mark_calls, [], "empty-proof refusal happens before profile publication")
	var stale: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	adapter.cursor = 1
	var result: Dictionary = _bridge.call("acknowledge_current_line_presentation", stale)
	assert_false(result.get("ok", true))
	assert_eq(profile.mark_calls, [], "a stale line cannot publish visited history")
	assert_false(profile.is_line_visited(LINE_A))
	assert_false(profile.is_line_visited(LINE_B))
	assert_eq(adapter.cursor, 1)


func test_replaced_runtime_during_presentation_publication_cannot_acknowledge_new_frontier() -> void:
	var wired := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.READ_ONLY)
	if not _has_presentation_acknowledgement_surface(): return
	var adapter: RefCounted = wired["adapter"]
	var profile: Node = wired["profile"]
	var frontier: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	profile.visited_history_changed.connect(func(_line_id: String, _visited: bool) -> void:
		adapter.generation += 1)
	var result: Dictionary = _bridge.call("acknowledge_current_line_presentation", frontier)
	assert_false(result.get("ok", true), "replacement during publication invalidates the receipt")
	assert_eq(profile.mark_calls, [LINE_A], "the old presentation committed before replacement")
	assert_true(profile.is_line_visited(LINE_A))
	assert_false(profile.is_line_visited(LINE_B), "the replacement frontier is never inferred or marked")
	assert_eq(adapter.cursor, 0)


func test_mutation_gate_blocks_ack_but_not_opaque_capture_or_later_exact_retry() -> void:
	var wired := _wired([[LINE_A, "text"]], POLICY.READ_ONLY)
	if not _has_presentation_acknowledgement_surface(): return
	var profile: Node = wired["profile"]
	var gate := _FakeMutationGate.new()
	add_child_autofree(gate)
	assert_true(_bridge.configure_mutation_gate(gate).get("ok", false))
	var proof: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	assert_true(proof.get("ok", false), str(proof))
	assert_eq(_bridge.call("capture_current_line_presentation_frontier"), proof,
		"custody does not change or suppress the renderer's opaque source proof")
	var blocked: Dictionary = _bridge.call("acknowledge_current_line_presentation", proof)
	assert_false(blocked.get("ok", true))
	assert_eq(blocked.get("code"), &"fixture_gate_held")
	assert_eq(profile.mark_calls, [], "custody refusal happens before the Profile write")
	assert_false(bool(_bridge.call("is_current_line_presentation_acknowledged")))
	gate.held = false
	var retried: Dictionary = _bridge.call("acknowledge_current_line_presentation", proof)
	assert_true(retried.get("ok", false), str(retried))
	assert_eq(profile.mark_calls, [LINE_A])
	assert_true(bool(_bridge.call("is_current_line_presentation_acknowledged")))


func test_fatal_acknowledgement_latch_survives_frontier_replacement_until_profile_rebind() -> void:
	var wired := _wired([[LINE_A, "text"]], POLICY.READ_ONLY)
	if not _has_presentation_acknowledgement_surface(): return
	var adapter: RefCounted = wired["adapter"]
	var profile: Node = wired["profile"]
	var first_proof: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	profile.failure_result = {"ok": false, "code": &"indeterminate_commit",
		"message": "fixture fatal", "fatal": true}
	var failed: Dictionary = _bridge.call("acknowledge_current_line_presentation", first_proof)
	assert_eq(failed, profile.failure_result)
	assert_eq(profile.mark_calls, [LINE_A])
	profile.failure_result.clear()
	adapter.generation += 1
	_bridge._active_entry = _active_entry_fixture("replacement-token")
	var replacement_proof: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	assert_true(replacement_proof.get("ok", false), str(replacement_proof))
	var still_blocked: Dictionary = _bridge.call(
		"acknowledge_current_line_presentation", replacement_proof)
	assert_eq(still_blocked, failed,
		"runtime and token replacement cannot erase a fatal Profile commitment result")
	assert_eq(profile.mark_calls, [LINE_A], "the latched fatal blocks another write attempt")
	var replacement_profile := _FakeProfile.new()
	add_child_autofree(replacement_profile)
	assert_true(_bridge.configure_skip_context(
		replacement_profile, POLICY.READ_ONLY).get("ok", false))
	var rebound_proof: Dictionary = _bridge.call("capture_current_line_presentation_frontier")
	assert_true(rebound_proof.get("ok", false), str(rebound_proof))
	var rebound: Dictionary = _bridge.call("acknowledge_current_line_presentation", rebound_proof)
	assert_true(rebound.get("ok", false), str(rebound))
	assert_eq(replacement_profile.mark_calls, [LINE_A],
		"a distinct Profile owner begins with a clean acknowledgement latch")
	assert_true(replacement_profile.is_line_visited(LINE_A))


func _has_auto_surface() -> bool:
	var available := _bridge.has_method("can_auto_advance_current_line") \
		and _bridge.has_method("request_auto_step")
	assert_true(available, "the Bridge owns guarded automatic advancement")
	return available


func test_auto_step_requires_acknowledged_complete_exact_source() -> void:
	var f := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.READ_ONLY)
	if not _has_auto_surface(): return
	f.profile.auto_enabled = true
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_false(_bridge.call("can_auto_advance_current_line"))
	assert_false(_bridge.call("request_auto_step", proof).get("ok", true))
	assert_eq(f.profile.mark_calls, [], "Auto never retries presentation persistence")
	assert_true(_bridge.acknowledge_current_line_presentation(proof).ok)
	f.adapter.line_complete = false
	assert_false(_bridge.call("can_auto_advance_current_line"))
	assert_false(_bridge.call("request_auto_step", proof).get("ok", true))
	f.adapter.line_complete = true
	assert_true(_bridge.call("can_auto_advance_current_line"))
	assert_true(_bridge.call("request_auto_step", proof).get("ok", false))
	assert_eq(f.adapter.calls, ["advance:0"], "Auto advances without reveal or another receipt")
	assert_eq(f.profile.mark_calls, [LINE_A])
	assert_false(_bridge.call("request_auto_step", proof).get("ok", true), "one proof cannot advance twice")
	assert_eq(f.adapter.cursor, 1)


func test_auto_step_stops_before_every_nontext_boundary_with_preference_on() -> void:
	var f := _wired([[LINE_A, "text"]], POLICY.READ_ONLY)
	if not _has_auto_surface(): return
	f.profile.auto_enabled = true
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(_bridge.acknowledge_current_line_presentation(proof).ok)
	for boundary: String in ["choice", "effect_transaction", "variable_transaction", "safe_marker", "scene_transition", "minesweeper_entry", "validation_error", "none"]:
		f.adapter.script_events[0][1] = boundary
		assert_false(_bridge.call("can_auto_advance_current_line"), boundary)
		assert_false(_bridge.call("request_auto_step", proof).get("ok", true), boundary)
		assert_eq(f.adapter.cursor, 0, boundary)
	assert_true(f.profile.auto_enabled)
	assert_eq(f.adapter.calls, [])
	assert_eq(f.profile.mark_calls, [LINE_A])


func test_auto_step_refuses_off_stale_proof_pause_and_mutation_custody() -> void:
	var f := _wired([[LINE_A, "text"], [LINE_B, "text"]], POLICY.READ_ONLY)
	if not _has_auto_surface(): return
	var proof: Dictionary = _bridge.capture_current_line_presentation_frontier()
	assert_true(_bridge.acknowledge_current_line_presentation(proof).ok)
	assert_false(_bridge.call("request_auto_step", proof).get("ok", true), "committed Auto Off is authoritative")
	f.profile.auto_enabled = true
	var stale := proof.duplicate(true)
	stale.value.token = "another-token"
	assert_false(_bridge.call("request_auto_step", stale).get("ok", true))
	assert_false(_bridge.call("request_auto_step", {}).get("ok", true))
	_bridge._pause_changing = true
	assert_false(_bridge.call("request_auto_step", proof).get("ok", true))
	_bridge._pause_changing = false
	var gate := _FakeMutationGate.new()
	add_child_autofree(gate)
	assert_true(_bridge.configure_mutation_gate(gate).ok)
	assert_false(_bridge.call("request_auto_step", proof).get("ok", true))
	assert_eq(f.adapter.calls, [])
	gate.held = false
	assert_true(_bridge.call("request_auto_step", proof).get("ok", false))
	assert_eq(f.adapter.calls, ["advance:0"])
