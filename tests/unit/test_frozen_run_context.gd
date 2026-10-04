extends "res://addons/gut/test.gd"

const RUN := preload("res://scripts/narrative/FrozenRunContext.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const ENDING := preload("res://scripts/narrative/EndingFrozenContext.gd")
const CONTACTS := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const DECK := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const READING_FIXTURE := preload("res://tests/unit/test_reading_restore_admission.gd")

func _snapshot() -> Dictionary:
	return {"lifecycle": {"run_id": "fixture:run", "branch_id": "restored:branch", "day": 2,
		"state": "PLAYING", "active_resolution_plan": null, "active_condition_hospital_plan": null,
		"condition_hospital_history": {}, "ending_plan": null},
		"gameplay": {"route_context": {}, "pending_hospital": false, "missed_invitations": []},
		"contacts": CONTACTS.make_defaults()}

func _solo_fields(phase: String) -> Dictionary:
	var fields := {"entry_id": "dating.solo.priscilla.day2." + phase,
		"entry_role": "solo_" + phase, "day": 2, "friend_id": "priscilla", "tier": "friend",
		"tone": "sweet", "attitude": "", "run_id": "fixture:run", "branch_id": "original:branch",
		"challenge_slot": "dating.solo.priscilla.day2", "phase": phase, "due_echoes": [], "attempt_residue_id": null}
	if phase == "post_challenge":
		fields.merge({"attempt_id": "fixture:board", "board_result": "cleared", "perfect_reasons": [],
			"relationship_outcome": "loved", "effect_receipt_id": "actual:effect"})
		var schema := FROZEN.schema_for_entry(fields.entry_id)
		if schema.value.fields.has("progression_window_result"):
			fields["progression_window_result"] = {"evaluated": true, "promotion_applied": false, "relationship_state": "friend"}
	return fields

func _dating(post: bool = false) -> Dictionary:
	var snapshot := _snapshot()
	var route: Dictionary = snapshot.gameplay.route_context
	route["active_dating_challenge"] = {"context": {"kind": "solo", "day": 2, "participants": ["priscilla"]},
		"spec": {"board_token": "fixture:board"}, "host": "canonical_solo", "phase": "post_challenge" if post else "pre_challenge",
		"outcome": "cleared" if post else null, "perfect_reasons": [], "relationship_outcome": "loved" if post else null,
		"applied_result": {"receipt": {"terminal_fact": {"transaction_id": "actual:effect"},
			"progression_evaluated": true, "promotion_applied": false, "relationship_state": "friend"}} if post else {}}
	var entries := {}
	for phase: String in (["pre_challenge", "post_challenge"] if post else ["pre_challenge"]):
		var fields := _solo_fields(phase)
		entries[fields.entry_id] = FROZEN.build(fields.entry_id, fields).value
	route[RUN.DATING_KEY] = {"schema_version": 1, "board_token": "fixture:board", "entries": entries}
	return snapshot

func test_v6_does_not_backfill_absent_cache_and_v7_refuses_generated_dating_gap() -> void:
	var snapshot := _dating()
	snapshot.gameplay.route_context.erase(RUN.DATING_KEY)
	var before := snapshot.duplicate(true)
	assert_true(RUN.validate(snapshot).ok)
	assert_eq(RUN.validate(snapshot, true).get("code"), &"frozen_context_snapshot_required")
	assert_eq(snapshot, before, "validation cannot invent a snapshot for a legacy save")
	assert_true(RUN.validate(_snapshot(), true).ok, "no producer has generated a context yet")

func test_minimal_gameplay_without_route_bag_remains_legal() -> void:
	var snapshot := _snapshot()
	snapshot.gameplay = {"narrative_variables": {}}
	assert_true(RUN.validate(snapshot).ok)
	assert_true(RUN.validate(snapshot, true).ok, "no generated producer fact requires a cache")
	snapshot.gameplay["route_context"] = null
	assert_eq(RUN.validate(snapshot).get("code"), &"frozen_run_snapshot_invalid")

func test_saved_dating_binds_run_board_and_effect_but_keeps_original_branch_and_tier() -> void:
	var snapshot := _dating(true)
	snapshot.gameplay["dating_route_state"] = {"priscilla": {"relationship_state": "love", "dark_points": 4}}
	snapshot.gameplay["friend_attitude"] = {"priscilla": "fixated"}
	var before := snapshot.duplicate(true)
	assert_true(RUN.validate(snapshot).ok, "later saved relationship values do not recapture reached prose")
	assert_eq(snapshot, before)
	var fields: Dictionary = snapshot.gameplay.route_context[RUN.DATING_KEY].entries["dating.solo.priscilla.day2.post_challenge"].fields
	fields.effect_receipt_id = "future:effect"
	assert_eq(RUN.validate(snapshot).get("code"), &"frozen_context_effect_receipt_required")
	fields.effect_receipt_id = "actual:effect"
	fields.run_id = "another:run"
	assert_eq(RUN.validate(snapshot).get("code"), &"frozen_context_attempt_mismatch")

func test_present_dating_cache_is_exact_and_requires_its_reached_phases() -> void:
	var snapshot := _dating(true)
	var cache: Dictionary = snapshot.gameplay.route_context[RUN.DATING_KEY]
	cache["future_phase"] = {}
	assert_eq(RUN.validate(snapshot).get("code"), &"frozen_context_cache_invalid")
	cache.erase("future_phase")
	cache.entries.erase("dating.solo.priscilla.day2.pre_challenge")
	assert_eq(RUN.validate(snapshot).get("code"), &"frozen_context_snapshot_required")

func test_pair_pending_count_snapshot_stays_pending_after_actual_rollover() -> void:
	var snapshot := _snapshot()
	var deck: Dictionary = DECK.build_draw([], 0).value
	var context := {"kind": "group", "day": 2, "participants": ["priscilla", "lavinia"]}
	var record := {"context": context, "spec": {"board_token": "pair:board"}, "host": "canonical_pair",
		"pair_form": deck.form, "phase": "pre_challenge", "applied_result": {}}
	var fields := {"entry_id": "dating.group.priscilla_lavinia.day2.pre_challenge", "entry_role": "pair_pre_challenge_scene",
		"day": 2, "phase": "pre_challenge", "run_id": "fixture:run", "branch_id": "original:branch", "attempt_residue_id": null,
		"pair_id": "priscilla_lavinia", "window_day": 2, "encounter_presentation": "group", "group_variation": null,
		"pair_count_receipt": null, "pair_count_status": "pending_rollover", "stable_deck_state": deck}
	var built := FROZEN.build(fields.entry_id, fields)
	assert_true(built.ok, str(built))
	if not built.ok: return
	snapshot.gameplay.route_context["active_dating_challenge"] = record
	snapshot.gameplay.route_context[RUN.DATING_KEY] = {"schema_version": 1, "board_token": "pair:board", "entries": {fields.entry_id: built.value}}
	assert_eq(RUN.validate(snapshot).get("code"), &"frozen_context_pair_receipt_required")
	snapshot.lifecycle.active_resolution_plan = {"source_day": 2, "stages": [{"stage_id": "invitation_rollover", "state": "pending"}]}
	assert_true(RUN.validate(snapshot).ok, "a saved unfinished rollover is an actual pending source")
	snapshot.lifecycle.active_resolution_plan = null
	var actual := {"transaction_id": "actual:rollover", "kind": "resolve_day_end", "day": 2,
		"pl_window": {"outcome": "group", "counts": true, "visible": true}}
	snapshot.contacts.transaction_receipts[actual.transaction_id] = actual
	assert_true(RUN.validate(snapshot).ok)
	var frozen: Dictionary = snapshot.gameplay.route_context[RUN.DATING_KEY].entries[fields.entry_id].fields
	frozen.pair_count_status = "committed"
	frozen.pair_count_receipt = actual.pl_window.duplicate(true)
	frozen.pair_count_receipt["transaction_id"] = "future:rollover"
	assert_eq(RUN.validate(snapshot).get("code"), &"frozen_context_pair_receipt_required")
	frozen.pair_count_receipt.transaction_id = actual.transaction_id
	assert_true(RUN.validate(snapshot).ok)

func _hospital_request(cause: String = "schedule_done") -> Dictionary:
	var fields := {"entry_id": "hospital.faint.day2", "entry_role": "hospital", "day": 2,
		"qualifying_cause": cause, "accepted_record_ids": [], "unfulfilled_record_ids": [],
		"sylvia_eligible": false, "sylvia_witness_receipt_id": null}
	return {"resolution_id": "original:resolution", "resolution_issuer_receipt": {}, "stage_id": "original:stage",
		"substage_id": "actual:intent", "route_id": "hospital", "timeline_id": "hospital.faint",
		"completion_transaction_id": "actual:completion-command", "completion_transaction_provenance": {},
		"context": {"kind": "hospital", "day": 2, "source_entry_ids": [], "miss_receipt_ids": [],
			"presentation": FROZEN.build(fields.entry_id, fields).value}}

func test_schedule_hospital_uses_saved_plan_and_allows_lawful_pending_first_capture() -> void:
	var snapshot := _snapshot()
	var stage := {"stage_id": "hospital_if_triggered", "transaction_id": "original:stage", "state": "pending", "receipt": null}
	snapshot.lifecycle.active_resolution_plan = {"resolution_id": "original:resolution", "resolution_issuer_receipt": {},
		"source_day": 2, "stages": [stage], "committed_schedule": {"entries": []}}
	snapshot.gameplay.pending_hospital = true
	assert_true(RUN.validate(snapshot, true).ok, "pending activation has not generated its first request")
	stage.state = "active"
	assert_eq(RUN.validate(snapshot, true).get("code"), &"hospital_frozen_context_required")
	snapshot.gameplay.route_context[RUN.HOSPITAL_KEY] = {"schema_version": 1, "requests": {"original:resolution": _hospital_request()}}
	assert_true(RUN.validate(snapshot, true).ok)
	snapshot.lifecycle.active_resolution_plan.resolution_issuer_receipt = {"receipt_id": "unrelated:root"}
	assert_eq(RUN.validate(snapshot).get("code"), &"hospital_frozen_request_mismatch")

func test_full_saved_run_boundary_rejects_hospital_checkpoint_frame_forgery() -> void:
	var fixture: Node = autofree(READING_FIXTURE.new())
	fixture.gut = gut
	var snapshot: Dictionary = fixture._hospital_snapshot()
	var before := snapshot.duplicate(true)
	assert_true(RUN.validate(snapshot, true).ok)
	assert_eq(snapshot, before)
	var checkpoint: Dictionary = snapshot.narrative_checkpoint
	checkpoint.frozen_context.playback_id = "foreign:physical:hospital"
	checkpoint.reading_session.ledger.entry_contexts[checkpoint.entry_id] = checkpoint.frozen_context.duplicate(true)
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_entry_context_mismatch",
		"matching attacker-controlled copies cannot supply the independent physical owner")

