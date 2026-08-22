extends "res://addons/gut/test.gd"
## Production durable first-Reveal transaction (Plan 02 Task 6, dwm-p2r.32, Phase D, brief Steps
## 6.10-6.12). Configures the REAL SaveManagerDesktopBoardPort over an isolated store and v4
## providers, and the real Task-5 MinesweeperRoundCoordinator/GameStateDesktopBoardPort through the
## new durable seam (MinesweeperRoundCoordinator.configure_durable_checkpoint()). Representative,
## not the brief's full exhaustive crash-injection matrix -- see the composer unit test and the
## task-6 report for the documented scope reduction this task's own precedent already established.
##
## The generation port stays the Task-5 FAKE (pure board-layout mechanics, unrelated to
## persistence); everything on the PERSISTENCE side -- SaveManager, its CheckpointJournal, its
## storage, the desktop identity issuer -- is real.

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const CHECKPOINT_PORT_PATH := "res://scripts/application/run/SaveManagerCheckpointPort.gd"
const DESKTOP_BOARD_SAVE_PORT_PATH := "res://scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd"
const COMPOSER_PATH := "res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd"
const GS_PATH := "res://autoload/GameState.gd"
const STATE_PORT_PATH := "res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd"
const CONSEQUENCE_STATE_PATH := "res://scripts/domain/desktop/DesktopConsequenceState.gd"
const COORDINATOR_PATH := "res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd"
const FAKE_CHECKPOINT_PATH := "res://tests/support/FakeMinesweeperCheckpointPort.gd"
const FAKE_GENERATION_PATH := "res://tests/support/FakeMinesweeperGenerationPort.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const FAKE_NAMESPACE_SOURCE_PATH := "res://tests/support/FakeDesktopNamespaceSource.gd"

const RUN_ID := "run-local"
const IDENTITY_CONTEXT := {
	"run_id": RUN_ID, "branch_id": "branch-local", "desktop_timeline_generation": 0,
	"causal_day_instance": "causal-day-local",
}


func _fresh_issuer(root: String) -> RefCounted:
	var file_ops: FakeFileOps = FakeFileOps.new()
	var storage := JsonFileStorage.new(root.path_join("_issuer"), file_ops)
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE_PATH).new("5".repeat(64))
	var store: RefCounted = load(ROOT_STORE_PATH).new()
	assert_true(store.configure(storage, namespace_source).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(store).get("ok", false))
	return issuer


func _wired() -> Dictionary:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("first_reveal_durable").path_join(str(randi()))
	DirAccess.make_dir_recursive_absolute(root.path_join("saves"))

	var save_manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(save_manager)
	save_manager.initialize(load(STORAGE_PATH).new(root.path_join("saves")))
	var gate: RefCounted = load(GATE_PATH).new()
	save_manager.configure_mutation_gate(gate)
	save_manager._journal.reset(RUN_ID)

	var checkpoint_port: Object = load(CHECKPOINT_PORT_PATH).new(save_manager)
	assert_true(checkpoint_port.configure_fatal_latch(load(GATE_PATH).new()).get("ok", false))
	var durable_port: Object = load(DESKTOP_BOARD_SAVE_PORT_PATH).new(checkpoint_port)

	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()

	var issuer := _fresh_issuer(root)
	var consequence_state: RefCounted = load(CONSEQUENCE_STATE_PATH).new()

	var state_port: Object = load(STATE_PORT_PATH).new()
	assert_true(state_port.configure(gs, issuer, IDENTITY_CONTEXT).get("ok", false))
	assert_true(state_port.configure_consequence_state_port(consequence_state).get("ok", false))

	var generation_port: RefCounted = load(FAKE_GENERATION_PATH).new()
	generation_port.arm_materialize({"schema_version": 1, "width": 9, "height": 9, "mine_indices": [70,71,72,73,74,75,76,77,78,79,80], "mine_count": 11})

	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	var fake_checkpoint: RefCounted = load(FAKE_CHECKPOINT_PATH).new()
	assert_true(coordinator.configure(state_port, fake_checkpoint, generation_port, issuer).get("ok", false))
	assert_true(coordinator.configure_durable_checkpoint(durable_port, load(COMPOSER_PATH), consequence_state).get("ok", false))

	return {"coordinator": coordinator, "save_manager": save_manager, "root": root, "gs": gs,
		"issuer": issuer, "durable_port": durable_port}


