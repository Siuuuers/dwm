extends "res://addons/gut/test.gd"
## Full public Run9/Save9 admission with actual owner-backed receipt + reading
## joins. Initial prior checkpoint provenance is explicitly injected by fixture.
## Uses installed transition marker (not a fabricated notification registration).
const FIXTURE := preload("res://tests/support/SceneRunSaveFixture.gd")
const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
var fixture: RefCounted
var setup_result: Dictionary = {}

func before_all() -> void:
	fixture = FIXTURE.new()
	setup_result = fixture.setup(get_tree())
	assert_true(setup_result.get("ok", false), str(setup_result))

func after_all() -> void:
	if fixture != null: fixture.close()

func _ready_fixture() -> bool:
	assert_true(setup_result.get("ok", false), "full fixture must be positively admitted: " + str(setup_result))
	return setup_result.get("ok", false)

func test_real_issuer_profile_reading_and_storage_pass_full_run_and_save_apis() -> void:
	if not _ready_fixture(): return
	var before: Dictionary = fixture.observed_state()
	assert_true(before.game.get("ok", false), "actual GameState backup capture succeeded")
	assert_true(before.root.get("ok", false), "actual durable issuer root capture succeeded")
	var run: Dictionary = RUN.validate(fixture.snapshot)
	assert_true(run.ok, str(run))
	var save: Dictionary = SAVE.validate(fixture.document)
	assert_true(save.ok, str(save))
	assert_true(fixture.setup_complete, "setup included real Profile and Save9 disk rereads")
	assert_eq(fixture.observed_state(), before, "admission does not mutate actual live owners")

func test_rebuilt_authenticated_absent_publication_fails_full_run_and_save_anchor_join() -> void:
	if not _ready_fixture(): return
	_check_authenticated_anchor_refusal("publication_id", "TEST.publication.not.retained")

func test_rebuilt_authenticated_wrong_catalogue_fails_full_run_and_save_anchor_join() -> void:
	if not _ready_fixture(): return
	_check_authenticated_anchor_refusal("catalogue_fingerprint", "b".repeat(64))

func _check_authenticated_anchor_refusal(field: String, value: String) -> void:
	assert_true(RUN.validate(fixture.snapshot).ok, "positive full Run prerequisite")
	assert_true(SAVE.validate(fixture.document).ok, "positive full Save prerequisite")
	var changed: Dictionary = fixture.anchor.duplicate(true)
	changed[field] = value
	var rebuilt: Dictionary = fixture.rebuild_event(changed)
	assert_true(rebuilt.get("ok", false), "real issuer reconstructs matching completion child: " + str(rebuilt))
	if not rebuilt.get("ok", false): return
	var candidate: Dictionary = fixture.with_receipt(rebuilt.value)
	var receipts: Dictionary = CONTRACT.validate_scene_receipts(candidate.command_receipts, fixture.bundle, fixture.issuer)
	assert_true(receipts.ok, "authenticated semantic receipts pass before saved-reading membership: " + str(receipts))
	if not receipts.ok: return
	var before: Dictionary = fixture.observed_state()
	assert_true(before.game.get("ok", false), "actual GameState backup capture succeeded")
	assert_true(before.root.get("ok", false), "actual durable issuer root capture succeeded")
	var expected_code: StringName = &"event_anchor_invalid" if field == "publication_id" else &"event_anchor_catalogue_mismatch"
	var candidate_before: Dictionary = candidate.duplicate(true)
	var candidate_document: Dictionary = fixture.document_for(candidate)
	var document_before: Dictionary = candidate_document.duplicate(true)
	var run: Dictionary = RUN.validate(candidate)
	assert_eq(run.get("code"), expected_code, "actual retained-reading join is the refusal boundary")
	assert_false(run.ok, "public Run validation must reach and reject absent anchor membership")
	var save: Dictionary = SAVE.validate(candidate_document)
	assert_eq(save.get("code"), expected_code, "Save preserves the exact reading-owner refusal")
	assert_false(save.ok, "public Save validation must preserve Run refusal")
	assert_eq(candidate, candidate_before, "Run admission does not edit refused bytes")
	assert_eq(candidate_document, document_before, "Save admission does not edit refused bytes")
	assert_eq(fixture.observed_state(), before, "refusal occurs without owner mutation")

