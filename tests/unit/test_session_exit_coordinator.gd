extends GutTest
const EXIT := preload("res://scripts/application/desktop/SessionExitCoordinator.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

class RunOwner extends RefCounted:
	var gate: Object
	var handle := {"active": true, "generation": 1, "run_id": "run-exit", "owner_id": 12}
	var retire_calls := 0
	func capture_live_session() -> Dictionary: return {"ok": true, "value": handle.duplicate(true)}
	func validate_live_session(expected: Dictionary) -> Dictionary:
		return {"ok": expected == handle and handle.active and gate.guard_external(&"exit").ok}
	func retire_live_session(expected: Dictionary) -> Dictionary:
		if not gate.is_internal_owner_active(&"session_abandonment") or expected != handle: return {"ok": false}
		retire_calls += 1
		handle.active = false
		handle.generation += 1
		return {"ok": true}

class Saves extends RefCounted:
	var gate: Object
	var writes := 0
	var fail_write := false
	func save_session_exit_checkpoint(_inputs: Dictionary, _handle: Dictionary) -> Dictionary:
		if not gate.is_internal_owner_active(&"session_abandonment"): return {"ok": false}
		writes += 1
		return {"ok": not fail_write, "code": &"write_failed" if fail_write else &"ok"}

class Router extends RefCounted:
	var gate: Object
	var preparations := 0
	var publications := 0
	var fail_preparation := false
	var fail_publication_once := false
	func prepare_return_to_title() -> Dictionary:
		preparations += 1
		return {"ok": not fail_preparation, "value": {"token": "prepared-menu"}}
	func validate_prepared_return_to_title(token: String) -> Dictionary:
		return {"ok": token == "prepared-menu" and gate.is_internal_owner_active(&"session_abandonment")}
	func cancel_prepared_return_to_title(_token: String) -> Dictionary: return {"ok": true}
	func publish_prepared_return_to_title(token: String) -> Dictionary:
		publications += 1
		if fail_publication_once:
			fail_publication_once = false
			return {"ok": false, "code": &"fixture_route_failed"}
		return validate_prepared_return_to_title(token)

func _fixture() -> Dictionary:
	var gate := GATE.new()
	var run := RunOwner.new()
	run.gate = gate
	var saves := Saves.new()
	saves.gate = gate
	var router := Router.new()
	router.gate = gate
	var exit := EXIT.new()
	assert_true(exit.configure(run, saves, router, gate, func() -> Dictionary:
		return {"ok": true, "value": {"snapshot_input": {"run_id": "run-exit"}}}).ok)
	return {"run": run, "gate": gate, "saves": saves, "router": router, "exit": exit}

func test_return_retires_without_saving_and_logout_saves_before_retirement() -> void:
	for should_save: bool in [false, true]:
		var f := _fixture()
		assert_true(f.exit.return_to_title(should_save).ok)
		assert_eq(f.saves.writes, 1 if should_save else 0)
		assert_eq(f.run.retire_calls, 1)
		assert_eq(f.router.publications, 1)
		assert_false(f.gate.is_active())
		assert_false(f.run.handle.active)

func test_failed_save_keeps_the_live_run_and_route_then_retry_is_safe() -> void:
	var f := _fixture()
	f.saves.fail_write = true
	assert_false(f.exit.return_to_title(true).ok)
	assert_true(f.run.handle.active)
	assert_eq(f.run.retire_calls, 0)
	assert_eq(f.router.publications, 0)
	assert_false(f.gate.is_active())
	f.saves.fail_write = false
	assert_true(f.exit.return_to_title(true).ok)
	assert_eq(f.run.retire_calls, 1)

func test_post_retirement_route_failure_keeps_custody_and_retry_does_not_repeat_save() -> void:
	var f := _fixture()
	f.router.fail_publication_once = true
	assert_false(f.exit.return_to_title(true).ok)
	assert_true(f.gate.is_internal_owner_active(&"session_abandonment"))
	assert_false(f.run.handle.active)
	assert_false(f.exit.return_to_title(false).ok)
	assert_true(f.exit.return_to_title(true).ok)
	assert_eq(f.saves.writes, 1)
	assert_eq(f.run.retire_calls, 1)
	assert_false(f.gate.is_active())

func test_stale_exit_view_and_foreign_custody_do_not_prepare_or_save() -> void:
	var f := _fixture()
	f.run.handle.generation += 1
	assert_false(f.exit.return_to_title(true).ok)
	assert_eq(f.router.preparations, 0)
	assert_eq(f.saves.writes, 0)
	f = _fixture()
	assert_true(f.gate.acquire(&"restore").ok)
	assert_false(f.exit.return_to_title(false).ok)
	assert_eq(f.router.preparations, 0)


func test_paused_custody_cleanup_failure_stays_forward_only_before_title_publication() -> void:
	var f := _fixture()
	var calls := [0]
	assert_true(f.exit.configure_retirement(func() -> Dictionary:
		calls[0] += 1
		assert_false(f.run.handle.active)
		assert_true(f.gate.is_internal_owner_active(&"session_abandonment"))
		return {"ok": calls[0] > 1}).ok)
	assert_eq(f.exit.return_to_title(false).get("code"), &"exit_route_retry_required")
	assert_eq(f.router.publications, 0)
	assert_true(f.gate.is_active())
	assert_true(f.exit.return_to_title(false).ok)
	assert_eq(f.run.retire_calls, 1)
	assert_eq(f.router.publications, 1)
	assert_eq(f.saves.writes, 0)
	assert_eq(calls[0], 2)
