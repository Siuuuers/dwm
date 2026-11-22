extends "res://addons/gut/test.gd"
## These are boundary/projection checks; full admission remains issuer-backed integration coverage.
const SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")

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
