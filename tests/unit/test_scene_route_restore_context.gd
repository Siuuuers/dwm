extends "res://addons/gut/test.gd"
## Real SceneRouter prepare/apply, with a detached state node. No publication,
## native activation, save validation or physical storage is claimed by this unit.
class ContextState extends Node:
	var route_context := {}

class Router extends "res://autoload/SceneRouter.gd":
	var state: Node
	func _gs() -> Node:
		return state

var state: ContextState
var router: Router

func before_each() -> void:
	state = ContextState.new()
	router = Router.new()
	router.state = state

func after_each() -> void:
	router.free()
	state.free()

func test_scene_restore_keeps_gameplay_context_owned_by_run() -> void:
	var gameplay := {"active_dating_challenge": {"TEST": ["retained"]}}
	state.route_context = gameplay.duplicate(true)
	var configured: Dictionary = router.configure_scene_host("res://tests/fixtures/scene_activation_host.tscn")
	assert_true(configured.ok, str(configured))
	if not configured.ok: return
	var host := {"active_app_id": null, "lifecycle_state": "PLAYING", "run_id": "TEST.run",
		"contacts": {"TEST": []}, "scene": {"active_occurrence_id": "TEST.occurrence"}}
	var prepared: Dictionary = router.prepare_route_restore("scene", host)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var applied: Dictionary = router.apply_route_restore_silent(prepared.value)
	assert_true(applied.ok, str(applied))
	assert_eq(state.route_context, gameplay, "host metadata is not persisted gameplay")
	assert_eq(prepared.value.route_context, host, "the host plan remains complete and detached")
	if applied.ok: assert_eq(applied.value.route_ready_token, prepared.value.route_ready_token)

func test_legacy_restore_still_merges_safe_context_without_losing_gameplay() -> void:
	state.route_context = {"active_dating_challenge": {"TEST": ["retained"]}, "ending_id": "old"}
	var host := {"ending_id": "new", "day": 3}
	var prepared: Dictionary = router.prepare_route_restore("main", host)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var applied: Dictionary = router.apply_route_restore_silent(prepared.value)
	assert_true(applied.ok, str(applied))
	assert_eq(state.route_context, {"active_dating_challenge": {"TEST": ["retained"]}, "ending_id": "new", "day": 3})
	assert_eq(host, {"ending_id": "new", "day": 3})
