extends "res://addons/gut/test.gd"
# The six real restore adapters over failure-injectable manager ports, exercising
# prepare_restore -> commit end to end
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const STORAGE_PATH := "res://scripts/infrastructure/storage/JsonFileStorage.gd"
const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const VALID_FIXTURE := "res://tests/fixtures/snapshots/valid_day3.json"
const RUN_P := "res://scripts/application/restore/RunRestoreParticipant.gd"
const PROFILE_P := "res://scripts/application/restore/ProfileRestoreParticipant.gd"
const LOC_P := "res://scripts/application/restore/LocalizationRestoreParticipant.gd"
const AUDIO_P := "res://scripts/application/restore/AudioRestoreParticipant.gd"
const ROUTE_P := "res://scripts/application/restore/RouteRestoreParticipant.gd"
const NARR_P := "res://scripts/application/restore/NarrativeRestoreParticipant.gd"
const SAVE_CHECKPOINT_PORT := "res://scripts/application/run/SaveManagerCheckpointPort.gd"
const DESKTOP_HOST := "res://scripts/domain/desktop/DesktopAppHostState.gd"
## Plan 02 Task 6 (dwm-p2r.32), Phase C2: two more real restore adapters plus the real issuer stack
## `commit_prepared_restore()` now drives for every genuine production restore.
const DESKTOP_CONSEQUENCE_STATE := "res://scripts/domain/desktop/DesktopConsequenceState.gd"
const DESKTOP_BOARD_STATE := "res://scripts/domain/minesweeper/DesktopBoardState.gd"
const DESKTOP_CONSEQUENCE_PARTICIPANT := "res://scripts/application/restore/DesktopConsequenceRestoreParticipant.gd"
const DESKTOP_BOARD_PARTICIPANT := "res://scripts/application/restore/DesktopBoardRestoreParticipant.gd"
const IDENTITY_ALLOCATION_PARTICIPANT := "res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd"
const ISSUER_PATH := "res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd"
const ROOT_STORE_PATH := "res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd"
const FAKE_NAMESPACE_SOURCE_PATH := "res://tests/support/FakeDesktopNamespaceSource.gd"

# Failure-injectable owner returning the exact shapes the real adapters expect.
class Owner extends RefCounted:
	var fail: StringName = &""
	func _g(m: String) -> Dictionary:
		return {"ok": false, "code": &"forced_owner_failure", "message": m} if fail == StringName(m) else {}
	func prepare_new_run_snapshot_input(run_id: String, _branch_id: String, _generation: int,
			_causal_day_instance: String, _causal_day_instance_issuer_receipt: Dictionary, dark_mode: bool) -> Dictionary:
		return {"ok": true, "value": {"snapshot_input": {"lifecycle": {"run_id": run_id, "dark_mode": dark_mode, "day": 1}}}}
	## Plan 02 Task 6 (dwm-p2r.32), Phase C2: RunRestoreParticipant.apply_continuation_remap()
	## delegates here for a real restore's identity-remap step; this fake owner accepts it trivially
	## (this file exercises the ORDINARY participant plumbing, not remap correctness itself -- see
	## test_desktop_board_persistence.gd for that).
	func apply_continuation_remap_silent(_restore_transaction_id: String, _identity_allocation_bundle: Dictionary) -> Dictionary:
		return {"ok": true, "code": &"ok"}
	func get_profile_snapshot() -> Dictionary:
		return preload("res://scripts/profile/ProfileSchema.gd").make_defaults()
	func prepare_profile_document(candidate: Dictionary) -> Dictionary:
		var guarded := _g("prepare_profile_document")
		if not guarded.is_empty(): return guarded
		return preload("res://scripts/profile/ProfileSchema.gd").validate(candidate)
	func prepare_legacy_profile_patch(_l: Dictionary, _m: Dictionary = {}) -> Dictionary:
		var g := _g("prepare_legacy_profile_patch")
		return g if not g.is_empty() else {"ok": true, "value": preload("res://scripts/profile/ProfileSchema.gd").make_defaults()}
	func prepare_locale(locale_id: String) -> Dictionary:
		return {"ok": true, "value": {"canonical_locale_id": locale_id}}
	func prepare_semantic_restore(ctx: Dictionary, _p: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"snapshot": ctx.duplicate(true)}}
	func prepare_route_restore(route_id: String, _c: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"route_ready_token": {"route_id": route_id, "layout_id": "L", "generation": 1}}}
	func apply_route_restore_silent(plan: Dictionary) -> Dictionary:
		return {"ok": true, "value": {"route_ready_token": plan.get("route_ready_token", {"route_id": "main", "layout_id": "L", "generation": 1})}}
	func capture_restore_state() -> Dictionary: return {"ok": true, "value": {"backup": true}}
	func apply_restore_silent(_p: Dictionary) -> Dictionary: return {"ok": true}
	func rollback_restore_silent(_b: Dictionary) -> Dictionary: return {"ok": true}
	func finalize_restore() -> Dictionary: return {"ok": true}

