class_name RestoreCallLog
extends RefCounted

## Shared ordered call log for restore-participant and transaction tests
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

var entries: Array[String] = []

func record(participant_id: String, method_name: String) -> void:
	entries.append("%s.%s" % [participant_id, method_name])

func for_participant(participant_id: String) -> Array[String]:
	var filtered: Array[String] = []
	for entry: String in entries:
		if entry.begins_with(participant_id + "."):
			filtered.append(entry.trim_prefix(participant_id + "."))
	return filtered

func clear() -> void:
	entries = []
