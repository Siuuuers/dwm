class_name ProvisionalProgressionRules
extends RefCounted

## Temporary mechanical policy approved for implementation on 2026-09-07.
##
## Remaining unspecified recovery and ending tuning is provisional. The fixed solo
## promotion windows and affection thresholds follow design section 8.3. The confirmed
## boundaries are kept here: code owns the decisions, progression is explicit
## and once-only, Hospital requires both condition boundaries, and Day 7 freezes
## one ordered plan before presentation.

const RULESET_ID := "provisional.relationship.2026-09-07.v1"
const RULESET_STATUS := "provisional_noncanonical"

# Provisional source copy and timing, pending authored scene detail. These finite atoms
# belong to existing Day 2 scenes; capture/fresh-run comparison and deliberate withholding
# are accepted laws. Only these source lines, copy and 15-second duration are provisional.
const OBSERVER_WITHHOLDING_MS := 15000
const OBSERVER_ATOMS := {
	"priscilla": {"entry_id": "dating.solo.priscilla.day2.pre_challenge",
		"presentation_atom_id": "atom.observer.priscilla.day2.verification",
		"line_id": "line.observer.priscilla.day2.verification",
		"comparison_key": "priscilla.day2.key_return",
		"original_text": "Priscilla: I returned the key yesterday.",
		"counterpart_text": "Priscilla: I have never returned that key."},
	"lavinia": {"entry_id": "dating.solo.lavinia.day2.pre_challenge",
		"presentation_atom_id": "atom.observer.lavinia.day2.restraint",
		"line_id": "line.observer.lavinia.day2.restraint", "comparison_key": "",
		"original_text": "Lavinia: Leave the cup. I can reach it."},
}

const FRIEND_IDS: Array[String] = ["priscilla", "lavinia", "sylvia"]
const RELATIONSHIP_STATES: Array[String] = ["friend", "ambiguous", "love"]
const PAIR_FORMS: Array[String] = [
	"ambiguous_sweet", "ambiguous_dark", "love_sweet", "love_dark",
]

# Fixed third/fourth invitation valves: seven-day design section 8.3, lines 535-546.
# The fourth slot never repairs a missed third; frozen prior effect receipts are not reevaluated.
const PROGRESSION_WINDOWS := {
	"dating.solo.priscilla.day4": "priscilla",
	"dating.solo.priscilla.day6": "priscilla",
	"dating.solo.lavinia.day5": "lavinia",
	"dating.solo.lavinia.day6": "lavinia",
	"dating.solo.sylvia.day4": "sylvia",
	"dating.solo.sylvia.day5": "sylvia",
}

const THIRD_VALVE_WINDOWS := ["dating.solo.priscilla.day4", "dating.solo.lavinia.day5", "dating.solo.sylvia.day4"]

# Affection thresholds and Dating outcome deltas follow the accepted design. Other tuning is provisional.
const AMBIGUOUS_MOMENTUM := 4
const LOVE_MOMENTUM := 8
const DARK_TONE_THRESHOLD := 2
const HOSPITAL_PRESSURE_BOUNDARY := 10
const HOSPITAL_HEALTH_BOUNDARY := 0
const HOSPITAL_RECOVERY := {"pressure": 3, "health": 6}


func resolve_scene_response(scene_id: String, outcome: String, relationship_outcome: String,
		perfect_reasons: Array) -> Dictionary:
	if not scene_id.begins_with("dating."):
		return _fail(&"invalid_dating_scene", scene_id)
	var deltas := {
		"hatred": [-1, 0, "hostile"], "upset": [0, 0, "upset"], "amused": [1, 0, "amused"],
		"loved": [2, 0, "affectionate"], "foresight": [2, 0, "seen"], "dark": [2, 1, "fixated"],
	}
	var allowed := {"exploded": ["hatred", "upset", "amused"],
		"cleared": ["loved", "dark"], "perfect": ["foresight", "dark"]}
	if not allowed.has(outcome) or relationship_outcome not in allowed[outcome]:
		return _fail(&"invalid_dating_outcome", relationship_outcome)
	var reasons: Array = perfect_reasons.duplicate()
	reasons.sort()
	if reasons != perfect_reasons or reasons not in [[], ["efficiency_gt_100"], ["efficiency_gte_100"], ["no_flag"], ["efficiency_gt_100", "no_flag"], ["efficiency_gte_100", "no_flag"]] \
			or (outcome == "perfect") != not reasons.is_empty():
		return _fail(&"invalid_dating_perfect_reasons", str(perfect_reasons))
	var values: Array = deltas[relationship_outcome]
	return _ok({"scene_id": scene_id, "outcome": outcome, "relationship_outcome": relationship_outcome,
		"perfect_reasons": reasons, "momentum_delta": values[0], "tone_delta": values[1],
		"attitude": values[2], "progression_qualifies": outcome != "exploded"})


