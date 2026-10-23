extends GutTest

const ROUTER := preload("res://autoload/SceneRouter.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const FIXTURE := preload("res://tests/unit/test_new_acc_title_lifetime.gd")

class IsolatedRouter extends ROUTER:
	func _gs() -> Node: return null

class NoStartupRecovery extends RefCounted:
	signal startup_recovery_changed()
	func get_new_run_startup_recovery() -> Dictionary:
		return {"ok": true, "value": {"available": false, "transaction_id": ""}}
	func get_startup_state() -> Dictionary: return {"ready": true, "fatal_result": {}}
	func retry_new_run_startup(_token: String) -> Dictionary: return {"ok": false}

var router: Node
var gate: RefCounted
var original_scene: Node
var source: Control
var source_button: Button
var replacement: Control
var mounted: Node
var prepared_node: Node
var gate_token := ""
var services: Array[Node] = []

func before_each() -> void:
	original_scene = get_tree().current_scene
	source = Control.new()
	source.name = "ReturnSourceFixture"
	source.size = Vector2(1280, 720)
	get_tree().root.add_child(source)
	get_tree().current_scene = source
	source_button = Button.new()
	source_button.text = "Suspended source"
	source_button.size = Vector2(240, 64)
	source.add_child(source_button)
	source_button.grab_focus()
	router = IsolatedRouter.new()
	add_child(router)
	gate = GATE.new()
	assert_true(router.configure_mutation_gate(gate).ok)

func after_each() -> void:
	get_tree().current_scene = original_scene if is_instance_valid(original_scene) else null
	if is_instance_valid(mounted): mounted.free()
	if is_instance_valid(source): source.free()
	if is_instance_valid(replacement): replacement.free()
	if is_instance_valid(router): router.free()
	if is_instance_valid(prepared_node) and not prepared_node.is_inside_tree(): prepared_node.free()
	for service: Node in services:
		if is_instance_valid(service): service.free()
	services.clear()
	await get_tree().process_frame

func _supported() -> bool:
	for method: String in ["prepare_return_to_title", "validate_prepared_return_to_title",
		"cancel_prepared_return_to_title", "publish_prepared_return_to_title"]:
		if not router.has_method(method):
			fail_test("Missing Title capability: " + method)
			return false
	return true

func _prepare() -> Dictionary:
	var result: Dictionary = router.prepare_return_to_title()
	assert_true(result.ok, str(result))
	if not result.ok: return {}
	prepared_node = instance_from_id(result.value.scene_instance_id)
	assert_true(is_instance_valid(prepared_node), "Preparation retains the actual target")
	return result.value

func _acquire(owner_id: StringName = &"session_abandonment") -> bool:
	var result: Dictionary = gate.acquire(owner_id)
	assert_true(result.ok, str(result))
	if not result.ok: return false
	gate_token = result.value.token
	return true

func _configure_target() -> void:
	var locale := FIXTURE.Locale.new()
	var profile := FIXTURE.Profile.new()
	add_child(locale)
	add_child(profile)
	prepared_node.configure_settings_services({"localization": locale, "profile": profile})
	prepared_node.configure_startup_recovery_owner(NoStartupRecovery.new())
	# Service lifetimes extend past the prepared Menu; tests own them.
	services.assign([locale, profile])

func test_prepare_retains_actual_off_tree_title_without_changing_source_or_focus() -> void:
	if not _supported(): return
	var before: Dictionary = router.capture_restore_state()
	var prepared := _prepare()
	if prepared.is_empty(): return
	assert_eq(prepared.route_id, "menu")
	assert_eq(prepared_node.scene_file_path, "res://scenes/menu/MenuScene.tscn")
	assert_false(prepared_node.is_inside_tree())
	assert_false(prepared_node.is_node_ready(), "Preparation makes no rendered readiness claim")
	assert_eq(get_tree().current_scene, source)
	assert_eq(get_tree().root.gui_get_focus_owner(), source_button)
	assert_eq(router.capture_restore_state(), before)
	assert_true(router.validate_prepared_return_to_title(prepared.token).ok)
	assert_false(router.publish_prepared_return_to_title(prepared.token).ok, "Publication needs abandonment ownership")
	assert_eq(get_tree().current_scene, source)
	var retained: WeakRef = weakref(prepared_node)
	assert_true(router.cancel_prepared_return_to_title(prepared.token).ok)
	assert_null(retained.get_ref(), "Cancel frees unused off-tree preparation")
	assert_eq(get_tree().current_scene, source)

func test_competing_transaction_and_foreign_tokens_refuse_without_retiring_source() -> void:
	if not _supported(): return
	var prepared := _prepare()
	if prepared.is_empty(): return
	assert_false(router.validate_prepared_return_to_title("foreign").ok)
	assert_false(router.cancel_prepared_return_to_title("foreign").ok)
	assert_false(router.publish_prepared_return_to_title("foreign").ok)
	assert_true(is_instance_valid(prepared_node))
	if not _acquire(&"restore"): return
	assert_false(router.prepare_return_to_title().ok)
	assert_false(router.validate_prepared_return_to_title(prepared.token).ok)
	assert_false(router.cancel_prepared_return_to_title(prepared.token).ok)
	assert_false(router.publish_prepared_return_to_title(prepared.token).ok)
	assert_eq(get_tree().current_scene, source)
	assert_eq(get_tree().root.gui_get_focus_owner(), source_button)
	assert_true(gate.release(&"restore", gate_token).ok)
	assert_true(router.validate_prepared_return_to_title(prepared.token).ok)

func test_source_replacement_and_queued_source_make_preparation_stale() -> void:
	if not _supported(): return
	var prepared := _prepare()
	if prepared.is_empty(): return
	replacement = Control.new()
	get_tree().root.add_child(replacement)
	get_tree().current_scene = replacement
	assert_false(router.validate_prepared_return_to_title(prepared.token).ok)
	if not _acquire(): return
	assert_false(router.publish_prepared_return_to_title(prepared.token).ok)
	assert_eq(get_tree().current_scene, replacement)
	assert_true(gate.release(&"session_abandonment", gate_token).ok)
	get_tree().current_scene = source
	source.queue_free()
	assert_false(router.validate_prepared_return_to_title(prepared.token).ok)
	assert_false(prepared_node.is_inside_tree())

func test_restore_apply_then_rollback_cannot_revalidate_an_old_title_capability() -> void:
	if not _supported(): return
	var prepared := _prepare()
	if prepared.is_empty(): return
	var before: Dictionary = router.capture_restore_state().value
	var plan: Dictionary = router.prepare_route_restore("hospital", {})
	assert_true(plan.ok)
	assert_true(router.apply_route_restore_silent(plan.value).ok)
	assert_true(router.rollback_restore_silent(before).ok)
	assert_eq(router.capture_restore_state().value, before, "Existing semantic backup is unchanged")
	assert_eq(get_tree().current_scene, source)
	assert_false(router.validate_prepared_return_to_title(prepared.token).ok,
		"Route custody revision cannot rewind with semantic restore rollback")

func test_publication_mounts_same_prepared_instance_once_and_reentrant_routes_refuse() -> void:
	if not _supported(): return
	var prepared := _prepare()
	if prepared.is_empty(): return
	_configure_target()
	if not _acquire(): return
	assert_true(router.validate_prepared_return_to_title(prepared.token).ok)
	var attempts: Array[Dictionary] = []
	var observer := func(child: Node):
		if child == prepared_node:
			attempts.append(router._change_to("hospital"))
			attempts.append(router.publish_prepared_return_to_title(prepared.token))
	get_tree().root.child_entered_tree.connect(observer)
	var result: Dictionary = router.publish_prepared_return_to_title(prepared.token)
	get_tree().root.child_entered_tree.disconnect(observer)
	assert_true(result.ok, str(result))
	if not result.ok: return
	mounted = prepared_node
	assert_eq(get_tree().current_scene, mounted)
	assert_true(mounted.is_node_ready())
	assert_eq(result.value.scene_instance_id, prepared.scene_instance_id)
	assert_eq(attempts.size(), 2)
	for attempt: Dictionary in attempts: assert_false(attempt.ok)
	assert_true(router.publish_prepared_return_to_title(prepared.token).ok)
	assert_eq(get_tree().current_scene, mounted)
	replacement = Control.new()
	get_tree().root.add_child(replacement)
	get_tree().current_scene = replacement
	assert_false(router.publish_prepared_return_to_title(prepared.token).ok,
		"Completed receipt cannot route again after its target retires")
	assert_eq(get_tree().current_scene, replacement)

func test_preparation_refuses_missing_source_and_startup_hold_without_publishing() -> void:
	if not _supported(): return
	get_tree().current_scene = null
	assert_false(router.prepare_return_to_title().ok)
	assert_false(source.is_queued_for_deletion())
	get_tree().current_scene = source
	assert_true(router.begin_startup_route_hold().ok)
	assert_false(router.prepare_return_to_title().ok, "Runtime Return cannot reuse startup publication custody")
	assert_eq(get_tree().current_scene, source)

func test_pending_semantic_restore_blocks_return_preparation_until_rollback() -> void:
	if not _supported(): return
	var baseline: Dictionary = router.capture_restore_state().value
	var plan: Dictionary = router.prepare_route_restore("hospital", {})
	assert_true(plan.ok)
	if not plan.ok: return
	assert_true(router.apply_route_restore_silent(plan.value).ok)
	var staged: Dictionary = router.capture_restore_state()
	var pending: String = router._pending_restore_scene_id
	assert_eq(pending, "hospital", "The route is staged but has not finalized")
	var refused: Dictionary = router.prepare_return_to_title()
	assert_false(refused.ok, "Return cannot discard a source with a pending semantic route")
	assert_eq(router.capture_restore_state(), staged, "Refusal preserves the semantic route backup")
	assert_eq(router._pending_restore_scene_id, pending, "Refusal preserves the pending route")
	assert_eq(get_tree().current_scene, source)
	assert_false(source.is_queued_for_deletion())
	assert_eq(get_tree().root.gui_get_focus_owner(), source_button)
	assert_true(router.rollback_restore_silent(baseline).ok)
	assert_eq(router._pending_restore_scene_id, "")
	var admitted := _prepare()
	if admitted.is_empty(): return
	assert_true(router.validate_prepared_return_to_title(admitted.token).ok)
	assert_eq(get_tree().current_scene, source)

func test_successful_return_invalidates_older_restore_route_tokens_but_accepts_fresh_plans() -> void:
	if not _supported(): return
	var old_plan: Dictionary = router.prepare_route_restore("hospital", {})
	assert_true(old_plan.ok)
	var prepared := _prepare()
	if prepared.is_empty(): return
	_configure_target()
	if not _acquire(): return
	var result: Dictionary = router.publish_prepared_return_to_title(prepared.token)
	assert_true(result.ok)
	if not result.ok: return
	mounted = prepared_node
	assert_false(router.apply_route_restore_silent(old_plan.value).ok,
		"Return must retire route tokens prepared for the abandoned source")
	var fresh: Dictionary = router.prepare_route_restore("hospital", {})
	assert_true(fresh.ok)
	assert_true(router.apply_route_restore_silent(fresh.value).ok,
		"A newly prepared route remains usable after Return")
