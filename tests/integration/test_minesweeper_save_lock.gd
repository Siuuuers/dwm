extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
# Step 2.5 (dwm-p2r.9 Plan 06 Task 2): the board lock is SILENT.
#
# These tests drive the real SaveManager, real CheckpointJournal, real SaveManagerCheckpointPort
# and real SaveManagerMinesweeperPort. Only the GameState side is a fake, so the whole durable
# save/lock path under test is production code.

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const SAVE_PORT := preload("res://scripts/application/minesweeper/SaveManagerMinesweeperPort.gd")
const COORDINATOR := preload("res://scripts/domain/minesweeper/MinesweeperRoundCoordinator.gd")
const FAKE_STATE := preload("res://tests/support/FakeMinesweeperStatePort.gd")
const FAKE_GATE := preload("res://tests/support/FakeApplicationMutationGate.gd")
const SCHEDULE_VIEW := preload("res://scripts/domain/schedule/ScheduleViewState.gd")
const VALID_FIXTURE := "res://tests/fixtures/snapshots/valid_day3.json"

## FakeMinesweeperStatePort reports this run and ordinal, so the journal, the previewed
## checkpoint ids and the built round id all have to agree with it.
const RUN_ID := "run-1"
const ROUND_ID := "run-1:day-1:round-1"

var _suite_counter := 0


## A state port that returns REAL checkpoint bundles, so the production checkpoint port
## accepts them. Everything else keeps the frozen fake behaviour and call counters.
class RealBundleStatePort:
	extends "res://tests/support/FakeMinesweeperStatePort.gd"
	var bundle: Dictionary = {}

	func prepare_begin(request: Dictionary, round_id: String) -> Dictionary:
		var prepared: Dictionary = super.prepare_begin(request, round_id)
		if prepared.get("ok", false):
			prepared["value"]["pre_board_checkpoint_inputs"] = bundle.duplicate(true)
		return prepared

	func finalize_complete(prepared_completion: Dictionary, checkpoint_id: String) -> Dictionary:
		var finalized: Dictionary = super.finalize_complete(prepared_completion, checkpoint_id)
		if finalized.get("ok", false):
			finalized["value"]["post_result_checkpoint_inputs"] = bundle.duplicate(true)
		return finalized


func _isolated_manager(suite_id: String) -> Node:
	_suite_counter += 1
	var created: Dictionary = TEMPORARY_STORAGE.create(
		"minesweeper-save-lock-%s-%d" % [suite_id, _suite_counter])
	assert_true(created.get("ok", false), created.get("message", ""))
	if not created.get("ok", false):
		return null
	var root := str(created["value"]).path_join("saves")
	var manager: Node = autofree(load(SAVE_MANAGER_PATH).new())
	assert_true(manager.call(&"initialize", STORAGE.new(root)).get("ok", false))
	return manager


## Test-authored current snapshot inputs explicitly choose Dark=false.
## Historical payload reuse is not a production migration. This retained .9-era lock stack still checkpoints through the same
## SaveManagerCheckpointPort / RunSnapshotSchema production code, so it must supply a v6-valid
## bundle even though the desktop board itself is never driven here.
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
			"pending": null, "outbox": {}, "shop_ledger": {"supportz_branch_purchase_count": 0,
				"supportz_last_purchase_causal_day_instance": "", "base_completion_receipts": []}},
	}

