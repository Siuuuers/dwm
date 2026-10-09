extends "res://addons/gut/test.gd"
## Joint creation uses actual filesystem/issuer/Profile/Run/SaveManager owners.
## Activation is deliberately injected through diagnostic participants. This is
## not rendered E2E and does not establish a fresh-process connected Load.
const FIXTURE := preload("res://tests/support/SceneNewRunFixture.gd")
const SAVE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const JOURNAL := preload("res://scripts/infrastructure/save/DesktopContinuationOperationJournal.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
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
	var started: Dictionary = fixture.start(0)
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
	var validated: Dictionary = SAVE.validate(document)
	assert_true(validated.ok, str(validated))
	assert_eq(fixture.participants.route.publications, 1)
	assert_eq(fixture.participants.narrative.publications, 1)
	fixture.participants.narrative.confirm()
	assert_eq(fixture.participants.narrative.publications, 1, "duplicate confirmation cannot republish")
	var second: Dictionary = fixture.start(0)
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
	assert_eq(final_profile.value.pair_deck_draws.size(), 2)
	assert_eq(final_profile.value.pair_deck_draws[snapshot.run_id], snapshot.lifecycle.scene_assignment,
		"later creation preserves the original assignment exactly")
