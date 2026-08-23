extends "res://addons/gut/test.gd"

## RED/GREEN coverage for DesktopCausalSequencePort (Plan 02 Task 6, dwm-p2r.32).

const _PORT_SCRIPT := preload("res://scripts/application/desktop/DesktopCausalSequencePort.gd")
const _STATE_SCRIPT := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const _GATE_SCRIPT := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## Minimal in-memory fake mirroring SaveManagerCheckpointPort's two-method Task-6 subset.
class FakeAdmissionCheckpointPort:
	var committed: Array = []
	var fail_next_commit := false

	func prepare_consequence_checkpoint(checkpoint_header: Dictionary, stage_candidate: Dictionary) -> Dictionary:
		var preimage: Dictionary = _STATE_SCRIPT.checkpoint_content_preimage(checkpoint_header, stage_candidate)
		if not preimage.get("ok", false):
			return preimage
		var preimage_value: Dictionary = preimage["value"]["preimage"]
		var content_sha256: String = _canon(preimage_value).sha256_text()
		var checkpoint_receipt := {"receipt_id": "consequence_checkpoint." + content_sha256,
			"header": preimage_value["header"], "content_sha256": content_sha256}
		return {"ok": true, "code": &"ok", "value": {
			"candidate": {"document": {"stage_candidate": stage_candidate}},
			"checkpoint_receipt": checkpoint_receipt,
		}}

	func commit_consequence_checkpoint(checkpoint_candidate: Dictionary, checkpoint_receipt: Dictionary) -> Dictionary:
		if fail_next_commit:
			fail_next_commit = false
			return {"ok": false, "code": &"forced_failure", "message": "test-forced checkpoint commit failure"}
		committed.append({"candidate": checkpoint_candidate, "receipt": checkpoint_receipt})
		return {"ok": true, "code": &"ok", "value": {"checkpoint_receipt": checkpoint_receipt}}

	static func _canon(value: Variant) -> String:
		var emitted: Dictionary = CanonicalJsonWriter.stringify(value)
		return str(emitted["value"])

class FakePublicationLedger:
	var records: Dictionary = {}

	func record_before_emit(request: Dictionary) -> Dictionary:
		var semantic_receipt: Dictionary = request["semantic_receipt"]
		# FIX (dwm-p2r.13 remediation, finding W1): under the corrected ledger kind union, the
		# causal_sequence kind's own semantic_receipt is {causal_sequence_receipt,
		# admission_checkpoint_receipt} -- it carries no top-level receipt_id of its own (that lives
		# nested inside causal_sequence_receipt), unlike this fake's previous single-shape assumption.
		var receipt_id: String
		if str(request["kind"]) == "causal_sequence":
			receipt_id = str((semantic_receipt["causal_sequence_receipt"] as Dictionary)["receipt_id"])
		else:
			receipt_id = str(semantic_receipt.get("receipt_id", semantic_receipt.get("commit_receipt_id", "")))
		var key := str(request["kind"]) + ":" + receipt_id
		if records.has(key):
			if records[key] == request:
				return {"ok": true, "code": &"ok", "value": {"record": request, "first_delivery": false}, "receipt": {}}
			return {"ok": false, "code": &"publication_record_conflict", "message": key}
		records[key] = request.duplicate(true)
		return {"ok": true, "code": &"ok", "value": {"record": request, "first_delivery": true}, "receipt": {}}


func _issuer_receipt(token: String, purpose: String = "causal_day_instance") -> Dictionary:
	return {"receipt_id": "issuer_receipt.fake-" + token, "purpose": purpose,
		"namespace": "fakenamespace", "counter": 3, "token": token, "numeric_value": null}

func _provenance() -> Dictionary:
	return {"causal_day_instance": "causal-day-1",
		"causal_day_instance_issuer_receipt": _issuer_receipt("causal-day-1")}

func _fresh_state() -> RefCounted:
	var state := _STATE_SCRIPT.new()
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	var prepared: Dictionary = state.prepare_restore(made["value"]["state"])
	state.commit(prepared["value"]["candidate"])
	return state

