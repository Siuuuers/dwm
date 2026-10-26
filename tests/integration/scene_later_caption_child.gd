extends "res://tests/integration/scene_computer_child.gd"
## Real FINAL host, Viewport Accept, physical Save and separate-process Load.
## Only reveal timing is slowed; no logical/native position is assigned.
const COMPACT_READING := preload("res://scripts/narrative/SoloReadingSession.gd")
const PROOF_PATH := "user://scene-later-caption-proof.json"
const LOOP_LINE := "line.scene.test.a.two"
var _ready_observation: Dictionary = {}
# Opt-in test observations only; monotonic ticks share the engine process origin.
var _ending_phase_timing: bool = false

func _ending_phase(label: String) -> void:
	if _ending_phase_timing:
		print("ENDING_LOAD_PHASE pid=", OS.get_process_id(), " ticks_usec=", Time.get_ticks_usec(), " phase=", label)


func _screenshot(label: String) -> void:
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	await get_tree().process_frame
	await super._screenshot(label)

func _ok(result: Dictionary) -> bool:
	assert_true(result.get("ok", false), str(result.get("code", "ok")))
	return result.get("ok", false)

func _native_observation(retained_native: Node = null) -> Dictionary:
	var native: Node = retained_native
	if native == null:
		var caption: Node = _caption()
		if caption != null: native = caption.caption_text
	# Pause deliberately hides the layer and excludes current_line_id(). Retain
	# the exact source node and inspect the actual event with paused admission.
	var event: DialogicTextEvent = bridge._runtime_adapter._current_skip_text(true)
	return {"line_id": bridge._runtime_adapter._authored_line_id(event),
		"revealing": native.revealing if is_instance_valid(native) else true,
		"visible_ratio": native.visible_ratio if is_instance_valid(native) else -1.0,
		"text": native.get_parsed_text() if is_instance_valid(native) else "",
		"visible": is_instance_valid(native) and native.is_visible_in_tree(),
		"event_done": event != null and event.state == DialogicTextEvent.States.DONE,
		"ledger": bridge._reading_session.ledger.snapshot().duplicate(true)}

func _accept(wait_for_input: bool = true) -> void:
	_ending_phase("accept.begin")
	# Native reveal completion and manual-input readiness are distinct. Organic
	# reveal starts Dialogic's advance-delay guard after publishing text_finished.
	# Observe that owner; never stop its timer or use Save as a timing workaround.
	if wait_for_input:
		var inputs: Node = bridge._runtime_adapter._dialogic.get_subsystem("Inputs")
		var deadline := Time.get_ticks_msec() + 5000
		while inputs.is_input_blocked() and Time.get_ticks_msec() < deadline:
			await get_tree().process_frame
		assert_false(inputs.is_input_blocked(), "native manual input is ready")
		if inputs.is_input_blocked(): return
	_ending_phase("accept.input_ready")
	var overlay := get_tree().root.find_child("GutLayer", true, false)
	if overlay is CanvasLayer: overlay.hide()
	var caption: Node = _caption()
	assert_not_null(caption)
	if caption == null: return
	caption.caption_text.grab_focus()
	await get_tree().process_frame
	assert_true(caption.caption_text.has_focus(), "caption owns Accept focus")
	_ending_phase("accept.focus_checked")
	for pressed: bool in [true, false]:
		var event := InputEventKey.new()
		event.keycode = KEY_ENTER
		event.physical_keycode = KEY_ENTER
		event.pressed = pressed
		_ending_phase("accept.press.before" if pressed else "accept.release.before")
		get_viewport().push_input(event, true)
		_ending_phase("accept.press.return" if pressed else "accept.release.return")
		await get_tree().process_frame
		_ending_phase("accept.press.frame" if pressed else "accept.release.frame")
	for frame: int in 4: await get_tree().process_frame
	_ending_phase("accept.return")

func _assert_source_files(proof: Dictionary, phase: String = "after Load") -> void:
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256, phase + ": source slot unchanged")
	assert_eq(_autosave_sha256(), proof.autosave_sha256, phase + ": source autosave unchanged")
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256, phase + ": global Profile unchanged")

