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

func test_shop_and_contact_publish_live_state_without_touching_storage() -> void:
	for kind: String in ["contact", "shop"]:
		var f := _fixture()
		var disk_before: Dictionary = f.real.current.duplicate(true)
		var input_before: Dictionary = f.input.duplicate(true)
		var result := _commit(f, kind)
		assert_true(result.ok, str(result))
		assert_false(result.get("durable", true))
		assert_eq(f.owner.phases, ["before_prepare", "after_commit"])
		assert_true(f.real.calls.is_empty(), "no capture, preparation, write or readback")
		assert_eq(f.real.current, disk_before)
		assert_eq(f.input, input_before)
		assert_eq(result.value.publication, {"kind": "live", "state_sha256": str(JSON_WRITER.stringify(f.checkpoint).value).sha256_text()})

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
	assert_true(f.real.calls.is_empty())

func test_owner_loss_before_adoption_is_retryable_without_durable_commit() -> void:
	for phase: String in ["before_prepare", "after_commit"]:
		var f := _fixture()
		f.owner.denied_phase = phase
		var result := _commit(f)
		assert_false(result.ok, phase)
		assert_false(result.get("committed", false))
		assert_true(f.real.calls.is_empty())
		f.owner.denied_phase = ""
		assert_true(_commit(f).ok)
		assert_true(f.real.calls.is_empty())

func test_older_or_unavailable_disk_does_not_gate_live_purchase() -> void:
	var f := _fixture()
	f.real.current = {}
	f.real.prepare_ok = false
	f.real.commit_ok = false
	f.real.rollback_ok = false
	f.owner.callback = func(_phase: String) -> void: f.real.current["unrelated_save"] = true
	var result := _commit(f)
	assert_true(result.ok, str(result))
	assert_false(result.get("durable", true))
	assert_true(f.real.calls.is_empty())
	f.owner.callback = Callable()

func test_shop_detaches_public_inputs_before_owner_callback() -> void:
	var f := _fixture()
	var expected_checkpoint: Dictionary = f.checkpoint.duplicate(true)
	f.owner.callback = func(_phase: String) -> void:
		f.input.gameplay.money = -30
		f.checkpoint.reading_session.boundary = "changed"
	var result := _commit(f)
	assert_true(result.ok, str(result))
	assert_eq(result.value.publication.state_sha256, str(JSON_WRITER.stringify(expected_checkpoint).value).sha256_text())
	assert_true(f.real.calls.is_empty())
	f.owner.callback = Callable()

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
	assert_eq(results.size(), 16)
	for refused: Dictionary in results: assert_false(refused.ok)
	assert_true(f.real.calls.is_empty())
	f.owner.callback = Callable()

func test_shop_requires_live_reading_boundary() -> void:
	var f := _fixture()
	f.checkpoint.reading_session.boundary = "unsupported"
	var result := _commit(f)
	assert_false(result.ok)
	assert_false(result.get("committed", false))
	assert_eq(str(result.code), "scene_shop_checkpoint_invalid")
	assert_true(f.real.calls.is_empty())
