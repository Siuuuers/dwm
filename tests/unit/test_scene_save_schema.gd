extends "res://addons/gut/test.gd"

const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const MIGRATIONS := preload("res://scripts/infrastructure/save/SaveMigrations.gd")

# These are wire-boundary unit checks, not substitutes for real owner-backed
# Run9 admission. Full integration supplies the actual issuer, Profile and B2.
func test_scene_versions_do_not_replace_or_migrate_legacy_versions() -> void:
	assert_eq(RUN.SCHEMA_VERSION, 8)
	assert_eq(SAVE.DOCUMENT_VERSION, 8)
	assert_eq(RUN.SCENE_SCHEMA_VERSION, 9)
	assert_eq(SAVE.SCENE_DOCUMENT_VERSION, 9)
	var locator := {"kind": "quick", "slot_id": null}
	assert_eq(MIGRATIONS.migrate_document({"schema_version": 7}, locator).code,
		&"unsupported_run_configuration_schema")
	assert_eq(MIGRATIONS.migrate_document({"schema_version": 10}, locator).code,
		&"unsupported_future_schema")
	var malformed := {"schema_version": 9}
	assert_false(MIGRATIONS.migrate_document(malformed, locator).ok)
	assert_eq(malformed, {"schema_version": 9}, "validation must not synthesize missing Run9 owners")

func test_scene_recovery_cannot_enter_legacy_document_via_proof_family() -> void:
	assert_eq(SAVE._journal_family_error(8, [{"snapshot": {"schema_version": 8}}]), "")
	assert_ne(SAVE._journal_family_error(8, [{"snapshot": {"schema_version": 9}}]), "")
	assert_ne(SAVE._journal_family_error(8, [{"snapshot": {"schema_version": 9.0}}]), "")
	var raw := [{"checkpoint_kind": "line", "snapshot": {"checkpoint_id": "run:1"}}]
	assert_eq(SAVE._scene_proof_error(raw, raw.duplicate(true)), "")
	var substituted := raw.duplicate(true)
	substituted[0].snapshot.checkpoint_id = "run:2"
	assert_ne(SAVE._scene_proof_error(raw, substituted), "")
	assert_ne(SAVE._scene_proof_error(raw, []), "")

func test_scene_admissions_do_not_claim_effect_or_variable_application() -> void:
	var receipt := {"kind": "scene_admission"}
	assert_eq(RUN._validate_receipt_partition({"admit": receipt}, [], []), "")
	assert_ne(RUN._validate_receipt_partition({"admit": receipt}, ["admit"], []), "")
	assert_ne(RUN._validate_receipt_partition({"admit": receipt}, [], ["admit"]), "")
	var effect := {"kind": "effect_transaction"}
	assert_eq(RUN._validate_receipt_partition({"admit": receipt, "effect": effect}, ["effect"], []), "")
	assert_ne(RUN._validate_receipt_partition({"admit": receipt, "effect": effect}, [], []), "")

func test_new_scene_builder_never_fills_calendar_or_missing_owner_defaults() -> void:
	var incomplete := {"lifecycle": {"run_id": "run:scene"}}
	var before := incomplete.duplicate(true)
	var result := RUN.build_scene(incomplete, {}, "scene", null, {}, 1, 0)
	assert_false(result.ok)
	assert_eq(result.code, &"invalid_snapshot_input")
	assert_eq(incomplete, before)
	assert_false(incomplete.has("dating"))
	assert_false(incomplete.has("committed_schedule"))
