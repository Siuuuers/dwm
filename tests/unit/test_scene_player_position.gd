extends "res://addons/gut/test.gd"
## Compact player position retains genuine caption identity, not admission history.
const FIXTURE := preload("res://tests/support/SceneDayReadingFixture.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")

func before_all() -> void:
	assert_true(FIXTURE.configure().ok)

func _session(entry: String = FIXTURE.A) -> RefCounted:
	var made := FIXTURE.create_session()
	assert_true(made.ok, str(made))
	if not made.ok: return null
	var session: RefCounted = made.value
	var occurrence := "TEST.player.position"
	var presentation := FROZEN.build(entry, {"entry_id": entry, "entry_role": "scene",
		"occurrence_id": occurrence, "admission_receipt_id": occurrence})
	assert_true(presentation.ok, str(presentation))
	if not presentation.ok: return null
	var frame := {"expected_stage": "scene", "playback_id": occurrence, "role": "scene",
		"transaction_id": occurrence, "presentation": presentation.value}
	assert_true(session.admit_scene(entry, frame).ok)
	var programme: Dictionary = session.entry_program(entry, frame)
	var allocation: Dictionary = session.ledger.allocate_publication(session.command_id, entry, occurrence)
	assert_true(session.ledger.publish_line(session.command_id, allocation.value, entry,
		programme.value.lines[0].line_id, occurrence).ok)
	return session

func _checkpoint(session: RefCounted) -> Dictionary:
	var frontier := FIXTURE.frontier(session) if session.boundary == "line" else {}
	var captured: Dictionary = session.capture(frontier)
	assert_true(captured.ok, str(captured))
	if not captured.ok: return {}
	var frame: Dictionary = session.ledger.snapshot().entry_contexts.values()[0]
	return {"entry_id": session.latest_entry, "content_version": 1,
		"manifest_fingerprint": session.fingerprint, "frozen_context": frame,
		"transaction_id": session.scene_occurrence, "stage": "scene", "reading_session": captured.value}

func test_compact_position_preserves_current_caption_and_continues_without_id_reuse() -> void:
	var session := _session()
	if session == null: return
	for index: int in 8:
		assert_true(FIXTURE.advance_detached(session).ok)
	var live := _checkpoint(session)
	var before := live.duplicate(true)
	var player := SESSION.project_player_checkpoint(live)
	assert_true(player.ok, str(player))
	if not player.ok: return
	var saved: Dictionary = player.value.reading_session
	assert_eq(saved.schema_version, 7)
	assert_eq(saved.captions.size(), 1)
	assert_eq(saved.publication_serial, 9)
	assert_false(saved.has("ledger"))
	assert_false(saved.has("next_operation"))
	assert_eq(live, before, "player projection leaves complete live backup intact")
	assert_eq(SESSION.project_player_checkpoint(player.value), player, "canonical projection is idempotent")
	var expanded := SESSION.expand_player_checkpoint(player.value)
	assert_true(expanded.ok, str(expanded))
	if not expanded.ok: return
	var restored := SESSION.new()
	assert_true(restored.configure_scene().ok)
	assert_true(restored.restore_player(saved, session.latest_entry).ok)
	assert_eq(restored.project(FIXTURE.frontier(restored)).value.captions.size(), 1)
	assert_eq(restored.project_scene_caption_memory(FIXTURE.frontier(restored)).value.captions.size(), 1)
	assert_eq(SESSION.project_player_checkpoint(expanded.value), player)
	assert_true(FIXTURE.advance_detached(restored).ok, "fresh live traversal works after bounded restoration")
	assert_eq(FIXTURE.frontier(restored).publication_id, "caption:10")

func test_held_control_keeps_authored_predecessor_without_traversal_proof() -> void:
	var session := _session(FIXTURE.B)
	if session == null: return
	assert_true(FIXTURE.advance_detached(session).ok)
	assert_true(FIXTURE.advance_detached(session).ok)
	assert_eq(session.boundary, "control")
	var player := SESSION.project_player_checkpoint(_checkpoint(session))
	assert_true(player.ok, str(player))
	if not player.ok: return
	var restored := SESSION.new()
	assert_true(restored.configure_scene().ok)
	assert_true(restored.restore_player(player.value.reading_session, FIXTURE.B).ok)
	assert_eq(restored.boundary, "control")
	assert_eq(restored.scene_index, session.scene_index)
	assert_true(restored.next_operation.is_empty(), "player Load carries no past traversal proof")
	assert_eq(restored.prepare_scene_control_continuation(), session.prepare_scene_control_continuation(),
		"transition control still requires route-owner departure")