func test_full_saved_run_boundary_preserves_completed_hospital_anchor_until_destination() -> void:
	var fixture: Node = autofree(READING_FIXTURE.new())
	fixture.gut = gut
	var snapshot: Dictionary = fixture._hospital_snapshot(true)
	var before := snapshot.duplicate(true)
	assert_true(RUN.validate(snapshot, true).ok)
	assert_eq(snapshot, before)
	snapshot.lifecycle.active_resolution_plan.stages[0].receipt.value.presentation_completion_receipt.physical_token = "foreign:physical"
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_physical_boundary_mismatch")

func test_condition_hospital_binds_historical_prepared_request_after_identity_remap() -> void:
	var snapshot := _snapshot()
	var request := _hospital_request("condition_hospital")
	request.stage_id = request.resolution_id + ":present_hospital"
	var stage := {"stage_id": "present_hospital", "state": "active", "prepared": {"presentation_request": request}}
	var closure := {"source_receipt_ids": [], "miss_receipt_ids": [], "sylvia_witness": null,
		"closure_receipt": {"transaction_id": request.resolution_id}}
	snapshot.lifecycle.active_condition_hospital_plan = {"source_day": 2,
		"resolution_receipt": {"receipt_id": "remapped:resolution"}, "transaction_issuer_receipt": {"receipt_id": "remapped:root"},
		"stages": [{"stage_id": "close_invitation_sources", "receipt": {"output": closure}}, stage]}
	assert_true(RUN.validate(snapshot, true).ok, "prepared transport remains bound to its original durable closure")
	request.context.erase("presentation")
	assert_true(RUN.validate(snapshot).ok, "legacy v6 missing frozen context is not reconstructed")
	assert_eq(RUN.validate(snapshot, true).get("code"), &"hospital_frozen_context_required")

