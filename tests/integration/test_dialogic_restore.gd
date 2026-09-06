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
	func start_timeline(path: String, event_index: Variant = 0) -> Dictionary:
		calls.append("start:%s" % event_index)
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


class _RefusingAdapter extends _FakeAdapter:
	func start_timeline(_path: String, _event_index: Variant = 0) -> Dictionary:
		return {"ok": false, "code": &"fixture_start_refused"}
	func capture_restore_state() -> Dictionary:
		return {"ok": true, "value": {"backup": {"paused": paused}}}
	func restore_captured_state(backup: Dictionary) -> Dictionary:
		paused = backup.paused
		return {"ok": true}


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


func test_refused_before_event_start_restores_cache_and_prior_pause_without_a_resume() -> void:
	var adapter := _RefusingAdapter.new()
	assert_true(_bridge.initialize(null, adapter).get("ok", false))
	var old_checkpoint := {"timeline_id": "dormant", "position": "external_route"}
	assert_true(_bridge.apply_restore_silent({"route_ready_token": {}, "position": "external_route",
		"narrative_checkpoint": old_checkpoint}).get("ok", false))
	for prior_pause: bool in [false, true]:
		adapter.paused = prior_pause
		var refused: Dictionary = _bridge.apply_restore_silent({"route_ready_token": {},
			"position": "before_event", "timeline_path": "res://refused.dtl", "resume_event_index": 0,
			"narrative_checkpoint": {"timeline_id": "replacement"}})
		assert_false(refused.get("ok", true))
		assert_false(_bridge.has_active_playback())
		assert_eq(_bridge.get_current_timeline_id(), "dormant")
		assert_eq(_bridge.get_current_timeline_context(), old_checkpoint)
		assert_eq(adapter.paused, prior_pause)
		_bridge.finalize_restore()
		await get_tree().process_frame
		assert_eq(adapter.paused, prior_pause, "failed apply leaves no deferred resume")


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
# =================================================================================================
# Seven-Day Flow Plan 01 Task 7 (dwm-oyo.2): semantic entry restore, prepared, stored and resumed
# WITHOUT production cutover. DEVIATION-14 Rulings 14-A/14-B/14-C/14-D plus Ruling 15-A.
#
# The legacy timeline_id path above is untouched and stays the DEFAULT (Ruling 14-D). The semantic
# branch engages only when the saved checkpoint carries entry_id, and nothing in the repository
# writes one today, so the seam is dormant in practice until Plan 04 lands a producer.
#
# RED DISCIPLINE. The new bridge entries do not exist when these tests are first written, so the
# tests that call them DIRECTLY reach them through has_method plus callv, and their absence fails by
# a NAMED assertion rather than by SCRIPT_LOAD_FAILED. Scoped honestly (reviewer n-11): the tests
# that reach the bridge INDIRECTLY, through participant.prepare(), depend on the participant not
# calling a method that is absent - which held at this task's observed RED, where the semantic
# branch did not exist either and the RED log carried zero SCRIPT ERROR.
#
# DECLARED BEFORE THE RUNS, so neither is discovered as a surprise afterwards:
# (1) test_semantic_restore_is_dormant_for_an_empty_narrative_state pins the legacy default and is
#     GREEN at RED by construction, because the behaviour it pins already ships. It is not
#     decoration: a mutant that makes the semantic branch the default kills it.
# (2) The participant's unfingerprintable-document passthrough has NO fixture. It is reached only
#     when the SHIPPED entry document is absent, unparseable, or refused by CanonicalJsonWriter, and
#     test_dialogic_entry_manifest.gd proves the shipped document is none of those. CORRECTED by the
#     Task 7 reviewer (m-5): an earlier wording here claimed the branch "keeps a code of its own",
#     and that was FALSE - it returns NARRATIVE_CONTENT_UNAVAILABLE exactly as the fingerprint-drift
#     branch beside it does, and the two differ only by message. Since no reachable input drives the
#     branch at all, no mutant on it could be killed by any test whatever code it returned, so the
#     identity claim was doing no work even when it was believed.
# (3) WHICH content_version the validator reports is unfalsifiable THROUGH THE PARTICIPANT, because
#     the participant now refuses any non-positive claim and the bridge refuses any other mismatch,
#     so the record's number and the checkpoint's claim are equal for every input that reaches the
#     report. CORRECTED by the reviewer (M-2): an earlier wording called this unfalsifiable outright,
#     which was false - a checkpoint claiming a NEGATIVE content_version forged the bridge's own
#     fresh-start sentinel, skipped the revalidation, and separated the two. That hole is now closed
#     at the participant and the forged sentinel is pinned by a test below.
# (4) A semantic apply that ALSO ran the legacy apply_restore_silent would not be observable: for a
#     plan carrying no position and no timeline_id the legacy state machine is a no-op that leaves
#     the bridge exactly where it was. The law is stated in the production comment rather than
#     pinned by a test that could not fail.

const ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const FAKE_RUNTIME := preload("res://tests/support/FakeDialogicRuntime.gd")
const ENTRY_MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const FAKE_COMPLETION_PORT := preload("res://tests/support/FakeDialogicPlaybackCompletionPort.gd")

const LAVINIA_ENTRY := "contact.ordinary.lavinia.day1"
const LAVINIA_MASTER := "res://dialogic/timelines/en/day_1.dtl"
const UNKNOWN_ENTRY := "contact.ordinary.nobody.day9"
const RETIRED_ENTRY := "ending.lavinia.true"

## Task 7's plan block says the prepared plan contains ONLY these six, so this is an exact-key set
## and not a minimum.
const SEMANTIC_PLAN_KEYS := ["content_version", "entry_id", "frozen_context",
	"manifest_fingerprint", "stage", "transaction_id"]
## Specification 12.4 and 14.4: a save never persists a physical path or an untrusted label, and a
## scene never inspects one.
const PHYSICAL_LOCATOR_KEYS := ["label", "path", "timeline_id", "timeline_path"]
## The EXACT semantic fields validate_resume_checkpoint may report (Ruling 14-A). Contrast
## resume_entry's own receipt, which does carry path and label to its caller.
const VALIDATED_VALUE_KEYS := ["content_version", "context_fingerprint", "entry_id", "stage",
	"transaction_id"]


## Catalog doubles reached THROUGH the bridge, so the participant's recoverable/fail-closed split
## covers the resolution refusals the real catalog cannot be asked for. Same shape as the doubles in
## test_dialogic_signal_boundary.gd: an inner class with a STATIC get_entry, passed as the bridge's
## catalog Script.
class _MissingMasterCatalog:
	static func get_entry(entry_id: String, _locale: String = "") -> Dictionary:
		return {"ok": true, "value": {
			"entry_id": entry_id, "locale": "en", "requested_locale": "en",
			"path": "res://dialogic/timelines/en/fixture_missing_master.dtl", "label": entry_id,
			"used_fallback": false,
		}}


class _GhostRecordCatalog:
	static func get_entry(entry_id: String, _locale: String = "") -> Dictionary:
		return {"ok": true, "value": {
			"entry_id": entry_id, "locale": "en", "requested_locale": "en",
			"path": "res://dialogic/timelines/en/day_1.dtl", "label": entry_id,
			"used_fallback": false,
		}}


class _NullResolutionCatalog:
	static func get_entry(_entry_id: String, _locale: String = "") -> Variant:
		return null


func _semantic_rig() -> Node:
	var runtime: Node = autofree(FAKE_RUNTIME.new())
	var adapter: RefCounted = ADAPTER.new()
	assert_true(adapter.bind_runtime(runtime).get("ok", false), "the fake runtime binds")
	assert_true(_bridge.initialize(null, adapter).get("ok", false), "the bridge initializes")
	return runtime


func _live_manifest_fingerprint() -> String:
	var loaded: Dictionary = ENTRY_MANIFEST.load_default()
	if not loaded.get("ok", false):
		return ""
	return str(ENTRY_MANIFEST.fingerprint(loaded["value"]))


func _frozen(stage: String, marker: String) -> Dictionary:
	return {"expected_stage": stage, "playback_id": "restore-" + marker, "role": "primary",
		"transaction_id": "tx-" + marker}


func _semantic(stage: String, marker: String, entry_id: String = LAVINIA_ENTRY) -> Dictionary:
	return {
		"content_version": 1,
		"entry_id": entry_id,
		"frozen_context": _frozen(stage, marker),
		"manifest_fingerprint": _live_manifest_fingerprint(),
		"stage": stage,
		"transaction_id": "tx-" + marker,
	}


## The five-key projection the bridge accepts: the six-field plan minus the compatibility field,
## which is discharged at prepare time.
func _five_key(checkpoint: Dictionary) -> Dictionary:
	var projected: Dictionary = checkpoint.duplicate(true)
	projected.erase("manifest_fingerprint")
	return projected


func _prepare_semantic(participant: Object, checkpoint: Dictionary) -> Dictionary:
	return participant.prepare({"narrative_checkpoint": checkpoint, "content_version": 1})


func _sub_dictionary(source: Dictionary, key: String) -> Dictionary:
	var nested: Variant = source.get(key, {})
	return nested if typeof(nested) == TYPE_DICTIONARY else {}


func _plan_of(prepared: Dictionary) -> Dictionary:
	return _sub_dictionary(_sub_dictionary(prepared, "value"), "narrative_plan")


