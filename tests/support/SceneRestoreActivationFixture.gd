extends "res://addons/gut/test.gd"

const MANAGER := preload("res://autoload/SaveManager.gd")

class Checkpoints:
	extends RefCounted
	var refuse_install := false
	func capture_state() -> Dictionary: return {"ok": true, "value": {"backup": {}}}
	func _install_prepared(_candidate: Dictionary) -> Dictionary: return {"ok": not refuse_install}
	func restore_state(_backup: Dictionary) -> Dictionary: return {"ok": true}

class Participant:
	extends RefCounted
	signal scene_activation_confirmed(operation_id: String)
	signal scene_activation_failed(operation_id: String, result: Dictionary)
	var confirmed := false
	var started := false
	var published := 0
	var rollbacks := 0
	var activated := 0
	var last_plan: Dictionary = {}
	func capture() -> Dictionary: return {"ok": true, "value": {}}
	func apply_silent(plan: Dictionary) -> Dictionary:
		last_plan = plan.duplicate(true)
		return {"ok": true, "value": {"route_ready_token": {"generation": 1}}}
	func rollback_silent(_backup: Dictionary) -> Dictionary:
		rollbacks += 1
		return {"ok": true}
	func finalize() -> Dictionary: return {"ok": true}
	func begin_scene_publication_hold(_operation: String) -> Dictionary: return {"ok": true}
	func cancel_scene_publication_hold(_operation: String) -> Dictionary: return {"ok": true}
	func begin_scene_activation(_operation: String) -> Dictionary:
		started = true
		return {"ok": true}
	func validate_scene_activation(_operation: String) -> Dictionary: return {"ok": confirmed}
	func publish_scene_activation(_operation: String) -> Dictionary:
		published += 1
		return {"ok": true}
	func activate_loaded_session(_ticket: Dictionary) -> Dictionary:
		activated += 1
		return {"ok": true}
	func confirm(operation: String) -> void:
		confirmed = true
		scene_activation_confirmed.emit(operation)

var manager: Node
var participants: Dictionary
var plans: Dictionary

func before_each() -> void:
	manager = autofree(MANAGER.new())
	manager._journal = Checkpoints.new()
	participants = {}
	plans = {}
	for key: String in MANAGER._SCENE_PARTICIPANT_ORDER:
		participants[key] = Participant.new()
		plans[key] = {}
	manager._restore_participants = participants

func _start() -> Dictionary:
	return manager._run_scene_restore_transaction(plans, {}, "scene", "saved-caption", "scene_load:1", false)
