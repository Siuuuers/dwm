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

