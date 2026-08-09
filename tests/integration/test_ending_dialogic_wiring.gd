extends "res://addons/gut/test.gd"

# DialogicBridge ending/postscript playback (dwm-p2r.8, Plan-05 Task 2 Step 2.3). Exercises
# manifest-resolved starts, tokenized completion/failure, and the frozen rejections. Uses an
# injected fake runtime adapter so no real Dialogic timeline is started.

const BRIDGE := preload("res://autoload/DialogicBridge.gd")

var _bridge: Node


class _FakeAdapter extends RefCounted:
	signal timeline_started_signal
	signal timeline_ended_signal
	signal event_handled_signal(resource)
	signal runtime_signal_event(argument)
	signal preference_reapply_requested
	var calls: Array = []
	var halted := false
	func start_timeline(path: String, event_index: int = 0) -> Dictionary:
		calls.append("start:%s:%d" % [path, event_index])
		return {"ok": true, "code": &"ok", "value": {"path": path, "event_index": event_index}}
	func halt_with_error(result: Dictionary) -> Dictionary:
		halted = true
		return {"ok": false, "code": &"runtime_halted", "details": result}
	func capture_checkpoint() -> Dictionary:
		return {"ok": true, "code": &"ok", "value": {}}
	func finish() -> void:
		timeline_ended_signal.emit()


func before_each() -> void:
	_bridge = BRIDGE.new()
	add_child_autofree(_bridge)


func _init_bridge() -> _FakeAdapter:
	var adapter := _FakeAdapter.new()
	var result: Dictionary = _bridge.initialize(null, adapter)
	assert_true(result.get("ok", false), str(result))
	return adapter


func _primary_ctx() -> Dictionary:
	return {"playback_id": "run:primary", "transaction_id": "run:primary:complete", "expected_stage": &"PRIMARY_PENDING", "role": "primary"}


func _epilogue_ctx() -> Dictionary:
	return {"playback_id": "run:epilogue", "transaction_id": "run:epilogue:complete", "expected_stage": &"PRIMARY_PLAYED", "role": "epilogue"}


func test_initialize_loads_ending_manifest() -> void:
	var adapter := _init_bridge()
	assert_not_null(adapter, "adapter bound")
	assert_true(_bridge.has_method("start_ending_id"), "bridge exposes start_ending_id")
	assert_true(_bridge.has_method("start_postscript_id"), "bridge exposes start_postscript_id")


func test_start_primary_returns_six_field_receipt() -> void:
	var adapter := _init_bridge()
	var result: Dictionary = _bridge.start_ending_id("ending.sylvia.special", _primary_ctx())
	assert_true(result.get("ok", false), str(result))
	assert_eq(str(result["code"]), "started")
	assert_eq(result["value"], {}, "value is exactly empty")
	var receipt: Dictionary = result["receipt"]
	assert_eq(receipt.keys().size(), 6, "exactly six receipt fields")
	assert_eq(str(receipt["ending_id"]), "ending.sylvia.special")
	assert_eq(str(receipt["role"]), "primary")
	assert_eq(str(receipt["timeline_id"]), "ending.sylvia")
	assert_eq(str(receipt["label"]), "ending.sylvia.special")
	assert_eq(receipt["started"], true)
	assert_false(str(receipt["playback_token"]).is_empty(), "opaque token issued")
	assert_eq(adapter.calls.size(), 1, "runtime started once")


func test_start_epilogue_resolves_manifest() -> void:
	_init_bridge()
	var result: Dictionary = _bridge.start_ending_id("ending.priscilla_lavinia", _epilogue_ctx())
	assert_true(result.get("ok", false), str(result))
	assert_eq(str(result["receipt"]["role"]), "epilogue")


func test_unknown_and_retired_ids_reject() -> void:
	var adapter := _init_bridge()
	for bad_id in ["ending.nope", "ending.priscilla.true", "ending.lavinia.true", "ending.sylvia.true"]:
		var result: Dictionary = _bridge.start_ending_id(bad_id, _primary_ctx())
		assert_false(result.get("ok", false), bad_id + " must reject")
		assert_false(result.has("receipt"), "no receipt on failure for " + bad_id)
	assert_eq(adapter.calls.size(), 0, "no runtime start for rejected ids")


func test_role_mismatch_rejects() -> void:
	_init_bridge()
	# postscript id cannot be started through the EndingPlan resolver
	assert_false(_bridge.start_ending_id("ending.priscilla.observation", _primary_ctx()).get("ok", false), "postscript via ending resolver rejects")
	# primary id with an epilogue context role
	assert_false(_bridge.start_ending_id("ending.alone", _epilogue_ctx()).get("ok", false), "role mismatch rejects")


