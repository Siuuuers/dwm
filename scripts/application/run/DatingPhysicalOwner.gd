class_name DatingPhysicalOwner
extends RefCounted
## Retained physical owner for one Schedule dating challenge. Board truth is reducer-owned;
## GameState stores the active record so a mid-date save resumes without replaying rewards.

const CATALOG := preload("res://scripts/domain/minesweeper/MinesweeperBoardCatalog.gd")
const SCHEMA := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const CANONICAL := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const PROFILE_SCHEMA := preload("res://scripts/profile/ProfileSchema.gd")
const ENVELOPE := preload("res://scripts/application/run/DatingChallengeEnvelope.gd")
const CAPABILITIES := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")
const RULES := preload("res://scripts/application/run/DatingChallengeRules.gd")
const ATTEMPTS := preload("res://scripts/profile/DatingAttemptLedger.gd")
const PRESENTATION_SIGNATURE := preload("res://scripts/domain/narrative/PresentationSignature.gd")
const OBSERVER_RULES := preload("res://scripts/domain/relationship/ProvisionalProgressionRules.gd")
const OWNER_KIND := "dating_challenge"
const PHASES := ["pre_challenge", "preparing", "challenge", "cleared_awaiting_terminal_choice", "settlement_retry", "post_challenge", "completed"]
const RECORD_KEYS := ["applied_result", "board", "command_sha256", "completion_transaction_id",
	"context", "host", "mine_dispositions", "outcome", "pair_form", "perfect_reasons", "phase",
	"physical_token", "relationship_outcome", "schema_version", "spec"]

signal physical_completion_ready(receipt: Dictionary)
signal physical_completion_failed(failure: Dictionary)

var _issuer: Object
var _game_state: Object
var _profile: Object
var _generation: Object
var _record: Dictionary = {}
var _checkpoint_writer: Callable
var _admitted_command: Dictionary = {}
var _attempt_gate: Object
var _first_cell_index := -1
var _pending_checkpoint: Dictionary = {}
var _history_selection: Dictionary = {}
var _history_reference: Dictionary = {}
var _history_revision := 0
var _history_committed := false
var _history_target_branch := ""

## Production actions own a short causal lease. The stage owner still admits begin_physical.
func configure_attempt_history(gate: Object) -> Dictionary:
	if gate == null or not gate.has_method("acquire") or not gate.has_method("release"):
		return _fail(&"invalid_dating_attempt_gate")
	for method: String in ["get_dating_attempt", "prepare_dating_attempt", "commit_dating_attempt", "prepare_dating_continuation", "has_completed_ending"]:
		if not _profile.has_method(method): return _fail(&"invalid_dating_attempt_profile")
	for method: String in ["capture_run_snapshot_input", "prepare_dating_challenge_effect", "apply_dating_challenge_effect_receipt"]:
		if not _game_state.has_method(method): return _fail(&"invalid_dating_attempt_state")
	if _attempt_gate != null and _attempt_gate != gate: return _fail(&"dating_attempt_gate_conflict")
	_attempt_gate = gate
	return _ok({})


func configure(identity_issuer: Object, game_state: Object, profile: Object,
		generation_port: Object) -> Dictionary:
	if not is_instance_valid(identity_issuer) or not identity_issuer.has_method("issue") \
			or not is_instance_valid(game_state) \
			or not game_state.has_method("capture_dating_challenge_state") \
			or not game_state.has_method("store_dating_challenge_state") \
			or not game_state.has_method("apply_dating_challenge_result") \
			or not is_instance_valid(profile) or not profile.has_method("record_pair_form_witness") \
			or not is_instance_valid(generation_port) or not generation_port.has_method("materialize"):
		return _fail(&"invalid_dating_owner_dependency")
	if _issuer != null:
		if [_issuer,_game_state,_profile,_generation] == [identity_issuer,game_state,profile,generation_port]:
			return _ok({"already_configured":true})
		return _fail(&"dating_owner_already_configured")
	_issuer=identity_issuer; _game_state=game_state; _profile=profile; _generation=generation_port
	return _ok({"already_configured":false})

func owner_kind() -> String:
	return OWNER_KIND

func configure_checkpoint_writer(writer: Callable) -> Dictionary:
	if not writer.is_valid() or _game_state == null \
			or not _game_state.has_method("capture_restore_state") \
			or not _game_state.has_method("rollback_restore_silent"):
		return _fail(&"invalid_dating_checkpoint_writer")
	if _checkpoint_writer.is_valid() and _checkpoint_writer != writer:
		return _fail(&"dating_checkpoint_writer_already_configured")
	_checkpoint_writer = writer
	return _ok({})

func begin_physical(command: Dictionary) -> Dictionary:
	var result: Dictionary = _with_checkpoint(_begin_physical.bind(command), false, false)
	if result.get("ok", false):
		_admitted_command = command.duplicate(true)
		var source: Variant = _game_state.route_context.get("dating_observer_source")
		if source is Dictionary:
			# A saved proof is not proof that this newly admitted view has rendered.
			# Window progress and durable receipts remain unchanged, including same-token Load.
			source["rendered"] = false
			source["playback_token"] = ""
			source["comparison_shown"] = false
	return result

func _begin_physical(command: Dictionary) -> Dictionary:
	if _issuer == null: return _fail(&"dating_owner_unconfigured")
	var completion_id := str(command.get("completion_transaction_id",""))
	var command_hash := str(command.get("command_sha256",""))
	if completion_id.is_empty() or command_hash.is_empty() or not command.get("context") is Dictionary:
		return _fail(&"invalid_presentation_command")
	var token := _token(completion_id,command_hash)
	var captured: Dictionary = _game_state.capture_dating_challenge_state()
	if not captured.get("ok",false): return captured
	var stored: Dictionary = captured.value
	if not stored.is_empty() and (str(stored.get("completion_transaction_id", "")) == completion_id 			or (_attempt_gate != null and stored.get("context") is Dictionary and not ATTEMPTS.semantic_slot(stored.context).is_empty() and ATTEMPTS.semantic_slot(stored.context) == ATTEMPTS.semantic_slot(command.context))):
		if not _valid_record(stored, {}): return _fail(&"invalid_restored_dating_challenge")
		_record = _rebind_record(stored, command)
		if not _valid_record(_record, command): return _fail(&"invalid_restored_dating_challenge")
		_pending_checkpoint = {}
		if _attempt_gate != null and _record.phase not in ["pre_challenge", "preparing"]:
			var resumed: Dictionary = _restore_attempt(command)
			if not resumed.get("ok", false): return resumed
		var frozen: Dictionary = _freeze_pre_challenge_presentation()
		if not frozen.ok: return frozen
		var post_frozen: Dictionary = _freeze_post_challenge_presentation()
		if not post_frozen.ok: return post_frozen
		var saved: Dictionary = _game_state.store_dating_challenge_state(_record)
		if not saved.get("ok", false): return saved
		return _ok({"physical_token":token,"command_sha256":command_hash})
	if not stored.is_empty() and str(stored.get("phase","")) != "completed":
		return _fail(&"dating_challenge_already_active")
	var context: Dictionary = command.context
	var host := "canonical_solo" if str(context.get("kind","")) == "solo" else "canonical_pair"
	var spec := _make_spec(host)
	if not spec.get("ok",false): return spec
	var pair_form := ""
	if host == "canonical_pair":
		pair_form=str(_game_state.inter_friend_route_state.get("priscilla_lavinia",{}).get("frozen_form",""))
		if pair_form not in PROFILE_SCHEMA.PAIR_FORMS: return _fail(&"invalid_dating_pair_form")
	_clear_history_state()
	if _attempt_gate != null: _game_state.route_context.erase("dating_active_attempt_ref")
	_record={"schema_version":3,"envelope":ENVELOPE.make(),"completion_transaction_id":completion_id,"command_sha256":command_hash,
		"physical_token":token,"context":context.duplicate(true),"host":host,"spec":spec.value,
		"board":null,"phase":"pre_challenge","outcome":null,"applied_result":{},"pair_form":pair_form,
		"mine_dispositions":[],"relationship_outcome":null,"perfect_reasons":[]}
	var frozen: Dictionary = _freeze_pre_challenge_presentation()
	if not frozen.ok: return frozen
	var saved: Dictionary = _game_state.store_dating_challenge_state(_record)
	if not saved.get("ok",false): _record={}; return saved
	return _ok({"physical_token":token,"command_sha256":command_hash})

