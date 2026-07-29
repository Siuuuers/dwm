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

## Primary ending resolver (dwm-p2r.7 Task 6, req.ending.primary).
const PRIMARY_INPUT_KEYS: Array[String] = [
	"completed_candidate", "dark_points", "day", "hospital_skipped_sylvia_solo_count", "receipt_index",
]
const CANDIDATE_KEYS: Array[String] = [
	"action_id", "completion_receipt_id", "friend_id", "schedule_receipt_id", "unlock_receipt_id",
]
const UNLOCK_RECEIPT_KEYS: Array[String] = ["action_id", "day", "friend_id", "kind", "previous_receipt_id", "receipt_id"]
const COMPLETION_RECEIPT_KEYS: Array[String] = ["action_id", "day", "friend_id", "kind", "outcome", "previous_receipt_id", "receipt_id"]

## Selects exactly one primary Day-7 ending from validated state. A completed candidate counts
## only when its unlock -> schedule_add -> date_completed(attended) receipt chain agrees exactly;
## a scheduled-only or faint-prevented date is not a candidate. Tone is binary (story/05 §1):
## Sylvia Special, then Dark, then Sweet, then Alone. Never mutates input.
static func resolve_primary_ending(input: Dictionary) -> Dictionary:
	var shape_error := _validate_primary_input(input)
	if shape_error != "":
		return {"ok": false, "code": &"invalid_primary_input", "message": shape_error}
	# Rule 1: Sylvia Special outranks any completed candidate.
	if int(input["hospital_skipped_sylvia_solo_count"]) >= 2:
		return _primary_result("ending.sylvia.special", "sylvia_special")
	var candidate: Variant = input["completed_candidate"]
	if candidate == null:
		return _primary_result("ending.alone", "alone")
	var walk := _walk_completion_chain(candidate as Dictionary, input["receipt_index"])
	if not str(walk.get("error", "")).is_empty():
		return {"ok": false, "code": &"invalid_primary_input", "message": str(walk["error"])}
	# A well-formed chain that did not end attended is simply not a primary candidate.
	if not bool(walk["attended"]):
		return _primary_result("ending.alone", "alone")
	var friend_id := str((candidate as Dictionary)["friend_id"])
	# Binary tone (story/05 §1): Totally Dark or Sweet; true-path is a separate postscript.
	if int(input["dark_points"]) >= 2:
		return _primary_result("ending.%s.dark" % friend_id, "dark")
	return _primary_result("ending.%s.sweet" % friend_id, "sweet")


## Valid Day-7 primaries after the story/05 §1 binary-tone reconciliation (true-path retired).
## priscilla_lavinia is epilogue-only and never a primary.
const VALID_PRIMARY_IDS: Array[String] = [
	"ending.alone",
	"ending.priscilla.sweet", "ending.priscilla.dark",
	"ending.lavinia.sweet", "ending.lavinia.dark",
	"ending.sylvia.sweet", "ending.sylvia.dark", "ending.sylvia.special",
]
const ENDING_PLAN_KEYS: Array[String] = ["epilogue_id", "playback_stage", "primary_id"]
const PLAYBACK_STAGES: Array[String] = ["PRIMARY_PENDING", "PRIMARY_COMPLETED", "EPILOGUE_COMPLETED", "GALLERY_RECORDED"]

## Composes the primary and epilogue resolvers into a fresh EndingPlan at PRIMARY_PENDING.
static func build_ending_plan(primary_input: Dictionary, epilogue_input: Dictionary) -> Dictionary:
	var primary := resolve_primary_ending(primary_input)
	if not primary.get("ok", false):
		return primary
	var epilogue := resolve_epilogue(epilogue_input)
	if not epilogue.get("ok", false):
		return epilogue
	var plan := {
		"primary_id": str(primary["value"]),
		"epilogue_id": epilogue["value"],
		"playback_stage": "PRIMARY_PENDING",
	}
	var validated := validate_ending_plan(plan)
	if not validated.get("ok", false):
		return validated
	return {"ok": true, "code": &"ok", "value": {"ending_plan": plan}}

