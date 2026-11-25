extends "res://addons/gut/test.gd"

const SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")

func _manager(storage: Object) -> Node:
	var manager := MANAGER.new()
	autofree(manager)
	assert_true(manager.initialize(storage).ok)
	return manager


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
