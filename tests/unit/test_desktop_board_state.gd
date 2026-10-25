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



# Scene facts use the real configuration facade but no retained payment proofs.
func _scene_fixture() -> Dictionary:
	var root := preload("res://tests/support/FakeDesktopIssuerRootStore.gd").new("33".repeat(32), 1)
	var issuer := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd").new()
	assert_true(issuer.configure(root).ok)
	var spec := _spec_a()
	spec.width = 8
	spec.height = 8
	spec.base_mine_count = 10
	spec.requested_mine_count = 10
	var layout := _layout_for(spec)
	var board: Dictionary = REDUCER.first_reveal(layout, 0).value.board
	var state := STATE.new()
	assert_true(state.configure_scene_payments(issuer).ok)
	var input := {"transaction_id": "scene-first", "request_fingerprint": "f".repeat(64),
		"identity": IDENTITY_A.duplicate(true), "expected_revision": 0, "cell_index": 0, "spec": spec}
	return {"root": root, "issuer": issuer, "state": state,
		"input": input, "materialized": {"layout": layout, "board": board}}


func _scene_frontier(spec: Dictionary) -> Dictionary:
	var kernel := preload("res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd")
	var projected: Dictionary = {}
	for key: String in kernel.SPEC_KEYS: projected[key] = spec[key]
	var states: Array[Dictionary] = []
	for stream: String in ["placement", "debug", "explosion"]:
		var rng := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd").new()
		assert_true(rng.seed(StringName(spec[stream + "_stream_id"]), spec[stream + "_nonce"]).ok)
		states.append(rng.capture().value)
	var begun := kernel.begin(projected, 0, kernel.MODE_CANDIDATE_SEARCH, states[0], states[1], states[2])
	assert_true(begun.ok, str(begun))
	return begun.value.preparation if begun.ok else {}


func _scene_start(fixture: Dictionary) -> Dictionary:
	var prepared: Dictionary = fixture.state.prepare_first_reveal(fixture.input, fixture.materialized)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return {}
	assert_true(fixture.state.commit(prepared.value.candidate).ok)
	return fixture.state.capture()


func test_scene_first_board_preserves_frozen_spec_without_payment_proof_or_history_admission() -> void:
	var fixture := _scene_fixture()
	var saved := _scene_start(fixture)
	if saved.is_empty(): return
	assert_eq(saved.board.keys().size(), 2)
	assert_eq(saved.board.spec, fixture.input.spec)
	assert_false(saved.board.has("paid_start_receipt"))
	saved.command_receipts.clear()
	var restored := STATE.new()
	var prepared := restored.prepare_restore_scene(saved, fixture.issuer)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_true(restored.commit(prepared.value.candidate).ok)
	assert_eq(restored.capture(), saved)
	assert_true(restored.capture().round_paid)
	var before := restored.capture()
	var changed := before.duplicate(true)
	changed.board.spec.pressure += 1
	assert_eq(restored.capture(), before, "captured spec must remain detached")


func test_scene_current_board_rejects_missing_spec_extra_proof_and_inconsistent_layout() -> void:
	var fixture := _scene_fixture()
	var saved := _scene_start(fixture)
	if saved.is_empty(): return
	var variants: Array[Dictionary] = []
	var changed := saved.duplicate(true)
	changed.board.erase("spec")
	variants.append(changed)
	changed = saved.duplicate(true)
	changed.board["paid_start_receipt"] = {"old": true}
	variants.append(changed)
	changed = saved.duplicate(true)
	changed.board.spec.width += 1
	variants.append(changed)
	changed = saved.duplicate(true)
	changed.board.spec.base_mine_count += 1
	changed.board.spec.requested_mine_count += 1
	variants.append(changed)
	changed = saved.duplicate(true)
	changed.board.board.adjacency_counts[0] += 1
	variants.append(changed)
	changed = saved.duplicate(true)
	changed.board.spec.board_kind = "solo_challenge"
	variants.append(changed)
	for invalid: Dictionary in variants:
		assert_false(STATE.new().prepare_restore_scene(invalid, fixture.issuer).ok, str(invalid.board))
	assert_eq(fixture.state.capture(), saved)


