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
const ENVELOPE := preload("res://scripts/application/run/DatingChallengeEnvelope.gd")
const RECORD_KEYS := ["applied_result", "board", "command_sha256", "completion_transaction_id", "context",
	"host", "mine_dispositions", "outcome", "pair_form", "perfect_reasons", "phase", "physical_token",
	"relationship_outcome", "schema_version", "spec"]
const SCENE_RECORD_KEYS := ["schema_version", "completion_transaction_id", "command_sha256", "physical_token",
	"context", "host", "spec", "board", "envelope", "phase", "state", "applied_result"]
const SCENE_CONTEXT_KEYS := ["kind", "scene_occurrence", "challenge_id", "playable_command_id", "registration_sha256"]
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
	var scene: bool = record.schema_version == 4
	if scene and not frozen_effect.is_empty(): return _fail(&"invalid_dating_effect_receipt")
	var mode: String = str(selection.get("mode", ""))
	if not selection.is_empty():
		if mode not in ["branch", "fresh", "continue", "start_from_absence"]: return _fail(&"invalid_dating_selection")
		var fields: Array = ["mode", "source_branch_id", "saved_record"] if mode == "continue" else ["mode"]
		if mode == "start_from_absence": fields = ["mode", "admission", "attempt_id", "generation", "entry_sha256"]
		if not _keys(selection, fields): return _fail(&"invalid_dating_selection")
	var slot: Dictionary = ledger.get(run_id, {}).get(slot_id, {})
	var attempt_id: String = str(record.spec.board_token)
	if scene and not slot.is_empty() and slot.first_attempt_id != attempt_id:
		return _fail(&"scene_challenge_attempt_already_started")
	if mode == "start_from_absence":
		return _prepare_absent_start(ledger, run_id, slot_id, branch_id, record, expected_revision, first_cell_index, selection)
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
		if record.board != null or (record.phase not in ["ready", "preparing", "preparation_failed"] if scene else record.phase != "challenge"):
			return _fail(&"dating_fresh_entry_required")
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
					if progress.record.schema_version == 4 and slot.attempts.size() != 1: return _fail(&"scene_challenge_attempt_already_started")
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
	if record.schema_version == 4:
		return _prepare_scene_flat(ledger, run_id, slot_id, branch_id, record, expected_revision, first_cell_index, frozen_effect)
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
		if not ENVELOPE.advances(previous.record, record) or not _board_advances(previous.record.board, record.board): return _fail(&"dating_attempt_rewind")
	if record.board != null:
		if attempt.materialization_receipt == null:
			if first_cell_index < 0: return _fail(&"dating_first_cell_required")
			attempt.materialization_receipt = {"first_cell_index": first_cell_index,
				"layout": _layout(record.board), "mine_dispositions": record.mine_dispositions.duplicate()}
			if record.schema_version == 3: attempt.materialization_receipt["shell"] = record.envelope.shell.duplicate(true)
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
					or not ENVELOPE.advances(before.record, after.record) \
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
	if record.schema_version == 4: return _validate_scene_attempt(attempt)
	var material: Variant = attempt.materialization_receipt
	if record.board == null:
		if material != null: return _fail(&"invalid_dating_materialization")
	else:
		var material_keys: Array = ["first_cell_index", "layout", "mine_dispositions"]
		if record.schema_version == 3: material_keys.append("shell")
		if not material is Dictionary or not _keys(material, material_keys) \
				or typeof(material.first_cell_index) != TYPE_INT or material.layout != _layout(record.board) \
				or material.mine_dispositions != record.mine_dispositions: return _fail(&"invalid_dating_materialization")
		if record.schema_version == 3 and material.shell != record.envelope.shell: return _fail(&"invalid_dating_materialization")
		var initial: Dictionary = REDUCER.first_reveal(material.layout, material.first_cell_index, material.get("shell", {}))
		if not initial.ok: return _fail(&"invalid_dating_materialization")
		for cell: int in initial.value.board.revealed_indices:
			if not record.board.revealed_indices.has(cell): return _fail(&"invalid_dating_materialization")
		if record.board.actions.size() == (material.shell.actions.size() if record.schema_version == 3 else 0):
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
	if context.get("kind") == "scene_challenge":
		if not _keys(context, SCENE_CONTEXT_KEYS) or not _scene_json(context): return ""
		for key: String in ["scene_occurrence", "challenge_id", "playable_command_id"]:
			if not _id(context[key]): return ""
		if not _hash(context.registration_sha256): return ""
		var hashed: Dictionary = CANONICAL.canonical_sha256([context.scene_occurrence, context.challenge_id])
		return "scene.challenge." + str(hashed.value.sha256) if hashed.ok else ""
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
	if record.schema_version == 4:
		return {"record_version": 4, "context": record.context.duplicate(true), "host": record.host, "spec": record.spec.duplicate(true)}
	var entry := {"spec": record.spec.duplicate(true), "context": record.context.duplicate(true),
		"host": record.host, "pair_form": record.pair_form}
	if record.schema_version == 3:
		entry["record_version"] = 3
		entry["prepared_layout"] = record.envelope.prepared_layout.duplicate(true) if record.envelope.prepared_layout != null else null
		entry["forced_cell"] = record.envelope.forced_cell
	return entry

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

