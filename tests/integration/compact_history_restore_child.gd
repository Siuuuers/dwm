extends "res://tests/integration/authored_week_child.gd"

func create_older_save_then_discover_more_dialogue() -> void:
	_phase = "create"
	if not _setup_authored(false, "Day2"): return
	get_node("/root/SceneRouter").goto_menu()
	if not await _new_from_title(1, _expected[0].line_id): return
	if not await _walk_authored(1, 5): return
	var proof: Dictionary = await _save_authored(1, "compact-history")
	if proof.is_empty(): return
	var older: Dictionary = profile.get_dialogue_library()
	if not await _walk_authored(6, _entry_starts["Day2"] + 2): return
	var library_fixture := preload("res://tests/support/DialogueLibraryFixture.gd")
	assert_true(library_fixture.install().ok)
	assert_true(profile.mark_caption_variant_witnessed(library_fixture.beat(),
		library_fixture.registry(library_fixture.beat()), library_fixture.CHECKPOINT).ok)
	var discoveries: Dictionary = profile.get_dialogue_library()
	assert_gt(discoveries.witnesses.size(), older.witnesses.size())
	proof["later_discoveries"] = discoveries
	assert_true(_write_json("user://compact-history-proof.json", proof))

func load_older_save_preserves_later_global_discoveries() -> void:
	_phase = "load"
	if not _setup_authored(false, "Day1"): return
	var parsed := PARSER.parse_object(FileAccess.get_file_as_string("user://compact-history-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_true(preload("res://tests/support/DialogueLibraryFixture.gd").install().ok)
	assert_eq(profile.get_dialogue_library(), proof.later_discoveries)
	if not await _load_authored(1, proof): return
	assert_eq(profile.get_dialogue_library(), proof.later_discoveries)
	assert_eq(bridge._reading_session.player_progress.history_sections, proof.checkpoint.reading_session.history_sections)
	var history: Dictionary = bridge.get_reading_history()
	if not _ok(history): return
	assert_eq(history.value.captions.back().line_id, proof.checkpoint.reading_session.position_id)

func _walk_authored(first: int, last: int) -> bool:
	for index: int in range(first, last + 1):
		if not await super._walk_authored(index, index): return false
		assert_eq(bridge._reading_session.ledger._sequence.size(), 1)
		assert_eq(bridge._reading_session.ledger._published.size(), 1)
		assert_eq(bridge._reading_session.ledger._entry_contexts.size(), 1)
		assert_lte(bridge._reading_session.player_progress.history_sections.size(), 3)
		var before: Dictionary = profile.get_dialogue_library()
		var history: Dictionary = bridge.get_reading_history()
		if not _ok(history): return false
		assert_eq(profile.get_dialogue_library(), before)
		assert_true(history.value.captions.any(func(row: Dictionary) -> bool: return row.line_id == _expected[index].line_id))
	return true
