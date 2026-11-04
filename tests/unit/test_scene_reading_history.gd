extends "res://addons/gut/test.gd"

const HISTORY := preload("res://scripts/narrative/SceneReadingHistory.gd")
const TRAVERSAL := preload("res://scripts/narrative/ReadingTraversalOperation.gd")

func _bundle() -> Dictionary:
	return {"caption_registry": {"entries": [
		{"entry_id": "selected", "lines": [{"line_id": "a", "beat_id": "a", "text": "A"},
			{"line_id": "b", "beat_id": "b", "text": "B"}, {"line_id": "c", "beat_id": "c", "text": "C"}]},
		{"entry_id": "other", "lines": [{"line_id": "unread", "beat_id": "unread", "text": "Other branch"}]},
		{"entry_id": "ending", "lines": [{"line_id": "end", "beat_id": "end", "text": "End"}]}]},
		"targets": [{"target_id": "end", "target": {"entry_id": "ending"}}],
		"scene_programme": {"entries": [{"entry_id": "selected", "markers": [
			{"marker_id": "leave", "kind": "scene.transition", "payload": {"target_id": "end"}}]}]}}

func _programme(entry_id: String) -> Dictionary:
	var nodes := [{"kind": "caption", "line_id": "end", "next": 1}, {"kind": "completion"}]
	if entry_id == "selected":
		nodes = [{"kind": "caption", "line_id": "a", "next": 1},
			{"kind": "caption", "line_id": "b", "next": 2},
			{"kind": "caption", "line_id": "c", "next": 3},
			{"kind": "control", "marker_id": "leave"}]
	return {"ok": true, "value": nodes}

func test_mid_block_endpoint_reconstructs_only_the_selected_prefix() -> void:
	var bundle := _bundle()
	var before := bundle.duplicate(true)
	var result := HISTORY.project_blocks(bundle, [{"checkpoint_id": "a", "last_line_id": "b"}], _programme)
	assert_true(result.ok)
	assert_eq(result.value.captions.map(func(row: Dictionary) -> String: return row.line_id), ["a", "b"])
	result.value.captions[0].text = "mutation"
	assert_eq(bundle, before)

func test_block_can_cross_an_ordinary_passage_without_entering_another_branch() -> void:
	var result := HISTORY.project_blocks(_bundle(), [{"checkpoint_id": "b", "last_line_id": "end"}], _programme)
	assert_true(result.ok)
	assert_eq(result.value.captions.map(func(row: Dictionary) -> String: return row.line_id), ["b", "c", "end"])

func test_progress_is_three_fixed_size_blocks_after_long_play() -> void:
	var progress := {}
	for block: int in 5:
		for line: int in 1000:
			TRAVERSAL.append_player_caption(progress, "entry", "%d:%d" % [block, line], 1, line == 0)
	assert_true(TRAVERSAL.valid_player_progress(progress))
	assert_eq(progress.history_sections, [
		{"checkpoint_id": "2:0", "last_line_id": "2:999"},
		{"checkpoint_id": "3:0", "last_line_id": "3:999"},
		{"checkpoint_id": "4:0", "last_line_id": "4:999"}])
	progress.history_sections[0]["text"] = "must not persist"
	assert_false(TRAVERSAL.valid_player_progress(progress))
