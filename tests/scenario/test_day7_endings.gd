extends "res://addons/gut/test.gd"

# Resumable ending playback (dwm-p2r.7 Task 6, req.ending.playback). EndingScene starts the
# current command through an injected playback port and advances the stage ONLY from a matching
# playback_completed callback -- never on start. .7 proves this with recording fakes; .8 supplies
# the real Dialogic-backed port.

class FakeEndingStatePort:
	extends RefCounted
	var completion_calls: Array[Dictionary] = []
	func request_next_ending_command() -> Dictionary:
		return {"ok": true, "code": &"play_ending", "value": {
			"kind": &"play_ending", "ending_id": "ending.alone",
			"playback_context": {
				"playback_id": "run-1:primary",
				"transaction_id": "run-1:primary:complete",
				"expected_stage": &"PRIMARY_PENDING",
				"role": &"primary",
			}}, "receipt": {}}
	func complete_ending_playback_stage(transaction_id: String, expected_stage: StringName, receipt: Dictionary) -> Dictionary:
		completion_calls.append({"transaction_id": transaction_id, "expected_stage": expected_stage, "receipt": receipt.duplicate(true)})
		return {"ok": true, "code": &"ok", "value": {}, "receipt": receipt}

class FakeEndingPlaybackPort:
	extends RefCounted
	signal playback_completed(completion: Dictionary)
	signal playback_failed(failure: Dictionary)
	var starts: Array[Dictionary] = []
	func is_ready() -> bool:
		return true
	func start_ending_id(ending_id: String, context: Dictionary = {}) -> Dictionary:
		starts.append({"ending_id": ending_id, "context": context.duplicate(true)})
		return {"ok": true, "code": &"started", "value": {}, "receipt": {
			"playback_id": context["playback_id"],
			"transaction_id": context["transaction_id"],
			"expected_stage": context["expected_stage"],
			"role": context["role"],
			"ending_id": ending_id,
			"playback_token": "fake-token-1",
			"started": true,
		}}

func _completion() -> Dictionary:
	return {
		"playback_id": "run-1:primary",
		"ending_id": "ending.alone",
		"expected_stage": &"PRIMARY_PENDING",
		"transaction_id": "run-1:primary:complete",
		"timeline_completion_receipt_id": "timeline:alone:complete",
		"outcome": &"completed",
	}

func test_stage_does_not_advance_until_matching_playback_completed() -> void:
	var scene: Node = load("res://scripts/ui/EndingScene.gd").new()
	add_child_autofree(scene)
	var state := FakeEndingStatePort.new()
	var playback := FakeEndingPlaybackPort.new()
	assert_true(scene.configure_ending_ports(state, playback).get("ok", false))
	assert_true(scene.resume_ending().get("ok", false))
	assert_eq(playback.starts.size(), 1)
	assert_eq(playback.starts[0]["context"], {
		"playback_id": "run-1:primary",
		"transaction_id": "run-1:primary:complete",
		"expected_stage": &"PRIMARY_PENDING",
		"role": &"primary",
	})
	assert_eq(state.completion_calls.size(), 0, "start must not advance the stage")
	playback.playback_completed.emit(_completion())
	assert_eq(state.completion_calls.size(), 1, "a matching completion advances the stage exactly once")
	assert_eq(state.completion_calls[0]["transaction_id"], "run-1:primary:complete")
	assert_eq(state.completion_calls[0]["expected_stage"], &"PRIMARY_PENDING")

func test_mismatched_completion_does_not_advance() -> void:
	var scene: Node = load("res://scripts/ui/EndingScene.gd").new()
	add_child_autofree(scene)
	var state := FakeEndingStatePort.new()
	var playback := FakeEndingPlaybackPort.new()
	scene.configure_ending_ports(state, playback)
	scene.resume_ending()
	var wrong := _completion()
	wrong["transaction_id"] = "run-1:primary:WRONG"
	playback.playback_completed.emit(wrong)
	assert_eq(state.completion_calls.size(), 0, "a completion that does not match the pending command is ignored")

func test_duplicate_completion_advances_only_once() -> void:
	var scene: Node = load("res://scripts/ui/EndingScene.gd").new()
	add_child_autofree(scene)
	var state := FakeEndingStatePort.new()
	var playback := FakeEndingPlaybackPort.new()
	scene.configure_ending_ports(state, playback)
	scene.resume_ending()
	playback.playback_completed.emit(_completion())
	playback.playback_completed.emit(_completion())
	assert_eq(state.completion_calls.size(), 1, "a duplicate identical completion returns the stored receipt, no re-advance")

func test_configure_rejects_replacement_while_a_command_is_pending() -> void:
	var scene: Node = load("res://scripts/ui/EndingScene.gd").new()
	add_child_autofree(scene)
	var state := FakeEndingStatePort.new()
	var playback := FakeEndingPlaybackPort.new()
	scene.configure_ending_ports(state, playback)
	scene.resume_ending()
	var replaced: Dictionary = scene.configure_ending_ports(FakeEndingStatePort.new(), FakeEndingPlaybackPort.new())
	assert_false(replaced.get("ok", true), "ports cannot be swapped while a command is pending")
