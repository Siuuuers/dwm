extends "res://tests/integration/authored_week_child.gd"
## Controller-only paired native measurement, identical for both runtime sources.
const TIMING := preload("res://scripts/narrative/SceneValidationTiming.gd")
var _pair_result := {"phases": [], "complete": false, "pending_phase": ""}

func _begin(label: String) -> int:
	_pair_result.pending_phase = label
	_write_json("res://.godot/ci/terminal-pair.json", _pair_result)
	assert_true(TIMING.begin_scope("terminal_pair_" + label, "ENDING", "PRIMARY_PENDING", 0))
	return Time.get_ticks_usec()

func _end(label: String, started: int, ok: bool) -> void:
	TIMING.end_scope(ok)
	_pair_result.phases.append({"phase": label, "elapsed_us": Time.get_ticks_usec() - started, "ok": ok})
	_pair_result.pending_phase = ""
	_write_json("res://.godot/ci/terminal-pair.json", _pair_result)

func test_genuine_ending_load_save() -> void:
	_phase = "terminal-pair"
	_pair_result.process_id = OS.get_process_id()
	var parsed: Dictionary = PARSER.parse_object(FileAccess.get_file_as_string("user://authored-week-ending.json"))
	if not _ok(parsed): return
	var proof: Dictionary = parsed.value
	# Relocate only diagnostic evidence in memory; saved authority remains byte-identical.
	proof.user_dir = ProjectSettings.globalize_path("user://")
	_pair_result.source_slot_sha256 = FileAccess.get_sha256("user://saves/slot_2.json")
	assert_eq(_pair_result.source_slot_sha256, proof.slot_sha256)
	assert_eq(proof.snapshot.checkpoint_sequence, 71)
	assert_eq(proof.snapshot.command_receipts.size(), 61)
	var started := _begin("boot")
	var succeeded := _setup_authored()
	_end("boot", started, succeeded)
	if not succeeded: return
	var before: Dictionary = profile.get_profile_snapshot().duplicate(true)
	var day4_hash := FileAccess.get_sha256("user://saves/slot_1.json")
	started = _begin("load")
	succeeded = await _load_authored(2, proof)
	_end("load", started, succeeded)
	if not succeeded: return
	started = _begin("save")
	assert_false(FileAccess.file_exists("user://saves/slot_3.json"))
	var saved: Dictionary = await _save_authored(3, "terminal-pair")
	_end("save", started, not saved.is_empty())
	if saved.is_empty(): return
	assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts, before.gallery_transaction_receipts)
	if OS.get_environment("DWM_TERMINAL_COMPLETE") == "1":
		started = _begin("ending_captions")
		succeeded = await _walk_authored(ENDING_INDEX + 1, _expected.size() - 1)
		_end("ending_captions", started, succeeded)
		if not succeeded: return
		started = _begin("completion")
		var finished: Dictionary = await _complete_authored()
		_end("completion", started, not finished.is_empty())
		if finished.is_empty(): return
		assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts, before.gallery_transaction_receipts)
		if not await _new_from_title(2): return
		var fresh: Dictionary = game.capture_run_snapshot_input()
		assert_ne(fresh.lifecycle.run_id, proof.snapshot.lifecycle.run_id)
		assert_eq(fresh.lifecycle.state, "PLAYING")
		assert_false(fresh.lifecycle.has("ending_plan"))
		assert_eq(bridge._reading_session.ledger.snapshot().captions.size(), 1)
		assert_true(game.capture_dating_challenge_state().value.is_empty())
		assert_eq(profile.get_profile_snapshot().gallery_transaction_receipts, before.gallery_transaction_receipts)
		assert_eq(FileAccess.get_sha256("user://saves/slot_3.json"), saved.slot_sha256)
		await _screenshot("authored-terminal-fresh-day1")
		_pair_result.completed_lifecycle = finished
		_pair_result.fresh_lifecycle = fresh.lifecycle
	assert_eq(FileAccess.get_sha256("user://saves/slot_2.json"), proof.slot_sha256)
	assert_eq(FileAccess.get_sha256("user://saves/slot_1.json"), day4_hash)
	_pair_result.complete = true
	_pair_result.observed_lines = observed_lines
	_write_json("res://.godot/ci/terminal-pair.json", _pair_result)
