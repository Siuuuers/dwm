class_name DialogicPlaybackCompletionPort
extends RefCounted


func complete_entry(intent: Dictionary) -> Dictionary:
	return _fail(&"not_configured",
		"no playback completion adapter is configured for %s" % str(intent.get("entry_id", "")))


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
