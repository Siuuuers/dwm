extends "res://tests/integration/scene_partner_fork_child.gd"
## FINAL services, real native captions and physical Save/fresh-process Load.
## Authored TEST content is the only registration substitution.
const RECALL := preload("res://tests/support/SceneChallengeRecallFixture.gd")
const RECALL_CONTRACT := preload("res://scripts/domain/narrative/SceneEventContract.gd")
const RECALL_PROOF := "user://scene-challenge-recall-proof.json"
const MEMORY_LINE := "line.scene.test.recall.later.one"
const SELECTED_LINE := "line.scene.test.recall_a_day1.one"

func _install_content_registration() -> Dictionary:
	return RECALL.install()

func _result_receipts(kind: String) -> Array:
	var found: Array = []
	for receipt: Dictionary in game.capture_run_snapshot_input().command_receipts.values():
		if receipt.get("scene_event", {}).get("result", {}).get("kind") == kind: found.append(receipt)
	return found

func _assert_no_reward_change(before: Dictionary) -> void:
	var current: Dictionary = game.capture_run_snapshot_input()
	for key: String in ["gameplay", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_eq(current[key], before[key], "recall preserves " + key)
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "no active board is needed")

func _recall_and_assert(proof: Dictionary) -> bool:
	assert_eq(_result_receipts("challenge_closed"), [proof.closure], "retained closure remains exact")
	assert_true(_result_receipts("challenge_recalled").is_empty())
	var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	await _accept()
	if not await _wait_line(SELECTED_LINE): return false
	var recalled: Array = _result_receipts("challenge_recalled")
	assert_eq(recalled.size(), 1)
	if recalled.size() != 1: return false
	assert_eq(recalled[0].scene_event.result, {"kind": "challenge_recalled",
		"closure_command_id": proof.closure.transaction_id, "outcome": "never_started", "target_id": "recall_a_day1"})
	assert_eq(_result_receipts("challenge_closed"), [proof.closure])
	_assert_no_reward_change(before)
	var profile_after: Dictionary = profile.get_profile_snapshot().duplicate(true)
	if SELECTED_LINE in profile_before.visited_line_ids:
		assert_eq(profile_after, profile_before, "revisiting the recalled caption writes no Profile history")
	else:
		var visits: Array = profile_before.visited_line_ids.duplicate()
		visits.append(SELECTED_LINE)
		assert_eq(profile_after.visited_line_ids, visits)
		var witnesses: Dictionary = profile_after.witnessed_caption_variants.duplicate(true)
		for id: String in profile_before.witnessed_caption_variants:
			assert_eq(witnesses.get(id), profile_before.witnessed_caption_variants[id])
			witnesses.erase(id)
		assert_eq(witnesses.size(), 1, "only the ordinary newly rendered caption is witnessed")
		if witnesses.size() == 1: assert_eq(witnesses.values()[0].line_id, SELECTED_LINE)
		for field: String in ["visited_line_ids", "witnessed_caption_variants"]:
			profile_before.erase(field)
			profile_after.erase(field)
		assert_eq(profile_after, profile_before, "recall adds no other Profile consequences")
	var snapshot: Dictionary = game.capture_run_snapshot_input()
	var bundle: Dictionary = RECALL.bundle().value
	var issuer: RefCounted = bootstrap._desktop_identity_nonce_issuer
	if not _check_selected_recall_ledger(snapshot, bundle, issuer, recalled[0], proof.closure): return false
	var forged: Dictionary = snapshot.command_receipts.duplicate(true)
	forged[recalled[0].transaction_id].scene_event.result.closure_command_id = "TEST.missing.closure"
	assert_false(RECALL_CONTRACT.validate_scene_receipts(forged, bundle, issuer, saves, snapshot.contacts).ok,
		"authentic ledger refuses recall with unrelated closure provenance")
	return true

func create_recall() -> void:
	if not _start_services(): return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://.godot/ci"))
	if not _ok(profile.set_preference(&"preferences.reading.auto_enabled", false)): return
	var started: Dictionary = saves.start_scene_new_run("recall.start", {"route_id": "scene", "content_version": 1,
		"audio_context": get_node("/root/AudioManager").get_semantic_audio_context()})
	assert_eq(started.get("code"), &"scene_activation_pending", str(started))
	if not await _await_ready(): return
	if not await _wait_line("line.scene.test.recall.start.one"): return
	await _accept()
	assert_eq(_result_receipts("challenge_playable").size(), 1)
	var held: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(held): return
	assert_eq(held.value.reading_session.boundary, "control")
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.recall.start.one")
	assert_true(game.capture_dating_challenge_state().value.is_empty())
	# Playable admission holds the caption; a separate physical Accept departs.
	await _click(_caption().caption_text)
	if not await _wait_line("line.scene.test.recall.start.two"): return
	await _accept()
	if not await _wait_line("line.scene.test.echo_a_day1.one"): return
	var closures: Array = _result_receipts("challenge_closed")
	assert_eq(closures.size(), 1)
	if closures.size() != 1: return
	assert_eq(closures[0].scene_event.result.outcome, "never_started")
	assert_null(closures[0].scene_event.result.attempt_proof)
	await _accept()
	if not await _wait_line(MEMORY_LINE): return
	if not await _save_partner(1): return
	var proof := {"pid": OS.get_process_id(), "closure": closures[0],
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"profile": profile.get_profile_snapshot().duplicate(true),
		"snapshot": game.capture_run_snapshot_input().duplicate(true)}
	if not _write_json(RECALL_PROOF, proof): return
	await _screenshot("challenge-recall-saved")
	if not await _recall_and_assert(proof): return
	proof.profile = profile.get_profile_snapshot().duplicate(true)
	if not _write_json(RECALL_PROOF, proof): return
	await _screenshot("challenge-recall-selected")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)

