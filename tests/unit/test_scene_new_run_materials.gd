extends "res://addons/gut/test.gd"

const MATERIALS := preload("res://scripts/infrastructure/save/NewRunMaterials.gd")
const PROFILE := preload("res://scripts/profile/ProfileSchema.gd")
const PROFILE_OWNER := preload("res://autoload/ProfileManager.gd")
const DRAW := preload("res://scripts/domain/relationship/PairDeckDraw.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

## Narrow failure diagnostics. The deliberately absent Autosave must never pass
## full material admission; connected Save9 success is covered by real producers.
func _fixture() -> Dictionary:
	var allocation := _make_allocation_candidate()
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
	fixture.context["dark_mode"] = false
	assert_true(preload("res://scripts/domain/run/RunSnapshotSchema.gd").validate_primitive_tree(fixture.context).ok,
		"the legacy-selector case must reach the context-member check")
	assert_eq(_validate(fixture).code, &"new_run_materials_invalid")
	fixture.context.erase("dark_mode")
	fixture.context.dialogic_checkpoint = {}
	assert_eq(_validate(fixture).code, &"new_run_materials_invalid")
	fixture.context.route_id = "main"
	assert_false(_validate(fixture).ok)

static func _make_allocation_candidate() -> Dictionary:
	var namespace_value: String = "4".repeat(64)
	var transaction_receipt: Dictionary = _receipt(namespace_value, 0, "transaction_id", null)
	var run_receipt: Dictionary = _receipt(namespace_value, 1, "run_id", null)
	var branch_receipt: Dictionary = _receipt(namespace_value, 2, "branch_id", null)
	var generation_receipt: Dictionary = _receipt(namespace_value, 3, "desktop_timeline_generation", 0)
	var causal_receipt: Dictionary = _receipt(namespace_value, 4, "causal_day_instance", null)
	return {
		"schema_version": 1,
		"kind": "new_run",
		"request": {
			"existing_run_id": null,
			"kind": "new_run",
			"remap_source_transaction_ids": [],
			"source_desktop_timeline_generation": null,
			"transaction_id": transaction_receipt["token"],
			"transaction_issuer_receipt": transaction_receipt,
		},
		"root_namespace": namespace_value,
		"root_next_counter": 1,
		"run_id": run_receipt["token"],
		"run_id_issuer_receipt": run_receipt,
		"branch_id": branch_receipt["token"],
		"branch_id_issuer_receipt": branch_receipt,
		"desktop_timeline_generation": 0,
		"desktop_timeline_generation_issuer_receipt": generation_receipt,
		"causal_day_instance": causal_receipt["token"],
		"causal_day_instance_issuer_receipt": causal_receipt,
		"remap_transaction_issuer_receipts": {},
		"transaction_remap": {},
	}


static func _receipt(namespace_value: String, counter: int, purpose: String,
		numeric_value: Variant) -> Dictionary:
	var token: String = "%s.%s" % [purpose,
		_sha256_text("%s\n%d\n%s" % [namespace_value, counter, purpose])]
	return {
		"counter": counter,
		"namespace": namespace_value,
		"numeric_value": numeric_value,
		"purpose": purpose,
		"receipt_id": "issuer_receipt." + _sha256_text(
			"desktop_issuer_receipt_v1\n%s\n%d\n%s\n%s" % [namespace_value, counter, purpose, token]),
		"token": token,
	}


static func _sha256_text(text: String) -> String:
	return text.sha256_text()