func _wired(state: RefCounted = null, checkpoint_port: FakeAdmissionCheckpointPort = null,
		ledger: FakePublicationLedger = null) -> Dictionary:
	var live_state := state if state != null else _fresh_state()
	var gate := _GATE_SCRIPT.new()
	var live_checkpoint_port := checkpoint_port if checkpoint_port != null else FakeAdmissionCheckpointPort.new()
	var live_ledger := ledger if ledger != null else FakePublicationLedger.new()
	var port := _PORT_SCRIPT.new()
	var configured_ledger: Dictionary = port.configure_publication_ledger(live_ledger)
	assert_true(configured_ledger.get("ok", false), JSON.stringify(configured_ledger))
	var configured: Dictionary = port.configure(live_state, gate, live_checkpoint_port)
	assert_true(configured.get("ok", false), JSON.stringify(configured))
	return {"port": port, "state": live_state, "gate": gate, "checkpoint_port": live_checkpoint_port, "ledger": live_ledger}

func _request(transaction_id: String = "txn-1", source_kind: String = "minesweeper_round") -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": _issuer_receipt(transaction_id, "transaction_id"),
		"run_id": "run-1", "branch_id": "branch-1", "desktop_timeline_generation": 0,
		"causal_day_instance": "causal-day-1", "source_kind": source_kind,
		"source_commit_receipt_id": "commit-receipt-1",
		"source_commit_receipt_provenance": {"child_kind": "board_fate"},
		"expected_last_sequence": 0, "expected_run_revision": 0,
	}


func test_configure_requires_publication_ledger_first() -> void:
	var port := _PORT_SCRIPT.new()
	var state := _fresh_state()
	var gate := _GATE_SCRIPT.new()
	var checkpoint_port := FakeAdmissionCheckpointPort.new()
	var attempted: Dictionary = port.configure(state, gate, checkpoint_port)
	assert_false(attempted.get("ok", true))
	assert_eq(attempted["code"], &"publication_ledger_not_configured")


func test_prepare_reservation_proposes_sequence_and_revision() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var prepared: Dictionary = port.prepare_reservation(_request())
	assert_true(prepared["ok"], JSON.stringify(prepared))
	var receipt: Dictionary = prepared["value"]["causal_sequence_receipt"]
	assert_eq(receipt["causal_sequence"], 1)
	assert_eq(receipt["run_revision"], 1)
	assert_eq(receipt["transaction_id"], "txn-1")
	# Neither sequence nor revision is allocated yet: live state is untouched.
	var live: Dictionary = wired["state"].capture()["value"]["state"]
	assert_eq(live["causal_sequence"], 0)
	assert_eq(live["run_revision"], 0)


func test_prepare_reservation_identical_replay_returns_original() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var first: Dictionary = port.prepare_reservation(_request())
	var second: Dictionary = port.prepare_reservation(_request())
	assert_true(second["ok"], JSON.stringify(second))
	assert_eq(second["value"]["causal_sequence_receipt"], first["value"]["causal_sequence_receipt"])


func test_prepare_reservation_changed_payload_conflicts() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	port.prepare_reservation(_request())
	var changed := _request()
	changed["source_commit_receipt_id"] = "commit-receipt-DIFFERENT"
	var conflicted: Dictionary = port.prepare_reservation(changed)
	assert_false(conflicted.get("ok", true))
	assert_eq(conflicted["code"], &"causal_sequence_conflict")


func test_prepare_reservation_rejects_stale_sequence_and_revision() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var stale_sequence := _request("txn-a")
	stale_sequence["expected_last_sequence"] = 5
	var rejected_sequence: Dictionary = port.prepare_reservation(stale_sequence)
	assert_false(rejected_sequence.get("ok", true))
	assert_eq(rejected_sequence["code"], &"causal_sequence_stale")

	var stale_revision := _request("txn-b")
	stale_revision["expected_run_revision"] = 5
	var rejected_revision: Dictionary = port.prepare_reservation(stale_revision)
	assert_false(rejected_revision.get("ok", true))
	assert_eq(rejected_revision["code"], &"run_revision_stale")


