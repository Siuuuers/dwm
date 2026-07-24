class_name DatingEndingRules
extends RefCounted

## Pure Day-7 ending-selection core
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).
##
## Phase 2R scope: this is the pure primary/epilogue selection used by legacy
## Day-8 migration to recompute a synchronized non-group primary. Issue .7
## extends THIS class with Hospital/playback behaviour; no second resolver.

const CANONICAL_ENDING_IDS: Array[String] = [
	"ending.alone",
	"ending.priscilla.sweet", "ending.priscilla.dark", "ending.priscilla.true",
	"ending.lavinia.sweet", "ending.lavinia.dark", "ending.lavinia.true",
	"ending.sylvia.sweet", "ending.sylvia.dark", "ending.sylvia.true",
	"ending.sylvia.special", "ending.priscilla_lavinia",
]
const FRIEND_IDS: Array[String] = ["priscilla", "lavinia", "sylvia"]
const SELECTION_INPUT_KEYS: Array[String] = [
	"affection_tiers", "candidate_friend_id", "dating_route_state",
	"pl_post_ending", "sylvia_special",
]

## Hospital outcome seam (dwm-p2r.7, req.flow.hospital_order).
const HOSPITAL_INPUT_KEYS: Array[String] = [
	"condition_effect_ids", "day", "health", "pressure",
	"scheduled_date_outcomes", "transaction_id",
]
const DATE_OUTCOME_KEYS: Array[String] = ["action_id", "friend_ids", "outcome"]
const DATE_OUTCOMES: Array[String] = [
	"attended", "not_attended", "prevented_by_fainting", "cancelled_by_fainting",
]
## Only these two mean the date was lost to the faint.
const FAINTING_LOST_OUTCOMES: Array[String] = ["prevented_by_fainting", "cancelled_by_fainting"]
const HOSPITAL_RECOVERED_HEALTH := 6
const HOSPITAL_RECOVERED_PRESSURE := 3

## Selects the primary Day-7 ending and any inter-friend epilogue from a fully
## detached, primitive input Dictionary. Never touches live state.
static func select_primary_ending(inputs: Dictionary) -> Dictionary:
	var shape_error := _validate_inputs(inputs)
	if shape_error != "":
		return {"ok": false, "code": &"invalid_ending_inputs", "message": shape_error}
	var candidate_friend_id := str(inputs["candidate_friend_id"])
	var dating_route_state: Dictionary = inputs["dating_route_state"]
	var affection_tiers: Dictionary = inputs["affection_tiers"]
	var sylvia_special := bool(inputs["sylvia_special"])
	var pl_post := bool(inputs["pl_post_ending"])

	var ending_id := ""
	if sylvia_special:
		ending_id = "ending.sylvia.special"
	elif pl_post:
		ending_id = "ending.priscilla_lavinia"
	elif candidate_friend_id == "":
		ending_id = "ending.alone"
	else:
		ending_id = _friend_ending(candidate_friend_id, dating_route_state, affection_tiers)

	var epilogue_ending_id := ""
	if pl_post and ending_id != "ending.priscilla_lavinia":
		epilogue_ending_id = "ending.priscilla_lavinia"

	return {"ok": true, "code": &"ok", "value": {
		"ending_id": ending_id,
		"epilogue_ending_id": epilogue_ending_id,
	}}

## Recomputes a legacy group-primary Day-8 save into a synchronized non-group
## primary with the group ending demoted to an epilogue.
static func recompute_synchronized_primary(inputs: Dictionary) -> Dictionary:
	var forced := inputs.duplicate(true)
	# The synchronized recompute never keeps priscilla_lavinia as the primary;
	# it is demoted to the epilogue slot while the Angela pairing wins.
	forced["pl_post_ending"] = false
	var primary := select_primary_ending(forced)
	if not primary.get("ok", false):
		return primary
	var ending_id := str(primary["value"]["ending_id"])
	var epilogue := "ending.priscilla_lavinia" if bool(inputs.get("pl_post_ending", false)) else ""
	return {"ok": true, "code": &"ok", "value": {
		"ending_id": ending_id,
		"epilogue_ending_id": epilogue,
	}}

static func is_canonical_ending(ending_id: String) -> bool:
	return ending_id in CANONICAL_ENDING_IDS

