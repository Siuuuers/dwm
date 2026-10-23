extends "res://addons/gut/test.gd"
# One mutation-gate identity shared across the configured owners, plus the
# SceneRouter common-gate matrix and the fatal-latch fence
# (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 7).

const GATE_PATH := "res://scripts/application/transaction/ApplicationMutationGate.gd"
const GS_PATH := "res://autoload/GameState.gd"
const SAVE_MANAGER_PATH := "res://autoload/SaveManager.gd"
const ROUTER_PATH := "res://autoload/SceneRouter.gd"

func test_one_gate_identity_across_owners() -> void:
	var gate: RefCounted = load(GATE_PATH).new()
	var gs: Node = load(GS_PATH).new()
	add_child_autofree(gs)
	var manager: Node = load(SAVE_MANAGER_PATH).new()
	autofree(manager)
	var router: Node = load(ROUTER_PATH).new()
	add_child_autofree(router)
	for owner: Node in [gs, manager, router]:
		var configured: Dictionary = owner.configure_mutation_gate(gate)
		assert_true(configured["ok"], JSON.stringify(configured))
		assert_eq(configured["value"]["gate_instance_id"], gate.get_instance_id(),
			"every owner retains the one gate identity")

func test_scene_router_common_gate_matrix() -> void:
	var router: Node = load(ROUTER_PATH).new()
	add_child_autofree(router)
	var gate: RefCounted = load(GATE_PATH).new()
	assert_eq(router.configure_mutation_gate(null).get("code"), &"invalid_mutation_gate")
	assert_eq(router.configure_mutation_gate(RefCounted.new()).get("code"), &"invalid_mutation_gate")
	var configured: Dictionary = router.configure_mutation_gate(gate)
	assert_true(configured["ok"])
	assert_eq(configured["value"]["already_configured"], false)
	assert_true(router.configure_mutation_gate(gate)["value"]["already_configured"], "same instance is idempotent")
	assert_eq(router.configure_mutation_gate(load(GATE_PATH).new()).get("code"),
		&"mutation_gate_already_configured", "a different instance rejects")

func test_fatal_latch_fences_guarded_operations() -> void:
	var gate: RefCounted = load(GATE_PATH).new()
	var latched: Dictionary = gate.latch_fatal({
		"source": "restore", "phase": "rollback", "code": "fatal_rollback_failed",
		"details": {"context": {}, "diagnostics": []}})
	assert_true(latched["ok"], JSON.stringify(latched))
	assert_true(gate.is_fatal_latched())
	# Once latched, every gate operation returns the retained APPLICATION_FATAL.
	assert_eq(gate.guard_external(&"restore_recovery").get("code"), &"APPLICATION_FATAL")
	assert_eq(gate.acquire(&"restore").get("code"), &"APPLICATION_FATAL")
	assert_false(gate.is_internal_owner_active(&"restore"), "no owner is active under a fatal latch")
