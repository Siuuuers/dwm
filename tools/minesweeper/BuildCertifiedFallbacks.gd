extends SceneTree

## Builds data/manifests/minesweeper_certified_fallbacks.v1.json (Plan 02 Task 4, dwm-p2r13).
##
## Runs via `-s`, so this extends SceneTree and works in `_init()`. CONSEQUENCE FOR TESTS: probe
## this file with DynamicScriptProbe.load_script() and NEVER instantiate() -- instantiating
## constructs a SceneTree and executes the tool. The pure per-cell logic below (nonce_for(),
## build_one_record(), parse_arguments(), canonical_bytes()) is exercised directly by
## tests/unit/tooling/test_minesweeper_generator_artifacts.gd against tiny synthetic boards without
## ever calling _init() or build_all_records() (which drives the real, expensive difficulty
## manifest and is not something a fast unit suite should run).
##
## Drives MinesweeperGeneratorKernel directly in mode=fallback_construction, before any fallback or
## runtime budget exists, and never imports the tooling-limits ceiling into
## MinesweeperBoardGenerator.gd. Iterates difficulty order beginner, intermediate, expert, then
## first_cell_zero=false,true, then forced cell ascending. Refuses to write unless every request
## stayed under the tooling safety ceiling, the real verifier independently re-certifies every
## written layout, every record's mine_count equals that difficulty's base_mine_count exactly (base
## mines are never reduced), and every first_cell_zero=true record's forced cell has zero mine
## neighbors in the final layout (a "Lucky" first reveal is genuinely blank).

const _KERNEL := preload("res://scripts/domain/minesweeper/MinesweeperGeneratorKernel.gd")
const _VERIFIER := preload("res://scripts/domain/minesweeper/MinesweeperNoGuessVerifier.gd")
const _TOOLING_LIMITS := preload("res://tools/minesweeper/MinesweeperGeneratorToolingLimits.gd")
const _CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const _STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")

const DIFFICULTY_MANIFEST_PATH := "res://data/manifests/minesweeper_difficulties.v1.json"
const ARTIFACT_PATH := "res://data/manifests/minesweeper_certified_fallbacks.v1.json"

const _NONCE_PREFIX := "minesweeper_fallback_v1"
const _KERNEL_MODE := &"fallback_construction"
const _BOARD_KIND := "desktop"
const _ADVANCE_CHUNK := 200_000

const _DIFFICULTY_ORDER := ["beginner", "intermediate", "expert"]
const _ZERO_ORDER := [false, true]

const _MODE_FLAGS := {"write": ["path"], "check": ["path"]}
## Soft internal deadline for one process invocation, well under the ~50-minute host process
## lifetime observed empirically for this tool (see task-4-report.md) so a checkpoint always lands
## before an external kill.
const _WALL_CLOCK_SOFT_DEADLINE_MSEC := 35 * 60 * 1000


# ---- pure, directly-testable helpers ----

## The tool-only, domain-separated per-stream nonce: sha256("minesweeper_fallback_v1\n" +
## difficulty_id + "\n" + str(forced_cell) + "\n" + ("1" if first_cell_zero else "0") + "\n" +
## stream_id). Lowercase hex, matching String.sha256_text().
static func nonce_for(difficulty_id: String, forced_cell: int, first_cell_zero: bool, stream_id: String) -> String:
	var flag: String = "1" if first_cell_zero else "0"
	var composed: String = "%s\n%s\n%d\n%s\n%s" % [_NONCE_PREFIX, difficulty_id, forced_cell, flag, stream_id]
	return composed.sha256_text()


static func _spec_for(difficulty_id: String, width: int, height: int, base_mine_count: int,
		first_cell_zero: bool, forced_cell: int) -> Dictionary:
	var capability_ids: Array[String] = ["first_cell_safe"]
	if first_cell_zero:
		capability_ids.append("first_cell_zero")
	return {
		"schema_version": 1, "board_kind": _BOARD_KIND, "difficulty_id": difficulty_id,
		"width": width, "height": height, "base_mine_count": base_mine_count,
		"raw_extra_mines": 0, "requested_mine_count": base_mine_count,
		"capability_ids": capability_ids,
		"placement_stream_id": "minesweeper_placement_v1",
		"placement_nonce": nonce_for(difficulty_id, forced_cell, first_cell_zero, "minesweeper_placement_v1"),
		"debug_stream_id": "minesweeper_debug_v1",
		"debug_nonce": nonce_for(difficulty_id, forced_cell, first_cell_zero, "minesweeper_debug_v1"),
		"explosion_stream_id": "minesweeper_explosion_v1",
		"explosion_nonce": nonce_for(difficulty_id, forced_cell, first_cell_zero, "minesweeper_explosion_v1"),
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
	}


