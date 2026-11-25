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
var _fixture := preload("res://tests/support/SceneRunSaveFixture.gd").new()
var _scope := preload("res://tests/support/SceneValidationScope.gd").new()

func before_all() -> void:
	_scope.install(true)
	var setup: Dictionary = _fixture.setup(get_tree())
	assert_true(setup.ok, str(setup))

func after_all() -> void:
	_fixture.close()
	_scope.restore()

var _suite_counter := 0


## A state port that returns REAL checkpoint bundles, so the production checkpoint port
## accepts them. Everything else keeps the frozen fake behaviour and call counters.
class RealBundleStatePort:
	extends "res://tests/support/FakeMinesweeperStatePort.gd"
	var bundle: Dictionary = {}

	func capture() -> Dictionary:
		var captured := super.capture()
		captured.value.backup.run_id = bundle.snapshot_input.lifecycle.run_id
		return captured

	func prepare_begin(request: Dictionary, round_id: String) -> Dictionary:
		var prepared: Dictionary = super.prepare_begin(request, round_id)
		if prepared.get("ok", false):
			prepared.value.active_round.run_id = bundle.snapshot_input.lifecycle.run_id
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


## Wires the full production save chain behind one coordinator, over a journal that already
## holds one stable checkpoint (a manual save has nothing to write without one).
func _make_round(suite_id: String) -> Dictionary:
	var manager := _isolated_manager(suite_id)
	if manager == null:
		return {}
	assert_true(manager.get("_journal").reset(_fixture.identity.run_id).get("ok", false))
	assert_true(manager.call(&"record_stable_checkpoint", _fixture.checkpoint_inputs, &"day_start").get("ok", false))
	var gate: RefCounted = FAKE_GATE.new()
	var checkpoint_port: RefCounted = CHECKPOINT_PORT.new(manager)
	assert_true(checkpoint_port.configure_fatal_latch(gate).get("ok", false))
	var save_port: RefCounted = SAVE_PORT.new()
	assert_true(save_port.configure(checkpoint_port, manager).get("ok", false))
	var state_port := RealBundleStatePort.new(gate)
	state_port.bundle = _fixture.checkpoint_inputs
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
		str(made.coordinator.get_active_round().value.round_id), {"outcome": &"cleared"}, "tx-lock-1")
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
		str(made.coordinator.get_active_round().value.round_id), &"fatal_teardown", "tx-abort-1")
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
	var journal_before: Dictionary = manager._journal.capture_state()
	var disk_before: Dictionary = manager._storage.read_text("autosave.json")
	var begun: Dictionary = made["coordinator"].begin_round({"context": &"app", "difficulty": &"beginner"})
	assert_eq(manager._journal.capture_state(), journal_before)
	assert_eq(manager._storage.read_text("autosave.json"), disk_before)
	assert_false(begun.get("ok", false))
	assert_eq(begun.get("code"), &"SAVE_LOCK_FAILED")
	assert_false(made["save_port"].owns_board_lock())
	assert_eq(made["coordinator"].get_active_round().get("code"), &"no_active_round",
		"no round is active after a failed acquisition")
	assert_eq(manager.call(&"get_save_capability"), {"enabled": false, "silent": true, "deferred": false},
		"the pre-existing restore lock is untouched")
