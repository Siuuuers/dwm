extends "res://addons/gut/test.gd"

const NARR_P := "res://scripts/application/restore/NarrativeRestoreParticipant.gd"
const SAVE_CHECKPOINT_PORT := "res://scripts/application/run/SaveManagerCheckpointPort.gd"
const DESKTOP_HOST := "res://scripts/domain/desktop/DesktopAppHostState.gd"

var _retained_scope := preload("res://tests/support/SceneValidationScope.gd").new()

func before_each() -> void:
	_retained_scope.install(true)

func after_each() -> void:
	_retained_scope.restore()

class Owner extends RefCounted:
	func prepare_semantic_restore(ctx: Dictionary, _p: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"snapshot": ctx.duplicate(true)}}

const NARRATIVE_SCHEMA := preload("res://scripts/narrative/NarrativeCheckpointSchema.gd")
const NARRATIVE_FINGERPRINT := "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"


class NarrativeCatalogStub extends RefCounted:
	var record: Dictionary = {}
	func get_record(timeline_id: String) -> Dictionary:
		if str(record.get("id", "")) != timeline_id:
			return {"ok": false, "code": &"unknown_timeline_id", "message": timeline_id}
		return {"ok": true, "value": record.duplicate(true)}
	func get_timeline_path(_timeline_id: String, _locale: String = "en") -> String:
		return "res://dialogic/timelines/en/core/hospital_faint.dtl"


func _narrative_record() -> Dictionary:
	return {"id": "T", "content_fingerprint": NARRATIVE_FINGERPRINT, "events": [
		{"event_id": "T@0:text", "event_index": 0, "event_kind": "text", "semantic_id": "T.line.1", "post_event_id": null, "post_event_index": null},
	]}


func _narrative_checkpoint() -> Dictionary:
	var event := {"event_id": "T@0:text", "event_index": 0, "event_kind": "text", "semantic_id": "T.line.1"}
	var post := {"position": "revealed_event", "event_id": "T@0:text", "event_index": 0, "event_kind": "text", "semantic_id": "T.line.1"}
	return NARRATIVE_SCHEMA.build(_narrative_record(), {"kind": "line", "semantic_id": "T.line.1", "transaction_id": ""}, event, post, "T.line.1", false)["value"]


func test_physical_narrative_participant_prepares_against_current_manifest() -> void:
	var catalog := NarrativeCatalogStub.new()
	catalog.record = _narrative_record()
	var participant: Object = load(NARR_P).new(Owner.new(), catalog)
	var prepared: Dictionary = participant.prepare({"narrative_checkpoint": _narrative_checkpoint(), "content_version": 1})
	assert_true(prepared.get("ok", false), str(prepared))
	assert_eq(str(prepared["value"]["narrative_plan"]["position"]), "revealed_event", "resolved restore position")


func test_physical_narrative_participant_reports_removed_content_as_recoverable() -> void:
	var catalog := NarrativeCatalogStub.new()
	var trimmed := _narrative_record()
	trimmed["events"] = []
	catalog.record = trimmed
	var participant: Object = load(NARR_P).new(Owner.new(), catalog)
	var prepared: Dictionary = participant.prepare({"narrative_checkpoint": _narrative_checkpoint(), "content_version": 1})
	assert_eq(str(prepared.get("code")), "NARRATIVE_CONTENT_UNAVAILABLE", "removed event advances to an earlier bundle")


func test_physical_narrative_participant_reports_fingerprint_drift_as_recoverable() -> void:
	var catalog := NarrativeCatalogStub.new()
	var drifted := _narrative_record()
	drifted["content_fingerprint"] = "sha256:feedface"
	catalog.record = drifted
	var participant: Object = load(NARR_P).new(Owner.new(), catalog)
	assert_eq(str(participant.prepare({"narrative_checkpoint": _narrative_checkpoint(), "content_version": 1}).get("code")), "NARRATIVE_CONTENT_UNAVAILABLE")


func test_physical_narrative_participant_fails_closed_on_malformed_bytes() -> void:
	var catalog := NarrativeCatalogStub.new()
	catalog.record = _narrative_record()
	var broken := _narrative_checkpoint()
	broken["boundary"] = {"kind": "line"}
	var participant: Object = load(NARR_P).new(Owner.new(), catalog)
	assert_eq(str(participant.prepare({"narrative_checkpoint": broken, "content_version": 1}).get("code")), "invalid_narrative_checkpoint", "malformed data must not be relabelled incompatible")


