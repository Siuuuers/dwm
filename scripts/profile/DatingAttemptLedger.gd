extends RefCounted
## Attempts and branch progress remain retained; each branch stores one latest record.
## Pre-ending callers keep the first lock. Post-ending callers explicitly choose a branch
## or a fresh entry. Rehearsal never enters this ledger.
## Provisional first-click rule: Continue freezes spec/nonces; the first reveal freezes
## its safe index and materialized layout before that move is published.

const CATALOG := preload("res://scripts/domain/minesweeper/MinesweeperBoardCatalog.gd")
const BOARD := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const RULES := preload("res://scripts/application/run/DatingChallengeRules.gd")
const CANONICAL := preload("res://scripts/domain/schedule/ScheduleStateSchema.gd")
const PHASES := ["challenge", "cleared_awaiting_terminal_choice", "settlement_retry", "post_challenge", "completed"]
const ATTEMPT_KEYS := ["attempt_id", "branch_id", "clear_receipt", "completion_receipt", "effect_receipt",
	"entry_receipt", "materialization_receipt", "record", "revision", "run_id", "slot_id", "terminal_receipt"]
const RECORD_KEYS := ["applied_result", "board", "command_sha256", "completion_transaction_id", "context",
	"host", "mine_dispositions", "outcome", "pair_form", "perfect_reasons", "phase", "physical_token",
	"relationship_outcome", "schema_version", "spec"]
const RECEIPTS := ["materialization_receipt", "clear_receipt", "terminal_receipt", "effect_receipt", "completion_receipt"]
const EFFECT_KEYS := ["attitude", "momentum_delta", "outcome", "perfect_reasons", "progression_evaluated",
	"relationship_outcome", "relationship_state", "ruleset_id", "ruleset_status", "scene_id", "terminal_fact", "tone_delta"]

const SLOT_KEYS := ["first_attempt_id", "attempts"]
const HISTORY_KEYS := ["generation", "origin_branch_id", "entry_receipt", "progress_by_branch"]
const PROGRESS_KEYS := ["revision", "record", "materialization_receipt", "clear_receipt", "terminal_receipt", "effect_receipt", "completion_receipt"]

## Default lookup retains the first entered attempt and its original progress (the pre-ending lock).
## An explicit attempt/branch reference never silently falls back to another timeline.
static func read(ledger: Dictionary, run_id: String, slot_id: String,
		attempt_id: String = "", branch_id: String = "") -> Dictionary:
	var slot: Dictionary = ledger.get(run_id, {}).get(slot_id, {})
	if slot.is_empty():
		return _ok({}) if attempt_id.is_empty() and branch_id.is_empty() else _fail(&"dating_attempt_missing")
	var selected: String = str(slot.first_attempt_id) if attempt_id.is_empty() else attempt_id
	if not slot.attempts.has(selected): return _fail(&"dating_attempt_missing")
	var history: Dictionary = slot.attempts[selected]
	var branch: String = str(history.origin_branch_id) if branch_id.is_empty() else branch_id
	if not history.progress_by_branch.has(branch): return _fail(&"dating_branch_missing")
	return _ok(_flatten(run_id, slot_id, selected, branch, history))

