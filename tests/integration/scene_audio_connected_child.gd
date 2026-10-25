extends "res://tests/integration/scene_manual_entry_child.gd"
## Real FINAL services, canonical registration and native playback. The port
## subclass only records calls before forwarding unchanged to the actual engine.
const AUDIO_CONTENT := preload("res://tests/support/SceneAudioRegistrationFixture.gd")
const AUDIO_OWNER := preload("res://autoload/AudioManager.gd")
const AUDIO_MANIFEST := preload("res://scripts/data/AudioManifest.gd")
const RUN_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const REGISTRY := preload("res://scripts/narrative/DialogicEntryManifest.gd")

class ObservedNativePort extends "res://scripts/audio/AudioPlaybackPort.gd":
	var starts: Array = []
	var clears := 0
	func play(player_id: StringName, from_position: float = 0.0) -> Dictionary:
		var result: Dictionary = super.play(player_id, from_position)
		if player_id == &"AmbienceA":
			starts.append({"position_ms": int(round(from_position * 1000.0)), "ok": result.get("ok", false)})
		return result
	func stop_and_clear(player_id: StringName) -> Dictionary:
		if player_id == &"AmbienceA": clears += 1
		return super.stop_and_clear(player_id)

var native: ObservedNativePort
var expected_start := 0.0
var continuity: Array = []
var ready_playback: AudioStreamPlayback

func _install_content_registration() -> Dictionary:
	return AUDIO_CONTENT.new()._install_registration()

func _start_services() -> bool:
	# The manual bootstrap has not initialized any service. Replace only the
	# uninitialized audio autoload with the SAME production script and native port.
	var old: Node = get_node("/root/AudioManager")
	assert_false(old._initialized)
	if old._initialized: return false
	old.free()
	native = ObservedNativePort.new()
	var audio: Node = AUDIO_OWNER.new(native)
	audio.name = "AudioManager"
	get_tree().root.add_child(audio)
	return super._start_services()

func _await_ready() -> bool:
	if not await super._await_ready(): return false
	assert_eq(native.starts, [{"position_ms": int(round(expected_start * 1000.0)), "ok": true}], "one actual native start at authored offset")
	var player: AudioStreamPlayer = native._players[&"AmbienceA"]
	assert_true(player.playing)
	assert_false(player.stream_paused)
	assert_true(player.has_stream_playback())
	if not player.has_stream_playback(): return false
	ready_playback = player.get_stream_playback()
	for frame: int in 4: await get_tree().process_frame
	assert_eq(native.starts.size(), 1, "native readiness must not restart audio")
	assert_same(player.get_stream_playback(), ready_playback)
	return true

func _click(control: Control) -> void:
	if control.name != "CheckComputer":
		await super._click(control)
		return
	var audio: Node = get_node("/root/AudioManager")
	var player: AudioStreamPlayer = native._players[&"AmbienceA"]
	var playback: AudioStreamPlayback = player.get_stream_playback()
	var stream: AudioStream = player.stream
	var context: Dictionary = audio.get_semantic_audio_context()
	var starts := native.starts.size()
	var clears := native.clears
	await super._click(control)
	assert_true(player.playing)
	assert_false(player.stream_paused)
	var before := player.get_playback_position()
	await get_tree().create_timer(0.15).timeout
	var after := player.get_playback_position()
	assert_true(player.playing)
	assert_false(player.stream_paused)
	assert_same(player.stream, stream)
	assert_same(player.get_stream_playback(), playback, "computer retains native playback identity")
	assert_eq(native.starts.size(), starts)
	assert_eq(native.clears, clears)
	assert_eq(audio.get_semantic_audio_context(), context)
	# The authored fixture loops at four seconds; account for a loop boundary.
	var advance := fposmod(after - before, 4.0)
	assert_gt(advance, 0.02, "audio advances while computer owns only captions")
	assert_lt(advance, 1.0, "bounded observation excludes an unexplained seek")
	continuity.append({"computer_open": get_tree().current_scene.is_computer_open(),
		"before_ms": int(round(before * 1000.0)), "after_ms": int(round(after * 1000.0)), "advance_ms": int(round(advance * 1000.0)),
		"playback_id": playback.get_instance_id(), "starts": starts, "clears": clears})