func pull_physical(physical_token: String) -> Dictionary:
	if not _adopt(physical_token): return _fail(&"dating_challenge_unavailable")
	return _ok(_view())

func dispatch_physical(physical_token: String, action: String, cell_index: int,
		expected_revision: int) -> Dictionary:
	if _attempt_gate == null:
		return _with_checkpoint(_dispatch_physical.bind(physical_token, action, cell_index, expected_revision), true)
	var acquired: Dictionary = _attempt_gate.acquire(&"causal_transaction")
	if not acquired.get("ok", false): return acquired
	_first_cell_index = -1
	var result: Dictionary
	if not _pending_checkpoint.is_empty():
		if physical_token != _pending_checkpoint.physical_token or action != "retry":
			result = _fail(&"dating_checkpoint_retry_required")
		else:
			result = _retry_checkpoint()
	else:
		result = _with_checkpoint(_dispatch_physical.bind(physical_token, action, cell_index, expected_revision), false)
	var released: Dictionary = _attempt_gate.release(&"causal_transaction", str(acquired.value.token))
	if not released.get("ok", false): return released
	# Completion can synchronously start the next stage, so release our action lease first.
	if result.get("ok", false) and _record.get("phase") == "completed":
		physical_completion_ready.emit(_completion_receipt())
	return result

func _dispatch_physical(physical_token: String, action: String, cell_index: int,
		expected_revision: int) -> Dictionary:
	if not _adopt(physical_token): return _fail(&"dating_challenge_unavailable")
	var observer_pending: Variant = _game_state.route_context.get("dating_observer_source")
	if observer_pending is Dictionary and observer_pending.get("checkpoint_pending", false) and observer_pending.get("run_id") == str(_attempt_identity().run_id) and _record.get("phase") == "pre_challenge":
		return _fail(&"observer_checkpoint_retry_required")
	# A later restore participant can roll GameState back without touching this retained
	# owner's local preview. Rebuild that preview from the live branch before accepting input.
	if _post_ending_history() and _record.phase not in ["pre_challenge", "preparing"] and (
			_history_target_branch != str(_attempt_identity().branch_id)
			or _history_reference.get("attempt_id") != _record.spec.board_token):
		var rebound: Dictionary = _restore_attempt(_record, true)
		if not rebound.get("ok", false): return rebound
	var view := _view()
	if expected_revision != _revision() or action not in view.actions:
		return _fail(&"dating_challenge_command_refused",view)
	match _record.phase:
		"pre_challenge":
			if action != "continue": return _fail(&"dating_challenge_command_refused",view)
			if _post_ending_history():
				# The saved preliminary presentation spec is not an entered board. A fresh
				# boundary burns fresh nonces; Load already allocated this branch identity.
				var fresh: Dictionary = _make_spec(str(_record.host))
				if not fresh.get("ok", false): return fresh
				_record.spec = fresh.value
				_clear_history_state()
				_history_selection = {"mode": "fresh"}
			if _record.schema_version == 3:
				_record.envelope = ENVELOPE.make()
				if _record.spec.capability_ids.has("forced_no_guess"):
					if not _generation.has_method("begin_search") or not _generation.has_method("run_search_slice"):
						return _fail(&"dating_preparation_unavailable")
					var begun: Dictionary = _generation.begin_search(_record.spec)
					if not begun.get("ok", false): return begun
					var plain: Dictionary = ENVELOPE.plain_frontier(begun.value.frontier)
					if not plain.get("ok", false): return plain
					_record.envelope.preparation = plain.value
					_record.phase = "preparing"
				else: _record.phase = "challenge"
			else: _record.phase = "challenge"
			if _record.phase == "challenge" and _attempt_gate != null and not _post_ending_history():
				var resumed: Dictionary = _restore_attempt(_admitted_command)
				if not resumed.get("ok", false): return resumed
		"preparing":
			var prepared: Dictionary = _advance_preparation()
			if not prepared.get("ok", false): return prepared
		"challenge":
			var changed := _board_action(action,cell_index)
			if not changed.get("ok",false): return changed
		"cleared_awaiting_terminal_choice":
			if _record.schema_version == 3:
				if action == "activate" and cell_index != int(_record.envelope.special_cell):
					return _fail(&"dating_special_cell_mismatch")
				if action == "continue" and cell_index != -1: return _fail(&"dating_challenge_command_refused")
			_record.relationship_outcome = "dark" if action in ["special_mine", "activate"] else (
				"foresight" if _record.outcome == "perfect" else "loved")
			var chosen: Dictionary = _settle_terminal()
			if not chosen.get("ok", false): return chosen
		"settlement_retry":
			if action != "retry": return _fail(&"dating_challenge_command_refused",view)
			var retried := _settle_terminal()
			if not retried.get("ok",false): return retried
		"post_challenge":
			if action != "continue": return _fail(&"dating_challenge_command_refused",view)
			var completed := _complete_post()
			if not completed.get("ok",false): return completed
			return _ok(_view())
		"completed":
			if action != "resume_completion": return _fail(&"dating_challenge_command_refused",view)
			return _ok(view)
	if _attempt_gate == null:
		var frozen: Dictionary = _freeze_post_challenge_presentation()
		if not frozen.ok: return frozen
	var saved: Dictionary = _game_state.store_dating_challenge_state(_record)
	if not saved.get("ok",false): return saved
	return _ok(_view())

func _with_checkpoint(operation: Callable, publish_completion: bool, commit_history: bool = true) -> Dictionary:
	var backup: Dictionary = {}
	var prior: Dictionary = _record.duplicate(true)
	var prior_history := _history_state()
	if _checkpoint_writer.is_valid():
		var captured: Dictionary = _game_state.capture_restore_state()
		if not captured.get("ok", false): return captured
		backup = captured.value.backup.duplicate(true)
		var physical: Dictionary = _game_state.capture_dating_challenge_state()
		if not physical.get("ok", false): return physical
		prior = physical.value.duplicate(true)
	var result: Dictionary = operation.call()
	if _checkpoint_writer.is_valid():
		var changed: bool = _record != prior
		# A frozen terminal selection whose effect failed must remain retryable across restart.
		var retain_retry: bool = changed and str(_record.get("phase", "")) == "settlement_retry"
		if not result.get("ok", false) and not retain_retry:
			_game_state.rollback_restore_silent(backup)
			_record = prior
			_restore_history_state(prior_history)
			return result
		if changed:
			if commit_history and _attempt_gate != null and _record.get("phase") not in ["pre_challenge", "preparing"]:
				var committed: Dictionary = _commit_attempt()
				if not committed.get("ok", false):
					_game_state.rollback_restore_silent(backup)
					_record = prior
					_restore_history_state(prior_history)
					return committed
				var reconciled: Dictionary = _apply_record_effect()
				if not reconciled.get("ok", false):
					_pending_checkpoint = _record.duplicate(true)
					var rollback: Dictionary = _rollback_run_preserving_retry(backup)
					if not rollback.get("ok", false): return rollback
					return reconciled
			var saved: Dictionary = _checkpoint_writer.call(_record.duplicate(true))
			if not saved.get("ok", false):
				if _attempt_gate != null and _record.get("phase") not in ["pre_challenge", "preparing"]:
					_pending_checkpoint = _record.duplicate(true)
				var rollback: Dictionary = _rollback_run_preserving_retry(backup) if not _pending_checkpoint.is_empty() else _game_state.rollback_restore_silent(backup)
				_record = prior
				if not rollback.get("ok", false): return rollback
				return saved
	if result.get("ok", false) and publish_completion and _record.get("phase") == "completed":
		physical_completion_ready.emit(_completion_receipt())
	return result


## Transaction-local owner state only; never serialized in Run/Profile documents.
## GameState fences this backup by live session before asking us to restore it.
func capture_reconciliation_state() -> Dictionary:
	return _ok({"owner_id": get_instance_id(), "record": _record.duplicate(true),
		"admitted_command": _admitted_command.duplicate(true), "pending_checkpoint": _pending_checkpoint.duplicate(true),
		"first_cell_index": _first_cell_index, "history": _history_state()})

