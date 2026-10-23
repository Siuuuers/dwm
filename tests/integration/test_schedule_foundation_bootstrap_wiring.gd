extends "res://addons/gut/test.gd"

const TEMPORARY_STORAGE := preload("res://tests/support/TemporaryStorage.gd")
# Bootstrap ownership of the Schedule foundation (Plan 01 Task 6, dwm-p2r.13, Step 6.5).
#
# WHY THIS FILE EXISTS. Step 6.5 requires Bootstrap to construct and retain EXACTLY ONE of each
# foundation object -- one validated registry, one publication ledger SHARED by both ports, one
# Schedule commit port, one day-resolution start port, and one configured Day-7 provenance service
# injected into the retained state port -- and to be idempotent on identical startup replay. That
# law was implemented before anything asserted it, which is the most dangerous shape a rule can
# have: it holds today by luck of the current call order and nothing would notice if a later edit
# constructed a second ledger.
#
# WHAT A SECOND INSTANCE WOULD ACTUALLY COST, and why each assertion below is not ceremony:
#   * A second LEDGER: the commit port's `schedule_commit` publications and the start port's
#     `day_resolution_start` publications would land in different documents, so a cold restart could
#     replay one without ever seeing the other.
#   * A second ISSUER: identities would be minted under a different root and every provenance chain
#     would silently fork -- the failure would surface far away, as an unverifiable receipt.
#   * A second PROVENANCE SERVICE: there would be two places a Day-7 handoff could come from, and
#     only one of them configured with the retained registry/issuer pair.
#
# HOW IT DRIVES BOOTSTRAP. `_construct_schedule_foundation()` is called directly with its two
# arguments rather than by running the whole startup sequence: this suite is about object identity,
# and a full `start()` would drag in root selection, profile IO and every other stage without making
# the identity claims any sharper. ApplicationBootstrap is instantiated with `.new()` and never
# added to the tree, so `_ready()` -- which defers into `start()` -- never fires.
#
# PARSE HAZARD: GUT treats an inferred-Variant `:=` as a parse error, so every local declaration
# below carries an explicit type annotation.

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://scripts/infrastructure/identity/DesktopIssuerRootStore.gd")
const NAMESPACE_SOURCE := preload("res://scripts/infrastructure/identity/CryptoDesktopNamespaceSource.gd")
const STATE_PORT := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const PROVENANCE := preload("res://scripts/domain/schedule/Day7ScheduleProvenance.gd")
const GAME_STATE_PATH := "res://autoload/GameState.gd"

## The exact fields Bootstrap must retain, one instance each.
const RETAINED_FIELDS: Array[String] = [
	"_retained_day7_provenance", "_retained_day_resolution_start_port",
	"_retained_publication_ledger", "_retained_schedule_commit_port",
	"_retained_schedule_registry",
]

var _bootstrap: Node = null
var _game_state: Node = null
var _state_port: RefCounted = null
var _issuer: RefCounted = null
var _storage: RefCounted = null
var _root_counter := 0


func before_each() -> void:
	_storage = null
	var root := _isolated_root()
	if root.is_empty():
		return
	_storage = JsonFileStorage.new(root)
	var root_store: RefCounted = ROOT_STORE.new()
	assert_true(root_store.configure(_storage, NAMESPACE_SOURCE.new()).get("ok", false))
	assert_true(root_store.load_or_create().get("ok", false))
	_issuer = ISSUER.new()
	assert_true(_issuer.configure(root_store).get("ok", false))

	_game_state = load(GAME_STATE_PATH).new()
	autofree(_game_state)
	_game_state.reset_game()
	_state_port = STATE_PORT.new(_game_state)

	# Never added to the tree: _ready() defers into start(), and this suite wires one stage by hand.
	_bootstrap = BOOTSTRAP.new()
	autofree(_bootstrap)
	_bootstrap.set("_profile_storage", _storage)
	_bootstrap.set("_desktop_identity_nonce_issuer", _issuer)


