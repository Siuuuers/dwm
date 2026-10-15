extends "res://addons/gut/test.gd"
# Semantic receipt proof using the real issuer over the existing fake root store.
# Installed DTL, Profile attempt proof, physical ledger anchoring and disk are separate.
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const STRUCTURAL_FIXTURE := preload("res://tests/unit/test_scene_event_contract.gd")
const IDENTITY_FIXTURE := preload("res://tests/support/SceneTransitionIdentityFixture.gd")

var issuer: RefCounted
var bundle: Dictionary
var event: Dictionary
var anchor: Dictionary
var admission: Dictionary
var identity: Dictionary

func before_each() -> void:
	var actual_identity := IDENTITY_FIXTURE.new()
	assert_true(actual_identity.setup().ok)
	issuer = actual_identity.issuer
	identity = actual_identity.identity(actual_identity.lifecycle)
	var fixture := STRUCTURAL_FIXTURE.new()
	bundle = fixture._scene_bundle()
	anchor = fixture._scene_anchor()
	fixture.free()
	var root: Dictionary = issuer.issue(&"transaction_id")
	assert_true(root.ok)
	var made: Dictionary = CONTRACT.make_scene_admission(identity, root.value.issuer_receipt,
		"TEST.target", {"checkpoint_id": "TEST.checkpoint", "checkpoint_sequence": 1,
		"snapshot_sha256": "a".repeat(64)}, null, null, bundle, issuer)
	assert_true(made.ok, str(made))
	admission = made.get("value", {})
	anchor.session_id = root.value.token
	var issued: Dictionary = issuer.issue(&"transaction_id")
	assert_true(issued.ok)
	event = {"schema_version": 2, "source": {"run_id": identity.run_id, "branch_id": identity.branch_id,
		"causal_day_instance": identity.causal_day_instance, "scene_occurrence": root.value.token,
		"entry_id": "TEST.scene", "content_version": 1}, "event_id": "TEST.transition",
		"ordinal": 0, "predecessor": "", "kind": "scene.transition", "payload": {"target_id": "TEST.target"},
		"command_id": issued.value.token, "issuer_receipt": issued.value.issuer_receipt,
		"playback_token": "TEST.live"}

func _receipt() -> Dictionary:
	var request: Dictionary = CONTRACT.scene_completion_request(event, anchor, bundle)
	assert_true(request.ok)
	if not request.ok: return {}
	var child: Dictionary = issuer.derive_child(request.value)
	assert_true(child.ok)
	if not child.ok: return {}
	var result := {"kind": "scene_transition_accepted", "source_scene_occurrence": event.source.scene_occurrence,
		"target_id": "TEST.target", "target": bundle.targets[0].target.duplicate(true),
		"resolution_receipt": {"receipt_id": child.value.child_id, "provenance": child.value.provenance}}
	var made: Dictionary = CONTRACT.make_scene_receipt(event, anchor, result, bundle)
	assert_true(made.ok, str(made))
	return made.get("value", {})

func _bag(receipt: Dictionary) -> Dictionary:
	return {admission.transaction_id: admission.duplicate(true), event.command_id: receipt}

func test_registered_issuer_receipt_and_completion_child_rebuild_exactly() -> void:
	var receipt := _receipt()
	if receipt.is_empty(): return
	var result: Dictionary = CONTRACT.validate_scene_receipts(_bag(receipt), bundle, issuer)
	assert_true(result.ok, str(result))
	if not result.ok: return
	assert_eq(result.value.commands[event.command_id], receipt)
	assert_eq(result.value.occurrences.values()[0].next_ordinal, 1)
	result.value.commands[event.command_id].scene_event.result.target_id = "TEST.changed"
	assert_eq(receipt.scene_event.result.target_id, "TEST.target")

