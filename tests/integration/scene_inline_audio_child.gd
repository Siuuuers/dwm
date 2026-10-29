extends "res://tests/ui/render_self_talk_base.gd"
## Authored DTL through FINAL services and native audio players. Observations
## forward every production port call unchanged; no playback result is invented.
const INLINE_DTL := "res://tests/fixtures/dialogic/scene_inline_audio.dtl"
const AUDIO_OWNER := preload("res://autoload/AudioManager.gd")
const RUN_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const PROOF := "user://inline-audio-proof.json"

class ObservedPort extends "res://scripts/audio/AudioPlaybackPort.gd":
	var starts: Array[Dictionary] = []
	func play(player_id: StringName, position: float = 0.0) -> Dictionary:
		var result: Dictionary = super.play(player_id, position)
		if str(player_id).begins_with("Music") or str(player_id).begins_with("SFX"):
			starts.append({"player": str(player_id), "position": position, "ok": result.get("ok", false)})
		return result

var observed: ObservedPort

func _inline_path() -> String:
	return INLINE_DTL

func _inline_markers() -> Array:
	return []

func _install_content_registration() -> Dictionary:
	var built := _inline_bundle()
	if not built.ok: return built
	return MANIFEST.configure_test_scene_registration(built.value)

func _inline_bundle() -> Dictionary:
	var built: Dictionary = CONTENT.new()._registration_bundle()
	if not built.ok: return built
	var bundle: Dictionary = built.value
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		labels.append(entry.entry_id)
		if entry.entry_id == "scene.test.a":
			entry.locators.en.path = _inline_path()
			for marker: Dictionary in _inline_markers():
				if marker.kind not in entry.allowed_signals: entry.allowed_signals.append(marker.kind)
	var compiled: Dictionary = ADAPTER.compile_scene_programme(_inline_path(), "scene.test.a", labels, _inline_markers())
	if not compiled.ok: return compiled
	var lines: Array = AUTHORING.caption_lines(compiled.value.events, {})
	for row: Dictionary in bundle.caption_registry.entries:
		if row.entry_id == "scene.test.a": row.lines = lines
	var registered: Array = []
	for row: Dictionary in bundle.ids_registry.lines:
		if row.owning_entry_id != "scene.test.a": registered.append(row)
	for line: Dictionary in lines: registered.append({"line_id": line.line_id, "owning_entry_id": "scene.test.a"})
	registered.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.line_id < b.line_id)
	bundle.ids_registry.lines = registered
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id == "scene.test.a":
			programme.markers = _inline_markers()
			programme.content_sha256 = compiled.value.content_sha256
			programme.program_sha256 = compiled.value.program_sha256
	for target: Dictionary in bundle.targets:
		if target.target.entry_id == "scene.test.a": target.target.program_sha256 = compiled.value.program_sha256
	bundle.schema_version = 3
	var bindings: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries: bindings.append({"entry_id": entry.entry_id, "plan_id": null})
	bindings.sort_custom(func(a: Dictionary, b: Dictionary) -> bool: return a.entry_id < b.entry_id)
	var plans: Array = []
	for id: String in ["TEST.inline.a", "TEST.inline.b"]:
		plans.append({"plan_id": id, "revision": 1, "variant_id": "base", "ambience_asset_id": null,
			"music": "TEST.inline.bed", "entrance_ms": 0, "load_anchor_id": "inline.start", "load_anchor_ms": 1000,
			"authorial": true, "essential": false, "missing_media": "silence", "cues": []})
	var assets: Array = []
	for id: String in ["TEST.inline.bed", "TEST.inline.hit"]:
		assets.append({"asset_id": id, "path": "res://tests/fixtures/audio/scene_test_bed.tres",
			"sha256": "f85a90530be2a8f0dad87f80844e6b79d5bdf171975f4c9044a770dc4c2d32aa", "duration_ms": 4000})
	bundle["audio_catalogue"] = {"kind": "scene_audio_catalogue", "schema_version": 3,
		"assets": assets, "plans": plans, "bindings": bindings}
	return {"ok": true, "value": bundle}

func _start_services() -> bool:
	var old: Node = get_node("/root/AudioManager")
	assert_false(old._initialized)
	if old._initialized: return false
	old.free()
	observed = ObservedPort.new()
	var owner: Node = AUDIO_OWNER.new(observed)
	owner.name = "AudioManager"
	get_tree().root.add_child(owner)
	return super._start_services()

func _begin_inline() -> bool:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless" or not _start_services(): return false
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci"))
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return false
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending")
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return false
	for frame: int in 5: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.one")
	_assert_selection("TEST.inline.a")
	assert_eq(_starts("Music"), 1, "entry cue starts exactly once")
	assert_eq(_starts("SFX"), 1, "new entry plays its one-shot once")
	assert_eq(_autosave_sha256(), "", "audio entry does not create Autosave")
	return true

func _starts(prefix: String) -> int:
	var count := 0
	for row: Dictionary in observed.starts:
		if row.player.begins_with(prefix):
			assert_true(row.ok)
			count += 1
	return count

func _assert_selection(id: String) -> void:
	var snapshot: Dictionary = game.capture_run_snapshot_input()
	assert_eq(snapshot.scene.get("music_plan_id"), id, "live scene owns the current selection")
	var derived: Dictionary = RUN_SCHEMA.derive_scene_audio_context(snapshot)
	if not _ok(derived): return
	assert_eq(get_node("/root/AudioManager").get_semantic_audio_context(), derived.value)
	var selection: Variant = derived.value.selection
	assert_eq("" if selection == null else str(selection.plan_id), id)

func _save_inline(slot: int, id: String) -> bool:
	# Capture synchronously while a ten-second fade remains unfinished.
	var inputs: Dictionary = bootstrap._capture_paused_checkpoint_inputs()
	if not _ok(inputs) or not _ok(saves.record_stable_checkpoint(inputs.value, &"manual_save")): return false
	if not _ok(saves.save_latest_to_slot(slot)): return false
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_%d.json" % slot))
	if not _ok(parsed): return false
	assert_eq(parsed.value.current_snapshot.snapshot.scene.music_plan_id, id)
	assert_false(parsed.value.current_snapshot.snapshot.has("audio_context"))
	assert_eq(_autosave_sha256(), "", "inline cues and manual saves never invent Autosave")
	return true

func _load_inline(slot: int, from_title: bool) -> bool:
	var port: RefCounted
	if from_title:
		port = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
		if not _ok(port.configure(saves, "title")): return false
	else:
		await _click(_caption().transport_rail.get_node("Load"))
		port = get_node("/root/SceneRouter")._production_pause._backup_port
	var prepared: Dictionary = port.prepare_action("load", "slot:%d" % slot)
	if not _ok(prepared): return false
	ready_count = 0
	var loaded: Dictionary = await port.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending": return false
	if not await _await_ready(): return false
	for frame: int in 5: await get_tree().process_frame
	return true

func _assert_music_players(expected: int) -> void:
	var playing := 0
	for id: StringName in [&"MusicA", &"MusicB"]:
		var player: AudioStreamPlayer = observed._players[id]
		if player.playing:
			playing += 1
			assert_true(player.has_stream_playback())
	assert_eq(playing, expected)