static func validate_ending_plan(plan: Dictionary) -> Dictionary:
	if not _keys_match(plan, ENDING_PLAN_KEYS):
		return {"ok": false, "code": &"invalid_ending_plan", "message": "ending plan keys must be exactly " + str(ENDING_PLAN_KEYS)}
	if str(plan["primary_id"]) not in VALID_PRIMARY_IDS:
		return {"ok": false, "code": &"invalid_ending_plan", "message": "unknown or non-primary ending id: " + str(plan["primary_id"])}
	var epilogue: Variant = plan["epilogue_id"]
	if epilogue != null and str(epilogue) != "ending.priscilla_lavinia":
		return {"ok": false, "code": &"invalid_ending_plan", "message": "epilogue must be null or ending.priscilla_lavinia"}
	if str(plan["playback_stage"]) not in PLAYBACK_STAGES:
		return {"ok": false, "code": &"invalid_ending_plan", "message": "unknown playback stage: " + str(plan["playback_stage"])}
	return {"ok": true, "code": &"ok"}

## The single next playback command for the plan's current stage (start-only; the caller
## advances the stage from its validated completion callback, never from this).
static func next_playback_command(plan: Dictionary) -> Dictionary:
	var validated := validate_ending_plan(plan)
	if not validated.get("ok", false):
		return validated
	var stage := str(plan["playback_stage"])
	var has_epilogue: bool = plan["epilogue_id"] != null
	var command: Dictionary
	match stage:
		"PRIMARY_PENDING":
			command = {"kind": &"play_ending", "ending_id": str(plan["primary_id"]), "role": &"primary", "expected_stage": &"PRIMARY_PENDING"}
		"PRIMARY_COMPLETED":
			if has_epilogue:
				command = {"kind": &"play_ending", "ending_id": str(plan["epilogue_id"]), "role": &"epilogue", "expected_stage": &"PRIMARY_COMPLETED"}
			else:
				command = {"kind": &"record_gallery", "expected_stage": &"PRIMARY_COMPLETED"}
		"EPILOGUE_COMPLETED":
			command = {"kind": &"record_gallery", "expected_stage": &"EPILOGUE_COMPLETED"}
		_:  # GALLERY_RECORDED
			command = {"kind": &"complete_run", "expected_stage": &"GALLERY_RECORDED"}
	return {"ok": true, "code": &"ok", "value": command}


## Optional inter-friend epilogue (req.ending.epilogue). Returns ending.priscilla_lavinia only
## when both counted Priscilla-Lavinia encounters occurred (pl_window_count >= 2, from the .6
## four-way window; a prevented window never counts). Null otherwise. It never changes the
## primary ending. Value is the epilogue id or null.
const EPILOGUE_INPUT_KEYS: Array[String] = ["pl_window_count"]

static func resolve_epilogue(input: Dictionary) -> Dictionary:
	if not _keys_match(input, EPILOGUE_INPUT_KEYS):
		return {"ok": false, "code": &"invalid_epilogue_input", "message": "epilogue input keys must be exactly " + str(EPILOGUE_INPUT_KEYS)}
	if typeof(input["pl_window_count"]) != TYPE_INT:
		return {"ok": false, "code": &"invalid_epilogue_input", "message": "pl_window_count must be an integer"}
	var epilogue: Variant = "ending.priscilla_lavinia" if int(input["pl_window_count"]) >= 2 else null
	return {"ok": true, "code": &"ok", "value": epilogue, "receipt": {"kind": "epilogue", "epilogue_id": epilogue}}


static func _primary_result(ending_id: String, rule: String) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": ending_id, "receipt": {"kind": "primary_ending", "ending_id": ending_id, "rule": rule}}