func test_unissued_command_and_completion_child_forgery_refuse() -> void:
	var receipt := _receipt()
	if receipt.is_empty(): return
	var foreign := ISSUER.new()
	assert_true(foreign.configure(ROOT.new("cd".repeat(32), 1)).ok)
	assert_false(CONTRACT.validate_scene_receipts(_bag(receipt), bundle, foreign).ok)
	receipt.scene_event.result.resolution_receipt.provenance.source_ids[0] = 'command_id="TEST.forged"'
	assert_false(CONTRACT.validate_scene_receipts(_bag(receipt), bundle, issuer).ok)

func test_shape_scalar_version_registration_and_result_tampering_refuse() -> void:
	var receipt := _receipt()
	if receipt.is_empty(): return
	for mutation: String in ["float_version", "foreign_registration", "wrong_map_key", "result_array", "extra"]:
		var bad := receipt.duplicate(true)
		var bag := _bag(bad)
		match mutation:
			"float_version": bad.scene_event.schema_version = 2.0
			"foreign_registration": bad.scene_event.registration_fingerprint = "0".repeat(64)
			"wrong_map_key":
				bag = {"TEST.other": bad}
			"result_array": bad.scene_event.result = []
			"extra": bad.extra = true
		assert_false(CONTRACT.validate_scene_receipts(bag, bundle, issuer).ok, mutation)
	var changed := bundle.duplicate(true)
	changed.caption_registry.TEST = "different installed bundle"
	assert_false(CONTRACT.validate_scene_receipts(_bag(receipt), changed, issuer).ok)

func test_hole_predecessor_and_unknown_receipt_family_refuse() -> void:
	event.ordinal = 1
	event.predecessor = "TEST.missing"
	var receipt := _receipt()
	if receipt.is_empty(): return
	assert_false(CONTRACT.validate_scene_receipts(_bag(receipt), bundle, issuer).ok)
	assert_false(CONTRACT.validate_scene_receipts({"TEST.command": {"transaction_id": "TEST.command",
		"kind": "scene_admission", "result": {"kind": "scene_admitted"}}}, bundle, issuer).ok)
	assert_false(CONTRACT.validate_scene_receipts({}, bundle, null).ok)

func test_legacy_partitions_remain_explicit_and_unknown_or_extended_members_refuse() -> void:
	var legacy := {"transaction_id": "TEST.effect", "request_fingerprint": "a".repeat(64),
		"kind": "effect_transaction", "source_id": "TEST.source"}
	assert_true(CONTRACT.validate_scene_receipts({"TEST.effect": legacy}, bundle, issuer).ok)
	legacy.extra = true
	assert_false(CONTRACT.validate_scene_receipts({"TEST.effect": legacy}, bundle, issuer).ok)
	legacy.erase("extra")
	legacy.kind = "unknown"
	assert_false(CONTRACT.validate_scene_receipts({"TEST.effect": legacy}, bundle, issuer).ok)

func test_admission_has_real_root_and_exact_child_bound_request() -> void:
	var checked: Dictionary = CONTRACT.validate_scene_receipts({admission.transaction_id: admission}, bundle, issuer)
	assert_true(checked.ok, str(checked))
	if not checked.ok: return
	assert_eq(checked.value.admissions[admission.transaction_id], admission.scene_admission.result)
	assert_eq(admission.source_id, admission.transaction_id)
	assert_eq(admission.scene_admission.result.occurrence_id, admission.transaction_id)
	assert_eq(admission.scene_admission.provenance.child_kind, "continuation_operation")
	assert_eq(admission.scene_admission.provenance.source_ids.size(), 2)
	assert_has(admission.scene_admission.provenance.source_ids, 'role="scene.admission"')
	for field: String in ["registration_fingerprint", "provenance", "result", "issuer_receipt"]:
		var bad := admission.duplicate(true)
		bad.scene_admission[field] = {} if field != "registration_fingerprint" else "0".repeat(64)
		assert_false(CONTRACT.validate_scene_receipts({bad.transaction_id: bad}, bundle, issuer).ok, field)

