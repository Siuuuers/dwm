extends "res://addons/gut/test.gd"

const MANIFEST_PATH := "res://data/manifests/timelines.json"
const ENDINGS_PATH := "res://data/manifests/endings.json"
const CATALOG_SOURCE := "res://scripts/data/DialogicTimelineCatalog.gd"
const STRICT_JSON := preload("res://scripts/validation/StrictJson.gd")
const DATING_ENDING_RULES := preload("res://scripts/domain/ending/DatingEndingRules.gd")
const CATALOG := preload("res://scripts/data/DialogicTimelineCatalog.gd")

const RETIRED_ENDING_IDS := ["ending.priscilla.true", "ending.lavinia.true", "ending.sylvia.true"]


func _load(path: String) -> Dictionary:
	assert_true(FileAccess.file_exists(path), "missing " + path)
	if not FileAccess.file_exists(path):
		return {}
	var parsed := STRICT_JSON.parse_object(FileAccess.get_file_as_string(path))
	assert_true(parsed.get("ok", false), str(parsed))
	return parsed.get("value", {})


func _sorted(values: Array) -> Array:
	var out: Array = []
	for value in values:
		out.append(str(value))
	out.sort()
	return out


func test_exact_timeline_manifest_is_required() -> void:
	var manifest := _load(MANIFEST_PATH)
	assert_eq(manifest.get("schema_version"), 1, "schema_version")
	assert_eq(str(manifest.get("locale")), "en", "locale")


func test_exactly_59_records_one_per_physical_file() -> void:
	var records: Array = _load(MANIFEST_PATH).get("records", [])
	assert_eq(records.size(), 59, "expected 59 timeline records")
	var ids := {}
	var paths := {}
	for record in records:
		var id := str(record["id"])
		var path := str(record["path"])
		assert_false(ids.has(id), "duplicate timeline id " + id)
		ids[id] = true
		assert_false(paths.has(path), "duplicate physical path " + path)
		paths[path] = true
		var res_path := "res://" + path
		assert_true(FileAccess.file_exists(res_path), "missing physical file " + res_path)
		assert_eq("sha256:" + FileAccess.get_sha256(res_path), str(record["content_fingerprint"]), "fingerprint drift for " + path)


func test_status_counts_are_24_placeholder_35_draft() -> void:
	var records: Array = _load(MANIFEST_PATH).get("records", [])
	var placeholder := 0
	var draft := 0
	for record in records:
		match str(record["content_status"]):
			"placeholder": placeholder += 1
			"draft": draft += 1
	assert_eq(placeholder, 24, "placeholder count")
	assert_eq(draft, 35, "draft count")


func test_no_broad_pattern_lookup_remains_in_catalog() -> void:
	var source := FileAccess.get_file_as_string(CATALOG_SOURCE)
	assert_false("_relative_path" in source, "catalog still infers paths by pattern (_relative_path)")
	assert_false("_contact_path" in source, "catalog still infers paths by pattern (_contact_path)")
	assert_false("_dating_path" in source, "catalog still infers paths by pattern (_dating_path)")


func test_catalog_resolves_ids_through_manifest() -> void:
	assert_true(CATALOG.has_timeline_id("ending.sylvia"), "known id should resolve")
	assert_false(CATALOG.has_timeline_id("does.not.exist"), "unknown id should not resolve")
	var resolved := CATALOG.get_path_for_id("dating.solo.sylvia.day3.pre_challenge")
	assert_true(resolved.get("ok", false), str(resolved))
	assert_eq(str((resolved.get("value", {}) as Dictionary).get("path", "")),
		"res://dialogic/timelines/en/dating/solo/sylvia_day3_pre_challenge.dtl", "manifest path")


func test_endings_manifest_matches_canonical_rules() -> void:
	var endings := _load(ENDINGS_PATH)
	var records: Array = endings.get("records", [])
	assert_eq(records.size(), 11, "expected 11 ending records")
	var by_id := {}
	for record in _load(MANIFEST_PATH).get("records", []):
		by_id[str(record["id"])] = record
	var primary: Array = []
	var postscript: Array = []
	var epilogue: Array = []
	for record in records:
		var ending_id := str(record["ending_id"])
		var role := str(record["role"])
		assert_false(ending_id in RETIRED_ENDING_IDS, "retired ending id present: " + ending_id)
		match role:
			"primary": primary.append(ending_id)
			"postscript": postscript.append(ending_id)
			"epilogue": epilogue.append(ending_id)
			_: assert_true(false, "unknown role " + role)
		var timeline_id := str(record["timeline_id"])
		assert_true(by_id.has(timeline_id), "unknown ending timeline " + timeline_id)
		if by_id.has(timeline_id):
			assert_true(str(record["label"]) in (by_id[timeline_id] as Dictionary).get("labels", []),
				"ending label does not resolve: " + str(record["label"]))
	assert_eq(_sorted(primary), _sorted(DATING_ENDING_RULES.VALID_PRIMARY_IDS), "primary set")
	assert_eq(_sorted(postscript), _sorted(DATING_ENDING_RULES.POSTSCRIPT_IDS), "postscript set")
	assert_eq(_sorted(epilogue), ["ending.priscilla_lavinia"], "epilogue set")
