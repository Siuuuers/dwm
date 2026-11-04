extends "res://addons/gut/test.gd"
const FIXTURE := preload("res://tests/support/ScenePlayableFixture.gd")
const SAVE_SCHEMA := preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const PARSER := preload("res://scripts/validation/StrictJson.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
var fixture: RefCounted
var fixture_ready := false

func before_all() -> void:
	fixture = FIXTURE.new()
	var checked: Dictionary = await fixture.setup_playable(get_tree())
	assert_true(checked.get("ok", false), str(checked))
	fixture_ready = checked.get("ok", false)

func after_all() -> void:
	if fixture != null: await fixture.close_restart()

func create_playable() -> void:
	if not fixture_ready: return
	var started: Dictionary = await fixture.begin_playable_source()
	assert_true(started.get("ok", false), str(started))
	if not started.get("ok", false): return
	var autosave_existed: bool = fixture.storage.exists("autosave.json")
	var original := ""
	if autosave_existed: original = fixture.storage.read_text("autosave.json").value
	var profile_hashes: Dictionary = fixture.profile_bytes()
	var result: Dictionary = fixture.dispatch()
	assert_true(result.get("ok", false), str(result))
	if not result.get("ok", false): return
	assert_false(result.get("duplicate", true))
	assert_eq(result.value.kind, "challenge_playable")
	assert_eq(fixture.bridge._reading_session.boundary, "control")
	var native: Dictionary = fixture.adapter.capture_scene_control_position(fixture.bridge._reading_session)
	assert_true(native.ok, str(native))
	if not native.ok: return
	assert_eq(native.value.ledger, fixture.before_reading.reading_session.ledger)
	assert_eq(fixture.native_publications.size(), fixture.before_publications)
	assert_eq(fixture.native_markers, [])
	assert_eq(fixture.files.autosave_writes, 0, "playable adoption does not write an autosave")
	assert_eq(fixture.storage.exists("autosave.json"), autosave_existed)
	if autosave_existed: assert_eq(fixture.storage.read_text("autosave.json").value, original)
	assert_eq(fixture.profile_bytes(), profile_hashes)
	var current: Dictionary = fixture.game.capture_run_snapshot_input()
	assert_true(current.command_receipts.has(fixture.issued_event.command_id))
	assert_eq(current.command_receipts.size(), fixture.before_input.command_receipts.size() + 1)
	assert_eq(current.gameplay, fixture.before_input.gameplay, "availability does not create a board")
	var retry: Dictionary = fixture.dispatch()
	assert_true(retry.get("ok", false), str(retry))
	assert_true(retry.get("duplicate", false))
	assert_eq(retry.get("value"), result.value)
	assert_eq(fixture.game.capture_run_snapshot_input(), current)
	assert_eq(fixture.files.autosave_writes, 0)
	var checkpoint: Dictionary = fixture.bridge.capture_reading_checkpoint(false)
	assert_true(checkpoint.ok, str(checkpoint))
	if not checkpoint.ok: return
	var live_board := DesktopBoardState.new()
	var board_plan := live_board.prepare_player_restore_scene(current.desktop.board, fixture.issuer)
	assert_true(board_plan.ok, str(board_plan))
	if not board_plan.ok: return
	assert_true(live_board.commit(board_plan.value.candidate).ok)
	current.desktop.board = live_board.capture()
	var recorded: Dictionary = fixture.manager.record_stable_checkpoint({"active_app_id": null,
		"audio_context": {}, "content_version": 1, "dialogic_checkpoint": checkpoint.value,
		"route_id": "scene", "snapshot_input": current}, &"safe_marker")
	assert_true(recorded.ok, str(recorded))
	if not recorded.ok: return
	var saved: Dictionary = fixture.manager.save_latest_to_slot(1)
	assert_true(saved.ok, str(saved))
	if not saved.ok: return
	var bytes: Dictionary = fixture.storage.read_text("slot_1.json")
	assert_true(bytes.ok, str(bytes))
	if not bytes.ok: return
	var document := PARSER.parse_object(bytes.value)
	assert_true(document.ok, str(document))
	if not document.ok: return
	assert_true(SAVE_SCHEMA.validate(document.value).ok)
	var snapshot: Dictionary = document.value.current_snapshot.snapshot
	assert_eq(snapshot.narrative_checkpoint.reading_session.schema_version, 7)
	assert_eq(snapshot.narrative_checkpoint.reading_session.boundary, "control")
	assert_eq(snapshot.narrative_checkpoint, SESSION.project_player_checkpoint(checkpoint.value).value)
	var proof := {"phase": "create", "process_id": OS.get_process_id(),
		"storage_root": fixture.storage.describe_root(), "slot_sha256": str(bytes.value).sha256_text(),
		"profile_files": fixture.profile_bytes(), "checkpoint": snapshot.narrative_checkpoint,
		"scene": snapshot.scene, "gameplay": snapshot.gameplay}
	write_proof(proof, true)

func load_playable() -> void:
	if not fixture_ready: return
	var witness_path: String = fixture.storage.describe_root().path_join("playable-witness.json")
	assert_true(FileAccess.file_exists(witness_path))
	if not FileAccess.file_exists(witness_path): return
	var read := PARSER.parse_object(FileAccess.get_file_as_string(witness_path))
	assert_true(read.ok, str(read))
	if not read.ok: return
	var witness: Dictionary = read.value
	assert_ne(OS.get_process_id(), int(witness.process_id))
	assert_eq(fixture.storage.describe_root(), witness.storage_root)
	var reconciled: Dictionary = fixture.storage.reconcile("slot_1.json", Callable(fixture.manager, "_document_text_validator"))
	assert_true(reconciled.ok, str(reconciled))
	if not reconciled.ok: return
	var bytes: Dictionary = fixture.storage.read_text("slot_1.json")
	assert_true(bytes.ok, str(bytes))
	if not bytes.ok: return
	assert_eq(str(bytes.value).sha256_text(), witness.slot_sha256)
	var prepared: Dictionary = fixture.manager.prepare_restore_slot(1)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var started: Dictionary = fixture.manager.commit_prepared_restore(prepared.value.prepared)
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending": return
	var activated: Dictionary = await fixture.await_activation()
	assert_true(activated.ok, str(activated))
	if not activated.ok: return
	assert_eq(fixture.ready_count, 1)
	assert_eq(fixture.bridge._reading_session.boundary, "control")
	var control: Dictionary = fixture.adapter.capture_scene_control_position(fixture.bridge._reading_session)
	assert_true(control.ok, str(control))
	if not control.ok: return
	assert_eq(fixture.adapter.current_line_id(), "line.scene.test.b.one")
	assert_eq(control.value.ledger.captions.size(), 1)
	var checkpoint: Dictionary = fixture.bridge.capture_reading_checkpoint(false)
	assert_true(checkpoint.ok, str(checkpoint))
	if not checkpoint.ok: return
	assert_eq(SESSION.project_player_checkpoint(checkpoint.value).value, witness.checkpoint)
	var current: Dictionary = fixture.game.capture_run_snapshot_input()
	assert_eq(current.scene, witness.scene)
	assert_eq(current.gameplay, witness.gameplay)
	assert_eq(fixture.profile_bytes(), witness.profile_files)
	assert_eq(fixture.native_markers, [])
	assert_eq(fixture.files.autosave_writes, 0)
	assert_eq(fixture.storage.read_text("slot_1.json").value, bytes.value)
	var proof: Dictionary = witness.duplicate(true)
	proof.phase = "load"
	proof["creator_process_id"] = witness.process_id
	proof.process_id = OS.get_process_id()
	write_proof(proof, false)

func write_proof(proof: Dictionary, witness: bool) -> void:
	var encoded := WRITER.stringify(proof)
	assert_true(encoded.ok, str(encoded))
	if not encoded.ok: return
	var output := "res://.godot/ci/playable-" + str(proof.phase) + ".json"
	assert_eq(DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci")), OK)
	var paths: Array[String] = [output]
	if witness: paths.append(fixture.storage.describe_root().path_join("playable-witness.json"))
	for path: String in paths:
		var file := FileAccess.open(path, FileAccess.WRITE)
		assert_not_null(file)
		if file == null: return
		file.store_string(str(encoded.value) + "\n")
		file.close()
	print("SCENE_PLAYABLE_PROOF=" + str(encoded.value))
