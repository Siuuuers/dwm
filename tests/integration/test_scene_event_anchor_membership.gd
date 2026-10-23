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

func _anchor(checkpoint: Dictionary) -> Dictionary:
	var reading: Dictionary = checkpoint.reading_session
	return {"session_id": reading.occurrence_id, "entry_id": checkpoint.entry_id,
		"content_version": checkpoint.content_version,
		"catalogue_fingerprint": reading.registration_sha256,
		"publication_id": reading.frontier.publication_id, "line_id": reading.frontier.line_id}

func test_batch_checks_later_anchors_and_keeps_occurrences_distinct() -> void:
	var bridge: Node = BRIDGE.new()
	autofree(bridge)
	var created: Dictionary = BASE.create_session()
	assert_true(created.ok)
	if not created.ok: return
	var session: RefCounted = created.value
	assert_true(BASE.enter(session, BASE.B, "TEST.batch.earlier").ok)
	var earlier: Dictionary = BASE.checkpoint(session)
	assert_true(earlier.ok)
	if not earlier.ok: return
	assert_true(BASE.enter(session, BASE.B, "TEST.batch.later").ok)
	var later: Dictionary = BASE.checkpoint(session)
	assert_true(later.ok)
	if not later.ok: return
	var anchors: Array[Dictionary] = [_anchor(earlier.value), _anchor(later.value)]
	var before: Dictionary = later.value.duplicate(true)
	var anchors_before: Array[Dictionary] = anchors.duplicate(true)
	assert_eq(anchors[0].line_id, anchors[1].line_id, "same authored caption in two occurrences")
	assert_ne(anchors[0].publication_id, anchors[1].publication_id)
	assert_true(bridge.validate_scene_event_anchors(anchors, later.value).ok)
	var wrong_occurrence: Dictionary = anchors[1].duplicate(true)
	wrong_occurrence.session_id = anchors[0].session_id
	var wrong_occurrence_anchors: Array[Dictionary] = [anchors[0], wrong_occurrence]
	assert_eq(bridge.validate_scene_event_anchors(wrong_occurrence_anchors, later.value).get("code"),
		&"event_anchor_invalid", "a valid first anchor cannot hide a wrong later occurrence")
	var absent: Dictionary = anchors[1].duplicate(true)
	absent.publication_id = "TEST.absent"
	var absent_anchors: Array[Dictionary] = [anchors[0], absent]
	assert_eq(bridge.validate_scene_event_anchors(absent_anchors, later.value).get("code"),
		&"event_anchor_invalid", "every anchor needs its retained publication")
	assert_eq(later.value, before, "batch admission leaves the saved checkpoint unchanged")
	assert_eq(anchors, anchors_before, "batch admission leaves caller anchors unchanged")

func test_batch_revalidates_changed_checkpoint_on_every_call() -> void:
	var bridge: Node = BRIDGE.new()
	autofree(bridge)
	var created: Dictionary = BASE.create_session()
	assert_true(created.ok)
	if not created.ok: return
	var session: RefCounted = created.value
	assert_true(BASE.enter(session, BASE.B, "TEST.batch.fresh").ok)
	var checkpoint: Dictionary = BASE.checkpoint(session)
	assert_true(checkpoint.ok)
	if not checkpoint.ok: return
	var anchors: Array[Dictionary] = [_anchor(checkpoint.value)]
	assert_true(bridge.validate_scene_event_anchors(anchors, checkpoint.value).ok)
	var changed: Dictionary = checkpoint.value.duplicate(true)
	changed.reading_session.ledger.captions[0].beat.line_id = "TEST.absent"
	var before: Dictionary = changed.duplicate(true)
	assert_false(bridge.validate_scene_event_anchors(anchors, changed).ok,
		"a previous successful call is not proof for changed saved input")
	assert_eq(changed, before, "refusal leaves invalid input unchanged")
	assert_true(bridge.validate_scene_event_anchors(anchors, checkpoint.value).ok)
	assert_true(bridge.validate_scene_event_anchor(anchors[0], checkpoint.value).ok,
		"the existing single-anchor entry point remains compatible")
