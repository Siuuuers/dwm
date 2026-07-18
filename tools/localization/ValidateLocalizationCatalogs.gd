extends SceneTree

const STRICT := preload("res://scripts/validation/StrictJson.gd")
const SCHEMA := preload("res://scripts/localization/LocalizationSchema.gd")
const WRITER := preload("res://scripts/validation/CanonicalJsonWriter.gd")

func _init() -> void:
	var manifest_result := STRICT.parse_object(FileAccess.get_file_as_string("res://localization/manifest.json"))
	if not manifest_result.get("ok", false): _fail(str(manifest_result)); return
	var manifest: Dictionary = manifest_result["value"]
	var catalogs := {}; var hashes := {}; var counts := {}
	for record in manifest["locales"]:
		var path := "res://localization/" + String(record["ui_file"])
		var parsed := STRICT.parse_object(FileAccess.get_file_as_string(path))
		if not parsed.get("ok", false): _fail(str(parsed)); return
		catalogs[record["id"]] = parsed["value"]
		hashes[record["id"]] = FileAccess.get_sha256(path)
		counts[record["id"]] = parsed["value"]["messages"].size()
	var valid := SCHEMA.validate_bundle(manifest, catalogs)
	if not valid.get("ok", false): _fail(str(valid)); return
	var evidence := {"catalog_counts": counts, "catalog_sha256": hashes, "manifest_sha256": FileAccess.get_sha256("res://localization/manifest.json"), "placeholder_validation": true, "schema_version": 1}
	var emitted := WRITER.stringify(evidence)
	if not emitted.get("ok", false): _fail(str(emitted)); return
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("res://evidence/phase_2r/localization"))
	var file := FileAccess.open("res://evidence/phase_2r/localization/full_catalog_validation.json", FileAccess.WRITE)
	if file == null: _fail("cannot write validation evidence"); return
	file.store_string(emitted["value"]); file.close(); quit(0)

func _fail(message: String) -> void:
	push_error("ValidateLocalizationCatalogs: " + message)
	quit(1)
