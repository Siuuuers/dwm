extends "res://tests/integration/scene_manual_entry_child.gd"
## Real FINAL services/files. Message seeding and Save/Load use application ports;
## correspondence selection and all caption/board actions use Viewport input.
const CONTACT_CONTENT := preload("res://tests/support/SceneContactsRegistrationFixture.gd")

func _install_content_registration() -> Dictionary:
	return CONTACT_CONTENT.new()._install_registration()

func _wait_line(entry: String, line: String) -> bool:
	var deadline := Time.get_ticks_msec() + 20000
	while true:
		var checkpoint: Dictionary = bridge.capture_reading_checkpoint(false)
		if checkpoint.get("ok", false) and checkpoint.value.entry_id == entry \
				and bridge._runtime_adapter.current_line_id() == line and bridge._runtime_adapter.is_current_line_complete(): return true
		if Time.get_ticks_msec() >= deadline:
			return _ok({"ok": false, "code": "TEST.line_timeout", "entry": entry, "line": line, "checkpoint": checkpoint})
		await get_tree().process_frame
	return false

func _save_slot(slot: int) -> bool:
	await _click(_controls(get_tree().current_scene, "Save"))
	var sheet: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(sheet.can_save_backup(), str(sheet.last_result))
	if not sheet.can_save_backup(): return false
	var prepared: Dictionary = sheet._backup_port.prepare_action("save", "slot:%d" % slot)
	if not _ok(prepared): return false
	if not _ok(await sheet._backup_port.commit_action(prepared.value.token)): return false
	sheet.surface.leave_host()
	for frame: int in 5: await get_tree().process_frame
	return true

func _check_contact_state(snapshot: Dictionary) -> void:
	var schema := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
	assert_true(schema.validate(snapshot).get("ok", false), "saved Contacts current state is valid")
	for key: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_false(snapshot.has(key), "player snapshot omits " + key)
	for field: String in ["target_id", "contact_event_id", "parent_entry"]:
		var changed: Dictionary = snapshot.duplicate(true)
		if field == "parent_entry": changed.scene.return_to.parent.entry_id = "TEST.unregistered"
		else: changed.scene.return_to[field] = "TEST.unregistered"
		assert_false(schema.validate(changed).get("ok", false), "return frame refuses unregistered " + field)

