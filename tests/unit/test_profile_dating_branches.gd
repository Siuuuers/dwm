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

class RejectingStorage extends "res://scripts/infrastructure/storage/JsonFileStorage.gd":
	var reject_write := false
	func _init(root_dir: String, file_ops: RefCounted) -> void:
		super(root_dir, file_ops)
	func write_atomic(relative_path: String, text: String, validator: Callable, keep_backup: bool = true) -> Dictionary:
		if reject_write: return {"ok": false, "code": &"fixture_profile_write_failure"}
		return super.write_atomic(relative_path, text, validator, keep_backup)

func _record(seed_hex: String = "86") -> Dictionary:
	var issuer := ISSUER.new()
	assert_true(issuer.configure(ROOT_STORE.new(seed_hex.repeat(32), 1)).ok)
	var owner := OWNER.new()
	owner._issuer = issuer
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
		next.perfect_reasons = RULES.perfect_reasons(next.board)
		next.outcome = "perfect" if not next.perfect_reasons.is_empty() else "cleared"
		next.phase = "cleared_awaiting_terminal_choice"
	return next

func _flag(record: Dictionary, index: int, event_id: String) -> Dictionary:
	var result := record.duplicate(true)
	result.board = REDUCER.set_flag(record.board, index, true, event_id).value.board
	result.board.outcome = str(result.board.outcome)
	for action: Dictionary in result.board.actions: action.kind = str(action.kind)
	return result

func test_v6_migration_retains_original_attempt_progress_and_receipts() -> void:
	var record := _materialize(_record(), 323)
	var flat: Dictionary = LEDGER._prepare_flat({}, "run-a", SLOT, "branch-a", record, 0, 323).value.ledger
	var old := PROFILE.make_defaults()
	old.schema_version = 6
	old.erase("observer_evidence")
	old.erase("pair_deck_draws")
	old.erase("reached_presentations")
	old.dating_attempts = flat
	var before := old.duplicate(true)
	var migrated := MIGRATION.prepare_document(old)
	assert_true(migrated.ok, str(migrated))
	if not migrated.ok: return
	assert_eq(migrated.value.schema_version, 8)
	var restored: Dictionary = LEDGER.read(migrated.value.dating_attempts, "run-a", SLOT).value
	var original: Dictionary = flat["run-a"][SLOT].duplicate(true)
	original["generation"] = 1
	assert_eq(restored, original)
	assert_eq(old, before)
	old.dating_attempts["run-a"][SLOT]["generation"] = 1
	assert_false(MIGRATION.prepare_document(old).ok, "v6 source rejects v7-only fields")
	assert_false(PROFILE.validate(before).ok, "current validation does not silently accept v6")

func test_fresh_entries_append_generations_and_default_lookup_keeps_first_lock() -> void:
	var first := _record()
	var entered := LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", first, 0)
	var fresh := _record("89")
	var second := LEDGER.prepare_update(entered.value.ledger, "run-a", SLOT, "branch-b", fresh, 0, -1, {}, {"mode": "fresh"})
	assert_true(second.ok, str(second))
	if not second.ok: return
	assert_eq(second.value.attempt.generation, 2)
	assert_eq(LEDGER.read(second.value.ledger, "run-a", SLOT).value, entered.value.attempt)
	assert_eq(LEDGER.read(second.value.ledger, "run-a", SLOT, fresh.spec.board_token, "branch-b").value, second.value.attempt)
	assert_true(LEDGER.preserves(entered.value.ledger, second.value.ledger))
	assert_false(LEDGER.preserves(second.value.ledger, entered.value.ledger))
	var replay := LEDGER.prepare_update(second.value.ledger, "run-a", SLOT, "branch-b", fresh, 0, -1, {}, {"mode": "fresh"})
	assert_true(replay.ok)
	assert_false(replay.value.changed)
	assert_false(LEDGER.prepare_update(second.value.ledger, "run-a", SLOT, "branch-c", fresh, 0, -1, {}, {"mode": "fresh"}).ok)
	assert_false(LEDGER.prepare_update(second.value.ledger, "run-a", SLOT, "branch-c", _materialize(_record("90")), 0, 36, {}, {"mode": "fresh"}).ok)
	assert_false(LEDGER.read(second.value.ledger, "run-a", SLOT, fresh.spec.board_token, "missing").ok)
	assert_false(LEDGER.read({}, "run-a", SLOT, fresh.spec.board_token, "missing").ok)

