extends "res://tests/ui/render_save_ink_base.gd"

func test_fresh_process_load_preserves_slot_marks_and_overwrite_uses_destination() -> void:
	assert_ne(DisplayServer.get_name(), "headless")
	if DisplayServer.get_name() == "headless": return
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(INK_PROOF))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), int(proof.creator_process_id))
	if not _start_services(): return
	var port: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(port.configure(saves, "title")): return
	var prepared: Dictionary = port.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = port.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending")
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.b", "line.scene.test.b.one"): return
	assert_eq(_ink_document("slot_1.json").ink_marks, proof.marks)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	var sheet: Node = await _ink_sheet()
	if sheet == null: return
	await _screenshot("save-ink-fresh-load")
	await _leave_ink_sheet(sheet)
	sheet = await _ink_sheet()
	if sheet == null: return
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256, "reopening never rerolls or ages ink")
	# The loaded source has eight marks; slot 2 has one. Destination ownership wins.
	var target_before: Array = _ink_document("slot_2.json").ink_marks.duplicate()
	assert_eq(target_before.size(), 1)
	if not await _ink_action(sheet, "save", "slot:2"): return
	var target_after: Array = _ink_document("slot_2.json").ink_marks
	assert_eq(target_after.size(), 2)
	assert_eq(target_after[0], target_before[0])
	assert_eq(_ink_document("slot_1.json").ink_marks, proof.marks)
	await _screenshot("save-ink-destination-overwrite")
	if not _write_json("res://.godot/ci/save-ink-load.json", {"process_id": OS.get_process_id(),
		"creator_process_id": proof.creator_process_id, "marks": target_after}): return
	print("SAVE_INK_LOAD_COMPLETED")
