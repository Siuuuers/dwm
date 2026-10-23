extends "res://addons/gut/test.gd"

const PARTICIPANT_PATH := "res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd"
const CONSEQUENCE_STATE_PATH := "res://scripts/domain/desktop/DesktopConsequenceState.gd"

func _exists() -> bool:
	return ResourceLoader.exists(PARTICIPANT_PATH, "Script")

func _issuer_provenance(causal_day_instance: String = "causal-day-1") -> Dictionary:
	return {"causal_day_instance": causal_day_instance, "causal_day_instance_issuer_receipt": {
		"receipt_id": "issuer_receipt.fixture-" + causal_day_instance, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": causal_day_instance, "numeric_value": null}}

func _fresh_state() -> Object:
	return load(CONSEQUENCE_STATE_PATH).new()

func _participant(state: Object) -> RefCounted:
	return load(PARTICIPANT_PATH).new(state)

func test_participant_exists() -> void:
	assert_true(_exists(), "DesktopConsequenceRestoreParticipant.gd must exist")

func test_prepare_rejects_missing_or_invalid_state() -> void:
	if not _exists(): return
	var participant := _participant(_fresh_state())
	assert_false(participant.prepare({}).get("ok", true), "missing input.state rejects")
	assert_false(participant.prepare({"state": {"garbage": true}}).get("ok", true), "an invalid state rejects")

func test_prepare_capture_apply_and_rollback_round_trip() -> void:
	if not _exists(): return
	var state := _fresh_state()
	var empty: Dictionary = state.call("make_empty", _issuer_provenance())
	assert_true(empty.get("ok", false), JSON.stringify(empty))
	var initial_state: Dictionary = (empty["value"] as Dictionary)["state"]
	# Establish the live baseline (make_empty() is a pure static builder; it never touches `state`
	# on its own) before this round trip's own capture(), so the backup actually matches
	# initial_state rather than the object's raw, still-uninitialized construction defaults.
	var restored_initial: Dictionary = state.prepare_restore(initial_state)
	assert_true(restored_initial.get("ok", false), JSON.stringify(restored_initial))
	assert_true(state.commit((restored_initial["value"] as Dictionary)["candidate"]).get("ok", false))

	var participant := _participant(state)
	var captured: Dictionary = participant.capture()
	assert_true(captured.get("ok", false), JSON.stringify(captured))
	var backup: Dictionary = captured["value"]

	var target_state: Dictionary = initial_state.duplicate(true)
	target_state["run_revision"] = 5
	var prepared: Dictionary = participant.prepare({"state": target_state})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var plan: Dictionary = (prepared["value"] as Dictionary)["consequence_plan"]

	var applied: Dictionary = participant.apply_silent(plan)
	assert_true(applied.get("ok", false), JSON.stringify(applied))
	assert_eq(state.capture()["value"]["state"]["run_revision"], 5)

	var finalized: Dictionary = participant.finalize()
	assert_true(finalized.get("ok", false))

	var rolled: Dictionary = participant.rollback_silent(backup)
	assert_true(rolled.get("ok", false), JSON.stringify(rolled))
	assert_eq(state.capture()["value"]["state"], initial_state, "rollback restores the exact captured state")

func test_apply_silent_rejects_a_malformed_plan() -> void:
	if not _exists(): return
	var participant := _participant(_fresh_state())
	assert_false(participant.apply_silent({}).get("ok", true), "apply_silent requires plan.state")

func test_apply_silent_never_publishes_the_outbox() -> void:
	# Silent by design (brief line 382): a restore apply must never toggle a pending outbox entry --
	# only prepare_outbox_publication() (a completely separate seam this participant never calls)
	# does that, and outbox stays byte-identical to whatever the candidate state already carried.
	if not _exists(): return
	var state := _fresh_state()
	var empty: Dictionary = state.call("make_empty", _issuer_provenance())
	var initial_state: Dictionary = (empty["value"] as Dictionary)["state"]
	var participant := _participant(state)
	var prepared: Dictionary = participant.prepare({"state": initial_state})
	assert_true(prepared.get("ok", false))
	participant.apply_silent((prepared["value"] as Dictionary)["consequence_plan"])
	assert_eq(state.capture()["value"]["state"]["outbox"], {}, "no outbox mutation happens on restore apply")