func rollback_reconciliation_silent(backup: Dictionary) -> Dictionary:
	var keys: Array = backup.keys()
	keys.sort()
	if keys != ["admitted_command", "first_cell_index", "history", "owner_id", "pending_checkpoint", "record"] \
			or typeof(backup.owner_id) != TYPE_INT or backup.owner_id != get_instance_id() \
			or typeof(backup.first_cell_index) != TYPE_INT or not backup.record is Dictionary \
			or not backup.admitted_command is Dictionary or not backup.pending_checkpoint is Dictionary \
			or not backup.history is Dictionary:
		return _fail(&"invalid_dating_reconciliation_backup")
	for candidate: Dictionary in [backup.record, backup.pending_checkpoint]:
		if not candidate.is_empty() and not _valid_record(candidate, {}):
			return _fail(&"invalid_dating_reconciliation_backup")
	var history: Dictionary = backup.history
	keys = history.keys()
	keys.sort()
	if keys != ["committed", "reference", "revision", "selection", "target_branch"] \
			or typeof(history.committed) != TYPE_BOOL or typeof(history.revision) != TYPE_INT \
			or not history.reference is Dictionary or not history.selection is Dictionary \
			or not history.target_branch is String:
		return _fail(&"invalid_dating_reconciliation_backup")
	_record = backup.record.duplicate(true)
	_admitted_command = backup.admitted_command.duplicate(true)
	_pending_checkpoint = backup.pending_checkpoint.duplicate(true)
	_first_cell_index = int(backup.first_cell_index)
	_restore_history_state(history)
	return _ok({})

## Profile has already committed this move. Roll back gameplay to its checkpoint, then
## retain this new exact retry payload instead of restoring the older local owner backup.
func _rollback_run_preserving_retry(backup: Dictionary) -> Dictionary:
	var retained: Dictionary = capture_reconciliation_state().value
	var rolled: Dictionary = _game_state.rollback_restore_silent(backup)
	if not rolled.get("ok", false): return rolled
	return rollback_reconciliation_silent(retained)

## Called by the run restore participant after the final remapped snapshot is installed.
## The participant's full backup covers rollback; no Profile write or domain signal occurs here.
func reconcile_restore_silent(restored_snapshot: Dictionary) -> Dictionary:
	if _attempt_gate == null: return _ok({})
	var snapshot: Dictionary = _game_state.capture_run_snapshot_input()
	var route_context: Dictionary = snapshot.gameplay.get("route_context", {})
	var stored: Dictionary = route_context.get("active_dating_challenge", {})
	_pending_checkpoint = {}
	_clear_history_state()
	if stored.is_empty() or stored.get("phase") in ["pre_challenge", "preparing"] \
			or int(stored.get("context", {}).get("day", 0)) != int(snapshot.lifecycle.day) \
			or str(restored_snapshot.get("route_id", "")) != "dating": return _ok({})
	if not _valid_record(stored, {}): return _fail(&"invalid_restored_dating_challenge")
	_record = stored.duplicate(true)
	return _restore_attempt(stored, true)

func _attempt_identity() -> Dictionary:
	return _game_state.capture_run_snapshot_input().lifecycle

func _rebind_record(record: Dictionary, command: Dictionary) -> Dictionary:
	var rebound := record.duplicate(true)
	if ATTEMPTS.semantic_slot(record.context) == ATTEMPTS.semantic_slot(command.context):
		rebound["context"] = command.context.duplicate(true)
	rebound["completion_transaction_id"] = str(command.completion_transaction_id)
	rebound["command_sha256"] = str(command.command_sha256)
	rebound["physical_token"] = _token(rebound.completion_transaction_id, rebound.command_sha256)
	return rebound

func _post_ending_history() -> bool:
	return _attempt_gate != null and _profile.has_completed_ending()

func _history_state() -> Dictionary:
	return {"selection": _history_selection.duplicate(true), "reference": _history_reference.duplicate(true),
		"revision": _history_revision, "committed": _history_committed, "target_branch": _history_target_branch}

func _restore_history_state(value: Dictionary) -> void:
	_history_selection = value.selection.duplicate(true)
	_history_reference = value.reference.duplicate(true)
	_history_revision = int(value.revision)
	_history_committed = bool(value.committed)
	_history_target_branch = str(value.target_branch)

func _clear_history_state() -> void:
	_history_selection = {}
	_history_reference = {}
	_history_revision = 0
	_history_committed = false
	_history_target_branch = ""

func _select_committed_attempt(attempt: Dictionary) -> void:
	_history_reference = {"attempt_id": attempt.attempt_id, "branch_id": attempt.branch_id,
		"generation": attempt.generation}
	_history_revision = int(attempt.revision)
	_history_committed = true
	_history_target_branch = str(_attempt_identity().branch_id)
	_history_selection = {"mode": "branch"} if _post_ending_history() else {}

func _restore_attempt(command: Dictionary, silent: bool = false, certified_entry: bool = false) -> Dictionary:
	var identity := _attempt_identity()
	var run_id := str(identity.run_id)
	var slot := ATTEMPTS.semantic_slot(_record.context)
	if not _post_ending_history():
		var first: Dictionary = _profile.get_dating_attempt(run_id, slot)
		if not first.get("ok", false): return first
		if first.value.is_empty():
			_clear_history_state()
			return _ok({})
		_select_committed_attempt(first.value)
		_record = _rebind_record(first.value.record, command)
		return _apply_record_effect(silent)
	var attempt_id := str(_record.spec.board_token)
	var branch_id := str(identity.branch_id)
	# A same-branch Profile-ahead write is a recovery, not a selected older-save fork.
	# Selected Load already allocates a new branch, so it cannot hit sibling progress here.
	var current: Dictionary = _profile.get_dating_attempt(run_id, slot, attempt_id, branch_id)
	if current.get("ok", false):
		_select_committed_attempt(current.value)
		_record = _rebind_record(current.value.record, command)
		return _apply_record_effect(silent)
	var reference: Variant = _game_state.route_context.get("dating_active_attempt_ref", {})
	if not reference is Dictionary: return _fail(&"invalid_dating_attempt_reference")
	var source: Dictionary
	if reference.is_empty():
		# v6 active saves predate explicit pointers; their board ID resolves its original branch.
		source = _profile.get_dating_attempt(run_id, slot, attempt_id)
	else:
		var keys: Array = reference.keys()
		keys.sort()
		if keys != ["attempt_id", "branch_id", "generation"] or reference.get("attempt_id") != attempt_id \
				or not reference.get("branch_id") is String or typeof(reference.get("generation")) != TYPE_INT:
			return _fail(&"invalid_dating_attempt_reference")
		source = _profile.get_dating_attempt(run_id, slot, attempt_id, reference.branch_id)
		if source.get("ok", false) and source.value.generation != reference.generation:
			return _fail(&"invalid_dating_attempt_reference")
	if not source.get("ok", false):
		# A saved search has not entered Profile history yet. Certification after Load
		# admits this exact frozen spec; any existing branch history above still wins.
		if certified_entry and reference.is_empty() and str(current.get("code", "")) == "dating_attempt_missing" \
				and str(source.get("code", "")) == "dating_attempt_missing" \
				and _record.schema_version == 3 and _record.phase == "challenge" \
				and _record.board == null and _record.envelope.prepared_layout != null:
			_clear_history_state()
			_history_selection = {"mode": "fresh"}
			return _ok({})
		return source
	var selected_record := _record.duplicate(true)
	selected_record["context"] = source.value.record.context.duplicate(true)
	var preview: Dictionary = _profile.prepare_dating_continuation(run_id, slot, attempt_id,
		str(source.value.branch_id), branch_id, selected_record)
	if not preview.get("ok", false): return preview
	_history_selection = preview.value.selection.duplicate(true)
	_history_reference = {"attempt_id": attempt_id, "branch_id": branch_id,
		"generation": preview.value.attempt.generation}
	_history_target_branch = branch_id
	_history_revision = int(preview.value.expected_revision)
	_history_committed = false
	# Keep the saved source reference until a canonical action durably creates this progress.
	# The record and effects remain exactly those in the selected save, not the parent's latest.
	return _game_state.store_dating_challenge_state(_record, not silent)

