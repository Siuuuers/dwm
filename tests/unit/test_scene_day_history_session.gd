extends "res://addons/gut/test.gd"
## Actual authored programme; reconstruction is a display projection, never live history.
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")

func _position(entry: String, index: int) -> RefCounted:
	var session := SESSION.new()
	assert_true(session.configure_scene().ok)
	assert_true(session.begin_scene("TEST.day-history.session").ok)
	var occurrence := "TEST.day-history." + entry
	var presentation := FROZEN.build(entry, {"entry_id": entry, "entry_role": "scene",
		"occurrence_id": occurrence, "admission_receipt_id": occurrence})
	assert_true(presentation.ok, str(presentation))
	if not presentation.ok: return null
	var frame := {"expected_stage": "scene", "playback_id": occurrence, "role": "scene",
		"transaction_id": occurrence, "presentation": presentation.value}
	assert_true(session.admit_scene(entry, frame, index).ok)
	var programme: Dictionary = session.entry_program(entry, frame)
	var allocation: Dictionary = session.ledger.allocate_publication(session.command_id, entry, occurrence)
	assert_true(session.ledger.publish_line(session.command_id, allocation.value, entry,
		programme.value.lines[index].line_id, occurrence).ok)
	return session

func _frontier(session: RefCounted) -> Dictionary:
	var tail: Dictionary = session.ledger.snapshot().captions.back()
	return {"line_id": tail.beat.line_id, "publication_id": tail.publication_id}

func test_reconstructed_day_passage_does_not_create_historical_publications() -> void:
	var session := _position("Day1", 5)
	if session == null: return
	var frontier := _frontier(session)
	var before: Dictionary = session.capture(frontier).value
	var history: Dictionary = session.project_scene_day_history(frontier, {}, {})
	assert_true(history.ok, str(history))
	if not history.ok: return
	assert_eq(history.value.captions.size(), 6)
	assert_eq(history.value.captions[0].line_id, "line.Day1.one")
	assert_eq(history.value.captions.back().publication_id, frontier.publication_id)
	assert_eq(history.value.captions.back().line_id, frontier.line_id)
	assert_eq(history.value.frontier, frontier)
	assert_eq(session.ledger.snapshot().captions.size(), 1, "earlier reconstructed text is display-only")
	assert_eq(session.capture(frontier).value, before, "projection has no live publication or cursor effects")
	history.value.captions.clear()
	assert_eq(session.project_scene_day_history(frontier, {}, {}).value.captions.size(), 6)

func test_day_two_passage_starts_at_day_two() -> void:
	var session := _position("Day2", 0)
	if session == null: return
	var history: Dictionary = session.project_scene_day_history(_frontier(session), {}, {})
	assert_true(history.ok, str(history))
	if history.ok:
		assert_eq(history.value.captions.size(), 1)
		assert_eq(history.value.captions[0].entry_id, "Day2")
