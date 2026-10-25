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

func test_shop_checkpoint_retry_custody_and_uncertain_commit() -> void:
	if not _start_services(): return
	var started: Dictionary = saves.start_scene_new_run("target_a", {"route_id": "scene",
		"content_version": 1, "audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if started.get("code") != &"scene_activation_pending" or not await _await_ready(): return
	if not await _wait_line("scene.test.a", "line.scene.test.a.one"): return
	# Economy fixture through the existing owner, not invented completion/claim
	# receipts. The first accepted purchase checkpoints this funding as well.
	game.change_money(200)
	var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var reading: Dictionary = bridge.capture_reading_checkpoint(false)
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var command: Callable = _shop_command("soft_blanket")
	if not command.is_valid(): return
	var actual_port: Object = game._narrative_checkpoint_port
	var probe := CustodyFault.new()
	probe.port = actual_port
	game._narrative_checkpoint_port = probe
	for phase: String in ["before_prepare", "before_commit"]:
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
	var disk: Dictionary = storage.read_text("autosave.json")
	fault.refuse_on = 1
	var refused: Dictionary = command.call()
	assert_false(refused.get("ok", false))
	assert_eq(refused.get("code"), &"write_not_committed")
	assert_false(refused.get("committed", false))
	assert_true(refused.get("rolled_back", false))
	assert_eq(fault.refused, 1, "physical autosave write reached")
	assert_eq(game.capture_run_snapshot_input(), before)
	assert_eq(storage.read_text("autosave.json"), disk)
	assert_eq(profile.get_profile_snapshot(), profile_before)
	var accepted: Dictionary = command.call()
	if not _ok(accepted):
		storage._file_ops = original_files
		return
	var after: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var catalogue: Variant = preload("res://scripts/data/DataCatalog.gd").new()
	assert_eq(after.gameplay.money, before.gameplay.money - catalogue.get_shop_item("soft_blanket").price)
	assert_eq(after.gameplay.stats.pressure, maxi(0, before.gameplay.stats.pressure - 2))
	assert_eq(after.command_receipts.size(), before.command_receipts.size() + 1)
	assert_eq(after.scene, before.scene, "purchase never advances authored frontier")
	assert_eq(after.contacts, before.contacts)
	assert_eq(after.desktop, before.desktop)
	assert_eq(bridge.capture_reading_checkpoint(false), reading)
	var writes: int = fault.autosave_writes
	var accepted_disk: Dictionary = storage.read_text("autosave.json")
	var persisted: Dictionary = JSON.parse_string(str(accepted_disk.value))
	assert_false(persisted.current_snapshot.snapshot.command_receipts.has(accepted.receipt.transaction_id),
		"player save retains purchase effects without the live retry receipt")
	assert_eq(persisted.current_snapshot.snapshot.gameplay, after.gameplay)
	assert_true(after.command_receipts.has(accepted.receipt.transaction_id), "live duplicate still has its acknowledgement")
	var invalid_input: Dictionary = after.duplicate(true)
	invalid_input.command_receipts[accepted.receipt.transaction_id].request_fingerprint = "invalid"
	var invalid_build: Dictionary = preload("res://scripts/domain/run/RunSnapshotSchema.gd").build_scene(
		invalid_input, reading.value, "scene", null, {}, 1, 99)
	assert_false(invalid_build.get("ok", false), "projection cannot hide malformed live purchase receipts")
	assert_eq(game.capture_run_snapshot_input(), after, "projection and rejected build do not mutate the live retry cache")
	if not _ok(command.call()):
		storage._file_ops = original_files
		return
	assert_eq(game.capture_run_snapshot_input(), after)
	assert_eq(fault.autosave_writes, writes, "duplicate does not write")
	assert_eq(storage.read_text("autosave.json"), accepted_disk)
	var receipt: Dictionary = accepted.receipt
	var context: Dictionary = game.capture_scene_shop_context()
	var conflict: Dictionary = game.commit_scene_shop_purchase("quiet_tea", 1, receipt.transaction_id,
		receipt.scene_shop_purchase.issuer_receipt, context.value)
	assert_false(conflict.get("ok", false))
	assert_eq(conflict.get("code"), &"scene_shop_command_conflict")
	var stale_issue: Dictionary = bootstrap._desktop_identity_nonce_issuer.issue(&"transaction_id")
	var stale_source: Dictionary = context.value.duplicate(true)
	stale_source.scene_occurrence = "TEST.other-occurrence"
	if _ok(stale_issue):
		assert_false(game.commit_scene_shop_purchase("quiet_tea", 1, stale_issue.value.token,
			stale_issue.value.issuer_receipt, stale_source).get("ok", false), "unaccepted request must match source occurrence")
	var supportz: Callable = _shop_command("supportz")
	if supportz.is_valid(): assert_false(supportz.call().get("ok", false), "no fabricated base completions")
	assert_eq(game.capture_run_snapshot_input(), after)
	assert_eq(fault.autosave_writes, writes)
	storage._file_ops = original_files
	# Last fault: real durable write succeeds, then custody is lost. The owner
	# must latch recovery instead of publishing or allowing a fresh debit.
	var uncertain_command: Callable = _shop_command("quiet_tea")
	if not uncertain_command.is_valid(): return
	probe.phase = "after_commit"
	probe.revoke_lease = false
	game._narrative_checkpoint_port = probe
	var uncertain: Dictionary = uncertain_command.call()
	game._narrative_checkpoint_port = actual_port
	assert_false(uncertain.get("ok", false))
	assert_true(uncertain.get("committed", false), str(uncertain))
	assert_eq(game.capture_run_snapshot_input(), after, "no publication after uncertain durable commit")
	assert_ne(storage.read_text("autosave.json"), accepted_disk, "candidate was physically committed")
	var stable: Dictionary = saves.get_latest_stable_checkpoint()
	if _ok(stable):
		var durable: Dictionary = stable.value.bundle.snapshot
		assert_eq(durable.gameplay.money, after.gameplay.money - catalogue.get_shop_item("quiet_tea").price)
		assert_eq(durable.gameplay.inventory.get("quiet_tea", 0), after.gameplay.inventory.get("quiet_tea", 0) + 1)
		assert_eq(durable.command_receipts, preload("res://scripts/domain/run/RunSnapshotSchema.gd").project_player_command_receipts(after.command_receipts),
			"uncertain durable purchase retains effects without either live purchase receipt")
	assert_false(game._mutation_gate.guard_external(&"scene_shop").get("ok", false), "fatal latch blocks another debit")
	_write_json("res://.godot/ci/scene-shop-transaction-proof.json", {"custody_faults": probe.hits,
		"physical_refusals": fault.refused, "accepted_receipt": receipt,
		"uncertain_committed": uncertain.get("committed", false), "process_id": OS.get_process_id()})
