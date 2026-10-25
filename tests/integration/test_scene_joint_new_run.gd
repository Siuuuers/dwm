extends "res://addons/gut/test.gd"
## Joint creation uses actual filesystem/issuer/Profile/Run/SaveManager owners.
## Activation is deliberately injected through diagnostic participants. This is
## not rendered E2E and does not establish a fresh-process connected Load.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const SAVE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
var fixture: RefCounted
var fixture_ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	var setup: Dictionary = fixture.setup(get_tree())
	assert_true(setup.get("ok", false), str(setup))
	fixture_ready = setup.get("ok", false)

func after_all() -> void:
	if fixture != null: fixture.close()

func test_joint_creation_persists_exact_material_before_activation_and_alternates_after_ack() -> void:
	assert_true(fixture_ready, "joint filesystem fixture must initialize")
	if not fixture_ready: return
	var prior_draw_count: int = fixture.profile.get_profile_snapshot().pair_deck_draws.size()
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	var transaction: String = started.transaction_id
	var operation: Dictionary = fixture.manager._continuation_journal.get_operation(transaction)
	assert_true(operation.ok, str(operation))
	if not operation.ok: return
	var retained: Dictionary = operation.value
	assert_eq(retained.kind, "scene_new_run")
	assert_eq(retained.stage, JOURNAL.STAGE_COMPLETED)
	assert_eq(retained.activation_state, "pending")
	assert_eq(retained.next_participant_index, 8)
	assert_eq(retained.new_run_materials.allocation_candidate.request.transaction_id, transaction)
	var first: Dictionary = fixture.read_autosave()
	assert_true(first.ok, str(first))
	if not first.ok: return
	var document: Dictionary = first.value
	var snapshot: Dictionary = document.current_snapshot.snapshot
	assert_eq(snapshot.schema_version, 9)
	assert_eq(snapshot.checkpoint_sequence, 1)
	assert_eq(snapshot.scene.active_occurrence_id, transaction)
	assert_false(snapshot.has("command_receipts"), "creation stores current facts, no historical admission")
	assert_eq(snapshot.scene.entry_id, "scene.test.b")
	assert_true(snapshot.scene.active_challenge.is_empty())
	assert_null(snapshot.scene.return_to)
	assert_eq(retained.new_run_materials.autosave.outgoing_text, WRITER.stringify(document).value + "\n")
	assert_false(fixture.manager.capture_committed_scene_creation(transaction).ok,
		"durable pending completion grants no public creation authority")
	assert_true(SAVE.validate(document).ok, "complete current state admits independently of unpublished activation")
	var reopened: Dictionary = fixture.reopen_journal()
	assert_true(reopened.ok, str(reopened))
	if not reopened.ok: return
	var disk_operation: Dictionary = reopened.value.get_operation(transaction)
	assert_true(disk_operation.ok, str(disk_operation))
	assert_eq(disk_operation.value, retained, "fresh journal reads exact immutable retry materials")
	var disk_profile: Dictionary = fixture.reload_profile()
	assert_true(disk_profile.ok, str(disk_profile))
	if not disk_profile.ok: return
	assert_eq(disk_profile.value.pair_deck_draws[snapshot.run_id], snapshot.lifecycle.scene_assignment)
	assert_eq(fixture.participants.route.publications, 0)
	assert_eq(fixture.participants.narrative.publications, 0)
	fixture.confirm_activation()
	var acknowledged: Dictionary = fixture.manager._continuation_journal.get_operation(transaction)
	assert_eq(acknowledged.value.activation_state, "acknowledged")
	assert_true(fixture.manager.capture_committed_scene_creation(transaction).ok)
	# Cold Bootstrap binds Profile storage before initialize/adoption. Historical
	# journal admission must still prove the actual persisted assignment then.
	var boot_profile: Node = PROFILE.new()
	var boot_bound: Dictionary = boot_profile.configure_new_run_storage(fixture.storage)
	assert_true(boot_bound.ok, str(boot_bound))
	var boot_proof: Dictionary = boot_profile.prove_scene_assignment(snapshot.run_id, snapshot.lifecycle.scene_assignment)
	assert_true(boot_proof.ok, str(boot_proof))
	var wrong_assignment: Dictionary = snapshot.lifecycle.scene_assignment.duplicate(true)
	wrong_assignment.creation_transaction_id = "TEST.wrong.creation"
	assert_false(boot_profile.prove_scene_assignment(snapshot.run_id, wrong_assignment).ok,
		"physical proof before adoption still rejects another creation")
	boot_profile.free()
	var validated: Dictionary = SAVE.validate(document)
	assert_true(validated.ok, str(validated))
	assert_eq(fixture.participants.route.publications, 1)
	assert_eq(fixture.participants.narrative.publications, 1)
	fixture.participants.narrative.confirm()
	assert_eq(fixture.participants.narrative.publications, 1, "duplicate confirmation cannot republish")
	var second: Dictionary = fixture.start()
	assert_eq(second.get("code"), &"scene_activation_pending", str(second))
	if second.get("code") != &"scene_activation_pending": return
	var next_document: Dictionary = fixture.read_autosave()
	assert_true(next_document.ok, str(next_document))
	if not next_document.ok: return
	var next_snapshot: Dictionary = next_document.value.current_snapshot.snapshot
	assert_ne(next_snapshot.run_id, snapshot.run_id)
	assert_ne(next_snapshot.lifecycle.scene_assignment.form, snapshot.lifecycle.scene_assignment.form)
	assert_eq(next_snapshot.lifecycle.scene_assignment.selection_kind, "alternate")
	assert_eq(next_snapshot.lifecycle.scene_assignment.predecessor_run_id, snapshot.run_id)
	assert_eq(next_snapshot.lifecycle.scene_assignment.creation_transaction_id, second.transaction_id)
	fixture.confirm_activation()
	assert_true(SAVE.validate(next_document.value).ok)
	var historical: Dictionary = SAVE.validate(document)
	assert_true(historical.ok, "later Profile assignment must preserve prior creation authority: " + str(historical))
	var final_profile: Dictionary = fixture.reload_profile()
	assert_true(final_profile.ok, str(final_profile))
	assert_eq(final_profile.value.pair_deck_draws.size(), prior_draw_count + 2)
	assert_eq(final_profile.value.pair_deck_draws[snapshot.run_id], snapshot.lifecycle.scene_assignment,
		"later creation preserves the original assignment exactly")