func _commit_attempt() -> Dictionary:
	var identity := _attempt_identity()
	var run_id := str(identity.run_id)
	var slot := ATTEMPTS.semantic_slot(_record.context)
	var retained_record := _record.duplicate(true)
	var selection := _history_selection.duplicate(true)
	var expected_revision := _history_revision
	var branch_id := str(identity.branch_id)
	if not _post_ending_history():
		var first: Dictionary = _profile.get_dating_attempt(run_id, slot)
		if not first.get("ok", false): return first
		if not first.value.is_empty(): retained_record["context"] = first.value.record.context.duplicate(true)
		expected_revision = int(first.value.get("revision", 0))
		selection = {}
	elif selection.get("mode") == "continue":
		retained_record["context"] = selection.saved_record.context.duplicate(true)
	elif _history_committed:
		branch_id = str(_history_reference.branch_id)
		var current: Dictionary = _profile.get_dating_attempt(run_id, slot,
			str(_history_reference.attempt_id), branch_id)
		if not current.get("ok", false): return current
		retained_record["context"] = current.value.record.context.duplicate(true)
		selection = {"mode": "branch"}
	else:
		if selection.get("mode") != "fresh": return _fail(&"dating_attempt_selection_required")
	var effect: Dictionary = _record.applied_result.get("receipt", {}) if _record.host == "canonical_solo" else {}
	var prepared: Dictionary = _profile.prepare_dating_attempt(run_id, slot, branch_id,
		retained_record, expected_revision, _first_cell_index, effect, selection)
	if not prepared.get("ok", false): return prepared
	var committed: Dictionary = _profile.commit_dating_attempt(prepared.value)
	if committed.get("ok", false): _select_committed_attempt(committed.value.attempt)
	return committed

func _publish_history_reference() -> Dictionary:
	if not _history_committed or _history_reference.is_empty(): return _ok({})
	_game_state.route_context["dating_active_attempt_ref"] = _history_reference.duplicate(true)
	if _record.phase == "completed":
		var heads: Variant = _game_state.route_context.get("dating_canonical_heads", {})
		if not heads is Dictionary: return _fail(&"invalid_dating_canonical_heads")
		var candidate: Dictionary = heads.duplicate(true)
		candidate[ATTEMPTS.semantic_slot(_record.context)] = {
			"attempt_id": _history_reference.attempt_id, "branch_id": _history_reference.branch_id}
		_game_state.route_context["dating_canonical_heads"] = candidate
	return _ok({})

func _apply_record_effect(silent: bool = false) -> Dictionary:
	if _record.host == "canonical_solo" and not _record.applied_result.is_empty():
		var applied: Dictionary = _game_state.apply_dating_challenge_effect_receipt(_entry(),
			_record.applied_result.receipt, not silent)
		if not applied.get("ok", false): return applied
	var published := _publish_history_reference()
	if not published.get("ok", false): return published
	var frozen: Dictionary = _freeze_post_challenge_presentation()
	if not frozen.ok: return frozen
	# Preserve the frozen physical receipt, including its original replay marker.
	return _game_state.store_dating_challenge_state(_record, not silent)

func _retry_checkpoint() -> Dictionary:
	var captured: Dictionary = _game_state.capture_restore_state()
	if not captured.get("ok", false): return captured
	_record = _pending_checkpoint.duplicate(true)
	var applied := _apply_record_effect()
	if not applied.get("ok", false):
		_game_state.rollback_restore_silent(captured.value.backup)
		return applied
	var saved: Dictionary = _checkpoint_writer.call(_record.duplicate(true))
	if not saved.get("ok", false):
		_game_state.rollback_restore_silent(captured.value.backup)
		return saved
	_pending_checkpoint = {}
	return _ok(_view())

func validate_physical_completion(request: Dictionary) -> Dictionary:
	if not request.get("presentation_command") is Dictionary \
			or not request.get("physical_completion_receipt") is Dictionary: return _fail(&"invalid_completion_request")
	var command: Dictionary=request.presentation_command
	var receipt: Dictionary=request.physical_completion_receipt
	if not _adopt(str(command.get("physical_token",""))) or _record.phase != "completed":
		return _fail(&"physical_completion_untrusted")
	if not _valid_record(_record, command) or receipt != _completion_receipt(): return _fail(&"physical_completion_untrusted")
	return _ok({"validated":true,"owner_kind":OWNER_KIND})

func _advance_preparation() -> Dictionary:
	var advanced: Dictionary = _generation.run_search_slice(_record.envelope.preparation)
	if not advanced.get("ok", false): return advanced
	if not bool(advanced.value.done):
		var plain: Dictionary = ENVELOPE.plain_frontier(advanced.value.frontier)
		if not plain.get("ok", false): return plain
		_record.envelope.preparation = plain.value
		return _ok({})
	_record.envelope.prepared_layout = advanced.value.layout.duplicate(true)
	_record.envelope.forced_cell = int(advanced.value.forced_cell)
	_record.envelope.special_cell = ENVELOPE.special_cell(_record.spec, advanced.value.layout)
	_record.envelope.preparation = null
	_record.phase = "challenge"
	if not ENVELOPE.validate(_record): return _fail(&"invalid_dating_prepared_candidate")
	if _attempt_gate != null: return _restore_attempt(_admitted_command, false, true)
	return _ok({})

func _board_action(action: String, index: int) -> Dictionary:
	var projected: Dictionary = _project_board()
	if index < 0 or index >= projected.cells.size() or action not in projected.cells[index].actions:
		return _fail(&"dating_challenge_action_unavailable")
	var reduced: Dictionary
	if _record.board == null:
		if _record.schema_version == 3 and action in ["flag", "unflag"]:
			var issued: Dictionary = _issuer.issue(&"transaction_id")
			if not issued.get("ok", false): return issued
			var marked: Dictionary = REDUCER.set_shell_flag(_record.envelope.shell, int(_record.spec.width),
				int(_record.spec.height), index, action == "flag", str(issued.value.token))
			if not marked.get("ok", false): return marked
			_record.envelope.shell = marked.value.shell.duplicate(true)
			return _ok({})
		var generated: Dictionary
		if _record.schema_version == 3 and _record.envelope.prepared_layout != null:
			if index != int(_record.envelope.forced_cell): return _fail(&"dating_forced_cell_mismatch")
			generated = _ok({"layout": _record.envelope.prepared_layout})
		else: generated = _generation.materialize(_record.spec, index)
		if not generated.get("ok", false): return generated
		if not generated.get("value") is Dictionary or not generated.value.get("layout") is Dictionary:
			return _fail(&"invalid_dating_layout")
		var layout: Dictionary = generated.value.layout
		if not SCHEMA.validate_layout(layout, _record.spec).get("ok", false):
			return _fail(&"invalid_dating_layout")
		# Same frozen explosion stream and one independent draw per sorted mine as the generator.
		_record.mine_dispositions = RULES.dispositions(_record.spec, layout.mine_indices.size()) \
			if _record.host == "canonical_solo" else []
		_first_cell_index = index
		if _record.schema_version == 3:
			_record.envelope.special_cell = ENVELOPE.special_cell(_record.spec, layout)
			reduced = REDUCER.first_reveal(layout, index, _record.envelope.shell)
		else: reduced = REDUCER.first_reveal(layout, index)
	else:
		var issued: Dictionary = _issuer.issue(&"transaction_id")
		if not issued.get("ok", false): return issued
		var transaction_id: String = str(issued.value.token)
		match action:
			"reveal": reduced = REDUCER.reveal(_record.board, index, transaction_id)
			"flag", "unflag": reduced = REDUCER.set_flag(_record.board, index, action == "flag", transaction_id)
			"chord": reduced = REDUCER.chord(_record.board, index, transaction_id)
			_: return _fail(&"dating_challenge_action_unavailable")
	if not reduced.get("ok", false): return reduced
	_record.board = reduced.value.board.duplicate(true)
	_record.board.outcome = str(_record.board.outcome)
	for entry: Dictionary in _record.board.actions: entry.kind = str(entry.kind)
	if not bool(_record.board.terminal): return _ok({})
	_record.perfect_reasons = RULES.perfect_reasons(_record.board, int(_record.schema_version))
	_record.outcome = "exploded" if str(_record.board.outcome) == "exploded" else (
		"cleared" if _record.perfect_reasons.is_empty() else "perfect")
	if _record.host == "canonical_pair":
		# Pair board truth is observation/mastery only; pair closure already owns its semantics.
		_record.applied_result = {"board_only": true}
		_record.phase = "post_challenge"
		return _ok({})
	if _record.schema_version == 3 and _record.outcome == "perfect":
		_record.relationship_outcome = "foresight"
		return _settle_terminal()
	if _record.outcome != "exploded":
		_record.phase = "cleared_awaiting_terminal_choice"
		return _ok({})
	var mine_ordinal: int = _record.board.mine_indices.find(_record.board.exploded_index)
	_record.relationship_outcome = _record.mine_dispositions[mine_ordinal]
	return _settle_terminal()

