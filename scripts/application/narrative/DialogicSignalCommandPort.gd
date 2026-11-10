class_name DialogicSignalCommandPort
extends RefCounted


func commit_signal(_entry_id: String, _stage: StringName, signal_id: String, _payload: Dictionary, _execution_mode: StringName) -> Dictionary:
	return _fail(&"not_configured", "no signal command adapter is configured for %s" % signal_id)


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
