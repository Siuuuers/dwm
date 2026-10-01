extends "res://addons/gut/test.gd"

const RUN := preload("res://scripts/narrative/FrozenRunContext.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const PARTICIPANT := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const PRE := "dating.solo.priscilla.day2.pre_challenge"
const POST := "dating.solo.priscilla.day2.post_challenge"

class ReadingOwner extends RefCounted:
	var staged: Dictionary = {}
	var resumed: Array[Dictionary] = []
	var validations: Array[Dictionary] = []
	var refusal := &""
	var active := false
	func validate_resume_checkpoint(_checkpoint: Dictionary) -> Dictionary:
		return {"ok": true}
	func validate_reading_checkpoint(checkpoint: Dictionary, independent: Dictionary = {}) -> Dictionary:
		validations.append(independent.duplicate(true))
		if refusal != &"": return {"ok": false, "code": refusal}
		return {"ok": independent == checkpoint.reading_session.ledger.entry_contexts}
	func stage_reading_restore(checkpoint: Dictionary) -> Dictionary:
		staged = checkpoint.duplicate(true)
		return {"ok": true}
	func has_active_playback() -> bool:
		return active
	func resume_entry(checkpoint: Dictionary) -> Dictionary:
		resumed.append(checkpoint.duplicate(true))
		staged = {}
		return {"ok": true}
	func finalize_restore() -> Dictionary:
		return {"ok": true}
	func capture_restore_state() -> Dictionary:
		return {"staged": staged.duplicate(true)}
	func rollback_restore_silent(backup: Dictionary) -> Dictionary:
		staged = backup.staged.duplicate(true)
		return {"ok": true}

func _presentation(phase: String) -> Dictionary:
	var entry := PRE if phase == "pre_challenge" else POST
	var fields := {"entry_id": entry, "entry_role": "solo_" + phase,
		"day": 2, "friend_id": "priscilla", "tier": "friend", "tone": "sweet", "attitude": "",
		"run_id": "fixture:run", "branch_id": "fixture:original-branch", "challenge_slot": "dating.solo.priscilla.day2",
		"phase": phase, "due_echoes": [], "attempt_residue_id": null}
	if phase == "post_challenge":
		fields.merge({"attempt_id": "fixture:board", "board_result": "cleared", "perfect_reasons": [],
			"relationship_outcome": "loved", "effect_receipt_id": "fixture:effect"})
		if FROZEN.schema_for_entry(entry).value.fields.has("progression_window_result"):
			fields["progression_window_result"] = {"evaluated": true, "promotion_applied": false, "relationship_state": "friend"}
	return FROZEN.build(entry, fields).value

func _snapshot(post: bool = true) -> Dictionary:
	var phase := "post_challenge" if post else "pre_challenge"
	var presentations := {PRE: _presentation("pre_challenge")}
	if post: presentations[POST] = _presentation("post_challenge")
	var record := {"context": {"kind": "solo", "day": 2, "participants": ["priscilla"]},
		"spec": {"board_token": "fixture:board"}, "host": "canonical_solo", "phase": phase,
		"completion_transaction_id": "fixture:completion", "physical_token": "fixture:physical",
		"outcome": "cleared" if post else null, "perfect_reasons": [], "relationship_outcome": "loved" if post else null,
		"applied_result": {"receipt": {"terminal_fact": {"transaction_id": "fixture:effect"},
			"progression_evaluated": true, "promotion_applied": false, "relationship_state": "friend"}} if post else {}}
	var frames := {}
	var captions: Array[Dictionary] = []
	for entry: String in presentations:
		var entry_phase := "pre_challenge" if entry == PRE else "post_challenge"
		frames[entry] = {"expected_stage": entry_phase, "playback_id": "fixture:physical:" + entry_phase,
			"role": "dating_phase", "transaction_id": "fixture:completion:" + entry_phase,
			"presentation": presentations[entry].duplicate(true)}
		captions.append({"publication_id": "caption:%d" % (captions.size() + 1),
			"beat": {"owning_entry_id": entry, "line_id": "fixture:" + entry_phase,
				"beat_id": "fixture:beat:" + entry_phase, "presentation_signature": {"revision": "fixture-v1"}}})
	var entry := POST if post else PRE
	var checkpoint := {"content_version": 1, "entry_id": entry, "frozen_context": frames[entry].duplicate(true),
		"manifest_fingerprint": PARTICIPANT._entry_document_fingerprint(), "stage": phase,
		"transaction_id": "fixture:completion:" + phase,
		"reading_session": {"schema_version": 1, "catalogue_fingerprint": "fixture:catalogue", "boundary": "line",
			"ledger": {"session_token": "fixture:completion", "frozen_context": {"completion_transaction_id": "fixture:completion", "pre_entry_id": PRE},
				"entry_contexts": frames, "captions": captions},
			"frontier": {"line_id": captions[-1].beat.line_id, "publication_id": captions[-1].publication_id}}}
	return {"route_id": "dating", "lifecycle": {"run_id": "fixture:run", "branch_id": "fixture:restored-branch", "day": 2,
		"state": "PLAYING", "active_resolution_plan": null, "active_condition_hospital_plan": null,
		"condition_hospital_history": {}, "ending_plan": null},
		"gameplay": {"route_context": {"active_dating_challenge": record,
			RUN.DATING_KEY: {"schema_version": 1, "board_token": "fixture:board", "entries": presentations}},
			"pending_hospital": false, "missed_invitations": []},
		"contacts": CONTACTS.make_defaults(), "narrative_checkpoint": checkpoint}

func _prepare(participant: Object, snapshot: Dictionary) -> Dictionary:
	return participant.prepare({"content_version": 1, "narrative_checkpoint": snapshot.narrative_checkpoint, "snapshot": snapshot})

func _apply(participant: Object, prepared: Dictionary) -> Dictionary:
	var plan: Dictionary = prepared.value.narrative_plan.duplicate(true)
	plan["route_ready_token"] = {"route_id": "dating"}
	return participant.apply_silent(plan)

func test_all_history_frames_bind_independently_to_saved_canonical_facts() -> void:
	var snapshot := _snapshot()
	var before := snapshot.duplicate(true)
	assert_true(RUN.validate(snapshot, true).ok)
	assert_eq(snapshot, before)
	# The current post line is still valid. Only the earlier pre History frame is
	# forged, so checking the top-level frozen_context cannot detect this change.
	snapshot.narrative_checkpoint.reading_session.ledger.entry_contexts[PRE].presentation.fields.attitude = "fixated"
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_entry_context_mismatch")
	var owner := ReadingOwner.new()
	var participant := PARTICIPANT.new(owner)
	assert_eq(_prepare(participant, snapshot).get("code"), &"invalid_narrative_checkpoint")
	assert_eq(owner.validations.size(), 0, "untrusted frame bytes never reach catalogue admission")
	assert_true(owner.staged.is_empty())
	assert_true(owner.resumed.is_empty())

func test_session_and_each_phase_identity_belong_to_the_saved_physical_command() -> void:
	for field: String in ["completion_transaction_id", "pre_entry_id"]:
		var snapshot := _snapshot()
		snapshot.narrative_checkpoint.reading_session.ledger.frozen_context[field] = "foreign:owner"
		assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_physical_owner_mismatch")
	for field: String in ["playback_id", "transaction_id", "expected_stage", "role"]:
		var snapshot := _snapshot()
		snapshot.narrative_checkpoint.reading_session.ledger.entry_contexts[PRE][field] = "foreign:phase"
		assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_entry_context_mismatch")
	var foreign_route := _snapshot()
	foreign_route.route_id = "main"
	assert_eq(RUN.validate(foreign_route, true).get("code"), &"reading_saved_run_required",
		"retained Dating facts cannot qualify a reading session on a different saved route")
	var foreign_session := _snapshot()
	foreign_session.narrative_checkpoint.reading_session.ledger.session_token = "foreign:session"
	assert_eq(RUN.validate(foreign_session, true).get("code"), &"reading_physical_owner_mismatch")

func test_board_boundary_retains_only_reached_frames_without_starting_future_prose() -> void:
	var snapshot := _snapshot(false)
	var checkpoint: Dictionary = snapshot.narrative_checkpoint
	var line_frontier: Dictionary = checkpoint.reading_session.frontier.duplicate(true)
	checkpoint.reading_session.boundary = "between_entries"
	checkpoint.reading_session.frontier = {}
	snapshot.gameplay.route_context.active_dating_challenge.phase = "challenge"
	assert_true(RUN.validate(snapshot, true).ok)
	# A committed board can freeze post facts before its first caption. Restoring
	# this exact boundary must retain pre History without fabricating post rows.
	var later := _snapshot()
	snapshot.gameplay.route_context = later.gameplay.route_context.duplicate(true)
	assert_true(RUN.validate(snapshot, true).ok)
	assert_false(checkpoint.reading_session.ledger.entry_contexts.has(POST))
	snapshot.gameplay.route_context.active_dating_challenge.phase = "completed"
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_physical_boundary_mismatch",
		"a fully completed date cannot retain only its pre-challenge History")
	snapshot.gameplay.route_context.active_dating_challenge.phase = "post_challenge"
	checkpoint.reading_session.boundary = "line"
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_session_invalid",
		"line boundary requires its semantic frontier before physical binding is checked")
	checkpoint.reading_session.frontier = line_frontier
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_physical_boundary_mismatch")

