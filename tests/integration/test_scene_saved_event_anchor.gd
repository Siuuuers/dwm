extends "res://addons/gut/test.gd"
## Full public Run9/Save9 admission with actual owner-backed receipt + reading
## joins. Initial prior checkpoint provenance is explicitly injected by fixture.
## Uses installed transition marker (not a fabricated notification registration).
const FIXTURE := preload("res://tests/support/SceneRunSaveFixture.gd")
const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const FROZEN_RUN := preload("res://scripts/narrative/FrozenRunContext.gd")
class PermissiveSceneAuthority:
	extends RefCounted
	var calls := 0
	func validate_scene_snapshot_semantics(_snapshot: Dictionary, _bundle: Dictionary) -> Dictionary:
		calls += 1
		return {"ok": true}

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

func test_selected_receipt_projection_is_owned_frozen_and_matches_fresh_validation() -> void:
	if not _ready_fixture(): return
	var manifest := preload("res://scripts/narrative/DialogicEntryManifest.gd")
	var selected: Dictionary = manifest.scene_contract_tables()
	assert_true(selected.ok)
	if not selected.ok: return
	assert_true(selected.value.is_read_only())
	assert_true(selected.value.entries.is_read_only())
	assert_true(selected.value.entries.values()[0].is_read_only())
	assert_true(selected.bundle.is_read_only())
	assert_true(selected.bundle.scene_programme.entries.is_read_only())
	assert_true(is_same(selected.value, manifest.scene_contract_tables().value), "one immutable selected projection")
	var fresh := CONTRACT.validate_bundle_structure(fixture.bundle)
	assert_true(fresh.ok)
	assert_eq(selected.value, fresh.value)
	fresh.value.entries.clear()
	assert_false(manifest.scene_contract_tables().value.entries.is_empty())
	var owner: Object = fixture.game.get_node_or_null("/root/SaveManager")
	var expected := CONTRACT.validate_scene_receipts(fixture.snapshot.command_receipts, fixture.bundle,
		fixture.issuer, owner, fixture.snapshot.contacts)
	var actual := CONTRACT.validate_selected_scene_receipts(fixture.snapshot.command_receipts,
		fixture.issuer, owner, fixture.snapshot.contacts)
	assert_true(expected.ok, str(expected))
	assert_eq(actual, expected)
	if not actual.ok: return
	actual.value.commands.clear()
	assert_eq(CONTRACT.validate_selected_scene_receipts(fixture.snapshot.command_receipts,
		fixture.issuer, owner, fixture.snapshot.contacts), expected, "returned receipts are detached")
	var changed: Dictionary = fixture.bundle.duplicate(true)
	changed.caption_registry.entries[0].lines[0].text = "Different registered caption."
	var changed_tables := CONTRACT.validate_bundle_structure(changed)
	assert_true(changed_tables.ok)
	assert_ne(changed_tables.value.fingerprint, selected.value.fingerprint, "arbitrary input is freshly derived")
	assert_false(CONTRACT.validate_scene_receipts(fixture.snapshot.command_receipts, changed,
		fixture.issuer, owner, fixture.snapshot.contacts).ok, "selected proof cannot authenticate changed registration")

func test_selected_receipt_refusal_order_keeps_input_and_issuer_checks() -> void:
	assert_eq(CONTRACT.validate_selected_scene_receipts({"bad": Vector2.ZERO}, null).code,
		&"scene_receipt_invalid")
	assert_eq(CONTRACT.validate_selected_scene_receipts({}, null).code, &"scene_receipt_issuer_unbound")

func test_rebuilt_authenticated_absent_publication_fails_full_run_and_save_anchor_join() -> void:
	if not _ready_fixture(): return
	_check_authenticated_anchor_refusal("publication_id", "TEST.publication.not.retained")

