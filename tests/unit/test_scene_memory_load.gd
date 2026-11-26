extends "res://tests/support/SceneRestoreActivationFixture.gd"

func test_memory_load_waits_for_route_and_native_readiness() -> void:
	var id := "scene_load:1"
	var result := _start()
	assert_eq(result.get("code"), &"scene_activation_pending", str(result))
	assert_false(manager.capture_scene_restore_activation(id).ok)
	assert_eq(participants.run.activated, 1, "saved Run is active before route mounting")
	assert_true(participants.route.started)
	assert_false(participants.narrative.started)
	participants.route.confirm(id)
	assert_true(participants.narrative.started)
	assert_true(participants.narrative.last_plan.read_only_restore)
	assert_false(manager.capture_scene_restore_activation(id).ok)
	participants.narrative.confirm(id)
	var captured: Dictionary = manager.capture_scene_restore_activation(id)
	var retried: Dictionary = manager.retry_scene_activation(id)
	assert_eq(captured, {"ok": true, "transaction_id": id,
		"value": {"transaction_id": id, "checkpoint_id": "saved-caption", "route_id": "scene"}})
	assert_eq(retried, captured)
	assert_false(is_same(retried.value, captured.value))
	participants.narrative.confirm(id)
	assert_eq(participants.run.activated, 1)
	assert_eq(participants.route.published, 1)