func _ending() -> Dictionary:
	var snapshot := _snapshot()
	snapshot.lifecycle.day = 7
	snapshot.lifecycle.state = "ENDING"
	var inputs := {"dark_mode": false, "pair_form": "love_sweet", "special_variant": "full"}
	for friend: String in ENDING.FRIENDS:
		inputs[friend] = {"tier": "friend", "tone": "sweet", "attitude": "", "echo_ids": [], "miss_reasons": []}
	var seed := ENDING.make_seed(inputs, {"priscilla": [], "lavinia": [], "sylvia": [], "priscilla_lavinia": []}, [], "empty_done")
	snapshot.lifecycle.ending_plan = {"steps": [{"ending_id": "ending.alone", "role": "core"}], "next_step_index": 0, "playback_receipts": {}}
	snapshot.gameplay.route_context[RUN.ENDING_KEY] = {"schema_version": 1, "seed": seed.value, "presentations": {}}
	snapshot.gameplay.route_context["provisional_ending_plan"] = {"eligibility_snapshot": {"presentation_by_scope": inputs.duplicate(true), "hospital_required": false}}
	return snapshot

func test_ending_admission_seed_must_match_saved_eligibility_and_missing_seed_is_versioned() -> void:
	var snapshot := _ending()
	assert_true(RUN.validate(snapshot, true).ok, "admitted current step can capture its first snapshot")
	var before := snapshot.duplicate(true)
	snapshot.gameplay.route_context[RUN.ENDING_KEY].seed.presentation_by_scope.sylvia.tone = "dark"
	assert_eq(RUN.validate(snapshot).get("code"), &"ending_frozen_seed_mismatch")
	snapshot = before
	snapshot.gameplay.route_context.erase(RUN.ENDING_KEY)
	assert_true(RUN.validate(snapshot).ok)
	assert_eq(RUN.validate(snapshot, true).get("code"), &"ending_frozen_seed_required")