func test_second_root_and_missing_admission_refuse_without_guessing_lineage() -> void:
	var receipt := _receipt()
	if receipt.is_empty(): return
	assert_false(CONTRACT.validate_scene_receipts({event.command_id: receipt}, bundle, issuer).ok)
	var next_root: Dictionary = issuer.issue(&"transaction_id")
	assert_true(next_root.ok)
	var another: Dictionary = CONTRACT.make_scene_admission(identity, next_root.value.issuer_receipt,
		"TEST.target", admission.scene_admission.result.source_checkpoint, null, null, bundle, issuer)
	assert_true(another.ok)
	var bag := {admission.transaction_id: admission, another.value.transaction_id: another.value}
	assert_false(CONTRACT.validate_scene_receipts(bag, bundle, issuer).ok)

func test_triggered_admission_reuses_accepted_transition_and_refuses_changed_preimage() -> void:
	var receipt := _receipt()
	if receipt.is_empty(): return
	var next_root: Dictionary = issuer.issue(&"transaction_id")
	assert_true(next_root.ok)
	var next: Dictionary = CONTRACT.make_scene_admission(identity, next_root.value.issuer_receipt,
		"TEST.target", admission.scene_admission.result.source_checkpoint, event.command_id, null, bundle, issuer)
	assert_true(next.ok)
	var bag := _bag(receipt)
	bag[next.value.transaction_id] = next.value
	assert_true(CONTRACT.validate_scene_receipts(bag, bundle, issuer).ok)
	next.value.scene_admission.result.trigger_command_id = admission.transaction_id
	assert_false(CONTRACT.validate_scene_receipts(bag, bundle, issuer).ok)

func test_notification_result_is_exact_and_clear_requires_retained_set() -> void:
	var notice := {"notification_id": "TEST.notice", "content_id": "TEST.copy", "parameters": {"count": 1}}
	bundle.scene_programme.entries[0].markers = [
		{"marker_id": "TEST.set", "label": "TEST.set.label", "after_line_id": "TEST.line", "kind": "notification.set", "payload": notice},
		{"marker_id": "TEST.clear", "label": "TEST.clear.label", "after_line_id": "TEST.line", "kind": "notification.clear", "payload": {"notification_id": "TEST.notice"}}]
	var rebuilt: Dictionary = CONTRACT.make_scene_admission(identity, admission.scene_admission.issuer_receipt,
		"TEST.target", admission.scene_admission.result.source_checkpoint, null, null, bundle, issuer)
	assert_true(rebuilt.ok)
	admission = rebuilt.value
	event.kind = "notification.set"
	event.event_id = "TEST.set"
	event.payload = notice
	var made: Dictionary = CONTRACT.make_scene_receipt(event, anchor,
		{"kind": "notification_updated", "notification": notice}, bundle)
	assert_true(made.ok)
	var bag := _bag(made.value)
	assert_true(CONTRACT.validate_scene_receipts(bag, bundle, issuer).ok)
	var issued: Dictionary = issuer.issue(&"transaction_id")
	event.command_id = issued.value.token
	event.issuer_receipt = issued.value.issuer_receipt
	event.kind = "notification.clear"
	event.event_id = "TEST.clear"
	event.ordinal = 1
	event.predecessor = "TEST.set"
	event.payload = {"notification_id": "TEST.notice"}
	made = CONTRACT.make_scene_receipt(event, anchor, {"kind": "notification_updated", "notification": {}}, bundle)
	assert_true(made.ok)
	bag[event.command_id] = made.value
	var checked: Dictionary = CONTRACT.validate_scene_receipts(bag, bundle, issuer)
	assert_true(checked.ok)
	assert_eq(checked.value.occurrences.values()[0].notification, {})
	event.ordinal = 0
	event.predecessor = ""
	made = CONTRACT.make_scene_receipt(event, anchor, {"kind": "notification_updated", "notification": {}}, bundle)
	assert_false(CONTRACT.validate_scene_receipts(_bag(made.value), bundle, issuer).ok)

