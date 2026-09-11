extends GutTest

const ROUTER := preload("res://autoload/SceneRouter.gd")
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

class IsolatedRouter extends ROUTER:
	# Route tests must not write the process GameState's context.
	func _gs() -> Node: return null

class PresentationPort extends RefCounted:
	var ready := true
	var begins := 0
	func is_ready() -> bool: return ready
	func begin(_command: Dictionary) -> Dictionary:
		begins += 1
		return {"ok": true}
	func complete(_command: Dictionary) -> Dictionary: return {"ok": true}
	func acknowledge_notice(_command: Dictionary) -> Dictionary: return {"ok": true}

var router: Node
var original_scene: Node
var title: Control
var token := ""

func before_each() -> void:
	original_scene = get_tree().current_scene
	title = Control.new()
	title.name = "StartupTitleFixture"
	get_tree().root.add_child(title)
	get_tree().current_scene = title
	router = IsolatedRouter.new()
	add_child(router)

func after_each() -> void:
	var published := get_tree().current_scene
	get_tree().current_scene = original_scene if is_instance_valid(original_scene) else null
	if is_instance_valid(published) and published != original_scene and published != title: published.free()
	if is_instance_valid(title): title.free()
	if is_instance_valid(router): router.free()
	await get_tree().process_frame

func _hold() -> void:
	var result: Dictionary = router.begin_startup_route_hold()
	assert_true(result.ok)
	token = result.value.token

func _finalize(route: String) -> Dictionary:
	var prepared: Dictionary = router.prepare_route_restore(route, {})
	assert_true(prepared.ok)
	var applied: Dictionary = router.apply_route_restore_silent(prepared.value)
	assert_true(applied.ok)
	return router.finalize_restore()

func _frames() -> void:
	for frame in 3: await get_tree().process_frame

func test_hold_is_idempotent_and_foreign_publication_cannot_remove_title() -> void:
	_hold()
	assert_eq(router.begin_startup_route_hold().value.token, token)
	assert_false(router.publish_startup_route_hold("foreign").ok)
	assert_false(router.publish_startup_route_hold("").ok)
	assert_true(_finalize("main").value.deferred)
	await _frames()
	assert_eq(get_tree().current_scene, title, "A later startup stage failure leaves Title mounted")
	assert_false(title.is_queued_for_deletion())
	assert_eq(router.begin_startup_route_hold().value.token, token)

func test_repeated_finalize_publishes_only_final_target_once() -> void:
	_hold()
	assert_true(_finalize("main").value.deferred)
	assert_true(_finalize("main").value.deferred, "Retry after a completion-journal failure remains semantic")
	assert_true(_finalize("hospital").value.deferred)
	await _frames()
	assert_eq(get_tree().current_scene, title)
	assert_eq(router.get_current_route_id(), "hospital")
	var published: Dictionary = router.publish_startup_route_hold(token)
	assert_true(published.ok)
	assert_false(published.value.deferred)
	await _frames()
	var scene := get_tree().current_scene
	assert_ne(scene, title)
	assert_eq(scene.scene_file_path, "res://scenes/hospital/HospitalScene.tscn")
	assert_true(router.publish_startup_route_hold(token).ok)
	await _frames()
	assert_eq(get_tree().current_scene, scene, "Completed-token replay cannot mount a second scene")
	assert_false(router.begin_startup_route_hold().ok, "Startup hold cannot be reopened after publication")

func test_restore_rollback_recovers_prior_held_target_and_rejects_foreign_backup() -> void:
	_hold()
	assert_true(_finalize("hospital").ok)
	var baseline: Dictionary = router.capture_restore_state().value
	var decoded: Dictionary = STRICT_JSON.parse_object(JSON.stringify(baseline))
	assert_true(decoded.ok)
	if not decoded.ok: return
	assert_eq(decoded.value, baseline, "Hold backup contains only plain data with exact integers")
	assert_true(_finalize("gallery").ok)
	var foreign := baseline.duplicate(true)
	foreign.backup.startup_route_hold.token = "foreign"
	var before: Dictionary = router.capture_restore_state()
	assert_false(router.rollback_restore_silent(foreign).ok)
	assert_eq(router.capture_restore_state(), before)
	assert_true(router.rollback_restore_silent(baseline).ok)
	assert_eq(router.capture_restore_state().value, baseline)
	assert_true(router.publish_startup_route_hold(token).ok)
	await _frames()
	assert_eq(get_tree().current_scene.scene_file_path, "res://scenes/hospital/HospitalScene.tscn")
	assert_false(router.rollback_restore_silent(baseline).ok, "Published hold backup is stale")

