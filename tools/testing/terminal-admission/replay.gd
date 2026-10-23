extends "res://tests/integration/authored_week_child.gd"
## Controller-only fresh-process replay of slot3 written by the paired candidate.
var _replay_result := {"complete": false, "pending_phase": ""}

func _mark(phase: String) -> void:
	_replay_result.pending_phase = phase
	_write_json("res://.godot/ci/terminal-replay.json", _replay_result)

func test_fresh_saved_ending_replay_and_new_game() -> void:
	_phase = "terminal-replay"
	_replay_result.process_id = OS.get_process_id()
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://authored-week-terminal-pair.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	_replay_result.creator_process_id = proof.process_id
	var saved_hashes := {}
	for slot: int in [1, 2, 3]:
		saved_hashes[str(slot)] = FileAccess.get_sha256("user://saves/slot_%d.json" % slot)
	assert_eq(saved_hashes["3"], proof.slot_sha256)
	_mark("boot")
	if not _setup_authored(): return
	var before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var gallery_id := "ending:%s:gallery:ending.alone" % str(proof.snapshot.lifecycle.run_id)
	assert_true(before.gallery_transaction_receipts.has(gallery_id))
	_mark("load_slot3")
	if not await _load_authored(3, proof): return
	_mark("ending_captions")
	if not await _walk_authored(ENDING_INDEX + 1, _expected.size() - 1): return
	assert_eq(observed_lines.size(), 22)
	_mark("completion")
	var finished: Dictionary = await _complete_authored()
	if finished.is_empty(): return
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts, before.gallery_transaction_receipts)
	_replay_result.completed_lifecycle = finished
	_mark("new_game")
	if not await _new_from_title(2): return
	var fresh: Dictionary = game.capture_run_snapshot_input()
	assert_ne(fresh.lifecycle.run_id, proof.snapshot.lifecycle.run_id)
	assert_eq(fresh.lifecycle.state, "PLAYING")
	assert_false(fresh.lifecycle.has("ending_plan"))
	assert_eq(bridge._reading_session.ledger.snapshot().captions.size(), 1)
	assert_true(game.capture_dating_challenge_state().value.is_empty())
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts, before.gallery_transaction_receipts)
	for slot: int in [1, 2, 3]:
		assert_eq(FileAccess.get_sha256("user://saves/slot_%d.json" % slot), saved_hashes[str(slot)])
	await _screenshot("authored-terminal-fresh-day1")
	_replay_result.fresh_lifecycle = fresh.lifecycle
	_replay_result.observed_lines = observed_lines
	_replay_result.slot_hashes = saved_hashes
	_replay_result.complete = true
	_mark("")
