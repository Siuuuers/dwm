extends "res://addons/gut/test.gd"

const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const PRE := "dating.solo.priscilla.day1.pre_challenge"
const POST := "dating.solo.priscilla.day1.post_challenge"
const TOKEN := "fixture:reading-command"
const NEXT := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
const HOSPITAL_FIXTURE := preload("res://tests/support/HospitalReadingFixture.gd")
const HOSPITAL_ENTRY := "hospital.faint.day3"

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

func _hospital_session() -> RefCounted:
	var session := SESSION.new()
	assert_true(session.configure(HOSPITAL_FIXTURE.catalogue()).ok)
	return session

func _hospital_context() -> Dictionary:
	var presentation := FROZEN.build(HOSPITAL_ENTRY, {"entry_id": HOSPITAL_ENTRY, "entry_role": "hospital",
		"day": 3, "qualifying_cause": "schedule_done", "accepted_record_ids": ["fixture:sylvia-source"],
		"unfulfilled_record_ids": ["fixture:sylvia-source"], "sylvia_eligible": true,
		"sylvia_witness_receipt_id": null})
	assert_true(presentation.ok, str(presentation))
	return {"expected_stage": "hospital", "role": "hospital", "transaction_id": TOKEN + ":hospital",
		"playback_id": "fixture:physical:hospital", "presentation": presentation.value}

func test_hospital_catalogue_is_one_closed_day_entry_with_exact_fixed_line_registration() -> void:
	for day: int in range(1, 8):
		var session := SESSION.new()
		assert_true(session.configure(HOSPITAL_FIXTURE.catalogue(day)).ok)
		assert_eq(session.family, "hospital")
		assert_eq(session.catalogue_schema_version, 1)
	for entry: String in [PRE, "hospital.faint", "hospital.faint.day0", "hospital.faint.day8", "hospital.faint.day03"]:
		var document := HOSPITAL_FIXTURE.catalogue()
		document.entries[0].entry_id = entry
		var session := SESSION.new()
		assert_false(session.configure(document).ok, entry)
		assert_true(session.catalogue.is_empty(), "failed admission installs no partial catalogue")
		assert_true(session.configure(HOSPITAL_FIXTURE.catalogue()).ok)
	for mutation: String in ["version", "extra_entry", "empty_lines", "extra_field", "duplicate_line"]:
		var document := HOSPITAL_FIXTURE.catalogue()
		match mutation:
			"version": document.schema_version = 2
			"extra_entry": document.entries.append(document.entries[0].duplicate(true))
			"empty_lines": document.entries[0].lines = []
			"extra_field": document.entries[0]["selector_fields"] = []
			"duplicate_line": document.entries[0].lines[1].line_id = document.entries[0].lines[0].line_id
		assert_false(SESSION.new().configure(document).ok, mutation)

func test_hospital_registration_and_frame_admission_never_prefill_history() -> void:
	var session := _hospital_session()
	assert_true(session.begin(TOKEN, HOSPITAL_ENTRY).ok)
	assert_eq(session.ledger.snapshot().captions, [])
	assert_eq(session.ledger.snapshot().entry_contexts, {})
	assert_eq(session.ledger.snapshot().frozen_context,
		{"family": "hospital", "completion_transaction_id": TOKEN, "entry_id": HOSPITAL_ENTRY})
	assert_true(session.admit(HOSPITAL_ENTRY, _hospital_context()).ok)
	assert_eq(session.ledger.snapshot().captions, [], "a causal frame is not a publication")
	var allocated: Dictionary = session.ledger.allocate_publication(TOKEN, HOSPITAL_ENTRY)
	assert_true(allocated.ok)
	assert_eq(session.ledger.snapshot().captions, [], "allocation is not a publication")
	assert_false(session.capture({"line_id": "fixture.hospital.a", "publication_id": allocated.value}).ok)
	assert_true(session.ledger.publish_line(TOKEN, allocated.value, HOSPITAL_ENTRY, "fixture.hospital.a").ok)
	var frontier := {"line_id": "fixture.hospital.a", "publication_id": allocated.value}
	assert_eq(session.project(frontier).value.captions.size(), 1, "unreached B stays out of History")
	var before: Dictionary = session.capture(frontier).value
	var queried: Array = []
	assert_eq(session.prepare_next(frontier, func(beat: Dictionary) -> bool:
		queried.append(beat)
		return true).get("code"), &"reading_next_unavailable")
	assert_eq(queried, [], "Hospital traversal is outside this admitted slice")
	assert_eq(session.capture(frontier).value, before)

