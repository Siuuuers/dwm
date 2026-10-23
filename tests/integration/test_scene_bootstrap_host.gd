extends "res://addons/gut/test.gd"
## Full FINAL startup stages and actual autoload owners. Only authored content is
## TEST-selected. No diagnostic restore participants or fabricated acknowledgments.
const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const CONTENT := preload("res://tests/support/ScenePlayableFixture.gd")
const HOST := "res://scenes/narrative/SceneHost.tscn"
var ready_count := 0
var bootstrap: Node
var saves: Node
var bridge: Node
var router: Node
var game: Node

func _ok(result: Dictionary) -> bool:
	assert_true(result.get("ok", false), str(result))
	return result.get("ok", false)

func _await_ready(count: int) -> Dictionary:
	for frame: int in 240:
		if ready_count >= count: return {"ok": true}
		var failure: Dictionary = saves._scene_restore_activation.get("failure", {})
		if not failure.is_empty(): return failure
		await get_tree().process_frame
	return {"ok": false, "code": &"TEST.bootstrap_activation_timeout"}

func test_real_bootstrap_scene_text_and_selected_load_keep_owner_authority() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	assert_false(OS.get_environment("DWM_TEST_ROOT").is_empty())
	if OS.get_environment("DWM_TEST_ROOT").is_empty(): return
	var content: RefCounted = CONTENT.new()
	if not _ok(content._install_registration()): return
	var old: Node = get_node("/root/ApplicationBootstrap")
	assert_eq(old.get_startup_state().mode, &"test_manual")
	assert_false(old.get_startup_state().ready)
	old.free()
	bootstrap = BOOTSTRAP.new()
	bootstrap.name = "ApplicationBootstrap"
	get_tree().root.add_child(bootstrap)
	# Explicitly execute every FINAL stage before the automatic deferred start.
	# Its later duplicate is refused by the production once-only start guard.
	get_tree().current_scene = null # The mounted route must not delete GUT.
	if not _ok(bootstrap.start(&"final")): return
	assert_eq(bootstrap.get_startup_state().completed_stages, BOOTSTRAP.STAGE_ORDER)
	assert_true(bootstrap.get_startup_state().ready)
	saves = get_node("/root/SaveManager")
	bridge = get_node("/root/DialogicBridge")
	router = get_node("/root/SceneRouter")
	game = get_node("/root/GameState")
	assert_eq(router._scene_host_path, HOST)
	assert_eq(saves._restore_participants.size(), 9, "retain historical Schedule participant")
	assert_same(saves._restore_participants.run, bootstrap._retained_restore_participants.run)
	assert_same(saves._restore_participants.desktop_board, bootstrap._retained_restore_participants.desktop_board)
	assert_same(saves._restore_participants.narrative, bootstrap._retained_restore_participants.narrative)
	var profile_registry: Node = get_node("/root/ProfileManager")
	var installed: Dictionary = preload("res://scripts/narrative/DialogicEntryManifest.gd").load_ids_default()
	if not _ok(installed): return
	assert_true(profile_registry._line_registry_admits(installed.value.lines[0].line_id))
	assert_false(profile_registry._line_registry_admits("TEST.unregistered.line"))
	var fingerprint: String = profile_registry._line_registry_fingerprint
	var forged: Dictionary = installed.value.duplicate(true)
	forged.lines[0].line_id = "TEST.unregistered.line"
	assert_false(profile_registry.configure_line_registry(forged).get("ok", false))
	assert_eq(profile_registry._line_registry_fingerprint, fingerprint)

	saves.live_session_ready.connect(func() -> void: ready_count += 1)
	var audio: Node = get_node("/root/AudioManager")
	var started: Dictionary = saves.start_scene_new_run("target_b", {
		"route_id": "scene", "content_version": 1, "audio_context": audio.get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	assert_eq(ready_count, 0, "queued route/native work is not Ready")
	if not _ok(await _await_ready(1)): return
	assert_eq(get_tree().current_scene.scene_file_path, HOST)
	assert_true(get_tree().current_scene.is_node_ready())
	assert_eq(ready_count, 1)
	assert_false(router.is_restore_publication_held())
	var pause: Node = router._production_pause
	assert_true(is_instance_valid(pause._find_caption(get_tree().root)))
	assert_true(bridge.requires_line_presentation_acknowledgement(), "scene Text uses exact native caption proof")
	var presented: Dictionary = bridge.capture_current_line_presentation_frontier()
	if not _ok(presented): return
	if not _ok(bridge.acknowledge_current_line_presentation(presented)): return
	assert_true(bridge.is_current_line_presentation_acknowledged())
	if not _ok(saves.save_latest_to_slot(1)): return
	var selected: Dictionary = saves.get_latest_stable_checkpoint()
	if not _ok(selected): return
	var reading: Dictionary = selected.value.bundle.snapshot.narrative_checkpoint.reading_session.duplicate(true)
	var source: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var profile: Node = get_node("/root/ProfileManager")
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	if not _ok(await pause.request_pause()): return
	assert_true(get_tree().paused)
	var prepared: Dictionary = pause._backup_port.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var opaque: Dictionary = saves._backup_actions[prepared.value.token].prepared_restore
	assert_true(saves._same_scene_preparation(opaque, opaque.duplicate(true)))
	assert_eq(typeof(opaque.participant_plans.desktop_board.candidate.kind), TYPE_STRING_NAME)
	var altered: Dictionary = opaque.duplicate(true)
	altered.participant_plans.desktop_board.candidate.kind = "restore"
	assert_eq(saves.commit_prepared_restore(altered).get("code"), &"invalid_scene_restore_preparation", "same text with a changed Variant type is not the retained plan")
	altered = opaque.duplicate(true)
	altered.participant_plans.desktop_board.candidate.kind = &"changed"
	assert_eq(saves.commit_prepared_restore(altered).get("code"), &"invalid_scene_restore_preparation", "changed plan is refused before identity allocation")
	assert_eq(game.capture_run_snapshot_input(), source)
	assert_eq(profile.get_profile_snapshot(), profile_before)
	if not _ok(await pause._backup_port.commit_action(prepared.value.token)): return
	if not _ok(await _await_ready(2)): return
	for frame: int in 4: await get_tree().process_frame
	assert_false(get_tree().paused)
	assert_eq(pause.coordinator.get_state().value.state, &"Active")
	assert_eq(ready_count, 2)
	assert_eq(get_tree().current_scene.scene_file_path, HOST)
	var restored: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(restored): return
	assert_eq(restored.value.reading_session.entry_id, reading.entry_id)
	assert_eq(restored.value.reading_session.program_index, reading.program_index)
	assert_eq(game.capture_run_snapshot_input().command_receipts, source.command_receipts)
	assert_eq(profile.get_profile_snapshot(), profile_before, "selected Load does not replay Profile/history consequences")
	assert_true(is_instance_valid(pause._find_caption(get_tree().root)))

func after_all() -> void:
	get_tree().paused = false

func test_scene_preparation_comparison_preserves_runtime_types_and_identity() -> void:
	var owner := RefCounted.new()
	var other := RefCounted.new()
	var plan := {"nested": [{"kind": &"restore", "count": 1, "owner": owner}]}
	assert_true(preload("res://autoload/SaveManager.gd")._same_scene_preparation(plan, plan.duplicate(true)))
	for replacement: Variant in ["restore", &"changed"]:
		var changed: Dictionary = plan.duplicate(true)
		changed.nested[0].kind = replacement
		assert_false(preload("res://autoload/SaveManager.gd")._same_scene_preparation(plan, changed))
	var changed: Dictionary = plan.duplicate(true)
	changed.nested[0].count = 1.0
	assert_false(preload("res://autoload/SaveManager.gd")._same_scene_preparation(plan, changed))
	changed = plan.duplicate(true)
	changed.nested[0].owner = other
	assert_false(preload("res://autoload/SaveManager.gd")._same_scene_preparation(plan, changed))
	assert_false(preload("res://autoload/SaveManager.gd")._same_scene_preparation({"key": 1}, {&"key": 1}))
	assert_false(preload("res://autoload/SaveManager.gd")._same_scene_preparation(plan, {}))
	assert_false(preload("res://autoload/SaveManager.gd")._same_scene_preparation([1], [1, 2]))
