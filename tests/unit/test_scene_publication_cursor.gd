extends "res://addons/gut/test.gd"
## Dedicated-process pure owner tests over the actual frozen TEST scene programme.
## Publication is genuine ledger admission; this establishes no native/Save proof.
const FIXTURE := preload("res://tests/support/SceneDayReadingFixture.gd")

func before_all() -> void:
	var configured: Dictionary = FIXTURE.configure()
	assert_true(configured.ok, str(configured.get("code", "ok")))

func _session(entry: String = FIXTURE.A, occurrence: String = "TEST.cursor.a") -> RefCounted:
	var created: Dictionary = FIXTURE.create_session()
	assert_true(created.ok, str(created.get("code", "ok")))
	if not created.ok: return null
	var session: RefCounted = created.value
	var entered: Dictionary = FIXTURE.enter(session, entry, occurrence)
	assert_true(entered.ok, str(entered.get("code", "ok")))
	return session if entered.ok else null

func _publish(session: RefCounted, line: String, entry: String = "", occurrence: String = "") -> Dictionary:
	if entry.is_empty(): entry = session.latest_entry
	if occurrence.is_empty(): occurrence = session.scene_occurrence
	var allocated: Dictionary = session.ledger.allocate_publication(session.command_id, entry, occurrence)
	assert_true(allocated.ok, str(allocated.get("code", "ok")))
	if not allocated.ok: return {}
	var published: Dictionary = session.ledger.publish_line(session.command_id, allocated.value, entry, line, occurrence)
	assert_true(published.ok, str(published.get("code", "ok")))
	return {"line_id": line, "publication_id": allocated.value} if published.ok else {}

func _state(session: RefCounted) -> Dictionary:
	return {"index": session.scene_index, "boundary": session.boundary,
		"entry": session.latest_entry, "occurrence": session.scene_occurrence,
		"next_operation": session.next_operation.duplicate(true), "ledger": session.ledger.snapshot()}

func _refused_without_mutation(session: RefCounted, index: int, frontier: Dictionary) -> void:
	var before := _state(session)
	var result: Dictionary = session.accept_scene_publication(index, frontier)
	assert_false(result.get("ok", true), str(result.get("code", "ok")))
	assert_true(_state(session) == before, "refusal preserves cursor, operation and ledger")

func test_adjacent_authentic_publication_updates_cursor_without_mutating_ledger() -> void:
	var session := _session()
	if session == null: return
	var frontier := _publish(session, "line.scene.test.a.two")
	var ledger: Dictionary = session.ledger.snapshot()
	var accepted: Dictionary = session.accept_scene_publication(1, frontier)
	assert_true(accepted.ok, str(accepted.get("code", "ok")))
	if not accepted.ok: return
	assert_eq(session.scene_index, 1)
	assert_true(session.ledger.snapshot() == ledger, "acceptance never allocates or republishes")
	var captured: Dictionary = session.capture(frontier)
	assert_true(captured.ok, str(captured.get("code", "ok")))
	if captured.ok:
		assert_eq(captured.value.program_index, 1)
		assert_true(captured.value.frontier == frontier)

func test_authored_loop_accepts_new_publication_at_same_program_index() -> void:
	var session := _session()
	if session == null: return
	var first := _publish(session, "line.scene.test.a.two")
	assert_true(session.accept_scene_publication(1, first).ok)
	var again := _publish(session, "line.scene.test.a.two")
	assert_ne(again.publication_id, first.publication_id)
	var ledger: Dictionary = session.ledger.snapshot()
	var accepted: Dictionary = session.accept_scene_publication(1, again)
	assert_true(accepted.ok, str(accepted.get("code", "ok")))
	assert_eq(session.scene_index, 1)
	assert_true(session.ledger.snapshot() == ledger, "loop retains genuine new ledger publication")
	assert_true(session.capture(again).ok)

func test_wrong_index_for_authentic_later_frontier_refuses_without_mutation() -> void:
	var session := _session()
	if session == null: return
	_refused_without_mutation(session, 0, _publish(session, "line.scene.test.a.two"))

func test_wrong_line_and_malformed_frontier_refuse_without_mutation() -> void:
	var session := _session()
	if session == null: return
	var frontier := _publish(session, "line.scene.test.a.two")
	var wrong := frontier.duplicate(true)
	wrong.line_id = "line.scene.test.a.one"
	_refused_without_mutation(session, 1, wrong)
	_refused_without_mutation(session, 1, {})
	wrong = frontier.duplicate(true)
	wrong["extra"] = true
	_refused_without_mutation(session, 1, wrong)

func test_unknown_and_superseded_publications_refuse_without_mutation() -> void:
	var session := _session()
	if session == null: return
	var old: Dictionary = FIXTURE.frontier(session)
	var current := _publish(session, "line.scene.test.a.two")
	var unknown := current.duplicate(true)
	unknown.publication_id = "TEST.unallocated.publication"
	_refused_without_mutation(session, 1, unknown)
	_refused_without_mutation(session, 0, old)

func test_authentic_foreign_entry_publication_refuses_without_mutation() -> void:
	var session := _session()
	if session == null: return
	var occurrence := "TEST.cursor.foreign-entry"
	var admitted: Dictionary = session.ledger.admit_entry_context(session.command_id, FIXTURE.B,
		FIXTURE.frame(FIXTURE.B, occurrence), occurrence)
	assert_true(admitted.ok)
	if not admitted.ok: return
	var frontier := _publish(session, "line.scene.test.b.two", FIXTURE.B, occurrence)
	_refused_without_mutation(session, 1, frontier)

func test_authentic_foreign_occurrence_publication_refuses_without_mutation() -> void:
	var session := _session()
	if session == null: return
	var occurrence := "TEST.cursor.other-occurrence"
	var admitted: Dictionary = session.ledger.admit_entry_context(session.command_id, FIXTURE.A,
		FIXTURE.frame(FIXTURE.A, occurrence), occurrence)
	assert_true(admitted.ok)
	if not admitted.ok: return
	var frontier := _publish(session, "line.scene.test.a.two", FIXTURE.A, occurrence)
	_refused_without_mutation(session, 1, frontier)

func test_actual_b_control_boundary_cannot_be_crossed_by_publication_callback() -> void:
	var session := _session(FIXTURE.B, "TEST.cursor.b")
	if session == null: return
	assert_true(FIXTURE.advance_detached(session).ok)
	assert_true(FIXTURE.advance_detached(session).ok)
	assert_eq(session.boundary, "control")
	assert_false(session.next_operation.is_empty(), "actual traversal retains control operation")
	var frontier := _publish(session, "line.scene.test.b.two")
	_refused_without_mutation(session, 1, frontier)
	_refused_without_mutation(session, session.scene_index + 1, frontier)

func test_non_line_unadmitted_session_refuses_without_mutation() -> void:
	var created: Dictionary = FIXTURE.create_session()
	assert_true(created.ok)
	if not created.ok: return
	var session: RefCounted = created.value
	assert_eq(session.boundary, "between_entries")
	_refused_without_mutation(session, 0, {"line_id": "line.scene.test.a.one", "publication_id": "TEST.unallocated"})

func test_invalid_and_noncaption_indices_refuse_without_mutation() -> void:
	var session := _session()
	if session == null: return
	var frontier := _publish(session, "line.scene.test.a.two")
	for index: int in [-1, 2, 2147483647]:
		_refused_without_mutation(session, index, frontier)
