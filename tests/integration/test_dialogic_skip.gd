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
	var visited: Array[String] = []
	var fail_write := false
	var mark_calls: Array[String] = []
	func is_line_visited(line_id: String) -> bool:
		return line_id in visited
	func mark_line_visited(line_id: String) -> Dictionary:
		mark_calls.append(line_id)
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


func before_each() -> void:
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)


func _wired(events: Array, mode: StringName, visited_seed: Array[String] = []) -> Dictionary:
	var adapter := _FakeAdapter.new()
	adapter.script_events = events
	var profile := _FakeProfile.new()
	profile.visited.assign(visited_seed)
	add_child_autofree(profile)
	assert_true(_bridge.initialize(null, adapter).get("ok", false))
	_bridge._active_entry = {"entry_id": ENTRY_ID, "token": "skip-fixture-token"}
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
		fresh._active_entry = {"entry_id": ENTRY_ID}
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
