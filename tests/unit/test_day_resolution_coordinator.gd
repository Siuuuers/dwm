extends "res://addons/gut/test.gd"

const COORDINATOR_PATH := "res://scripts/application/run/DayResolutionCoordinator.gd"
const STATE_PATH := "res://tests/support/FakeDayResolutionStatePort.gd"
const CHECKPOINT_PATH := "res://tests/support/FakeCheckpointPort.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"

func _all_exist() -> bool:
	for path: String in [COORDINATOR_PATH, STATE_PATH, CHECKPOINT_PATH, GATE_PATH]:
		if not ResourceLoader.exists(path, "Script"):
			return false
	return true

func _wired(day: int) -> Dictionary:
	var calls: Array[String] = []
	var state: RefCounted = load(STATE_PATH).new(calls)
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	state.seed_playing_day("run-1", day, [])
	checkpoint.seed_empty("run-1")
	var gate: RefCounted = load(GATE_PATH).new()
	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	assert_true(coordinator.configure_fatal_latch(gate)["ok"])
	assert_true(coordinator.configure(state, checkpoint)["ok"])
	return {"coordinator": coordinator, "state": state, "checkpoint": checkpoint, "gate": gate, "calls": calls}

func test_checkpoint_commit_failure_rolls_back_without_publication() -> void:
	for path in [COORDINATOR_PATH, STATE_PATH, CHECKPOINT_PATH]:
		assert_true(ResourceLoader.exists(path, "Script"), path + " must exist")
		if not ResourceLoader.exists(path, "Script"):
			return
	var calls: Array[String] = []
	var state: RefCounted = load(STATE_PATH).new(calls)
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	state.seed_playing_day("run-1", 3, [])
	checkpoint.seed_empty("run-1")
	checkpoint.set_failure(&"commit_after_mutation")
	var state_before: Dictionary = state.peek_state()
	var checkpoint_before: Dictionary = checkpoint.peek_state()
	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	assert_true(coordinator.configure_fatal_latch(load(GATE_PATH).new())["ok"])
	assert_true(coordinator.configure(state, checkpoint)["ok"])
	var result: Dictionary = coordinator.request_schedule_done("done:run-1:day-3")
	assert_false(result["ok"])
	assert_eq(result["code"], &"checkpoint_commit_failed")
	assert_eq(state.peek_state(), state_before)
	assert_eq(checkpoint.peek_state(), checkpoint_before)
	assert_eq(state.get_publication_count(), 0)
	assert_eq(calls, [
		"state.begin_or_resume", "state.begin_next_stage",
		"state.capture", "checkpoint.capture",
		"state.prepare_completion", "checkpoint.prepare",
		"checkpoint.commit", "checkpoint.rollback",
	])

func test_configuration_matrix_and_gate_identity() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	var calls: Array[String] = []
	var state: RefCounted = load(STATE_PATH).new(calls)
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	assert_eq(coordinator.configure(state, checkpoint)["code"], &"fatal_latch_not_configured",
		"configure requires the fatal latch first")
	assert_eq(coordinator.configure_fatal_latch(null).get("code"), &"invalid_mutation_gate")
	assert_eq(coordinator.configure_fatal_latch(RefCounted.new()).get("code"), &"invalid_mutation_gate")
	var gate: RefCounted = load(GATE_PATH).new()
	var configured: Dictionary = coordinator.configure_fatal_latch(gate)
	assert_true(configured["ok"])
	assert_eq(configured["value"]["gate_instance_id"], gate.get_instance_id())
	assert_eq(configured["value"]["already_configured"], false)
	var repeat: Dictionary = coordinator.configure_fatal_latch(gate)
	assert_true(repeat["ok"], "identical instance is idempotent")
	assert_eq(repeat["value"]["already_configured"], true)
	assert_eq(coordinator.configure_fatal_latch(load(GATE_PATH).new()).get("code"),
		&"mutation_gate_already_configured", "replacement rejects")
	assert_true(coordinator.configure(state, checkpoint)["ok"])
	assert_eq(coordinator.request_schedule_done("").get("code"), &"invalid_command_id")

func test_day3_full_resolution_reaches_plan_complete() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(3)
	var result: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["code"], &"plan_complete")
	assert_true(str(result["value"]["checkpoint_id"]).begins_with("run-1:"))
	assert_eq(wired["state"].peek_state()["lifecycle"]["day"], 4, "day advanced once")
	assert_true(wired["state"].get_publication_count() > 0, "successful stages publish")
	var replay: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	assert_true(replay.get("ok", false), "repeated Done with the same command is idempotent")
	assert_eq(replay["code"], &"plan_complete")
	assert_eq(wired["state"].peek_state()["lifecycle"]["day"], 4, "replay never advances the day again")