func test_causal_entry_order_and_unknown_history_owners_refuse() -> void:
	var snapshot := _snapshot()
	snapshot.narrative_checkpoint.reading_session.ledger.captions.reverse()
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_caption_sequence_invalid")
	snapshot = _snapshot()
	snapshot.narrative_checkpoint.reading_session.ledger.captions[-1].beat.owning_entry_id = "foreign:entry"
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_caption_sequence_invalid")

func test_reading_discriminator_cannot_downgrade_to_legacy_empty_playhead() -> void:
	var owner := ReadingOwner.new()
	var participant := PARTICIPANT.new(owner)
	var snapshot := _snapshot()
	snapshot.narrative_checkpoint.erase("entry_id")
	assert_eq(_prepare(participant, snapshot).get("code"), &"invalid_narrative_checkpoint")
	assert_true(owner.validations.is_empty())
	snapshot = _snapshot()
	assert_eq(participant._prepare_semantic(snapshot.narrative_checkpoint).get("code"), &"invalid_narrative_checkpoint",
		"the older exact six-field reader must not silently discard the new sequence")
	assert_eq(participant.prepare({"content_version": 1, "narrative_checkpoint": snapshot.narrative_checkpoint}).get("code"), &"invalid_narrative_input")

func test_invalid_version_or_containers_stay_fail_closed_even_with_stale_content() -> void:
	var owner := ReadingOwner.new()
	var participant := PARTICIPANT.new(owner)
	for invalid: Variant in [null, true, "1", 0, 2]:
		var snapshot := _snapshot()
		snapshot.narrative_checkpoint.reading_session.schema_version = invalid
		snapshot.narrative_checkpoint.manifest_fingerprint = "stale:manifest"
		assert_eq(_prepare(participant, snapshot).get("code"), &"invalid_narrative_checkpoint")
	for field: String in ["ledger", "frontier"]:
		var snapshot := _snapshot()
		snapshot.narrative_checkpoint.reading_session[field] = []
		assert_eq(_prepare(participant, snapshot).get("code"), &"invalid_narrative_checkpoint")
	assert_true(owner.validations.is_empty())
	assert_true(owner.staged.is_empty())