static func _rng_capture(stream_id: StringName, nonce: String) -> Dictionary:
	var rng := preload("res://scripts/domain/minesweeper/DeterministicRng32.gd").new()
	var seeded: Dictionary = rng.seed(stream_id, nonce)
	if not seeded.get("ok", false):
		return seeded
	return {"ok": true, "value": rng.capture()["value"]}


## Certifies exactly one fallback record for one (difficulty_id, forced_cell, first_cell_zero)
## tuple, looping the kernel only while cumulative operations stay under `ceiling`. Returns
## {"ok":true,"value":{"record":{...}}} on success, or a failure envelope with code
## tooling_safety_ceiling_reached / kernel_rejected / self_check_failed otherwise. This is the unit
## directly exercised by fast tests against tiny synthetic boards.
static func build_one_record(difficulty_id: String, width: int, height: int, base_mine_count: int,
		forced_cell: int, first_cell_zero: bool, ceiling: int) -> Dictionary:
	var spec := _spec_for(difficulty_id, width, height, base_mine_count, first_cell_zero, forced_cell)
	var placement := _rng_capture(&"minesweeper_placement_v1", String(spec["placement_nonce"]))
	if not placement.get("ok", false):
		return placement
	var debug := _rng_capture(&"minesweeper_debug_v1", String(spec["debug_nonce"]))
	if not debug.get("ok", false):
		return debug
	var explosion := _rng_capture(&"minesweeper_explosion_v1", String(spec["explosion_nonce"]))
	if not explosion.get("ok", false):
		return explosion

	var begun: Dictionary = _KERNEL.begin(spec, forced_cell, _KERNEL_MODE,
		placement["value"], debug["value"], explosion["value"])
	if not begun.get("ok", false):
		return {"ok": false, "code": &"kernel_rejected", "message": "kernel.begin() rejected the spec",
			"details": begun}
	var frontier: Dictionary = (begun["value"] as Dictionary)["preparation"]

	while StringName(frontier["status"]) == _KERNEL.STATUS_SEARCHING:
		if int(frontier["operations_used"]) >= ceiling:
			return {"ok": false, "code": &"tooling_safety_ceiling_reached",
				"message": "the tooling safety ceiling was reached before certification",
				"details": {"difficulty_id": difficulty_id, "forced_cell": forced_cell,
					"first_cell_zero": first_cell_zero, "operations_used": frontier["operations_used"]}}
		var remaining: int = ceiling - int(frontier["operations_used"])
		# Never offer less than one candidate's worth (width*height): a smaller operation_limit
		# would make advance() a guaranteed no-op (searching, operations_used unchanged), which
		# would starve the operations_used>=ceiling check above forever. This can overshoot the
		# ceiling by at most one candidate's cost on the final call, which is acceptable for a
		# safety bound this many orders of magnitude below TOOLING_SAFETY_OPERATION_CEILING.
		var call_limit: int = maxi(mini(_ADVANCE_CHUNK, remaining), width * height)
		var advanced: Dictionary = _KERNEL.advance(frontier, call_limit)
		if not advanced.get("ok", false):
			return {"ok": false, "code": &"kernel_rejected", "message": "kernel.advance() rejected the frontier",
				"details": advanced}
		frontier = (advanced["value"] as Dictionary)["preparation"]

	if StringName(frontier["status"]) != _KERNEL.STATUS_CERTIFIED:
		return {"ok": false, "code": &"kernel_exhausted",
			"message": "the kernel search exhausted without certifying", "details": {
				"difficulty_id": difficulty_id, "forced_cell": forced_cell, "first_cell_zero": first_cell_zero}}

	var candidate: Dictionary = frontier["candidate_state"]
	var mine_indices: Array = candidate["mine_indices"]
	var self_check: Dictionary = _self_check(difficulty_id, width, height, base_mine_count,
		forced_cell, first_cell_zero, mine_indices)
	if not self_check.get("ok", false):
		return self_check

	return {"ok": true, "code": &"ok", "value": {"record": {
		"difficulty_id": difficulty_id, "forced_cell": forced_cell, "first_cell_zero": first_cell_zero,
		"mine_indices": mine_indices, "mine_count": (mine_indices as Array).size(),
	}}, "receipt": {}}