func _admit(wired: Dictionary, transaction_id: String = "txn-1") -> Dictionary:
	var port: RefCounted = wired["port"]
	var state: RefCounted = wired["state"]
	var request := _request(transaction_id)
	var payload := {"source_kind": "minesweeper_round", "action_receipt": {"result": "completed"},
		"run_revision_before": 0, "participant_snapshot_ids": {}}
	var action_receipt := {
		"source_kind": "minesweeper_round", "transaction_id": transaction_id,
		"transaction_issuer_receipt": request["transaction_issuer_receipt"],
		"source_commit_receipt_id": "commit-receipt-1", "source_commit_receipt_provenance": {"child_kind": "board_fate"},
	}
	var handoff: Dictionary = state.prepare_action_handoff(action_receipt, 0, payload)
	assert_true(handoff.get("ok", false), JSON.stringify(handoff))
	state.commit(handoff["value"]["candidate"])

	var reserved: Dictionary = port.prepare_reservation(request)
	assert_true(reserved.get("ok", false), JSON.stringify(reserved))
	var sequence_candidate: Dictionary = reserved["value"]["sequence_candidate"]

	var live_pending: Dictionary = state.capture()["value"]["state"]["pending"]
	var header := {"kind": &"consequence_admission", "operation_ordinal": 0, "run_id": "run-1",
		"source_ids": [], "stage": String(live_pending["stage"]), "transaction_id": transaction_id}
	var candidate_state: Dictionary = state.capture()["value"]["state"]
	var admission_checkpoint_candidate: Dictionary = wired["checkpoint_port"].prepare_consequence_checkpoint(header, candidate_state)
	assert_true(admission_checkpoint_candidate.get("ok", false), JSON.stringify(admission_checkpoint_candidate))

	var admitted: Dictionary = port.prepare_admission(
		sequence_candidate, admission_checkpoint_candidate["value"], _sha256(payload))
	assert_true(admitted.get("ok", false), JSON.stringify(admitted))
	return {"admission_candidate": admitted["value"]["candidate"], "request": request}

func _sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	return str(emitted["value"]).sha256_text()


