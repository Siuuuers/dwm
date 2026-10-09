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