func test_ordinary_hospital_frame_admits_and_restores_without_fabricating_sylvia_or_history() -> void:
	var frame := _hospital_context()
	frame.presentation.fields.accepted_record_ids = []
	frame.presentation.fields.unfulfilled_record_ids = []
	frame.presentation.fields.sylvia_eligible = false
	var session := _hospital_session()
	assert_true(session.begin(TOKEN, HOSPITAL_ENTRY).ok)
	assert_true(session.admit(HOSPITAL_ENTRY, frame).ok)
	assert_true(session.ledger.snapshot().captions.is_empty(), "admission does not invent a witnessed caption")
	var frontier := _publish(session, HOSPITAL_ENTRY, "fixture.hospital.a")
	var saved: Dictionary = session.capture(frontier).value
	var target := _hospital_session()
	assert_true(target.restore(saved, HOSPITAL_ENTRY).ok)
	assert_eq(target.capture(frontier).value, saved, "ordinary recovery retains the exact admitted frame")
	assert_false(saved.ledger.entry_contexts[HOSPITAL_ENTRY].presentation.fields.sylvia_eligible)
	assert_null(saved.ledger.entry_contexts[HOSPITAL_ENTRY].presentation.fields.sylvia_witness_receipt_id)
	for mutation: String in ["condition", "foreign_day", "forged_stage"]:
		var invalid := frame.duplicate(true)
		match mutation:
			"condition": invalid.presentation.fields.qualifying_cause = "condition_hospital"
			"foreign_day": invalid.presentation.fields.day = 4
			"forged_stage": invalid.expected_stage = "post_challenge"
		var candidate := _hospital_session()
		assert_true(candidate.begin(TOKEN, HOSPITAL_ENTRY).ok)
		assert_false(candidate.admit(HOSPITAL_ENTRY, invalid).ok, mutation)

func test_hospital_frame_refuses_other_causes_foreign_phase_and_changed_eligibility_without_rebinding() -> void:
	var session := _hospital_session()
	assert_true(session.begin(TOKEN, HOSPITAL_ENTRY).ok)
	assert_true(session.admit(HOSPITAL_ENTRY, _hospital_context()).ok)
	var frontier := _publish(session, HOSPITAL_ENTRY, "fixture.hospital.a")
	var before: Dictionary = session.capture(frontier).value
	for mutation: String in ["condition", "changed_eligibility", "stage", "role", "transaction", "playback", "playback_suffix", "rebind_source", "day", "extra"]:
		var frame := _hospital_context()
		match mutation:
			"condition": frame.presentation.fields.qualifying_cause = "condition_hospital"
			"changed_eligibility": frame.presentation.fields.sylvia_eligible = false
			"stage": frame.expected_stage = "pre_challenge"
			"role": frame.role = "dating_phase"
			"transaction": frame.transaction_id = "other:completion:hospital"
			"playback": frame.playback_id = ""
			"playback_suffix": frame.playback_id = "fixture:physical:pre_challenge"
			"rebind_source":
				frame.presentation.fields.accepted_record_ids = ["other:sylvia-source"]
				frame.presentation.fields.unfulfilled_record_ids = ["other:sylvia-source"]
			"day": frame.presentation.fields.day = 4
			"extra": frame["source"] = "unregistered"
		assert_false(session.admit(HOSPITAL_ENTRY, frame).ok, mutation)
		assert_eq(session.capture(frontier).value, before, mutation)
	assert_false(session.admit(PRE, _context(PRE)).ok)
	assert_false(session.begin(TOKEN, HOSPITAL_ENTRY).ok, "one instance cannot adopt a second session")

