class_name FakeDesktopBoardStatePort
extends RefCounted

## Contract fake for the Task-5 GameState-facing state port (Plan 02 Task 5, dwm-p2r.32),
## delivered under this renamed path per the controller's coexistence ruling. The EXISTING
## `tests/support/FakeMinesweeperStatePort.gd` belongs to the retained .9-era round transaction and
## is never read or edited by this file.
##
## Tracks a small in-memory GameState-shaped slice (motivation, rounds_left, next ordinal) so
## coordinator tests can exercise capacity/motivation gating, the exact first-Reveal receipt shape,
## and full prepare/commit/rollback/publish transactional round-trips without touching real
## GameState. Never production wiring: it never calls SaveManager or any storage path.

const _RECEIPT_KEYS: Array[String] = [
	"receipt_id", "receipt_provenance", "transaction_id", "transaction_issuer_receipt",
	"identity", "difficulty_id", "first_cell", "board_revision", "rounds_before", "rounds_after",
	"motivation_before", "motivation_after", "layout_sha256", "proof_sha256", "checkpoint_id",
]

var run_id := "run-fake"
var branch_id := "branch-fake"
var desktop_timeline_generation := 0
var causal_day_instance := "day-fake"
var motivation := 7
var rounds_left := 2
var round_floor := 0
var next_ordinal := 1

var call_log: Array[Dictionary] = []
var published: Array[Dictionary] = []

var _fatal_latched := false
var _fatal_failure: Dictionary = {}
var _fail_next: Dictionary = {}  # method_name (String) -> failure Dictionary


func fail_next(method_name: String, failure: Dictionary) -> void:
	_fail_next[method_name] = failure.duplicate(true)


func latch_fatal_for_test(failure: Dictionary) -> void:
	_fatal_latched = true
	_fatal_failure = failure.duplicate(true)


func guard_external(operation_id: StringName) -> Dictionary:
	_log(&"guard_external", {"operation_id": operation_id})
	if _fatal_latched:
		return {"ok": false, "code": &"APPLICATION_FATAL", "details": {"failure": _fatal_failure.duplicate(true)}}
	return {"ok": true, "code": &"ok", "value": {}, "receipt": {}}


func capture() -> Dictionary:
	_log(&"capture", {})
	var armed := _consume_failure("capture")
	if not armed.is_empty():
		return armed
	var eligible: bool = motivation > 0 and rounds_left > round_floor and next_ordinal <= 5
	return {"ok": true, "code": &"ok", "value": {
		"run_id": run_id, "branch_id": branch_id,
		"desktop_timeline_generation": desktop_timeline_generation,
		"causal_day_instance": causal_day_instance, "next_app_round_ordinal": next_ordinal,
		"eligible": eligible, "motivation": motivation, "rounds_left": rounds_left,
		"backup": {"motivation": motivation, "rounds_left": rounds_left, "next_ordinal": next_ordinal},
	}, "receipt": {}}


func prepare_spec(difficulty_id: String, transaction_id: String,
		transaction_issuer_receipt: Dictionary) -> Dictionary:
	_log(&"prepare_spec", {"difficulty_id": difficulty_id, "transaction_id": transaction_id})
	var armed := _consume_failure("prepare_spec")
	if not armed.is_empty():
		return armed
	if typeof(transaction_issuer_receipt) != TYPE_DICTIONARY or transaction_issuer_receipt.is_empty():
		return {"ok": false, "code": &"invalid_transaction_issuer_receipt", "message": "", "details": {}}
	var identity := {
		"run_id": run_id, "branch_id": branch_id,
		"desktop_timeline_generation": desktop_timeline_generation,
		"causal_day_instance": causal_day_instance, "app_round_ordinal": next_ordinal,
	}
	var spec := _fake_spec_for(difficulty_id, transaction_id)
	return {"ok": true, "code": &"ok", "value": {"identity": identity, "spec": spec}, "receipt": {}}