## Selection is explicit: empty keeps the first lock; branch updates an existing branch;
## fresh enters a new board; continue copies a selected save only as part of this candidate.
static func prepare_update(ledger: Dictionary, run_id: String, slot_id: String, branch_id: String,
		record: Dictionary, expected_revision: int, first_cell_index: int = -1,
		frozen_effect: Dictionary = {}, selection: Dictionary = {}) -> Dictionary:
	if not _valid_record(record) or run_id.strip_edges().is_empty() or branch_id.strip_edges().is_empty() \
			or slot_id != semantic_slot(record.context) or expected_revision < 0:
		return _fail(&"invalid_dating_attempt")
	var mode: String = str(selection.get("mode", ""))
	if not selection.is_empty():
		if mode not in ["branch", "fresh", "continue"]: return _fail(&"invalid_dating_selection")
		var fields: Array = ["mode", "source_branch_id", "saved_record"] if mode == "continue" else ["mode"]
		if not _keys(selection, fields): return _fail(&"invalid_dating_selection")
	var slot: Dictionary = ledger.get(run_id, {}).get(slot_id, {})
	var attempt_id: String = str(record.spec.board_token)
	var previous := {}
	var generation := 1
	var effective_branch := branch_id
	var copied := false
	if mode.is_empty():
		var found := read(ledger, run_id, slot_id)
		if not found.ok: return found
		previous = found.value
		if not previous.is_empty():
			attempt_id = str(previous.attempt_id)
			effective_branch = str(previous.branch_id)
			generation = int(previous.generation)
	elif mode == "fresh":
		if record.phase != "challenge" or record.board != null: return _fail(&"dating_fresh_entry_required")
		if not slot.is_empty() and slot.attempts.has(attempt_id):
			var history: Dictionary = slot.attempts[attempt_id]
			if history.origin_branch_id != branch_id: return _fail(&"dating_entry_conflict")
			previous = read(ledger, run_id, slot_id, attempt_id, branch_id).value
			generation = int(history.generation)
		elif not slot.is_empty(): generation = slot.attempts.size() + 1
	else:
		if slot.is_empty() or not slot.attempts.has(attempt_id): return _fail(&"dating_attempt_missing")
		generation = int(slot.attempts[attempt_id].generation)
		var found := read(ledger, run_id, slot_id, attempt_id, branch_id)
		if found.ok:
			previous = found.value
		elif mode == "branch": return found
		else:
			if not selection.source_branch_id is String or not selection.saved_record is Dictionary \
					or selection.source_branch_id == branch_id: return _fail(&"invalid_dating_selection")
			var source := read(ledger, run_id, slot_id, attempt_id, selection.source_branch_id)
			if not source.ok: return source
			var restored := _copy_saved(source.value, selection.saved_record, branch_id)
			if not restored.ok: return restored
			previous = restored.value
			copied = true
	if copied and expected_revision != 0: return _fail(&"dating_revision_conflict")
	var flat := {}
	if not previous.is_empty(): flat = {run_id: {slot_id: previous}}
	var prepared := _prepare_flat(flat, run_id, slot_id, effective_branch, record,
		1 if copied else expected_revision, first_cell_index, frozen_effect)
	if not prepared.ok: return prepared
	var attempt: Dictionary = prepared.value.attempt
	attempt["generation"] = generation
	if copied: attempt.revision = 1
	if not copied and not prepared.value.changed:
		return _ok({"ledger": ledger.duplicate(true), "attempt": attempt.duplicate(true), "changed": false})
	var candidate := ledger.duplicate(true)
	if not candidate.has(run_id): candidate[run_id] = {}
	if slot.is_empty():
		candidate[run_id][slot_id] = {"first_attempt_id": attempt_id, "attempts": {}}
	var attempts: Dictionary = candidate[run_id][slot_id].attempts
	if not attempts.has(attempt_id):
		attempts[attempt_id] = {"generation": generation, "origin_branch_id": effective_branch,
			"entry_receipt": attempt.entry_receipt.duplicate(true), "progress_by_branch": {}}
	attempts[attempt_id].progress_by_branch[effective_branch] = _progress(attempt)
	var checked := validate(candidate)
	if not checked.ok: return checked
	return _ok({"ledger": candidate, "attempt": attempt.duplicate(true), "changed": true})

## Read-only preview. Do not commit it during Load; pass its selection with the first
## canonical action to prepare_update(expected_revision=0), then commit that one candidate.
static func prepare_continuation(ledger: Dictionary, run_id: String, slot_id: String,
		attempt_id: String, source_branch_id: String, branch_id: String, saved_record: Dictionary) -> Dictionary:
	if branch_id.strip_edges().is_empty() or branch_id == source_branch_id: return _fail(&"invalid_dating_selection")
	var source := read(ledger, run_id, slot_id, attempt_id, source_branch_id)
	if not source.ok: return source
	if read(ledger, run_id, slot_id, attempt_id, branch_id).ok: return _fail(&"dating_branch_exists")
	var copied := _copy_saved(source.value, saved_record, branch_id)
	if not copied.ok: return copied
	return _ok({"attempt": copied.value, "expected_revision": 0,
		"selection": {"mode": "continue", "source_branch_id": source_branch_id, "saved_record": saved_record.duplicate(true)}})

