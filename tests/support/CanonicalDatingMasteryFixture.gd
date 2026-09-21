extends RefCounted
## Test-only physical board/effect evidence, validated and persisted by the real Profile owner.
const MASTERY := preload("res://scripts/domain/ending/CanonicalDatingMastery.gd")
const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")
const OWNER := preload("res://scripts/application/run/DatingPhysicalOwner.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const RULES := preload("res://scripts/application/run/DatingChallengeRules.gd")

# Specs use the neutral capability/condition inputs required by the fixed board below.
class SpecState extends RefCounted:
	var inventory: Dictionary:
		get: return {}
	var penalty_points_today: int:
		get: return 0
	func get_stat(_stat: String) -> int:
		return 0

class Game extends "res://autoload/GameState.gd":
	var mastery_profile: Node = null
	var mastery_lookups: Array[Dictionary] = []
	func _prepare_day7_ending_plan(source: Dictionary, reader: Callable = Callable(), profile_reader: Callable = Callable()) -> Dictionary:
		return super._prepare_day7_ending_plan(source, _read_attempt if mastery_profile != null else reader, mastery_profile.get_profile_snapshot if mastery_profile != null else profile_reader)
	func _read_attempt(run_id: String, slot: String, attempt_id: String, branch_id: String) -> Dictionary:
		mastery_lookups.append({"run_id": run_id, "slot_id": slot,
			"attempt_id": attempt_id, "branch_id": branch_id})
		return mastery_profile.get_dating_attempt(run_id, slot, attempt_id, branch_id)

static func completed(run_id: String, scope: String, day: int, branch: String = "original-progress",
		outcome: String = "perfect") -> Dictionary:
	var pair := scope == "priscilla_lavinia"
	var host := "canonical_pair" if pair else "canonical_solo"
	var issuer := ISSUER.new()
	var configured: Dictionary = issuer.configure(ROOT.new((run_id + scope + str(day) + branch + outcome).sha256_text(), 1))
	if not configured.ok: return configured
	var owner := OWNER.new()
	owner._issuer = issuer
	owner._game_state = SpecState.new()
	var made: Dictionary = owner._make_spec(host)
	if not made.ok: return made
	var transaction := "completed-%s-%d" % [scope, day]
	var first_cell := 323 if outcome == "perfect" else 36
	var mines: Array = []
	for cell in 36: mines.append(cell)
	var layout := {"schema_version": 1, "width": 18, "height": 18, "mine_indices": mines, "mine_count": 36}
	var materialized: Dictionary = REDUCER.first_reveal(layout, first_cell)
	if not materialized.ok: return materialized
	var board: Dictionary = materialized.value.board
	if outcome == "cleared":
		board = REDUCER.set_flag(board, 0, true, transaction + ":flag").value.board
		board = REDUCER.reveal(board, 323, transaction + ":solve").value.board
	elif outcome == "exploded":
		board = REDUCER.reveal(board, 0, transaction + ":explode").value.board
	board.outcome = str(board.outcome)
	for action: Dictionary in board.actions: action.kind = str(action.kind)
	var context := {"kind": ("group" if day == 2 else "twofriends_if_deferred") if pair else "solo",
		"participants": ["priscilla", "lavinia"] if pair else [scope], "day": day}
	var slot: String = LEDGER.semantic_slot(context)
	var dispositions: Array = [] if pair else RULES.dispositions(made.value, 36)
	var relationship: Variant = null if pair else (dispositions[0] if outcome == "exploded" else "dark")
	var record := {"schema_version": 2, "completion_transaction_id": transaction,
		"command_sha256": "a".repeat(64), "physical_token": owner._token(transaction, "a".repeat(64)),
		"context": context, "host": host, "spec": made.value, "board": board, "phase": "completed",
		"outcome": outcome, "applied_result": {"board_only": true} if pair else {},
		"pair_form": "love_sweet" if pair else "", "mine_dispositions": dispositions,
		"relationship_outcome": relationship, "perfect_reasons": RULES.perfect_reasons(board)}
	var effect := {}
	if not pair:
		effect = {"terminal_fact": {"transaction_id": transaction, "outcome": outcome,
			"relationship_outcome": relationship, "perfect_reasons": record.perfect_reasons.duplicate()},
			"relationship_outcome": relationship, "perfect_reasons": record.perfect_reasons.duplicate(),
			"attitude": "close", "outcome": outcome, "scene_id": slot,
			"momentum_delta": 2, "tone_delta": 1, "progression_evaluated": true,
			"relationship_state": "ambiguous", "ruleset_id": "provisional", "ruleset_status": "provisional"}
		record.applied_result = {"replayed": false, "receipt": effect.duplicate(true)}
	return LEDGER.prepare_update({}, run_id, slot, branch, record, 0, first_cell, effect)

static func for_scope(run_id: String, scope: String, branch: String = "original-progress") -> Dictionary:
	var heads := {}
	var attempts := {}
	var ledger := {run_id: {}}
	for day: int in MASTERY.WINDOWS.get(scope, []):
		var made := completed(run_id, scope, day, branch)
		if not made.ok: return made
		var attempt: Dictionary = made.value.attempt
		heads[attempt.slot_id] = {"attempt_id": attempt.attempt_id, "branch_id": attempt.branch_id}
		attempts[attempt.slot_id] = attempt
		ledger[run_id][attempt.slot_id] = made.value.ledger[run_id][attempt.slot_id]
	return {"ok": true, "value": {"heads": heads, "attempts": attempts, "ledger": ledger}}

static func profile_for_scope(game: Node, scope: String) -> Dictionary:
	var evidence := for_scope(str(game._run_lifecycle.to_dict().run_id), scope)
	if not evidence.ok: return evidence
	var profile: Node = preload("res://autoload/ProfileManager.gd").new()
	var initialized: Dictionary = profile.initialize(preload("res://scripts/infrastructure/storage/JsonFileStorage.gd").new(
		"mastery-profile", preload("res://tests/support/FakeFileOps.gd").new()))
	if not initialized.ok:
		profile.free()
		return initialized
	var candidate: Dictionary = profile.get_profile_snapshot()
	candidate.dating_attempts = evidence.value.ledger
	var committed: Dictionary = profile.commit_prepared_profile(candidate)
	if not committed.ok:
		profile.free()
		return committed
	game.route_context["dating_canonical_heads"] = evidence.value.heads
	game.mastery_profile = profile
	return {"ok": true, "value": {"profile": profile, "evidence": evidence.value}}
