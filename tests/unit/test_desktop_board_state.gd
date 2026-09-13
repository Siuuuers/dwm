extends "res://addons/gut/test.gd"
# Behavioral RED/GREEN contract tests for DesktopBoardState (Plan 02 Task 5, dwm-p2r.32).
#
# DesktopBoardState is the canonical desktop Minesweeper state machine: closed phases NONE ->
# PREPARING -> PREPARED_UNSTARTED -> ACTIVE_VISIBLE <-> ACTIVE_SUSPENDED -> SETTLING, driven
# entirely by prepare_*()/commit() candidates (never a raw setter). Every commit() call is keyed
# by the candidate's transaction_id: a repeat of the same transaction_id with an identical request
# fingerprint replays the stored result (duplicate request equality); a repeat with a different
# fingerprint conflicts (changed-payload conflict); a caller whose expected_revision no longer
# matches is stale.
#
# GLOBAL CLASS NAMES ARE NOT AVAILABLE for this fresh Task-5 script (never through an editor import
# pass), so every dependency is preloaded by path -- this repo's established answer (see
# test_desktop_identity_nonce_issuer.gd).

const PROBE := preload("res://tests/support/DynamicScriptProbe.gd")
const STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const IDENTITY := preload("res://scripts/domain/desktop/DesktopIdentity.gd")
const BOARD_SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")

const STATE_PATH := "res://scripts/domain/minesweeper/DesktopBoardState.gd"

const IDENTITY_A := {
	"run_id": "run-a", "branch_id": "branch-a", "desktop_timeline_generation": 0,
	"causal_day_instance": "day-a", "app_round_ordinal": 1,
}
const IDENTITY_B := {
	"run_id": "run-b", "branch_id": "branch-b", "desktop_timeline_generation": 0,
	"causal_day_instance": "day-b", "app_round_ordinal": 2,
}

var _state: STATE


func before_each() -> void:
	_state = STATE.new()


# ---- Step 5.1 parse proof ----

func test_state_script_loads() -> void:
	var loaded: Dictionary = PROBE.load_script(STATE_PATH)
	assert_true(loaded.get("ok", false), "DesktopBoardState.gd must load")


func test_state_instantiates() -> void:
	var instantiated: Dictionary = PROBE.instantiate(STATE_PATH)
	assert_true(instantiated.get("ok", false), "DesktopBoardState.gd must instantiate")


# ---- fresh/reset invariants ----

func test_fresh_state_is_none_phase_with_zero_revision() -> void:
	var captured := _state.capture()
	assert_eq(captured["phase"], "NONE")
	assert_eq(captured["revision"], 0)
	assert_null(captured["identity"])
	assert_null(captured["candidate"])
	assert_null(captured["board"])
	assert_null(captured["settlement"])
	assert_eq(captured["command_receipts"], {})
	assert_eq(captured["terminal_receipts"], {})
	assert_eq(captured["schema_version"], 1)


func test_capture_shape_is_exactly_nine_keys() -> void:
	var keys: Array = _state.capture().keys()
	keys.sort()
	var expected: Array = [
		"board", "candidate", "command_receipts", "identity", "phase",
		"revision", "schema_version", "settlement", "terminal_receipts",
	]
	assert_eq(keys, expected)


func test_reset_returns_to_fresh_state() -> void:
	_begin_debug(_state, "tx-reset", IDENTITY_A, _spec_a())
	_state.reset()
	var captured := _state.capture()
	assert_eq(captured["phase"], "NONE")
	assert_eq(captured["revision"], 0)
	assert_eq(captured["command_receipts"], {})


# ---- capture() detachment ----

func test_capture_is_detached_from_internal_state() -> void:
	var first := _state.capture()
	first["phase"] = "TAMPERED"
	first["command_receipts"]["injected"] = {"tampered": true}
	var second := _state.capture()
	assert_eq(second["phase"], "NONE", "mutating a captured dictionary must not affect internal state")
	assert_false(second["command_receipts"].has("injected"))


# ---- prepare_debug_candidate: legal edge (NONE -> PREPARING) ----

func test_prepare_debug_candidate_from_none_transitions_to_preparing() -> void:
	var result := _begin_debug(_state, "tx-1", IDENTITY_A, _spec_a())
	assert_true(result.get("ok", false), JSON.stringify(result))
	var captured := _state.capture()
	assert_eq(captured["phase"], "PREPARING")
	assert_eq(captured["revision"], 1)
	assert_eq(captured["identity"], IDENTITY_A)
	assert_eq((captured["candidate"] as Dictionary)["spec"], _spec_a())
	assert_null(captured["board"])
	assert_null(captured["settlement"])


