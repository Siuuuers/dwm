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


func _admitted_schedule(transaction_id: String = "txn-sched-1") -> RefCounted:
	var state := _bootstrapped()
	var payload := {
		"source_kind": "schedule_done", "schedule_header": {"day": 1}, "run_revision_before": 0,
		"participant_snapshot_ids": {},
	}
	var prepared: Dictionary = state.prepare_schedule_recovery_transport(_schedule_header(transaction_id), payload)
	state.commit(prepared["value"]["candidate"])
	var receipt := _causal_sequence_receipt(state, "schedule_done", transaction_id)
	var reserved: Dictionary = state.prepare_sequence_reservation(
		{"transaction_id": transaction_id, "source_kind": "schedule_done"}, receipt)
	if not reserved.get("ok", false):
		push_error("prepare_sequence_reservation failed: " + JSON.stringify(reserved))
		return state
	var candidate_state: Dictionary = reserved["value"]["candidate"]["state_after"]
	var admission_receipt := {"checkpoint_id": "chk-sched-1", "sequence": 1}
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


## IMPORTANT 3(a): the class doc comment claims commit() is a transaction-id ledger, but until this
## fix _command_receipts was written nowhere and commit() adopted unconditionally -- a byte-identical
## replay of an already-committed action_handoff would have fallen through to stale_run_revision
## instead of replaying, since run_revision hadn't moved but the candidate's pre_run_revision now
## disagrees with nothing (action_handoff never touches run_revision) -- so prove replay explicitly.
func test_commit_is_a_transaction_ledger_for_action_handoff_replay() -> void:
	var state := _bootstrapped()
	var payload := _action_recovery_payload("minesweeper_round")
	var prepared: Dictionary = state.prepare_action_handoff(_action_receipt("minesweeper_round"), 0, payload)
	assert_true(prepared["ok"], JSON.stringify(prepared))
	var candidate: Dictionary = prepared["value"]["candidate"]
	var first: Dictionary = state.commit(candidate)
	assert_true(first["ok"], JSON.stringify(first))

	var replay: Dictionary = state.commit(candidate)
	assert_true(replay["ok"], JSON.stringify(replay))
	assert_eq(replay, first, "an identical replay returns the exact stored result, not a fresh re-adoption")


func test_commit_rejects_changed_bytes_at_an_occupied_ledger_key() -> void:
	var state := _bootstrapped()
	var payload := _action_recovery_payload("minesweeper_round")
	var prepared: Dictionary = state.prepare_action_handoff(_action_receipt("minesweeper_round"), 0, payload)
	state.commit(prepared["value"]["candidate"])

	# Same ledger key (transaction_id + kind), but a fingerprint that does not match what was
	# actually committed: a caller resubmitting the SAME operation with different bytes.
	var tampered: Dictionary = (prepared["value"]["candidate"] as Dictionary).duplicate(true)
	tampered["request_fingerprint"] = "0".repeat(64)
	var conflicted: Dictionary = state.commit(tampered)
	assert_false(conflicted.get("ok", true))
	assert_eq(conflicted["code"], &"consequence_command_conflict")


## IMPORTANT 3(b): prepare_recovery_advance()'s checkpoint_header previously hardcoded
## operation_ordinal=0 always (via unread _command_receipts.size()) and source_ids=[]. Prove the
## frozen per-source-kind ordinal table (plan02-frozen-contracts.md lines 127-132, 319-321) instead.
func test_prepare_recovery_advance_ordinary_edge_operation_ordinal_matches_frozen_table() -> void:
	var action_state := _admitted("minesweeper_round", "txn-1")
	var action_advance: Dictionary = action_state.prepare_recovery_advance(
		"txn-1", &"sequence_committed", &"publication_pending", {}, null, null,
		{"cursor": 0, "complete": false, "callback_receipts": {}})
	assert_true(action_advance["ok"], JSON.stringify(action_advance))
	assert_eq(action_advance["value"]["checkpoint_header"]["operation_ordinal"], 8,
		"action-source publication_pending stage entry is frozen ordinal 8")
	assert_eq(action_advance["value"]["checkpoint_header"]["source_ids"], ["txn-1"],
		"source_ids honestly carries this checkpoint's own transaction, not an empty placeholder")

	var schedule_state := _admitted_schedule("txn-sched-1")
	var schedule_advance: Dictionary = schedule_state.prepare_recovery_advance(
		"txn-sched-1", &"sequence_committed", &"publication_pending", {}, null, null,
		{"cursor": 0, "complete": false, "callback_receipts": {}})
	assert_true(schedule_advance["ok"], JSON.stringify(schedule_advance))
	assert_eq(schedule_advance["value"]["checkpoint_header"]["operation_ordinal"], 6,
		"schedule_done publication_pending stage entry is frozen ordinal 6")


