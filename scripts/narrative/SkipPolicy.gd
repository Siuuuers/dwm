class_name SkipPolicy
extends RefCounted
## Pure boundary decision for skip (dwm-p2r.8, Plan-05 Task 4).
##
## It reads no state and touches no runtime: the caller supplies the mode, whether the current line
## was visited BEFORE this reveal, and the classified next boundary. The current line is always
## revealed and always marked visited; only advancement is conditional.

const READ_ONLY := &"read_only"
const ALL_TEXT := &"all_text"

## Skip must stop before every boundary that can mutate state, branch, or leave the timeline.
const STOP_BOUNDARIES: Array[StringName] = [
	&"choice",
	&"effect_transaction",
	&"variable_transaction",
	&"safe_marker",
	&"scene_transition",
	&"minesweeper_entry",
	&"validation_error",
]


static func evaluate(
	mode: StringName,
	was_visited_before_reveal: bool,
	next_boundary: StringName
) -> Dictionary:
	var normalized := mode
	if normalized not in [READ_ONLY, ALL_TEXT]:
		normalized = READ_ONLY
	var stop_before := next_boundary in STOP_BOUNDARIES
	var may_advance := not stop_before
	if normalized == READ_ONLY and not was_visited_before_reveal:
		may_advance = false
	return {
		"mode": normalized,
		"reveal_current": true,
		"mark_current_visited": true,
		"advance": may_advance,
		"stop_before_boundary": stop_before,
	}
