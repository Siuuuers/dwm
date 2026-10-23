extends "res://addons/gut/test.gd"
# Pure skip decision (dwm-p2r.8, Plan-05 Task 4 Step 4.1). RED-first via dynamic load so the
# missing policy fails by assertion, never by a parse error, and no Dialogic event is consumed.

const POLICY_PATH := "res://scripts/narrative/SkipPolicy.gd"

const READ_ONLY := &"read_only"
const ALL_TEXT := &"all_text"
## Every boundary the skip must stop before, per the frozen policy contract.
const STOP_BOUNDARIES: Array[StringName] = [
	&"choice", &"effect_transaction", &"variable_transaction", &"safe_marker",
	&"scene_transition", &"minesweeper_entry", &"validation_error",
]

var _policy: GDScript


func before_all() -> void:
	if ResourceLoader.exists(POLICY_PATH, "Script"):
		_policy = load(POLICY_PATH)


func _evaluate(mode: StringName, visited: bool, next_boundary: StringName) -> Dictionary:
	return _policy.call(&"evaluate", mode, visited, next_boundary)


func test_skip_policy_script_exists() -> void:
	assert_true(ResourceLoader.exists(POLICY_PATH, "Script"), "missing SkipPolicy.gd")


func test_skip_stops_before_variable_transaction() -> void:
	if _policy == null:
		return
	var decision: Dictionary = _evaluate(ALL_TEXT, false, &"variable_transaction")
	assert_true(decision["reveal_current"])
	assert_false(decision["advance"])
	assert_true(decision["stop_before_boundary"])


func test_every_registered_boundary_stops_the_skip_in_both_modes() -> void:
	if _policy == null:
		return
	for mode: StringName in [READ_ONLY, ALL_TEXT]:
		for visited: bool in [false, true]:
			for boundary: StringName in STOP_BOUNDARIES:
				var decision: Dictionary = _evaluate(mode, visited, boundary)
				assert_true(decision["stop_before_boundary"], "%s/%s must stop before %s" % [String(mode), str(visited), String(boundary)])
				assert_false(decision["advance"], "a stopped skip never advances: " + String(boundary))
				assert_true(decision["reveal_current"], "the current line is always revealed")


func test_all_text_advances_through_unseen_text() -> void:
	if _policy == null:
		return
	var decision: Dictionary = _evaluate(ALL_TEXT, false, &"text")
	assert_true(decision["advance"], "all_text skips unread text")
	assert_false(decision["stop_before_boundary"])


func test_unknown_and_absent_boundaries_stop_in_both_modes() -> void:
	if _policy == null:
		return
	for mode: StringName in [READ_ONLY, ALL_TEXT]:
		for visited: bool in [false, true]:
			for boundary: StringName in [&"none", &"unknown", &"", &"future_event"]:
				var decision: Dictionary = _evaluate(mode, visited, boundary)
				assert_true(decision["stop_before_boundary"], "unclassified frontier stops: " + String(boundary))
				assert_false(decision["advance"], "unclassified frontier is never consumed")
				assert_true(decision["reveal_current"])
				assert_true(decision["mark_current_visited"])


func test_all_text_advances_through_seen_text() -> void:
	if _policy == null:
		return
	assert_true(_evaluate(ALL_TEXT, true, &"text")["advance"], "all_text skips read text too")


func test_read_only_advances_only_through_previously_visited_text() -> void:
	if _policy == null:
		return
	assert_true(_evaluate(READ_ONLY, true, &"text")["advance"], "read_only advances past text already seen")
	assert_false(_evaluate(READ_ONLY, false, &"text")["advance"], "read_only stops at unseen text")


func test_current_line_is_always_revealed_and_marked_visited() -> void:
	if _policy == null:
		return
	for mode: StringName in [READ_ONLY, ALL_TEXT]:
		for visited: bool in [false, true]:
			for boundary: StringName in ([&"text"] as Array[StringName]) + STOP_BOUNDARIES:
				var decision: Dictionary = _evaluate(mode, visited, boundary)
				assert_true(decision["reveal_current"], "reveal is unconditional")
				assert_true(decision["mark_current_visited"], "visiting is unconditional")


func test_invalid_mode_behaves_exactly_as_read_only() -> void:
	if _policy == null:
		return
	for boundary: StringName in ([&"text"] as Array[StringName]) + STOP_BOUNDARIES:
		for visited: bool in [false, true]:
			var invalid: Dictionary = _evaluate(&"not_a_mode", visited, boundary)
			var read_only: Dictionary = _evaluate(READ_ONLY, visited, boundary)
			assert_eq(invalid, read_only, "an invalid mode normalizes to read_only: " + String(boundary))
			assert_eq(String(invalid["mode"]), String(READ_ONLY), "the normalized mode is reported")


func test_decision_shape_is_exact() -> void:
	if _policy == null:
		return
	var keys: Array = _evaluate(ALL_TEXT, true, &"text").keys()
	keys.sort()
	assert_eq(keys, ["advance", "mark_current_visited", "mode", "reveal_current", "stop_before_boundary"],
		"the decision exposes exactly these five fields")