func _settle_terminal() -> Dictionary:
	# Persist the selected terminal fact before applying effects, so retries never offer a second
	# choice. GameState checks the exact fact under this one completion transaction on replay.
	_record.phase = "settlement_retry"
	var frozen: Dictionary = _game_state.store_dating_challenge_state(_record)
	if not frozen.get("ok", false): return frozen
	var fact := {"transaction_id": str(_record.spec.board_token) + ":effect" if _attempt_gate != null else _record.completion_transaction_id,
		"outcome": _record.outcome, "relationship_outcome": _record.relationship_outcome,
		"perfect_reasons": _record.perfect_reasons.duplicate()}
	var applied: Dictionary
	if _attempt_gate != null:
		applied = _game_state.prepare_dating_challenge_effect(_entry(), fact)
		if applied.get("ok", false): applied.value["replayed"] = false
	else:
		applied = _game_state.apply_dating_challenge_result(_entry(), fact)
	if not applied.get("ok", false): return applied
	_record.applied_result = applied.value.duplicate(true)
	_record.phase = "post_challenge"
	return _ok({})

func _complete_post() -> Dictionary:
	if _record.host == "canonical_pair" and _attempt_gate == null \
			and _admitted_command.get("execution_mode", "canonical") == "canonical" \
			and _record.outcome in ["perfect", "cleared"]:
		var witnessed: Dictionary=_profile.record_pair_form_witness(_record.pair_form,
			_record.completion_transaction_id)
		if not witnessed.get("ok",false): return witnessed
	_record.phase="completed"
	var saved: Dictionary=_game_state.store_dating_challenge_state(_record)
	if not saved.get("ok",false): return saved
	return _ok({})

func _completion_receipt() -> Dictionary:
	return {"owner_kind":OWNER_KIND,"physical_token":_record.physical_token,
		"command_sha256":_record.command_sha256,"completion_transaction_id":_record.completion_transaction_id,
		"status":"completed","result":{"outcome":_record.outcome,
			"perfect_reasons":_record.perfect_reasons.duplicate()}}

func _entry() -> Dictionary:
	var c: Dictionary=_record.context
	if c.kind == "solo": return {"type":"solo","friend_id":c.participants[0],"day":c.day}
	return {"type":"twofriends" if c.kind=="twofriends_if_deferred" else "group",
		"friend_ids":c.participants.duplicate(),"day":c.day}

## A finite provisional scene atom is admitted by the same physical command as the board.
## No history/replay adapter receives this capability. Window progress lives only in Run.
## Freeze pre-challenge presentation facts with the admitted Run state, before its
## initial checkpoint. Restoring this pending view never consults later live attributes.
func _freeze_pre_challenge_presentation() -> Dictionary:
	if _record.phase != "pre_challenge" or not _profile.has_method("record_reached_presentation"):
		return _ok({})
	var stored: Variant = _game_state.route_context.get("dating_pre_challenge_presentation")
	var context: Dictionary = _record.context
	var entry_id := "dating.solo.%s.day%d.pre_challenge" % [context.participants[0], int(context.day)] if context.kind == "solo" else "dating.%s.priscilla_lavinia.day%d.pre_challenge" % ["group" if context.kind == "group" else "twofriends", int(context.day)]
	if stored is Dictionary and stored.get("board_token") == _record.spec.board_token and stored.get("entry_id") == entry_id:
		if not stored.get("fields") is Dictionary: return _fail(&"invalid_saved_presentation_fields")
		var checked: Dictionary = PRESENTATION_SIGNATURE.from_dating_pre_challenge(_record, stored.fields)
		return _ok({}) if checked.ok else checked
	var fields := {}
	if _record.host == "canonical_solo":
		var friend_id: String = _record.context.participants[0]
		var relationship: Dictionary = _game_state.dating_route_state.get(friend_id, {})
		fields = {"tier": str(relationship.get("relationship_state", "friend")),
			"tone": "dark" if int(relationship.get("dark_points", 0)) >= OBSERVER_RULES.DARK_TONE_THRESHOLD else "sweet",
			"attitude": str(_game_state.friend_attitude.get(friend_id, "")), "echo_ids": []}
	else:
		fields = {"pair_mode": str(_record.context.kind), "pair_form": str(_record.pair_form)}
	var current: Dictionary = PRESENTATION_SIGNATURE.from_dating_pre_challenge(_record, fields)
	if not current.ok: return current
	_game_state.route_context["dating_pre_challenge_presentation"] = {
		"board_token": str(_record.spec.board_token), "entry_id": str(current.value.signature.entry_id),
		"fields": fields.duplicate(true)}
	return _ok({})

func acknowledge_pre_challenge_render(physical_token: String) -> Dictionary:
	if not _adopt(physical_token) or _record.phase != "pre_challenge" \
			or _admitted_command.get("execution_mode", "canonical") != "canonical":
		return _fail(&"presentation_render_not_admitted")
	if not _profile.has_method("record_reached_presentation"): return _fail(&"presentation_history_unavailable")
	var stored: Variant = _game_state.route_context.get("dating_pre_challenge_presentation")
	if not stored is Dictionary or not stored.get("fields") is Dictionary \
			or stored.get("board_token") != _record.spec.board_token:
		return _fail(&"missing_frozen_presentation_fields")
	var signature: Dictionary = PRESENTATION_SIGNATURE.from_dating_pre_challenge(_record, stored.fields)
	if not signature.ok or signature.value.signature.entry_id != stored.get("entry_id"):
		return _fail(&"invalid_saved_presentation_fields")
	var lease := {}
	if _attempt_gate != null:
		lease = _attempt_gate.acquire(&"causal_transaction")
		if not lease.get("ok", false): return lease
	var recorded: Dictionary = _profile.record_reached_presentation(signature.value.signature)
	if not lease.is_empty():
		var released: Dictionary = _attempt_gate.release(&"causal_transaction", lease.value.token)
		if not released.ok: return released
	return recorded

## Freeze only after the exact terminal relationship effect has been applied. This lives
## beside the physical record in the existing saved route context, never in Profile attempts.
func _freeze_post_challenge_presentation() -> Dictionary:
	if _record.phase not in ["post_challenge", "completed"] or not _profile.has_method("record_reached_presentation"):
		return _ok({})
	var stored: Variant = _game_state.route_context.get("dating_post_challenge_presentation")
	if stored is Dictionary and stored.get("board_token") == _record.spec.board_token:
		if not stored.get("fields") is Dictionary: return _fail(&"invalid_saved_presentation_fields")
		var saved_fields: Dictionary = stored.fields.duplicate(true)
		if _record.host == "canonical_pair" and saved_fields.get("pair_mode") != _record.context.kind:
			# The trusted presentation command may re-admit this exact pair slot as a
			# deferred encounter. Verify the original frozen signature before changing
			# only its presentation mode; the board, form and Profile attempt stay exact.
			var prior_record: Dictionary = _record.duplicate(true)
			prior_record.context.kind = saved_fields.get("pair_mode")
			var prior_signature: Dictionary = PRESENTATION_SIGNATURE.from_dating_post_challenge(prior_record, saved_fields)
			if not prior_signature.ok or prior_signature.value.signature.entry_id != stored.get("entry_id"):
				return _fail(&"invalid_saved_presentation_fields")
			saved_fields.pair_mode = _record.context.kind
			var remapped: Dictionary = PRESENTATION_SIGNATURE.from_dating_post_challenge(_record, saved_fields)
			if not remapped.ok: return remapped
			_game_state.route_context["dating_post_challenge_presentation"] = {
				"board_token": str(_record.spec.board_token),
				"entry_id": str(remapped.value.signature.entry_id), "fields": saved_fields}
			return _ok({})
		var checked: Dictionary = PRESENTATION_SIGNATURE.from_dating_post_challenge(_record, saved_fields)
		return _ok({}) if checked.ok and checked.value.signature.entry_id == stored.get("entry_id") else _fail(&"invalid_saved_presentation_fields")
	var fields := {}
	if _record.host == "canonical_solo":
		var friend_id: String = _record.context.participants[0]
		var relationship: Dictionary = _game_state.dating_route_state.get(friend_id, {})
		var effect: Dictionary = _record.applied_result.get("receipt", {})
		var tier: String = str(relationship.get("relationship_state", "friend"))
		var promotion := "none"
		if effect.get("promotion_applied", false): promotion = str(effect.relationship_state)
		elif effect.is_empty():
			var pre: Dictionary = _game_state.route_context.get("dating_pre_challenge_presentation", {})
			if pre.get("fields", {}).get("tier", tier) != tier: promotion = tier
		fields = {"tier": tier,
			"tone": "dark" if int(relationship.get("dark_points", 0)) >= OBSERVER_RULES.DARK_TONE_THRESHOLD else "sweet",
			"attitude": str(_game_state.friend_attitude.get(friend_id, "")),
			"echo_ids": [], "promotion_result": promotion}
	else:
		fields = {"pair_mode": str(_record.context.kind), "pair_form": str(_record.pair_form)}
	var current: Dictionary = PRESENTATION_SIGNATURE.from_dating_post_challenge(_record, fields)
	if not current.ok: return current
	_game_state.route_context["dating_post_challenge_presentation"] = {
		"board_token": str(_record.spec.board_token), "entry_id": str(current.value.signature.entry_id),
		"fields": fields.duplicate(true)}
	return _ok({})

