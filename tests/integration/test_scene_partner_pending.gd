extends "res://tests/integration/scene_partner_fork_child.gd"
func test_target_write_refusal_retains_choice_for_fresh_recovery() -> void:
	if not _start_services(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci"))
	var started: Dictionary = saves.start_scene_new_run("partner.shared", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if not await _await_ready(): return
	if not await _wait_line("line.scene.test.partner.shared.before"): return
	await _accept()
	if not await _wait_line(OFFER): return
	var original: RefCounted = saves._storage._file_ops
	var fault = WRITE_REFUSAL.WriteRefusal.new()
	fault.refuse_on = 2
	saves._storage._file_ops = fault
	var result: Dictionary = game.accept_scene_thought(bridge.capture_current_line_presentation_frontier())
	assert_false(result.ok, str(result))
	assert_eq(fault.refused, 1)
	saves._storage._file_ops = original
	assert_eq(_thoughts().size(), 1, "choice committed before failed target write")
	assert_eq(_thoughts()[0].scene_event.result.choice, "yes")
	assert_eq(bridge._runtime_adapter.current_line_id(), OFFER)
	if not _ok(saves.save_latest_to_slot(1)): return
	_write_json("user://partner-pending.json", {"pid": OS.get_process_id(), "receipt": _thoughts()[0]})
