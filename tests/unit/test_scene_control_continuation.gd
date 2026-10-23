extends "res://addons/gut/test.gd"
## Detached reading plans only: no native execution, Profile effects, or disk proof.
## Run in a dedicated process because fixture registration is immutable.
const FIXTURE := preload("res://tests/support/SceneDayReadingFixture.gd")
const PLAYABLE := preload("res://tests/support/ScenePlayableFixture.gd")
const OP := preload("res://scripts/narrative/ReadingTraversalOperation.gd")

func before_all() -> void:
	var registration := PLAYABLE.new()
	var configured: Dictionary = registration._install_registration()
	assert_true(configured.ok, str(configured))

func _at_playable() -> RefCounted:
	var created: Dictionary = FIXTURE.create_session()
	assert_true(created.ok, str(created))
	if not created.ok: return null
	var session: RefCounted = created.value
	var entered: Dictionary = FIXTURE.enter(session, FIXTURE.B, "control:1")
	assert_true(entered.ok, str(entered))
	if not entered.ok: return null
	var incoming: Dictionary = session.prepare_scene_next(FIXTURE.frontier(session),
		func(_beat: Dictionary) -> bool: return false)
	assert_true(incoming.ok, str(incoming))
	if not incoming.ok: return null
	var held: Dictionary = OP.project(incoming.value, "destination")
	assert_true(held.ok, str(held))
	if not held.ok: return null
	var restored: Dictionary = session.restore(held.value, FIXTURE.B)
	assert_true(restored.ok, str(restored))
	return session if restored.ok else null

func test_continuation_plans_one_visible_caption_without_mutating_held_custody() -> void:
	var session := _at_playable()
	if session == null: return
	var before: Dictionary = session.capture({})
	assert_true(before.ok, str(before))
	var planned: Dictionary = session.prepare_scene_control_continuation()
	assert_true(planned.ok, str(planned))
	if not planned.ok: return
	var plan: Dictionary = planned.value
	assert_eq(plan.schema_version, 3)
	assert_eq(plan.source_reading.boundary, "control")
	assert_eq(plan.path.size(), 1)
	assert_eq(plan.traversed_captions, [], "B second must be shown, never silently traversed.")
	assert_eq(plan.destination.kind, "line")
	assert_eq(plan.destination.caption.beat.line_id, "line.scene.test.b.two")
	assert_eq(session.capture({}), before, "Planning cannot release control or publish into the live ledger.")
	var projected: Dictionary = OP.project(plan, "destination")
	assert_true(projected.ok, str(projected))
	if not projected.ok: return
	assert_eq(projected.value.ledger.captions.size(), before.value.ledger.captions.size() + 1)
	assert_eq(session.capture({}), before, "Projection grants no commit or native installation authority.")
	plan.destination.caption.beat.line_id = "TEST.changed.detached.copy"
	assert_eq(session.capture({}), before)

func test_ordinary_next_cannot_release_control_and_continuation_refuses_caption_source() -> void:
	var session := _at_playable()
	if session == null: return
	var before: Dictionary = session.capture({})
	assert_false(session.prepare_scene_next({}, func(_beat: Dictionary) -> bool: return false).ok)
	assert_eq(session.capture({}), before)
	var planned: Dictionary = session.prepare_scene_control_continuation()
	assert_true(planned.ok, str(planned))
	if not planned.ok: return
	var projected: Dictionary = OP.project(planned.value, "destination")
	assert_true(projected.ok, str(projected))
	if not projected.ok: return
	var restored: Dictionary = session.restore(projected.value, FIXTURE.B)
	assert_true(restored.ok, str(restored))
	if not restored.ok: return
	var caption_before: Dictionary = session.capture(FIXTURE.frontier(session))
	assert_false(session.prepare_scene_control_continuation().ok, "A caption must use ordinary caption admission.")
	assert_eq(session.capture(FIXTURE.frontier(session)), caption_before)

func test_continuation_cannot_skip_second_caption_to_end_control() -> void:
	var session := _at_playable()
	if session == null: return
	var planned: Dictionary = session.prepare_scene_control_continuation()
	assert_true(planned.ok, str(planned))
	if not planned.ok: return
	var forged: Dictionary = planned.value.duplicate(true)
	var nodes: Array = session._scene_nodes[FIXTURE.B]
	var second: int = forged.destination.program_index
	var end: int = nodes[second].next
	assert_eq(nodes[end].kind, "control")
	forged.path.append({"from": second, "to": end})
	forged.traversed_captions = [forged.destination.caption.duplicate(true)]
	forged.destination = {"kind": "control", "program_index": end, "caption": null}
	assert_false(OP.validate_scene_path(forged, nodes).ok,
		"Even an internally consistent suffix cannot turn continuation into silent Next.")
	assert_eq(session.boundary, "control")

func test_continuation_refuses_end_control_without_following_caption() -> void:
	var session := _at_playable()
	if session == null: return
	var planned: Dictionary = session.prepare_scene_control_continuation()
	assert_true(planned.ok, str(planned))
	if not planned.ok: return
	var caption: Dictionary = OP.project(planned.value, "destination")
	assert_true(caption.ok, str(caption))
	if not caption.ok: return
	assert_true(session.restore(caption.value, FIXTURE.B).ok)
	var to_end: Dictionary = session.prepare_scene_next(FIXTURE.frontier(session),
		func(_beat: Dictionary) -> bool: return false)
	assert_true(to_end.ok, str(to_end))
	if not to_end.ok: return
	var end: Dictionary = OP.project(to_end.value, "destination")
	assert_true(end.ok, str(end))
	if not end.ok: return
	assert_true(session.restore(end.value, FIXTURE.B).ok)
	var before: Dictionary = session.capture({})
	assert_false(session.prepare_scene_control_continuation().ok,
		"End belongs to its registered marker owner, never generic continuation.")
	assert_eq(session.capture({}), before)