func test_scene_paid_replacement_and_debug_restore_current_facts_without_receipts() -> void:
	var fixture := _scene_fixture()
	if _scene_start(fixture).is_empty(): return
	var spec: Dictionary = fixture.input.spec.duplicate(true)
	spec.board_token = "replacement-token"
	var input := {"transaction_id": "replace", "request_fingerprint": "replace", "expected_revision": 1, "identity": IDENTITY_A}
	var replacement: Dictionary = fixture.state.prepare_paid_replacement(input, spec)
	assert_true(replacement.ok, str(replacement))
	if not replacement.ok: return
	assert_true(fixture.state.commit(replacement.value.candidate).ok)
	var shell: Dictionary = fixture.state.capture()
	assert_true(shell.round_paid)
	assert_false(shell.candidate.has("paid_start_receipt"))
	assert_eq(shell.candidate.spec, spec)
	assert_true(STATE.new().prepare_restore_scene(shell, fixture.issuer).ok)
	input = {"transaction_id": "debug", "request_fingerprint": "debug", "expected_revision": 2, "identity": IDENTITY_A, "spec": spec}
	var begun: Dictionary = fixture.state.prepare_debug_candidate(input, {"frontier": _scene_frontier(spec)})
	assert_true(begun.ok, str(begun))
	if not begun.ok: return
	assert_true(fixture.state.commit(begun.value.candidate).ok)
	var preparing: Dictionary = fixture.state.capture()
	assert_true(preparing.round_paid)
	assert_true(STATE.new().prepare_restore_scene(preparing, fixture.issuer).ok)
	var malformed := preparing.duplicate(true)
	malformed.candidate.frontier = {"cursor": 0}
	assert_false(STATE.new().prepare_restore_scene(malformed, fixture.issuer).ok)
	malformed = preparing.duplicate(true)
	malformed.candidate.spec.board_kind = "solo_challenge"
	assert_false(STATE.new().prepare_restore_scene(malformed, fixture.issuer).ok)
	malformed = preparing.duplicate(true)
	malformed.candidate.spec.placement_nonce = "other-placement"
	assert_false(STATE.new().prepare_restore_scene(malformed, fixture.issuer).ok,
		"a valid frontier must still belong to the frozen current spec")
	input = {"transaction_id": "slice", "request_fingerprint": "slice", "expected_revision": 3, "identity": IDENTITY_A}
	var sliced: Dictionary = fixture.state.prepare_debug_slice(input, {"done": true,
		"layout": fixture.materialized.layout, "forced_cell": 0, "proof_sha256": null})
	assert_true(sliced.ok, str(sliced))
	if not sliced.ok: return
	assert_true(fixture.state.commit(sliced.value.candidate).ok)
	var certified: Dictionary = fixture.state.capture()
	certified.command_receipts.clear()
	var restored := STATE.new()
	var restore := restored.prepare_restore_scene(certified, fixture.issuer)
	assert_true(restore.ok, str(restore))
	if not restore.ok: return
	assert_true(restored.commit(restore.value.candidate).ok)
	assert_true(restored.capture().round_paid)
	input = {"transaction_id": "paid-reveal", "request_fingerprint": "paid-reveal", "expected_revision": 4,
		"identity": IDENTITY_A, "spec": spec, "cell_index": 0}
	var reveal := restored.prepare_first_reveal(input, fixture.materialized)
	assert_true(reveal.ok, str(reveal))
	if not reveal.ok: return
	assert_true(restored.commit(reveal.value.candidate).ok)
	assert_eq(restored.capture().board.spec, spec)
	assert_true(restored.capture().round_paid)
	assert_false(restored.capture().board.has("paid_start_receipt"))
	for field: String in ["forced_cell", "proof_sha256"]:
		malformed = certified.duplicate(true)
		malformed.candidate[field] = -1 if field == "forced_cell" else "bad-proof"
		assert_false(STATE.new().prepare_restore_scene(malformed, fixture.issuer).ok)


