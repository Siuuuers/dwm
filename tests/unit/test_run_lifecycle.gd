extends "res://addons/gut/test.gd"

const LIFECYCLE_PATH := "res://scripts/domain/run/RunLifecycle.gd"
const RECEIPTS_PATH := "res://tests/support/DayResolutionReceiptFixtures.gd"

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
		"run_id": run_id, "day": day, "state": state,
		"active_resolution_plan": active_resolution_plan, "ending_plan": ending_plan,
	}
	for key in _desktop_fields():
		merged[key] = _desktop_fields()[key]
	return merged

func _fresh(run_id: String, day: int) -> RefCounted:
	var lifecycle: RefCounted = load(LIFECYCLE_PATH).new()
	lifecycle.reset(run_id, "branch-1", 0, "causal-day-1", _identity_allocation_receipt())
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
	lifecycle.reset("run-day7", "branch-1", 0, "causal-day-1", _identity_allocation_receipt())
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
	lifecycle.reset("run-restore", "branch-1", 0, "causal-day-1", _identity_allocation_receipt())
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
		"causal_day_instance_issuer_receipt", "day", "desktop_timeline_generation", "ending_plan",
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
	lifecycle.reset("run-x", "branch-1", 0, "causal-day-1", {"causal_day_instance_issuer_receipt": _issuer_receipt("wrong-token")})
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

func test_continuation_remap_seams_are_typed_not_implemented_skeletons() -> void:
	# Phase C of this worktree's phased-commit plan wires the real DesktopContinuationRemapper.
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle: RefCounted = load(LIFECYCLE_PATH).new()
	var prepared: Dictionary = lifecycle.prepare_continuation_remap("restore-txn-1", {})
	assert_false(prepared.get("ok", true))
	assert_eq(prepared["code"], &"not_implemented")
	var committed: Dictionary = lifecycle.commit_continuation_remap({})
	assert_false(committed.get("ok", true))
	assert_eq(committed["code"], &"not_implemented")