func test_other_occurrence_anchor_is_refused_by_authenticated_source_binding() -> void:
	if not _ready_fixture(): return
	# A receipt for a different occurrence is rejected before ledger membership:
	# make_scene_receipt requires anchor.session_id == semantic.source occurrence.
	# This assertion deliberately does not claim an authenticated membership test.
	var changed: Dictionary = fixture.anchor.duplicate(true)
	changed.session_id = "TEST.other.occurrence"
	var before: Dictionary = fixture.observed_state()
	assert_true(before.game.get("ok", false), "actual GameState backup capture succeeded")
	assert_true(before.root.get("ok", false), "actual durable issuer root capture succeeded")
	var rebuilt: Dictionary = fixture.rebuild_event(changed)
	assert_false(rebuilt.ok, "issuer-backed builder refuses a foreign occurrence anchor")
	var candidate: Dictionary = fixture.snapshot.duplicate(true)
	candidate.command_receipts[fixture.event.command_id].scene_event.reading_anchor = changed
	assert_false(RUN.validate(candidate).ok, "public Run also refuses unrebuilt foreign occurrence")
	assert_false(SAVE.validate(fixture.document_for(candidate)).ok, "public Save preserves receipt refusal")
	assert_eq(fixture.observed_state(), before)


const CHECKPOINT_PORT := preload("res://scripts/application/run/SaveManagerCheckpointPort.gd")
const CANONICAL := preload("res://scripts/validation/CanonicalJsonWriter.gd")

# Reuse the admitted owner-backed fixture, retaining its original valid checkpoint
# as history under a later current checkpoint. No new story/issuer fixture is invented.
func _scene_document_with_retained_history() -> Dictionary:
	if not _ready_fixture(): return {}
	var document: Dictionary = fixture.document.duplicate(true)
	var previous: Dictionary = document.current_snapshot.duplicate(true)
	document.current_snapshot.snapshot.checkpoint_sequence += 1
	document.current_snapshot.snapshot.checkpoint_id = "%s:%d" % [
		document.current_snapshot.snapshot.run_id, document.current_snapshot.snapshot.checkpoint_sequence]
	document.recovery_journal = [previous]
	var admitted: Dictionary = SAVE.validate(document)
	assert_true(admitted.get("ok", false), "positive complete Save9 history prerequisite: " + str(admitted))
	return document if admitted.get("ok", false) else {}

func _scene_canonical(value: Variant) -> String:
	var encoded: Dictionary = CANONICAL.stringify(value)
	assert_true(encoded.get("ok", false), str(encoded))
	return str(encoded.get("value", ""))

