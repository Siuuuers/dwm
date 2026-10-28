extends "res://tests/ui/render_save_ink_base.gd"

func test_all_save_types_omit_ink_and_existing_ink_remains_loadable() -> void:
	if not await _begin_ink_run(): return
	assert_false(_ink_document("autosave.json").has("ink_marks"), "new run Autosave omits ink")
	if not _ok(saves.autosave_latest()): return
	assert_false(_ink_document("autosave.json").has("ink_marks"))
	var sheet: Node = await _ink_sheet()
	if sheet == null: return
	for locator: String in ["slot:1", "slot:2", "quick"]:
		if not await _ink_action(sheet, "save", locator): return
	for file: String in ["slot_1.json", "slot_2.json", "quicksave.json"]:
		assert_false(_ink_document(file).has("ink_marks"))
	if not await _ink_action(sheet, "delete", "slot:2"): return
	assert_false(FileAccess.file_exists("user://saves/slot_2.json"))
	if not await _ink_action(sheet, "save", "slot:2"): return
	assert_false(_ink_document("slot_2.json").has("ink_marks"), "saving after Delete stays undecorated")
	await _screenshot("save-ink-all-save-types")
	await _leave_ink_sheet(sheet)
	# Preserve an actual old-format save for the fresh-process compatibility journey.
	var legacy := _ink_document("slot_1.json")
	legacy["ink_marks"] = [17, 420, 9123]
	if not _write_json("user://saves/slot_1.json", legacy): return
	var proof := {"creator_process_id": OS.get_process_id(),
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"profile_sha256": FileAccess.get_sha256("user://profile.json")}
	if not _write_json(INK_PROOF, proof): return
	if not _write_json("res://.godot/ci/save-ink-create.json", proof): return
	print("SAVE_INK_CREATE_COMPLETED")
