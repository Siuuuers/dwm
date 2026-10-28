extends "res://tests/ui/render_save_ink_base.gd"

func test_successful_saves_age_only_the_destination_and_delete_clears_ink() -> void:
	if not await _begin_ink_run(): return
	if not _ok(saves.autosave_latest()): return
	var auto_before: Array = _ink_document("autosave.json").ink_marks.duplicate()
	assert_eq(auto_before.size(), 1)
	if not _ok(saves.autosave_latest()): return
	var auto_after: Array = _ink_document("autosave.json").ink_marks
	assert_eq(auto_after.size(), 2)
	assert_eq(auto_after[0], auto_before[0])
	var sheet: Node = await _ink_sheet()
	if sheet == null: return
	var first_save: Dictionary = sheet._backup_port.prepare_action("save", "slot:1")
	if not _ok(first_save): return
	if not _ok(await sheet._backup_port.commit_action(first_save.value.token)): return
	assert_false(sheet._backup_port.commit_action(first_save.value.token).get("ok", false), "completed token cannot add another mark")
	var unmarked: Dictionary = _ink_document("slot_1.json").duplicate(true)
	unmarked.erase("ink_marks")
	assert_true(preload("res://scripts/infrastructure/save/SaveDocumentSchema.gd").validate(unmarked).get("ok", false), "existing Save9 without marks remains valid")
	var previous: Array = _ink_document("slot_1.json").ink_marks.duplicate()
	assert_eq(previous.size(), 1)
	var original_seed: int = previous[0]
	# Cancelling preparation and refreshing projection do not modify the slot.
	var hash_before := FileAccess.get_sha256("user://saves/slot_1.json")
	var cancelled: Dictionary = sheet._backup_port.prepare_action("save", "slot:1")
	if not _ok(cancelled): return
	sheet._backup_port.cancel_action(cancelled.value.token)
	assert_false(sheet._backup_port.commit_action(cancelled.value.token).get("ok", false))
	for repetition: int in 3: sheet._backup_port.get_projection()
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), hash_before)
	for overwrite: int in 9:
		if not await _ink_action(sheet, "save", "slot:1"): return
		var marks: Array = _ink_document("slot_1.json").ink_marks
		assert_eq(marks.size(), mini(previous.size() + 1, 8))
		assert_eq(marks.slice(0, marks.size() - 1), previous.slice(maxi(0, previous.size() - 7)), "only oldest overflow is retired")
		previous = marks.duplicate()
	assert_false(previous.has(original_seed), "bounded history retires the earliest splash")
	if not await _ink_action(sheet, "save", "quick"): return
	var quick_before: Array = _ink_document("quicksave.json").ink_marks.duplicate()
	assert_eq(quick_before.size(), 1)
	if not await _ink_action(sheet, "save", "quick"): return
	assert_eq(_ink_document("quicksave.json").ink_marks.size(), 2)
	assert_eq(_ink_document("quicksave.json").ink_marks[0], quick_before[0])
	assert_eq(_ink_document("autosave.json").ink_marks, auto_after, "other slots never age Autosave")
	if not await _ink_action(sheet, "save", "slot:2"): return
	if not await _ink_action(sheet, "delete", "slot:2"): return
	assert_false(FileAccess.file_exists("user://saves/slot_2.json"))
	var deleted: Dictionary = saves.inspect_backup("slot:2")
	if not _ok(deleted): return
	assert_eq(deleted.value.ink_marks, [])
	if not await _ink_action(sheet, "save", "slot:2"): return
	assert_eq(_ink_document("slot_2.json").ink_marks.size(), 1, "saving after Delete starts fresh")
	await _screenshot("save-ink-all-save-types")
	await _leave_ink_sheet(sheet)
	var proof := {"creator_process_id": OS.get_process_id(), "marks": previous,
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"profile_sha256": FileAccess.get_sha256("user://profile.json")}
	if not _write_json(INK_PROOF, proof): return
	if not _write_json("res://.godot/ci/save-ink-create.json", proof): return
	print("SAVE_INK_CREATE_COMPLETED")