func test_hospital_v3_restores_exact_published_prefix_and_refuses_downgrade_or_foreign_rows() -> void:
	var source := _hospital_session()
	assert_true(source.begin(TOKEN, HOSPITAL_ENTRY).ok)
	assert_true(source.admit(HOSPITAL_ENTRY, _hospital_context()).ok)
	_publish(source, HOSPITAL_ENTRY, "fixture.hospital.a")
	var frontier := _publish(source, HOSPITAL_ENTRY, "fixture.hospital.b")
	var saved: Dictionary = source.capture(frontier).value
	assert_eq(saved.schema_version, 3)
	assert_eq(saved.family, "hospital")
	var target := _hospital_session()
	assert_true(target.restore(saved, HOSPITAL_ENTRY).ok)
	assert_eq(target.capture(frontier).value, saved)
	assert_eq(target.project(frontier).value.captions.size(), 2)
	assert_eq(target.pre_entry_id, HOSPITAL_ENTRY, "internal entry custody does not fabricate a Solo ID")
	assert_false(_session().restore(saved, HOSPITAL_ENTRY).ok, "a Solo catalogue cannot admit Hospital data")
	for mutation: String in ["version1", "version2", "float_version", "missing_family", "wrong_family",
			"old_context", "foreign_row", "wrong_frontier", "duplicate_publication", "extra_frame"]:
		var changed := saved.duplicate(true)
		match mutation:
			"version1": changed.schema_version = 1
			"version2": changed.schema_version = 2
			"float_version": changed.schema_version = 3.0
			"missing_family": changed.erase("family")
			"wrong_family": changed.family = "solo"
			"old_context": changed.ledger.frozen_context = {"completion_transaction_id": TOKEN, "pre_entry_id": HOSPITAL_ENTRY}
			"foreign_row": changed.ledger.captions[0].beat.owning_entry_id = PRE
			"wrong_frontier": changed.frontier.publication_id = changed.ledger.captions[0].publication_id
			"duplicate_publication": changed.ledger.captions[1].publication_id = changed.ledger.captions[0].publication_id
			"extra_frame": changed.ledger.entry_contexts[PRE] = _context(PRE)
		assert_false(target.restore(changed, HOSPITAL_ENTRY).ok, mutation)
		assert_eq(target.capture(frontier).value, saved, "refusal preserves the standing Hospital session: " + mutation)
	var detached: Dictionary = target.project(frontier).value
	detached.captions[0].text = "caller replacement"
	assert_eq(target.capture(frontier).value, saved)

func test_hospital_completed_anchor_requires_full_prefix_without_a_new_publication() -> void:
	var session := _hospital_session()
	assert_true(session.begin(TOKEN, HOSPITAL_ENTRY).ok)
	assert_true(session.admit(HOSPITAL_ENTRY, _hospital_context()).ok)
	_publish(session, HOSPITAL_ENTRY, "fixture.hospital.a")
	var frontier := _publish(session, HOSPITAL_ENTRY, "fixture.hospital.b")
	var before: Dictionary = session.ledger.snapshot()
	session.completed(HOSPITAL_ENTRY)
	assert_eq(session.ledger.snapshot(), before)
	assert_false(session.current_caption_variant(HOSPITAL_ENTRY, frontier).ok)
	var completed: Dictionary = session.capture({})
	assert_true(completed.ok, str(completed))
	assert_eq(completed.value.boundary, "between_entries")
	assert_eq(session.project({}).value.captions.size(), 2, "pending settlement retains the final anchor")
	var changed: Dictionary = completed.value.duplicate(true)
	changed.ledger.captions.pop_back()
	assert_false(session.validate_saved(changed, HOSPITAL_ENTRY).ok, "an early prefix cannot claim physical completion")
	assert_eq(session.capture({}).value, completed.value)

