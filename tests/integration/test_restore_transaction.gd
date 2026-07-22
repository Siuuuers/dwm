extends "res://addons/gut/test.gd"
# Restore transaction orchestration over fake participants
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const FAKE_PARTICIPANT := "res://tests/support/FakeRestoreParticipant.gd"
const CALL_LOG := "res://tests/support/RestoreCallLog.gd"

const KEYS := ["run", "profile", "localization", "audio", "route", "narrative"]

func _manager(log: RefCounted) -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("restore_txn").path_join(str(randi())).path_join("saves")
	DirAccess.make_dir_recursive_absolute(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	manager.initialize(load(STORAGE_PATH).new(root))
	var gate: RefCounted = load(GATE_PATH).new()
	manager.configure_mutation_gate(gate)
	var participants := {}
	for key: String in KEYS:
		participants[key] = load(FAKE_PARTICIPANT).new(key, log)
	assert_true(manager.configure_restore_participants(participants)["ok"])
	return {"manager": manager, "gate": gate, "participants": participants}

func _prepared() -> Dictionary:
	var plans := {}
	for key: String in KEYS:
		plans[key] = {}
	return {"participant_plans": plans, "checkpoint_id": "run-r:5", "route_id": "main"}

func test_configure_restore_participants_validates_six_keys() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var manager: Node = _manager(log)["manager"]
	assert_eq(manager.configure_restore_participants({"run": load(FAKE_PARTICIPANT).new("run", log)}).get("code"),
		&"invalid_restore_participants", "fewer than six rejects")
	assert_eq(manager.commit_prepared_restore({}).get("code"), &"invalid_prepared_restore",
		"a prepared with no participant_plans rejects")

func test_restore_success_applies_and_finalizes_in_order() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	var manager: Node = wired["manager"]
	var emissions: Array = []
	manager.run_restored.connect(func(cp: String, route: String) -> void: emissions.append([cp, route]))
	var result: Dictionary = manager.commit_prepared_restore(_prepared())
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result["value"]["checkpoint_id"], "run-r:5")
	var applies: Array[String] = []
	var finals: Array[String] = []
	for entry: String in log.entries:
		if entry.ends_with(".apply_silent"): applies.append(entry.trim_suffix(".apply_silent"))
		if entry.ends_with(".finalize"): finals.append(entry.trim_suffix(".finalize"))
	assert_eq(applies, KEYS, "apply runs run->profile->localization->audio->route->narrative")
	assert_eq(finals, KEYS, "finalize runs in the same order")
	assert_eq(emissions.size(), 1, "exactly one run_restored")
	assert_false(manager.is_save_locked(), "restore lock released on success")
	assert_false(wired["gate"].is_active(), "mutation gate released on success")

func test_apply_failure_rolls_back_in_reverse_and_emits_nothing() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	var manager: Node = wired["manager"]
	wired["participants"]["audio"].set_failure(&"apply_silent")  # 4th in order
	var emissions: Array = []
	manager.run_restored.connect(func(_c: String, _r: String) -> void: emissions.append(true))
	var result: Dictionary = manager.commit_prepared_restore(_prepared())
	assert_false(result.get("ok", true), "audio apply failure fails the transaction")
	var rollbacks: Array[String] = []
	for entry: String in log.entries:
		if entry.ends_with(".rollback_silent"): rollbacks.append(entry.trim_suffix(".rollback_silent"))
	assert_eq(rollbacks, ["localization", "profile", "run"], "rollback runs in exact reverse order")
	assert_eq(emissions.size(), 0, "no run_restored on failure")
	assert_false(manager.is_save_locked(), "locks released after clean rollback")
	assert_false(wired["gate"].is_active())
	assert_false(wired["gate"].is_fatal_latched(), "a clean rollback never latches")

func test_rollback_failure_latches_shared_gate() -> void:
	var log: RefCounted = load(CALL_LOG).new()
	var wired := _manager(log)
	var manager: Node = wired["manager"]
	wired["participants"]["audio"].set_failure(&"apply_silent")
	wired["participants"]["profile"].set_failure(&"rollback_silent")
	var result: Dictionary = manager.commit_prepared_restore(_prepared())
	assert_false(result.get("ok", true))
	assert_eq(result["code"], &"APPLICATION_FATAL", JSON.stringify(result))
	assert_true(wired["gate"].is_fatal_latched(), "a failed rollback irreversibly latches the shared gate")
	assert_eq(result["details"]["failure"]["source"], "restore")
