class_name SkipPolicy
extends RefCounted

const READ_ONLY := &"read_only"
const ALL_TEXT := &"all_text"

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
	var stop_before := next_boundary != &"text"
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