## Test-authored v5 cases retain the source payload and explicitly choose Dark=false.
## This fixture construction is not a player-save migration.
func _issuer_receipt(token: String) -> Dictionary:
	return {"receipt_id": "issuer_receipt.fixture-" + token, "purpose": "causal_day_instance",
		"namespace": "fixturenamespace", "counter": 1, "token": token, "numeric_value": null}

func _empty_desktop() -> Dictionary:
	return {
		"board": {"schema_version": 1, "phase": "NONE", "revision": 0, "identity": null,
			"candidate": null, "board": null, "settlement": null, "command_receipts": {}, "terminal_receipts": {}},
		"consequence": {"schema_version": 1, "run_revision": 0, "causal_sequence": 0,
			"causal_day_instance": "causal-day-1",
			"causal_day_instance_issuer_receipt": _issuer_receipt("causal-day-1"),
			"pending": null, "outbox": {}, "shop_ledger": {"supportz_branch_purchase_count": 0,
				"supportz_last_purchase_causal_day_instance": "", "base_completion_receipts": []}},
	}

func _snapshot(run_id: String, seq: int, narrative: Dictionary = {}) -> Dictionary:
	var s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VALID_FIXTURE))
	s["schema_version"] = 5
	s["lifecycle"]["dark_mode"] = false
	s["gameplay"].erase("opening_seen")
	s["gameplay"].erase("tutorial_seen")
	s["run_id"] = run_id
	s["checkpoint_sequence"] = seq
	s["checkpoint_id"] = "%s:%d" % [run_id, seq]
	s["lifecycle"]["run_id"] = run_id
	s["lifecycle"]["branch_id"] = "branch-1"
	s["lifecycle"]["desktop_timeline_generation"] = 0
	s["lifecycle"]["causal_day_instance"] = "causal-day-1"
	s["lifecycle"]["causal_day_instance_issuer_receipt"] = _issuer_receipt("causal-day-1")
	s["lifecycle"]["restore_provenance"] = null
	s["desktop"] = _empty_desktop()
	s["narrative_checkpoint"] = narrative
	var validated: Dictionary = load("res://scripts/domain/run/RunSnapshotSchema.gd").validate(s)
	assert_true(validated.get("ok", false), JSON.stringify(validated))
	return validated["value"]["candidate"]