const ENDING_FROZEN := preload("res://scripts/narrative/EndingFrozenContext.gd")
const ENDING_CHAIN := "fixture:run:ending"
const ENDING_FIRST := "ending.priscilla.sweet"
const ENDING_SECOND := "ending.priscilla_lavinia.sweet"
const ENDING_THIRD := "ending.priscilla.observer.residue"

func _ending_catalogue() -> Dictionary:
	var entries: Array = []
	for index: int in range(3):
		var lines: Array = []
		for suffix: String in ["a", "b"]:
			var line_id := "fixture.ending.%d.%s" % [index, suffix]
			lines.append({"beat_id": line_id, "line_id": line_id,
				"text": "Ending step %d, caption %s." % [index, suffix], "revision": "fixture-v1"})
		entries.append({"entry_id": [ENDING_FIRST, ENDING_SECOND, ENDING_THIRD][index],
			"content_version": 1, "lines": lines})
	return {"kind": "ending_reading_catalogue", "schema_version": 1, "entries": entries}

func _ending_session() -> RefCounted:
	var session := SESSION.new()
	assert_true(session.configure(_ending_catalogue()).ok)
	return session

func _ending_context(index: int) -> Dictionary:
	var inputs := {"dark_mode": false, "pair_form": "love_sweet", "special_variant": "full"}
	for friend: String in ENDING_FROZEN.FRIENDS:
		inputs[friend] = {"tier": "love", "tone": "sweet", "attitude": "affectionate", "echo_ids": [], "miss_reasons": []}
	var seed := ENDING_FROZEN.make_seed(inputs,
		{"priscilla": [], "lavinia": [], "sylvia": [], "priscilla_lavinia": []}, [], "empty_done")
	assert_true(seed.ok, str(seed))
	var plan := {"steps": [{"ending_id": ENDING_FIRST, "role": "core"},
		{"ending_id": ENDING_SECOND, "role": "pair_coda"},
		{"ending_id": "ending.priscilla.observation", "role": "observer_coda", "presentation_variant": "residue"}],
		"playback_receipts": {}}
	for previous: int in range(index):
		plan.playback_receipts["step:%d" % previous] = {"value": {"outcome": "completed",
			"timeline_completion_receipt_id": "%s:%d:complete" % [ENDING_CHAIN, previous]}}
	var playback_id := "%s:%d" % [ENDING_CHAIN, index]
	var frozen := ENDING_FROZEN.build(plan, index, seed.value, playback_id)
	assert_true(frozen.ok, str(frozen))
	return {"expected_stage": "PRIMARY_PENDING", "role": plan.steps[index].role,
		"playback_id": playback_id, "transaction_id": playback_id + ":complete",
		"presentation": frozen.value.presentation}

func _ending_publish(session: RefCounted, index: int, suffix: String) -> Dictionary:
	var entry_id: String = [ENDING_FIRST, ENDING_SECOND, ENDING_THIRD][index]
	var line_id := "fixture.ending.%d.%s" % [index, suffix]
	var allocated: Dictionary = session.ledger.allocate_publication(ENDING_CHAIN, entry_id)
	assert_true(allocated.ok, str(allocated))
	assert_true(session.ledger.publish_line(ENDING_CHAIN, allocated.value, entry_id, line_id).ok)
	return {"line_id": line_id, "publication_id": allocated.value}

func _ending_at_second_step() -> Dictionary:
	var session := _ending_session()
	assert_true(session.begin(ENDING_CHAIN, ENDING_FIRST).ok)
	assert_true(session.admit(ENDING_FIRST, _ending_context(0)).ok)
	_ending_publish(session, 0, "a")
	_ending_publish(session, 0, "b")
	session.completed(ENDING_FIRST)
	assert_true(session.admit(ENDING_SECOND, _ending_context(1)).ok)
	var frontier := _ending_publish(session, 1, "a")
	return {"session": session, "frontier": frontier}

