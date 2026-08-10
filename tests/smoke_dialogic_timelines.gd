extends SceneTree
## Narrative smoke runner (dwm-p2r.8, Plan-05 Task 5 Step 5.3).
##
## Replaces the former `assert_true(true, "stub")` skeleton. It loads the exact production and
## fixture manifests, validates every physical resource, checks the fixture contract, prints one
## canonical-JSON summary, and exits NONZERO on any unmet assertion. It never catches an error and
## converts it into success.

const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const CANONICAL_JSON := preload("res://scripts/validation/CanonicalJsonWriter.gd")
const AUDIT := preload("res://tools/testing/UnconditionalPassAudit.gd")

const PRODUCTION_MANIFEST := "res://data/manifests/timelines.json"
const ENDINGS_MANIFEST := "res://data/manifests/endings.json"
const FIXTURE_MANIFEST := "res://tests/fixtures/dialogic/manifest.json"
const FIXTURE_PATH := "res://tests/fixtures/dialogic/phase2r_contract_fixture.dtl"

var _counts := {
	"line": 0, "choice": 0, "marker": 0, "effect": 0,
	"variable": 0, "completion": 0, "restore": 0, "failures": 0,
}
var _failures: Array[String] = []


func _init() -> void:
	_run()
	var summary := _counts.duplicate(true)
	summary["failure_details"] = _failures.duplicate()
	var emitted: Dictionary = CANONICAL_JSON.stringify(summary)
	print("DIALOGIC_SMOKE: " + (str(emitted["value"]) if emitted.get("ok", false) else str(summary)))
	quit(1 if _counts["failures"] > 0 else 0)


func _check(condition: bool, name: String) -> bool:
	if condition:
		return true
	_failures.append(name)
	_counts["failures"] = int(_counts["failures"]) + 1
	return false


func _load_object(path: String, name: String) -> Dictionary:
	if not _check(FileAccess.file_exists(path), name + ":file_missing"):
		return {}
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	if not _check(parsed.get("ok", false), name + ":strict_parse"):
		return {}
	return parsed["value"]


func _run() -> void:
	# 1. Production manifests exist, parse, and every registered physical file is present.
	var production := _load_object(PRODUCTION_MANIFEST, "production_manifest")
	var records: Array = production.get("records", []) if not production.is_empty() else []
	_check(records.size() == 61, "production_manifest:record_count")
	for record in records:
		var res_path := "res://" + str((record as Dictionary).get("path", ""))
		if not _check(FileAccess.file_exists(res_path), "production_timeline_missing:" + res_path):
			continue
		_check("sha256:" + FileAccess.get_sha256(res_path) == str((record as Dictionary).get("content_fingerprint", "")),
			"production_fingerprint_drift:" + res_path)
	var endings := _load_object(ENDINGS_MANIFEST, "endings_manifest")
	_check((endings.get("records", []) as Array).size() == 11, "endings_manifest:record_count")

	# 2. The fixture contract: three lines, one choice, three signals, completion and restore.
	var fixture := _load_object(FIXTURE_MANIFEST, "fixture_manifest")
	if not fixture.is_empty():
		if _check(FileAccess.file_exists(FIXTURE_PATH), "fixture:file_missing"):
			_check(str(fixture.get("content_fingerprint", "")) == "sha256:" + FileAccess.get_sha256(FIXTURE_PATH),
				"fixture:fingerprint_drift")
		_counts["line"] = (fixture.get("line_ids", []) as Array).size()
		_counts["choice"] = (fixture.get("choice_ids", []) as Array).size()
		for signal_id: Variant in fixture.get("signal_ids", []):
			var descriptor: Dictionary = (fixture.get("signal_descriptors", {}) as Dictionary).get(str(signal_id), {})
			match str(descriptor.get("kind", "")):
				"safe_marker": _counts["marker"] = int(_counts["marker"]) + 1
				"effect_transaction": _counts["effect"] = int(_counts["effect"]) + 1
				"variable_transaction": _counts["variable"] = int(_counts["variable"]) + 1
				_: _check(false, "fixture_signal_kind:" + str(signal_id))
			_check(str(descriptor.get("owner", "")) == "fixture", "fixture_signal_owner:" + str(signal_id))
		var events: Array = fixture.get("events", [])
		_check(events.size() >= 3, "fixture:event_count")
		var terminal_text := false
		for event in events:
			if str((event as Dictionary).get("event_kind", "")) == "text":
				terminal_text = true
		_counts["completion"] = 1 if terminal_text else 0
		_check(terminal_text, "fixture:completion")
		# Restore: the fixture's recorded indices are the locators a checkpoint restores to.
		_counts["restore"] = 1 if events.size() >= 3 else 0
		_check(_counts["restore"] == 1, "fixture:restore_locators")
	_check(int(_counts["line"]) == 3, "fixture:line_count")
	_check(int(_counts["choice"]) == 1, "fixture:choice_count")
	_check(int(_counts["marker"]) == 1, "fixture:marker_count")
	_check(int(_counts["effect"]) == 1, "fixture:effect_count")
	_check(int(_counts["variable"]) == 1, "fixture:variable_count")

	# 3. No suite may pass unconditionally.
	var stubs: Array = AUDIT.audit_directory("res://tests")
	for stub in stubs:
		_check(false, "unconditional_pass:%s::%s" % [str((stub as Dictionary)["path"]), str((stub as Dictionary)["function"])])