func select_pair_form(witnessed_forms: Array[String], draw_index: int) -> Dictionary:
	if draw_index < 0:
		return _fail(&"invalid_pair_draw", "draw_index must be non-negative")
	var witnessed := {}
	for form: String in witnessed_forms:
		if form not in PAIR_FORMS:
			return _fail(&"invalid_pair_form", form)
		witnessed[form] = true
	var eligible: Array[String] = []
	for form: String in PAIR_FORMS:
		if not witnessed.has(form):
			eligible.append(form)
	if eligible.is_empty():
		eligible = PAIR_FORMS.duplicate()
	return _ok({
		"form": eligible[draw_index % eligible.size()],
		"eligible_pool": eligible,
	})


func evaluate_progression(input: Dictionary) -> Dictionary:
	var error := _progression_input_error(input)
	if error != "":
		return _fail(&"invalid_progression_input", error)
	var state := str(input["current_state"])
	var event_id := str(input["event_id"])
	var committed: Array = input["committed_event_ids"]
	if committed.has(event_id):
		return _progression_result(false, state, state, "already_evaluated", "")
	var window_id := str(input["window_id"])
	if not PROGRESSION_WINDOWS.has(window_id) \
			or str(PROGRESSION_WINDOWS[window_id]) != str(input["friend_id"]):
		return _progression_result(false, state, state, "not_progression_window", "")
	if not bool(input["attended"]):
		return _progression_result(false, state, state, "not_attended", "")
	if bool(input["hospital_superseded"]):
		return _progression_result(false, state, state, "hospital_superseded", "")

	var next_state := state
	if bool(input["response_qualifies"]):
		var momentum := int(input["relational_momentum"])
		if window_id in THIRD_VALVE_WINDOWS and state == "friend" and momentum >= AMBIGUOUS_MOMENTUM:
			next_state = "ambiguous"
		elif window_id not in THIRD_VALVE_WINDOWS and state == "ambiguous" and momentum >= LOVE_MOMENTUM:
			next_state = "love"
	return _progression_result(true, state, next_state,
		"advanced" if next_state != state else "held", event_id)


func resolve_hospital(input: Dictionary) -> Dictionary:
	var error := _hospital_input_error(input)
	if error != "":
		return _fail(&"invalid_hospital_input", error)
	var required := int(input["pressure"]) >= HOSPITAL_PRESSURE_BOUNDARY \
		and int(input["health"]) <= HOSPITAL_HEALTH_BOUNDARY
	if not required:
		return _ok({"required": false, "branch": "none", "recovery": {}})
	var day := int(input["day"])
	if day == 7:
		return _ok({
			"required": true,
			"branch": "ending_special" if bool(input["sylvia_invitation_read"]) else "ending_alone",
			"recovery": {},
		})
	return _ok({
		"required": true,
		"branch": "sylvia_variant" if bool(input["sylvia_encounter_committed"]) else "code_only",
		"recovery": HOSPITAL_RECOVERY.duplicate(true),
	})


func freeze_day7_ending_plan(input: Dictionary) -> Dictionary:
	var error := _ending_input_error(input)
	if error != "":
		return _fail(&"invalid_day7_ending_input", error)
	var invitation_read: Dictionary = input["invitation_read"]
	var states: Dictionary = input["relationship_states"]
	var destination := str(input["committed_destination"])
	var hospital_required := bool(input["hospital_required"])
	var steps: Array[Dictionary] = []

	if hospital_required:
		if bool(invitation_read.get("sylvia", false)):
			steps.append(_step("ending.sylvia.special", "special_prefix"))
			steps.append(_step("ending.sylvia.dark", "core"))
		else:
			steps.append(_step("ending.alone", "core"))
	elif destination.is_empty():
		steps.append(_step("ending.alone", "core"))
	else:
		if destination not in FRIEND_IDS or not bool(invitation_read.get(destination, false)) \
				or str(states.get(destination, "friend")) not in ["ambiguous", "love"]:
			return _fail(&"ineligible_committed_destination", destination)
		var tone := "dark" if int(input["tone_points"]) >= DARK_TONE_THRESHOLD else "sweet"
		steps.append(_step("ending.%s.%s" % [destination, tone], "core"))

	var latest_observer_scope := ""
	if bool(input["pair_ending_eligible"]):
		var pair_form := str(input["pair_form"])
		if pair_form not in PAIR_FORMS:
			return _fail(&"invalid_pair_form", pair_form)
		var pair_tone := "dark" if pair_form.ends_with("_dark") else "sweet"
		var pair_step := _step("ending.priscilla_lavinia.%s" % pair_tone, "pair_coda")
		pair_step["pair_form"] = pair_form
		steps.append(pair_step)
		latest_observer_scope = "priscilla_lavinia"
	elif destination in ["priscilla", "lavinia"] and not hospital_required:
		latest_observer_scope = destination

	if latest_observer_scope != "":
		var variants: Dictionary = input["observer_variant_by_scope"]
		var variant := str(variants.get(latest_observer_scope, ""))
		if variant != "":
			if variant not in ["full", "residue"]:
				return _fail(&"invalid_observer_variant", variant)
			var observer_id := "ending.priscilla_lavinia.observer" if latest_observer_scope == "priscilla_lavinia" else "ending.%s.observation" % latest_observer_scope
			var observer := _step(observer_id, "observer_coda")
			observer["presentation_variant"] = variant
			steps.append(observer)

	return _ok({
		"source_day": 7,
		"steps": steps,
		"eligibility_snapshot": input.duplicate(true),
	})


