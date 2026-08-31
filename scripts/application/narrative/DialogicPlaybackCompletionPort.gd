class_name DialogicPlaybackCompletionPort
extends RefCounted
## The single physical-completion seam for semantic entry playback (Seven-Day Flow Plan 01
## Task 5; dwm-oyo.2 rulings R-FF and R-KK). When Dialogic's real timeline_ended reaches the
## bridge while a semantic entry is active, the bridge advances NOTHING itself: it builds one
## completion intent with the exact primitive keys entry_id, transaction_id, stage,
## playback_token, context_fingerprint, execution_mode and completion_kind (natural_end), and
## hands it to whatever adapter is configured over this interface. An aborted playback never
## reaches this port at all - the bridge clears its active entry first.
##
## Stateless interface per R-JJ: the default body fails CLOSED with the house envelope so an
## unconfigured seam can never advance a run. Sited under scripts/application/narrative/ beside
## SaveManagerNarrativeCheckpointPort.gd per R-KK.


func complete_entry(intent: Dictionary) -> Dictionary:
	return _fail(&"not_configured",
		"no playback completion adapter is configured for %s" % str(intent.get("entry_id", "")))


func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
