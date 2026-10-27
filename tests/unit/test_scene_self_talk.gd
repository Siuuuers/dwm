extends "res://addons/gut/test.gd"
## Synthetic pair semantics; no authored story or adversarial input fixtures.
const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")

func test_compiler_pairs_ids_without_an_extra_progression_node() -> void:
	var source := "label fixture\nCaption A. #id:fixture.a\n# self-talk\nThought A. #id:fixture.thought\nCaption B. #id:fixture.b\nreturn\n"
	var result := ADAPTER._compile_scene_programme_source(source, "fixture", ["fixture"], [])
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.nodes.size(), 3)
	assert_eq(result.value.nodes[0].line_id, "fixture.a")
	assert_eq(result.value.nodes[0].self_talk.line_id, "fixture.thought")
	assert_eq(result.value.nodes[0].next, 1)
	assert_eq(result.value.nodes[1].line_id, "fixture.b")
	assert_eq(result.value.events.filter(func(row: Dictionary) -> bool: return row.kind == "text").map(
		func(row: Dictionary) -> String: return row.line_id), ["fixture.a", "fixture.thought", "fixture.b"])
	assert_gt(result.value.native_indices[1], result.value.nodes[0].self_talk.native_index)

func test_clear_belongs_to_next_caption_without_a_reading_step() -> void:
	var source := "label fixture\nCaption A. #id:fixture.a\n# self-talk\nThought A. #id:fixture.thought\n# self-talk-clear\nCaption B. #id:fixture.b\nreturn\n"
	var result := ADAPTER._compile_scene_programme_source(source, "fixture", ["fixture"], [])
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.nodes.size(), 3)
	assert_true(result.value.nodes[1].self_talk_clear)
	assert_false(result.value.nodes[0].has("self_talk_clear"))

func test_pair_identity_does_not_replace_primary_identity() -> void:
	var session := SESSION.new()
	var caption := {"line_id": "a"}
	var thought := {"line_id": "thought"}
	session._caption_variants_by_line = {"a": caption, "thought": thought}
	session._scene_display = {"a": {"self_talk": {"line_id": "thought"}}}
	assert_eq(session.scene_pair_beats("a"), [caption, thought])
