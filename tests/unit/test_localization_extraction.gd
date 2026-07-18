extends "res://addons/gut/test.gd"

const STRICT := preload("res://scripts/validation/StrictJson.gd")
const LOCALIZATION_SCHEMA := preload("res://scripts/localization/LocalizationSchema.gd")

func _read(path: String) -> Dictionary:
	var parsed := STRICT.parse_object(FileAccess.get_file_as_string(path))
	assert_true(parsed.get("ok", false), "%s: %s" % [path, parsed])
	return parsed.get("value", {})

func test_extracted_catalogs_equal_every_live_legacy_oracle_value() -> void:
	var manager_script: Script = load("res://autoload/LocalizationManager.gd")
	var manager: Node = autofree(manager_script.new())
	manager.call(&"_build_tables")
	var tables: Dictionary = manager.get("_tables").duplicate(true)
	for locale in ["en", "zh_CN", "zh_HK"]:
		var catalog := _read("res://localization/ui/%s.json" % locale)
		var extracted := {}
		for message in catalog["messages"]: extracted[message["id"]] = message["text"]
		assert_eq(extracted, tables[locale], locale)

func test_immutable_fingerprint_matches_exact_50_25_25_records() -> void:
	var evidence := _read("res://evidence/phase_2r/localization/legacy_subset_fingerprint.json")
	assert_eq(evidence["counts"], {"en": 50, "zh_CN": 25, "zh_HK": 25})
	var records: Array[Dictionary] = []
	for locale in ["en", "zh_CN", "zh_HK"]:
		for message in evidence["records"][locale]: records.append({"locale": locale, "id": message["id"], "text": message["text"]})
	assert_eq(LOCALIZATION_SCHEMA.fingerprint_records(records), evidence["combined_sha256"])
	assert_eq(FileAccess.get_sha256("res://autoload/LocalizationManager.gd"), evidence["oracle_sha256"])

func test_manifest_and_catalog_bundle_are_semantically_valid() -> void:
	var manifest := _read("res://localization/manifest.json")
	var catalogs := {}
	for record in manifest["locales"]: catalogs[record["id"]] = _read("res://localization/" + String(record["ui_file"]))
	assert_true(LOCALIZATION_SCHEMA.validate_bundle(manifest, catalogs).get("ok", false))

func test_manifest_rejects_duplicates_paths_and_cycles() -> void:
	var manifest := _read("res://localization/manifest.json")
	var duplicate := manifest.duplicate(true); duplicate["locales"].append(duplicate["locales"][0].duplicate(true))
	assert_false(LOCALIZATION_SCHEMA.validate_manifest(duplicate, "res://localization/").get("ok", true))
	var escaped := manifest.duplicate(true); escaped["locales"][1]["ui_file"] = "../outside.json"
	assert_false(LOCALIZATION_SCHEMA.validate_manifest(escaped, "res://localization/").get("ok", true))
	var cycle := manifest.duplicate(true); cycle["locales"][1]["fallback_locale"] = "zh_HK"; cycle["locales"][2]["fallback_locale"] = "zh_CN"
	assert_false(LOCALIZATION_SCHEMA.validate_manifest(cycle, "res://localization/").get("ok", true))

func test_placeholder_mismatch_rejects_bundle() -> void:
	var manifest := _read("res://localization/manifest.json")
	var catalogs := {}
	for record in manifest["locales"]: catalogs[record["id"]] = _read("res://localization/" + String(record["ui_file"]))
	for message in catalogs["zh_CN"]["messages"]:
		if message["id"] == "hud.minesweeper_rounds": message["text"] = "{wrong}"; break
	assert_eq(LOCALIZATION_SCHEMA.validate_bundle(manifest, catalogs).get("code"), &"placeholder_mismatch")
