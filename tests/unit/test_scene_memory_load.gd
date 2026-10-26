extends "res://tests/unit/test_scene_restore_activation_protocol.gd"

class UnusedJournal extends RefCounted:
	var calls: Array[String] = []
	var incomplete: Array = []
	func list_incomplete() -> Dictionary:
		calls.append("list_incomplete")
		return {"ok": true, "value": incomplete.duplicate(true)}
	func get_operation(_id: String) -> Dictionary:
		calls.append("get_operation")
		return {"ok": false, "code": &"unexpected_durable_load"}
	func acknowledge_scene_activation(_id: String, _fingerprint: String) -> Dictionary:
		calls.append("acknowledge")
		return {"ok": false}
	func advance(_input: Dictionary) -> Dictionary:
		calls.append("advance")
		return {"ok": false}

func test_memory_load_waits_for_ui_and_native_then_retains_only_process_local_readiness() -> void:
	var unused := UnusedJournal.new()
	manager._continuation_journal = unused
	manager._identity_issuer = null
	var before: String = storage.text
	var id := "scene_load:1"
	var result: Dictionary = manager._run_scene_restore_transaction(plans, {}, "scene", "saved-caption", true,
		{"kind": "memory_restore", "transaction_id": id}, "lease", false)
	assert_eq(result.get("code"), &"scene_activation_pending", str(result))
	assert_false(manager.capture_scene_restore_activation(id).ok)
	assert_eq(participants.run.activated, 0)
	participants.route.confirm(id)
	assert_eq(participants.run.activated, 0, "mounted UI alone does not enable input")
	assert_true(participants.narrative.last_plan.read_only_restore)
	participants.narrative.confirm(id)
	assert_eq(participants.run.activated, 1)
	assert_true(manager.capture_scene_restore_activation(id).ok)
	assert_true(manager.retry_scene_activation(id).ok)
	assert_true(gate.released)
	assert_eq(unused.calls, [], "Load never reads or writes durable operation bookkeeping")
	assert_eq(storage.text, before)

func test_startup_leaves_obsolete_load_record_untouched_without_resuming_it() -> void:
	var unused := UnusedJournal.new()
	unused.incomplete = [{"kind": "scene_restore", "transaction_id": "old-load"}]
	manager._continuation_journal = unused
	manager._mutation_gate = null
	manager._identity_issuer = RefCounted.new()
	var before: String = storage.text
	var result: Dictionary = manager.reconcile_incomplete_continuations()
	assert_true(result.ok, str(result))
	assert_eq(result.value.reconciled, [])
	assert_eq(unused.calls, ["list_incomplete"])
	assert_eq(storage.text, before, "shared file is not deleted or rewritten")
	assert_eq(participants.run.silent_applies, 0)
