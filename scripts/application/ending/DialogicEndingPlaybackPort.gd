class_name DialogicEndingPlaybackPort
extends RefCounted
## Production `.7` EndingPlaybackPort adapter for primary/epilogue playback (dwm-p2r.8, Plan-05
## Task 2). Passes the four-key playback_context unchanged to DialogicBridge.start_ending_id(),
## returns an immediate-start receipt, and advances Plan04's stage ONLY from the physical-completion
## signal. It never widens the `.7` interface and owns no lifecycle-stage meaning.

signal playback_completed(completion: Dictionary)
signal playback_failed(failure: Dictionary)

const DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")
const CONTEXT_KEYS := ["expected_stage", "playback_id", "role", "transaction_id"]
const EPILOGUE_ID := "ending.priscilla_lavinia"

var _bridge: Object = null
var _initialized := false
var _active: Dictionary = {}
var _completed: Dictionary = {}


func initialize(dialogic_bridge: Object) -> Dictionary:
	if _initialized:
		if dialogic_bridge == _bridge:
			return {"ok": true, "code": &"ok", "value": {"already_initialized": true}}
		return _fail(&"ending_playback_port_already_initialized", "")
	if dialogic_bridge == null or not dialogic_bridge.has_method("start_ending_id"):
		return _fail(&"invalid_bridge", "bridge must expose start_ending_id")
	for signal_name in ["ending_playback_finished", "ending_playback_failed"]:
		if not dialogic_bridge.has_signal(signal_name):
			return _fail(&"invalid_bridge", "bridge must expose signal " + signal_name)
	_bridge = dialogic_bridge
	_bridge.connect("ending_playback_finished", _on_finished)
	_bridge.connect("ending_playback_failed", _on_failed)
	_initialized = true
	return {"ok": true, "code": &"ok", "value": {"already_initialized": false}}


func is_ready() -> bool:
	return _initialized and _bridge != null


func start_ending_id(ending_id: String, context: Dictionary = {}) -> Dictionary:
	if not _initialized:
		return _fail(&"not_initialized", "initialize first")
	var validated := _validate_context(ending_id, context)
	if not validated.get("ok", false):
		return validated
	if not _active.is_empty():
		if str(context["playback_id"]) == str(_active["playback_id"]):
			if _same_request(ending_id, context):
				return (_active["start_result"] as Dictionary).duplicate(true)
			return _fail(&"playback_context_conflict", "active playback id reused with a different ending/stage/role")
		return _fail(&"playback_in_progress", "another ending playback is in flight")
	var started: Variant = _bridge.start_ending_id(ending_id, context.duplicate(true))
	if typeof(started) != TYPE_DICTIONARY or not (started as Dictionary).get("ok", false):
		return _copy(started)
	var token := str(((started as Dictionary).get("receipt", {}) as Dictionary).get("playback_token", ""))
	if token.is_empty():
		return _fail(&"invalid_bridge_receipt", "bridge did not return a playback_token")
	var start_result := {"ok": true, "code": &"started", "value": {}, "receipt": {
		"playback_id": str(context["playback_id"]),
		"transaction_id": str(context["transaction_id"]),
		"expected_stage": StringName(String(context["expected_stage"])),
		"role": StringName(String(context["role"])),
		"ending_id": ending_id,
		"playback_token": token,
		"started": true,
	}}
	_active = {"token": token, "playback_id": str(context["playback_id"]), "ending_id": ending_id, "context": context.duplicate(true), "start_result": start_result.duplicate(true)}
	return start_result.duplicate(true)


func _on_finished(playback_token: String, ending_id: String, receipt: Dictionary) -> void:
	if _active.is_empty() or str(_active["token"]) != playback_token:
		return
	var context: Dictionary = _active["context"]
	var completion := {
		"playback_id": str(context["playback_id"]),
		"ending_id": ending_id,
		"expected_stage": StringName(String(context["expected_stage"])),
		"transaction_id": str(context["transaction_id"]),
		"timeline_completion_receipt_id": str(receipt.get("receipt_id", "")),
		"outcome": &"completed",
	}
	_completed[playback_token] = completion.duplicate(true)
	_active = {}
	playback_completed.emit(completion)


func _on_failed(playback_token: String, ending_id: String, result: Dictionary) -> void:
	if _active.is_empty() or str(_active["token"]) != playback_token:
		return
	var context: Dictionary = _active["context"]
	var failure := {
		"playback_id": str(context["playback_id"]),
		"ending_id": ending_id,
		"expected_stage": StringName(String(context["expected_stage"])),
		"transaction_id": str(context["transaction_id"]),
		"code": StringName(str(result.get("code", "playback_failed"))),
		"result": result.duplicate(true),
	}
	_active = {}
	playback_failed.emit(failure)


func _validate_context(ending_id: String, context: Dictionary) -> Dictionary:
	if typeof(context) != TYPE_DICTIONARY or not _exact_keys(context, CONTEXT_KEYS):
		return _fail(&"invalid_playback_context", "context keys must be exactly " + str(CONTEXT_KEYS))
	var role := String(context["role"])
	var stage := String(context["expected_stage"])
	if role == "primary" and stage == "PRIMARY_PENDING" and ending_id in DATING_ENDING_RULES.VALID_PRIMARY_IDS:
		return {"ok": true}
	if role == "epilogue" and stage == "PRIMARY_PLAYED" and ending_id == EPILOGUE_ID:
		return {"ok": true}
	return _fail(&"illegal_playback_triple", "role=%s stage=%s ending=%s" % [role, stage, ending_id])


func _same_request(ending_id: String, context: Dictionary) -> bool:
	var active_context: Dictionary = _active["context"]
	return str(_active["ending_id"]) == ending_id \
		and String(active_context["expected_stage"]) == String(context["expected_stage"]) \
		and String(active_context["role"]) == String(context["role"]) \
		and str(active_context["transaction_id"]) == str(context["transaction_id"])


func _exact_keys(target: Dictionary, keys: Array) -> bool:
	if target.size() != keys.size():
		return false
	for key in keys:
		if not target.has(key):
			return false
	return true


func _copy(value: Variant) -> Variant:
	if typeof(value) == TYPE_DICTIONARY or typeof(value) == TYPE_ARRAY:
		return value.duplicate(true)
	return value


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
