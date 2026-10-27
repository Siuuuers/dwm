extends "res://tests/integration/scene_contacts_connected_child.gd"
## Real FINAL owners/native caption input/physical files. Run in its own
## test_manual process with DWM_TEST_ROOT, like scene_shop_checkpoint_transaction.
const ART := preload("res://scripts/data/ArtManifest.gd")

class ArrivalObserver extends RefCounted:
	var delegate: RefCounted
	var envelope: Dictionary = {}
	var result: Dictionary = {}
	func dispatch(value: Variant) -> Dictionary:
		envelope = value.duplicate(true)
		result = delegate.dispatch(value)
		return result

func _install_content_registration() -> Dictionary:
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/presentation/named_checkpoints.json"))
	# This fixture has no soundtrack; named silence exercises the same current
	# schema while the audio unit suite covers selection of an existing plan.
	catalog.presentation_checkpoints["template.checkpoint"].audio_plan_id = ""
	catalog.presentation_entries = {
		"scene.test.a": [{"kind": "checkpoint", "id": "template.checkpoint"}],
		"contact.test.a": [{"kind": "show", "id": "template.left"},
			{"kind": "show", "id": "template.right"}, {"kind": "show", "id": "template.left"},
			{"kind": "remove", "id": "template.right"}, {"kind": "remove", "id": "template.right"}]}
	if not _write_json("user://named-presentation-connected.json", catalog): return {"ok": false}
	if not ART.reload_placements("user://named-presentation-connected.json"): return {"ok": false}
	return super._install_content_registration()

func _assert_mounted_overlays(expected: int) -> void:
	var found := false
	for view: Node in get_tree().root.find_children("SceneArt", "", true, false):
		if view.get_script() == preload("res://scripts/ui/art/SceneArtView.gd") and view.is_visible_in_tree():
			found = true
			assert_eq(view._overlays.get_child_count(), expected)
	assert_true(found, "named art is mounted on the visible native caption layout")

func test_named_arrival_manual_save_load_and_ordinary_overlay_continuation() -> void:
	if not _start_services(): return
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var storage: RefCounted = saves._storage
	var original_files: RefCounted = storage._file_ops
	var files := CONTENT.WriteRefusal.new()
	storage._file_ops = files
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.a", "line.scene.test.a.one"): return
	var initial := {"checkpoint_id": "template.checkpoint", "overlays": []}
	assert_eq(game.capture_run_snapshot_input().scene.presentation, initial)
	assert_eq(files.autosave_writes, 0, "New Account installs named presentation without saving")
	assert_false(storage.exists("autosave.json"))
	_assert_mounted_overlays(0)
	# Normal owner actions establish the contact eligibility and a consequence
	# that the later named checkpoint must preserve rather than reset.
	game.change_money(37)
	var issued: Dictionary = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
	if not _ok(issued): return
	if not _ok(game.emit_scene_contact_message("TEST.message", issued.value.token, issued.value.issuer_receipt)): return
	issued = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
	if not _ok(issued): return
	if not _ok(game.open_contact("lavinia", issued.value.token, issued.value.issuer_receipt)): return
	if not _ok(game.resolve_scene_contact_facts(["TEST.fact.read"])): return
	await _click(_caption().caption_text)
	if not await _wait_line("contact.test.a", "line.contact.test.a.one"): return
	var child: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var expected := {"checkpoint_id": "template.checkpoint", "overlays": ["template.left"]}
	assert_eq(child.scene.presentation, expected)
	assert_eq(files.autosave_writes, 0, "ordinary arrival and contact actions never prepare an Autosave")
	assert_false(storage.exists("autosave.json"))
	_assert_mounted_overlays(1)
	await _screenshot("named-presentation-overlay")
	if not await _save_slot(1): return
	var saved: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(saved): return
	assert_eq(saved.value.current_snapshot.snapshot.scene.presentation, expected)
	assert_eq(saved.value.current_snapshot.snapshot.gameplay.money, 37)
	var slot_hash := FileAccess.get_sha256("user://saves/slot_1.json")
	assert_eq(files.autosave_writes, 0)
	var pause: Node = get_node("/root/SceneRouter")._production_pause
	if not _ok(await pause.request_pause()): return
	var prepared: Dictionary = pause._backup_port.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	if not _ok(await pause._backup_port.commit_action(prepared.value.token)): return
	for frame: int in 240:
		if ready_count == 2: break
		await get_tree().process_frame
	assert_eq(ready_count, 2)
	if ready_count != 2 or not await _wait_line("contact.test.a", "line.contact.test.a.one"): return
	assert_eq(game.capture_run_snapshot_input().scene.presentation, expected)
	assert_eq(game.capture_run_snapshot_input().gameplay.money, 37)
	assert_eq(game.contacts, child.contacts)
	assert_eq(files.autosave_writes, 0, "Load resolves saved overlays without checkpoint entry or Autosave")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), slot_hash)
	_assert_mounted_overlays(1)
	await _screenshot("named-presentation-loaded-overlay")
	var observer := ArrivalObserver.new()
	observer.delegate = bridge._scene_event_port
	bridge._scene_event_port = observer
	await _click(_caption().caption_text)
	var arrived: bool = await _wait_line("scene.test.a", "line.scene.test.a.two")
	bridge._scene_event_port = observer.delegate
	if not arrived: return
	assert_true(observer.result.get("ok", false), str(observer.result))
	assert_eq(game.capture_run_snapshot_input().scene.presentation, initial)
	assert_eq(files.autosave_writes, 1, "one explicit named arrival writes exactly once")
	var autosave: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _ok(autosave): return
	var persisted: Dictionary = autosave.value.current_snapshot.snapshot
	assert_eq(persisted.scene.presentation, initial)
	assert_eq(persisted.scene.entry_id, "scene.test.a")
	assert_eq(persisted.narrative_checkpoint.reading_session.position_id, "line.scene.test.a.two")
	assert_eq(persisted.gameplay.money, 37)
	assert_eq(persisted.contacts, child.contacts)
	assert_null(persisted.scene.return_to)
	var autosave_hash := _autosave_sha256()
	observer.delegate.dispatch(observer.envelope)
	assert_eq(files.autosave_writes, 1, "repeated callback cannot write a second arrival")
	assert_eq(_autosave_sha256(), autosave_hash)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), slot_hash)
	_assert_mounted_overlays(0)
	await _screenshot("named-presentation-checkpoint-arrival")
	_write_json("res://.godot/ci/named-presentation-proof.json", {"autosave_writes": files.autosave_writes,
		"manual_save_sha256": slot_hash, "autosave_sha256": autosave_hash,
		"presentation": persisted.scene.presentation, "position_id": persisted.narrative_checkpoint.reading_session.position_id,
		"money": persisted.gameplay.money, "process_id": OS.get_process_id()})
	storage._file_ops = original_files
	ART.reload_placements()