func test_present_contact_cache_delegates_strict_shape_without_mutating_source() -> void:
	var snapshot := _snapshot()
	snapshot.gameplay.route_context["contacts_frozen_contexts_v1"] = {"schema_version": 1, "entries": {}, "invented": true}
	var before := snapshot.duplicate(true)
	assert_eq(RUN.validate(snapshot).get("code"), &"contacts_frozen_cache_invalid")
	assert_eq(snapshot, before)

func test_hospital_miss_container_wrong_types_refuse_before_typed_contact_calls() -> void:
	for invalid: Variant in [{}, null, "misses", true, 1]:
		var snapshot := _snapshot()
		snapshot.gameplay.route_context["contacts_frozen_contexts_v1"] = {"schema_version": 1, "entries": {}}
		snapshot.gameplay.missed_invitations = invalid
		assert_eq(RUN.validate(snapshot).get("code"), &"contacts_frozen_hospital_miss_source_invalid")
		var gameplay: Dictionary = snapshot.gameplay.duplicate(true)
		snapshot.gameplay.missed_invitations = []
		snapshot.lifecycle.active_condition_hospital_plan = {"source_day": 2, "stages": [{"stage_id": "close_invitation_sources",
			"prepared": {"owner_candidate": {"gameplay": gameplay}}}]}
		assert_eq(RUN.validate(snapshot).get("code"), &"contacts_frozen_hospital_miss_source_invalid")