func prepare_first_reveal(board_candidate: Dictionary, transaction_id: String,
		transaction_issuer_receipt: Dictionary, expected_checkpoint_id: String) -> Dictionary:
	_log(&"prepare_first_reveal", {"transaction_id": transaction_id})
	var armed := _consume_failure("prepare_first_reveal")
	if not armed.is_empty():
		return armed
	if motivation <= 0:
		return {"ok": false, "code": &"insufficient_motivation", "message": "", "details": {}}
	if rounds_left <= round_floor:
		return {"ok": false, "code": &"insufficient_capacity", "message": "", "details": {}}
	if next_ordinal < 1 or next_ordinal > 5:
		return {"ok": false, "code": &"insufficient_capacity", "message": "no eligible ordinal remains", "details": {}}
	var board: Dictionary = board_candidate["board"]
	var layout_view := {
		"schema_version": 1, "width": board["width"], "height": board["height"],
		"mine_indices": board["mine_indices"], "mine_count": board["mine_count"],
	}
	var layout_sha256: String = JSON.stringify(layout_view).sha256_text()
	var receipt := {
		"receipt_id": "board_start.%s" % transaction_id,
		"receipt_provenance": {
			"child_kind": "board_start",
			"parent_receipt_id": str(transaction_issuer_receipt.get("receipt_id", "")),
			"ordinal": 0, "source_ids": [transaction_id],
		},
		"transaction_id": transaction_id,
		"transaction_issuer_receipt": transaction_issuer_receipt.duplicate(true),
		"identity": (board_candidate["identity"] as Dictionary).duplicate(true),
		"difficulty_id": str(board_candidate["difficulty_id"]),
		"first_cell": int(board_candidate["cell_index"]),
		"board_revision": int(board["revision"]),
		"rounds_before": rounds_left, "rounds_after": rounds_left - 1,
		"motivation_before": motivation, "motivation_after": motivation - 1,
		"layout_sha256": layout_sha256,
		"proof_sha256": board_candidate.get("proof_sha256", null),
		"checkpoint_id": expected_checkpoint_id,
	}
	var receipt_keys: Array = receipt.keys()
	receipt_keys.sort()
	var expected_keys := _RECEIPT_KEYS.duplicate()
	expected_keys.sort()
	if receipt_keys != expected_keys:
		return {"ok": false, "code": &"fake_receipt_shape_invalid", "message": "", "details": {}}
	var run_candidate := {
		"transaction_id": transaction_id,
		"rounds_left": rounds_left - 1, "motivation": motivation - 1, "next_ordinal": next_ordinal + 1,
	}
	return {"ok": true, "code": &"ok", "value": {
		"run_candidate": run_candidate, "receipt": receipt.duplicate(true),
		"snapshot_input": {"transaction_id": transaction_id, "run_id": run_id},
		"publication": {"transaction_id": transaction_id, "receipt": receipt.duplicate(true)},
	}, "receipt": {}}


func prepare_board_only(board_candidate: Dictionary, transaction_id: String,
		_transaction_issuer_receipt: Dictionary) -> Dictionary:
	_log(&"prepare_board_only", {"transaction_id": transaction_id})
	var armed := _consume_failure("prepare_board_only")
	if not armed.is_empty():
		return armed
	if typeof(board_candidate) != TYPE_DICTIONARY:
		return {"ok": false, "code": &"invalid_board_candidate", "message": "", "details": {}}
	return {"ok": true, "code": &"ok",
		"value": {"run_candidate": {"transaction_id": transaction_id, "board_only": true}}, "receipt": {}}


func commit(candidate: Dictionary) -> Dictionary:
	_log(&"commit", {})
	var armed := _consume_failure("commit")
	if not armed.is_empty():
		return armed
	if candidate.has("rounds_left"):
		rounds_left = int(candidate["rounds_left"])
	if candidate.has("motivation"):
		motivation = int(candidate["motivation"])
	if candidate.has("next_ordinal"):
		next_ordinal = int(candidate["next_ordinal"])
	return {"ok": true, "code": &"ok", "value": {"committed": true}, "receipt": {}}


func rollback(backup: Dictionary) -> Dictionary:
	_log(&"rollback", {})
	var armed := _consume_failure("rollback")
	if not armed.is_empty():
		return armed
	motivation = int(backup["motivation"])
	rounds_left = int(backup["rounds_left"])
	next_ordinal = int(backup["next_ordinal"])
	return {"ok": true, "code": &"ok", "value": {"restored": true}, "receipt": {}}


func publish(publication: Dictionary) -> Dictionary:
	_log(&"publish", {})
	var armed := _consume_failure("publish")
	if not armed.is_empty():
		return armed
	published.append(publication.duplicate(true))
	return {"ok": true, "code": &"ok", "value": {"published": true}, "receipt": {}}


func _fake_spec_for(difficulty_id: String, transaction_id: String) -> Dictionary:
	return {
		"schema_version": 1, "board_kind": "desktop", "board_token": "board-token.%s" % transaction_id,
		"board_token_receipt_id": "receipt-board.%s" % transaction_id, "difficulty_id": difficulty_id,
		"width": 3, "height": 3, "base_mine_count": 1, "pressure": 3, "penalty_points_today": 0,
		"raw_extra_mines": 1, "requested_mine_count": 1, "capability_ids": ["first_cell_safe"],
		"placement_stream_id": "minesweeper_placement_v1", "placement_nonce": "placement.%s" % transaction_id,
		"placement_nonce_receipt_id": "receipt-placement.%s" % transaction_id,
		"debug_stream_id": "minesweeper_debug_v1", "debug_nonce": "debug.%s" % transaction_id,
		"debug_nonce_receipt_id": "receipt-debug.%s" % transaction_id,
		"explosion_stream_id": "minesweeper_explosion_v1", "explosion_nonce": "explosion.%s" % transaction_id,
		"explosion_nonce_receipt_id": "receipt-explosion.%s" % transaction_id,
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}


func _consume_failure(method_name: String) -> Dictionary:
	if not _fail_next.has(method_name):
		return {}
	var failure: Dictionary = _fail_next[method_name]
	_fail_next.erase(method_name)
	return failure


func _log(method: StringName, argument: Dictionary) -> void:
	call_log.append({"method": method, "argument": argument.duplicate(true)})
