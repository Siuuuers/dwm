extends "res://addons/gut/test.gd"
# SaveManagerCheckpointPort's Task-6 consequence-admission checkpoint additions
# (Plan 02 Task 6, dwm-p2r.32). Controller ruling: this file is listed as Modify in the brief but
# did not exist on this branch -- created here per that ruling.
#
# dwm-p2r.35.3 remediation (finding A-C3): extended for the keyed-records document, occupied-slot
# conflict law, receipt-attached stored candidate, and the new read_pending_consequence_checkpoint()
# reader -- see SaveManagerCheckpointPort.gd's own updated doc comments for the frozen-law citations.

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

## Builds a real DesktopConsequenceState, drives it through prepare_action_handoff() then
## prepare_sequence_reservation() (mirroring DesktopCausalSequencePort.commit()'s own live-side
## calls), and returns the resulting state_after -- a live consequence candidate at EXACTLY the
## sequence_committed admission point, with both admission_checkpoint_receipt and checkpoint_receipt
## still null (the frozen "in-flight admission" shape checkpoint_content_preimage() itself accepts,
## which DesktopConsequenceState.validate() rejects at rest -- the whole point of finding A-C3's
## unloadable-shape fix). `run_revision` is an optional knob so a second, structurally-valid-but-
## content-different candidate can be built at the SAME transaction_id/ordinal for the occupied-slot
## conflict tests.
func _admitted_state_candidate(transaction_id: String = "txn-1", run_revision_marker: int = 1) -> Dictionary:
	var state := CONSEQUENCE_STATE.new()
	var made: Dictionary = CONSEQUENCE_STATE.make_empty({
		"causal_day_instance": "causal-day-1", "causal_day_instance_issuer_receipt": _issuer_receipt("causal-day-1"),
	})
	var prepared_restore: Dictionary = state.prepare_restore(made["value"]["state"])
	state.commit(prepared_restore["value"]["candidate"])
	var payload := {"source_kind": "minesweeper_round", "action_receipt": {"result": "completed"},
		"run_revision_before": 0, "participant_snapshot_ids": {"marker": run_revision_marker}}
	var action_receipt := {
		"source_kind": "minesweeper_round", "transaction_id": transaction_id,
		"transaction_issuer_receipt": _issuer_receipt(transaction_id),
		"source_commit_receipt_id": "commit-receipt-1", "source_commit_receipt_provenance": {"child_kind": "board_fate"},
	}
	var handoff: Dictionary = state.prepare_action_handoff(action_receipt, 0, payload)
	assert_true(handoff.get("ok", false), JSON.stringify(handoff))
	state.commit(handoff["value"]["candidate"])
	var receipt := {
		"receipt_id": "causal-seq-receipt-1", "receipt_provenance": {}, "transaction_id": transaction_id,
		"transaction_issuer_receipt": _issuer_receipt(transaction_id), "run_id": "run-1", "branch_id": "branch-1",
		"desktop_timeline_generation": 0, "causal_day_instance": "causal-day-1",
		"source_kind": "minesweeper_round", "source_commit_receipt_id": "commit-receipt-1",
		"source_commit_receipt_provenance": {"child_kind": "board_fate"}, "causal_sequence": 1, "run_revision": 1,
	}
	var reserved: Dictionary = state.prepare_sequence_reservation({"transaction_id": transaction_id, "source_kind": "minesweeper_round"}, receipt)
	assert_true(reserved.get("ok", false), JSON.stringify(reserved))
	return reserved["value"]["candidate"]["state_after"]

