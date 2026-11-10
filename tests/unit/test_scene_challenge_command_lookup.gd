extends "res://addons/gut/test.gd"

class CommandState extends "res://autoload/GameState.gd":
	var context_captures := 0
	func _ready() -> void: pass
	func _current_scene_challenge_command(_scene: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"context": {"challenge_id": "TEST.challenge"}}}
	func _scene_runtime_event_context() -> Dictionary:
		context_captures += 1
		return {"ok": false}

func test_command_lookup_and_validation_do_not_capture_checkpoint() -> void:
	var state := CommandState.new()
	autofree(state)
	var found: Dictionary = state._retained_scene_challenge_command()
	assert_true(found.ok, str(found))
	if not found.ok: return
	assert_false(found.value.has("checkpoint"))
	assert_true(state.validate_scene_challenge_command(found.value.command, found.value.bundle).ok)
	assert_eq(state.context_captures, 0)
