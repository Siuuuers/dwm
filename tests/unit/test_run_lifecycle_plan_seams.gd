extends "res://addons/gut/test.gd"

const LIFECYCLE := preload("res://scripts/domain/run/RunLifecycle.gd")

const EMPTY_AGGREGATE := {
	"schema_version": 1, "day": 1, "registry_fingerprint": null,
	"entries": [], "commit_receipt": null,
}


## Plan 02 Task 6 (dwm-p2r.32): branch_id/desktop_timeline_generation/causal_day_instance/receipt
## arrive already allocated in production; this test supplies a self-consistent placeholder.
func _lifecycle() -> RefCounted:
	var lifecycle: RefCounted = LIFECYCLE.new()
	var receipt := {"receipt_id": "issuer_receipt.fixture-causal-day-seams", "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": "causal-day-seams", "numeric_value": null}
	lifecycle.reset("run-seams", "branch-seams", 0, "causal-day-seams",
		{"causal_day_instance_issuer_receipt": receipt}, false)
	return lifecycle


func _aggregate(day: int) -> Dictionary:
	var aggregate: Dictionary = EMPTY_AGGREGATE.duplicate(true)
	aggregate["day"] = day
	return aggregate


# ---- purity ----

func test_prepare_produces_a_candidate_without_installing_it() -> void:
	var lifecycle: RefCounted = _lifecycle()
	var prepared: Dictionary = lifecycle.prepare_day_resolution("res:1", _aggregate(1))
	assert_true(prepared.get("ok", false),
		"prepare must succeed: %s" % str(prepared.get("code", &"")))
	var value: Dictionary = prepared.get("value", {}) as Dictionary
	assert_false(value.get("already_active", true), "a first preparation is genuinely new")
	assert_false((value.get("candidate", {}) as Dictionary).is_empty(), "a candidate is produced")
	assert_null(lifecycle.to_dict()["active_resolution_plan"],
		"prepare must NOT install the plan it produced")
	assert_false(lifecycle.resume_resolution().get("ok", true),
		"with nothing installed there is still no active plan to resume")


func test_prepare_is_pure_on_the_conflict_path_too() -> void:
	var lifecycle: RefCounted = _lifecycle()
	assert_true(lifecycle.begin_day_resolution("res:1", _aggregate(1)).get("ok", false))
	var before: Variant = lifecycle.to_dict()["active_resolution_plan"]
	var conflicting: Dictionary = lifecycle.prepare_day_resolution("res:2", _aggregate(1))
	assert_false(conflicting.get("ok", true), "a different incomplete resolution conflicts")
	assert_eq(str(conflicting.get("code", &"")), "resolution_conflict", "the exact code")
	assert_eq(lifecycle.to_dict()["active_resolution_plan"], before,
		"a rejected preparation must leave the installed plan byte-identical")


func test_prepare_replaying_the_same_resolution_returns_the_existing_plan_and_says_so() -> void:
	var lifecycle: RefCounted = _lifecycle()
	assert_true(lifecycle.begin_day_resolution("res:1", _aggregate(1)).get("ok", false))
	var installed: Variant = lifecycle.to_dict()["active_resolution_plan"]
	var replay: Dictionary = lifecycle.prepare_day_resolution("res:1", _aggregate(1))
	assert_true(replay.get("ok", false), "the same resolution replays idempotently")
	var value: Dictionary = replay.get("value", {}) as Dictionary
	assert_true(value.get("already_active", false),
		"already_active must tell the caller committing this is a no-op")
	assert_eq(value.get("candidate"), installed,
		"the candidate IS the existing plan, not a freshly built twin")


# ---- commit ----

func test_a_prepared_candidate_commits_and_becomes_the_active_plan() -> void:
	var lifecycle: RefCounted = _lifecycle()
	var prepared: Dictionary = lifecycle.prepare_day_resolution("res:1", _aggregate(1))
	var candidate: Dictionary = (prepared.get("value", {}) as Dictionary).get("candidate", {}) as Dictionary
	var committed: Dictionary = lifecycle.commit_active_plan(candidate)
	assert_true(committed.get("ok", false),
		"the candidate must commit: %s" % str(committed.get("code", &"")))
	assert_eq(lifecycle.to_dict()["active_resolution_plan"], candidate,
		"the installed plan is exactly what was prepared")


func test_commit_refuses_a_malformed_candidate_and_changes_nothing() -> void:
	var lifecycle: RefCounted = _lifecycle()
	var refused: Dictionary = lifecycle.commit_active_plan({"resolution_id": "res:1"})
	assert_false(refused.get("ok", true), "a malformed candidate is refused")
	assert_null(lifecycle.to_dict()["active_resolution_plan"],
		"a refused commit installs nothing")


func test_capture_reads_just_the_active_plan() -> void:
	var lifecycle: RefCounted = _lifecycle()
	assert_eq(lifecycle.capture_active_plan().value, {"active_resolution_plan": null})
	assert_true(lifecycle.begin_day_resolution("res:1", _aggregate(1)).ok)
	assert_eq(lifecycle.capture_active_plan().value, {"active_resolution_plan": lifecycle.to_dict().active_resolution_plan})
