extends "res://tests/integration/scene_contacts_connected_child.gd"
## Real FINAL owners, issuer, schema and physical saves. Run this file in its own
## test_manual process with DWM_TEST_ROOT, like contacts_checkpoint_refusal.

class CustodyFault extends RefCounted:
	var port: Object
	var game_owner: Object
	var phase := ""
	var revoke_lease := false
	var hits := 0
	var validator: Callable
	func configure_scene_shop_authority(owner: Object, callback: Callable) -> Dictionary:
		game_owner = owner
		validator = callback
		return port.configure_scene_shop_authority(owner, callback)
	func commit_scene_shop(input: Dictionary, checkpoint: Dictionary) -> Dictionary:
		# Fault only the validator's supplied detached input, never the candidate
		# retained by either owner. Real checkpoint phases still execute normally.
		port.set("_scene_shop_validator", _validate)
		var result: Dictionary = port.commit_scene_shop(input, checkpoint)
		port.set("_scene_shop_validator", validator)
		return result
	func _validate(input: Dictionary, checkpoint: Dictionary, at_phase: String) -> bool:
		if at_phase == phase:
			hits += 1
			if revoke_lease:
				game_owner._mutation_gate.release(&"causal_transaction", game_owner._scene_shop_operation.lease)
			else:
				input.gameplay.money -= 1
		return validator.call(input, checkpoint, at_phase)

func _shop_command(item: String) -> Callable:
	var issued: Dictionary = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
	var source: Dictionary = game.capture_scene_shop_context()
	if not _ok(issued) or not _ok(source): return Callable()
	return game.commit_scene_shop_purchase.bind(item, 1, issued.value.token,
		issued.value.issuer_receipt, source.value)