static func _copy_saved(source: Dictionary, saved_record: Dictionary, branch_id: String) -> Dictionary:
	if not _valid_record(saved_record) or _entry(saved_record) != source.entry_receipt:
		return _fail(&"dating_entry_conflict")
	var first_cell := -1
	if saved_record.board != null:
		if source.materialization_receipt == null: return _fail(&"dating_materialization_conflict")
		first_cell = int(source.materialization_receipt.first_cell_index)
	var saved_effect: Dictionary = saved_record.applied_result.get("receipt", {})
	var copied := _prepare_flat({}, source.run_id, source.slot_id, branch_id, saved_record, 0, first_cell, saved_effect)
	if not copied.ok: return copied
	var attempt: Dictionary = copied.value.attempt
	# Validate provenance as a prefix of the source, never import its later receipts.
	var source_first: int = int(source.materialization_receipt.first_cell_index) if source.materialization_receipt != null else -1
	var source_effect: Dictionary = source.effect_receipt.value if source.effect_receipt != null else {}
	var checked := _prepare_flat({source.run_id: {source.slot_id: attempt}}, source.run_id,
		source.slot_id, branch_id, source.record, 1, source_first, source_effect)
	if not checked.ok: return _fail(&"dating_saved_progress_conflict")
	attempt["generation"] = source.generation
	return _ok(attempt)

static func _flatten(run_id: String, slot_id: String, attempt_id: String, branch_id: String,
		history: Dictionary) -> Dictionary:
	var attempt: Dictionary = history.progress_by_branch[branch_id].duplicate(true)
	attempt.merge({"run_id": run_id, "slot_id": slot_id, "attempt_id": attempt_id, "branch_id": branch_id,
		"entry_receipt": history.entry_receipt.duplicate(true), "generation": history.generation})
	return attempt

static func _progress(attempt: Dictionary) -> Dictionary:
	var result := {}
	for key: String in PROGRESS_KEYS: result[key] = attempt[key]
	return result.duplicate(true)

static func validate(ledger: Variant) -> Dictionary:
	if not ledger is Dictionary: return _fail(&"invalid_dating_ledger")
	for run_id: Variant in ledger:
		if not run_id is String or run_id.strip_edges().is_empty() or not ledger[run_id] is Dictionary:
			return _fail(&"invalid_dating_ledger")
		for slot_id: Variant in ledger[run_id]:
			var slot: Variant = ledger[run_id][slot_id]
			if not slot_id is String or not slot is Dictionary or not _keys(slot, SLOT_KEYS) \
					or not slot.first_attempt_id is String or not slot.attempts is Dictionary \
					or not slot.attempts.has(slot.first_attempt_id): return _fail(&"invalid_dating_ledger")
			var generations: Array = []
			for attempt_id: Variant in slot.attempts:
				var history: Variant = slot.attempts[attempt_id]
				if not attempt_id is String or attempt_id.is_empty() or not history is Dictionary \
						or not _keys(history, HISTORY_KEYS) or typeof(history.generation) != TYPE_INT \
						or history.generation < 1 or history.generation > slot.attempts.size() \
						or history.generation in generations or not history.origin_branch_id is String \
						or not history.entry_receipt is Dictionary or not history.progress_by_branch is Dictionary \
						or not history.progress_by_branch.has(history.origin_branch_id): return _fail(&"invalid_dating_ledger")
				generations.append(history.generation)
				if attempt_id == slot.first_attempt_id and history.generation != 1: return _fail(&"invalid_dating_ledger")
				for branch_id: Variant in history.progress_by_branch:
					var progress: Variant = history.progress_by_branch[branch_id]
					if not branch_id is String or branch_id.strip_edges().is_empty() or not progress is Dictionary \
							or not _keys(progress, PROGRESS_KEYS): return _fail(&"invalid_dating_ledger")
					var checked := validate_attempt(_flatten(run_id, slot_id, attempt_id, branch_id, history))
					if not checked.ok: return checked
	return _ok(ledger.duplicate(true))

## Every prior attempt and branch stays retained; only its latest progress advances.
static func preserves(previous: Dictionary, candidate: Dictionary) -> bool:
	for run_id: String in previous:
		if not candidate.has(run_id): return false
		for slot_id: String in previous[run_id]:
			if not candidate[run_id].has(slot_id): return false
			var old_slot: Dictionary = previous[run_id][slot_id]
			var next_slot: Dictionary = candidate[run_id][slot_id]
			if old_slot.first_attempt_id != next_slot.first_attempt_id: return false
			for attempt_id: String in old_slot.attempts:
				if not next_slot.attempts.has(attempt_id): return false
				var before: Dictionary = old_slot.attempts[attempt_id]
				var after: Dictionary = next_slot.attempts[attempt_id]
				for key: String in ["generation", "origin_branch_id", "entry_receipt"]:
					if before[key] != after[key]: return false
				for branch_id: String in before.progress_by_branch:
					if not after.progress_by_branch.has(branch_id): return false
					if not _preserves_flat({run_id: {slot_id: _flatten(run_id, slot_id, attempt_id, branch_id, before)}},
							{run_id: {slot_id: _flatten(run_id, slot_id, attempt_id, branch_id, after)}}): return false
	return true

