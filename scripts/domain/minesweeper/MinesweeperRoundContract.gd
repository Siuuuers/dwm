class_name MinesweeperRoundContract
extends RefCounted

# Frozen Phase 2R Minesweeper round contract. This is the single source of truth
# for round difficulty/outcome vocabularies and for validating untrusted start
# requests and completion results. Trusted identity (round_id, context,
# difficulty, day, ordinal) always comes from the active round, never from the
# untrusted result input.

const DIFFICULTIES: Array[StringName] = [
	&"beginner", &"intermediate", &"expert"
]

const OUTCOMES: Array[StringName] = [
	&"exploded", &"cleared", &"perfect", &"no_flag", &"foresight"
]


# Validates an untrusted start request. Context must be "app" or "dating";
# difficulty must be one of DIFFICULTIES. Returns {ok, code, value={context,
# difficulty}} on success, or {ok:false, code:"invalid_request"} otherwise.
static func validate_start_request(request: Variant) -> Dictionary:
	if not (request is Dictionary):
		return {"ok": false, "code": &"invalid_request"}
	var context: Variant = request.get("context", null)
	if not (context == &"app" or context == &"dating"):
		return {"ok": false, "code": &"invalid_request"}
	var difficulty: Variant = request.get("difficulty", null)
	if difficulty is StringName:
		difficulty = String(difficulty)
	if typeof(difficulty) != TYPE_STRING or not (StringName(difficulty) in DIFFICULTIES):
		return {"ok": false, "code": &"invalid_request"}
	return {"ok": true, "code": &"ok", "value": {"context": StringName(context), "difficulty": StringName(difficulty)}}


# Validates an untrusted completion result against the trusted active round.
# The result must be a single-key {outcome} dictionary whose value is a known
# OUTCOME. App rounds require null dating_evidence; dating rounds require a
# non-empty dating_evidence. Returns {ok, code, value={outcome:String}} or a
# failure with code "invalid_result"/"invalid_active_round".
static func validate_result(active_round: Variant, result: Variant) -> Dictionary:
	if not (active_round is Dictionary):
		return {"ok": false, "code": &"invalid_active_round"}
	if not (result is Dictionary):
		return {"ok": false, "code": &"invalid_result"}
	if result.size() != 1 or not result.has("outcome"):
		return {"ok": false, "code": &"invalid_result"}
	var outcome: Variant = result.get("outcome")
	if outcome is StringName:
		outcome = String(outcome)
	if typeof(outcome) != TYPE_STRING or not (StringName(outcome) in OUTCOMES):
		return {"ok": false, "code": &"invalid_result"}
	var context: Variant = active_round.get("context", null)
	var dating_evidence: Variant = active_round.get("dating_evidence", null)
	if context == &"dating":
		if not (dating_evidence is Dictionary) or (dating_evidence as Dictionary).is_empty():
			return {"ok": false, "code": &"invalid_result"}
	elif context == &"app":
		if dating_evidence != null:
			return {"ok": false, "code": &"invalid_result"}
	else:
		return {"ok": false, "code": &"invalid_result"}
	return {"ok": true, "code": &"ok", "value": {"outcome": outcome}}


# Builds the canonical round id from trusted run/day/ordinal. The result shape
# is "run-1:day-2:round-3".
static func build_round_id(run_id: String, day: int, ordinal: int) -> String:
	return "%s:day-%d:round-%d" % [run_id, day, ordinal]
