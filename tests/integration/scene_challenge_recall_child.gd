extends "res://tests/integration/scene_partner_fork_child.gd"
## FINAL services, real native captions and physical Save/fresh-process Load.
## Authored TEST content is the only registration substitution.
const RECALL := preload("res://tests/support/SceneChallengeRecallFixture.gd")
const RECALL_PROOF := "user://scene-challenge-recall-proof.json"
const MEMORY_LINE := "line.scene.test.recall.later.one"
const SELECTED_LINE := "line.scene.test.recall_a_day1.one"

func _install_content_registration() -> Dictionary:
	return RECALL.install()

func _assert_no_reward_change(before: Dictionary) -> void:
	var current: Dictionary = game.capture_run_snapshot_input()
	for key: String in ["gameplay"]:
		assert_eq(current[key], before[key], "recall preserves " + key)
	assert_true(game.capture_dating_challenge_state().value.is_empty(), "no active board is needed")

func _recall_and_assert(proof: Dictionary) -> bool:
	var expected: Dictionary = proof.outcomes
	assert_eq(game.scene_challenge_outcomes, expected, "saved outcome is explicit before recall")
	var occurrence: String = expected.keys()[0]
	var detached: Dictionary = game.capture_run_snapshot_input()
	detached.gameplay.scene_challenge_outcomes[occurrence].outcome = "won"
	assert_eq(game.scene_challenge_outcomes, expected, "snapshot callers cannot mutate nested live outcomes")
	var before: Dictionary = game.capture_run_snapshot_input().duplicate(true)
	var profile_before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	await _accept()
	if not await _wait_line(SELECTED_LINE): return false
	assert_eq(game.capture_run_snapshot_input().scene.entry_id, "scene.test.recall_a_day1",
		"saved never_started outcome selects its registered later variation")
	assert_eq(game.scene_challenge_outcomes, expected, "recall never closes or rewrites the earlier Challenge")
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
	var reading_schema := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
	var before_playable: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(before_playable): return
	var reading_candidate := {"scene": game.capture_run_snapshot_input().scene,
		"content_version": before_playable.value.content_version, "narrative_checkpoint": before_playable.value}
	assert_true(reading_candidate.scene.active_challenge.is_empty())
	assert_true(reading_schema._validate_scene_reading(reading_candidate).ok,
		"caption before Start needs no active Challenge even when playable is next")
	await _accept()
	assert_eq(game.capture_run_snapshot_input().scene.active_challenge.challenge_id, RECALL.CHALLENGE_ID)
	var held: Dictionary = bridge.capture_reading_checkpoint(false)
	if not _ok(held): return
	assert_eq(held.value.reading_session.boundary, "control")
	reading_candidate.scene = game.capture_run_snapshot_input().scene
	reading_candidate.narrative_checkpoint = held.value
	assert_true(reading_schema._validate_scene_reading(reading_candidate).ok, "genuine held playable is valid")
	reading_candidate.scene.active_challenge = {}
	var missing_challenge: Dictionary = reading_schema._validate_scene_reading(reading_candidate)
	assert_false(missing_challenge.ok, "held playable cannot lose its required current Challenge")
	assert_eq(missing_challenge.get("code"), &"scene_challenge_position_invalid")
	assert_eq(bridge._runtime_adapter.current_line_id(), "line.scene.test.recall.start.one")
	assert_true(game.capture_dating_challenge_state().value.is_empty())
	assert_eq(game.scene_challenge_outcomes, {}, "playable without closure has no outcome fact")
	# Playable admission holds the caption; a separate physical Accept departs.
	await _click(_caption().caption_text)
	if not await _wait_line("line.scene.test.recall.start.two"): return
	await _accept()
	if not await _wait_line("line.scene.test.echo_a_day1.one"): return
	var outcomes: Dictionary = game.scene_challenge_outcomes.duplicate(true)
	assert_eq(outcomes.size(), 1)
	if outcomes.size() != 1: return
	assert_eq(outcomes.values()[0], {"challenge_id": RECALL.CHALLENGE_ID, "outcome": "never_started", "physical_slot": ""},
		"Finish records never_started distinctly from an open opportunity")
	assert_true(game.capture_run_snapshot_input().scene.active_challenge.is_empty())
	assert_true(profile.get_profile_snapshot().dating_attempts.is_empty(), "never_started creates no physical attempt")
	await _accept()
	if not await _wait_line(MEMORY_LINE): return
	if not await _save_partner(1): return
	var proof := {"pid": OS.get_process_id(), "outcomes": outcomes,
		"slot_sha256": FileAccess.get_sha256("user://saves/slot_1.json"),
		"profile": profile.get_profile_snapshot().duplicate(true),
		"snapshot": game.capture_run_snapshot_input().duplicate(true)}
	var saved: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://saves/slot_1.json"))
	if not _ok(saved): return
	var persisted: Dictionary = saved.value.current_snapshot.snapshot
	for key: String in ["command_receipts", "applied_effect_transaction_ids", "applied_variable_transaction_ids"]:
		assert_false(persisted.has(key), "player snapshot omits " + key)
	assert_eq(persisted.gameplay.scene_challenge_outcomes, outcomes)
	var schema := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
	assert_true(schema.validate(persisted).get("ok", false), "direct outcome snapshot is admissible")
	for field: String in ["challenge_id", "outcome"]:
		var changed: Dictionary = persisted.duplicate(true)
		changed.gameplay.scene_challenge_outcomes[outcomes.keys()[0]][field] = "" if field == "challenge_id" else "TEST.invalid_outcome"
		assert_false(schema.validate(changed).get("ok", false), "required outcome rejects invalid " + field)
	assert_eq(persisted.gameplay.scene_challenge_outcomes, outcomes, "validation never mutates the selected outcome")
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

