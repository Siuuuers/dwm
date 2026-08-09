extends "res://addons/gut/test.gd"

# Manifest-aware narrative restore (dwm-p2r.8, Plan-05 Task 2 Step 2.4). Covers the participant's
# pure prepare() (fingerprint/content compatibility vs fail-closed malformed data) and the exact
# post-event restore state machine: revealed_event reveals, before_event stages without executing,
# finalize schedules one deferred resume, rollback cancels it.

const PARTICIPANT := preload("res://scripts/application/restore/NarrativeRestoreParticipant.gd")
const BRIDGE := preload("res://autoload/DialogicBridge.gd")
const SCHEMA := preload("res://scripts/narrative/NarrativeCheckpointSchema.gd")

const FINGERPRINT := "sha256:0123456789abcdef0123456789abcdef0123456789abcdef0123456789abcdef"

var _bridge: Node


class _FakeCatalog extends RefCounted:
	var record: Dictionary = {}
	func get_record(timeline_id: String) -> Dictionary:
		if str(record.get("id", "")) != timeline_id:
			return {"ok": false, "code": &"unknown_timeline_id", "message": timeline_id}
		return {"ok": true, "value": record.duplicate(true)}
	func get_timeline_path(_timeline_id: String, _locale: String = "en") -> String:
		return "res://dialogic/timelines/en/core/opening_day1.dtl"


class _FakeAdapter extends RefCounted:
	signal timeline_started_signal
	signal timeline_ended_signal
	signal event_handled_signal(resource)
	signal runtime_signal_event(argument)
	signal preference_reapply_requested
	var calls: Array = []
	var paused := false
	func start_timeline(path: String, event_index: int = 0) -> Dictionary:
		calls.append("start:%d" % event_index)
		return {"ok": true, "code": &"ok", "value": {"path": path, "event_index": event_index}}
	func reveal_current_line() -> Dictionary:
		calls.append("reveal")
		return {"ok": true, "code": &"ok", "value": {}}
	func set_paused(value: bool) -> Dictionary:
		paused = value
		calls.append("paused:%s" % str(value))
		return {"ok": true, "code": &"ok", "value": {}}
	func halt_with_error(_r: Dictionary) -> Dictionary:
		return {"ok": false}
	func capture_restore_state() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {"backup": {}}}
	func restore_captured_state(_b: Dictionary) -> Dictionary:
		calls.append("restore_captured")
		return {"ok": true, "code": &"ok", "value": {}}


func _record() -> Dictionary:
	return {
		"id": "T",
		"content_fingerprint": FINGERPRINT,
		"events": [
			{"event_id": "T@0:choice", "event_index": 0, "event_kind": "choice", "semantic_id": "T.choice.1", "post_event_id": "T@1:effect_transaction", "post_event_index": 1},
			{"event_id": "T@1:effect_transaction", "event_index": 1, "event_kind": "effect_transaction", "semantic_id": "T.effect.tx", "post_event_id": "T@2:text", "post_event_index": 2},
			{"event_id": "T@2:text", "event_index": 2, "event_kind": "text", "semantic_id": "T.line.1", "post_event_id": null, "post_event_index": null},
		],
	}


func _evt(index: int) -> Dictionary:
	var e: Dictionary = _record()["events"][index]
	return {"event_id": e["event_id"], "event_index": e["event_index"], "event_kind": e["event_kind"], "semantic_id": e["semantic_id"]}


func _post(position: String, fields: Dictionary) -> Dictionary:
	var out := {"position": position}
	out.merge(fields)
	return out


func _line_checkpoint() -> Dictionary:
	var built: Dictionary = SCHEMA.build(_record(), {"kind": "line", "semantic_id": "T.line.1", "transaction_id": ""}, _evt(2), _post("revealed_event", _evt(2)), "T.line.1", false)
	return built["value"]


func _effect_checkpoint() -> Dictionary:
	var built: Dictionary = SCHEMA.build(_record(), {"kind": "effect_transaction", "semantic_id": "T.effect.tx", "transaction_id": "run:effect:1"}, _evt(1), _post("before_event", _evt(2)), null, false)
	return built["value"]


func _new_participant(catalog: _FakeCatalog) -> Object:
	return PARTICIPANT.new(_bridge, catalog)


func _catalog() -> _FakeCatalog:
	var catalog := _FakeCatalog.new()
	catalog.record = _record()
	return catalog


func before_each() -> void:
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)


func _init_bridge() -> _FakeAdapter:
	var adapter := _FakeAdapter.new()
	_bridge.initialize(null, adapter)
	return adapter


func test_prepare_accepts_matching_checkpoint() -> void:
	var participant: Object = _new_participant(_catalog())
	var result: Dictionary = participant.prepare({"narrative_checkpoint": _line_checkpoint(), "content_version": 1})
	assert_true(result.get("ok", false), str(result))
	var plan: Dictionary = result["value"]["narrative_plan"]
	assert_eq(str(plan["position"]), "revealed_event", "plan carries the resolved position")
	assert_eq(int(plan["resume_event_index"]), 2, "plan carries the resolved locator")