static func upgrade_v6(ledger: Dictionary) -> Dictionary:
	var checked := validate_v6(ledger)
	if not checked.ok: return checked
	var candidate := {}
	for run_id: String in ledger:
		candidate[run_id] = {}
		for slot_id: String in ledger[run_id]:
			var old: Dictionary = ledger[run_id][slot_id]
			candidate[run_id][slot_id] = {"first_attempt_id": old.attempt_id, "attempts": {
				old.attempt_id: {"generation": 1, "origin_branch_id": old.branch_id,
					"entry_receipt": old.entry_receipt.duplicate(true),
					"progress_by_branch": {old.branch_id: _progress(old)}}}}
	return validate(candidate)

static func _prepare_flat(ledger: Dictionary, run_id: String, slot_id: String, branch_id: String,
		record: Dictionary, expected_revision: int, first_cell_index: int = -1,
		frozen_effect: Dictionary = {}) -> Dictionary:
	if run_id.strip_edges().is_empty() or branch_id.strip_edges().is_empty() or expected_revision < 0 \
			or not _valid_record(record) or slot_id != semantic_slot(record.context):
		return _fail(&"invalid_dating_attempt")
	var previous: Dictionary = ledger.get(run_id, {}).get(slot_id, {})
	if not previous.is_empty() and not validate_attempt(previous).ok: return _fail(&"invalid_dating_attempt")
	var attempt: Dictionary
	if previous.is_empty():
		attempt = {"run_id": run_id, "slot_id": slot_id, "attempt_id": record.spec.board_token,
			"branch_id": branch_id, "revision": 1, "record": record.duplicate(true),
			"entry_receipt": _entry(record), "materialization_receipt": null, "clear_receipt": null,
			"terminal_receipt": null, "effect_receipt": null, "completion_receipt": null}
	else:
		attempt = previous.duplicate(true)
		attempt.record = record.duplicate(true)
		if attempt.entry_receipt != _entry(record): return _fail(&"dating_entry_conflict")
		if PHASES.find(record.phase) < PHASES.find(previous.record.phase): return _fail(&"dating_attempt_rewind")
		if not _board_advances(previous.record.board, record.board): return _fail(&"dating_attempt_rewind")
	if record.board != null:
		if attempt.materialization_receipt == null:
			if first_cell_index < 0: return _fail(&"dating_first_cell_required")
			attempt.materialization_receipt = {"first_cell_index": first_cell_index,
				"layout": _layout(record.board), "mine_dispositions": record.mine_dispositions.duplicate()}
		elif first_cell_index != -1 and first_cell_index != attempt.materialization_receipt.first_cell_index:
			return _fail(&"dating_materialization_conflict")
	elif first_cell_index != -1:
		return _fail(&"dating_materialization_conflict")
	if record.outcome in ["cleared", "perfect"]:
		attempt.clear_receipt = {"outcome": record.outcome, "perfect_reasons": record.perfect_reasons.duplicate()}
	if record.relationship_outcome != null or (record.host == "canonical_pair" and record.outcome != null):
		attempt.terminal_receipt = {"outcome": record.outcome, "perfect_reasons": record.perfect_reasons.duplicate(),
			"relationship_outcome": record.relationship_outcome}
	if not frozen_effect.is_empty():
		attempt.effect_receipt = {"receipt_id": str(attempt.attempt_id) + ":effect", "value": frozen_effect.duplicate(true)}
	if record.phase == "completed":
		attempt.completion_receipt = {"receipt_id": str(attempt.attempt_id) + ":complete", "outcome": record.outcome}
	if not previous.is_empty():
		for key: String in RECEIPTS:
			if previous[key] != null and attempt[key] != previous[key]: return _fail(&"dating_receipt_conflict")
		if attempt == previous: return _ok({"ledger": ledger.duplicate(true), "attempt": attempt, "changed": false})
		attempt.revision = int(previous.revision) + 1
	if expected_revision != int(previous.get("revision", 0)): return _fail(&"dating_revision_conflict")
	var checked := validate_attempt(attempt)
	if not checked.ok: return checked
	var candidate := ledger.duplicate(true)
	if not candidate.has(run_id): candidate[run_id] = {}
	candidate[run_id][slot_id] = attempt.duplicate(true)
	return _ok({"ledger": candidate, "attempt": attempt.duplicate(true), "changed": true})