func acknowledge_post_challenge_render(physical_token: String) -> Dictionary:
	if not _adopt(physical_token) or _record.phase != "post_challenge" or not _pending_checkpoint.is_empty() \
			or _admitted_command.get("execution_mode", "canonical") != "canonical":
		return _fail(&"presentation_render_not_admitted")
	if not _profile.has_method("record_reached_presentation"): return _fail(&"presentation_history_unavailable")
	var stored: Variant = _game_state.route_context.get("dating_post_challenge_presentation")
	if not stored is Dictionary or not stored.get("fields") is Dictionary \
			or stored.get("board_token") != _record.spec.board_token:
		return _fail(&"missing_frozen_presentation_fields")
	var signature: Dictionary = PRESENTATION_SIGNATURE.from_dating_post_challenge(_record, stored.fields)
	if not signature.ok or signature.value.signature.entry_id != stored.get("entry_id"):
		return _fail(&"invalid_saved_presentation_fields")
	var lease := {}
	if _attempt_gate != null:
		lease = _attempt_gate.acquire(&"causal_transaction")
		if not lease.get("ok", false): return lease
	var recorded: Dictionary = _profile.record_reached_presentation(signature.value.signature)
	if not lease.is_empty():
		var released: Dictionary = _attempt_gate.release(&"causal_transaction", lease.value.token)
		if not released.ok: return released
	return recorded

func pull_observer(physical_token: String) -> Dictionary:
	if not _adopt(physical_token): return _fail(&"stale_dating_physical_token")
	var source := _observer_source()
	if source.is_empty(): return _ok({})
	return _ok(_observer_projection(source))

func dispatch_observer(physical_token: String, atom_id: String, action: String, elapsed_ms: int = 0) -> Dictionary:
	if not _adopt(physical_token): return _fail(&"stale_dating_physical_token")
	var source := _observer_source()
	if source.is_empty() or atom_id != source.presentation_atom_id: return _fail(&"observer_source_not_admitted")
	var lease := {}
	if _attempt_gate != null:
		lease = _attempt_gate.acquire(&"causal_transaction")
		if not lease.get("ok", false): return lease
	var result := _dispatch_observer(source, action, elapsed_ms)
	if not lease.is_empty():
		var released: Dictionary = _attempt_gate.release(&"causal_transaction", lease.value.token)
		if not released.ok: return released
	return result

func _observer_source() -> Dictionary:
	if _admitted_command.get("execution_mode", "canonical") != "canonical": return {}
	if _record.is_empty() or _record.get("phase") != "pre_challenge" or _record.get("host") != "canonical_solo" \
			or int(_record.context.get("day", 0)) != 2 or not _profile.has_method("get_observer_evidence"):
		return {}
	var participants: Array = _record.context.get("participants", [])
	if participants.size() != 1 or participants[0] not in ["priscilla", "lavinia"]: return {}
	var atom: Dictionary = OBSERVER_RULES.OBSERVER_ATOMS[participants[0]].duplicate(true)
	# This is the same exact scene identity emitted by _entry(), not a loose friend match.
	if (ATTEMPTS.semantic_slot(_record.context) + ".pre_challenge") != atom.entry_id: return {}
	var registered: Dictionary = PRESENTATION_SIGNATURE.entry_record(str(atom.entry_id))
	if not registered.ok: return {}
	var expected := {"atom_id": atom.presentation_atom_id, "line_id": atom.line_id,
		"evidence_id": "observer.%s.%s" % [participants[0], "verification" if participants[0] == "priscilla" else "restraint"],
		"comparison_key": atom.comparison_key,
		"grammar": "capture_compare" if participants[0] == "priscilla" else "withholding"}
	var grants: Variant = registered.value.get("observer_atoms", [])
	if not grants is Array or not grants.has(expected): return {}
	atom["scope"] = participants[0]
	atom["run_id"] = str(_attempt_identity().run_id)
	return atom

func _observer_state(source: Dictionary) -> Dictionary:
	var stored: Variant = _game_state.route_context.get("dating_observer_source")
	if stored is Dictionary and stored.get("entry_id") == source.entry_id and stored.get("run_id") == source.run_id:
		var expected := ["capture_receipt_id", "checkpoint_pending", "closed", "comparison_shown", "elapsed_ms", "entry_id", "intervened", "playback_token", "rendered", "run_id"]
		var keys: Array = stored.keys()
		keys.sort()
		if keys != expected: return {}
		for key: String in ["capture_receipt_id", "entry_id", "playback_token", "run_id"]:
			if not stored[key] is String: return {}
		for key: String in ["checkpoint_pending", "closed", "comparison_shown", "intervened", "rendered"]:
			if typeof(stored[key]) != TYPE_BOOL: return {}
		if typeof(stored.elapsed_ms) != TYPE_INT or stored.elapsed_ms < 0 or stored.elapsed_ms > OBSERVER_RULES.OBSERVER_WITHHOLDING_MS: return {}
		return stored.duplicate(true)
	var capture_id := ""
	var evidence: Dictionary = _profile.get_observer_evidence().value.receipts
	var ids: Array = evidence.keys()
	ids.sort()
	for id: String in ids:
		var receipt: Dictionary = evidence[id]
		if receipt.kind == "capture" and receipt.run_id != source.run_id and receipt.comparison_key == source.comparison_key:
			capture_id = id
			break
	return {"entry_id": source.entry_id, "run_id": source.run_id, "playback_token": "",
		"capture_receipt_id": capture_id, "rendered": false, "comparison_shown": false,
		"elapsed_ms": 0, "intervened": false, "closed": false, "checkpoint_pending": false}

func _observer_projection(source: Dictionary) -> Dictionary:
	var state := _observer_state(source)
	if state.is_empty(): return {}
	var evidence: Dictionary = _profile.get_observer_evidence().value.receipts
	var captured := evidence.has(source.run_id + ":observer:capture")
	var counterpart: bool = not str(state.capture_receipt_id).is_empty()
	return {"entry_id": source.entry_id, "presentation_atom_id": source.presentation_atom_id,
		"scope": source.scope, "text": source.original_text,
		"counterpart_text": source.get("counterpart_text", ""),
		"counterpart": counterpart, "captured": captured,
		"comparison_shown": state.comparison_shown, "closed": state.closed,
		"intervened": state.intervened, "elapsed_ms": state.elapsed_ms,
		"checkpoint_pending": state.checkpoint_pending,
		"duration_ms": OBSERVER_RULES.OBSERVER_WITHHOLDING_MS}