static func validate_record(record: Dictionary) -> bool:
	return _valid_record(record)

static func _valid_record(record: Dictionary) -> bool:
	if record.get("schema_version") == 4: return _valid_scene_record(record)
	var expected_keys: Array = RECORD_KEYS.duplicate()
	if record.get("schema_version") == 3: expected_keys.append("envelope")
	if not _keys(record, expected_keys) or typeof(record.schema_version) != TYPE_INT \
			or record.schema_version not in [2, 3] or record.phase not in PHASES \
			or not record.context is Dictionary or record.context.get("kind") == "scene_challenge" or semantic_slot(record.context).is_empty() \
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
			or record.spec.base_mine_count != dimensions.base_mine_count: return false
	if record.schema_version == 2 and (record.spec.requested_mine_count != dimensions.base_mine_count \
			or record.spec.pressure != 0 or record.spec.penalty_points_today != 0): return false
	if record.board != null and not record.board is Dictionary: return false
	if record.schema_version == 3 and not ENVELOPE.validate(record): return false
	if host == "canonical_solo" and record.pair_form != "": return false
	if host == "canonical_pair" and record.pair_form not in ["ambiguous_sweet", "ambiguous_dark", "love_sweet", "love_dark"]: return false
	if record.board == null:
		return record.phase == "challenge" and record.outcome == null and record.relationship_outcome == null \
			and record.mine_dispositions.is_empty() and record.perfect_reasons.is_empty() and record.applied_result.is_empty()
	if not record.board is Dictionary or not BOARD.validate_board(record.board).ok: return false
	var board: Dictionary = record.board
	if board.width != record.spec.width or board.height != record.spec.height \
			or board.mine_count < record.spec.base_mine_count or board.mine_count > record.spec.requested_mine_count: return false
	var dispositions: Array = RULES.dispositions(record.spec, board.mine_count) if host == "canonical_solo" else []
	if record.mine_dispositions != dispositions: return false
	if not board.terminal or record.phase == "challenge":
		# dwm-634.2: a terminal board still in `challenge` is painted but unsettled; it carries no
		# outcome until its `settle` command runs on a later frame.
		return record.phase == "challenge" and record.outcome == null and record.relationship_outcome == null \
			and record.perfect_reasons.is_empty() and record.applied_result.is_empty()
	var reasons: Array = RULES.perfect_reasons(board, int(record.schema_version))
	var outcome: String = "exploded" if str(board.outcome) == "exploded" else ("cleared" if reasons.is_empty() else "perfect")
	if record.outcome != outcome or record.perfect_reasons != reasons: return false
	if host == "canonical_pair":
		return record.phase in ["post_challenge", "completed"] and record.relationship_outcome == null \
			and record.applied_result == {"board_only": true}
	if record.phase == "cleared_awaiting_terminal_choice":
		return (outcome == "cleared" if record.schema_version == 3 else outcome != "exploded") and record.relationship_outcome == null and record.applied_result.is_empty()
	if outcome == "exploded":
		if record.relationship_outcome != dispositions[board.mine_indices.find(board.exploded_index)]: return false
	elif record.schema_version == 3 and outcome == "perfect":
		if record.relationship_outcome != "foresight": return false
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

## Resolve the original retained execution branch, never the latest sibling. The
## checkpoint's actual write acknowledgement belongs to the source save owner;
## this resolver validates its immutable shape, not the continued presence of bytes.
static func resolve_attempt_proof(ledger: Dictionary, proof: Dictionary) -> Dictionary:
	if not _valid_proof_shape(proof): return _fail(&"invalid_scene_attempt_proof")
	var found: Dictionary = read(ledger, proof.run_id, proof.slot_id, proof.attempt_id, proof.branch_id)
	if not found.ok: return found
	return validate_attempt_proof(found.value, proof)