func test_rebuilt_other_initial_target_is_valid_preparation_but_not_committed_authority() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	var original: Dictionary = fixture.read_autosave()
	assert_true(original.ok, str(original))
	if not original.ok: return
	var transaction: String = started.transaction_id
	var proof: Dictionary = fixture.manager.capture_committed_scene_creation(transaction)
	assert_true(proof.ok, str(proof))
	if not proof.ok: return
	if OS.get_environment("DWM_SAVE_PARSE_CACHE_DISABLED") != "1":
		var retained_text: String = proof.value.operation.new_run_materials.autosave.outgoing_text
		var retained_parse := false
		for entry: Dictionary in fixture.manager._document_parse_cache:
			if entry.text == retained_text: retained_parse = true
		assert_true(retained_parse, "committed creation shares the existing strict document parser")
	var bundle: Dictionary = MANIFEST.scene_registration().value
	var allocation: Dictionary = proof.value.allocation_candidate
	var material: Dictionary = proof.value.profile_material
	var before: Dictionary = _observed_state(transaction)
	var rebuilt: Dictionary = CONTRACT.prepare_scene_initial_admission(allocation, material, "target_a", bundle, fixture.issuer)
	assert_true(rebuilt.ok, str(rebuilt))
	if not rebuilt.ok: return
	var receipt: Dictionary = rebuilt.value
	assert_ne(receipt.scene_admission.result.entry_id, proof.value.initial_scene.entry_id)
	assert_true(CONTRACT.validate_scene_initial_admission_candidate(receipt, allocation, material, bundle, fixture.issuer).ok)
	var checkpoint: Dictionary = BRIDGE.build_scene_initial_checkpoint(receipt, bundle)
	assert_true(checkpoint.ok, str(checkpoint))
	if not checkpoint.ok: return
	var input: Dictionary = fixture.game.prepare_scene_new_run_snapshot_input(allocation, material, receipt, bundle)
	assert_true(input.ok, str(input))
	if not input.ok: return
	var candidate: Dictionary = RUN.build_scene_new_run_candidate(input.value.snapshot_input, checkpoint.value, {},
		checkpoint.value.content_version, allocation, material, bundle, fixture.issuer)
	assert_true(candidate.ok, str(candidate))
	if not candidate.ok: return
	var substituted: Dictionary = original.value.duplicate(true)
	substituted.current_snapshot.snapshot = candidate.value.snapshot
	assert_true(SAVE.validate_scene_new_run_candidate(substituted, allocation, material, bundle, fixture.issuer).ok,
		"the alternative has a correctly rebuilt first reading/frame, not a stale target edit")
	assert_true(RUN.validate(candidate.value.snapshot).ok,
		"ordinary player admission accepts coherent current state without historical first-target proof")
	assert_true(SAVE.validate(substituted).ok)
	assert_eq(_observed_state(transaction), before, "validation does not select or write alternative bytes")
	assert_true(SAVE.validate(original.value).ok)
	# Diagnostic creation material remains exact and detached; it does not govern later player state.
	proof.value.initial_scene = candidate.value.snapshot.scene.duplicate(true)
	assert_ne(fixture.manager.capture_committed_scene_creation(transaction).value.initial_scene, candidate.value.snapshot.scene)

