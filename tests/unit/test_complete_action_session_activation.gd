extends GutTest

const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

class Bootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}
	var queued_receipts: Array = []
	func _target(key: StringName) -> Node: return targets.get(key)
	func _queue_live_continuation() -> void:
		queued_receipts.append(_retained_checkpoint_port.records.duplicate(true))

class Checkpoints extends RefCounted:
	var records := {"old_action": "pending"}
	var clears := 0
	func clear_transient_consequence_checkpoints() -> void:
		records.clear()
		clears += 1

class Save extends Node:
	signal live_session_ready()
	func initialize(_storage: Object) -> Dictionary: return {"ok": true}
	func configure_new_run_profile_owner(_profile: Object) -> Dictionary: return {"ok": true}
	func reconcile_new_run_storage() -> Dictionary: return {"ok": true}

class Profile extends Node:
	func configure_new_run_storage(_storage: Object) -> Dictionary: return {"ok": true}

class Game extends Node:
	func capture_live_session() -> Dictionary:
		return {"ok": true, "value": {"active": true, "generation": 2, "run_id": "loaded-run"}}

func _fixture() -> Dictionary:
	var bootstrap: Node = autofree(Bootstrap.new())
	var save: Node = autofree(Save.new())
	var checkpoints := Checkpoints.new()
	bootstrap.targets = {&"SaveManager": save, &"ProfileManager": autofree(Profile.new()),
		&"GameState": autofree(Game.new())}
	bootstrap._application_gate = GATE.new()
	bootstrap._retained_checkpoint_port = checkpoints
	return {"bootstrap": bootstrap, "save": save, "checkpoints": checkpoints}

func test_successful_session_activation_clears_old_action_before_continuation_once() -> void:
	var f := _fixture()
	assert_true(f.bootstrap._run_stage(&"initialize_saves", &"final").ok)
	assert_true(f.bootstrap._run_stage(&"initialize_saves", &"final").ok)
	assert_eq(f.checkpoints.clears, 0, "initialization does not discard a live retry")
	f.save.live_session_ready.emit()
	assert_eq(f.checkpoints.clears, 1, "repeated initialization connects only once")
	assert_eq(f.bootstrap.queued_receipts, [{}], "loaded session cannot observe old action receipts")
	assert_eq(f.bootstrap._pending_live_continuation.run_id, "loaded-run")

func test_routine_continuation_keeps_same_session_retry_receipts() -> void:
	var f := _fixture()
	f.bootstrap._on_day_resolution_completed({"ok": true})
	assert_eq(f.checkpoints.clears, 0)
	assert_eq(f.bootstrap.queued_receipts, [{"old_action": "pending"}])