## Allows the Profile owner's existing exact four-key lookup to supply the record.
static func validate_attempt_proof(attempt: Dictionary, proof: Dictionary) -> Dictionary:
	if not _valid_proof_shape(proof): return _fail(&"invalid_scene_attempt_proof")
	if not validate_attempt(attempt).ok or attempt.record.schema_version != 4 \
			or not attempt.has("generation"): return _fail(&"invalid_scene_attempt_proof")
	for key: String in ["run_id", "slot_id", "attempt_id", "branch_id", "generation", "revision"]:
		if attempt[key] != proof.get(key): return _fail(&"scene_attempt_proof_conflict")
	var hashed: Dictionary = CANONICAL.canonical_sha256(attempt.record)
	if not hashed.ok or hashed.value.sha256 != proof.get("record_sha256"):
		return _fail(&"scene_attempt_proof_conflict")
	return _ok(attempt.duplicate(true))

static func _valid_scene_record(record: Dictionary) -> bool:
	if not _keys(record, SCENE_RECORD_KEYS) or not _scene_json(record) \
			or typeof(record.schema_version) != TYPE_INT or record.schema_version != 4 \
			or not record.context is Dictionary or record.context.get("kind") != "scene_challenge" \
			or semantic_slot(record.context).is_empty() or record.host != "scene_challenge" \
			or not record.spec is Dictionary or not BOARD.validate_spec(record.spec).ok \
			or record.applied_result != {} or record.state not in ["in_progress", "lost", "won"]: return false
	if not _id(record.completion_transaction_id) or not _hash(record.command_sha256) or not _id(record.physical_token): return false
	var token: Dictionary = CANONICAL.canonical_sha256(record.completion_transaction_id + "|" + record.command_sha256)
	if not token.ok or record.physical_token != "dating_challenge." + str(token.value.sha256): return false
	var board_host: String = {"solo_challenge": "canonical_solo", "pair_challenge": "canonical_pair"}.get(record.spec.board_kind, "")
	var geometry: Dictionary = CATALOG.lookup(board_host)
	if not geometry.ok or record.spec.difficulty_id != board_host \
			or record.spec.width != geometry.value.width or record.spec.height != geometry.value.height \
			or record.spec.base_mine_count != geometry.value.base_mine_count: return false
	if not ENVELOPE.validate(record): return false
	if record.board == null:
		return record.phase in ["preparing", "preparation_failed", "ready"] and record.state == "in_progress"
	if not record.board is Dictionary or not BOARD.validate_board(record.board).ok: return false
	var board: Dictionary = record.board
	if board.width != record.spec.width or board.height != record.spec.height \
			or board.mine_count < record.spec.base_mine_count or board.mine_count > record.spec.requested_mine_count: return false
	if not board.terminal: return record.phase == "active" and record.state == "in_progress"
	return record.phase == "terminal" and record.state == ("lost" if str(board.outcome) == "exploded" else "won")

static func _scene_terminal(record: Dictionary) -> Variant:
	if record.state == "in_progress": return null
	return {"state": record.state, "outcome": str(record.board.outcome),
		"perfect_reasons": RULES.perfect_reasons(record.board, 4)}

static func _prepare_scene_flat(ledger: Dictionary, run_id: String, slot_id: String, branch_id: String,
		record: Dictionary, expected_revision: int, first_cell: int, effect: Dictionary) -> Dictionary:
	if not effect.is_empty(): return _fail(&"invalid_dating_effect_receipt")
	var previous: Dictionary = ledger.get(run_id, {}).get(slot_id, {})
	if not previous.is_empty() and not validate_attempt(previous).ok: return _fail(&"invalid_dating_attempt")
	var attempt := {"run_id": run_id, "slot_id": slot_id, "attempt_id": record.spec.board_token,
		"branch_id": branch_id, "revision": 1, "record": record.duplicate(true), "entry_receipt": _entry(record),
		"materialization_receipt": null, "clear_receipt": null, "terminal_receipt": null,
		"effect_receipt": null, "completion_receipt": null}
	if not previous.is_empty():
		if previous.entry_receipt != _entry(record): return _fail(&"dating_entry_conflict")
		if not ENVELOPE.advances(previous.record, record) or not _board_advances(previous.record.board, record.board):
			return _fail(&"dating_attempt_rewind")
		attempt = previous.duplicate(true)
		attempt.record = record.duplicate(true)
	if record.board != null:
		if attempt.materialization_receipt == null:
			if first_cell < 0: return _fail(&"dating_first_cell_required")
			attempt.materialization_receipt = {"first_cell_index": first_cell,
				"layout": _layout(record.board), "shell": record.envelope.shell.duplicate(true)}
		elif first_cell != -1 and first_cell != attempt.materialization_receipt.first_cell_index:
			return _fail(&"dating_materialization_conflict")
	elif first_cell != -1: return _fail(&"dating_materialization_conflict")
	attempt.terminal_receipt = _scene_terminal(record)
	attempt.clear_receipt = attempt.terminal_receipt if record.state == "won" else null
	if not previous.is_empty():
		for key: String in RECEIPTS:
			if previous[key] != null and attempt[key] != previous[key]: return _fail(&"dating_receipt_conflict")
		if attempt == previous: return _ok({"ledger": ledger.duplicate(true), "attempt": attempt, "changed": false})
		attempt.revision = int(previous.revision) + 1
	if expected_revision != int(previous.get("revision", 0)): return _fail(&"dating_revision_conflict")
	if not validate_attempt(attempt).ok: return _fail(&"invalid_dating_attempt")
	var candidate: Dictionary = ledger.duplicate(true)
	if not candidate.has(run_id): candidate[run_id] = {}
	candidate[run_id][slot_id] = attempt.duplicate(true)
	return _ok({"ledger": candidate, "attempt": attempt, "changed": true})

