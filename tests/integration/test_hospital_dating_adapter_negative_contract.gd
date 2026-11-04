extends "res://addons/gut/test.gd"

const GAME_STATE_PATH := "res://autoload/GameState.gd"
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")
const DATING_PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const HOSPITAL_PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const ROUTER_PATH := "res://autoload/SceneRouter.gd"


## The exact nine keys the RETIRED caller-owned Schedule entry carried, read off the pre-Phase-2R
## ScheduleRules.ENTRY_KEYS at fb7291680 (plan Step 1.6: "do not port the old nine-key caller
## route/effects shape"). Three of the nine survive into the committed contract by name; the other
## six are the caller-owned facts the registry now owns and no entry may carry again.
const OLD_NINE_KEY_SHAPE: Array[String] = [
	"action_id", "day", "effect_ids", "entry_id", "friend_ids",
	"route_id", "slot_index", "type", "unlock_receipt_id",
]
const RETIRED_ENTRY_FIELDS: Array[String] = [
	"effect_ids", "entry_id", "friend_ids", "route_id", "type", "unlock_receipt_id",
]
const RETAINED_ENTRY_FIELDS: Array[String] = ["action_id", "day", "slot_index"]

## The retired deferred-pair PSEUDO-ROUTE. twofriends_if_deferred is a STAGE and a presentation
## kind and both are legitimate; bare twofriends was a route/date-type and is not.
const PSEUDO_ROUTE := "twofriends"
const PAIR_STAGE := "twofriends_if_deferred"
## The one surviving producer of the pseudo-route, and the seam that must have no caller.
const LEGACY_ROUTE_PRODUCER := "execute_schedule_sequence_until_route_needed"

## Every component dwm-p2r.14 installed or reworked on the presentation path.
const HOSPITAL_PORT_PATH := "res://scripts/application/run/HospitalPresentationPort.gd"
const DATING_PORT_PATH := "res://scripts/application/run/DatingPresentationPort.gd"
const OWNER_ADAPTER_PATH := "res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd"
const HOSPITAL_SCENE_PATH := "res://scripts/ui/HospitalScene.gd"
const DATING_SCENE_PATH := "res://scripts/ui/DatingScene.gd"
const STATE_PORT_PATH := "res://scripts/application/run/GameStateDayResolutionPort.gd"

## The five adapters. None of them may name a gameplay mutation seam in executable code.
const ADAPTER_PATHS: Array[String] = [
	HOSPITAL_PORT_PATH, DATING_PORT_PATH, OWNER_ADAPTER_PATH,
	HOSPITAL_SCENE_PATH, DATING_SCENE_PATH,
]
## Everything on the presentation path EXCEPT the one narrative owner allowed to start a timeline.
const NON_OWNER_PATHS: Array[String] = [
	HOSPITAL_PORT_PATH, DATING_PORT_PATH, HOSPITAL_SCENE_PATH, DATING_SCENE_PATH,
	STATE_PORT_PATH, ROUTER_PATH,
]

## Naming any of these is a direct Dialogic start: the physical runtime, or the autoload that wraps
## it. Only DialogicPresentationOwnerAdapter may, and only through its injected bridge.
const DIALOGIC_START_TOKENS: Array[String] = ["start_timeline", "DialogicBridge", "Dialogic."]
## Gameplay mutation seams. These are commands or private mutable state, rather than the gameplay
## owner's name: Hospital presentation now legitimately reads retained Contacts and Schedule facts.
const MUTATION_TOKENS: Array[String] = [
	"SceneRouter", "_run_lifecycle", "advance_day", "increment_day",
	"apply_hospital", "commit_effect_transaction", "complete_active_stage", "route_context",
]


# -------------------------------------------------------------------------------------------------
# "No old nine-key Schedule fields"
# -------------------------------------------------------------------------------------------------

## The contract half. Six of the nine caller-owned keys are gone from the committed entry member
## set, the three that survive are named rather than assumed, and the set is EXACT -- so this fails
## if a tenth caller fact is ever added, not only if one of the six returns.
func test_the_committed_entry_contract_retired_the_old_nine_key_shape() -> void:
	var entry_keys: Array = STATE_SCHEMA.ENTRY_KEYS
	assert_eq(OLD_NINE_KEY_SHAPE.size(), 9, "the retired shape is the nine-key one")
	for retired: String in RETIRED_ENTRY_FIELDS:
		assert_false(entry_keys.has(retired),
			"a committed entry must not carry the retired caller field " + retired)
	for retained: String in RETAINED_ENTRY_FIELDS:
		assert_true(entry_keys.has(retained),
			retained + " is one of the three old keys that legitimately survives")
	assert_eq(entry_keys.size(), 10,
		"the committed entry member set is exact, so a new caller-owned fact cannot be added")


# -------------------------------------------------------------------------------------------------
# "No twofriends pseudo-route"
# -------------------------------------------------------------------------------------------------

## The pseudo-route is gone from every place a route can be declared, while the deferred PAIR keeps
## its stage and its presentation kind -- which is the distinction that makes the claim meaningful
## rather than a blanket ban on the substring.
func test_twofriends_survives_only_as_a_stage_and_never_as_a_route() -> void:
	assert_false((STATE_SCHEMA.ACTION_KINDS as Array).has(PSEUDO_ROUTE),
		"twofriends is not a committable action kind")
	var routes: Dictionary = {}
	for record_value: Variant in _registry_records():
		routes[str((record_value as Dictionary)["route_id"])] = true
	assert_false(routes.has(PSEUDO_ROUTE),
		"no registered action routes to twofriends; the registry knows only " + str(routes.keys()))
	assert_true((PLAN.DAY_1_6_STAGES as Array).has(PAIR_STAGE),
		"the deferred pair keeps its STAGE, so this is not a blanket ban on the name")
	assert_true((DATING_PORT.CONTEXT_KINDS as Array).has(PAIR_STAGE),
		"the deferred pair keeps its presentation KIND")
	assert_false((DATING_PORT.CONTEXT_KINDS as Array).has(PSEUDO_ROUTE),
		"the bare pseudo-route is not an accepted dating context kind")


