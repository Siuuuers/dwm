extends RefCounted
## TEST ONLY. Real issuer/root/allocator and real JsonFileStorage over FakeFileOps.
## The registration and scene save projection are invented nonwired fixtures, not
## installed DTL or an assertion that the production Run schema accepts scenes.
const CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const REMAPPER := preload("res://scripts/domain/desktop/DesktopContinuationRemapper.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const PORT := preload("res://scripts/application/run/CausalDayAdvanceIdentityPort.gd")
const NAMESPACE := preload("res://tests/support/FakeDesktopNamespaceSource.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const IDENTITY_KEYS := ["run_id", "branch_id", "desktop_timeline_generation", "causal_day_instance", "causal_day_instance_issuer_receipt"]
var ops := FakeFileOps.new()
var storage := JsonFileStorage.new("TEST/scene-identity", ops)
var root := ROOT.new()
var issuer := ISSUER.new()
var port := PORT.new()
var bundle := registration()
var event := {}
var anchor := {"session_id": "TEST.occurrence", "entry_id": "TEST.scene", "content_version": 1,
	"catalogue_fingerprint": "TEST.catalogue", "publication_id": "TEST.publication", "line_id": "TEST.line"}
var lifecycle := {}
var command_receipts := {}
var original_completion := {}
var durable_source := {}

func setup() -> Dictionary:
	var result: Dictionary = root.configure(storage, NAMESPACE.new("ab".repeat(32)))
	if not result.ok: return result
	result = root.load_or_create()
	if not result.ok: return result
	result = issuer.configure(root)
	if not result.ok: return result
	result = port.configure(issuer)
	if not result.ok: return result
	result = allocate("new_run", {})
	if not result.ok: return result
	lifecycle = identity(result.value)
	lifecycle.restore_provenance = null
	lifecycle.state = "PLAYING"
	result = issuer.issue(&"transaction_id")
	if not result.ok: return result
	event = {"schema_version": 2, "source": {"run_id": lifecycle.run_id,
		"branch_id": lifecycle.branch_id, "causal_day_instance": lifecycle.causal_day_instance,
		"scene_occurrence": "TEST.occurrence", "entry_id": "TEST.scene", "content_version": 1},
		"event_id": "TEST.transition", "ordinal": 0, "predecessor": "", "kind": "scene.transition",
		"payload": {"target_id": "TEST.target"}, "command_id": result.value.issuer_receipt.token,
		"issuer_receipt": result.value.issuer_receipt, "playback_token": "TEST.playback"}
	result = CONTRACT.scene_completion_request(event, anchor, bundle)
	if not result.ok: return result
	result = issuer.derive_child(result.value)
	if not result.ok: return result
	original_completion = {"receipt_id": result.value.child_id, "provenance": result.value.provenance}
	result = CONTRACT.make_scene_receipt(event, anchor, {"kind": "scene_transition_accepted",
		"source_scene_occurrence": event.source.scene_occurrence, "target_id": event.payload.target_id,
		"target": bundle.targets[0].target, "resolution_receipt": original_completion}, bundle)
	if not result.ok: return result
	command_receipts[event.command_id] = result.value
	var stages: Array = []
	for stage_id: String in ["checkpoint_outcomes", "advance_day", "enter_scene"]:
		result = issuer.issue(&"transaction_id")
		if not result.ok: return result
		stages.append({"stage_id": stage_id, "transaction_id": result.value.issuer_receipt.token,
			"state": "completed" if stage_id == "checkpoint_outcomes" else "pending",
			"receipt": {"stage_id": stage_id, "result": {"checkpoint_id": "TEST.checkpoint"}} if stage_id == "checkpoint_outcomes" else null})
	lifecycle.active_resolution_plan = {"kind": "scene_transition", "schema_version": 1,
		"source": {"event_command_id": event.command_id, "identity": identity(lifecycle)}, "stages": stages}
	return persist_source()

func allocate(kind: String, selected: Dictionary) -> Dictionary:
	var issued: Dictionary = issuer.issue(&"transaction_id")
	if not issued.ok: return issued
	var prepared: Dictionary = issuer.prepare_continuation_allocation({
		"transaction_id": issued.value.issuer_receipt.token, "transaction_issuer_receipt": issued.value.issuer_receipt, "kind": kind,
		"existing_run_id": selected.get("run_id") if kind == "restore" else null,
		"source_desktop_timeline_generation": selected.get("desktop_timeline_generation") if kind == "restore" else null,
		"remap_source_transaction_ids": []})
	if not prepared.ok: return prepared
	return issuer.commit_continuation_allocation(prepared.value)

func restore_selected(selected: Dictionary) -> Dictionary:
	var allocated := allocate("restore", selected)
	if not allocated.ok: return allocated
	var allocation: Dictionary = allocated.value
	var transaction: Dictionary = allocation.request.transaction_issuer_receipt
	var remap: Dictionary = issuer.derive_child({"parent_receipt_id": transaction.receipt_id,
		"child_kind": "continuation_operation", "ordinal": 0, "source_ids": []})
	if not remap.ok: return remap
	for key: String in IDENTITY_KEYS: lifecycle[key] = allocation[key]
	lifecycle.restore_provenance = {"source_branch_id": selected.branch_id,
		"source_desktop_timeline_generation": selected.desktop_timeline_generation,
		"source_causal_day_instance": selected.causal_day_instance,
		"source_issuer_observed_counter": selected.causal_day_instance_issuer_receipt.counter,
		"restore_transaction_id": transaction.token, "identity_allocation_receipt_id": transaction.receipt_id,
		"transaction_remap_sha256": hash_value(allocation.transaction_remap),
		"remap_receipt_id": remap.value.child_id, "remap_receipt_provenance": remap.value.provenance}
	return {"ok": true, "value": allocation}

func persist_source() -> Dictionary:
	var snapshot := {"checkpoint_id": "TEST.checkpoint", "lifecycle": lifecycle.duplicate(true),
		"command_receipts": command_receipts.duplicate(true)}
	var current := {"checkpoint_kind": "day_resolution_stage", "snapshot": snapshot}
	var document := {"schema_version": 1, "kind": "autosave", "slot_id": null,
		"save_reason": "automatic", "current_snapshot": current, "recovery_journal": []}
	var encoded: Dictionary = WRITER.stringify(document)
	if not encoded.ok: return encoded
	var written: Dictionary = storage.write_atomic("source.json", encoded.value, _parse)
	if not written.ok: return written
	var readback: Dictionary = storage.inspect_revision("source.json")
	if not readback.ok: return readback
	durable_source = {"document_text": readback.value.text, "locator": {"slot_id": "autosave",
		"checkpoint_id": snapshot.checkpoint_id, "document_sha256": hash_value(snapshot), "bundle_id": hash_value(current)}}
	return {"ok": true}

func source() -> Dictionary:
	var captured: Dictionary = root.capture()
	if not captured.ok: return captured
	return REMAPPER.scene_day_advance_source(lifecycle, command_receipts, bundle, captured.value, durable_source)

func completion(source_result: Dictionary) -> Dictionary:
	if not source_result.get("ok", false): return source_result
	if source_result.value.has("source_resolution_receipt"):
		return {"ok": true, "value": source_result.value.source_resolution_receipt}
	var derived: Dictionary = issuer.derive_child(source_result.value.derivation_request)
	if not derived.ok: return derived
	return {"ok": true, "value": {"receipt_id": derived.value.child_id, "provenance": derived.value.provenance}}

func advance(receipt: Dictionary) -> Dictionary:
	var prepared: Dictionary = port.prepare_advance({"resolution_kind": "scene_day_complete",
		"source_resolution_receipt": receipt, "run_id": lifecycle.run_id, "branch_id": lifecycle.branch_id,
		"desktop_timeline_generation": lifecycle.desktop_timeline_generation,
		"source_causal_day_instance": lifecycle.causal_day_instance,
		"source_causal_day_instance_issuer_receipt": lifecycle.causal_day_instance_issuer_receipt})
	if not prepared.ok: return prepared
	return port.commit_advance(prepared.value.day_advance_identity_candidate)

static func identity(value: Dictionary) -> Dictionary:
	var result := {}
	for key: String in IDENTITY_KEYS: result[key] = value[key]
	return result.duplicate(true)

static func hash_value(value: Variant) -> String:
	return str(WRITER.stringify(value).value).sha256_text()

static func projection(key: String, value: Variant) -> String:
	return key + "=" + str(WRITER.stringify(value).value)

static func _parse(text: String) -> Dictionary:
	return PARSER.parse_object(text)

static func registration() -> Dictionary:
	return {"kind": "scene_reading_registration", "schema_version": 1,
		"entry_manifest": {"TEST": "manifest"}, "context_registry": {"TEST": "contexts"},
		"ids_registry": {"TEST": "ids"}, "caption_registry": {"TEST": "captions"},
		"scene_programme": {"kind": "scene_programme", "schema_version": 1, "entries": [
			{"entry_id": "TEST.scene", "content_version": 1, "content_sha256": "a".repeat(64),
				"program_sha256": "b".repeat(64), "markers": [
					{"marker_id": "TEST.transition", "label": "TEST.exit", "after_line_id": "TEST.line",
						"kind": "scene.transition", "payload": {"target_id": "TEST.target"}}]}]},
		"targets": [{"target_id": "TEST.target", "target": {"kind": "scene", "entry_id": "TEST.scene",
			"label": "TEST.scene", "content_version": 1, "program_sha256": "b".repeat(64)}}],
		"board_profiles": [], "challenges": [], "contacts": []}