func test_malformed_contact_source_rows_refuse_instead_of_entering_typed_loops() -> void:
	for invalid: Variant in [null, true, 1, "receipt", []]:
		var snapshot := _snapshot()
		snapshot.gameplay.route_context["contacts_frozen_contexts_v1"] = {"schema_version": 1, "entries": {}}
		snapshot.contacts.transaction_receipts["invalid"] = invalid
		var before := snapshot.duplicate(true)
		assert_false(RUN.validate(snapshot).ok)
		assert_eq(snapshot, before)
	for invalid: Variant in [null, true, 1, "message", {}, ["message"]]:
		var snapshot := _snapshot()
		snapshot.gameplay.route_context["contacts_frozen_contexts_v1"] = {"schema_version": 1, "entries": {}}
		snapshot.contacts.messages.priscilla = invalid
		assert_false(RUN.validate(snapshot).ok)

func test_semantic_checkpoint_cannot_disagree_with_its_saved_canonical_projection() -> void:
	var snapshot := _dating()
	var entry_id := "dating.solo.priscilla.day2.pre_challenge"
	var presentation: Dictionary = snapshot.gameplay.route_context[RUN.DATING_KEY].entries[entry_id].duplicate(true)
	snapshot["narrative_checkpoint"] = {"entry_id": entry_id, "frozen_context": {"presentation": presentation}}
	assert_true(RUN.validate(snapshot).ok)
	presentation.fields.attitude = "fixated"
	assert_eq(RUN.validate(snapshot).get("code"), &"frozen_run_narrative_context_mismatch")
	snapshot.gameplay.route_context.erase(RUN.DATING_KEY)
	assert_true(RUN.validate(snapshot).ok, "v6 permits absent producer cache but still types the supplied presentation")
	presentation.fields.tier = "unregistered"
	assert_false(RUN.validate(snapshot).ok)

func test_hospital_annotation_requires_its_saved_closure_receipt() -> void:
	var snapshot := _snapshot()
	snapshot.gameplay.route_context["contacts_frozen_contexts_v1"] = {"schema_version": 1, "entries": {}}
	snapshot.gameplay.missed_invitations.append({"friend_id": "priscilla", "source": "solo", "day": 2,
		"missed_reason": "hospital", "source_receipt_id": "actual:accepted", "hospital_miss_receipt_id": "future:miss"})
	assert_eq(RUN.validate(snapshot).get("code"), &"contacts_frozen_hospital_miss_source_invalid")
	var miss := {"receipt_id": "actual:miss", "source_receipt_id": "actual:accepted", "day": 2, "participants": ["priscilla"]}
	snapshot.lifecycle.active_condition_hospital_plan = {"source_day": 2, "stages": [
		{"stage_id": "close_invitation_sources", "state": "completed", "receipt": {"output": {"misses": [miss]}}},
		{"stage_id": "present_hospital", "state": "pending", "prepared": null}]}
	assert_eq(RUN.validate(snapshot).get("code"), &"contacts_frozen_hospital_miss_source_invalid")
	snapshot.gameplay.missed_invitations[0].hospital_miss_receipt_id = miss.receipt_id
	assert_true(RUN.validate(snapshot).ok)

func test_prepared_condition_owner_cache_is_validated_before_it_can_be_installed() -> void:
	var snapshot := _snapshot()
	var gameplay: Dictionary = snapshot.gameplay.duplicate(true)
	gameplay.route_context["contacts_frozen_contexts_v1"] = {"schema_version": 1, "entries": {}, "extra": true}
	snapshot.lifecycle.active_condition_hospital_plan = {"source_day": 2, "stages": [
		{"stage_id": "close_invitation_sources", "state": "active", "prepared": {
			"owner_candidate": {"contacts": snapshot.contacts.duplicate(true), "gameplay": gameplay}}},
		{"stage_id": "present_hospital", "state": "pending", "prepared": null}]}
	assert_eq(RUN.validate(snapshot).get("code"), &"contacts_frozen_cache_invalid")

