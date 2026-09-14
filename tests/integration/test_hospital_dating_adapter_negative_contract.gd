extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")

# The NEGATIVE half of dwm-p2r.14's acceptance criteria, in one place (Plan 01 Task 8).
#
# WHY THIS FILE EXISTS. The bead's acceptance criteria end with a sentence no suite asserted:
# "No old nine-key Schedule fields, twofriends pseudo-route, synthetic completion, direct Dialogic
# start, or presentation-owned mutation remains." The positive half -- valid, stale, duplicate,
# conflicting, interrupted, Hospital, pair and Day-7 -- is proved elsewhere and is NOT repeated
# here. What was missing is a check that the retired shapes stayed retired.
#
# WHAT THIS FILE DELIBERATELY DOES NOT DUPLICATE, and where that work already lives:
#
#   synthetic completion .... test_hospital_presentation_port.gd
#                             (a_scene_authored_receipt_never_reaches_a_stage),
#                             test_dating_presentation_port.gd
#                             (a_scene_authored_challenge_result_never_reaches_a_stage),
#                             test_dialogic_presentation_owner_adapter.gd
#                             (a_scene_authored_result_is_refused,
#                             no_public_bridge_method_can_forge_a_completion) and
#                             test_dialogic_bridge_contract.gd
#                             (the_caller_forgeable_finisher_is_gone_from_source_and_from_the
#                             _instance). Already proved behaviourally, four times over.
#   scene-owned mutation .... test_hospital_scene.gd / test_dating_scene.gd compare a full owner
#                             snapshot across _ready() and across button input. The SCENES are
#                             covered; what was not covered is the ports and the narrative owner,
#                             which is the half this file adds.
#   the pair's route id ..... test_committed_schedule_presentation_matrix.gd
#                             (the_deferred_pair_variant_carries_its_exact_matrix_row) already
#                             freezes route_id="dating" for the deferred pair.
#   unknown-route refusal ... test_schedule_presentation_bootstrap_wiring.gd already proves the
#                             router refuses an unregistered route generically. The case named
#                             below is the specific retired one, which is the claim being made.
#
# THE COMMENT-STRIPPING SCANS ARE THE POINT, not an implementation detail. HospitalScene.gd's
# doc comment still NAMES GameState.apply_hospital_recovery_and_advance_day() and SceneRouter to
# record what Task 8 removed. A raw contains() scan would either fail on that prose or be quietly
# weakened to accommodate it. _code_lines() drops full-line comments and scans what executes --
# and test_the_comment_stripper_is_doing_real_work proves the stripper is not vacuously passing by
# requiring those tokens to be present in the RAW file and absent from the code.
#
# SUBSTRATE. Real throughout: GUID-isolated root, real DesktopIssuerRootStore over real
# JsonFileStorage, the real DesktopIdentityNonceIssuer, the production ScheduleActionRegistry, the
# real GameStateScheduleCommitPort and a real GameState in the tree. The only fixture is the
# Plan-02 desktop-consequence source, authorised by plan line 532 until Plan 02 exists.