func test_prepare_still_accepts_empty_checkpoint() -> void:
	var participant: Object = _new_participant(_catalog())
	assert_true(participant.prepare({"narrative_checkpoint": {}, "content_version": 1}).get("ok", false), "empty playhead ok")


func test_prepare_rejects_malformed_input_fail_closed() -> void:
	var participant: Object = _new_participant(_catalog())
	assert_eq(str(participant.prepare({"content_version": 1}).get("code")), "invalid_narrative_input")
	assert_eq(str(participant.prepare({"narrative_checkpoint": _line_checkpoint()}).get("code")), "invalid_narrative_input")


func test_prepare_reports_content_incompatible_for_unknown_timeline() -> void:
	var catalog := _catalog()
	catalog.record = {"id": "OTHER", "content_fingerprint": FINGERPRINT, "events": []}
	var result: Dictionary = _new_participant(catalog).prepare({"narrative_checkpoint": _line_checkpoint(), "content_version": 1})
	assert_false(result.get("ok", false), "unknown timeline rejects")
	assert_eq(str(result.get("code")), "NARRATIVE_CONTENT_UNAVAILABLE", "typed recoverable incompatibility")


func test_prepare_reports_content_incompatible_for_fingerprint_drift() -> void:
	var catalog := _catalog()
	var drifted := _record()
	drifted["content_fingerprint"] = "sha256:feedface"
	catalog.record = drifted
	var result: Dictionary = _new_participant(catalog).prepare({"narrative_checkpoint": _line_checkpoint(), "content_version": 1})
	assert_eq(str(result.get("code")), "NARRATIVE_CONTENT_UNAVAILABLE", "fingerprint drift is recoverable")


func test_prepare_reports_content_incompatible_for_removed_event() -> void:
	var catalog := _catalog()
	var trimmed := _record()
	trimmed["events"] = [trimmed["events"][0]]
	catalog.record = trimmed
	var result: Dictionary = _new_participant(catalog).prepare({"narrative_checkpoint": _line_checkpoint(), "content_version": 1})
	assert_eq(str(result.get("code")), "NARRATIVE_CONTENT_UNAVAILABLE", "removed event is recoverable")


func test_prepare_fails_closed_on_structurally_broken_checkpoint() -> void:
	var broken := _line_checkpoint()
	broken["boundary"] = {"kind": "line"}
	var result: Dictionary = _new_participant(_catalog()).prepare({"narrative_checkpoint": broken, "content_version": 1})
	assert_false(result.get("ok", false), "broken shape rejects")
	assert_eq(str(result.get("code")), "invalid_narrative_checkpoint", "malformed data is fail-closed, not incompatible")


func test_apply_requires_route_ready_token() -> void:
	_init_bridge()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = participant.prepare({"narrative_checkpoint": _line_checkpoint(), "content_version": 1})
	assert_false(participant.apply_silent(prepared["value"]["narrative_plan"]).get("ok", false), "apply without route token rejects")


func test_revealed_event_starts_and_reveals() -> void:
	var adapter := _init_bridge()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = participant.prepare({"narrative_checkpoint": _line_checkpoint(), "content_version": 1})
	var plan: Dictionary = prepared["value"]["narrative_plan"]
	plan["route_ready_token"] = {"route_id": "main"}
	assert_true(participant.apply_silent(plan).get("ok", false), "apply ok")
	assert_eq(adapter.calls, ["start:2", "reveal"], "starts the exact text event then reveals it")


func test_before_event_stages_without_executing_then_resumes_on_finalize() -> void:
	var adapter := _init_bridge()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = participant.prepare({"narrative_checkpoint": _effect_checkpoint(), "content_version": 1})
	var plan: Dictionary = prepared["value"]["narrative_plan"]
	assert_eq(str(plan["position"]), "before_event", "effect boundary stages its successor")
	assert_eq(int(plan["resume_event_index"]), 2, "resumes at the successor, never replaying the effect")
	plan["route_ready_token"] = {"route_id": "main"}
	assert_true(participant.apply_silent(plan).get("ok", false), "apply ok")
	assert_true(adapter.paused, "execution suspended while staged")
	assert_eq(adapter.calls, ["paused:true", "start:2"], "paused before staging the successor")
	assert_true(participant.finalize().get("ok", false), "finalize ok")
	await get_tree().process_frame
	assert_false(adapter.paused, "deferred resume unpauses exactly once")


func test_rollback_cancels_pending_resume() -> void:
	var adapter := _init_bridge()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = participant.prepare({"narrative_checkpoint": _effect_checkpoint(), "content_version": 1})
	var plan: Dictionary = prepared["value"]["narrative_plan"]
	plan["route_ready_token"] = {"route_id": "main"}
	participant.apply_silent(plan)
	var captured: Dictionary = participant.capture()
	assert_true(participant.rollback_silent(captured.get("value", {}).get("backup", {})).get("ok", false), "rollback ok")
	participant.finalize()
	await get_tree().process_frame
	assert_true(adapter.paused, "cancelled resume never fires after rollback")
