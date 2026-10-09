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
	old.erase("reached_presentation_chronology")
	old.erase("witnessed_caption_variants")
	old.pair_form_witness_receipts = {"pair-presented": "love_dark"}
	var upgraded: Dictionary = MIGRATION.prepare_document(old)
	assert_true(upgraded.ok, str(upgraded))
	if not upgraded.ok: return
	assert_eq(upgraded.value.schema_version, PROFILE.SCHEMA_VERSION)
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

const SCENE_ENVELOPE := preload("res://scripts/application/run/DatingChallengeEnvelope.gd")
const SCENE_GENERATOR := preload("res://scripts/domain/minesweeper/MinesweeperBoardGenerator.gd")
const SCENE_HASH := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")

func _scene_record(debug: bool = false) -> Dictionary:
	var source: Dictionary = _record()
	if debug:
		var state := LegacySpecState.new()
		state.inventory = {"debug_key": 1}
		var issuer := ISSUER.new()
		assert_true(issuer.configure(ROOT_STORE.new("86".repeat(32), 1)).ok)
		var owner := OWNER.new()
		owner._issuer = issuer
		owner._game_state = state
		source.spec = owner._make_spec("canonical_solo").value
	var result := {"schema_version": 4, "completion_transaction_id": source.completion_transaction_id,
		"command_sha256": source.command_sha256, "physical_token": source.physical_token,
		"context": {"kind": "scene_challenge", "scene_occurrence": "scene-test-occurrence",
			"challenge_id": "test-challenge", "playable_command_id": "test-playable", "registration_sha256": "b".repeat(64)},
		"host": "scene_challenge", "spec": source.spec, "board": null,
		"envelope": SCENE_ENVELOPE.make(), "phase": "ready", "state": "in_progress", "applied_result": {}}
	if debug:
		var begun: Dictionary = SCENE_GENERATOR.begin_debug(result.spec)
		assert_true(begun.ok, str(begun))
		result.phase = "preparing"
		result.envelope.preparation = SCENE_ENVELOPE.plain_frontier(begun.value.preparation).value
	return result

func _scene_materialize(record: Dictionary, index: int) -> Dictionary:
	var result := record.duplicate(true)
	var mines: Array = []
	for cell in 36: mines.append(cell)
	var reduced: Dictionary = REDUCER.first_reveal({"schema_version": 1, "width": 18,
		"height": 18, "mine_indices": mines, "mine_count": 36}, index)
	result.board = SCENE_ENVELOPE.plain_frontier(reduced.value.board).value
	result.envelope.special_cell = SCENE_ENVELOPE.special_cell(result.spec, result.board)
	result.phase = "terminal" if result.board.terminal else "active"
	result.state = ("lost" if result.board.outcome == "exploded" else "won") if result.board.terminal else "in_progress"
	return result

func _scene_proof(attempt: Dictionary) -> Dictionary:
	return {"run_id": attempt.run_id, "slot_id": attempt.slot_id, "attempt_id": attempt.attempt_id,
		"branch_id": attempt.branch_id, "generation": attempt.generation, "revision": attempt.revision,
		"record_sha256": SCENE_HASH.canonical_sha256(attempt.record).value.sha256,
		"checkpoint": {"checkpoint_id": "source-checkpoint", "checkpoint_sequence": 2, "snapshot_sha256": "c".repeat(64)}}

