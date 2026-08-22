extends "res://addons/gut/test.gd"

## RED/GREEN coverage for DesktopConsequenceState (Plan 02 Task 6, dwm-p2r.32).

const _STATE_SCRIPT := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

func _issuer_receipt(token: String, purpose: String = "causal_day_instance") -> Dictionary:
	return {
		"receipt_id": "issuer_receipt.fake-" + token, "purpose": purpose, "namespace": "fakenamespace",
		"counter": 7, "token": token, "numeric_value": null,
	}

func _provenance(day_token: String = "causal-day-1") -> Dictionary:
	return {"causal_day_instance": day_token, "causal_day_instance_issuer_receipt": _issuer_receipt(day_token)}

func _sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	return str(emitted["value"]).sha256_text()

func _fresh_state() -> RefCounted:
	return _STATE_SCRIPT.new()


func test_make_empty_produces_valid_zeroed_state() -> void:
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	assert_true(made["ok"], JSON.stringify(made))
	var state: Dictionary = made["value"]["state"]
	assert_eq(state["run_revision"], 0)
	assert_eq(state["causal_sequence"], 0)
	assert_eq(state["pending"], null)
	assert_eq(state["outbox"], {})
	var validated: Dictionary = _STATE_SCRIPT.validate(state)
	assert_true(validated["ok"], JSON.stringify(validated))


func test_make_empty_rejects_id_only_or_mismatched_provenance() -> void:
	var id_only: Dictionary = _STATE_SCRIPT.make_empty({"causal_day_instance": "causal-day-1"})
	assert_false(id_only.get("ok", true))
	var mismatched := _provenance()
	mismatched["causal_day_instance_issuer_receipt"] = _issuer_receipt("some-other-token")
	var drifted: Dictionary = _STATE_SCRIPT.make_empty(mismatched)
	assert_false(drifted.get("ok", true))
	var wrong_purpose := _provenance()
	wrong_purpose["causal_day_instance_issuer_receipt"] = _issuer_receipt("causal-day-1", "transaction_id")
	var wrong: Dictionary = _STATE_SCRIPT.make_empty(wrong_purpose)
	assert_false(wrong.get("ok", true))


func test_validate_rejects_extra_and_missing_top_level_keys() -> void:
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	var state: Dictionary = made["value"]["state"]
	var extra := state.duplicate(true)
	extra["bogus"] = 1
	assert_false(_STATE_SCRIPT.validate(extra).get("ok", true))
	var missing := state.duplicate(true)
	missing.erase("outbox")
	assert_false(_STATE_SCRIPT.validate(missing).get("ok", true))


func test_capture_and_restore_round_trip() -> void:
	var state := _fresh_state()
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	var prepared: Dictionary = state.prepare_restore(made["value"]["state"])
	assert_true(prepared["ok"], JSON.stringify(prepared))
	var committed: Dictionary = state.commit(prepared["value"]["candidate"])
	assert_true(committed["ok"], JSON.stringify(committed))
	var captured: Dictionary = state.capture()
	assert_eq(captured["value"]["state"], made["value"]["state"])


func _bootstrapped(day_token: String = "causal-day-1") -> RefCounted:
	var state := _fresh_state()
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance(day_token))
	var prepared: Dictionary = state.prepare_restore(made["value"]["state"])
	state.commit(prepared["value"]["candidate"])
	return state


func _action_recovery_payload(source_kind: String) -> Dictionary:
	return {
		"source_kind": source_kind, "action_receipt": {"result": "completed"},
		"run_revision_before": 0, "participant_snapshot_ids": {},
	}


func _action_receipt(source_kind: String, transaction_id: String = "txn-1") -> Dictionary:
	return {
		"source_kind": source_kind,
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": _issuer_receipt(transaction_id, "transaction_id"),
		"source_commit_receipt_id": "commit-receipt-1",
		"source_commit_receipt_provenance": {"child_kind": "board_fate"},
	}


