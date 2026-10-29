extends "res://tests/integration/scene_inline_presentation_child.gd"
## Producer and same-process checkpoint/Load acceptance.

func test_inline_art_checkpoint_and_load_keep_current_composition_without_replay() -> void:
	if not await _begin_inline(): return
	var storage: RefCounted = saves._storage
	var original_files: RefCounted = storage._file_ops
	var files := CountingFiles.new()
	storage._file_ops = files
	_assert_art("template.background", ["portrait"])
	if not await _advance_to("line.scene.test.a.two"): return
	_assert_art("template.art", ["portrait", "letter"])
	_assert_selection("TEST.inline.b")
	assert_eq(files.autosave_writes, 0, "ordinary artwork changes never write Autosave")
	var composition: Dictionary = game.capture_run_snapshot_input().scene.presentation.duplicate(true)
	if not await _save_inline(4, "TEST.inline.b"): return
	var starts: int = _starts("SFX")
	if not await _advance_to("line.scene.test.a.three"): return
	assert_eq(files.autosave_writes, 1, "the inline checkpoint writes at its accepted caption")
	_assert_art("template.art", ["portrait", "letter"])
	_assert_selection("TEST.inline.a")
	var expected: Dictionary = composition.duplicate(true)
	expected.checkpoint_id = "template.checkpoint"
	assert_eq(game.capture_run_snapshot_input().scene.presentation, expected)
	var saved: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/autosave.json"))
	if not _ok(saved): return
	assert_eq(saved.value.current_snapshot.snapshot.scene.presentation, expected)
	assert_eq(saved.value.current_snapshot.snapshot.scene.music_plan_id, "TEST.inline.a")
	assert_eq(saved.value.current_snapshot.snapshot.narrative_checkpoint.reading_session.position_id,
		"line.scene.test.a.three")
	await _screenshot("inline-presentation-checkpoint")
	if not await _advance_to("line.scene.test.a.four"): return
	_assert_art("template.art", ["letter"])
	if not await _advance_to("line.scene.test.a.five"): return
	_assert_art("template.art", ["letter", "portrait"])
	if not await _advance_to("line.scene.test.a.four"): return
	_assert_art("template.art", ["letter"])
	if not await _advance_to("line.scene.test.a.five"): return
	_assert_art("template.art", ["letter", "portrait"])
	assert_eq(files.autosave_writes, 1, "repeated branch artwork remains independent of checkpoint arrival")
	var autosave_hash := _autosave_sha256()
	if not await _load_inline(4, false): return
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.two")
	assert_eq(game.capture_run_snapshot_input().scene.presentation, composition)
	_assert_art("template.art", ["portrait", "letter"])
	_assert_selection("TEST.inline.b")
	assert_eq(_starts("SFX"), starts, "Load restores selection without replaying one-shots")
	assert_eq(files.autosave_writes, 1, "Load never executes checkpoint commands")
	assert_eq(_autosave_sha256(), autosave_hash)
	await _screenshot("inline-presentation-loaded")
	_write_json("res://.godot/ci/inline-presentation.json", {"restored": composition,
		"checkpoint": expected, "autosave_writes": files.autosave_writes,
		"starts": observed.starts, "renderer": DisplayServer.get_name()})
	_write_json("user://inline-presentation-proof.json", {"process_id": OS.get_process_id(),
		"presentation": composition, "checkpoint": expected,
		"slot_4_sha256": FileAccess.get_sha256("user://saves/slot_4.json"),
		"autosave_sha256": autosave_hash})
	storage._file_ops = original_files
	ART.reload_placements()