## Independent post-build revalidation of one record before it is trusted to write: base mine
## counts unchanged, the real verifier re-certifies the layout, and (for first_cell_zero=true) the
## forced cell's true mine-neighbor count is exactly zero.
static func _self_check(difficulty_id: String, width: int, height: int, base_mine_count: int,
		forced_cell: int, first_cell_zero: bool, mine_indices: Array) -> Dictionary:
	if mine_indices.size() != base_mine_count:
		return {"ok": false, "code": &"base_mine_count_changed",
			"message": "a fallback record's mine_count must equal base_mine_count exactly", "details": {}}
	var layout := {"schema_version": 1, "width": width, "height": height,
		"mine_indices": mine_indices, "mine_count": mine_indices.size()}
	var reverified: Dictionary = _VERIFIER.verify(layout, forced_cell, width * height)
	if not reverified.get("ok", false):
		return {"ok": false, "code": &"self_check_failed",
			"message": "the real verifier did not independently re-certify the layout",
			"details": {"difficulty_id": difficulty_id, "forced_cell": forced_cell}}
	if first_cell_zero:
		var mine_set: Dictionary = {}
		for m: Variant in mine_indices:
			mine_set[int(m)] = true
		var x: int = forced_cell % width
		var y: int = forced_cell / width
		for dy in range(-1, 2):
			for dx in range(-1, 2):
				if dx == 0 and dy == 0:
					continue
				var nx: int = x + dx
				var ny: int = y + dy
				if nx >= 0 and nx < width and ny >= 0 and ny < height:
					if mine_set.has(ny * width + nx):
						return {"ok": false, "code": &"lucky_forced_cell_not_zero",
							"message": "a first_cell_zero record's forced cell must have zero mine neighbors",
							"details": {"difficulty_id": difficulty_id, "forced_cell": forced_cell}}
	return {"ok": true}


static func canonical_bytes(artifact: Dictionary) -> Dictionary:
	var stringified: Dictionary = _CANONICAL_JSON.stringify(artifact)
	if not stringified.get("ok", false):
		return stringified
	return {"ok": true, "value": {"bytes": String(stringified["value"]).to_utf8_buffer()}}


static func parse_arguments(args: PackedStringArray) -> Dictionary:
	if args.size() != 1:
		return _fail(&"generator_argument_count_invalid",
			"exactly one of --write=<path> or --check=<path> is required", {})
	var argument: String = String(args[0])
	for mode: String in _MODE_FLAGS.keys():
		var prefix: String = "--%s=" % mode
		if argument.begins_with(prefix):
			var path: String = argument.substr(prefix.length())
			if path.is_empty():
				return _fail(&"generator_argument_blank", "a flag value is never blank", {"mode": mode})
			return {"ok": true, "value": {"mode": mode, "path": path}}
	return _fail(&"generator_argument_unknown",
		"only --write=<res://path> or --check=<res://path> are legal (no bare mode, no --verify alias)",
		{"argument": argument})


## Reads and minimally structurally validates the frozen difficulty manifest, returning its
## records in file order (beginner, intermediate, expert).
static func read_difficulty_manifest() -> Dictionary:
	if not FileAccess.file_exists(DIFFICULTY_MANIFEST_PATH):
		return _fail(&"difficulty_manifest_missing", "the difficulty manifest is absent", {})
	var parsed: Dictionary = _STRICT_JSON.parse_object(
		FileAccess.get_file_as_bytes(DIFFICULTY_MANIFEST_PATH).get_string_from_utf8())
	if not parsed.get("ok", false):
		return _fail(&"difficulty_manifest_unparsable", "the difficulty manifest is not strict JSON", {})
	var artifact: Dictionary = parsed["value"]
	if int(artifact.get("schema_version", 0)) != 1 or String(artifact.get("kind", "")) != "minesweeper_difficulties":
		return _fail(&"difficulty_manifest_invalid", "the difficulty manifest header is invalid", {})
	var records: Variant = artifact.get("records")
	if typeof(records) != TYPE_ARRAY:
		return _fail(&"difficulty_manifest_invalid", "records must be an array", {})
	var seen_order: Array[String] = []
	for entry: Variant in (records as Array):
		seen_order.append(String((entry as Dictionary)["difficulty_id"]))
	if seen_order != _DIFFICULTY_ORDER:
		return _fail(&"difficulty_manifest_invalid",
			"records must be exactly beginner, intermediate, expert in that order", {})
	return {"ok": true, "value": {"records": (records as Array).duplicate(true)}}


