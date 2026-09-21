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
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

func _canonical_text(value: Variant) -> String:
	var emitted: Dictionary = CANONICAL_JSON.stringify(value)
	assert_true(emitted.get("ok", false), str(emitted))
	return str(emitted.get("value", ""))

func _isolated_wired() -> Dictionary:
	var created := TemporaryStorage.create("save_manager_consequence_checkpoint")
	assert_true(created.get("ok", false), str(created))
	if not created.get("ok", false):
		return {}
	var root: String = str(created["value"]).path_join("saves")
	var mkdir_error := DirAccess.make_dir_recursive_absolute(root)
	assert_eq(mkdir_error, OK)
	if mkdir_error != OK:
		return {}
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
func _pre_admission_state_candidate(transaction_id: String = "txn-1", admission_ready: bool = false) -> Dictionary:
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
	if admission_ready:
		# Reuse the production builder, as test_desktop_cold_recovery_preparation does,
		# so ordinal 1 carries its real payload shape and computed nested hashes.
		var builder: RefCounted = preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd").new()
		var frozen: Dictionary = builder._build_admission_ready_payload("minesweeper_round",
			action_receipt, {"result": "completed"}, {}, null, null, null, null, null, null,
			false, {}, {}, null, null)
		payload = frozen["recovery_payload"]
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


func _evict_issued_checkpoints(port: RefCounted) -> void:
	for index: int in 8:
		var transaction_id := "evict-txn-" + str(index)
		assert_true(port.prepare_consequence_checkpoint(_header(transaction_id),
			_admitted_state_candidate(transaction_id)).get("ok", false))


func test_prepare_consequence_checkpoint_builds_a_candidate_and_receipt() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var receipt: Dictionary = prepared["value"]["checkpoint_receipt"]
	assert_true(str(receipt["receipt_id"]).begins_with("consequence_checkpoint."))
	var expected_header := _header()
	expected_header["kind"] = String(expected_header["kind"])
	assert_eq(receipt["header"], expected_header)
	assert_eq(typeof(receipt["header"]["kind"]), TYPE_STRING)
	assert_eq(typeof(receipt["header"]["operation_ordinal"]), TYPE_INT,
		"canonical StringName normalization must not turn receipt ordinals into floats")
	var numeric_probe: Dictionary = port._normalize_json_string_types(
		{"integer": 7, "fraction": 1.25, "name": &"probe"})
	assert_eq(typeof(numeric_probe["integer"]), TYPE_INT)
	assert_eq(typeof(numeric_probe["fraction"]), TYPE_FLOAT)
	assert_eq(typeof(numeric_probe["name"]), TYPE_STRING)
	# Mutation-free: nothing is written to disk yet.
	assert_false(FileAccess.file_exists(str(wired["root"]).path_join("desktop-consequence-checkpoint.json")))


## dwm-p2r.35.3 remediation (finding A-C3, fix 2): the candidate prepare_consequence_checkpoint() builds
## carries the just-minted receipt attached to BOTH pending.checkpoint_receipt and
## pending.admission_checkpoint_receipt (this is the admission ordinal: both were null on the input),
## unlike the raw un-patched input -- the exact shape that makes the durable record loadable.
func test_prepare_consequence_checkpoint_attaches_the_receipt_to_the_admission_candidate() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
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
	assert_null(input_pending["checkpoint_receipt"], "attaching the receipt must not mutate caller state")
	assert_null(input_pending["admission_checkpoint_receipt"], "the caller still owns its receipt-free input")


func test_commit_consequence_checkpoint_retains_and_rereads_in_same_process() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate())
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed: Dictionary = port.commit_consequence_checkpoint(
		prepared["value"]["candidate"], prepared["value"]["checkpoint_receipt"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(committed["value"]["checkpoint_receipt"], prepared["value"]["checkpoint_receipt"])
	var read: Dictionary = port.read_pending_consequence_checkpoint()
	assert_true(read.get("ok", false), JSON.stringify(read))
	assert_true(read.value.found)
	assert_eq(_canonical_text(read.value.stage_candidate),
		_canonical_text(prepared.value.candidate.document.stage_candidate))
	assert_false(FileAccess.file_exists(str(wired["root"]).path_join("desktop-consequence-checkpoint.json")),
		"transient recovery never creates the legacy sidecar")

func test_issued_transient_record_cache_is_bounded_and_cleared_with_transient_state() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	for index: int in 10:
		var transaction_id := "cache-txn-" + str(index)
		var prepared: Dictionary = port.prepare_consequence_checkpoint(
			_header(transaction_id), _admitted_state_candidate(transaction_id))
		assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq((port.get("_issued_transient_records") as Dictionary).size(), 8)
	assert_eq((port.get("_issued_transient_order") as Array).size(), 8)
	port.clear_transient_consequence_checkpoints()
	assert_true((port.get("_issued_transient_records") as Dictionary).is_empty())
	assert_true((port.get("_issued_transient_order") as Array).is_empty())


func test_commit_consequence_checkpoint_rejects_a_receipt_mismatch() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
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


func test_known_issued_checkpoint_rejects_equal_float_payload_before_first_commit() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate())
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var changed: Dictionary = prepared.value.candidate.duplicate(true)
	# Native Dictionary equality rejects this type change; the cold fallback must also
	# refuse it after normalization instead of retaining it under the original receipt.
	changed.document.stage_candidate.pending.recovery_payload.participant_snapshot_ids.marker = 1.0
	var rejected: Dictionary = port.commit_consequence_checkpoint(changed, prepared.value.checkpoint_receipt)
	assert_false(rejected.get("ok", true), "equal numeric values do not authorize different canonical bytes")
	assert_eq(rejected.get("code"), &"invalid_candidate")
	assert_false(port.read_pending_consequence_checkpoint().value.found,
		"a changed issued record never enters an empty transient slot")
	assert_true(port.commit_consequence_checkpoint(prepared.value.candidate,
		prepared.value.checkpoint_receipt).get("ok", false), "the untouched prepared record remains usable")
	var retained: Dictionary = port.read_pending_consequence_checkpoint().value.stage_candidate
	assert_eq(typeof(retained.pending.recovery_payload.participant_snapshot_ids.marker), TYPE_INT)
	assert_true(CONSEQUENCE_STATE.validate(retained).get("ok", false),
		"the retained original still matches its payload hash")


func test_supplied_checkpoint_receipt_rejects_equal_float_ordinal() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate())
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var changed_receipt: Dictionary = prepared.value.checkpoint_receipt.duplicate(true)
	changed_receipt.header.operation_ordinal = 2.0
	var rejected: Dictionary = port.commit_consequence_checkpoint(prepared.value.candidate, changed_receipt)
	assert_false(rejected.get("ok", true))
	assert_eq(rejected.get("code"), &"checkpoint_receipt_mismatch")
	assert_false(port.read_pending_consequence_checkpoint().value.found,
		"a numeric receipt alias cannot commit the otherwise valid record")


func test_known_issued_checkpoint_accepts_string_name_aliases_after_normalization() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate())
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var aliased: Dictionary = prepared.value.candidate.duplicate(true)
	aliased.document.header.kind = &"consequence_admission"
	aliased.document.stage_candidate.pending.stage = &"sequence_committed"
	aliased.document.checkpoint_receipt.header.kind = &"consequence_admission"
	var aliased_receipt: Dictionary = prepared.value.checkpoint_receipt.duplicate(true)
	aliased_receipt.header.kind = &"consequence_admission"
	var committed: Dictionary = port.commit_consequence_checkpoint(aliased, aliased_receipt)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	var retained: Dictionary = port.read_pending_consequence_checkpoint().value.stage_candidate
	assert_eq(_canonical_text(retained), _canonical_text(prepared.value.candidate.document.stage_candidate))
	assert_eq(typeof(retained.pending.stage), TYPE_STRING)
	assert_eq(typeof(retained.pending.recovery_payload.participant_snapshot_ids.marker), TYPE_INT)
	assert_eq(typeof(aliased.document.stage_candidate.pending.stage), TYPE_STRING_NAME,
		"cold normalization does not mutate the caller's typed values")


func test_cache_evicted_prepared_checkpoint_still_commits_through_cold_validation() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate())
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	_evict_issued_checkpoints(port)
	assert_false((port.get("_issued_transient_records") as Dictionary).has(prepared.value.checkpoint_receipt.receipt_id),
		"the fixture reaches the legitimate cold path")
	var committed: Dictionary = port.commit_consequence_checkpoint(prepared.value.candidate,
		prepared.value.checkpoint_receipt)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	var retained: Dictionary = port.read_pending_consequence_checkpoint().value.stage_candidate
	assert_eq(_canonical_text(retained), _canonical_text(prepared.value.candidate.document.stage_candidate))
	assert_true(CONSEQUENCE_STATE.validate(retained).get("ok", false))


