extends RefCounted
## Versioned, detached challenge shell and prepared layout. No live owner or global RNG.
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const JSON_READER := preload("res://scripts/validation/StrictJson.gd")
const BOARD := preload("res://scripts/domain/minesweeper/MinesweeperBoardSchema.gd")
const REDUCER := preload("res://scripts/domain/minesweeper/MinesweeperBoardReducer.gd")
const PREPARATION := preload("res://scripts/domain/minesweeper/MinesweeperPreparationState.gd")
const CAPABILITIES := preload("res://scripts/domain/minesweeper/MinesweeperCapabilityRules.gd")
const RNG := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd")
const KEYS := ["forced_cell", "preparation", "prepared_layout", "shell", "special_cell"]

static func make() -> Dictionary:
	return {"shell": {"flagged_indices": [], "actions": []}, "preparation": null,
		"prepared_layout": null, "forced_cell": -1, "special_cell": -1}

static func plain_frontier(frontier: Dictionary) -> Dictionary:
	var encoded: Dictionary = WRITER.stringify(frontier)
	if not encoded.ok: return encoded
	# StrictJson retains integral numbers while removing runtime StringName enums.
	return JSON_READER.parse_object(str(encoded.value))

static func special_cell(spec: Dictionary, layout: Dictionary) -> int:
	if spec.board_kind != "solo_challenge" or layout.mine_indices.is_empty(): return -1
	var rng := RNG.new()
	rng.seed(&"minesweeper_special_mine_v1", str(spec.placement_nonce))
	var selected: Dictionary = rng.sample_bounded(layout.mine_indices.size())
	return int(layout.mine_indices[int(selected.value.result)])

static func validate(record: Dictionary) -> bool:
	var envelope: Variant = record.get("envelope")
	if not envelope is Dictionary: return false
	var keys: Array = envelope.keys(); keys.sort()
	if keys != KEYS or not envelope.shell is Dictionary \
			or typeof(envelope.forced_cell) != TYPE_INT or typeof(envelope.special_cell) != TYPE_INT: return false
	var spec: Dictionary = record.spec
	if not REDUCER.validate_shell(envelope.shell, int(spec.width), int(spec.height)).get("ok", false): return false
	var policy: Dictionary = CAPABILITIES.build_spec_inputs({"capability_ids": spec.capability_ids}, int(spec.pressure), int(spec.penalty_points_today))
	if not policy.ok or spec.raw_extra_mines != policy.value.raw_extra_mines \
			or spec.requested_mine_count != spec.base_mine_count + policy.value.effective_extra_mines: return false
	var debug: bool = spec.capability_ids.has("forced_no_guess")
	if envelope.preparation != null:
		if not debug or record.phase != "preparing" or not envelope.preparation is Dictionary \
				or not PREPARATION.validate(envelope.preparation).get("ok", false): return false
		for key: String in envelope.preparation.spec:
			if envelope.preparation.spec[key] != spec.get(key): return false
		if str(envelope.preparation.status) != "searching": return false
	elif record.phase == "preparing": return false
	if envelope.prepared_layout != null:
		if not debug or not envelope.prepared_layout is Dictionary \
				or not BOARD.validate_layout(envelope.prepared_layout, spec).get("ok", false): return false
		var rng := RNG.new(); rng.seed(StringName(spec.debug_stream_id), str(spec.debug_nonce))
		var forced: Dictionary = rng.sample_bounded(int(spec.width) * int(spec.height))
		if envelope.forced_cell != int(forced.value.result) or envelope.prepared_layout.mine_indices.has(envelope.forced_cell): return false
	elif envelope.forced_cell != -1: return false
	if debug and record.phase not in ["pre_challenge", "preparing"] and envelope.prepared_layout == null: return false
	if record.board == null:
		return envelope.special_cell == (special_cell(spec, envelope.prepared_layout) if envelope.prepared_layout != null else -1)
	var board: Dictionary = record.board
	if board.actions.size() < envelope.shell.actions.size() \
			or board.actions.slice(0, envelope.shell.actions.size()) != envelope.shell.actions: return false
	if envelope.prepared_layout != null and (board.mine_indices != envelope.prepared_layout.mine_indices \
			or board.mine_count != envelope.prepared_layout.mine_count): return false
	return envelope.special_cell == special_cell(spec, board)

static func advances(before: Dictionary, after: Dictionary) -> bool:
	if before.schema_version != after.schema_version: return false
	if before.schema_version == 2: return true
	var old: Dictionary = before.envelope
	var current: Dictionary = after.envelope
	if current.shell.actions.size() < old.shell.actions.size() \
			or current.shell.actions.slice(0, old.shell.actions.size()) != old.shell.actions: return false
	if before.board != null and current.shell != old.shell: return false
	return old.prepared_layout == current.prepared_layout and old.forced_cell == current.forced_cell \
		and (old.special_cell < 0 or old.special_cell == current.special_cell)