func test_capture_boundary_refuses_stripped_or_expanded_semantic_envelopes() -> void:
	var snapshot := _snapshot()
	for key: String in snapshot.narrative_checkpoint:
		var stripped: Dictionary = snapshot.narrative_checkpoint.duplicate(true)
		stripped.erase(key)
		assert_eq(RUN.validate_reading_checkpoint(stripped, snapshot).get("code"), &"reading_session_invalid", key)
	for key: String in ["path", "event_index", "future_field"]:
		var expanded: Dictionary = snapshot.narrative_checkpoint.duplicate(true)
		expanded[key] = "untrusted"
		assert_eq(RUN.validate_reading_checkpoint(expanded, snapshot).get("code"), &"reading_session_invalid", key)
	for invalid: Variant in [0, -1, true, "1", 1.0, null]:
		var malformed: Dictionary = snapshot.narrative_checkpoint.duplicate(true)
		malformed.content_version = invalid
		assert_eq(RUN.validate_reading_checkpoint(malformed, snapshot).get("code"), &"reading_session_invalid")
	for key: String in ["entry_id", "manifest_fingerprint", "stage", "transaction_id"]:
		var malformed: Dictionary = snapshot.narrative_checkpoint.duplicate(true)
		malformed[key] = []
		assert_eq(RUN.validate_reading_checkpoint(malformed, snapshot).get("code"), &"reading_session_invalid", key)