func test_ending_frames_advance_only_after_complete_preceding_caption_prefix() -> void:
	var session := _ending_session()
	assert_false(session.begin(ENDING_CHAIN, ENDING_SECOND).ok)
	assert_true(session.begin(ENDING_CHAIN, ENDING_FIRST).ok)
	assert_false(session.admit(ENDING_SECOND, _ending_context(1)).ok)
	assert_true(session.admit(ENDING_FIRST, _ending_context(0)).ok)
	assert_eq(session.ledger.snapshot().captions, [], "admission cannot invent History")
	_ending_publish(session, 0, "a")
	var before: Dictionary = session.ledger.snapshot()
	assert_false(session.admit(ENDING_SECOND, _ending_context(1)).ok)
	session.completed(ENDING_FIRST)
	assert_false(session.admit(ENDING_SECOND, _ending_context(1)).ok, "completion cannot disguise an omitted caption")
	assert_eq(session.ledger.snapshot(), before)
	_ending_publish(session, 0, "b")
	assert_false(session.admit(ENDING_FIRST, _ending_context(0)).ok, "completed prose cannot reopen its foreground")
	assert_eq(session.boundary, "between_entries")
	assert_false(session.admit(ENDING_THIRD, _ending_context(2)).ok, "ordered admission cannot skip a step")
	assert_true(session.admit(ENDING_SECOND, _ending_context(1)).ok)
	assert_false(session.admit(ENDING_FIRST, _ending_context(0)).ok, "an old frame cannot become foreground again")
	assert_eq(session.ledger.snapshot().captions.size(), 2)

func test_ending_fresh_restore_keeps_exact_cross_step_history_and_published_frontier() -> void:
	var source := _ending_at_second_step()
	var saved: Dictionary = source.session.capture(source.frontier).value
	assert_eq(saved.schema_version, 3)
	assert_eq(saved.family, "ending")
	assert_eq(saved.ledger.frozen_context,
		{"family": "ending", "completion_transaction_id": ENDING_CHAIN, "entry_id": ENDING_FIRST})
	assert_false(saved.ledger.entry_contexts.has(ENDING_THIRD), "future step facts are not admitted early")
	var target := _ending_session()
	assert_true(target.restore(saved, ENDING_SECOND).ok)
	assert_eq(target.capture(source.frontier).value, saved, "restore allocates no new occurrence")
	var history: Dictionary = target.project(source.frontier).value
	assert_eq(history.captions.size(), 3)
	assert_eq(history.captions[0].text, "Ending step 0, caption a.")
	assert_eq(history.captions[1].text, "Ending step 0, caption b.")
	assert_eq(history.captions[2].text, "Ending step 1, caption a.")
	assert_eq(history.frontier, source.frontier)
	assert_eq(target.current_caption_variant(ENDING_SECOND, source.frontier).value.line_id, "fixture.ending.1.a")
	history.captions[0].text = "caller mutation"
	assert_eq(target.capture(source.frontier).value, saved)
	assert_false(_session().restore(saved, ENDING_SECOND).ok)
	assert_false(_hospital_session().restore(saved, ENDING_SECOND).ok)