func _apply(participant: Object, plan: Dictionary) -> Dictionary:
	var carried: Dictionary = plan.duplicate(true)
	carried["route_ready_token"] = {"route_id": "main"}
	return participant.apply_silent(carried)


func _sorted_keys(source: Dictionary) -> Array:
	var keys: Array = source.keys()
	keys.sort()
	return keys


func _validate(checkpoint: Dictionary) -> Dictionary:
	var answered: Variant = _bridge.callv(&"validate_resume_checkpoint", [checkpoint, &"canonical"])
	return answered if typeof(answered) == TYPE_DICTIONARY else {}


func _requires_validator() -> bool:
	if _bridge.has_method("validate_resume_checkpoint"):
		return true
	assert_true(false,
		"expected RED: DialogicBridge must declare validate_resume_checkpoint (Ruling 14-A)")
	return false


func test_semantic_restore_is_dormant_for_an_empty_narrative_state() -> void:
	var runtime := _semantic_rig()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = _prepare_semantic(participant, {})
	assert_true(prepared.get("ok", false), str(prepared))
	assert_false(_plan_of(prepared).has("entry_id"),
		"an empty narrative state never takes the semantic branch")
	var legacy: Dictionary = _prepare_semantic(participant, _line_checkpoint())
	assert_true(legacy.get("ok", false), str(legacy))
	assert_false(_plan_of(legacy).has("entry_id"),
		"a legacy timeline checkpoint stays on the legacy branch: the semantic path is opt-in")
	assert_true(participant.finalize().get("ok", false), "finalize ok")
	assert_eq(runtime.calls, [], "a dormant seam resumes nothing")