func test_full_admission_commits_checkpoint_then_forward_applies_live_state() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var gate: RefCounted = wired["gate"]
	var acquired: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(acquired["ok"], JSON.stringify(acquired))

	var admission := _admit(wired)
	var committed: Dictionary = port.commit(admission["admission_candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(committed["value"]["causal_sequence_receipt"]["causal_sequence"], 1)
	assert_eq(committed["value"]["causal_sequence_receipt"]["run_revision"], 1)
	assert_eq((wired["checkpoint_port"] as FakeAdmissionCheckpointPort).committed.size(), 1,
		"the admission checkpoint must be committed exactly once")

	var live: Dictionary = wired["state"].capture()["value"]["state"]
	assert_eq(live["causal_sequence"], 1)
	assert_eq(live["run_revision"], 1)
	assert_eq(live["pending"]["stage"], &"sequence_committed")
	assert_eq(live["pending"]["admission_checkpoint_receipt"], live["pending"]["checkpoint_receipt"])


func test_commit_requires_the_active_causal_transaction_lease() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var admission := _admit(wired)
	# No gate.acquire(&"causal_transaction") this time.
	var rejected: Dictionary = port.commit(admission["admission_candidate"])
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"causal_transaction_lease_required")


func test_publish_records_through_the_configured_ledger_at_most_once() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var gate: RefCounted = wired["gate"]
	gate.acquire(&"causal_transaction")
	var admission := _admit(wired)
	var committed: Dictionary = port.commit(admission["admission_candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))

	var publication := {"causal_sequence_receipt": committed["value"]["causal_sequence_receipt"],
		"admission_checkpoint_receipt": committed["value"]["admission_checkpoint_receipt"]}
	var published: Dictionary = port.publish(publication)
	assert_true(published.get("ok", false), JSON.stringify(published))
	assert_eq(published["value"]["published"], true)
	assert_eq((wired["ledger"] as FakePublicationLedger).records.size(), 1)

	var replay: Dictionary = port.publish(publication)
	assert_true(replay.get("ok", false), "byte-identical replay is a no-op success")
	assert_eq((wired["ledger"] as FakePublicationLedger).records.size(), 1, "no second record is allocated")


func test_rollback_before_admission_restores_pending_reservations() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var backup: Dictionary = port.capture()
	port.prepare_reservation(_request())
	var rolled: Dictionary = port.rollback(backup["value"]["backup"])
	assert_true(rolled.get("ok", false), JSON.stringify(rolled))
	assert_eq(rolled["value"]["restored"], true)
	# The reservation is gone: a fresh prepare_reservation for the same transaction proposes anew.
	var reprepared: Dictionary = port.prepare_reservation(_request())
	assert_true(reprepared.get("ok", false))
	assert_eq(reprepared["value"]["causal_sequence_receipt"]["causal_sequence"], 1)


func test_rollback_after_admission_is_irreversible() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var gate: RefCounted = wired["gate"]
	var backup: Dictionary = port.capture()
	gate.acquire(&"causal_transaction")
	var admission := _admit(wired)
	var committed: Dictionary = port.commit(admission["admission_candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	var rejected: Dictionary = port.rollback(backup["value"]["backup"])
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"causal_admission_irreversible")


func test_checkpoint_commit_failure_leaves_live_state_untouched() -> void:
	var checkpoint_port := FakeAdmissionCheckpointPort.new()
	var wired := _wired(null, checkpoint_port)
	var port: RefCounted = wired["port"]
	var gate: RefCounted = wired["gate"]
	gate.acquire(&"causal_transaction")
	var admission := _admit(wired)
	checkpoint_port.fail_next_commit = true
	var failed: Dictionary = port.commit(admission["admission_candidate"])
	assert_false(failed.get("ok", true))
	var live: Dictionary = wired["state"].capture()["value"]["state"]
	assert_eq(live["causal_sequence"], 0, "a failed checkpoint commit must not advance live causal_sequence")
	assert_eq(live["run_revision"], 0)


## Minimal in-memory wrapper over a real DesktopConsequenceState: forwards every call except a
## one-shot forced failure on whichever method name is armed. Used to inject a failure strictly
## AFTER the admission checkpoint has already committed to disk -- the exact CRITICAL-1 gap -- since
## FakeAdmissionCheckpointPort alone can only fail BEFORE that point.
class FailInjectingConsequenceState:
	var _inner: RefCounted
	var fail_next_call_name: String = ""

	func _init(inner: RefCounted) -> void:
		_inner = inner

	func capture() -> Dictionary:
		return _inner.capture()

	func prepare_action_handoff(action_receipt: Dictionary, run_revision_before: int, payload: Dictionary) -> Dictionary:
		return _inner.prepare_action_handoff(action_receipt, run_revision_before, payload)

	func prepare_sequence_reservation(request: Dictionary, causal_sequence_receipt: Dictionary) -> Dictionary:
		if fail_next_call_name == "prepare_sequence_reservation":
			fail_next_call_name = ""
			return {"ok": false, "code": &"forced_failure", "message": "test-forced live failure"}
		return _inner.prepare_sequence_reservation(request, causal_sequence_receipt)

	func prepare_restore(state: Dictionary) -> Dictionary:
		if fail_next_call_name == "prepare_restore":
			fail_next_call_name = ""
			return {"ok": false, "code": &"forced_failure", "message": "test-forced live failure"}
		return _inner.prepare_restore(state)

	func commit(candidate: Dictionary) -> Dictionary:
		return _inner.commit(candidate)

	func rollback(backup: Dictionary) -> Dictionary:
		return _inner.rollback(backup)


func test_commit_partial_live_failure_after_checkpoint_returns_committed_pending_recovery() -> void:
	var spy_state := FailInjectingConsequenceState.new(_fresh_state())
	var wired := _wired(spy_state)
	var port: RefCounted = wired["port"]
	var gate: RefCounted = wired["gate"]
	gate.acquire(&"causal_transaction")
	var admission := _admit(wired)

	spy_state.fail_next_call_name = "prepare_sequence_reservation"
	var partial: Dictionary = port.commit(admission["admission_candidate"])
	assert_false(partial.get("ok", true))
	assert_eq(partial["code"], &"causal_admission_committed_pending_recovery")
	assert_eq((wired["checkpoint_port"] as FakeAdmissionCheckpointPort).committed.size(), 1,
		"the admission checkpoint genuinely committed to disk despite the live failure")
	var details: Dictionary = partial["details"]
	assert_eq(details["transaction_id"], "txn-1")
	assert_true(details.has("causal_sequence_receipt"))
	assert_eq((details["causal_sequence_receipt"] as Dictionary)["causal_sequence"], 1)
	assert_true(details.has("admission_checkpoint_receipt"))
	assert_true(details.has("live_failure"))

	# Live consequence state never advanced (the injected failure fired before any live mutation).
	var live: Dictionary = spy_state.capture()["value"]["state"]
	assert_eq(live["causal_sequence"], 0)
	assert_eq(live["run_revision"], 0)


func test_commit_partial_live_failure_pre_admission_backup_rollback_refuses() -> void:
	var spy_state := FailInjectingConsequenceState.new(_fresh_state())
	var wired := _wired(spy_state)
	var port: RefCounted = wired["port"]
	var gate: RefCounted = wired["gate"]
	gate.acquire(&"causal_transaction")
	var pre_admission_backup: Dictionary = port.capture()

	var admission := _admit(wired)
	spy_state.fail_next_call_name = "prepare_sequence_reservation"
	var partial: Dictionary = port.commit(admission["admission_candidate"])
	assert_false(partial.get("ok", true))
	assert_eq(partial["code"], &"causal_admission_committed_pending_recovery")

	var rejected: Dictionary = port.rollback(pre_admission_backup["value"]["backup"])
	assert_false(rejected.get("ok", true), "rollback must refuse once the admission checkpoint has committed, even if live adoption then failed")
	assert_eq(rejected["code"], &"causal_admission_irreversible")


func test_commit_partial_live_failure_then_retry_resumes_coherently() -> void:
	var spy_state := FailInjectingConsequenceState.new(_fresh_state())
	var wired := _wired(spy_state)
	var port: RefCounted = wired["port"]
	var gate: RefCounted = wired["gate"]
	gate.acquire(&"causal_transaction")
	var admission := _admit(wired)

	spy_state.fail_next_call_name = "prepare_sequence_reservation"
	var partial: Dictionary = port.commit(admission["admission_candidate"])
	assert_false(partial.get("ok", true))

	# fail_next_call_name self-clears after firing once: a second commit() of the SAME candidate
	# resumes and completes normally.
	var resumed: Dictionary = port.commit(admission["admission_candidate"])
	assert_true(resumed.get("ok", false), JSON.stringify(resumed))
	assert_eq(resumed["value"]["causal_sequence_receipt"]["causal_sequence"], 1)
	assert_eq(resumed["value"]["causal_sequence_receipt"]["run_revision"], 1)

	var live: Dictionary = spy_state.capture()["value"]["state"]
	assert_eq(live["causal_sequence"], 1)
	assert_eq(live["run_revision"], 1)


func test_prepare_reservation_after_commit_identical_retry_replays_original_success() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var gate: RefCounted = wired["gate"]
	gate.acquire(&"causal_transaction")
	var admission := _admit(wired)
	var committed: Dictionary = port.commit(admission["admission_candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))

	# _committed_transaction_ids is now actually read (IMPORTANT 2): an identical retry replays the
	# original prepare_reservation() success rather than falling through to live validation, where
	# expected_last_sequence=0 is now stale (live causal_sequence already advanced to 1).
	var replay: Dictionary = port.prepare_reservation(admission["request"])
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay["value"]["causal_sequence_receipt"], committed["value"]["causal_sequence_receipt"])
	assert_ne(replay.get("code"), &"causal_sequence_stale")


func test_prepare_reservation_after_commit_changed_bytes_conflicts() -> void:
	var wired := _wired()
	var port: RefCounted = wired["port"]
	var gate: RefCounted = wired["gate"]
	gate.acquire(&"causal_transaction")
	var admission := _admit(wired)
	var committed: Dictionary = port.commit(admission["admission_candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))

	var changed: Dictionary = (admission["request"] as Dictionary).duplicate(true)
	changed["source_commit_receipt_id"] = "commit-receipt-DIFFERENT"
	var conflicted: Dictionary = port.prepare_reservation(changed)
	assert_false(conflicted.get("ok", true))
	assert_eq(conflicted["code"], &"causal_sequence_conflict")