func test_prepare_checks_complete_catalogue_before_staging_and_finalization_is_one_shot() -> void:
	var owner := ReadingOwner.new()
	var participant := PARTICIPANT.new(owner)
	var snapshot := _snapshot()
	var prepared := _prepare(participant, snapshot)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_eq(owner.validations, [snapshot.narrative_checkpoint.reading_session.ledger.entry_contexts])
	assert_true(owner.staged.is_empty())
	assert_true(owner.resumed.is_empty())
	assert_true(_apply(participant, prepared).ok)
	assert_eq(owner.staged, snapshot.narrative_checkpoint)
	assert_true(owner.resumed.is_empty(), "apply cannot project or begin native playback")
	assert_true(participant.finalize().ok)
	assert_true(participant.finalize().ok)
	assert_eq(owner.resumed, [snapshot.narrative_checkpoint], "finalize consumes the full frontier once")

func test_catalogue_refusal_and_rollback_cannot_leave_a_future_resume() -> void:
	var owner := ReadingOwner.new()
	var participant := PARTICIPANT.new(owner)
	var snapshot := _snapshot()
	owner.refusal = &"caption_registration_mismatch"
	assert_eq(_prepare(participant, snapshot).get("code"), &"invalid_narrative_checkpoint")
	assert_true(owner.staged.is_empty())
	for code: StringName in [&"reading_catalogue_mismatch", &"reading_line_unavailable", &"reading_line_content_mismatch",
			&"reading_line_ambiguous", &"reading_entry_mismatch", &"entry_master_missing"]:
		owner.refusal = code
		assert_eq(_prepare(participant, snapshot).get("code"), &"NARRATIVE_CONTENT_UNAVAILABLE", str(code))
	owner.refusal = &""
	var prepared := _prepare(participant, snapshot)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var backup: Dictionary = participant.capture()
	assert_true(_apply(participant, prepared).ok)
	assert_true(participant.rollback_silent(backup).ok)
	assert_true(owner.staged.is_empty())
	assert_true(participant.finalize().ok)
	assert_true(owner.resumed.is_empty(), "rolled-back session cannot appear at later finalize")

func test_active_playback_refusal_does_not_install_a_staged_helper() -> void:
	var owner := ReadingOwner.new()
	var participant := PARTICIPANT.new(owner)
	var prepared := _prepare(participant, _snapshot())
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	owner.active = true
	assert_eq(_apply(participant, prepared).get("code"), &"narrative_playback_active")
	assert_true(owner.staged.is_empty())
	assert_true(owner.resumed.is_empty())
