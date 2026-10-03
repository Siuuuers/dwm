extends "res://addons/gut/test.gd"

const RUN := preload("res://scripts/narrative/FrozenRunContext.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const PARTICIPANT := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const NEXT := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
const NEXT_FIXTURE := preload("res://tests/support/ReadingNextFixture.gd")
const HOSPITAL := preload("res://scripts/narrative/HospitalFrozenContext.gd")
const CONTACT_FROZEN := preload("res://scripts/narrative/ContactsFrozenContext.gd")
const HOSPITAL_FIXTURE := preload("res://tests/support/HospitalReadingFixture.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const NARRATIVE_OWNER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")
const CANON := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const GAME := preload("res://autoload/GameState.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ISSUER_ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
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

func test_next_source_and_destination_validate_and_restore_their_exact_own_frontiers() -> void:
	var snapshot := NEXT_FIXTURE.snapshot()
	var base: Dictionary = snapshot.narrative_checkpoint.duplicate(true)
	var plan := NEXT_FIXTURE.plan(base)
	for phase: String in ["source", "destination"]:
		var owner := ReadingOwner.new()
		var participant := PARTICIPANT.new(owner)
		snapshot.narrative_checkpoint = NEXT_FIXTURE.checkpoint_for(base, plan, phase)
		var before := snapshot.duplicate(true)
		var prepared := _prepare(participant, snapshot)
		assert_true(prepared.ok, str(prepared))
		assert_eq(snapshot, before, "validation is pure")
		if not prepared.ok: continue
		assert_true(_apply(participant, prepared).ok)
		assert_true(participant.finalize().ok)
		assert_eq(owner.resumed, [snapshot.narrative_checkpoint])
		assert_eq(owner.resumed[0].reading_session.ledger.captions.size(), 1 if phase == "source" else 3)

func test_next_checkpoint_rejects_changed_operation_and_sequence_without_staging() -> void:
	var initial := NEXT_FIXTURE.snapshot()
	var base: Dictionary = initial.narrative_checkpoint
	var plan := NEXT_FIXTURE.plan(base)
	for change: String in ["id", "source", "phase", "sequence", "missing", "downgrade"]:
		var snapshot := initial.duplicate(true)
		snapshot.narrative_checkpoint = NEXT_FIXTURE.checkpoint_for(base, plan, "destination")
		var reading: Dictionary = snapshot.narrative_checkpoint.reading_session
		match change:
			"id": reading.next_operation.operation_id = "stale"
			"source": reading.next_operation.plan.source_frontier.publication_id = "foreign"
			"phase": reading.next_operation.phase = "source"
			"sequence": reading.ledger.captions.remove_at(1)
			"missing": reading.erase("next_operation")
			"downgrade": reading.schema_version = 1
		var owner := ReadingOwner.new()
		assert_eq(_prepare(PARTICIPANT.new(owner), snapshot).get("code"), &"invalid_narrative_checkpoint", change)
		assert_true(owner.validations.is_empty(), change)
		assert_true(owner.staged.is_empty(), change)

func test_next_plan_refuses_duplicate_source_and_foreign_entry_suffix() -> void:
	var plan := NEXT_FIXTURE.plan(NEXT_FIXTURE.snapshot().narrative_checkpoint)
	var duplicate := plan.duplicate(true)
	duplicate.traversed_captions[0] = duplicate.source_ledger.captions[0].duplicate(true)
	assert_eq(NEXT.create(duplicate, "source").get("code"), &"reading_next_sequence_invalid")
	var foreign := plan.duplicate(true)
	foreign.traversed_captions[0].beat.owning_entry_id = POST
	assert_eq(NEXT.create(foreign, "source").get("code"), &"reading_next_sequence_invalid")
	var changed := plan.duplicate(true)
	changed.traversed_captions[0].beat.presentation_signature.content_revision = "fixture-v2"
	assert_ne(NEXT.create(plan, "source").value.operation_id, NEXT.create(changed, "source").value.operation_id)

func test_next_completion_record_survives_exact_physical_board_boundary() -> void:
	var snapshot := NEXT_FIXTURE.snapshot()
	var base: Dictionary = snapshot.narrative_checkpoint
	var plan := NEXT_FIXTURE.plan(base, true)
	snapshot.narrative_checkpoint = NEXT_FIXTURE.checkpoint_for(base, plan, "destination")
	snapshot.gameplay.route_context.active_dating_challenge.phase = "challenge"
	var admitted := RUN.validate_reading_checkpoint(snapshot.narrative_checkpoint, snapshot)
	assert_true(admitted.ok, str(admitted))
	assert_eq(snapshot.narrative_checkpoint.reading_session.boundary, "between_entries")
	assert_eq(snapshot.narrative_checkpoint.reading_session.ledger.captions.size(), 2)
	assert_true(snapshot.narrative_checkpoint.reading_session.frontier.is_empty())
	snapshot.narrative_checkpoint.reading_session.frontier = plan.source_frontier.duplicate(true)
	assert_eq(RUN.validate_reading_checkpoint(snapshot.narrative_checkpoint, snapshot).get("code"), &"reading_next_projection_mismatch")

## Isolated saved-authority fixture, shared with Pause capture tests. Contacts
## eligibility uses the real accepted-source owner; the small plan is deliberately
## not a complete Run or a substitute for the connected Schedule-Done journey.
func _hospital_snapshot(completed: bool = false) -> Dictionary:
	var game: Node = autofree(GAME.new())
	game.reset_game()
	var issuer := ISSUER.new()
	assert_true(issuer.configure(ISSUER_ROOT.new("91".repeat(32), 1)).ok)
	var action := "solo:sylvia:day1"
	var offered := CONTACTS.prepare_offer_solo(game.contacts, "sylvia", 1, action, "fixture:hospital:offer")
	assert_true(offered.ok, str(offered))
	if not offered.ok: return {}
	var issued: Dictionary = issuer.issue(&"transaction_id").value
	var accepted := CONTACTS._prepare_invitation_open(offered.value.candidate, "sylvia", 1,
		issued.token, issued.issuer_receipt, issuer, game._schedule_action_record(action))
	assert_true(accepted.ok, str(accepted))
	if not accepted.ok: return {}
	var contacts: Dictionary = accepted.value.candidate
	var scheduled := {"slot_index": 0, "action_kind": "solo", "participants": ["sylvia"],
		"schedule_entry_id": "fixture:hospital:schedule", "action_id": action, "source_receipt_id": accepted.receipt.receipt_id}
	var context := HOSPITAL.from_schedule({"kind": "hospital", "day": 1,
		"source_entry_ids": [scheduled.schedule_entry_id], "miss_receipt_ids": ["fixture:hospital:miss"]}, contacts, [scheduled])
	assert_true(context.ok, str(context))
	if not context.ok: return {}
	var root: Dictionary = issuer.issue(&"transaction_id").value
	var request := {"resolution_id": "fixture:hospital:resolution", "resolution_issuer_receipt": root.issuer_receipt,
		"stage_id": "fixture:hospital:stage", "substage_id": "fixture:hospital:intent", "route_id": "hospital",
		"timeline_id": "hospital.faint", "completion_transaction_id": "fixture:hospital:completion",
		"completion_transaction_provenance": {}, "context": context.value}
	var command_hash: String = CANON.canonical_sha256(request).value.sha256
	var token := NARRATIVE_OWNER.derive_token(request.completion_transaction_id, command_hash)
	var entry: String = context.value.presentation.fields.entry_id
	var frame := {"expected_stage": "hospital", "playback_id": token + ":hospital", "role": "hospital",
		"transaction_id": request.completion_transaction_id + ":hospital", "presentation": context.value.presentation}
	var session := SESSION.new()
	assert_true(session.configure(HOSPITAL_FIXTURE.catalogue(1)).ok)
	assert_true(session.begin(request.completion_transaction_id, entry).ok)
	assert_true(session.admit(entry, frame).ok)
	var frontier := {}
	for index: int in session.registry.beats.size():
		var beat: Dictionary = session.registry.beats[index]
		frontier = {"line_id": beat.line_id, "publication_id": "fixture:hospital:caption:%d" % index}
		assert_true(session.ledger.publish_caption(request.completion_transaction_id, frontier.publication_id, beat).ok)
	if completed:
		session.completed(entry)
		frontier = {}
	var captured := session.capture(frontier)
	assert_true(captured.ok, str(captured))
	if not captured.ok: return {}
	var stage := {"stage_id": "hospital_if_triggered", "transaction_id": request.stage_id,
		"state": "completed" if completed else "active", "receipt": null}
	if completed:
		var physical := {"owner_kind": "narrative", "physical_token": token, "command_sha256": command_hash,
			"completion_transaction_id": request.completion_transaction_id, "status": "completed", "result": {}}
		var receipt := {"receipt_id": request.completion_transaction_id, "receipt_provenance": request.completion_transaction_provenance,
			"resolution_id": request.resolution_id, "stage_id": request.stage_id, "substage_id": request.substage_id,
			"route_id": request.route_id, "timeline_id": request.timeline_id, "command_sha256": command_hash,
			"physical_owner_kind": "narrative", "physical_token": token, "physical_completion_receipt": physical}
		stage.receipt = {"value": {"required": true, "date_schedule_entry_ids": [scheduled.schedule_entry_id],
			"superseded_entry_ids": [scheduled.schedule_entry_id], "witness_entry_id": scheduled.schedule_entry_id,
			"presentation_completion_receipt": receipt}}
	var gameplay := CONTACT_FROZEN.capture_candidate(game.contacts, contacts,
		{"route_context": {RUN.HOSPITAL_KEY: {"schema_version": 1, "requests": {request.resolution_id: request}}},
		"pending_hospital": not completed, "missed_invitations": []}, 1)
	assert_true(gameplay.ok, str(gameplay))
	if not gameplay.ok: return {}
	return {"route_id": "hospital", "lifecycle": {"run_id": "fixture:run", "branch_id": "fixture:restored-branch",
		"day": 1, "state": "PLAYING", "active_condition_hospital_plan": null, "condition_hospital_history": {},
		"ending_plan": null, "active_resolution_plan": {"resolution_id": request.resolution_id,
			"resolution_issuer_receipt": request.resolution_issuer_receipt, "source_day": 1,
			"stages": [stage], "committed_schedule": {"entries": [scheduled]}}},
		"gameplay": gameplay.value, "contacts": contacts,
		"narrative_checkpoint": {"content_version": 1, "entry_id": entry, "frozen_context": frame,
			"manifest_fingerprint": PARTICIPANT._entry_document_fingerprint(), "stage": "hospital",
			"transaction_id": frame.transaction_id, "reading_session": captured.value}}

func test_hospital_v3_prepares_exact_saved_frames_without_starting_or_changing_sources() -> void:
	var snapshot := _hospital_snapshot()
	var before := snapshot.duplicate(true)
	var owner := ReadingOwner.new()
	var participant := PARTICIPANT.new(owner)
	var prepared := _prepare(participant, snapshot)
	assert_true(prepared.ok, str(prepared))
	assert_eq(owner.validations, [snapshot.narrative_checkpoint.reading_session.ledger.entry_contexts])
	assert_true(owner.staged.is_empty())
	assert_true(owner.resumed.is_empty())
	assert_eq(snapshot, before)
	assert_true(RUN.validate(snapshot).ok)

func test_hospital_single_frame_forgery_cannot_rewrite_current_and_history_authority_together() -> void:
	var source := _hospital_snapshot()
	for field: String in ["presentation", "playback_id", "transaction_id", "role", "expected_stage"]:
		var changed := source.duplicate(true)
		var checkpoint: Dictionary = changed.narrative_checkpoint
		var frame: Dictionary = checkpoint.frozen_context.duplicate(true)
		if field == "presentation":
			frame.presentation.fields.sylvia_witness_receipt_id = "invented:future-witness"
		else:
			frame[field] = "invented:" + field
		checkpoint.frozen_context = frame
		checkpoint.reading_session.ledger.entry_contexts[checkpoint.entry_id] = frame.duplicate(true)
		var owner := ReadingOwner.new()
		var result := _prepare(PARTICIPANT.new(owner), changed)
		assert_false(result.ok, field)
		assert_eq(result.code, &"invalid_narrative_checkpoint", field)
		assert_true(owner.validations.is_empty(), "independent facts refuse before the catalogue trusts a coherent forgery")
		assert_true(owner.staged.is_empty())
		assert_eq(RUN.validate_reading_checkpoint(checkpoint, changed).get("code"), &"reading_entry_context_mismatch", field)
	assert_true(RUN.validate_reading_checkpoint(source.narrative_checkpoint, source).ok)

func test_hospital_membership_checks_earlier_and_current_captions_and_exact_tail() -> void:
	var source := _hospital_snapshot()
	for mutation: String in ["earlier_owner", "current_owner", "duplicate_publication", "extra_frame", "empty_captions", "non_tail_frontier"]:
		var changed := source.duplicate(true)
		var saved: Dictionary = changed.narrative_checkpoint.reading_session
		match mutation:
			"earlier_owner": saved.ledger.captions[0].beat.owning_entry_id = PRE
			"current_owner": saved.ledger.captions[1].beat.owning_entry_id = PRE
			"duplicate_publication": saved.ledger.captions[1].publication_id = saved.ledger.captions[0].publication_id
			"extra_frame": saved.ledger.entry_contexts[PRE] = changed.narrative_checkpoint.frozen_context.duplicate(true)
			"empty_captions": saved.ledger.captions.clear()
			"non_tail_frontier": saved.frontier = {"line_id": saved.ledger.captions[0].beat.line_id,
				"publication_id": saved.ledger.captions[0].publication_id}
		assert_false(RUN.validate_reading_checkpoint(changed.narrative_checkpoint, changed).ok, mutation)

func test_hospital_versions_family_and_operation_are_closed_without_solo_downgrade() -> void:
	var source := _hospital_snapshot()
	for mutation: String in ["version1", "version2", "float_version", "missing_family", "wrong_family", "next_operation", "wrong_route", "old_session"]:
		var changed := source.duplicate(true)
		var saved: Dictionary = changed.narrative_checkpoint.reading_session
		match mutation:
			"version1": saved.schema_version = 1
			"version2": saved.schema_version = 2
			"float_version": saved.schema_version = 3.0
			"missing_family": saved.erase("family")
			"wrong_family": saved.family = "solo"
			"next_operation": saved["next_operation"] = {}
			"wrong_route": changed.route_id = "dating"
			"old_session": saved.ledger.frozen_context = {"completion_transaction_id": saved.ledger.session_token, "pre_entry_id": PRE}
		assert_false(_prepare(PARTICIPANT.new(ReadingOwner.new()), changed).ok, mutation)

func test_hospital_line_requires_active_retained_schedule_and_real_sylvia_sources() -> void:
	var source := _hospital_snapshot()
	for mutation: String in ["plan_missing", "pending_stage", "completed_stage", "not_pending", "wrong_stage", "wrong_root", "wrong_day", "missing_source", "wrong_schedule", "condition_plan", "duplicate_stage", "malformed_stage", "malformed_entries"]:
		var changed := source.duplicate(true)
		var plan: Dictionary = changed.lifecycle.active_resolution_plan
		match mutation:
			"plan_missing": changed.lifecycle.active_resolution_plan = null
			"pending_stage": plan.stages[0].state = "pending"
			"completed_stage": plan.stages[0].state = "completed"
			"not_pending": changed.gameplay.pending_hospital = false
			"wrong_stage": plan.stages[0].transaction_id = "foreign:stage"
			"wrong_root": plan.resolution_issuer_receipt = {"receipt_id": "foreign:root"}
			"wrong_day": changed.lifecycle.day = 2
			"missing_source": changed.contacts.schedule_source_receipts.clear()
			"wrong_schedule": plan.committed_schedule.entries[0].action_id = "foreign:action"
			"condition_plan": changed.lifecycle.active_condition_hospital_plan = {}
			"duplicate_stage": plan.stages.append(plan.stages[0].duplicate(true))
			"malformed_stage": plan.stages[0] = false
			"malformed_entries": plan.committed_schedule.entries[0] = false
		assert_false(RUN.validate_reading_checkpoint(changed.narrative_checkpoint, changed).ok, mutation)

func test_hospital_saved_authority_refuses_other_cause_but_admits_coherent_ordinary_recovery() -> void:
	var source := _hospital_snapshot()
	for mutation: String in ["condition", "ordinary"]:
		var changed := source.duplicate(true)
		var plan: Dictionary = changed.lifecycle.active_resolution_plan
		var request: Dictionary = changed.gameplay.route_context[RUN.HOSPITAL_KEY].requests[plan.resolution_id]
		if mutation == "condition":
			request.context.presentation.fields.qualifying_cause = "condition_hospital"
		else:
			plan.committed_schedule.entries = []
			request.context.source_entry_ids = []
			request.context.miss_receipt_ids = []
			request.context.presentation.fields.accepted_record_ids = []
			request.context.presentation.fields.unfulfilled_record_ids = []
			request.context.presentation.fields.sylvia_eligible = false
		var checkpoint: Dictionary = changed.narrative_checkpoint
		checkpoint.frozen_context.presentation = request.context.presentation.duplicate(true)
		checkpoint.frozen_context.playback_id = NARRATIVE_OWNER.derive_token(request.completion_transaction_id,
			CANON.canonical_sha256(request).value.sha256) + ":hospital"
		checkpoint.reading_session.ledger.entry_contexts[checkpoint.entry_id] = checkpoint.frozen_context.duplicate(true)
		var before := changed.duplicate(true)
		var validated := RUN.validate_reading_checkpoint(checkpoint, changed)
		if mutation == "condition":
			assert_false(validated.ok, "condition-Hospital still has a distinct recovery authority")
		else:
			assert_true(validated.ok, "ordinary recovery follows the shared Hospital narrative owner: " + str(validated))
			assert_true(_prepare(PARTICIPANT.new(ReadingOwner.new()), changed).ok)
		assert_eq(changed, before, "admission neither invents Sylvia nor mutates the saved frame")

func test_hospital_internal_completed_anchor_survives_lawful_following_day_capture() -> void:
	var snapshot := _hospital_snapshot(true)
	var before := snapshot.duplicate(true)
	assert_true(RUN.validate_reading_checkpoint(snapshot.narrative_checkpoint, snapshot).ok)
	assert_true(_prepare(PARTICIPANT.new(ReadingOwner.new()), snapshot).ok)
	assert_eq(snapshot, before)
	snapshot.lifecycle.active_resolution_plan.stages.append({"stage_id": "increment_day", "state": "completed"})
	snapshot.lifecycle.day = 2
	assert_true(RUN.validate_reading_checkpoint(snapshot.narrative_checkpoint, snapshot).ok,
		"the original retained request owns the final anchor during later produced checkpoints")
	snapshot.lifecycle.active_resolution_plan.stages[-1].state = "active"
	assert_false(RUN.validate_reading_checkpoint(snapshot.narrative_checkpoint, snapshot).ok)
	snapshot.lifecycle.active_resolution_plan.stages[-1].state = "completed"
	snapshot.lifecycle.day = 3
	assert_false(RUN.validate_reading_checkpoint(snapshot.narrative_checkpoint, snapshot).ok)

func test_hospital_completed_anchor_requires_exact_committed_physical_receipt() -> void:
	var source := _hospital_snapshot(true)
	for mutation: String in ["active", "pending", "frontier", "required", "missing_receipt", "completion_id", "provenance", "stage", "hash", "token", "owner", "physical_id", "physical_status", "physical_hash", "extra_physical"]:
		var changed := source.duplicate(true)
		var stage: Dictionary = changed.lifecycle.active_resolution_plan.stages[0]
		var completion: Dictionary = stage.receipt.value.presentation_completion_receipt
		match mutation:
			"active": stage.state = "active"
			"pending": changed.gameplay.pending_hospital = true
			"frontier": changed.narrative_checkpoint.reading_session.frontier = {"line_id": "fixture.hospital.b", "publication_id": "fixture:hospital:caption:1"}
			"required": stage.receipt.value.required = false
			"missing_receipt": stage.receipt.value.presentation_completion_receipt = null
			"completion_id": completion.receipt_id = "foreign:completion"
			"provenance": completion.receipt_provenance = {"child_id": "foreign:child"}
			"stage": completion.stage_id = "foreign:stage"
			"hash": completion.command_sha256 = "0".repeat(64)
			"token": completion.physical_token = "foreign:token"
			"owner": completion.physical_owner_kind = "dating_challenge"
			"physical_id": completion.physical_completion_receipt.completion_transaction_id = "foreign:completion"
			"physical_status": completion.physical_completion_receipt.status = "pending"
			"physical_hash": completion.physical_completion_receipt.command_sha256 = "0".repeat(64)
			"extra_physical": completion.physical_completion_receipt["extra"] = true
		assert_false(RUN.validate_reading_checkpoint(changed.narrative_checkpoint, changed).ok, mutation)