## dwm-p2r.35.7 remediation (finding 1): a pre-admission (action_prepared) candidate -- the shape the
## source participant's own ordinal-0 checkpoint carries, mirroring _admitted_state_candidate()'s own
## pattern but stopping before prepare_sequence_reservation() (i.e. before admission).
func _pre_admission_state_candidate(transaction_id: String = "txn-1") -> Dictionary:
	var state := CONSEQUENCE_STATE.new()
	var made: Dictionary = CONSEQUENCE_STATE.make_empty({
		"causal_day_instance": "causal-day-1", "causal_day_instance_issuer_receipt": _issuer_receipt("causal-day-1"),
	})
	var prepared_restore: Dictionary = state.prepare_restore(made["value"]["state"])
	state.commit(prepared_restore["value"]["candidate"])
	var payload := {"source_kind": "minesweeper_round", "action_receipt": {"result": "completed"},
		"run_revision_before": 0, "participant_snapshot_ids": {}}
	var action_receipt := {
		"source_kind": "minesweeper_round", "transaction_id": transaction_id,
		"transaction_issuer_receipt": _issuer_receipt(transaction_id),
		"source_commit_receipt_id": "commit-receipt-1", "source_commit_receipt_provenance": {"child_kind": "board_fate"},
	}
	var handoff: Dictionary = state.prepare_action_handoff(action_receipt, 0, payload)
	assert_true(handoff.get("ok", false), JSON.stringify(handoff))
	return handoff["value"]["candidate"]["state_after"]

func _pre_admission_header(transaction_id: String = "txn-1") -> Dictionary:
	return {"kind": &"round_action_checkpoint", "operation_ordinal": 0, "run_id": "run-1",
		"source_ids": [transaction_id], "stage": "action_prepared", "transaction_id": transaction_id}

func _header(transaction_id: String = "txn-1", operation_ordinal: int = 2, stage: String = "sequence_committed") -> Dictionary:
	return {"kind": &"consequence_admission", "operation_ordinal": operation_ordinal, "run_id": "run-1",
		"source_ids": [], "stage": stage, "transaction_id": transaction_id}

func _record_key(transaction_id: String = "txn-1", operation_ordinal: int = 2) -> String:
	return transaction_id + ":" + str(operation_ordinal)


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


## dwm-p2r.35.3 remediation (finding A-C3, fix 2): the candidate prepare_consequence_checkpoint() builds
## carries the just-minted receipt attached to BOTH pending.checkpoint_receipt and
## pending.admission_checkpoint_receipt (this is the admission ordinal: both were null on the input),
## unlike the raw un-patched input -- the exact shape that makes the durable record loadable.
func test_prepare_consequence_checkpoint_attaches_the_receipt_to_the_admission_candidate() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var input_pending: Dictionary = candidate_state["pending"]
	assert_null(input_pending["checkpoint_receipt"], "the raw input candidate is receipt-free")
	assert_null(input_pending["admission_checkpoint_receipt"], "the raw input candidate is receipt-free")
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var stored_pending: Dictionary = (((prepared["value"] as Dictionary)["candidate"] as Dictionary)
		["document"] as Dictionary)["stage_candidate"]["pending"]
	var receipt: Dictionary = prepared["value"]["checkpoint_receipt"]
	assert_eq(stored_pending["checkpoint_receipt"], receipt)
	assert_eq(stored_pending["admission_checkpoint_receipt"], receipt)


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
	var record: Dictionary = ((parsed as Dictionary)["records"] as Dictionary)[_record_key()]
	# Plain JSON.parse_string() (unlike StrictJson) hands back String where the in-memory receipt
	# carries a StringName (header.kind), so this compares the fields that matter rather than whole-
	# dict identity across that boundary.
	var disk_receipt: Dictionary = record["checkpoint_receipt"]
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


