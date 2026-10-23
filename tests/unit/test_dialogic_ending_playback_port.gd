extends "res://addons/gut/test.gd"

# RED-first via dynamic load (dwm-p2r.8, Plan-05 Task 2 Step 2.1/2.3). Proves the .7 primary/
# epilogue adapter passes the four-key context unchanged, returns the seven-field immediate-start
# receipt with value:{}, emits completion/failure only for its own token, and — on async failure —
# clears the binding so the next identical request starts a fresh playback.

const PORT_PATH := "res://scripts/application/ending/DialogicEndingPlaybackPort.gd"

var _port_script: GDScript


class _FakeBridge extends RefCounted:
	signal ending_playback_finished(playback_token: String, ending_id: String, receipt: Dictionary)
	signal ending_playback_failed(playback_token: String, ending_id: String, result: Dictionary)
	var start_calls: Array = []
	var fail_start := false
	var _counter := 0
	func start_ending_id(ending_id: String, context: Dictionary) -> Dictionary:
		start_calls.append({"ending_id": ending_id, "context": context.duplicate(true)})
		if fail_start:
			return {"ok": false, "code": &"unknown_ending_id", "message": ending_id, "details": {}}
		_counter += 1
		return {"ok": true, "code": &"started", "value": {}, "receipt": {
			"playback_token": "token-%d" % _counter, "ending_id": ending_id,
			"role": context.get("role"), "timeline_id": "ending.x", "label": ending_id, "started": true}}
	func finish(token: String, ending_id: String, receipt: Dictionary) -> void:
		ending_playback_finished.emit(token, ending_id, receipt)
	func fail_playback(token: String, ending_id: String, result: Dictionary) -> void:
		ending_playback_failed.emit(token, ending_id, result)


func before_all() -> void:
	if ResourceLoader.exists(PORT_PATH, "Script"):
		_port_script = load(PORT_PATH)


func _primary_ctx() -> Dictionary:
	return {"playback_id": "run:primary", "transaction_id": "run:primary:complete", "expected_stage": &"PRIMARY_PENDING", "role": "primary"}


func _epilogue_ctx() -> Dictionary:
	return {"playback_id": "run:epilogue", "transaction_id": "run:epilogue:complete", "expected_stage": &"PRIMARY_PLAYED", "role": "epilogue"}


func _new_port(bridge: RefCounted) -> Object:
	var port: Object = _port_script.new()
	port.initialize(bridge)
	return port


func test_port_script_exists() -> void:
	assert_true(ResourceLoader.exists(PORT_PATH, "Script"), "missing %s" % PORT_PATH)


func test_initialize_accepts_bridge_and_rejects_replacement() -> void:
	if _port_script == null:
		return
	var bridge := _FakeBridge.new()
	var port: Object = _port_script.new()
	assert_true(port.initialize(bridge).get("ok", false), "first initialize")
	assert_true(port.is_ready(), "ready after initialize")
	assert_true(port.initialize(bridge).get("ok", false), "idempotent same bridge")
	assert_false(port.initialize(_FakeBridge.new()).get("ok", false), "replacement rejected")


func test_initialize_rejects_bad_bridge() -> void:
	if _port_script == null:
		return
	assert_false(_port_script.new().initialize(RefCounted.new()).get("ok", false), "bridge missing api rejected")


func test_start_primary_returns_immediate_start_receipt() -> void:
	if _port_script == null:
		return
	var bridge := _FakeBridge.new()
	var port: Object = _new_port(bridge)
	var result: Dictionary = port.start_ending_id("ending.alone", _primary_ctx())
	assert_true(result.get("ok", false), str(result))
	assert_eq(str(result["code"]), "started")
	assert_eq(result["value"], {}, "value is exactly empty")
	assert_eq(str(result["receipt"]["ending_id"]), "ending.alone")
	assert_eq(str(result["receipt"]["role"]), "primary")
	assert_eq(result["receipt"]["started"], true)
	assert_eq(str(result["receipt"]["playback_token"]), "token-1")
	assert_eq(bridge.start_calls.size(), 1, "bridge called once")
	assert_eq(bridge.start_calls[0]["context"], _primary_ctx(), "context passed unchanged")


func test_start_epilogue_ok() -> void:
	if _port_script == null:
		return
	assert_true(_new_port(_FakeBridge.new()).start_ending_id("ending.priscilla_lavinia", _epilogue_ctx()).get("ok", false))


