class_name CheckpointJournal
extends RefCounted

## Monotonic, bounded, single-run in-memory checkpoint journal
## (docs/superpowers/plans/2026-07-17-phase-2r-03-lifecycle-save.md Task 5).

const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")

const LINE_RETENTION := 32
const SEMANTIC_KINDS: Array[String] = [
	"day_start", "timeline_start", "timeline_complete", "choice", "variable_transaction",
	"effect_transaction", "safe_marker", "scene_transition", "pre_board", "post_result",
	"day_resolution_stage",
]
const CANDIDATE_KEYS: Array[String] = ["candidate_kind", "current", "earlier", "next_sequence", "run_id"]

var _run_id := ""
var _next_sequence := 1
var _current: Dictionary = {}
var _earlier: Array[Dictionary] = []

func reset(run_id: String) -> Dictionary:
	if run_id.is_empty():
		return _fail(&"invalid_run_id", "run_id must be nonempty")
	_run_id = run_id
	_next_sequence = 1
	_current = {}
	_earlier = []
	return {"ok": true, "code": &"ok"}

func peek_next_sequence(run_id: String) -> Dictionary:
	if run_id != _run_id:
		return _fail(&"run_mismatch", run_id)
	return {"ok": true, "code": &"ok", "value": {"checkpoint_sequence": _next_sequence}}

func prepare_record(snapshot: Dictionary, checkpoint_kind: StringName) -> Dictionary:
	var kind := String(checkpoint_kind)
	if kind != "line" and kind not in SEMANTIC_KINDS:
		return _fail(&"unknown_checkpoint_kind", kind)
	var validated: Dictionary = RUN_SNAPSHOT_SCHEMA.validate(snapshot)
	if not validated.get("ok", false):
		return validated
	var candidate_snapshot: Dictionary = validated["value"]["candidate"]
	if str(candidate_snapshot["run_id"]) != _run_id:
		return _fail(&"run_mismatch", str(candidate_snapshot["run_id"]))
	if int(candidate_snapshot["checkpoint_sequence"]) != _next_sequence:
		return _fail(&"sequence_mismatch",
			"expected %d, got %d" % [_next_sequence, int(candidate_snapshot["checkpoint_sequence"])])
	var earlier: Array[Dictionary] = _earlier.duplicate(true)
	if not _current.is_empty():
		earlier.append(_current.duplicate(true))
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"candidate_kind": "record",
		"run_id": _run_id,
		"next_sequence": _next_sequence + 1,
		"current": {"checkpoint_kind": kind, "snapshot": candidate_snapshot},
		"earlier": _retained(earlier),
	}}}

func prepare_reset_with_initial(snapshot: Dictionary, checkpoint_kind: StringName) -> Dictionary:
	if checkpoint_kind != &"day_start":
		return _fail(&"invalid_reset_kind", String(checkpoint_kind))
	var validated: Dictionary = RUN_SNAPSHOT_SCHEMA.validate(snapshot)
	if not validated.get("ok", false):
		return validated
	var candidate_snapshot: Dictionary = validated["value"]["candidate"]
	var lifecycle: Dictionary = candidate_snapshot["lifecycle"]
	if int(lifecycle["day"]) != 1 or str(lifecycle["state"]) != "PLAYING":
		return _fail(&"invalid_initial_snapshot", "reset requires Day 1 PLAYING")
	if int(candidate_snapshot["checkpoint_sequence"]) != 1:
		return _fail(&"invalid_initial_snapshot", "reset requires checkpoint_sequence 1")
	if str(candidate_snapshot["checkpoint_id"]) != str(candidate_snapshot["run_id"]) + ":1":
		return _fail(&"invalid_initial_snapshot", "reset requires checkpoint_id <run_id>:1")
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"candidate_kind": "reset",
		"run_id": str(candidate_snapshot["run_id"]),
		"next_sequence": 2,
		"current": {"checkpoint_kind": "day_start", "snapshot": candidate_snapshot},
		"earlier": [],
	}}}