func test_prepare_recovery_advance_callback_progress_operation_ordinal_is_sequential() -> void:
	var state := _admitted("minesweeper_round", "txn-1")
	var to_pending: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"sequence_committed", &"publication_pending", {}, null, null,
		{"cursor": 0, "complete": false, "callback_receipts": {}})
	state.commit({"kind": &"recovery_advance", "state_after": to_pending["value"]["stage_candidate"]})

	# First appended callback (causal_sequence): cursor advances 0 -> 1, frozen ordinal 9.
	var progress1: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"publication_pending", &"publication_pending", {}, null, null,
		{"cursor": 1, "complete": false, "callback_receipts": {"causal_sequence": {}}})
	assert_true(progress1["ok"], JSON.stringify(progress1))
	assert_eq(progress1["value"]["checkpoint_header"]["operation_ordinal"], 9)
	state.commit({"kind": &"recovery_advance", "state_after": progress1["value"]["stage_candidate"]})

	# Second appended callback (action_source): cursor advances 1 -> 2, frozen ordinal 10.
	var progress2: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"publication_pending", &"publication_pending", {}, null, null,
		{"cursor": 2, "complete": true, "callback_receipts": {"causal_sequence": {}, "action_source": {}}})
	assert_true(progress2["ok"], JSON.stringify(progress2))
	assert_eq(progress2["value"]["checkpoint_header"]["operation_ordinal"], 10)


func test_prepare_recovery_advance_terminal_cleanup_operation_ordinal_is_twelve() -> void:
	var state := _admitted("minesweeper_round", "txn-1")
	var to_pending: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"sequence_committed", &"publication_pending", {}, null, null,
		{"cursor": 0, "complete": false, "callback_receipts": {}})
	state.commit({"kind": &"recovery_advance", "state_after": to_pending["value"]["stage_candidate"]})
	var to_complete: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"publication_pending", &"publication_pending", {}, null, null,
		{"cursor": 1, "complete": true, "callback_receipts": {"notify": {}}})
	state.commit({"kind": &"recovery_advance", "state_after": to_complete["value"]["stage_candidate"]})
	var cleanup: Dictionary = state.prepare_recovery_advance(
		"txn-1", &"publication_pending", null, {}, null, null, null)
	assert_true(cleanup["ok"], JSON.stringify(cleanup))
	# Terminal cleanup is the one ordinal shared by every source_kind (frozen table, both rows).
	assert_eq(cleanup["value"]["checkpoint_header"]["operation_ordinal"], 12)
	assert_eq(cleanup["value"]["checkpoint_header"]["source_ids"], ["txn-1"])


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


# -------------------------------------------------------------------------------------------------
# Task 7 (dwm-p2r.32.7): shop_ledger registration seam -- Supportz branch/day purchase record and
# current-causal-day base-completion receipts (controller ruling, bead addendum 9).
# -------------------------------------------------------------------------------------------------

func _completion(ordinal: int, causal_day_instance: String) -> Dictionary:
	return {"kind": "complete", "app_round_ordinal": ordinal, "causal_day_instance": causal_day_instance}


func test_make_empty_seeds_a_zeroed_shop_ledger() -> void:
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	var state: Dictionary = made["value"]["state"]
	assert_true(state.has("shop_ledger"), "shop_ledger is a top-level v4 consequence member")
	var ledger: Dictionary = state["shop_ledger"]
	assert_eq(int(ledger["supportz_branch_purchase_count"]), 0)
	assert_eq(str(ledger["supportz_last_purchase_causal_day_instance"]), "")
	assert_eq((ledger["base_completion_receipts"] as Array), [])
	assert_true(_STATE_SCRIPT.validate(state)["ok"])