func test_committed_receipt_survives_evolved_checkpoint_and_unrelated_profile_write() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	var original: Dictionary = fixture.read_autosave()
	assert_true(original.ok, str(original))
	if not original.ok: return
	var document: Dictionary = original.value.duplicate(true)
	var snapshot: Dictionary = document.current_snapshot.snapshot
	snapshot.checkpoint_sequence = 2
	snapshot.checkpoint_id = snapshot.run_id + ":2"
	snapshot.gameplay.money = 17
	document.current_snapshot.checkpoint_kind = "safe_marker"
	var evolved: Dictionary = SAVE.validate(document)
	assert_true(evolved.ok, "only the immutable receipt must match creation: " + str(evolved))
	var preference: Dictionary = fixture.profile.set_preference(&"preferences.audio.master_volume", 0.5)
	assert_true(preference.ok, str(preference))
	if not preference.ok: return
	var before: Dictionary = _observed_state(started.transaction_id)
	var historical: Dictionary = SAVE.validate(document)
	assert_true(historical.ok, "unrelated later Profile bytes preserve creation authority: " + str(historical))
	assert_eq(_observed_state(started.transaction_id), before)

func test_initial_receipt_rechecks_registration_and_physical_profile_after_success() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	var proof: Dictionary = fixture.manager.capture_committed_scene_creation(started.transaction_id)
	assert_true(proof.ok, str(proof))
	if not proof.ok: return
	var current: Dictionary = fixture.read_autosave().value.current_snapshot.snapshot
	var bundle: Dictionary = MANIFEST.scene_registration().value
	assert_true(RUN.validate_scene(current, bundle).ok)
	proof.value.initial_scene.entry_id = "TEST.changed"
	assert_ne(fixture.manager.capture_committed_scene_creation(started.transaction_id).value.initial_scene.entry_id, "TEST.changed")
	var changed: Dictionary = bundle.duplicate(true)
	changed.caption_registry.TEST = "changed registration"
	assert_false(RUN.validate_scene(current, changed).ok, "current state cannot select a changed programme")
	assert_true(RUN.validate(current).ok)
	# Damage only this isolated fixture's physical file, then restore exact bytes.
	# The in-memory Profile remains valid, exposing accidental proof caching.
	var path: String = fixture.storage.describe_root().path_join("profile.json")
	var original: PackedByteArray = FileAccess.get_file_as_bytes(path)
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null: return
	file.store_string("{}")
	file.close()
	var refused: Dictionary = fixture.manager.capture_committed_scene_creation(started.transaction_id)
	file = FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null: return
	file.store_buffer(original)
	file.close()
	assert_false(refused.ok, "diagnostic creation proof still checks physical Profile material")
	assert_true(fixture.manager.capture_committed_scene_creation(started.transaction_id).ok,
		"restoring the actual proof permits validation again")

func test_schema_without_creation_owner_cannot_borrow_semantic_creation_authority() -> void:
	assert_true(fixture_ready)
	if not fixture_ready: return
	var started: Dictionary = fixture.start()
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	fixture.confirm_activation()
	var original: Dictionary = fixture.read_autosave()
	assert_true(original.ok, str(original))
	if not original.ok: return
	var snapshot: Dictionary = original.value.current_snapshot.snapshot
	var before: Dictionary = _observed_state(started.transaction_id)
	assert_true(RUN._scene_semantic_authenticates_receipts(), "fixture uses configured live owners")
	assert_true(RUN.validate(snapshot).ok)
	var owner: Object = RUN._scene_creation_owner
	RUN._scene_creation_owner = null
	var matched: bool = RUN._scene_semantic_authenticates_receipts()
	var refused_run: Dictionary = RUN.validate(snapshot)
	var refused_save: Dictionary = SAVE.validate(original.value)
	RUN._scene_creation_owner = owner
	assert_false(matched, "schema and semantic creation owners must be identical")
	assert_true(refused_run.ok, "player admission does not depend on historical creation owner")
	assert_true(refused_save.ok, "current state and Profile assignment remain sufficient")
	assert_true(RUN.validate(snapshot).ok, "restoring the bound owner restores admission")
	assert_eq(_observed_state(started.transaction_id), before)

func _observed_state(transaction: String) -> Dictionary:
	return {"game": fixture.game.capture_restore_state(), "profile": fixture.profile.get_profile_snapshot(),
		"profile_revision": fixture.profile.get_profile_revision(), "root": fixture.issuer.capture_root(),
		"operation": fixture.manager._continuation_journal.get_operation(transaction),
		"autosave_bytes": fixture.storage.read_text("autosave.json"), "profile_bytes": fixture.storage.read_text("profile.json"),
		"route_publications": fixture.participants.route.publications,
		"narrative_publications": fixture.participants.narrative.publications}