func test_copied_midboard_keeps_exact_saved_progress_and_original_first_cell() -> void:
	var saved := _materialize(_record())
	var initial := LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", saved, 0, 36)
	var parent_record := _flag(saved, 0, "parent-flag")
	var parent := LEDGER.prepare_update(initial.value.ledger, "run-a", SLOT, "branch-a", parent_record, 1)
	var preview := LEDGER.prepare_continuation(parent.value.ledger, "run-a", SLOT,
		saved.spec.board_token, "branch-a", "branch-b", saved)
	assert_true(preview.ok, str(preview))
	if not preview.ok: return
	assert_eq(preview.value.attempt.record, saved)
	assert_eq(preview.value.attempt.materialization_receipt.first_cell_index, 36)
	assert_eq(preview.value.expected_revision, 0)
	assert_false(LEDGER.read(parent.value.ledger, "run-a", SLOT, saved.spec.board_token, "branch-b").ok)
	var branch_record := _flag(saved, 1, "branch-flag")
	var copied := LEDGER.prepare_update(parent.value.ledger, "run-a", SLOT, "branch-b", branch_record,
		0, -1, {}, preview.value.selection)
	assert_true(copied.ok, str(copied))
	if not copied.ok: return
	assert_eq(copied.value.attempt.revision, 1)
	assert_eq(copied.value.attempt.generation, 1)
	assert_eq(copied.value.attempt.record.board.flagged_indices, [1])
	assert_eq(LEDGER.read(copied.value.ledger, "run-a", SLOT).value, parent.value.attempt)
	assert_true(LEDGER.preserves(parent.value.ledger, copied.value.ledger))
	var retry := LEDGER.prepare_update(copied.value.ledger, "run-a", SLOT, "branch-b", branch_record,
		0, -1, {}, preview.value.selection)
	assert_true(retry.ok)
	assert_false(retry.value.changed)
	assert_false(LEDGER.prepare_update(copied.value.ledger, "run-a", SLOT, "branch-b", saved,
		1, -1, {}, {"mode": "branch"}).ok, "the copied branch itself remains monotonic")
	preview.value.attempt.record.board.flagged_indices.append(99)
	assert_eq(LEDGER.read(copied.value.ledger, "run-a", SLOT, saved.spec.board_token, "branch-b").value.record.board.flagged_indices, [1])

func test_entered_unmaterialized_save_does_not_import_later_first_click() -> void:
	var saved := _record()
	var parent := LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", _materialize(saved), 0, 36)
	var preview := LEDGER.prepare_continuation(parent.value.ledger, "run-a", SLOT,
		saved.spec.board_token, "branch-a", "branch-b", saved)
	assert_true(preview.ok, str(preview))
	if not preview.ok: return
	assert_null(preview.value.attempt.record.board)
	assert_null(preview.value.attempt.materialization_receipt)
	var copied := LEDGER.prepare_update(parent.value.ledger, "run-a", SLOT, "branch-b", _materialize(saved, 323),
		0, 323, {}, preview.value.selection)
	assert_true(copied.ok, str(copied))
	if not copied.ok: return
	assert_eq(copied.value.attempt.materialization_receipt.first_cell_index, 323)
	assert_eq(LEDGER.read(copied.value.ledger, "run-a", SLOT).value.materialization_receipt.first_cell_index, 36)

func test_terminal_choices_are_independent_across_saved_continuations_but_frozen_within_each() -> void:
	var saved := _materialize(_record(), 323)
	var parent_record := saved.duplicate(true)
	parent_record.phase = "settlement_retry"
	parent_record.relationship_outcome = "dark"
	var parent := LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", parent_record, 0, 323)
	var preview := LEDGER.prepare_continuation(parent.value.ledger, "run-a", SLOT,
		saved.spec.board_token, "branch-a", "branch-b", saved)
	assert_true(preview.ok, str(preview))
	if not preview.ok: return
	assert_null(preview.value.attempt.terminal_receipt)
	assert_null(preview.value.attempt.effect_receipt)
	var chosen := saved.duplicate(true)
	chosen.phase = "settlement_retry"
	chosen.relationship_outcome = "foresight"
	var branch := LEDGER.prepare_update(parent.value.ledger, "run-a", SLOT, "branch-b", chosen,
		0, -1, {}, preview.value.selection)
	assert_true(branch.ok, str(branch))
	if not branch.ok: return
	assert_eq(branch.value.attempt.terminal_receipt.relationship_outcome, "foresight")
	assert_eq(LEDGER.read(branch.value.ledger, "run-a", SLOT).value.terminal_receipt.relationship_outcome, "dark")
	assert_false(LEDGER.prepare_update(branch.value.ledger, "run-a", SLOT, "branch-b", parent_record,
		1, -1, {}, {"mode": "branch"}).ok)
	assert_false(LEDGER.prepare_continuation(parent.value.ledger, "run-a", SLOT,
		saved.spec.board_token, "branch-a", "branch-c", chosen).ok, "a fabricated source terminal is not the selected source's prefix")