func _dispatch_observer(source: Dictionary, action: String, elapsed_ms: int) -> Dictionary:
	var state := _observer_state(source)
	if state.is_empty(): return _fail(&"invalid_observer_restore_state")
	if state.checkpoint_pending and action not in ["render", "retry"]: return _fail(&"observer_checkpoint_retry_required")
	if action == "retry" and state.checkpoint_pending:
		return _observer_checkpoint(source, state)
	if action == "render":
		state["rendered"] = true
		state["playback_token"] = _record.physical_token
	elif not state.rendered or state.playback_token != _record.physical_token:
		return _fail(&"observer_atom_not_rendered")
	elif source.scope == "priscilla":
		if action == "capture" and str(state.capture_receipt_id).is_empty():
			var receipt := _observer_receipt(source, "capture")
			receipt["text_variant"] = "original"
			var committed: Dictionary = _profile.record_observer_evidence(receipt)
			if not committed.ok: return committed
		elif action == "compare" and not str(state.capture_receipt_id).is_empty():
			# The renderer opens the overlay first, then acknowledges its actual visible text.
			state["comparison_shown"] = true
		elif action == "compare_rendered" and state.comparison_shown and not str(state.capture_receipt_id).is_empty():
			var receipt := _observer_receipt(source, "verification")
			receipt["capture_receipt_id"] = state.capture_receipt_id
			var committed: Dictionary = _profile.record_observer_evidence(receipt)
			if not committed.ok: return committed
		else: return _fail(&"observer_action_unavailable")
	else:
		if state.closed: return _ok(_observer_projection(source))
		if action == "intervene": state["intervened"] = true
		elif action == "tick" and elapsed_ms >= 0 and elapsed_ms <= 1000:
			state["elapsed_ms"] = mini(OBSERVER_RULES.OBSERVER_WITHHOLDING_MS, int(state.elapsed_ms) + elapsed_ms)
		elif action == "close" and state.elapsed_ms == OBSERVER_RULES.OBSERVER_WITHHOLDING_MS:
			if not state.intervened:
				var receipt := _observer_receipt(source, "restraint")
				receipt["window_id"] = source.run_id + ":" + source.entry_id + ":withholding"
				receipt["duration_ms"] = OBSERVER_RULES.OBSERVER_WITHHOLDING_MS
				receipt["intervened"] = false
				var committed: Dictionary = _profile.record_observer_evidence(receipt)
				if not committed.ok: return committed
			state["closed"] = true
		else: return _fail(&"observer_action_unavailable")
	_game_state.route_context["dating_observer_source"] = state.duplicate(true)
	if action in ["capture", "compare_rendered", "intervene", "close"]:
		return _observer_checkpoint(source, state)
	return _ok(_observer_projection(source))

func _observer_checkpoint(source: Dictionary, state: Dictionary) -> Dictionary:
	state["checkpoint_pending"] = false
	_game_state.route_context["dating_observer_source"] = state.duplicate(true)
	if _checkpoint_writer.is_valid():
		var saved: Variant = _checkpoint_writer.call(_record.duplicate(true))
		if not saved is Dictionary or not saved.get("ok", false):
			state["checkpoint_pending"] = true
			_game_state.route_context["dating_observer_source"] = state.duplicate(true)
			return saved if saved is Dictionary else _fail(&"observer_checkpoint_failed")
	state["checkpoint_pending"] = false
	_game_state.route_context["dating_observer_source"] = state.duplicate(true)
	return _ok(_observer_projection(source))

func _observer_receipt(source: Dictionary, kind: String) -> Dictionary:
	var previous: Variant = _profile.get_observer_evidence().value.receipts.get(source.run_id + ":observer:" + kind)
	if previous is Dictionary: return previous.duplicate(true)
	return {"kind": kind, "run_id": source.run_id,
		"receipt_id": source.run_id + ":observer:" + kind,
		"entry_id": source.entry_id, "presentation_atom_id": source.presentation_atom_id,
		"line_id": source.line_id, "comparison_key": source.comparison_key,
		"playback_token": _record.physical_token}

func _make_spec(host: String) -> Dictionary:
	var dimensions: Dictionary=CATALOG.lookup(host)
	if not dimensions.get("ok",false): return dimensions
	var owned: Dictionary = CAPABILITIES.resolve_owned(_game_state.inventory)
	if not owned.get("ok", false): return owned
	var inputs: Dictionary = CAPABILITIES.build_spec_inputs(owned.value,
		int(_game_state.get_stat("pressure")), int(_game_state.penalty_points_today))
	if not inputs.get("ok", false): return inputs
	var values: Dictionary={}
	for pair: Array in [[&"board_id","board"],[&"placement_nonce","placement"],
			[&"debug_nonce","debug"],[&"explosion_nonce","explosion"]]:
		var issued: Dictionary=_issuer.issue(pair[0])
		if not issued.get("ok",false): return issued
		values[pair[1]]={"token":str(issued.value.token),"receipt_id":str(issued.value.issuer_receipt.receipt_id)}
	var kind := "solo_challenge" if host=="canonical_solo" else "pair_challenge"
	var spec={"schema_version":1,"board_kind":kind,"board_token":values.board.token,
		"board_token_receipt_id":values.board.receipt_id,"difficulty_id":host,
		"width":dimensions.value.width,"height":dimensions.value.height,
		"base_mine_count":dimensions.value.base_mine_count,"pressure":inputs.value.pressure,"penalty_points_today":inputs.value.penalty_points_today,
		"raw_extra_mines":inputs.value.raw_extra_mines,"requested_mine_count":dimensions.value.base_mine_count + inputs.value.effective_extra_mines,
		"capability_ids":inputs.value.capability_ids,"placement_stream_id":"minesweeper_placement_v1",
		"placement_nonce":values.placement.token,"placement_nonce_receipt_id":values.placement.receipt_id,
		"debug_stream_id":"minesweeper_debug_v1","debug_nonce":values.debug.token,
		"debug_nonce_receipt_id":values.debug.receipt_id,"explosion_stream_id":"minesweeper_explosion_v1",
		"explosion_nonce":values.explosion.token,"explosion_nonce_receipt_id":values.explosion.receipt_id,
		"generator_version":"dwm_generator_v1","verifier_version":"visible_deduction_v1"}
	var valid: Dictionary=SCHEMA.validate_spec(spec)
	return _ok(valid.value.spec) if valid.get("ok",false) else valid

func _view() -> Dictionary:
	if not _pending_checkpoint.is_empty():
		return {"phase": "checkpoint_retry", "host": _record.host, "board": _project_board(),
			"outcome": _record.outcome, "actions": ["retry"], "no_flag": _no_flag_status(),
			"special_mine_visible": _record.schema_version == 2 and _record.host == "canonical_solo", "special_mine_enabled": false}
	var actions: Array=[]
	match _record.phase:
		"pre_challenge","post_challenge": actions=["continue"]
		"settlement_retry": actions=["retry"]
		"completed": actions=["resume_completion"]
		"preparing": actions=["prepare"]
		"challenge": actions=["reveal","flag","unflag","chord"]
		"cleared_awaiting_terminal_choice": actions=["continue","activate"] if _record.schema_version == 3 else ["continue","special_mine"]
	return {"phase":_record.phase,"host":_record.host,"board":_project_board(),
		"outcome":_record.outcome,"actions":actions,"no_flag":_no_flag_status(),
		"special_mine_visible":_record.schema_version == 2 and _record.host == "canonical_solo",
		"special_mine_enabled":_record.phase == "cleared_awaiting_terminal_choice"}

