extends "res://addons/gut/test.gd"
# Bootstrap ownership of the Schedule-Done presentation layer (Plan 01 Task 8 Step 8.6, dwm-p2r.14).
#
# WHAT THIS FILE OWNS. That the composition root builds EXACTLY ONE narrative presentation owner,
# EXACTLY ONE Hospital port configured with it, and EXACTLY ONE Dating port left deliberately
# unconfigured -- and that those exact identities, not copies, reach the coordinator and SceneRouter.
#
# WHY EACH CLAIM MATTERS RATHER THAN BEING CEREMONY:
#   * A second OWNER would mean two objects observing the same bridge, so one timeline ending would
#     produce two "trusted" completions and the port would settle a presentation twice.
#   * A port the coordinator does not hold would publish completions nobody checkpoints; the stage
#     would hang forever while the player watched a finished timeline.
#   * A CONFIGURED Dating port would be this task claiming a playable relationship board that Phase
#     2R never built. Its unreadiness is a deliverable, and it is asserted as one.
#
# HOW IT DRIVES BOOTSTRAP. `_construct_schedule_presentation()` is called directly rather than by
# running the whole startup sequence, following the precedent in
# test_schedule_foundation_bootstrap_wiring.gd: this suite is about object identity, and a full
# `start()` would drag in root selection and profile IO without sharpening a single claim. Tree
# targets are injected through a harness subclass, so Bootstrap is never added to the tree and its
# `_ready()` -- which defers into `start()` -- never fires.
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so every local declaration
# below carries an explicit type annotation.

const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const HOSPITAL_PORT := preload("res://scripts/application/run/HospitalPresentationPort.gd")
const DATING_PORT := preload("res://scripts/application/run/DatingPresentationPort.gd")
const OWNER_ADAPTER := preload("res://scripts/application/narrative/DialogicPresentationOwnerAdapter.gd")

## The exact fields Bootstrap must retain, one instance each.
const RETAINED_FIELDS: Array[String] = [
	"_retained_dating_presentation_port", "_retained_hospital_presentation_port",
	"_retained_presentation_owner_adapter",
]

var _bootstrap: Node = null
var _coordinator: RefCounted = null
var _issuer: RefCounted = null
var _bridge: Node = null
var _router: Node = null
var _root_counter := 0


class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)


func before_each() -> void:
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(JsonFileStorage.new(_isolated_root()),
		NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(root_store).get("ok", false))

	_bridge = load("res://autoload/DialogicBridge.gd").new()
	add_child_autofree(_bridge)
	_router = load("res://autoload/SceneRouter.gd").new()
	add_child_autofree(_router)
	_coordinator = COORDINATOR.new()

	_bootstrap = HarnessBootstrap.new()
	autofree(_bootstrap)
	_bootstrap.set("_desktop_identity_nonce_issuer", _issuer)
	_bootstrap.set("targets", {"DialogicBridge": _bridge, "SceneRouter": _router})


func _isolated_root() -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	return wrapper.path_join("presentation-wiring-%d" % _root_counter)


func _compose() -> Dictionary:
	return _bootstrap.call(&"_construct_schedule_presentation", _coordinator)


func _retained(field: String) -> Object:
	return _bootstrap.get(field)


# -------------------------------------------------------------------------------------------------
# construction
# -------------------------------------------------------------------------------------------------

func test_composition_retains_exactly_one_of_each_presentation_object() -> void:
	var composed: Dictionary = _compose()
	assert_true(composed.get("ok", false), str(composed))
	for field: String in RETAINED_FIELDS:
		assert_not_null(_retained(field), field + " is retained")
	assert_eq(_retained("_retained_presentation_owner_adapter").get_script(), OWNER_ADAPTER)
	assert_eq(_retained("_retained_hospital_presentation_port").get_script(), HOSPITAL_PORT)
	assert_eq(_retained("_retained_dating_presentation_port").get_script(), DATING_PORT)


func test_identical_startup_replay_reuses_every_instance() -> void:
	assert_true(_compose().get("ok", false))
	var first: Dictionary = {}
	for field: String in RETAINED_FIELDS:
		first[field] = _retained(field).get_instance_id()

	assert_true(_compose().get("ok", false),
		"a legitimate re-run is idempotent, not a replacement conflict")
	for field: String in RETAINED_FIELDS:
		assert_eq(_retained(field).get_instance_id(), int(first[field]),
			field + " is not rebuilt on identical replay")


func test_the_hospital_port_retains_the_exact_bootstrap_owned_adapter() -> void:
	# A second owner observing the same bridge would turn one timeline ending into two "trusted"
	# completions, so the port's retained owner identity is checked, not merely its type.
	assert_true(_compose().get("ok", false))
	var replayed: Dictionary = _retained("_retained_hospital_presentation_port").configure(
		_issuer, _retained("_retained_presentation_owner_adapter"))
	assert_true(replayed.get("ok", false), "the port already holds this exact owner")
	assert_true(bool(replayed["value"]["already_configured"]))
	assert_eq(int(replayed["value"]["owner_instance_id"]),
		_retained("_retained_presentation_owner_adapter").get_instance_id())


func test_the_adapter_retains_the_existing_bridge_rather_than_a_new_one() -> void:
	assert_true(_compose().get("ok", false))
	var replayed: Dictionary = _retained("_retained_presentation_owner_adapter").configure(_bridge)
	assert_true(replayed.get("ok", false), "the adapter already holds the existing bridge")
	assert_eq(int(replayed["value"]["bridge_instance_id"]), _bridge.get_instance_id())