func load_recall() -> void:
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string(RECALL_PROOF))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	assert_ne(OS.get_process_id(), proof.pid, "Load uses a fresh OS process")
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	if not _start_services() or not await _load_partner(1, true): return
	if not await _wait_line(MEMORY_LINE): return
	assert_eq(profile.get_profile_snapshot(), proof.profile)
	_assert_no_reward_change(proof.snapshot)
	if not await _recall_and_assert(proof): return
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), proof.slot_sha256)
	await _screenshot("challenge-recall-restored-selected")

# Exercise the public selected ledger on the real issued, persisted recall journey.
# Generic callers retain fresh validation of their arbitrary bundle.
func _check_selected_recall_ledger(snapshot: Dictionary, bundle: Dictionary, issuer: Object,
		recall_receipt: Dictionary, closure: Dictionary) -> bool:
	var timing := preload("res://scripts/narrative/SceneValidationTiming.gd")
	var prior_environment := OS.get_environment("DWM_SCENE_VALIDATION_PROFILE")
	OS.set_environment("DWM_SCENE_VALIDATION_PROFILE", "1")
	var generic_started: bool = timing.begin_scope("recall_generic_ledger", "PLAYING", "", 0)
	assert_true(generic_started)
	var expected := RECALL_CONTRACT.validate_scene_receipts(snapshot.command_receipts,
		bundle, issuer, saves, snapshot.contacts)
	var generic_calls: int = timing._record.get("bundle_validation_calls", -1)
	if generic_started: timing.end_scope(expected.ok)
	var selected_started: bool = timing.begin_scope("recall_selected_ledger", "PLAYING", "", 0)
	assert_true(selected_started)
	var actual := RECALL_CONTRACT.validate_selected_scene_receipts(snapshot.command_receipts,
		issuer, saves, snapshot.contacts)
	var selected_calls: int = timing._record.get("bundle_validation_calls", -1)
	if selected_started: timing.end_scope(actual.ok)
	OS.set_environment("DWM_SCENE_VALIDATION_PROFILE", prior_environment)
	assert_true(expected.ok, str(expected))
	assert_eq(actual, expected, "selected registration preserves the complete authenticated ledger")
	assert_eq(generic_calls, selected_calls + 2,
		"one recall removes the outer and recall-specific structural bundle checks")
	if not expected.ok or not actual.ok: return false
	var source_before: Dictionary = snapshot.command_receipts.duplicate(true)
	for mutation: String in ["recall_version", "recall_closure", "closure_anchor", "missing_closure"]:
		var changed: Dictionary = source_before.duplicate(true)
		var code: StringName
		match mutation:
			"recall_version":
				changed[recall_receipt.transaction_id].scene_event.semantic.schema_version = 2.0
				code = &"scene_event_version_invalid"
			"recall_closure":
				changed[recall_receipt.transaction_id].scene_event.result.closure_command_id = "TEST.missing.closure"
				code = &"scene_challenge_recall_mismatch"
			"closure_anchor":
				changed[closure.transaction_id].scene_event.reading_anchor.line_id = "TEST.other.line"
				changed[recall_receipt.transaction_id].scene_event.semantic.schema_version = 2.0
				code = &"event_anchor_invalid"
			"missing_closure":
				changed.erase(closure.transaction_id)
				code = &"scene_challenge_recall_missing"
		var before: Dictionary = changed.duplicate(true)
		var generic := RECALL_CONTRACT.validate_scene_receipts(changed, bundle, issuer, saves, snapshot.contacts)
		var selected := RECALL_CONTRACT.validate_selected_scene_receipts(changed, issuer, saves, snapshot.contacts)
		assert_eq(generic.get("code"), code, mutation)
		assert_eq(selected, generic, mutation + " preserves fresh refusal and order")
		assert_eq(changed, before, mutation + " preserves caller bytes")
	var changed_bundle: Dictionary = bundle.duplicate(true)
	changed_bundle.caption_registry["TEST.changed"] = "different registration"
	assert_true(RECALL_CONTRACT.validate_bundle_structure(changed_bundle).ok)
	assert_false(RECALL_CONTRACT.validate_scene_receipts(source_before,
		changed_bundle, issuer, saves, snapshot.contacts).ok,
		"generic bundle input cannot use selected registration authority")
	assert_eq(RECALL_CONTRACT.validate_selected_scene_receipts(source_before,
		issuer, saves, snapshot.contacts), expected, "later calls freshly authenticate original receipts")
	assert_eq(snapshot.command_receipts, source_before)
	return true

