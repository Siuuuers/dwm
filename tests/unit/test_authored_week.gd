extends "res://addons/gut/test.gd"
const WEEK := preload("res://tools/authoring/AuthoredWeekRegistration.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")

func test_authored_week_compiles_and_preserves_conditional_branch_bindings() -> void:
	var prepared: Dictionary = WEEK.prepare()
	assert_true(prepared.get("ok", false), str(prepared))
	if not prepared.get("ok", false): return
	var bundle: Dictionary = prepared.value.registration
	assert_true(CONTRACT.validate_bundle_structure(bundle).ok)
	assert_eq(prepared.value.first_target_id, "target.Day1")
	var entries := {}
	for entry: Dictionary in bundle.scene_programme.entries: entries[entry.entry_id] = entry
	assert_eq(entries.size(), 92)
	assert_eq(bundle.challenges.size(), 9, "mutually exclusive Day3 and clipboard branches share the seven-day journey")
	var threshold: Dictionary = entries["Day2.result.D"].markers[0]
	assert_eq(threshold.kind, "thought.options")
	assert_eq(threshold.payload.pass_target_id, "target.Day2.threshold.benchmark")
	assert_eq(threshold.payload.options.size(), 2)
	var cheek: Dictionary = entries.Day5.markers[0].payload
	assert_eq(cheek.challenge_id, "Day2.challenge")
	assert_eq(cheek.lost_target_id, "target.Day5.cheek")
	assert_eq(cheek.never_started_target_id, "target.Day5.impulse")
	for branch: String in ["crossed", "untouched"]:
		var recall: Dictionary = entries["Day7." + branch + ".D"].markers[0].payload
		assert_eq(recall.challenge_id, "Day1.challenge")
		assert_ne(recall.lost_target_id, recall.never_started_target_id)
	for challenge: Dictionary in bundle.challenges:
		var markers: Array = entries[challenge.entry_id].markers
		assert_eq(markers.size(), 2)
		assert_eq(markers[0].kind, "challenge.playable")
		assert_eq(markers[1].kind, "challenge.end")
		assert_eq(markers[0].after_line_id, markers[1].after_line_id, "one real cue caption, no invented intermediate witness")
	var ending: Dictionary = bundle.entry_manifest.entries.back()
	assert_eq(ending.entry_id, "ending.alone.normal")
	assert_eq(ending.role, "alone_step")