func test_warm_scene_splice_preserves_history_and_admits_exact_document_proofs() -> void:
	var document := _scene_document_with_retained_history()
	if document.is_empty(): return
	var raw_proofs: Array = document.recovery_journal.duplicate(true)
	var normalized_proofs: Array = document.recovery_journal.duplicate(true)
	var before := _scene_canonical(document)
	var raw_before := _scene_canonical(raw_proofs)
	var proofs_before := _scene_canonical(normalized_proofs)
	var normalized: Dictionary = CHECKPOINT_PORT._normalize_outgoing_document(document, true)
	var outgoing: Dictionary = SAVE._validate_outgoing_document_proofs(normalized, raw_proofs, normalized_proofs)
	# Baseline fails specifically with scene journal proof count mismatch because
	# its shared splice normalizer replaces Save9's retained journal with [].
	assert_true(outgoing.get("ok", false), "warm Save9 must keep its proof-count binding: " + str(outgoing))
	if not outgoing.get("ok", false): return
	assert_eq(normalized.recovery_journal.size(), raw_proofs.size())
	assert_eq(_scene_canonical(normalized.recovery_journal), raw_before)
	var full: Dictionary = SAVE.validate(CHECKPOINT_PORT._normalize_json_string_types(document))
	assert_true(full.get("ok", false), str(full))
	if not full.get("ok", false): return
	assert_eq(_scene_canonical(outgoing.value.candidate), _scene_canonical(full.value.candidate),
		"optimized proof admission describes the same exact bytes as full validation")
	assert_eq(_scene_canonical(document), before, "normalization/admission leaves caller values unchanged")
	assert_eq(_scene_canonical(raw_proofs), raw_before)
	assert_eq(_scene_canonical(normalized_proofs), proofs_before)
	outgoing.value.candidate.recovery_journal[0].snapshot.gameplay.coins += 1
	outgoing.value.candidate.current_snapshot.snapshot.gameplay.coins += 1
	assert_eq(_scene_canonical(document), before, "returned current/history do not alias caller")
	assert_eq(_scene_canonical(raw_proofs), raw_before, "returned history does not alias raw proof")
	assert_eq(_scene_canonical(normalized_proofs), proofs_before, "returned history does not alias document proof")

func test_scene_splice_still_refuses_missing_or_substituted_history_proofs() -> void:
	var document := _scene_document_with_retained_history()
	if document.is_empty(): return
	var before := _scene_canonical(document)
	var normalized: Dictionary = CHECKPOINT_PORT._normalize_outgoing_document(document, true)
	var missing: Dictionary = SAVE._validate_outgoing_document_proofs(normalized, [], [])
	assert_false(missing.get("ok", false))
	assert_eq(missing.get("code"), &"invalid_recovery_journal")
	assert_eq(missing.get("message"), "scene journal proof count mismatch")
	var substituted: Array = document.recovery_journal.duplicate(true)
	substituted[0].snapshot.gameplay.coins += 1
	var substituted_before := _scene_canonical(substituted)
	var refused: Dictionary = SAVE._validate_outgoing_document_proofs(normalized, substituted, substituted.duplicate(true))
	assert_false(refused.get("ok", false))
	assert_eq(refused.get("code"), &"invalid_recovery_journal")
	assert_eq(refused.get("message"), "scene journal proof does not match its bundle")
	assert_eq(_scene_canonical(document), before)
	assert_eq(_scene_canonical(substituted), substituted_before, "refusal never repairs a substituted proof")

func test_legacy_splice_normalization_keeps_empty_history_shortcut_and_cold_path() -> void:
	# A normalization-only wire value; full legacy schema/byte acceptance remains
	# covered by test_save_manager_checkpoint_port's existing splice tests.
	var document := {"schema_version": 8, "current_snapshot": {"marker": &"current"},
		"recovery_journal": [{"marker": &"history"}]}
	var before := document.duplicate(true)
	var warm: Dictionary = CHECKPOINT_PORT._normalize_outgoing_document(document, true)
	assert_eq(warm.recovery_journal, [])
	assert_eq(typeof(warm.current_snapshot.marker), TYPE_STRING)
	var cold: Dictionary = CHECKPOINT_PORT._normalize_outgoing_document(document, false)
	assert_eq(cold, CHECKPOINT_PORT._normalize_json_string_types(document))
	assert_eq(cold.recovery_journal.size(), 1)
	assert_eq(typeof(cold.recovery_journal[0].marker), TYPE_STRING)
	assert_eq(document, before)
	assert_eq(typeof(document.current_snapshot.marker), TYPE_STRING_NAME)
	assert_eq(typeof(document.recovery_journal[0].marker), TYPE_STRING_NAME)

