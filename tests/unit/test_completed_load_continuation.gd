extends GutTest

const GAME := preload("res://autoload/GameState.gd")
const FIXTURE := preload("res://tests/unit/test_new_run_replacement_baseline.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")

class Bootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}
	func _ready() -> void: pass
	func _target(key: StringName) -> Node: return targets.get(key)

class Router extends Node:
	var route := "main"
	var returns := 0
	var game: Node
	var gate: RefCounted
	var returned_after_retirement := false
	func get_current_route_id() -> String: return route
	func goto_menu() -> void:
		returned_after_retirement = not game.capture_live_session().value.active and not gate.is_active()
		returns += 1
		route = "menu"

class Writer extends RefCounted:
	var calls := 0
	func write() -> Dictionary:
		calls += 1
		return {"ok": true}

func test_completed_main_and_menu_load_retire_after_restore_lease_without_replaying_ending() -> void:
	var fixture: Node = add_child_autofree(FIXTURE.new())
	fixture.gut = gut
	for saved_route: String in ["main", "menu"]:
		var game: Node = autofree(GAME.new())
		game.reset_game()
		var gate := GATE.new()
		assert_true(game.configure_mutation_gate(gate).get("ok", false))
		var snapshot: Dictionary = fixture._snapshot(game, "completed-load-" + saved_route)
		snapshot["route_id"] = saved_route
		snapshot.lifecycle["day"] = 7
		snapshot.lifecycle["state"] = "COMPLETED"
		var ending: Dictionary = preload("res://tests/support/DayResolutionReceiptFixtures.gd").ending_plan()
		ending["playback_stage"] = "GALLERY_RECORDED"
		snapshot.lifecycle["ending_plan"] = ending
		snapshot.committed_schedule["day"] = 7
		snapshot["schedule_view"] = preload("res://scripts/domain/schedule/ScheduleViewState.gd").make_empty(
			7, str(snapshot.lifecycle.causal_day_instance)).value.view
		var validated: Dictionary = SCHEMA.validate(snapshot)
		assert_true(validated.get("ok", false), str(validated))
		if not validated.get("ok", false): return
		var before: Dictionary = game.capture_live_session().value
		var ticket := {"operation_id": "restore-completed-" + saved_route,
			"expected_generation": before.generation, "owner_id": before.owner_id, "run_id": snapshot.run_id}
		var lease: Dictionary = gate.acquire(&"restore")
		assert_true(lease.get("ok", false))
		assert_true(game.apply_restore_silent({"snapshot": validated.value.candidate}).get("ok", false))
		assert_true(game.activate_live_session(ticket).get("ok", false))
		var handle: Dictionary = game.capture_live_session().value
		var writer := Writer.new()
		assert_true(game.configure_ending_checkpoint_writer(writer.write).get("ok", false))
		var router: Node = autofree(Router.new())
		router.route = saved_route
		router.game = game
		router.gate = gate
		var bootstrap: Node = add_child_autofree(Bootstrap.new())
		bootstrap.targets = {&"GameState": game, &"SceneRouter": router}
		bootstrap._application_gate = gate
		bootstrap._pending_live_continuation = handle.duplicate(true)
		await bootstrap._resume_live_continuation()
		assert_eq(router.returns, 0, "the restore transaction cannot navigate or retire early")
		assert_eq(game.capture_live_session().value, handle)
		assert_true(gate.release(&"restore", lease.value.token).get("ok", false))
		await bootstrap._resume_live_continuation()
		assert_eq(router.returns, 1)
		assert_true(router.returned_after_retirement)
		assert_false(game.capture_live_session().value.active)
		assert_eq(game._run_lifecycle.get_state(), &"COMPLETED")
		assert_eq(game.day, 7)
		assert_eq(game._run_lifecycle.to_dict().ending_plan, ending)
		assert_eq(writer.calls, 0, "returning a completed save creates no new ending checkpoint")
		bootstrap._pending_live_continuation = handle.duplicate(true)
		await bootstrap._resume_live_continuation()
		assert_eq(router.returns, 1, "the stale pre-retirement handle cannot repeat navigation")