func test_compact_line_and_control_projection_is_idempotent_and_detached() -> void:
	for held: bool in [false, true]:
		var session := _session(FIXTURE.B)
		if session == null: return
		assert_true(FIXTURE.advance_detached(session).ok)
		if held: assert_true(FIXTURE.advance_detached(session).ok)
		var player := SESSION.project_player_checkpoint(_checkpoint(session))
		assert_true(player.ok, str(player))
		if not player.ok: return
		var before: Dictionary = player.value.duplicate(true)
		var projected := SESSION.project_player_checkpoint(player.value)
		assert_eq(projected, player, "line and held control retain exact compact state")
		if not projected.ok: return
		projected.value.reading_session.captions[0].line_id = "changed.caption"
		projected.value.reading_session.history_sections[0].append("changed.history")
		projected.value.reading_session.recovery_anchor.line_id = "changed.anchor"
		projected.value.frozen_context.presentation.fields.entry_id = "changed.context"
		assert_eq(player.value, before, "mutating a projected checkpoint cannot change its source")

func test_live_projection_preserves_loop_history_and_multiple_occurrences() -> void:
	for held: bool in [false, true]:
		var session := _session()
		if session == null: return
		for step: int in 3: assert_true(FIXTURE.advance_detached(session).ok)
		assert_true(FIXTURE.enter(session, FIXTURE.B, "TEST.second.occurrence").ok)
		assert_true(FIXTURE.advance_detached(session).ok)
		var captured: Dictionary = FIXTURE.checkpoint(session)
		assert_true(captured.ok, str(captured))
		if not captured.ok: return
		var live: Dictionary = captured.value
		if held:
			assert_true(FIXTURE.advance_detached(session).ok)
			live.reading_session = session.capture({}).value
		var before := live.duplicate(true)
		# Differential oracle retains the former full admission before conversion.
		var admitted := SESSION.new()
		assert_true(admitted.configure_scene().ok)
		assert_true(admitted.restore(live.reading_session, FIXTURE.B).ok)
		var expected := live.duplicate(true)
		expected.reading_session = admitted._project_player_reading(live.reading_session).value
		var projected := SESSION.project_player_checkpoint(live)
		assert_true(projected.ok, str(projected))
		if not projected.ok: return
		assert_eq(projected.value, expected, "direct conversion equals full-admission conversion")
		assert_eq(live, before, "conversion changes neither ledger nor traversal proof")
		var saved: Dictionary = projected.value.reading_session
		assert_eq(saved.captions, [{"line_id": "line.scene.test.b.two", "publication_id": "caption:6"}])
		assert_eq(saved.occurrence_id, "TEST.second.occurrence")
		assert_eq(saved.publication_serial, 6)
		assert_eq(saved.history_sections, [["line.scene.test.a.one", "line.scene.test.a.two",
			"line.scene.test.b.one", "line.scene.test.b.two"]])
		assert_false(saved.has("ledger"))
		assert_false(saved.has("next_operation"))
		var restored := SESSION.new()
		assert_true(restored.configure_scene().ok)
		assert_true(restored.restore_player(saved, FIXTURE.B).ok)
		assert_eq(restored.scene_index, session.scene_index)
		assert_eq(restored.boundary, session.boundary)
		if not held:
			assert_true(FIXTURE.advance_detached(session).ok)
			assert_true(FIXTURE.advance_detached(restored).ok)
			assert_eq(restored.boundary, "control")
			assert_eq(restored.scene_index, session.scene_index)
		assert_eq(restored.prepare_scene_control_continuation(), session.prepare_scene_control_continuation())
		projected.value.reading_session.history_sections[0].append("changed.history")
		assert_eq(live, before, "compact History does not alias the live capture")

