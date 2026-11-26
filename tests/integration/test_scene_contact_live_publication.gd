extends "res://tests/integration/scene_contacts_connected_child.gd"
func test_message_and_read_publish_once_without_autosave() -> void:
	if not _start_services(): return
	var audio: Node = get_node("/root/AudioManager")
	var started: Dictionary = saves.start_scene_new_run("target_a", {
		"route_id": "scene", "content_version": 1, "audio_context": audio.get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.a", "line.scene.test.a.one"): return
	var storage: RefCounted = saves._storage
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(reading): return
	assert_false(storage.exists("autosave.json"))
	for kind: String in ["message", "read"]:
		var issued: Dictionary = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
		if not _ok(issued): break
		var command: Callable = game.emit_scene_contact_message.bind("TEST.message", issued.value.token, issued.value.issuer_receipt) \
			if kind == "message" else game.open_contact.bind("lavinia", issued.value.token, issued.value.issuer_receipt)
		if not _ok(command.call()): return
		var committed: Dictionary = game.contacts.duplicate(true)
		assert_eq(committed.transaction_receipts.size(), 1 if kind == "message" else 2)
		assert_true(committed.transaction_receipts.has(issued.value.token))
		if not _ok(game.resolve_scene_contact_facts(["TEST.fact.message" if kind == "message" else "TEST.fact.read"])): break
		if not _ok(command.call()): return
		assert_eq(game.contacts, committed, "exact duplicate has no new effect")
		assert_eq(bridge.capture_reading_checkpoint(false), reading)
		assert_false(storage.exists("autosave.json"), kind)
	assert_eq(game.contacts.transaction_receipts.size(), 2)