func test_evicted_checkpoints_accept_each_legitimate_recovery_stage() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	# Different payload content is valid when freshly prepared with its matching receipt;
	# cold validation proves self-consistency, not the historical origin of those bytes.
	var admission: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate("txn-1", 2))
	assert_true(admission.get("ok", false), JSON.stringify(admission))
	if not admission.get("ok", false):
		return
	var checkpoints: Array[Dictionary] = [admission]
	var state := CONSEQUENCE_STATE.new()
	var progress := {"publication_plan_sha256": "a".repeat(64), "callback_ids": ["causal_sequence", "action_source", "board_fate"],
		"next_callback_index": 0, "callback_receipts": {}}
	for cursor: int in 5:
		var mounted: Dictionary = state.prepare_restore(checkpoints.back().value.candidate.document.stage_candidate)
		assert_true(mounted.get("ok", false), JSON.stringify(mounted))
		if not mounted.get("ok", false):
			return
		assert_true(state.commit(mounted.value.candidate).get("ok", false))
		if cursor == 1:
			progress.next_callback_index = 1
			progress.callback_receipts = {"causal_sequence": {"receipt_id": "callback-1"}}
		elif cursor == 2:
			progress.next_callback_index = 2
			progress.callback_receipts.action_source = {"receipt_id": "callback-2"}
		elif cursor == 3:
			progress.next_callback_index = 3
			progress.callback_receipts.board_fate = {"receipt_id": "callback-3"}
		var advanced: Dictionary = state.prepare_recovery_advance("txn-1",
			&"sequence_committed" if cursor == 0 else &"publication_pending",
			null if cursor == 4 else &"publication_pending", {}, null, null,
			null if cursor == 4 else progress)
		assert_true(advanced.get("ok", false), JSON.stringify(advanced))
		if not advanced.get("ok", false):
			return
		advanced.value.checkpoint_header.run_id = "run-1"
		var prepared: Dictionary = port.prepare_consequence_checkpoint(
			advanced.value.checkpoint_header, advanced.value.stage_candidate)
		assert_true(prepared.get("ok", false), JSON.stringify(prepared))
		if not prepared.get("ok", false):
			return
		checkpoints.append(prepared)
	_evict_issued_checkpoints(port)
	var expected_ordinals := [2, 8, 9, 10, 11, 12]
	for index: int in checkpoints.size():
		var prepared: Dictionary = checkpoints[index]
		assert_eq(prepared.value.checkpoint_receipt.header.operation_ordinal, expected_ordinals[index])
		assert_false((port.get("_issued_transient_records") as Dictionary).has(prepared.value.checkpoint_receipt.receipt_id))
		var committed: Dictionary = port.commit_consequence_checkpoint(prepared.value.candidate,
			prepared.value.checkpoint_receipt)
		assert_true(committed.get("ok", false), "cold ordinal %d: %s" % [expected_ordinals[index], JSON.stringify(committed)])
		if not committed.get("ok", false):
			continue
		var retained: Dictionary = port.get("_transient_consequence_document").records[prepared.value.candidate.document.key]
		assert_eq(_canonical_text(retained), _canonical_text(prepared.value.candidate.document))
		assert_true(CONSEQUENCE_STATE.validate(retained.stage_candidate).get("ok", false))
		assert_eq(port.read_pending_consequence_checkpoint().value.found, expected_ordinals[index] != 12,
			"terminal cleanup retires the same transaction only after its exact cold record commits")


func test_evicted_checkpoint_rejects_inconsistent_fields_before_insertion() -> void:
	for fault: String in ["payload_numeric_type", "payload_value", "header_receipt", "receipt_digest",
			"receipt_content_hash", "ordinal_stage"]:
		var wired := _isolated_wired()
		if wired.is_empty():
			return
		var port: RefCounted = wired["port"]
		var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate())
		assert_true(prepared.get("ok", false), JSON.stringify(prepared))
		if not prepared.get("ok", false):
			continue
		_evict_issued_checkpoints(port)
		assert_false((port.get("_issued_transient_records") as Dictionary).has(prepared.value.checkpoint_receipt.receipt_id))
		var candidate: Dictionary = prepared.value.candidate.duplicate(true)
		var record: Dictionary = candidate.document
		match fault:
			"payload_numeric_type":
				record.stage_candidate.pending.recovery_payload.participant_snapshot_ids.marker = 1.0
			"payload_value":
				record.stage_candidate.pending.recovery_payload.participant_snapshot_ids.marker = 2
			"header_receipt":
				record.header.run_id = "different-run"
			"receipt_digest":
				record.checkpoint_receipt.content_sha256 = "0".repeat(64)
			"receipt_content_hash":
				record.checkpoint_receipt.content_sha256 = "0".repeat(64)
				record.checkpoint_receipt.receipt_id = "consequence_checkpoint." + "0".repeat(64)
				record.stage_candidate.pending.checkpoint_receipt = record.checkpoint_receipt.duplicate(true)
				record.stage_candidate.pending.admission_checkpoint_receipt = record.checkpoint_receipt.duplicate(true)
			"ordinal_stage":
				record.header.operation_ordinal = 9
				record.key = _record_key("txn-1", 9)
				record.checkpoint_receipt.header = record.header.duplicate(true)
				record.stage_candidate.pending.checkpoint_receipt = record.checkpoint_receipt.duplicate(true)
				record.stage_candidate.pending.admission_checkpoint_receipt = record.checkpoint_receipt.duplicate(true)
		# Pass the candidate's own receipt: each case must reach cold validation rather
		# than failing the already-covered supplied-receipt argument mismatch guard.
		var rejected: Dictionary = port.commit_consequence_checkpoint(candidate, record.checkpoint_receipt)
		assert_false(rejected.get("ok", true), fault)
		assert_eq(rejected.get("code"), &"invalid_candidate", fault)
		assert_true((port.get("_transient_consequence_document").records as Dictionary).is_empty(),
			fault + " must be refused before insertion")
		assert_true(port.commit_consequence_checkpoint(prepared.value.candidate,
			prepared.value.checkpoint_receipt).get("ok", false), "refused mutations do not poison the valid cold record")


func test_evicted_reprepared_admission_preserves_its_older_admission_receipt() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var admission: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate())
	assert_true(admission.get("ok", false), JSON.stringify(admission))
	if not admission.get("ok", false):
		return
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(),
		admission.value.candidate.document.stage_candidate)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return
	assert_ne(_canonical_text(prepared.value.checkpoint_receipt), _canonical_text(admission.value.checkpoint_receipt),
		"re-preparation binds the existing admission receipt into a new checkpoint")
	_evict_issued_checkpoints(port)
	assert_false((port.get("_issued_transient_records") as Dictionary).has(prepared.value.checkpoint_receipt.receipt_id))
	var committed: Dictionary = port.commit_consequence_checkpoint(prepared.value.candidate,
		prepared.value.checkpoint_receipt)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	if not committed.get("ok", false):
		return
	var retained: Dictionary = port.read_pending_consequence_checkpoint().value.stage_candidate
	assert_eq(_canonical_text(retained.pending.admission_checkpoint_receipt), _canonical_text(admission.value.checkpoint_receipt))
	assert_eq(_canonical_text(retained.pending.checkpoint_receipt), _canonical_text(prepared.value.checkpoint_receipt))
	assert_true(CONSEQUENCE_STATE.validate(retained).get("ok", false))


func test_evicted_preadmission_checkpoints_preserve_receipt_free_state() -> void:
	# Both pre-admission stages remain receipt-free; ordinal 1 already freezes the
	# coordinator's admission-ready payload before its sequence reservation is adopted.
	for ordinal: int in [0, 1]:
		var wired := _isolated_wired()
		if wired.is_empty():
			return
		var port: RefCounted = wired["port"]
		var header := _pre_admission_header()
		header.operation_ordinal = ordinal
		if ordinal == 1:
			header.kind = &"consequence_admission_ready"
		var prepared: Dictionary = port.prepare_consequence_checkpoint(header,
			_pre_admission_state_candidate("txn-1", ordinal == 1))
		assert_true(prepared.get("ok", false), JSON.stringify(prepared))
		if not prepared.get("ok", false):
			continue
		_evict_issued_checkpoints(port)
		assert_false((port.get("_issued_transient_records") as Dictionary).has(prepared.value.checkpoint_receipt.receipt_id))
		var committed: Dictionary = port.commit_consequence_checkpoint(prepared.value.candidate,
			prepared.value.checkpoint_receipt)
		assert_true(committed.get("ok", false), JSON.stringify(committed))
		if not committed.get("ok", false):
			continue
		var retained: Dictionary = port.read_pending_consequence_checkpoint().value.stage_candidate
		assert_null(retained.pending.checkpoint_receipt)
		assert_null(retained.pending.admission_checkpoint_receipt)
		assert_eq(_canonical_text(retained), _canonical_text(prepared.value.candidate.document.stage_candidate))
		assert_true(CONSEQUENCE_STATE.validate(retained).get("ok", false))
		if ordinal == 1:
			var payload: Dictionary = retained.pending.recovery_payload
			assert_eq(payload.payload_phase, "admission_ready")
			assert_eq(payload.publication_plan_sha256, _canonical_text(payload.publication_plan).sha256_text())


