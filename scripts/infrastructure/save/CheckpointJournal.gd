class_name CheckpointJournal
extends RefCounted


const RUN_SNAPSHOT_SCHEMA := preload("res://scripts/domain/run/RunSnapshotSchema.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const LINE_RETENTION := 32
const MANUAL_SAVE_RETENTION := 32
const SEMANTIC_RETENTION := 2
const SEMANTIC_KINDS: Array[String] = [
	"day_start", "timeline_start", "timeline_complete", "choice", "variable_transaction",
	"effect_transaction", "safe_marker", "scene_transition", "pre_board", "post_result",
	"day_resolution_stage", "manual_save",
]
const CANDIDATE_KEYS: Array[String] = ["candidate_kind", "current", "earlier", "next_sequence", "run_id"]

var _run_id := ""
var _next_sequence := 1
var _current: Dictionary = {}
var _earlier: Array[Dictionary] = []
var _bundle_proofs: Dictionary = {}

func reset(run_id: String) -> Dictionary:
	if run_id.is_empty():
		return _fail(&"invalid_run_id", "run_id must be nonempty")
	_run_id = run_id
	_next_sequence = 1
	_current = {}
	_earlier = []
	_bundle_proofs = {}
	return {"ok": true, "code": &"ok"}

func peek_next_sequence(run_id: String) -> Dictionary:
	if run_id != _run_id:
		return _fail(&"run_mismatch", run_id)
	return {"ok": true, "code": &"ok", "value": {"checkpoint_sequence": _next_sequence}}

func prepare_record(snapshot: Dictionary, checkpoint_kind: StringName,
		proven_candidate: Dictionary = {}) -> Dictionary:
	var kind := String(checkpoint_kind)
	if kind != "line" and kind not in SEMANTIC_KINDS:
		return _fail(&"unknown_checkpoint_kind", kind)
	var candidate_snapshot: Dictionary
	if not proven_candidate.is_empty() and is_same(proven_candidate, snapshot):
		candidate_snapshot = snapshot
	else:
		var validated: Dictionary = RUN_SNAPSHOT_SCHEMA.validate(snapshot)
		if not validated.get("ok", false):
			return validated
		candidate_snapshot = validated["value"]["candidate"]
	if str(candidate_snapshot["run_id"]) != _run_id:
		return _fail(&"run_mismatch", str(candidate_snapshot["run_id"]))
	if int(candidate_snapshot["checkpoint_sequence"]) != _next_sequence:
		return _fail(&"sequence_mismatch",
			"expected %d, got %d" % [_next_sequence, int(candidate_snapshot["checkpoint_sequence"])])
	var earlier: Array[Dictionary] = []
	if candidate_snapshot.get("schema_version") != RUN_SNAPSHOT_SCHEMA.SCENE_SCHEMA_VERSION:
		earlier = _earlier.duplicate(true)
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

func prepare_scene_new_run_reset(snapshot: Dictionary, allocation_candidate: Dictionary,
		profile_material: Dictionary, bundle: Dictionary, issuer: Object) -> Dictionary:
	var validated: Dictionary = RUN_SNAPSHOT_SCHEMA.validate_scene_new_run_candidate(
		snapshot, allocation_candidate, profile_material, bundle, issuer)
	if not validated.get("ok", false): return validated
	var candidate_snapshot: Dictionary = validated["value"]["candidate"]
	return {"ok": true, "code": &"ok", "value": {"candidate": {
		"candidate_kind": "reset", "run_id": candidate_snapshot["run_id"], "next_sequence": 2,
		"current": {"checkpoint_kind": "day_start", "snapshot": candidate_snapshot}, "earlier": [],
	}}}

func commit_scene_new_run_reset(candidate: Dictionary, allocation_candidate: Dictionary,
		profile_material: Dictionary, bundle: Dictionary, issuer: Object) -> Dictionary:
	if typeof(candidate.get("current")) != TYPE_DICTIONARY \
			or typeof(candidate["current"].get("snapshot")) != TYPE_DICTIONARY:
		return _fail(&"invalid_candidate", "scene creation requires a current snapshot")
	var prepared := prepare_scene_new_run_reset(candidate["current"]["snapshot"],
		allocation_candidate, profile_material, bundle, issuer)
	if not prepared.get("ok", false): return prepared
	if not CANONICAL_JSON._deep_same(candidate, prepared["value"]["candidate"]):
		return _fail(&"invalid_candidate", "scene creation reset differs from validated retained material")
	if candidate["run_id"] == _run_id and candidate["next_sequence"] == _next_sequence:
		return {"ok": false, "code": &"duplicate_commit", "message": candidate["run_id"]}
	return _install_prepared(candidate)

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
		"reset":
			if str(candidate["run_id"]) == _run_id and int(candidate["next_sequence"]) == _next_sequence:
				return {"ok": false, "code": &"duplicate_commit", "message": str(candidate["run_id"])}
	return _install_prepared(candidate)

func _install_prepared(candidate: Dictionary) -> Dictionary:
	var candidate_kind := str(candidate["candidate_kind"])
	_run_id = str(candidate["run_id"])
	_next_sequence = int(candidate["next_sequence"])
	_current = (candidate["current"] as Dictionary).duplicate(true)
	_earlier.assign((candidate["earlier"] as Array).duplicate(true))
	if candidate_kind == "record":
		_forget_unretained_bundle_proofs()
	else:
		_bundle_proofs = {}
	return {"ok": true, "code": &"ok",
		"value": {"checkpoint_id": str(_current["snapshot"]["checkpoint_id"])}}

func remember_committed_bundle_text(checkpoint_id: String, text: String,
		document_bundle: Dictionary = {}) -> bool:
	if text.is_empty() or _current.is_empty():
		return false
	if str((_current["snapshot"] as Dictionary)["checkpoint_id"]) != checkpoint_id:
		return false
	_bundle_proofs[checkpoint_id] = {"text": text, "document_bundle": document_bundle.duplicate(true)}
	return true

func remember_written_retained_bundle(checkpoint_id: String, text: String,
		document_bundle: Dictionary) -> bool:
	if text.is_empty() or document_bundle.is_empty():
		return false
	var retained := get_retained_bundle(checkpoint_id)
	if retained.is_empty() or not CANONICAL_JSON._deep_same(retained, document_bundle):
		return false
	var keys: Array = document_bundle.keys()
	keys.sort()
	if keys != ["checkpoint_kind", "snapshot"] or document_bundle.get("snapshot") is not Dictionary:
		return false
	var kind := str(document_bundle.get("checkpoint_kind", ""))
	if kind != "line" and kind not in SEMANTIC_KINDS:
		return false
	var validated := RUN_SNAPSHOT_SCHEMA.validate(document_bundle["snapshot"])
	if not validated.get("ok", false) or not CANONICAL_JSON._deep_same(
			document_bundle["snapshot"], validated["value"]["candidate"]):
		return false
	_bundle_proofs[checkpoint_id] = {"text": text, "document_bundle": {
		"checkpoint_kind": kind, "snapshot": validated["value"]["candidate"],
	}}
	return true

func get_retained_bundle_text(checkpoint_id: String) -> String:
	var proof: Dictionary = _bundle_proofs.get(checkpoint_id, {})
	return str(proof.get("text", ""))

func get_retained_bundle_document(checkpoint_id: String) -> Dictionary:
	var proof: Dictionary = _bundle_proofs.get(checkpoint_id, {})
	var document_bundle: Dictionary = proof.get("document_bundle", {})
	return document_bundle

func get_retained_bundle(checkpoint_id: String) -> Dictionary:
	if not _current.is_empty() \
			and str((_current["snapshot"] as Dictionary)["checkpoint_id"]) == checkpoint_id:
		return _current
	for bundle: Dictionary in _earlier:
		if str((bundle["snapshot"] as Dictionary)["checkpoint_id"]) == checkpoint_id:
			return bundle
	return {}

func _forget_unretained_bundle_proofs() -> void:
	if _bundle_proofs.is_empty():
		return
	var retained := {}
	if not _current.is_empty():
		retained[str((_current["snapshot"] as Dictionary)["checkpoint_id"])] = true
	for bundle: Dictionary in _earlier:
		retained[str((bundle["snapshot"] as Dictionary)["checkpoint_id"])] = true
	for checkpoint_id: String in _bundle_proofs.keys():
		if not retained.has(checkpoint_id):
			_bundle_proofs.erase(checkpoint_id)

func get_current_bundle() -> Dictionary:
	if _current.is_empty():
		return _fail(&"empty_journal", _run_id)
	return {"ok": true, "code": &"ok", "value": {"bundle": _current.duplicate(true)}}

func get_bundles_for_disk() -> Array[Dictionary]:
	if _current.get("snapshot", {}).get("schema_version") == RUN_SNAPSHOT_SCHEMA.SCENE_SCHEMA_VERSION:
		return []
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
	return _prepare_seed_from_valid_bundles(valid_bundles, selected_bundle, diagnostics)

func _prepare_seed_from_valid_bundles(valid_bundles: Array, selected_bundle: Dictionary,
		diagnostics: Array[Dictionary]) -> Dictionary:
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
	if typeof(backup["current"]) != TYPE_DICTIONARY or typeof(backup["earlier"]) != TYPE_ARRAY \
			or typeof(backup["next_sequence"]) != TYPE_INT:
		return _fail(&"invalid_backup", "malformed backup field types")
	_run_id = str(backup["run_id"])
	_next_sequence = int(backup["next_sequence"])
	_current = (backup["current"] as Dictionary).duplicate(true)
	_earlier.assign((backup["earlier"] as Array).duplicate(true))
	_bundle_proofs = {}
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
	var manual_saves: Array[Dictionary] = []
	for bundle: Dictionary in earlier:
		if str(bundle.get("checkpoint_kind", "")) == "line":
			lines.append(bundle)
		elif str(bundle.get("checkpoint_kind", "")) == "manual_save":
			manual_saves.append(bundle)
		else:
			anchors.append(bundle)
	if lines.size() > LINE_RETENTION:
		lines = lines.slice(lines.size() - LINE_RETENTION)
	if manual_saves.size() > MANUAL_SAVE_RETENTION:
		manual_saves = manual_saves.slice(manual_saves.size() - MANUAL_SAVE_RETENTION)
	if anchors.size() > SEMANTIC_RETENTION:
		anchors = anchors.slice(anchors.size() - SEMANTIC_RETENTION)
	var retained: Array[Dictionary] = anchors + lines + manual_saves
	retained.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		return int(a["snapshot"]["checkpoint_sequence"]) < int(b["snapshot"]["checkpoint_sequence"]))
	return retained

