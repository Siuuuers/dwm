extends "res://tests/ui/render_save_ink_base.gd"

func test_fresh_process_load_accepts_old_ink_without_projecting_or_recreating_it() -> void:
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
	assert_eq(_ink_document("slot_1.json").ink_marks, [17, 420, 9123], "load preserves source bytes")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://profile.json"), proof.profile_sha256)
	var sheet: Node = await _ink_sheet()
	if sheet == null: return
	await _screenshot("save-ink-fresh-load")
	await _leave_ink_sheet(sheet)
	sheet = await _ink_sheet()
	if sheet == null: return
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256, "reopening does not rewrite old saves")
	var inspected: Dictionary = saves.inspect_backup("slot:1")
	if not _ok(inspected): return
	assert_false(inspected.value.has("ink_marks"), "old decoration is not projected")
	if not await _ink_action(sheet, "save", "slot:2"): return
	assert_false(_ink_document("slot_2.json").has("ink_marks"))
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	if not await _ink_action(sheet, "save", "slot:1"): return
	assert_false(_ink_document("slot_1.json").has("ink_marks"), "overwriting a legacy save retires its decoration")
	await _screenshot("save-ink-destination-overwrite")
	if not _write_json("res://.godot/ci/save-ink-load.json", {"process_id": OS.get_process_id(),
		"creator_process_id": proof.creator_process_id, "retired_ink": true}): return
	print("SAVE_INK_LOAD_COMPLETED")
