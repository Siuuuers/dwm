extends "res://addons/gut/test.gd"

## Dedicated outbox-publication-transition coverage for DesktopConsequenceState (Plan 02 Task 6,
## dwm-p2r.32), complementing test_desktop_consequence_state.gd's broader suite: every outbox kind,
## the "cannot run while pending" boundary, and the outbox's own structural validation via
## DesktopConsequenceState.validate() (the "three exact key/record/publication unions" the brief
## requires -- here at the consequence-state layer, distinct from DesktopPublicationLedger's own).

const _STATE_SCRIPT := preload("res://scripts/domain/desktop/DesktopConsequenceState.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

func _issuer_receipt(token: String) -> Dictionary:
	return {"receipt_id": "issuer_receipt.fixture-" + token, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 5, "token": token, "numeric_value": null}

func _provenance() -> Dictionary:
	return {"causal_day_instance": "causal-day-1", "causal_day_instance_issuer_receipt": _issuer_receipt("causal-day-1")}

func _sha256(value: Variant) -> String:
	var emitted: Dictionary = _CANONICAL_JSON.stringify(value)
	return str(emitted["value"]).sha256_text()

func _bootstrapped_with_outbox(outbox: Dictionary) -> RefCounted:
	var state := _STATE_SCRIPT.new()
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	var seeded: Dictionary = made["value"]["state"]
	seeded["outbox"] = outbox
	var prepared: Dictionary = state.prepare_restore(seeded)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed: Dictionary = state.commit(prepared["value"]["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	return state

func _outbox_entry(key: String, consumer: String, status: String = "pending") -> Dictionary:
	var payload := {"a": key}
	return {"key": key, "payload_hash": _sha256(payload), "provenance": {"source": key},
		"consumer": consumer, "status": status}


func test_both_outbox_kinds_toggle_independently() -> void:
	var outbox := {
		"notification": _outbox_entry("notify-1", "day_advance"),
		"hospital": _outbox_entry("hospital-1", "condition_hospital"),
	}
	var state := _bootstrapped_with_outbox(outbox)

	var published_notification: Dictionary = state.prepare_outbox_publication({
		"kind": "notification", "key": "notify-1", "payload_hash": _sha256({"a": "notify-1"}),
		"provenance": {"source": "notify-1"}, "consumer": "day_advance",
	})
	assert_true(published_notification.get("ok", false), JSON.stringify(published_notification))
	state.commit(published_notification["value"]["candidate"])
	var after_first: Dictionary = state.capture()["value"]["state"]
	assert_eq(after_first["outbox"]["notification"]["status"], "published")
	assert_eq(after_first["outbox"]["hospital"]["status"], "pending",
		"toggling one outbox kind never touches the other")

	var published_hospital: Dictionary = state.prepare_outbox_publication({
		"kind": "hospital", "key": "hospital-1", "payload_hash": _sha256({"a": "hospital-1"}),
		"provenance": {"source": "hospital-1"}, "consumer": "condition_hospital",
	})
	assert_true(published_hospital.get("ok", false), JSON.stringify(published_hospital))
	state.commit(published_hospital["value"]["candidate"])
	var after_second: Dictionary = state.capture()["value"]["state"]
	assert_eq(after_second["outbox"]["notification"]["status"], "published")
	assert_eq(after_second["outbox"]["hospital"]["status"], "published")


func test_publication_cannot_run_while_a_transaction_is_pending() -> void:
	var state := _bootstrapped_with_outbox({"notification": _outbox_entry("notify-1", "day_advance")})
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

	var rejected: Dictionary = state.prepare_outbox_publication({
		"kind": "notification", "key": "notify-1", "payload_hash": _sha256({"a": "notify-1"}),
		"provenance": {"source": "notify-1"}, "consumer": "day_advance",
	})
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"consequence_publication_requires_no_pending")


func test_publication_rejects_wrong_consumer_and_wrong_kind_and_absent_entry() -> void:
	var state := _bootstrapped_with_outbox({"notification": _outbox_entry("notify-1", "day_advance")})

	var wrong_consumer: Dictionary = state.prepare_outbox_publication({
		"kind": "notification", "key": "notify-1", "payload_hash": _sha256({"a": "notify-1"}),
		"provenance": {"source": "notify-1"}, "consumer": "wrong_consumer",
	})
	assert_false(wrong_consumer.get("ok", true))
	assert_eq(wrong_consumer["code"], &"outbox_consumer_mismatch")

	var absent_kind: Dictionary = state.prepare_outbox_publication({
		"kind": "hospital", "key": "notify-1", "payload_hash": _sha256({"a": "notify-1"}),
		"provenance": {"source": "notify-1"}, "consumer": "day_advance",
	})
	assert_false(absent_kind.get("ok", true))
	assert_eq(absent_kind["code"], &"outbox_entry_absent")

	var invalid_kind: Dictionary = state.prepare_outbox_publication({
		"kind": "day7_destination", "key": "notify-1", "payload_hash": _sha256({"a": "notify-1"}),
		"provenance": {"source": "notify-1"}, "consumer": "day_advance",
	})
	assert_false(invalid_kind.get("ok", true))
	assert_eq(invalid_kind["code"], &"outbox_kind_invalid",
		"only notification and hospital are registered outbox kinds")


func test_publication_rejects_a_request_that_is_not_a_true_bit_flip() -> void:
	# The request shape can only carry one boolean transition (pending -> published); there is no
	# field through which a caller could ask for anything else (e.g. published -> pending).
	var already_published := _outbox_entry("notify-1", "day_advance", "published")
	var state := _bootstrapped_with_outbox({"notification": already_published})
	var replay: Dictionary = state.prepare_outbox_publication({
		"kind": "notification", "key": "notify-1", "payload_hash": already_published["payload_hash"],
		"provenance": already_published["provenance"], "consumer": "day_advance",
	})
	assert_false(replay.get("ok", true))
	assert_eq(replay["code"], &"outbox_already_published")


# ---- Structural validation: DesktopConsequenceState.validate() is the sole owner of outbox shape ----

func test_validate_rejects_unregistered_outbox_kind() -> void:
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	var state: Dictionary = made["value"]["state"]
	state["outbox"] = {"day7_destination": _outbox_entry("x", "y")}
	var validated: Dictionary = _STATE_SCRIPT.validate(state)
	assert_false(validated.get("ok", true))
	assert_eq(validated["code"], &"outbox_kind_invalid")

func test_validate_rejects_malformed_outbox_entry_member_set() -> void:
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	var state: Dictionary = made["value"]["state"]
	var malformed := _outbox_entry("x", "y")
	malformed.erase("provenance")
	state["outbox"] = {"notification": malformed}
	var validated: Dictionary = _STATE_SCRIPT.validate(state)
	assert_false(validated.get("ok", true))
	assert_eq(validated["code"], &"outbox_entry_member_set_invalid")

func test_validate_rejects_unregistered_outbox_status() -> void:
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	var state: Dictionary = made["value"]["state"]
	var bad_status := _outbox_entry("x", "y")
	bad_status["status"] = "archived"
	state["outbox"] = {"notification": bad_status}
	var validated: Dictionary = _STATE_SCRIPT.validate(state)
	assert_false(validated.get("ok", true))
	assert_eq(validated["code"], &"outbox_status_invalid")

func test_empty_outbox_is_valid() -> void:
	var made: Dictionary = _STATE_SCRIPT.make_empty(_provenance())
	assert_eq(made["value"]["state"]["outbox"], {})
	assert_true(_STATE_SCRIPT.validate(made["value"]["state"]).get("ok", false))
