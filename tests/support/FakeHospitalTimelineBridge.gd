extends Node
## Explicit playback-boundary double for committed-effect and persistence tests.
## Real Hospital port/physical-owner receipts remain under test; native Dialogic
## admission, rendering and natural return are covered by the runtime suites.

signal timeline_finished(timeline_id: String, result: Dictionary)

var starts: Array[Dictionary] = []
var _active_timeline := ""

func is_dialogic_available() -> bool:
	return true

func start_timeline_id(timeline_id: String, context: Dictionary) -> Dictionary:
	if not _active_timeline.is_empty():
		return {"ok": false, "code": &"narrative_playback_active"}
	starts.append({"timeline_id": timeline_id, "context": context.duplicate(true)})
	_active_timeline = timeline_id
	return {"ok": true}

func has_active_playback() -> bool:
	return not _active_timeline.is_empty()

func publish_fixture_completion() -> void:
	if _active_timeline.is_empty(): return
	var timeline := _active_timeline
	_active_timeline = ""
	timeline_finished.emit(timeline, {"fixture": "completed_playback"})