func test_scene_entry_has_one_attempt_and_exact_family_without_legacy_effects() -> void:
	var record := _scene_record()
	var slot: String = LEDGER.semantic_slot(record.context)
	assert_true(slot.begins_with("scene.challenge."))
	var entered: Dictionary = LEDGER.prepare_update({}, "run-scene", slot, "branch-a", record, 0, -1, {}, {"mode": "fresh"})
	assert_true(entered.ok, str(entered))
	if not entered.ok: return
	assert_eq(entered.value.attempt.entry_receipt.keys().size(), 4)
	assert_eq(entered.value.attempt.entry_receipt.record_version, 4)
	assert_null(entered.value.attempt.effect_receipt)
	var forged := record.duplicate(true)
	forged.spec.board_token += ".replacement"
	assert_false(LEDGER.prepare_update(entered.value.ledger, "run-scene", slot, "branch-a", forged, 0, -1, {}, {"mode": "fresh"}).ok)
	forged = record.duplicate(true)
	forged.spec.board_kind = "desktop"
	forged.spec.difficulty_id = "beginner"
	assert_false(LEDGER.validate_record(forged))
	forged = record.duplicate(true)
	forged.schema_version = 4.0
	assert_false(LEDGER.validate_record(forged))
	forged = record.duplicate(true)
	forged.context.kind = &"scene_challenge"
	assert_false(LEDGER.validate_record(forged))
	assert_false(LEDGER.prepare_update({}, "run-scene", slot, "branch-a", record, 0, -1, {"legacy_effect": true}).ok)
	var legacy := _record()
	legacy.context = record.context.duplicate(true)
	assert_false(LEDGER.validate_record(legacy), "scene slot derivation cannot admit a legacy record family")

func test_scene_selected_prefix_is_committed_to_new_branch_without_ending_unlock() -> void:
	var manager := MANAGER.new()
	autofree(manager)
	assert_true(manager.initialize(STORAGE.new("scene-prefix-profile", OPS.new())).ok)
	assert_false(manager.has_completed_ending())
	var ready := _scene_record()
	var slot: String = LEDGER.semantic_slot(ready.context)
	var entered: Dictionary = manager.prepare_dating_attempt("scene-run", slot, "branch-a", ready, 0)
	assert_true(entered.ok, str(entered))
	if not entered.ok: return
	assert_true(manager.commit_dating_attempt(entered.value).ok)
	var terminal := _scene_materialize(ready, 323)
	assert_eq(terminal.state, "won")
	var progressed: Dictionary = manager.prepare_dating_attempt("scene-run", slot, "branch-a", terminal, 1, 323, {}, {"mode": "branch"})
	assert_true(progressed.ok, str(progressed))
	if not progressed.ok: return
	assert_true(manager.commit_dating_attempt(progressed.value).ok)
	var original: Dictionary = manager.get_dating_attempt("scene-run", slot, ready.spec.board_token, "branch-a").value
	var proof := _scene_proof(original)
	var preview: Dictionary = manager.prepare_dating_continuation("scene-run", slot, ready.spec.board_token, "branch-a", "branch-b", ready)
	assert_true(preview.ok, str(preview))
	if not preview.ok: return
	assert_eq(preview.value.attempt.record, ready, "selected prefix does not import Profile-ahead terminal state")
	var copied: Dictionary = manager.prepare_dating_attempt("scene-run", slot, "branch-b", ready, 0, -1, {}, preview.value.selection)
	assert_true(copied.ok, str(copied))
	if not copied.ok: return
	assert_true(manager.commit_dating_attempt(copied.value).ok)
	assert_eq(manager.get_dating_attempt("scene-run", slot, ready.spec.board_token, "branch-b").value.record, ready)
	assert_eq(manager.get_dating_attempt("scene-run", slot, ready.spec.board_token, "branch-a").value, original)
	assert_true(LEDGER.resolve_attempt_proof(manager.get_profile_snapshot().dating_attempts, proof).ok)
	assert_false(manager.prepare_dating_attempt("scene-run", slot, "branch-a", ready, 2, -1, {}, {"mode": "branch"}).ok,
		"same-operation branch cannot rewind its terminal history")