## dwm-p2r.35.3 remediation (finding A-C3): real occupied-slot conflict law. An identical-bytes rewrite
## at an occupied (transaction_id, operation_ordinal) slot replays as success with no duplicate
## record; a changed-bytes rewrite at the same slot returns the frozen consequence_checkpoint_conflict
## and leaves the durable record untouched.
func test_commit_consequence_checkpoint_replays_an_identical_rewrite_at_an_occupied_slot() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var first_commit: Dictionary = port.commit_consequence_checkpoint(
		prepared["value"]["candidate"], prepared["value"]["checkpoint_receipt"])
	assert_true(first_commit.get("ok", false), JSON.stringify(first_commit))

	# A second, byte-identical prepare/commit pass over the SAME candidate at the SAME (transaction_id,
	# operation_ordinal) slot -- e.g. a retried commit after a crash right after the first write.
	var prepared_again: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared_again.get("ok", false), JSON.stringify(prepared_again))
	var replayed: Dictionary = port.commit_consequence_checkpoint(
		prepared_again["value"]["candidate"], prepared_again["value"]["checkpoint_receipt"])
	assert_true(replayed.get("ok", false), JSON.stringify(replayed))
	assert_eq(replayed["value"]["checkpoint_receipt"], first_commit["value"]["checkpoint_receipt"])

	var disk_path := str(wired["root"]).path_join("desktop-consequence-checkpoint.json")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(disk_path))
	assert_eq((parsed["records"] as Dictionary).size(), 1, "a byte-identical replay never grows a duplicate record")


func test_commit_consequence_checkpoint_rejects_a_different_rewrite_at_an_occupied_slot() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate("txn-1", 1)
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var first_commit: Dictionary = port.commit_consequence_checkpoint(
		prepared["value"]["candidate"], prepared["value"]["checkpoint_receipt"])
	assert_true(first_commit.get("ok", false), JSON.stringify(first_commit))

	# A structurally-valid but content-different candidate at the SAME transaction_id/ordinal slot.
	var conflicting_state: Dictionary = _admitted_state_candidate("txn-1", 2)
	var prepared_conflicting: Dictionary = port.prepare_consequence_checkpoint(_header(), conflicting_state)
	assert_true(prepared_conflicting.get("ok", false), JSON.stringify(prepared_conflicting))
	var rejected: Dictionary = port.commit_consequence_checkpoint(
		prepared_conflicting["value"]["candidate"], prepared_conflicting["value"]["checkpoint_receipt"])
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"consequence_checkpoint_conflict")

	# The original durable record is untouched.
	var disk_path := str(wired["root"]).path_join("desktop-consequence-checkpoint.json")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(disk_path))
	var records: Dictionary = parsed["records"]
	assert_eq(records.size(), 1)
	var record: Dictionary = records[_record_key()]
	assert_eq(str((record["checkpoint_receipt"] as Dictionary)["receipt_id"]),
		str(first_commit["value"]["checkpoint_receipt"]["receipt_id"]))


## Acceptance: a durable admission checkpoint written at ordinal 2 can be read back and passes
## DesktopConsequenceState.validate() -- proving the stored shape is genuinely loadable, not merely
## byte-written.
func test_a_committed_admission_checkpoint_reads_back_and_validates() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed: Dictionary = port.commit_consequence_checkpoint(
		prepared["value"]["candidate"], prepared["value"]["checkpoint_receipt"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))

	var read: Dictionary = port.read_pending_consequence_checkpoint()
	assert_true(read.get("ok", false), JSON.stringify(read))
	assert_true(bool(read["value"]["found"]))
	var loaded_state: Dictionary = read["value"]["stage_candidate"]
	assert_eq(str((loaded_state["pending"] as Dictionary)["transaction_id"]), "txn-1")
	var validated := CONSEQUENCE_STATE.validate(loaded_state)
	assert_true(validated.get("ok", false), "the durable admission checkpoint must load and validate: " + JSON.stringify(validated))