func test_validate_rejects_extra_and_missing_shop_ledger_keys() -> void:
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	var state: Dictionary = made["value"]["state"]
	var missing := state.duplicate(true)
	missing.erase("shop_ledger")
	assert_false(_STATE_SCRIPT.validate(missing).get("ok", true), "missing shop_ledger must reject")

	var extra_top: Dictionary = state.duplicate(true)
	var bogus_ledger: Dictionary = (extra_top["shop_ledger"] as Dictionary).duplicate(true)
	bogus_ledger["bogus"] = 1
	extra_top["shop_ledger"] = bogus_ledger
	assert_false(_STATE_SCRIPT.validate(extra_top).get("ok", true), "extra shop_ledger member must reject")

	var missing_member: Dictionary = state.duplicate(true)
	var incomplete_ledger: Dictionary = (missing_member["shop_ledger"] as Dictionary).duplicate(true)
	incomplete_ledger.erase("base_completion_receipts")
	missing_member["shop_ledger"] = incomplete_ledger
	assert_false(_STATE_SCRIPT.validate(missing_member).get("ok", true), "missing shop_ledger member must reject")


func test_validate_rejects_a_malformed_base_completion_receipt() -> void:
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	var state: Dictionary = made["value"]["state"]
	var bad_ordinal: Dictionary = state.duplicate(true)
	var ledger: Dictionary = (bad_ordinal["shop_ledger"] as Dictionary).duplicate(true)
	ledger["base_completion_receipts"] = [_completion(3, "causal-day-1")]
	bad_ordinal["shop_ledger"] = ledger
	assert_false(_STATE_SCRIPT.validate(bad_ordinal).get("ok", true), "app_round_ordinal must be 1 or 2")

	var bad_kind: Dictionary = state.duplicate(true)
	var kind_ledger: Dictionary = (bad_kind["shop_ledger"] as Dictionary).duplicate(true)
	var entry := _completion(1, "causal-day-1")
	entry["kind"] = "incomplete"
	kind_ledger["base_completion_receipts"] = [entry]
	bad_kind["shop_ledger"] = kind_ledger
	assert_false(_STATE_SCRIPT.validate(bad_kind).get("ok", true), "kind must be complete")