static func _validate_scene_attempt(attempt: Dictionary) -> Dictionary:
	if not _scene_json(attempt): return _fail(&"invalid_dating_attempt")
	var record: Dictionary = attempt.record
	var terminal: Variant = _scene_terminal(record)
	if attempt.terminal_receipt != terminal or attempt.clear_receipt != (terminal if record.state == "won" else null) \
			or attempt.effect_receipt != null or attempt.completion_receipt != null: return _fail(&"invalid_dating_receipt")
	var material: Variant = attempt.materialization_receipt
	if record.board == null:
		return _ok(attempt.duplicate(true)) if material == null else _fail(&"invalid_dating_materialization")
	if not material is Dictionary or not _keys(material, ["first_cell_index", "layout", "shell"]) \
			or typeof(material.first_cell_index) != TYPE_INT or material.layout != _layout(record.board) \
			or material.shell != record.envelope.shell: return _fail(&"invalid_dating_materialization")
	if record.envelope.forced_cell >= 0 and material.first_cell_index != record.envelope.forced_cell:
		return _fail(&"invalid_dating_materialization")
	var initial: Dictionary = REDUCER.first_reveal(material.layout, material.first_cell_index, material.shell)
	if not initial.ok: return _fail(&"invalid_dating_materialization")
	for cell: int in initial.value.board.revealed_indices:
		if cell not in record.board.revealed_indices: return _fail(&"invalid_dating_materialization")
	if record.board.actions.size() == material.shell.actions.size():
		var plain: Dictionary = ENVELOPE.plain_frontier(initial.value.board)
		if not plain.ok or plain.value != record.board: return _fail(&"invalid_dating_materialization")
	return _ok(attempt.duplicate(true))

static func _id(value: Variant) -> bool:
	return value is String and not value.strip_edges().is_empty()

static func _hash(value: Variant) -> bool:
	if not value is String or value.length() != 64: return false
	for character: String in value:
		if character not in "0123456789abcdef": return false
	return true

static func _scene_json(value: Variant) -> bool:
	if value is Dictionary:
		for key: Variant in value:
			if not key is String or not _scene_json(value[key]): return false
	elif value is Array:
		for child: Variant in value:
			if not _scene_json(child): return false
	elif typeof(value) not in [TYPE_NIL, TYPE_BOOL, TYPE_INT, TYPE_STRING]: return false
	return true

static func _valid_proof_shape(proof: Dictionary) -> bool:
	if not _keys(proof, ["run_id", "slot_id", "attempt_id", "branch_id", "generation", "revision", "record_sha256", "checkpoint"]) \
			or not _scene_json(proof): return false
	for key: String in ["run_id", "slot_id", "attempt_id", "branch_id"]:
		if not _id(proof[key]): return false
	if typeof(proof.generation) != TYPE_INT or proof.generation < 1 \
			or typeof(proof.revision) != TYPE_INT or proof.revision < 1 or not _hash(proof.record_sha256) \
			or not proof.checkpoint is Dictionary \
			or not _keys(proof.checkpoint, ["checkpoint_id", "checkpoint_sequence", "snapshot_sha256"]) \
			or not _id(proof.checkpoint.checkpoint_id) or typeof(proof.checkpoint.checkpoint_sequence) != TYPE_INT \
			or proof.checkpoint.checkpoint_sequence < 1 or not _hash(proof.checkpoint.snapshot_sha256):
		return false
	return true

