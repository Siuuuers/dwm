class_name DesktopFirstRevealSnapshotComposer
extends RefCounted

## Production first-Reveal detached-candidate composer (Plan 02 Task 6, dwm-p2r.32, Phase D, brief
## lines 295/402). PURE: `compose()` never touches live GameState/DesktopBoardState/
## DesktopConsequenceState -- it projects exactly what each object's own `commit()` would install,
## from the exact detached POST-COMMIT candidates `GameStateDesktopBoardPort.
## prepare_first_reveal_consequence()` returns, onto a `base_snapshot_input` capture of what is
## CURRENTLY live (never live state at the moment compose() itself runs, and never anything the
## coordinator has already committed).
##
## `base_snapshot_input` is shaped exactly like `SaveManagerCheckpointPort.prepare()`'s own
## `checkpoint_inputs.snapshot_input` (the established convention throughout this codebase): a
## `{lifecycle, gameplay, contacts, committed_schedule, desktop, dating, applied_effect_transaction_
## ids, applied_variable_transaction_ids}`-shaped dict, captured via GameState.capture_run_snapshot_
## input() BEFORE first Reveal prepares anything. `compose()` returns that SAME shape with only
## `gameplay.minesweeper_rounds_left`/`gameplay.motivation` (read off `game_state_candidate`) and
## `desktop.board`/`desktop.consequence` (projected from `board_candidate`/`consequence_candidate`)
## overwritten -- everything else (contacts, committed_schedule, other gameplay fields) survives
## byte-for-byte, since first Reveal touches nothing else.
##
## DESIGN CHOICE, not literally frozen by the brief (documented per this task's own established
## precedent for underspecified members): `consequence_candidate` here is the lightweight
## `{"expected_run_revision": int}` marker `GameStateDesktopBoardPort.prepare_first_reveal_
## consequence()` emits (first Reveal never opens a DesktopConsequenceState pending transaction --
## no causal-sequence admission is involved), so this composer copies `desktop.consequence` from
## `base_snapshot_input` UNCHANGED and only asserts its `run_revision` still equals the candidate's
## `expected_run_revision` -- "matching consequence revision" (brief Step 6.10) rather than a content
## change.

const _GAME_STATE_CANDIDATE_KEYS: Array[String] = ["transaction_id", "motivation", "rounds_left", "starts_today"]
const _BOARD_CANDIDATE_KEYS: Array[String] = [
	"kind", "transaction_id", "request_fingerprint", "identity_fingerprint", "pre_revision",
	"phase_after", "identity_after", "candidate_after", "board_after", "settlement_after",
]
const _SNAPSHOT_INPUT_KEYS: Array[String] = [
	"lifecycle", "gameplay", "contacts", "committed_schedule", "desktop", "dating",
	"applied_effect_transaction_ids", "applied_variable_transaction_ids", "command_receipts",
]


