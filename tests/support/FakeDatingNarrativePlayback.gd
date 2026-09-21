extends RefCounted
## Scene fixtures complete empty DTL immediately; waiting tests can finish it explicitly.
var auto_complete := true
var fail_begin := false
var started: Array[Dictionary] = []
var _command: Dictionary = {}
var _phase := ""
var _status := "idle"

func begin_presentation(_command_to_present: Dictionary) -> Dictionary:
	_command = {}
	_phase = ""
	_status = "idle"
	return {"ok": true}

func begin_phase(command: Dictionary, phase: String, retry: bool = false) -> Dictionary:
	if phase not in ["pre_challenge", "post_challenge"]: return _fail()
	if not _command.is_empty():
		if _command != command or _phase != phase: return _fail()
		if _status != "failed" or not retry: return pull_phase(command, phase)
	_command = command.duplicate(true)
	_phase = phase
	started.append({"command": command.duplicate(true), "phase": phase})
	_status = "failed" if fail_begin else ("completed" if auto_complete else "playing")
	return pull_phase(command, phase)

func pull_phase(command: Dictionary, phase: String) -> Dictionary:
	if _command != command or _phase != phase or _status == "failed": return _fail()
	return {"ok": true, "value": {"status": _status,
		"entry_id": str(command.get("timeline_id", "")).trim_suffix(".pre_challenge") + "." + phase}}

func finish() -> void:
	if _status == "playing": _status = "completed"

func finish_phase(command: Dictionary, phase: String) -> Dictionary:
	if _command != command or _phase != phase or _status != "completed": return _fail()
	_command = {}
	_phase = ""
	_status = "idle"
	return {"ok": true}

func _fail() -> Dictionary:
	return {"ok": false, "code": &"fixture_dating_narrative_failure"}