func test_prepare_debug_candidate_rejects_when_not_none_phase() -> void:
	_begin_debug(_state, "tx-1", IDENTITY_A, _spec_a())
	var input := _debug_input("tx-2", IDENTITY_A, 1)
	var prepared := _state.prepare_debug_candidate(input, {"frontier": {"cursor": 0}})
	assert_false(prepared.get("ok", false))
	assert_ne(prepared.get("code"), &"not_implemented")
	assert_eq(prepared.get("code"), &"debug_candidate_requires_none_phase")


func test_prepare_debug_candidate_rejects_stale_revision() -> void:
	var input := _debug_input("tx-1", IDENTITY_A, 7)
	var prepared := _state.prepare_debug_candidate(input, {"frontier": {"cursor": 0}})
	assert_false(prepared.get("ok", false))
	assert_eq(prepared.get("code"), &"stale_revision")


func test_prepare_debug_candidate_rejects_invalid_identity() -> void:
	var bad_identity := IDENTITY_A.duplicate(true)
	bad_identity["app_round_ordinal"] = 99
	var input := _debug_input("tx-1", bad_identity, 0)
	var prepared := _state.prepare_debug_candidate(input, {"frontier": {"cursor": 0}})
	assert_false(prepared.get("ok", false))
	assert_ne(prepared.get("code"), &"not_implemented")


# ---- prepare_debug_slice: progress and certified transitions ----