## Drives the full 1,608-record build across the real frozen difficulty manifest. Expensive --
## intended to be invoked only from `_init()`, never from a fast unit suite.
##
## CHECKPOINT/RESUME (dwm-p2r13 Task 4 Phase 2): the observed host environment kills this process
## after roughly 50 minutes of wall-clock regardless of which tool launched it, well short of the
## ~1.75h a single from-scratch pass needs. Since the frozen CLI law is exactly one of
## --write=<path>/--check=<path> with no other flag, resumability is entirely internal and
## automatic: on entry this reads _CHECKPOINT_PATH (a scratch file, never one of the sixteen Task-4
## files) if present and resumes exactly where it left off -- the (difficulty, first_cell_zero,
## forced_cell) enumeration is fully deterministic, so "already have N records" unambiguously means
## "skip the first N enumerated tuples." After every completed record the checkpoint is rewritten
## (atomic scratch-then-rename, matching the final artifact's own publish pattern) so a hard kill
## loses at most one record's worth of work. If the wall-clock since this call began exceeds
## _WALL_CLOCK_SOFT_DEADLINE_MSEC, the function stops (having just checkpointed) and returns
## {"ok":true,"value":{"complete":false,...}} -- NOT a failure; the caller must simply invoke
## --write=<path> again to continue. Once every record is built, the checkpoint file is deleted and
## the complete artifact is returned.
static func build_all_records(ceiling: int) -> Dictionary:
	var difficulties := read_difficulty_manifest()
	if not difficulties.get("ok", false):
		return difficulties
	var difficulty_records: Array = (difficulties["value"] as Dictionary)["records"]

	var records: Array = []
	var resume_from: int = 0
	var checkpoint_loaded := _read_checkpoint()
	if checkpoint_loaded.get("ok", false):
		records = (checkpoint_loaded["value"] as Dictionary)["records"]
		resume_from = records.size()

	var total_tuples := 0
	for entry: Variant in difficulty_records:
		var row: Dictionary = entry
		total_tuples += 2 * int(row["width"]) * int(row["height"])

	var started_msec: int = Time.get_ticks_msec()
	var ordinal := 0
	for entry: Variant in difficulty_records:
		var row: Dictionary = entry
		var difficulty_id: String = String(row["difficulty_id"])
		var width: int = int(row["width"])
		var height: int = int(row["height"])
		var base_mine_count: int = int(row["base_mine_count"])
		for first_cell_zero: bool in _ZERO_ORDER:
			for forced_cell in range(width * height):
				if ordinal < resume_from:
					ordinal += 1
					continue
				var built := build_one_record(difficulty_id, width, height, base_mine_count,
					forced_cell, first_cell_zero, ceiling)
				if not built.get("ok", false):
					return built
				records.append((built["value"] as Dictionary)["record"])
				ordinal += 1
				var checkpointed := _write_checkpoint(records)
				if not checkpointed.get("ok", false):
					return checkpointed
				if Time.get_ticks_msec() - started_msec > _WALL_CLOCK_SOFT_DEADLINE_MSEC:
					return {"ok": true, "value": {
						"complete": false, "records_done": records.size(), "records_total": total_tuples,
					}}

	var artifact := {
		"schema_version": 1, "kind": "minesweeper_certified_fallbacks",
		"registry_version": "minesweeper_certified_fallbacks_v1",
		"generator_version": "dwm_generator_v1", "verifier_version": "visible_deduction_v1",
		"records": records,
	}
	_delete_checkpoint()
	return {"ok": true, "value": {"complete": true, "artifact": artifact}}


static func _checkpoint_path() -> String:
	return ARTIFACT_PATH + ".build-checkpoint.json"


static func _read_checkpoint() -> Dictionary:
	var path: String = _checkpoint_path()
	if not FileAccess.file_exists(path):
		return {"ok": false}
	var parsed: Dictionary = _STRICT_JSON.parse_object(FileAccess.get_file_as_bytes(path).get_string_from_utf8())
	if not parsed.get("ok", false):
		return {"ok": false}
	var checkpoint: Dictionary = parsed["value"]
	if not checkpoint.has("records") or typeof(checkpoint["records"]) != TYPE_ARRAY:
		return {"ok": false}
	return {"ok": true, "value": {"records": (checkpoint["records"] as Array).duplicate(true)}}


