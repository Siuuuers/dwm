extends "res://addons/gut/test.gd"

const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const PRE := "dating.solo.priscilla.day1.pre_challenge"
const POST := "dating.solo.priscilla.day1.post_challenge"
const TOKEN := "fixture:reading-command"

class Runtime extends RefCounted:
	var halted := 0
	func halt_with_error(_failure: Dictionary) -> void: halted += 1
	func restore_captured_state(_backup: Dictionary) -> Dictionary: return {"ok": true}

func _session() -> RefCounted:
	var session := SESSION.new()
	var document: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/dialogic/solo_reading_rail_catalogue.json"))
	assert_true(session.configure(document).ok)
	return session

func _context(entry_id: String) -> Dictionary:
	var phase := "pre_challenge" if entry_id == PRE else "post_challenge"
	var fields := {"entry_id": entry_id, "entry_role": "solo_" + phase, "day": 1,
		"friend_id": "priscilla", "tier": "friend", "tone": "sweet", "attitude": "",
		"run_id": "fixture:run", "branch_id": "fixture:branch",
		"challenge_slot": "dating.solo.priscilla.day1", "phase": phase,
		"due_echoes": [], "attempt_residue_id": null}
	if entry_id == POST:
		fields.merge({"attempt_id": "fixture:attempt", "board_result": "cleared",
			"perfect_reasons": [], "relationship_outcome": "loved", "effect_receipt_id": "fixture:effect"})
	var presentation := FROZEN.build(entry_id, fields)
	assert_true(presentation.ok, str(presentation))
	return {"expected_stage": phase, "playback_id": "fixture:physical:" + phase,
		"role": "dating_phase", "transaction_id": TOKEN + ":" + phase, "presentation": presentation.value}

func _publish(session: RefCounted, entry_id: String, line_id: String) -> Dictionary:
	var allocated: Dictionary = session.ledger.allocate_publication(TOKEN, entry_id)
	assert_true(allocated.ok)
	assert_true(session.ledger.publish_line(TOKEN, allocated.value, entry_id, line_id).ok)
	return {"line_id": line_id, "publication_id": allocated.value}

func test_real_phase_frames_are_causal_and_one_history_survives_board_boundary() -> void:
	var session := _session()
	assert_true(session.begin(TOKEN, PRE).ok)
	assert_true(session.admit(PRE, _context(PRE)).ok)
	_publish(session, PRE, "fixture.solo.pre.a")
	_publish(session, PRE, "fixture.solo.pre.b")
	session.completed(PRE)
	var board: Dictionary = session.capture({})
	assert_true(board.ok, str(board))
	assert_false(board.value.ledger.entry_contexts.has(POST), "future outcome is not frozen early")
	var restored := _session()
	assert_true(restored.restore(board.value, PRE).ok)
	assert_true(restored.admit(POST, _context(POST)).ok)
	var frontier := _publish(restored, POST, "fixture.solo.post.a")
	var history: Dictionary = restored.project(frontier)
	assert_true(history.ok, str(history))
	assert_eq(history.value.captions.size(), 3)
	assert_eq(history.value.captions[0].text, "Before the board, a quiet moment.")
	assert_eq(history.value.captions[2].line_id, "fixture.solo.post.a")
	assert_eq(restored.ledger.snapshot().entry_contexts[PRE], _context(PRE))

func test_invalid_suffix_frontier_or_completed_prefix_never_replace_retained_history() -> void:
	var source := _session()
	assert_true(source.begin(TOKEN, PRE).ok)
	assert_true(source.admit(PRE, _context(PRE)).ok)
	_publish(source, PRE, "fixture.solo.pre.a")
	var frontier := _publish(source, PRE, "fixture.solo.pre.b")
	var saved: Dictionary = source.capture(frontier).value
	var target := _session()
	assert_true(target.restore(saved, PRE).ok)
	var before: Dictionary = target.ledger.snapshot()
	var poisoned := saved.duplicate(true)
	poisoned.ledger.captions[1].beat.line_id = "fixture.solo.post.a"
	assert_false(target.restore(poisoned, PRE).ok)
	poisoned = saved.duplicate(true)
	poisoned.frontier = {"line_id": "fixture.solo.pre.a", "publication_id": saved.ledger.captions[0].publication_id}
	assert_false(target.restore(poisoned, PRE).ok)
	poisoned = saved.duplicate(true)
	poisoned.ledger.captions.pop_back()
	poisoned.boundary = "between_entries"
	poisoned.frontier = {}
	assert_false(target.restore(poisoned, PRE).ok, "a truncated prefix cannot claim entry completion")
	assert_eq(target.ledger.snapshot(), before)

func test_projection_and_capture_are_detached_and_rebinding_an_entry_is_refused() -> void:
	var session := _session()
	assert_true(session.begin(TOKEN, PRE).ok)
	var context := _context(PRE)
	assert_true(session.admit(PRE, context).ok)
	var frontier := _publish(session, PRE, "fixture.solo.pre.a")
	var captured: Dictionary = session.capture(frontier)
	assert_true(captured.ok)
	var before: Dictionary = session.ledger.snapshot()
	captured.value.ledger.entry_contexts[PRE].presentation.fields.tone = "dark"
	var history: Dictionary = session.project(frontier)
	history.value.captions[0].text = "caller replacement"
	context.presentation.fields.tone = "dark"
	assert_false(session.admit(PRE, context).ok)
	assert_eq(session.ledger.snapshot(), before)
	assert_eq(session.project(frontier).value.captions[0].text, "Before the board, a quiet moment.")

func test_route_finalize_failure_retires_only_the_started_restore_and_reinstates_session() -> void:
	var bridge := preload("res://autoload/DialogicBridge.gd").new()
	var runtime := Runtime.new()
	bridge._runtime_adapter = runtime
	var source := _session()
	assert_true(source.begin(TOKEN, PRE).ok)
	bridge._reading_session = source
	bridge._reading_adoption_checkpoint = {"source": "retained"}
	var backup: Dictionary = bridge.capture_restore_state().value.backup
	var candidate := _session()
	bridge._reading_session = candidate
	bridge._reading_restore_token = "resume:target"
	bridge._active_entry = {"token": "resume:target", "entry_id": PRE}
	bridge._reading_restore_adoption = true
	bridge._reading_adoption_checkpoint = {"target": "must disappear"}
	assert_true(bridge.rollback_restore_silent(backup).ok)
	assert_eq(runtime.halted, 1)
	assert_true(bridge._active_entry.is_empty(), "failed route publication leaves no target playback")
	assert_same(bridge._reading_session, source)
	assert_false(bridge._reading_restore_adoption)
	assert_eq(bridge._reading_adoption_checkpoint, {"source": "retained"})
	bridge.free()
