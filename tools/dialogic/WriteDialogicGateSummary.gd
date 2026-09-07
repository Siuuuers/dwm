extends SceneTree
class_name WriteDialogicGateSummary
## Fail-closed narrative subsystem gate summary (dwm-p2r.8, Plan-05 Task 6).
##
## It records only what was actually proven: exact manifest hashes, the 59/24/35 production counts,
## the fixture counts, and the requirement ids linked to dwm-p2r.8. It NEVER claims implementation
## authorization, and any missing file, non-GREEN result, count mismatch, or duplicate requirement
## id fails the build instead of emitting weaker evidence.

const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")

const ISSUE_ID := "dwm-p2r.8"
const INPUT_KEYS := ["fixture_counts", "logs", "manifests", "requirement_ids"]
const EXPECTED_FIXTURE_COUNTS := {
	"line": 3, "choice": 1, "marker": 1, "effect": 1,
	"variable": 1, "completion": 1, "restore": 1, "failures": 0,
}
const EXPECTED_TOTAL := 59
const EXPECTED_PLACEHOLDER := 24
const EXPECTED_DRAFT := 35
const DEFAULT_OUTPUT := "res://evidence/phase_2r/dialogic/gate_summary.json"


static func build(inputs: Dictionary) -> Dictionary:
	if typeof(inputs) != TYPE_DICTIONARY or not _exact_keys(inputs, INPUT_KEYS):
		return _fail("inputs must have exactly " + str(INPUT_KEYS))
	var manifests: Variant = inputs["manifests"]
	var logs: Variant = inputs["logs"]
	if typeof(manifests) != TYPE_ARRAY or (manifests as Array).is_empty():
		return _fail("manifests must be a nonempty array")
	if typeof(logs) != TYPE_ARRAY or (logs as Array).is_empty():
		return _fail("logs must be a nonempty array")

	var hashes := {}
	var all_paths: Array = []
	all_paths.append_array(manifests as Array)
	all_paths.append_array(logs as Array)
	all_paths.sort()
	for raw_path: Variant in all_paths:
		var path := str(raw_path)
		if path.is_empty() or path.begins_with("/") or ".." in path or path.begins_with("res://"):
			return _fail("paths must be root-relative and must not escape: " + path)
		var res_path := "res://" + path
		if not FileAccess.file_exists(res_path):
			return _fail("missing evidence file: " + path)
		hashes[path] = FileAccess.get_sha256(res_path).to_lower()
		# Every JSON input must strict-parse; a malformed input is never evidence.
		if path.ends_with(".json"):
			var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(res_path))
			if not parsed.get("ok", false):
				return _fail("evidence did not strict-parse: " + path)

	var counts := _production_counts()
	if not counts.get("ok", false):
		return counts
	var fixture_counts: Variant = inputs["fixture_counts"]
	if typeof(fixture_counts) != TYPE_DICTIONARY or not _exact_keys(fixture_counts, EXPECTED_FIXTURE_COUNTS.keys()):
		return _fail("fixture_counts keys must be exactly " + str(EXPECTED_FIXTURE_COUNTS.keys()))
	for key: Variant in EXPECTED_FIXTURE_COUNTS:
		if int((fixture_counts as Dictionary)[key]) != int(EXPECTED_FIXTURE_COUNTS[key]):
			return _fail("fixture count mismatch for %s: %s" % [str(key), str((fixture_counts as Dictionary)[key])])

	var requirement_ids: Variant = inputs["requirement_ids"]
	if typeof(requirement_ids) != TYPE_ARRAY or (requirement_ids as Array).is_empty():
		return _fail("requirement_ids must be a nonempty array")
	var seen := {}
	var sorted_requirements: Array = []
	for raw_id: Variant in (requirement_ids as Array):
		var id := str(raw_id)
		if id.is_empty():
			return _fail("requirement ids must be nonempty")
		if seen.has(id):
			return _fail("duplicate requirement id: " + id)
		seen[id] = true
		sorted_requirements.append(id)
	sorted_requirements.sort()

	return {"ok": true, "code": &"ok", "value": {
		"schema_version": 1,
		"issue_id": ISSUE_ID,
		"manifest_hashes": _sorted_dictionary(hashes),
		"production_counts": counts["value"],
		"fixture_counts": (fixture_counts as Dictionary).duplicate(true),
		"requirement_ids": sorted_requirements,
	}, "receipt": {}}