static func _write_checkpoint(records: Array) -> Dictionary:
	var canonical: Dictionary = canonical_bytes({"records": records})
	if not canonical.get("ok", false):
		return canonical
	var bytes: PackedByteArray = (canonical["value"] as Dictionary)["bytes"]
	var absolute: String = ProjectSettings.globalize_path(_checkpoint_path())
	var scratch: String = "%s.partial-%d" % [absolute, OS.get_process_id()]
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var file: FileAccess = FileAccess.open(scratch, FileAccess.WRITE)
	if file == null:
		return {"ok": false, "code": &"checkpoint_open_failed", "message": scratch, "details": {}}
	file.store_buffer(bytes)
	file.flush()
	file.close()
	var rename_error: int = DirAccess.rename_absolute(scratch, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(scratch)
		return {"ok": false, "code": &"checkpoint_rename_failed", "message": str(rename_error), "details": {}}
	return {"ok": true}


static func _delete_checkpoint() -> void:
	var absolute: String = ProjectSettings.globalize_path(_checkpoint_path())
	if FileAccess.file_exists(absolute):
		DirAccess.remove_absolute(absolute)


static func _fail(code: StringName, message: String, details: Dictionary) -> Dictionary:
	return {"ok": false, "code": code, "message": message, "details": details}


# ---- CLI entry point ----

func _init() -> void:
	var parsed: Dictionary = parse_arguments(OS.get_cmdline_user_args())
	if not parsed.get("ok", false):
		_reject("ARGUMENTS", parsed)
		return
	var arguments: Dictionary = parsed["value"] as Dictionary
	var mode: String = String(arguments["mode"])
	var path: String = String(arguments["path"])

	var built: Dictionary = build_all_records(_TOOLING_LIMITS.TOOLING_SAFETY_OPERATION_CEILING)
	if not built.get("ok", false):
		_reject("BUILD", built)
		return
	var built_value: Dictionary = built["value"]
	if not bool(built_value.get("complete", false)):
		print("MINESWEEPER_CERTIFIED_FALLBACKS: RESUME_NEEDED %d/%d records checkpointed -- rerun the same command to continue" % [
			int(built_value["records_done"]), int(built_value["records_total"])])
		quit(0)
		return
	var artifact: Dictionary = built_value["artifact"]
	var canonical: Dictionary = canonical_bytes(artifact)
	if not canonical.get("ok", false):
		_reject("SERIALIZE", canonical)
		return
	var bytes: PackedByteArray = (canonical["value"] as Dictionary)["bytes"]

	if mode == "check":
		_run_check(path, bytes)
		return
	_run_write(path, bytes)


func _run_check(path: String, bytes: PackedByteArray) -> void:
	if not FileAccess.file_exists(path):
		_reject("CHECK", {"code": &"target_missing", "message": path})
		return
	var on_disk: PackedByteArray = FileAccess.get_file_as_bytes(path)
	if on_disk != bytes:
		_reject("CHECK", {"code": &"byte_mismatch", "message": "regenerated bytes differ from the target"})
		return
	print("MINESWEEPER_CERTIFIED_FALLBACKS: CHECK_PASS %s" % path)
	quit(0)


func _run_write(path: String, bytes: PackedByteArray) -> void:
	var absolute: String = ProjectSettings.globalize_path(path)
	var directory_error: int = DirAccess.make_dir_recursive_absolute(absolute.get_base_dir())
	if directory_error != OK:
		_reject("WRITE", {"code": &"output_directory_failed", "message": str(directory_error)})
		return
	var scratch: String = "%s.partial-%d" % [absolute, OS.get_process_id()]
	if FileAccess.file_exists(scratch):
		DirAccess.remove_absolute(scratch)
	var file: FileAccess = FileAccess.open(scratch, FileAccess.WRITE)
	if file == null:
		_reject("WRITE", {"code": &"output_open_failed", "message": scratch})
		return
	file.store_buffer(bytes)
	file.flush()
	file.close()
	var reread: PackedByteArray = FileAccess.get_file_as_bytes(scratch)
	if reread != bytes:
		DirAccess.remove_absolute(scratch)
		_reject("WRITE", {"code": &"output_reread_mismatch", "message": "staged bytes differ"})
		return
	var rename_error: int = DirAccess.rename_absolute(scratch, absolute)
	if rename_error != OK:
		DirAccess.remove_absolute(scratch)
		_reject("WRITE", {"code": &"output_rename_failed", "message": str(rename_error)})
		return
	print("MINESWEEPER_CERTIFIED_FALLBACKS: WRITE_PASS %s" % path)
	quit(0)


func _reject(stage: String, envelope: Dictionary) -> void:
	printerr("MINESWEEPER_CERTIFIED_FALLBACKS_%s_REJECTED: %s: %s" % [
		stage, str(envelope.get("code", &"")), str(envelope.get("message", "")),
	])
	quit(1)
