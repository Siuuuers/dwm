extends "res://addons/gut/test.gd"
# SaveManager save-capability and lock integration
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 6).

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const TEMP_PATH := "res://tests/support/TemporaryStorage.gd"
const VALID_FIXTURE := "res://tests/fixtures/snapshots/valid_day3.json"

var _suite_counter := 0

func _artifacts_exist() -> bool:
	for path: String in [SAVE_MANAGER_PATH, STORAGE_PATH, TEMP_PATH]:
		if not ResourceLoader.exists(path, "Script"):
			return false
	return true

func _isolated_manager(suite_id: String) -> Node:
	_suite_counter += 1
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("save_manager_capability") \
		.path_join("%s_%d" % [suite_id, _suite_counter]).path_join("saves")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	var storage: RefCounted = load(STORAGE_PATH).new(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	assert_true(manager.initialize(storage)["ok"])
	return manager

## Plan 02 Task 6 (dwm-p2r.32): the v4 lifecycle/desktop identity fields this suite's hand-built
## snapshot_input now requires.
func _issuer_receipt(token: String) -> Dictionary:
	return {"receipt_id": "issuer_receipt.fixture-" + token, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": token, "numeric_value": null}

func _empty_desktop() -> Dictionary:
	return {
		"board": {"schema_version": 1, "phase": "NONE", "revision": 0, "identity": null,
			"candidate": null, "board": null, "settlement": null, "command_receipts": {}, "terminal_receipts": {}},
		"consequence": {"schema_version": 1, "run_revision": 0, "causal_sequence": 0,
			"causal_day_instance": "causal-day-1",
			"causal_day_instance_issuer_receipt": _issuer_receipt("causal-day-1"),
			"pending": null, "outbox": {}},
	}

func _seed(manager: Node, run_id: String) -> void:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VALID_FIXTURE))
	var lifecycle: Dictionary = fixture["lifecycle"]
	lifecycle["run_id"] = run_id
	lifecycle["branch_id"] = "branch-1"
	lifecycle["desktop_timeline_generation"] = 0
	lifecycle["causal_day_instance"] = "causal-day-1"
	lifecycle["causal_day_instance_issuer_receipt"] = _issuer_receipt("causal-day-1")
	lifecycle["restore_provenance"] = null
	assert_true(manager._journal.reset(run_id)["ok"])
	var seeded: Dictionary = manager.record_stable_checkpoint({
		"snapshot_input": {
			"lifecycle": lifecycle, "gameplay": fixture["gameplay"], "contacts": fixture["contacts"],
			"committed_schedule": {
				"schema_version": 1, "day": int(lifecycle["day"]),
				"registry_fingerprint": null, "entries": [], "commit_receipt": null,
			},
			"desktop": _empty_desktop(),
			"dating": fixture["dating"],
			"applied_effect_transaction_ids": [], "applied_variable_transaction_ids": [],
		},
		"dialogic_checkpoint": {}, "route_id": "main", "active_app_id": null,
		"audio_context": {}, "content_version": 1,
	}, &"day_start")
	assert_true(seeded.get("ok", false), JSON.stringify(seeded))

func test_capability_values_per_owner() -> void:
	assert_true(_artifacts_exist(), "artifacts must exist")
	if not _artifacts_exist():
		return
	var manager := _isolated_manager("capability_values")
	assert_eq(manager.get_save_capability(), {"enabled": true, "silent": false, "deferred": false})
	assert_true(manager.acquire_save_lock(&"minesweeper_board")["ok"])
	assert_eq(manager.get_save_capability(), {"enabled": false, "silent": true, "deferred": false})
	assert_true(manager.release_save_lock(&"minesweeper_board")["ok"])
	assert_true(manager.acquire_save_lock(&"scene_transition")["ok"])
	assert_eq(manager.get_save_capability(), {"enabled": false, "silent": true, "deferred": true})
	assert_true(manager.release_save_lock(&"scene_transition")["ok"])
	assert_true(manager.acquire_save_lock(&"restore")["ok"])
	assert_eq(manager.get_save_capability(), {"enabled": false, "silent": true, "deferred": false})

func test_lock_idempotence_and_cross_owner_release() -> void:
	assert_true(_artifacts_exist(), "artifacts must exist")
	if not _artifacts_exist():
		return
	var manager := _isolated_manager("lock_rules")
	assert_eq(manager.acquire_save_lock(&"bogus").get("code"), &"invalid_lock_owner")
	assert_true(manager.acquire_save_lock(&"restore")["ok"])
	var repeat: Dictionary = manager.acquire_save_lock(&"restore")
	assert_true(repeat["ok"] and repeat["value"]["already_locked"], "same owner is idempotent")
	assert_eq(manager.acquire_save_lock(&"minesweeper_board").get("code"), &"save_lock_held")
	assert_eq(manager.release_save_lock(&"minesweeper_board").get("code"), &"save_lock_mismatch",
		"another owner cannot release the lock")
	assert_true(manager.release_save_lock(&"restore")["ok"])
	assert_false(manager.is_save_locked())

func test_board_lock_is_silent_and_transition_defers() -> void:
	assert_true(_artifacts_exist(), "artifacts must exist")
	if not _artifacts_exist():
		return
	var manager := _isolated_manager("lock_behavior")
	_seed(manager, "run-lock")
	var emissions: Array[Dictionary] = []
	manager.save_capability_changed.connect(func(c: Dictionary) -> void: emissions.append(c))

	assert_true(manager.acquire_save_lock(&"minesweeper_board")["ok"])
	var board_blocked: Dictionary = manager.quick_save_latest()
	assert_false(board_blocked["ok"])
	assert_eq(board_blocked["code"], &"save_locked")
	assert_eq(board_blocked["details"], {"silent": true, "deferred": false})
	assert_false(manager.save_exists(&"quick", -1), "the board lock queues nothing and writes nothing")
	assert_true(manager.release_save_lock(&"minesweeper_board")["ok"])

	assert_true(manager.acquire_save_lock(&"scene_transition")["ok"])
	var deferred: Dictionary = manager.autosave_latest()
	assert_false(deferred["ok"])
	assert_eq(deferred["details"], {"silent": true, "deferred": true})
	assert_false(manager.save_exists(&"autosave", -1), "the deferred save has not written yet")
	assert_true(manager.release_save_lock(&"scene_transition")["ok"])
	assert_true(manager.save_exists(&"autosave", -1),
		"releasing the transition lock fulfills the pending save")
	assert_true(emissions.size() >= 4, "each lock and release emits a capability change")

func test_deferred_save_fulfilled_at_next_checkpoint() -> void:
	assert_true(_artifacts_exist(), "artifacts must exist")
	if not _artifacts_exist():
		return
	var manager := _isolated_manager("deferred_checkpoint")
	assert_true(manager._journal.reset("run-defer")["ok"])
	assert_true(manager.acquire_save_lock(&"scene_transition")["ok"])
	assert_false(manager.autosave_latest()["ok"], "no checkpoint yet, deferred")
	assert_true(manager.release_save_lock(&"scene_transition")["ok"])
	# Still no stable checkpoint, so the deferred autosave found nothing to write.
	assert_false(manager.save_exists(&"autosave", -1))