## dwm-p2r.35.3 remediation (finding A-C3): real occupied-slot conflict law. An identical-bytes rewrite
## at an occupied (transaction_id, operation_ordinal) slot replays as success with no duplicate
## record; a changed-bytes rewrite at the same slot returns the frozen consequence_checkpoint_conflict
## and leaves the durable record untouched.
func test_commit_consequence_checkpoint_rejects_malformed_or_uncanonicalizable_records() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate())
	var missing_header: Dictionary = prepared.value.candidate.duplicate(true)
	missing_header.document = (missing_header.document as Dictionary).duplicate(true)
	missing_header.document.erase("header")
	var rejected_shape: Dictionary = port.commit_consequence_checkpoint(
		missing_header, prepared.value.checkpoint_receipt)
	assert_false(rejected_shape.get("ok", true))
	assert_eq(rejected_shape.get("code"), &"invalid_candidate")
	var unsupported: Dictionary = prepared.value.candidate.duplicate(true)
	unsupported.document = (unsupported.document as Dictionary).duplicate(true)
	unsupported.document["unexpected"] = Vector2(1.0, 2.0)
	var rejected_variant: Dictionary = port.commit_consequence_checkpoint(
		unsupported, prepared.value.checkpoint_receipt)
	assert_false(rejected_variant.get("ok", true))
	assert_eq(rejected_variant.get("code"), &"invalid_candidate")
	assert_true((port.get("_transient_consequence_document").records as Dictionary).is_empty(),
		"invalid records never enter transient retry state")

func test_commit_consequence_checkpoint_replays_an_identical_rewrite_at_an_occupied_slot() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	var first_commit: Dictionary = port.commit_consequence_checkpoint(
		prepared.value.candidate, prepared.value.checkpoint_receipt)
	assert_true(first_commit.get("ok", false), JSON.stringify(first_commit))
	var prepared_again: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	var replayed: Dictionary = port.commit_consequence_checkpoint(
		prepared_again.value.candidate, prepared_again.value.checkpoint_receipt)
	assert_true(replayed.get("ok", false), JSON.stringify(replayed))
	assert_eq(replayed.value.checkpoint_receipt, first_commit.value.checkpoint_receipt)
	assert_eq((port.get("_transient_consequence_document").records as Dictionary).size(), 1,
		"an identical same-process retry never grows a duplicate record")

func test_commit_consequence_checkpoint_rejects_a_different_rewrite_at_an_occupied_slot() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var first: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate("txn-1", 1))
	assert_true(port.commit_consequence_checkpoint(first.value.candidate,
		first.value.checkpoint_receipt).get("ok", false))
	var conflicting: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate("txn-1", 2))
	_evict_issued_checkpoints(port)
	assert_false((port.get("_issued_transient_records") as Dictionary).has(conflicting.value.checkpoint_receipt.receipt_id))
	var rejected: Dictionary = port.commit_consequence_checkpoint(
		conflicting.value.candidate, conflicting.value.checkpoint_receipt)
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"consequence_checkpoint_conflict")
	var retained: Dictionary = port.get("_transient_consequence_document").records[_record_key()]
	assert_eq(_canonical_text(retained.checkpoint_receipt), _canonical_text(first.value.checkpoint_receipt),
		"a conflict leaves the original same-process record untouched")

## Acceptance: a durable admission checkpoint written at ordinal 2 can be read back and passes
## DesktopConsequenceState.validate() -- proving the stored shape is genuinely loadable, not merely
## byte-written.
func test_a_committed_admission_checkpoint_reads_back_and_validates() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
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
	if wired.is_empty():
		return
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

	assert_eq((port.get("_transient_consequence_document").records as Dictionary).size(), 1,
		"abandonment never creates or promotes a checkpoint")
	assert_false(FileAccess.file_exists(str(wired.root).path_join("desktop-consequence-checkpoint.json")))


func test_abandon_pending_consequence_checkpoint_rejects_a_nonexistent_transaction() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var rejected: Dictionary = port.abandon_pending_consequence_checkpoint("no-such-txn")
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"consequence_checkpoint_not_found")


## Abandonment is legal only pre-admission -- an already-admitted (sequence_committed) checkpoint may
## never be abandoned; forward recovery, not abandonment, is the only legal path from there.
func test_abandon_pending_consequence_checkpoint_rejects_an_already_admitted_transaction() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
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
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var read: Dictionary = port.read_pending_consequence_checkpoint()
	assert_true(read.get("ok", false), JSON.stringify(read))
	assert_false(bool(read["value"]["found"]))


func test_clear_transient_consequence_checkpoints_is_explicit_and_complete() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired.port
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), _admitted_state_candidate())
	assert_true(port.commit_consequence_checkpoint(prepared.value.candidate,
		prepared.value.checkpoint_receipt).get("ok", false))
	var cleared: Dictionary = port.clear_transient_consequence_checkpoints()
	assert_true(cleared.get("ok", false), JSON.stringify(cleared))
	assert_eq(cleared.value.records_cleared, 1)
	assert_eq(cleared.value.abandoned_cleared, 0)
	assert_false(port.read_pending_consequence_checkpoint().value.found)
	var repeated: Dictionary = port.clear_transient_consequence_checkpoints()
	assert_eq(repeated.value.records_cleared, 0, "the explicit clear is idempotent")


func test_clear_transient_consequence_checkpoints_does_not_depend_on_storage_readiness() -> void:
	var port: RefCounted = load(CHECKPOINT_PORT_PATH).new()
	port.set("_transient_consequence_document", {
		"records": {"stale:0": {}}, "abandoned": {"stale": true}})
	var cleared: Dictionary = port.clear_transient_consequence_checkpoints()
	assert_true(cleared.get("ok", false), JSON.stringify(cleared))
	assert_eq(cleared.value.records_cleared, 1)
	assert_eq(cleared.value.abandoned_cleared, 1)
	assert_true((port.get("_transient_consequence_document").records as Dictionary).is_empty())
	assert_true((port.get("_transient_consequence_document").abandoned as Dictionary).is_empty())


func test_fresh_port_ignores_and_preserves_every_legacy_sidecar_artifact() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var base := str(wired.root).path_join("desktop-consequence-checkpoint.json")
	var artifacts := {
		base: "malformed final bytes",
		base + ".bak": "{\"old\":\"backup\"}",
		base + ".next": "[\"unfinished\"]",
		base + ".txn.json": "corrupt transaction marker",
	}
	for path: String in artifacts:
		var file := FileAccess.open(path, FileAccess.WRITE)
		assert_not_null(file)
		file.store_string(artifacts[path])
		file.close()
	var fresh_port: RefCounted = load(CHECKPOINT_PORT_PATH).new(wired.manager)
	assert_true(fresh_port.configure_fatal_latch(load(GATE_PATH).new()).get("ok", false))
	var read: Dictionary = fresh_port.read_pending_consequence_checkpoint()
	assert_true(read.get("ok", false), JSON.stringify(read))
	assert_false(read.value.found, "a fresh process never resumes an unfinished legacy sidecar")
	for path: String in artifacts:
		assert_eq(FileAccess.get_file_as_string(path), artifacts[path],
			"legacy recovery evidence is preserved byte-for-byte: " + path)


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
	if wired.is_empty():
		return
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
	if wired.is_empty():
		return
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
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]
	var candidate_state := _admitted_state_candidate()
	var bad_header := _header("txn-1", 9, "action_prepared")
	var rejected: Dictionary = port.prepare_consequence_checkpoint(bad_header, candidate_state)
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"consequence_checkpoint_ordinal_stage_invalid")
	assert_false(FileAccess.file_exists(str(wired["root"]).path_join("desktop-consequence-checkpoint.json")))


func _completion_snapshot() -> Dictionary:
	var raw: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(
		FileAccess.get_file_as_string("res://tests/fixtures/saves/v6_desktop_prepared.json"))["value"]
	return preload("res://scripts/domain/run/RunSnapshotSchema.gd").validate(raw)["value"]["candidate"]


func _checkpoint_inputs(snapshot: Dictionary) -> Dictionary:
	var snapshot_input := {}
	for key: String in ["lifecycle", "gameplay", "contacts", "committed_schedule", "dating",
			"applied_effect_transaction_ids", "applied_variable_transaction_ids", "desktop", "schedule_view",
			"command_receipts"]:
		snapshot_input[key] = snapshot[key]
	return {"snapshot_input": snapshot_input, "dialogic_checkpoint": {}, "route_id": "main",
		"active_app_id": snapshot["active_app_id"], "audio_context": snapshot["audio_context"],
		"content_version": snapshot["content_version"]}