## This pure branch verifies comparison material; Profile's privately configured
## live authority must authorize the selected absence before any durable write.
static func _prepare_absent_start(ledger: Dictionary, run_id: String, slot_id: String, branch_id: String,
		record: Dictionary, expected_revision: int, first_cell: int, selection: Dictionary) -> Dictionary:
	if record.schema_version != 4 or not _scene_json(selection) or expected_revision != 0 or first_cell != -1 \
			or not _valid_absence_admission(selection.get("admission"), run_id, branch_id, record.context) \
			or not _id(selection.attempt_id) or typeof(selection.generation) != TYPE_INT \
			or not _hash(selection.entry_sha256): return _fail(&"invalid_scene_absence_selection")
	var first: Dictionary = read(ledger, run_id, slot_id)
	if not first.ok or first.value.is_empty(): return _fail(&"dating_attempt_missing")
	var original: Dictionary = first.value
	var entry_hash: Dictionary = CANONICAL.canonical_sha256(original.entry_receipt)
	if not entry_hash.ok or original.attempt_id != selection.attempt_id or original.generation != selection.generation \
			or entry_hash.value.sha256 != selection.entry_sha256 or _entry(record) != original.entry_receipt:
		return _fail(&"dating_entry_conflict")
	for key: String in ["completion_transaction_id", "command_sha256", "physical_token"]:
		if record[key] != original.record[key]: return _fail(&"dating_entry_conflict")
	var current: Dictionary = read(ledger, run_id, slot_id, original.attempt_id, branch_id)
	if current.ok:
		# Profile-before-Run retry must never replace progress with a new revision1.
		return _ok({"ledger": ledger.duplicate(true), "attempt": current.value, "changed": false})
	if branch_id == original.branch_id or record.board != null or record.state != "in_progress" \
			or record.envelope.shell != ENVELOPE.make().shell or record.envelope.prepared_layout != null \
			or record.envelope.forced_cell != -1 or record.envelope.special_cell != -1:
		return _fail(&"invalid_scene_absence_start")
	if record.spec.capability_ids.has("forced_no_guess"):
		if record.phase != "preparing" or record.envelope.preparation == null \
				or record.envelope.preparation.slice_sequence != 0: return _fail(&"invalid_scene_absence_start")
	elif record.phase != "ready" or record.envelope.preparation != null: return _fail(&"invalid_scene_absence_start")
	var prepared: Dictionary = _prepare_flat({}, run_id, slot_id, branch_id, record, 0)
	if not prepared.ok: return prepared
	var attempt: Dictionary = prepared.value.attempt
	attempt["generation"] = original.generation
	var candidate := ledger.duplicate(true)
	candidate[run_id][slot_id].attempts[original.attempt_id].progress_by_branch[branch_id] = _progress(attempt)
	var checked: Dictionary = validate(candidate)
	if not checked.ok: return checked
	return _ok({"ledger": candidate, "attempt": attempt, "changed": true})

static func _valid_absence_admission(value: Variant, run_id: String, branch_id: String, context: Dictionary) -> bool:
	if not value is Dictionary or not _scene_json(value) \
			or not _keys(value, ["restore_transaction_id", "source_locator", "source_identity", "destination_identity",
				"allocation_receipt_id", "remap_receipt_id", "transaction_remap_sha256", "challenge_key"]): return false
	for key: String in ["restore_transaction_id", "allocation_receipt_id", "remap_receipt_id"]:
		if not _id(value[key]): return false
	if not _hash(value.transaction_remap_sha256) or not value.source_locator is Dictionary \
			or not _keys(value.source_locator, ["slot_id", "bundle_id", "checkpoint_id", "document_sha256"]) \
			or not _id(value.source_locator.slot_id) or not _id(value.source_locator.checkpoint_id) \
			or not _hash(value.source_locator.bundle_id) or not _hash(value.source_locator.document_sha256): return false
	for key: String in ["source_identity", "destination_identity"]:
		var identity: Variant = value[key]
		if not identity is Dictionary or not _keys(identity, ["run_id", "branch_id", "desktop_timeline_generation",
				"causal_day_instance", "causal_day_instance_issuer_receipt"]) \
				or identity.run_id != run_id or not _id(identity.branch_id) \
				or typeof(identity.desktop_timeline_generation) != TYPE_INT or identity.desktop_timeline_generation < 0 \
				or not _id(identity.causal_day_instance) or not identity.causal_day_instance_issuer_receipt is Dictionary \
				or identity.causal_day_instance_issuer_receipt.is_empty(): return false
	if value.destination_identity.branch_id != branch_id or value.source_identity.branch_id == branch_id: return false
	return value.challenge_key == {"run_id": run_id, "scene_occurrence": context.scene_occurrence,
		"challenge_id": context.challenge_id, "playable_command_id": context.playable_command_id,
		"registration_sha256": context.registration_sha256}
