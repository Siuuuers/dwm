extends "res://addons/gut/test.gd"
## Contract evidence only: actual issuer/Profile material, no live creation claim.
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const FIXTURE := preload("res://tests/support/SceneContactFixture.gd")
const ROOT := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const NAMESPACE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const FILES := preload("res://scripts/infrastructure/storage/FileOps.gd")
const TEMP := preload("res://tests/support/TemporaryStorage.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
var issuer: RefCounted
var allocation: Dictionary
var material: Dictionary
var bundle: Dictionary
var receipt: Dictionary

func before_all() -> void:
	assert_true(FIXTURE.install_registration().ok)

func _prepare(nonce: int = 0) -> bool:
	var temporary: Dictionary = TEMP.create("scene_initial_contract")
	assert_true(temporary.ok, str(temporary))
	if not temporary.ok: return false
	var storage: RefCounted = STORAGE.new(temporary.value, FILES.new())
	var root: RefCounted = ROOT.new()
	var result: Dictionary = root.configure(storage, NAMESPACE.new("db".repeat(32)))
	if result.ok: result = root.load_or_create()
	assert_true(result.ok, str(result))
	if not result.ok: return false
	issuer = ISSUER.new()
	result = issuer.configure(root)
	assert_true(result.ok, str(result))
	if not result.ok: return false
	var transaction: Dictionary = issuer.issue(&"transaction_id")
	assert_true(transaction.ok, str(transaction))
	if not transaction.ok: return false
	result = issuer.prepare_continuation_allocation({"kind": "new_run", "transaction_id": transaction.value.token,
		"transaction_issuer_receipt": transaction.value.issuer_receipt, "existing_run_id": null,
		"source_desktop_timeline_generation": null, "remap_source_transaction_ids": []})
	assert_true(result.ok, str(result))
	if not result.ok: return false
	allocation = result.value
	var profile: Node = PROFILE.new()
	result = profile.initialize(storage)
	if result.ok: result = profile.configure_new_run_storage(storage)
	if result.ok: result = profile.prepare_scene_new_run_consumption(profile.get_profile_revision(), allocation.run_id,
		transaction.value.token, nonce)
	profile.free()
	assert_true(result.ok, str(result))
	if not result.ok: return false
	material = result.value
	bundle = MANIFEST.scene_registration().value
	result = CONTRACT.prepare_scene_initial_admission(allocation, material, "target_b", bundle, issuer)
	assert_true(result.ok, str(result))
	if not result.ok: return false
	receipt = result.value
	return true

func _validate(changed: Dictionary) -> Dictionary:
	return CONTRACT.validate_scene_initial_admission_candidate(changed, allocation, material, bundle, issuer)

func test_candidate_before_commit_has_one_creation_root_and_no_previous_checkpoint() -> void:
	if not _prepare(): return
	var before: Dictionary = issuer.capture_root()
	assert_true(_validate(receipt).ok)
	assert_eq(receipt.transaction_id, allocation.request.transaction_id)
	assert_eq(receipt.scene_admission.result.kind, "scene_initial_admitted")
	assert_false(receipt.scene_admission.result.has("source_checkpoint"))
	assert_true(before.value.allocation_receipts.is_empty())
	assert_false(CONTRACT.validate_scene_receipts({receipt.transaction_id: receipt}, bundle, issuer).ok,
		"a prepared receipt is not committed creation authority")
	assert_eq(issuer.capture_root(), before, "candidate admission is read-only")
	assert_true(issuer.commit_continuation_allocation(allocation).ok)
	assert_true(_validate(receipt).ok, "same retained candidate validates after allocation commit")
	assert_false(CONTRACT.validate_scene_receipts({receipt.transaction_id: receipt}, bundle, issuer).ok,
		"allocation alone is still not completed joint creation")

func test_both_frozen_initial_forms_bind_the_same_receipt_material_on_revalidation() -> void:
	for nonce: int in [0, 1]:
		if not _prepare(nonce): return
		assert_eq(material.scene_assignment.receipt.form, "sweet" if nonce == 0 else "dark")
		var first: Dictionary = receipt.duplicate(true)
		assert_true(_validate(receipt).ok)
		assert_eq(CONTRACT.prepare_scene_initial_admission(allocation, material, "target_b", bundle, issuer).value, first)
		var changed: Dictionary = material.duplicate(true)
		changed.scene_assignment.receipt.form = "dark" if nonce == 0 else "sweet"
		assert_false(CONTRACT.validate_scene_initial_admission_candidate(receipt, allocation, changed, bundle, issuer).ok)

func test_initial_exact_members_digests_projections_and_types_refuse_tampering() -> void:
	if not _prepare(): return
	for field: String in ["allocation_candidate_sha256", "scene_assignment_sha256", "registration_fingerprint"]:
		var changed: Dictionary = receipt.duplicate(true)
		changed.scene_admission[field] = "e".repeat(64)
		assert_false(_validate(changed).ok, field)
	for field: String in ["source_checkpoint", "trigger_command_id", "return_to"]:
		var changed: Dictionary = receipt.duplicate(true)
		changed.scene_admission.result[field] = null
		assert_false(_validate(changed).ok, field)
	var changed: Dictionary = receipt.duplicate(true)
	changed.scene_admission.schema_version = 3.0
	assert_false(_validate(changed).ok)
	changed = receipt.duplicate(true)
	changed.scene_admission.provenance.source_ids[1] = 'role="scene.admission"'
	assert_false(_validate(changed).ok)
	changed = receipt.duplicate(true)
	changed.scene_admission.result.target_id = "target_a"
	assert_false(_validate(changed).ok)
	changed = allocation.duplicate(true)
	changed.request.transaction_issuer_receipt.counter = float(changed.request.transaction_issuer_receipt.counter)
	assert_false(CONTRACT.prepare_scene_initial_admission(changed, material, "target_b", bundle, issuer).ok)
	changed = allocation.duplicate(true)
	changed.desktop_timeline_generation = 0.0
	assert_false(CONTRACT.prepare_scene_initial_admission(changed, material, "target_b", bundle, issuer).ok)
	changed = allocation.duplicate(true)
	changed.root_next_counter += 1
	assert_false(CONTRACT.prepare_scene_initial_admission(changed, material, "target_b", bundle, issuer).ok)

func test_initial_variant_does_not_relax_schema_two_checkpoint_obligations() -> void:
	if not _prepare(): return
	assert_true(issuer.commit_continuation_allocation(allocation).ok)
	var identity := {}
	for key: String in ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt"]:
		identity[key] = allocation[key]
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.ok, str(issued))
	if not issued.ok: return
	var old: Dictionary = CONTRACT.make_scene_admission(identity, issued.value.issuer_receipt, "target_b",
		{"checkpoint_id": "TEST.prior", "checkpoint_sequence": 1, "snapshot_sha256": "a".repeat(64)},
		null, null, bundle, issuer)
	assert_true(old.ok, str(old))
	if not old.ok: return
	assert_true(CONTRACT.validate_scene_receipts({old.value.transaction_id: old.value}, bundle, issuer).ok)
	var changed: Dictionary = old.value.duplicate(true)
	changed.scene_admission.result.source_checkpoint = null
	assert_false(CONTRACT.validate_scene_receipts({changed.transaction_id: changed}, bundle, issuer).ok)
	changed.scene_admission.result.erase("source_checkpoint")
	assert_false(CONTRACT.validate_scene_receipts({changed.transaction_id: changed}, bundle, issuer).ok)