func _bundle(run_id: String) -> Dictionary:
	var fixture: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VALID_FIXTURE))
	fixture["gameplay"].erase("opening_seen")
	fixture["gameplay"].erase("tutorial_seen")
	var lifecycle: Dictionary = fixture["lifecycle"]
	lifecycle["dark_mode"] = false
	lifecycle["run_id"] = run_id
	lifecycle["branch_id"] = "branch-1"
	lifecycle["desktop_timeline_generation"] = 0
	lifecycle["causal_day_instance"] = "causal-day-1"
	lifecycle["causal_day_instance_issuer_receipt"] = _issuer_receipt("causal-day-1")
	lifecycle["restore_provenance"] = null
	lifecycle["active_condition_hospital_plan"] = null
	lifecycle["condition_hospital_history"] = {}
	lifecycle["terminal_intent_handoff"] = null
	var schedule_view: Dictionary = SCHEDULE_VIEW.make_empty(
		int(lifecycle["day"]), str(lifecycle["causal_day_instance"]))["value"]["view"]
	return {
		"snapshot_input": {
			"lifecycle": lifecycle, "gameplay": fixture["gameplay"], "contacts": fixture["contacts"],
			"committed_schedule": {
				"schema_version": 1, "day": int(lifecycle["day"]),
				"registry_fingerprint": null, "entries": [], "commit_receipt": null,
			},
			"desktop": _empty_desktop(),
			"schedule_view": schedule_view,
			"dating": fixture["dating"],
			"applied_effect_transaction_ids": [], "applied_variable_transaction_ids": [],
		},
		"dialogic_checkpoint": {}, "route_id": "main", "active_app_id": null,
		"audio_context": {}, "content_version": 1,
	}