func create_later_caption() -> void:
	if not _start_services(): return
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	assert_false(FileAccess.file_exists("user://saves/slot_1.json"))
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending")
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.one")
	assert_false(_caption().caption_text.revealing, "initial activation reveals first caption")
	var first: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(first): return
	# Native update_dialog_text resets speed AFTER started_revealing_text.
	# text_started follows that reset and precedes the first idle reveal tick.
	# Change only elapsed reveal timing, never text position or reveal state.
	var native: Node = _caption().caption_text
	var slow := func(_info: Dictionary) -> void: native.active_speed = 10.0
	get_node("/root/Dialogic").Text.text_started.connect(slow, CONNECT_ONE_SHOT)
	await _accept()
	var visible := _native_observation()
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	var diagnostic := {"process_id": OS.get_process_id(), "native": visible,
		"capture_ok": checkpoint.get("ok", false), "capture_code": str(checkpoint.get("code", "ok")),
		"logical_program_index": bridge._reading_session.scene_index,
		"first_checkpoint": first.value}
	# Baseline failure must leave its actual native/logical discrepancy inspectable.
	if not _write_json("res://.godot/ci/scene-later-caption-diagnostic.json", diagnostic): return
	await _screenshot("later-caption-partial-source")
	assert_eq(visible.line_id, LOOP_LINE)
	assert_true(visible.visible)
	assert_true("A loop." in visible.text)
	assert_true(visible.revealing, "pre-Save source is a genuine partial native reveal")
	assert_lt(float(visible.visible_ratio), 1.0)
	if not _ok(checkpoint): return
	assert_eq(checkpoint.value.reading_session.frontier.line_id, LOOP_LINE)
	assert_gt(int(checkpoint.value.reading_session.program_index), int(first.value.reading_session.program_index))
	assert_ne(checkpoint.value.reading_session.frontier.publication_id, first.value.reading_session.frontier.publication_id)
	await _click(_controls(get_tree().current_scene, "Save"))
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(sheet.can_save_backup(), str(sheet.last_result.get("code", "ok")))
	if not sheet.can_save_backup(): return
	# Existing Save entry completes the partial source under suspension;
	# source_native below records the pre-Save reveal, not a persisted cursor.
	var saved_native := _native_observation(native)
	assert_eq(saved_native.line_id, LOOP_LINE)
	assert_false(saved_native.revealing, "Save entry completes the admitted source reveal")
	assert_eq(float(saved_native.visible_ratio), 1.0)
	assert_true(saved_native.event_done, "Save entry leaves native text DONE")
	assert_true(saved_native.ledger == visible.ledger, "Save entry preserves publication ledger")
	var prepared: Dictionary = sheet._backup_port.prepare_action("save", "slot:1")
	if not _ok(prepared): return
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return
	sheet.surface.leave_host()
	for frame: int in 4: await get_tree().process_frame
	var document: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(document): return
	var snapshot: Dictionary = document.value.current_snapshot.snapshot
	var projected: Dictionary = COMPACT_READING.project_player_checkpoint(checkpoint.value)
	if not _ok(projected): return
	assert_true(snapshot.narrative_checkpoint == projected.value,
		"real slot retains the canonical current position")
	assert_eq(snapshot.narrative_checkpoint.reading_session.schema_version, 7)
	assert_false(snapshot.narrative_checkpoint.reading_session.has("ledger"))
	assert_false(snapshot.narrative_checkpoint.reading_session.has("next_operation"))
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "reading creates no board")
	var proof := {"process_id": OS.get_process_id(), "user_dir": ProjectSettings.globalize_path("user://"),
		"checkpoint": snapshot.narrative_checkpoint, "source_native": visible, "saved_native": saved_native,
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"autosave_sha256": _autosave_sha256(),
		"profile_sha256": FileAccess.get_sha256("user://profile.json"),
		"profile": profile.get_profile_snapshot(), "gameplay": snapshot.gameplay,
		"scene": snapshot.scene}
	for field: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_false(snapshot.has(field), "player save omits live retry state: " + field)
	for key: String in ["slot_sha256", "autosave_sha256", "profile_sha256"]:
		assert_eq(str(proof[key]).length(), 64)
	if not _write_json(PROOF_PATH, proof): return
	_write_json("res://.godot/ci/scene-later-caption-create-proof.json", proof)

