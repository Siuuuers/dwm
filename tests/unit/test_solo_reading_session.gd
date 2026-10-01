extends "res://addons/gut/test.gd"

const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const PRE := "dating.solo.priscilla.day1.pre_challenge"
const POST := "dating.solo.priscilla.day1.post_challenge"
const TOKEN := "fixture:reading-command"
const NEXT := preload("res://scripts/narrative/ReadingTraversalOperation.gd")

func test_next_plan_is_pure_and_stops_before_first_exact_unseen_variant() -> void:
	var session := _session()
	assert_true(session.begin(TOKEN, PRE).ok)
	assert_true(session.admit(PRE, _context(PRE)).ok)
	var frontier := _publish(session, PRE, "fixture.solo.pre.a")
	var before: Dictionary = session.capture(frontier).value
	var queried: Array = []
	var planned: Dictionary = session.prepare_next(frontier, func(variant: Dictionary) -> bool:
		queried.append(variant.duplicate(true))
		return false)
	assert_true(planned.ok, str(planned))
	assert_eq(planned.value.traversed_captions, [])
	assert_eq(planned.value.destination.kind, "line")
	assert_eq(planned.value.destination.caption.beat.line_id, "fixture.solo.pre.b")
	assert_eq(queried, [planned.value.destination.caption.beat])
	assert_eq(session.capture(frontier).value, before, "planning cannot allocate in the live ledger")
	var projected: Dictionary = NEXT.project(planned.value, "destination")
	var restored := _session()
	assert_true(restored.restore(projected.value, PRE).ok)
	assert_eq(restored.project(projected.value.frontier).value.captions.size(), 2)
	assert_eq(restored.capture(projected.value.frontier).value, projected.value)

func test_next_completion_retains_exact_source_and_destination_then_retires_at_new_frame() -> void:
	var session := _session()
	assert_true(session.begin(TOKEN, PRE).ok)
	assert_true(session.admit(PRE, _context(PRE)).ok)
	var frontier := _publish(session, PRE, "fixture.solo.pre.a")
	var planned: Dictionary = session.prepare_next(frontier, func(_variant: Dictionary) -> bool: return true)
	assert_true(planned.ok, str(planned))
	assert_eq(planned.value.destination, {"kind": "completion", "caption": null})
	assert_eq(planned.value.traversed_captions.size(), 1)
	for phase: String in ["source", "destination"]:
		var projected: Dictionary = NEXT.project(planned.value, phase)
		var restored := _session()
		assert_true(restored.restore(projected.value, PRE).ok, phase)
		assert_eq(restored.capture(projected.value.frontier).value, projected.value)
		assert_eq(restored.ledger.snapshot().captions.size(), 1 if phase == "source" else 2)
	var destination: Dictionary = NEXT.project(planned.value, "destination").value
	var completed := _session()
	assert_true(completed.restore(destination, PRE).ok)
	completed.completed(PRE)
	assert_eq(completed.capture({}).value, destination, "physical boundary retains the operation")
	assert_true(completed.admit(POST, _context(POST)).ok)
	var post := _publish(completed, POST, "fixture.solo.post.a")
	assert_eq(completed.capture(post).value.schema_version, 1)
	assert_eq(completed.project(post).value.captions.size(), 3)

func test_next_source_record_rejects_future_variant_tampering_even_with_recomputed_digest() -> void:
	var session := _session()
	assert_true(session.begin(TOKEN, PRE).ok)
	assert_true(session.admit(PRE, _context(PRE)).ok)
	var frontier := _publish(session, PRE, "fixture.solo.pre.a")
	var planned: Dictionary = session.prepare_next(frontier, func(_variant: Dictionary) -> bool: return true)
	var plan: Dictionary = planned.value.duplicate(true)
	plan.traversed_captions[0].beat.presentation_signature.content_revision = "forged"
	var changed: Dictionary = NEXT.project(plan, "source")
	assert_true(changed.ok, "structural schema cannot substitute for actual authored registration")
	var before: Dictionary = session.capture(frontier).value
	assert_false(session.restore(changed.value, PRE).ok)
	assert_eq(session.capture(frontier).value, before)

func test_next_plan_requires_boolean_exact_membership_result_and_current_frontier() -> void:
	var session := _session()
	assert_true(session.begin(TOKEN, PRE).ok)
	assert_true(session.admit(PRE, _context(PRE)).ok)
	var frontier := _publish(session, PRE, "fixture.solo.pre.a")
	var before: Dictionary = session.capture(frontier).value
	assert_false(session.prepare_next(frontier, func(_variant: Dictionary) -> int: return 1).ok)
	var stale := frontier.duplicate(true)
	stale.publication_id = "caption:stale"
	assert_false(session.prepare_next(stale, func(_variant: Dictionary) -> bool: return true).ok)
	assert_eq(session.capture(frontier).value, before)

class Runtime extends RefCounted:
	var halted := 0
	func halt_with_error(_failure: Dictionary) -> void: halted += 1
	func restore_captured_state(_backup: Dictionary) -> Dictionary: return {"ok": true}

func _session() -> RefCounted:
	var session := SESSION.new()
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/dialogic/solo_reading_rail_catalogue.json"))
	assert_true(parsed.ok, str(parsed))
	if not parsed.ok: return session
	assert_eq(typeof(parsed.value.schema_version), TYPE_INT)
	assert_eq(typeof(parsed.value.entries[0].content_version), TYPE_INT)
	var configured: Dictionary = session.configure(parsed.value)
	assert_true(configured.ok, str(configured))
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
	assert_eq(history.value.captions[0].text, "Before the board, a quiet moment. This deliberately long noncanonical fixture line leaves time to open Pause, cancel, continue, and request Backup while the original semantic beat is still revealing.")
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
	assert_eq(session.project(frontier).value.captions[0].text, "Before the board, a quiet moment. This deliberately long noncanonical fixture line leaves time to open Pause, cancel, continue, and request Backup while the original semantic beat is still revealing.")

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

func test_current_variant_is_detached_and_requires_the_admitted_published_tail() -> void:
	var session := _session()
	assert_true(session.begin(TOKEN, PRE).ok)
	assert_true(session.admit(PRE, _context(PRE)).ok)
	assert_false(session.current_caption_variant(PRE, {"line_id": "fixture.solo.pre.a",
		"publication_id": "caption:1"}).ok, "registration and allocation alone are not publication")
	var first := _publish(session, PRE, "fixture.solo.pre.a")
	var current: Dictionary = session.current_caption_variant(PRE, first)
	assert_true(current.ok, str(current))
	assert_eq(current.value, {"beat_id": "fixture.solo.pre.a", "line_id": "fixture.solo.pre.a",
		"owning_entry_id": PRE, "presentation_signature": {
			"content_revision": "fixture-v1", "variant_id": "fixture.solo.pre.a"}})
	current.value.presentation_signature.content_revision = "caller-change"
	assert_eq(session.current_caption_variant(PRE, first).value.presentation_signature.content_revision, "fixture-v1")
	var second := _publish(session, PRE, "fixture.solo.pre.b")
	assert_false(session.current_caption_variant(PRE, first).ok, "older History rows cannot witness the current line")
	assert_false(session.current_caption_variant(POST, second).ok, "another entry cannot claim this occurrence")
	assert_true(session.current_caption_variant(PRE, second).ok)
	session.completed(PRE)
	assert_false(session.current_caption_variant(PRE, second).ok, "completed prose is no longer the foreground")
