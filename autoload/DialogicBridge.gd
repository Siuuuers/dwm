extends Node
# DialogicBridge (CONTRACTS §10 / DIALOGIC.md): owns ALL direct Dialogic interaction.
# Safe checked calls only; no arbitrary gameplay effects from DTL; no GameState calls by
# name; no eval; validates timeline IDs against DialogicTimelineCatalog; returns safe error
# dictionaries for unknown IDs / missing files / missing Dialogic. Never crashes.

signal timeline_started(timeline_id: String, path: String)
signal timeline_finished(timeline_id: String, result: Dictionary)
signal timeline_failed(result: Dictionary)
signal timeline_marker_received(marker_id: String, payload: Dictionary)

const MISSING_DIALOGIC_MESSAGE := "Dialogic 2 addon file does not exist."

# Whitelisted safe marker ids (DTL may only call DialogicBridge.timeline_marker("<id>")).
const _SAFE_MARKERS := [
	"opening_done", "tutorial_done", "hospital_recovered",
	"contact_history_shown", "invitation_offered", "challenge_ready",
	"dating_pre_done", "dating_post_done", "ending_shown",
]

var _current_timeline_id: String = ""
var _current_timeline_context: Dictionary = {}


func is_dialogic_available() -> bool:
	# Safe file check + runtime autoload check; never crashes if absent.
	var plugin_present := FileAccess.file_exists("res://addons/dialogic/plugin.cfg")
	var runtime := get_node_or_null("/root/Dialogic")
	return plugin_present and runtime != null


func require_dialogic() -> Dictionary:
	if is_dialogic_available():
		return {"ok": true}
	return {"ok": false, "reason": "dialogic_missing", "message": MISSING_DIALOGIC_MESSAGE}


func start_timeline_id(timeline_id: String, context: Dictionary = {}) -> Dictionary:
	var req := require_dialogic()
	if not req["ok"]:
		var fail := {"ok": false, "reason": "dialogic_missing", "timeline_id": timeline_id, "message": MISSING_DIALOGIC_MESSAGE}
		emit_signal("timeline_failed", fail)
		return fail
	if not DialogicTimelineCatalog.has_timeline_id(timeline_id):
		var fail2 := {"ok": false, "reason": "unknown_timeline_id", "timeline_id": timeline_id}
		emit_signal("timeline_failed", fail2)
		return fail2
	var locale := _current_locale()
	var path := DialogicTimelineCatalog.get_timeline_path(timeline_id, locale)
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		# Permitted English fallback (DIALOGIC.md §3).
		var en_path := DialogicTimelineCatalog.get_timeline_path(timeline_id, "en")
		if ResourceLoader.exists(en_path) or FileAccess.file_exists(en_path):
			path = en_path
		else:
			var fail3 := {"ok": false, "reason": "timeline_file_missing", "timeline_id": timeline_id, "path": path}
			emit_signal("timeline_failed", fail3)
			return fail3
	return _start_at_path(timeline_id, path, context)


func start_timeline_path(path: String, context: Dictionary = {}) -> Dictionary:
	var req := require_dialogic()
	if not req["ok"]:
		var fail := {"ok": false, "reason": "dialogic_missing", "path": path, "message": MISSING_DIALOGIC_MESSAGE}
		emit_signal("timeline_failed", fail)
		return fail
	if not (ResourceLoader.exists(path) or FileAccess.file_exists(path)):
		var fail2 := {"ok": false, "reason": "timeline_file_missing", "path": path}
		emit_signal("timeline_failed", fail2)
		return fail2
	return _start_at_path("", path, context)


func _start_at_path(timeline_id: String, path: String, context: Dictionary) -> Dictionary:
	var dialogic := get_node_or_null("/root/Dialogic")
	if dialogic == null or not dialogic.has_method("start"):
		var fail := {"ok": false, "reason": "dialogic_missing", "path": path, "message": MISSING_DIALOGIC_MESSAGE}
		emit_signal("timeline_failed", fail)
		return fail
	_current_timeline_id = timeline_id
	_current_timeline_context = context.duplicate(true)
	dialogic.call("start", path)
	emit_signal("timeline_started", timeline_id, path)
	return {"ok": true, "timeline_id": timeline_id, "path": path}


func finish_current_timeline(result: Dictionary = {}) -> void:
	var finished_id := _current_timeline_id
	_current_timeline_id = ""
	_current_timeline_context = {}
	emit_signal("timeline_finished", finished_id, result)


func validate_required_timelines() -> Dictionary:
	return DialogicTimelineCatalog.build_missing_timeline_report("en")


func get_required_timeline_paths() -> Array[String]:
	return DialogicTimelineCatalog.get_required_timeline_paths("en")


func get_current_timeline_id() -> String:
	return _current_timeline_id


func get_current_timeline_context() -> Dictionary:
	return _current_timeline_context.duplicate(true)


func timeline_marker(marker_id: String, payload: Dictionary = {}) -> void:
	if not (marker_id in _SAFE_MARKERS):
		push_warning("DialogicBridge: ignoring unknown timeline marker '%s'." % marker_id)
		return
	emit_signal("timeline_marker_received", marker_id, payload)


func _current_locale() -> String:
	var loc := get_node_or_null("/root/LocalizationManager")
	if loc != null and loc.has_method("get_locale"):
		return loc.get_locale()
	return "en"