func _audio_checkpoint() -> Dictionary:
	var registered: Dictionary = REGISTRY.scene_registration()
	if not _ok(registered): return {}
	assert_eq(registered.value.schema_version, 3)
	var selected: Dictionary = saves.get_latest_stable_checkpoint()
	if not _ok(selected): return {}
	var snapshot: Dictionary = selected.value.bundle.snapshot
	var admission: String = snapshot.scene.active_admission_receipt_id
	var entry: String = snapshot.command_receipts[admission].scene_admission.result.entry_id
	var expected: Dictionary = AUDIO_MANIFEST.make_scene_context(registered.value, entry, admission)
	if not _ok(expected): return {}
	assert_false(snapshot.has("audio_context"), "player snapshot stores no duplicated audio context")
	var derived: Dictionary = RUN_SCHEMA.derive_scene_audio_context(snapshot)
	if not _ok(derived): return {}
	assert_eq(derived.value, expected.value)
	assert_eq(get_node("/root/AudioManager").get_semantic_audio_context(), expected.value)
	assert_false(derived.value.has("scene_audio_mode"))
	return expected.value

func create_audio_scene() -> void:
	expected_start = 0.0
	await create_computer_board()
	assert_true(FileAccess.file_exists("user://computer-board-proof.json"))
	if not FileAccess.file_exists("user://computer-board-proof.json"): return
	var context: Dictionary = _audio_checkpoint()
	assert_false(context.is_empty())
	_assert_saved_audio("user://saves/slot_1.json", context)
	if not _retain_obsolete_audio_fixture(): return
	assert_gte(continuity.size(), 3)
	var proof := {"process_id": OS.get_process_id(), "context": context,
		"starts": native.starts, "continuity": continuity, "ready_count": ready_count,
		"renderer": DisplayServer.get_name()}
	if not _write_json("user://audio-connected-proof.json", proof): return
	_write_json("res://.godot/ci/audio-connected-create-proof.json", proof)

func load_audio_scene() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://audio-connected-proof.json"))
	if not _ok(parsed): return
	expected_start = 1.0
	await load_computer_board()
	var context: Dictionary = _audio_checkpoint()
	assert_eq(context, parsed.value.context, "Load retains admission and canonical selection")
	assert_ne(OS.get_process_id(), parsed.value.process_id)
	assert_gte(continuity.size(), 1)
	# Saving the restored and continued board must retain the same audio identity.
	if not _ok(saves.save_latest_to_slot(2)): return
	assert_eq(_audio_checkpoint(), context)
	_assert_saved_audio("user://saves/slot_2.json", context)
	var destination: Dictionary = await _finish_to_silent_target(context)
	if destination.is_empty(): return
	_write_json("res://.godot/ci/audio-connected-load-proof.json", {
		"process_id": OS.get_process_id(), "creator_process_id": parsed.value.process_id,
		"context": context, "destination_context": destination, "starts": native.starts, "continuity": continuity,
		"ready_count": ready_count, "renderer": DisplayServer.get_name(),
		"resaved_slot_sha256": FileAccess.get_sha256("user://saves/slot_2.json")})

## Deliberate test input: the writer has already proved omission above. Fresh
## Load must ignore an obsolete track selector while retaining the same progress.
func _retain_obsolete_audio_fixture() -> bool:
	var path := "user://saves/slot_1.json"
	var document: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(path))
	if not _ok(document): return false
	document.value.current_snapshot.snapshot["audio_context"] = {"selection": {"plan_id": "obsolete.invalid-track"}}
	if not _write_json(path, document.value): return false
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://computer-board-proof.json"))
	if not _ok(parsed): return false
	parsed.value["slot_sha256"] = FileAccess.get_sha256(path)
	parsed.value["obsolete_audio_injected"] = true
	if not _write_json("user://computer-board-proof.json", parsed.value): return false
	return _write_json("res://.godot/ci/audio-obsolete-input-proof.json", parsed.value)