func test_strict_prepared_condition_candidate_requires_its_generated_dating_cache_without_repair() -> void:
	var snapshot := _snapshot()
	var earlier := _dating()
	var owner := {"contacts": earlier.contacts.duplicate(true), "gameplay": earlier.gameplay.duplicate(true)}
	snapshot.lifecycle.active_condition_hospital_plan = {"source_day": 2, "stages": [
		{"stage_id": "close_invitation_sources", "state": "active", "prepared": {"owner_candidate": owner}},
		{"stage_id": "present_hospital", "state": "pending", "prepared": null}]}
	assert_true(RUN.validate(snapshot, true).ok, "the prepared candidate retains its own admitted challenge facts")
	owner.gameplay.route_context.erase(RUN.DATING_KEY)
	var before := snapshot.duplicate(true)
	assert_true(RUN.validate(snapshot).ok, "the explicit pre-cutover optional seam remains unchanged")
	assert_eq(RUN.validate(snapshot, true).get("code"), &"frozen_context_snapshot_required")
	assert_eq(snapshot, before, "refusal preserves both current gameplay and its prepared candidate")
	owner.gameplay.route_context.erase("active_dating_challenge")
	assert_true(RUN.validate(snapshot, true).ok, "a candidate with no admitted challenge needs no Dating cache")

func test_strict_historical_candidate_does_not_inherit_a_later_ending_requirement() -> void:
	var snapshot := _ending()
	var earlier := _snapshot()
	var plan := {"source_day": 2, "stages": [{"stage_id": "advance_day", "prepared": {
		"owner_candidate": {"contacts": earlier.contacts, "gameplay": earlier.gameplay}}}]}
	var before := plan.duplicate(true)
	assert_true(RUN.validate(snapshot, true).ok)
	assert_true(RUN._condition_candidates(plan, snapshot.lifecycle, snapshot.contacts, true).ok,
		"later ENDING state does not fabricate admission in an earlier prepared gameplay bag")
	assert_eq(plan, before)

func test_strict_prepared_pair_keeps_pending_projection_after_a_real_saved_rollover() -> void:
	var earlier := _snapshot()
	var deck: Dictionary = DECK.build_draw([], 0).value
	var fields := {"entry_id": "dating.group.priscilla_lavinia.day2.pre_challenge", "entry_role": "pair_pre_challenge_scene",
		"day": 2, "phase": "pre_challenge", "run_id": "fixture:run", "branch_id": "original:branch", "attempt_residue_id": null,
		"pair_id": "priscilla_lavinia", "window_day": 2, "encounter_presentation": "group", "group_variation": null,
		"pair_count_receipt": null, "pair_count_status": "pending_rollover", "stable_deck_state": deck}
	var built := FROZEN.build(fields.entry_id, fields)
	assert_true(built.ok, str(built))
	if not built.ok: return
	earlier.gameplay.route_context["active_dating_challenge"] = {
		"context": {"kind": "group", "day": 2, "participants": ["priscilla", "lavinia"]},
		"spec": {"board_token": "pair:board"}, "host": "canonical_pair", "pair_form": deck.form,
		"phase": "pre_challenge", "applied_result": {}}
	earlier.gameplay.route_context[RUN.DATING_KEY] = {
		"schema_version": 1, "board_token": "pair:board", "entries": {fields.entry_id: built.value}}
	var closed := CONTACTS.prepare_resolve_day_end(earlier.contacts, 2, {}, "fixture:actual-rollover")
	assert_true(closed.ok, str(closed))
	if not closed.ok: return
	assert_true(closed.value.candidate.transaction_receipts["fixture:actual-rollover"].pl_window is Dictionary)
	var plan := {"source_day": 2, "stages": [{"stage_id": "advance_day", "prepared": {
		"owner_candidate": {"contacts": earlier.contacts.duplicate(true), "gameplay": earlier.gameplay.duplicate(true)}}}]}
	var later_lifecycle: Dictionary = earlier.lifecycle.duplicate(true)
	later_lifecycle.day = 3
	var before := plan.duplicate(true)
	var receipts_before: Dictionary = closed.value.candidate.duplicate(true)
	assert_eq(RUN._condition_candidates(plan, later_lifecycle, earlier.contacts, true).get("code"),
		&"frozen_context_pair_receipt_required", "neither a pending source nor a committed source exists yet")
	assert_true(RUN._condition_candidates(plan, later_lifecycle, closed.value.candidate, true).ok,
		"the real append-only current receipt proves an earlier saved pending pair without rewriting it")
	assert_eq(plan, before)
	assert_eq(closed.value.candidate, receipts_before, "using the later receipt cannot modify its Contacts owner")
	assert_null(plan.stages[0].prepared.owner_candidate.gameplay.route_context[RUN.DATING_KEY].entries[fields.entry_id].fields.pair_count_receipt)

