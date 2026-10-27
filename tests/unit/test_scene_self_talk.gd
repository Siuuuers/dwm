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

func test_existing_passage_card_keeps_attached_thought_in_same_step() -> void:
	var catalog := preload("res://scripts/narrative/ScenePassageCatalog.gd")
	var bundle := {"entry_manifest": {"entries": []},
		"caption_registry": {"entries": [{"entry_id": "fixture", "lines": [
			{"line_id": "a", "text": "Caption."}, {"line_id": "thought", "text": "Thought."}]}]},
		"scene_programme": {"entries": [{"entry_id": "fixture", "content_sha256": "synthetic-pair-card", "markers": [
			{"kind": "passage.start", "label": "start", "marker_id": "start", "after_line_id": "", "payload": {"passage_id": "passage.fixture"}},
			{"kind": "passage.finish", "label": "finish", "marker_id": "finish", "after_line_id": "a", "payload": {"passage_id": "passage.fixture"}}]}]}}
	var compiled := {"fixture": {"nodes": [{"kind": "caption", "line_id": "a", "self_talk": {"line_id": "thought", "text": "Thought."}}]}}
	var result: Dictionary = catalog.inspect(bundle, compiled)
	assert_true(result.ok, str(result))
	if not result.ok: return
	var passage: Dictionary = result.value.records["passage.fixture"]
	assert_eq(passage.line_ids, ["a"])
	assert_eq(passage.captions.size(), 1)
	assert_eq(passage.captions[0].self_talk.line_id, "thought")
	var bridge: Node = add_child_autofree(load("res://autoload/DialogicBridge.gd").new())
	bridge._reached_replay = {"passage": passage, "passage_index": 0, "token": "fixture-replay"}
	var card: Dictionary = bridge._scene_passage_replay_card()
	assert_eq(card.body, "Caption.\n\nThought.")
	assert_eq(card.receipt.line_id, "a")