func test_prepare_debug_slice_progress_stays_in_preparing() -> void:
	_begin_debug(_state, "tx-1", IDENTITY_A, _spec_a())
	var input := _debug_input("tx-2", IDENTITY_A, 1)
	var prepared := _state.prepare_debug_slice(input, {"done": false, "frontier": {"cursor": 3}})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed := _state.commit(prepared["value"]["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(committed["value"]["phase"], "PREPARING")
	assert_eq(committed["value"]["revision"], 2)


func test_prepare_debug_slice_certified_transitions_to_prepared_unstarted() -> void:
	_begin_debug(_state, "tx-1", IDENTITY_A, _spec_a())
	var certified := _certify_debug(_state, "tx-2", IDENTITY_A, 1)
	assert_true(certified.get("ok", false), JSON.stringify(certified))
	var captured := _state.capture()
	assert_eq(captured["phase"], "PREPARED_UNSTARTED")
	assert_eq(captured["revision"], 2)
	var candidate: Dictionary = captured["candidate"]
	assert_eq(candidate["forced_cell"], 0)
	assert_true(candidate.has("layout"))


func test_debug_is_cost_free_through_prepared_unstarted() -> void:
	# No board/settlement exists and no motivation-relevant field is touched anywhere in
	# DesktopBoardState through PREPARED_UNSTARTED -- only identity/candidate/phase/revision.
	_begin_debug(_state, "tx-1", IDENTITY_A, _spec_a())
	_certify_debug(_state, "tx-2", IDENTITY_A, 1)
	var captured := _state.capture()
	assert_eq(captured["phase"], "PREPARED_UNSTARTED")
	assert_null(captured["board"])
	assert_null(captured["settlement"])


func test_prepare_debug_slice_rejects_wrong_phase() -> void:
	var input := _debug_input("tx-1", IDENTITY_A, 0)
	var prepared := _state.prepare_debug_slice(input, {"done": false, "frontier": {}})
	assert_false(prepared.get("ok", false))
	assert_eq(prepared.get("code"), &"debug_slice_requires_preparing_phase")


func test_prepare_debug_slice_rejects_identity_mismatch() -> void:
	_begin_debug(_state, "tx-1", IDENTITY_A, _spec_a())
	var input := _debug_input("tx-2", IDENTITY_B, 1)
	var prepared := _state.prepare_debug_slice(input, {"done": false, "frontier": {}})
	assert_false(prepared.get("ok", false))
	assert_eq(prepared.get("code"), &"identity_mismatch")


# ---- prepare_first_reveal: Default/Lucky path (NONE -> ACTIVE_VISIBLE directly) ----

func test_default_and_lucky_remain_none_until_reveal() -> void:
	# Nothing but capture()/get_entry_context-style queries touches phase before first Reveal.
	var captured := _state.capture()
	assert_eq(captured["phase"], "NONE")
	var result := _first_reveal_from_none(_state, "tx-1", IDENTITY_A, _spec_a(), 0)
	assert_true(result.get("ok", false), JSON.stringify(result))
	assert_eq(_state.capture()["phase"], "ACTIVE_VISIBLE")


func test_prepare_first_reveal_from_none_populates_board_and_receipt() -> void:
	_first_reveal_from_none(_state, "tx-1", IDENTITY_A, _spec_a(), 0)
	var captured := _state.capture()
	assert_eq(captured["phase"], "ACTIVE_VISIBLE")
	assert_eq(captured["revision"], 1)
	assert_null(captured["candidate"])
	var board_slot: Dictionary = captured["board"]
	assert_true(board_slot.has("board"))
	assert_true(board_slot.has("paid_start_receipt"))
	assert_eq(board_slot["paid_start_receipt"], {"checkpoint_id": "run-a:1"})
	var board: Dictionary = board_slot["board"]
	assert_true((board["revealed_indices"] as Array).has(0))


func test_prepare_first_reveal_from_prepared_unstarted_adopts_certified_layout() -> void:
	_begin_debug(_state, "tx-1", IDENTITY_A, _spec_a())
	_certify_debug(_state, "tx-2", IDENTITY_A, 1)
	var layout: Dictionary = _state.capture()["candidate"]["layout"]
	var board: Dictionary = REDUCER.first_reveal(layout, 0)["value"]["board"]
	var input := _with_fp({
		"transaction_id": "tx-3", "identity": IDENTITY_A, "expected_revision": 2,
		"cell_index": 0, "spec": _spec_a(),
	})
	var prepared := _state.prepare_first_reveal(input, {"layout": layout, "board": board},
		{"checkpoint_id": "run-a:1"})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed := _state.commit(prepared["value"]["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(committed["value"]["phase"], "ACTIVE_VISIBLE")


func test_prepare_first_reveal_rejects_forced_cell_mismatch_from_prepared_unstarted() -> void:
	_begin_debug(_state, "tx-1", IDENTITY_A, _spec_a())
	_certify_debug(_state, "tx-2", IDENTITY_A, 1)
	var layout: Dictionary = _state.capture()["candidate"]["layout"]
	var board: Dictionary = REDUCER.first_reveal(layout, 2)["value"]["board"]
	var input := _with_fp({
		"transaction_id": "tx-3", "identity": IDENTITY_A, "expected_revision": 2,
		"cell_index": 2, "spec": _spec_a(),
	})
	var prepared := _state.prepare_first_reveal(input, {"layout": layout, "board": board},
		{"checkpoint_id": "run-a:1"})
	assert_false(prepared.get("ok", false))
	assert_eq(prepared.get("code"), &"forced_cell_mismatch")


func test_prepare_first_reveal_rejects_wrong_phase() -> void:
	_first_reveal_from_none(_state, "tx-1", IDENTITY_A, _spec_a(), 0)
	var input := _with_fp({
		"transaction_id": "tx-2", "identity": IDENTITY_A, "expected_revision": 1,
		"cell_index": 3, "spec": _spec_a(),
	})
	var layout := _layout_a()
	var board: Dictionary = REDUCER.first_reveal(layout, 3)["value"]["board"]
	var prepared := _state.prepare_first_reveal(input, {"layout": layout, "board": board}, {"x": 1})
	assert_false(prepared.get("ok", false))
	assert_eq(prepared.get("code"), &"first_reveal_requires_none_or_prepared_phase")


# ---- prepare_board_command: routine reveal/flag/chord ----

func test_prepare_board_command_reveal_commits_new_revision() -> void:
	_first_reveal_from_none(_state, "tx-1", IDENTITY_A, _spec_a(), 0)
	var board_before: Dictionary = _state.capture()["board"]["board"]
	var reduced: Dictionary = REDUCER.reveal(board_before, 2, "tx-2")["value"]["board"]
	var input := _with_fp({
		"transaction_id": "tx-2", "identity": IDENTITY_A, "expected_revision": 1,
		"kind": &"reveal", "cell_index": 2,
	})
	var prepared := _state.prepare_board_command(input, reduced)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed := _state.commit(prepared["value"]["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(committed["value"]["phase"], "ACTIVE_VISIBLE")
	assert_eq(committed["value"]["revision"], 2)
	var board_slot: Dictionary = committed["value"]["board"]
	assert_eq(board_slot["paid_start_receipt"], {"checkpoint_id": "run-a:1"}, "paid receipt carries over")


func test_prepare_board_command_rejects_when_suspended() -> void:
	_first_reveal_from_none(_state, "tx-1", IDENTITY_A, _spec_a(), 0)
	_suspend(_state, "tx-2", IDENTITY_A, 1)
	var board_before: Dictionary = _state.capture()["board"]["board"]
	var reduced: Dictionary = REDUCER.reveal(board_before, 2, "tx-3")["value"]["board"]
	var input := _with_fp({
		"transaction_id": "tx-3", "identity": IDENTITY_A, "expected_revision": 2,
		"kind": &"reveal", "cell_index": 2,
	})
	var prepared := _state.prepare_board_command(input, reduced)
	assert_false(prepared.get("ok", false))
	assert_eq(prepared.get("code"), &"board_command_requires_active_visible_phase")


# ---- prepare_visibility: suspend/resume ----

func test_prepare_visibility_suspend_then_resume() -> void:
	_first_reveal_from_none(_state, "tx-1", IDENTITY_A, _spec_a(), 0)
	var suspended := _suspend(_state, "tx-2", IDENTITY_A, 1)
	assert_true(suspended.get("ok", false), JSON.stringify(suspended))
	assert_eq(_state.capture()["phase"], "ACTIVE_SUSPENDED")
	var resumed := _resume(_state, "tx-3", IDENTITY_A, 2)
	assert_true(resumed.get("ok", false), JSON.stringify(resumed))
	assert_eq(_state.capture()["phase"], "ACTIVE_VISIBLE")


func test_prepare_visibility_rejects_from_none() -> void:
	var input := _with_fp({"transaction_id": "tx-1", "identity": IDENTITY_A, "expected_revision": 0})
	var prepared := _state.prepare_visibility(input, false)
	assert_false(prepared.get("ok", false))
	assert_eq(prepared.get("code"), &"visibility_requires_active_phase")


# ---- prepare_settlement ----

func test_prepare_settlement_requires_terminal_board() -> void:
	_first_reveal_from_none(_state, "tx-1", IDENTITY_A, _spec_a(), 0)
	var input := _with_fp({"transaction_id": "tx-2", "identity": IDENTITY_A, "expected_revision": 1})
	var prepared := _state.prepare_settlement(input, {"outcome": &"cleared"})
	assert_false(prepared.get("ok", false))
	assert_eq(prepared.get("code"), &"settlement_requires_terminal_board")


func test_prepare_settlement_on_terminal_board_transitions_to_settling() -> void:
	# A trivial 1x1, zero-mine board: the forced first reveal is immediately terminal (cleared).
	var trivial_spec := _spec_a()
	trivial_spec["width"] = 1
	trivial_spec["height"] = 1
	trivial_spec["base_mine_count"] = 0
	trivial_spec["pressure"] = 0
	trivial_spec["requested_mine_count"] = 0
	trivial_spec["raw_extra_mines"] = 0
	var trivial_layout := {
		"schema_version": 1, "width": 1, "height": 1, "mine_indices": [], "mine_count": 0,
	}
	_first_reveal_from_none(_state, "tx-1", IDENTITY_A, trivial_spec, 0, trivial_layout)
	var board_slot: Dictionary = _state.capture()["board"]
	assert_true((board_slot["board"] as Dictionary)["terminal"])
	var input := _with_fp({"transaction_id": "tx-2", "identity": IDENTITY_A, "expected_revision": 1})
	var prepared := _state.prepare_settlement(input, {"outcome": &"cleared"})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed := _state.commit(prepared["value"]["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	assert_eq(committed["value"]["phase"], "SETTLING")
	assert_eq(committed["value"]["settlement"], {"outcome": &"cleared"})


# ---- duplicate request equality / changed-payload conflict / stale revision (commit-level) ----

func test_commit_duplicate_transaction_id_same_payload_replays_result() -> void:
	var first := _begin_debug(_state, "tx-dup", IDENTITY_A, _spec_a())
	assert_true(first.get("ok", false))
	# Re-committing the EXACT SAME already-applied candidate a second time (as a coordinator retry
	# would, before it has re-validated current phase) must short-circuit to the original result
	# rather than double-apply.
	var replay := _state.commit(_last_candidate)
	assert_true(replay.get("ok", false), JSON.stringify(replay))
	assert_eq(replay, first, "an identical replay returns the exact original result")
	assert_eq(_state.capture()["revision"], 1, "a duplicate commit must not advance revision again")


func test_routine_receipts_keep_latest_retry_but_compact_older_boards_after_acceptance() -> void:
	_first_reveal_from_none(_state, "start", IDENTITY_A, _spec_a(), 0)
	var first_receipt: Dictionary = _state.capture().command_receipts.start.duplicate(true)
	var suspended := _suspend(_state, "older", IDENTITY_A, 1)
	var older_candidate := _last_candidate.duplicate(true)
	var legacy := _state.capture()
	assert_eq(legacy.command_receipts.older.result, suspended)
	var fresh := STATE.new()
	assert_true(fresh.commit(fresh.prepare_restore(legacy).value.candidate).ok)
	assert_eq(fresh.capture(), legacy, "loading an older full receipt does not rewrite it")
	var resumed := _resume(fresh, "latest", IDENTITY_A, 2)
	var latest_candidate := _last_candidate.duplicate(true)
	var captured := fresh.capture()
	assert_eq(captured.command_receipts.start, first_receipt, "paid first-Reveal evidence stays exact")
	assert_eq(captured.command_receipts.latest.result, resumed, "latest action retains exact retry")
	assert_false(captured.command_receipts.older.result.value.has("board"), "old board copy is retired")
	assert_eq(captured.command_receipts.older, {
		"request_fingerprint": older_candidate.request_fingerprint,
		"result": {"ok": true, "code": &"board_command_already_applied",
			"value": {"already_applied": true, "revision": 2}, "receipt": {}},
	}, "older visibility receipts retain the exact retry contract without redundant metadata")
	assert_eq(fresh.commit(latest_candidate), resumed)
	var old_retry := fresh.commit(older_candidate)
	assert_true(old_retry.ok)
	assert_eq(old_retry.code, &"board_command_already_applied")
	assert_eq(old_retry.value.revision, 2)
	assert_eq(fresh.capture(), captured, "old retry neither rolls back nor reapplies the board")
	older_candidate.request_fingerprint = "changed-old-input"
	assert_eq(fresh.commit(older_candidate).code, &"transaction_conflict")
	assert_eq(fresh.capture(), captured)


func test_legacy_compacted_board_receipt_sheds_metadata_only_after_new_acceptance() -> void:
	assert_true(_begin_debug(_state, "debug", IDENTITY_A, _spec_a()).ok)
	assert_true(_certify_debug(_state, "certify", IDENTITY_A, 1).ok)
	assert_true(_first_reveal_from_none(_state, "start", IDENTITY_A, _spec_a(), 0).ok)
	var proof_snapshot := _state.capture()
	var board_before: Dictionary = proof_snapshot.board.board
	var flagged: Dictionary = REDUCER.set_flag(board_before, 1, true, "older")
	assert_true(flagged.get("ok", false), JSON.stringify(flagged))
	var prepared := _state.prepare_board_command(_with_fp({
		"transaction_id": "older", "identity": IDENTITY_A, "expected_revision": 3,
		"kind": &"set_flag", "cell_index": 1, "flagged": true,
	}), flagged.value.board)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var older_candidate: Dictionary = prepared.value.candidate
	assert_true(_state.commit(older_candidate).ok)
	var legacy_entry: Dictionary = _state.capture().command_receipts.older
	assert_true(_suspend(_state, "pause", IDENTITY_A, 4).ok)
	var legacy := _state.capture()
	var acknowledged := {"ok": true, "code": &"board_command_already_applied",
		"value": {"already_applied": true, "revision": 4}, "receipt": {}}
	# Recreate the previously shipped compact result WITH its four redundant metadata
	# fields, independently of whether the current producer has already removed them.
	legacy_entry.result = acknowledged.duplicate(true)
	legacy.command_receipts.older = legacy_entry
	var frozen_legacy := legacy.duplicate(true)
	var fresh := STATE.new()
	assert_true(fresh.commit(fresh.prepare_restore(legacy).value.candidate).ok)
	assert_eq(fresh.capture(), frozen_legacy, "loading legacy receipts alone never rewrites their shape")
	legacy.command_receipts.older.result.value.revision = -1
	legacy.command_receipts.older.request_fingerprint = "caller-mutated"
	assert_eq(fresh.capture(), frozen_legacy, "the restored receipt is detached from caller-owned input")
	var latest := _resume(fresh, "latest", IDENTITY_A, 5)
	assert_true(latest.get("ok", false), JSON.stringify(latest))
	var latest_candidate := _last_candidate.duplicate(true)
	var retained := fresh.capture()
	assert_eq(retained.command_receipts.older, {
		"request_fingerprint": older_candidate.request_fingerprint, "result": acknowledged,
	}, "the next accepted command compacts legacy metadata without changing its acknowledgement")
	for preserved: String in ["debug", "certify", "start"]:
		assert_eq(retained.command_receipts[preserved], proof_snapshot.command_receipts[preserved],
			preserved + " nonroutine or first-Reveal proof remains exact")
	assert_eq(retained.board.board, frozen_legacy.board.board, "receipt compaction does not alter board history or flags")
	assert_eq(retained.command_receipts.size(), frozen_legacy.command_receipts.size() + 1,
		"all historical transaction keys survive; only the newly accepted command is added")
	assert_eq(fresh.commit(older_candidate), acknowledged)
	assert_eq(fresh.commit(latest_candidate), latest, "the latest full response still retries exactly")
	var changed := older_candidate.duplicate(true)
	changed.request_fingerprint = "changed-request"
	assert_eq(fresh.commit(changed).code, &"transaction_conflict")
	assert_eq(fresh.capture(), retained, "neither old retry nor conflict changes live state")
	retained.command_receipts.older.result.value.revision = -2
	assert_eq(fresh.commit(older_candidate), acknowledged, "captured compact results are also detached")
	assert_eq(frozen_legacy.command_receipts.older, {
		"request_fingerprint": older_candidate.request_fingerprint, "result": acknowledged,
		"command_kind": "board_command", "identity_fingerprint": legacy_entry.identity_fingerprint,
		"pre_revision": 3, "post_revision": 4,
	}, "compaction leaves earlier detached snapshots unchanged")


func test_receipt_metadata_compaction_preserves_unknown_extended_and_minimal_records() -> void:
	assert_true(_first_reveal_from_none(_state, "start", IDENTITY_A, _spec_a(), 0).ok)
	assert_true(_suspend(_state, "older", IDENTITY_A, 1).ok)
	var legacy := _state.capture()
	var full: Dictionary = legacy.command_receipts.older
	var unknown: Dictionary = full.duplicate(true)
	unknown.command_kind = "extension_visibility"
	var extended: Dictionary = full.duplicate(true)
	extended["opaque"] = {"labels": ["keep-extension"]}
	var malformed: Dictionary = full.duplicate(true)
	malformed.erase("request_fingerprint")
	var minimal := {"request_fingerprint": "minimal-fingerprint", "result": {
		"ok": true, "code": &"board_command_already_applied",
		"value": {"already_applied": true, "revision": 2}, "receipt": {},
	}}
	unknown.result = minimal.result.duplicate(true)
	legacy.command_receipts["unknown"] = unknown
	legacy.command_receipts["extended"] = extended
	legacy.command_receipts["malformed"] = malformed
	legacy.command_receipts["minimal"] = minimal
	var wrong_types := {"request_fingerprint": {"opaque": "request"},
		"identity_fingerprint": {"opaque": "identity"}, "pre_revision": null}
	for field: String in wrong_types:
		var mistyped: Dictionary = full.duplicate(true)
		mistyped[field] = wrong_types[field]
		legacy.command_receipts["wrong_type_" + field] = mistyped
	var fresh := STATE.new()
	assert_true(fresh.commit(fresh.prepare_restore(legacy).value.candidate).ok)
	assert_true(_resume(fresh, "latest", IDENTITY_A, 2).ok)
	var retained: Dictionary = fresh.capture().command_receipts
	assert_eq(retained.unknown, unknown, "an unknown command kind does not authorize compaction")
	assert_eq(retained.extended.get("opaque"), extended.opaque, "eligible-looking extensions retain their opaque payload")
	# Existing full-result compaction may still replace these rows' result. Metadata
	# reduction must not reinterpret an extended or malformed row as the exact known shape.
	for field: String in ["command_kind", "identity_fingerprint", "pre_revision", "post_revision"]:
		assert_eq(retained.extended.get(field), full[field], "extended receipt retains " + field)
		assert_eq(retained.malformed.get(field), full[field], "malformed receipt retains " + field)
	assert_false(retained.malformed.has("request_fingerprint"), "malformed records are not silently repaired")
	assert_eq(retained.minimal, minimal, "an already minimal receipt remains exact")
	for field: String in wrong_types:
		var key := "wrong_type_" + field
		var expected: Dictionary = legacy.command_receipts[key].duplicate(true)
		# Permit the pre-existing full-result compaction while preserving every other
		# field of a six-key record whose metadata is not the producer's known type.
		expected.result = retained[key].result
		assert_eq(retained[key], expected, "mistyped " + field + " cannot authorize metadata removal")


func test_commit_duplicate_transaction_id_changed_payload_conflicts() -> void:
	_begin_debug(_state, "tx-dup2", IDENTITY_A, _spec_a())
	# To specifically prove commit()'s own conflict law (independent of the higher-level phase
	# guard a fresh prepare_* call would also raise), build a candidate by hand with the SAME
	# transaction_id already on record but a different request_fingerprint.
	var candidate: Dictionary = _last_candidate.duplicate(true)
	candidate["request_fingerprint"] = "not-the-real-fingerprint"
	var conflict_result := _state.commit(candidate)
	assert_false(conflict_result.get("ok", false))
	assert_eq(conflict_result.get("code"), &"transaction_conflict")


func test_stale_revision_rejected_across_every_prepare_method() -> void:
	_first_reveal_from_none(_state, "tx-1", IDENTITY_A, _spec_a(), 0)
	var stale_visibility := _state.prepare_visibility(
		_with_fp({"transaction_id": "tx-x", "identity": IDENTITY_A, "expected_revision": 0}), false)
	assert_eq(stale_visibility.get("code"), &"stale_revision")


# ---- mutation-after-call/return detachment ----

func test_prepare_candidate_mutation_before_commit_does_not_leak_into_a_prior_capture() -> void:
	var before := _state.capture()
	var prepared := _state.prepare_debug_candidate(_debug_input("tx-1", IDENTITY_A, 0),
		{"frontier": {"cursor": 0}})
	var candidate: Dictionary = prepared["value"]["candidate"]
	candidate["identity_after"]["run_id"] = "tampered"
	_state.commit(candidate)
	assert_eq(before["phase"], "NONE", "the earlier NONE-phase capture must stay frozen")
	assert_eq(_state.capture()["identity"]["run_id"], "tampered",
		"commit() applies exactly the candidate bytes it was handed")


func test_captured_result_mutation_does_not_leak_into_internal_state() -> void:
	_first_reveal_from_none(_state, "tx-1", IDENTITY_A, _spec_a(), 0)
	var captured := _state.capture()
	captured["board"]["board"]["revealed_indices"].append(999)
	captured["command_receipts"]["tx-1"]["command_kind"] = "tampered"
	var recaptured := _state.capture()
	assert_false((recaptured["board"]["board"]["revealed_indices"] as Array).has(999))
	assert_ne(recaptured["command_receipts"]["tx-1"]["command_kind"], "tampered")


# ---- prepare_restore ----

func test_prepare_restore_round_trips_a_captured_snapshot() -> void:
	_first_reveal_from_none(_state, "tx-1", IDENTITY_A, _spec_a(), 0)
	var snapshot := _state.capture()
	var fresh := STATE.new()
	var prepared := fresh.prepare_restore(snapshot)
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	var committed := fresh.commit(prepared["value"]["candidate"])
	assert_true(committed.get("ok", false), JSON.stringify(committed))
	# commit()'s result is a single flat CommandResult -- never a CommandResult wrapping another
	# CommandResult -- so "phase" reads at the same one level every other commit() caller relies on.
	assert_true(committed["value"].has("phase"), "restore's result must not double-wrap its value")
	assert_eq(committed["value"]["phase"], "ACTIVE_VISIBLE")
	assert_eq(fresh.capture(), snapshot)


func test_prepare_restore_rejects_bad_member_set() -> void:
	var prepared := _state.prepare_restore({"phase": "NONE"})
	assert_false(prepared.get("ok", false))
	assert_ne(prepared.get("code"), &"not_implemented")


func test_prepare_restore_rejects_phase_invariant_violation() -> void:
	var bad_snapshot := {
		"schema_version": 1, "phase": "ACTIVE_VISIBLE", "revision": 1,
		"identity": null, "candidate": null, "board": null, "settlement": null,
		"command_receipts": {}, "terminal_receipts": {},
	}
	var prepared := _state.prepare_restore(bad_snapshot)
	assert_false(prepared.get("ok", false))
	assert_ne(prepared.get("code"), &"not_implemented")


# ---- helpers ----

var _last_candidate: Dictionary = {}

## A stable content fingerprint for a semantic input dict. Not cryptographic -- just deterministic
## given GDScript's stable Dictionary insertion order, matching what a real caller (the Task-5
## coordinator) would supply from its own request-fingerprinting seam.
func _fp(semantic_input: Dictionary) -> String:
	return JSON.stringify(semantic_input).sha256_text()


func _with_fp(semantic_input: Dictionary) -> Dictionary:
	var input: Dictionary = semantic_input.duplicate(true)
	input["request_fingerprint"] = _fp(semantic_input)
	return input


func _debug_input(transaction_id: String, identity: Dictionary, expected_revision: int) -> Dictionary:
	return _with_fp({
		"transaction_id": transaction_id, "identity": identity,
		"expected_revision": expected_revision, "spec": _spec_a(),
	})


func _begin_debug(state: STATE, transaction_id: String, identity: Dictionary, spec: Dictionary) -> Dictionary:
	var captured := state.capture()
	var input := _with_fp({
		"transaction_id": transaction_id, "identity": identity,
		"expected_revision": captured["revision"], "spec": spec,
	})
	var prepared := state.prepare_debug_candidate(input, {"frontier": {"cursor": 0}})
	if not prepared.get("ok", false):
		return prepared
	_last_candidate = prepared["value"]["candidate"]
	return state.commit(_last_candidate)


func _certify_debug(state: STATE, transaction_id: String, identity: Dictionary, expected_revision: int) -> Dictionary:
	var input := _with_fp({
		"transaction_id": transaction_id, "identity": identity, "expected_revision": expected_revision,
	})
	var layout := _layout_a()
	var prepared := state.prepare_debug_slice(input,
		{"done": true, "layout": layout, "forced_cell": 0, "proof_sha256": "fake-proof-sha256"})
	if not prepared.get("ok", false):
		return prepared
	_last_candidate = prepared["value"]["candidate"]
	return state.commit(_last_candidate)


func _first_reveal_from_none(state: STATE, transaction_id: String, identity: Dictionary,
		spec: Dictionary, cell_index: int, layout_override: Dictionary = {}) -> Dictionary:
	var captured := state.capture()
	var layout: Dictionary = layout_override if not layout_override.is_empty() else _layout_for(spec)
	var board: Dictionary = REDUCER.first_reveal(layout, cell_index)["value"]["board"]
	var input := _with_fp({
		"transaction_id": transaction_id, "identity": identity,
		"expected_revision": captured["revision"], "cell_index": cell_index, "spec": spec,
	})
	var run_id: String = str(identity["run_id"])
	var checkpoint_sequence: int = 1
	var paid_start_receipt := {"checkpoint_id": "%s:%d" % [run_id, checkpoint_sequence]}
	var prepared := state.prepare_first_reveal(input, {"layout": layout, "board": board}, paid_start_receipt)
	if not prepared.get("ok", false):
		return prepared
	_last_candidate = prepared["value"]["candidate"]
	return state.commit(_last_candidate)


func _suspend(state: STATE, transaction_id: String, identity: Dictionary, expected_revision: int) -> Dictionary:
	var input := _with_fp({
		"transaction_id": transaction_id, "identity": identity, "expected_revision": expected_revision,
	})
	var prepared := state.prepare_visibility(input, false)
	if not prepared.get("ok", false):
		return prepared
	_last_candidate = prepared["value"]["candidate"]
	return state.commit(_last_candidate)


func _resume(state: STATE, transaction_id: String, identity: Dictionary, expected_revision: int) -> Dictionary:
	var input := _with_fp({
		"transaction_id": transaction_id, "identity": identity, "expected_revision": expected_revision,
	})
	var prepared := state.prepare_visibility(input, true)
	if not prepared.get("ok", false):
		return prepared
	_last_candidate = prepared["value"]["candidate"]
	return state.commit(_last_candidate)


func _spec_a() -> Dictionary:
	return {
		"schema_version": 1, "board_kind": "desktop", "board_token": "board-token-a",
		"board_token_receipt_id": "receipt-board-a", "difficulty_id": "beginner",
		"width": 3, "height": 3, "base_mine_count": 1, "pressure": 3, "penalty_points_today": 0,
		"raw_extra_mines": 1, "requested_mine_count": 1, "capability_ids": ["first_cell_safe"],
		"placement_stream_id": "minesweeper_placement_v1", "placement_nonce": "nonce-p-a",
		"placement_nonce_receipt_id": "receipt-p-a",
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": "nonce-d-a",
		"debug_nonce_receipt_id": "receipt-d-a",
		"explosion_stream_id": "minesweeper_explosion_v1", "explosion_nonce": "nonce-e-a",
		"explosion_nonce_receipt_id": "receipt-e-a",
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}


func _layout_a() -> Dictionary:
	return _layout_for(_spec_a())


func _layout_for(spec: Dictionary) -> Dictionary:
	var width: int = int(spec["width"])
	var height: int = int(spec["height"])
	var requested: int = int(spec["requested_mine_count"])
	var mine_indices: Array[int] = []
	# Deterministic placement starting at index 1 (never index 0, so the forced first-reveal cell
	# is always safe, but ADJACENT to it so revealing 0 stays local instead of flood-clearing the
	# whole board -- tests that need an ACTIVE_VISIBLE board with other still-hidden cells rely on
	# this).
	for i in range(requested):
		mine_indices.append(1 + i)
	mine_indices.sort()
	return {
		"schema_version": 1, "width": width, "height": height,
		"mine_indices": mine_indices, "mine_count": mine_indices.size(),
	}
