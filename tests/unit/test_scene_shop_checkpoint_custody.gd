extends "res://addons/gut/test.gd"

# Adapter custody tests with an injected checkpoint seam, not disk/restart or
# complete Run9 receipt-validation evidence. GameState owns the causal lease.
const PORT := preload("res://scripts/application/narrative/SaveManagerNarrativeCheckpointPort.gd")
const JSON_WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const SESSION := preload("res://scripts/narrative/SoloReadingSession.gd")
const MANIFEST := preload("res://scripts/narrative/DialogicEntryManifest.gd")
const FROZEN := preload("res://scripts/narrative/FrozenPresentationContext.gd")

class CheckpointSeam extends "res://tests/support/FakeNarrativeCheckpointContext.gd":
	var current := {"checkpoint_id": "run:1", "checkpoint_sequence": 1}
	var prepared_object: Dictionary = {}
	var after_prepare := Callable()
	var before_capture := Callable()
	var committed_same_object := false
	var uncertain_failure := false
	var bad_ack := false
	var readback_mismatch := false

	func capture() -> Dictionary:
		calls.append("capture")
		if before_capture.is_valid(): before_capture.call()
		return {"ok": true, "value": {"backup": {"current": {"snapshot": current.duplicate(true)}}}}

	func prepare(inputs: Dictionary, _kind: StringName, _write: Dictionary) -> Dictionary:
		calls.append("prepare")
		if not prepare_ok: return {"ok": false, "code": &"prepare_failed"}
		var snapshot: Dictionary = inputs.snapshot_input.duplicate(true)
		for key: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
			snapshot.erase(key)
		var player_board: Dictionary = BOARD_STATE.project_player_state(snapshot.desktop.board)
		if not player_board.ok: return player_board
		snapshot.desktop.board = player_board.value.snapshot
		var player_reading: Dictionary = SESSION.project_player_checkpoint(inputs.dialogic_checkpoint)
		if not player_reading.ok: return player_reading
		snapshot.merge({"schema_version": 9, "route_id": "scene", "checkpoint_id": "run:2", "checkpoint_sequence": 2,
			"narrative_checkpoint": player_reading.value})
		prepared_object = {"checkpoint_id": "run:2", "journal_candidate": {"current": {"snapshot": snapshot}},
			"autosave_document": {"schema_version": 9, "current_snapshot": {"snapshot": snapshot.duplicate(true)}},
			"storage_backup": {"original": true}}
		if after_prepare.is_valid(): after_prepare.call()
		return {"ok": true, "value": {"candidate": prepared_object}}

	func commit(candidate: Dictionary) -> Dictionary:
		calls.append("commit")
		committed_same_object = is_same(candidate, prepared_object)
		if uncertain_failure: return {"ok": false, "code": &"APPLICATION_FATAL", "committed": true}
		if not commit_ok: return {"ok": false, "code": &"write_failed"}
		current = candidate.journal_candidate.current.snapshot.duplicate(true)
		if readback_mismatch: current["unexpected"] = true
		return {"ok": true, "value": {"checkpoint_id": "wrong" if bad_ack else candidate.checkpoint_id}}

class Authority extends RefCounted:
	var denied_phase := ""
	var phases: Array[String] = []
	var callback := Callable()
	func validate(_input: Dictionary, _checkpoint: Dictionary, phase: String) -> bool:
		phases.append(phase)
		if callback.is_valid(): callback.call(phase)
		return phase != denied_phase
	func entry_validate(_capability: String, _binding: Dictionary, _checkpoint: Dictionary, _phase: String) -> Dictionary:
		return {"ok": true}

