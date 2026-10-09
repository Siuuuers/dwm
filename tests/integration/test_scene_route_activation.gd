extends GutTest

const ROUTER := preload("res://autoload/SceneRouter.gd")
const PARTICIPANT := preload("res://scripts/application/restore/RouteRestoreParticipant.gd")
const HOST := "res://tests/fixtures/scene_activation_host.tscn"
const DESKTOP := preload("res://scripts/domain/desktop/DesktopAppHostState.gd")
var _saved_route_context: Dictionary = {}

func before_each() -> void:
	var game := get_node_or_null("/root/GameState")
	if game != null: _saved_route_context = game.route_context.duplicate(true)

func after_each() -> void:
	var game := get_node_or_null("/root/GameState")
	if game != null: game.route_context = _saved_route_context.duplicate(true)

func test_scene_desktop_restore_uses_dayless_owner_candidate() -> void:
	var router := ROUTER.new()
	add_child_autofree(router)
	assert_true(router.configure_scene_host(HOST).ok)
	var participant := PARTICIPANT.new(router)
	var desktop := DESKTOP.new()
	assert_true(participant.configure_desktop_host(desktop).ok)
	var prepared: Dictionary = participant.prepare({"route_id": "scene", "route_context": {"active_app_id": null}})
	assert_true(prepared.ok)
	if not prepared.ok: return
	assert_false(prepared.value.route_plan.desktop.has("current_day"))
	assert_true(participant.apply_silent(prepared.value.route_plan).ok)
	assert_false(desktop.get_state().has("current_day"))
	assert_false(participant.prepare({"route_id": "scene", "route_context": {}}).ok)

func test_scene_route_ack_requires_actual_mount_and_exact_operation() -> void:
	var tree := get_tree()
	# GUT remains mounted while its prior current scene is protected from replacement.
	var previous := tree.current_scene
	tree.current_scene = null
	var router := ROUTER.new()
	tree.root.add_child(router)
	var participant := PARTICIPANT.new(router)
	var acknowledgements: Array[String] = []
	participant.scene_activation_confirmed.connect(func(operation: String): acknowledgements.append(operation))
	assert_true(router.configure_scene_host(HOST).ok)
	var prepared: Dictionary = participant.prepare({"route_id": "scene", "route_context": {}})
	assert_true(prepared.ok)
	if not prepared.ok:
		router.free()
		tree.current_scene = previous
		return
	assert_true(participant.apply_silent(prepared.value.route_plan).ok)
	assert_true(participant.finalize().ok)
	assert_true(acknowledgements.is_empty(), "silent preparation and finalize do not acknowledge mounting")
	assert_false(participant.validate_scene_activation("restore.one").ok)
	var started: Dictionary = participant.begin_scene_activation("restore.one")
	assert_true(started.ok)
	assert_true(acknowledgements.is_empty(), "queued scene replacement is not a mounted acknowledgement")
	assert_false(participant.begin_scene_activation("restore.foreign").ok)
	if started.ok:
		await tree.scene_changed
		assert_eq(acknowledgements, ["restore.one"])
		assert_true(participant.validate_scene_activation("restore.one").ok)
		assert_false(participant.validate_scene_activation("restore.foreign").ok)
		assert_true(participant.begin_scene_activation("restore.one").ok)
		assert_eq(acknowledgements.size(), 1, "duplicate begin never remounts or republishes")
		var mounted := tree.current_scene
		tree.current_scene = null
		assert_false(participant.validate_scene_activation("restore.one").ok, "route string cannot substitute for mounted node")
		tree.current_scene = mounted
		var next: Dictionary = participant.prepare({"route_id": "scene", "route_context": {}})
		assert_true(next.ok)
		assert_true(participant.apply_silent(next.value.route_plan).ok)
		assert_false(participant.validate_scene_activation("restore.one").ok, "new semantic generation fences prior acknowledgement")
		tree.current_scene = null
		mounted.free()
	router.free()
	tree.current_scene = previous

func test_scene_route_missing_host_and_rollback_never_acknowledge() -> void:
	var router := ROUTER.new()
	add_child_autofree(router)
	var participant := PARTICIPANT.new(router)
	assert_false(participant.prepare({"route_id": "scene", "route_context": {}}).ok)
	assert_false(participant.begin_scene_activation("restore.one").ok)
	assert_true(router.configure_scene_host(HOST).ok)
	var backup: Dictionary = participant.capture()
	var prepared: Dictionary = participant.prepare({"route_id": "scene", "route_context": {}})
	assert_true(prepared.ok)
	assert_true(participant.apply_silent(prepared.value.route_plan).ok)
	assert_true(participant.rollback_silent(backup.value).ok)
	assert_false(participant.begin_scene_activation("restore.one").ok)
	assert_false(participant.validate_scene_activation("restore.one").ok)