static func validate_v6(ledger: Variant) -> Dictionary:
	if not ledger is Dictionary: return _fail(&"invalid_dating_ledger")
	for run_id: Variant in ledger:
		if not run_id is String or run_id.strip_edges().is_empty() or not ledger[run_id] is Dictionary:
			return _fail(&"invalid_dating_ledger")
		for slot_id: Variant in ledger[run_id]:
			var attempt: Variant = ledger[run_id][slot_id]
			if not slot_id is String or not attempt is Dictionary or not _keys(attempt, ATTEMPT_KEYS): return _fail(&"invalid_dating_ledger")
			var checked := validate_attempt(attempt)
			if not checked.ok: return checked
			if attempt.run_id != run_id or attempt.slot_id != slot_id: return _fail(&"invalid_dating_ledger")
	return _ok(ledger.duplicate(true))

## Ordinary Profile commits/restores preserve history; only full reset may remove it.
static func _preserves_flat(previous: Dictionary, candidate: Dictionary) -> bool:
	for run_id: String in previous:
		if not candidate.has(run_id): return false
		for slot_id: String in previous[run_id]:
			if not candidate[run_id].has(slot_id): return false
			var before: Dictionary = previous[run_id][slot_id]
			var after: Dictionary = candidate[run_id][slot_id]
			if before == after: continue
			if after.revision <= before.revision or after.attempt_id != before.attempt_id \
					or after.branch_id != before.branch_id or after.entry_receipt != before.entry_receipt \
					or PHASES.find(after.record.phase) < PHASES.find(before.record.phase) \
					or not _board_advances(before.record.board, after.record.board): return false
			for key: String in RECEIPTS:
				if before[key] != null and after[key] != before[key]: return false
	return true

static func validate_attempt(attempt: Dictionary) -> Dictionary:
	if not (_keys(attempt, ATTEMPT_KEYS) or _keys(attempt, ATTEMPT_KEYS + ["generation"])) or not attempt.record is Dictionary or not _valid_record(attempt.record):
		return _fail(&"invalid_dating_attempt")
	if attempt.has("generation") and (typeof(attempt.generation) != TYPE_INT or attempt.generation < 1):
		return _fail(&"invalid_dating_attempt")
	for key: String in ["run_id", "slot_id", "branch_id", "attempt_id"]:
		if not attempt[key] is String or attempt[key].strip_edges().is_empty(): return _fail(&"invalid_dating_attempt")
	var record: Dictionary = attempt.record
	if typeof(attempt.revision) != TYPE_INT or attempt.revision < 1 \
			or attempt.slot_id != semantic_slot(record.context) or attempt.attempt_id != record.spec.board_token \
			or attempt.entry_receipt != _entry(record): return _fail(&"invalid_dating_attempt")
	var material: Variant = attempt.materialization_receipt
	if record.board == null:
		if material != null: return _fail(&"invalid_dating_materialization")
	else:
		if not material is Dictionary or not _keys(material, ["first_cell_index", "layout", "mine_dispositions"]) \
				or typeof(material.first_cell_index) != TYPE_INT or material.layout != _layout(record.board) \
				or material.mine_dispositions != record.mine_dispositions: return _fail(&"invalid_dating_materialization")
		var initial: Dictionary = REDUCER.first_reveal(material.layout, material.first_cell_index)
		if not initial.ok: return _fail(&"invalid_dating_materialization")
		for cell: int in initial.value.board.revealed_indices:
			if not record.board.revealed_indices.has(cell): return _fail(&"invalid_dating_materialization")
		if record.board.actions.is_empty():
			var initial_board: Dictionary = initial.value.board.duplicate(true)
			initial_board.outcome = str(initial_board.outcome)
			if initial_board != record.board: return _fail(&"invalid_dating_materialization")
	var clear: Variant = {"outcome": record.outcome, "perfect_reasons": record.perfect_reasons} \
		if record.outcome in ["cleared", "perfect"] else null
	var terminal: Variant = {"outcome": record.outcome, "perfect_reasons": record.perfect_reasons,
		"relationship_outcome": record.relationship_outcome} if record.relationship_outcome != null \
		or (record.host == "canonical_pair" and record.outcome != null) else null
	if attempt.clear_receipt != clear or attempt.terminal_receipt != terminal: return _fail(&"invalid_dating_receipt")
	if attempt.effect_receipt != null:
		var effect: Variant = attempt.effect_receipt
		if terminal == null or not effect is Dictionary or not _keys(effect, ["receipt_id", "value"]) \
				or effect.receipt_id != str(attempt.attempt_id) + ":effect" or not effect.value is Dictionary \
				or not _valid_effect(effect.value, record, str(attempt.slot_id)):
			return _fail(&"invalid_dating_effect_receipt")
	# Pair boards have no relationship effect; their physical completion is still irreversible.
	if record.host == "canonical_solo" and record.phase in ["post_challenge", "completed"] \
			and attempt.effect_receipt == null: return _fail(&"dating_effect_receipt_required")
	if record.host == "canonical_solo" and record.phase in ["post_challenge", "completed"]:
		if not _keys(record.applied_result, ["receipt", "replayed"]) \
				or typeof(record.applied_result.replayed) != TYPE_BOOL \
				or record.applied_result.receipt != attempt.effect_receipt.value:
			return _fail(&"dating_effect_receipt_conflict")
	var completion: Variant = {"receipt_id": str(attempt.attempt_id) + ":complete", "outcome": record.outcome} \
		if record.phase == "completed" else null
	if attempt.completion_receipt != completion: return _fail(&"invalid_dating_receipt")
	return _ok(attempt.duplicate(true))

