extends GutTest

const RUN_LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")
const ENDING_SCENE := preload("res://scripts/ui/EndingScene.gd")


class SequencedStatePort:
	extends RefCounted
	var step_ids: Array[String] = [
		"ending.sylvia.special", "ending.sylvia.dark",
		"ending.priscilla_lavinia.sweet", "ending.priscilla_lavinia.observer",
	]
	var next_index := 0
	var background_calls: Array[String] = []

	func request_next_ending_command() -> Dictionary:
		if next_index < step_ids.size():
			var index := next_index
			return {"ok": true, "code": &"ok", "value": {
				"kind": &"play_ending", "ending_id": step_ids[index],
				"playback_context": {
					"playback_id": "ordered-run:ending:%d" % index,
					"transaction_id": "ordered-run:ending:%d:complete" % index,
					"expected_stage": &"PRIMARY_PENDING",
					"role": [&"special_prefix", &"core", &"pair_coda", &"observer_coda"][index],
				},
			}}
		if background_calls.is_empty():
			return {"ok": true, "code": &"ok", "value": {
				"kind": &"record_gallery", "expected_stage": &"EPILOGUE_PLAYED"}}
		return {"ok": true, "code": &"ok", "value": {
			"kind": &"complete_run", "expected_stage": &"GALLERY_RECORDED"}}

	func complete_ending_playback_stage(transaction_id: String,
			expected_stage: StringName, _receipt: Dictionary) -> Dictionary:
		if expected_stage == &"PRIMARY_PENDING":
			if transaction_id != "ordered-run:ending:%d:complete" % next_index:
				return {"ok": false, "code": &"transaction_mismatch"}
			next_index += 1
			return {"ok": true, "code": &"ok", "value": {}}
		background_calls.append(String(expected_stage))
		return {"ok": true, "code": &"ok", "value": {
			"route": "menu" if expected_stage == &"GALLERY_RECORDED" else ""}}


class SequencedPlaybackPort:
	extends RefCounted
	signal playback_completed(completion: Dictionary)
	signal playback_failed(failure: Dictionary)
	var starts: Array[Dictionary] = []

	func is_ready() -> bool:
		return true

	func start_ending_id(ending_id: String, context: Dictionary = {}) -> Dictionary:
		starts.append({"ending_id": ending_id, "context": context.duplicate(true)})
		return {"ok": true, "code": &"started", "value": {}, "receipt": {
			"playback_token": "token-%d" % starts.size()}}

	func finish_current() -> void:
		var started: Dictionary = starts.back()
		var context: Dictionary = started["context"]
		playback_completed.emit({
			"playback_id": context["playback_id"],
			"ending_id": started["ending_id"],
			"expected_stage": context["expected_stage"],
			"transaction_id": context["transaction_id"],
			"timeline_completion_receipt_id": "timeline:%d" % starts.size(),
			"outcome": &"completed",
		})


func _issuer_receipt() -> Dictionary:
	return {"receipt_id": "issuer_receipt.ordered-ending", "purpose": "causal_day_instance",
		"namespace": "fixture", "counter": 1, "token": "causal-ordered-ending",
		"numeric_value": null}


func _fresh_day7() -> RefCounted:
	var lifecycle: RefCounted = RUN_LIFECYCLE.new()
	lifecycle.reset("ordered-run", "ordered-branch", 0, "causal-ordered-ending",
		{"causal_day_instance_issuer_receipt": _issuer_receipt()}, false)
	var candidate: Dictionary = lifecycle.to_dict()
	candidate["day"] = 7
	var prepared: Dictionary = lifecycle.prepare_restore(candidate)
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(lifecycle.commit_restore(prepared["value"]["candidate"]).get("ok", false))
	return lifecycle


func _ordered_plan() -> Dictionary:
	return {
		"ending_id": "ending.sylvia.special",
		"epilogue_ending_id": "ending.priscilla_lavinia",
		"source_day": 7,
		"playback_stage": "PRIMARY_PENDING",
		"playback_receipts": {},
		"steps": [
			{"ending_id": "ending.sylvia.special", "role": "special_prefix"},
			{"ending_id": "ending.sylvia.dark", "role": "core"},
			{"ending_id": "ending.priscilla_lavinia.sweet", "role": "pair_coda",
				"pair_form": "love_sweet"},
			{"ending_id": "ending.priscilla_lavinia.observer", "role": "observer_coda",
				"presentation_variant": "full"},
		],
		"next_step_index": 0,
	}


func test_lifecycle_accepts_strict_ordered_plan_and_advances_each_index() -> void:
	var lifecycle := _fresh_day7()
	var entered: Dictionary = lifecycle.enter_ending(_ordered_plan())
	assert_true(entered.get("ok", false), str(entered))

	for index in range(4):
		var advanced: Dictionary = lifecycle.complete_ending_playback_stage(
			"ending:step:%d" % index, &"PRIMARY_PENDING", {"value": {"index": index}})
		assert_true(advanced.get("ok", false), "%d: %s" % [index, advanced])
		var stored: Dictionary = lifecycle.to_dict()["ending_plan"]
		assert_eq(stored["next_step_index"], index + 1)
		assert_eq(stored["playback_stage"],
			"PRIMARY_PENDING" if index < 3 else "EPILOGUE_PLAYED")
		if index == 0:
			var restored: RefCounted = RUN_LIFECYCLE.new()
			var prepared: Dictionary = restored.prepare_restore(lifecycle.to_dict())
			assert_true(prepared.get("ok", false), str(prepared))
			assert_true(restored.commit_restore(prepared["value"]["candidate"]).get("ok", false))
			lifecycle = restored
			assert_eq(lifecycle.to_dict()["ending_plan"]["next_step_index"], 1,
				"the exact next presentation survives Save/Load")

	assert_true(lifecycle.complete_ending_playback_stage(
		"ending:EPILOGUE_PLAYED", &"EPILOGUE_PLAYED", {"value": {}}).get("ok", false))
	assert_true(lifecycle.complete_ending().get("ok", false))
	assert_eq(lifecycle.get_state(), &"COMPLETED")


func test_ordered_plan_restore_refuses_tampered_cursor_and_role_order() -> void:
	var lifecycle := _fresh_day7()
	var bad_cursor := _ordered_plan()
	bad_cursor["next_step_index"] = 5
	assert_false(lifecycle.enter_ending(bad_cursor).get("ok", true))

	var bad_order := _ordered_plan()
	var steps: Array = bad_order["steps"]
	var swap: Variant = steps[0]
	steps[0] = steps[1]
	steps[1] = swap
	assert_false(lifecycle.enter_ending(bad_order).get("ok", true))

	var extra := _ordered_plan()
	(extra["steps"][0] as Dictionary)["caller_metadata"] = true
	assert_false(lifecycle.enter_ending(extra).get("ok", true))


func test_ending_scene_chains_all_steps_then_drains_gallery_and_completion() -> void:
	var scene: Node = add_child_autofree(ENDING_SCENE.new())
	var state := SequencedStatePort.new()
	var playback := SequencedPlaybackPort.new()
	assert_true(scene.configure_ending_ports(state, playback).get("ok", false))
	assert_true(scene.resume_ending().get("ok", false))
	assert_eq(playback.starts.size(), 1)

	for expected_count in range(2, 5):
		playback.finish_current()
		assert_eq(playback.starts.size(), expected_count,
			"a matching completion starts the next frozen step")
	playback.finish_current()
	assert_eq(state.next_index, 4)
	assert_eq(state.background_calls, ["EPILOGUE_PLAYED", "GALLERY_RECORDED"],
		"the final timeline drains gallery recording then completes the run")