static func compose(base_snapshot_input: Dictionary, game_state_candidate: Dictionary,
		board_candidate: Dictionary, consequence_candidate: Dictionary) -> Dictionary:
	var base_shape := _exact_keys(base_snapshot_input, _SNAPSHOT_INPUT_KEYS, &"invalid_base_snapshot_input")
	if not base_shape.get("ok", false):
		return base_shape
	var game_shape := _exact_keys(game_state_candidate, _GAME_STATE_CANDIDATE_KEYS, &"invalid_game_state_candidate")
	if not game_shape.get("ok", false):
		return game_shape
	var board_shape := _exact_keys(board_candidate, _BOARD_CANDIDATE_KEYS, &"invalid_board_candidate")
	if not board_shape.get("ok", false):
		return board_shape
	if typeof(consequence_candidate.get("expected_run_revision")) != TYPE_INT:
		return _fail(&"invalid_consequence_candidate", "consequence_candidate.expected_run_revision must be an integer")
	if typeof(board_candidate.get("board_after")) != TYPE_DICTIONARY:
		return _fail(&"invalid_board_candidate", "a first-Reveal board candidate requires board_after")
	if str(board_candidate["kind"]) != "first_reveal":
		return _fail(&"invalid_board_candidate", "compose() accepts only a first_reveal board candidate")
	if str(board_candidate["transaction_id"]) != str(game_state_candidate["transaction_id"]):
		return _fail(&"first_reveal_candidate_transaction_mismatch",
			"game_state_candidate and board_candidate must share one transaction_id")

	var base_desktop: Dictionary = base_snapshot_input["desktop"]
	var desktop_shape := _exact_keys(base_desktop, ["board", "consequence"], &"invalid_base_snapshot_input")
	if not desktop_shape.get("ok", false):
		return desktop_shape
	if typeof(base_desktop.get("board")) != TYPE_DICTIONARY or typeof(base_desktop.get("consequence")) != TYPE_DICTIONARY:
		return _fail(&"invalid_base_snapshot_input", "base_snapshot_input.desktop.{board,consequence} are required")
	var base_consequence: Dictionary = base_desktop["consequence"]
	if int(base_consequence.get("run_revision", -1)) != int(consequence_candidate["expected_run_revision"]):
		return _fail(&"first_reveal_candidate_revision_mismatch",
			"consequence_candidate.expected_run_revision no longer matches the base consequence state")

	var projected_board := _project_board(base_desktop["board"], board_candidate)
	if not projected_board.get("ok", false):
		return projected_board

	var composed: Dictionary = base_snapshot_input.duplicate(true)
	var gameplay: Dictionary = (composed["gameplay"] as Dictionary).duplicate(true)
	if typeof(gameplay.get("stats")) != TYPE_DICTIONARY:
		return _fail(&"invalid_base_snapshot_input", "base_snapshot_input.gameplay.stats is required")
	var stats: Dictionary = (gameplay["stats"] as Dictionary).duplicate(true)
	stats["motivation"] = int(game_state_candidate["motivation"])
	gameplay["stats"] = stats
	gameplay["minesweeper_rounds_left"] = int(game_state_candidate["rounds_left"])
	composed["gameplay"] = gameplay
	var desktop: Dictionary = base_desktop.duplicate(true)
	desktop["board"] = (projected_board["value"] as Dictionary)["board"]
	composed["desktop"] = desktop
	return {"ok": true, "code": &"ok", "value": {"snapshot_input": composed}}


## Pure projection of what `DesktopBoardState.commit(board_candidate)` would install, given the
## board's CURRENT capture (`base_board`) -- mirrors that method's own field-by-field behavior
## exactly (scripts/domain/minesweeper/DesktopBoardState.gd `commit()`), without mutating any live
## object. `command_receipts` gains the one new transaction entry; `terminal_receipts` is untouched
## (first Reveal never produces terminal truth).
static func _project_board(base_board: Dictionary, candidate: Dictionary) -> Dictionary:
	if int(candidate["pre_revision"]) != int(base_board.get("revision", -1)):
		return _fail(&"first_reveal_candidate_stale_revision",
			"board_candidate.pre_revision no longer matches the base board's revision")
	var receipts: Dictionary = (base_board.get("command_receipts", {}) as Dictionary).duplicate(true)
	var post_revision := int(candidate["pre_revision"]) + 1
	var board_after: Dictionary = candidate["board_after"]
	receipts[str(candidate["transaction_id"])] = {
		"request_fingerprint": str(candidate["request_fingerprint"]),
		"identity_fingerprint": str(candidate["identity_fingerprint"]),
		"pre_revision": int(candidate["pre_revision"]), "post_revision": post_revision,
		"command_kind": str(candidate["kind"]),
		"result": {
			"phase": str(candidate["phase_after"]), "revision": post_revision,
			"identity": candidate.get("identity_after"), "candidate": candidate.get("candidate_after"),
			"board": board_after.duplicate(true), "settlement": candidate.get("settlement_after"),
		},
	}
	return {"ok": true, "value": {"board": {
		"schema_version": 1, "phase": str(candidate["phase_after"]), "revision": post_revision,
		"identity": candidate.get("identity_after"), "candidate": candidate.get("candidate_after"),
		"board": board_after.duplicate(true), "settlement": candidate.get("settlement_after"),
		"command_receipts": receipts,
		"terminal_receipts": (base_board.get("terminal_receipts", {}) as Dictionary).duplicate(true),
	}}}


static func _exact_keys(value: Dictionary, expected: Array[String], code: StringName) -> Dictionary:
	if typeof(value) != TYPE_DICTIONARY:
		return _fail(code, "expected an object")
	var keys: Array = value.keys()
	keys.sort()
	var sorted_expected := expected.duplicate()
	sorted_expected.sort()
	if keys != sorted_expected:
		return _fail(code, "unexpected keys: " + str(keys))
	return {"ok": true}


static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": {}}