func _progression_input_error(input: Dictionary) -> String:
	for key: String in ["window_id", "event_id", "friend_id", "attended", "hospital_superseded",
			"current_state", "relational_momentum", "response_qualifies", "committed_event_ids"]:
		if not input.has(key):
			return "missing " + key
	if str(input["event_id"]).strip_edges().is_empty():
		return "event_id must be nonempty"
	if str(input["friend_id"]) not in FRIEND_IDS:
		return "unknown friend_id"
	if str(input["current_state"]) not in RELATIONSHIP_STATES:
		return "unknown current_state"
	if typeof(input["attended"]) != TYPE_BOOL or typeof(input["hospital_superseded"]) != TYPE_BOOL \
			or typeof(input["response_qualifies"]) != TYPE_BOOL:
		return "progression flags must be Boolean"
	if typeof(input["relational_momentum"]) != TYPE_INT:
		return "relational_momentum must be an integer"
	if typeof(input["committed_event_ids"]) != TYPE_ARRAY:
		return "committed_event_ids must be an Array"
	return ""


func _hospital_input_error(input: Dictionary) -> String:
	for key: String in ["day", "pressure", "health", "sylvia_encounter_committed", "sylvia_invitation_read"]:
		if not input.has(key):
			return "missing " + key
	if typeof(input["day"]) != TYPE_INT or int(input["day"]) < 1 or int(input["day"]) > 7:
		return "day must be 1 through 7"
	if typeof(input["pressure"]) != TYPE_INT or typeof(input["health"]) != TYPE_INT:
		return "condition values must be integers"
	if typeof(input["sylvia_encounter_committed"]) != TYPE_BOOL \
			or typeof(input["sylvia_invitation_read"]) != TYPE_BOOL:
		return "Hospital facts must be Boolean"
	return ""


func _ending_input_error(input: Dictionary) -> String:
	for key: String in ["day", "committed_destination", "relationship_states", "invitation_read",
			"tone_points", "hospital_required", "pair_ending_eligible", "pair_form",
			"observer_variant_by_scope"]:
		if not input.has(key):
			return "missing " + key
	if typeof(input["day"]) != TYPE_INT or int(input["day"]) != 7:
		return "ending plan requires day 7"
	if typeof(input["committed_destination"]) != TYPE_STRING \
			or typeof(input["relationship_states"]) != TYPE_DICTIONARY \
			or typeof(input["invitation_read"]) != TYPE_DICTIONARY \
			or typeof(input["tone_points"]) != TYPE_INT \
			or typeof(input["hospital_required"]) != TYPE_BOOL \
			or typeof(input["pair_ending_eligible"]) != TYPE_BOOL \
			or typeof(input["pair_form"]) != TYPE_STRING \
			or typeof(input["observer_variant_by_scope"]) != TYPE_DICTIONARY:
		return "ending input types are invalid"
	return ""


func _progression_result(evaluated: bool, previous_state: String, state: String,
		reason: String, commit_event_id: String) -> Dictionary:
	return _ok({
		"evaluated": evaluated,
		"previous_state": previous_state,
		"state": state,
		"reason": reason,
		"commit_event_id": commit_event_id,
	})


static func _step(ending_id: String, role: String) -> Dictionary:
	return {"ending_id": ending_id, "role": role}


static func _ok(value: Dictionary) -> Dictionary:
	var detached := value.duplicate(true)
	detached["ruleset_id"] = RULESET_ID
	detached["ruleset_status"] = RULESET_STATUS
	return {"ok": true, "code": &"ok", "value": detached}


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message,
		"ruleset_id": RULESET_ID, "ruleset_status": RULESET_STATUS}