func test_invalid_context_keys_reject() -> void:
	_init_bridge()
	var short_ctx := _primary_ctx()
	short_ctx.erase("transaction_id")
	assert_false(_bridge.start_ending_id("ending.alone", short_ctx).get("ok", false), "missing context key rejects")


func test_completion_emits_tokenized_finish() -> void:
	var adapter := _init_bridge()
	var finished: Array = []
	_bridge.ending_playback_finished.connect(func(token: String, ending_id: String, receipt: Dictionary) -> void:
		finished.append({"token": token, "ending_id": ending_id, "receipt": receipt}))
	var started: Dictionary = _bridge.start_ending_id("ending.alone", _primary_ctx())
	adapter.finish()
	assert_eq(finished.size(), 1, "one completion")
	assert_eq(finished[0]["token"], started["receipt"]["playback_token"], "same token")
	assert_eq(str(finished[0]["ending_id"]), "ending.alone")
	assert_false(str(finished[0]["receipt"]["receipt_id"]).is_empty(), "completion receipt id")


func test_invalid_runtime_event_halts_and_fails_playback() -> void:
	var adapter := _init_bridge()
	var failures: Array = []
	var validation: Array = []
	_bridge.ending_playback_failed.connect(func(token: String, ending_id: String, result: Dictionary) -> void:
		failures.append({"token": token, "ending_id": ending_id, "result": result}))
	_bridge.narrative_validation_failed.connect(func(result: Dictionary) -> void: validation.append(result))
	var started: Dictionary = _bridge.start_ending_id("ending.alone", _primary_ctx())
	adapter.runtime_signal_event.emit({"kind": "not_a_registered_kind"})
	assert_eq(validation.size(), 1, "narrative_validation_failed emitted")
	assert_true(adapter.halted, "runtime halted through the adapter")
	assert_eq(failures.size(), 1, "active ending playback failed")
	assert_eq(failures[0]["token"], started["receipt"]["playback_token"], "same token")


func test_postscript_start_accepts_only_postscript_role() -> void:
	var adapter := _init_bridge()
	var result: Dictionary = _bridge.start_postscript_id("ending.lavinia.observation")
	assert_true(result.get("ok", false), str(result))
	assert_eq(str(result["receipt"]["role"]), "postscript")
	assert_eq(str(result["receipt"]["timeline_id"]), "ending.lavinia")
	for bad_id in ["ending.alone", "ending.priscilla_lavinia", "ending.sylvia.true", "ending.nope"]:
		assert_false(_bridge.start_postscript_id(bad_id).get("ok", false), bad_id + " must reject as postscript")


func test_postscript_finishes_with_its_own_token() -> void:
	var adapter := _init_bridge()
	var finished: Array = []
	_bridge.ending_playback_finished.connect(func(token: String, ending_id: String, receipt: Dictionary) -> void:
		finished.append(token))
	var started: Dictionary = _bridge.start_postscript_id("ending.priscilla.observation")
	adapter.finish()
	assert_eq(finished.size(), 1, "postscript finish emitted")
	assert_eq(finished[0], started["receipt"]["playback_token"], "same token")


func test_configure_narrative_checkpoint_port_identity() -> void:
	_init_bridge()
	var port := _StubPort.new()
	var first: Dictionary = _bridge.configure_narrative_checkpoint_port(port)
	assert_true(first.get("ok", false), str(first))
	assert_eq(int(first["value"]["port_instance_id"]), port.get_instance_id(), "retains port id")
	assert_true(_bridge.configure_narrative_checkpoint_port(port).get("ok", false), "idempotent same port")
	assert_false(_bridge.configure_narrative_checkpoint_port(_StubPort.new()).get("ok", false), "replacement rejected")


class _StubPort extends RefCounted:
	func configure(_a: Object, _b: Dictionary) -> Dictionary: return {"ok": true}
	func commit_current_boundary(_r: Dictionary) -> Dictionary: return {"ok": true, "value": {"checkpoint_id": "c:1", "duplicate": false}, "receipt": {}}
	func preview_checkpoint_id(_r: String) -> Dictionary: return {"ok": true, "value": {"checkpoint_id": "c:1"}}
	func capture() -> Dictionary: return {"ok": true, "value": {"backup": {}}}
	func prepare_candidate(_o: StringName, _s: Dictionary, _t: String, _src: String, _k: StringName, _e: String) -> Dictionary: return {"ok": true}
	func commit(_o: StringName, _c: Dictionary) -> Dictionary: return {"ok": true}
	func rollback(_o: StringName, _b: Dictionary) -> Dictionary: return {"ok": true}