func test_scene_commit_rechecks_mutated_detached_restore_and_live_candidates() -> void:
	var fixture := _scene_fixture()
	var prepared: Dictionary = fixture.state.prepare_first_reveal(fixture.input, fixture.materialized)
	assert_true(prepared.ok)
	if not prepared.ok: return
	var before: Dictionary = fixture.state.capture()
	prepared.value.candidate.board_after.spec.width += 1
	assert_false(fixture.state.commit(prepared.value.candidate).ok)
	assert_eq(fixture.state.capture(), before)
	var snapshot := _scene_start(fixture)
	if snapshot.is_empty(): return
	var target := STATE.new()
	var restore := target.prepare_restore_scene(snapshot, fixture.issuer)
	assert_true(restore.ok)
	if not restore.ok: return
	restore.value.candidate.snapshot_after.board.erase("spec")
	assert_false(target.commit(restore.value.candidate).ok)
	assert_eq(target.capture().phase, "NONE")


func test_scene_configuration_cannot_relabel_already_installed_legacy_state() -> void:
	var fixture := _scene_fixture()
	var legacy := STATE.new()
	var prepared := legacy.prepare_first_reveal(fixture.input, fixture.materialized, {"checkpoint_id": "old:1"})
	assert_true(prepared.ok)
	assert_true(legacy.commit(prepared.value.candidate).ok)
	var before := legacy.capture()
	assert_false(legacy.configure_scene_payments(fixture.issuer).ok)
	assert_eq(legacy.capture(), before)


# Current Scene settlement is present board state; legacy history tests above remain separate.
func _scene_terminal_snapshot(fixture: Dictionary) -> Dictionary:
	var saved := _scene_start(fixture)
	if saved.is_empty(): return {}
	var reduced := REDUCER.reveal(saved.board.board, int(saved.board.board.mine_indices[0]), "TEST.terminal")
	assert_true(reduced.ok, str(reduced))
	if not reduced.ok: return {}
	saved.board.board = reduced.value.board
	assert_true(saved.board.board.terminal)
	saved.settled_inspection = true
	return saved

func test_scene_settled_flag_is_required_boolean_and_requires_terminal_board() -> void:
	var fixture := _scene_fixture()
	var saved := _scene_start(fixture)
	if saved.is_empty(): return
	assert_false(saved.settled_inspection)
	for invalid: Variant in [null, 0, "true", true]:
		var changed := saved.duplicate(true)
		changed.settled_inspection = invalid
		assert_false(STATE.new().prepare_restore_scene(changed, fixture.issuer).ok,
			"nonterminal board cannot carry malformed or completed settlement state")
	var old_shape := saved.duplicate(true)
	old_shape["terminal_receipts"] = {}
	assert_false(STATE.new().prepare_restore_scene(old_shape, fixture.issuer).ok, "retired history is not a current field")
	var missing := saved.duplicate(true)
	missing.erase("settled_inspection")
	assert_false(STATE.new().prepare_restore_scene(missing, fixture.issuer).ok, "current-build fact is required")
	assert_eq(fixture.state.capture(), saved, "refused restores do not mutate source")

func test_scene_settled_board_restores_without_terminal_history_and_preserves_visibility_and_remap() -> void:
	var fixture := _scene_fixture()
	var saved := _scene_terminal_snapshot(fixture)
	if saved.is_empty(): return
	assert_false(saved.has("terminal_receipts"))
	var state := STATE.new()
	var prepared := state.prepare_restore_scene(saved, fixture.issuer)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_true(state.commit(prepared.value.candidate).ok)
	assert_true(state.has_settled_inspection(), "current fact alone identifies paid result inspection")
	for visible: bool in [false, true]:
		var live := state.capture()
		var request := {"transaction_id": "visibility-" + str(visible), "request_fingerprint": "visibility-" + str(visible),
			"identity": live.identity, "expected_revision": live.revision}
		var changed := state.prepare_visibility(request, visible)
		assert_true(changed.ok, str(changed))
		if not changed.ok: return
		assert_true(state.commit(changed.value.candidate).ok)
		assert_true(state.capture().settled_inspection)
		assert_true(state.has_settled_inspection())
	var remapped := state.capture()
	remapped.identity.branch_id = "restored-branch"
	remapped.identity.desktop_timeline_generation = 2
	var restored := STATE.new()
	prepared = restored.prepare_restore_scene(remapped, fixture.issuer)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_true(restored.commit(prepared.value.candidate).ok)
	assert_eq(restored.capture(), remapped)
	assert_true(restored.has_settled_inspection())
	var detached := restored.capture()
	detached.settled_inspection = false
	assert_true(restored.has_settled_inspection(), "captured fact is detached")
	var cleared := STATE.dismissed_inspection_snapshot(remapped)
	assert_false(cleared.settled_inspection)
	assert_eq(cleared.phase, "NONE")

