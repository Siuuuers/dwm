class_name MinesweeperRoundContract
extends RefCounted


const DIFFICULTIES: Array[StringName] = [
	&"beginner", &"intermediate", &"expert"
]

const OUTCOMES: Array[StringName] = [
	&"exploded", &"cleared", &"perfect", &"no_flag", &"foresight"
]


static func validate_start_request(request: Variant) -> Dictionary:
	if not (request is Dictionary):
		return {"ok": false, "code": &"invalid_request"}
	for key: Variant in (request as Dictionary).keys():
		if not (str(key) == "context" or str(key) == "difficulty"):
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


static func build_round_id(run_id: String, day: int, ordinal: int) -> String:
	return "%s:day-%d:round-%d" % [run_id, day, ordinal]