func test_profile_continuation_is_milestone_gated_and_first_action_write_is_atomic() -> void:
	var storage := RejectingStorage.new("profile-dating-branches", OPS.new())
	var manager := MANAGER.new()
	autofree(manager)
	assert_true(manager.initialize(storage).ok)
	var saved := _materialize(_record())
	var entered := manager.prepare_dating_attempt("run-a", SLOT, "branch-a", saved, 0, 36)
	assert_true(manager.commit_dating_attempt(entered.value).ok)
	assert_eq(manager.prepare_dating_continuation("run-a", SLOT, saved.spec.board_token,
		"branch-a", "branch-b", saved).code, &"dating_replacement_locked")
	assert_eq(manager.prepare_dating_attempt("run-a", SLOT, "branch-b", _record("89"),
		0, -1, {}, {"mode": "fresh"}).code, &"dating_replacement_locked")
	assert_true(manager.unlock_ending("ending.alone", "ending:fixture:gallery:ending.alone").ok)
	var preview := manager.prepare_dating_continuation("run-a", SLOT, saved.spec.board_token,
		"branch-a", "branch-b", saved)
	assert_true(preview.ok, str(preview))
	if not preview.ok: return
	var gate := GATE.new()
	assert_true(manager.configure_mutation_gate(gate).ok)
	var action := manager.prepare_dating_attempt("run-a", SLOT, "branch-b", _flag(saved, 1, "branch-action"),
		0, -1, {}, preview.value.selection)
	assert_true(action.ok, str(action))
	if not action.ok: return
	assert_eq(manager.commit_dating_attempt(action.value).code, &"dating_attempt_custody_required")
	var lease := gate.acquire(&"causal_transaction")
	assert_true(lease.ok)
	var before := manager.get_profile_snapshot()
	storage.reject_write = true
	assert_eq(manager.commit_dating_attempt(action.value).code, &"fixture_profile_write_failure")
	assert_eq(manager.get_profile_snapshot(), before)
	assert_false(manager.get_dating_attempt("run-a", SLOT, saved.spec.board_token, "branch-b").ok)
	storage.reject_write = false
	assert_true(manager.commit_dating_attempt(action.value).ok)
	var revision: int = manager.get_profile_revision()
	assert_true(manager.commit_dating_attempt(action.value).ok)
	assert_eq(manager.get_profile_revision(), revision)
	assert_true(gate.release(&"causal_transaction", lease.value.token).ok)
	var restarted := MANAGER.new()
	autofree(restarted)
	assert_true(restarted.initialize(storage).ok)
	assert_eq(restarted.get_dating_attempt("run-a", SLOT, saved.spec.board_token, "branch-b").value.record.board.flagged_indices, [1])
	assert_true(restarted.reset_gallery().ok)
	assert_true(restarted.has_completed_ending())
	assert_true(restarted.get_dating_attempt("run-a", SLOT, saved.spec.board_token, "branch-b").ok)
	assert_true(restarted.reset_entire_profile().ok)
	assert_eq(restarted.get_dating_attempt("run-a", SLOT).value, {})

func test_branch_shape_rejects_missing_history_changed_generations_and_unknown_fields() -> void:
	var record := _record()
	var entered := LEDGER.prepare_update({}, "run-a", SLOT, "branch-a", record, 0)
	var ledger: Dictionary = entered.value.ledger
	var invalid := ledger.duplicate(true)
	invalid["run-a"][SLOT].attempts[record.spec.board_token].generation = 2
	assert_false(LEDGER.validate(invalid).ok)
	invalid = ledger.duplicate(true)
	invalid["run-a"][SLOT].attempts[record.spec.board_token].progress_by_branch.erase("branch-a")
	assert_false(LEDGER.validate(invalid).ok)
	assert_false(LEDGER.preserves(ledger, invalid))
	invalid = ledger.duplicate(true)
	invalid["run-a"][SLOT]["head"] = record.spec.board_token
	assert_false(LEDGER.validate(invalid).ok, "canonical heads belong to the saved branch, not global Profile state")
	assert_false(LEDGER.prepare_update(ledger, "run-a", SLOT, "missing", record, 0,
		-1, {}, {"mode": "branch"}).ok)
	assert_false(LEDGER.prepare_update(ledger, "run-a", SLOT, "branch-a", record, 1,
		-1, {}, {"mode": "branch", "extra": true}).ok)