func test_registered_command_pause_and_completion() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(3)
	wired["state"].set_registered_stage("hospital_if_triggered")
	var paused: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	assert_true(paused.get("ok", false), JSON.stringify(paused))
	assert_eq(paused["code"], &"await_registered_command")
	var command: Dictionary = paused["value"]["command"]
	assert_eq(command["stage_id"], "hospital_if_triggered")
	var wrong_owner := {"owner_id": "impostor", "kind": "hospital_resolution",
		"value": {"required": false, "route_receipt_id": null, "prevented_entry_id": null}}
	assert_false(wired["coordinator"].complete_route_stage(
		str(command["transaction_id"]), wrong_owner).get("ok", true), "owner mismatch rejects")
	wired["state"].set_registered_stage("")
	var receipt := {"owner_id": "dating_ending_rules", "kind": "hospital_resolution",
		"value": {"required": false, "route_receipt_id": null, "prevented_entry_id": null}}
	var finished: Dictionary = wired["coordinator"].complete_route_stage(
		str(command["transaction_id"]), receipt)
	assert_true(finished.get("ok", false), JSON.stringify(finished))
	assert_eq(finished["code"], &"plan_complete")
	assert_eq(wired["state"].peek_state()["lifecycle"]["day"], 4)

func test_recoverable_failures_restore_pre_command_state() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	for phase: StringName in [&"prepare_completion", &"commit", &"publish"]:
		var wired := _wired(2)
		wired["state"].set_failure(phase)
		var state_before: Dictionary = wired["state"].peek_state()
		var checkpoint_before: Dictionary = wired["checkpoint"].peek_state()
		var result: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-2")
		assert_false(result.get("ok", true), String(phase))
		assert_eq(wired["state"].peek_state(), state_before, String(phase) + " restores state")
		assert_eq(wired["checkpoint"].peek_state(), checkpoint_before, String(phase) + " restores checkpoint")
		assert_eq(wired["state"].get_publication_count(), 0, String(phase) + " publishes nothing")
		if phase == &"prepare_completion":
			assert_false("state.rollback" in (wired["calls"] as Array[String]),
				"prepare failure performs no rollback")
		else:
			assert_true("state.rollback" in (wired["calls"] as Array[String]),
				String(phase) + " failure rolls state back")

func test_rollback_failure_latches_shared_gate_and_returns_fatal() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(2)
	var gate: RefCounted = wired["gate"]
	var coordinator: RefCounted = wired["coordinator"]
	wired["state"].set_failure(&"commit")
	wired["checkpoint"].set_failure(&"rollback")
	var result: Dictionary = coordinator.request_schedule_done("done:run-1:day-2")
	assert_false(result.get("ok", true))
	assert_eq(result["code"], &"APPLICATION_FATAL", JSON.stringify(result))
	assert_true(gate.is_fatal_latched(), "shared gate latched exactly once")
	var failure: Dictionary = result["details"]["failure"]
	assert_eq(failure["source"], "day_resolution")
	assert_eq(failure["code"], "fatal_rollback_failed")
	assert_true(failure["details"]["context"].has("transaction_id"))
	assert_true(failure["details"]["context"].has("stage_id"))
	assert_true(failure["details"]["diagnostics"].size() > 0, "raw recovery results are projected")
	var after: Dictionary = coordinator.request_schedule_done("done:run-1:day-2-again")
	assert_eq(after["code"], &"APPLICATION_FATAL", "post-fatal commands return the retained failure")

func test_duplicate_transaction_returns_stored_receipt_without_new_checkpoint() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var wired := _wired(3)
	wired["state"].set_registered_stage("hospital_if_triggered")
	var paused: Dictionary = wired["coordinator"].request_schedule_done("done:run-1:day-3")
	var command: Dictionary = paused["value"]["command"]
	wired["state"].set_registered_stage("")
	var receipt := {"owner_id": "dating_ending_rules", "kind": "hospital_resolution",
		"value": {"required": false, "route_receipt_id": null, "prevented_entry_id": null}}
	assert_true(wired["coordinator"].complete_route_stage(str(command["transaction_id"]), receipt)["ok"])
	var checkpoints_after: Dictionary = wired["checkpoint"].peek_state()
	var publications_after: int = wired["state"].get_publication_count()
	var replay: Dictionary = wired["coordinator"].complete_route_stage(str(command["transaction_id"]), receipt)
	assert_true(replay.get("ok", false), "duplicate completion succeeds: " + JSON.stringify(replay))
	assert_eq(wired["checkpoint"].peek_state(), checkpoints_after, "no second checkpoint")
	assert_eq(wired["state"].get_publication_count(), publications_after, "no second publication")

func test_checkpoint_preview_matches_prepare_without_mutation() -> void:
	assert_true(_all_exist(), "coordinator artifacts must exist")
	if not _all_exist():
		return
	var calls: Array[String] = []
	var checkpoint: RefCounted = load(CHECKPOINT_PATH).new(calls)
	checkpoint.seed_empty("run-1")
	var before: Dictionary = checkpoint.peek_state()
	var preview: Dictionary = checkpoint.preview_checkpoint_id("run-1")
	assert_true(preview["ok"])
	assert_eq(checkpoint.peek_state(), before, "preview never mutates")
	var prepared: Dictionary = checkpoint.prepare({"run_id": "run-1"}, &"day_resolution_stage",
		{"kind": &"none", "reason": &"stage"})
	assert_true(prepared["ok"])
	assert_eq(str(preview["value"]["checkpoint_id"]), str(prepared["value"]["checkpoint_id"]),
		"preview and immediate prepare agree")
