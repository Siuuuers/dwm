extends "res://addons/gut/test.gd"
## DesktopFirstRevealSnapshotComposer (Plan 02 Task 6, dwm-p2r.32, Phase D, brief Step 6.10).
## Representative, mutation-verified coverage of the core contract -- not the brief's full
## exhaustive crash-injection matrix, matching this task's own established precedent (see the
## task-6 report handoff). Proves: the composed post-commit snapshot_input carries the decremented
## round without a stat charge and the materialized/revealed board (brief Step 6.10's own words), that
## desktop.consequence survives untouched when its run_revision agrees, and that every structural
## mismatch this composer is documented to catch fails closed before composing anything.

const COMPOSER := preload("res://scripts/application/minesweeper/DesktopFirstRevealSnapshotComposer.gd")
const BOARD_STATE := preload("res://scripts/domain/minesweeper/DesktopBoardState.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")

const IDENTITY := {
	"run_id": "run-composer", "branch_id": "branch-composer", "desktop_timeline_generation": 0,
	"causal_day_instance": "day-composer", "app_round_ordinal": 1,
}

func _spec() -> Dictionary:
	return {
		"schema_version": 1, "board_kind": "desktop", "board_token": "board-token-composer",
		"board_token_receipt_id": "receipt-board-composer", "difficulty_id": "beginner",
		"width": 3, "height": 3, "base_mine_count": 1, "pressure": 0, "penalty_points_today": 0,
		"raw_extra_mines": 0, "requested_mine_count": 1, "capability_ids": [],
		"placement_stream_id": "minesweeper_placement_v1", "placement_nonce": "nonce-p-composer",
		"placement_nonce_receipt_id": "receipt-p-composer",
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": "nonce-d-composer",
		"debug_nonce_receipt_id": "receipt-d-composer",
		"explosion_stream_id": "minesweeper_explosion_v1", "explosion_nonce": "nonce-e-composer",
		"explosion_nonce_receipt_id": "receipt-e-composer",
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}

func _layout() -> Dictionary:
	return {"schema_version": 1, "width": 3, "height": 3, "mine_indices": [8], "mine_count": 1}

func _fp(value: Dictionary) -> String:
	return JSON.stringify(value).sha256_text()

## A fresh real DesktopBoardState's prepare_first_reveal() candidate, over a genuine reduced board.
func _board_candidate(transaction_id: String = "tx-composer") -> Dictionary:
	var state: RefCounted = BOARD_STATE.new()
	var layout := _layout()
	var board: Dictionary = REDUCER.first_reveal(layout, 0)["value"]["board"]
	var semantic := {"transaction_id": transaction_id, "identity": IDENTITY, "expected_revision": 0,
		"cell_index": 0, "spec": _spec()}
	var input: Dictionary = semantic.duplicate(true)
	input["request_fingerprint"] = _fp(semantic)
	var prepared: Dictionary = state.prepare_first_reveal(input, {"layout": layout, "board": board},
		{"checkpoint_id": "run-composer:1"})
	assert_true(prepared.get("ok", false), JSON.stringify(prepared))
	return (prepared["value"] as Dictionary)["candidate"]

func _game_state_candidate(transaction_id: String = "tx-composer") -> Dictionary:
	return {"transaction_id": transaction_id, "rounds_left": 4, "starts_today": {"day-composer": 1}}

func _empty_board_snapshot() -> Dictionary:
	return BOARD_STATE.new().capture()

func _consequence(run_revision: int = 0) -> Dictionary:
	return {
		"schema_version": 1, "run_revision": run_revision, "causal_sequence": 0,
		"causal_day_instance": "day-composer",
		"causal_day_instance_issuer_receipt": {
			"receipt_id": "issuer_receipt.fixture-day-composer", "purpose": "causal_day_instance",
			"namespace": "fixturenamespace", "counter": 1, "token": "day-composer", "numeric_value": null,
		},
		"pending": null, "outbox": {}, "shop_ledger": {"supportz_branch_purchase_count": 0,
			"supportz_last_purchase_causal_day_instance": "", "base_completion_receipts": []},
	}

func _base_snapshot_input(run_revision: int = 0) -> Dictionary:
	return {
		"lifecycle": {"run_id": "run-composer", "day": 1},
		"gameplay": {"stats": {"pressure": 3}, "minesweeper_rounds_left": 5},
		"contacts": {}, "scene": {},
		"applied_effect_transaction_ids": [], "applied_variable_transaction_ids": [], "command_receipts": {},
		"desktop": {"board": _empty_board_snapshot(), "consequence": _consequence(run_revision)},
	}

func _consequence_candidate(run_revision: int = 0) -> Dictionary:
	return {"expected_run_revision": run_revision}


func test_compose_projects_decremented_round_without_stat_charge_and_revealed_board() -> void:
	var composed: Dictionary = COMPOSER.compose(_base_snapshot_input(), _game_state_candidate(),
		_board_candidate(), _consequence_candidate())
	assert_true(composed.get("ok", false), JSON.stringify(composed))
	var snapshot_input: Dictionary = (composed["value"] as Dictionary)["snapshot_input"]
	assert_eq(int(snapshot_input["gameplay"]["minesweeper_rounds_left"]), 4, "the round is decremented")
	assert_eq(snapshot_input["gameplay"]["stats"], {"pressure": 3}, "first Reveal does not change or resurrect stats")
	var board: Dictionary = snapshot_input["desktop"]["board"]
	assert_eq(str(board["phase"]), "ACTIVE_VISIBLE", "the board is materialized/revealed")
	assert_eq(int(board["revision"]), 1)
	assert_true((board["command_receipts"] as Dictionary).has("tx-composer"),
		"the new transaction's command receipt is present")
	assert_eq(snapshot_input["desktop"]["consequence"], _consequence(0), "consequence is untouched")
	# Everything the composer does not own survives byte-for-byte.
	assert_eq(snapshot_input["lifecycle"], {"run_id": "run-composer", "day": 1})
	assert_eq(snapshot_input["contacts"], {})


