extends RefCounted
## One transient semantic DTL phase owned by the retained Dating presentation port.
## Durable recovery remains the physical owner's pre/post phase boundary. Restarting prose
## never repeats the already committed board or consequence. No empty entry grants evidence.
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

var _bridge: Object
var _command: Dictionary = {}
var _phase := ""
var _entry_id := ""
var _context: Dictionary = {}
var _receipt: Dictionary = {}
var _status := "idle"
var _failure: Dictionary = {}
var _starting := false
var _early_completion: Dictionary = {}

func configure(bridge: Object) -> Dictionary:
	if bridge == null: return _fail(&"dating_narrative_unavailable")
	for method: String in ["start_entry", "configure_playback_completion_port", "is_entry_playback_active"]:
		if not bridge.has_method(method): return _fail(&"dating_narrative_unavailable")
	if _bridge != null and _bridge != bridge: return _fail(&"dating_narrative_already_configured")
	var bound: Dictionary = bridge.configure_playback_completion_port(self)
	if not bound.get("ok", false): return bound
	_bridge = bridge
	if bridge.has_signal("entry_playback_failed") and not bridge.is_connected("entry_playback_failed", _on_failed):
		bridge.connect("entry_playback_failed", _on_failed)
	return _ok()

## SceneRouter mounts a fresh scene only when its route publication succeeds. This
## invalidates completed transient prose even if Load reuses the same command/phase;
## an ordinary checkpoint Retry on the mounted scene keeps its completed playback.
func begin_presentation(_command_to_present: Dictionary) -> Dictionary:
	if _bridge == null: return _fail(&"dating_narrative_unavailable")
	if not _command.is_empty() and _bridge.is_entry_playback_active(
			str(_receipt.get("playback_token", "")), _entry_id):
		if not _bridge.has_method("abort_current_entry"): return _fail(&"dating_narrative_command_conflict")
		var aborted: Dictionary = _bridge.abort_current_entry(&"dating_presentation_replaced")
		if not aborted.get("ok", false): return aborted
	_clear()
	return _ok()

func begin_phase(command: Dictionary, phase: String, retry: bool = false, presentation: Dictionary = {}) -> Dictionary:
	if _bridge == null or phase not in ["pre_challenge", "post_challenge"] \
			or not str(command.get("timeline_id", "")).begins_with("dating.") \
			or not str(command.get("timeline_id", "")).ends_with(".pre_challenge") \
			or str(command.get("physical_token", "")).is_empty() \
			or str(command.get("completion_transaction_id", "")).is_empty():
		return _fail(&"dating_narrative_unavailable")
	var requested_entry := str(command.timeline_id).trim_suffix(".pre_challenge") + "." + phase
	var frozen := {}
	if not presentation.is_empty():
		var checked := preload("res://scripts/narrative/FrozenPresentationContext.gd").validate(requested_entry, presentation)
		if not checked.ok: return checked
		frozen = checked.value
	if not _command.is_empty():
		if _command != command or _phase != phase:
			if _command.get("completion_transaction_id") == command.get("completion_transaction_id") \
					and _command != command:
				return _fail(&"dating_narrative_command_conflict")
			# A restored physical boundary may replace an interrupted date. Cancel only our
			# exact token; never an unrelated Hospital, ending, or archive playback.
			if _bridge.is_entry_playback_active(str(_receipt.get("playback_token", "")), _entry_id):
				if _command == command: return _fail(&"dating_narrative_command_conflict")
				if not _bridge.has_method("abort_current_entry"): return _fail(&"dating_narrative_command_conflict")
				var aborted: Dictionary = _bridge.abort_current_entry(&"dating_phase_superseded")
				if not aborted.get("ok", false): return aborted
			_clear()
		else:
			if _context.get("presentation", {}) != presentation:
				return _fail(&"dating_narrative_context_conflict")
			var current := pull_phase(command, phase)
			if current.get("ok", false) or not retry: return current
			_clear()
	_command = command.duplicate(true)
	_phase = phase
	_entry_id = requested_entry
	_context = {"expected_stage": phase, "playback_id": str(command.physical_token) + ":" + phase,
		"role": "dating_phase", "transaction_id": str(command.completion_transaction_id) + ":" + phase}
	if not frozen.is_empty(): _context["presentation"] = frozen
	_status = "playing"
	_starting = true
	var started: Dictionary = _bridge.start_entry(_entry_id, _context.duplicate(true), &"canonical")
	_starting = false
	if not started.get("ok", false): return _latch(started)
	if _status == "failed": return _failure.duplicate(true)
	_receipt = started.get("receipt", {}).duplicate(true)
	var canonical: Dictionary = JSON_WRITER.stringify(_context)
	if not canonical.get("ok", false) or str(_receipt.get("entry_id", "")) != _entry_id \
			or str(_receipt.get("playback_token", "")).is_empty() \
			or str(_receipt.get("context_fingerprint", "")) != str(canonical.value).sha256_text():
		return _latch(_fail(&"dating_narrative_receipt_mismatch"))
	if not _early_completion.is_empty():
		var completed := complete_entry(_early_completion)
		_early_completion = {}
		if not completed.get("ok", false): return _latch(completed)
	return _ok()

func pull_phase(command: Dictionary, phase: String) -> Dictionary:
	if _command != command or _phase != phase: return _fail(&"dating_narrative_command_conflict")
	if _status == "failed": return _failure.duplicate(true)
	if _status == "playing" and not _starting and not _bridge.is_entry_playback_active(
			str(_receipt.get("playback_token", "")), _entry_id):
		return _latch(_fail(&"dating_narrative_interrupted"))
	return _ok()

func complete_entry(intent: Dictionary) -> Dictionary:
	if _status not in ["playing", "completed"] or not _matches_context(intent):
		return _fail(&"dating_narrative_completion_untrusted")
	if _starting:
		if not _early_completion.is_empty() and _early_completion != intent:
			return _fail(&"dating_narrative_completion_untrusted")
		_early_completion = intent.duplicate(true)
		return _ok()
	if str(intent.get("playback_token", "")) != str(_receipt.get("playback_token", "")) \
			or str(intent.get("context_fingerprint", "")) != str(_receipt.get("context_fingerprint", "")):
		return _fail(&"dating_narrative_completion_untrusted")
	_status = "completed"
	return _ok()

func finish_phase(command: Dictionary, phase: String) -> Dictionary:
	if _command != command or _phase != phase or _status != "completed":
		return _fail(&"dating_narrative_completion_untrusted")
	_clear()
	return _ok()

func _matches_context(intent: Dictionary) -> bool:
	return intent.get("entry_id") == _entry_id and intent.get("stage") == _phase \
		and intent.get("transaction_id") == _context.get("transaction_id") \
		and intent.get("execution_mode") == &"canonical" \
		and intent.get("completion_kind") == &"natural_end"

func _on_failed(token: String, entry_id: String, failure: Dictionary) -> void:
	if _status != "playing" or entry_id != _entry_id: return
	if not _starting and token != str(_receipt.get("playback_token", "")): return
	_latch(failure)

func _clear() -> void:
	_command = {}
	_phase = ""
	_entry_id = ""
	_context = {}
	_receipt = {}
	_status = "idle"
	_failure = {}
	_early_completion = {}

func _latch(failure: Dictionary) -> Dictionary:
	_status = "failed"
	_failure = failure.duplicate(true)
	return _failure.duplicate(true)

func _ok() -> Dictionary:
	return {"ok": true, "value": {"status": _status, "entry_id": _entry_id}}

func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": "", "details": {}}
