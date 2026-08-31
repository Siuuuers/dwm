extends RefCounted
## Test double for the Task 5 DialogicSignalCommandPort seam (Seven-Day Flow Plan 01 Task 5).
## Deliberately a standalone duck-type rather than a subclass of the production port, so this
## fake loads while the production port is still ABSENT and the ordered RED can compile.
## Records every commit_signal call verbatim and answers with an injectable result, so a suite
## can pin call counts (the receipt-ledger and stale-completion laws) and drive rejections.

var calls: Array = []
var next_result: Dictionary = {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func commit_signal(entry_id: String, stage: StringName, signal_id: String, payload: Dictionary, execution_mode: StringName) -> Dictionary:
	calls.append({
		"entry_id": entry_id,
		"stage": stage,
		"signal_id": signal_id,
		"payload": payload.duplicate(true),
		"execution_mode": execution_mode,
	})
	return next_result.duplicate(true)
