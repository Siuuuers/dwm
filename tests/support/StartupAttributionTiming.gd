extends RefCounted
## Temporary diagnostic-branch instrumentation. Inclusive phases overlap.
static var rows: Array[Dictionary] = []
static func stamp() -> Dictionary:
	return {"ticks_us": Time.get_ticks_usec(), "unix_ms": Time.get_unix_time_from_system() * 1000.0}
static func finish(phase: String, began: Dictionary, ok: bool = true) -> void:
	if OS.get_environment("DWM_STARTUP_ATTRIBUTION") != "1": return
	var ended := stamp()
	rows.append({"phase": phase, "start": began, "end": ended,
		"elapsed_us": int(ended.ticks_us) - int(began.ticks_us), "ok": ok})