func load_later_caption() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(PROOF_PATH))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id, "fresh process")
	assert_eq(ProjectSettings.globalize_path("user://"), proof.user_dir)
	_assert_source_files(proof, "before bootstrap")
	if not _start_services(): return
	_assert_source_files(proof, "after bootstrap")
	saves.live_session_ready.connect(func() -> void: _ready_observation = _native_observation())
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending")
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	assert_eq(ready_count, 1)
	assert_eq(get_tree().current_scene.scene_file_path, HOST)
	var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(checkpoint): return
	var expanded: Dictionary = COMPACT_READING.expand_player_checkpoint(proof.checkpoint)
	if not _ok(expanded): return
	var expected_checkpoint: Dictionary = expanded.value
	assert_true(checkpoint.value == expected_checkpoint, "same saved current caption, publication and occurrence")
	assert_eq(_ready_observation.line_id, LOOP_LINE)
	assert_true(_ready_observation.visible)
	assert_true("A loop." in _ready_observation.text)
	assert_false(_ready_observation.revealing, "Load is fully revealed at Ready")
	assert_eq(float(_ready_observation.visible_ratio), 1.0)
	assert_true(_ready_observation.event_done, "native text event is DONE at Ready")
	assert_true(_ready_observation.ledger == expected_checkpoint.reading_session.ledger, "Load allocates no publication")
	await _screenshot("later-caption-restored-full")
	var current: Dictionary = game.capture_run_snapshot_input()
	assert_true(current.gameplay == proof.gameplay, "Load replays no gameplay consequence")
	assert_true(current.scene == proof.scene, "Load preserves scene progress")
	assert_true(current.command_receipts.is_empty(), "Load creates no command receipt")
	assert_true(current.applied_effect_transaction_ids.is_empty(), "Load applies no effect")
	assert_true(current.applied_variable_transaction_ids.is_empty(), "Load applies no variable transaction")
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "Load creates no board")
	assert_true(profile.get_profile_snapshot() == proof.profile, "Load writes no Profile history")
	_assert_source_files(proof)
	await _accept()
	var continued: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(continued): return
	assert_eq(continued.value.reading_session.frontier.line_id, LOOP_LINE)
	assert_eq(continued.value.reading_session.program_index, expected_checkpoint.reading_session.program_index)
	assert_eq(continued.value.reading_session.occurrence_id, proof.checkpoint.reading_session.occurrence_id)
	assert_ne(continued.value.reading_session.frontier.publication_id, expected_checkpoint.reading_session.frontier.publication_id)
	assert_eq(continued.value.reading_session.ledger.captions.size(), expected_checkpoint.reading_session.ledger.captions.size() + 1)
	var ledger: Dictionary = bridge._reading_session.ledger.snapshot().duplicate(true)
	bridge._runtime_adapter._on_caption_about_to_show({})
	bridge._runtime_adapter._on_caption_text_started({})
	bridge._runtime_adapter._on_caption_about_to_show({})
	bridge._runtime_adapter._on_caption_text_started({})
	assert_true(bridge._reading_session.ledger.snapshot() == ledger, "duplicate callbacks allocate no publication")
	assert_true(bridge.capture_reading_checkpoint(false) == continued, "duplicate callbacks preserve exact loop frontier")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256, "continued reading preserves source slot")
	await _screenshot("later-caption-loop-continued")
	proof["loader_process_id"] = OS.get_process_id()
	proof["ready_native"] = _ready_observation
	proof["continued_checkpoint"] = continued.value
	_write_json("res://.godot/ci/scene-later-caption-load-proof.json", proof)