func test_rollback_preserves_a_semantic_route_pending_before_finalize() -> void:
	_hold()
	assert_true(_finalize("main").ok)
	var prepared: Dictionary = router.prepare_route_restore("hospital", {})
	assert_true(router.apply_route_restore_silent(prepared.value).ok)
	var baseline: Dictionary = router.capture_restore_state().value
	assert_true(_finalize("gallery").ok)
	assert_true(router.rollback_restore_silent(baseline).ok)
	assert_true(router.finalize_restore().value.deferred)
	assert_eq(router.get_current_route_id(), "hospital")
	assert_true(router.publish_startup_route_hold(token).ok)
	await _frames()
	assert_eq(get_tree().current_scene.scene_file_path, "res://scenes/hospital/HospitalScene.tscn")

func test_presentation_route_cannot_bypass_hold_and_reentrant_requests_are_refused() -> void:
	_hold()
	var port := PresentationPort.new()
	assert_true(router.configure_schedule_presentation_ports(port, port).ok)
	var command := {"route_id": "hospital", "command_id": "fixture-presentation"}
	var deferred: Dictionary = router.route_presentation("hospital", command)
	assert_true(deferred.ok, str(deferred))
	if not deferred.ok: return
	assert_true(deferred.value.deferred)
	assert_false(deferred.value.has("scene_instance_id"), "Deferred receipt never invents a mounted scene")
	assert_eq(deferred.value.port_instance_id, port.get_instance_id(), "Preserve signed RefCounted instance identity")
	var held: Dictionary = router.capture_restore_state().value
	var decoded: Dictionary = STRICT_JSON.parse_object(JSON.stringify(held))
	assert_true(decoded.ok, str(decoded))
	if not decoded.ok: return
	assert_eq(decoded.value, held, "Signed port identity survives the plain-data backup")
	command.command_id = "caller-mutated"
	await _frames()
	assert_eq(get_tree().current_scene, title)
	assert_eq(port.begins, 0)
	var reentrant: Array[Dictionary] = []
	var observed: Array[Node] = []
	var observer := func(child: Node):
		if child.scene_file_path == "res://scenes/hospital/HospitalScene.tscn":
			observed.append(child)
			reentrant.append(router.publish_startup_route_hold(token))
			reentrant.append(router._change_to("menu"))
	get_tree().root.child_entered_tree.connect(observer)
	var result: Dictionary = router.publish_startup_route_hold(token)
	get_tree().root.child_entered_tree.disconnect(observer)
	assert_true(result.ok)
	assert_eq(observed.size(), 1)
	assert_eq(reentrant.size(), 2)
	for refused: Dictionary in reentrant: assert_false(refused.ok)
	var scene := get_tree().current_scene
	assert_eq(scene.get_presentation_projection().command_id, "fixture-presentation")
	assert_eq(scene._presentation_port, port)
	assert_true(router.publish_startup_route_hold(token).ok)
	assert_eq(get_tree().current_scene, scene)

func test_failed_presentation_publication_retains_request_and_same_hold_for_retry() -> void:
	_hold()
	var port := PresentationPort.new()
	assert_true(router.configure_schedule_presentation_ports(port, port).ok)
	var admitted: Dictionary = router.route_presentation("hospital", {"route_id": "hospital"})
	assert_true(admitted.ok, str(admitted))
	if not admitted.ok: return
	var before: Dictionary = router.capture_restore_state()
	port.ready = false
	assert_false(router.publish_startup_route_hold(token).ok)
	assert_eq(get_tree().current_scene, title)
	assert_eq(router.capture_restore_state(), before)
	assert_eq(router.begin_startup_route_hold().value.token, token)
	port.ready = true
	assert_true(router.publish_startup_route_hold(token).ok)
	assert_eq(get_tree().current_scene.scene_file_path, "res://scenes/hospital/HospitalScene.tscn")

func test_ordinary_routing_and_backup_shape_remain_unchanged_without_hold() -> void:
	assert_eq(router.capture_restore_state().value.backup, {"scene_id": "", "route_generation": 0})
	assert_true(router._change_to("hospital").ok)
	await _frames()
	assert_eq(get_tree().current_scene.scene_file_path, "res://scenes/hospital/HospitalScene.tscn")
	assert_false(router.capture_restore_state().value.backup.has("startup_route_hold"))

func test_empty_hold_publication_keeps_title_and_invalid_route_does_not_replace_request() -> void:
	_hold()
	assert_false(router._change_to("unknown").ok)
	assert_true(router.publish_startup_route_hold(token).ok)
	assert_eq(get_tree().current_scene, title)
	assert_true(router.publish_startup_route_hold(token).ok)
	assert_false(router.begin_startup_route_hold().ok)