func test_composition_without_an_issuer_or_bridge_fails_closed() -> void:
	var without_issuer: Node = HarnessBootstrap.new()
	autofree(without_issuer)
	without_issuer.set("targets", {"DialogicBridge": _bridge})
	assert_eq(without_issuer.call(&"_construct_schedule_presentation", COORDINATOR.new()).get("code"),
		&"missing_identity_issuer")

	var without_bridge: Node = HarnessBootstrap.new()
	autofree(without_bridge)
	without_bridge.set("_desktop_identity_nonce_issuer", _issuer)
	without_bridge.set("targets", {})
	assert_eq(without_bridge.call(&"_construct_schedule_presentation", COORDINATOR.new()).get("code"),
		&"missing_stage_adapter")


# -------------------------------------------------------------------------------------------------
# injection into the coordinator and the router
# -------------------------------------------------------------------------------------------------

func test_the_coordinator_receives_the_exact_retained_port_identities() -> void:
	assert_true(_compose().get("ok", false))
	var replayed: Dictionary = _coordinator.configure_presentation_ports(
		_retained("_retained_hospital_presentation_port"),
		_retained("_retained_dating_presentation_port"))
	assert_true(replayed.get("ok", false), "the coordinator already holds these exact ports")
	assert_true(bool(replayed["value"]["already_configured"]))
	assert_eq(int(replayed["value"]["hospital_port_instance_id"]),
		_retained("_retained_hospital_presentation_port").get_instance_id())
	assert_eq(int(replayed["value"]["dating_port_instance_id"]),
		_retained("_retained_dating_presentation_port").get_instance_id())


func test_the_coordinator_refuses_a_replacement_port() -> void:
	assert_true(_compose().get("ok", false))
	var replaced: Dictionary = _coordinator.configure_presentation_ports(
		HOSPITAL_PORT.new(), DATING_PORT.new())
	assert_false(replaced.get("ok", true))
	assert_eq(replaced.get("code"), &"presentation_ports_conflict")


func test_the_coordinator_refuses_an_incomplete_presentation_capability() -> void:
	var fresh: RefCounted = COORDINATOR.new()
	assert_eq(fresh.configure_presentation_ports(RefCounted.new(), DATING_PORT.new()).get("code"),
		&"presentation_ports_conflict")
	assert_eq(fresh.configure_presentation_ports(null, null).get("code"),
		&"presentation_ports_conflict")


func test_the_router_receives_the_exact_retained_port_identities() -> void:
	assert_true(_compose().get("ok", false))
	assert_true(_router.is_schedule_presentation_ports_configured())
	var replayed: Dictionary = _router.configure_schedule_presentation_ports(
		_retained("_retained_hospital_presentation_port"),
		_retained("_retained_dating_presentation_port"))
	assert_true(replayed.get("ok", false))
	assert_true(bool(replayed["value"]["already_configured"]))
	assert_eq(int(replayed["value"]["hospital_port_instance_id"]),
		_retained("_retained_hospital_presentation_port").get_instance_id())


func test_the_router_refuses_a_replacement_port() -> void:
	assert_true(_compose().get("ok", false))
	var replaced: Dictionary = _router.configure_schedule_presentation_ports(
		HOSPITAL_PORT.new(), DATING_PORT.new())
	assert_false(replaced.get("ok", true))
	assert_eq(replaced.get("code"), &"schedule_presentation_ports_already_configured")


# -------------------------------------------------------------------------------------------------
# the deliberate Dating handoff, stated in bootstrap evidence
# -------------------------------------------------------------------------------------------------

func test_hospital_is_ready_and_dating_is_deliberately_not() -> void:
	var composed: Dictionary = _compose()
	assert_true(composed.get("ok", false))
	assert_true(bool(composed["value"]["hospital_ready"]))
	assert_false(bool(composed["value"]["dating_ready"]),
		"bootstrap evidence states the Dating owner is missing rather than hiding it")
	assert_true(_retained("_retained_hospital_presentation_port").is_ready())
	assert_false(_retained("_retained_dating_presentation_port").is_ready())


func test_bootstrap_configures_no_dating_owner_at_all() -> void:
	# The handoff is a MISSING OWNER, and it must be missing because nobody configured one -- not
	# because a configured one happens to answer false.
	assert_true(_compose().get("ok", false))
	var dating: RefCounted = _retained("_retained_dating_presentation_port")
	var begun: Dictionary = dating.begin({})
	assert_eq(begun.get("code"), &"dating_physical_owner_unconfigured",
		"the port refuses before it even reaches request validation")


func test_the_router_refuses_to_route_an_unready_dating_presentation() -> void:
	assert_true(_compose().get("ok", false))
	var routed: Dictionary = _router.route_presentation("dating", {
		"route_id": "dating", "timeline_id": "dating.solo.sylvia.day3.pre_challenge",
	})
	assert_false(routed.get("ok", true))
	assert_eq(routed.get("code"), &"presentation_port_not_ready",
		"an unconfigured Dating route fails closed rather than opening an improvised board")


func test_the_router_refuses_an_unknown_route_or_a_mismatched_command() -> void:
	assert_true(_compose().get("ok", false))
	assert_eq(_router.route_presentation("main", {"route_id": "main"}).get("code"),
		&"invalid_presentation_route")
	assert_eq(_router.route_presentation("hospital", {"route_id": "dating"}).get("code"),
		&"invalid_presentation_route", "the command must name the route it is being sent to")
	assert_eq(_router.route_presentation("hospital", {}).get("code"),
		&"invalid_presentation_command")


func test_an_unconfigured_router_routes_nothing() -> void:
	var fresh: Node = load("res://autoload/SceneRouter.gd").new()
	add_child_autofree(fresh)
	assert_false(fresh.is_schedule_presentation_ports_configured())
	assert_eq(fresh.route_presentation("hospital", {"route_id": "hospital"}).get("code"),
		&"schedule_presentation_ports_unconfigured")