func test_scene_dismiss_and_reset_clear_settlement_without_terminal_history() -> void:
	var fixture := _scene_fixture()
	var saved := _scene_terminal_snapshot(fixture)
	if saved.is_empty(): return
	var state := STATE.new()
	var prepared := state.prepare_restore_scene(saved, fixture.issuer)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_true(state.commit(prepared.value.candidate).ok)
	var dismissed := state.prepare_dismiss_inspection({"transaction_id": "dismiss", "request_fingerprint": "dismiss",
		"identity": saved.identity, "expected_revision": saved.revision})
	assert_true(dismissed.ok, str(dismissed))
	if not dismissed.ok: return
	assert_true(state.commit(dismissed.value.candidate).ok)
	assert_false(state.capture().settled_inspection)
	assert_false(state.has_settled_inspection())
	assert_eq(state.capture().phase, "NONE")
	prepared = state.prepare_restore_scene(saved, fixture.issuer)
	assert_true(prepared.ok)
	assert_true(state.commit(prepared.value.candidate).ok)
	state.reset()
	assert_false(state.capture().settled_inspection)
	assert_false(state.has_settled_inspection())


func test_scene_round_paid_is_required_boolean_and_agrees_with_active_phase() -> void:
	var fixture := _scene_fixture()
	var saved := _scene_start(fixture)
	if saved.is_empty(): return
	assert_true(saved.round_paid)
	for value: Variant in [null, 0, 1, "true", false]:
		var changed := saved.duplicate(true)
		changed.round_paid = value
		assert_false(STATE.new().prepare_restore_scene(changed, fixture.issuer).ok, str(value))
	var missing := saved.duplicate(true)
	missing.erase("round_paid")
	assert_false(STATE.new().prepare_restore_scene(missing, fixture.issuer).ok)
	var cleared := STATE.dismissed_inspection_snapshot(saved)
	assert_false(cleared.round_paid)
	assert_true(STATE.new().prepare_restore_scene(cleared, fixture.issuer).ok)
	cleared.round_paid = true
	assert_false(STATE.new().prepare_restore_scene(cleared, fixture.issuer).ok)


func test_scene_new_unpaid_preparation_ignores_previous_day_matching_round_ordinal() -> void:
	var fixture := _scene_fixture()
	var saved := _scene_start(fixture)
	if saved.is_empty(): return
	var cleared := STATE.dismissed_inspection_snapshot(saved)
	var restored := STATE.new()
	var restore := restored.prepare_restore_scene(cleared, fixture.issuer)
	assert_true(restore.ok, str(restore))
	if not restore.ok: return
	assert_true(restored.commit(restore.value.candidate).ok)
	var input: Dictionary = fixture.input.duplicate(true)
	input.transaction_id = "next-day-debug"
	input.expected_revision = cleared.revision
	input.identity.causal_day_instance = "next-day"
	var begun := restored.prepare_debug_candidate(input, {"frontier": _scene_frontier(input.spec)})
	assert_true(begun.ok, str(begun))
	if not begun.ok: return
	assert_true(restored.commit(begun.value.candidate).ok)
	var preparing := restored.capture()
	assert_false(preparing.round_paid)
	assert_false(preparing.candidate.has("paid_start_receipt"))
	assert_eq(preparing.identity.app_round_ordinal, saved.identity.app_round_ordinal)
	assert_eq(preparing.command_receipts[fixture.input.transaction_id], saved.command_receipts[fixture.input.transaction_id])
	assert_true(STATE.new().prepare_restore_scene(preparing, fixture.issuer).ok)