## dwm-p2r.35.7 remediation (finding 1): plan02-frozen-contracts.md line 2271 -- marks the durable
## unpromoted ordinal-0 checkpoint abandoned, and proves read_pending_consequence_checkpoint() no
## longer reports it as still-pending (the exact mechanism that stops
## adopt_durable_checkpoint_if_live_is_behind() from re-adopting an abandoned transaction on every
## subsequent boot). Also proves it never creates or promotes a checkpoint (the frozen law's own
## closing clause) and replays idempotently.
func test_abandon_pending_consequence_checkpoint_marks_a_pre_admission_checkpoint_abandoned() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _pre_admission_state_candidate()
	var header := _pre_admission_header()
	var prepared: Dictionary = port.prepare_consequence_checkpoint(header, candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed: Dictionary = port.commit_consequence_checkpoint(
		prepared["value"]["candidate"], prepared["value"]["checkpoint_receipt"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))

	var found_before: Dictionary = port.read_pending_consequence_checkpoint()
	assert_true(bool(found_before["value"]["found"]), "the durable ordinal-0 checkpoint is pending before abandonment")

	var abandoned: Dictionary = port.abandon_pending_consequence_checkpoint("txn-1")
	assert_true(abandoned.get("ok", false), JSON.stringify(abandoned))
	assert_false(bool(abandoned["value"]["already_abandoned"]))

	var found_after: Dictionary = port.read_pending_consequence_checkpoint()
	assert_true(found_after.get("ok", false), JSON.stringify(found_after))
	assert_false(bool(found_after["value"]["found"]), "an abandoned transaction must never be reported as still-pending")

	var replayed: Dictionary = port.abandon_pending_consequence_checkpoint("txn-1")
	assert_true(replayed.get("ok", false), JSON.stringify(replayed))
	assert_true(bool(replayed["value"]["already_abandoned"]))

	var disk_path := str(wired["root"]).path_join("desktop-consequence-checkpoint.json")
	var parsed: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(disk_path))
	assert_eq((parsed["records"] as Dictionary).size(), 1, "abandonment never creates or promotes a checkpoint")


func test_abandon_pending_consequence_checkpoint_rejects_a_nonexistent_transaction() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var rejected: Dictionary = port.abandon_pending_consequence_checkpoint("no-such-txn")
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"consequence_checkpoint_not_found")


## Abandonment is legal only pre-admission -- an already-admitted (sequence_committed) checkpoint may
## never be abandoned; forward recovery, not abandonment, is the only legal path from there.
func test_abandon_pending_consequence_checkpoint_rejects_an_already_admitted_transaction() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	port.commit_consequence_checkpoint(prepared["value"]["candidate"], prepared["value"]["checkpoint_receipt"])

	var rejected: Dictionary = port.abandon_pending_consequence_checkpoint("txn-1")
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"consequence_checkpoint_not_pre_admission")


func test_read_pending_consequence_checkpoint_finds_nothing_when_no_checkpoint_exists() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var read: Dictionary = port.read_pending_consequence_checkpoint()
	assert_true(read.get("ok", false), JSON.stringify(read))
	assert_false(bool(read["value"]["found"]))


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


## dwm-p2r.35.3 remediation (finding A-C3): ordinal/stage cross-validation is now centralized in
## prepare_consequence_checkpoint() (DesktopConsequenceState.validate_checkpoint_ordinal_stage()), so
## it fires for EVERY checkpoint author -- not only DesktopConsequenceCoordinator's own two directly-
## authored ordinals. Ordinal 0 (the source participant's own pre-admission checkpoint) must pair with
## "action_prepared"; pairing it with any other stage is rejected before anything reaches disk.
func test_prepare_consequence_checkpoint_rejects_a_bad_ordinal_stage_pairing_at_ordinal_0() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var bad_header := _header("txn-1", 0, "sequence_committed")
	var rejected: Dictionary = port.prepare_consequence_checkpoint(bad_header, candidate_state)
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"consequence_checkpoint_ordinal_stage_invalid")
	assert_false(FileAccess.file_exists(str(wired["root"]).path_join("desktop-consequence-checkpoint.json")))


## Same law, exercised somewhere in the 8-12 publication-progress/terminal-cleanup range this class's
## own DesktopConsequenceState.prepare_recovery_advance() authors -- ordinal 9 must pair with
## "publication_pending", never with an earlier stage.
func test_prepare_consequence_checkpoint_rejects_a_bad_ordinal_stage_pairing_at_ordinal_9() -> void:
	var wired := _isolated_wired()
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var bad_header := _header("txn-1", 9, "action_prepared")
	var rejected: Dictionary = port.prepare_consequence_checkpoint(bad_header, candidate_state)
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"consequence_checkpoint_ordinal_stage_invalid")
	assert_false(FileAccess.file_exists(str(wired["root"]).path_join("desktop-consequence-checkpoint.json")))
