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
const TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")
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
		"saved_time": {"unix_seconds": 0, "utc_offset_minutes": 0, "hhmm": "00:00"},
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

func test_initial_candidate_ignores_retired_reason_but_preserves_exact_write_material() -> void:
	if not _prepare(): return
	for retired: Variant in ["day_start", "obsolete", 7, null, {"old": true}]:
		var input: Dictionary = document.duplicate(true)
		input["save_reason"] = retired
		input.current_snapshot.snapshot["audio_context"] = retired
		input.current_snapshot.snapshot["active_app_id"] = retired
		var admitted := _validate(input)
		assert_true(admitted.ok, str(admitted))
		if admitted.ok: assert_eq(admitted.value.candidate, document)
		var retained: Dictionary = materials.duplicate(true)
		retained.autosave.outgoing_text = WRITER.stringify(input).value + "\n"
		retained.autosave.outgoing_hash = retained.autosave.outgoing_text.sha256_text()
		assert_true(MATERIALS.validate(retained, context, receipt.transaction_id,
			str(WRITER.stringify(allocation).value).sha256_text(), bundle, issuer).ok)


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
	changed.current_snapshot.snapshot.narrative_checkpoint.reading_session.captions.append(
		changed.current_snapshot.snapshot.narrative_checkpoint.reading_session.captions[0].duplicate(true))
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

func test_initial_validation_preserves_canonical_input_and_prepared_position() -> void:
	if not _prepare(): return
	var original: Dictionary = document.duplicate(true)
	var previous_profile := OS.get_environment("DWM_SCENE_VALIDATION_PROFILE")
	OS.set_environment("DWM_SCENE_VALIDATION_PROFILE", "1")
	var started := TIMING.begin_scope("initial_candidate_configuration", "PLAYING", "", 0)
	assert_true(started)
	if not started:
		OS.set_environment("DWM_SCENE_VALIDATION_PROFILE", previous_profile)
		return
	var checked := _validate(document)
	var observation: Dictionary = TIMING._record.duplicate(true)
	TIMING.end_scope(checked.ok)
	OS.set_environment("DWM_SCENE_VALIDATION_PROFILE", previous_profile)
	assert_true(checked.ok, str(checked))
	assert_gt(observation.configuration_calls, 0, "candidate position is checked against the installed programme")
	if not checked.ok: return
	assert_eq(checked.value.candidate, original, "candidate canonical contents remain exact")
	assert_eq(WRITER.stringify(checked.value.candidate).value, WRITER.stringify(original).value,
		"canonical candidate bytes remain exact")
	assert_eq(document, original, "validation cannot modify its saved input")

func test_restorable_foreign_first_publication_is_not_used_as_initial_expected_ledger() -> void:
	if not _prepare(): return
	var changed: Dictionary = document.duplicate(true)
	var checkpoint: Dictionary = changed.current_snapshot.snapshot.narrative_checkpoint
	checkpoint.reading_session.captions[0].publication_id = "caption:999"
	checkpoint.reading_session.publication_serial = 999
	var reading: Dictionary = RUN._validate_scene_reading(changed.current_snapshot.snapshot)
	assert_true(reading.ok, "ordinary reading allows a retained publication identity: " + str(reading))
	if not reading.ok: return
	var prior_ledger: Dictionary = reading.session.ledger.snapshot()
	var independent: Dictionary = BRIDGE._build_scene_initial_checkpoint(receipt, bundle, reading.session)
	assert_true(independent.ok, str(independent))
	if not independent.ok: return
	assert_eq(independent.value, context.dialogic_checkpoint, "expected first publication is built independently")
	assert_eq(reading.session.ledger.snapshot(), prior_ledger, "reconstruction does not reset the restored ledger")
	var checked := _validate(changed)
	assert_false(checked.ok)
	assert_eq(checked.get("code"), &"scene_initial_state_invalid")
	assert_eq(checked.get("message"), "initial checkpoint must be the registered target's exact first caption")
	assert_true(_validate(document).ok, "failed reconstruction does not contaminate another call")

func test_configuration_fork_keeps_fresh_mutable_session_state() -> void:
	if not _prepare(): return
	var reading: Dictionary = RUN._validate_scene_reading(document.current_snapshot.snapshot)
	assert_true(reading.ok, str(reading))
	if not reading.ok: return
	var sibling: RefCounted = reading.session._fork_scene_configuration()
	assert_null(sibling.ledger)
	assert_eq(sibling.command_id, "")
	assert_eq(sibling.latest_entry, "")
	assert_eq(sibling.scene_occurrence, "")
	assert_eq(sibling.scene_index, 0)
	assert_eq(sibling.boundary, "between_entries")
	assert_true(sibling.next_operation.is_empty())
	assert_true(sibling.catalogue.is_read_only())
	assert_true(sibling.registry.is_read_only())
	assert_true(sibling._scene_nodes.is_read_only())
	sibling.manifest.clear()
	sibling._caption_variants_by_line.clear()
	assert_false(reading.session.manifest.is_empty(), "mutable manifest belongs to each session")
	assert_false(reading.session._caption_variants_by_line.is_empty(), "mutable lookup belongs to each session")
	assert_true(BRIDGE.build_scene_initial_checkpoint(receipt, bundle).ok, "private fork cannot change public reconstruction")

func test_next_public_build_and_candidate_validation_recheck_physical_content() -> void:
	if not _prepare(): return
	var source_path := ""
	for entry: Dictionary in bundle.entry_manifest.entries:
		if entry.entry_id == receipt.scene_admission.result.entry_id: source_path = entry.locators.en.path
	assert_false(source_path.is_empty())
	if source_path.is_empty(): return
	var original := FileAccess.get_file_as_string(source_path)
	var source := FileAccess.open(source_path, FileAccess.WRITE)
	assert_not_null(source)
	if source == null: return
	source.store_string(original + "\n")
	source.close()
	# A trailing empty line preserves the programme but changes its physical hash.
	# Both public entries must still configure and compare current source bytes.
	var rebuilt: Dictionary = BRIDGE.build_scene_initial_checkpoint(receipt, bundle)
	var checked := _validate(document)
	source = FileAccess.open(source_path, FileAccess.WRITE)
	assert_not_null(source)
	if source == null: return
	source.store_string(original)
	source.close()
	assert_false(rebuilt.ok)
	assert_eq(rebuilt.get("code"), &"reading_catalogue_mismatch")
	assert_false(checked.ok)
	assert_eq(checked.get("code"), &"reading_catalogue_mismatch")
	var restored: Dictionary = BRIDGE.build_scene_initial_checkpoint(receipt, bundle)
	assert_true(restored.ok, str(restored))
	if restored.ok: assert_eq(restored.value, context.dialogic_checkpoint)
	assert_true(_validate(document).ok, "restoring source bytes permits a new fresh validation")

func test_foreign_current_frame_is_refused_before_initial_admission() -> void:
	if not _prepare(): return
	var changed: Dictionary = document.duplicate(true)
	changed.current_snapshot.snapshot.narrative_checkpoint.frozen_context.transaction_id = "TEST.foreign.saved.frame"
	var reading: Dictionary = RUN._validate_scene_reading(changed.current_snapshot.snapshot)
	assert_false(reading.ok, "compact position must agree with its current frame")
	assert_false(_validate(changed).ok)
	assert_true(_validate(document).ok)
