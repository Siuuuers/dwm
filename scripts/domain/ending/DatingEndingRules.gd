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
	var true_path_count := int(drs.get("true_path_count", 0))
	var dark_points := int(drs.get("dark_points", 0))
	var tier := str(affection_tiers.get(friend_id, "hate"))
	if true_path_count >= 4 and tier == "love":
		return "ending.%s.true" % friend_id
	if dark_points >= 2:
		return "ending.%s.dark" % friend_id
	return "ending.%s.sweet" % friend_id

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