func _tx(issuer: Object) -> Dictionary:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.get("ok", false), JSON.stringify(issued))
	return {"transaction_id": str(issued["value"]["token"]), "transaction_issuer_receipt": issued["value"]["issuer_receipt"]}


func _reveal_request(coordinator: Object, issuer: Object, cell_index: int = 0) -> Dictionary:
	var context: Dictionary = coordinator.get_entry_context("beginner")
	assert_true(context.get("ok", false), JSON.stringify(context))
	var identity: Dictionary = context["value"]["identity"]
	var tx := _tx(issuer)
	return {
		"transaction_id": tx["transaction_id"], "transaction_issuer_receipt": tx["transaction_issuer_receipt"],
		"expected_identity": identity, "expected_revision": 0, "difficulty_id": "beginner", "cell_index": cell_index,
	}


## Reads through the SAME StorageAdapter instance the write happened on (SaveManager._storage) --
## a freshly constructed JsonFileStorage over the same root has no reconciled view of a write it
## never itself performed. StrictJson (not the bare JSON singleton, which parses every number as
## float) is this codebase's own established reader for exactly this reason.
func _autosave_document(save_manager: Node) -> Dictionary:
	var read: Dictionary = save_manager._storage.read_text("autosave.json")
	assert_true(read.get("ok", false), JSON.stringify(read))
	var parsed: Dictionary = load("res://scripts/validation/StrictJson.gd").parse_object(str(read["value"]))
	assert_true(parsed.get("ok", false), JSON.stringify(parsed))
	return parsed["value"] as Dictionary


func test_first_reveal_writes_a_durable_pre_board_autosave_with_the_charged_and_revealed_state() -> void:
	var wired := _wired()
	var coordinator: RefCounted = wired["coordinator"]
	var request := _reveal_request(coordinator, wired["issuer"])
	var result: Dictionary = coordinator.reveal(request)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(result.get("code"), &"first_reveal_committed")

	var document := _autosave_document(wired["save_manager"])
	assert_eq(str(document["save_reason"]), "pre_board")
	var snapshot: Dictionary = document["current_snapshot"]["snapshot"]
	assert_eq(int(snapshot["gameplay"]["minesweeper_rounds_left"]), 1, "the round is genuinely decremented on disk")
	assert_eq(int(snapshot["gameplay"]["stats"]["motivation"]), 6, "motivation is genuinely charged on disk")
	var board: Dictionary = snapshot["desktop"]["board"]
	assert_eq(str(board["phase"]), "ACTIVE_VISIBLE")
	assert_true((board["board"]["board"]["revealed_indices"] as Array).has(0), "the forced cell is revealed on disk")
	assert_true((board["board"] as Dictionary).has("paid_start_receipt"))

	# Live state agrees with disk (forward-committed after the checkpoint, per the frozen order).
	assert_eq(coordinator.get_state()["value"]["phase"], "ACTIVE_VISIBLE")


func test_first_reveal_charges_exactly_once_across_a_retried_request() -> void:
	var wired := _wired()
	var coordinator: RefCounted = wired["coordinator"]
	var request := _reveal_request(coordinator, wired["issuer"])
	var first: Dictionary = coordinator.reveal(request)
	assert_true(first.get("ok", false), JSON.stringify(first))
	var retried: Dictionary = coordinator.reveal(request)
	assert_true(retried.get("ok", false), JSON.stringify(retried))
	assert_eq(retried["value"]["receipt"], first["value"]["receipt"], "an identical retry republishes, never recharges")
	var document := _autosave_document(wired["save_manager"])
	assert_eq(int(document["current_snapshot"]["snapshot"]["gameplay"]["stats"]["motivation"]), 6,
		"only one paid first Reveal ever reaches disk")