func test_pending_semantic_entry_restore_prepares_stores_and_resumes_with_a_fresh_token() -> void:
	var runtime := _semantic_rig()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = _prepare_semantic(participant, _semantic("current_entry", "pending"))
	assert_true(prepared.get("ok", false), str(prepared))
	var plan: Dictionary = _plan_of(prepared)
	assert_eq(_sorted_keys(plan), SEMANTIC_PLAN_KEYS,
		"the prepared plan carries exactly the six declared fields: " + str(_sorted_keys(plan)))
	assert_eq(runtime.calls, [], "prepare validates compatibility without starting Dialogic")
	assert_true(_apply(participant, plan).get("ok", false), "apply stores the semantic plan")
	assert_eq(runtime.calls, [], "apply stores the plan; it never starts playback")
	var finalized: Dictionary = participant.finalize()
	assert_true(finalized.get("ok", false), str(finalized))
	var receipt: Dictionary = _sub_dictionary(finalized, "receipt")
	var token := str(receipt.get("playback_token", ""))
	assert_true(token.begins_with("resume-"),
		"finalize mints a FRESH process-local resume token: " + token)
	assert_eq(str(receipt.get("entry_id", "")), LAVINIA_ENTRY,
		"the receipt names the entry the durable checkpoint declared")
	assert_eq(runtime.calls, ["clear:1", "start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]],
		"finalize starts the EXACT registered master and label, exactly once")
	# The staged resume is ONE SHOT: finalize consumes it, so a second finalize can never replay it.
	assert_true(participant.finalize().get("ok", false), "a second finalize is a plain no-op")
	assert_eq(runtime.calls.count("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]), 1,
		"the staged resume was consumed exactly once")


func test_post_commit_continuation_restore_resumes_the_registered_stage() -> void:
	var runtime := _semantic_rig()
	# Both operands of the stage cross-check are pinned. First operand: a checkpoint whose stage
	# contradicts its own frozen expected_stage is malformed data, not unmappable content.
	var drifted: Dictionary = _semantic("post_reply_committed", "continuation")
	drifted["stage"] = "current_entry"
	var refused: Dictionary = _prepare_semantic(_new_participant(_catalog()), drifted)
	assert_false(refused.get("ok", true), "a stage that contradicts the frozen context is refused")
	assert_eq(str(refused.get("code", "")), "invalid_narrative_checkpoint",
		"a self-contradicting checkpoint is fail-closed, never relabelled recoverable")
	# Second operand: the registered continuation stage survives prepare verbatim and resumes.
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = _prepare_semantic(participant,
		_semantic("post_reply_committed", "continuation"))
	assert_true(prepared.get("ok", false), str(prepared))
	var plan: Dictionary = _plan_of(prepared)
	assert_eq(str(plan.get("stage", "")), "post_reply_committed",
		"the registered continuation stage survives prepare verbatim; it is never re-derived")
	assert_eq(str(plan.get("transaction_id", "")), "tx-continuation",
		"the DURABLE transaction id is retained across the restore")
	var completion: RefCounted = FAKE_COMPLETION_PORT.new()
	assert_true(_bridge.configure_playback_completion_port(completion).get("ok", false),
		"the completion port binds")
	assert_true(_apply(participant, plan).get("ok", false), "apply ok")
	assert_true(participant.finalize().get("ok", false), "the registered continuation resumes")
	assert_eq(runtime.calls.count("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]), 1,
		"the master and label are started exactly once")
	# Reviewer m-9: runtime.calls is byte-identical for every stage, so the START is not evidence of
	# WHICH stage resumed. The completion intent carries the stage, so drive the playback to its end
	# and read it there.
	runtime.timeline_ended.emit()
	assert_eq(completion.intents.size(), 1, "the resumed playback completes exactly once")
	if completion.intents.size() == 1:
		assert_eq(str((completion.intents[0] as Dictionary).get("stage", "")), "post_reply_committed",
			"specification 14.3: the bridge resumed at the REGISTERED continuation stage")
		assert_eq(str((completion.intents[0] as Dictionary).get("transaction_id", "")), "tx-continuation",
			"and the DURABLE transaction id survived the restore into the completion intent")


func test_incompatible_manifest_fingerprint_is_recoverable_and_starts_nothing() -> void:
	var runtime := _semantic_rig()
	var drifted: Dictionary = _semantic("current_entry", "drift")
	drifted["manifest_fingerprint"] = "sha256:" + "0".repeat(64)
	var result: Dictionary = _prepare_semantic(_new_participant(_catalog()), drifted)
	assert_false(result.get("ok", true), "a drifted manifest fingerprint refuses")
	assert_eq(str(result.get("code", "")), "NARRATIVE_CONTENT_UNAVAILABLE",
		"manifest drift is RECOVERABLE, so SaveManager may try an earlier whole bundle")
	assert_eq(runtime.calls, [], "an incompatible bundle starts nothing")


func test_missing_and_retired_entries_are_recoverable_and_start_nothing() -> void:
	var runtime := _semantic_rig()
	for entry_id: String in [UNKNOWN_ENTRY, RETIRED_ENTRY]:
		var result: Dictionary = _prepare_semantic(_new_participant(_catalog()),
			_semantic("current_entry", "missing", entry_id))
		assert_false(result.get("ok", true), "%s must not resolve" % entry_id)
		assert_eq(str(result.get("code", "")), "NARRATIVE_CONTENT_UNAVAILABLE",
			"%s is unmappable content, not malformed bytes" % entry_id)
	assert_eq(runtime.calls, [],
		"specification 14.4: unmappable content never substitutes Alone, a day start or another route")


func test_a_stale_content_version_is_recoverable_content() -> void:
	var runtime := _semantic_rig()
	var stale: Dictionary = _semantic("current_entry", "stale")
	stale["content_version"] = 999
	var refused: Dictionary = _prepare_semantic(_new_participant(_catalog()), stale)
	assert_false(refused.get("ok", true), "a stale content_version refuses")
	assert_eq(str(refused.get("code", "")), "NARRATIVE_CONTENT_UNAVAILABLE",
		"a record that moved on is unmappable CONTENT, so an earlier bundle may still load")
	assert_eq(runtime.calls, [], "a stale bundle starts nothing")


func test_every_bridge_resolution_refusal_is_recoverable_content() -> void:
	# One catalog double per resolution refusal a real catalog cannot be made to produce, so the
	# recoverable half of the content-code list is pinned entry by entry instead of as a block.
	for probe: Array in [
			[_MissingMasterCatalog, LAVINIA_ENTRY, "entry_master_missing"],
			[_GhostRecordCatalog, UNKNOWN_ENTRY, "entry_record_missing"],
			[_NullResolutionCatalog, LAVINIA_ENTRY, "entry_resolution_failed"],
		]:
		var runtime: Node = autofree(FAKE_RUNTIME.new())
		var adapter: RefCounted = ADAPTER.new()
		assert_true(adapter.bind_runtime(runtime).get("ok", false), "the fake runtime binds")
		var bridge: Node = BRIDGE.new()
		add_child_autofree(bridge)
		assert_true(bridge.initialize(probe[0], adapter).get("ok", false), "the bridge initializes")
		var participant: Object = PARTICIPANT.new(bridge, _catalog())
		var result: Dictionary = participant.prepare({
			"narrative_checkpoint": _semantic("current_entry", "resolve", str(probe[1])),
			"content_version": 1})
		assert_eq(str(result.get("code", "")), "NARRATIVE_CONTENT_UNAVAILABLE",
			"%s is recoverable content, not malformed bytes" % str(probe[2]))
		# Reviewer m-7: entry_master_missing's own message IS the physical path, so forwarding it
		# verbatim would re-admit a locator through the error channel that 12.4 keeps out of the plan.
		assert_false(str(result.get("message", "")).contains("res://"),
			"a refusal never hands its caller a physical path: " + str(probe[2]))
		assert_true(str(result.get("message", "")).contains(str(probe[2])),
			"and it names the refusal it is reporting")
		assert_eq(runtime.calls, [], "a refused resolution starts nothing: " + str(probe[2]))


func test_a_checkpoint_carrying_a_physical_locator_is_refused_fail_closed() -> void:
	var runtime := _semantic_rig()
	for key: String in PHYSICAL_LOCATOR_KEYS:
		var injected: Dictionary = _semantic("current_entry", "inject")
		injected[key] = LAVINIA_MASTER
		var result: Dictionary = _prepare_semantic(_new_participant(_catalog()), injected)
		assert_false(result.get("ok", true), "a checkpoint carrying %s is refused" % key)
		assert_eq(str(result.get("code", "")), "invalid_narrative_checkpoint",
			"a persisted physical locator is malformed data, not unmappable content: " + key)
		assert_true(str(result.get("message", "")).contains(key),
			"the locator law names the offending key, so it cannot be mistaken for the key-set law")
	# The other law that shares this code is the exact-six-key set. It names ITSELF, so neither
	# branch can be deleted and answered by its sibling.
	var short: Dictionary = _semantic("current_entry", "short")
	short.erase("manifest_fingerprint")
	var shorted: Dictionary = _prepare_semantic(_new_participant(_catalog()), short)
	assert_eq(str(shorted.get("code", "")), "invalid_narrative_checkpoint",
		"a semantic checkpoint missing a declared field is malformed")
	assert_true(str(shorted.get("message", "")).contains("manifest_fingerprint"),
		"the exact-six-key law names the field set it enforces")
	# Specification 12.3: undeclared extra fields are rejected, so the key set is closed on BOTH
	# sides and not merely a required minimum.
	var extra: Dictionary = _semantic("current_entry", "extra")
	extra["undeclared"] = true
	var refused: Dictionary = _prepare_semantic(_new_participant(_catalog()), extra)
	assert_eq(str(refused.get("code", "")), "invalid_narrative_checkpoint",
		"an undeclared extra field is rejected, not tolerated")
	assert_eq(runtime.calls, [], "a rejected checkpoint starts nothing")


func test_the_prepared_plan_and_the_validator_report_semantic_fields_only() -> void:
	_semantic_rig()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = _prepare_semantic(participant, _semantic("current_entry", "pure"))
	assert_true(prepared.get("ok", false), str(prepared))
	var plan: Dictionary = _plan_of(prepared)
	for key: String in PHYSICAL_LOCATOR_KEYS:
		assert_false(plan.has(key), "the prepared plan never carries " + key)
	if not _requires_validator():
		return
	var validated: Dictionary = _validate(_five_key(_semantic("current_entry", "pure")))
	assert_true(validated.get("ok", false), str(validated))
	var reported: Dictionary = _sub_dictionary(validated, "value")
	assert_eq(_sorted_keys(reported), VALIDATED_VALUE_KEYS,
		"the validator reports SEMANTIC fields only: " + str(_sorted_keys(reported)))
	assert_eq(str(validated.get("code", "")), "validated", "and answers in its own named envelope")
	# Reviewer m-6: the RECEIPT is the other channel a locator could leave by, and an unpinned empty
	# dictionary is exactly where one would hide.
	assert_eq(_sorted_keys(_sub_dictionary(validated, "receipt")), [],
		"the pure validator hands its caller an EMPTY receipt, never the resolved locator")
	assert_eq(str(reported.get("entry_id", "")), LAVINIA_ENTRY, "it names the entry it resolved")
	# The prepared plan carries its OWN copy of the frozen context. A caller that keeps mutating the
	# checkpoint it handed in must not be able to change a plan that has ALREADY been validated -
	# the same law DialogicBridge._entry_record carries, and for the same reason.
	var source: Dictionary = _semantic("current_entry", "alias")
	var aliased: Dictionary = _prepare_semantic(_new_participant(_catalog()), source)
	assert_true(aliased.get("ok", false), str(aliased))
	(source["frozen_context"] as Dictionary)["playback_id"] = "mutated-after-prepare"
	assert_eq(str(_sub_dictionary(_plan_of(aliased), "frozen_context").get("playback_id", "")),
		"restore-alias", "mutating the input checkpoint never reaches the validated plan")
	# IDENTITY, not occurrence. The digest the validator previews must be the EXACT one the playback
	# path later stores, which is the whole reason both compose the same private derivation. A field
	# that is merely PRESENT would let a constant satisfy the key-set assertion above.
	var previewed := str(reported.get("context_fingerprint", ""))
	assert_eq(previewed.length(), 64, "the previewed digest is 64 characters: " + previewed)
	var resumed: Dictionary = _bridge.resume_entry(_five_key(_semantic("current_entry", "pure")))
	assert_true(resumed.get("ok", false), str(resumed))
	assert_eq(str(_sub_dictionary(resumed, "receipt").get("context_fingerprint", "")), previewed,
		"the validator previews the EXACT digest the playback path stores")
	# The reported stage and transaction are the CHECKPOINT's own, not constants. Every checkpoint
	# reaching the validator elsewhere in this suite uses "current_entry", so without a DISTINCT one
	# a hardcoded stage would satisfy every other assertion here.
	var elsewhere: Dictionary = _sub_dictionary(
		_validate(_five_key(_semantic("post_reply_committed", "elsewhere"))), "value")
	assert_eq(str(elsewhere.get("stage", "")), "post_reply_committed",
		"the validator reports the checkpoint's own stage")
	assert_eq(str(elsewhere.get("transaction_id", "")), "tx-elsewhere",
		"and the checkpoint's own durable transaction id")


func test_the_validator_revalidates_without_starting_dialogic() -> void:
	var runtime := _semantic_rig()
	if not _requires_validator():
		return
	var accepted: Dictionary = _validate(_five_key(_semantic("current_entry", "pure")))
	assert_true(accepted.get("ok", false), str(accepted))
	assert_eq(int(_sub_dictionary(accepted, "value").get("content_version", -1)), 1,
		"the validated content_version reaches the caller")
	assert_eq(runtime.calls, [], "a pure validator starts nothing")
	# prepare and finalize must share ONE refusal vocabulary, so the validator speaks resume_entry's.
	var drifted: Dictionary = _five_key(_semantic("current_entry", "pure"))
	drifted["content_version"] = 999
	assert_eq(str(_validate(drifted).get("code", "")), "entry_content_version_mismatch",
		"a stale content_version is refused by the same code resume_entry uses")
	var short_keys: Dictionary = _five_key(_semantic("current_entry", "pure"))
	short_keys.erase("stage")
	assert_eq(str(_validate(short_keys).get("code", "")), "invalid_resume_checkpoint",
		"the five-key law is the bridge's own, not a second copy")
	var unknown: Dictionary = _five_key(_semantic("current_entry", "pure", UNKNOWN_ENTRY))
	assert_eq(str(_validate(unknown).get("code", "")), "ENTRY_MANIFEST_UNKNOWN_ENTRY",
		"the owning validator's envelope reaches the caller verbatim")
	assert_eq(runtime.calls, [], "no refusal starts anything either")


func test_a_forged_fresh_start_sentinel_is_refused_before_it_reaches_the_bridge() -> void:
	# Reviewer M-2. _begin_entry_playback treats a NEGATIVE expected_version as "fresh start" and
	# skips the record revalidation entirely, so a saved content_version below zero would validate and
	# play a bundle that is incompatible by construction. The participant refuses it at the trust
	# boundary, and the bridge's sentinel is left exactly as Task 5 shipped it.
	var runtime := _semantic_rig()
	if not _requires_validator():
		return
	for forged: int in [-1, 0]:
		var checkpoint: Dictionary = _semantic("current_entry", "forged")
		checkpoint["content_version"] = forged
		var refused: Dictionary = _prepare_semantic(_new_participant(_catalog()), checkpoint)
		assert_false(refused.get("ok", true), "a content_version of %d is refused" % forged)
		assert_eq(str(refused.get("code", "")), "invalid_narrative_checkpoint",
			"a forged sentinel is MALFORMED data, not merely unmappable content: %d" % forged)
	# And the sentinel really is what makes it dangerous: straight at the bridge, -1 is accepted and
	# the reported content_version is the RECORD's, not the claim's - which is what makes claim (3)
	# in this suite's header a scoped statement rather than an excuse.
	var sentinel: Dictionary = _five_key(_semantic("current_entry", "forged"))
	sentinel["content_version"] = -1
	var admitted: Dictionary = _validate(sentinel)
	assert_true(admitted.get("ok", false), str(admitted))
	assert_eq(int(_sub_dictionary(admitted, "value").get("content_version", -99)), 1,
		"the bridge reports the RECORD's version, which is why the participant must refuse the forgery")
	assert_eq(runtime.calls, [], "neither the refusal nor the validation started anything")


func test_a_semantic_checkpoint_with_a_malformed_primitive_is_refused_fail_closed() -> void:
	# Reviewer M-1. The bridge type-checks only frozen_context, so an indexed str()/int() on a
	# corrupt Variant would FAULT rather than refuse. Specification 14.4 requires rejection.
	var runtime := _semantic_rig()
	for probe: Array in [
			["entry_id", null], ["entry_id", 7], ["entry_id", ""],
			["stage", {}], ["transaction_id", []], ["manifest_fingerprint", 3],
			["frozen_context", "not-a-dictionary"], ["content_version", null],
			["content_version", "1"],
		]:
		var checkpoint: Dictionary = _semantic("current_entry", "malformed")
		checkpoint[str(probe[0])] = probe[1]
		var refused: Dictionary = _prepare_semantic(_new_participant(_catalog()), checkpoint)
		assert_eq(str(refused.get("code", "")), "invalid_narrative_checkpoint",
			"a malformed %s is rejected, never faulted on: %s" % [str(probe[0]), str(probe[1])])
	# stage and transaction_id would otherwise be caught by the bridge's cross-checks, but ONLY
	# because a corrupt value's str() form differs from the frozen one. Make the two AGREE while
	# staying non-String and the participant's own guard is the only thing left standing.
	for key: String in ["stage", "transaction_id"]:
		var agreeing: Dictionary = _semantic("current_entry", "agree")
		agreeing[key] = 7
		var frozen_key := "expected_stage" if key == "stage" else "transaction_id"
		(agreeing["frozen_context"] as Dictionary)[frozen_key] = 7
		var refused_agreeing: Dictionary = _prepare_semantic(_new_participant(_catalog()), agreeing)
		assert_eq(str(refused_agreeing.get("code", "")), "invalid_narrative_checkpoint",
			"a non-String %s is refused even when it AGREES with its frozen context" % key)
	assert_eq(runtime.calls, [], "malformed bytes start nothing")


func test_a_standing_playback_is_refused_at_apply_before_the_point_of_no_return() -> void:
	# Ruling 15-B, from reviewer M-3. SaveManager commits its checkpoint journal BETWEEN the apply
	# loop and the finalize loop, so the refusal owed to a live playback must surface at apply.
	var runtime := _semantic_rig()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = _prepare_semantic(participant, _semantic("current_entry", "standing"))
	assert_true(prepared.get("ok", false),
		"prepare stays activity-blind: a compatible bundle is never rejected for a transient state")
	var started: Dictionary = _bridge.start_entry(LAVINIA_ENTRY, _frozen("current_entry", "live"))
	assert_true(started.get("ok", false), str(started))
	var applied: Dictionary = _apply(participant, _plan_of(prepared))
	assert_false(applied.get("ok", true), "a standing playback refuses the semantic apply")
	assert_eq(str(applied.get("code", "")), "narrative_playback_active",
		"the refusal is fail-closed and names itself, so SaveManager rolls back before it commits")
	assert_true(participant.finalize().get("ok", false), "nothing was staged, so finalize is a no-op")
	assert_eq(runtime.calls.count("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]), 1,
		"the standing playback is untouched and no second one began")


func test_has_active_playback_reports_both_vocabularies() -> void:
	# BOTH operands of a two-operand predicate. A one-sided fixture would leave a guaranteed survivor.
	_semantic_rig()
	if not _bridge.has_method("has_active_playback"):
		assert_true(false,
			"expected RED: DialogicBridge must declare has_active_playback (Ruling 15-B)")
		return
	assert_false(bool(_bridge.call(&"has_active_playback")), "an idle bridge has no standing playback")
	assert_true(_bridge.start_entry(LAVINIA_ENTRY, _frozen("current_entry", "probe")).get("ok", false),
		"a semantic entry starts")
	assert_true(bool(_bridge.call(&"has_active_playback")), "a live semantic ENTRY is standing")
	assert_true(_bridge.abort_current_entry(&"probe_done").get("ok", false), "and can be aborted")
	assert_false(bool(_bridge.call(&"has_active_playback")), "after which nothing is standing again")
	var ending: Dictionary = _bridge.start_ending_id("ending.sylvia.special", {
		"expected_stage": "PRIMARY_PENDING", "playback_id": "run:primary",
		"role": "primary", "transaction_id": "run:primary:complete"})
	assert_true(ending.get("ok", false), str(ending))
	assert_true(bool(_bridge.call(&"has_active_playback")), "a live ENDING playback is standing too")


func test_the_validator_admits_a_compatible_bundle_while_an_entry_is_active() -> void:
	var runtime := _semantic_rig()
	if not _requires_validator():
		return
	var started: Dictionary = _bridge.start_entry(LAVINIA_ENTRY, _frozen("current_entry", "standing"))
	assert_true(started.get("ok", false), str(started))
	var validated: Dictionary = _validate(_five_key(_semantic("current_entry", "while-active")))
	assert_true(validated.get("ok", false),
		"activity is a transient runtime precondition, not a compatibility property of the save: "
		+ str(validated))
	assert_eq(runtime.calls.count("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]), 1,
		"validating while an entry is active started nothing of its own")


func test_an_active_entry_at_finalize_returns_the_bridge_refusal_unchanged() -> void:
	var runtime := _semantic_rig()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = _prepare_semantic(participant, _semantic("current_entry", "active"))
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(_apply(participant, _plan_of(prepared)).get("ok", false), "apply ok")
	var started: Dictionary = _bridge.start_entry(LAVINIA_ENTRY, _frozen("current_entry", "standing"))
	assert_true(started.get("ok", false), str(started))
	var finalized: Dictionary = participant.finalize()
	assert_false(finalized.get("ok", true), "a live entry blocks the semantic finalize")
	assert_eq(str(finalized.get("code", "")), "entry_already_active",
		"the bridge's refusal reaches SaveManager UNCHANGED; nothing is substituted")
	assert_eq(runtime.calls.count("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]), 1,
		"the standing playback is the only one; the refused resume started nothing")


func test_rollback_cancels_a_pending_semantic_resume() -> void:
	var runtime := _semantic_rig()
	var cancelled: Object = _new_participant(_catalog())
	var prepared: Dictionary = _prepare_semantic(cancelled, _semantic("current_entry", "rollback"))
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(_apply(cancelled, _plan_of(prepared)).get("ok", false), "apply ok")
	var captured: Dictionary = cancelled.capture()
	var backup: Dictionary = _sub_dictionary(_sub_dictionary(captured, "value"), "backup")
	assert_true(cancelled.rollback_silent(backup).get("ok", false), "rollback ok")
	assert_true(cancelled.finalize().get("ok", false), "finalize after a rollback is a no-op")
	assert_eq(runtime.calls, [], "a rolled-back restore never resumes the entry")
	# The other operand: without the rollback the very same plan DOES resume, so the assertion above
	# is a cancellation law rather than an accident of a seam that never fires.
	var resumed: Object = _new_participant(_catalog())
	var second: Dictionary = _prepare_semantic(resumed, _semantic("current_entry", "rollback"))
	assert_true(_apply(resumed, _plan_of(second)).get("ok", false), "apply ok")
	assert_true(resumed.finalize().get("ok", false), "an uncancelled restore resumes")
	assert_eq(runtime.calls.count("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]), 1,
		"the uncancelled restore is the ONLY one that started playback")


func test_a_refused_rollback_still_cancels_the_staged_semantic_resume() -> void:
	var runtime := _semantic_rig()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = _prepare_semantic(participant, _semantic("current_entry", "badbackup"))
	assert_true(prepared.get("ok", false), str(prepared))
	assert_true(_apply(participant, _plan_of(prepared)).get("ok", false), "apply ok")
	var rolled: Dictionary = participant.rollback_silent({})
	assert_false(rolled.get("ok", true), "a malformed backup still refuses")
	assert_eq(str(rolled.get("code", "")), "invalid_narrative_backup",
		"the owner's refusal reaches the caller unchanged")
	assert_true(participant.finalize().get("ok", false),
		"finalize after a refused rollback is a no-op")
	assert_eq(runtime.calls, [],
		"a rollback ATTEMPT cancels the staged resume whether or not the backup was well formed")
	# Only the pending plan was cancelled: the participant itself is still usable afterwards.
	var again: Dictionary = _prepare_semantic(participant, _semantic("current_entry", "badbackup"))
	assert_true(_apply(participant, _plan_of(again)).get("ok", false), "apply ok")
	assert_true(participant.finalize().get("ok", false), "a freshly applied plan resumes")
	assert_eq(runtime.calls.count("start:%s:%s" % [LAVINIA_MASTER, LAVINIA_ENTRY]), 1,
		"exactly one resume, the one that was never cancelled")


func test_manifest_fingerprint_is_the_shipped_entry_document_digest() -> void:
	_semantic_rig()
	var participant: Object = _new_participant(_catalog())
	var prepared: Dictionary = _prepare_semantic(participant, _semantic("current_entry", "fp"))
	assert_true(prepared.get("ok", false),
		"the live document fingerprint is the one prepare compares against: " + str(prepared))
	var reported := str(_plan_of(prepared).get("manifest_fingerprint", ""))
	assert_true(reported.begins_with("sha256:"), "the digest names its own algorithm (Ruling 15-A)")
	assert_eq(reported.length(), 71, "the reported fingerprint is 71 characters")
	var loaded: Dictionary = ENTRY_MANIFEST.load_default()
	assert_true(loaded.get("ok", false), str(loaded))
	assert_eq(reported, str(ENTRY_MANIFEST.fingerprint(loaded["value"])),
		"the SHIPPED document producer is reused, never a second definition of the same value")