func _assert_saved_audio(path: String, expected: Dictionary) -> void:
	var document: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(path))
	if not _ok(document): return
	var snapshot: Dictionary = document.value.current_snapshot.snapshot
	assert_false(snapshot.has("audio_context"), "written Scene save omits audio metadata")
	var derived: Dictionary = RUN_SCHEMA.derive_scene_audio_context(snapshot)
	if not _ok(derived): return
	assert_eq(derived.value, expected)
	# Obsolete fields cannot choose a soundtrack or block admitted progress.
	for obsolete: Variant in [null, "missing-track", {"selection": {"plan_id": "foreign-track"}}]:
		var old: Dictionary = snapshot.duplicate(true)
		old["audio_context"] = obsolete
		var admitted: Dictionary = RUN_SCHEMA.validate(old)
		if not _ok(admitted): continue
		assert_eq(admitted.value.candidate, snapshot)
		assert_eq(RUN_SCHEMA.derive_scene_audio_context(admitted.value.candidate).value, expected)
		assert_true(old.has("audio_context"), "normalization leaves source bytes untouched")

func _finish_to_silent_target(source: Dictionary) -> Dictionary:
	# Continue the restored real board to an authored losing transition. Layout
	# inspection only selects test input; all completion/admission owners are real.
	if not _ok(profile.set_preference(&"preferences.reading.auto_delay", "short")): return {}
	var host: Node = get_tree().current_scene
	assert_true(host.is_computer_open())
	var panel: Control = host.get_challenge_mount().get_node("SceneChallengePanel")
	var failures: Array = []
	panel.presentation_failed.connect(func(code: StringName): failures.append(String(code)))
	bridge.next_request_finished.connect(func(_frontier: Dictionary, result: Dictionary):
		if not result.get("ok", false): failures.append(str(result)))
	bridge.scene_activation_failed.connect(func(_operation: String, result: Dictionary): failures.append(str(result)))
	var terminal := [false]
	panel.presentation_changed.connect(func():
		if panel.public_view.get("phase") == "terminal": terminal[0] = true)
	var record: Dictionary = game.capture_dating_challenge_state().value
	var mine := -1
	for index: int in record.board.mine_indices:
		if "reveal" in panel.public_view.board.cells[index].actions:
			mine = index
			break
	assert_gte(mine, 0)
	if mine < 0: return {}
	assert_true(panel.worksheet.set_mode(&"reveal"))
	assert_true(panel.worksheet.grid.focus_cell(mine))
	await get_tree().process_frame
	assert_true(panel._can_interact())
	await _click(panel.worksheet.grid.cell_nodes[mine])
	var arrived := false
	var deadline := Time.get_ticks_msec() + 15000
	# A synchronous durable transition can finish in the last awaited frame.
	# Inspect that completed frame before declaring timeout; this is not a
	# performance deadline or permission to retry the game operation.
	while true:
		var reading: Dictionary = bridge.capture_reading_checkpoint(false)
		if reading.get("ok", false) and reading.value.entry_id == "scene.test.a":
			arrived = true
			break
		if Time.get_ticks_msec() >= deadline: break
		await get_tree().process_frame
	var diagnostic := {"arrived": arrived, "terminal_observed": terminal[0], "failures": failures,
		"paused": get_tree().paused, "computer_open": host.is_computer_open(),
		"panel_phase": str(panel.public_view.get("phase", "")),
		"reading": str(bridge.capture_reading_checkpoint(false)),
		"entry_operation_keys": game._scene_entry_operation.keys(),
		"live_audio": get_node("/root/AudioManager").get_semantic_audio_context()}
	_write_json("res://.godot/ci/audio-forward-diagnostic.json", diagnostic)
	assert_true(terminal[0], "real mine input produced terminal publication")
	assert_true(arrived, "registered Challenge completion reaches explicit silent target: " + str(failures))
	if not arrived: return {}
	var destination: Dictionary = _audio_checkpoint()
	assert_null(destination.selection)
	assert_ne(destination.admission_receipt_id, source.admission_receipt_id)
	assert_eq(destination.registration_sha256, source.registration_sha256)
	var player: AudioStreamPlayer = native._players[&"AmbienceA"]
	assert_false(player.playing)
	assert_null(player.stream)
	assert_eq(native.starts.size(), 1, "silent target never starts an inherited stream")
	await _screenshot("audio-silent-target")
	return destination