const COMMIT_PORT := preload("res://scripts/application/schedule/GameStateScheduleCommitPort.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const START_PORT := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const REGISTRY := preload("res://scripts/domain/schedule/ScheduleActionRegistry.gd")
const LEDGER := preload("res://scripts/infrastructure/save/ScheduleFoundationPublicationLedger.gd")
const CONTACT_STATE := preload("res://scripts/domain/contact/ContactInvitationState.gd")
const CONSEQUENCE_SOURCE := preload("res://tests/support/FakeDesktopConsequenceSource.gd")
const STATE_SCHEMA := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const PLAN := preload("res://scripts/domain/run/DayResolutionPlan.gd")
const DATING_PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const HOSPITAL_PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const ROUTER_PATH := "res://autoload/SceneRouter.gd"

const CAUSAL_DAY := "causal_day_instance.5555555555555555555555555555555555555555555555555555555555555555"
const VIEW_FINGERPRINT := "schedule_view.55555555555555555555555555555555"
const MAX_WALK_STEPS := 40

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
const COORDINATOR_PATH := "res://scripts/application/run/DayResolutionCoordinator.gd"
const STATE_PORT_PATH := "res://scripts/application/run/GameStateDayResolutionPort.gd"

## The five adapters. None of them may name a gameplay mutation seam in executable code.
const ADAPTER_PATHS: Array[String] = [
	HOSPITAL_PORT_PATH, DATING_PORT_PATH, OWNER_ADAPTER_PATH,
	HOSPITAL_SCENE_PATH, DATING_SCENE_PATH,
]
## Everything on the presentation path EXCEPT the one narrative owner allowed to start a timeline.
const NON_OWNER_PATHS: Array[String] = [
	HOSPITAL_PORT_PATH, DATING_PORT_PATH, HOSPITAL_SCENE_PATH, DATING_SCENE_PATH,
	COORDINATOR_PATH, STATE_PORT_PATH, ROUTER_PATH,
]

## Naming any of these is a direct Dialogic start: the physical runtime, or the autoload that wraps
## it. Only DialogicPresentationOwnerAdapter may, and only through its injected bridge.
const DIALOGIC_START_TOKENS: Array[String] = ["start_timeline", "DialogicBridge", "Dialogic."]
## Gameplay mutation seams. A presentation component that names one of these owns an outcome.
const MUTATION_TOKENS: Array[String] = [
	"GameState", "SceneRouter", "_run_lifecycle", "advance_day", "increment_day",
	"apply_hospital", "commit_effect_transaction", "complete_active_stage", "route_context",
]

var _root := ""
var _root_counter := 0
var _registry: RefCounted
var _fingerprint := ""
var _issuer: RefCounted
var _game_state: Node
var _state_port: RefCounted
var _consequence: RefCounted
var _commands: Dictionary = {}


func before_each() -> void:
	_commands = {}
	_root = ""
	_root_counter += 1
	var result: Dictionary = TEMPORARY_STORAGE.create("adapter-negative-%d" % _root_counter)
	assert_true(result.get("ok", false), result.get("message", ""))
	if not result.get("ok", false):
		return
	_root = str(result["value"])

	var loaded: Dictionary = REGISTRY.load_current()
	assert_true(loaded.get("ok", false), str(loaded))
	_registry = (loaded.get("value", {}) as Dictionary).get("registry")
	_fingerprint = str((loaded.get("value", {}) as Dictionary).get("registry_fingerprint", ""))

	var storage := JsonFileStorage.new(_root)
	var store: RefCounted = ROOT_STORE.new()
	assert_true(store.configure(storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(store).get("ok", false))

	_game_state = load(GAME_STATE_PATH).new()
	add_child_autofree(_game_state)
	_game_state.reset_game()

	var ledger: RefCounted = LEDGER.new()
	assert_true(ledger.configure(storage).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	_state_port = STATE_PORT.new(_game_state)
	_consequence = CONSEQUENCE_SOURCE.new()
	assert_true(_consequence.configure(_issuer).get("ok", false))
	assert_true(_state_port.configure_desktop_consequence_source(_consequence).get("ok", false))
	assert_true(_state_port.configure_resolution_identity(
		_issuer, START_PORT.new(_state_port, _registry, _issuer, ledger)).get("ok", false))


# -------------------------------------------------------------------------------------------------
# "No old nine-key Schedule fields"
# -------------------------------------------------------------------------------------------------

## The contract half. Six of the nine caller-owned keys are gone from the committed entry member
## set, the three that survive are named rather than assumed, and the set is EXACT -- so this fails
## if a tenth caller fact is ever added, not only if one of the six returns.
func test_the_committed_entry_contract_retired_the_old_nine_key_shape() -> void:
	if _root.is_empty():
		return
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


## The behavioural half. Naming the retired keys is not the same as REFUSING them: this drives a
## real committed aggregate through the production commit port and requires the exact-key validator
## to reject each retired field, one at a time, on a committed entry.
func test_every_retired_entry_field_is_refused_by_the_committed_validator() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var aggregate: Dictionary = _committed_aggregate()
	assert_true(STATE_SCHEMA.validate_aggregate(aggregate).get("ok", false),
		"the untampered real aggregate validates")
	for retired: String in RETIRED_ENTRY_FIELDS:
		var tampered: Dictionary = aggregate.duplicate(true)
		var entry: Dictionary = (tampered["entries"] as Array)[0]
		entry[retired] = "smuggled"
		var result: Dictionary = STATE_SCHEMA.validate_aggregate(tampered)
		assert_false(result.get("ok", true), retired + " must not be accepted on a committed entry")
		assert_eq(result.get("code"), &"invalid_committed_entry",
			"the exact-key contract is what refuses " + retired)


## Over the REAL committed schedule, end to end: no retired field survives into the aggregate the
## resolution froze, nor into the frozen context the adapter is handed. route_id is checked
## separately below, because the presentation REQUEST legitimately carries one.
func test_no_retired_field_reaches_the_adapter_over_a_real_committed_schedule() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var aggregate_keys := _every_key(_committed_aggregate())
	var context_keys := _every_key(request["context"])
	for retired: String in RETIRED_ENTRY_FIELDS:
		assert_false(aggregate_keys.has(retired),
			"the frozen committed aggregate carries no " + retired)
		assert_false(context_keys.has(retired),
			"the frozen presentation context carries no " + retired)


## route_id is the sharpest of the six, because the presentation request DOES carry one: the
## question is where it came from. A committed entry may not carry a route, and the route the
## producer emitted must equal the REGISTRY's route for that entry's action -- so the route is a
## registry fact, not a caller fact that merely moved.
func test_the_presentation_route_is_a_registry_fact_and_never_an_entry_field() -> void:
	if _root.is_empty():
		return
	_commit_and_begin(3, [_date("d-lav", 0, "lavinia", 3)])
	var request := _await_presentation()
	if request.is_empty():
		return
	var entry: Dictionary = (_committed_aggregate()["entries"] as Array)[0]
	assert_false(entry.has("route_id"), "a committed entry carries no route of its own")
	var found: Dictionary = _registry.find_record(str(entry["action_id"]))
	assert_true(found.get("ok", false), str(found))
	if not found.get("ok", false):
		return
	assert_eq(str(request["route_id"]),
		str(((found["value"] as Dictionary)["record"] as Dictionary)["route_id"]),
		"the emitted route is the registry's route for this action")


# -------------------------------------------------------------------------------------------------
# "No twofriends pseudo-route"
# -------------------------------------------------------------------------------------------------

## The pseudo-route is gone from every place a route can be declared, while the deferred PAIR keeps
## its stage and its presentation kind -- which is the distinction that makes the claim meaningful
## rather than a blanket ban on the substring.
func test_twofriends_survives_only_as_a_stage_and_never_as_a_route() -> void:
	if _root.is_empty():
		return
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


## The router half, stated for the retired name specifically: neither the pseudo-route nor the
## stage name is routable, because the only two semantic routes are Hospital and Dating.
func test_the_router_refuses_the_pseudo_route_and_the_stage_name_alike() -> void:
	if _root.is_empty():
		return
	var router: Node = load(ROUTER_PATH).new()
	add_child_autofree(router)
	assert_true(router.configure_schedule_presentation_ports(
		HOSPITAL_PORT.new(), DATING_PORT.new()).get("ok", false))
	for route: String in [PSEUDO_ROUTE, PAIR_STAGE]:
		var routed: Dictionary = router.route_presentation(route, {"route_id": route})
		assert_false(routed.get("ok", true), route + " must not be routable")
		assert_eq(routed.get("code"), &"invalid_presentation_route",
			route + " is refused as a route, not as a bad command")


## THE MIRROR IMAGE of the scan below, and the last dwm-p2r.18 SCOPE bullet stated as a fact.
##
## `SceneRouter.route_presentation()` existed, was tested, and had ZERO production callers: the walk
## derived an exact presentation intent, paused carrying its `route_id`, and handed it to nothing, so
## no Hospital or Dating adapter was ever launched. The scan below proves a legacy seam stays
## uncalled; this one proves the live seam IS called, and by the walk rather than by a scene.
##
## It goes red if anyone deletes the wire, and it goes red if the caller migrates into a Control
## node -- which is the failure mode Task 8 spent its whole budget removing.
func test_the_walk_is_the_production_caller_of_route_presentation() -> void:
	if _root.is_empty():
		return
	var callers: Array[String] = []
	for path: String in _production_scripts("res://scripts") + _production_scripts("res://autoload"):
		if path == ROUTER_PATH:
			continue
		if _code_lines(path).contains("route_presentation"):
			callers.append(path)
	assert_eq(callers, [COORDINATOR_PATH] as Array[String],
		"the day-resolution walk is the sole production script naming route_presentation; found: "
		+ str(callers))
	# NAMING IT IS NOT CALLING IT. The coordinator also names the seam in the capability set it
	# requires of a router, so the substring scan above stays green even with the dispatch deleted --
	# verified by mutation, not assumed. The call form is what proves the walk actually launches.
	assert_true(_code_lines(COORDINATOR_PATH).contains(".call(&\"route_presentation\""),
		"the walk must CALL the seam, not merely declare it in a required capability")
	assert_true(_code_lines(ROUTER_PATH).contains("func route_presentation"),
		"and the seam being pinned still exists on the router, so this scan is not vacuous")


## The capability the coordinator declares is the one the REAL router offers.
##
## The dispatch law is proved against a fake router in `tests/unit/test_day_resolution_coordinator.gd`
## because the real one instantiates a PackedScene and mutates `tree.current_scene`. That fake is only
## as good as its agreement with the real object, so the agreement is asserted here rather than
## assumed: a router method renamed on one side alone fails closed at composition, not at the first
## faint a player ever sees.
func test_the_real_router_satisfies_the_capability_the_coordinator_requires() -> void:
	if _root.is_empty():
		return
	var router: Node = load(ROUTER_PATH).new()
	add_child_autofree(router)
	var required: Array = load(COORDINATOR_PATH).PRESENTATION_ROUTER_METHODS
	assert_false(required.is_empty(), "the coordinator declares a route capability at all")
	for method: String in required:
		assert_true(router.has_method(method),
			"SceneRouter must offer " + method + ", which the coordinator requires")
	assert_true(load(COORDINATOR_PATH).new().configure_presentation_router(router).get("ok", false),
		"and the real router is adoptable by the real coordinator")


## THE PSEUDO-ROUTE PRODUCER STILL EXISTS, and this pins its containment rather than pretending it
## does not. GameState.execute_schedule_sequence_until_route_needed() still returns
## route == "twofriends" and create_missed_group_twofriends_entry() still builds an old-shape
## {type,friend_ids,...} entry. Both belong to the legacy transport GameState's own comment records
## as replaced by the committed-receipt start port -- and both are UNCALLED. This test is what
## makes "uncalled" a fact instead of a claim: it goes red the moment anyone wires the pseudo-route
## back into production.
func test_the_legacy_pseudo_route_producer_has_no_caller_in_production() -> void:
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
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
	if _root.is_empty():
		return
	for port: RefCounted in [HOSPITAL_PORT.new(), DATING_PORT.new()]:
		for forbidden: String in ["start_timeline", "start_timeline_id", "begin_physical"]:
			assert_false(port.has_method(forbidden),
				port.get_script().resource_path + " must not expose " + forbidden)


# -------------------------------------------------------------------------------------------------
# "No presentation-owned mutation"
# -------------------------------------------------------------------------------------------------

## The scene suites prove the SCENES mutate nothing by snapshot comparison. This proves the whole
## adapter set -- both ports and the narrative owner included -- cannot, because none of them names
## a gameplay owner or a mutation seam in executable code at all.
func test_no_presentation_adapter_names_a_gameplay_mutation_seam() -> void:
	if _root.is_empty():
		return
	for path: String in ADAPTER_PATHS:
		var code := _code_lines(path)
		for token: String in MUTATION_TOKENS:
			assert_false(code.contains(token), path + " must not name " + token)


## The guard on the guard. HospitalScene's doc comment deliberately names the two mutations Task 8
## removed; if the stripper ever stopped removing comments, the scan above would be testing prose
## and would still pass. This requires the tokens to be present in the RAW file and absent from the
## code, so the sweep above cannot go vacuous unnoticed.
func test_the_comment_stripper_is_doing_real_work() -> void:
	if _root.is_empty():
		return
	var raw := FileAccess.get_file_as_string(HOSPITAL_SCENE_PATH)
	var code := _code_lines(HOSPITAL_SCENE_PATH)
	assert_true(raw.length() > 0, "the scene source is readable")
	assert_true(code.length() > 0, "the scene has executable code")
	for token: String in ["GameState", "SceneRouter", "apply_hospital"]:
		assert_true(raw.contains(token),
			token + " is still named in HospitalScene's prose, which is what makes this a real test")
		assert_false(code.contains(token), token + " appears only in prose, never in code")


# -------------------------------------------------------------------------------------------------
# helpers
# -------------------------------------------------------------------------------------------------

## Source with every full-line comment removed, so a scan reads what EXECUTES rather than what the
## file says about itself.
func _code_lines(path: String) -> String:
	var kept: PackedStringArray = []
	for line: String in FileAccess.get_file_as_string(path).split("\n"):
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


## Every dictionary key anywhere inside value, at any depth.
func _every_key(value: Variant) -> Dictionary:
	var found: Dictionary = {}
	_collect_keys(value, found)
	return found


func _collect_keys(value: Variant, found: Dictionary) -> void:
	match typeof(value):
		TYPE_DICTIONARY:
			for key: Variant in (value as Dictionary):
				found[str(key)] = true
				_collect_keys((value as Dictionary)[key], found)
		TYPE_ARRAY:
			for item: Variant in (value as Array):
				_collect_keys(item, found)


func _registry_records() -> Array:
	var parsed: Variant = JSON.parse_string(
		FileAccess.get_file_as_string(REGISTRY.MANIFEST_PATH))
	assert_eq(typeof(parsed), TYPE_DICTIONARY, "the registry manifest parses")
	if typeof(parsed) != TYPE_DICTIONARY:
		return []
	return (parsed as Dictionary)["records"] as Array


func _active_plan() -> Dictionary:
	var plan: Variant = _game_state._run_lifecycle.to_dict()["active_resolution_plan"]
	return (plan as Dictionary) if typeof(plan) == TYPE_DICTIONARY else {}


func _committed_aggregate() -> Dictionary:
	return (_active_plan()["committed_schedule"] as Dictionary).duplicate(true)


## Drives to the first presentation boundary and returns the producer's exact request.
func _await_presentation() -> Dictionary:
	var steps := 0
	while steps < MAX_WALK_STEPS:
		steps += 1
		var cursor: Dictionary = _state_port.inspect_next_stage()
		if not cursor.get("ok", false) or not bool(cursor["value"]["has_stage"]):
			assert_true(false, "the walk ended before any presentation")
			return {}
		var begun: Dictionary = _state_port.begin_next_stage()
		assert_true(begun.get("ok", false), JSON.stringify(begun))
		if not begun.get("ok", false):
			return {}
		var value: Dictionary = begun["value"]
		if str(value["mode"]) == "await_registered_command":
			return ((value["command"] as Dictionary)["presentation_request"] as Dictionary)
		var receipt: Dictionary = value["receipt"]
		assert_true(_game_state._run_lifecycle.complete_active_stage(
			str((value["stage"] as Dictionary)["transaction_id"]),
			{"value": (receipt["value"] as Dictionary).duplicate(true)}).get("ok", false))
	assert_true(false, "the walk stopped advancing before a presentation")
	return {}


func _commit_and_begin(day: int, drafts: Array) -> void:
	_game_state._lifecycle_set_playing_day(day)
	var storage := JsonFileStorage.new(_root)
	var ledger: RefCounted = LEDGER.new()
	assert_true(ledger.configure(storage).get("ok", false))
	assert_true(ledger.load().get("ok", false))
	var commit_port: RefCounted = COMMIT_PORT.new(_game_state, _registry, _issuer, ledger)
	var command: Dictionary = _command("commit.day%d" % day)
	var prepared: Dictionary = commit_port.call(&"prepare_commit", {
		"transaction_id": command["id"],
		"transaction_issuer_receipt": command["receipt"],
		"expected_view_fingerprint": VIEW_FINGERPRINT,
		"day": day,
		"causal_day_instance": CAUSAL_DAY,
		"draft_entries": drafts.duplicate(true),
		"registry_fingerprint": _fingerprint,
	})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	if not prepared.get("ok", false):
		return
	var value: Dictionary = (prepared.get("value", {}) as Dictionary).duplicate(true)
	assert_true(commit_port.call(&"commit", value["game_state_candidate"]).get("ok", false))
	assert_true(_state_port.begin_or_resume(str(command["id"]) + ":resolution").get("ok", false))


func _date(draft_entry_id: String, slot_index: int, friend: String, day: int) -> Dictionary:
	var action_id := "solo:%s:day%d" % [friend, day]
	return {
		"draft_entry_id": draft_entry_id,
		"day": day,
		"slot_index": slot_index,
		"action_id": action_id,
		"action_kind": "solo",
		"participants": [friend],
		"source_receipt_id": _seed_solo_source(friend, day, action_id),
	}


func _seed_solo_source(friend_id: String, day: int, action_id: String) -> String:
	var offered: Dictionary = CONTACT_STATE.prepare_offer_solo(
		_game_state.contacts, friend_id, day, action_id, "offer.%s" % action_id)
	assert_true(offered.get("ok", false), str(offered))
	if not offered.get("ok", false):
		return ""
	var command: Dictionary = _command("open.%s.day%d" % [friend_id, day])
	var found: Dictionary = _registry.find_record(action_id)
	assert_true(found.get("ok", false), str(found))
	if not found.get("ok", false):
		return ""
	var opened: Dictionary = CONTACT_STATE.prepare_open_contact(
		offered["value"]["candidate"], friend_id, day, command["id"], command["receipt"],
		_issuer, ((found["value"] as Dictionary)["record"] as Dictionary))
	assert_true(opened.get("ok", false), str(opened))
	if not opened.get("ok", false):
		return ""
	_game_state.contacts = opened["value"]["candidate"]
	return str(opened["receipt"]["receipt_id"])


func _command(label: String) -> Dictionary:
	if not _commands.has(label):
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		assert_true(issued.get("ok", false), str(issued))
		_commands[label] = {
			"id": str((issued.get("value", {}) as Dictionary).get("token", "")),
			"receipt": ((issued.get("value", {}) as Dictionary).get("issuer_receipt", {}) as Dictionary).duplicate(true),
		}
	return (_commands[label] as Dictionary).duplicate(true)
