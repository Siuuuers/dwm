extends "res://tests/support/SceneNewRunFixture.gd"
## Test-selected connected persistence integration. Real FileOps, issuer, Profile,
## Run, SaveManager selected Load, SceneRouter mount and installed Dialogic runtime.
## Empty test host plus diagnostic board/consequence/audio/localization participants:
## this is not shipped Bootstrap, desktop usability, or rendered E2E acceptance.
const ROUTER := preload("res://autoload/SceneRouter.gd")
const ROUTE_PARTICIPANT := preload("res://scripts/application/restore/RouteRestoreParticipant.gd")
const IDENTITY_PARTICIPANT := preload("res://scripts/application/restore/DesktopIdentityAllocationRestoreParticipant.gd")
const RUNTIME_ADAPTER := preload("res://scripts/narrative/DialogicRuntimeAdapter.gd")
const HOST := "res://tests/fixtures/scene_activation_host.tscn"
const STYLE := "res://dialogic/styles/witnessed_caption_style.tres"
var router: Node
var runtime: DialogicGameHandler
var adapter: DialogicRuntimeAdapter
var viewport: SubViewport
var previous_scene: Node
var native_publications: Array[Dictionary] = []
var native_markers: Array = []
var route_confirmations: Array[String] = []
var narrative_confirmations: Array[String] = []
var ready_count := 0
var settings: Dictionary = {}

func setup_restart(scene_tree: SceneTree) -> Dictionary:
	previous_scene = scene_tree.current_scene
	var wrapper := OS.get_environment("DWM_TEST_ROOT")
	if wrapper.is_empty(): return {"ok": false, "code": &"test_root_missing"}
	var checked: Dictionary = super.setup(scene_tree, wrapper.path_join("scene_restart_shared"))
	if not checked.ok: return checked
	# Genuine router/style code resolves these canonical autoload paths.
	for owner: Node in [game, bridge]: tree.root.remove_child(owner)
	_replace_owner("GameState", game)
	_replace_owner("DialogicBridge", bridge)
	router = ROUTER.new()
	_replace_owner("SceneRouter", router)
	tree.current_scene = null # Keep GUT alive when the real router replaces its host.
	checked = router.configure_scene_host(HOST)
	if not checked.ok: return checked
	participants.route = ROUTE_PARTICIPANT.new(router)
	participants.narrative = NARRATIVE_PARTICIPANT.new(bridge)
	checked = manager.configure_scene_restore_participants(participants)
	if checked.ok:
		checked = manager.configure_identity_allocation_participant(IDENTITY_PARTICIPANT.new(issuer, manager))
	if not checked.ok: return checked
	for key: String in ["dialogic/save/autosave", "dialogic/layout/end_behaviour"]:
		settings[key] = {"exists": ProjectSettings.has_setting(key), "value": ProjectSettings.get_setting(key)}
	ProjectSettings.set_setting("dialogic/save/autosave", false)
	ProjectSettings.set_setting("dialogic/layout/end_behaviour", 0)
	runtime = tree.root.get_node("Dialogic") as DialogicGameHandler
	if runtime == null: return {"ok": false, "code": &"test_native_runtime_missing"}
	runtime.History.save_visited_history_on_save = false
	runtime.History.save_visited_history_on_autosave = false
	viewport = SubViewport.new()
	viewport.size = Vector2i(1280, 720)
	tree.root.add_child(viewport)
	var layout: Node = runtime.Styles.load_style(STYLE, viewport)
	if layout == null: return {"ok": false, "code": &"test_native_style_missing"}
	if not layout.is_node_ready(): await layout.ready
	adapter = RUNTIME_ADAPTER.new()
	checked = adapter.bind_runtime(runtime)
	if not checked.ok: return checked
	# Match the installed-native fixture: activation connects Bridge's exact native
	# readiness signals; no fabricated callbacks or automatic confirmation exist.
	bridge._runtime_adapter = adapter
	adapter.caption_publication_recorded.connect(func(result: Dictionary) -> void:
		native_publications.append(result.duplicate(true)))
	adapter.runtime_signal_event.connect(func(value: Variant) -> void: native_markers.append(value))
	participants.route.scene_activation_confirmed.connect(func(id: String) -> void: route_confirmations.append(id))
	participants.narrative.scene_activation_confirmed.connect(func(id: String) -> void: narrative_confirmations.append(id))
	manager.live_session_ready.connect(func() -> void: ready_count += 1)
	return {"ok": true}

func await_activation() -> Dictionary:
	for frame: int in 180:
		if ready_count > 0: return {"ok": true}
		if not manager._scene_restore_activation.get("failure", {}).is_empty():
			return manager._scene_restore_activation.failure.duplicate(true)
		await tree.process_frame
	return {"ok": false, "code": &"test_scene_activation_timeout"}

func close_restart() -> void:
	if tree == null: return
	for text_node: Node in tree.get_nodes_in_group("dialogic_dialog_text"):
		text_node.set_process(false)
	if is_instance_valid(runtime):
		runtime.paused = false
		await runtime.clear()
		var remaining: Node = runtime.Styles.get_layout_node()
		if is_instance_valid(remaining) and (not is_instance_valid(viewport) or not viewport.is_ancestor_of(remaining)):
			remaining.queue_free()
	if is_instance_valid(viewport): viewport.queue_free()
	await tree.process_frame
	var mounted := tree.current_scene
	tree.current_scene = previous_scene if is_instance_valid(previous_scene) else null
	if is_instance_valid(mounted) and mounted != previous_scene: mounted.free()
	if is_instance_valid(router): router.free()
	super.close()
	for name: String in ["GameState", "DialogicBridge", "SceneRouter"]:
		if not original_owners.has(name): continue
		var original: Node = original_owners[name].node
		if is_instance_valid(original) and original.get_parent() == null:
			tree.root.add_child(original)
			tree.root.move_child(original, mini(original_owners[name].index, tree.root.get_child_count() - 1))
	for key: String in settings:
		ProjectSettings.set_setting(key, settings[key].value if settings[key].exists else null)
