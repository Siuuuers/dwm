extends "res://addons/gut/test.gd"
# Held fast-forward through DialogicBridge (dwm-p2r.8, Plan-05 Task 4 Steps 4.2/4.3).
# Repeated request_skip_step() must reveal each line, mark it globally visited BEFORE deciding,
# and stop before every boundary WITHOUT consuming it.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const POLICY := preload("res://scripts/narrative/SkipPolicy.gd")

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
	var calls: Array[String] = []
	func start_timeline(path: String, event_index: Variant = 0) -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"path": path, "event_index": event_index}}
	func reveal_current_line() -> Dictionary:
		calls.append("reveal:%d" % cursor)
		return {"ok": true, "code": &"ok", "value": {}}
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
	_bridge.initialize(null, adapter)
	assert_true(_bridge.configure_skip_context(profile, mode).get("ok", false), "skip context configured")
	return {"adapter": adapter, "profile": profile}


func test_bridge_exposes_the_skip_command() -> void:
	assert_true(_bridge.has_method("request_skip_step"), "DialogicBridge.request_skip_step is required")
	assert_true(_bridge.has_method("configure_skip_context"), "DialogicBridge.configure_skip_context is required")


func test_all_text_fast_forwards_through_unread_text() -> void:
	var wired := _wired([["l.1", "text"], ["l.2", "text"], ["l.3", "choice"]], POLICY.ALL_TEXT)
	var adapter: RefCounted = wired["adapter"]
	assert_true(_bridge.request_skip_step().get("ok", false), "first skip step")
	assert_true(_bridge.request_skip_step().get("ok", false), "second skip step")
	assert_eq(adapter.cursor, 2, "all_text advanced through both unread lines")


func test_read_only_stops_at_the_first_unread_line() -> void:
	var wired := _wired([["l.1", "text"], ["l.2", "text"]], POLICY.READ_ONLY)
	var adapter: RefCounted = wired["adapter"]
	var decision: Dictionary = _bridge.request_skip_step()
	assert_true(decision.get("ok", false), str(decision))
	assert_false(decision["value"]["advance"], "read_only does not advance past an unread line")
	assert_eq(adapter.cursor, 0, "the playhead did not move")
	assert_true(("reveal:0" in adapter.calls), "but the line was still revealed")


func test_read_only_advances_through_previously_visited_text() -> void:
	var seed: Array[String] = ["l.1"]
	var wired := _wired([["l.1", "text"], ["l.2", "text"]], POLICY.READ_ONLY, seed)
	var adapter: RefCounted = wired["adapter"]
	assert_true(_bridge.request_skip_step()["value"]["advance"], "a globally visited line may be skipped")
	assert_eq(adapter.cursor, 1, "the playhead advanced")


func test_visited_is_read_before_it_is_marked() -> void:
	# read_only must decide from the PRE-reveal visited state, else every line would look visited.
	var wired := _wired([["l.1", "text"], ["l.2", "text"]], POLICY.READ_ONLY)
	var profile: Node = wired["profile"]
	var decision: Dictionary = _bridge.request_skip_step()
	assert_false(decision["value"]["advance"], "the pre-reveal state decided, not the post-mark state")
	assert_eq(profile.mark_calls, ["l.1"], "the current line was still marked visited")
	assert_true(profile.is_line_visited("l.1"), "and persisted globally")


func test_every_boundary_stops_the_skip_without_being_consumed() -> void:
	for boundary in ["choice", "effect_transaction", "variable_transaction", "safe_marker", "scene_transition", "minesweeper_entry", "validation_error"]:
		var fresh: Node = BRIDGE.new()
		add_child_autofree(fresh)
		var adapter := _FakeAdapter.new()
		adapter.script_events = [["l.1", boundary]]
		var profile := _FakeProfile.new()
		profile.visited.assign(["l.1"] as Array[String])
		add_child_autofree(profile)
		fresh.initialize(null, adapter)
		fresh.configure_skip_context(profile, POLICY.ALL_TEXT)
		var decision: Dictionary = fresh.request_skip_step()
		assert_true(decision["value"]["stop_before_boundary"], "must stop before " + boundary)
		assert_false(decision["value"]["advance"], "must not advance into " + boundary)
		assert_eq(adapter.cursor, 0, boundary + " was not consumed")
		assert_true(("reveal:0" in adapter.calls), "current text is fully revealed at " + boundary)


func test_profile_write_failure_halts_advancement() -> void:
	var wired := _wired([["l.1", "text"], ["l.2", "text"]], POLICY.ALL_TEXT)
	var adapter: RefCounted = wired["adapter"]
	(wired["profile"] as Node).fail_write = true
	var decision: Dictionary = _bridge.request_skip_step()
	assert_false(decision.get("ok", false), "a profile write failure fails the step")
	assert_eq(adapter.cursor, 0, "advancement halted")


func test_skip_requires_a_configured_context() -> void:
	var bare: Node = BRIDGE.new()
	add_child_autofree(bare)
	assert_false(bare.request_skip_step().get("ok", false), "skip without a profile/context rejects")
