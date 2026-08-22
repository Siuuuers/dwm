extends "res://addons/gut/test.gd"
# SaveManagerCheckpointPort's Task-6 consequence-admission checkpoint additions
# (Plan 02 Task 6, dwm-p2r.32). Controller ruling: this file is listed as Modify in the brief but
# did not exist on this branch -- created here per that ruling.

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const CHECKPOINT_PORT_PATH := "res://scripts/application/run/SaveManagerCheckpointPort.gd"
const CONSEQUENCE_STATE_PATH := "res://scripts/domain/desktop/DesktopConsequenceState.gd"

const CONSEQUENCE_STATE := preload(CONSEQUENCE_STATE_PATH)

var _suite_counter := 0

func _isolated_wired() -> Dictionary:
	_suite_counter += 1
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("save_manager_consequence_checkpoint") \
		.path_join(str(_suite_counter)).path_join("saves")
	assert_eq(DirAccess.make_dir_recursive_absolute(root), OK)
	var storage: RefCounted = load(STORAGE_PATH).new(root)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	assert_true(manager.initialize(storage)["ok"])
	var gate: RefCounted = load(GATE_PATH).new()
	var port: RefCounted = load(CHECKPOINT_PORT_PATH).new(manager)
	assert_true(port.configure_fatal_latch(gate)["ok"])
	return {"manager": manager, "gate": gate, "port": port, "root": root}

func _issuer_receipt(token: String) -> Dictionary:
	return {"receipt_id": "issuer_receipt.fixture-" + token, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": token, "numeric_value": null}

func _admitted_state_candidate() -> Dictionary:
	# A live DesktopConsequenceState at exactly the sequence_committed admission point, matching
	# what DesktopCausalSequencePort.commit() would feed to prepare_consequence_checkpoint().
	var state := CONSEQUENCE_STATE.new()
	var made: Dictionary = CONSEQUENCE_STATE.make_empty({
		"causal_day_instance": "causal-day-1", "causal_day_instance_issuer_receipt": _issuer_receipt("causal-day-1"),
	})
	var prepared_restore: Dictionary = state.prepare_restore(made["value"]["state"])
	state.commit(prepared_restore["value"]["candidate"])
	var payload := {"source_kind": "minesweeper_round", "action_receipt": {"result": "completed"},
		"run_revision_before": 0, "participant_snapshot_ids": {}}
	var action_receipt := {
		"source_kind": "minesweeper_round", "transaction_id": "txn-1",
		"transaction_issuer_receipt": _issuer_receipt("txn-1"),
		"source_commit_receipt_id": "commit-receipt-1", "source_commit_receipt_provenance": {"child_kind": "board_fate"},
	}
	var handoff: Dictionary = state.prepare_action_handoff(action_receipt, 0, payload)
	assert_true(handoff.get("ok", false), JSON.stringify(handoff))
	state.commit(handoff["value"]["candidate"])
	var receipt := {
		"receipt_id": "causal-seq-receipt-1", "receipt_provenance": {}, "transaction_id": "txn-1",
		"transaction_issuer_receipt": _issuer_receipt("txn-1"), "run_id": "run-1", "branch_id": "branch-1",
		"desktop_timeline_generation": 0, "causal_day_instance": "causal-day-1",
		"source_kind": "minesweeper_round", "source_commit_receipt_id": "commit-receipt-1",
		"source_commit_receipt_provenance": {"child_kind": "board_fate"}, "causal_sequence": 1, "run_revision": 1,
	}
	var reserved: Dictionary = state.prepare_sequence_reservation({"transaction_id": "txn-1", "source_kind": "minesweeper_round"}, receipt)
	assert_true(reserved.get("ok", false), JSON.stringify(reserved))
	return reserved["value"]["candidate"]["state_after"]

func _header(transaction_id: String = "txn-1") -> Dictionary:
	return {"kind": &"consequence_admission", "operation_ordinal": 0, "run_id": "run-1",
		"source_ids": [], "stage": "sequence_committed", "transaction_id": transaction_id}


func test_prepare_consequence_checkpoint_builds_a_candidate_and_receipt() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var receipt: Dictionary = prepared["value"]["checkpoint_receipt"]
	assert_true(str(receipt["receipt_id"]).begins_with("consequence_checkpoint."))
	assert_eq(receipt["header"], _header())
	# Mutation-free: nothing is written to disk yet.
	assert_false(FileAccess.file_exists(str(wired["root"]).path_join("desktop-consequence-checkpoint.json")))


func test_commit_consequence_checkpoint_writes_and_rereads() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed: Dictionary = port.commit_consequence_checkpoint(
		prepared["value"]["candidate"], prepared["value"]["checkpoint_receipt"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(committed["value"]["checkpoint_receipt"], prepared["value"]["checkpoint_receipt"])
	var disk_path := str(wired["root"]).path_join("desktop-consequence-checkpoint.json")
	assert_true(FileAccess.file_exists(disk_path))
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(disk_path))
	assert_eq(typeof(parsed), TYPE_DICTIONARY)
	# Plain JSON.parse_string() (unlike StrictJson) hands back String where the in-memory receipt
	# carries a StringName (header.kind), so this compares the fields that matter rather than whole-
	# dict identity across that boundary.
	var disk_receipt: Dictionary = (parsed as Dictionary)["checkpoint_receipt"]
	assert_eq(str(disk_receipt["receipt_id"]), str(prepared["value"]["checkpoint_receipt"]["receipt_id"]))
	assert_eq(str(disk_receipt["content_sha256"]), str(prepared["value"]["checkpoint_receipt"]["content_sha256"]))


func test_commit_consequence_checkpoint_rejects_a_receipt_mismatch() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var forged_receipt: Dictionary = (prepared["value"]["checkpoint_receipt"] as Dictionary).duplicate(true)
	forged_receipt["content_sha256"] = "0".repeat(64)
	var rejected: Dictionary = port.commit_consequence_checkpoint(prepared["value"]["candidate"], forged_receipt)
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"checkpoint_receipt_mismatch")
	var disk_path := str(wired["root"]).path_join("desktop-consequence-checkpoint.json")
	assert_false(FileAccess.file_exists(disk_path), "a rejected commit never writes to disk")


func test_prepare_consequence_checkpoint_requires_configuration() -> void:
	var port: RefCounted = load(CHECKPOINT_PORT_PATH).new()
	var candidate_state := _admitted_state_candidate()
	var rejected: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"fatal_latch_not_configured")


func test_checkpoint_content_preimage_is_the_sole_builder() -> void:
	# The preimage/receipt fields the port produces must trace back to DesktopConsequenceState's own
	# checkpoint_content_preimage(), never a second copy of that hashing law inside the port.
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var expected_preimage: Dictionary = CONSEQUENCE_STATE.checkpoint_content_preimage(_header(), candidate_state)
	assert_true(expected_preimage.get("ok", false), JSON.stringify(expected_preimage))
	var expected_hash: String = CanonicalJsonWriter.stringify(
		(expected_preimage["value"] as Dictionary)["preimage"])["value"].sha256_text()
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq(str(prepared["value"]["checkpoint_receipt"]["content_sha256"]), expected_hash)
