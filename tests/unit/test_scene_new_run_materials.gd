extends "res://addons/gut/test.gd"

const MATERIALS := preload("res://scripts/infrastructure/save/NewRunMaterials.gd")
const ALLOCATION_FIXTURE := preload("res://tests/unit/test_new_run_materials.gd")
const PROFILE := preload("res://scripts/profile/ProfileSchema.gd")
const PROFILE_OWNER := preload("res://autoload/ProfileManager.gd")
const DRAW := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## Narrow failure diagnostics. The deliberately absent Autosave must never pass
## full material admission; connected Save9 success is covered by real producers.
func _fixture() -> Dictionary:
	var allocation := ALLOCATION_FIXTURE.make_allocation_candidate()
	var before := PROFILE.make_defaults()
	var receipt: Dictionary = DRAW.prepare_scene_assignment(before.pair_deck_draws,
		allocation.run_id, allocation.request.transaction_id, 0)
	assert_true(receipt.ok)
	var candidate := before.duplicate(true)
	candidate.pair_deck_draws[allocation.run_id] = receipt.value.duplicate(true)
	var output: String = WRITER.stringify(candidate).value
	var profile := {"before": before, "candidate": candidate, "profile_revision": 1,
		"source_revision": str(WRITER.stringify(before).value).sha256_text(),
		"outgoing_text": output, "outgoing_hash": output.sha256_text(),
		"scene_assignment": {"run_id": allocation.run_id, "receipt": receipt.value}}
	assert_true(PROFILE_OWNER.validate_scene_new_run_material(profile).ok)
	return {"materials": {"allocation_candidate": allocation, "profile": profile, "autosave": {}},
		"context": {"route_id": "scene", "active_app_id": null, "audio_context": {},
			"content_version": 1, "dialogic_checkpoint": {"reading_session": {"schema_version": 5}}},
		"transaction_id": allocation.request.transaction_id,
		"fingerprint": str(WRITER.stringify(allocation).value).sha256_text()}

func _validate(fixture: Dictionary) -> Dictionary:
	return MATERIALS.validate(fixture.materials, fixture.context, fixture.transaction_id, fixture.fingerprint)

func test_scene_profile_owner_valid_material_does_not_bypass_actual_save_validation() -> void:
	var fixture := _fixture()
	var checked := _validate(fixture)
	assert_false(checked.ok)
	assert_eq(checked.code, &"new_run_autosave_invalid", "a genuine assignment does not manufacture a valid Save9")

func test_scene_creation_binding_rejects_valid_assignment_for_other_run() -> void:
	var fixture := _fixture()
	var profile: Dictionary = fixture.materials.profile
	var receipt: Dictionary = profile.scene_assignment.receipt
	profile.scene_assignment.run_id = "foreign.run"
	profile.candidate = profile.before.duplicate(true)
	profile.candidate.pair_deck_draws["foreign.run"] = receipt.duplicate(true)
	profile.outgoing_text = WRITER.stringify(profile.candidate).value
	profile.outgoing_hash = profile.outgoing_text.sha256_text()
	assert_true(PROFILE_OWNER.validate_scene_new_run_material(profile).ok)
	var checked := _validate(fixture)
	assert_false(checked.ok)
	assert_eq(checked.code, &"new_run_profile_invalid")

func test_scene_creation_binding_rejects_valid_assignment_for_other_transaction() -> void:
	var fixture := _fixture()
	var profile: Dictionary = fixture.materials.profile
	profile.scene_assignment.receipt.creation_transaction_id = "foreign.creation"
	profile.candidate.pair_deck_draws[profile.scene_assignment.run_id] = profile.scene_assignment.receipt.duplicate(true)
	profile.outgoing_text = WRITER.stringify(profile.candidate).value
	profile.outgoing_hash = profile.outgoing_text.sha256_text()
	assert_true(PROFILE_OWNER.validate_scene_new_run_material(profile).ok)
	var checked := _validate(fixture)
	assert_false(checked.ok)
	assert_eq(checked.code, &"new_run_profile_invalid")

func test_scene_initial_context_cannot_downgrade_or_add_legacy_dark_selector() -> void:
	var fixture := _fixture()
	fixture.context.dark_mode = false
	assert_eq(_validate(fixture).code, &"new_run_materials_invalid")
	fixture.context.erase("dark_mode")
	fixture.context.dialogic_checkpoint = {}
	assert_eq(_validate(fixture).code, &"new_run_materials_invalid")
	fixture.context.route_id = "main"
	assert_false(_validate(fixture).ok)
