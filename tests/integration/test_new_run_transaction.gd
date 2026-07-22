extends "res://addons/gut/test.gd"
# start_new_run transaction over the real run participant + fake owners
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const GS_PATH := "res://autoload/GameState.gd"
const RUN_PARTICIPANT := "res://scripts/application/restore/RunRestoreParticipant.gd"
const FAKE_PARTICIPANT := "res://tests/support/FakeRestoreParticipant.gd"
const CALL_LOG := "res://tests/support/RestoreCallLog.gd"

func _initial_context() -> Dictionary:
	return {"route_id": "opening", "dialogic_checkpoint": {}, "active_app_id": null,
		"audio_context": {}, "content_version": 1}

func _wired() -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("new_run").path_join(str(randi())).path_join("saves")
	DirAccess.make_dir_recursive_absolute(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root))
	var gate: RefCounted = load(GATE_PATH).new()
	manager.configure_mutation_gate(gate)
	assert_true(manager._journal.reset("run-a")["ok"])
	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()
	var log: RefCounted = load(CALL_LOG).new()
	assert_true(manager.configure_restore_participants({
		"run": load(RUN_PARTICIPANT).new(gs),
		"profile": load(FAKE_PARTICIPANT).new("profile", log),
		"localization": load(FAKE_PARTICIPANT).new("localization", log),
		"audio": load(FAKE_PARTICIPANT).new("audio", log),
		"route": load(FAKE_PARTICIPANT).new("route", log),
		"narrative": load(FAKE_PARTICIPANT).new("narrative", log),
	})["ok"])
	return {"manager": manager, "gate": gate, "gs": gs, "log": log}

func test_start_new_run_rejects_bad_context_and_run_id() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	assert_eq(manager.start_new_run("run-b", {"route_id": "main"}).get("code"), &"invalid_initial_context")
	assert_eq(manager.start_new_run("", _initial_context()).get("code"), &"invalid_run_id")
	var extra := _initial_context()
	extra["surprise"] = 1
	assert_eq(manager.start_new_run("run-b", extra).get("code"), &"invalid_initial_context")

func test_start_new_run_builds_day1_run_b() -> void:
	var wired := _wired()
	var manager: Node = wired["manager"]
	var result: Dictionary = manager.start_new_run("run-b", _initial_context())
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["run_id"], "run-b")
	assert_eq(result["value"]["checkpoint_id"], "run-b:1", "Run-B starts at sequence 1")
	assert_eq(result["value"]["route_id"], "opening")
	assert_eq(int(manager._journal.peek_next_sequence("run-b")["value"]["checkpoint_sequence"]), 2)
	assert_eq(manager._journal.get_bundles_for_disk(), [], "a fresh run has no earlier bundles")
	assert_eq(wired["gs"].day, 1, "live GameState is now Day 1 of the new run")
	assert_false(wired["gate"].is_active(), "gate released after the new-run transaction")
	assert_false(manager.is_save_locked(), "no lingering save lock")

func test_start_new_run_requires_participants() -> void:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("new_run_np").path_join(str(randi())).path_join("saves")
	DirAccess.make_dir_recursive_absolute(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root))
	assert_eq(manager.start_new_run("run-b", _initial_context()).get("code"),
		&"TRANSACTION_PARTICIPANTS_NOT_CONFIGURED")
