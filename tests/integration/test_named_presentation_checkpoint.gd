extends "res://tests/integration/scene_contacts_connected_child.gd"
## Real FINAL owners/native caption input/physical files. Run in its own
## test_manual process with DWM_TEST_ROOT, like scene_shop_checkpoint_transaction.
const ART := preload("res://scripts/data/ArtManifest.gd")

class ObservedMusicPort extends "res://scripts/audio/AudioPlaybackPort.gd":
	var starts: Array = []
	func play(player_id: StringName, from_position: float = 0.0) -> Dictionary:
		var result: Dictionary = super.play(player_id, from_position)
		if player_id == &"MusicA":
			starts.append({"position_ms": int(round(from_position * 1000.0)), "ok": result.get("ok", false)})
		return result

var music_port: ObservedMusicPort

func _start_services() -> bool:
	var old: Node = get_node("/root/AudioManager")
	assert_false(old._initialized)
	if old._initialized: return false
	old.free()
	music_port = ObservedMusicPort.new()
	var audio: Node = preload("res://autoload/AudioManager.gd").new(music_port)
	audio.name = "AudioManager"
	get_tree().root.add_child(audio)
	var started: bool = super._start_services()
	music_port.starts.clear()
	return started

func _assert_music(offsets: Array) -> void:
	var expected: Array = []
	for offset: int in offsets: expected.append({"position_ms": offset, "ok": true})
	assert_eq(music_port.starts, expected, "native music starts only at authored entry/load anchors")
	var player: AudioStreamPlayer = music_port._players[&"MusicA"]
	assert_true(player.playing)
	assert_false(player.stream_paused)
	assert_true(player.has_stream_playback())
	var context: Dictionary = get_node("/root/AudioManager").get_semantic_audio_context()
	assert_eq(context.get("selection", {}).get("plan_id"), "TEST.presentation.music")

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
	catalog.presentation_checkpoints["template.checkpoint"].audio_plan_id = "TEST.presentation.music"
	catalog.presentation_entries = {
		"scene.test.a": [{"kind": "checkpoint", "id": "template.checkpoint"}],
		"contact.test.a": [{"kind": "show", "id": "template.left"},
			{"kind": "show", "id": "template.right"}, {"kind": "show", "id": "template.left"},
			{"kind": "remove", "id": "template.right"}, {"kind": "remove", "id": "template.right"}]}
	if not _write_json("user://named-presentation-connected.json", catalog): return {"ok": false}
	if not ART.reload_placements("user://named-presentation-connected.json"): return {"ok": false}
	var built: Dictionary = CONTACT_CONTENT.new()._registration_bundle()
	if not built.ok: return built
	var bundle: Dictionary = built.value
	bundle.schema_version = 3
	var bindings: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		bindings.append({"entry_id": entry.entry_id, "plan_id": null})
	bindings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	bundle["audio_catalogue"] = {"kind": "scene_audio_catalogue", "schema_version": 2,
		"assets": [{"asset_id": "TEST.presentation.asset", "path": "res://tests/fixtures/audio/scene_test_bed.tres",
			"sha256": "f85a90530be2a8f0dad87f80844e6b79d5bdf171975f4c9044a770dc4c2d32aa", "duration_ms": 4000}],
		"plans": [{"plan_id": "TEST.presentation.music", "revision": 1, "variant_id": "base",
			"ambience_asset_id": null, "entrance_ms": 0, "load_anchor_id": "TEST.presentation.load",
			"load_anchor_ms": 1000, "authorial": true, "essential": false, "missing_media": "silence",
			"music": "TEST.presentation.asset", "cues": []}], "bindings": bindings}
	return preload("res://scripts/narrative/DialogicEntryManifest.gd").configure_test_scene_registration(bundle)

func _assert_mounted_overlays(expected: int) -> void:
	var found := false
	for view: Node in get_tree().root.find_children("SceneArt", "", true, false):
		if view.get_script() == preload("res://scripts/ui/art/SceneArtView.gd") and view.is_visible_in_tree():
			found = true
			assert_eq(view._overlays.get_child_count(), expected)
	assert_true(found, "named art is mounted on the visible native caption layout")

