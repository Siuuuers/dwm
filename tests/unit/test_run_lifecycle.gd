extends "res://addons/gut/test.gd"

const LIFECYCLE_PATH := "res://scripts/domain/run/RunLifecycle.gd"
const RECEIPTS_PATH := "res://tests/support/DayResolutionReceiptFixtures.gd"
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

func _lifecycle_exists() -> bool:
	return ResourceLoader.exists(LIFECYCLE_PATH, "Script")

## Plan 02 Task 6 (dwm-p2r.32): a fixed, self-consistent desktop identity pair for this suite's
## lifecycle-only fixtures. Structural self-consistency (purpose/token match) is all RunLifecycle
## itself checks; it has no root-store access to verify against.
func _issuer_receipt(token: String) -> Dictionary:
	return {"receipt_id": "issuer_receipt.fixture-" + token, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": token, "numeric_value": null}

func _identity_allocation_receipt(causal_day_instance: String = "causal-day-1") -> Dictionary:
	return {"causal_day_instance_issuer_receipt": _issuer_receipt(causal_day_instance)}

func _desktop_fields(causal_day_instance: String = "causal-day-1") -> Dictionary:
	return {
		"branch_id": "branch-1", "desktop_timeline_generation": 0,
		"causal_day_instance": causal_day_instance,
		"causal_day_instance_issuer_receipt": _issuer_receipt(causal_day_instance),
		"restore_provenance": null,
	}

func _lifecycle_dict(run_id: String, day: int, state: String, active_resolution_plan: Variant = null,
		ending_plan: Variant = null) -> Dictionary:
	var merged := {
		"run_id": run_id, "dark_mode": false, "day": day, "state": state,
		"active_resolution_plan": active_resolution_plan, "ending_plan": ending_plan,
	}
	for key in _desktop_fields():
		merged[key] = _desktop_fields()[key]
	return merged

func _fresh(run_id: String, day: int) -> RefCounted:
	var lifecycle: RefCounted = load(LIFECYCLE_PATH).new()
	lifecycle.reset(run_id, "branch-1", 0, "causal-day-1", _identity_allocation_receipt(), false)
	var restored: Dictionary = lifecycle.prepare_restore(_lifecycle_dict(run_id, day, "PLAYING"))
	assert_true(restored.get("ok", false), JSON.stringify(restored))
	assert_true(lifecycle.commit_restore(restored["value"]["candidate"])["ok"])
	return lifecycle

func _drive_to_completion(lifecycle: RefCounted, source_day: int) -> Array[String]:
	var receipts_script: Script = load(RECEIPTS_PATH)
	var visited: Array[String] = []
	while lifecycle.resume_resolution()["value"]["has_stage"]:
		var begun: Dictionary = lifecycle.begin_next_stage()
		var stage: Dictionary = begun["value"]["stage"]
		visited.append(stage["stage_id"])
		var receipt: Dictionary = receipts_script.call(&"for_stage", stage["stage_id"], source_day)
		assert_true(lifecycle.complete_active_stage(stage["transaction_id"], receipt)["ok"],
			str(stage["stage_id"]))
	return visited

func test_day7_enters_ending_without_day8_or_rollover_stage() -> void:
	assert_true(ResourceLoader.exists(LIFECYCLE_PATH, "Script"), "RunLifecycle must exist")
	if not ResourceLoader.exists(LIFECYCLE_PATH, "Script"):
		return
	assert_true(ResourceLoader.exists(RECEIPTS_PATH, "Script"), "receipt fixtures must exist")
	if not ResourceLoader.exists(RECEIPTS_PATH, "Script"):
		return
	var lifecycle_script: Script = load(LIFECYCLE_PATH)
	var receipts_script: Script = load(RECEIPTS_PATH)
	var lifecycle: RefCounted = lifecycle_script.new()
	lifecycle.reset("run-day7", "branch-1", 0, "causal-day-1", _identity_allocation_receipt(), false)
	var restored: Dictionary = lifecycle.prepare_restore(_lifecycle_dict("run-day7", 7, "PLAYING"))
	assert_true(restored["ok"], JSON.stringify(restored))
	assert_true(lifecycle.commit_restore(restored["value"]["candidate"])["ok"])
	assert_true(lifecycle.begin_day_resolution("resolution-day7", {"entries": []})["ok"])

	var visited: Array[String] = []
	while lifecycle.resume_resolution()["value"]["has_stage"]:
		var begun: Dictionary = lifecycle.begin_next_stage()
		var stage: Dictionary = begun["value"]["stage"]
		visited.append(stage["stage_id"])
		var receipt: Dictionary = receipts_script.call(&"for_stage", stage["stage_id"], 7)
		assert_true(lifecycle.complete_active_stage(
			stage["transaction_id"], receipt
		)["ok"])

	# Plan 01 Task 7 (dwm-p2r.14): a Day-7 resolution ENDS at the checkpointed provenance handoff.
	# It no longer selects an ending or enters ENDING -- dwm-oyo.6 owns the ordered ending plan and
	# consumes this handoff. The run therefore stays PLAYING on day 7, with no Day 8.
	assert_eq(lifecycle.get_day(), 7)
	assert_eq(lifecycle.get_state(), &"PLAYING",
		"Day-7 resolution stops at the provenance handoff and never enters ENDING itself")
	assert_eq(visited.back(), "checkpoint_day7_provenance",
		"the walk ends at the provenance checkpoint")
	assert_false("increment_day" in visited)
	assert_false("invitation_rollover" in visited)
	assert_false("twofriends_if_deferred" in visited)
	for forbidden: String in ["resolve_ending_plan", "enter_ending", "ending_autosave"]:
		assert_false(forbidden in visited, forbidden + " is not a Plan-01 Day-7 stage")
	assert_eq(lifecycle.to_dict()["ending_plan"], null,
		"no ending plan is constructed by a Plan-01 Day-7 resolution")

func test_day3_full_resolution_increments_exactly_once() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-day3", 3)
	assert_true(lifecycle.begin_day_resolution("resolution-day3", {"entries": []})["ok"])
	var visited := _drive_to_completion(lifecycle, 3)
	assert_eq(visited.find("hospital_if_triggered") < visited.find("twofriends_if_deferred"), true,
		"hospital precedes twofriends")
	assert_eq(visited.find("invitation_rollover") < visited.find("increment_day"), true,
		"rollover precedes increment_day")
	assert_eq(visited.count("increment_day"), 1)
	assert_eq(lifecycle.get_day(), 4, "increment_day changes day exactly once")
	assert_eq(lifecycle.get_state(), &"PLAYING")
	assert_false(lifecycle.resume_resolution()["value"]["has_stage"], "plan complete")

func test_repeated_done_reuses_plan_and_conflict_rejects() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-reuse", 2)
	assert_true(lifecycle.begin_day_resolution("resolution-a", {"entries": []})["ok"])
	var reused: Dictionary = lifecycle.begin_day_resolution("resolution-a", {"entries": []})
	assert_true(reused.get("ok", false), "same resolution_id reuses the active plan")
	var conflict: Dictionary = lifecycle.begin_day_resolution("resolution-b", {"entries": []})
	assert_false(conflict.get("ok", true))
	assert_eq(conflict["code"], &"resolution_conflict")

func test_restore_rejects_invalid_shapes() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle: RefCounted = load(LIFECYCLE_PATH).new()
	lifecycle.reset("run-restore", "branch-1", 0, "causal-day-1", _identity_allocation_receipt(), false)
	for day: int in [0, 8, 9]:
		var rejected: Dictionary = lifecycle.prepare_restore(_lifecycle_dict("run-restore", day, "PLAYING"))
		assert_false(rejected.get("ok", true), "day %d rejects" % day)
	assert_false(lifecycle.prepare_restore(_lifecycle_dict("run-restore", 3, "SLEEPING")).get("ok", true),
		"invalid state rejects")
	assert_false(lifecycle.prepare_restore(_lifecycle_dict("run-restore", 7, "ENDING")).get("ok", true),
		"ENDING without ending plan rejects")
	var with_extra := _lifecycle_dict("run-restore", 3, "PLAYING")
	with_extra["extra"] = 1
	assert_false(lifecycle.prepare_restore(with_extra).get("ok", true), "unknown key rejects")
	# Desktop-identity structural rejections (Plan 02 Task 6): blank branch_id, ID-only/mismatched
	# causal_day_instance_issuer_receipt.
	var blank_branch := _lifecycle_dict("run-restore", 3, "PLAYING")
	blank_branch["branch_id"] = ""
	assert_false(lifecycle.prepare_restore(blank_branch).get("ok", true), "blank branch_id rejects")
	var mismatched_receipt := _lifecycle_dict("run-restore", 3, "PLAYING")
	mismatched_receipt["causal_day_instance_issuer_receipt"] = _issuer_receipt("some-other-token")
	assert_false(lifecycle.prepare_restore(mismatched_receipt).get("ok", true),
		"causal_day_instance_issuer_receipt.token must equal causal_day_instance")
	var untouched: Dictionary = lifecycle.to_dict()
	assert_eq(untouched["day"], 1, "failed prepare_restore never mutates")

func test_rollover_receipt_must_target_next_day() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-rollover", 5)
	assert_true(lifecycle.begin_day_resolution("resolution-rollover", {"entries": []})["ok"])
	var receipts_script: Script = load(RECEIPTS_PATH)
	while true:
		var cursor: Dictionary = lifecycle.resume_resolution()["value"]
		if not cursor["has_stage"]:
			break
		var begun: Dictionary = lifecycle.begin_next_stage()
		var stage: Dictionary = begun["value"]["stage"]
		if stage["stage_id"] == "invitation_rollover":
			var wrong: Dictionary = {"value": {"target_day": 5}}
			assert_false(lifecycle.complete_active_stage(stage["transaction_id"], wrong).get("ok", true),
				"rollover target must equal source_day + 1")
			break
		assert_true(lifecycle.complete_active_stage(stage["transaction_id"],
			receipts_script.call(&"for_stage", stage["stage_id"], 5))["ok"])

func test_ending_playback_edges_and_terminal_completed() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-ending", 7)
	# Task 7 decoupled ENDING from the Day-7 stage walk, but the ENDING machinery itself is
	# UNCHANGED and still owns playback (Task 8 Step 8.7 forbids editing it). Enter it directly so
	# this suite keeps proving the playback edges without depending on a removed stage.
	var entered: Dictionary = lifecycle.enter_ending(
		load(RECEIPTS_PATH).call(&"ending_plan"))
	assert_true(entered.get("ok", false), JSON.stringify(entered))
	assert_eq(lifecycle.get_state(), &"ENDING")
	assert_false(lifecycle.complete_ending().get("ok", true), "complete_ending requires GALLERY_RECORDED")
	var receipts_script: Script = load(RECEIPTS_PATH)
	for expected: String in ["PRIMARY_PENDING", "PRIMARY_PLAYED", "EPILOGUE_PLAYED"]:
		var advanced: Dictionary = lifecycle.complete_ending_playback_stage(
			"ending:" + expected, StringName(expected), receipts_script.call(&"playback_receipt", expected))
		assert_true(advanced.get("ok", false), expected + ": " + JSON.stringify(advanced))
	assert_false(lifecycle.complete_ending_playback_stage(
		"ending:PRIMARY_PENDING", &"PRIMARY_PENDING",
		receipts_script.call(&"playback_receipt", "PRIMARY_PENDING")).get("ok", true),
		"stale playback edge rejects")
	assert_true(lifecycle.complete_ending()["ok"])
	assert_eq(lifecycle.get_state(), &"COMPLETED")
	assert_eq(lifecycle.get_day(), 7, "COMPLETED retains day 7")
	assert_false(lifecycle.begin_day_resolution("resolution-after", {"entries": []}).get("ok", true),
		"COMPLETED cannot re-enter gameplay")
	var snapshot: Dictionary = lifecycle.to_dict()
	assert_eq(snapshot["state"], "COMPLETED")
	assert_false(snapshot["ending_plan"] == null, "COMPLETED retains the ending plan")

func test_to_dict_shape_is_exact() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-shape", 3)
	var snapshot: Dictionary = lifecycle.to_dict()
	var keys := snapshot.keys()
	keys.sort()
	assert_eq(keys, ["active_resolution_plan", "branch_id", "causal_day_instance",
		"causal_day_instance_issuer_receipt", "dark_mode", "day", "desktop_timeline_generation", "ending_plan",
		"restore_provenance", "run_id", "state"])
	assert_eq(snapshot["run_id"], "run-shape")
	assert_eq(snapshot["day"], 3)
	assert_eq(snapshot["state"], "PLAYING")
	assert_true(snapshot["active_resolution_plan"] == null, "no active plan serialized")
	assert_true(snapshot["ending_plan"] == null, "no ending plan serialized")
	assert_eq(snapshot["branch_id"], "branch-1")
	assert_eq(snapshot["desktop_timeline_generation"], 0)
	assert_eq(snapshot["causal_day_instance"], "causal-day-1")
	assert_eq(snapshot["restore_provenance"], null)

func test_reset_rejects_id_only_or_mismatched_provenance_downstream() -> void:
	# reset() itself is void (no envelope) and never validates -- the actual enforcement point is
	# prepare_restore()/RunSnapshotSchema against this object's own to_dict() output (brief line
	# 203's provenance-pairing law). Prove that path here.
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle: RefCounted = load(LIFECYCLE_PATH).new()
	lifecycle.reset("run-x", "branch-1", 0, "causal-day-1", {"causal_day_instance_issuer_receipt": _issuer_receipt("wrong-token")}, false)
	var snapshot: Dictionary = lifecycle.to_dict()
	assert_false(lifecycle.prepare_restore(snapshot).get("ok", true),
		"a token-mismatched receipt installed via reset() fails downstream at prepare_restore")

func test_get_desktop_identity_context_shape() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-context", 2)
	var context: Dictionary = lifecycle.get_desktop_identity_context()
	var keys := context.keys()
	keys.sort()
	assert_eq(keys, ["branch_id", "causal_day_instance", "causal_day_instance_issuer_receipt",
		"desktop_timeline_generation", "run_id"])
	assert_eq(context["run_id"], "run-context")
	assert_eq(context["branch_id"], "branch-1")
	assert_eq(context["causal_day_instance"], "causal-day-1")

## Task 6 Phase C: a well-formed enriched identity_allocation_bundle, matching exactly what
## DesktopIdentityAllocationRestoreParticipant is documented to hand RunLifecycle -- the raw
## continuation-allocation identity plus the one continuation_operation remap receipt.
func _remap_bundle(run_id: String, causal_day_instance: String = "causal-day-2") -> Dictionary:
	return {
		"run_id": run_id,
		"allocation_receipt_id": "issuer_receipt.fixture-allocation-1",
		"branch_id": "branch-2",
		"desktop_timeline_generation": 1,
		"causal_day_instance": causal_day_instance,
		"causal_day_instance_issuer_receipt": _issuer_receipt(causal_day_instance),
		"remap_receipt_id": "continuation_operation.fixture-remap-1",
		"remap_receipt_provenance": {"parent_receipt_id": "transaction_id.fixture-restore-1",
			"child_kind": "continuation_operation", "ordinal": 0, "source_ids": [], "schema_version": 1,
			"child_id": "continuation_operation.fixture-remap-1"},
		"transaction_remap": {"old-tx-1": {"source_transaction_id": "old-tx-1",
			"new_transaction_id": "new-tx-1", "new_transaction_issuer_receipt": {}}},
	}

func test_continuation_remap_installs_the_new_identity_and_provenance() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-remap", 3)
	var bundle := _remap_bundle("run-remap")
	var prepared: Dictionary = lifecycle.prepare_continuation_remap("restore-txn-1", bundle)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var candidate: Dictionary = prepared["value"]["candidate"]
	assert_eq(candidate["run_id"], "run-remap", "restore never changes run_id")
	assert_eq(candidate["branch_id"], "branch-2")
	assert_eq(candidate["desktop_timeline_generation"], 1)
	assert_eq(candidate["causal_day_instance"], "causal-day-2")
	assert_eq((candidate["causal_day_instance_issuer_receipt"] as Dictionary)["token"], "causal-day-2")
	var provenance: Dictionary = candidate["restore_provenance"]
	assert_eq(provenance["source_branch_id"], "branch-1", "provenance records the PRE-remap identity")
	assert_eq(provenance["source_desktop_timeline_generation"], 0)
	assert_eq(provenance["source_causal_day_instance"], "causal-day-1")
	assert_eq(provenance["source_issuer_observed_counter"], 1)
	assert_eq(provenance["restore_transaction_id"], "restore-txn-1")
	assert_eq(provenance["identity_allocation_receipt_id"], "issuer_receipt.fixture-allocation-1")
	assert_eq(provenance["remap_receipt_id"], "continuation_operation.fixture-remap-1")
	assert_eq(provenance["remap_receipt_provenance"], bundle["remap_receipt_provenance"])
	var canonical: Dictionary = _CANONICAL_JSON.stringify(bundle["transaction_remap"])
	assert_true(canonical.get("ok", false))
	var expected_hash: String = str(canonical["value"]).sha256_text()
	assert_eq(provenance["transaction_remap_sha256"], expected_hash,
		"the hash is recomputed canonically from transaction_remap, never trusted from the caller")

	var committed: Dictionary = lifecycle.commit_continuation_remap(candidate)
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	var context: Dictionary = lifecycle.get_desktop_identity_context()
	assert_eq(context["branch_id"], "branch-2")
	assert_eq(context["causal_day_instance"], "causal-day-2")
	assert_eq(lifecycle.to_dict()["restore_provenance"]["restore_transaction_id"], "restore-txn-1")

func test_continuation_remap_rejects_a_bundle_for_a_different_run() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-remap-2", 3)
	var rejected: Dictionary = lifecycle.prepare_continuation_remap("restore-txn-2", _remap_bundle("some-other-run"))
	assert_false(rejected.get("ok", true), "a bundle for a different run_id must reject")
	assert_eq(rejected["code"], &"identity_allocation_run_id_mismatch")
	assert_eq(lifecycle.to_dict()["run_id"], "run-remap-2", "a rejected prepare never mutates")

func test_continuation_remap_rejects_a_blank_restore_transaction_id() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-remap-3", 3)
	var rejected: Dictionary = lifecycle.prepare_continuation_remap("", _remap_bundle("run-remap-3"))
	assert_false(rejected.get("ok", true))
	assert_eq(rejected["code"], &"invalid_restore_transaction_id")

func test_continuation_remap_rejects_an_incomplete_bundle() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-remap-4", 3)
	for missing: String in ["allocation_receipt_id", "branch_id", "causal_day_instance",
			"causal_day_instance_issuer_receipt", "desktop_timeline_generation", "remap_receipt_id",
			"remap_receipt_provenance", "run_id", "transaction_remap"]:
		var incomplete := _remap_bundle("run-remap-4")
		incomplete.erase(missing)
		var rejected: Dictionary = lifecycle.prepare_continuation_remap("restore-txn-4", incomplete)
		assert_false(rejected.get("ok", true), "a bundle missing " + missing + " must reject")
		assert_eq(rejected["code"], &"invalid_identity_allocation_bundle", missing)
