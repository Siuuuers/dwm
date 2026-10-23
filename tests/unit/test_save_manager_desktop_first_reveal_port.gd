extends GutTest
## Adapter boundary only: authentic scene/schema validation remains with production owners.
const PORT := preload("res://scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd")

class RecordingCheckpoint extends RefCounted:
	var calls: Array = []
	func prepare(inputs: Dictionary, kind: StringName, disk_write: Dictionary) -> Dictionary:
		calls.append({"inputs": inputs.duplicate(true), "kind": kind, "disk_write": disk_write.duplicate(true)})
		return {"ok": true, "value": {"checkpoint_id": "recorded:1"}}

var lower: RecordingCheckpoint
var port: RefCounted
var response: Variant
var callback_calls := 0
var mutate_argument := false

func before_each() -> void:
	lower = RecordingCheckpoint.new()
	port = PORT.new(lower)
	response = {"ok": true, "value": _context()}
	callback_calls = 0
	mutate_argument = false
	assert_true(port.configure_audio_context_capture(_audio).ok)

func _audio() -> Dictionary:
	return {"music_context_id": "", "music_context": {}, "ambience_context_id": "", "ambience_context": {}}

func _context() -> Dictionary:
	return {"active_app_id": "minesweeper", "route_id": "scene", "content_version": 7,
		"dialogic_checkpoint": {"entry_id": "TEST.current", "reading_session": {"boundary": "line"}}}

func _snapshot() -> Dictionary:
	return {"scene": {"active_occurrence_id": "TEST.occurrence"},
		"desktop": {"board": {"phase": "ACTIVE_VISIBLE", "board": {"revealed_indices": [4]}},
			"consequence": {"run_revision": 2}}, "gameplay": {"minesweeper_rounds_left": 1}}

func _capture(candidate: Dictionary) -> Variant:
	callback_calls += 1
	if mutate_argument:
		candidate.desktop.board.board.revealed_indices.append(99)
		candidate.gameplay.minesweeper_rounds_left = 99
	return response

func _other_capture(_candidate: Dictionary) -> Variant:
	return response

func _prepare(snapshot: Dictionary) -> Dictionary:
	return port.prepare_checkpoint(snapshot, &"pre_board", {"kind": &"autosave", "reason": &"pre_board"})

func test_missing_context_refuses_before_lower_prepare() -> void:
	var result := _prepare(_snapshot())
	assert_false(result.ok)
	assert_eq(result.code, &"scene_context_capture_unavailable")
	assert_eq(lower.calls.size(), 0)

func test_refused_context_preserves_reason_and_never_prepares() -> void:
	assert_true(port.configure_scene_context_capture(_capture).ok)
	response = {"ok": false, "code": &"scene_frontier_stale", "details": {"source": "TEST"}}
	assert_eq(_prepare(_snapshot()), response)
	assert_eq(callback_calls, 1)
	assert_eq(lower.calls.size(), 0)

func test_malformed_contexts_never_reach_lower_prepare() -> void:
	assert_true(port.configure_scene_context_capture(_capture).ok)
	var cases: Array = [null, [], {"ok": true}, {"ok": true, "value": []}]
	for changed: Dictionary in [
			{"route_id": "main"}, {"active_app_id": 12}, {"content_version": 0},
			{"content_version": "7"}, {"dialogic_checkpoint": {}},
			{"dialogic_checkpoint": []}, {"snapshot_input": _snapshot()}]:
		var context := _context()
		context.merge(changed, true)
		cases.append({"ok": true, "value": context})
	var missing := _context()
	missing.erase("active_app_id")
	cases.append({"ok": true, "value": missing})
	for malformed: Variant in cases:
		response = malformed
		var result := _prepare(_snapshot())
		assert_false(result.ok, str(malformed))
		assert_eq(result.code, &"invalid_scene_checkpoint_context", str(malformed))
		assert_eq(lower.calls.size(), 0)
	assert_eq(callback_calls, cases.size())

func test_callback_cannot_mutate_chosen_detached_board_or_accounting() -> void:
	assert_true(port.configure_scene_context_capture(_capture).ok)
	mutate_argument = true
	var chosen := _snapshot()
	var before := chosen.duplicate(true)
	assert_true(_prepare(chosen).ok)
	assert_eq(chosen, before)
	assert_eq(lower.calls.size(), 1)
	assert_eq(lower.calls[0].inputs.snapshot_input, before)
	assert_eq(callback_calls, 1)

func test_live_semantic_context_and_safe_marker_are_forwarded() -> void:
	assert_true(port.configure_scene_context_capture(_capture).ok)
	var chosen := _snapshot()
	var disk := {"kind": &"autosave", "reason": &"automatic"}
	assert_true(port.prepare_checkpoint(chosen, &"safe_marker", disk).ok)
	assert_eq(lower.calls.size(), 1)
	var recorded: Dictionary = lower.calls[0]
	assert_eq(recorded.kind, &"safe_marker")
	assert_eq(recorded.disk_write, disk)
	assert_eq(recorded.inputs.snapshot_input, chosen)
	assert_eq(recorded.inputs.audio_context, _audio())
	for key: String in _context():
		assert_eq(recorded.inputs[key], _context()[key])
	response.value.active_app_id = null
	assert_true(_prepare(chosen).ok)
	assert_null(lower.calls[1].inputs.active_app_id)

func test_binding_is_idempotent_and_refuses_replacement() -> void:
	assert_false(port.configure_scene_context_capture(Callable()).ok)
	var first: Dictionary = port.configure_scene_context_capture(_capture)
	assert_true(first.ok)
	assert_false(first.value.already_configured)
	var again: Dictionary = port.configure_scene_context_capture(_capture)
	assert_true(again.ok)
	assert_true(again.value.already_configured)
	var replacement: Dictionary = port.configure_scene_context_capture(_other_capture)
	assert_false(replacement.ok)
	assert_eq(replacement.code, &"scene_context_capture_already_configured")
	assert_true(_prepare(_snapshot()).ok)
	assert_eq(callback_calls, 1, "the original provider remains bound")
