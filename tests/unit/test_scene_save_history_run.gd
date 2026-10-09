extends "res://addons/gut/test.gd"

const RUN := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const SAVE := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const IDENTITY := preload("res://tests/support/SceneTransitionIdentityFixture.gd")
const REGISTRY := preload("res://tests/unit/test_scene_event_contract.gd")

# Real allocated issuer identities and canonical receipt producers. Registry and
# source checkpoint are explicit injected boundaries, as in receipt contract tests.
# Public Run/Save calls below prove their rejection gate, not positive full Run9
# admission, installed DTL, a persisted checkpoint or filesystem Load.
func _receipts() -> Dictionary:
	var owner := IDENTITY.new()
	var initialized: Dictionary = owner.setup()
	assert_true(initialized.ok, str(initialized))
	if not initialized.ok: return {}
	var identity: Dictionary = owner.identity(owner.lifecycle)
	var registry := REGISTRY.new()
	var bundle: Dictionary = registry._scene_bundle()
	var anchor: Dictionary = registry._scene_anchor()
	registry.free()
	var root: Dictionary = owner.issuer.issue(&"transaction_id")
	assert_true(root.ok, str(root))
	if not root.ok: return {}
	var admission: Dictionary = CONTRACT.make_scene_admission(identity, root.value.issuer_receipt,
		"TEST.target", {"checkpoint_id": "TEST.injected-source", "checkpoint_sequence": 1,
		"snapshot_sha256": "a".repeat(64)}, null, null, bundle, owner.issuer)
	assert_true(admission.ok, str(admission))
	if not admission.ok: return {}
	anchor.session_id = root.value.token
	var issued: Dictionary = owner.issuer.issue(&"transaction_id")
	assert_true(issued.ok, str(issued))
	if not issued.ok: return {}
	var event := {"schema_version": 2, "source": {"run_id": identity.run_id,
		"branch_id": identity.branch_id, "causal_day_instance": identity.causal_day_instance,
		"scene_occurrence": root.value.token, "entry_id": "TEST.scene", "content_version": 1},
		"event_id": "TEST.transition", "ordinal": 0, "predecessor": "", "kind": "scene.transition",
		"payload": {"target_id": "TEST.target"}, "command_id": issued.value.token,
		"issuer_receipt": issued.value.issuer_receipt, "playback_token": "TEST.live"}
	var request: Dictionary = CONTRACT.scene_completion_request(event, anchor, bundle)
	assert_true(request.ok, str(request))
	if not request.ok: return {}
	var child: Dictionary = owner.issuer.derive_child(request.value)
	assert_true(child.ok, str(child))
	if not child.ok: return {}
	var made: Dictionary = CONTRACT.make_scene_receipt(event, anchor,
		{"kind": "scene_transition_accepted", "source_scene_occurrence": root.value.token,
		"target_id": "TEST.target", "target": bundle.targets[0].target.duplicate(true),
		"resolution_receipt": {"receipt_id": child.value.child_id, "provenance": child.value.provenance}}, bundle)
	assert_true(made.ok, str(made))
	if not made.ok: return {}
	var bag := {root.value.token: admission.value, issued.value.token: made.value}
	var admitted: Dictionary = CONTRACT.validate_scene_receipts(bag, bundle, owner.issuer)
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return {}
	return {"run_id": identity.run_id, "bag": bag, "admission": admission.value, "event": made.value}

func _snapshot(receipts: Dictionary, run_id: String) -> Dictionary:
	# Exact Run9 envelope with deliberately unfilled independent owner sections.
	# A specific run-join error must precede any unrelated owner refusal.
	var result := {}
	for key: String in RUN.SCENE_TOP_KEYS: result[key] = {}
	result.merge({"schema_version": 9, "run_id": run_id, "route_id": "scene", "content_version": 1,
		"checkpoint_id": run_id + ":2", "checkpoint_sequence": 2, "active_app_id": null,
		"lifecycle": {"run_id": run_id, "branch_id": "TEST.current-branch"},
		"command_receipts": receipts, "applied_effect_transaction_ids": [], "applied_variable_transaction_ids": [],
		"scene": {"active_occurrence_id": "TEST.current", "active_admission_receipt_id": "TEST.current",
			"registration_sha256": "b".repeat(64)}}, true)
	return result

func test_public_run_and_save_reject_foreign_admission_and_event_even_when_unused() -> void:
	var fixture := _receipts()
	if fixture.is_empty(): return
	for member: String in ["admission", "event"]:
		var receipt: Dictionary = fixture[member]
		var snapshot := _snapshot({receipt.transaction_id: receipt}, "TEST.other-run")
		var before := snapshot.duplicate(true)
		assert_eq(RUN.validate(snapshot).code, &"scene_receipt_run_changed", member)
		assert_eq(RUN.validate_scene(snapshot, {}).code, &"scene_receipt_run_changed", member)
		var document := {"schema_version": 9, "kind": "quick", "slot_id": null, "save_reason": "quick",
			"current_snapshot": {"checkpoint_kind": "line", "snapshot": snapshot}, "recovery_journal": []}
		assert_eq(SAVE.validate(document).code, &"scene_receipt_run_changed", member)
		assert_eq(SAVE.validate_outgoing(document, []).code, &"scene_receipt_run_changed", member)
		assert_eq(SAVE.build(&"quick", null, &"quick", document.current_snapshot, []).code,
			&"scene_receipt_run_changed", member)
		assert_eq(snapshot, before, "failed join must not repair retained history")

func test_history_join_allows_original_branches_and_scans_every_map_member() -> void:
	var fixture := _receipts()
	if fixture.is_empty(): return
	assert_eq(RUN._validate_scene_history_run(fixture.bag, fixture.run_id), "")
	var snapshot := _snapshot(fixture.bag, fixture.run_id)
	assert_ne(snapshot.lifecycle.branch_id, fixture.admission.scene_admission.source_identity.branch_id)
	assert_eq(RUN._validate_scene_history_run(snapshot.command_receipts, snapshot.run_id), "",
		"current branch does not replace historical receipt identities")
	var unused := fixture.event.duplicate(true)
	unused.scene_event.semantic.source.run_id = "TEST.foreign"
	var extended: Dictionary = fixture.bag.duplicate(true)
	extended["TEST.unused-history"] = unused
	assert_ne(RUN._validate_scene_history_run(extended, fixture.run_id), "")
	var input := {"lifecycle": {"run_id": fixture.run_id}, "command_receipts": extended}
	assert_eq(RUN.validate_scene_input_fields(input, {}).code, &"scene_receipt_run_changed")