func commit_prepared(candidate: Dictionary) -> Dictionary:
	var shape_error := _validate_candidate(candidate)
	if shape_error != "":
		return _fail(&"invalid_candidate", shape_error)
	var candidate_kind := str(candidate["candidate_kind"])
	var current_sequence := int((candidate["current"] as Dictionary)["snapshot"]["checkpoint_sequence"])
	match candidate_kind:
		"record":
			if str(candidate["run_id"]) != _run_id:
				return _fail(&"run_mismatch", str(candidate["run_id"]))
			if current_sequence == _next_sequence - 1 and _next_sequence > 1:
				return {"ok": false, "code": &"duplicate_commit", "message": str(current_sequence)}
			if current_sequence != _next_sequence:
				return _fail(&"sequence_mismatch",
					"expected %d, got %d" % [_next_sequence, current_sequence])
		"reset", "seed":
			if str(candidate["run_id"]) == _run_id and int(candidate["next_sequence"]) == _next_sequence:
				return {"ok": false, "code": &"duplicate_commit", "message": str(candidate["run_id"])}
	_run_id = str(candidate["run_id"])
	_next_sequence = int(candidate["next_sequence"])
	_current = (candidate["current"] as Dictionary).duplicate(true)
	_earlier.assign((candidate["earlier"] as Array).duplicate(true))
	return {"ok": true, "code": &"ok",
		"value": {"checkpoint_id": str(_current["snapshot"]["checkpoint_id"])}}

func get_current_bundle() -> Dictionary:
	if _current.is_empty():
		return _fail(&"empty_journal", _run_id)
	return {"ok": true, "code": &"ok", "value": {"bundle": _current.duplicate(true)}}

func get_bundles_for_disk() -> Array[Dictionary]:
	return _earlier.duplicate(true)

func prepare_seed(document: Dictionary, selected_bundle: Dictionary) -> Dictionary:
	var current_snapshot: Variant = document.get("current_snapshot")
	if typeof(current_snapshot) != TYPE_DICTIONARY:
		return _fail(&"invalid_document", "document lacks current_snapshot")
	var raw_bundles: Array = [(current_snapshot as Dictionary)]
	for entry: Variant in document.get("recovery_journal", []):
		raw_bundles.append(entry)
	var diagnostics: Array[Dictionary] = []
	var valid_bundles: Array[Dictionary] = []
	for index: int in range(raw_bundles.size()):
		var bundle: Variant = raw_bundles[index]
		if typeof(bundle) != TYPE_DICTIONARY or typeof((bundle as Dictionary).get("snapshot")) != TYPE_DICTIONARY:
			diagnostics.append({"index": index, "code": "invalid_bundle_shape"})
			continue
		var validated: Dictionary = RUN_SNAPSHOT_SCHEMA.validate(bundle["snapshot"])
		if not validated.get("ok", false):
			diagnostics.append({"index": index, "code": str(validated.get("code", "invalid_snapshot"))})
			continue
		valid_bundles.append({
			"checkpoint_kind": str(bundle.get("checkpoint_kind", "")),
			"snapshot": validated["value"]["candidate"],
		})
	var selected_id := ""
	if typeof(selected_bundle.get("snapshot")) == TYPE_DICTIONARY:
		selected_id = str((selected_bundle["snapshot"] as Dictionary).get("checkpoint_id", ""))
	var selected: Dictionary = {}
	for bundle: Dictionary in valid_bundles:
		if str(bundle["snapshot"]["checkpoint_id"]) == selected_id:
			selected = bundle
	if selected.is_empty():
		return _fail(&"selected_bundle_missing", selected_id)
	var selected_run := str(selected["snapshot"]["run_id"])
	var selected_sequence := int(selected["snapshot"]["checkpoint_sequence"])
	var earlier: Array[Dictionary] = []
	for bundle: Dictionary in valid_bundles:
		if str(bundle["snapshot"]["run_id"]) != selected_run:
			continue
		var sequence := int(bundle["snapshot"]["checkpoint_sequence"])
		if sequence < selected_sequence:
			earlier.append(bundle)
	earlier.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["snapshot"]["checkpoint_sequence"]) < int(b["snapshot"]["checkpoint_sequence"]))
	return {"ok": true, "code": &"ok", "value": {
		"candidate": {
			"candidate_kind": "seed",
			"run_id": selected_run,
			"next_sequence": selected_sequence + 1,
			"current": selected.duplicate(true),
			"earlier": _retained(earlier),
		},
		"diagnostics": diagnostics,
	}}

