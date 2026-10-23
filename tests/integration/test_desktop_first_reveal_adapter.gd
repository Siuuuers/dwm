extends "res://addons/gut/test.gd"
## Retained adapter refusal and explicit fake-checkpoint compatibility contracts.
## Motivation-charging durable cases remain byte-for-byte in
## test_minesweeper_first_reveal_transaction.gd; current ordinary-board durability
## is covered by scene_desktop_first_reveal_child.gd create/Load children.

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const CHECKPOINT_PORT_PATH := "res://scripts/application/run/SaveManagerCheckpointPort.gd"
const DESKTOP_BOARD_SAVE_PORT_PATH := "res://scripts/application/minesweeper/SaveManagerDesktopBoardPort.gd"
const GS_PATH := "res://autoload/GameState.gd"
const STATE_PORT_PATH := "res://scripts/application/minesweeper/GameStateDesktopBoardPort.gd"
const COORDINATOR_PATH := "res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd"
const FAKE_CHECKPOINT_PATH := "res://tests/support/FakeMinesweeperCheckpointPort.gd"
const FAKE_GENERATION_PATH := "res://tests/support/FakeMinesweeperGenerationPort.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const FAKE_NAMESPACE_SOURCE_PATH := "res://tests/support/FakeDesktopNamespaceSource.gd"
const RUN_ID := "run-local"
const IDENTITY_CONTEXT := {"run_id": RUN_ID, "branch_id": "branch-local",
	"desktop_timeline_generation": 0, "causal_day_instance": "causal-day-local"}

func _adapter_fixture() -> Dictionary:
	var manager: Node = autofree(load(SAVE_MANAGER_PATH).new())
	assert_true(manager.initialize(load(STORAGE_PATH).new("adapter-refusals", FakeFileOps.new())).ok)
	manager._journal.reset(RUN_ID)
	var checkpoint: RefCounted = load(CHECKPOINT_PORT_PATH).new(manager)
	assert_true(checkpoint.configure_fatal_latch(load(GATE_PATH).new()).ok)
	return {"durable_port": load(DESKTOP_BOARD_SAVE_PORT_PATH).new(checkpoint)}

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

func test_adapter_rejects_a_desktop_less_post_commit_snapshot_input() -> void:
	var wired := _adapter_fixture()
	if wired.is_empty():
		return
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
	var wired := _adapter_fixture()
	if wired.is_empty():
		return
	var durable_port: Object = wired["durable_port"]
	var prepared: Dictionary = durable_port.prepare_checkpoint(
		{"lifecycle": {"run_id": RUN_ID}, "desktop": {"board": {}}}, &"pre_board",
		{"kind": &"autosave", "reason": &"pre_board"})
	assert_false(prepared.get("ok", true), "a desktop member missing consequence must reject")
	assert_eq(prepared["code"], &"invalid_post_commit_snapshot_input")

func test_adapter_rejects_an_extra_desktop_key() -> void:
	var wired := _adapter_fixture()
	if wired.is_empty():
		return
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
	var created: Dictionary = TEMPORARY_STORAGE.create("first-reveal-fake-only")
	assert_true(created.get("ok", false), created.get("message", ""))
	if not created.get("ok", false):
		return
	var issuer := _fresh_issuer(str(created["value"]))
	var fake_checkpoint: RefCounted = load(FAKE_CHECKPOINT_PATH).new()
	var generation_port: RefCounted = load(FAKE_GENERATION_PATH).new()
	generation_port.arm_materialize({"schema_version": 1, "width": 8, "height": 8, "mine_indices": [53,54,55,56,57,58,59,60,61,62,63], "mine_count": 11})
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