static func _friend_ending(friend_id: String, dating_route_state: Dictionary, affection_tiers: Dictionary) -> String:
	if friend_id not in FRIEND_IDS:
		return "ending.alone"
	var drs: Dictionary = dating_route_state.get(friend_id, {})
	var dark_points := int(drs.get("dark_points", 0))
	# Tone is binary (story/05 §1): Sweet or Totally Dark. The true-path is no longer a
	# destination -- it is the conjunctively-gated true (observation) postscript.
	if dark_points >= 2:
		return "ending.%s.dark" % friend_id
	return "ending.%s.sweet" % friend_id

## Resolves Hospital consequences as a pure result (req.flow.hospital_order). Recovery is
## fixed; the only variable is how many Sylvia SOLO dates the faint cost, which later feeds
## the Sylvia Special check. Never advances the day and never mutates the input.
static func resolve_hospital_outcome(input: Dictionary) -> Dictionary:
	var shape_error := _validate_hospital_input(input)
	if shape_error != "":
		return {"ok": false, "code": &"invalid_hospital_input", "message": shape_error}
	var skipped: Array[String] = []
	for raw: Variant in input["scheduled_date_outcomes"]:
		var outcome := raw as Dictionary
		if str(outcome["outcome"]) not in FAINTING_LOST_OUTCOMES:
			continue
		var friend_ids: Array = outcome["friend_ids"]
		# Only a SOLO Sylvia date feeds the counter; a lost group date never does.
		if friend_ids.size() == 1 and str(friend_ids[0]) == "sylvia":
			skipped.append(str(outcome["action_id"]))
	skipped.sort()
	return {
		"ok": true,
		"code": &"ok",
		"value": {
			"health": HOSPITAL_RECOVERED_HEALTH,
			"pressure": HOSPITAL_RECOVERED_PRESSURE,
			"condition_effect_ids": [],
			"hospital_skipped_sylvia_solo_count_delta": skipped.size(),
		},
		"receipt": {
			"transaction_id": str(input["transaction_id"]),
			"kind": "hospital_outcome",
			"day": int(input["day"]),
			"skipped_action_ids": skipped,
		},
	}


static func _validate_hospital_input(input: Dictionary) -> String:
	var keys: Array = input.keys()
	keys.sort()
	var expected: Array = HOSPITAL_INPUT_KEYS.duplicate()
	expected.sort()
	if keys != expected:
		return "hospital input keys must be exactly " + str(expected)
	if typeof(input["day"]) != TYPE_INT:
		return "day must be an integer"
	if typeof(input["health"]) != TYPE_INT or typeof(input["pressure"]) != TYPE_INT:
		return "health and pressure must be integers"
	if typeof(input["condition_effect_ids"]) != TYPE_ARRAY:
		return "condition_effect_ids must be an array"
	if str(input["transaction_id"]).is_empty():
		return "transaction_id must be nonempty"
	if typeof(input["scheduled_date_outcomes"]) != TYPE_ARRAY:
		return "scheduled_date_outcomes must be an array"
	for raw: Variant in input["scheduled_date_outcomes"]:
		if typeof(raw) != TYPE_DICTIONARY:
			return "each scheduled outcome must be an object"
		var outcome := raw as Dictionary
		var outcome_keys: Array = outcome.keys()
		outcome_keys.sort()
		var expected_outcome: Array = DATE_OUTCOME_KEYS.duplicate()
		expected_outcome.sort()
		if outcome_keys != expected_outcome:
			return "scheduled outcome keys must be exactly " + str(expected_outcome)
		if str(outcome["outcome"]) not in DATE_OUTCOMES:
			return "unknown outcome: " + str(outcome["outcome"])
		if typeof(outcome["friend_ids"]) != TYPE_ARRAY or (outcome["friend_ids"] as Array).is_empty():
			return "friend_ids must be a nonempty array"
		if str(outcome["action_id"]).is_empty():
			return "action_id must be nonempty"
	return ""


static func _validate_inputs(inputs: Dictionary) -> String:
	var keys: Array = inputs.keys()
	keys.sort()
	var expected := SELECTION_INPUT_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return "unexpected ending-input keys: " + str(keys)
	if typeof(inputs["candidate_friend_id"]) != TYPE_STRING:
		return "candidate_friend_id must be a String"
	if typeof(inputs["dating_route_state"]) != TYPE_DICTIONARY:
		return "dating_route_state must be a Dictionary"
	if typeof(inputs["affection_tiers"]) != TYPE_DICTIONARY:
		return "affection_tiers must be a Dictionary"
	if typeof(inputs["sylvia_special"]) != TYPE_BOOL:
		return "sylvia_special must be a bool"
	if typeof(inputs["pl_post_ending"]) != TYPE_BOOL:
		return "pl_post_ending must be a bool"
	return ""
