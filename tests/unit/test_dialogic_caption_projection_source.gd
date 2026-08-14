extends "res://addons/gut/test.gd"

const SOURCE_PATH := "res://scripts/narrative/DialogicCaptionProjectionSource.gd"

func _make_source() -> RefCounted:
	var source_script := load(SOURCE_PATH) as Script
	assert_not_null(source_script)
	if source_script == null:
		return null
	return source_script.new() as RefCounted

func test_registered_text_index_projects_exact_identity_without_reading_prose() -> void:
	var source := _make_source()
	if source == null:
		return
	var records: Array[Dictionary] = [
		{"event_index": 0, "event_kind": "text", "semantic_id": &"fixture.caption.one"},
		{"event_index": 1, "event_kind": "signal", "semantic_id": &"fixture.signal"},
	]
	assert_true(source.call("configure", &"fixture.session", &"single", records).ok)
	var projected: Dictionary = source.call("project_text", 0, {"text": "Repeated prose", "append": false})
	assert_true(projected.ok)
	assert_eq(projected.projection.semantic_id, &"fixture.caption.one")
	assert_eq(projected.projection.primary_text, "Repeated prose")
	assert_false(source.call("project_text", 99, {"text": "Repeated prose", "append": false}).ok)
	assert_eq(source.call("project_text", 1, {"text": "Repeated prose", "append": false}).code, &"unknown_caption_event")

func test_append_keeps_the_registered_event_identity() -> void:
	var source := _make_source()
	if source == null:
		return
	source.call("configure", &"fixture.session", &"dual", [
		{"event_index": 4, "event_kind": "text", "semantic_id": &"fixture.caption.append"},
	])
	var projected: Dictionary = source.call("project_text", 4, {
		"text": " fragment",
		"secondary_text": " 片段",
		"append": true,
	})
	assert_true(projected.ok)
	assert_true(projected.append)
	assert_eq(projected.projection.semantic_id, &"fixture.caption.append")
	assert_eq(projected.projection.secondary_text, " 片段")

func test_configuration_fails_closed_and_does_not_publish_partial_state() -> void:
	var source := _make_source()
	if source == null:
		return
	assert_false(source.call("configure", &"", &"single", []).ok)
	assert_false(source.call("configure", &"fixture.session", &"unknown", []).ok)
	assert_false(source.call("configure", &"fixture.session", &"single", [
		{"event_index": 0, "event_kind": "text", "semantic_id": &"one"},
		{"event_index": 0, "event_kind": "text", "semantic_id": &"two"},
	]).ok)
	assert_false(source.call("project_text", 0, {"text": "Words", "append": false}).ok)

func test_empty_identity_and_incomplete_records_fail_closed() -> void:
	var source := _make_source()
	if source == null:
		return
	assert_false(source.call("configure", &"fixture.session", &"single", [
		{"event_index": 0, "event_kind": "text", "semantic_id": &""},
	]).ok)
	assert_false(source.call("configure", &"fixture.session", &"single", [
		{"event_index": 0, "event_kind": "text"},
	]).ok)

func test_text_info_must_include_text_and_append() -> void:
	var source := _make_source()
	if source == null:
		return
	assert_true(source.call("configure", &"fixture.session", &"single", [
		{"event_index": 0, "event_kind": "text", "semantic_id": &"fixture.caption.one"},
	]).ok)
	assert_eq(source.call("project_text", 0, {"append": false}).code, &"caption_text_info_incomplete")
	assert_eq(source.call("project_text", 0, {"text": "Words"}).code, &"caption_text_info_incomplete")

func test_configured_records_are_owned_copies() -> void:
	var source := _make_source()
	if source == null:
		return
	var record := {"event_index": 0, "event_kind": "text", "semantic_id": &"fixture.caption.one"}
	var records: Array[Dictionary] = [record]
	assert_true(source.call("configure", &"fixture.session", &"single", records).ok)
	record.semantic_id = &"mutated"
	var projected: Dictionary = source.call("project_text", 0, {"text": "Words", "append": false})
	assert_eq(projected.projection.semantic_id, &"fixture.caption.one")