func _load_backup(locator: String, entry: String, line: String) -> bool:
	var pause: Node = get_node("/root/SceneRouter")._production_pause
	var previous_ready := ready_count
	if not _ok(await pause.request_pause()): return false
	var prepared: Dictionary = pause._backup_port.prepare_action("load", locator)
	if not _ok(prepared): return false
	if not _ok(await pause._backup_port.commit_action(prepared.value.token)): return false
	for frame: int in 240:
		if ready_count > previous_ready: break
		await get_tree().process_frame
	assert_eq(ready_count, previous_ready + 1)
	return ready_count == previous_ready + 1 and await _wait_line(entry, line)

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
	_assert_music([0])
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
	_assert_music([0])
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
	_assert_music([0, 1000])
	await _screenshot("named-presentation-loaded-overlay")
	var observer := ArrivalObserver.new()
	observer.delegate = bridge._scene_event_port
	bridge._scene_event_port = observer
	assert_true(bridge.capture_scene_pending_marker().get("ok", false), "loaded contact exposes return marker")
	var loaded_caption: Node = _caption()
	var focused: Control = get_viewport().gui_get_focus_owner()
	var input_diagnostic := {
		"caption_path": str(loaded_caption.get_path()),
		"caption_rect": str(loaded_caption.caption_text.get_global_rect()),
		"caption_visible": loaded_caption.caption_text.is_visible_in_tree(),
		"focused": str(focused.get_path()) if focused != null else "",
		"pause_covered": loaded_caption._pause_covered,
		"next_admitted": loaded_caption._next_admitted(),
		"source_admitted": loaded_caption.accept_input.is_source_admitted(),
		"await_neutral": loaded_caption.accept_input._await_initial_neutral,
		"tree_paused": get_tree().paused, "accept_foreground": loaded_caption.accept_input._foreground,
		"runtime_paused": loaded_caption.accept_input._runtime.get("paused"),
		"input_admitted": get_node("/root/InputManager").is_source_input_admitted(),
		"input_quarantine": get_node("/root/InputManager")._resume_quarantine,
		"input_state": get_node("/root/InputManager").get_state(),
		"physical_contacts": get_node("/root/InputManager").get_physical_contacts(),
		"pause_loading": pause._loading, "pause_busy": pause._busy,
		"bridge_state": bridge.get_state(),
		"presented_line": loaded_caption._presented_line,
		"current_scene": str(get_tree().current_scene.get_path())}
	var arrival_started := Time.get_ticks_usec()
	await _click(loaded_caption.caption_text)
	var caption_dispatched := not observer.envelope.is_empty()
	if not caption_dispatched:
		await _click(loaded_caption.transport_rail._next_button)
	_write_json("res://.godot/ci/named-presentation-return-diagnostic.json", {
		"before": input_diagnostic, "caption_dispatched": caption_dispatched,
		"dispatched": not observer.envelope.is_empty(), "result": observer.result,
		"autosave_writes": files.autosave_writes,
		"pending_marker": bridge.capture_scene_pending_marker(),
		"entry_candidate": game._scene_entry_operation.has("candidate")})
	assert_true(caption_dispatched, "real caption click dispatches Contacts return after Load")
	assert_false(observer.envelope.is_empty(), "real caption or Next input dispatches Contacts return")
	assert_true(observer.result.get("ok", false), "named return dispatch: " + str(observer.result))
	var arrived: bool = await _wait_line("scene.test.a", "line.scene.test.a.two")
	bridge._scene_event_port = observer.delegate
	var arrival_usec := Time.get_ticks_usec() - arrival_started
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
	_assert_music([0, 1000, 0])
	await _screenshot("named-presentation-checkpoint-arrival")
	_write_json("res://.godot/ci/named-presentation-proof.json", {"autosave_writes": files.autosave_writes,
		"manual_save_sha256": slot_hash, "autosave_sha256": autosave_hash,
		"presentation": persisted.scene.presentation, "position_id": persisted.narrative_checkpoint.reading_session.position_id,
		"money": persisted.gameplay.money, "music_starts": music_port.starts,
		"arrival_usec": arrival_usec, "process_id": OS.get_process_id()})
	# Refuse a real named write with an existing Autosave, then retry the retained
	# target admission. The prior durable save remains the recovery point.
	if not await _load_backup("slot:1", "contact.test.a", "line.contact.test.a.one"): return
	var before_refusal_writes: int = files.autosave_writes
	files.refuse_on = before_refusal_writes + 1
	var refusal_observer := ArrivalObserver.new()
	refusal_observer.delegate = bridge._scene_event_port
	bridge._scene_event_port = refusal_observer
	var refusal_started := Time.get_ticks_usec()
	await _click(_caption().transport_rail._next_button)
	var refusal_usec := Time.get_ticks_usec() - refusal_started
	bridge._scene_event_port = refusal_observer.delegate
	assert_false(refusal_observer.envelope.is_empty(), "native Next attempts named checkpoint")
	assert_false(refusal_observer.result.get("ok", true), str(refusal_observer.result))
	assert_eq(files.refused, 1, "actual Autosave temporary-file write was refused")
	assert_eq(_autosave_sha256(), autosave_hash, "failed named write preserves prior Autosave bytes")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), slot_hash)
	assert_eq(game.capture_run_snapshot_input().scene.presentation, expected)
	assert_true(game._scene_entry_operation.has("candidate"), "definite refusal retains exact retry target")
	if not game._scene_entry_operation.has("candidate"): return
	var binding: Dictionary = game._scene_entry_operation.binding.duplicate(true)
	var retry_started := Time.get_ticks_usec()
	var retry: Dictionary = game.admit_scene_target(binding.target_id, binding.trigger_command_id)
	if not _ok(retry): return
	if not await _wait_line("scene.test.a", "line.scene.test.a.two"): return
	var retry_usec := Time.get_ticks_usec() - retry_started
	assert_eq(game.capture_run_snapshot_input().scene.presentation, initial)
	assert_eq(game.capture_run_snapshot_input().gameplay.money, 37)
	assert_eq(game.contacts, child.contacts)
	var retry_hash := _autosave_sha256()
	var writes_before_load: int = files.autosave_writes
	if not await _load_backup("autosave", "scene.test.a", "line.scene.test.a.two"): return
	assert_eq(files.autosave_writes, writes_before_load, "Autosave Load never writes another Autosave")
	assert_eq(_autosave_sha256(), retry_hash)
	assert_eq(game.capture_run_snapshot_input().scene.presentation, initial)
	assert_eq(game.capture_run_snapshot_input().gameplay.money, 37)
	assert_eq(game.contacts, child.contacts, "Load never replays Contacts consequences")
	_assert_mounted_overlays(0)
	_assert_music([0, 1000, 0, 1000, 0, 1000])
	await _screenshot("named-presentation-autosave-loaded")
	_write_json("res://.godot/ci/named-presentation-retry-proof.json", {
		"arrival_usec": arrival_usec, "refusal_usec": refusal_usec, "retry_usec": retry_usec,
		"refused_writes": files.refused, "autosave_writes": files.autosave_writes,
		"autosave_sha256": retry_hash, "music_starts": music_port.starts})
	# Manually deleted required art is a visible content error; saved bytes remain.
	var edited: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("user://named-presentation-connected.json"))
	edited.overlay_labels.erase("template.left")
	if not _write_json("user://named-presentation-connected.json", edited): return
	assert_true(ART.reload_placements("user://named-presentation-connected.json"))
	var missing: Dictionary = saves.prepare_restore_slot(1)
	assert_eq(missing.get("code"), &"reading_content_error", str(missing))
	var confirmation: Control = bootstrap.get_node_or_null("ContentError/ContentErrorConfirmation")
	assert_not_null(confirmation)
	if confirmation != null:
		assert_true(str(confirmation.request.body).contains("template.left"))
		assert_false(confirmation.cancel_button.visible)
		await _screenshot("named-presentation-missing-label")
	assert_eq(_autosave_sha256(), retry_hash)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), slot_hash)
	assert_eq(files.autosave_writes, writes_before_load)
	storage._file_ops = original_files
	ART.reload_placements()