func test_prepare_action_handoff_creates_pending_at_action_prepared() -> void:
	var state := _bootstrapped()
	var payload := _action_recovery_payload("minesweeper_round")
	var prepared: Dictionary = state.prepare_action_handoff(
		_action_receipt("minesweeper_round"), 0, payload)
	assert_true(prepared["ok"], JSON.stringify(prepared))
	var committed: Dictionary = state.commit(prepared["value"]["candidate"])
	assert_true(committed["ok"], JSON.stringify(committed))
	var pending: Dictionary = committed["value"]["state"]["pending"]
	assert_eq(pending["stage"], &"action_prepared")
	assert_eq(pending["admission_checkpoint_receipt"], null)
	assert_eq(pending["checkpoint_receipt"], null)
	assert_eq(pending["source_kind"], "minesweeper_round")


func test_prepare_action_handoff_rejects_second_concurrent_pending() -> void:
	var state := _bootstrapped()
	var payload := _action_recovery_payload("minesweeper_round")
	var prepared: Dictionary = state.prepare_action_handoff(_action_receipt("minesweeper_round"), 0, payload)
	state.commit(prepared["value"]["candidate"])
	var second: Dictionary = state.prepare_action_handoff(_action_receipt("shop_purchase", "txn-2"), 0,
		_action_recovery_payload("shop_purchase"))
	assert_false(second.get("ok", true), "a second pending transaction must be rejected")
	assert_eq(second["code"], &"consequence_transaction_already_pending")


func test_prepare_action_handoff_rejects_stale_run_revision() -> void:
	var state := _bootstrapped()
	var prepared: Dictionary = state.prepare_action_handoff(
		_action_receipt("minesweeper_round"), 5, _action_recovery_payload("minesweeper_round"))
	assert_false(prepared.get("ok", true))
	assert_eq(prepared["code"], &"stale_run_revision")


func _schedule_header(transaction_id: String = "txn-sched-1") -> Dictionary:
	return {
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": _issuer_receipt(transaction_id, "transaction_id"),
		"source_commit_receipt_id": "schedule-commit-1",
		"source_commit_receipt_provenance": {"child_kind": "schedule_commit"},
		"expected_run_revision": 0,
	}


func test_prepare_schedule_recovery_transport_creates_pending_at_prepared_checkpointed() -> void:
	var state := _bootstrapped()
	var payload := {
		"source_kind": "schedule_done", "schedule_header": {"day": 1}, "run_revision_before": 0,
		"participant_snapshot_ids": {},
	}
	var prepared: Dictionary = state.prepare_schedule_recovery_transport(_schedule_header(), payload)
	assert_true(prepared["ok"], JSON.stringify(prepared))
	var committed: Dictionary = state.commit(prepared["value"]["candidate"])
	assert_true(committed["ok"], JSON.stringify(committed))
	assert_eq(committed["value"]["state"]["pending"]["stage"], &"prepared_checkpointed")


func _causal_sequence_receipt(state: RefCounted, source_kind: String, transaction_id: String) -> Dictionary:
	var captured: Dictionary = state.capture()
	var live: Dictionary = captured["value"]["state"]
	var pending: Dictionary = live["pending"]
	return {
		"receipt_id": "causal-seq-receipt-1", "receipt_provenance": {},
		"transaction_id": transaction_id, "transaction_issuer_receipt": pending["transaction_issuer_receipt"],
		"run_id": "run-1", "branch_id": "branch-1", "desktop_timeline_generation": 0,
		"causal_day_instance": live["causal_day_instance"], "source_kind": source_kind,
		"source_commit_receipt_id": pending["source_commit_receipt_id"],
		"source_commit_receipt_provenance": pending["source_commit_receipt_provenance"],
		"causal_sequence": int(live["causal_sequence"]) + 1, "run_revision": int(live["run_revision"]) + 1,
	}


