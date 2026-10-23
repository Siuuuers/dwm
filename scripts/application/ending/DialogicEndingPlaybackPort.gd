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
const PAIR_CODA_IDS: Array[String] = [
	"ending.priscilla_lavinia.sweet", "ending.priscilla_lavinia.dark",
]
const OBSERVER_CODA_IDS: Array[String] = [
	"ending.priscilla.observer.full", "ending.priscilla.observer.residue",
	"ending.lavinia.observer.full", "ending.lavinia.observer.residue",
	"ending.priscilla_lavinia.observer.full", "ending.priscilla_lavinia.observer.residue",
]

const SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
var _reached_profile: Object
var _presentation_reader: Callable
var _frozen_presentation_reader: Callable

func configure_reached_presentations(profile: Object, reader: Callable, frozen_reader: Callable = Callable()) -> Dictionary:
	if profile == null or not profile.has_method("record_reached_presentation") or not reader.is_valid():
		return _fail(&"invalid_presentation_recorder", "")
	if _reached_profile != null and (_reached_profile != profile or _presentation_reader != reader or _frozen_presentation_reader != frozen_reader):
		return _fail(&"presentation_recorder_already_configured", "")
	_reached_profile = profile
	_presentation_reader = reader
	_frozen_presentation_reader = frozen_reader
	return {"ok":true}

var _bridge: Object = null
var _initialized := false
var _active: Dictionary = {}
var _completed: Dictionary = {}
var _starting := false
var _early_events: Array[Dictionary] = []


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
	if _bridge.has_signal("ending_playback_retired"):
		_bridge.connect("ending_playback_retired", _on_retired)
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
	var signature: Dictionary = {}
	var presentation: Dictionary = {}
	if _presentation_reader.is_valid():
		var captured: Dictionary = _presentation_reader.call(ending_id, context.duplicate(true))
		if not captured.get("ok", false): return captured
		var checked := SIGNATURE.validate(captured.value)
		if not checked.ok: return checked
		signature = checked.value.signature.duplicate(true)
	if _frozen_presentation_reader.is_valid():
		var frozen: Dictionary = _frozen_presentation_reader.call(ending_id, context.duplicate(true))
		if not frozen.get("ok", false): return frozen
		if signature.is_empty() or not frozen.get("value") is Dictionary or frozen.value.get("signature") != signature:
			return _fail(&"ending_frozen_signature_mismatch", "")
		var checked := preload("res://scripts/narrative/FrozenPresentationContext.gd").validate(signature.entry_id, frozen.value.get("presentation"))
		if not checked.ok: return checked
		presentation = checked.value
		if presentation.fields.step_token != context.playback_id or presentation.fields.ending_role != str(context.role):
			return _fail(&"ending_frozen_step_mismatch", "")
	var role := str(context["role"])
	var started: Variant
	_starting = true
	_early_events.clear()
	if not signature.is_empty():
		if not _bridge.has_method("start_ending_presentation"):
			_starting = false
			return _fail(&"invalid_bridge", "exact ending presentation API required")
		started = _bridge.start_ending_presentation(ending_id, context.duplicate(true), signature.duplicate(true), presentation.duplicate(true)) \
			if not presentation.is_empty() else _bridge.start_ending_presentation(ending_id, context.duplicate(true), signature.duplicate(true))
	elif role == "observer_coda":
		if not _bridge.has_method("start_postscript_id"):
			_starting = false
			return _fail(&"invalid_bridge", "bridge must expose start_postscript_id for Observer")
		started = _bridge.start_postscript_id(ending_id)
	else:
		var bridge_context := context.duplicate(true)
		if role not in ["primary", "epilogue"]:
			bridge_context["role"] = &"epilogue" if role == "pair_coda" else &"primary"
		started = _bridge.start_ending_id(ending_id, bridge_context)
	_starting = false
	if typeof(started) != TYPE_DICTIONARY or not (started as Dictionary).get("ok", false):
		_early_events.clear()
		return _copy(started) if started is Dictionary else _fail(&"invalid_bridge_receipt", "invalid result")
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
	_active = {"token": token, "playback_id": str(context["playback_id"]), "ending_id": ending_id, "context": context.duplicate(true), "start_result": start_result.duplicate(true), "signature": signature}
	if not _early_events.is_empty():
		_drain_early_events.call_deferred()
	return start_result.duplicate(true)


func _on_finished(playback_token: String, ending_id: String, receipt: Dictionary) -> void:
	if _starting:
		_early_events.append({"kind": "finished", "token": playback_token, "ending_id": ending_id, "receipt": receipt.duplicate(true)})
		return
	if _active.is_empty() or str(_active["token"]) != playback_token:
		return
	if str(_active["ending_id"]) != ending_id or str(receipt.get("receipt_id", "")).is_empty():
		_on_failed(playback_token, str(_active["ending_id"]), _fail(&"invalid_ending_completion", "completion identity differs"))
		return
	if _reached_profile != null and not (_active.get("signature", {}) as Dictionary).is_empty():
		var recorded: Dictionary = _reached_profile.record_reached_presentation(_active.signature.duplicate(true))
		if not recorded.get("ok", false):
			_on_failed(playback_token, ending_id, recorded)
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
	if _starting:
		_early_events.append({"kind": "failed", "token": playback_token, "ending_id": ending_id, "receipt": result.duplicate(true)})
		return
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


## Return discards this process-local binding, without completing or failing the old run.
func _on_retired(playback_token: String, ending_id: String) -> void:
	if str(_active.get("token", "")) != playback_token \
			or str(_active.get("ending_id", "")) != ending_id:
		return
	_active = {}


func _drain_early_events() -> void:
	# A no-dialogue timeline may finish inside start_ending_id. Defer only that early callback
	# until both this port and the scene have retained the exact admitted command.
	var events := _early_events.duplicate(true)
	_early_events.clear()
	for event: Dictionary in events:
		if str(event.kind) == "finished":
			_on_finished(str(event.token), str(event.ending_id), event.receipt)
		else:
			_on_failed(str(event.token), str(event.ending_id), event.receipt)


func _validate_context(ending_id: String, context: Dictionary) -> Dictionary:
	if typeof(context) != TYPE_DICTIONARY or not _exact_keys(context, CONTEXT_KEYS):
		return _fail(&"invalid_playback_context", "context keys must be exactly " + str(CONTEXT_KEYS))
	var role := String(context["role"])
	var stage := String(context["expected_stage"])
	if role == "primary" and stage == "PRIMARY_PENDING" and ending_id in DATING_ENDING_RULES.VALID_PRIMARY_IDS:
		return {"ok": true}
	if role == "epilogue" and stage == "PRIMARY_PLAYED" and ending_id == EPILOGUE_ID:
		return {"ok": true}
	if stage == "PRIMARY_PENDING":
		if role == "special_prefix" and ending_id == "ending.sylvia.special":
			return {"ok": true}
		if role == "core" and ending_id in DATING_ENDING_RULES.VALID_PRIMARY_IDS \
				and ending_id != "ending.sylvia.special":
			return {"ok": true}
		if role == "pair_coda" and ending_id in PAIR_CODA_IDS:
			return {"ok": true}
		if role == "observer_coda" and ending_id in OBSERVER_CODA_IDS:
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
