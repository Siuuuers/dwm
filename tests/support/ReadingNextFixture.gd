extends RefCounted
## Synthetic Solo semantic/physical facts composed into the current Run seed.
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")
const RUN_CONTEXT := preload("res://scripts/narrative/FrozenRunContext.gd")
const RESTORE := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd")
const OPERATION := preload("res://scripts/narrative/ReadingTraversalOperation.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const ENTRY := "dating.solo.priscilla.day1.pre_challenge"

static func caption(suffix: String, publication: int) -> Dictionary:
	return {"publication_id": "caption:%d" % publication, "beat": {
		"owning_entry_id": ENTRY, "line_id": "fixture.next." + suffix,
		"beat_id": "fixture.next.beat." + suffix,
		"presentation_signature": {"content_revision": "fixture-v1", "variant_id": "fixture.next.beat." + suffix}}}

static func snapshot() -> Dictionary:
	var result: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(
		"res://tests/fixtures/saves/v7_desktop_prepared.json")).value
	result["schema_version"] = preload("res://scripts/domain/run/RunSnapshotSchema.gd").SCHEMA_VERSION
	var fields := {"entry_id": ENTRY, "entry_role": "solo_pre_challenge", "day": 1,
		"friend_id": "priscilla", "tier": "friend", "tone": "sweet", "attitude": "",
		"run_id": result.run_id, "branch_id": result.lifecycle.branch_id,
		"challenge_slot": "dating.solo.priscilla.day1", "phase": "pre_challenge",
		"due_echoes": [], "attempt_residue_id": null}
	var presentation: Dictionary = FROZEN.build(ENTRY, fields).value
	var frame := {"expected_stage": "pre_challenge", "playback_id": "fixture:physical:pre_challenge",
		"role": "dating_phase", "transaction_id": "fixture:completion:pre_challenge", "presentation": presentation}
	var first := caption("a", 1)
	var ledger := {"session_token": "fixture:completion",
		"frozen_context": {"completion_transaction_id": "fixture:completion", "pre_entry_id": ENTRY},
		"entry_contexts": {ENTRY: frame.duplicate(true)}, "captions": [first]}
	result["route_id"] = "dating"
	result["active_app_id"] = null
	result.gameplay["route_context"] = {"active_dating_challenge": {
		"context": {"kind": "solo", "day": 1, "participants": ["priscilla"]},
		"spec": {"board_token": "fixture:board"}, "host": "canonical_solo", "phase": "pre_challenge",
		"completion_transaction_id": "fixture:completion", "physical_token": "fixture:physical",
		"outcome": null, "perfect_reasons": [], "relationship_outcome": null, "applied_result": {}},
		RUN_CONTEXT.DATING_KEY: {"schema_version": 1, "board_token": "fixture:board", "entries": {ENTRY: presentation}}}
	result["narrative_checkpoint"] = {"content_version": 1, "entry_id": ENTRY, "frozen_context": frame,
		"manifest_fingerprint": RESTORE._entry_document_fingerprint(), "stage": "pre_challenge",
		"transaction_id": "fixture:completion:pre_challenge", "reading_session": {
			"schema_version": 1, "catalogue_fingerprint": "fixture:next:catalogue", "boundary": "line",
			"ledger": ledger, "frontier": {"line_id": first.beat.line_id, "publication_id": first.publication_id}}}
	return result

static func plan(checkpoint: Dictionary, completion: bool = false) -> Dictionary:
	var reading: Dictionary = checkpoint.reading_session
	return {"entry_id": checkpoint.entry_id, "catalogue_fingerprint": reading.catalogue_fingerprint,
		"source_ledger": reading.ledger.duplicate(true), "source_frontier": reading.frontier.duplicate(true),
		"traversed_captions": [caption("b", 2)],
		"destination": {"kind": "completion" if completion else "line", "caption": null if completion else caption("c", 3)}}

static func checkpoint_for(checkpoint: Dictionary, frozen_plan: Dictionary, phase: String) -> Dictionary:
	var result := checkpoint.duplicate(true)
	result["reading_session"] = OPERATION.project(frozen_plan, phase).value
	return result

static func snapshot_input(snapshot_value: Dictionary) -> Dictionary:
	var result := {}
	for key: String in ["lifecycle", "gameplay", "contacts", "committed_schedule", "dating",
			"applied_effect_transaction_ids", "applied_variable_transaction_ids", "desktop", "schedule_view", "command_receipts"]:
		result[key] = snapshot_value[key].duplicate(true) if snapshot_value[key] is Dictionary or snapshot_value[key] is Array else snapshot_value[key]
	return result