# ---- dwm-p2r.9 Plan 02 Task 1: the checkpoint port's desktop context provider contract ----
func test_checkpoint_port_configures_desktop_context_provider() -> void:
	var port: Object = load(SAVE_CHECKPOINT_PORT).new(null)
	var host: RefCounted = load(DESKTOP_HOST).new()
	var configured: Dictionary = port.configure_desktop_context_provider(host)
	assert_true(configured.get("ok", false), "accepts a DesktopAppHostState provider")
	var again: Dictionary = port.configure_desktop_context_provider(host)
	assert_true(again.get("ok", false) and again["value"]["already_configured"],
		"the same provider instance is idempotent")
	var different: Dictionary = port.configure_desktop_context_provider(load(DESKTOP_HOST).new())
	assert_false(different.get("ok", true), "a different provider is rejected")
	var nullp: Dictionary = port.configure_desktop_context_provider(null)
	assert_false(nullp.get("ok", true), "a null provider is rejected")
# ---- Seven-Day Flow Plan 01 Task 7 (dwm-oyo.2): the SEMANTIC narrative participant ----
# The same real class over the REAL DialogicBridge and its REAL entry catalog, so the semantic
# branch is exercised against production wiring rather than a duck-typed owner. Deliberately only
# two tests: this file is sha256-bound in evidence/phase_2r/handoff/desktop_contract.json and moves
# the restore-consumer baseline, so Task 7's share of it stays small.

const SEMANTIC_BRIDGE := preload("res://autoload/DialogicBridge.gd")
const SEMANTIC_ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const SEMANTIC_RUNTIME := preload("res://tests/support/FakeDialogicRuntime.gd")
const SEMANTIC_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const SEMANTIC_ENTRY := "contact.ordinary.lavinia.day1"
const SEMANTIC_PLAN_FIELDS := ["content_version", "entry_id", "frozen_context",
	"manifest_fingerprint", "stage", "transaction_id"]


func _semantic_bridge() -> Node:
	var runtime: Node = autofree(SEMANTIC_RUNTIME.new())
	var adapter: RefCounted = SEMANTIC_ADAPTER.new()
	assert_true(adapter.bind_runtime(runtime).get("ok", false), "the fake runtime binds")
	var bridge: Node = SEMANTIC_BRIDGE.new()
	add_child_autofree(bridge)
	assert_true(bridge.initialize(null, adapter).get("ok", false), "the real bridge initializes")
	return bridge


func _live_entry_document_fingerprint() -> String:
	var loaded: Dictionary = SEMANTIC_MANIFEST.load_default()
	if not loaded.get("ok", false):
		return ""
	return str(SEMANTIC_MANIFEST.fingerprint(loaded["value"]))


func _semantic_entry_checkpoint(manifest_fingerprint: String) -> Dictionary:
	return {
		"content_version": 1,
		"entry_id": SEMANTIC_ENTRY,
		"frozen_context": {"expected_stage": "current_entry", "playback_id": "prod-restore",
			"role": "primary", "transaction_id": "tx-prod"},
		"manifest_fingerprint": manifest_fingerprint,
		"stage": "current_entry",
		"transaction_id": "tx-prod",
	}


func _semantic_plan_of(prepared: Dictionary) -> Dictionary:
	var value: Variant = prepared.get("value", {})
	if typeof(value) != TYPE_DICTIONARY:
		return {}
	var plan: Variant = (value as Dictionary).get("narrative_plan", {})
	return plan if typeof(plan) == TYPE_DICTIONARY else {}


func test_semantic_narrative_participant_prepares_the_six_field_plan_over_the_real_bridge() -> void:
	var participant: Object = load(NARR_P).new(_semantic_bridge(), NarrativeCatalogStub.new())
	var prepared: Dictionary = participant.prepare({
		"narrative_checkpoint": _semantic_entry_checkpoint(_live_entry_document_fingerprint()),
		"content_version": 1})
	assert_true(prepared.get("ok", false), str(prepared))
	var keys: Array = _semantic_plan_of(prepared).keys()
	keys.sort()
	assert_eq(keys, SEMANTIC_PLAN_FIELDS,
		"the production participant prepares exactly the six declared fields: " + str(keys))
	assert_false(keys.has("timeline_path"),
		"specification 14.4: a prepared plan never carries a physical path")


func test_semantic_narrative_participant_reports_manifest_drift_as_recoverable() -> void:
	var participant: Object = load(NARR_P).new(_semantic_bridge(), NarrativeCatalogStub.new())
	var prepared: Dictionary = participant.prepare({
		"narrative_checkpoint": _semantic_entry_checkpoint("sha256:" + "0".repeat(64)),
		"content_version": 1})
	assert_eq(str(prepared.get("code", "")), "NARRATIVE_CONTENT_UNAVAILABLE",
		"a drifted manifest fingerprint advances to an earlier bundle instead of failing the restore")