static func _valid_effect(effect: Dictionary, record: Dictionary, slot_id: String) -> bool:
	if not (_keys(effect, EFFECT_KEYS) or _keys(effect, EFFECT_KEYS + ["promotion_applied"])) \
			or not CANONICAL.canonical_json(effect).ok \
			or not effect.terminal_fact is Dictionary \
			or not _keys(effect.terminal_fact, ["transaction_id", "outcome", "relationship_outcome", "perfect_reasons"]): return false
	if effect.has("promotion_applied") and typeof(effect.promotion_applied) != TYPE_BOOL: return false
	if typeof(effect.momentum_delta) != TYPE_INT or typeof(effect.tone_delta) != TYPE_INT \
			or typeof(effect.progression_evaluated) != TYPE_BOOL or effect.scene_id != slot_id: return false
	for key: String in ["attitude", "relationship_state", "ruleset_id", "ruleset_status"]:
		if not effect[key] is String or effect[key].is_empty(): return false
	for key: String in ["outcome", "relationship_outcome", "perfect_reasons"]:
		if effect[key] != record[key] or effect.terminal_fact[key] != record[key]: return false
	return effect.terminal_fact.transaction_id is String and not effect.terminal_fact.transaction_id.is_empty()

static func semantic_slot(context: Dictionary) -> String:
	if typeof(context.get("day")) != TYPE_INT or not context.get("participants") is Array: return ""
	var day: int = context.day
	if context.get("kind") == "solo" and context.participants.size() == 1:
		var friend: String = str(context.participants[0])
		var windows := {"priscilla": [1, 2, 4, 6], "lavinia": [2, 3, 5, 6], "sylvia": [1, 3, 4, 5]}
		if windows.has(friend) and day in windows[friend]: return "dating.solo.%s.day%d" % [friend, day]
	if context.get("kind") in ["group", "twofriends_if_deferred"] \
			and context.participants == ["priscilla", "lavinia"] and day in [2, 6]:
		return "dating.pair.priscilla_lavinia.day%d" % day
	return ""

static func _entry(record: Dictionary) -> Dictionary:
	return {"spec": record.spec.duplicate(true), "context": record.context.duplicate(true),
		"host": record.host, "pair_form": record.pair_form}

static func _layout(board: Dictionary) -> Dictionary:
	return {"schema_version": 1, "width": board.width, "height": board.height,
		"mine_count": board.mine_count, "mine_indices": board.mine_indices.duplicate()}