func _project_board() -> Variant:
	if _record.board == null:
		var shell: Dictionary = _record.envelope.shell if _record.schema_version == 3 else {"flagged_indices": [], "actions": []}
		var forced: int = int(_record.envelope.forced_cell) if _record.schema_version == 3 else -1
		var cells: Array = []
		for index in int(_record.spec.width) * int(_record.spec.height):
			var legal: bool = _record.phase == "challenge"
			var flagged: bool = shell.flagged_indices.has(index)
			var actions: Array = []
			if legal:
				if flagged: actions = ["unflag"]
				elif forced < 0 or index == forced:
					actions = ["reveal", "flag"] if _record.schema_version == 3 else ["reveal"]
				elif _record.schema_version == 3: actions = ["flag"]
			cells.append({"index": index, "face": "covered", "mark": "flag" if flagged else "none", "number": 0,
				"bracketed": index == forced, "inspectable": legal, "pressable": not actions.is_empty(), "actions": actions})
		var estimate: Variant = null
		if _record.schema_version == 3 and _record.envelope.prepared_layout != null:
			estimate = int(_record.envelope.prepared_layout.mine_count) - shell.flagged_indices.size()
		return {"width": _record.spec.width, "height": _record.spec.height, "revision": _revision(),
			"mine_estimate": estimate, "terminal": false, "custody": _record.phase != "challenge", "cells": cells}
	var checked: Dictionary=SCHEMA.validate_board(_record.board)
	if not checked.get("ok",false): return null
	var board: Dictionary=checked.value.board
	var cells: Array=[]
	var inspectable: bool = not bool(board.terminal)
	var choice: bool = _record.schema_version == 3 and _record.phase == "cleared_awaiting_terminal_choice"
	for index in int(board.width)*int(board.height):
		var revealed: bool=board.revealed_indices.has(index)
		var flagged: bool=board.flagged_indices.has(index)
		var cell={"index":index,"face":"revealed" if revealed else "covered","mark":"flag" if flagged else "none",
			"number":int(board.adjacency_counts[index]) if revealed else 0,"bracketed":false,
			"inspectable":inspectable,"pressable":false,"actions":[]}
		if inspectable:
			if revealed:
				cell.actions = ["chord"] if cell.number > 0 else []
			elif flagged:
				cell.actions = ["unflag"]
			else:
				cell.actions = ["reveal", "flag"]
		if board.terminal and board.mine_indices.has(index):
			cell.face="covered" if flagged else "revealed"; cell.number=0; cell.mark="exploded" if index==board.exploded_index else ("correct_flag" if flagged else "mine")
		elif board.terminal and flagged:
			cell.mark = "correct_flag" if board.mine_indices.has(index) else "incorrect_flag"
		if choice and index == int(_record.envelope.special_cell):
			cell.mark = "marked_flag" if flagged else "marked_mine"
			cell.inspectable = true
			cell.actions = ["activate"]
		cell.pressable=not cell.actions.is_empty()
		cells.append(cell)
	return {"width":board.width,"height":board.height,"revision":board.revision,
		"mine_estimate":board.mine_count-board.flagged_indices.size(),"terminal":board.terminal,
		"custody":board.terminal and not choice,"cells":cells}

func _revision() -> int:
	return int(_record.board.revision) if _record.get("board") is Dictionary else (_record.envelope.shell.actions.size() if _record.get("schema_version") == 3 else 0)

func _no_flag_status() -> String:
	if not _record.get("board") is Dictionary:
		if _record.get("schema_version") == 3:
			for action: Dictionary in _record.envelope.shell.actions:
				if bool(action.get("flagged", false)): return "lost"
		return "intact"
	for entry: Variant in (_record.board as Dictionary).get("actions", []):
		if entry is Dictionary and str((entry as Dictionary).get("kind", "")) == "set_flag" \
				and bool((entry as Dictionary).get("flagged", false)):
			return "lost"
	return "intact"

func _adopt(token: String) -> bool:
	if _game_state == null: return false
	if not _pending_checkpoint.is_empty() and _pending_checkpoint.physical_token == token:
		_record = _pending_checkpoint.duplicate(true)
		return _valid_record(_record, _admitted_command)
	var captured: Dictionary=_game_state.capture_dating_challenge_state()
	if not captured.get("ok",false) or captured.value.is_empty() or captured.value.get("physical_token")!=token: return false
	if not _valid_record(captured.value, _admitted_command): return false
	_record=captured.value.duplicate(true)
	return true

func _valid_record(value: Dictionary, command: Dictionary) -> bool:
	var keys: Array = value.keys(); keys.sort()
	var expected_keys: Array = RECORD_KEYS.duplicate()
	if value.get("schema_version") == 3: expected_keys.append("envelope"); expected_keys.sort()
	if keys != expected_keys or value.schema_version not in [2, 3] or value.phase not in PHASES: return false
	if not value.context is Dictionary or not value.spec is Dictionary or not value.applied_result is Dictionary \
			or not value.mine_dispositions is Array or not value.perfect_reasons is Array: return false
	if typeof(value.completion_transaction_id) != TYPE_STRING or typeof(value.command_sha256) != TYPE_STRING \
			or value.completion_transaction_id.is_empty() or value.command_sha256.is_empty(): return false
	if not command.is_empty() and (value.completion_transaction_id != command.get("completion_transaction_id") \
			or value.command_sha256 != command.get("command_sha256") or value.context != command.get("context")): return false
	if value.physical_token != _token(value.completion_transaction_id, value.command_sha256): return false
	var context: Dictionary = value.context
	if context.get("kind") not in ["solo", "group", "twofriends_if_deferred"] \
			or not context.get("participants") is Array or typeof(context.get("day")) != TYPE_INT: return false
	if context.kind == "solo":
		if context.participants.size() != 1 or context.participants[0] not in ["sylvia", "priscilla", "lavinia"]: return false
	elif context.participants != ["priscilla", "lavinia"]: return false
	var expected_host: String = "canonical_solo" if context.kind == "solo" else "canonical_pair"
	var expected_kind: String = "solo_challenge" if expected_host == "canonical_solo" else "pair_challenge"
	var dimensions: Dictionary = CATALOG.lookup(expected_host)
	if expected_host == "canonical_pair" and value.pair_form not in PROFILE_SCHEMA.PAIR_FORMS: return false
	if expected_host == "canonical_solo" and value.pair_form != "": return false
	if value.host != expected_host or not SCHEMA.validate_spec(value.spec).get("ok", false) \
			or value.spec.board_kind != expected_kind or value.spec.difficulty_id != expected_host \
			or value.spec.width != dimensions.value.width or value.spec.height != dimensions.value.height \
			or value.spec.base_mine_count != dimensions.value.base_mine_count: return false
	if value.schema_version == 2 and (value.spec.requested_mine_count != dimensions.value.base_mine_count \
			or value.spec.pressure != 0 or value.spec.penalty_points_today != 0): return false
	if value.board != null and not value.board is Dictionary: return false
	if value.schema_version == 3 and not ENVELOPE.validate(value): return false
	if value.board == null:
		return value.phase in ["pre_challenge", "preparing", "challenge"] and value.outcome == null \
			and value.relationship_outcome == null and value.mine_dispositions.is_empty() \
			and value.perfect_reasons.is_empty() and value.applied_result.is_empty()
	if not value.board is Dictionary or not SCHEMA.validate_board(value.board).get("ok", false): return false
	var board: Dictionary = value.board
	if board.width != value.spec.width or board.height != value.spec.height \
			or board.mine_count < value.spec.base_mine_count or board.mine_count > value.spec.requested_mine_count: return false
	var dispositions: Array = RULES.dispositions(value.spec, board.mine_count) if expected_host == "canonical_solo" else []
	if value.mine_dispositions != dispositions: return false
	if not board.terminal:
		return value.phase == "challenge" and value.outcome == null and value.relationship_outcome == null \
			and value.perfect_reasons.is_empty() and value.applied_result.is_empty()
	var reasons: Array = RULES.perfect_reasons(board, int(value.schema_version))
	var outcome: String = "exploded" if str(board.outcome) == "exploded" else ("cleared" if reasons.is_empty() else "perfect")
	if value.outcome != outcome or value.perfect_reasons != reasons: return false
	if expected_host == "canonical_pair":
		return value.phase in ["post_challenge", "completed"] and value.relationship_outcome == null \
			and value.applied_result == {"board_only": true}
	if value.phase == "cleared_awaiting_terminal_choice":
		return (outcome == "cleared" if value.schema_version == 3 else outcome != "exploded") and value.relationship_outcome == null and value.applied_result.is_empty()
	var relationship: String = str(value.relationship_outcome)
	if outcome == "exploded":
		if relationship != dispositions[board.mine_indices.find(board.exploded_index)]: return false
	elif value.schema_version == 3 and outcome == "perfect":
		if relationship != "foresight": return false
	elif relationship not in ["dark", "foresight" if outcome == "perfect" else "loved"]: return false
	if value.phase == "settlement_retry": return value.applied_result.is_empty()
	return value.phase in ["post_challenge", "completed"] and not value.applied_result.is_empty()

func _token(completion_id: String, command_hash: String) -> String:
	var hashed: Dictionary=CANONICAL.canonical_sha256(completion_id+"|"+command_hash)
	return "dating_challenge."+str(hashed.value.sha256) if hashed.get("ok",false) else ""

func _ok(value: Variant) -> Dictionary:
	return {"ok":true,"code":&"ok","value":value,"receipt":{}}
func _fail(code: StringName, value: Dictionary={}) -> Dictionary:
	var result={"ok":false,"code":code,"message":"","details":{}}
	if not value.is_empty(): result["value"]=value.duplicate(true)
	return result