func test_scene_proof_resolves_exact_original_branch_revision_and_hash() -> void:
	var record := _scene_materialize(_scene_record(), 323)
	var slot: String = LEDGER.semantic_slot(record.context)
	var prepared: Dictionary = LEDGER.prepare_update({}, "scene-run", slot, "original", record, 0, 323)
	assert_true(prepared.ok, str(prepared))
	if not prepared.ok: return
	var proof := _scene_proof(prepared.value.attempt)
	assert_true(LEDGER.resolve_attempt_proof(prepared.value.ledger, proof).ok)
	assert_false(prepared.value.attempt.terminal_receipt.perfect_reasons.is_empty(), "Perfect detail is retained")
	for key: String in ["revision", "generation"]:
		var bad := proof.duplicate(true)
		bad[key] += 1
		assert_false(LEDGER.resolve_attempt_proof(prepared.value.ledger, bad).ok)
	for key: String in ["run_id", "slot_id", "attempt_id", "branch_id", "record_sha256"]:
		var bad := proof.duplicate(true)
		bad[key] += "x"
		assert_false(LEDGER.resolve_attempt_proof(prepared.value.ledger, bad).ok)
	var extra := proof.duplicate(true)
	extra.checkpoint["confirmed"] = true
	assert_false(LEDGER.resolve_attempt_proof(prepared.value.ledger, extra).ok)
	assert_false(LEDGER.validate_attempt_proof(prepared.value.attempt, extra).ok)
	var changed := record.duplicate(true)
	changed.state = "in_progress"
	changed.phase = "active"
	assert_false(LEDGER.validate_record(changed), "terminal state is derived in the same physical boundary")

func test_scene_preparing_prefix_replays_generator_and_freezes_only_entry_spec() -> void:
	var preparing := _scene_record(true)
	assert_true(LEDGER.validate_record(preparing))
	var slot: String = LEDGER.semantic_slot(preparing.context)
	var entered: Dictionary = LEDGER.prepare_update({}, "scene-run", slot, "branch-a", preparing, 0)
	assert_true(entered.ok, str(entered))
	if not entered.ok: return
	var current: Dictionary = preparing.envelope.preparation
	while str(current.status) == "searching":
		var advanced: Dictionary = SCENE_GENERATOR.run_debug_slice(current)
		assert_true(advanced.ok, str(advanced))
		if not advanced.ok: return
		current = SCENE_ENVELOPE.plain_frontier(advanced.value.preparation).value
	assert_eq(str(current.status), "certified")
	if str(current.status) != "certified": return
	var ready := preparing.duplicate(true)
	ready.phase = "ready"
	ready.envelope.preparation = null
	ready.envelope.prepared_layout = {"schema_version": 1, "width": ready.spec.width, "height": ready.spec.height,
		"mine_count": current.candidate_state.mine_count, "mine_indices": current.candidate_state.mine_indices}
	ready.envelope.forced_cell = current.forced_cell
	ready.envelope.special_cell = SCENE_ENVELOPE.special_cell(ready.spec, ready.envelope.prepared_layout)
	var finished: Dictionary = LEDGER.prepare_update(entered.value.ledger, "scene-run", slot, "branch-a", ready, 1)
	assert_true(finished.ok, str(finished))
	if not finished.ok: return
	assert_eq(finished.value.attempt.entry_receipt, entered.value.attempt.entry_receipt)
	var preview: Dictionary = LEDGER.prepare_continuation(finished.value.ledger, "scene-run", slot,
		preparing.spec.board_token, "branch-a", "branch-b", preparing)
	assert_true(preview.ok, str(preview))
	if preview.ok: assert_eq(preview.value.attempt.record, preparing)
	var forged := preparing.duplicate(true)
	forged.envelope.preparation.operations_used += 1
	assert_false(LEDGER.validate_record(forged), "structurally valid lower counters do not prove a generator prefix")
	assert_false(LEDGER.prepare_continuation(finished.value.ledger, "scene-run", slot,
		preparing.spec.board_token, "branch-a", "branch-c", forged).ok)
	forged = ready.duplicate(true)
	forged.envelope.prepared_layout.mine_indices.reverse()
	assert_false(LEDGER.validate_record(forged), "a changed layout is not the certified deterministic result")