func test_scene_player_projection_omits_retry_records_and_live_backup_keeps_exact_responses() -> void:
	var fixture := _scene_fixture()
	var live := _scene_start(fixture)
	if live.is_empty(): return
	var projected := STATE.project_player_state(live)
	assert_true(projected.ok, str(projected))
	if not projected.ok: return
	var player: Dictionary = projected.value.snapshot
	assert_false(player.has("command_receipts"))
	assert_false(live.command_receipts.is_empty())
	assert_eq(fixture.state.capture(), live)
	var restored := STATE.new()
	var prepared := restored.prepare_player_restore_scene(player, fixture.issuer)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_true(restored.commit(prepared.value.candidate).ok)
	assert_eq(restored.capture().command_receipts, {})
	assert_eq(STATE.project_player_state(restored.capture()).value.snapshot, player)
	assert_false(STATE.new().prepare_player_restore_scene(live, fixture.issuer).ok,
		"player admission must not accept retry records")
	assert_false(STATE.new().prepare_restore_scene(player, fixture.issuer).ok,
		"live backup admission must not silently discard retry records")
	var rolled := restored.prepare_restore_scene(live, fixture.issuer)
	assert_true(rolled.ok, str(rolled))
	if not rolled.ok: return
	assert_true(restored.commit(rolled.value.candidate).ok)
	assert_eq(restored.capture(), live)
	var duplicate := restored.commit({"kind": &"first_reveal", "transaction_id": fixture.input.transaction_id,
		"request_fingerprint": fixture.input.request_fingerprint})
	assert_eq(duplicate, live.command_receipts[fixture.input.transaction_id].result,
		"failed Load rollback preserves the genuine response for a preexisting retry")


func test_scene_board_command_and_visibility_preserve_frozen_spec() -> void:
	var fixture := _scene_fixture()
	var saved := _scene_start(fixture)
	if saved.is_empty(): return
	var reduced := REDUCER.set_flag(saved.board.board, 63, true, "flag-current")
	assert_true(reduced.ok, str(reduced))
	if not reduced.ok: return
	var command: Dictionary = fixture.state.prepare_board_command({"transaction_id": "flag-current",
		"request_fingerprint": "flag-current", "identity": saved.identity, "expected_revision": saved.revision,
		"kind": &"set_flag"}, reduced.value.board)
	assert_true(command.ok, str(command))
	if not command.ok: return
	assert_true(fixture.state.commit(command.value.candidate).ok)
	var flagged: Dictionary = fixture.state.capture()
	assert_eq(flagged.board.spec, saved.board.spec)
	assert_eq(flagged.board.board.flagged_indices, [63])
	assert_true(flagged.round_paid)
	var visibility: Dictionary = fixture.state.prepare_visibility({"transaction_id": "hide-current",
		"request_fingerprint": "hide-current", "identity": saved.identity, "expected_revision": flagged.revision}, false)
	assert_true(visibility.ok, str(visibility))
	if not visibility.ok: return
	assert_true(fixture.state.commit(visibility.value.candidate).ok)
	var suspended: Dictionary = fixture.state.capture()
	assert_eq(suspended.board, flagged.board)
	assert_true(suspended.round_paid)
	assert_true(STATE.new().prepare_restore_scene(suspended, fixture.issuer).ok)


func test_scene_first_reveal_rejects_a_board_from_a_different_materialized_layout() -> void:
	var fixture := _scene_fixture()
	var materialized: Dictionary = fixture.materialized.duplicate(true)
	materialized.layout.mine_indices[-1] = 11
	var before: Dictionary = fixture.state.capture()
	var prepared: Dictionary = fixture.state.prepare_first_reveal(fixture.input, materialized)
	assert_false(prepared.ok)
	assert_eq(prepared.code, &"materialized_board_layout_mismatch")
	assert_eq(fixture.state.capture(), before)
