extends GutTest

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")

func test_pending_scene_activation_is_not_fatal_or_new_run_recovery() -> void:
	var bootstrap := BOOTSTRAP.new()
	var pending := {"ok": false, "code": &"scene_activation_pending", "transaction_id": "scene-restore-1"}
	var result: Dictionary = bootstrap._record_startup_stage_failure(&"publish_application_ready", pending)
	assert_eq(result, pending)
	assert_false(bootstrap.get_startup_state().ready)
	assert_eq(bootstrap.get_startup_state().fatal_result, {})
	assert_false(bootstrap.get_new_run_startup_recovery().value.available)
	assert_eq(bootstrap.get_scene_startup_recovery().value.transaction_id, "scene-restore-1")
	assert_false(bootstrap.retry_scene_startup_activation("different-operation").ok)
	assert_eq(bootstrap.get_scene_startup_recovery().value.transaction_id, "scene-restore-1")
	bootstrap.free()

func test_pending_startup_cannot_replace_another_committed_operation() -> void:
	var bootstrap := BOOTSTRAP.new()
	bootstrap._record_startup_stage_failure(&"publish_application_ready", {"ok": false, "code": &"scene_activation_pending", "transaction_id": "original"})
	var result: Dictionary = bootstrap._record_startup_stage_failure(&"publish_application_ready", {"ok": false, "code": &"scene_activation_pending", "transaction_id": "replacement"})
	assert_false(result.ok)
	assert_eq(result.code, &"scene_startup_transaction_changed")
	assert_eq(bootstrap.get_scene_startup_recovery().value.transaction_id, "original")
	bootstrap.free()
