extends "res://tests/integration/scene_inline_audio_child.gd"
## Observe the real checkpoint write after detached destination preparation and
## before commit. Playback calls are still forwarded to native players unchanged.
const ART := preload("res://scripts/data/ArtManifest.gd")

class ObservedFiles extends "res://scripts/infrastructure/storage/FileOps.gd":
	var on_autosave: Callable
	func write_bytes(path: String, bytes: PackedByteArray) -> Dictionary:
		if path.replace("\\", "/").ends_with("/autosave.json.next"):
			on_autosave.call(bytes)
		return super.write_bytes(path, bytes)

var before_commit: Array[Dictionary] = []
var checkpoint_definitions: Dictionary = {}

func _install_content_registration() -> Dictionary:
	var registered: Dictionary = super._install_content_registration()
	if not registered.ok: return registered
	var reading := preload("res://scripts/narrative/SoloReadingSession.gd").new()
	var configured: Dictionary = reading.configure_scene()
	if not configured.ok: return configured
	var entries: Array = []
	for beat: Dictionary in reading.registry.beats:
		if beat.owning_entry_id not in ["scene.test.a", "scene.test.b"]: continue
		for line: Dictionary in reading.catalogue[beat.owning_entry_id].lines:
			if line.line_id == beat.line_id:
				entries.append({"beat": beat, "kind": "caption", "text": {"en": line.text}, "requirements": {}})
	return preload("res://scripts/narrative/DialogueLibraryCatalogue.gd").configure(
		[{"id": "template.checkpoint", "title": {"en": "Audio arrival"}, "entries": entries}],
		reading.registry.beats, checkpoint_definitions)


func _inline_path() -> String:
	return "res://tests/fixtures/dialogic/scene_inline_audio_transition.dtl"

func _inline_markers() -> Array:
	return [{"marker_id": "scene.test.a.transition", "label": "scene.test.a.transition",
		"after_line_id": "line.scene.test.a.five", "kind": "scene.transition", "payload": {"target_id": "target_b"}}]

func _inline_bundle() -> Dictionary:
	var built: Dictionary = super._inline_bundle()
	if not built.ok: return built
	var bundle: Dictionary = built.value
	var labels: Array = []
	for entry: Dictionary in bundle.entry_manifest.entries:
		labels.append(entry.entry_id)
		if entry.entry_id == "scene.test.b": entry.locators.en.path = _inline_path()
	for programme: Dictionary in bundle.scene_programme.entries:
		if programme.entry_id != "scene.test.b": continue
		var compiled: Dictionary = ADAPTER.compile_scene_programme(_inline_path(), programme.entry_id, labels, programme.markers)
		if not compiled.ok: return compiled
		programme.content_sha256 = compiled.value.content_sha256
		programme.program_sha256 = compiled.value.program_sha256
		for target: Dictionary in bundle.targets:
			if target.target.entry_id == programme.entry_id: target.target.program_sha256 = programme.program_sha256
	# Checkpoint base selects A, while the arriving DTL deliberately selects B.
	var catalog: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(
		"res://tests/fixtures/presentation/named_checkpoints.json"))
	catalog.presentation_checkpoints["template.checkpoint"].audio_plan_id = "TEST.inline.a"
	checkpoint_definitions = catalog.presentation_checkpoints
	catalog.presentation_entries = {"scene.test.b": [{"kind": "checkpoint", "id": "template.checkpoint"}]}
	if not _write_json("user://inline-presentation.json", catalog): return {"ok": false}
	if not ART.reload_placements("user://inline-presentation.json"): return {"ok": false}
	return built

func _observe_autosave(bytes: PackedByteArray) -> void:
	var document: Variant = JSON.parse_string(bytes.get_string_from_utf8())
	before_commit.append({"document": document, "starts": observed.starts.duplicate(true),
		"scene": game.capture_run_snapshot_input().scene,
		"audio": get_node("/root/AudioManager").get_semantic_audio_context()})

func test_checkpoint_then_inline_selection_is_saved_before_destination_audio() -> void:
	if not await _begin_inline(): return
	if not _ok(profile.set_preference(&"preferences.reading.skip_mode", "all_text")): return
	await _click(_caption().transport_rail.get_node("Skip"))
	var deadline := Time.get_ticks_msec() + 12000
	while _caption().skip_controller.is_skip_active() and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.five")
	_assert_selection("TEST.inline.a")
	var source_starts := observed.starts.duplicate(true)
	var source_sfx := _starts("SFX")
	var source_music := _starts("Music")
	var files := ObservedFiles.new()
	files.on_autosave = _observe_autosave
	saves._storage._file_ops = files
	if _caption().caption_text.revealing: await _accept()
	await _accept()
	deadline = Time.get_ticks_msec() + 15000
	while bridge._runtime_adapter.current_line_id() != "line.scene.test.b.one" and Time.get_ticks_msec() < deadline:
		await get_tree().process_frame
	for frame: int in 5: await get_tree().process_frame
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.b.one")
	assert_eq(before_commit.size(), 1, "one named-checkpoint Autosave")
	if before_commit.size() != 1: return
	var staged: Dictionary = before_commit[0]
	assert_eq(staged.starts, source_starts, "detached destination preparation emits no native audio")
	assert_eq(staged.audio.selection.plan_id, "TEST.inline.a", "source playback remains active before commit")
	assert_eq(staged.scene.entry_id, "scene.test.a")
	assert_eq(staged.document.current_snapshot.snapshot.scene.music_plan_id, "TEST.inline.b",
		"candidate saves inline selection after checkpoint base, before playback")
	var saved: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _ok(saved): return
	assert_eq(saved.value.current_snapshot.snapshot.scene.music_plan_id, "TEST.inline.b")
	assert_eq(saved.value.current_snapshot.snapshot.scene.presentation.checkpoint_id, "template.checkpoint")
	_assert_selection("TEST.inline.b")
	assert_eq(_starts("Music"), source_music + 1, "only destination B starts after source A")
	assert_eq(_starts("SFX"), source_sfx + 1, "arrival effect runs once after commit")
	# Save before the playable marker; genuine re-encounter after same-process
	# Load must not inherit the discarded encounter's one-shot suppression.
	var inputs: Dictionary = bootstrap._capture_paused_checkpoint_inputs()
	if not _ok(inputs) or not _ok(saves.record_stable_checkpoint(inputs.value, &"manual_save")): return
	if not _ok(saves.save_latest_to_slot(3)): return
	if _caption().caption_text.revealing: await _accept()
	await _accept()
	assert_eq(bridge.capture_reading_checkpoint(false).value.reading_session.boundary, "control")
	assert_eq(_starts("SFX"), source_sfx + 2, "new playable encounter emits its effect")
	if not await _load_inline(3, false): return
	assert_eq(_starts("SFX"), source_sfx + 2, "Load does not replay entry effects")
	await _accept()
	assert_eq(bridge.capture_reading_checkpoint(false).value.reading_session.boundary, "control")
	assert_eq(_starts("SFX"), source_sfx + 3, "crossing the same marker after Load is a new encounter")
	await _screenshot("inline-audio-checkpoint")
	_write_json("res://.godot/ci/inline-audio-transition.json", {"precommit": before_commit,
		"starts": observed.starts, "renderer": DisplayServer.get_name()})
