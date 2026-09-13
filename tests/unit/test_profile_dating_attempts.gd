extends "res://addons/gut/test.gd"

const LEDGER := preload("res://scripts/profile/DatingAttemptLedger.gd")
const PROFILE := preload("res://scripts/profile/ProfileSchema.gd")
const MIGRATION := preload("res://scripts/profile/ProfileMigration.gd")
const MANAGER := preload("res://autoload/ProfileManager.gd")
const OWNER := preload("res://scripts/application/run/DatingPhysicalOwner.gd")
const ISSUER := preload("res://scripts/application/desktop/DesktopIdentityNonceIssuer.gd")
const ROOT_STORE := preload("res://tests/support/FakeDesktopIssuerRootStore.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const RULES := preload("res://scripts/application/run/DatingChallengeRules.gd")
const STORAGE := preload("res://scripts/infrastructure/storage/JsonFileStorage.gd")
const OPS := preload("res://tests/support/FakeFileOps.gd")
const GATE := preload("res://scripts/application/transaction/ApplicationMutationGate.gd")
const SLOT := "dating.solo.priscilla.day1"

# These records intentionally exercise persisted v2 history with its original fixed spec.
class LegacySpecState extends RefCounted:
	var inventory: Dictionary = {}
	var penalty_points_today := 0
	func get_stat(_id: String) -> int: return 0

class RejectingStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var reject_write := false
	func _init(root_dir: String, file_ops: RefCounted) -> void:
		super(root_dir, file_ops)
	func write_atomic(relative_path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary:
		if reject_write: return {"ok": false, "code": &"fixture_profile_write_failure"}
		return super.write_atomic(relative_path, text, validator, keep_backup)

func _record() -> Dictionary:
	var issuer := ISSUER.new()
	assert_true(issuer.configure(ROOT_STORE.new("86".repeat(32), 1)).ok)
	var owner := OWNER.new()
	owner._issuer = issuer
	owner._game_state = LegacySpecState.new()
	var spec: Dictionary = owner._make_spec("canonical_solo").value
	return {"schema_version": 2, "completion_transaction_id": "date-completion",
		"command_sha256": "a".repeat(64), "physical_token": owner._token("date-completion", "a".repeat(64)),
		"context": {"kind": "solo", "participants": ["priscilla"], "day": 1},
		"host": "canonical_solo", "spec": spec, "board": null, "phase": "challenge",
		"outcome": null, "applied_result": {}, "pair_form": "", "mine_dispositions": [],
		"relationship_outcome": null, "perfect_reasons": []}

func _materialize(record: Dictionary, index: int = 36) -> Dictionary:
	var next := record.duplicate(true)
	var mines: Array = []
	for cell in 36: mines.append(cell)
	var reduced: Dictionary = REDUCER.first_reveal({"schema_version": 1, "width": 18,
		"height": 18, "mine_indices": mines, "mine_count": 36}, index)
	next.board = reduced.value.board.duplicate(true)
	next.board.outcome = str(next.board.outcome)
	next.mine_dispositions = RULES.dispositions(next.spec, 36)
	if next.board.terminal:
		next.perfect_reasons = RULES.perfect_reasons(next.board, 2)
		next.outcome = "perfect" if not next.perfect_reasons.is_empty() else "cleared"
		next.phase = "cleared_awaiting_terminal_choice"
	return next

func test_entry_is_detached_idempotent_and_cannot_be_replaced_or_rewound() -> void:
	var record := _record()
	var entered: Dictionary = LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", record, 0)
	assert_true(entered.ok, str(entered))
	if not entered.ok: return
	var ledger: Dictionary = entered.value.ledger
	assert_eq(entered.value.attempt.revision, 1)
	var replay: Dictionary = LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-b", record, 0)
	assert_true(replay.ok)
	assert_false(replay.value.changed)
	replay.value.attempt.record.phase = "completed"
	assert_eq(LEDGER.read(ledger, "run-a", SLOT).value.record.phase, "challenge")
	var replacement := record.duplicate(true)
	replacement.spec.placement_nonce = "different-nonce"
	assert_false(LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-a", replacement, 1).ok)
	assert_eq(LEDGER.read(ledger, "run-b", SLOT).value, {})
	assert_eq(record, _record(), "preparation cannot modify its caller's record")

func test_first_cell_layout_and_action_prefix_survive_only_monotonic_progress() -> void:
	var record := _record()
	var ledger: Dictionary = LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", record, 0).value.ledger
	var board := _materialize(record)
	assert_false(board.board.terminal)
	assert_false(LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-a", board, 1).ok,
		"first reveal is absent from reducer actions; its index must be supplied")
	var materialized: Dictionary = LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-a", board, 1, 36)
	assert_true(materialized.ok, str(materialized))
	if not materialized.ok: return
	ledger = materialized.value.ledger
	var flagged := board.duplicate(true)
	flagged.board = REDUCER.set_flag(board.board, 0, true, "flag-one").value.board
	flagged.board.outcome = str(flagged.board.outcome)
	for action: Dictionary in flagged.board.actions: action.kind = str(action.kind)
	var progressed: Dictionary = LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-a", flagged, 2)
	assert_true(progressed.ok, str(progressed))
	if not progressed.ok: return
	assert_eq(progressed.value.attempt.materialization_receipt.first_cell_index, 36)
	assert_false(LEDGER.prepare_update(progressed.value.ledger, "run-a", SLOT, "branch-a", board, 3).ok)
	assert_false(LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-a", flagged, 1).ok)
	assert_false(LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-a", flagged, 2, 37).ok)

func test_painted_terminal_board_awaiting_settlement_is_valid_monotonic_progress() -> void:
	# dwm-634.2: a terminal reveal only paints; a save between the paint and its settlement
	# commits the board with no outcome yet, and settlement then advances it in place.
	var record := _record()
	var ledger: Dictionary = LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", record, 0).value.ledger
	# The bottom corner floods every safe cell, so the first reveal already clears the board.
	var settled := _materialize(record, 323)
	assert_true(settled.board.terminal)
	var unsettled := settled.duplicate(true)
	unsettled.phase = "challenge"
	unsettled.outcome = null
	unsettled.perfect_reasons = []
	var painted: Dictionary = LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-a", unsettled, 1, 323)
	assert_true(painted.ok, str(painted))
	if not painted.ok: return
	assert_eq(LEDGER.read(painted.value.ledger, "run-a", SLOT).value.record.phase, "challenge")
	var progressed: Dictionary = LEDGER.prepare_update(painted.value.ledger, "run-a", SLOT, "branch-a", settled, 2)
	assert_true(progressed.ok, str(progressed))
	var half := unsettled.duplicate(true)
	half.outcome = settled.outcome
	assert_false(LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-a", half, 1, 323).ok,
		"an unsettled board carries no outcome")

func test_clear_and_terminal_choices_are_write_once_without_full_snapshot_history() -> void:
	var record := _record()
	var ledger: Dictionary = LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", record, 0).value.ledger
	var cleared := _materialize(record, 323)
	var clear: Dictionary = LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-a", cleared, 1, 323)
	assert_true(clear.ok, str(clear))
	if not clear.ok: return
	var chosen := cleared.duplicate(true)
	chosen.phase = "settlement_retry"
	chosen.relationship_outcome = "dark"
	var terminal: Dictionary = LEDGER.prepare_update(clear.value.ledger, "run-a", SLOT, "branch-a", chosen, 2)
	assert_true(terminal.ok, str(terminal))
	if not terminal.ok: return
	assert_eq(terminal.value.attempt.clear_receipt, clear.value.attempt.clear_receipt)
	chosen.relationship_outcome = "foresight"
	assert_false(LEDGER.prepare_update(terminal.value.ledger, "run-a", SLOT, "branch-a", chosen, 3).ok)
	assert_false(LEDGER.prepare_update(terminal.value.ledger, "run-a", SLOT, "branch-a", cleared, 3).ok)
	assert_false(terminal.value.attempt.has("revision_history"))

func test_v5_upgrade_adds_empty_ledger_and_preserves_other_profile_facts() -> void:
	var old: Dictionary = PROFILE.make_defaults()
	old.erase("dating_attempts")
	old.schema_version = 5
	old.erase("observer_evidence")
	old.erase("pair_deck_draws")
	old.erase("reached_presentations")
	old.pair_form_witness_receipts = {"pair-presented": "love_dark"}
	var upgraded: Dictionary = MIGRATION.prepare_document(old)
	assert_true(upgraded.ok, str(upgraded))
	if not upgraded.ok: return
	assert_eq(upgraded.value.schema_version, 8)
	assert_eq(upgraded.value.dating_attempts, {})
	assert_eq(upgraded.value.pair_form_witness_receipts, old.pair_form_witness_receipts)
	assert_false(old.has("dating_attempts"))
	old.dating_attempts = {}
	assert_false(MIGRATION.prepare_document(old).ok, "v5 remains a strict source schema")

func test_profile_ahead_record_survives_restart_gallery_clear_and_old_run_patch() -> void:
	var storage := STORAGE.new("profile-dating-attempts", OPS.new())
	var manager := MANAGER.new()
	autofree(manager)
	assert_true(manager.initialize(storage).ok)
	var prepared: Dictionary = manager.prepare_dating_attempt("run-a", SLOT, "branch-a", _record(), 0)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	assert_true(manager.commit_dating_attempt(prepared.value).ok)
	var restarted := MANAGER.new()
	autofree(restarted)
	assert_true(restarted.initialize(storage).ok)
	assert_eq(restarted.get_dating_attempt("run-a", SLOT).value.revision, 1,
		"the Profile commitment survives even when the run Autosave was never written")
	assert_true(restarted.reset_gallery().ok)
	assert_eq(restarted.get_dating_attempt("run-a", SLOT).value.revision, 1)
	assert_eq(restarted.prepare_legacy_profile_patch({}).value.dating_attempts,
		restarted.get_profile_snapshot().dating_attempts)
	assert_true(restarted.reset_entire_profile().ok)
	assert_eq(restarted.get_dating_attempt("run-a", SLOT).value, {})

func test_frozen_effect_and_completion_survive_retry_without_recalculation() -> void:
	var record := _materialize(_record(), 323)
	record.phase = "settlement_retry"
	record.relationship_outcome = "dark"
	var effect := {"terminal_fact": {"transaction_id": "date-completion", "outcome": record.outcome,
		"relationship_outcome": "dark", "perfect_reasons": record.perfect_reasons.duplicate()},
		"relationship_outcome": "dark", "perfect_reasons": record.perfect_reasons.duplicate(),
		"attitude": "close", "outcome": record.outcome, "scene_id": SLOT,
		"momentum_delta": 2, "tone_delta": 1, "progression_evaluated": true,
		"relationship_state": "ambiguous", "ruleset_id": "provisional", "ruleset_status": "provisional"}
	var selected: Dictionary = LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", record, 0, 323, effect)
	assert_true(selected.ok, str(selected))
	if not selected.ok: return
	var post := record.duplicate(true)
	post.phase = "post_challenge"
	post.applied_result = {"replayed": false, "receipt": effect.duplicate(true)}
	var paid: Dictionary = LEDGER.prepare_update(selected.value.ledger, "run-a", SLOT, "branch-a", post, 1)
	assert_true(paid.ok, str(paid))
	if not paid.ok: return
	var changed_effect := effect.duplicate(true)
	changed_effect.momentum_delta = 99
	assert_false(LEDGER.prepare_update(paid.value.ledger, "run-a", SLOT, "branch-a", post, 2, -1, changed_effect).ok)
	post.phase = "completed"
	var completed: Dictionary = LEDGER.prepare_update(paid.value.ledger, "run-a", SLOT, "branch-a", post, 2)
	assert_true(completed.ok, str(completed))
	if not completed.ok: return
	assert_eq(completed.value.attempt.effect_receipt.value, effect)
	assert_false(LEDGER.preserves(completed.value.ledger, selected.value.ledger))
	assert_false(LEDGER.preserves(completed.value.ledger, {}))

func test_commit_requires_causal_custody_and_rejects_stale_profile_preparation() -> void:
	var manager := MANAGER.new()
	autofree(manager)
	assert_true(manager.initialize(STORAGE.new("profile-dating-custody", OPS.new())).ok)
	var gate := GATE.new()
	assert_true(manager.configure_mutation_gate(gate).ok)
	var prepared: Dictionary = manager.prepare_dating_attempt("run-a", SLOT, "branch-a", _record(), 0)
	assert_true(prepared.ok)
	if not prepared.ok: return
	assert_eq(manager.commit_dating_attempt(prepared.value).code, &"dating_attempt_custody_required")
	assert_true(manager.set_preference(&"preferences.audio.music_volume", 0.4).ok)
	var lease: Dictionary = gate.acquire(&"causal_transaction")
	assert_true(lease.ok)
	assert_false(manager.commit_dating_attempt(prepared.value).ok, "unrelated Profile updates cannot be overwritten")
	var fresh: Dictionary = manager.prepare_dating_attempt("run-a", SLOT, "branch-a", _record(), 0)
	assert_true(manager.commit_dating_attempt(fresh.value).ok)
	var revision: int = manager.get_profile_revision()
	var replay: Dictionary = manager.prepare_dating_attempt("run-a", SLOT, "branch-a", _record(), 0)
	assert_true(manager.commit_dating_attempt(replay.value).ok)
	assert_eq(manager.get_profile_revision(), revision)
	assert_true(gate.release(&"causal_transaction", lease.value.token).ok)

func test_closed_slot_identity_and_typed_receipts_reject_fabricated_state() -> void:
	var record := _record()
	record.context.day = 7
	assert_false(LEDGER.prepare_update({}, "run-a", "dating.solo.priscilla.day7", "branch-a", record, 0).ok)
	record = _record()
	var entered: Dictionary = LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", record, 0)
	var invalid: Dictionary = entered.value.ledger.duplicate(true)
	invalid["run-a"][SLOT].attempts[entered.value.attempt.attempt_id].progress_by_branch["branch-a"].revision = 0
	assert_false(LEDGER.validate(invalid).ok)
	invalid = entered.value.ledger.duplicate(true)
	invalid["run-a"][SLOT].attempts[entered.value.attempt.attempt_id].progress_by_branch["branch-a"].terminal_receipt = {"outcome": "perfect"}
	assert_false(LEDGER.validate(invalid).ok)
	invalid = entered.value.ledger.duplicate(true)
	invalid["run-a"][SLOT].attempts[entered.value.attempt.attempt_id].progress_by_branch["branch-a"].record["extra"] = true
	assert_false(LEDGER.validate(invalid).ok)

func test_failed_profile_write_keeps_live_history_and_allows_exact_retry() -> void:
	var storage := RejectingStorage.new("profile-dating-write-failure", OPS.new())
	var manager := MANAGER.new()
	autofree(manager)
	assert_true(manager.initialize(storage).ok)
	var before: Dictionary = manager.get_profile_snapshot()
	var revision: int = manager.get_profile_revision()
	var prepared: Dictionary = manager.prepare_dating_attempt("run-a", SLOT, "branch-a", _record(), 0)
	assert_true(prepared.ok)
	if not prepared.ok: return
	storage.reject_write = true
	assert_eq(manager.commit_dating_attempt(prepared.value).code, &"fixture_profile_write_failure")
	assert_eq(manager.get_profile_snapshot(), before)
	assert_eq(manager.get_profile_revision(), revision)
	storage.reject_write = false
	assert_true(manager.commit_dating_attempt(prepared.value).ok)
	assert_eq(manager.get_dating_attempt("run-a", SLOT).value.revision, 1)
	assert_false(manager.commit_prepared_profile(before).ok, "ordinary Profile writes cannot erase committed attempts")
	assert_false(manager.apply_restore_silent({"profile": before}).ok, "old restore material cannot erase committed attempts")
