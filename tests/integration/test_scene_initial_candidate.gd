extends "res://addons/gut/test.gd"
## Detached full candidate evidence with real FileOps/Profile/issuer and compiled reading.
## No live creation or connected Load claim.
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
const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const MATERIALS := preload("res://scripts/infrastructure/save/NewRunMaterials.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const GAME := preload("res://autoload/GameState.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
var document: Dictionary
var context: Dictionary
var materials: Dictionary
var issuer: RefCounted
var allocation: Dictionary
var material: Dictionary
var bundle: Dictionary
var receipt: Dictionary

func before_all() -> void:
	assert_true(FIXTURE.install_registration().ok)

func _prepare(nonce: int = 0) -> bool:
	var temporary: Dictionary = TEMP.create("scene_initial_candidate")
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
	result = BRIDGE.build_scene_initial_checkpoint(receipt, bundle)
	assert_true(result.ok, str(result))
	if not result.ok: return false
	var checkpoint: Dictionary = result.value
	var game: Node = GAME.new()
	result = game.configure_identity_issuer(issuer)
	if result.ok: result = game.prepare_scene_new_run_snapshot_input(allocation, material, receipt, bundle)
	game.free()
	assert_true(result.ok, str(result))
	if not result.ok: return false
	result = RUN.build_scene_new_run_candidate(result.value.snapshot_input, checkpoint, {},
		checkpoint.content_version, allocation, material, bundle, issuer)
	assert_true(result.ok, str(result))
	if not result.ok: return false
	document = {"schema_version": 9, "kind": "autosave", "slot_id": null,
		"save_reason": "day_start", "saved_time": {"unix_seconds": 0, "utc_offset_minutes": 0, "hhmm": "00:00"},
		"current_snapshot": {"checkpoint_kind": "day_start", "snapshot": result.value.snapshot}, "recovery_journal": []}
	context = {"active_app_id": null, "audio_context": {}, "content_version": checkpoint.content_version,
		"dialogic_checkpoint": checkpoint, "route_id": "scene"}
	var text: String = str(WRITER.stringify(document).value) + "\n"
	materials = {"allocation_candidate": allocation, "profile": material,
		"autosave": {"source_revision": "absent", "outgoing_text": text, "outgoing_hash": text.sha256_text()}}
	return true

func _validate(value: Dictionary) -> Dictionary:
	return SAVE.validate_scene_new_run_candidate(value, allocation, material, bundle, issuer)

func test_complete_initial_candidate_is_read_only_and_not_committed_authority() -> void:
	for nonce: int in [0, 1]:
		if not _prepare(nonce): return
		var root_before: Dictionary = issuer.capture_root()
		var original: Dictionary = document.duplicate(true)
		assert_true(_validate(document).ok)
		assert_true(MATERIALS.validate(materials, context, receipt.transaction_id,
			str(WRITER.stringify(allocation).value).sha256_text(), bundle, issuer).ok)
		assert_eq(document, original)
		assert_eq(issuer.capture_root(), root_before)
		assert_true(root_before.value.allocation_receipts.is_empty())
		assert_false(SAVE.validate(document).ok, "prepared candidate must not admit ordinary Load")
		assert_eq(document.current_snapshot.snapshot.lifecycle.scene_assignment.form, "sweet" if nonce == 0 else "dark")

func test_initial_candidate_refuses_prior_state_and_forged_first_reading() -> void:
	if not _prepare(): return
	var changed: Dictionary = document.duplicate(true)
	changed.current_snapshot.snapshot.gameplay.money = 1
	assert_false(_validate(changed).ok)
	changed = document.duplicate(true)
	changed.current_snapshot.snapshot.applied_effect_transaction_ids.append("TEST.prior.effect")
	assert_false(_validate(changed).ok)
	changed = document.duplicate(true)
	changed.current_snapshot.snapshot.checkpoint_sequence = 2
	changed.current_snapshot.snapshot.checkpoint_id = allocation.run_id + ":2"
	assert_false(_validate(changed).ok)
	changed = document.duplicate(true)
	changed.recovery_journal.append(document.current_snapshot.duplicate(true))
	assert_false(_validate(changed).ok)
	changed = document.duplicate(true)
	changed.current_snapshot.snapshot.narrative_checkpoint.frozen_context.transaction_id = "TEST.foreign"
	assert_false(_validate(changed).ok)
	changed = document.duplicate(true)
	changed.current_snapshot.snapshot.narrative_checkpoint.reading_session.ledger.captions.append(
		changed.current_snapshot.snapshot.narrative_checkpoint.reading_session.ledger.captions[0].duplicate(true))
	assert_false(_validate(changed).ok)

func test_raw_initial_receipt_and_save_header_float_types_are_refused_before_normalization() -> void:
	if not _prepare(): return
	var changed: Dictionary = document.duplicate(true)
	changed.current_snapshot.snapshot.command_receipts[receipt.transaction_id].scene_admission.schema_version = 3.0
	assert_false(_validate(changed).ok)
	assert_eq(SAVE.validate(changed).code, &"scene_initial_types_invalid")
	assert_eq(RUN.validate(changed.current_snapshot.snapshot).code, &"scene_initial_types_invalid")
	changed = document.duplicate(true)
	changed.schema_version = 9.0
	assert_false(_validate(changed).ok)
	assert_eq(SAVE.validate(changed).code, &"scene_initial_types_invalid")
	changed = document.duplicate(true)
	changed.current_snapshot.snapshot.lifecycle.desktop_timeline_generation = 0.0
	assert_false(_validate(changed).ok)
	assert_eq(SAVE.validate(changed).code, &"scene_initial_types_invalid")
	changed = document.duplicate(true)
	changed.current_snapshot.snapshot.command_receipts[receipt.transaction_id].scene_admission.provenance.ordinal = 0.0
	assert_eq(SAVE.validate(changed).code, &"scene_initial_types_invalid")
	var raw_context: Dictionary = context.duplicate(true)
	raw_context.dialogic_checkpoint.content_version = float(raw_context.dialogic_checkpoint.content_version)
	assert_false(MATERIALS.validate(materials, raw_context, receipt.transaction_id,
		str(WRITER.stringify(allocation).value).sha256_text(), bundle, issuer).ok)

func test_candidate_requires_installed_registration_and_complete_profile_material() -> void:
	if not _prepare(): return
	var changed_bundle: Dictionary = bundle.duplicate(true)
	changed_bundle["uninstalled_member"] = true
	assert_false(SAVE.validate_scene_new_run_candidate(document, allocation, material, changed_bundle, issuer).ok)
	var changed_profile: Dictionary = material.duplicate(true)
	changed_profile.erase("before")
	assert_false(SAVE.validate_scene_new_run_candidate(document, allocation, changed_profile, bundle, issuer).ok)
	var changed: Dictionary = document.duplicate(true)
	changed.current_snapshot.snapshot.lifecycle.run_id = "TEST.foreign.run"
	assert_false(_validate(changed).ok)
	changed = document.duplicate(true)
	changed.current_snapshot.snapshot.contacts.next_sequence = 2
	assert_false(_validate(changed).ok)
