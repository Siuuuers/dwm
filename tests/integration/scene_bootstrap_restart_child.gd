extends "res://addons/gut/test.gd"
## Real FINAL services in separate OS processes sharing the wrapper-owned user directory.
## Content registration is TEST-authored; no diagnostic restore participants are installed.
const BOOTSTRAP := preload("res://autoload/ApplicationBootstrap.gd")
const CONTENT := preload("res://tests/support/ScenePlayableFixture.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const HOST := "res://scenes/narrative/SceneHost.tscn"
var bootstrap: Node
var saves: Node
var bridge: Node
var game: Node
var profile: Node
var ready_count := 0

func _ok(result: Dictionary) -> bool:
	assert_true(result.get("ok", false), str(result))
	return result.get("ok", false)

func _install_content_registration() -> Dictionary:
	var content: RefCounted = CONTENT.new()
	return content._install_registration()

func _start_services() -> bool:
	process_mode = Node.PROCESS_MODE_ALWAYS
	assert_false(OS.get_environment("DWM_TEST_ROOT").is_empty())
	if OS.get_environment("DWM_TEST_ROOT").is_empty(): return false
	if not _ok(_install_content_registration()): return false
	var old: Node = get_node("/root/ApplicationBootstrap")
	assert_eq(old.get_startup_state().mode, &"test_manual")
	assert_false(old.get_startup_state().ready)
	old.free()
	saves = get_node("/root/SaveManager")
	bridge = get_node("/root/DialogicBridge")
	game = get_node("/root/GameState")
	profile = get_node("/root/ProfileManager")
	saves.live_session_ready.connect(func() -> void: ready_count += 1)
	bootstrap = BOOTSTRAP.new()
	bootstrap.name = "ApplicationBootstrap"
	get_tree().root.add_child(bootstrap)
	get_tree().current_scene = null
	if not _ok(bootstrap.start(&"final")): return false
	assert_eq(bootstrap.get_startup_state().completed_stages, BOOTSTRAP.STAGE_ORDER)
	assert_true(bootstrap.get_startup_state().ready)
	assert_eq(saves._restore_participants.size(), 9)
	assert_eq(ready_count, 0, "completed prior operations do not fabricate a live Ready")
	return true

func _await_ready() -> bool:
	for frame: int in 240:
		if ready_count == 1: return true
		var failure: Dictionary = saves._scene_restore_activation.get("failure", {})
		if not failure.is_empty(): return _ok(failure)
		await get_tree().process_frame
	return _ok({"ok": false, "code": &"TEST.bootstrap_restart_timeout"})

func _write_json(path: String, value: Dictionary) -> bool:
	var encoded: Dictionary = WRITER.stringify(value)
	if not _ok(encoded): return false
	var file := FileAccess.open(path, FileAccess.WRITE)
	assert_not_null(file)
	if file == null: return false
	file.store_string(encoded.value)
	file.close()
	return true

func create_saved_text() -> void:
	if not _start_services(): return
	assert_false(FileAccess.file_exists("user://saves/slot_1.json"))
	var audio: Node = get_node("/root/AudioManager")
	var started: Dictionary = saves.start_scene_new_run("target_b", {
		"route_id": "scene", "content_version": 1, "audio_context": audio.get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	assert_eq(ready_count, 0)
	if not await _await_ready(): return
	var frontier: Dictionary = bridge.capture_current_line_presentation_frontier()
	if not _ok(frontier): return
	if not _ok(bridge.acknowledge_current_line_presentation(frontier)): return
	if not _ok(saves.save_latest_to_slot(1)): return
	var selected: Dictionary = saves.get_latest_stable_checkpoint()
	if not _ok(selected): return
	var snapshot: Dictionary = selected.value.bundle.snapshot
	var proof := {"phase": "create", "process_id": OS.get_process_id(),
		"user_dir": ProjectSettings.globalize_path("user://"),
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"autosave_sha256": FileAccess.get_sha256("user://saves/autosave.json"),
		"profile_sha256": FileAccess.get_sha256("user://profile.json"),
		"profile": profile.get_profile_snapshot(),
		"reading_session": snapshot.narrative_checkpoint.reading_session,
		"command_receipts": game.capture_run_snapshot_input().command_receipts,
		"source_branch": snapshot.lifecycle.branch_id,
		"source_run": snapshot.run_id, "ready_count": ready_count}
	for key: String in ["slot_sha256", "autosave_sha256", "profile_sha256"]:
		assert_eq(str(proof[key]).length(), 64, "physical file exists: " + key)
	if not _write_json("user://bootstrap-restart-proof.json", proof): return
	_write_json("res://.godot/ci/bootstrap-create-proof.json", proof)

func load_saved_text() -> void:
	# Read the creator's physical witness before FINAL startup can reconcile any storage.
	assert_true(FileAccess.file_exists("user://bootstrap-restart-proof.json"))
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://bootstrap-restart-proof.json"))
	if not _ok(parsed): return
	var witness: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), witness.process_id)
	assert_eq(ProjectSettings.globalize_path("user://"), witness.user_dir)
	_assert_physical_bytes(witness)
	if not _start_services(): return
	_assert_physical_bytes(witness)
	assert_eq(profile.get_profile_snapshot(), witness.profile)
	# Title Backup owns revision inspection, reconciliation and selected-Load consent.
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	assert_false(prepared.value.confirmation_required)
	var restored: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(restored.get("code"), &"scene_activation_pending", str(restored))
	if restored.get("code") != &"scene_activation_pending": return
	assert_eq(ready_count, 0)
	if not await _await_ready(): return
	for frame: int in 4: await get_tree().process_frame
	assert_eq(ready_count, 1)
	assert_eq(get_tree().current_scene.scene_file_path, HOST)
	assert_true(get_tree().current_scene.is_node_ready())
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return
	assert_eq(reading.value.reading_session.entry_id, witness.reading_session.entry_id)
	assert_eq(reading.value.reading_session.program_index, witness.reading_session.program_index)
	var current: Dictionary = game.capture_run_snapshot_input()
	assert_eq(current.lifecycle.run_id, witness.source_run)
	assert_ne(current.lifecycle.branch_id, witness.source_branch, "selected Load creates a fresh branch")
	assert_eq(current.command_receipts, witness.command_receipts)
	assert_eq(profile.get_profile_snapshot(), witness.profile, "no Profile/history consequences replay")
	_assert_physical_bytes(witness)
	var frontier: Dictionary = bridge.capture_current_line_presentation_frontier()
	if not _ok(frontier): return
	if not _ok(bridge.acknowledge_current_line_presentation(frontier)): return
	assert_true(bridge.is_current_line_presentation_acknowledged())
	assert_eq(profile.get_profile_snapshot(), witness.profile)
	_assert_physical_bytes(witness)
	var proof: Dictionary = witness.duplicate(true)
	proof.phase = "load"
	proof["creator_process_id"] = witness.process_id
	proof.process_id = OS.get_process_id()
	proof["destination_branch"] = current.lifecycle.branch_id
	proof.ready_count = ready_count
	_write_json("res://.godot/ci/bootstrap-load-proof.json", proof)

func _assert_physical_bytes(witness: Dictionary) -> void:
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), witness.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://saves/autosave.json"), witness.autosave_sha256)
	assert_eq(FileAccess.get_sha256("user://profile.json"), witness.profile_sha256)
