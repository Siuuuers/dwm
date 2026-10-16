extends "res://addons/gut/test.gd"
## These are boundary/projection checks; full admission remains issuer-backed integration coverage.
const SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const REMAPPER := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
const FIXTURE := preload("res://tests/unit/test_scene_runtime_remap.gd")

func test_terminal_reading_never_accepts_missing_source_history() -> void:
	var candidate := {"lifecycle": {"state": "ENDING", "ending_plan": {"source_kind": "scene"}},
		"narrative_checkpoint": {}}
	var checked: Dictionary = SCHEMA._validate_scene_reading(candidate)
	assert_false(checked.ok)
	assert_eq(checked.code, &"reading_checkpoint_invalid")
	candidate.lifecycle.ending_plan.source_reading_checkpoint = {}
	checked = SCHEMA._validate_scene_reading(candidate)
	assert_false(checked.ok, "Empty terminal checkpoint cannot conceal missing source reading")
	assert_eq(checked.code, &"reading_checkpoint_invalid")

func test_terminal_restore_remaps_live_identity_but_retains_admission_and_reading() -> void:
	var fixture := FIXTURE.new()
	var source: Dictionary = fixture._source()
	var allocation: Dictionary = fixture._bundle()
	fixture.free()
	source.route_id = "ending"
	source.lifecycle.state = "ENDING"
	source.lifecycle.ending_plan = {"source_kind": "scene", "source_reading_checkpoint": source.narrative_checkpoint.duplicate(true),
		"admission": {"source_identity": {"branch_id": "TEST.old.branch"}}, "playback_stage": "PRIMARY_PENDING"}
	source.narrative_checkpoint = {"TEST.ending_cursor": 2}
	var before := source.duplicate(true)
	var result: Dictionary = REMAPPER.prepare(source, "TEST.restore", allocation)
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.snapshot.lifecycle.branch_id, "TEST.new.branch")
	assert_eq(result.value.snapshot.lifecycle.ending_plan, before.lifecycle.ending_plan)
	assert_eq(result.value.snapshot.narrative_checkpoint, before.narrative_checkpoint)
	assert_eq(source, before)
	source.route_id = "scene"
	assert_false(REMAPPER.collect_rewindable_transaction_ids(source).ok, "Terminal lifecycle cannot claim an ordinary route")
