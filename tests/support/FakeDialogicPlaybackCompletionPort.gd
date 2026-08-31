extends RefCounted
## Test double for the Task 5 DialogicPlaybackCompletionPort seam (Seven-Day Flow Plan 01 Task 5).
## Standalone duck-type on purpose: it must load while the production port is still ABSENT so the
## ordered RED can compile. Records every completion intent verbatim so a suite can pin the exact
## intent keys, the natural_end completion kind, and the call COUNT (a stale or aborted playback
## must reach no port at all - pinned as a count, not as silence).

var intents: Array = []
var next_result: Dictionary = {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func complete_entry(intent: Dictionary) -> Dictionary:
	intents.append(intent.duplicate(true))
	return next_result.duplicate(true)