func _admitted(source_kind: String = "minesweeper_round", transaction_id: String = "txn-1") -> RefCounted:
	var state := _bootstrapped()
	var payload := _action_recovery_payload(source_kind)
	var prepared: Dictionary = state.prepare_action_handoff(
		_action_receipt(source_kind, transaction_id), 0, payload)
	state.commit(prepared["value"]["candidate"])
	var receipt := _causal_sequence_receipt(state, source_kind, transaction_id)
	var reserved: Dictionary = state.prepare_sequence_reservation(
		{"transaction_id": transaction_id, "source_kind": source_kind}, receipt)
	if not reserved.get("ok", false):
		push_error("prepare_sequence_reservation failed: " + JSON.stringify(reserved))
		return state
	# The disk admission-checkpoint receipt is minted by the causal port / checkpoint port (out of
	# this unit's scope). The live adoption of a sequence reservation and its admission receipt is
	# ONE atomic transition (brief line 249): "That live adoption sets both pending receipt fields
	# atomically." So the candidate's admission_checkpoint_receipt/checkpoint_receipt are patched
	# in BEFORE the single commit that makes any of this live -- never as two separate live states.
	var candidate_state: Dictionary = reserved["value"]["candidate"]["state_after"]
	var admission_receipt := {"checkpoint_id": "chk-1", "sequence": 1}
	candidate_state["pending"]["admission_checkpoint_receipt"] = admission_receipt
	candidate_state["pending"]["checkpoint_receipt"] = admission_receipt.duplicate(true)
	var prepared_restore: Dictionary = state.prepare_restore(candidate_state)
	var committed: Dictionary = state.commit(prepared_restore["value"]["candidate"])
	if not committed.get("ok", false):
		push_error("admission commit failed: " + JSON.stringify(committed))
	return state


func test_prepare_sequence_reservation_advances_to_sequence_committed() -> void:
	var state := _admitted()
	var live: Dictionary = state.capture()["value"]["state"]
	assert_eq(live["pending"]["stage"], &"sequence_committed")
	assert_eq(live["run_revision"], 1)
	assert_eq(live["causal_sequence"], 1)
	assert_eq(live["pending"]["admission_checkpoint_receipt"], live["pending"]["checkpoint_receipt"])


func test_prepare_sequence_reservation_rejects_out_of_order_sequence() -> void:
	var state := _bootstrapped()
	var payload := _action_recovery_payload("minesweeper_round")
	var prepared: Dictionary = state.prepare_action_handoff(_action_receipt("minesweeper_round"), 0, payload)
	state.commit(prepared["value"]["candidate"])
	var receipt := _causal_sequence_receipt(state, "minesweeper_round", "txn-1")
	receipt["causal_sequence"] = 99
	var reserved: Dictionary = state.prepare_sequence_reservation(
		{"transaction_id": "txn-1", "source_kind": "minesweeper_round"}, receipt)
	assert_false(reserved.get("ok", true))
	assert_eq(reserved["code"], &"causal_sequence_conflict")


func test_prepare_recovery_advance_ordinary_edge_to_publication_pending() -> void:
	var state := _admitted()
	var advanced: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"sequence_committed", &"publication_pending", {}, null, null,
		{"cursor": 0, "complete": false, "callback_receipts": {}})
	assert_true(advanced["ok"], JSON.stringify(advanced))
	var stage_candidate: Dictionary = advanced["value"]["stage_candidate"]
	assert_eq(stage_candidate["pending"]["stage"], &"publication_pending")
	assert_eq(stage_candidate["pending"]["checkpoint_receipt"], stage_candidate["pending"]["admission_checkpoint_receipt"],
		"the checkpoint_receipt still equals the admission receipt until a later advance rotates it")


func test_prepare_recovery_advance_rejects_stage_mismatch() -> void:
	var state := _admitted()
	var advanced: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"publication_pending", &"publication_pending", {}, null, null,
		{"cursor": 0, "complete": false, "callback_receipts": {}})
	assert_false(advanced.get("ok", true))
	assert_eq(advanced["code"], &"consequence_stage_mismatch")