func test_frozen_commands_are_authenticated_detached_and_rechecked_on_next_call() -> void:
	if not _ready_fixture(): return
	var original: Dictionary = fixture.snapshot.duplicate(true)
	var before: Dictionary = fixture.observed_state()
	var result: Dictionary = FROZEN_RUN.validate(fixture.snapshot, true)
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_has(result, "scene_commands")
	if not result.has("scene_commands"): return
	assert_eq(result.scene_commands[fixture.event.command_id], fixture.snapshot.command_receipts[fixture.event.command_id])
	assert_eq(result.value.entry_contexts, fixture.snapshot.narrative_checkpoint.reading_session.ledger.entry_contexts)
	result.scene_commands[fixture.event.command_id].scene_event.reading_anchor.publication_id = "TEST.changed"
	assert_eq(fixture.snapshot, original)
	assert_true(RUN.validate(fixture.snapshot).ok, "a returned command cannot corrupt later semantic admission")
	var changed: Dictionary = fixture.snapshot.duplicate(true)
	changed.command_receipts[fixture.event.command_id].request_fingerprint = "0".repeat(64)
	assert_false(FROZEN_RUN.validate(changed, true).ok, "each public call authenticates fresh input")
	assert_false(RUN.validate(changed).ok)
	assert_true(FROZEN_RUN.validate(fixture.snapshot, true).ok)
	assert_eq(fixture.observed_state(), before)

func test_semantic_owner_does_not_reuse_another_issuers_frozen_proof() -> void:
	if not _ready_fixture(): return
	var foreign := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd").new()
	var root := preload("res://tests/support/FakeDesktopIssuerRootStore.gd").new("cd".repeat(32), 1)
	assert_true(foreign.configure(root).ok)
	assert_false(FROZEN_RUN.scene_validation_uses(foreign, null))
	var original: Object = fixture.game._identity_issuer
	fixture.game._identity_issuer = foreign
	var refused: Dictionary = fixture.game.validate_scene_snapshot_semantics(fixture.snapshot, fixture.bundle)
	fixture.game._identity_issuer = original
	assert_false(refused.ok, "a differently bound GameState must still authenticate with its own issuer")
	assert_true(RUN.validate(fixture.snapshot).ok)

func test_custom_semantic_authority_cannot_bypass_receipt_authentication() -> void:
	if not _ready_fixture(): return
	var before: Dictionary = fixture.observed_state()
	var original_authority: Object = RUN._scene_authority
	var original_creation_owner: Object = RUN._scene_creation_owner
	# This older v2 fixture normally omits the schema's creation owner. Align it
	# explicitly so the positive prerequisite exercises actual receipt deferral.
	RUN._scene_creation_owner = fixture.game.get_node_or_null("/root/SaveManager")
	var matched: bool = RUN._scene_semantic_authenticates_receipts()
	var admitted: Dictionary = RUN.validate(fixture.snapshot)
	var changed: Dictionary = fixture.snapshot.duplicate(true)
	changed.command_receipts[fixture.event.command_id].request_fingerprint = "0".repeat(64)
	var real_refused: Dictionary = RUN.validate(changed)
	var custom := PermissiveSceneAuthority.new()
	RUN._scene_authority = custom
	var custom_matched: bool = RUN._scene_semantic_authenticates_receipts()
	var custom_admitted: Dictionary = RUN.validate(fixture.snapshot)
	var calls_before_refusal: int = custom.calls
	var refused_run: Dictionary = RUN.validate(changed)
	var refused_save: Dictionary = SAVE.validate(fixture.document_for(changed))
	var calls_after_refusal: int = custom.calls
	RUN._scene_authority = original_authority
	RUN._scene_creation_owner = original_creation_owner
	assert_true(matched, "same actual owners exercise deferred receipt authentication")
	assert_true(admitted.ok, str(admitted))
	assert_false(real_refused.ok, "the real semantic owner still authenticates deferred receipts")
	assert_false(custom_matched, "a permissive callback cannot select receipt deferral")
	assert_true(custom_admitted.ok, str(custom_admitted))
	assert_eq(calls_before_refusal, 1, "valid input reaches the configured custom authority")
	assert_false(refused_run.ok, "Run independently rejects forged receipts with a custom authority")
	assert_false(refused_save.ok, "Save preserves the independent receipt refusal")
	assert_eq(calls_after_refusal, calls_before_refusal, "forged receipts are refused before the permissive callback")
	assert_true(RUN.validate(fixture.snapshot).ok)
	assert_eq(fixture.observed_state(), before)

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