func test_compose_rejects_transaction_id_disagreement() -> void:
	var composed: Dictionary = COMPOSER.compose(_base_snapshot_input(), _game_state_candidate("tx-other"),
		_board_candidate("tx-composer"), _consequence_candidate())
	assert_false(composed.get("ok", true))
	assert_eq(composed["code"], &"first_reveal_candidate_transaction_mismatch")


func test_compose_rejects_a_consequence_revision_that_no_longer_matches_the_base() -> void:
	var composed: Dictionary = COMPOSER.compose(_base_snapshot_input(0), _game_state_candidate(),
		_board_candidate(), _consequence_candidate(1))
	assert_false(composed.get("ok", true))
	assert_eq(composed["code"], &"first_reveal_candidate_revision_mismatch")


func test_compose_rejects_a_stale_board_pre_revision() -> void:
	var base := _base_snapshot_input()
	var stale_board: Dictionary = BOARD_STATE.new().capture()
	stale_board["revision"] = 3
	base["desktop"]["board"] = stale_board
	var composed: Dictionary = COMPOSER.compose(base, _game_state_candidate(), _board_candidate(), _consequence_candidate())
	assert_false(composed.get("ok", true))
	assert_eq(composed["code"], &"first_reveal_candidate_stale_revision")


func test_compose_rejects_a_desktop_less_base_snapshot_input() -> void:
	var base := _base_snapshot_input()
	base.erase("desktop")
	var composed: Dictionary = COMPOSER.compose(base, _game_state_candidate(), _board_candidate(), _consequence_candidate())
	assert_false(composed.get("ok", true), "a schema-3-shaped (desktop-less) base rejects")
	assert_eq(composed["code"], &"invalid_base_snapshot_input")


func test_compose_rejects_a_board_only_desktop_value() -> void:
	var base := _base_snapshot_input()
	(base["desktop"] as Dictionary).erase("consequence")
	var composed: Dictionary = COMPOSER.compose(base, _game_state_candidate(), _board_candidate(), _consequence_candidate())
	assert_false(composed.get("ok", true), "a desktop member missing consequence rejects")


func test_compose_rejects_an_extra_desktop_key() -> void:
	var base := _base_snapshot_input()
	(base["desktop"] as Dictionary)["surprise"] = {}
	var composed: Dictionary = COMPOSER.compose(base, _game_state_candidate(), _board_candidate(), _consequence_candidate())
	assert_false(composed.get("ok", true), "an extra desktop key rejects")


func test_compose_rejects_a_non_first_reveal_board_candidate() -> void:
	var restore_candidate := {"kind": &"restore", "snapshot_after": _empty_board_snapshot()}
	var composed: Dictionary = COMPOSER.compose(_base_snapshot_input(), _game_state_candidate(), restore_candidate, _consequence_candidate())
	assert_false(composed.get("ok", true))



func test_compose_refuses_retired_candidate_fields_without_mutating_input() -> void:
	for stat_id: String in ["motivation", "health"]:
		var base := _base_snapshot_input()
		var before := base.duplicate(true)
		var candidate := _game_state_candidate()
		candidate[stat_id] = 1
		var result: Dictionary = COMPOSER.compose(base, candidate, _board_candidate(), _consequence_candidate())
		assert_false(result.get("ok", true))
		assert_eq(result.code, &"invalid_game_state_candidate")
		assert_eq(base, before)


func test_scene_composer_refuses_legacy_outer_members_and_missing_scene() -> void:
	for key: String in ["committed_schedule", "schedule_view", "dating"]:
		var base := _base_snapshot_input()
		base[key] = {}
		var before := base.duplicate(true)
		assert_false(COMPOSER.compose(base, _game_state_candidate(), _board_candidate(), _consequence_candidate()).ok)
		assert_eq(base, before)
	var missing := _base_snapshot_input()
	missing.erase("scene")
	assert_false(COMPOSER.compose(missing, _game_state_candidate(), _board_candidate(), _consequence_candidate()).ok)

func test_scene_composer_refuses_retired_stats_and_coercible_candidates() -> void:
	for stats: Dictionary in [{"pressure": 3, "health": 8}, {"pressure": 3, "motivation": 4}, {"pressure": 3.0}, {"pressure": 13}]:
		var base := _base_snapshot_input()
		base.gameplay.stats = stats
		assert_false(COMPOSER.compose(base, _game_state_candidate(), _board_candidate(), _consequence_candidate()).ok)
	for value: Variant in [4.0, "4", true]:
		var candidate := _game_state_candidate()
		candidate.rounds_left = value
		assert_false(COMPOSER.compose(_base_snapshot_input(), candidate, _board_candidate(), _consequence_candidate()).ok)


func test_scene_composer_refuses_wrong_debit_and_coerced_revisions() -> void:
	var candidate := _game_state_candidate()
	candidate.rounds_left = 5
	assert_false(COMPOSER.compose(_base_snapshot_input(), candidate, _board_candidate(), _consequence_candidate()).ok)
	var board := _board_candidate()
	board.pre_revision = 0.0
	assert_false(COMPOSER.compose(_base_snapshot_input(), _game_state_candidate(), board, _consequence_candidate()).ok)
	var consequence := _consequence_candidate()
	consequence.extra = true
	assert_false(COMPOSER.compose(_base_snapshot_input(), _game_state_candidate(), _board_candidate(), consequence).ok)