func create_contacts_scene() -> void:
	if not await _start_playable(): return
	var host: Control = get_tree().current_scene
	await _click(_controls(host, "CheckComputer"))
	assert_true(host.is_computer_open())
	if not host.is_computer_open(): return
	var panel: Control = host.get_challenge_mount().get_node("SceneChallengePanel")
	assert_true(panel.worksheet.grid.focus_cell(323))
	await _click(panel.worksheet.grid.cell_nodes[323])
	var record: Dictionary = game.capture_dating_challenge_state().value
	assert_eq(record.state, "in_progress")
	if record.state != "in_progress": return
	# TEST solver knowledge selects a mine; the action is real player cell input.
	var mine: int = record.board.mine_indices[0]
	assert_true(panel.worksheet.grid.focus_cell(mine))
	await _click(panel.worksheet.grid.cell_nodes[mine])
	if not await _wait_line("scene.test.b", "line.scene.test.b.two"): return
	await _click(_caption().caption_text)
	if not await _wait_line("scene.test.a", "line.scene.test.a.one"): return
	var parent: Dictionary = game.capture_run_snapshot_input()
	assert_eq(parent.gameplay.route_context.active_dating_challenge.state, "lost")
	await _screenshot("contacts-parent-before")
	var issued: Dictionary = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
	if not _ok(issued): return
	if not _ok(game.emit_scene_contact_message("TEST.message", issued.value.token, issued.value.issuer_receipt)): return
	var seeded: Dictionary = game.contacts.duplicate(true)
	if not _ok(game.emit_scene_contact_message("TEST.message", issued.value.token, issued.value.issuer_receipt)): return
	assert_eq(game.contacts, seeded, "same command retry creates no duplicate message")
	assert_false(game.resolve_scene_contact_facts(["TEST.fact.read"]).ok)
	await _click(_controls(host, "CheckComputer"))
	assert_true(host.is_computer_open())
	await _click(_controls(host, "Apps"))
	var shell: Control = host.get_computer_mount().get_node_or_null("SceneComputerDesktop")
	assert_not_null(shell, "Apps opens the current computer desktop")
	if shell == null: return
	assert_true(shell.is_visible_in_tree())
	var launcher: Button = shell.launcher_buttons[&"contacts"]
	assert_true(launcher.is_visible_in_tree())
	assert_false(launcher.disabled)
	if not launcher.is_visible_in_tree() or launcher.disabled: return
	await _click(launcher)
	assert_eq(shell._active_id, &"contacts")
	var app: Control = shell._cached_app_windows.get(&"contacts")
	assert_not_null(app)
	if app == null: return
	assert_true(app.is_visible_in_tree())
	var row_index: int = app.contacts_panel.FRIENDS.find("lavinia")
	assert_true(app.contacts_panel.rows[row_index].unread)
	await _click(app.contacts_panel.rows[row_index])
	assert_eq(app.contacts_panel.selected_friend, "lavinia")
	assert_false(app.contacts_panel.rows[row_index].unread)
	if not _ok(game.resolve_scene_contact_facts(["TEST.fact.read"])): return
	var projection: Dictionary = app._presentation_port.get_projection("lavinia")
	assert_eq(projection.value.entries[0].texts.en, "TEST incoming.")
	assert_eq(game.capture_run_snapshot_input().scene, parent.scene, "reading while Computer is held establishes eligibility without entering Contacts")
	var read_contacts: Dictionary = game.contacts.duplicate(true)
	await _click(app.contacts_panel.rows[row_index])
	assert_eq(game.contacts, read_contacts, "opening already read correspondence creates no new receipt")
	await _screenshot("contacts-message-read")
	await _click(_controls(host, "CheckComputer"))
	assert_false(host.is_computer_open())
	assert_eq(game.capture_run_snapshot_input().scene, parent.scene)
	await _click(_caption().caption_text)
	if not await _wait_line("contact.test.a", "line.contact.test.a.one"): return
	var child: Dictionary = game.capture_run_snapshot_input()
	assert_eq(child.scene.entry_id, "contact.test.a")
	assert_eq(child.scene.return_to.parent.active_occurrence_id, parent.scene.active_occurrence_id)
	assert_eq(child.scene.return_to.parent.entry_id, parent.scene.entry_id)
	assert_ne(child.scene.active_occurrence_id, parent.scene.active_occurrence_id)
	assert_eq(child.gameplay.route_context, parent.gameplay.route_context)
	assert_eq(child.contacts, read_contacts)
	await _screenshot("contacts-child-before-save")
	if not await _save_slot(1): return
	var saved: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(saved): return
	_check_contact_state(saved.value.current_snapshot.snapshot)
	var proof := {"process_id": OS.get_process_id(), "parent_scene": parent.scene,
		"child_scene": child.scene, "contacts": read_contacts,
		"board": child.gameplay.route_context.active_dating_challenge.board,
		"checkpoint": saved.value.current_snapshot.snapshot.narrative_checkpoint,
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json")}
	assert_eq(str(proof.slot_sha256).length(), 64)
	if not _write_json("user://contacts-proof.json", proof): return
	_write_json("res://.godot/ci/contacts-connected-create-proof.json", proof)

func load_contacts_scene() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://contacts-proof.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.process_id)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	if not _start_services(): return
	var backup: RefCounted = preload("res://scripts/application/backup/BackupPresentationPort.gd").new()
	if not _ok(backup.configure(saves, "title")): return
	var prepared: Dictionary = backup.prepare_action("load", "slot:1")
	if not _ok(prepared): return
	var loaded: Dictionary = backup.commit_action(prepared.value.token)
	assert_eq(loaded.get("code"), &"scene_activation_pending", str(loaded))
	if loaded.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("contact.test.a", "line.contact.test.a.one"): return
	assert_eq(game.capture_run_snapshot_input().scene, proof.child_scene)
	assert_eq(game.contacts, proof.contacts)
	assert_eq(game.capture_dating_challenge_state().value.state, "lost")
	assert_eq(game.capture_dating_challenge_state().value.phase, "terminal")
	assert_eq(game.capture_dating_challenge_state().value.board, proof.board)
	var expected_reading: Dictionary = preload("res://scripts/narrative/SoloReadingSession.gd").expand_player_checkpoint(proof.checkpoint)
	if not _ok(expected_reading): return
	assert_eq(bridge.capture_reading_checkpoint(false).value, expected_reading.value,
		"fresh Load restores full current Contacts caption from compact position")
	assert_true(game.capture_run_snapshot_input().command_receipts.is_empty(), "Load restores no Scene command history")
	await _screenshot("contacts-child-fresh-load")
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var return_results: Array[Dictionary] = []
	var observe_return := func(_frontier: Dictionary, result: Dictionary) -> void:
		return_results.append(result.duplicate(true))
	bridge.next_request_finished.connect(observe_return)
	await _click(_caption().caption_text)
	var returned_to_parent: bool = await _wait_line("scene.test.a", "line.scene.test.a.two")
	bridge.next_request_finished.disconnect(observe_return)
	assert_false(return_results.is_empty(), "caption input issues the Contacts return command")
	for result: Dictionary in return_results:
		assert_true(result.get("ok", false), "Contacts return result: " + str(result))
	if not returned_to_parent: return
	var returned: Dictionary = game.capture_run_snapshot_input()
	assert_eq(returned.scene, proof.parent_scene, "return restores the saved parent Scene directly")
	assert_eq(returned.contacts, proof.contacts)
	assert_eq(game.capture_dating_challenge_state().value.state, "lost")
	assert_eq(game.capture_dating_challenge_state().value.phase, "terminal")
	assert_eq(game.capture_dating_challenge_state().value.board, proof.board)
	assert_null(returned.scene.return_to, "return consumes the single parent frame")
	var ledger: Dictionary = bridge.capture_reading_checkpoint(false).value.reading_session.ledger
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.a.two")
	assert_true(bridge._runtime_adapter.is_current_line_complete(), "returned caption is fully visible")
	# The newly rendered resume caption adds exactly its ordinary Profile witness.
	var profile_after: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var expected_visits: Array = profile_before.visited_line_ids.duplicate()
	expected_visits.append("line.scene.test.a.two")
	assert_eq(profile_after.visited_line_ids, expected_visits)
	var new_witnesses: Dictionary = profile_after.witnessed_caption_variants.duplicate(true)
	for witness_id: String in profile_before.witnessed_caption_variants:
		assert_eq(new_witnesses.get(witness_id), profile_before.witnessed_caption_variants[witness_id])
		new_witnesses.erase(witness_id)
	assert_eq(new_witnesses.size(), 1)
	if new_witnesses.size() == 1: assert_eq(new_witnesses.values()[0], ledger.captions[-1].beat)
	for field: String in ["visited_line_ids", "witnessed_caption_variants"]:
		profile_before.erase(field)
		profile_after.erase(field)
	assert_eq(profile_after, profile_before, "return preserves every other Profile field")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	await _screenshot("contacts-parent-return")
	if not await _save_slot(2): return
	assert_null(game.capture_run_snapshot_input().scene.return_to)
	assert_eq(game.capture_run_snapshot_input().scene, proof.parent_scene)
	assert_eq(game.contacts, proof.contacts)
	assert_eq(ready_count, 1)
	proof["loader_process_id"] = OS.get_process_id()
	proof["returned_scene"] = returned.scene
	proof["second_save_sha256"] = FileAccess.get_sha256("user://saves/slot_2.json")
	_write_json("res://.godot/ci/contacts-connected-load-proof.json", proof)