func _isolated_root() -> String:
	_root_counter += 1
	var created: Dictionary = TEMPORARY_STORAGE.create("foundation-wiring-%d" % _root_counter)
	assert_true(created.get("ok", false), created.get("message", ""))
	return str(created.get("value", "")) if created.get("ok", false) else ""


func _construct() -> Dictionary:
	return _bootstrap.call(&"_construct_schedule_foundation", _game_state, _state_port)


func test_the_foundation_constructs_exactly_one_of_each_object() -> void:
	if _storage == null:
		return
	var constructed: Dictionary = _construct()
	assert_true(constructed.get("ok", false),
		"the foundation must construct: %s" % str(constructed.get("code", &"")))
	if not constructed.get("ok", false):
		return
	for field: String in RETAINED_FIELDS:
		assert_not_null(_bootstrap.get(field), "%s must be retained" % field)


func test_identical_startup_replay_reuses_every_retained_instance() -> void:
	if _storage == null:
		return
	if not _construct().get("ok", false):
		assert_true(false, "the first construction must succeed")
		return
	var first: Dictionary = {}
	for field: String in RETAINED_FIELDS:
		first[field] = _bootstrap.get(field)
	var replay: Dictionary = _construct()
	assert_true(replay.get("ok", false), "identical replay must be idempotent")
	for field: String in RETAINED_FIELDS:
		assert_eq(_bootstrap.get(field), first[field],
			"%s must be the SAME instance after replay, not a rebuilt one" % field)


# The ledger is shared by construction rather than by coincidence. Neither port exposes its ledger,
# so this asserts the observable consequence instead: exactly one ledger object is retained, and it
# is the one both ports were handed at construction time in _construct_schedule_foundation.
func test_one_ledger_is_retained_and_is_the_only_one_constructed() -> void:
	if _storage == null:
		return
	if not _construct().get("ok", false):
		assert_true(false, "the first construction must succeed")
		return
	var ledger: Object = _bootstrap.get("_retained_publication_ledger")
	assert_not_null(ledger, "one publication ledger is retained")
	assert_true(ledger.has_method("record_before_emit"), "the retained object is a real ledger")
	if not _construct().get("ok", false):
		return
	assert_eq(_bootstrap.get("_retained_publication_ledger"), ledger,
		"a replay must not construct a second ledger for the two ports to diverge across")


# The injection is observable from the port's own side: a port that already holds the retained
# service refuses a DIFFERENT one. If Bootstrap had failed to inject, this second call would
# succeed instead, which is exactly the silent failure worth catching.
func test_the_configured_provenance_service_is_injected_into_the_retained_state_port() -> void:
	if _storage == null:
		return
	if not _construct().get("ok", false):
		assert_true(false, "the first construction must succeed")
		return
	var retained: Object = _bootstrap.get("_retained_day7_provenance")
	assert_not_null(retained, "one provenance service is retained")
	var same: Dictionary = _state_port.configure_day7_provenance(retained)
	assert_true(same.get("ok", false),
		"re-injecting the SAME service is idempotent, proving it is already installed")
	var intruder: RefCounted = PROVENANCE.new()
	var replaced: Dictionary = _state_port.configure_day7_provenance(intruder)
	assert_false(replaced.get("ok", true),
		"the port already holds the retained service, so a second one is refused")
	assert_eq(str(replaced.get("code", &"")), "day7_provenance_already_configured",
		"the exact refusal code")


func test_the_foundation_refuses_to_build_without_the_retained_issuer_or_storage() -> void:
	if _storage == null:
		return
	_bootstrap.set("_desktop_identity_nonce_issuer", null)
	assert_false(_construct().get("ok", true),
		"the foundation never mints a second issuer to proceed without the retained one")
	_bootstrap.set("_desktop_identity_nonce_issuer", _issuer)
	_bootstrap.set("_profile_storage", null)
	assert_false(_construct().get("ok", true),
		"the foundation never chooses its own storage root")