static func _production_counts() -> Dictionary:
	var path := "res://data/manifests/timelines.json"
	if not FileAccess.file_exists(path):
		return _fail("production manifest is missing")
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if not parsed.get("ok", false):
		return _fail("production manifest did not strict-parse")
	var records: Variant = (parsed["value"] as Dictionary).get("records")
	if typeof(records) != TYPE_ARRAY:
		return _fail("production manifest records must be an array")
	var placeholder := 0
	var draft := 0
	for record: Variant in (records as Array):
		match str((record as Dictionary).get("content_status", "")):
			"placeholder": placeholder += 1
			"draft": draft += 1
			_: return _fail("unexpected content status in the production manifest")
	if (records as Array).size() != EXPECTED_TOTAL or placeholder != EXPECTED_PLACEHOLDER or draft != EXPECTED_DRAFT:
		return _fail("production counts must be %d/%d/%d" % [EXPECTED_TOTAL, EXPECTED_PLACEHOLDER, EXPECTED_DRAFT])
	return {"ok": true, "value": {"total": (records as Array).size(), "placeholder": placeholder, "draft": draft}}


static func _sorted_dictionary(source: Dictionary) -> Dictionary:
	var keys: Array = source.keys()
	keys.sort()
	var out := {}
	for key: Variant in keys:
		out[key] = source[key]
	return out


static func _exact_keys(target: Dictionary, keys: Array) -> bool:
	if target.size() != keys.size():
		return false
	for key: Variant in keys:
		if not target.has(key):
			return false
	return true


static func _fail(message: String) -> Dictionary:
	return {"ok": false, "code": &"gate_evidence_invalid", "message": message, "details": {}}


func _init() -> void:
	quit(_run())


func _run() -> int:
	var output := DEFAULT_OUTPUT
	for argument: String in OS.get_cmdline_user_args():
		if argument.begins_with("--output="):
			output = argument.trim_prefix("--output=")
		else:
			printerr("GATE_SUMMARY: unknown flag: " + argument)
			return 1
	var built := build({
		"manifests": [
			"data/manifests/timelines.json", "data/manifests/endings.json",
			"data/manifests/effects.json", "data/manifests/routes.json",
			"data/manifests/narrative_variables.json",
		],
		"logs": [
			"evidence/phase_2r/dialogic/addon_api.json",
			"evidence/phase_2r/dialogic/timeline_inventory.json",
			"tests/fixtures/dialogic/manifest.json",
		],
		"fixture_counts": EXPECTED_FIXTURE_COUNTS.duplicate(true),
		"requirement_ids": [
			"req.dialogic.authority", "req.dialogic.manifest", "req.dialogic.effects",
			"req.dialogic.visited", "req.dialogic.skip", "req.dialogic.content_status",
			"req.test.dialogic_fixture", "req.locale.narrative_deferred",
		],
	})
	if not built.get("ok", false):
		printerr("GATE_SUMMARY: FAIL " + str(built))
		return 1
	var emitted: Dictionary = CANONICAL_JSON.stringify(built["value"])
	if not emitted.get("ok", false):
		printerr("GATE_SUMMARY: canonical serialization failed")
		return 1
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(output.get_base_dir()))
	var file := FileAccess.open(output, FileAccess.WRITE)
	if file == null:
		printerr("GATE_SUMMARY: cannot write " + output)
		return 1
	file.store_string(str(emitted["value"]) + "\n")
	file.close()
	# Strict re-read: the bytes on disk must be exactly what we claimed.
	var reread: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(output))
	if not reread.get("ok", false) or str(CANONICAL_JSON.stringify(reread["value"]).get("value", "")) != str(emitted["value"]):
		printerr("GATE_SUMMARY: re-read mismatch")
		return 1
	print("GATE_SUMMARY: PASS " + output)
	return 0