func test_strict_semantic_checkpoint_requires_both_discriminators_and_preserves_generic_restart() -> void:
	var snapshot := _dating()
	var entry_id := "dating.solo.priscilla.day2.pre_challenge"
	var presentation: Dictionary = snapshot.gameplay.route_context[RUN.DATING_KEY].entries[entry_id].duplicate(true)
	var semantic := {"entry_id": entry_id, "frozen_context": {"presentation": presentation}}
	snapshot["narrative_checkpoint"] = semantic.duplicate(true)
	assert_true(RUN.validate(snapshot, true).ok)
	for missing: String in ["entry_id", "frozen_context"]:
		snapshot.narrative_checkpoint = semantic.duplicate(true)
		snapshot.narrative_checkpoint.erase(missing)
		var before := snapshot.duplicate(true)
		assert_eq(RUN.validate(snapshot, true).get("code"), &"frozen_run_narrative_context_invalid")
		assert_eq(snapshot, before)
	for generic: Dictionary in [{}, {"timeline_id": "fixture:timeline", "boundary": "restart"}]:
		snapshot.narrative_checkpoint = generic.duplicate(true)
		var before := snapshot.duplicate(true)
		assert_true(RUN.validate(snapshot, true).ok, "generic restart transport has no semantic producer discriminator")
		assert_eq(snapshot, before)

## The saved plan, not History's copies, supplies each ordered ending frame.
func _ending_reading_snapshot(tail: int = 1, boundary: String = "line") -> Dictionary:
	var snapshot := _ending()
	snapshot["route_id"] = "ending"
	var plan: Dictionary = snapshot.lifecycle.ending_plan
	plan.steps = [{"ending_id": "ending.priscilla.sweet", "role": "core"},
		{"ending_id": "ending.priscilla.observation", "role": "observer_coda", "presentation_variant": "residue"}]
	plan.next_step_index = tail
	if tail > 0:
		plan.playback_receipts["step:0"] = {"value": {"outcome": "completed", "timeline_completion_receipt_id": "actual:step:0:complete"}}
	var cache: Dictionary = snapshot.gameplay.route_context[RUN.ENDING_KEY]
	var frames := {}
	var captions := []
	var entry := ""
	var first_entry := ""
	var frame := {}
	for index: int in range(tail + 1):
		var playback_id := "fixture:run:ending:%d" % index
		var frozen := ENDING.build(plan, index, cache.seed, playback_id)
		assert_true(frozen.ok, str(frozen))
		cache.presentations[playback_id] = frozen.value
		entry = frozen.value.signature.entry_id
		if index == 0: first_entry = entry
		frame = {"expected_stage": "PRIMARY_PENDING", "playback_id": playback_id,
			"role": plan.steps[index].role, "transaction_id": playback_id + ":complete", "presentation": frozen.value.presentation}
		frames[entry] = frame
		captions.append({"publication_id": "publication:%d" % index, "beat": {
			"beat_id": "beat:%d" % index, "line_id": "line:%d" % index,
			"owning_entry_id": entry, "presentation_signature": frozen.value.signature}})
	var reading := {"schema_version": 3, "family": "ending", "catalogue_fingerprint": "fixture:catalogue",
		"boundary": boundary, "frontier": {"line_id": "line:%d" % tail, "publication_id": "publication:%d" % tail} if boundary == "line" else {},
		"ledger": {"session_token": "fixture:run:ending", "frozen_context": {
			"family": "ending", "completion_transaction_id": "fixture:run:ending", "entry_id": first_entry},
			"entry_contexts": frames, "captions": captions}}
	snapshot["narrative_checkpoint"] = {"content_version": 1, "entry_id": entry, "frozen_context": frame,
		"manifest_fingerprint": "fixture:manifest", "stage": frame.expected_stage,
		"transaction_id": frame.transaction_id, "reading_session": reading}
	return snapshot

