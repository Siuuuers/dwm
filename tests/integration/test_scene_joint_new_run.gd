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
	var admission: Dictionary = snapshot.command_receipts[transaction]
	assert_eq(snapshot.schema_version, 9)
	assert_eq(snapshot.checkpoint_sequence, 1)
	assert_eq(snapshot.scene.active_occurrence_id, transaction)
	assert_eq(admission.scene_admission.schema_version, 3)
	assert_eq(admission.scene_admission.result.kind, "scene_initial_admitted")
	assert_false(admission.scene_admission.result.has("source_checkpoint"), "creation must not invent a predecessor")
	assert_eq(retained.new_run_materials.autosave.outgoing_text, WRITER.stringify(document).value + "\n")
	assert_false(fixture.manager.capture_committed_scene_creation(transaction).ok,
		"durable pending completion grants no public creation authority")
	assert_false(SAVE.validate(document).ok, "candidate bytes alone cannot become a committed Save")
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
	var bundle: Dictionary = MANIFEST.scene_registration().value
	var allocation: Dictionary = proof.value.allocation_candidate
	var material: Dictionary = proof.value.profile_material
	var before: Dictionary = _observed_state(transaction)
	var rebuilt: Dictionary = CONTRACT.prepare_scene_initial_admission(allocation, material, "target_a", bundle, fixture.issuer)
	assert_true(rebuilt.ok, str(rebuilt))
	if not rebuilt.ok: return
	var receipt: Dictionary = rebuilt.value
	assert_ne(receipt, proof.value.initial_receipt)
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
	var direct: Dictionary = CONTRACT.validate_scene_receipts({transaction: receipt}, bundle, fixture.issuer, fixture.manager)
	assert_eq(direct.get("code"), &"scene_initial_committed_receipt_mismatch", str(direct))
	var run_result: Dictionary = RUN.validate(candidate.value.snapshot)
	assert_eq(run_result.get("code"), &"scene_initial_committed_receipt_mismatch", str(run_result))
	var save_result: Dictionary = SAVE.validate(substituted)
	assert_eq(save_result.get("code"), &"scene_initial_committed_receipt_mismatch", str(save_result))
	assert_eq(_observed_state(transaction), before, "reconstruction and refusal preserve physical and live owners")
	assert_true(SAVE.validate(original.value).ok, "the actual committed initial scene remains admitted")
	# Returned proof is detached; mutating it cannot rewrite the committed choice.
	proof.value.initial_receipt = receipt
	assert_ne(fixture.manager.capture_committed_scene_creation(transaction).value.initial_receipt, receipt)

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
	document.save_reason = "automatic"
	var evolved: Dictionary = SAVE.validate(document)
	assert_true(evolved.ok, "only the immutable receipt must match creation: " + str(evolved))
	var preference: Dictionary = fixture.profile.set_preference(&"preferences.audio.master_volume", 0.5)
	assert_true(preference.ok, str(preference))
	if not preference.ok: return
	var before: Dictionary = _observed_state(started.transaction_id)
	var historical: Dictionary = SAVE.validate(document)
	assert_true(historical.ok, "unrelated later Profile bytes preserve creation authority: " + str(historical))
	assert_eq(_observed_state(started.transaction_id), before)

func _observed_state(transaction: String) -> Dictionary:
	return {"game": fixture.game.capture_restore_state(), "profile": fixture.profile.get_profile_snapshot(),
		"profile_revision": fixture.profile.get_profile_revision(), "root": fixture.issuer.capture_root(),
		"operation": fixture.manager._continuation_journal.get_operation(transaction),
		"autosave_bytes": fixture.storage.read_text("autosave.json"), "profile_bytes": fixture.storage.read_text("profile.json"),
		"route_publications": fixture.participants.route.publications,
		"narrative_publications": fixture.participants.narrative.publications}