## Real DesktopIdentityNonceIssuer/DesktopIssuerRootStore stack, isolated per manager (mirrors
## test_desktop_identity_allocation_restore_participant.gd's own established substrate choice).
func _fresh_issuer(root: String) -> RefCounted:
	var file_ops: FakeFileOps = FakeFileOps.new()
	var storage := JsonFileStorage.new(root.path_join("_issuer"), file_ops)
	var namespace_source: RefCounted = load(FAKE_NAMESPACE_SOURCE_PATH).new("2".repeat(64))
	var store: RefCounted = load(ROOT_STORE_PATH).new()
	assert_true(store.configure(storage, namespace_source).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	var issuer: RefCounted = load(ISSUER_PATH).new()
	assert_true(issuer.configure(store).get("ok", false))
	return issuer

func _manager(owner: Owner) -> Node:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("prod_adapters").path_join(str(randi()))
	var saves_root := root.path_join("saves")
	DirAccess.make_dir_recursive_absolute(saves_root)
	var m: Node = load(SAVE_MANAGER_PATH).new()
	autofree(m)
	m.initialize(load(STORAGE_PATH).new(saves_root))
	m.configure_mutation_gate(load(GATE_PATH).new())
	var issuer := _fresh_issuer(root)
	m.configure_identity_issuer(issuer)
	m.configure_identity_allocation_participant(load(IDENTITY_ALLOCATION_PARTICIPANT).new(issuer, m))
	m.configure_restore_participants({
		"run": load(RUN_P).new(owner),
		"desktop_consequence": load(DESKTOP_CONSEQUENCE_PARTICIPANT).new(load(DESKTOP_CONSEQUENCE_STATE).new()),
		"desktop_board": load(DESKTOP_BOARD_PARTICIPANT).new(load(DESKTOP_BOARD_STATE).new()),
		"profile": load(PROFILE_P).new(owner),
		"localization": load(LOC_P).new(owner), "audio": load(AUDIO_P).new(owner),
		"route": load(ROUTE_P).new(owner), "narrative": load(NARR_P).new(owner),
	})
	return m

func test_prepare_builds_eight_plans_and_commits() -> void:
	var m := _manager(Owner.new())
	m._journal.reset("run-a")
	m._journal.commit_prepared(m._journal.prepare_record(_snapshot("run-a", 1), &"day_start")["value"]["candidate"])
	assert_true(m.save_latest_to_slot(1)["ok"])
	# A different game is live when the player loads.
	m._journal.reset("run-live")
	m._journal.commit_prepared(m._journal.prepare_record(_snapshot("run-live", 1), &"day_start")["value"]["candidate"])
	var prepared: Dictionary = m.prepare_restore_slot(1)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var value: Dictionary = prepared["value"]["prepared"]
	for key: String in ["run", "desktop_consequence", "desktop_board", "profile", "localization", "audio", "route", "narrative"]:
		assert_true(value["participant_plans"].has(key), "plan built for " + key)
	assert_true(value.has("source_locator"), "prepare embeds the identity-continuation source locator")
	assert_eq(value["route_id"], "main", "route id derived from the one selected bundle")
	var committed: Dictionary = m.commit_prepared_restore(value)
	assert_true(committed.get("ok", false), "the prepared restore commits atomically: " + JSON.stringify(committed))
	assert_eq(str(m._journal.get_current_bundle()["value"]["bundle"]["snapshot"]["run_id"]), "run-a",
		"the restored run replaced the live journal")

## IMPORTANT 5 (brief line 209): a caller-authored prepared dictionary carrying any issuer/
## allocation/remap-shaped field must reject before durable allocation. Each stray key below is
## exactly the shape produced INSIDE _begin_restore_continuation(), never legitimate top-level
## input to commit_prepared_restore() itself.
func _prepared_restore_with_stray_key(m: Node, slot_id: int, key: String, value: Variant) -> Dictionary:
	m._journal.reset("run-stray-%s-a" % key)
	m._journal.commit_prepared(m._journal.prepare_record(_snapshot("run-stray-%s-a" % key, 1), &"day_start")["value"]["candidate"])
	assert_true(m.save_latest_to_slot(slot_id)["ok"])
	# A different game is live when the player loads, matching this file's own established pattern.
	m._journal.reset("run-stray-%s-live" % key)
	m._journal.commit_prepared(m._journal.prepare_record(_snapshot("run-stray-%s-live" % key, 1), &"day_start")["value"]["candidate"])
	var prepared: Dictionary = m.prepare_restore_slot(slot_id)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var stray: Dictionary = (prepared["value"]["prepared"] as Dictionary).duplicate(true)
	stray[key] = value
	return stray


func test_commit_prepared_restore_rejects_stray_identity_allocation_bundle_key() -> void:
	var m := _manager(Owner.new())
	var stray := _prepared_restore_with_stray_key(m, 4, "identity_allocation_bundle", {"forged": true})
	var rejected: Dictionary = m.commit_prepared_restore(stray)
	assert_false(rejected.get("ok", true), "a stray identity_allocation_bundle key must reject before durable allocation")
	assert_eq(rejected["code"], &"invalid_prepared_restore")
	assert_eq(str(m._journal.get_current_bundle()["value"]["bundle"]["snapshot"]["run_id"]), "run-stray-identity_allocation_bundle-live",
		"no journal write: the live run is untouched")
	assert_eq((m._continuation_journal.list_incomplete() as Dictionary)["value"], [],
		"no continuation-journal write either")


func test_commit_prepared_restore_rejects_stray_transaction_issuer_receipt_key() -> void:
	var m := _manager(Owner.new())
	var stray := _prepared_restore_with_stray_key(m, 5, "transaction_issuer_receipt", {"forged": true})
	var rejected: Dictionary = m.commit_prepared_restore(stray)
	assert_false(rejected.get("ok", true), "a stray transaction_issuer_receipt key must reject before durable allocation")
	assert_eq(rejected["code"], &"invalid_prepared_restore")
	assert_eq(str(m._journal.get_current_bundle()["value"]["bundle"]["snapshot"]["run_id"]), "run-stray-transaction_issuer_receipt-live",
		"no journal write: the live run is untouched")
	assert_eq((m._continuation_journal.list_incomplete() as Dictionary)["value"], [],
		"no continuation-journal write either")


func test_commit_prepared_restore_rejects_stray_transaction_remap_key() -> void:
	var m := _manager(Owner.new())
	var stray := _prepared_restore_with_stray_key(m, 6, "transaction_remap", {"forged": true})
	var rejected: Dictionary = m.commit_prepared_restore(stray)
	assert_false(rejected.get("ok", true), "a stray transaction_remap key must reject before durable allocation")
	assert_eq(rejected["code"], &"invalid_prepared_restore")
	assert_eq(str(m._journal.get_current_bundle()["value"]["bundle"]["snapshot"]["run_id"]), "run-stray-transaction_remap-live",
		"no journal write: the live run is untouched")
	assert_eq((m._continuation_journal.list_incomplete() as Dictionary)["value"], [],
		"no continuation-journal write either")


func test_late_narrative_incompatibility_selects_earlier_bundle() -> void:
	var m := _manager(Owner.new())
	m._journal.reset("run-b")
	m._journal.commit_prepared(m._journal.prepare_record(_snapshot("run-b", 1), &"day_start")["value"]["candidate"])
	m._journal.commit_prepared(m._journal.prepare_record(_snapshot("run-b", 2, {"timeline_id": "x"}), &"line")["value"]["candidate"])
	assert_true(m.save_latest_to_slot(2)["ok"])
	var prepared: Dictionary = m.prepare_restore_slot(2)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	assert_eq(str(prepared["value"]["prepared"]["checkpoint_id"]), "run-b:1",
		"the current bundle is narrative-incompatible, so the earlier compatible bundle wins")

func test_profile_prepare_failure_is_structural_not_content() -> void:
	var owner := Owner.new()
	owner.fail = &"prepare_profile_document"
	var m := _manager(owner)
	m._journal.reset("run-c")
	m._journal.commit_prepared(m._journal.prepare_record(_snapshot("run-c", 1), &"day_start")["value"]["candidate"])
	assert_true(m.save_latest_to_slot(3)["ok"])
	var prepared: Dictionary = m.prepare_restore_slot(3)
	assert_false(prepared.get("ok", true), "a hard participant failure fails prepare, never a silent fallback")
	assert_ne(prepared.get("code"), &"NO_COMPATIBLE_BUNDLE")


# ---- dwm-p2r.8 (Plan-05 Task 2 Step 2.4): the PHYSICAL manifest-aware narrative participant ----
# These exercise the real class against the current manifest, not a SaveManager-only fake.

const NARRATIVE_SCHEMA := preload("res://scripts/narrative/NarrativeCheckpointSchema.gd")
const NARRATIVE_FINGERPRINT := "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"


class NarrativeCatalogStub extends RefCounted:
	var record: Dictionary = {}
	func get_record(timeline_id: String) -> Dictionary:
		if str(record.get("id", "")) != timeline_id:
			return {"ok": false, "code": &"unknown_timeline_id", "message": timeline_id}
		return {"ok": true, "value": record.duplicate(true)}
	func get_timeline_path(_timeline_id: String, _locale: String = "en") -> String:
		return "res://dialogic/timelines/en/day_2.dtl"


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