func test_ending_reading_restore_binds_old_and_current_frames_to_saved_plan() -> void:
	var snapshot := _ending_reading_snapshot()
	var before := snapshot.duplicate(true)
	assert_true(RUN.validate(snapshot, true).ok)
	assert_eq(snapshot, before, "validation is pure")
	var checkpoint: Dictionary = snapshot.narrative_checkpoint
	checkpoint.reading_session.ledger.entry_contexts["ending.priscilla.sweet"].transaction_id = "foreign:completed"
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_entry_context_mismatch",
		"an older History frame must also match the saved physical plan")

func test_ending_reading_between_steps_accepts_future_cache_without_fabricating_frame() -> void:
	var snapshot := _ending_reading_snapshot(0, "between_entries")
	var plan: Dictionary = snapshot.lifecycle.ending_plan
	plan.next_step_index = 1
	plan.playback_receipts["step:0"] = {"value": {"outcome": "completed", "timeline_completion_receipt_id": "actual:step:0:complete"}}
	var cache: Dictionary = snapshot.gameplay.route_context[RUN.ENDING_KEY]
	cache.presentations["fixture:run:ending:1"] = ENDING.build(plan, 1, cache.seed, "fixture:run:ending:1").value
	var before := snapshot.duplicate(true)
	assert_true(RUN.validate(snapshot, true).ok,
		"completion advances durable cursor before the next semantic publication")
	assert_eq(snapshot, before)
	assert_eq(snapshot.narrative_checkpoint.reading_session.ledger.entry_contexts.size(), 1)
	snapshot.narrative_checkpoint.reading_session.boundary = "line"
	snapshot.narrative_checkpoint.reading_session.frontier = {"line_id": "line:0", "publication_id": "publication:0"}
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_physical_boundary_mismatch",
		"the completed step cannot masquerade as an active line")

func test_ending_reading_refuses_reordered_history_foreign_session_and_missing_prerequisite() -> void:
	var snapshot := _ending_reading_snapshot()
	snapshot.narrative_checkpoint.reading_session.ledger.captions.reverse()
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_caption_sequence_invalid")
	snapshot = _ending_reading_snapshot()
	snapshot.narrative_checkpoint.reading_session.ledger.session_token = "another:run:ending"
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_physical_owner_mismatch")
	snapshot = _ending_reading_snapshot()
	snapshot.lifecycle.ending_plan.playback_receipts.clear()
	assert_eq(RUN.validate(snapshot, true).get("code"), &"ending_frozen_prerequisite_missing")

func test_ending_reading_completed_tail_remains_an_inert_history_anchor() -> void:
	var snapshot := _ending_reading_snapshot(1, "between_entries")
	assert_true(RUN.validate(snapshot, true).ok,
		"a just-completed physical tail remains valid if its cursor save failed")
	snapshot.lifecycle.ending_plan.next_step_index = 2
	snapshot.lifecycle.ending_plan.playback_receipts["step:1"] = {"value": {
		"outcome": "completed", "timeline_completion_receipt_id": "actual:step:1:complete"}}
	snapshot.lifecycle.state = "COMPLETED"
	assert_true(RUN.validate(snapshot, true).ok, "completed Run preserves chronological History without playable text")
	snapshot.lifecycle.ending_plan.next_step_index = 1
	assert_eq(RUN.validate(snapshot, true).get("code"), &"reading_physical_owner_mismatch")