## Wires the full production save chain behind one coordinator, over a journal that already
## holds one stable checkpoint (a manual save has nothing to write without one).
func _make_round(suite_id: String) -> Dictionary:
	var manager := _isolated_manager(suite_id)
	if manager == null:
		return {}
	assert_true(manager.get("_journal").reset(RUN_ID).get("ok", false))
	assert_true(manager.call(&"record_stable_checkpoint", _bundle(RUN_ID), &"day_start").get("ok", false))
	var gate: RefCounted = FAKE_GATE.new()
	var checkpoint_port: RefCounted = CHECKPOINT_PORT.new(manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	var save_port: RefCounted = SAVE_PORT.new()
	assert_true(save_port.configure(checkpoint_port, manager).get("ok", false))
	var state_port := RealBundleStatePort.new(gate)
	state_port.bundle = _bundle(RUN_ID)
	var coordinator: RefCounted = COORDINATOR.new()
	assert_true(coordinator.configure(save_port, state_port).get("ok", false))
	return {
		"manager": manager, "gate": gate, "checkpoint_port": checkpoint_port,
		"save_port": save_port, "state_port": state_port, "coordinator": coordinator,
	}


func test_production_save_port_delegates_only_the_board_lock_owner() -> void:
	var manager := _isolated_manager("owner_only")
	if manager == null:
		return
	var gate: RefCounted = FAKE_GATE.new()
	var checkpoint_port: RefCounted = CHECKPOINT_PORT.new(manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	var save_port: RefCounted = SAVE_PORT.new()
	assert_true(save_port.configure(checkpoint_port, manager).get("ok", false))
	assert_eq(save_port.get("BOARD_LOCK_OWNER"), &"minesweeper_board")
	assert_false(save_port.owns_board_lock())
	assert_true(save_port.acquire_board_lock().get("ok", false))
	assert_true(save_port.owns_board_lock())
	assert_true(manager.call(&"is_save_locked"))
	# The adapter never reaches for another owner, so a foreign release cannot succeed.
	assert_eq(manager.call(&"release_save_lock", &"scene_transition").get("code"), &"save_lock_mismatch")
	assert_true(save_port.owns_board_lock())
	assert_true(save_port.release_board_lock().get("ok", false))
	assert_false(save_port.owns_board_lock())
	assert_false(manager.call(&"is_save_locked"))
	var source := FileAccess.get_file_as_string(
		"res://scripts/application/minesweeper/SaveManagerMinesweeperPort.gd")
	for foreign: String in ["scene_transition", "restore", "new_run"]:
		assert_false(source.contains(foreign),
			"the board adapter names no other lock owner: " + foreign)


func test_active_round_disables_save_silently_and_never_defers() -> void:
	var made := _make_round("active_round")
	if made.is_empty():
		return
	var manager: Node = made["manager"]
	var emissions: Array[Dictionary] = []
	manager.save_capability_changed.connect(func(c: Dictionary) -> void: emissions.append(c))
	assert_eq(manager.call(&"get_save_capability"), {"enabled": true, "silent": false, "deferred": false})

	var begun: Dictionary = made["coordinator"].begin_round({"context": &"app", "difficulty": &"beginner"})
	assert_true(begun.get("ok", false), str(begun))

	# The exact frozen capability while a board is active.
	assert_eq(manager.call(&"get_save_capability"), {"enabled": false, "silent": true, "deferred": false})
	assert_true(made["save_port"].owns_board_lock())

	# A manual save returns the silent locked result and writes nothing.
	var manual: Dictionary = manager.call(&"quick_save_latest")
	assert_false(manual.get("ok", false))
	assert_eq(manual.get("code"), &"save_locked")
	assert_eq(manual.get("details"), {"silent": true, "deferred": false},
		"never deferred: the board lock queues no save")
	assert_false(manager.call(&"save_exists", &"quick", -1))

	# A repeated input is consumed and ignored the same way, still with nothing queued.
	var repeated: Dictionary = manager.call(&"quick_save_latest")
	assert_eq(repeated.get("code"), &"save_locked")
	assert_false(manager.call(&"save_exists", &"quick", -1))
	assert_false(bool(manager.get("_pending_deferred_save")),
		"no deferred save is retained behind the board lock")

	# No notification/toast/dialog/recommendation channel fired; only capability changed.
	for emission: Dictionary in emissions:
		assert_false(bool(emission.get("enabled", true)) and emission.has("recommendation"),
			"the board lock raises no save recommendation")
	assert_eq(emissions.size(), 1, "exactly one capability change: the acquisition itself")


func test_completion_releases_the_lock_and_restores_capability() -> void:
	var made := _make_round("completion")
	if made.is_empty():
		return
	var manager: Node = made["manager"]
	assert_true(made["coordinator"].begin_round({"context": &"app", "difficulty": &"beginner"}).get("ok", false))
	assert_true(manager.call(&"is_save_locked"))
	var completed: Dictionary = made["coordinator"].complete_round(
		ROUND_ID, {"outcome": &"cleared"}, "tx-lock-1")
	assert_true(completed.get("ok", false), str(completed))
	assert_false(manager.call(&"is_save_locked"), "completion releases the board lock")
	assert_false(made["save_port"].owns_board_lock())
	assert_eq(manager.call(&"get_save_capability"), {"enabled": true, "silent": false, "deferred": false})
	# Saving works again immediately, with no deferred save having been queued meanwhile.
	assert_true(manager.call(&"quick_save_latest").get("ok", false))
	assert_true(manager.call(&"save_exists", &"quick", -1))


func test_abort_releases_the_lock_without_publishing_a_result() -> void:
	var made := _make_round("abort")
	if made.is_empty():
		return
	var manager: Node = made["manager"]
	assert_true(made["coordinator"].begin_round({"context": &"app", "difficulty": &"beginner"}).get("ok", false))
	made["state_port"].reset_call_counts()
	var aborted: Dictionary = made["coordinator"].abort_round(
		ROUND_ID, &"fatal_teardown", "tx-abort-1")
	assert_true(aborted.get("ok", false), str(aborted))
	assert_false(manager.call(&"is_save_locked"), "abort releases the board lock")
	assert_eq(int(made["state_port"].get_call_counts()["publish"]), 0,
		"a trusted abort emits no result")
	assert_eq(manager.call(&"get_save_capability"), {"enabled": true, "silent": false, "deferred": false})


func test_a_failed_lock_acquisition_consumes_no_round_and_leaves_no_lock() -> void:
	var made := _make_round("lock_failure")
	if made.is_empty():
		return
	var manager: Node = made["manager"]
	# Another owner already holds the lock, so the board can never take it.
	assert_true(manager.call(&"acquire_save_lock", &"restore").get("ok", false))
	var begun: Dictionary = made["coordinator"].begin_round({"context": &"app", "difficulty": &"beginner"})
	assert_false(begun.get("ok", false))
	assert_eq(begun.get("code"), &"SAVE_LOCK_FAILED")
	assert_false(made["save_port"].owns_board_lock())
	assert_eq(made["coordinator"].get_active_round().get("code"), &"no_active_round",
		"no round is active after a failed acquisition")
	assert_eq(manager.call(&"get_save_capability"), {"enabled": false, "silent": true, "deferred": false},
		"the pre-existing restore lock is untouched")