static func _board_advances(before: Variant, after: Variant) -> bool:
	if before == null: return true
	if after == null or _layout(before) != _layout(after): return false
	if before.terminal: return before == after
	if after.actions.size() < before.actions.size(): return false
	if after.actions.slice(0, before.actions.size()) != before.actions: return false
	if after.actions.size() == before.actions.size(): return before == after
	for index: int in before.revealed_indices:
		if not after.revealed_indices.has(index): return false
	return true

static func _valid_record(record: Dictionary) -> bool:
	if not _keys(record, RECORD_KEYS) or typeof(record.schema_version) != TYPE_INT \
			or record.schema_version != 2 or record.phase not in PHASES \
			or not record.context is Dictionary or semantic_slot(record.context).is_empty() \
			or not record.spec is Dictionary or not BOARD.validate_spec(record.spec).ok \
			or not record.applied_result is Dictionary or not record.mine_dispositions is Array \
			or not record.perfect_reasons is Array: return false
	for key: String in ["completion_transaction_id", "command_sha256", "physical_token"]:
		if not record[key] is String or record[key].is_empty(): return false
	var token: Dictionary = CANONICAL.canonical_sha256(record.completion_transaction_id + "|" + record.command_sha256)
	if not token.ok or record.physical_token != "dating_challenge." + str(token.value.sha256): return false
	var host: String = "canonical_solo" if record.context.kind == "solo" else "canonical_pair"
	if record.host != host or record.spec.difficulty_id != host \
			or record.spec.board_kind != ("solo_challenge" if host == "canonical_solo" else "pair_challenge"): return false
	var dimensions: Dictionary = CATALOG.lookup(host).value
	if record.spec.width != dimensions.width or record.spec.height != dimensions.height \
			or record.spec.requested_mine_count != dimensions.base_mine_count \
			or record.spec.base_mine_count != dimensions.base_mine_count or record.spec.pressure != 0 \
			or record.spec.penalty_points_today != 0: return false
	if host == "canonical_solo" and record.pair_form != "": return false
	if host == "canonical_pair" and record.pair_form not in ["ambiguous_sweet", "ambiguous_dark", "love_sweet", "love_dark"]: return false
	if record.board == null:
		return record.phase == "challenge" and record.outcome == null and record.relationship_outcome == null \
			and record.mine_dispositions.is_empty() and record.perfect_reasons.is_empty() and record.applied_result.is_empty()
	if not record.board is Dictionary or not BOARD.validate_board(record.board).ok: return false
	var board: Dictionary = record.board
	if board.width != record.spec.width or board.height != record.spec.height \
			or board.mine_count != record.spec.requested_mine_count: return false
	var dispositions: Array = RULES.dispositions(record.spec, board.mine_count) if host == "canonical_solo" else []
	if record.mine_dispositions != dispositions: return false
	if not board.terminal:
		return record.phase == "challenge" and record.outcome == null and record.relationship_outcome == null \
			and record.perfect_reasons.is_empty() and record.applied_result.is_empty()
	var reasons: Array = RULES.perfect_reasons(board)
	var outcome: String = "exploded" if str(board.outcome) == "exploded" else ("cleared" if reasons.is_empty() else "perfect")
	if record.outcome != outcome or record.perfect_reasons != reasons: return false
	if host == "canonical_pair":
		return record.phase in ["post_challenge", "completed"] and record.relationship_outcome == null \
			and record.applied_result == {"board_only": true}
	if record.phase == "cleared_awaiting_terminal_choice":
		return outcome != "exploded" and record.relationship_outcome == null and record.applied_result.is_empty()
	if outcome == "exploded":
		if record.relationship_outcome != dispositions[board.mine_indices.find(board.exploded_index)]: return false
	elif record.relationship_outcome not in ["dark", "foresight" if outcome == "perfect" else "loved"]: return false
	if record.phase == "settlement_retry": return record.applied_result.is_empty()
	return record.phase in ["post_challenge", "completed"] and not record.applied_result.is_empty()

static func _keys(value: Dictionary, expected: Array) -> bool:
	var keys := value.keys()
	keys.sort()
	var sorted := expected.duplicate()
	sorted.sort()
	return keys == sorted

static func _ok(value: Variant) -> Dictionary:
	return {"ok": true, "code": &"ok", "value": value}

static func _fail(code: StringName) -> Dictionary:
	return {"ok": false, "code": code, "message": "Dating attempt commitment is invalid or would change history"}
