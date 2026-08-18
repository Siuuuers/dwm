extends "res://addons/gut/test.gd"
# Same-boot desktop/Schedule foundation identity (Plan 01 Task 8 Step 8.1, dwm-p2r.14).
#
# WHY THIS FILE EXISTS NOW. Plan 01 Task 8 names `tests/integration/test_desktop_bootstrap_wiring.gd`
# in both its RED and GREEN gate command lines, but the file had never been authored on any branch
# (DEVIATION-2 on dwm-p2r.14: `.9` shipped at a narrower scope than Plan 02 chartered). Task 8 needs
# it, so Task 8 writes it.
#
# WHAT IT OWNS. `ApplicationBootstrap.get_desktop_contract_state()` -- the read-only probe Step 8.1
# requires -- and the law it exists to enforce: composing the presentation layer must not
# reconstruct, swap, or fake any foundation instance. The probe is captured BEFORE presentation
# configuration and compared afterwards, which is the only way a silently rebuilt issuer or ledger
# would ever be caught.
#
# WHY IT MUST BE INTEGERS ONLY. A probe that returned live Objects would itself be the leak it is
# meant to detect: any caller could reach in and take an owner. Every value below is an int or a
# bool, and one test asserts exactly that.
#
# THESE NUMBERS ARE PROCESS-LOCAL. They are meaningless across runs. Nothing here compares them to a
# prior run or to a committed evidence file -- only to another reading from this same boot.
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so every local declaration
# below carries an explicit type annotation.

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const COORDINATOR := preload("res://scripts/application/run/DayResolutionCoordinator.gd")
const CONTACT_COMMAND_PORT := preload("res://scripts/application/contact/ContactCommandPort.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"

## Every foundation identity Step 8.1 requires to survive presentation configuration unchanged.
const FOUNDATION_IDENTITY_KEYS: Array[String] = [
	"causal_day_advance_identity_port_instance_id",
	"contact_command_port_instance_id",
	"day_resolution_coordinator_instance_id",
	"day_resolution_start_port_instance_id",
	"day_resolution_state_port_instance_id",
	"issuer_instance_id",
	"provenance_owner_instance_id",
	"publication_ledger_instance_id",
	"root_store_instance_id",
	"schedule_port_instance_id",
	"schedule_registry_instance_id",
]

var _bootstrap: Node = null
var _game_state: Node = null
var _state_port: RefCounted = null
var _coordinator: RefCounted = null
var _issuer: RefCounted = null
var _storage: RefCounted = null
var _root_counter := 0


## A bootstrap that resolves its tree targets from an injected map instead of `/root`, so the suite
## can wire one stage by hand without adding Bootstrap to the tree (whose `_ready()` would defer into
## the whole `start()` sequence).
class HarnessBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	var targets: Dictionary = {}

	func _target(target_name: StringName) -> Node:
		return targets.get(String(target_name), null)


func before_each() -> void:
	_storage = JsonFileStorage.new(_isolated_root())
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(_storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(root_store).get("ok", false))

	_game_state = load(GAME_STATE_PATH).new()
	autofree(_game_state)
	_game_state.reset_game()
	_state_port = STATE_PORT.new(_game_state)
	_coordinator = COORDINATOR.new()

	_bootstrap = HarnessBootstrap.new()
	autofree(_bootstrap)
	_bootstrap.set("_profile_storage", _storage)
	_bootstrap.set("_desktop_issuer_root_store", root_store)
	_bootstrap.set("_desktop_identity_nonce_issuer", _issuer)
	_bootstrap.set("_retained_day_resolution_state_port", _state_port)
	_bootstrap.set("_retained_day_resolution_coordinator", _coordinator)
	_bootstrap.set("targets", {
		"DialogicBridge": _bridge(),
		"SceneRouter": _router(),
	})


func _bridge() -> Node:
	var bridge: Node = load("res://autoload/DialogicBridge.gd").new()
	add_child_autofree(bridge)
	return bridge


func _router() -> Node:
	var router: Node = load("res://autoload/SceneRouter.gd").new()
	add_child_autofree(router)
	return router


func _isolated_root() -> String:
	var wrapper: String = OS.get_environment("DWM_TEST_ROOT")
	assert_false(wrapper.strip_edges().is_empty(), "DWM_TEST_ROOT is required")
	_root_counter += 1
	return wrapper.path_join("desktop-wiring-%d" % _root_counter)


## Composes the retained foundation in the same order `configure_day_resolution()` does: the shared
## advance-identity owner, then the Schedule foundation. The contact command port belongs to the
## earlier identity stage, so the harness supplies the one Bootstrap would already be holding.
func _build_foundation() -> void:
	if _bootstrap.get("_contact_command_port") == null:
		_bootstrap.set("_contact_command_port", CONTACT_COMMAND_PORT.new())
	var advance: Dictionary = _bootstrap.call(&"_configure_causal_day_advance_identity",
		_coordinator)
	assert_true(advance.get("ok", false), "the shared advance-identity owner composes: "
		+ str(advance))
	var built: Dictionary = _bootstrap.call(&"_construct_schedule_foundation", _game_state,
		_state_port)
	assert_true(built.get("ok", false), "the Schedule foundation composes: " + str(built))


func _build_presentation() -> Dictionary:
	return _bootstrap.call(&"_construct_schedule_presentation", _coordinator)


func _foundation_identities(state: Dictionary) -> Dictionary:
	var identities: Dictionary = {}
	for key: String in FOUNDATION_IDENTITY_KEYS:
		identities[key] = state.get(key)
	return identities


# -------------------------------------------------------------------------------------------------
# the probe itself
# -------------------------------------------------------------------------------------------------

func test_the_probe_exists_and_returns_only_integers_and_booleans() -> void:
	assert_true(_bootstrap.has_method("get_desktop_contract_state"),
		"Step 8.1 requires this read-only probe")
	_build_foundation()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_false(state.is_empty())
	for key: Variant in state:
		var value: Variant = state[key]
		assert_true(typeof(value) == TYPE_INT or typeof(value) == TYPE_BOOL,
			"%s must be an int or bool, never a live Object" % str(key))


func test_the_probe_names_every_foundation_identity_step_8_1_requires() -> void:
	_build_foundation()
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	for key: String in FOUNDATION_IDENTITY_KEYS:
		assert_true(state.has(key), "the probe must expose " + key)
		assert_true(int(state[key]) != 0, key + " must name a retained instance")


func test_reading_the_probe_twice_is_stable_and_mutates_nothing() -> void:
	_build_foundation()
	var first: Dictionary = _bootstrap.get_desktop_contract_state()
	var second: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_eq(second, first, "the probe is a pure read")


# -------------------------------------------------------------------------------------------------
# the law the probe exists for
# -------------------------------------------------------------------------------------------------

func test_presentation_configuration_reconstructs_no_foundation_instance() -> void:
	_build_foundation()
	var before: Dictionary = _foundation_identities(_bootstrap.get_desktop_contract_state())
	assert_true(_build_presentation().get("ok", false))
	var after: Dictionary = _foundation_identities(_bootstrap.get_desktop_contract_state())
	assert_eq(after, before,
		"composing the presentation layer rebuilds no foundation object")


func test_identical_startup_replay_reuses_every_instance() -> void:
	_build_foundation()
	assert_true(_build_presentation().get("ok", false))
	var first: Dictionary = _bootstrap.get_desktop_contract_state()

	_build_foundation()
	assert_true(_build_presentation().get("ok", false),
		"identical replay is idempotent rather than a replacement conflict")
	assert_eq(_bootstrap.get_desktop_contract_state(), first,
		"a legitimate re-run builds a second of nothing")


func test_a_swapped_issuer_is_visible_in_the_probe() -> void:
	# The probe's whole purpose: if a later edit ever re-pointed a retained dependency, the same-boot
	# reading changes. This test proves the probe would actually notice.
	_build_foundation()
	var before: Dictionary = _bootstrap.get_desktop_contract_state()
	var other_store: RefCounted = ROOT_STORE.new()
	assert_true(other_store.configure(JsonFileStorage.new(_isolated_root()),
		NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(other_store.load_or_create().get("ok", false))
	var other_issuer: RefCounted = ISSUER.new()
	assert_true(other_issuer.configure(other_store).get("ok", false))
	_bootstrap.set("_desktop_identity_nonce_issuer", other_issuer)

	var after: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_ne(int(after["issuer_instance_id"]), int(before["issuer_instance_id"]),
		"a swapped issuer changes its same-boot identity")


func test_the_probe_reports_hospital_ready_and_dating_deliberately_not_ready() -> void:
	_build_foundation()
	assert_true(_build_presentation().get("ok", false))
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_true(bool(state["hospital_presentation_ready"]),
		"the Hospital route is composed and ready")
	assert_false(bool(state["dating_presentation_ready"]),
		"Phase 2R exposes the Dating route as NOT ready; dwm-oyo.4 owns that owner")
	assert_true(int(state["dating_presentation_port_instance_id"]) != 0,
		"the Dating port is still CONSTRUCTED and retained, just unconfigured")


func test_an_unbuilt_foundation_reports_zero_rather_than_guessing() -> void:
	var state: Dictionary = _bootstrap.get_desktop_contract_state()
	assert_eq(int(state["provenance_owner_instance_id"]), 0)
	assert_eq(int(state["schedule_port_instance_id"]), 0)
	assert_false(bool(state["hospital_presentation_ready"]))
	assert_false(bool(state["dating_presentation_ready"]))