func capture_state() -> Dictionary:
	return {"ok": true, "code": &"ok", "value": {"backup": {
		"run_id": _run_id,
		"next_sequence": _next_sequence,
		"current": _current.duplicate(true),
		"earlier": _earlier.duplicate(true),
	}}}

func restore_state(backup: Dictionary) -> Dictionary:
	for key: String in ["run_id", "next_sequence", "current", "earlier"]:
		if not backup.has(key):
			return _fail(&"invalid_backup", "missing key: " + key)
	_run_id = str(backup["run_id"])
	_next_sequence = int(backup["next_sequence"])
	_current = (backup["current"] as Dictionary).duplicate(true)
	_earlier.assign((backup["earlier"] as Array).duplicate(true))
	return {"ok": true, "code": &"ok"}

func _validate_candidate(candidate: Dictionary) -> String:
	var keys: Array = candidate.keys()
	keys.sort()
	var expected := CANDIDATE_KEYS.duplicate()
	expected.sort()
	if keys != Array(expected):
		return "unexpected candidate keys: " + str(keys)
	if str(candidate["candidate_kind"]) not in ["record", "reset", "seed"]:
		return "unknown candidate kind: " + str(candidate["candidate_kind"])
	if str(candidate["run_id"]).is_empty():
		return "run_id must be nonempty"
	if typeof(candidate["current"]) != TYPE_DICTIONARY \
			or typeof((candidate["current"] as Dictionary).get("snapshot")) != TYPE_DICTIONARY:
		return "current must be a bundle"
	var current_validated: Dictionary = RUN_SNAPSHOT_SCHEMA.validate(candidate["current"]["snapshot"])
	if not current_validated.get("ok", false):
		return "invalid current snapshot: " + str(current_validated.get("message", ""))
	if str(candidate["current"]["snapshot"]["run_id"]) != str(candidate["run_id"]):
		return "current snapshot run must match the candidate run"
	if typeof(candidate["next_sequence"]) != TYPE_INT \
			or int(candidate["next_sequence"]) != int(candidate["current"]["snapshot"]["checkpoint_sequence"]) + 1:
		return "next_sequence must be the current sequence + 1"
	if typeof(candidate["earlier"]) != TYPE_ARRAY:
		return "earlier must be an array"
	var previous := 0
	for bundle: Variant in (candidate["earlier"] as Array):
		if typeof(bundle) != TYPE_DICTIONARY or typeof((bundle as Dictionary).get("snapshot")) != TYPE_DICTIONARY:
			return "earlier entries must be bundles"
		var sequence := int((bundle as Dictionary)["snapshot"].get("checkpoint_sequence", 0))
		if sequence <= previous:
			return "earlier bundles must ascend by sequence"
		if sequence >= int(candidate["current"]["snapshot"]["checkpoint_sequence"]):
			return "earlier bundles must precede the current bundle"
		previous = sequence
	return ""

static func _fail(code: StringName, message: String) -> Dictionary:
	return {"ok": false, "code": code, "message": message}

static func _retained(earlier: Array[Dictionary]) -> Array[Dictionary]:
	var anchors: Array[Dictionary] = []
	var lines: Array[Dictionary] = []
	for bundle: Dictionary in earlier:
		if str(bundle.get("checkpoint_kind", "")) == "line":
			lines.append(bundle)
		else:
			anchors.append(bundle)
	if lines.size() > LINE_RETENTION:
		lines = lines.slice(lines.size() - LINE_RETENTION)
	var retained: Array[Dictionary] = anchors + lines
	retained.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["snapshot"]["checkpoint_sequence"]) < int(b["snapshot"]["checkpoint_sequence"]))
	return retained
