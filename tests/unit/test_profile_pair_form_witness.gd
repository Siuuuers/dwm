extends "res://addons/gut/test.gd"

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const MIGRATION := preload("res://scripts/profile/ProfileMigration.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")

func _manager(storage: Object) -> Node:
	var manager := MANAGER.new()
	autofree(manager)
	assert_true(manager.initialize(storage).ok)
	return manager

func test_v4_profile_upgrade_preserves_facts_without_inventing_pair_witnesses() -> void:
	var old: Dictionary = SCHEMA.make_defaults()
	old.schema_version = 4
	old.erase("observer_evidence")
	old.erase("pair_deck_draws")
	old.erase("reached_presentations")
	old.erase("reached_presentation_chronology")
	old.erase("witnessed_caption_variants")
	old.erase("pair_form_witness_receipts")
	old.erase("dating_attempts")
	old.gallery_unlocks = ["ending.priscilla_lavinia"]
	var migrated: Dictionary = MIGRATION.prepare_document(old)
	assert_true(migrated.get("ok", false), str(migrated))
	if not migrated.get("ok", false): return
	assert_eq(migrated.value.schema_version, SCHEMA.SCHEMA_VERSION)
	assert_eq(migrated.value.get("pair_form_witness_receipts"), {})
	assert_eq(migrated.value.gallery_unlocks, old.gallery_unlocks)

func test_only_presented_forms_are_persisted_once_and_conflicts_do_not_overwrite() -> void:
	var storage := STORAGE.new("profile-pair-form", OPS.new())
	var manager := _manager(storage)
	if not manager.has_method("record_pair_form_witness"):
		fail_test("Profile needs an explicit presentation-only pair witness seam")
		return
	assert_eq(manager.get_pair_form_witnesses().value, [])
	assert_true(manager.record_pair_form_witness("love_dark", "presented-pair-event-1").ok)
	var revision: int = manager.get_profile_revision()
	assert_true(manager.record_pair_form_witness("love_dark", "presented-pair-event-1").ok)
	assert_eq(manager.get_profile_revision(), revision)
	assert_false(manager.record_pair_form_witness("love_sweet", "presented-pair-event-1").ok)
	assert_false(manager.record_pair_form_witness("unknown", "event-2").ok)
	var reloaded := _manager(storage)
	assert_eq(reloaded.get_pair_form_witnesses().value, ["love_dark"])
	assert_eq(reloaded.get_profile_snapshot().pair_form_witness_receipts,
		{"presented-pair-event-1": "love_dark"})

func test_pair_witness_ledger_rejects_unknown_forms_and_empty_receipt_ids() -> void:
	var candidate: Dictionary = SCHEMA.make_defaults()
	candidate["pair_form_witness_receipts"] = {"": "love_dark"}
	assert_false(SCHEMA.validate(candidate).ok)
	candidate.pair_form_witness_receipts = {"event": "invented"}
	assert_false(SCHEMA.validate(candidate).ok)