func _fixture() -> Dictionary:
	var real := CheckpointSeam.new()
	real.route_id_value = "scene"
	real.active_app_id_value = "shop"
	var owner := Authority.new()
	var port := PORT.new()
	assert_true(port.configure(real, real.provider_callables()).ok)
	assert_true(port.configure_scene_entry_authority(owner, owner.entry_validate).ok)
	assert_true(port.configure_scene_contact_authority(owner, owner.validate).ok)
	assert_true(port.configure_scene_shop_authority(owner, owner.validate).ok)
	var session := SESSION.new()
	assert_true(session.configure_scene().ok)
	assert_true(session.begin_scene("shop-test:session").ok)
	var registered: Dictionary = MANIFEST.scene_registration().value
	var entry: String = registered.scene_programme.entries[0].entry_id
	var occurrence := "occurrence:1"
	var presentation: Dictionary = FROZEN.build(entry, {"entry_id": entry, "entry_role": "scene",
		"occurrence_id": occurrence, "admission_receipt_id": occurrence})
	assert_true(presentation.ok)
	var frame := {"expected_stage": "scene", "playback_id": occurrence, "role": "scene",
		"transaction_id": occurrence, "presentation": presentation.value}
	assert_true(session.admit_scene(entry, frame).ok)
	var programme: Dictionary = session.entry_program(entry, frame).value
	var allocation: Dictionary = session.ledger.allocate_publication(session.command_id, entry, occurrence)
	assert_true(allocation.ok)
	var line_id: String = programme.lines[0].line_id
	assert_true(session.ledger.publish_line(session.command_id, allocation.value, entry, line_id, occurrence).ok)
	var captured: Dictionary = session.capture({"line_id": line_id, "publication_id": allocation.value})
	assert_true(captured.ok)
	var checkpoint := {"stage": "scene", "manifest_fingerprint": session.fingerprint,
		"entry_id": entry, "content_version": programme.content_version, "transaction_id": occurrence,
		"reading_session": captured.value, "frozen_context": frame}
	var board: Dictionary = BOARD_STATE.new().capture()
	board.erase("terminal_receipts")
	board["settled_inspection"] = false
	board["round_paid"] = false
	var input := {"lifecycle": {}, "gameplay": {"money": 5}, "contacts": {}, "desktop": {"board": board, "consequence": {}},
		"scene": {"registration_sha256": session.fingerprint, "active_occurrence_id": occurrence,
			"entry_id": entry, "notification": {}, "active_challenge": {}, "return_to": null},
		"command_receipts": {}, "applied_effect_transaction_ids": {}, "applied_variable_transaction_ids": {}}
	real.current["narrative_checkpoint"] = SESSION.project_player_checkpoint(checkpoint).value
	return {"real": real, "owner": owner, "port": port, "input": input, "checkpoint": checkpoint}

func _commit(f: Dictionary, kind: String = "shop") -> Dictionary:
	return f.port.commit_scene_shop(f.input, f.checkpoint) if kind == "shop" else f.port.commit_scene_contact(f.input, f.checkpoint)

func test_shop_and_contact_keep_one_lower_commit_and_three_owner_phases() -> void:
	for kind: String in ["contact", "shop"]:
		var f := _fixture()
		var result := _commit(f, kind)
		assert_true(result.ok, str(result))
		assert_eq(f.owner.phases, ["before_prepare", "before_commit", "after_commit"])
		assert_eq(f.real.calls.count("prepare"), 1)
		assert_eq(f.real.calls.count("commit"), 1)
		assert_true(f.real.committed_same_object)
		assert_true(f.input.desktop.board.has("command_receipts"), "live input keeps its retry state")
		assert_false(f.real.current.desktop.board.has("command_receipts"), "lower seam produces player facts")
		for key: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
			assert_true(f.input.has(key), "live custody retains retry cache: %s" % key)
			assert_false(f.real.current.has(key), "player save excludes retry cache: %s" % key)
		assert_eq(f.real.current.scene, f.input.scene, "player save retains exact current Scene state")
		assert_eq(f.real.current.narrative_checkpoint, SESSION.project_player_checkpoint(f.checkpoint).value)
		assert_false(f.real.current.narrative_checkpoint.reading_session.has("ledger"))
		assert_true(f.checkpoint.reading_session.has("ledger"), "live custody retains complete reading state")
		assert_eq(result.value.checkpoint_reference.snapshot_sha256, str(JSON_WRITER.stringify(f.real.current).value).sha256_text())

func test_shop_requires_bound_owner_and_refuses_authority_replacement() -> void:
	var f := _fixture()
	var other := Authority.new()
	assert_true(f.port.configure_scene_shop_authority(f.owner, f.owner.validate).ok)
	assert_false(f.port.configure_scene_shop_authority(other, other.validate).ok)
	assert_false(f.port.configure_scene_shop_authority(f.owner, other.validate).ok)
	assert_false(PORT.new().configure_scene_shop_authority(f.owner, f.owner.validate).ok)
	var unbound := PORT.new()
	assert_true(unbound.configure(f.real, f.real.provider_callables()).ok)
	assert_true(unbound.configure_scene_entry_authority(f.owner, f.owner.entry_validate).ok)
	assert_false(unbound.commit_scene_shop(f.input, f.checkpoint).ok)
	assert_false(f.real.calls.has("prepare"))

func test_shop_refuses_lease_loss_before_write_and_marks_postwrite_loss_uncertain() -> void:
	for phase: String in ["before_prepare", "before_commit", "after_commit"]:
		var f := _fixture()
		f.owner.denied_phase = phase
		var result := _commit(f)
		assert_false(result.ok, phase)
		assert_eq(result.get("committed", false), phase == "after_commit")
		assert_eq(f.real.calls.has("commit"), phase == "after_commit")
		assert_false(f.real.calls.has("rollback"))