func test_shop_live_purchase_custody_duplicate_and_manual_save() -> void:
	if not _start_services(): return
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.a", "line.scene.test.a.one"): return
	# Economy fixture through the existing owner, not invented completion/claim
	# receipts. Manual Save later persists the funding and purchase together.
	game.change_money(200)
	var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var command: Callable = _shop_command("crystal_stutters")
	if not command.is_valid(): return
	var actual_port: Object = game._narrative_checkpoint_port
	var probe := CustodyFault.new()
	probe.port = actual_port
	game._narrative_checkpoint_port = probe
	for phase: String in ["before_prepare", "after_commit"]:
		probe.phase = phase
		var prior_hits: int = probe.hits
		var refused: Dictionary = command.call()
		assert_false(refused.get("ok", false), phase)
		assert_false(refused.get("committed", false), phase)
		assert_eq(probe.hits, prior_hits + 1, "actual custody phase reached")
		assert_eq(game.capture_run_snapshot_input(), before)
		assert_eq(bridge.capture_reading_checkpoint(false), reading)
	probe.phase = "before_prepare"
	probe.revoke_lease = true
	var revoked: Dictionary = command.call()
	assert_false(revoked.get("ok", false), "revoked causal lease refuses purchase")
	assert_eq(game.capture_run_snapshot_input(), before)
	game._narrative_checkpoint_port = actual_port
	var storage: RefCounted = saves._storage
	var original_files: RefCounted = storage._file_ops
	var fault := CONTENT.WriteRefusal.new()
	storage._file_ops = fault
	assert_false(storage.exists("autosave.json"), "first purchase starts with no initial Autosave")
	fault.refuse_on = 1
	var lower: Object = actual_port._real_port
	var lower_trap := preload("res://tests/support/FakeNarrativeCheckpointContext.gd").new()
	lower_trap.prepare_ok = false
	lower_trap.commit_ok = false
	actual_port._real_port = lower_trap
	var accepted: Dictionary = command.call()
	if not _ok(accepted):
		storage._file_ops = original_files
		return
	var after: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var catalogue: Variant = preload("res://scripts/data/DataCatalog.gd").new()
	assert_eq(after.gameplay.money, before.gameplay.money - catalogue.get_shop_item("crystal_stutters").price)
	assert_eq(after.gameplay.stats, before.gameplay.stats)
	assert_eq(after.gameplay.inventory.get("crystal_stutters"), 1)
	assert_eq(after.gameplay.shop_purchase_counts, before.gameplay.shop_purchase_counts)
	assert_eq(after.command_receipts.size(), before.command_receipts.size() + 1)
	assert_eq(after.scene, before.scene, "purchase never advances authored frontier")
	assert_eq(after.contacts, before.contacts)
	assert_eq(after.desktop, before.desktop)
	assert_eq(bridge.capture_reading_checkpoint(false), reading)
	assert_true(lower_trap.calls.is_empty(), "purchase never captures or prepares storage")
	assert_eq(fault.autosave_writes, 0, "ordinary purchase performs no physical Autosave write")
	assert_eq(fault.refused, 0, "armed storage failure is never reached")
	assert_false(storage.exists("autosave.json"))
	assert_eq(profile.get_profile_snapshot(), profile_before)
	var writes: int = fault.autosave_writes
	var accepted_disk: Dictionary = storage.read_text("autosave.json")
	assert_true(after.command_receipts.has(accepted.receipt.transaction_id), "live duplicate still has its acknowledgement")
	var invalid_input: Dictionary = after.duplicate(true)
	invalid_input.scene.entry_id = "missing.entry"
	var invalid_build: Dictionary = preload("res://scripts/domain/run/RunSnapshotSchema.gd").build_scene(
		invalid_input, reading.value, "scene", null, {}, 1, 99)
	assert_false(invalid_build.get("ok", false), "required current position cannot be omitted with live retry records")
	assert_eq(game.capture_run_snapshot_input(), after, "projection and rejected build do not mutate the live retry cache")
	if not _ok(command.call()):
		storage._file_ops = original_files
		return
	assert_eq(game.capture_run_snapshot_input(), after)
	assert_eq(fault.autosave_writes, writes, "duplicate does not write")
	assert_eq(storage.read_text("autosave.json"), accepted_disk)
	var receipt: Dictionary = accepted.receipt
	var context: Dictionary = game.capture_scene_shop_context()
	var conflict: Dictionary = game.commit_scene_shop_purchase("inked_silk_string", 1, receipt.transaction_id,
		receipt.scene_shop_purchase.issuer_receipt, context.value)
	assert_false(conflict.get("ok", false))
	assert_eq(conflict.get("code"), &"scene_shop_command_conflict")
	var stale_issue: Dictionary = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
	var stale_source: Dictionary = context.value.duplicate(true)
	stale_source.scene_occurrence = "TEST.other-occurrence"
	if _ok(stale_issue):
		assert_false(game.commit_scene_shop_purchase("inked_silk_string", 1, stale_issue.value.token,
			stale_issue.value.issuer_receipt, stale_source).get("ok", false), "unaccepted request must match source occurrence")
	var supportz: Callable = _shop_command("supportz")
	if supportz.is_valid(): assert_false(supportz.call().get("ok", false), "no fabricated base completions")
	assert_eq(game.capture_run_snapshot_input(), after)
	assert_eq(fault.autosave_writes, writes)
	assert_true(lower_trap.calls.is_empty())
	actual_port._real_port = lower
	storage._file_ops = original_files
	# The exact live effects become durable only through an explicit manual Save.
	if not await _save_slot(1): return
	var parsed_disk: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(parsed_disk): return
	var persisted: Dictionary = parsed_disk.value.current_snapshot.snapshot
	assert_eq(persisted.gameplay, after.gameplay)
	assert_false(persisted.has("command_receipts"), "save omits the process-local duplicate cache")
	assert_false(storage.exists("autosave.json"), "manual Save does not create an Autosave")
	var slot_hash := FileAccess.get_sha256("user://saves/slot_1.json")
	# A live caption loads through its native Pause-owned Backup handoff.
	var load_button: Control = _controls(get_tree().current_scene, "Load")
	var deadline := Time.get_ticks_msec() + 10000
	await RenderingServer.frame_post_draw
	while not load_button._admitted() and Time.get_ticks_msec() < deadline:
		await RenderingServer.frame_post_draw
	assert_true(load_button._admitted(), "rendered Load rail admits a fresh press")
	if not load_button._admitted(): return
	await _click(load_button)
	var pause: Node = get_node("/root/SceneRouter")._production_pause
	assert_true(pause.can_load_backup(), str(pause.last_result))
	if not pause.can_load_backup(): return
	var prepared_load: Dictionary = pause._backup_port.prepare_action("load", "slot:1")
	if not _ok(prepared_load): return
	assert_true(prepared_load.value.confirmation_required)
	ready_count = 0
	var loaded: Dictionary = await pause._backup_port.commit_action(prepared_load.value.token)
	if not _ok(loaded) or not await _await_ready(): return
	assert_eq(ready_count, 1, "one Ready belongs to this Load")
	assert_false(pause.surface.visible)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), slot_hash)
	if not await _wait_line("scene.test.a", "line.scene.test.a.one"): return
	assert_eq(game.inventory.get("crystal_stutters"), 1, "manual Load retains cosmetic ownership")
	var second_purchase: Callable = _shop_command("crystal_stutters")
	if second_purchase.is_valid(): assert_false(second_purchase.call().get("ok", false), "Load does not re-enable owned cosmetic")
	# Retire the live run through the existing Logout confirmation before New Acc.
	var host: Control = get_tree().current_scene
	await _click(_controls(host, "CheckComputer"))
	assert_true(host.is_computer_open())
	if not host.is_computer_open(): return
	var desktop: Control = host.get_computer_mount().get_node_or_null("SceneComputerDesktop")
	assert_not_null(desktop)
	if desktop == null: return
	await _click(desktop.launcher_buttons[&"logout"])
	assert_true(pause.surface.confirmation.is_visible_in_tree())
	if not pause.surface.confirmation.is_visible_in_tree(): return
	await _click(pause.surface.return_button)
	for frame: int in 5: await get_tree().process_frame
	assert_false(game.capture_live_session().value.active)
	assert_eq(get_tree().current_scene.scene_file_path, "res://scenes/menu/MenuScene.tscn")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), slot_hash)
	assert_false(storage.exists("autosave.json"), "Logout does not invent an Autosave")
	ready_count = 0
	var fresh: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(fresh.get("code"), &"scene_activation_pending", str(fresh))
	if fresh.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	assert_eq(ready_count, 1, "one Ready belongs to the new run")
	assert_false(game.inventory.has("crystal_stutters"), "genuinely new run resets cosmetic ownership")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), slot_hash, "new run preserves the owned-cosmetic save")
	_write_json("res://.godot/ci/scene-shop-transaction-proof.json", {"custody_faults": probe.hits,
		"automatic_writes": fault.autosave_writes, "storage_preparations": lower_trap.calls.size(),
		"accepted_receipt": receipt, "process_id": OS.get_process_id()})