static func _validate_primary_input(input: Dictionary) -> String:
	if not _keys_match(input, PRIMARY_INPUT_KEYS):
		return "primary input keys must be exactly " + str(PRIMARY_INPUT_KEYS)
	if typeof(input["day"]) != TYPE_INT or int(input["day"]) != 7:
		return "day must be 7"
	if typeof(input["hospital_skipped_sylvia_solo_count"]) != TYPE_INT or typeof(input["dark_points"]) != TYPE_INT:
		return "counters must be integers"
	if typeof(input["receipt_index"]) != TYPE_DICTIONARY:
		return "receipt_index must be a dictionary"
	var candidate: Variant = input["completed_candidate"]
	if candidate != null:
		if typeof(candidate) != TYPE_DICTIONARY or not _keys_match(candidate as Dictionary, CANDIDATE_KEYS):
			return "completed_candidate must be null or carry exactly " + str(CANDIDATE_KEYS)
		if str((candidate as Dictionary)["friend_id"]) not in FRIEND_IDS:
			return "candidate friend must be priscilla, lavinia, or sylvia"
	return ""


static func _walk_completion_chain(candidate: Dictionary, receipt_index: Dictionary) -> Dictionary:
	var friend_id := str(candidate["friend_id"])
	var action_id := str(candidate["action_id"])
	var unlock := _receipt_of(receipt_index, str(candidate["unlock_receipt_id"]), "day7_unlock", UNLOCK_RECEIPT_KEYS, friend_id, action_id)
	if not str(unlock.get("error", "")).is_empty():
		return {"error": unlock["error"]}
	if unlock["record"]["previous_receipt_id"] != null:
		return {"error": "the unlock receipt must start the chain"}
	var schedule := _receipt_of(receipt_index, str(candidate["schedule_receipt_id"]), "schedule_add", UNLOCK_RECEIPT_KEYS, friend_id, action_id)
	if not str(schedule.get("error", "")).is_empty():
		return {"error": schedule["error"]}
	if str(schedule["record"]["previous_receipt_id"]) != str(candidate["unlock_receipt_id"]):
		return {"error": "schedule_add must chain to the unlock receipt"}
	var completion := _receipt_of(receipt_index, str(candidate["completion_receipt_id"]), "date_completed", COMPLETION_RECEIPT_KEYS, friend_id, action_id)
	if not str(completion.get("error", "")).is_empty():
		return {"error": completion["error"]}
	if str(completion["record"]["previous_receipt_id"]) != str(candidate["schedule_receipt_id"]):
		return {"error": "date_completed must chain to the schedule receipt"}
	return {"error": "", "attended": str(completion["record"]["outcome"]) == "attended"}


static func _receipt_of(receipt_index: Dictionary, receipt_id: String, kind: String, expected_keys: Array[String], friend_id: String, action_id: String) -> Dictionary:
	if not receipt_index.has(receipt_id):
		return {"error": "no receipt record for " + receipt_id}
	var raw: Variant = receipt_index[receipt_id]
	if typeof(raw) != TYPE_DICTIONARY or not _keys_match(raw as Dictionary, expected_keys):
		return {"error": "malformed receipt record for " + receipt_id}
	var record := raw as Dictionary
	if str(record["receipt_id"]) != receipt_id:
		return {"error": "receipt map key must equal receipt_id for " + receipt_id}
	if str(record["kind"]) != kind:
		return {"error": "%s must have kind %s" % [receipt_id, kind]}
	if int(record["day"]) != 7 or str(record["friend_id"]) != friend_id or str(record["action_id"]) != action_id:
		return {"error": "receipt %s does not match the candidate's day/friend/action" % receipt_id}
	return {"error": "", "record": record}


static func _keys_match(value: Dictionary, expected: Array[String]) -> bool:
	var keys: Array = value.keys()
	keys.sort()
	var want: Array = expected.duplicate()
	want.sort()
	return keys == want


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
		var friend_ids: Array = outcome["friend_ids"]
		# One friend is a solo; two must be the canonical sorted Priscilla-Lavinia pair.
		if friend_ids.size() == 2:
			if [str(friend_ids[0]), str(friend_ids[1])] != ["priscilla", "lavinia"]:
				return "a group outcome must name the canonical sorted priscilla+lavinia pair"
		elif friend_ids.size() != 1:
			return "an outcome names one friend (solo) or the canonical pair (group)"
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