func test_shop_detects_source_replacement_at_each_authority_phase() -> void:
	for phase: String in ["before_prepare", "before_commit", "after_commit"]:
		var f := _fixture()
		f.owner.callback = func(current_phase: String) -> void:
			if current_phase == phase: f.real.current["displaced"] = true
		var result := _commit(f)
		assert_false(result.ok, phase)
		assert_eq(result.get("committed", false), phase == "after_commit")
		assert_eq(f.real.calls.has("commit"), phase == "after_commit")
		assert_false(f.real.calls.has("rollback"))
		f.owner.callback = Callable()

func test_shop_detaches_public_inputs_before_owner_callback() -> void:
	var f := _fixture()
	var expected_input: Dictionary = f.input.duplicate(true)
	var expected_checkpoint: Dictionary = f.checkpoint.duplicate(true)
	f.owner.callback = func(_phase: String) -> void:
		f.input.gameplay.money = -30
		f.checkpoint.reading_session.boundary = "changed"
	var result := _commit(f)
	assert_true(result.ok, str(result))
	assert_eq(f.real.current.gameplay, expected_input.gameplay)
	assert_eq(f.real.current.narrative_checkpoint, SESSION.project_player_checkpoint(expected_checkpoint).value)
	f.owner.callback = Callable()

func test_shop_refuses_candidate_mutation_from_final_authority_or_source_callback() -> void:
	for source_callback: bool in [false, true]:
		var f := _fixture()
		var mutate := func() -> void:
			if f.real.prepared_object.is_empty(): return
			f.real.prepared_object.journal_candidate.current.snapshot.gameplay.money = 100
			f.real.prepared_object.autosave_document.current_snapshot.snapshot.gameplay.money = 100
		if source_callback: f.real.before_capture = mutate
		else:
			f.owner.callback = func(phase: String) -> void:
				if phase == "before_commit": mutate.call()
		var result := _commit(f)
		assert_false(result.ok)
		assert_false(result.get("committed", false))
		assert_false(f.real.calls.has("commit"))
		f.owner.callback = Callable()
		f.real.before_capture = Callable()

func test_shop_prepare_and_write_refusals_preserve_rollback_classification() -> void:
	for failure: String in ["prepare", "write", "rollback"]:
		var f := _fixture()
		f.real.prepare_ok = failure != "prepare"
		f.real.commit_ok = false
		f.real.rollback_ok = failure != "rollback"
		var result := _commit(f)
		assert_false(result.ok)
		assert_eq(result.get("committed", false), failure == "rollback")
		assert_eq(result.get("rolled_back", false), failure == "write")
		assert_eq(f.real.calls.has("rollback"), failure != "prepare")

func test_shop_bad_durable_ack_or_readback_never_becomes_retryable_refusal() -> void:
	for mode: String in ["bad_ack", "readback_mismatch"]:
		var f := _fixture()
		f.real.set(mode, true)
		var result := _commit(f)
		assert_false(result.ok)
		assert_true(result.committed)
		assert_false(f.real.calls.has("rollback"))

func test_shop_reentrant_publication_and_configuration_are_excluded() -> void:
	var f := _fixture()
	var results: Array = []
	f.owner.callback = func(_phase: String) -> void:
		results.append(f.port.commit_scene_shop(f.input, f.checkpoint))
		results.append(f.port.commit_scene_contact(f.input, f.checkpoint))
		results.append(f.port.commit_scene_challenge(f.input, f.checkpoint))
		results.append(f.port.commit_scene_event(f.input, f.checkpoint))
		results.append(f.port.configure(f.real, f.real.provider_callables()))
		results.append(f.port.configure_scene_shop_authority(f.owner, f.owner.validate))
		results.append(f.port.commit(&"game_state_narrative_transaction", {}))
		results.append(f.port.rollback(&"game_state_narrative_transaction", {}))
	var result := _commit(f)
	assert_true(result.ok, str(result))
	assert_eq(results.size(), 24)
	for refused: Dictionary in results: assert_false(refused.ok)
	assert_eq(f.real.calls.count("commit"), 1)
	f.owner.callback = Callable()

func test_shop_cannot_change_the_saved_reading_boundary() -> void:
	var f := _fixture()
	f.checkpoint.reading_session.boundary = "control"
	var result := _commit(f)
	assert_false(result.ok)
	assert_false(result.committed)
	assert_eq(str(result.code), "scene_shop_source_changed")
	assert_false(f.real.calls.has("prepare"))

func test_shop_explicit_committed_failure_is_not_rolled_back_as_fresh_refusal() -> void:
	var f := _fixture()
	f.real.uncertain_failure = true
	var result := _commit(f)
	assert_false(result.ok)
	assert_true(result.committed)
	assert_eq(str(result.code), "APPLICATION_FATAL")
	assert_false(f.real.calls.has("rollback"))