func test_start_rejects_illegal_triples() -> void:
	if _port_script == null:
		return
	var bridge := _FakeBridge.new()
	var port: Object = _new_port(bridge)
	var postscript_ctx := _primary_ctx()
	postscript_ctx["role"] = "postscript"
	assert_false(port.start_ending_id("ending.priscilla.observation", postscript_ctx).get("ok", false), "postscript rejected")
	var wrong_stage := _primary_ctx()
	wrong_stage["expected_stage"] = &"PRIMARY_PLAYED"
	assert_false(port.start_ending_id("ending.alone", wrong_stage).get("ok", false), "wrong stage rejected")
	assert_false(port.start_ending_id("ending.alone", _epilogue_ctx()).get("ok", false), "epilogue role with primary id rejected")
	assert_eq(bridge.start_calls.size(), 0, "no illegal triple reaches the bridge")


func test_synchronous_bridge_failure_creates_no_binding() -> void:
	if _port_script == null:
		return
	var bridge := _FakeBridge.new()
	bridge.fail_start = true
	var port: Object = _new_port(bridge)
	var result: Dictionary = port.start_ending_id("ending.alone", _primary_ctx())
	assert_false(result.get("ok", true), "bridge failure surfaced")
	assert_false(result.has("receipt"), "no receipt on failure")
	bridge.fail_start = false
	assert_true(port.start_ending_id("ending.alone", _primary_ctx()).get("ok", false), "fresh start after failure")


func test_completion_emits_playback_completed() -> void:
	if _port_script == null:
		return
	var bridge := _FakeBridge.new()
	var port: Object = _new_port(bridge)
	var captured: Array = []
	port.playback_completed.connect(func(completion: Dictionary) -> void: captured.append(completion))
	port.start_ending_id("ending.alone", _primary_ctx())
	bridge.finish("token-1", "ending.alone", {"receipt_id": "rcpt-1"})
	assert_eq(captured.size(), 1, "one completion")
	assert_eq(captured[0]["outcome"], &"completed")
	assert_eq(str(captured[0]["timeline_completion_receipt_id"]), "rcpt-1")
	assert_eq(str(captured[0]["playback_id"]), "run:primary")


func test_mismatched_token_does_not_complete() -> void:
	if _port_script == null:
		return
	var bridge := _FakeBridge.new()
	var port: Object = _new_port(bridge)
	var captured: Array = []
	port.playback_completed.connect(func(completion: Dictionary) -> void: captured.append(completion))
	port.start_ending_id("ending.alone", _primary_ctx())
	bridge.finish("token-999", "ending.alone", {"receipt_id": "x"})
	assert_eq(captured.size(), 0, "another token cannot satisfy completion")


func test_async_failure_clears_binding_and_allows_restart() -> void:
	if _port_script == null:
		return
	var bridge := _FakeBridge.new()
	var port: Object = _new_port(bridge)
	var failures: Array = []
	port.playback_failed.connect(func(failure: Dictionary) -> void: failures.append(failure))
	port.start_ending_id("ending.alone", _primary_ctx())
	bridge.fail_playback("token-1", "ending.alone", {"code": &"halted"})
	assert_eq(failures.size(), 1, "one failure")
	assert_eq(str(failures[0]["code"]), "halted")
	var restart: Dictionary = port.start_ending_id("ending.alone", _primary_ctx())
	assert_true(restart.get("ok", false), "fresh start after async failure")
	assert_eq(str(restart["receipt"]["playback_token"]), "token-2", "new token after failure")


func test_concurrent_identical_start_returns_cached_result() -> void:
	if _port_script == null:
		return
	var bridge := _FakeBridge.new()
	var port: Object = _new_port(bridge)
	var first: Dictionary = port.start_ending_id("ending.alone", _primary_ctx())
	var second: Dictionary = port.start_ending_id("ending.alone", _primary_ctx())
	assert_true(second.get("ok", false), str(second))
	assert_eq(second["receipt"]["playback_token"], first["receipt"]["playback_token"], "same token, no replay")
	assert_eq(bridge.start_calls.size(), 1, "bridge not called again for identical in-flight start")


func test_different_in_flight_returns_playback_in_progress() -> void:
	if _port_script == null:
		return
	var bridge := _FakeBridge.new()
	var port: Object = _new_port(bridge)
	port.start_ending_id("ending.alone", _primary_ctx())
	var other: Dictionary = port.start_ending_id("ending.priscilla_lavinia", _epilogue_ctx())
	assert_false(other.get("ok", false), "different in-flight rejected")
	assert_eq(str(other.get("code")), "playback_in_progress")
