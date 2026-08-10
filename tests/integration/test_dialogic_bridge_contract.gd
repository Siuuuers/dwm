extends "res://addons/gut/test.gd"
# Physical Dialogic fixture contract (dwm-p2r.8, Plan-05 Task 5). RED-first on the physical files:
# no assertion here may be unconditional, and none may mutate a gameplay autoload.

const FIXTURE_PATH := "res://tests/fixtures/dialogic/phase2r_contract_fixture.dtl"
const FIXTURE_MANIFEST := "res://tests/fixtures/dialogic/manifest.json"
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")


func _manifest() -> Dictionary:
	if not FileAccess.file_exists(FIXTURE_MANIFEST):
		return {}
	var parsed: Dictionary = STRICT_JSON.parse_object(FileAccess.get_file_as_string(FIXTURE_MANIFEST))
	return parsed.get("value", {}) if parsed.get("ok", false) else {}


func test_physical_fixture_and_manifest_are_required() -> void:
	assert_true(FileAccess.file_exists(FIXTURE_PATH), "missing physical Dialogic fixture")
	assert_true(FileAccess.file_exists(FIXTURE_MANIFEST), "missing fixture manifest")


func test_fixture_manifest_is_strict_and_separate_from_production() -> void:
	var manifest := _manifest()
	if manifest.is_empty():
		assert_true(false, "fixture manifest must strict-parse")
		return
	assert_eq(str(manifest.get("timeline_id", "")), "fixture.phase2r.contract", "the fixture owns its own timeline id")
	assert_eq(int(manifest.get("schema_version", 0)), 1, "fixture manifest schema_version")
	# It must NOT be one of the 61 production records.
	var production := STRICT_JSON.parse_object(FileAccess.get_file_as_string("res://data/manifests/timelines.json"))
	if production.get("ok", false):
		for record in (production["value"] as Dictionary).get("records", []):
			assert_false(str((record as Dictionary).get("id", "")) == "fixture.phase2r.contract",
				"the test fixture must never enter the production manifest")


func test_fixture_registers_every_declared_semantic_id() -> void:
	var manifest := _manifest()
	if manifest.is_empty():
		assert_true(false, "fixture manifest must strict-parse")
		return
	var lines: Array = manifest.get("line_ids", [])
	assert_eq(lines, ["fixture.line.start", "fixture.line.after_choice", "fixture.line.after_effect"],
		"three text events map in order")
	assert_eq(manifest.get("choice_ids", []), ["fixture.choice.continue"], "one registered choice")
	assert_eq(manifest.get("signal_ids", []), ["fixture.marker.safe", "fixture.effect.tx", "fixture.variable.tx"],
		"safe marker, effect transaction and variable transaction signals")


func test_fixture_signal_descriptors_are_exact_and_non_gameplay() -> void:
	var manifest := _manifest()
	if manifest.is_empty():
		assert_true(false, "fixture manifest must strict-parse")
		return
	var descriptors: Dictionary = manifest.get("signal_descriptors", {})
	assert_eq(str((descriptors.get("fixture.marker.safe", {}) as Dictionary).get("kind", "")), "safe_marker")
	assert_eq(str((descriptors.get("fixture.effect.tx", {}) as Dictionary).get("kind", "")), "effect_transaction")
	assert_eq(str((descriptors.get("fixture.variable.tx", {}) as Dictionary).get("kind", "")), "variable_transaction")
	for id in ["fixture.marker.safe", "fixture.effect.tx", "fixture.variable.tx"]:
		var descriptor: Dictionary = descriptors.get(id, {})
		assert_true(str(descriptor.get("owner", "")) == "fixture",
			"a fixture signal never routes to a gameplay autoload: " + id)


func test_physical_fixture_text_declares_its_header_and_labels() -> void:
	if not FileAccess.file_exists(FIXTURE_PATH):
		assert_true(false, "missing physical Dialogic fixture")
		return
	var text := FileAccess.get_file_as_string(FIXTURE_PATH)
	assert_true("# timeline_id: fixture.phase2r.contract" in text, "declares its timeline id")
	assert_true("label fixture.start" in text, "declares its entry label")
	for signal_id in ["fixture.marker.safe", "fixture.effect.tx", "fixture.variable.tx"]:
		assert_true(signal_id in text, "raises " + signal_id)
	assert_true(text.strip_edges().ends_with("return"), "terminates with return")


func test_fixture_event_indices_are_recorded_after_import() -> void:
	var manifest := _manifest()
	if manifest.is_empty():
		assert_true(false, "fixture manifest must strict-parse")
		return
	var events: Array = manifest.get("events", [])
	assert_true(events.size() >= 3, "the manifest records imported event indices")
	var seen := {}
	for event in events:
		var index := int((event as Dictionary).get("event_index", -1))
		assert_true(index >= 0, "each recorded event has a real index")
		assert_false(seen.has(index), "event indices are unique")
		seen[index] = true
		assert_false(str((event as Dictionary).get("event_kind", "")).is_empty(), "each event records its kind")


func test_fixture_content_fingerprint_matches_the_physical_file() -> void:
	var manifest := _manifest()
	if manifest.is_empty() or not FileAccess.file_exists(FIXTURE_PATH):
		assert_true(false, "fixture and manifest are required")
		return
	assert_eq(str(manifest.get("content_fingerprint", "")), "sha256:" + FileAccess.get_sha256(FIXTURE_PATH),
		"the manifest is bound to the exact fixture bytes")