func test_prepare_recovery_advance_terminal_cleanup_requires_complete_cursor() -> void:
	var state := _admitted()
	var to_pending: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"sequence_committed", &"publication_pending", {}, null, null,
		{"cursor": 0, "complete": false, "callback_receipts": {}})
	state.commit({"kind": &"recovery_advance", "state_after": to_pending["value"]["stage_candidate"]})
	var incomplete_cleanup: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"publication_pending", null, {}, null, null, null)
	assert_false(incomplete_cleanup.get("ok", true))
	assert_eq(incomplete_cleanup["code"], &"consequence_publication_cursor_incomplete")

	var to_complete: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"publication_pending", &"publication_pending", {}, null, null,
		{"cursor": 1, "complete": true, "callback_receipts": {"notify": {}}})
	state.commit({"kind": &"recovery_advance", "state_after": to_complete["value"]["stage_candidate"]})
	var cleanup: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"publication_pending", null, {}, null, null, null)
	assert_true(cleanup["ok"], JSON.stringify(cleanup))
	assert_eq(cleanup["value"]["stage_candidate"]["pending"], null)


func test_checkpoint_content_preimage_omits_admission_receipt_only_at_admission() -> void:
	var state := _bootstrapped()
	var payload := _action_recovery_payload("minesweeper_round")
	var prepared: Dictionary = state.prepare_action_handoff(_action_receipt("minesweeper_round"), 0, payload)
	state.commit(prepared["value"]["candidate"])
	var receipt := _causal_sequence_receipt(state, "minesweeper_round", "txn-1")
	var reserved: Dictionary = state.prepare_sequence_reservation(
		{"transaction_id": "txn-1", "source_kind": "minesweeper_round"}, receipt)
	var candidate_state: Dictionary = reserved["value"]["candidate"]["state_after"]
	# At admission time the candidate's admission_checkpoint_receipt is still null; the preimage
	# must omit that key entirely rather than embed a null placeholder.
	var header := {
		"kind": &"consequence_admission", "operation_ordinal": 0, "run_id": "run-1",
		"source_ids": ["b", "a"], "stage": "sequence_committed", "transaction_id": "txn-1",
	}
	var preimage: Dictionary = _STATE_SCRIPT.checkpoint_content_preimage(header, candidate_state)
	assert_true(preimage["ok"], JSON.stringify(preimage))
	var pending_preimage: Dictionary = preimage["value"]["preimage"]["stage_candidate"]["pending"]
	assert_false(pending_preimage.has("admission_checkpoint_receipt"),
		"the admission preimage must omit the not-yet-produced admission receipt")
	assert_eq(preimage["value"]["preimage"]["header"]["source_ids"], ["a", "b"], "source_ids must be lexically sorted")

	var admitted := _admitted()
	var later_advance: Dictionary = admitted.prepare_recovery_advance(
		"txn-1", &"sequence_committed", &"publication_pending", {}, null, null,
		{"cursor": 0, "complete": false, "callback_receipts": {}})
	var later_state: Dictionary = later_advance["value"]["stage_candidate"]
	var later_preimage: Dictionary = _STATE_SCRIPT.checkpoint_content_preimage(header, later_state)
	assert_true(later_preimage["ok"], JSON.stringify(later_preimage))
	assert_true((later_preimage["value"]["preimage"]["stage_candidate"]["pending"] as Dictionary)
		.has("admission_checkpoint_receipt"), "every later preimage retains the admission receipt")
	assert_eq((later_preimage["value"]["preimage"]["stage_candidate"]["pending"] as Dictionary)["checkpoint_receipt"], null,
		"the current checkpoint_receipt is always nulled in the preimage")