func test_live_projection_keeps_wrapper_and_required_compact_reference_checks() -> void:
	var session := _session(FIXTURE.B)
	if session == null: return
	assert_true(FIXTURE.advance_detached(session).ok)
	assert_true(FIXTURE.advance_detached(session).ok)
	var checkpoint := _checkpoint(session)
	for changed: String in ["wrapper", "control", "caption", "publication"]:
		var bad := checkpoint.duplicate(true)
		match changed:
			"wrapper": bad.entry_id = FIXTURE.A
			"control": bad.reading_session.program_index = 999
			"caption": bad.reading_session.ledger.captions.back().beat.line_id = "line.missing"
			"publication": bad.reading_session.ledger.captions.back().publication_id = "invented"
		var before := bad.duplicate(true)
		assert_false(SESSION.project_player_checkpoint(bad).ok, changed)
		assert_eq(bad, before, "refusal leaves captured source intact")

func test_invalid_locator_memory_and_compatibility_refuse_before_adoption() -> void:
	var session := _session()
	if session == null: return
	var player := SESSION.project_player_checkpoint(_checkpoint(session))
	assert_true(player.ok, str(player))
	if not player.ok: return
	var before := _checkpoint(session)
	for field: String in ["position_id", "registration_sha256", "occurrence_id", "publication_serial", "captions"]:
		var bad: Dictionary = player.value.reading_session.duplicate(true)
		match field:
			"position_id": bad.position_id = "missing.line"
			"registration_sha256": bad.registration_sha256 = "missing.programme"
			"occurrence_id": bad.occurrence_id = ""
			"publication_serial": bad.publication_serial = 0
			"captions": bad.captions.append(bad.captions[0].duplicate(true))
		assert_false(session.restore_player(bad, session.latest_entry).ok, field)
		var checkpoint: Dictionary = player.value.duplicate(true)
		checkpoint.reading_session = bad
		var unchanged := checkpoint.duplicate(true)
		assert_false(SESSION.project_player_checkpoint(checkpoint).ok, field)
		assert_eq(checkpoint, unchanged, "failed projection leaves supplied checkpoint intact")
		assert_eq(_checkpoint(session), before, "refusal leaves live state intact: " + field)

func test_compact_publication_requires_canonical_positive_unexhausted_counter() -> void:
	var session := _session()
	if session == null: return
	var player := SESSION.project_player_checkpoint(_checkpoint(session))
	assert_true(player.ok, str(player))
	if not player.ok: return
	var before := _checkpoint(session)
	for pair: Array in [["invented", 0], ["caption:01", 1], ["caption:-1", 1],
			["caption:9223372036854775807", 9223372036854775807],
			["caption:999999999999999999999999999", 1]]:
		var bad: Dictionary = player.value.reading_session.duplicate(true)
		bad.captions[0].publication_id = pair[0]
		bad.publication_serial = pair[1]
		assert_false(session.restore_player(bad, session.latest_entry).ok, str(pair))
		assert_eq(_checkpoint(session), before, "invalid counter preserves existing live reading")

func test_publication_exhaustion_refuses_before_increment_or_collision_wrap() -> void:
	var session := _session()
	if session == null: return
	var maximum: int = 9223372036854775807
	session.ledger._publication_serial = maximum
	var result: Dictionary = session.ledger.allocate_publication(session.command_id, session.latest_entry, session.scene_occurrence)
	assert_false(result.ok)
	assert_eq(result.code, &"caption_publication_exhausted")
	assert_eq(session.ledger._publication_serial, maximum)
	var frontier := FIXTURE.frontier(session)
	assert_true(session.ledger.publish_line(session.command_id, "caption:%d" % maximum,
		session.latest_entry, frontier.line_id, session.scene_occurrence).ok)
	session.ledger._publication_serial = maximum - 1
	result = session.ledger.allocate_publication(session.command_id, session.latest_entry, session.scene_occurrence)
	assert_false(result.ok, "collision at maximum cannot wrap the allocator")
	assert_eq(result.code, &"caption_publication_exhausted")
	assert_eq(session.ledger._publication_serial, maximum)