func test_scene_profile_preserves_success_refusal_bytes_and_detachment() -> void:
	var valid := _scene_document_with_retained_history()
	if valid.is_empty(): return
	for mode: String in ["valid", "mismatched_proof", "malformed_history"]:
		var document: Dictionary = valid.duplicate(true)
		if mode == "malformed_history":
			document.recovery_journal[0].snapshot.checkpoint_sequence = document.current_snapshot.snapshot.checkpoint_sequence
			document.recovery_journal[0].snapshot.checkpoint_id = document.current_snapshot.snapshot.checkpoint_id
		var proofs: Array = document.recovery_journal.duplicate(true)
		if mode == "mismatched_proof": proofs[0].snapshot.gameplay.coins += 1
		var before := _scene_canonical(document)
		var proofs_before := _scene_canonical(proofs)
		var disabled := {}
		var enabled := {"diagnostic": true}
		var plain: Dictionary = SAVE._validate_outgoing_document_proofs(document, proofs, proofs, disabled)
		var measured: Dictionary = SAVE._validate_outgoing_document_proofs(document, proofs, proofs, enabled)
		assert_eq(measured, plain, mode + ": diagnostic flag preserves full result")
		assert_eq(measured.ok, mode == "valid", mode)
		assert_true(disabled.is_empty(), "disabled profiling remains empty")
		assert_true(enabled.has("outgoing_schema_proof_binding_us"))
		assert_eq(enabled.has("outgoing_schema_scene_journal_us"), mode != "mismatched_proof")
		if measured.ok:
			assert_true(enabled.has("history_run9_semantic_owner_us"))
			assert_true(enabled.has("history_semantic_reading_anchors_us"))
			assert_true(enabled.has("history_receipt_prelude_us"))
			assert_eq(enabled.get("history_receipt_calls"), enabled.get("history_receipt_completed"))
			assert_eq(_scene_canonical(measured.value.candidate), _scene_canonical(plain.value.candidate))
			measured.value.candidate.recovery_journal[0].snapshot.gameplay.coins += 1
		assert_eq(_scene_canonical(document), before)
		assert_eq(_scene_canonical(proofs), proofs_before)
	var profile := {"diagnostic": true}
	var built: Dictionary = SAVE.build(&"autosave", null, &"automatic", valid.current_snapshot, valid.recovery_journal, {}, valid.recovery_journal)
	var timed: Dictionary = SAVE.build(&"autosave", null, &"automatic", valid.current_snapshot, valid.recovery_journal, {}, valid.recovery_journal, profile)
	assert_true(timed.ok, str(timed))
	assert_eq(timed, built)
	assert_true(profile.has("document_schema_proof_binding_us"))
	assert_true(profile.has("document_schema_scene_journal_us"))
	var cold_profile := {"diagnostic": true}
	assert_eq(SAVE.validate(valid, cold_profile), SAVE.validate(valid))
	assert_true(cold_profile.has("outgoing_schema_scene_journal_us"))

	# Public receipt refusal order and detached results remain identical with timing.
	for receipt_mode: String in ["valid", "wrong_issuer", "bad_bundle", "bad_receipt"]:
		var receipts: Dictionary = fixture.snapshot.command_receipts.duplicate(true)
		var bundle: Dictionary = fixture.bundle.duplicate(true)
		var issuer: Object = fixture.issuer if receipt_mode != "wrong_issuer" else null
		if receipt_mode == "bad_bundle": bundle.clear()
		if receipt_mode == "bad_receipt": receipts["invalid"] = {"transaction_id": "different"}
		var before_receipts := _scene_canonical(receipts)
		var before_bundle := _scene_canonical(bundle)
		var receipt_profile := {"diagnostic": true}
		var plain_receipts: Dictionary = CONTRACT.validate_scene_receipts(receipts, bundle, issuer, null, fixture.snapshot.contacts)
		var timed_receipts: Dictionary = CONTRACT.validate_scene_receipts(receipts, bundle, issuer, null, fixture.snapshot.contacts, receipt_profile)
		assert_eq(timed_receipts, plain_receipts, receipt_mode)
		assert_eq(timed_receipts.get("ok"), receipt_mode == "valid", receipt_mode)
		assert_eq(receipt_profile.get("history_receipt_calls"), 1)
		assert_eq(_scene_canonical(receipts), before_receipts)
		assert_eq(_scene_canonical(bundle), before_bundle)