func _write_pending_for_snapshot(port: RefCounted, snapshot: Dictionary) -> void:
	var state := _admitted_state_candidate("completed-round")
	state["causal_day_instance"] = snapshot["lifecycle"]["causal_day_instance"]
	state["causal_day_instance_issuer_receipt"] = snapshot["lifecycle"]["causal_day_instance_issuer_receipt"]
	state["pending"]["recovery_payload"]["action_receipt"] = snapshot["lifecycle"].duplicate(true)
	var canonical: Dictionary = preload("res://scripts/validation/CanonicalJsonWriter.gd").stringify(
		state["pending"]["recovery_payload"])
	state["pending"]["recovery_payload_sha256"] = str(canonical["value"]).sha256_text()
	var header := _header("completed-round")
	header["run_id"] = snapshot["run_id"]
	var prepared: Dictionary = port.prepare_consequence_checkpoint(header, state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if prepared.get("ok", false):
		assert_true(port.commit_consequence_checkpoint(prepared["value"]["candidate"],
			prepared["value"]["checkpoint_receipt"]).get("ok", false))


func _write_full_result(wired: Dictionary, snapshot: Dictionary) -> void:
	assert_true(wired["manager"]._journal.reset(snapshot["run_id"]).get("ok", false))
	var lease: Dictionary = wired["gate"].acquire(&"causal_transaction")
	assert_true(lease.get("ok", false))
	var prepared: Dictionary = wired["port"].prepare(_checkpoint_inputs(snapshot), &"post_result",
		{"kind": &"autosave", "reason": &"automatic"})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if prepared.get("ok", false):
		assert_true(wired["port"].commit(prepared["value"]["candidate"]).get("ok", false))
	assert_true(wired["gate"].release(&"causal_transaction", lease["value"]["token"]).get("ok", false))


func test_restart_drops_unfinished_action_but_preserves_completed_post_result_autosave() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var snapshot := _completion_snapshot()
	_write_pending_for_snapshot(wired.port, snapshot)
	assert_true(wired.port.read_pending_consequence_checkpoint().value.found)

	# A new process has no transient recovery state, so an interrupted action replays from the
	# previous Autosave instead of adopting an intermediate consequence stage.
	var fresh_before_save: RefCounted = load(CHECKPOINT_PORT_PATH).new(wired.manager)
	assert_true(fresh_before_save.configure_fatal_latch(load(GATE_PATH).new()).get("ok", false))
	assert_false(fresh_before_save.read_pending_consequence_checkpoint().value.found)

	# Once the completed result is fully saved, ordinary restart retains its gameplay result while
	# still carrying no intermediate consequence transaction.
	snapshot["desktop"]["consequence"]["causal_sequence"] = 1
	snapshot["desktop"]["consequence"]["run_revision"] = 1
	snapshot["desktop"]["consequence"]["pending"] = null
	snapshot["gameplay"]["money"] = 777
	snapshot["gameplay"]["minesweeper_app_rounds_finished_today"] = 1
	_write_full_result(wired, snapshot)
	var fresh_manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(fresh_manager)
	assert_true(fresh_manager.initialize(load(STORAGE_PATH).new(wired.root)).get("ok", false))
	var fresh_after_save: RefCounted = load(CHECKPOINT_PORT_PATH).new(fresh_manager)
	assert_true(fresh_after_save.configure_fatal_latch(load(GATE_PATH).new()).get("ok", false))
	assert_false(fresh_after_save.read_pending_consequence_checkpoint().value.found)
	var document: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(
		FileAccess.get_file_as_string(str(wired.root).path_join("autosave.json")))["value"]
	assert_eq(document.current_snapshot.checkpoint_kind, "post_result")
	assert_eq(document.current_snapshot.snapshot.gameplay.money, 777)
	assert_eq(document.current_snapshot.snapshot.gameplay.minesweeper_app_rounds_finished_today, 1)
	assert_null(document.current_snapshot.snapshot.desktop.consequence.pending)


## --- Autosave splice law (perf/terminal-settlement-3) -------------------------------------------
## The port may stringify only the NEW current bundle plus a tiny envelope and splice in the
## journal-remembered canonical text of the earlier bundles, but the bytes on disk must equal what
## one whole-document CanonicalJsonWriter.stringify(document) + "\n" produces. These tests pin that
## law on real SaveManager + JsonFileStorage + CheckpointJournal wiring.

const DOCUMENT_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
## The exact sentinel strings the port substitutes for the spliced bundles. Their canonical
## emission is "\u0001dwm-splice-current\u0001" / "\u0001dwm-splice-journal-<i>\u0001" with the
## control character escaped, so a snapshot string equal to a sentinel emits the same token.
const SPLICE_SENTINELS := ["\u0001dwm-splice-current\u0001", "\u0001dwm-splice-journal-0\u0001",
	"\u0001dwm-splice-journal-1\u0001"]


## Reports the first differing offset instead of dumping two ~450 KB documents into the log.
func _assert_same_bytes(actual: PackedByteArray, expected: PackedByteArray, label: String) -> void:
	if actual == expected:
		assert_true(true, label)
		return
	var first_difference := mini(actual.size(), expected.size())
	for index: int in range(mini(actual.size(), expected.size())):
		if actual[index] != expected[index]:
			first_difference = index
			break
	var window_start := maxi(0, first_difference - 40)
	assert_true(false, "%s: actual %d bytes vs expected %d bytes, first difference at byte %d; actual[%d..]=%s expected[%d..]=%s" % [
		label, actual.size(), expected.size(), first_difference, window_start,
		actual.slice(window_start, mini(actual.size(), first_difference + 40)).get_string_from_utf8().json_escape(),
		window_start,
		expected.slice(window_start, mini(expected.size(), first_difference + 40)).get_string_from_utf8().json_escape()])


## Drives ONE post_result autosave commit of `snapshot` through the real port (money varied so
## consecutive bundles differ) and returns the prepared candidate; its autosave_document is the very
## Dictionary the port serialised.
func _commit_autosave(wired: Dictionary, snapshot: Dictionary, money: int, dialogic: Dictionary = {}) -> Dictionary:
	var edited := snapshot.duplicate(true)
	edited["gameplay"]["money"] = money
	var inputs := _checkpoint_inputs(edited)
	inputs["dialogic_checkpoint"] = dialogic
	var lease: Dictionary = wired["gate"].acquire(&"causal_transaction")
	assert_true(lease.get("ok", false), JSON.stringify(lease))
	var prepared: Dictionary = wired["port"].prepare(inputs, &"post_result",
		{"kind": &"autosave", "reason": &"automatic"})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var candidate: Dictionary = prepared["value"]["candidate"] if prepared.get("ok", false) else {}
	if not candidate.is_empty():
		var committed: Dictionary = wired["port"].commit(candidate)
		assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_true(wired["gate"].release(&"causal_transaction", lease["value"]["token"]).get("ok", false))
	return candidate


func _written_autosave(wired: Dictionary) -> PackedByteArray:
	return FileAccess.get_file_as_bytes(str(wired["root"]).path_join("autosave.json"))


func _assert_autosave_matches_full_writer(wired: Dictionary, candidate: Dictionary, label: String) -> void:
	var expected := _canonical_text(candidate["autosave_document"]) + "\n"
	_assert_same_bytes(_written_autosave(wired), expected.to_utf8_buffer(), label)


func test_autosave_bytes_equal_the_full_canonical_writer_across_three_commits() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var snapshot := _completion_snapshot()
	assert_true(wired["manager"]._journal.reset(str(snapshot["run_id"])).get("ok", false))
	var first := _commit_autosave(wired, snapshot, 101)
	_assert_autosave_matches_full_writer(wired, first, "first autosave")
	var second := _commit_autosave(wired, snapshot, 202)
	_assert_autosave_matches_full_writer(wired, second, "second autosave")
	var third := _commit_autosave(wired, snapshot, 303)
	var document: Dictionary = third["autosave_document"]
	assert_eq((document["recovery_journal"] as Array).size(), 2, "the third autosave carries two earlier bundles")
	# The law: bytes on disk == the whole-document writer over the same inputs the port used.
	var journal_candidate: Dictionary = third["journal_candidate"]
	var rebuilt: Dictionary = DOCUMENT_SCHEMA.build(&"autosave", null, &"automatic",
		journal_candidate["current"], journal_candidate["earlier"])
	assert_true(rebuilt.get("ok", false), JSON.stringify(rebuilt))
	var expected := _canonical_text(rebuilt["value"]) + "\n"
	var written := _written_autosave(wired)
	_assert_same_bytes(written, expected.to_utf8_buffer(), "third autosave vs SaveDocumentSchema.build + full writer")
	_assert_autosave_matches_full_writer(wired, third, "third autosave vs candidate document")
	# Reuse premise on real data: the journal's private duplicates of commits 1 and 2 stringify to
	# exactly the current_snapshot text regions those commits wrote, and the third document is the
	# envelope composed around them.
	var first_current := _canonical_text((first["autosave_document"] as Dictionary)["current_snapshot"])
	var second_current := _canonical_text((second["autosave_document"] as Dictionary)["current_snapshot"])
	var third_current := _canonical_text(document["current_snapshot"])
	assert_ne(first_current, second_current, "consecutive bundles differ, so reuse is observable")
	assert_true(_canonical_text((document["recovery_journal"] as Array)[0]) == first_current,
		"recovery_journal[0] text equals the first commit's current_snapshot text")
	assert_true(_canonical_text((document["recovery_journal"] as Array)[1]) == second_current,
		"recovery_journal[1] text equals the second commit's current_snapshot text")
	var composed := "{\"current_snapshot\":" + third_current + ",\"kind\":\"autosave\",\"recovery_journal\":[" \
		+ first_current + "," + second_current + "],\"save_reason\":\"automatic\",\"schema_version\":6,\"slot_id\":null}\n"
	_assert_same_bytes(written, composed.to_utf8_buffer(), "third autosave equals the envelope composed around the reused regions")
	var text := written.get_string_from_utf8()
	assert_eq(text.count(first_current), 1, "the first bundle's text appears exactly once in the third document")


## A snapshot whose strings equal the splice sentinels (so every sentinel token appears verbatim
## inside the reused bundle texts) must still produce bytes equal to the full writer.
func test_autosave_bytes_survive_snapshot_strings_equal_to_splice_sentinels() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var snapshot := _completion_snapshot()
	assert_true(wired["manager"]._journal.reset(str(snapshot["run_id"])).get("ok", false))
	var poisoned := {"sentinels": SPLICE_SENTINELS.duplicate(), "nested": {"current": SPLICE_SENTINELS[0]}}
	var first := _commit_autosave(wired, snapshot, 11, poisoned)
	var first_text := _canonical_text((first["autosave_document"] as Dictionary)["current_snapshot"])
	for sentinel: String in SPLICE_SENTINELS:
		var token := _canonical_text(sentinel)
		assert_eq(token, "\"\\u0001" + sentinel.substr(1, sentinel.length() - 2) + "\\u0001\"",
			"the writer escapes the sentinel's control characters")
		assert_gt(first_text.count(token), 0, "the poisoned bundle carries the emitted token " + token)
	_assert_autosave_matches_full_writer(wired, first, "poisoned first autosave")
	var second := _commit_autosave(wired, snapshot, 22, poisoned)
	_assert_autosave_matches_full_writer(wired, second, "poisoned second autosave (journal-0 text contains every token)")
	var third := _commit_autosave(wired, snapshot, 33, poisoned)
	assert_eq(((third["autosave_document"] as Dictionary)["recovery_journal"] as Array).size(), 2)
	_assert_autosave_matches_full_writer(wired, third, "poisoned third autosave (both journal texts contain every token)")


## A journal seeded from disk holds bundles whose canonical text nobody remembered; the port must
## still write bytes equal to the full writer. One earlier bundle carries a non-integral float so the
## whole document is ineligible for the writer's native encoder while the new current bundle is not.
func test_seeded_journal_without_remembered_texts_writes_full_writer_bytes() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var snapshot := _completion_snapshot()
	var bundles: Array = []
	for sequence: int in [1, 2, 3]:
		var copy := snapshot.duplicate(true)
		copy["checkpoint_sequence"] = sequence
		copy["checkpoint_id"] = "%s:%d" % [str(snapshot["run_id"]), sequence]
		copy["gameplay"]["money"] = sequence * 100
		if sequence == 2:
			copy["narrative_checkpoint"] = {"probe": 0.1}
		bundles.append({"checkpoint_kind": "post_result", "snapshot": copy})
	var seed_document: Dictionary = DOCUMENT_SCHEMA.build(&"autosave", null, &"automatic",
		bundles[2], [bundles[0], bundles[1]])
	assert_true(seed_document.get("ok", false), JSON.stringify(seed_document))
	var journal: RefCounted = wired["manager"]._journal
	var seeded: Dictionary = journal.prepare_seed(seed_document["value"], bundles[2])
	assert_true(seeded.get("ok", false), JSON.stringify(seeded))
	assert_true(journal.commit_prepared(seeded["value"]["candidate"]).get("ok", false))
	assert_eq((journal.get_bundles_for_disk() as Array).size(), 2, "the seed retained both earlier bundles")
	assert_eq(journal.get_retained_bundle_text(str(snapshot["run_id"]) + ":2"), "",
		"a cold seed starts without any byte proof")
	var candidate := _commit_autosave(wired, snapshot, 444)
	var document: Dictionary = candidate["autosave_document"]
	assert_eq((document["recovery_journal"] as Array).size(), 2)
	assert_eq(str((document["recovery_journal"] as Array)[0]["snapshot"]["checkpoint_id"]), str(snapshot["run_id"]) + ":2")
	assert_eq(str((document["recovery_journal"] as Array)[1]["snapshot"]["checkpoint_id"]), str(snapshot["run_id"]) + ":3")
	assert_true(CANONICAL_JSON._can_use_native_encoder(document["current_snapshot"]),
		"the new current bundle is native-eligible")
	assert_false(CANONICAL_JSON._can_use_native_encoder(document),
		"the whole document is not native-eligible (float in an earlier bundle)")
	_assert_autosave_matches_full_writer(wired, candidate, "autosave after a seeded journal")
	for bundle: Dictionary in document["recovery_journal"]:
		var checkpoint_id := str(bundle.snapshot.checkpoint_id)
		assert_eq(journal.get_retained_bundle_text(checkpoint_id), _canonical_text(bundle),
			"the full durable write proves the cold retained bundle: " + checkpoint_id)
	var warm := _commit_autosave(wired, snapshot, 555)
	_assert_autosave_matches_full_writer(wired, warm, "autosave after cold history was durably proven")


## The mixed encoding case on the SPLICE side: commit 1 carries a non-integral float (through
## dialogic_checkpoint, which RunSnapshotSchema records as narrative_checkpoint), so from commit 2
## on the whole document is ineligible for the writer's native encoder while each new current bundle
## is eligible. Both earlier bundles still hold a remembered text, so the bytes were composed by the
## splice -- not by the fallback the seeded test pins -- and must still equal the full writer.
func test_autosave_bytes_equal_the_full_writer_when_an_earlier_bundle_is_not_native_eligible() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var snapshot := _completion_snapshot()
	assert_true(wired["manager"]._journal.reset(str(snapshot["run_id"])).get("ok", false))
	var first := _commit_autosave(wired, snapshot, 111, {"probe": 0.1})
	_assert_autosave_matches_full_writer(wired, first, "first autosave carries the non-integral float")
	var second := _commit_autosave(wired, snapshot, 222)
	_assert_autosave_matches_full_writer(wired, second, "second autosave splices the float-carrying bundle")
	var third := _commit_autosave(wired, snapshot, 333)
	var document: Dictionary = third["autosave_document"]
	var earlier: Array = document["recovery_journal"]
	assert_eq(earlier.size(), 2, "the third autosave carries two earlier bundles")
	var journal: RefCounted = wired["manager"]._journal
	for bundle: Dictionary in earlier:
		var checkpoint_id := str((bundle["snapshot"] as Dictionary)["checkpoint_id"])
		assert_ne(journal.get_retained_bundle_text(checkpoint_id), "",
			"the splice path, not the fallback, composed these bytes: " + checkpoint_id + " is remembered")
	assert_true(CANONICAL_JSON._can_use_native_encoder(document["current_snapshot"]),
		"the new current bundle is native-eligible")
	assert_false(CANONICAL_JSON._can_use_native_encoder(document),
		"the whole document is not native-eligible (float in an earlier bundle)")
	_assert_autosave_matches_full_writer(wired, third, "third autosave vs the whole-document writer")


# -------------------------------------------------------------------------------------------------
# settlement4 Step 2: the prepare side. SaveDocumentSchema.build re-validates and re-normalizes the
# two retained journal bundles on every autosave (25-62 ms of each 35-76 ms prepare) although each
# was proven at its own commit, so the journal now remembers the document bundle beside the proven
# text and prepare hands those back as build()'s per-entry proofs. The bytes are unchanged -- the
# three byte-equality rows above are that proof -- so what is pinned here is the wiring and the one
# hazard it adds: a remembered document bundle that does not describe the bundle the journal kept.
# -------------------------------------------------------------------------------------------------

func test_committed_autosave_remembers_the_document_bundle_under_the_texts_own_gate() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var snapshot := _completion_snapshot()
	assert_true(wired["manager"]._journal.reset(str(snapshot["run_id"])).get("ok", false))
	var journal: RefCounted = wired["manager"]._journal
	# Asserted before the reads below: a nonexistent call aborts the test function outright, which
	# GUT records as risky rather than failed.
	assert_true(journal.has_method("get_retained_bundle_document"),
		"the journal must serve back the document bundle a commit remembered")
	if not journal.has_method("get_retained_bundle_document"):
		return

	var first := _commit_autosave(wired, snapshot, 101)
	var first_id := str(first["checkpoint_id"])
	var written_bundle: Dictionary = (first["autosave_document"] as Dictionary)["current_snapshot"]
	var remembered: Dictionary = journal.get_retained_bundle_document(first_id)
	assert_false(remembered.is_empty(), "a committed autosave remembers its document bundle")
	assert_eq(_canonical_text(remembered), _canonical_text(written_bundle),
		"the remembered document bundle emits the bytes this commit wrote for that bundle")
	assert_true(CANONICAL_JSON._deep_same(remembered, written_bundle),
		"...and deep-equals the document's own current bundle")
	assert_false(journal.get_retained_bundle_text(first_id).is_empty(),
		"the proven text is remembered beside it")

	# The gate: the caller edits the outgoing current bundle in place between prepare and commit.
	# Those bytes are written and accepted -- that is the law -- while the journal retains the
	# UNEDITED bundle under the same id, so neither proof may be remembered for it.
	var edited := snapshot.duplicate(true)
	edited["gameplay"]["money"] = 202
	var lease: Dictionary = wired["gate"].acquire(&"causal_transaction")
	assert_true(lease.get("ok", false), JSON.stringify(lease))
	var prepared: Dictionary = wired["port"].prepare(_checkpoint_inputs(edited), &"post_result",
		{"kind": &"autosave", "reason": &"automatic"})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var candidate: Dictionary = prepared["value"]["candidate"]
	var second_id := str(candidate["checkpoint_id"])
	var outgoing_bundle: Dictionary = (candidate["autosave_document"] as Dictionary)["current_snapshot"]
	((outgoing_bundle["snapshot"] as Dictionary)["gameplay"] as Dictionary)["money"] = 999
	assert_true(wired["port"].commit(candidate).get("ok", false))
	assert_true(wired["gate"].release(&"causal_transaction", lease["value"]["token"]).get("ok", false))
	var written_text := FileAccess.get_file_as_string(str(wired["root"]).path_join("autosave.json"))
	var reparsed: Dictionary = preload("res://scripts/validation/StrictJson.gd").parse_object(
		written_text)["value"]
	var written_gameplay: Dictionary = ((reparsed["current_snapshot"] as Dictionary)["snapshot"] as Dictionary)["gameplay"]
	assert_eq(int(written_gameplay["money"]), 999, "the edited bundle is what was written, as today")
	assert_eq(journal.get_retained_bundle_text(second_id), "",
		"a text that does not describe the retained bundle is not remembered")
	assert_true(journal.get_retained_bundle_document(second_id).is_empty(),
		"neither is the document bundle: the next save would compose this entry from a bundle these bytes do not describe")


## The wiring produces byte-identical output, so the source is the observable, in the idiom of the
## profile-record pin below: prepare must compose the journal entries from the journal's own proofs.
func test_prepare_composes_the_autosave_journal_from_the_journals_own_proofs() -> void:
	var source := FileAccess.get_file_as_string(CHECKPOINT_PORT_PATH)
	assert_false(source.is_empty(), "the port source must be readable")
	assert_true(source.contains("_journal().get_retained_bundle_document("),
		"prepare() asks the journal for each retained bundle's proven document bundle")
	assert_true(source.contains("{}, proven_journal)"),
		"...and hands them to SaveDocumentSchema.build() as its trailing proven journal")


# -------------------------------------------------------------------------------------------------
# Identity-preserving `_normalize_json_string_types` (click-latency Step 2). The normalizer allocates
# a fresh Dictionary/Array for every node of every preimage even though the recovery_payload subtree
# contains no StringName at all. Returning the ORIGINAL container when no descendant was converted
# must change nothing a caller can observe: the result stays deep-equal (int and float provenance
# included) to its input with every StringName turned into a String, the record the port stores must
# still be fully detached from the caller's stage_candidate, and the port's own receipt attachment
# must still be confined to the private tree `_validate_for_preimage()` already detached.
# -------------------------------------------------------------------------------------------------

## Independent, always-copying StringName -> String conversion. The row below compares the port's
## normalization against THIS, so an identity-preserving implementation cannot supply its own oracle.
func _as_json_string_types(value: Variant) -> Variant:
	match typeof(value):
		TYPE_STRING_NAME:
			return String(value)
		TYPE_ARRAY:
			var converted_array: Array = []
			for item: Variant in value as Array:
				converted_array.append(_as_json_string_types(item))
			return converted_array
		TYPE_DICTIONARY:
			var converted_dictionary: Dictionary = {}
			for raw_key: Variant in value as Dictionary:
				var key: Variant = String(raw_key) if typeof(raw_key) == TYPE_STRING_NAME else raw_key
				converted_dictionary[key] = _as_json_string_types((value as Dictionary)[raw_key])
			return converted_dictionary
		_:
			return value


func test_normalized_preimage_is_deep_equal_and_never_aliases_the_callers_stage_candidate() -> void:
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var port: RefCounted = wired["port"]

	# 1. Identity preservation, observed directly on the normalizer.
	var no_names := {"integer": 7, "fraction": 1.25, "text": "plain", "list": [1, 2.5, "x"],
		"nested": {"deep": [true, null]}}
	var untouched: Variant = port._normalize_json_string_types(no_names)
	assert_true(is_same(untouched, no_names),
		"a subtree with no StringName anywhere is returned as the SAME container, not a fresh copy")
	assert_eq(typeof((untouched as Dictionary)["integer"]), TYPE_INT)
	assert_eq(typeof((untouched as Dictionary)["fraction"]), TYPE_FLOAT,
		"int and float provenance stays exact through normalization")

	var sibling := {"keep": [3, 4], "deeper": {"still": "here"}}
	var with_name := {"named": &"probe", "sibling": sibling}
	var converted: Variant = port._normalize_json_string_types(with_name)
	assert_false(is_same(converted, with_name), "a converted descendant forces a new container")
	assert_eq(typeof((converted as Dictionary)["named"]), TYPE_STRING)
	assert_eq(str((converted as Dictionary)["named"]), "probe")
	assert_true(is_same((converted as Dictionary)["sibling"], sibling),
		"a sibling container with nothing to convert keeps its identity inside the rebuilt parent")
	assert_eq(typeof(with_name["named"]), TYPE_STRING_NAME,
		"the caller's own StringName is never converted in place")

	var deep_sibling := {"keep": [5, 6]}
	var deep := {"inner": {"named": &"deep-probe"}, "sibling": deep_sibling}
	var deep_converted: Dictionary = port._normalize_json_string_types(deep)
	assert_false(is_same(deep_converted, deep), "the rebuild propagates up the path that converted")
	assert_false(is_same(deep_converted["inner"], deep["inner"]), "the converting node itself is rebuilt")
	assert_true(is_same(deep_converted["sibling"], deep_sibling),
		"the rebuild is confined to the path containing the conversion")
	assert_eq(typeof((deep_converted["inner"] as Dictionary)["named"]), TYPE_STRING)

	# 2. Deep equality on a REAL consequence preimage, against the independent oracle above.
	var candidate_state := _admitted_state_candidate()
	var preimage: Dictionary = CONSEQUENCE_STATE.checkpoint_content_preimage(_header(), candidate_state)
	assert_true(preimage.get("ok", false), JSON.stringify(preimage))
	var preimage_value: Dictionary = (preimage["value"] as Dictionary)["preimage"]
	var expected_hash := _canonical_text(preimage_value).sha256_text()
	var normalized_preimage: Dictionary = port._normalize_json_string_types(preimage_value)
	assert_eq(normalized_preimage, _as_json_string_types(preimage_value),
		"the normalized preimage is deep-equal to its input with every StringName turned into a String")
	assert_eq(typeof((preimage_value["stage_candidate"] as Dictionary)["pending"]["stage"]), TYPE_STRING_NAME,
		"normalizing the preimage does not convert the caller's own values in place")
	assert_eq(typeof((normalized_preimage["stage_candidate"] as Dictionary)["pending"]["stage"]), TYPE_STRING)
	assert_eq(typeof((normalized_preimage["stage_candidate"] as Dictionary)["pending"]
		["recovery_payload"]["participant_snapshot_ids"]["marker"]), TYPE_INT,
		"an integer deep inside the recovery payload is never widened to a float")

	# 3. The prepared record is deep-equal to that same expectation, apart from the receipt the port
	# attaches to its OWN detached candidate.
	var prepared: Dictionary = port.prepare_consequence_checkpoint(_header(), candidate_state)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var document: Dictionary = (prepared["value"] as Dictionary)["candidate"]["document"]
	var receipt: Dictionary = (prepared["value"] as Dictionary)["checkpoint_receipt"]
	assert_eq(str(receipt["content_sha256"]), expected_hash)
	assert_eq(document["header"], _as_json_string_types(preimage_value["header"]))

	var actual_candidate: Dictionary = (document["stage_candidate"] as Dictionary).duplicate(true)
	var actual_pending: Dictionary = actual_candidate["pending"]
	assert_eq(actual_pending["checkpoint_receipt"], receipt, "the port attaches its just-minted receipt")
	assert_eq(actual_pending["admission_checkpoint_receipt"], receipt,
		"at the admission ordinal the same receipt fills the still-null admission slot")
	actual_pending.erase("checkpoint_receipt")
	actual_pending.erase("admission_checkpoint_receipt")
	var expected_candidate: Dictionary = _as_json_string_types(preimage_value["stage_candidate"])
	var expected_pending: Dictionary = expected_candidate["pending"]
	expected_pending.erase("checkpoint_receipt")
	expected_pending.erase("admission_checkpoint_receipt")
	assert_eq(actual_candidate, expected_candidate,
		"everything the receipt attachment does not touch is the normalized preimage, unchanged")

	# 4. The stored record never aliases the caller's stage_candidate.
	assert_false(is_same(document["stage_candidate"], candidate_state),
		"the stored stage_candidate is not the caller's own Dictionary")
	assert_false(is_same((document["stage_candidate"] as Dictionary)["pending"], candidate_state["pending"]),
		"nor is any nested container of it")
	assert_null(candidate_state["pending"]["checkpoint_receipt"],
		"the receipt attachment never reaches the caller's tree")
	assert_null(candidate_state["pending"]["admission_checkpoint_receipt"],
		"the caller still owns its receipt-free input")

	var document_before := _canonical_text(document)
	var receipt_before: Dictionary = receipt.duplicate(true)
	# The caller keeps mutating its own tree after preparing; the prepared record cannot move.
	candidate_state["run_revision"] = 77
	candidate_state["pending"]["stage"] = &"publication_pending"
	candidate_state["pending"]["recovery_payload"]["participant_snapshot_ids"]["marker"] = 999
	assert_eq(_canonical_text(document), document_before,
		"mutating the caller's stage_candidate after prepare cannot change the stored record")
	assert_eq((prepared["value"] as Dictionary)["checkpoint_receipt"], receipt_before)
	assert_eq(str(((prepared["value"] as Dictionary)["checkpoint_receipt"] as Dictionary)["content_sha256"]),
		expected_hash, "the content hash still proves the bytes that were prepared")


## --- Permanent env-gated prepare profile (dwm-634.3 session 4 Step 2 (b)) ----------------------
## prepare() gains the same DWM_CHECKPOINT_PROFILE=1 record commit() already emits, scoped
## "save_checkpoint_prepare" and stamped with the five phase names below through the existing
## static _profile_phase(); results flow through _profile_result(), which prints the
## `DWM_CHECKPOINT_PROFILE {json}` line. The record's FIELDS (elapsed_us, ok, per-phase micros) are
## asserted by the archived benchmark log in evidence/minesweeper_click_latency, not here, matching
## how the commit-side markers are covered; this test pins the scope and phase names in the source
## and guards that a profiled autosave prepare still succeeds.
const PREPARE_PROFILE_PHASES := ["view_capture_us", "run_snapshot_build_us", "journal_prepare_us",
	"document_build_us", "backup_us"]


func test_prepare_emits_a_permanent_env_gated_profile_record() -> void:
	var source := FileAccess.get_file_as_string(CHECKPOINT_PORT_PATH)
	assert_false(source.is_empty(), "the port source must be readable")
	assert_true(source.contains('"scope": "save_checkpoint_prepare"'),
		"prepare() builds a profile record scoped save_checkpoint_prepare")
	for phase: String in PREPARE_PROFILE_PHASES:
		assert_true(source.contains('_profile_phase(profile, "' + phase + '"'),
			"prepare() stamps the " + phase + " phase through _profile_phase")

	# Behavioural guard: an autosave disk_write so document_build_us and backup_us are exercised.
	var wired := _isolated_wired()
	if wired.is_empty():
		return
	var snapshot := _completion_snapshot()
	assert_true(wired["manager"]._journal.reset(str(snapshot["run_id"])).get("ok", false))
	var lease: Dictionary = wired["gate"].acquire(&"causal_transaction")
	assert_true(lease.get("ok", false), JSON.stringify(lease))
	OS.set_environment("DWM_CHECKPOINT_PROFILE", "1")
	var prepared: Dictionary = wired["port"].prepare(_checkpoint_inputs(snapshot), &"post_result",
		{"kind": &"autosave", "reason": &"automatic"})
	OS.unset_environment("DWM_CHECKPOINT_PROFILE")
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if prepared.get("ok", false):
		var candidate: Dictionary = prepared["value"]["candidate"]
		assert_false(str(candidate.get("checkpoint_id", "")).is_empty(),
			"a profiled prepare still issues a checkpoint_id")
		assert_eq(str(candidate["checkpoint_id"]), str(prepared["value"]["checkpoint_id"]))
		assert_not_null(candidate.get("autosave_document"), "the autosave document was built under profiling")
		assert_not_null(candidate.get("storage_backup"), "the storage backup was captured under profiling")
	assert_true(wired["gate"].release(&"causal_transaction", lease["value"]["token"]).get("ok", false))


func test_spliced_normalization_preserves_validation_and_refusal_results() -> void:
	var wired := _isolated_wired()
	if wired.is_empty(): return
	var snapshot := _completion_snapshot()
	assert_true(wired.manager._journal.reset(str(snapshot.run_id)).get("ok", false))
	_commit_autosave(wired, snapshot, 101)
	var candidate := _commit_autosave(wired, snapshot, 202)
	var original: Dictionary = candidate.autosave_document
	var proofs: Array = original.recovery_journal.duplicate(true)
	for fault: String in ["none", "engine_text", "unknown_member", "invalid_current", "wrong_journal_type"]:
		var document := original.duplicate(true)
		match fault:
			"engine_text":
				document.current_snapshot.snapshot.narrative_checkpoint[&"history_probe"] = &"kept"
			"unknown_member": document["unexpected"] = 1.0
			"invalid_current": document.current_snapshot["unexpected"] = true
			"wrong_journal_type": document.recovery_journal = 3
		var before := _canonical_text(document)
		var baseline: Dictionary = DOCUMENT_SCHEMA.validate_outgoing(
			wired.port._normalize_json_string_types(document), proofs)
		var candidate_result: Dictionary = DOCUMENT_SCHEMA.validate_outgoing(
			wired.port._normalize_outgoing_document(document, true), proofs)
		assert_true(preload("res://scripts/validation/CanonicalJsonWriter.gd")._deep_same(
			candidate_result, _as_json_string_types(baseline)), "same exact normalized result/refusal: " + fault)
		assert_eq(_canonical_text(document), before, "normalization never edits caller: " + fault)
		assert_true(preload("res://scripts/validation/CanonicalJsonWriter.gd")._deep_same(
			wired.port._normalize_outgoing_document(document, false),
			wired.port._normalize_json_string_types(document)), "cold path is unchanged: " + fault)


func test_spliced_commit_uses_proven_history_even_when_caller_journal_is_edited() -> void:
	var wired := _isolated_wired()
	if wired.is_empty(): return
	var snapshot := _completion_snapshot()
	assert_true(wired.manager._journal.reset(str(snapshot.run_id)).get("ok", false))
	_commit_autosave(wired, snapshot, 101)
	_commit_autosave(wired, snapshot, 202)
	var lease: Dictionary = wired.gate.acquire(&"causal_transaction")
	assert_true(lease.get("ok", false))
	var prepared: Dictionary = wired.port.prepare(_checkpoint_inputs(snapshot), &"post_result",
		{"kind": &"autosave", "reason": &"automatic"})
	assert_true(prepared.get("ok", false), str(prepared))
	if prepared.get("ok", false):
		var candidate: Dictionary = prepared.value.candidate
		var expected := (_canonical_text(candidate.autosave_document) + "\n").to_utf8_buffer()
		var forged: Dictionary = candidate.autosave_document.recovery_journal[0]
		forged.snapshot.gameplay.money = 999
		forged.snapshot.narrative_checkpoint[&"forged_history"] = &"must_not_be_written"
		var committed: Dictionary = wired.port.commit(candidate)
		assert_true(committed.get("ok", false), str(committed))
		_assert_same_bytes(_written_autosave(wired), expected,
			"journal-owned bytes and both semantic fallbacks remain exact after caller edits")
		assert_eq(int(forged.snapshot.gameplay.money), 999, "caller journal stays untouched")
	assert_true(wired.gate.release(&"causal_transaction", lease.value.token).get("ok", false))


class HistoryProofFailureStorage:
	extends "res://scripts/infrastructure/storage/JsonFileStorage.gd"
	var failure_mode := ""
	var completed_write := false

	func _init(root_dir: String) -> void:
		super(root_dir)

	func write_atomic(relative_path: String, text: String, validator: Callable,
			keep_backup: bool = true) -> Dictionary:
		if failure_mode == "write":
			return {"ok": false, "code": &"injected_write_failure"}
		var result: Dictionary = super.write_atomic(relative_path, text, validator, keep_backup)
		completed_write = result.get("ok", false)
		return result

	func read_text(relative_path: String) -> Dictionary:
		if completed_write and failure_mode == "read":
			return {"ok": false, "code": &"injected_read_failure"}
		var result: Dictionary = super.read_text(relative_path)
		if completed_write and failure_mode == "mismatch" and result.get("ok", false):
			result["value"] = str(result["value"]) + "\n"
		return result


func _record_memory_history(wired: Dictionary, snapshot: Dictionary, kind: StringName) -> Dictionary:
	var inputs := _checkpoint_inputs(snapshot)
	inputs["dialogic_checkpoint"] = {"history_note": "kept"}
	inputs["active_app_id"] = &"minesweeper"
	var lease: Dictionary = wired.gate.acquire(&"causal_transaction")
	assert_true(lease.get("ok", false), str(lease))
	var prepared: Dictionary = wired.port.prepare(inputs, kind, {"kind": &"none", "reason": &"stage"})
	assert_true(prepared.get("ok", false), str(prepared))
	var bundle := {}
	if prepared.get("ok", false):
		assert_true(wired.port.commit(prepared.value.candidate).get("ok", false))
		bundle = prepared.value.candidate.journal_candidate.current
	assert_true(wired.gate.release(&"causal_transaction", lease.value.token).get("ok", false))
	return bundle


func test_full_autosave_proves_memory_only_history_for_the_next_splice() -> void:
	var wired := _isolated_wired()
	if wired.is_empty(): return
	var snapshot := _completion_snapshot()
	assert_true(wired.manager._journal.reset(str(snapshot.run_id)).get("ok", false))
	for kind: StringName in [&"line", &"manual_save"]:
		var bundle := _record_memory_history(wired, snapshot, kind)
		assert_eq(typeof(bundle.snapshot.active_app_id), TYPE_STRING_NAME)
		assert_eq(wired.manager._journal.get_retained_bundle_text(str(bundle.snapshot.checkpoint_id)), "",
			"a memory-only record grants no durable proof")
	var first := _commit_autosave(wired, snapshot, 301)
	_assert_autosave_matches_full_writer(wired, first, "first durable full write")
	for bundle: Dictionary in first.autosave_document.recovery_journal:
		var checkpoint_id := str(bundle.snapshot.checkpoint_id)
		assert_eq(wired.manager._journal.get_retained_bundle_text(checkpoint_id), _canonical_text(bundle))
		assert_true(CANONICAL_JSON._deep_same(
			wired.manager._journal.get_retained_bundle_document(checkpoint_id), bundle))
		assert_eq(typeof(bundle.snapshot.active_app_id), TYPE_STRING,
			"normalized written text agrees with retained engine StringName values")
	var lease: Dictionary = wired.gate.acquire(&"causal_transaction")
	assert_true(lease.get("ok", false))
	var prepared: Dictionary = wired.port.prepare(_checkpoint_inputs(snapshot), &"post_result",
		{"kind": &"autosave", "reason": &"automatic"})
	assert_true(prepared.get("ok", false), str(prepared))
	if prepared.get("ok", false):
		var candidate: Dictionary = prepared.value.candidate
		var document: Dictionary = candidate.autosave_document
		var proofs: Array = []
		var spliced: String = wired.port._splice_autosave_text(document,
			_canonical_text(document.current_snapshot), proofs)
		assert_eq(spliced, _canonical_text(document), "every actual retained entry now has an exact splice proof")
		assert_eq(proofs.size(), document.recovery_journal.size())
		assert_true(wired.port.commit(candidate).get("ok", false))
		_assert_autosave_matches_full_writer(wired, candidate, "next write after warming history")
	assert_true(wired.gate.release(&"causal_transaction", lease.value.token).get("ok", false))


func test_history_proofs_require_successful_write_reread_and_journal_commit() -> void:
	for failure: String in ["write", "read", "mismatch", "journal"]:
		var wired := _isolated_wired()
		if wired.is_empty(): return
		var storage := HistoryProofFailureStorage.new(str(wired.root))
		wired.manager._storage = storage
		var snapshot := _completion_snapshot()
		assert_true(wired.manager._journal.reset(str(snapshot.run_id)).get("ok", false))
		var bundle := _record_memory_history(wired, snapshot, &"line")
		var checkpoint_id := str(bundle.snapshot.checkpoint_id)
		var lease: Dictionary = wired.gate.acquire(&"causal_transaction")
		assert_true(lease.get("ok", false))
		var prepared: Dictionary = wired.port.prepare(_checkpoint_inputs(snapshot), &"post_result",
			{"kind": &"autosave", "reason": &"automatic"})
		assert_true(prepared.get("ok", false), str(prepared))
		if prepared.get("ok", false):
			var candidate: Dictionary = prepared.value.candidate
			storage.failure_mode = failure
			if failure == "journal": candidate.journal_candidate.next_sequence += 1
			var committed: Dictionary = wired.port.commit(candidate)
			assert_false(committed.get("ok", true), failure)
			var expected_codes := {"write": &"injected_write_failure", "read": &"injected_read_failure",
				"mismatch": &"reread_mismatch", "journal": &"invalid_candidate"}
			assert_eq(committed.get("code"), expected_codes[failure], failure)
			assert_eq(storage.completed_write, failure != "write", "failure occurs at its intended gate")
			assert_eq(wired.manager._journal.get_retained_bundle_text(checkpoint_id), "", failure)
			assert_true(wired.manager._journal.get_retained_bundle_document(checkpoint_id).is_empty(), failure)
			assert_eq(wired.manager._journal.get_retained_bundle_text(str(candidate.checkpoint_id)), "", failure)
		assert_true(wired.gate.release(&"causal_transaction", lease.value.token).get("ok", false))


func test_full_write_history_edits_never_prove_a_different_retained_bundle() -> void:
	for edit: String in ["value", "float", "both_float", "malformed", "during_write"]:
		var wired := _isolated_wired()
		if wired.is_empty(): return
		var snapshot := _completion_snapshot()
		assert_true(wired.manager._journal.reset(str(snapshot.run_id)).get("ok", false))
		var recorded := _record_memory_history(wired, snapshot, &"line")
		var checkpoint_id := str(recorded.snapshot.checkpoint_id)
		var lease: Dictionary = wired.gate.acquire(&"causal_transaction")
		assert_true(lease.get("ok", false))
		var prepared: Dictionary = wired.port.prepare(_checkpoint_inputs(snapshot), &"post_result",
			{"kind": &"autosave", "reason": &"automatic"})
		assert_true(prepared.get("ok", false), str(prepared))
		if prepared.get("ok", false):
			var candidate: Dictionary = prepared.value.candidate
			var historical: Dictionary = candidate.autosave_document.recovery_journal[0]
			match edit:
				"value": historical.snapshot.content_version += 100
				"float": historical.snapshot.content_version = float(historical.snapshot.content_version)
				"both_float":
					historical.snapshot.content_version = float(historical.snapshot.content_version)
					candidate.journal_candidate.earlier[0].snapshot.content_version = historical.snapshot.content_version
				"malformed": candidate.autosave_document.recovery_journal[0] = {}
				"during_write":
					assert_true(wired.manager._storage.configure_before_write(func() -> Dictionary:
						historical.snapshot.content_version += 100
						candidate.journal_candidate.earlier[0].snapshot.content_version += 100
						return {"ok": true}).get("ok", false))
			var expected := (_canonical_text(candidate.autosave_document) + "\n").to_utf8_buffer()
			var committed: Dictionary = wired.port.commit(candidate)
			assert_true(committed.get("ok", false), edit + ": " + str(committed))
			_assert_same_bytes(_written_autosave(wired), expected, "full writer stays authoritative: " + edit)
			assert_eq(wired.manager._journal.get_retained_bundle_text(checkpoint_id), "", edit)
			assert_true(wired.manager._journal.get_retained_bundle_document(checkpoint_id).is_empty(), edit)
		assert_true(wired.gate.release(&"causal_transaction", lease.value.token).get("ok", false))