## THE PSEUDO-ROUTE PRODUCER STILL EXISTS, and this pins its containment rather than pretending it
## does not. GameState.execute_schedule_sequence_until_route_needed() still returns
## route == "twofriends" and create_missed_group_twofriends_entry() still builds an old-shape
## {type,friend_ids,...} entry. Both belong to the legacy transport GameState's own comment records
## as replaced by the committed-receipt start port -- and both are UNCALLED. This test is what
## makes "uncalled" a fact instead of a claim: it goes red the moment anyone wires the pseudo-route
## back into production.
func test_the_legacy_pseudo_route_producer_has_no_caller_in_production() -> void:
	var callers: Array[String] = []
	for path: String in _production_scripts("res://scripts") + _production_scripts("res://autoload"):
		if path == GAME_STATE_PATH:
			continue
		if _code_lines(path).contains(LEGACY_ROUTE_PRODUCER):
			callers.append(path)
	assert_eq(callers, [] as Array[String],
		LEGACY_ROUTE_PRODUCER + " must remain uncalled; callers found: " + str(callers))
	assert_true(_code_lines(GAME_STATE_PATH).contains(LEGACY_ROUTE_PRODUCER),
		"the seam being pinned still exists in GameState, so this scan is not vacuous")


# -------------------------------------------------------------------------------------------------
# "No direct Dialogic start"
# -------------------------------------------------------------------------------------------------

## Exactly one object on the presentation path may start a timeline. Ports validate, scenes render,
## the router injects, the coordinator advances -- none of them touch the runtime.
func test_only_the_narrative_owner_may_start_a_dialogic_timeline() -> void:
	for path: String in NON_OWNER_PATHS:
		var code := _code_lines(path)
		for token: String in DIALOGIC_START_TOKENS:
			assert_false(code.contains(token), path + " must not name " + token)
	var owner_code := _code_lines(OWNER_ADAPTER_PATH)
	assert_true(owner_code.contains("_bridge.call(&\"start_timeline_id\""),
		"the owner starts a timeline only through its injected bridge")
	for token: String in ["DialogicBridge", "Dialogic."]:
		assert_false(owner_code.contains(token),
			"even the owner reaches the runtime through injection, never through " + token)


## The ports carry the presentation forward, so a start method ON one of them would be a direct
## start with extra steps. Neither exposes one.
func test_neither_presentation_port_exposes_a_timeline_start() -> void:
	for port: RefCounted in [HOSPITAL_PORT.new(), DATING_PORT.new()]:
		for forbidden: String in ["start_timeline", "start_timeline_id", "begin_physical"]:
			assert_false(port.has_method(forbidden),
				port.get_script().resource_path + " must not expose " + forbidden)


# -------------------------------------------------------------------------------------------------
# "No presentation-owned mutation"
# -------------------------------------------------------------------------------------------------

## The scene suites prove the SCENES mutate nothing by snapshot comparison. The real Hospital-port
## suite separately snapshots GameState across the narrative owner's legitimate attendance read.
## This scan pins the narrower structural boundary: no presentation adapter names an actual gameplay
## mutation command or private mutable owner state.
func test_no_presentation_adapter_names_a_gameplay_mutation_seam() -> void:
	for path: String in ADAPTER_PATHS:
		var code := _code_lines(path)
		for token: String in MUTATION_TOKENS:
			assert_false(code.contains(token), path + " must not name " + token)


## The guard on the guard uses a local specimen so documentation may evolve without turning prose
## into a production dependency. It proves full-line comments are removed while executable text is
## retained.
func test_the_comment_stripper_is_doing_real_work() -> void:
	var specimen := "# GameState.apply_hospital_recovery_and_advance_day()\nfunc retained_code():\n\tpass\n"
	var code := _strip_comment_lines(specimen)
	assert_true(specimen.contains("apply_hospital"), "the specimen contains a forbidden prose token")
	assert_false(code.contains("apply_hospital"), "full-line comments do not enter executable scans")
	assert_true(code.contains("func retained_code():\n\tpass"),
		"the stripper retains executable lines, so it cannot make every scan vacuous")


# -------------------------------------------------------------------------------------------------
# helpers
# -------------------------------------------------------------------------------------------------

## Source with every full-line comment removed, so a scan reads what EXECUTES rather than what the
## file says about itself.
func _code_lines(path: String) -> String:
	return _strip_comment_lines(FileAccess.get_file_as_string(path))


func _strip_comment_lines(source: String) -> String:
	var kept: PackedStringArray = []
	for line: String in source.split("\n"):
		if line.strip_edges().begins_with("#"):
			continue
		kept.append(line)
	return "\n".join(kept)


## Every production .gd under root, recursively. Tests are excluded by construction: nothing under
## res://tests is reachable from either root passed in.
func _production_scripts(root: String) -> Array[String]:
	var found: Array[String] = []
	var directory := DirAccess.open(root)
	if directory == null:
		return found
	for name: String in directory.get_files():
		if name.ends_with(".gd"):
			found.append(root.path_join(name))
	for name: String in directory.get_directories():
		found.append_array(_production_scripts(root.path_join(name)))
	return found


func _registry_records() -> Array:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(REGISTRY.MANIFEST_PATH))
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "the registry manifest parses")
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	return (parsed as Dictionary)["records"] as Array
