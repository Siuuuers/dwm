extends "res://addons/gut/test.gd"
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const FIXTURE := preload("res://tests/support/SceneCaptionChallengeFixture.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")

func test_adjacent_challenge_end_requires_same_challenge_and_real_caption() -> void:
	var playable := {"marker_id": "play", "label": "play", "after_line_id": "cue", "kind": "challenge.playable", "payload": {"challenge_id": "test"}}
	var end := {"marker_id": "end", "label": "end", "after_line_id": "cue", "kind": "challenge.end", "payload": {"challenge_id": "test"}}
	var nodes := [{"kind": "caption", "line_id": "cue"}, {"kind": "control", "marker_id": "play"}, {"kind": "control", "marker_id": "end"}]
	assert_true(BRIDGE._adjacent_challenge_end(nodes, [playable, end], 1, playable).ok)
	var wrong: Dictionary = end.duplicate(true)
	wrong.payload.challenge_id = "other"
	assert_false(BRIDGE._adjacent_challenge_end(nodes, [playable, wrong], 1, playable).ok)
	wrong = end.duplicate(true)
	wrong.after_line_id = "other"
	assert_false(BRIDGE._adjacent_challenge_end(nodes, [playable, wrong], 1, playable).ok)
	var separated: Array = nodes.duplicate(true)
	separated.insert(2, {"kind": "caption", "line_id": "next"})
	assert_false(BRIDGE._adjacent_challenge_end(separated, [playable, end], 1, playable).ok)
	assert_false(BRIDGE._adjacent_challenge_end(nodes, [playable, end], 0, playable).ok)

func test_native_registration_accepts_two_markers_on_one_caption() -> void:
	var fixture: RefCounted = FIXTURE.new()
	var built: Dictionary = fixture._registration_bundle()
	assert_true(built.ok, str(built))
	if not built.ok: return
	var checked: Dictionary = MANIFEST.validate_scene_registration(built.value)
	assert_true(checked.ok, str(checked))