func test_prepare_record_base_completion_appends_and_is_content_idempotent() -> void:
	var state := _bootstrapped()
	var first: Dictionary = state.prepare_record_base_completion(_completion(1, "causal-day-1"))
	assert_true(first.get("ok", false), JSON.stringify(first))
	var committed: Dictionary = state.commit((first["value"] as Dictionary)["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	var ledger: Dictionary = (committed["value"] as Dictionary)["state"]["shop_ledger"]
	assert_eq((ledger["base_completion_receipts"] as Array), [_completion(1, "causal-day-1")])

	# A byte-identical record is not appended twice.
	var replay: Dictionary = state.prepare_record_base_completion(_completion(1, "causal-day-1"))
	var replay_committed: Dictionary = state.commit((replay["value"] as Dictionary)["candidate"])
	var replay_ledger: Dictionary = (replay_committed["value"] as Dictionary)["state"]["shop_ledger"]
	assert_eq((replay_ledger["base_completion_receipts"] as Array).size(), 1, "duplicate content is not appended twice")

	var second: Dictionary = state.prepare_record_base_completion(_completion(2, "causal-day-1"))
	var second_committed: Dictionary = state.commit((second["value"] as Dictionary)["candidate"])
	var second_ledger: Dictionary = (second_committed["value"] as Dictionary)["state"]["shop_ledger"]
	assert_eq((second_ledger["base_completion_receipts"] as Array).size(), 2)


func test_prepare_record_base_completion_rejects_a_malformed_receipt() -> void:
	var state := _bootstrapped()
	var wrong_kind: Dictionary = state.prepare_record_base_completion({"kind": "incomplete",
		"app_round_ordinal": 1, "causal_day_instance": "causal-day-1"})
	assert_false(wrong_kind.get("ok", true))
	var wrong_ordinal: Dictionary = state.prepare_record_base_completion(_completion(3, "causal-day-1"))
	assert_false(wrong_ordinal.get("ok", true))
	var blank_day: Dictionary = state.prepare_record_base_completion(_completion(1, ""))
	assert_false(blank_day.get("ok", true))


func test_prepare_record_supportz_purchase_increments_count_and_sets_the_last_purchase_day() -> void:
	var state := _bootstrapped()
	var prepared: Dictionary = state.prepare_record_supportz_purchase("txn-supportz-1", "causal-day-1")
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed: Dictionary = state.commit((prepared["value"] as Dictionary)["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	var ledger: Dictionary = (committed["value"] as Dictionary)["state"]["shop_ledger"]
	assert_eq(int(ledger["supportz_branch_purchase_count"]), 1)
	assert_eq(str(ledger["supportz_last_purchase_causal_day_instance"]), "causal-day-1")


func test_prepare_record_supportz_purchase_is_idempotent_via_the_transaction_ledger() -> void:
	var state := _bootstrapped()
	var prepared: Dictionary = state.prepare_record_supportz_purchase("txn-supportz-1", "causal-day-1")
	var committed: Dictionary = state.commit((prepared["value"] as Dictionary)["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))

	var replay_prepared: Dictionary = state.prepare_record_supportz_purchase("txn-supportz-1", "causal-day-1")
	var replay: Dictionary = state.commit((replay_prepared["value"] as Dictionary)["candidate"])
	assert_eq(replay, committed, "an identical replay returns the stored result rather than incrementing again")

	var conflicting_prepared: Dictionary = state.prepare_record_supportz_purchase("txn-supportz-1", "causal-day-2")
	var conflicting: Dictionary = state.commit((conflicting_prepared["value"] as Dictionary)["candidate"])
	assert_false(conflicting.get("ok", true))
	assert_eq(conflicting.get("code"), &"consequence_command_conflict")


func test_supportz_eligibility_state_projects_the_capability_rules_exact_four_key_shape() -> void:
	var state := _bootstrapped()
	var base_1: Dictionary = state.prepare_record_base_completion(_completion(1, "causal-day-1"))
	state.commit((base_1["value"] as Dictionary)["candidate"])
	var base_2: Dictionary = state.prepare_record_base_completion(_completion(2, "causal-day-1"))
	state.commit((base_2["value"] as Dictionary)["candidate"])

	var projected: Dictionary = state.supportz_eligibility_state("causal-day-1")
	assert_true(projected.get("ok", false), JSON.stringify(projected))
	var value: Dictionary = projected["value"]["state"]
	var keys: Array = value.keys()
	keys.sort()
	assert_eq(keys, ["branch_purchase_count", "causal_day_instance", "completion_receipts", "daily_purchase_done"])
	assert_eq(str(value["causal_day_instance"]), "causal-day-1")
	assert_eq(int(value["branch_purchase_count"]), 0)
	assert_false(bool(value["daily_purchase_done"]))
	var receipts: Array = value["completion_receipts"]
	assert_eq(receipts.size(), 2)
	for receipt: Variant in receipts:
		var entry_keys: Array = (receipt as Dictionary).keys()
		entry_keys.sort()
		assert_eq(entry_keys, ["app_round_ordinal", "causal_day_instance", "kind"],
			"KNOWN CONSUMER CONTRACT: supportz_eligible() requires exactly these 3 keys")


func test_supportz_eligibility_state_filters_completions_by_causal_day() -> void:
	var state := _bootstrapped()
	var other_day: Dictionary = state.prepare_record_base_completion(_completion(1, "causal-day-other"))
	state.commit((other_day["value"] as Dictionary)["candidate"])
	var this_day: Dictionary = state.prepare_record_base_completion(_completion(1, "causal-day-1"))
	state.commit((this_day["value"] as Dictionary)["candidate"])

	var projected: Dictionary = state.supportz_eligibility_state("causal-day-1")
	var receipts: Array = (projected["value"] as Dictionary)["state"]["completion_receipts"]
	assert_eq(receipts.size(), 2, "both days' receipts are present; supportz_eligible() itself filters by day")


func test_supportz_eligibility_state_reflects_daily_purchase_done_after_a_recorded_purchase() -> void:
	var state := _bootstrapped()
	var prepared: Dictionary = state.prepare_record_supportz_purchase("txn-supportz-1", "causal-day-1")
	state.commit((prepared["value"] as Dictionary)["candidate"])
	var projected: Dictionary = state.supportz_eligibility_state("causal-day-1")
	assert_true(bool((projected["value"] as Dictionary)["state"]["daily_purchase_done"]))
	var other_day: Dictionary = state.supportz_eligibility_state("causal-day-2")
	assert_false(bool((other_day["value"] as Dictionary)["state"]["daily_purchase_done"]),
		"a different causal day is not marked done")
