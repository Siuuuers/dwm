extends "res://addons/gut/test.gd"

const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const GAME := preload("res://autoload/GameState.gd")
const PROFILE := preload("res://autoload/ProfileManager.gd")
const DAY_STATE := preload("res://scripts/application/run/GameStateDayResolutionPort.gd")
const DAY_START := preload("res://scripts/application/run/DayResolutionStartPort.gd")
const CONSEQUENCE := preload("res://scripts/application/desktop/DesktopConsequenceCoordinator.gd")
const ROUND := preload("res://scripts/application/minesweeper/MinesweeperRoundCoordinator.gd")
const SHOP := preload("res://scripts/application/shop/MinesweeperShopPurchaseParticipant.gd")
const CONDITION := preload("res://scripts/application/run/ConditionHospitalCoordinator.gd")
const CONDITION_STATE := preload("res://scripts/domain/run/ConditionHospitalState.gd")
const CONDITION_ADAPTER := preload("res://scripts/application/run/GameStateConditionHospitalPort.gd")
const PAIR := preload("res://scripts/application/run/PairDeckDrawPort.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")

class LifecycleBootstrap extends "res://autoload/ApplicationBootstrap.gd":
	# Exercise production teardown without queuing unrelated startup stages.
	func _ready() -> void:
		pass

class Checkpoints extends RefCounted:
	var calls := 0
	func preview_checkpoint_id(_input: Variant = null, _kind: Variant = null) -> Dictionary:
		calls += 1
		return {"ok": false, "code": &"unexpected_shutdown_checkpoint"}
	func prepare(_input: Variant = null, _kind: Variant = null, _target: Variant = null) -> Dictionary:
		calls += 1
		return {"ok": false, "code": &"unexpected_shutdown_checkpoint"}
	func commit(_candidate: Variant = null) -> Dictionary:
		calls += 1
		return {"ok": false, "code": &"unexpected_shutdown_checkpoint"}

func _cycles(bootstrap: Node, checkpoints: RefCounted) -> Dictionary:
	# These are the production configure seams that formed the three cycles.
	# Bootstrap retains the same roots as a full startup; no private edge is forged.
	var game: Node = autofree(GAME.new())
	var profile: Node = autofree(PROFILE.new())
	var gate := GATE.new()
	var issuer: RefCounted = BOOTSTRAP.DESKTOP_IDENTITY_NONCE_ISSUER.new()
	var day_state := DAY_STATE.new(game)
	var day_start := DAY_START.new(day_state, BOOTSTRAP.SCHEDULE_ACTION_REGISTRY.new(),
		issuer, BOOTSTRAP.SCHEDULE_PUBLICATION_LEDGER.new())
	assert_true(day_state.configure_resolution_identity(issuer, day_start).ok)
	bootstrap.set("_retained_day_resolution_state_port", day_state)
	bootstrap.set("_retained_day_resolution_start_port", day_start)

	var consequence := CONSEQUENCE.new()
	var round_owner := ROUND.new()
	assert_true(consequence.configure_action_source_ports(round_owner, SHOP.new()).ok)
	assert_true(round_owner.configure_consequence_port(consequence, gate).ok)
	bootstrap.set("_retained_desktop_consequence_coordinator", consequence)
	bootstrap.set("_retained_minesweeper_round_coordinator_app", round_owner)

	var condition := CONDITION.new()
	var adapter := CONDITION_ADAPTER.new()
	var pair := PAIR.new()
	assert_true(condition.configure(CONDITION_STATE.new(), BOOTSTRAP.DESKTOP_CONSEQUENCE_STATE.new(),
		adapter, checkpoints, gate).ok)
	assert_true(pair.configure(game, profile, gate, condition).ok)
	assert_true(adapter.configure_pair_deck(pair).ok)
	bootstrap.set("_retained_condition_hospital_coordinator", condition)
	bootstrap.set("_retained_condition_hospital_adapter", adapter)
	bootstrap.set("_pair_deck_draw_port", pair)
	return {"day_state": weakref(day_state), "day_start": weakref(day_start),
		"consequence": weakref(consequence), "round": weakref(round_owner),
		"condition": weakref(condition), "adapter": weakref(adapter), "pair": weakref(pair),
		"pair_rng": weakref(pair.get("_rng"))}

func _assert_retained(refs: Dictionary) -> void:
	for key: String in refs:
		assert_not_null(refs[key].get_ref(), "configured runtime dependency remains owned: " + key)

func _assert_released(refs: Dictionary) -> void:
	for key: String in refs:
		assert_null(refs[key].get_ref(), "Bootstrap deletion must release the actual runtime graph: " + key)

func test_off_tree_bootstrap_free_breaks_all_three_real_cycles() -> void:
	var bootstrap := LifecycleBootstrap.new()
	var checkpoints := Checkpoints.new()
	var refs := _cycles(bootstrap, checkpoints)
	_assert_retained(refs)
	bootstrap.free()
	_assert_released(refs)
	assert_eq(checkpoints.calls, 0, "shutdown cannot create, preview, or commit a checkpoint")

func test_tree_exit_then_delete_is_idempotent_and_releases_owned_graph() -> void:
	var bootstrap := LifecycleBootstrap.new()
	var checkpoints := Checkpoints.new()
	var refs := _cycles(bootstrap, checkpoints)
	add_child(bootstrap)
	_assert_retained(refs)
	remove_child(bootstrap)
	# EXIT_TREE has released back edges; Bootstrap still owns the remaining roots.
	_assert_retained(refs)
	bootstrap.free()
	_assert_released(refs)
	assert_eq(checkpoints.calls, 0)

func test_repeated_explicit_release_and_partial_startup_free_are_safe() -> void:
	var bootstrap := LifecycleBootstrap.new()
	var checkpoints := Checkpoints.new()
	var refs := _cycles(bootstrap, checkpoints)
	bootstrap.call("_release_runtime_dependencies")
	bootstrap.call("_release_runtime_dependencies")
	bootstrap.free()
	_assert_released(refs)
	assert_eq(checkpoints.calls, 0)
	var incomplete := LifecycleBootstrap.new()
	incomplete.free()