func test_ending_rejects_corrupt_cross_step_saves_without_replacing_standing_history() -> void:
	var source := _ending_at_second_step()
	var saved: Dictionary = source.session.capture(source.frontier).value
	var target := _ending_session()
	assert_true(target.restore(saved, ENDING_SECOND).ok)
	for mutation: String in ["omitted_caption", "duplicate_caption", "foreign_caption", "reordered_captions",
			"missing_frame", "future_frame", "reordered_frame_tokens", "missing_family", "wrong_family",
			"malformed_family", "version1", "version2", "float_version", "wrong_frontier", "wrong_first"]:
		var changed := saved.duplicate(true)
		match mutation:
			"omitted_caption": changed.ledger.captions.remove_at(1)
			"duplicate_caption": changed.ledger.captions.insert(1, changed.ledger.captions[0].duplicate(true))
			"foreign_caption": changed.ledger.captions[0].beat.owning_entry_id = PRE
			"reordered_captions": changed.ledger.captions.reverse()
			"missing_frame": changed.ledger.entry_contexts.erase(ENDING_FIRST)
			"future_frame": changed.ledger.entry_contexts[ENDING_THIRD] = _ending_context(2)
			"reordered_frame_tokens":
				changed.ledger.entry_contexts[ENDING_FIRST].playback_id = ENDING_CHAIN + ":1"
				changed.ledger.entry_contexts[ENDING_SECOND].playback_id = ENDING_CHAIN + ":0"
			"missing_family": changed.erase("family")
			"wrong_family": changed.family = "hospital"
			"malformed_family": changed.family = ["ending"]
			"version1": changed.schema_version = 1
			"version2": changed.schema_version = 2
			"float_version": changed.schema_version = 3.0
			"wrong_frontier": changed.frontier.publication_id = changed.ledger.captions[0].publication_id
			"wrong_first": changed.ledger.frozen_context.entry_id = ENDING_SECOND
		assert_false(target.restore(changed, ENDING_SECOND).ok, mutation)
		assert_eq(target.capture(source.frontier).value, saved, mutation)

func test_ending_frame_rebinding_and_next_cannot_mutate_the_retained_session() -> void:
	var source := _ending_at_second_step()
	var session: RefCounted = source.session
	var before: Dictionary = session.capture(source.frontier).value
	assert_true(session.admit(ENDING_SECOND, _ending_context(1)).ok, "identical frame admission is idempotent")
	for mutation: String in ["stage", "role", "playback", "transaction", "step_token", "facts", "extra"]:
		var frame := _ending_context(1)
		match mutation:
			"stage": frame.expected_stage = "pre_challenge"
			"role": frame.role = "core"
			"playback": frame.playback_id = ENDING_CHAIN + ":0"
			"transaction": frame.transaction_id = ENDING_CHAIN + ":0:complete"
			"step_token": frame.presentation.fields.step_token = "foreign:ending:1"
			"facts": frame.presentation.fields.pair_count_receipt_ids = ["foreign:pair-receipt"]
			"extra": frame["unexpected"] = true
		assert_false(session.admit(ENDING_SECOND, frame).ok, mutation)
		assert_eq(session.capture(source.frontier).value, before, mutation)
	var queries: Array = []
	assert_eq(session.prepare_next(source.frontier, func(beat: Dictionary) -> bool:
		queries.append(beat)
		return true).get("code"), &"reading_next_unavailable")
	assert_eq(queries, [], "ending Next cannot consult or spend profile knowledge")
	assert_eq(session.capture(source.frontier).value, before)

func test_ending_catalogue_order_is_bound_to_the_saved_history() -> void:
	var source := _ending_at_second_step()
	var saved: Dictionary = source.session.capture(source.frontier).value
	var reordered := _ending_catalogue()
	reordered.entries.reverse()
	var target := SESSION.new()
	assert_true(target.configure(reordered).ok)
	assert_false(target.restore(saved, ENDING_SECOND).ok, "a reordered programme requires its own fingerprint")
	for mutation: String in ["empty", "foreign_entry", "duplicate_entry", "empty_lines", "duplicate_line"]:
		var document := _ending_catalogue()
		match mutation:
			"empty": document.entries = []
			"foreign_entry": document.entries[0].entry_id = PRE
			"duplicate_entry": document.entries[1].entry_id = ENDING_FIRST
			"empty_lines": document.entries[0].lines = []
			"duplicate_line": document.entries[1].lines[0].line_id = document.entries[0].lines[0].line_id
		assert_false(SESSION.new().configure(document).ok, mutation)
