extends "res://addons/gut/test.gd"

const LIFECYCLE_PATH := "res://scripts/domain/run/RunLifecycle.gd"
const RECEIPTS_PATH := "res://tests/support/DayResolutionReceiptFixtures.gd"

func _lifecycle_exists() -> bool:
	return ResourceLoader.exists(LIFECYCLE_PATH, "Script")

func _fresh(run_id: String, day: int) -> RefCounted:
	var lifecycle: RefCounted = load(LIFECYCLE_PATH).new()
	lifecycle.reset(run_id)
	var restored: Dictionary = lifecycle.prepare_restore({
		"run_id": run_id,
		"day": day,
		"state": "PLAYING",
		"active_resolution_plan": null,
		"ending_plan": null,
	})
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
	lifecycle.reset("run-day7")
	var restored: Dictionary = lifecycle.prepare_restore({
		"run_id": "run-day7",
		"day": 7,
		"state": "PLAYING",
		"active_resolution_plan": null,
		"ending_plan": null,
	})
	assert_true(restored["ok"], JSON.stringify(restored))
	assert_true(lifecycle.commit_restore(restored["value"]["candidate"])["ok"])
	assert_true(lifecycle.begin_day_resolution("resolution-day7", [])["ok"])

	var visited: Array[String] = []
	while lifecycle.resume_resolution()["value"]["has_stage"]:
		var begun: Dictionary = lifecycle.begin_next_stage()
		var stage: Dictionary = begun["value"]["stage"]
		visited.append(stage["stage_id"])
		var receipt: Dictionary = receipts_script.call(&"for_stage", stage["stage_id"], 7)
		assert_true(lifecycle.complete_active_stage(
			stage["transaction_id"], receipt
		)["ok"])

	assert_eq(lifecycle.get_day(), 7)
	assert_eq(lifecycle.get_state(), &"ENDING")
	assert_false("increment_day" in visited)
	assert_false("invitation_rollover" in visited)
	assert_false("twofriends_if_deferred" in visited)

func test_day3_full_resolution_increments_exactly_once() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-day3", 3)
	assert_true(lifecycle.begin_day_resolution("resolution-day3", [])["ok"])
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
	assert_true(lifecycle.begin_day_resolution("resolution-a", [])["ok"])
	var reused: Dictionary = lifecycle.begin_day_resolution("resolution-a", [])
	assert_true(reused.get("ok", false), "same resolution_id reuses the active plan")
	var conflict: Dictionary = lifecycle.begin_day_resolution("resolution-b", [])
	assert_false(conflict.get("ok", true))
	assert_eq(conflict["code"], &"resolution_conflict")

func test_restore_rejects_invalid_shapes() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle: RefCounted = load(LIFECYCLE_PATH).new()
	lifecycle.reset("run-restore")
	for day: int in [0, 8, 9]:
		var rejected: Dictionary = lifecycle.prepare_restore({
			"run_id": "run-restore", "day": day, "state": "PLAYING",
			"active_resolution_plan": null, "ending_plan": null,
		})
		assert_false(rejected.get("ok", true), "day %d rejects" % day)
	assert_false(lifecycle.prepare_restore({
		"run_id": "run-restore", "day": 3, "state": "SLEEPING",
		"active_resolution_plan": null, "ending_plan": null,
	}).get("ok", true), "invalid state rejects")
	assert_false(lifecycle.prepare_restore({
		"run_id": "run-restore", "day": 7, "state": "ENDING",
		"active_resolution_plan": null, "ending_plan": null,
	}).get("ok", true), "ENDING without ending plan rejects")
	assert_false(lifecycle.prepare_restore({
		"run_id": "run-restore", "day": 3, "state": "PLAYING",
		"active_resolution_plan": null, "ending_plan": null, "extra": 1,
	}).get("ok", true), "unknown key rejects")
	var untouched: Dictionary = lifecycle.to_dict()
	assert_eq(untouched["day"], 1, "failed prepare_restore never mutates")

func test_rollover_receipt_must_target_next_day() -> void:
	assert_true(_lifecycle_exists(), "RunLifecycle must exist")
	if not _lifecycle_exists():
		return
	var lifecycle := _fresh("run-rollover", 5)
	assert_true(lifecycle.begin_day_resolution("resolution-rollover", [])["ok"])
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
	assert_true(lifecycle.begin_day_resolution("resolution-ending", [])["ok"])
	_drive_to_completion(lifecycle, 7)
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
	assert_false(lifecycle.begin_day_resolution("resolution-after", []).get("ok", true),
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
	assert_eq(keys, ["active_resolution_plan", "day", "ending_plan", "run_id", "state"])
	assert_eq(snapshot["run_id"], "run-shape")
	assert_eq(snapshot["day"], 3)
	assert_eq(snapshot["state"], "PLAYING")
	assert_true(snapshot["active_resolution_plan"] == null, "no active plan serialized")
	assert_true(snapshot["ending_plan"] == null, "no ending plan serialized")
