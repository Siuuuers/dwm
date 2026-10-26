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
	assert_eq(history.value.captions.size(), 1)
	assert_eq(history.value.captions[0].line_id, frontier.line_id)
	assert_eq(history.value.captions.back().publication_id, frontier.publication_id)
	assert_eq(history.value.captions.back().line_id, frontier.line_id)
	assert_eq(history.value.frontier, frontier)
	assert_eq(session.ledger.snapshot().captions.size(), 1, "unencountered earlier text is never backfilled")
	assert_eq(session.capture(frontier).value, before, "projection has no live publication or cursor effects")
	history.value.captions.clear()
	assert_eq(session.project_scene_day_history(frontier, {}, {}).value.captions.size(), 1)

func test_day_two_passage_starts_at_day_two() -> void:
	var session := _position("Day2", 0)
	if session == null: return
	var history: Dictionary = session.project_scene_day_history(_frontier(session), {}, {})
	assert_true(history.ok, str(history))
	if history.ok:
		assert_eq(history.value.captions.size(), 1)
		assert_eq(history.value.captions[0].entry_id, "Day2")


func test_fresh_capture_records_encounters_once_and_returns_detached_checkpoint() -> void:
	var session := _position("Day1", 0)
	if session == null: return
	var first := _frontier(session)
	var published: Dictionary = session.ledger.snapshot()
	assert_true(session.player_progress.is_empty(), "fixture has published but has never captured")
	assert_true(session._pending_checkpoint, "first encounter still owns its section boundary")
	var captured: Dictionary = session.capture(first)
	assert_true(captured.ok, str(captured))
	if not captured.ok: return
	assert_false(session._pending_checkpoint, "capture consumes the pending section boundary")
	var expected: Dictionary = captured.value.duplicate(true)
	assert_eq(expected.player_progress.history_sections, [[first.line_id]])
	assert_eq(expected.player_progress.recovery_anchor, {"entry_id": "Day1", "line_id": first.line_id})
	assert_eq(session.ledger.snapshot(), published, "capture records progress without allocating a publication")
	captured.value.ledger.captions.clear()
	captured.value.frontier.line_id = "TEST.changed-copy"
	captured.value.player_progress.history_sections[0].clear()
	captured.value.player_progress.recovery_anchor.line_id = "TEST.changed-copy"
	assert_eq(session.capture(first).value, expected, "returned nested state is detached from all live owners")
	for repeat: int in 2:
		var history: Dictionary = session.project_scene_day_history(first, {}, {})
		assert_true(history.ok, str(history))
		if not history.ok: return
		assert_eq(history.value.captions.size(), 1)
		assert_eq(history.value.captions[0].line_id, first.line_id)
		assert_eq(history.value.captions[0].publication_id, first.publication_id)
		assert_eq(session.capture(first).value, expected)
		assert_eq(session.player_progress, expected.player_progress)
		assert_eq(session.ledger.snapshot(), published)
	var allocated: Dictionary = session.ledger.allocate_publication(session.command_id, "Day1", session.scene_occurrence)
	assert_true(allocated.ok, str(allocated))
	if not allocated.ok: return
	var next := {"line_id": "line.Day1.002", "publication_id": allocated.value}
	assert_true(session.ledger.publish_line(session.command_id, allocated.value, "Day1", next.line_id, session.scene_occurrence).ok)
	assert_true(session.accept_scene_publication(1, next).ok)
	assert_ne(next.publication_id, first.publication_id)
	published = session.ledger.snapshot()
	var following: Dictionary = session.capture(next)
	assert_true(following.ok, str(following))
	if not following.ok: return
	assert_eq(following.value.player_progress.history_sections, [[first.line_id, next.line_id]])
	assert_eq(following.value.player_progress.recovery_anchor, expected.player_progress.recovery_anchor)
	assert_eq(following.value.frontier, next)
	assert_eq(following.value.program_index, 1)
	var history: Dictionary = session.project_scene_day_history(next, {}, {})
	assert_true(history.ok, str(history))
	if not history.ok: return
	assert_eq(history.value.captions.map(func(row: Dictionary) -> String: return row.line_id), [first.line_id, next.line_id])
	assert_eq(history.value.captions.back().publication_id, next.publication_id)
	assert_eq(session.capture(next).value, following.value)
	assert_eq(session.player_progress, following.value.player_progress)
	assert_eq(session.ledger.snapshot(), published, "later capture and History keep the two genuine publications")

	var restored := SESSION.new()
	assert_true(restored.configure_scene().ok)
	var restoration: Dictionary = restored.restore(following.value, "Day1")
	assert_true(restoration.ok, str(restoration))
	if not restoration.ok: return
	assert_eq(restored.capture(next).value, following.value, "full restore still accepts and preserves the captured checkpoint")
