extends "res://tests/integration/scene_partner_fork_child.gd"
class LostAcknowledgement extends RefCounted:
	var real_port: RefCounted
	func commit_scene_event(candidate: Dictionary, checkpoint: Dictionary) -> Dictionary:
		var result: Dictionary = real_port.commit_scene_event(candidate, checkpoint)
		if result.get("ok", false): return {"ok": false, "committed": true, "code": &"TEST.acknowledgement_lost"}
		return result

func test_committed_acknowledgement_loss_blocks_both_choices() -> void:
	if not _start_services(): return
	var started: Dictionary = saves.start_scene_new_run("partner.shared", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if not await _await_ready(): return
	if not await _wait_line("line.scene.test.partner.shared.before"): return
	await _accept()
	if not await _wait_line(OFFER): return
	var frontier: Dictionary = bridge.capture_current_line_presentation_frontier()
	var fault := LostAcknowledgement.new()
	fault.real_port = game._narrative_checkpoint_port
	game._narrative_checkpoint_port = fault
	var result: Dictionary = game.accept_scene_thought(frontier)
	assert_false(result.ok)
	assert_true(result.get("committed", false))
	assert_false(game._mutation_gate.guard_external(&"TEST.retry").ok)
	assert_false(game.accept_scene_thought(frontier).ok)
	assert_false(game.advance_scene_registered_marker().ok)
	assert_eq(bridge._runtime_adapter.current_line_id(), OFFER)
	var stable: Dictionary = saves.get_latest_stable_checkpoint()
	assert_true(stable.ok)
	var resolved := 0
	if stable.ok:
		for receipt: Dictionary in stable.value.bundle.snapshot.command_receipts.values():
			if receipt.get("scene_event", {}).get("result", {}).get("kind") == "thought_resolved": resolved += 1
	assert_eq(resolved, 1, "real durable commit preceded lost acknowledgement")
	game._narrative_checkpoint_port = fault.real_port