func test_prepare_outbox_publication_toggles_exactly_one_bit() -> void:
	var state := _bootstrapped()
	var seeded: Dictionary = state.capture()["value"]["state"]
	seeded["outbox"] = {
		"notification": {
			"key": "notify-1", "payload_hash": _sha256({"a": 1}), "provenance": {"x": 1},
			"consumer": "day_advance", "status": "pending",
		},
	}
	var prepared_restore: Dictionary = state.prepare_restore(seeded)
	state.commit(prepared_restore["value"]["candidate"])

	var published: Dictionary = state.prepare_outbox_publication({
		"kind": "notification", "key": "notify-1", "payload_hash": _sha256({"a": 1}),
		"provenance": {"x": 1}, "consumer": "day_advance",
	})
	assert_true(published["ok"], JSON.stringify(published))
	var committed: Dictionary = state.commit(published["value"]["candidate"])
	assert_eq(committed["value"]["state"]["outbox"]["notification"]["status"], "published")

	var replay: Dictionary = state.prepare_outbox_publication({
		"kind": "notification", "key": "notify-1", "payload_hash": _sha256({"a": 1}),
		"provenance": {"x": 1}, "consumer": "day_advance",
	})
	assert_false(replay.get("ok", true), "an already-published outbox entry cannot be re-toggled")


func test_prepare_outbox_publication_rejects_wrong_payload_hash() -> void:
	var state := _bootstrapped()
	var seeded: Dictionary = state.capture()["value"]["state"]
	seeded["outbox"] = {
		"hospital": {
			"key": "hospital-1", "payload_hash": _sha256({"a": 1}), "provenance": {},
			"consumer": "condition_hospital", "status": "pending",
		},
	}
	var prepared_restore: Dictionary = state.prepare_restore(seeded)
	state.commit(prepared_restore["value"]["candidate"])
	var wrong: Dictionary = state.prepare_outbox_publication({
		"kind": "hospital", "key": "hospital-1", "payload_hash": _sha256({"a": 2}),
		"provenance": {}, "consumer": "condition_hospital",
	})
	assert_false(wrong.get("ok", true))
	assert_eq(wrong["code"], &"outbox_payload_hash_mismatch")


func test_commit_is_a_transaction_ledger_via_restore_replay() -> void:
	var state := _bootstrapped()
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance("causal-day-2"))
	var prepared: Dictionary = state.prepare_restore(made["value"]["state"])
	var first: Dictionary = state.commit(prepared["value"]["candidate"])
	assert_true(first["ok"])
	assert_eq(first["value"]["state"]["causal_day_instance"], "causal-day-2")


func test_rollback_restores_the_captured_backup() -> void:
	var state := _bootstrapped()
	var backup: Dictionary = state.capture()
	var payload := _action_recovery_payload("minesweeper_round")
	var prepared: Dictionary = state.prepare_action_handoff(_action_receipt("minesweeper_round"), 0, payload)
	state.commit(prepared["value"]["candidate"])
	assert_true(state.capture()["value"]["state"]["pending"] != null)
	var rolled: Dictionary = state.rollback(backup["value"])
	assert_true(rolled["ok"], JSON.stringify(rolled))
	assert_eq(rolled["value"]["restored"], true)
	assert_eq(state.capture()["value"]["state"]["pending"], null)


func test_validate_recovery_payload_rejects_hash_mismatch() -> void:
	var payload := _action_recovery_payload("shop_purchase")
	var wrong: Dictionary = _STATE_SCRIPT.validate_recovery_payload(&"shop_purchase", payload, "0".repeat(64))
	assert_false(wrong.get("ok", true))
	assert_eq(wrong["code"], &"recovery_payload_hash_mismatch")
	var correct: Dictionary = _STATE_SCRIPT.validate_recovery_payload(&"shop_purchase", payload, _sha256(payload))
	assert_true(correct["ok"], JSON.stringify(correct))


func test_validate_recovery_payload_rejects_wrong_source_kind_shape() -> void:
	var action_payload := _action_recovery_payload("minesweeper_round")
	var wrong: Dictionary = _STATE_SCRIPT.validate_recovery_payload(
		&"schedule_done", action_payload, _sha256(action_payload))
	assert_false(wrong.get("ok", true), "an action-shaped payload cannot validate as schedule_done")
