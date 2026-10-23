extends "res://tests/integration/scene_contacts_connected_child.gd"
## Focused negative seam check, separate from the accepted rendered journey.
## FINAL owners and physical files; only the actual autosave.next write is refused.

func test_message_and_read_refusal_preserve_state_and_allow_exact_retry() -> void:
	if not _start_services(): return
	var audio: Node = get_node("/root/AudioManager")
	var started: Dictionary = saves.start_scene_new_run("target_a", {
		"route_id": "scene", "content_version": 1, "audio_context": audio.get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.a", "line.scene.test.a.one"): return
	var storage: RefCounted = saves._storage
	var original_files: RefCounted = storage._file_ops
	var fault := CONTENT.WriteRefusal.new()
	storage._file_ops = fault
	for kind: String in ["message", "read"]:
		var issued: Dictionary = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
		if not _ok(issued): break
		var command: Callable = game.emit_scene_contact_message.bind("TEST.message", issued.value.token, issued.value.issuer_receipt) \
			if kind == "message" else game.open_contact.bind("lavinia", issued.value.token, issued.value.issuer_receipt)
		var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
		var reading: Dictionary = bridge.capture_reading_checkpoint(false)
		var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
		var disk: Dictionary = storage.read_text("autosave.json")
		if not _ok(disk) or not _ok(reading): break
		var attempts: int = fault.autosave_writes
		var refusals: int = fault.refused
		fault.refuse_on = attempts + 1
		var refused: Dictionary = command.call()
		assert_false(refused.get("ok", false), kind)
		assert_eq(refused.get("code"), &"write_not_committed", kind)
		assert_false(refused.get("committed", false), kind)
		assert_true(refused.get("rolled_back", false), kind)
		assert_eq(fault.refused, refusals + 1, "fault reached physical " + kind + " write")
		assert_eq(fault.autosave_writes, attempts + 2, "refused write and real rollback")
		assert_eq(game.capture_run_snapshot_input(), before, "no live adoption after refused " + kind)
		assert_eq(bridge.capture_reading_checkpoint(false), reading)
		assert_eq(profile.get_profile_snapshot(), profile_before)
		assert_eq(storage.read_text("autosave.json"), disk, "physical autosave restored byte-for-byte")
		assert_false(game.resolve_scene_contact_facts(["TEST.fact.message" if kind == "message" else "TEST.fact.read"]).ok)
		if refused.get("ok", false) or fault.refused != refusals + 1: break
		if not _ok(command.call()): break
		assert_eq(fault.autosave_writes, attempts + 3, "same-command retry writes once")
		var committed: Dictionary = game.contacts.duplicate(true)
		assert_eq(committed.transaction_receipts.size(), 1 if kind == "message" else 2)
		assert_true(committed.transaction_receipts.has(issued.value.token))
		if not _ok(game.resolve_scene_contact_facts(["TEST.fact.message" if kind == "message" else "TEST.fact.read"])): break
		var saved: Dictionary = storage.read_text("autosave.json")
		if not _ok(command.call()): break
		assert_eq(game.contacts, committed, "exact duplicate has no new effect")
		assert_eq(fault.autosave_writes, attempts + 3, "duplicate does not write")
		assert_eq(storage.read_text("autosave.json"), saved)
	storage._file_ops = original_files
	assert_eq(fault.refused, 2, "both message and read refusal branches exercised")
	assert_eq(game.contacts.transaction_receipts.size(), 2)
	_write_json("res://.godot/ci/contacts-refusal-proof.json", {
		"refusals": fault.refused, "autosave_writes": fault.autosave_writes,
		"contact_receipts": game.contacts.transaction_receipts.size(), "process_id": OS.get_process_id()})
