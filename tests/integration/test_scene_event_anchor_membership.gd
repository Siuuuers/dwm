extends "res://addons/gut/test.gd"
## Detached reading-owner checks only; this is not full Run9/Save9 admission.
const BASE := preload("res://tests/support/SceneDayReadingFixture.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")

func before_all() -> void:
	assert_true(BASE.configure().ok)

func test_scene_anchor_requires_retained_publication_occurrence_and_catalogue() -> void:
	var bridge: Node = BRIDGE.new()
	autofree(bridge)
	var created: Dictionary = BASE.create_session()
	assert_true(created.ok)
	var session: RefCounted = created.value
	assert_true(BASE.enter(session, BASE.B, "TEST.anchor.membership").ok)
	var first: Dictionary = BASE.checkpoint(session)
	assert_true(first.ok)
	var anchor := {"session_id": "TEST.anchor.membership", "entry_id": first.value.entry_id,
		"content_version": first.value.content_version,
		"catalogue_fingerprint": first.value.reading_session.registration_sha256,
		"publication_id": first.value.reading_session.frontier.publication_id,
		"line_id": first.value.reading_session.frontier.line_id}
	assert_true(bridge.validate_scene_event_anchor(anchor, first.value).ok)
	assert_true(BASE.advance_detached(session).ok)
	var later: Dictionary = BASE.checkpoint(session)
	assert_true(later.ok)
	assert_ne(later.value.reading_session.frontier.publication_id, anchor.publication_id)
	assert_true(bridge.validate_scene_event_anchor(anchor, later.value).ok,
		"historical publication membership does not require the current frontier")
	for field: String in ["publication_id", "session_id", "catalogue_fingerprint", "line_id"]:
		var absent: Dictionary = anchor.duplicate(true)
		absent[field] = "TEST.absent"
		assert_false(bridge.validate_scene_event_anchor(absent, later.value).ok, field)
	var wrong_version: Dictionary = anchor.duplicate(true)
	wrong_version.content_version += 1
	assert_false(bridge.validate_scene_event_anchor(wrong_version, later.value).ok)