func test_adapter_rejects_a_desktop_less_post_commit_snapshot_input() -> void:
	var wired := _wired()
	var durable_port: Object = wired["durable_port"]
	var preview: Dictionary = durable_port.preview_checkpoint_id(RUN_ID)
	assert_true(preview.get("ok", false), JSON.stringify(preview))
	var v3_shaped := {
		"active_app_id": null, "audio_context": {}, "content_version": 1,
		"dialogic_checkpoint": {}, "route_id": "main",
		"snapshot_input": {"lifecycle": {"run_id": RUN_ID}},
	}
	var prepared: Dictionary = durable_port.prepare_checkpoint(v3_shaped["snapshot_input"], &"pre_board",
		{"kind": &"autosave", "reason": &"pre_board"})
	assert_false(prepared.get("ok", true), "a desktop-less (schema 3) snapshot_input must reject")
	assert_eq(prepared["code"], &"invalid_post_commit_snapshot_input")


func test_adapter_rejects_a_board_only_desktop_value() -> void:
	var wired := _wired()
	var durable_port: Object = wired["durable_port"]
	var prepared: Dictionary = durable_port.prepare_checkpoint(
		{"lifecycle": {"run_id": RUN_ID}, "desktop": {"board": {}}}, &"pre_board",
		{"kind": &"autosave", "reason": &"pre_board"})
	assert_false(prepared.get("ok", true), "a desktop member missing consequence must reject")
	assert_eq(prepared["code"], &"invalid_post_commit_snapshot_input")


func test_adapter_rejects_an_extra_desktop_key() -> void:
	var wired := _wired()
	var durable_port: Object = wired["durable_port"]
	var prepared: Dictionary = durable_port.prepare_checkpoint(
		{"lifecycle": {"run_id": RUN_ID}, "desktop": {"board": {}, "consequence": {}, "surprise": {}}},
		&"pre_board", {"kind": &"autosave", "reason": &"pre_board"})
	assert_false(prepared.get("ok", true), "an extra desktop key must reject")
	assert_eq(prepared["code"], &"invalid_post_commit_snapshot_input")


func test_first_reveal_falls_back_to_the_fake_checkpoint_when_durable_is_not_configured() -> void:
	# Task-5 parity: a coordinator that never calls configure_durable_checkpoint() behaves exactly
	# as it always did (brief line 295: "cannot install a second coordinator or silently adapt a
	# fake candidate" -- the untouched fake path proves the durable addition changed nothing there).
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("first_reveal_fake_only").path_join(str(randi()))
	var issuer := _fresh_issuer(root)
	var fake_checkpoint: RefCounted = load(FAKE_CHECKPOINT_PATH).new()
	var generation_port: RefCounted = load(FAKE_GENERATION_PATH).new()
	generation_port.arm_materialize({"schema_version": 1, "width": 9, "height": 9, "mine_indices": [70,71,72,73,74,75,76,77,78,79,80], "mine_count": 11})
	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	gs.reset_game()
	var state_port: Object = load(STATE_PORT_PATH).new()
	assert_true(state_port.configure(gs, issuer, IDENTITY_CONTEXT).get("ok", false))
	var coordinator: RefCounted = load(COORDINATOR_PATH).new()
	assert_true(coordinator.configure(state_port, fake_checkpoint, generation_port, issuer).get("ok", false))

	var result: Dictionary = coordinator.reveal(_reveal_request(coordinator, issuer))
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_true(fake_checkpoint.is_sealed("run-local:1"), "the untouched fake path still seals, exactly as Task 5 left it")
