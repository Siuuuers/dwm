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

# Failure-injectable owner returning the exact shapes the real adapters expect.
class Owner extends RefCounted:
	var fail: StringName = &""
	func _g(m: String) -> Dictionary:
		return {"ok": false, "code": &"forced_owner_failure", "message": m} if fail == StringName(m) else {}
	func prepare_new_run_snapshot_input(run_id: String) -> Dictionary:
		return {"ok": true, "value": {"snapshot_input": {"lifecycle": {"run_id": run_id, "day": 1}}}}
	func prepare_legacy_profile_patch(_l: Dictionary, _m: Dictionary = {}) -> Dictionary:
		var g := _g("prepare_legacy_profile_patch")
		return g if not g.is_empty() else {"ok": true, "value": {"preferences": {"language": "en"}}}
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

func _snapshot(run_id: String, seq: int, narrative: Dictionary = {}) -> Dictionary:
	var s: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(VALID_FIXTURE))
	s["run_id"] = run_id
	s["checkpoint_sequence"] = seq
	s["checkpoint_id"] = "%s:%d" % [run_id, seq]
	s["lifecycle"]["run_id"] = run_id
	s["narrative_checkpoint"] = narrative
	return load("res://scripts/domain/run/RunSnapshotSchema.gd").validate(s)["value"]["candidate"]

func _manager(owner: Owner) -> Node:
	var root := OS.get_environment("DWM_TEST_ROOT").path_join("prod_adapters").path_join(str(randi())).path_join("saves")
	DirAccess.make_dir_recursive_absolute(root)
	var m: Node = load(SAVE_MANAGER_PATH).new()
	autofree(m)
	m.initialize(load(STORAGE_PATH).new(root))
	m.configure_mutation_gate(load(GATE_PATH).new())
	m.configure_restore_participants({
		"run": load(RUN_P).new(owner), "profile": load(PROFILE_P).new(owner),
		"localization": load(LOC_P).new(owner), "audio": load(AUDIO_P).new(owner),
		"route": load(ROUTE_P).new(owner), "narrative": load(NARR_P).new(owner),
	})
	return m

func test_prepare_builds_six_plans_and_commits() -> void:
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
	for key: String in ["run", "profile", "localization", "audio", "route", "narrative"]:
		assert_true(value["participant_plans"].has(key), "plan built for " + key)
	assert_eq(value["route_id"], "main", "route id derived from the one selected bundle")
	assert_true(m.commit_prepared_restore(value).get("ok", false), "the prepared restore commits atomically")
	assert_eq(str(m._journal.get_current_bundle()["value"]["bundle"]["snapshot"]["run_id"]), "run-a",
		"the restored run replaced the live journal")

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
	owner.fail = &"prepare_legacy_profile_patch"
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
		return "res://dialogic/timelines/en/core/opening_day1.dtl"


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
